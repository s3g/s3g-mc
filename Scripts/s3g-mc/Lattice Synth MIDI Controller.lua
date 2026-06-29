-- @description Lattice Synth MIDI Controller
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; JSFX: s3g MC Lattice Synth Engine
-- @category Procedural Synthesis
-- @method Realtime controller for the Lattice Synth JSFX engine. Auto-loads the synth on the selected track and exposes table, gesture, resonator, and MIDI response controls for use with generated MIDI items.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Lattice Synth MIDI Controller", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local FX_NAME = "s3g MC Lattice Synth Engine"
local FX_NAME_CLEAN = "MC Lattice Synth Engine"
local WINDOW_TITLE = "Lattice Synth MIDI Controller"

local TEMPLATES = { "Circulating", "Diagonal fold", "Spiral", "Cross address", "Egress pull" }
local PITCH_MODES = { "Pitch sets frequency", "Pitch transposes base", "Gate only" }
local FOCUS_MODES = { "All channels", "Focus by MIDI channel" }
local CLEAR_MODES = { "Keep extra channels", "Clear extra channels" }

local PARAM = {
  channels = 0,
  template = 1,
  rows = 2,
  cols = 3,
  layers = 4,
  in_row = 5,
  in_col = 6,
  out_row = 7,
  out_col = 8,
  gesture_pos = 9,
  mutation = 10,
  resonance = 11,
  damping = 12,
  brightness = 13,
  divider = 14,
  feedback = 15,
  spread = 16,
  base_freq = 17,
  gain = 18,
  seed = 19,
  clear = 20,
  midi = 21,
  pitch = 22,
  focus = 23,
  vel_excitation = 24,
  vel_brightness = 25,
  gate = 26,
  focus_width = 27,
}

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
  grid = color(0.48, 0.52, 0.51, 0.32),
  text = color(0.80, 0.84, 0.82, 1),
  dim = color(0.50, 0.55, 0.54, 1),
  line = color(0.28, 0.72, 0.68, 1),
  hit = color(0.95, 0.74, 0.28, 1),
  ingress = color(0.16, 0.80, 0.95, 1),
  egress = color(1.00, 0.36, 0.28, 1),
  muted = color(0.22, 0.24, 0.25, 1),
}

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function hash01(x)
  local v = math.sin((x + 1.2345) * 12.9898) * 43758.5453
  return v - math.floor(v)
end

local function wrap(value, count)
  return ((math.floor(value) - 1) % math.max(1, count)) + 1
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

