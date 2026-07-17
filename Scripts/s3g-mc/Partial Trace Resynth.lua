-- @description Partial Trace Resynth
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Offline Synthesis / IR
-- @render Yes; analyzes one selected item and renders a multichannel oscillator resynthesis.
-- @method Offline NumPy analysis-resynthesis. Select one WAV-backed media item; prominent spectral peaks are analyzed with an STFT and rendered as a multichannel oscillator field with breakpoint control over amplitude, trace gain, drift, and spatial width.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")
local be = dofile(script_dir .. "Breakpoint Envelope Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Partial Trace Resynth", 0)
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

local EXT = "s3g_mc_partial_trace_resynth_v2"
local FFT_SIZES = { 1024, 2048, 4096, 8192 }
local TRACE_BEHAVIORS = {
  { label = "Linked partials", value = "linked" },
  { label = "Point traces", value = "point" },
  { label = "Smear trails", value = "smear" },
  { label = "Frozen shimmer", value = "freeze" },
}
local OUTPUT_CHANNELS = {}
for ch = 2, mc.MAX_REAPER_TRACK_CHANNELS, 2 do
  OUTPUT_CHANNELS[#OUTPUT_CHANNELS + 1] = ch
end

local ENV_DEFS = {
  { key = "amplitude", label = "Amplitude", min = 0.0, max = 1.5, default = 1.0, fmt = "%.2f" },
  { key = "density", label = "Density", min = 0.0, max = 1.0, default = 1.0, fmt = "%.2f" },
  { key = "trace_gain", label = "Trace gain", min = 0.05, max = 4.0, default = 1.0, fmt = "%.2f" },
  { key = "drift", label = "Drift", min = 0.0, max = 0.18, default = 0.012, fmt = "%.3f" },
  { key = "spatial_width", label = "Spatial width", min = 0.05, max = 6.0, default = 0.65, fmt = "%.2f" },
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
  ["FFT SIZE"] = "FFT",
  ["HOP SAMPLES"] = "HOP",
  ["TRACES PER FRAME"] = "TRACES",
  ["TRACE LENGTH MS"] = "LEN",
  ["ANALYSIS FLOOR DB"] = "FLOOR",
  ["PITCH SCALE"] = "PITCH",
  ["TRACE BEHAVIOR"] = "MODE",
  ["TRACKING TOLERANCE CENTS"] = "TOL",
  ["MIN LINKED FRAMES"] = "MIN",
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
  if type(avail) ~= "number" then avail = 600 end
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
  for index, candidate in ipairs(values) do
    if candidate == value then current = index break end
  end
  local x, y, control_x, control_w = row_layout(ctx)
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, control_w)
  if ImGui.BeginCombo(ctx, "##" .. label, tostring(values[current])) then
    for index, candidate in ipairs(values) do
      local selected = index == current
      if ImGui.Selectable(ctx, tostring(candidate), selected) then
        current = index
        value = candidate
      end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  finish_row(ctx, x, y)
  return value
end

local function combo_behavior(ctx, label, value)
  local current = 1
  for index, behavior in ipairs(TRACE_BEHAVIORS) do
    if behavior.value == value then current = index break end
  end
  local x, y, control_x, control_w = row_layout(ctx)
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, control_w)
  if ImGui.BeginCombo(ctx, "##" .. label, TRACE_BEHAVIORS[current].label) then
    for index, behavior in ipairs(TRACE_BEHAVIORS) do
      local selected = index == current
      if ImGui.Selectable(ctx, behavior.label, selected) then
        current = index
        value = behavior.value
      end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  finish_row(ctx, x, y)
  return value
end

local function selected_entry()
  local entries = nr.selected_entries()
  if #entries == 0 then
    mc.show_error("Select one WAV-backed media item first.")
    return nil
  end
  if #entries > 1 then
    mc.show_error("Partial Trace Resynth uses one selected media item at a time.")
    return nil
  end
  local entry = entries[1]
  if not entry.filename or entry.filename == "" then
    mc.show_error("The selected item does not expose a source WAV path.")
    return nil
  end
  if not entry.filename:lower():match("%.wav$") then
    mc.show_error("Partial Trace Resynth currently needs a WAV source item.")
    return nil
  end
  return entry
