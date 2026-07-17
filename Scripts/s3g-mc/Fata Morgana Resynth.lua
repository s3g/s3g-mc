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
do
  local _s3g_theme_path = ({ reaper.get_action_context() })[2]
  if not _s3g_theme_path or _s3g_theme_path == "" then
    _s3g_theme_path = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
  end
  local _s3g_theme_dir = _s3g_theme_path:match("^(.*[/\\])") or ""
  package.path = _s3g_theme_dir .. "?.lua;" .. package.path
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme and _s3g_theme.install then _s3g_theme.install(ImGui) end
end
local theme = require("s3g-mc ImGui Theme")
local THEME = theme.palette(ImGui)

local WINDOW_OPEN_COND = ImGui.Cond_Appearing

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

local ROW_H = 25
local LABEL_W = 86
local CONTROL_GAP = 8
local VALUE_W = 76
local LABEL_ABBR = {
  ["RENDER DURATION SEC"] = "DUR",
  ["OUTPUT CHANNELS"] = "OUT CH",
  ["HYBRID MODE"] = "HYBRID",
  ["TRACE BEHAVIOR"] = "TRACE",
  ["FFT SIZE"] = "FFT",
  ["HOP SAMPLES"] = "HOP",
  ["TRACES PER FRAME"] = "TRACES",
  ["TRAIT MUTATION"] = "MUTATE",
  ["TEXTURE BIAS"] = "BIAS",
  ["TRACE LENGTH MS"] = "LEN",
  ["ANALYSIS FLOOR DB"] = "FLOOR",
  ["PITCH SCALE"] = "PITCH",
  ["TRACE GAIN"] = "GAIN",
  ["MAGNITUDE CURVE"] = "CURVE",
  ["FREQUENCY DRIFT"] = "DRIFT",
  ["SPATIAL WIDTH"] = "WIDTH",
  ["CLARITY PROTECT"] = "CLARITY",
  ["LOW CUT / MIN PARTIAL HZ"] = "LOWCUT",
  ["SOFT LIMIT PEAKS"] = "LIMIT",
  ["PEAK NORMALIZE"] = "PEAK",
  ["NORMALIZE DB"] = "NORM DB",
  ["INSERTED TRACK GAIN"] = "INSERT",
}

local function row_label_text(label)
  local upper = tostring(label or ""):upper()
  return LABEL_ABBR[upper] or upper
end

local function row_layout(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local avail = ImGui.GetContentRegionAvail(ctx)
  if type(avail) ~= "number" then avail = 620 end
  local control_x = x + LABEL_W
  local control_w = math.max(120, avail - LABEL_W - CONTROL_GAP)
  return x, y, control_x, control_w
end

local function row_label(ctx, x, y, label)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 4, THEME.label, row_label_text(label))
end

local function finish_row(ctx, x, y)
  ImGui.SetCursorScreenPos(ctx, x, y + ROW_H)
end

local function draw_custom_slider(ctx, label, value, lo, hi, fmt, integer)
  local x, y, control_x, control_w = row_layout(ctx)
  local slider_w = math.max(80, control_w - VALUE_W - CONTROL_GAP)
  local value_x = control_x + slider_w + CONTROL_GAP
  local track_y = y + 8
  local track_h = 8
  local norm = hi ~= lo and clamp((value - lo) / (hi - lo), 0, 1) or 0
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.InvisibleButton(ctx, "##" .. label, slider_w, ROW_H)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local changed = false
  if (hovered or active) and ImGui.IsMouseDown(ctx, 0) then
    local mx = ImGui.GetMousePos(ctx)
    local next_norm = clamp((mx - control_x) / slider_w, 0, 1)
    local next_value = lo + (hi - lo) * next_norm
    if integer then next_value = math.floor(next_value + 0.5) end
    if math.abs(next_value - value) > (integer and 0 or 0.0000001) then
      value = next_value
      norm = next_norm
      changed = true
    end
  end
  local draw = ImGui.GetWindowDrawList(ctx)
  local frame = active and THEME.frame_active or (hovered and THEME.frame_hover or THEME.frame)
  local fill = active and THEME.active or THEME.fill
  local handle = active and THEME.active_hover or THEME.active
  ImGui.DrawList_AddRectFilled(draw, control_x, track_y, control_x + slider_w, track_y + track_h, frame)
  ImGui.DrawList_AddRectFilled(draw, control_x + 1, track_y + 1, control_x + math.max(2, slider_w * norm), track_y + track_h - 1, fill)
  local hx = clamp(control_x + slider_w * norm - 1.5, control_x + 1, control_x + slider_w - 4)
  ImGui.DrawList_AddRectFilled(draw, hx, track_y - 2, hx + 3, track_y + track_h + 2, handle)
  ImGui.DrawList_AddText(draw, value_x, y + 4, THEME.value, integer and tostring(math.floor(value + 0.5)) or string.format(fmt or "%.3f", value))
  finish_row(ctx, x, y)
  return changed, value