local function draw_combo(label, labels, param, width)
  local current = clamp(math.floor(get_param(param) + 0.5) + 1, 1, #labels)
  ImGui.SetNextItemWidth(ctx, width or 220)
  local changed, next_index = ImGui.Combo(ctx, label, current, table.concat(labels, "\0") .. "\0")
  if changed then set_param(param, next_index - 1) end
end

local function draw_slider(label, param, lo, hi, fmt, width)
  local value = get_param(param)
  ImGui.SetNextItemWidth(ctx, width or 520)
  local changed, next_value = ImGui.SliderDouble(ctx, label, value, lo, hi, fmt)
  if changed then set_param(param, next_value) end
end

local function draw_int_slider(label, param, lo, hi, width)
  local value = math.floor(get_param(param) + 0.5)
  ImGui.SetNextItemWidth(ctx, width or 220)
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

local function table_value(row, col, layer, rows, cols, layers, seed)
  row = wrap(row, rows)
  col = wrap(col, cols)
  layer = wrap(layer, layers)
  local diag = (row * 7 + col * 11 + layer * 13 + seed * 3) % 23
  local wave = math.sin(row * 1.73 + col * 2.11 + layer * 0.83 + seed * 0.07)
  return clamp((diag / 22) * 0.62 + ((wave + 1) * 0.5) * 0.38, 0, 1)
end

local function path_step(template, row, col, in_row, in_col, out_row, out_col, rows, cols, index)
  if template == 2 then
    row = row + 1
    col = col + ((index % 2 == 0) and -1 or 1)
  elseif template == 3 then
    local phase = index % 4
    if phase == 0 then col = col + 1
    elseif phase == 1 then row = row + 1
    elseif phase == 2 then col = col - 1
    else row = row - 1 end
  elseif template == 4 then
    if index % 3 == 0 then
      row = out_row
      col = col + 1
    elseif index % 3 == 1 then
      col = out_col
      row = row + 1
    else
      row = row - 1
      col = col - 1
    end
  elseif template == 5 then
    row = row + (out_row > row and 1 or (out_row < row and -1 or 0))
    col = col + (out_col > col and 1 or (out_col < col and -1 or 0))
    if row == out_row and col == out_col then
      row = in_row
      col = in_col
    end
  else
    col = col + 1
    if col > cols then
      col = 1
      row = row + 1
    end
  end
  return wrap(row, rows), wrap(col, cols)
end

local function draw_lattice_preview()
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  local h = 300
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, COLORS.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, COLORS.edge)
  ImGui.DrawList_AddText(draw_list, x + 12, y + 10, COLORS.dim, "LATTICE SYNTH")

  local rows = math.floor(get_param(PARAM.rows) + 0.5)
  local cols = math.floor(get_param(PARAM.cols) + 0.5)
  local layers = math.floor(get_param(PARAM.layers) + 0.5)
  local in_row = math.min(rows, math.floor(get_param(PARAM.in_row) + 0.5))
  local in_col = math.min(cols, math.floor(get_param(PARAM.in_col) + 0.5))
  local out_row = math.min(rows, math.floor(get_param(PARAM.out_row) + 0.5))
  local out_col = math.min(cols, math.floor(get_param(PARAM.out_col) + 0.5))
  local template = math.floor(get_param(PARAM.template) + 0.5) + 1
  local seed = math.floor(get_param(PARAM.seed) + 0.5)
  local mutation = get_param(PARAM.mutation)
  local pos = get_param(PARAM.gesture_pos)

  local table_w = math.min(w * 0.64, h * 1.02)
  local table_h = h - 62
  local cell = math.max(14, math.min(30, math.floor(math.min(table_w / cols, table_h / rows))))
  local grid_w = cell * cols
  local grid_h = cell * rows
  local gx = x + 22
  local gy = y + 42

  for layer = layers, 1, -1 do
    local off = (layer - 1) * 4
    ImGui.DrawList_AddRect(draw_list, gx + off, gy - off, gx + grid_w + off, gy + grid_h - off,
      layer == 1 and COLORS.grid or COLORS.muted)
  end

  for row = 1, rows do
    for col = 1, cols do
      local v = table_value(row, col, 1, rows, cols, layers, seed)
      local cx1 = gx + (col - 1) * cell
      local cy1 = gy + (row - 1) * cell
      local shade = 0.08 + v * 0.13
      ImGui.DrawList_AddRectFilled(draw_list, cx1, cy1, cx1 + cell - 1, cy1 + cell - 1,
        color(shade, shade + 0.012, shade + 0.014, 1))
      ImGui.DrawList_AddRect(draw_list, cx1, cy1, cx1 + cell, cy1 + cell, COLORS.grid)
    end
  end

  local row, col = in_row, in_col
  local last_x, last_y
  local steps = 24
  for index = 1, steps do
    local px = gx + (col - 0.5) * cell
    local py = gy + (row - 0.5) * cell
    if last_x then ImGui.DrawList_AddLine(draw_list, last_x, last_y, px, py, COLORS.line, 1.2) end
    local active = index / steps <= pos
    ImGui.DrawList_AddCircleFilled(draw_list, px, py, active and 4.4 or 2.5, active and COLORS.hit or COLORS.dim)
    local jitter = (hash01(seed * 19 + index * 7) - 0.5) * mutation
    row, col = path_step(template, row + jitter, col - jitter, in_row, in_col, out_row, out_col, rows, cols, index)
    last_x, last_y = px, py
  end

  local ix = gx + (in_col - 0.5) * cell
  local iy = gy + (in_row - 0.5) * cell
  local ox = gx + (out_col - 0.5) * cell
  local oy = gy + (out_row - 0.5) * cell
  ImGui.DrawList_AddCircle(draw_list, ix, iy, 9, COLORS.ingress, 16, 2)
  ImGui.DrawList_AddCircle(draw_list, ox, oy, 9, COLORS.egress, 16, 2)

  local sx = gx + grid_w + 44
  ImGui.DrawList_AddText(draw_list, sx, y + 42, COLORS.dim, TEMPLATES[template])
  ImGui.DrawList_AddText(draw_list, sx, y + 66, COLORS.dim, "layers " .. tostring(layers))
  ImGui.DrawList_AddText(draw_list, sx, y + 90, COLORS.dim, "in " .. in_row .. "," .. in_col)
  ImGui.DrawList_AddText(draw_list, sx, y + 114, COLORS.dim, "out " .. out_row .. "," .. out_col)
  ImGui.DrawList_AddText(draw_list, sx, y + 148, COLORS.text, "MIDI notes excite the table")
  ImGui.DrawList_AddText(draw_list, sx, y + 170, COLORS.dim, "channel = source focus")
  ImGui.DrawList_AddText(draw_list, sx, y + 192, COLORS.dim, "velocity = excitation")
  ImGui.SetCursorScreenPos(ctx, x, y + h + 10)
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
  ImGui.SetNextWindowSize(ctx, 820, 920, ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, WINDOW_TITLE, open)
  if visible then
    track = selected_track()
    if track and (fx < 0 or find_fx(track) ~= fx) then fx = load_fx(track) end

    if not track or fx < 0 then
      ImGui.TextColored(ctx, color(1, 0.45, 0.35, 1), status ~= "" and status or "Select a track and rescan JSFX if the engine is missing.")
    else
      draw_lattice_preview()

      local x, y, _, h = section("Engine", 170)
      draw_channels()
      ImGui.SameLine(ctx)
      draw_combo("Template", TEMPLATES, PARAM.template, 190)
      draw_slider("Gesture position", PARAM.gesture_pos, 0, 1, "%.3f")
      draw_slider("Gesture mutation", PARAM.mutation, 0, 1, "%.3f")
      draw_slider("Base frequency", PARAM.base_freq, 20, 4000, "%.1f Hz")
      draw_slider("Output gain", PARAM.gain, -60, 0, "%.1f dB")
      finish_section(x, y, h)

      x, y, _, h = section("Table", 185)
      draw_int_slider("Rows", PARAM.rows, 3, 12)
      ImGui.SameLine(ctx)
      draw_int_slider("Columns", PARAM.cols, 3, 12)
      draw_int_slider("Layers", PARAM.layers, 1, 8)
      draw_int_slider("Ingress row", PARAM.in_row, 1, math.max(1, math.floor(get_param(PARAM.rows) + 0.5)))
      ImGui.SameLine(ctx)
      draw_int_slider("Ingress column", PARAM.in_col, 1, math.max(1, math.floor(get_param(PARAM.cols) + 0.5)))
      draw_int_slider("Egress row", PARAM.out_row, 1, math.max(1, math.floor(get_param(PARAM.rows) + 0.5)))
      ImGui.SameLine(ctx)
      draw_int_slider("Egress column", PARAM.out_col, 1, math.max(1, math.floor(get_param(PARAM.cols) + 0.5)))
      finish_section(x, y, h)

      x, y, _, h = section("Resonator", 220)
      draw_slider("Resonance", PARAM.resonance, 0, 1, "%.3f")
      draw_slider("Damping", PARAM.damping, 0, 1, "%.3f")
      draw_slider("Brightness", PARAM.brightness, 0, 1, "%.3f")
      draw_slider("Divider shadow", PARAM.divider, 0, 1, "%.3f")
      draw_slider("Feedback drive", PARAM.feedback, 0, 1, "%.3f")
      draw_slider("Channel spread", PARAM.spread, 0, 1, "%.3f")
      finish_section(x, y, h)

      x, y, _, h = section("MIDI Response", 220)
      draw_combo("MIDI control", { "Off", "On" }, PARAM.midi, 120)
      ImGui.SameLine(ctx)
      draw_combo("Pitch mode", PITCH_MODES, PARAM.pitch, 210)
      draw_combo("Channel focus", FOCUS_MODES, PARAM.focus, 210)
      draw_slider("Velocity to excitation", PARAM.vel_excitation, 0, 1, "%.3f")
      draw_slider("Velocity to brightness", PARAM.vel_brightness, 0, 1, "%.3f")
      draw_slider("Note gate depth", PARAM.gate, 0, 1, "%.3f")
      draw_slider("Focus width", PARAM.focus_width, 0.02, 1, "%.3f")
      finish_section(x, y, h)

      draw_combo("Extra channel output", CLEAR_MODES, PARAM.clear, 190)
      ImGui.SameLine(ctx)
      draw_int_slider("Seed", PARAM.seed, 1, 9999, 190)
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Show JSFX") then reaper.TrackFX_Show(track, fx, 3) end
    end
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