end

local function render(entry, settings, env_points, env_enabled)
  settings.channels = valid_output_channels(settings.channels, math.max(2, entry.channels or 2))
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_partial_trace_renders", entry.filename, script_dir)
  local output_path = out_dir .. "/s3g_partial_trace_resynth_" .. stamp .. "_" .. tostring(settings.channels) .. "ch.wav"
  local manifest = {
    source_path = entry.filename,
    source_start = entry.start_offset or 0,
    source_duration = (entry.length or settings.duration) * (entry.playrate or 1.0),
    output_path = output_path,
    sample_rate = settings.sample_rate,
    duration = settings.duration,
    channels = settings.channels,
    fft_size = settings.fft_size,
    hop = settings.hop,
    partials_per_frame = settings.partials_per_frame,
    partial_ms = settings.partial_ms,
    floor_db = settings.floor_db,
    pitch_scale = settings.pitch_scale,
    density = settings.density,
    trace_gain = settings.trace_gain,
    drift = settings.drift,
    brightness = settings.brightness,
    spatial_width = settings.spatial_width,
    trace_behavior = settings.trace_behavior,
    track_tolerance_cents = settings.track_tolerance_cents,
    min_track_frames = settings.min_track_frames,
    clarity_protect = settings.clarity_protect,
    low_cut_hz = settings.low_cut_hz,
    soft_limit = settings.soft_limit,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    seed = settings.seed,
  }
  be.add_to_manifest(manifest, ENV_DEFS, env_points, env_enabled)
  local log, elapsed = nr.run_backend(script_dir, "partial_trace_resynth", manifest, "Partial Trace Resynth")
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path,
    "Partial trace resynth (" .. tostring(settings.channels) .. "ch)", entry.position, settings.channels,
    { track_gain = settings.insert_gain })
  reaper.Undo_EndBlock("Partial Trace Resynth", -1)
  if not item then mc.show_error(err or "Could not insert rendered partial trace resynthesis.") return end
  mc.print_plan("Partial Trace Resynth", {
    "Source: " .. (entry.name or entry.filename),
    "Output: " .. output_path,
    "Duration: " .. tostring(settings.duration) .. " sec",
    "Channels: " .. tostring(settings.channels),
    "Inserted track gain: " .. string.format("%.1f dB", 20 * math.log(settings.insert_gain, 10)),
    "NumPy time: " .. string.format("%.2f sec", elapsed),
    log,
  })
end

