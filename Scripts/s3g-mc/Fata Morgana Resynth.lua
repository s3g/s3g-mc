-- @description Fata Morgana Resynth
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Offline Synthesis / IR
-- @render Yes; analyzes multiple selected items and renders a multichannel hybrid resynthesis.
-- @method Offline NumPy hybrid resynthesis. Select 2-16 WAV-backed media items; the action recombines timing, pitch, amplitude, and spatial traits from their STFT peak traces into a new multichannel oscillator field.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")
local be = dofile(script_dir .. "Breakpoint Envelope Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Fata Morgana Resynth", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local WINDOW_OPEN_COND = ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver

local EXT = "s3g_mc_fata_morgana_resynth_v2"
local FFT_SIZES = { 1024, 2048, 4096, 8192 }
local OUTPUT_CHANNELS = {}
for ch = 2, mc.MAX_REAPER_TRACK_CHANNELS, 2 do OUTPUT_CHANNELS[#OUTPUT_CHANNELS + 1] = ch end

local HYBRID_MODES = {
  { label = "Chimera", value = "chimera" },
  { label = "Mirage", value = "mirage" },
  { label = "Graft", value = "graft" },
  { label = "Swarm splice", value = "swarm" },
  { label = "Spectral mask", value = "mask" },
}

local TRACE_BEHAVIORS = {
  { label = "Point traces", value = "point" },
  { label = "Smear trails", value = "smear" },
  { label = "Frozen shimmer", value = "freeze" },
}

local ENV_DEFS = {
  { key = "amplitude", label = "Amplitude", min = 0.0, max = 1.5, default = 1.0, fmt = "%.2f" },
  { key = "density", label = "Density", min = 0.0, max = 1.0, default = 0.8, fmt = "%.2f" },
  { key = "trace_gain", label = "Trace gain", min = 0.05, max = 4.0, default = 1.0, fmt = "%.2f" },
  { key = "mutation", label = "Mutation", min = 0.0, max = 1.0, default = 0.65, fmt = "%.2f" },
  { key = "drift", label = "Drift", min = 0.0, max = 0.18, default = 0.012, fmt = "%.3f" },
  { key = "spatial_width", label = "Spatial width", min = 0.05, max = 6.0, default = 0.75, fmt = "%.2f" },
}

local function get_number(key, default)
  local value = tonumber(reaper.GetExtState(EXT, key))
  return value or default
end

local function get_bool(key, default)
  local value = reaper.GetExtState(EXT, key)
  if value == "" then return default end
  return value ~= "0"
end

local function get_string(key, default)
  local value = reaper.GetExtState(EXT, key)
  if value == "" then return default end
  return value
end

local function store(settings)
  for key, value in pairs(settings) do
    reaper.SetExtState(EXT, key, type(value) == "boolean" and (value and "1" or "0") or tostring(value), true)
  end
end

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function valid_output_channels(value, fallback)
  value = math.floor(tonumber(value) or 0)
  fallback = math.floor(tonumber(fallback) or 2)
  if fallback < 2 then fallback = 2 end
  if fallback > mc.MAX_REAPER_TRACK_CHANNELS then fallback = mc.MAX_REAPER_TRACK_CHANNELS end
  if fallback % 2 ~= 0 then fallback = fallback + 1 end
  if value < 2 or value > mc.MAX_REAPER_TRACK_CHANNELS or value % 2 ~= 0 then return fallback end
  return value
end

local function combo_value(ctx, label, value, values)
  local current = 1
  for index, candidate in ipairs(values) do if candidate == value then current = index break end end
  if ImGui.BeginCombo(ctx, label, tostring(values[current])) then
    for index, candidate in ipairs(values) do
      local selected = index == current
      if ImGui.Selectable(ctx, tostring(candidate), selected) then current = index value = candidate end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return value
end

local function combo_table(ctx, label, value, values)
  local current = 1
  for index, entry in ipairs(values) do if entry.value == value then current = index break end end
  if ImGui.BeginCombo(ctx, label, values[current].label) then
    for index, entry in ipairs(values) do
      local selected = index == current
      if ImGui.Selectable(ctx, entry.label, selected) then current = index value = entry.value end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return value
end

local function selected_entries()
  local entries = nr.selected_entries()
  if #entries < 2 then
    mc.show_error("Select at least two WAV-backed media items.")
    return nil
  end
  if #entries > 16 then
    mc.show_error("Fata Morgana Resynth supports up to 16 selected media items.")
    return nil
  end
  for _, entry in ipairs(entries) do
    if not entry.filename or entry.filename == "" or not entry.filename:lower():match("%.wav$") then
      mc.show_error("Every selected item must be backed by a WAV source.")
      return nil
    end
  end
  return entries
end

local function render(entries, settings, env_points, env_enabled)
  settings.channels = valid_output_channels(settings.channels, 8)
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_fata_morgana_renders", entries[1].filename, script_dir)
  local output_path = out_dir .. "/s3g_fata_morgana_" .. stamp .. "_" .. tostring(settings.channels) .. "ch.wav"
  local manifest = {
    output_path = output_path,
    sample_rate = settings.sample_rate,
    duration = settings.duration,
    channels = settings.channels,
    source_count = #entries,
    fft_size = settings.fft_size,
    hop = settings.hop,
    partials_per_frame = settings.partials_per_frame,
    partial_ms = settings.partial_ms,
    floor_db = settings.floor_db,
    pitch_scale = settings.pitch_scale,
    density = settings.density,
    mutation = settings.mutation,
    texture_bias = settings.texture_bias,
    trace_gain = settings.trace_gain,
    drift = settings.drift,
    brightness = settings.brightness,
    spatial_width = settings.spatial_width,
    hybrid_mode = settings.hybrid_mode,
    trace_behavior = settings.trace_behavior,
    clarity_protect = settings.clarity_protect,
    low_cut_hz = settings.low_cut_hz,
    soft_limit = settings.soft_limit,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    seed = settings.seed,
  }
  for index, entry in ipairs(entries) do
    manifest["source" .. tostring(index) .. "_path"] = entry.filename
    manifest["source" .. tostring(index) .. "_start"] = entry.start_offset or 0
    manifest["source" .. tostring(index) .. "_duration"] = (entry.length or settings.duration) * (entry.playrate or 1.0)
  end
  be.add_to_manifest(manifest, ENV_DEFS, env_points, env_enabled)
  local log, elapsed = nr.run_backend(script_dir, "fata_morgana", manifest, "Fata Morgana Resynth")
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path,
    "Fata Morgana resynth (" .. tostring(settings.channels) .. "ch)", entries[1].position, settings.channels)
  reaper.Undo_EndBlock("Fata Morgana Resynth", -1)
  if not item then mc.show_error(err or "Could not insert rendered Fata Morgana resynthesis.") return end
  local track = reaper.GetMediaItem_Track(item)
  if track then
    reaper.SetMediaTrackInfo_Value(track, "D_VOL", settings.insert_gain)
  end
  mc.print_plan("Fata Morgana Resynth", {
    "Sources: " .. tostring(#entries),
    "Output: " .. output_path,
    "Duration: " .. tostring(settings.duration) .. " sec",
    "Channels: " .. tostring(settings.channels),
    "Texture bias: " .. string.format("%.2f", settings.texture_bias),
    "Insert gain: " .. string.format("%.1f dB", 20 * math.log(settings.insert_gain, 10)),
    "NumPy time: " .. string.format("%.2f sec", elapsed),
    log,
  })
end

local function main()
  local entries = selected_entries()
  if not entries then return end
  local default_channels = valid_output_channels(math.max(2, entries[1].channels or 2), 2)
  local settings = {
    sample_rate = get_number("sample_rate", nr.source_sample_rate(entries[1])),
    duration = get_number("duration", math.max(0.1, entries[1].length or 6.0)),
    channels = valid_output_channels(get_number("channels", default_channels), default_channels),
    fft_size = get_number("fft_size", 2048),
    hop = get_number("hop", 512),
    partials_per_frame = get_number("partials_per_frame", 8),
    partial_ms = get_number("partial_ms", 140.0),
    floor_db = get_number("floor_db", -62.0),
    pitch_scale = get_number("pitch_scale", 1.0),
    density = get_number("density", 0.65),
    mutation = get_number("mutation", 0.55),
    texture_bias = get_number("texture_bias", 0.55),
    trace_gain = get_number("trace_gain", 0.45),
    drift = get_number("drift", 0.012),
    brightness = get_number("brightness", 1.05),
    spatial_width = get_number("spatial_width", 0.75),
    hybrid_mode = get_string("hybrid_mode", "chimera"),
    trace_behavior = get_string("trace_behavior", "point"),
    clarity_protect = get_bool("clarity_protect", true),
    low_cut_hz = get_number("low_cut_hz", 30.0),
    soft_limit = get_bool("soft_limit", false),
    normalize = get_bool("normalize", true),
    normalize_db = get_number("normalize_db", -12.0),
    insert_gain = get_number("insert_gain", 0.25),
    seed = get_number("seed", 1),
  }
  local env_points, env_enabled = be.init(ENV_DEFS, settings)
  be.load_extstate(EXT, ENV_DEFS, env_points, env_enabled)
  local ctx = ImGui.CreateContext("Fata Morgana Resynth")
  local open = true
  local should_render = false
  local selected_env = 1
  local selected_env_point = nil
  local env_opts = { height = 150, overview_lane_h = 58, random_amount = 0.35, random_count = 12, random_dispersion = 0.25, random_smooth = true }

  local function loop()
    ImGui.SetNextWindowSize(ctx, 780, 1040, WINDOW_OPEN_COND)
    local visible
    visible, open = ImGui.Begin(ctx, "Fata Morgana Resynth", open)
    if visible then
      ImGui.Text(ctx, "Selected sources: " .. tostring(#entries))
      if ImGui.BeginChild(ctx, "##sources", 0, 92) then
        for index, entry in ipairs(entries) do
          ImGui.Text(ctx, tostring(index) .. ". " .. (entry.name or entry.filename) .. "  (" .. tostring(entry.channels) .. " ch)")
        end
        ImGui.EndChild(ctx)
      end
      local changed
      changed, settings.duration = ImGui.SliderDouble(ctx, "Render duration sec", settings.duration, 0.1, 300.0, "%.2f")
      settings.channels = combo_value(ctx, "Output channels", math.floor(settings.channels), OUTPUT_CHANNELS)
      settings.hybrid_mode = combo_table(ctx, "Hybrid mode", settings.hybrid_mode, HYBRID_MODES)
      settings.trace_behavior = combo_table(ctx, "Trace behavior", settings.trace_behavior, TRACE_BEHAVIORS)
      settings.fft_size = combo_value(ctx, "FFT size", math.floor(settings.fft_size), FFT_SIZES)
      changed, settings.hop = ImGui.SliderInt(ctx, "Hop samples", math.floor(settings.hop), 64, math.floor(settings.fft_size))
      changed, settings.partials_per_frame = ImGui.SliderInt(ctx, "Traces per frame", math.floor(settings.partials_per_frame), 1, 64)
      changed, settings.density = ImGui.SliderDouble(ctx, "Density", settings.density, 0.0, 1.0, "%.2f")
      changed, settings.mutation = ImGui.SliderDouble(ctx, "Trait mutation", settings.mutation, 0.0, 1.0, "%.2f")
      changed, settings.texture_bias = ImGui.SliderDouble(ctx, "Texture bias", settings.texture_bias, 0.0, 1.0, "%.2f")
      changed, settings.partial_ms = ImGui.SliderDouble(ctx, "Trace length ms", settings.partial_ms, 20.0, 1200.0, "%.1f")
      changed, settings.floor_db = ImGui.SliderDouble(ctx, "Analysis floor dB", settings.floor_db, -96.0, -12.0, "%.1f")
      changed, settings.pitch_scale = ImGui.SliderDouble(ctx, "Pitch scale", settings.pitch_scale, 0.125, 4.0, "%.3f")
      changed, settings.trace_gain = ImGui.SliderDouble(ctx, "Trace gain", settings.trace_gain, 0.05, 4.0, "%.2f")
      changed, settings.brightness = ImGui.SliderDouble(ctx, "Magnitude curve", settings.brightness, 0.35, 3.0, "%.2f")
      changed, settings.drift = ImGui.SliderDouble(ctx, "Frequency drift", settings.drift, 0.0, 0.18, "%.3f")
      changed, settings.spatial_width = ImGui.SliderDouble(ctx, "Spatial width", settings.spatial_width, 0.05, 6.0, "%.2f")
      ImGui.Separator(ctx)
      changed, settings.clarity_protect = ImGui.Checkbox(ctx, "Clarity protect", settings.clarity_protect)
      if settings.clarity_protect then
        changed, settings.low_cut_hz = ImGui.SliderDouble(ctx, "Low cut / min partial Hz", settings.low_cut_hz, 0.0, 180.0, "%.1f")
        changed, settings.soft_limit = ImGui.Checkbox(ctx, "Soft limit peaks", settings.soft_limit)
      end
      changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -36.0, -3.0, "%.1f")
      end
      changed, settings.insert_gain = ImGui.SliderDouble(ctx, "Inserted track gain", settings.insert_gain, 0.05, 1.0, "%.2f")
      changed, settings.seed = ImGui.InputInt(ctx, "Seed", math.floor(settings.seed))
      settings.channels = valid_output_channels(settings.channels, default_channels)
      settings.hop = clamp(math.floor(settings.hop), 16, math.floor(settings.fft_size))
      ImGui.Separator(ctx)
      selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env,
        selected_env_point, settings, env_opts)
      if ImGui.Button(ctx, "Render", 96, 28) then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 96, 28) then open = false end
      ImGui.End(ctx)
    end
    if should_render then
      open = false
      store(settings)
      be.save_extstate(EXT, ENV_DEFS, env_points, env_enabled)
      render(entries, settings, env_points, env_enabled)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