end

local function draw_int_input(ctx, label, value)
  local x, y, control_x, control_w = row_layout(ctx)
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, control_w)
  local changed, next_value = ImGui.InputInt(ctx, "##" .. label, math.floor(value))
  finish_row(ctx, x, y)
  return changed, next_value
end

local function draw_checkbox(ctx, label, value)
  local x, y, control_x = row_layout(ctx)
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y + 2)
  local changed, next_value = ImGui.Checkbox(ctx, "##" .. label, value)
  finish_row(ctx, x, y)
  return changed, next_value
end

local function section(ctx, label, height)
  local stack = theme.push_soft_panel(ImGui, ctx)
  local draw = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + height, THEME.panel_soft)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + 2, THEME.active)
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 10)
  theme.text(ImGui, ctx, label:upper())
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 36)
  return x, y, height, stack
end

local function finish_section(ctx, x, y, height, stack)
  theme.pop_soft_panel(ImGui, ctx, stack)
  ImGui.SetCursorScreenPos(ctx, x, y + height + 10)
  ImGui.Dummy(ctx, 1, 1)
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
  local x, y, control_x, control_w = row_layout(ctx)
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, control_w)
  if ImGui.BeginCombo(ctx, "##" .. label, tostring(values[current])) then
    for index, candidate in ipairs(values) do
      local selected = index == current
      if ImGui.Selectable(ctx, tostring(candidate), selected) then current = index value = candidate end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  finish_row(ctx, x, y)
  return value
end

