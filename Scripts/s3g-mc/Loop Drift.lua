-- @description Loop Drift
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Multichannel Texture / Montage
-- @render Yes; NumPy-backed render from one selected media item.
-- @method Offline NumPy renderer. Select one or more WAV-backed media items, choose source-pool routing, output channels, overlap-add seam crossfade, source-channel distribution, rate quantization, direction behavior, start jitter, gain variation, and output motion; breakpoint curves can shape amplitude, rate spread, drift, spread, gain variation, and motion over time.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")
local be = dofile(script_dir .. "Breakpoint Envelope Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Loop Drift", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local WINDOW_OPEN_COND = ImGui.Cond_Appearing
local EXT = "s3g_mc_loop_drift_v1"

local ENV_DEFS = {
  { key = "amplitude", label = "Amplitude", min = 0.0, max = 1.5, default = 1.0, fmt = "%.2f" },
  { key = "rate_amount", label = "Rate spread", min = 0.0, max = 1.0, default = 0.08, fmt = "%.3f" },
  { key = "drift_amount", label = "Rate drift", min = 0.0, max = 0.12, default = 0.0, fmt = "%.4f" },
  { key = "spatial_spread", label = "Neighbor spread", min = 0.0, max = 1.0, default = 0.0, fmt = "%.2f" },
  { key = "gain_variation_db", label = "Gain variation", min = 0.0, max = 6.0, default = 0.0, fmt = "%.1f dB" },
  { key = "output_motion", label = "Output motion", min = 0.0, max = 1.0, default = 0.0, fmt = "%.2f" },
}

local RATE_MODES = {
  { label = "Deviation", value = "deviation" },
  { label = "Spread", value = "spread" },
  { label = "Ascending", value = "ascending" },
  { label = "Descending", value = "descending" },
  { label = "Random steps", value = "random_steps" },
}

local DISTRIBUTIONS = {
  { label = "Cycle source channels", value = "cycle" },
  { label = "Mono sum to all", value = "mono_sum" },
  { label = "Adjacent pairs", value = "paired" },
  { label = "Mirror source channels", value = "mirror" },
  { label = "Random source per output", value = "random" },
}

local RATE_QUANTIZE = {
  { label = "Free", value = "free" },
  { label = "Quarter-tone", value = "quartertone" },
  { label = "Semitone", value = "semitone" },
  { label = "Simple ratios", value = "simple_ratios" },
}

local DIRECTION_MODES = {
  { label = "Forward", value = "forward" },
  { label = "Reverse", value = "reverse" },
  { label = "Alternating", value = "alternating" },
  { label = "Mirror pairs", value = "mirror_pairs" },
  { label = "Random", value = "random" },
}

local PHASE_MODES = {
  { label = "Even phase", value = "even" },
  { label = "Aligned", value = "aligned" },
  { label = "Random phase", value = "random" },
}

local SOURCE_MODES = {
  { label = "First selected only", value = "first" },
  { label = "Cycle selected items", value = "cycle_items" },
  { label = "Item per channel group", value = "item_per_group" },
  { label = "Random item per channel", value = "random_channel" },
  { label = "Layer all selected", value = "layer_all" },
}

local function get_number(key, default)
  local value = tonumber(reaper.GetExtState(EXT, key))
  return value or default
end

local function set_number(key, value)
  reaper.SetExtState(EXT, key, tostring(value), true)
end

local function get_string(key, default)
  local value = reaper.GetExtState(EXT, key)
  if value == "" then return default end
  return value
end

local function set_string(key, value)
  reaper.SetExtState(EXT, key, tostring(value), true)
end

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function combo_from_options(ctx, label, current, options)
  local current_index = 1
  for index, option in ipairs(options) do
    if option.value == current then current_index = index end
  end
  local preview = options[current_index].label
  local changed = false
  if ImGui.BeginCombo(ctx, label, preview) then
    for index, option in ipairs(options) do
      local selected = index == current_index
      if ImGui.Selectable(ctx, option.label, selected) then
        current = option.value
        changed = true
      end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return changed, current
end

local function add_sources_to_manifest(manifest, entries)
  manifest.source_count = #entries
  for index, entry in ipairs(entries) do
    if entry.filename == "" or not nr.file_exists(entry.filename) then
      return false, "Every selected source item must be backed by a readable WAV file."
    end
    local suffix = index == 1 and "" or ("_" .. tostring(index))
    manifest["source_path" .. suffix] = entry.filename
    manifest["source_start" .. suffix] = entry.start_offset
    manifest["source_duration" .. suffix] = entry.length * math.max(0.000001, entry.playrate)
  end
  return true, nil
end

local function render(entries, settings, env_points, env_enabled)
  local entry = entries[1]
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_loop_drift_renders", entry.filename, script_dir)
  local output_path = out_dir .. "/s3g_loop_drift_" .. stamp .. "_" .. tostring(settings.channels) .. "ch.wav"
  local manifest = {
    output_path = output_path,
    sample_rate = nr.source_sample_rate(entry),
    duration = settings.duration,
    channels = settings.channels,
    xfade_ms = settings.xfade_ms,
    xfade_duck = settings.xfade_duck,
    base_rate = settings.base_rate,
    rate_amount = settings.rate_amount,
    rate_mode = settings.rate_mode,
    rate_quantize = settings.rate_quantize,
    distribution = settings.distribution,
    source_mode = settings.source_mode,
    source_group_size = settings.source_group_size,
    phase_mode = settings.phase_mode,
    direction_mode = settings.direction_mode,
    reverse_probability = settings.reverse_probability,
    start_jitter_ms = settings.start_jitter_ms,
    drift_amount = settings.drift_amount,
    spatial_spread = settings.spatial_spread,
    gain_variation_db = settings.gain_variation_db,
    output_motion = settings.output_motion,
    gain = settings.gain,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    seed = settings.seed,
  }
  local ok, err = add_sources_to_manifest(manifest, entries)
  if not ok then mc.show_error(err) return end
  be.add_to_manifest(manifest, ENV_DEFS, env_points, env_enabled)

  local log, elapsed = nr.run_backend(script_dir, "loop_drift_bed", manifest, "Loop Drift")
  if not log then return end

  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path,
    "Loop Drift (" .. tostring(settings.channels) .. "ch)", entry.position, settings.channels)
  reaper.Undo_EndBlock("Loop Drift", -1)
  if not item then mc.show_error(err or "Could not insert rendered loop drift.") return end

  mc.print_plan("Loop Drift", {
    "Sources: " .. tostring(#entries),
    "Output: " .. output_path,
    "Duration: " .. string.format("%.2f sec", settings.duration),
    "Channels: " .. tostring(settings.channels),
    "Rate mode: " .. settings.rate_mode .. " / " .. settings.rate_quantize,
    "Distribution: " .. settings.distribution,
    "Source mode: " .. settings.source_mode,
    "Direction: " .. settings.direction_mode,
    "NumPy time: " .. string.format("%.2f sec", elapsed),
    log,
  })
end

local function main()
  local entries = nr.selected_entries()
  if #entries < 1 then
    mc.show_error("Select one WAV-backed audio media item first.")
    return
  end
  local entry = entries[1]
  local settings = {
    duration = get_number("duration", math.max(1.0, entry.length)),
    channels = get_number("channels", math.max(2, entry.channels)),
    xfade_ms = get_number("xfade_ms", 80.0),
    xfade_duck = get_number("xfade_duck", 0.12),
    base_rate = get_number("base_rate", 1.0),
    rate_amount = get_number("rate_amount", 0.08),
    rate_mode = get_string("rate_mode", "deviation"),
    rate_quantize = get_string("rate_quantize", "free"),
    source_mode = get_string("source_mode", #entries > 1 and "cycle_items" or "first"),
    source_group_size = get_number("source_group_size", 4),
    distribution = get_string("distribution", entry.channels == 1 and "mono_sum" or "cycle"),
    phase_mode = get_string("phase_mode", "even"),
    direction_mode = get_string("direction_mode", "forward"),
    reverse_probability = get_number("reverse_probability", 0.0),
    start_jitter_ms = get_number("start_jitter_ms", 0.0),
    drift_amount = get_number("drift_amount", 0.0),
    spatial_spread = get_number("spatial_spread", 0.0),
    gain_variation_db = get_number("gain_variation_db", 0.0),
    output_motion = get_number("output_motion", 0.0),
    gain = get_number("gain", 0.85),
    normalize = reaper.GetExtState(EXT, "normalize") ~= "0",
    normalize_db = get_number("normalize_db", -6.0),
    seed = get_number("seed", 1),
  }
  local env_points, env_enabled = be.init(ENV_DEFS, settings)
  be.load_extstate(EXT, ENV_DEFS, env_points, env_enabled)

  local ctx = ImGui.CreateContext("Loop Drift")
  local open = true
  local should_render = false
  local selected_env = 1
  local selected_env_point = nil
  local env_opts = { height = 150, overview_lane_h = 56, random_amount = 0.3, random_count = 12, random_dispersion = 0.25, random_smooth = true }

  local function loop()
    ImGui.SetNextWindowSize(ctx, 720, 760, WINDOW_OPEN_COND)
    local visible
    visible, open = ImGui.Begin(ctx, "Loop Drift", open)
    if visible then
      local _, avail_h = ImGui.GetContentRegionAvail(ctx)
      local control_h = math.max(300, (avail_h or 960) - 44)
      if ImGui.BeginChild(ctx, "##loop_drift_controls", 0, control_h) then
      ImGui.Text(ctx, "Sources: " .. tostring(#entries) .. " selected")
      local changed
      if ImGui.CollapsingHeader(ctx, "Render Setup", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        changed, settings.duration = ImGui.SliderDouble(ctx, "Duration sec", settings.duration, 0.25, 1800.0, "%.2f")
        changed, settings.channels = ImGui.SliderInt(ctx, "Output channels", math.floor(settings.channels), 1, mc.MAX_REAPER_TRACK_CHANNELS)
        changed, settings.xfade_ms = ImGui.SliderDouble(ctx, "Loop crossfade ms", settings.xfade_ms, 1.0, 2000.0, "%.1f")
        changed, settings.xfade_duck = ImGui.SliderDouble(ctx, "Seam duck", settings.xfade_duck, 0.0, 0.75, "%.2f")
      end
      if ImGui.CollapsingHeader(ctx, "Rate And Spatial Drift", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        changed, settings.base_rate = ImGui.SliderDouble(ctx, "Base rate", settings.base_rate, 0.125, 4.0, "%.4f")
        changed, settings.rate_amount = ImGui.SliderDouble(ctx, "Rate spread/deviation", settings.rate_amount, 0.0, 1.0, "%.4f")
        changed, settings.start_jitter_ms = ImGui.SliderDouble(ctx, "Start jitter ms", settings.start_jitter_ms, 0.0, 5000.0, "%.1f")
        changed, settings.drift_amount = ImGui.SliderDouble(ctx, "Slow rate drift", settings.drift_amount, 0.0, 0.12, "%.4f")
        changed, settings.spatial_spread = ImGui.SliderDouble(ctx, "Neighbor spread", settings.spatial_spread, 0.0, 1.0, "%.2f")
        changed, settings.output_motion = ImGui.SliderDouble(ctx, "Output motion", settings.output_motion, 0.0, 1.0, "%.2f")
        changed, settings.gain_variation_db = ImGui.SliderDouble(ctx, "Gain variation dB", settings.gain_variation_db, 0.0, 6.0, "%.1f")
        changed, settings.gain = ImGui.SliderDouble(ctx, "Render gain", settings.gain, 0.05, 2.0, "%.2f")
      end
      settings.channels = clamp(math.floor(settings.channels), 1, mc.MAX_REAPER_TRACK_CHANNELS)
      settings.seed = math.floor(settings.seed)
      if ImGui.CollapsingHeader(ctx, "Source And Output Rules", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        changed, settings.rate_mode = combo_from_options(ctx, "Rate mode", settings.rate_mode, RATE_MODES)
        changed, settings.rate_quantize = combo_from_options(ctx, "Rate quantize", settings.rate_quantize, RATE_QUANTIZE)
        changed, settings.source_mode = combo_from_options(ctx, "Source mode", settings.source_mode, SOURCE_MODES)
        if settings.source_mode == "item_per_group" then
          changed, settings.source_group_size = ImGui.SliderInt(ctx, "Source group size", math.floor(settings.source_group_size), 1, 32)
        end
        changed, settings.distribution = combo_from_options(ctx, "Source distribution", settings.distribution, DISTRIBUTIONS)
        changed, settings.phase_mode = combo_from_options(ctx, "Loop phase", settings.phase_mode, PHASE_MODES)
        changed, settings.direction_mode = combo_from_options(ctx, "Direction", settings.direction_mode, DIRECTION_MODES)
        if settings.direction_mode == "random" then
          changed, settings.reverse_probability = ImGui.SliderDouble(ctx, "Reverse probability", settings.reverse_probability, 0.0, 1.0, "%.2f")
        end
      end
      if ImGui.CollapsingHeader(ctx, "Output", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
        if settings.normalize then
          changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -36.0, -1.0, "%.1f")
        end
        changed, settings.seed = ImGui.InputInt(ctx, "Seed", math.floor(settings.seed))
      end
      ImGui.Separator(ctx)
      if ImGui.CollapsingHeader(ctx, "Breakpoint Envelopes", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env,
          selected_env_point, settings, env_opts)
      end
        ImGui.EndChild(ctx)
      end
      if ImGui.Button(ctx, "Render", 96, 28) then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 96, 28) then open = false end
      ImGui.End(ctx)
    end

    if should_render then
      open = false
      for key, value in pairs(settings) do
        if type(value) == "boolean" then
          reaper.SetExtState(EXT, key, value and "1" or "0", true)
        elseif type(value) == "number" then
          set_number(key, value)
        else
          set_string(key, value)
        end
      end
      be.save_extstate(EXT, ENV_DEFS, env_points, env_enabled)
      render(entries, settings, env_points, env_enabled)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