local function main()
  local entry = selected_entry()
  if not entry then return end
  local source_sr = nr.source_sample_rate(entry)
  local default_channels = valid_output_channels(entry.channels or 2, 2)
  local settings = {
    sample_rate = get_number("sample_rate", source_sr),
    duration = get_number("duration", math.max(0.1, entry.length or 6.0)),
    channels = valid_output_channels(get_number("channels", default_channels), default_channels),
    fft_size = get_number("fft_size", 2048),
    hop = get_number("hop", 512),
    partials_per_frame = get_number("partials_per_frame", 10),
    partial_ms = get_number("partial_ms", 120.0),
    floor_db = get_number("floor_db", -62.0),
    pitch_scale = get_number("pitch_scale", 1.0),
    density = get_number("density", 1.0),
    trace_gain = get_number("trace_gain", 0.65),
    drift = get_number("drift", 0.012),
    brightness = get_number("brightness", 1.05),
    spatial_width = get_number("spatial_width", 0.65),
    trace_behavior = get_string("trace_behavior", "linked"),
    track_tolerance_cents = get_number("track_tolerance_cents", 90.0),
    min_track_frames = get_number("min_track_frames", 3),
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
  local ctx = ImGui.CreateContext("Partial Trace Resynth")
  local open = true
  local should_render = false
  local selected_env = 1
  local selected_env_point = nil
  local env_opts = { height = 150, overview_lane_h = 58, random_amount = 0.35, random_count = 12, random_dispersion = 0.25, random_smooth = true, collapse_editor = true, compact_window_h = 760, expanded_window_h = 760 }

  local function loop()
    ImGui.SetNextWindowSize(ctx, 800, env_opts._editor_was_open and env_opts.expanded_window_h or env_opts.compact_window_h, ImGui.Cond_Always)
    local visible
    visible, open = ImGui.Begin(ctx, "Partial Trace Resynth", open)
    if visible then
      local _, avail_h = ImGui.GetContentRegionAvail(ctx)
      local control_h = math.max(260, (avail_h or env_opts.compact_window_h) - 44)
      if ImGui.BeginChild(ctx, "##partial_trace_controls", 0, control_h) then
      theme.muted(ImGui, ctx, "Source: " .. (entry.name or entry.filename))
      local changed
      ImGui.Spacing(ctx)
      selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env,
        selected_env_point, settings, env_opts)
      ImGui.Separator(ctx)
      local sx, sy, sh, stack = section(ctx, "Analysis", 252)
      changed, settings.duration = draw_custom_slider(ctx, "Render duration sec", settings.duration, 0.1, 300.0, "%.2f", false)
      settings.channels = combo_value(ctx, "Output channels", math.floor(settings.channels), OUTPUT_CHANNELS)
      settings.fft_size = combo_value(ctx, "FFT size", math.floor(settings.fft_size), FFT_SIZES)
      changed, settings.hop = draw_custom_slider(ctx, "Hop samples", math.floor(settings.hop), 64, math.floor(settings.fft_size), nil, true)
      changed, settings.partials_per_frame = draw_custom_slider(ctx, "Traces per frame", math.floor(settings.partials_per_frame), 1, 64, nil, true)
      changed, settings.density = draw_custom_slider(ctx, "Density", settings.density, 0.0, 1.0, "%.2f", false)
      changed, settings.partial_ms = draw_custom_slider(ctx, "Trace length ms", settings.partial_ms, 20.0, 1200.0, "%.1f", false)
      changed, settings.floor_db = draw_custom_slider(ctx, "Analysis floor dB", settings.floor_db, -96.0, -12.0, "%.1f", false)
      finish_section(ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = section(ctx, "Trace", settings.trace_behavior == "linked" and 252 or 200)
      changed, settings.pitch_scale = draw_custom_slider(ctx, "Pitch scale", settings.pitch_scale, 0.125, 4.0, "%.3f", false)
      settings.trace_behavior = combo_behavior(ctx, "Trace behavior", settings.trace_behavior)
      if settings.trace_behavior == "linked" then
        changed, settings.track_tolerance_cents = draw_custom_slider(ctx, "Tracking tolerance cents", settings.track_tolerance_cents, 15.0, 400.0, "%.1f", false)
        changed, settings.min_track_frames = draw_custom_slider(ctx, "Min linked frames", math.floor(settings.min_track_frames), 2, 24, nil, true)
      end
      changed, settings.trace_gain = draw_custom_slider(ctx, "Trace gain", settings.trace_gain, 0.05, 4.0, "%.2f", false)
      changed, settings.brightness = draw_custom_slider(ctx, "Magnitude curve", settings.brightness, 0.35, 3.0, "%.2f", false)
      changed, settings.drift = draw_custom_slider(ctx, "Frequency drift", settings.drift, 0.0, 0.18, "%.3f", false)
      changed, settings.spatial_width = draw_custom_slider(ctx, "Spatial width", settings.spatial_width, 0.05, 6.0, "%.2f", false)
      finish_section(ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = section(ctx, "Output", settings.clarity_protect and (settings.normalize and 200 or 174) or (settings.normalize and 148 or 122))
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
      settings.min_track_frames = clamp(math.floor(settings.min_track_frames), 2, 64)
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
      render(entry, settings, env_points, env_enabled)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
