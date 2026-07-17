-- @description Spectra Synth MIDI Controller
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; JSFX: s3g MC Spectra Synth Engine
-- @category Procedural Synthesis
-- @method Realtime controller for the Spectra Synth JSFX engine. Auto-loads the synth on the selected track and exposes MIDI response controls so MIDI items can drive pitch, gate, velocity response, and channel focus while preserving the separate offline render workflow.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Spectra Synth MIDI Controller", 0)
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
  package.loaded["s3g-mc ImGui Theme"] = nil
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme and _s3g_theme.install then _s3g_theme.install(ImGui) end
end

local theme = require("s3g-mc ImGui Theme")
local THEME = theme.palette(ImGui)

local FX_NAME = "s3g MC Spectra Synth Engine"
local FX_NAME_CLEAN = "MC Spectra Synth Engine"
local WINDOW_TITLE = "Spectra Synth MIDI Controller"
local ALGORITHMS = { "Partial cloud", "Comb strata", "Formant bands", "Impulse resonator", "Noise spectra" }

local PARAM = {
  channels = 0,
  algorithm = 1,
  rate = 2,
  base_freq = 3,
  density = 4,
  brightness = 5,
  decay = 6,
  spread = 7,
  correlation = 8,
  drift = 9,
  crush = 10,
  gain = 11,
  seed = 12,
  clear = 13,
  midi = 14,
  pitch = 15,
  focus = 16,
  vel_density = 17,
  vel_rate = 18,
  vel_gain = 19,
  gate = 20,
  focus_width = 21,
}

local PITCH_MODES = { "Pitch sets frequency", "Pitch transposes base", "Gate only" }
local FOCUS_MODES = { "All channels", "Focus by MIDI channel" }
local CLEAR_MODES = { "Keep extra channels", "Clear extra channels" }
local CH_NAMES, CH_VALUES = {}, {}
for ch = 2, 64, 2 do
  CH_NAMES[#CH_NAMES + 1] = tostring(ch)
  CH_VALUES[#CH_VALUES + 1] = ch
end
CH_NAMES[#CH_NAMES + 1] = "128"
CH_VALUES[#CH_VALUES + 1] = 128

local ctx = ImGui.CreateContext(WINDOW_TITLE)
local open = true
local status = ""

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local STYLE = {
  panel = THEME.panel,
  edge = THEME.edge,
  text = THEME.text,
  dim = THEME.value,
  warn = THEME.warn,
}

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function find_fx(track)
  if not track then return -1 end
  for fx = 0, reaper.TrackFX_GetCount(track) - 1 do
    local ok, name = reaper.TrackFX_GetFXName(track, fx, "")
    if ok and name and (name:find(FX_NAME, 1, true) or name:find(FX_NAME_CLEAN, 1, true)) then return fx end
  end
  return -1
end

local function selected_track()
  return reaper.GetSelectedTrack(0, 0) or reaper.GetTrack(0, 0)
end

local function load_fx(track)
  if not track then return -1 end
  local fx = find_fx(track)
  if fx >= 0 then return fx end
  fx = reaper.TrackFX_AddByName(track, "JS: " .. FX_NAME, false, -1)
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, FX_NAME, false, -1) end
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, "JS: " .. FX_NAME_CLEAN, false, -1) end
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, FX_NAME_CLEAN, false, -1) end
  status = fx >= 0 and "Loaded synth engine on selected track" or "Could not load synth engine. Rescan JSFX if needed."
  return fx
end

local track = selected_track()
local fx = load_fx(track)

local function get_param(param)
  if not track or fx < 0 then return 0 end
  return select(1, reaper.TrackFX_GetParam(track, fx, param))
end

local function set_param(param, value)
  if not track or fx < 0 then return end
  reaper.TrackFX_SetParam(track, fx, param, value)
end

local ROW_H = 25
local LABEL_W = 86
local CONTROL_GAP = 8
local VALUE_W = 76

local LABEL_ABBR = {
  ["OUTPUT CHANNELS"] = "OUT CH",
  ["BASE FREQUENCY"] = "BASE",
  ["OUTPUT GAIN"] = "OUT",
  ["DENSITY / CHAOS"] = "DENS",
  ["DECAY / SUSTAIN"] = "DECAY",
  ["FIELD SPREAD"] = "SPREAD",
  ["CHANNEL CORRELATION"] = "CORR",
  ["MIDI CONTROL"] = "MIDI",
  ["PITCH MODE"] = "PITCH",
  ["CHANNEL FOCUS"] = "FOCUS",
  ["VELOCITY TO DENSITY"] = "V DENS",
  ["VELOCITY TO RATE"] = "V RATE",
  ["VELOCITY TO GAIN"] = "V GAIN",
  ["NOTE GATE DEPTH"] = "GATE",
  ["FOCUS WIDTH"] = "WIDTH",
  ["EXTRA CHANNEL OUTPUT"] = "EXTRA",
}

local function row_label_text(label)
  local upper = tostring(label or ""):upper()
  return LABEL_ABBR[upper] or upper
end

local function row_layout()
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local avail = ImGui.GetContentRegionAvail(ctx)
  if type(avail) ~= "number" then avail = 360 end
  local control_x = x + LABEL_W
  local control_w = math.max(120, avail - LABEL_W - CONTROL_GAP)
  return x, y, control_x, control_w
end

local function row_label(x, y, label)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 4, THEME.label, row_label_text(label))
end