local function combo_table(ctx, label, value, values)
  local current = 1
  for index, entry in ipairs(values) do if entry.value == value then current = index break end end
  local x, y, control_x, control_w = row_layout(ctx)
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, control_w)
  if ImGui.BeginCombo(ctx, "##" .. label, values[current].label) then
    for index, entry in ipairs(values) do
      local selected = index == current
      if ImGui.Selectable(ctx, entry.label, selected) then current = index value = entry.value end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  finish_row(ctx, x, y)
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
  local env_opts = { height = 150, overview_lane_h = 58, random_amount = 0.35, random_count = 12, random_dispersion = 0.25, random_smooth = true, collapse_editor = true, compact_window_h = 760, expanded_window_h = 760 }

  local function loop()
    ImGui.SetNextWindowSize(ctx, 820, env_opts._editor_was_open and env_opts.expanded_window_h or env_opts.compact_window_h, ImGui.Cond_Always)
    local visible
    visible, open = ImGui.Begin(ctx, "Fata Morgana Resynth", open)
    if visible then
      local _, avail_h = ImGui.GetContentRegionAvail(ctx)
      local control_h = math.max(260, (avail_h or env_opts.compact_window_h) - 44)
      if ImGui.BeginChild(ctx, "##fata_morgana_controls", 0, control_h) then
      theme.muted(ImGui, ctx, "Selected sources: " .. tostring(#entries))
      if ImGui.BeginChild(ctx, "##sources", 0, 92) then
        for index, entry in ipairs(entries) do
          theme.muted(ImGui, ctx, tostring(index) .. ". " .. (entry.name or entry.filename) .. "  (" .. tostring(entry.channels) .. " ch)")
        end
        ImGui.EndChild(ctx)
      end
      local changed
      selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env,
        selected_env_point, settings, env_opts)
      ImGui.Separator(ctx)
      local sx, sy, sh, stack = section(ctx, "Analysis", 226)
      changed, settings.duration = draw_custom_slider(ctx, "Render duration sec", settings.duration, 0.1, 300.0, "%.2f", false)
      settings.channels = combo_value(ctx, "Output channels", math.floor(settings.channels), OUTPUT_CHANNELS)
      settings.hybrid_mode = combo_table(ctx, "Hybrid mode", settings.hybrid_mode, HYBRID_MODES)
      settings.trace_behavior = combo_table(ctx, "Trace behavior", settings.trace_behavior, TRACE_BEHAVIORS)
      settings.fft_size = combo_value(ctx, "FFT size", math.floor(settings.fft_size), FFT_SIZES)
      changed, settings.hop = draw_custom_slider(ctx, "Hop samples", math.floor(settings.hop), 64, math.floor(settings.fft_size), nil, true)
      changed, settings.partials_per_frame = draw_custom_slider(ctx, "Traces per frame", math.floor(settings.partials_per_frame), 1, 64, nil, true)
      changed, settings.density = draw_custom_slider(ctx, "Density", settings.density, 0.0, 1.0, "%.2f", false)
      finish_section(ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = section(ctx, "Hybrid", 226)
      changed, settings.mutation = draw_custom_slider(ctx, "Trait mutation", settings.mutation, 0.0, 1.0, "%.2f", false)
      changed, settings.texture_bias = draw_custom_slider(ctx, "Texture bias", settings.texture_bias, 0.0, 1.0, "%.2f", false)
      changed, settings.partial_ms = draw_custom_slider(ctx, "Trace length ms", settings.partial_ms, 20.0, 1200.0, "%.1f", false)
      changed, settings.floor_db = draw_custom_slider(ctx, "Analysis floor dB", settings.floor_db, -96.0, -12.0, "%.1f", false)
      changed, settings.pitch_scale = draw_custom_slider(ctx, "Pitch scale", settings.pitch_scale, 0.125, 4.0, "%.3f", false)
      changed, settings.trace_gain = draw_custom_slider(ctx, "Trace gain", settings.trace_gain, 0.05, 4.0, "%.2f", false)
      changed, settings.brightness = draw_custom_slider(ctx, "Magnitude curve", settings.brightness, 0.35, 3.0, "%.2f", false)
      changed, settings.drift = draw_custom_slider(ctx, "Frequency drift", settings.drift, 0.0, 0.18, "%.3f", false)
      finish_section(ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = section(ctx, "Output", settings.clarity_protect and (settings.normalize and 226 or 200) or (settings.normalize and 174 or 148))
      changed, settings.spatial_width = draw_custom_slider(ctx, "Spatial width", settings.spatial_width, 0.05, 6.0, "%.2f", false)
      changed, settings.clarity_protect = draw_checkbox(ctx, "Clarity protect", settings.clarity_protect)
      if settings.clarity_protect then
        changed, settings.low_cut_hz = draw_custom_slider(ctx, "Low cut / min partial Hz", settings.low_cut_hz, 0.0, 180.0, "%.1f", false)
        changed, settings.soft_limit = draw_checkbox(ctx, "Soft limit peaks", settings.soft_limit)
      end
      changed, settings.normalize = draw_checkbox(ctx, "Peak normalize", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = draw_custom_slider(ctx, "Normalize dB", settings.normalize_db, -36.0, -3.0, "%.1f", false)
      end
      changed, settings.insert_gain = draw_custom_slider(ctx, "Inserted track gain", settings.insert_gain, 0.05, 1.0, "%.2f", false)
      changed, settings.seed = draw_int_input(ctx, "Seed", settings.seed)
      finish_section(ctx, sx, sy, sh, stack)
      settings.channels = valid_output_channels(settings.channels, default_channels)
      settings.hop = clamp(math.floor(settings.hop), 16, math.floor(settings.fft_size))
        ImGui.EndChild(ctx)
      end
      if ImGui.Button(ctx, "RENDER", 96, 28) then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "CANCEL", 96, 28) then open = false end
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
