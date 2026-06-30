-- @description Carto Synth MIDI Controller
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; JSFX: s3g MC Carto Synth Engine
-- @category Procedural Synthesis
-- @method Realtime controller for the Carto Synth JSFX engine. Auto-loads the synth on the selected track and exposes MIDI response controls so MIDI items can drive pitch, gate, velocity response, and channel focus while preserving the separate offline render workflow.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Carto Synth MIDI Controller", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local FX_NAME = "s3g MC Carto Synth Engine"
local FX_NAME_CLEAN = "MC Carto Synth Engine"
local WINDOW_TITLE = "Carto Synth MIDI Controller"
local ALGORITHMS = { "Dust field", "Pulse packet", "Logic / fractal drone", "Byte mask", "Spline drift" }

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

local COLORS = {
  panel = color(0.055, 0.060, 0.064, 1),
  edge = color(0.30, 0.32, 0.33, 1),
  text = color(0.80, 0.84, 0.82, 1),
  dim = color(0.50, 0.55, 0.54, 1),
  active = color(0.25, 0.78, 0.62, 1),
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

local function draw_combo(label, labels, param)
  local current = clamp(math.floor(get_param(param) + 0.5) + 1, 1, #labels)
  ImGui.SetNextItemWidth(ctx, 230)
  local changed, next_index = ImGui.Combo(ctx, label, current, table.concat(labels, "\0") .. "\0")
  if changed then set_param(param, next_index - 1) end
end

local function draw_slider(label, param, lo, hi, fmt)
  local value = get_param(param)
  ImGui.SetNextItemWidth(ctx, 520)
  local changed, next_value = ImGui.SliderDouble(ctx, label, value, lo, hi, fmt)
  if changed then set_param(param, next_value) end
end

local function draw_int_slider(label, param, lo, hi)
  local value = math.floor(get_param(param) + 0.5)
  ImGui.SetNextItemWidth(ctx, 220)
  local changed, next_value = ImGui.SliderInt(ctx, label, value, lo, hi)
  if changed then set_param(param, next_value) end
end

local function draw_channels()
  local current_channels = math.floor(get_param(PARAM.channels) + 0.5)
  local index = 1
  for i, ch in ipairs(CH_VALUES) do
    if ch == current_channels then index = i end
  end
  ImGui.SetNextItemWidth(ctx, 120)
  local changed, next_index = ImGui.Combo(ctx, "Output channels", index, table.concat(CH_NAMES, "\0") .. "\0")
  if changed then
    local channels = CH_VALUES[next_index]
    set_param(PARAM.channels, channels)
    if track then reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", channels) end
  end
end

local function section(label, height)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + height, COLORS.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + height, COLORS.edge)
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 10)
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, COLORS.text)
  ImGui.Text(ctx, label)
  ImGui.PopStyleColor(ctx)
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 36)
  return x, y, w, height
end

local function finish_section(x, y, h)
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
      ImGui.TextColored(ctx, color(1, 0.45, 0.35, 1), status ~= "" and status or "Select a track and rescan JSFX if the engine is missing.")
    else
      local x, y, _, h = section("Engine", 180)
      draw_channels()
      ImGui.SameLine(ctx)
      draw_combo("Algorithm", ALGORITHMS, PARAM.algorithm)
      draw_slider("Rate", PARAM.rate, 0, 1, "%.3f")
      draw_slider("Base frequency", PARAM.base_freq, 20, 4000, "%.1f Hz")
      draw_slider("Output gain", PARAM.gain, -60, 0, "%.1f dB")
      finish_section(x, y, h)

      x, y, _, h = section("Color / Field", 220)
      draw_slider("Density / chaos", PARAM.density, 0, 1, "%.3f")
      draw_slider("Brightness", PARAM.brightness, 0, 1, "%.3f")
      draw_slider("Decay / sustain", PARAM.decay, 0, 1, "%.3f")
      draw_slider("Field spread", PARAM.spread, 0, 1, "%.3f")
      draw_slider("Channel correlation", PARAM.correlation, 0, 1, "%.3f")
      draw_slider("Drift", PARAM.drift, 0, 1, "%.3f")
      finish_section(x, y, h)

      x, y, _, h = section("MIDI Response", 250)
      draw_combo("MIDI control", { "Off", "On" }, PARAM.midi)
      ImGui.SameLine(ctx)
      draw_combo("Pitch mode", PITCH_MODES, PARAM.pitch)
      draw_combo("Channel focus", FOCUS_MODES, PARAM.focus)
      draw_slider("Velocity to density", PARAM.vel_density, 0, 1, "%.3f")
      draw_slider("Velocity to rate", PARAM.vel_rate, 0, 1, "%.3f")
      draw_slider("Velocity to gain", PARAM.vel_gain, 0, 1, "%.3f")
      draw_slider("Note gate depth", PARAM.gate, 0, 1, "%.3f")
      draw_slider("Focus width", PARAM.focus_width, 0.02, 1, "%.3f")
      finish_section(x, y, h)

      draw_combo("Extra channel output", CLEAR_MODES, PARAM.clear)
      ImGui.SameLine(ctx)
      draw_int_slider("Seed", PARAM.seed, 1, 9999)
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Show JSFX") then reaper.TrackFX_Show(track, fx, 3) end
    end
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