local function finish_row(x, y)
  ImGui.SetCursorScreenPos(ctx, x, y + ROW_H)
end

local function format_value(value, fmt, integer)
  if integer then return tostring(math.floor(value + 0.5)) end
  return string.format(fmt or "%.3f", value)
end

local function draw_custom_slider(label, value, lo, hi, fmt, integer)
  local x, y, control_x, control_w = row_layout()
  local slider_w = math.max(80, control_w - VALUE_W - CONTROL_GAP)
  local value_x = control_x + slider_w + CONTROL_GAP
  local track_y = y + 8
  local track_h = 8
  local norm = 0
  if hi ~= lo then norm = clamp((value - lo) / (hi - lo), 0, 1) end

  row_label(x, y, label)
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
  ImGui.DrawList_AddText(draw, value_x, y + 4, THEME.value, format_value(value, fmt, integer))
  finish_row(x, y)
  return changed, value
end

local function draw_combo(label, labels, param)
  local current = clamp(math.floor(get_param(param) + 0.5) + 1, 1, #labels)
  local x, y, control_x, control_w = row_layout()
  row_label(x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, control_w)
  local changed, next_index = ImGui.Combo(ctx, "##" .. label, current, table.concat(labels, "\0") .. "\0")
  finish_row(x, y)
  if changed then set_param(param, next_index - 1) end
end

local function draw_slider(label, param, lo, hi, fmt)
  local value = get_param(param)
  local changed, next_value = draw_custom_slider(label, value, lo, hi, fmt, false)
  if changed then set_param(param, next_value) end
end

local function draw_int_slider(label, param, lo, hi)
  local value = math.floor(get_param(param) + 0.5)
  local changed, next_value = draw_custom_slider(label, value, lo, hi, nil, true)
  if changed then set_param(param, next_value) end
end

local function draw_channels()
  local current_channels = math.floor(get_param(PARAM.channels) + 0.5)
  local index = 1
  for i, ch in ipairs(CH_VALUES) do
    if ch == current_channels then index = i end
  end
  local x, y, control_x, control_w = row_layout()
  row_label(x, y, "Output channels")
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, control_w)
  local changed, next_index = ImGui.Combo(ctx, "##Output channels", index, table.concat(CH_NAMES, "\0") .. "\0")
  finish_row(x, y)
  if changed then
    local channels = CH_VALUES[next_index]
    set_param(PARAM.channels, channels)
    if track then reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", channels) end
  end
end

local function section(label, height)
  local stack = theme.push_soft_panel(ImGui, ctx)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + height, THEME.panel_soft)
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + 2, THEME.active)
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 10)
  theme.text(ImGui, ctx, label:upper())
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 36)
  return x, y, w, height, stack
end

local function finish_section(x, y, h, stack)
  theme.pop_soft_panel(ImGui, ctx, stack)
  ImGui.SetCursorScreenPos(ctx, x, y + h + 10)
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 760, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, WINDOW_TITLE, open)
  if visible then
    track = selected_track()
    if track and (fx < 0 or find_fx(track) ~= fx) then fx = load_fx(track) end

    if not track or fx < 0 then
      theme.status(ImGui, ctx, status ~= "" and status or "Select a track and rescan JSFX if the engine is missing.", "warn")
    else
      local x, y, _, h, stack = section("Engine", 192)
      draw_channels()
      draw_combo("Algorithm", ALGORITHMS, PARAM.algorithm)
      draw_slider("Rate", PARAM.rate, 0, 1, "%.3f")
      draw_slider("Base frequency", PARAM.base_freq, 20, 4000, "%.1f Hz")
      draw_slider("Output gain", PARAM.gain, -60, 0, "%.1f dB")
      finish_section(x, y, h, stack)

      x, y, _, h, stack = section("Color / Field", 220)
      draw_slider("Density / chaos", PARAM.density, 0, 1, "%.3f")
      draw_slider("Brightness", PARAM.brightness, 0, 1, "%.3f")
      draw_slider("Decay / sustain", PARAM.decay, 0, 1, "%.3f")
      draw_slider("Field spread", PARAM.spread, 0, 1, "%.3f")
      draw_slider("Channel correlation", PARAM.correlation, 0, 1, "%.3f")
      draw_slider("Drift", PARAM.drift, 0, 1, "%.3f")
      finish_section(x, y, h, stack)

      x, y, _, h, stack = section("MIDI Response", 272)
      draw_combo("MIDI control", { "Off", "On" }, PARAM.midi)
      draw_combo("Pitch mode", PITCH_MODES, PARAM.pitch)
      draw_combo("Channel focus", FOCUS_MODES, PARAM.focus)
      draw_slider("Velocity to density", PARAM.vel_density, 0, 1, "%.3f")
      draw_slider("Velocity to rate", PARAM.vel_rate, 0, 1, "%.3f")
      draw_slider("Velocity to gain", PARAM.vel_gain, 0, 1, "%.3f")
      draw_slider("Note gate depth", PARAM.gate, 0, 1, "%.3f")
      draw_slider("Focus width", PARAM.focus_width, 0.02, 1, "%.3f")
      finish_section(x, y, h, stack)

      draw_combo("Extra channel output", CLEAR_MODES, PARAM.clear)
      draw_int_slider("Seed", PARAM.seed, 1, 9999)
      if ImGui.Button(ctx, "SHOW JSFX") then reaper.TrackFX_Show(track, fx, 3) end
    end
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
