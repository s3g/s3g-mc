-- @description Generate Lattice MIDI
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; MIDI Rule Library.lua
-- @category MIDI Composition
-- @render No
-- @method Creates an editable MIDI item from a table-scanning gesture model. A visible lattice of cells is translated into pitch, velocity, duration, and MIDI-channel focus; the ingress-to-egress path shown in the GUI is the same path used to write the MIDI notes.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local midi = dofile(script_dir .. "MIDI Rule Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Generate Lattice MIDI", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "Generate Lattice MIDI"
local ctx = ImGui.CreateContext(TITLE)
local open = true
local status = ""

local ROOTS = midi.ROOT_NAMES
local SCALES = midi.SCALE_NAMES
local LENGTHS = { "Use time selection", "1 bar", "2 bars", "4 bars", "8 bars", "16 bars" }
local LENGTH_BEATS = { 0, 4, 8, 16, 32, 64 }
local TEMPLATES = { "Circulating", "Diagonal fold", "Spiral", "Cross address", "Egress pull" }
local LAYER_RULES = { "Pitch / velocity / channel", "Pitch / duration / channel", "Channel / pitch / velocity", "Velocity / channel / pitch" }

local state = {
  root = 1,
  scale = 2,
  length = 4,
  rows = 7,
  cols = 7,
  layers = 4,
  events = 48,
  template = 1,
  layer_rule = 1,
  ingress_row = 2,
  ingress_col = 2,
  egress_row = 6,
  egress_col = 6,
  density = 0.92,
  mutation = 0.18,
  octave = 3,
  span = 4,
  note_len = 0.55,
  velocity = 76,
  accent = 26,
  channels = 8,
  seed = 11,
}

local preview = {}
local table_cache = {}

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local COLORS = {
  panel = color(0.055, 0.060, 0.064, 1),
  panel2 = color(0.080, 0.086, 0.088, 1),
  edge = color(0.30, 0.32, 0.33, 1),
  grid = color(0.48, 0.52, 0.51, 0.35),
  text = color(0.80, 0.84, 0.82, 1),
  dim = color(0.50, 0.55, 0.54, 1),
  line = color(0.28, 0.72, 0.68, 1),
  hit = color(0.95, 0.74, 0.28, 1),
  ingress = color(0.16, 0.80, 0.95, 1),
  egress = color(1.00, 0.36, 0.28, 1),
  muted = color(0.22, 0.24, 0.25, 1),
}

local function combo(label, labels, value, width)
  ImGui.SetNextItemWidth(ctx, width or 160)
  local changed, next_value = ImGui.Combo(ctx, label, value, table.concat(labels, "\0") .. "\0")
  return changed, next_value
end

local function wrap(value, count)
  return ((math.floor(value) - 1) % math.max(1, count)) + 1
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function cell_key(row, col, layer)
  return tostring(layer) .. ":" .. tostring(row) .. ":" .. tostring(col)
end

local function build_table()
  table_cache = {}
  midi.seed(state.seed)
  for layer = 1, state.layers do
    for row = 1, state.rows do
      for col = 1, state.cols do
        local diagonal = (row * 7 + col * 11 + layer * 13 + state.seed * 3) % 23
        local wave = math.sin((row * 1.73 + col * 2.11 + layer * 0.83 + state.seed * 0.07))
        local value = (diagonal / 22) * 0.62 + ((wave + 1) * 0.5) * 0.38
        table_cache[cell_key(row, col, layer)] = midi.clamp(value, 0, 1)
      end
    end
  end
end

local function cell_value(row, col, layer)
  return table_cache[cell_key(wrap(row, state.rows), wrap(col, state.cols), wrap(layer, state.layers))] or 0
end

local function step_position(row, col, layer, index)
  local template = TEMPLATES[state.template]
  if template == "Diagonal fold" then
    row = row + 1
    col = col + ((index % 2 == 0) and -1 or 1)
  elseif template == "Spiral" then
    local phase = index % 4
    if phase == 0 then col = col + 1
    elseif phase == 1 then row = row + 1
    elseif phase == 2 then col = col - 1
    else row = row - 1 end
  elseif template == "Cross address" then
    if index % 3 == 0 then
      row = state.egress_row
      col = col + 1
    elseif index % 3 == 1 then
      col = state.egress_col
      row = row + 1
    else
      row = row - 1
      col = col - 1
    end
  elseif template == "Egress pull" then
    row = row + (state.egress_row > row and 1 or (state.egress_row < row and -1 or 0))
    col = col + (state.egress_col > col and 1 or (state.egress_col < col and -1 or 0))
    if row == state.egress_row and col == state.egress_col then
      row = state.ingress_row
      col = state.ingress_col
    end
  else
    col = col + 1
    if col > state.cols then
      col = 1
      row = row + 1
    end
  end
  if math.random() < state.mutation then
    row = row + math.floor(math.random() * 3) - 1
    col = col + math.floor(math.random() * 3) - 1
  end
  layer = layer + 1
  return wrap(row, state.rows), wrap(col, state.cols), wrap(layer, state.layers)
end

local function translate_cell(row, col, layer, event_index)
  local a = cell_value(row, col, layer)
  local b = cell_value(row + 1, col - 1, layer + 1)
  local c = cell_value(row - 1, col + 1, layer + 2)
  local rule = LAYER_RULES[state.layer_rule]
  local pitch_v, vel_v, chan_v, dur_v = a, b, c, (a + b + c) / 3
  if rule == "Pitch / duration / channel" then
    pitch_v, dur_v, chan_v, vel_v = a, b, c, (a * 0.55 + c * 0.45)
  elseif rule == "Channel / pitch / velocity" then
    chan_v, pitch_v, vel_v, dur_v = a, b, c, (b * 0.5 + c * 0.5)
  elseif rule == "Velocity / channel / pitch" then
    vel_v, chan_v, pitch_v, dur_v = a, b, c, (a * 0.35 + b * 0.65)
  end

  local degree_span = math.max(4, state.span * 7)
  local degree = math.floor(lerp(-degree_span * 0.35, degree_span, pitch_v) + 0.5)
  local pitch = midi.scale_pitch(ROOTS[state.root], SCALES[state.scale], degree, state.octave, state.span)
  local channel = math.floor(chan_v * math.max(0, state.channels - 1) + 0.5)
  local velocity = midi.velocity(state.velocity + vel_v * 18, state.accent, event_index, 5, 5)
  local note_len = lerp(0.16, 1.25, dur_v) * state.note_len
  return pitch, channel, velocity, note_len, degree
end

local function generate_preview()
  build_table()
  preview = {}
  midi.seed(state.seed + 7919)
  local row = wrap(state.ingress_row, state.rows)
  local col = wrap(state.ingress_col, state.cols)
  local layer = 1
  local accepted = 0
  for index = 1, math.max(1, state.events) do
    if midi.chance(state.density) then
      accepted = accepted + 1
      local pitch, channel, velocity, note_len, degree = translate_cell(row, col, layer, accepted)
      preview[#preview + 1] = {
        row = row,
        col = col,
        layer = layer,
        pitch = pitch,
        channel = midi.clamp(channel, 0, math.min(15, state.channels - 1)),
        velocity = velocity,
        note_len = note_len,
        degree = degree,
      }
    end
    row, col, layer = step_position(row, col, layer, index)
  end
end

local function draw_lattice()
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  local h = 360
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, COLORS.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, COLORS.edge)
  ImGui.DrawList_AddText(draw_list, x + 12, y + 10, COLORS.dim, "GESTURE TEMPLATE TABLE")

  local table_w = math.min(w * 0.66, h * 1.05)
  local table_h = h - 68
  local cell = math.floor(math.min(table_w / state.cols, table_h / state.rows))
  cell = math.max(15, math.min(36, cell))
  local grid_w = cell * state.cols
  local grid_h = cell * state.rows
  local gx = x + 24
  local gy = y + 44

  for layer = state.layers, 1, -1 do
    local off = (layer - 1) * 5
    ImGui.DrawList_AddRect(draw_list, gx + off, gy - off, gx + grid_w + off, gy + grid_h - off,
      layer == 1 and COLORS.grid or COLORS.muted)
  end

  for row = 1, state.rows do
    for col = 1, state.cols do
      local v = cell_value(row, col, 1)
      local cx1 = gx + (col - 1) * cell
      local cy1 = gy + (row - 1) * cell
      local shade = 0.08 + v * 0.13
      ImGui.DrawList_AddRectFilled(draw_list, cx1, cy1, cx1 + cell - 1, cy1 + cell - 1,
        color(shade, shade + 0.012, shade + 0.014, 1))
      ImGui.DrawList_AddRect(draw_list, cx1, cy1, cx1 + cell, cy1 + cell, COLORS.grid)
    end
  end

  local last_x, last_y = nil, nil
  for index, event in ipairs(preview) do
    local px = gx + (event.col - 0.5) * cell
    local py = gy + (event.row - 0.5) * cell
    if last_x then ImGui.DrawList_AddLine(draw_list, last_x, last_y, px, py, COLORS.line, 1.4) end
    local radius = 3 + (event.velocity / 127) * 3
    ImGui.DrawList_AddCircleFilled(draw_list, px, py, radius, COLORS.hit)
    if index == 1 then ImGui.DrawList_AddText(draw_list, px + 7, py - 8, COLORS.ingress, "in") end
    if index == #preview then ImGui.DrawList_AddText(draw_list, px + 7, py - 8, COLORS.egress, "out") end
    last_x, last_y = px, py
  end

  local in_x = gx + (state.ingress_col - 0.5) * cell
  local in_y = gy + (state.ingress_row - 0.5) * cell
  local out_x = gx + (state.egress_col - 0.5) * cell
  local out_y = gy + (state.egress_row - 0.5) * cell
  ImGui.DrawList_AddCircle(draw_list, in_x, in_y, 9, COLORS.ingress, 16, 2)
  ImGui.DrawList_AddCircle(draw_list, out_x, out_y, 9, COLORS.egress, 16, 2)

  local strip_x = gx + grid_w + 46
  local strip_y = y + 50
  local strip_w = math.max(110, w - (strip_x - x) - 20)
  ImGui.DrawList_AddText(draw_list, strip_x, y + 10, COLORS.dim, "TRANSLATION LAYERS")
  for layer = 1, state.layers do
    local ly = strip_y + (layer - 1) * 32
    ImGui.DrawList_AddText(draw_list, strip_x, ly - 7, COLORS.dim, "L" .. tostring(layer))
    ImGui.DrawList_AddRect(draw_list, strip_x + 28, ly - 8, strip_x + strip_w, ly + 8, COLORS.grid)
    for step = 1, 16 do
      local sx = strip_x + 30 + (strip_w - 34) * ((step - 1) / 15)
      local value = cell_value(((step - 1) % state.rows) + 1, ((step + layer - 2) % state.cols) + 1, layer)
      local sy = ly + lerp(6, -6, value)
      ImGui.DrawList_AddCircleFilled(draw_list, sx, sy, 2.2, layer == 1 and COLORS.line or COLORS.hit)
    end
  end
  ImGui.DrawList_AddText(draw_list, strip_x, y + h - 40, COLORS.dim,
    tostring(#preview) .. " events  /  " .. TEMPLATES[state.template])
  ImGui.DrawList_AddText(draw_list, strip_x, y + h - 22, COLORS.dim,
    "ingress " .. state.ingress_row .. "," .. state.ingress_col ..
    "  egress " .. state.egress_row .. "," .. state.egress_col)

  ImGui.SetCursorScreenPos(ctx, x, y + h + 12)
end

local function generate_item()
  local track = midi.ensure_track()
  if not track then midi.show_error("Could not find or create a track.", TITLE) return end
  local default_beats = LENGTH_BEATS[state.length] > 0 and LENGTH_BEATS[state.length] or 16
  local start_qn, end_qn = midi.time_selection_or_cursor_qn(default_beats)
  if LENGTH_BEATS[state.length] > 0 then end_qn = start_qn + LENGTH_BEATS[state.length] end
  local item, take = midi.create_midi_item(track, start_qn, end_qn, "Lattice MIDI")
  if not take then midi.show_error("Could not create MIDI item.", TITLE) return end

  generate_preview()
  local total_beats = math.max(0.25, end_qn - start_qn)
  local step_beats = total_beats / math.max(1, state.events)
  local event_index = 0
  for _, event in ipairs(preview) do
    event_index = event_index + 1
    local note_start = start_qn + (event_index - 1) * step_beats
    local note_end = note_start + step_beats * event.note_len
    midi.insert_note_qn(take, note_start, note_end, event.channel, event.pitch, event.velocity)
  end
  reaper.MIDI_Sort(take)
  reaper.UpdateArrange()
  status = "Wrote " .. tostring(#preview) .. " lattice events to a new MIDI item."
end

generate_preview()

local function loop()
  ImGui.SetNextWindowSize(ctx, 900, 790, ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    draw_lattice()
    local changed = false
    local c

    c, state.root = combo("Root", ROOTS, state.root, 90); changed = changed or c
    ImGui.SameLine(ctx)
    c, state.scale = combo("Scale", SCALES, state.scale, 170); changed = changed or c
    ImGui.SameLine(ctx)
    c, state.length = combo("Length", LENGTHS, state.length, 150); changed = changed or c

    c, state.template = combo("Gesture template", TEMPLATES, state.template, 190); changed = changed or c
    ImGui.SameLine(ctx)
    c, state.layer_rule = combo("Layer translation", LAYER_RULES, state.layer_rule, 220); changed = changed or c

    ImGui.Separator(ctx)
    c, state.rows = ImGui.SliderInt(ctx, "Rows", state.rows, 3, 12); changed = changed or c
    c, state.cols = ImGui.SliderInt(ctx, "Columns", state.cols, 3, 12); changed = changed or c
    c, state.layers = ImGui.SliderInt(ctx, "Layers", state.layers, 1, 8); changed = changed or c
    c, state.events = ImGui.SliderInt(ctx, "Events", state.events, 4, 256); changed = changed or c
    state.ingress_row = math.min(state.ingress_row, state.rows)
    state.ingress_col = math.min(state.ingress_col, state.cols)
    state.egress_row = math.min(state.egress_row, state.rows)
    state.egress_col = math.min(state.egress_col, state.cols)

    ImGui.Separator(ctx)
    c, state.ingress_row = ImGui.SliderInt(ctx, "Ingress row", state.ingress_row, 1, state.rows); changed = changed or c
    c, state.ingress_col = ImGui.SliderInt(ctx, "Ingress column", state.ingress_col, 1, state.cols); changed = changed or c
    c, state.egress_row = ImGui.SliderInt(ctx, "Egress row", state.egress_row, 1, state.rows); changed = changed or c
    c, state.egress_col = ImGui.SliderInt(ctx, "Egress column", state.egress_col, 1, state.cols); changed = changed or c

    ImGui.Separator(ctx)
    c, state.density = ImGui.SliderDouble(ctx, "Density", state.density, 0, 1, "%.3f"); changed = changed or c
    c, state.mutation = ImGui.SliderDouble(ctx, "Gesture mutation", state.mutation, 0, 1, "%.3f"); changed = changed or c
    c, state.octave = ImGui.SliderInt(ctx, "Base octave", state.octave, 0, 8); changed = changed or c
    c, state.span = ImGui.SliderInt(ctx, "Register span", state.span, 1, 6); changed = changed or c
    c, state.note_len = ImGui.SliderDouble(ctx, "Note length scale", state.note_len, 0.05, 1.5, "%.2f"); changed = changed or c
    c, state.velocity = ImGui.SliderInt(ctx, "Base velocity", state.velocity, 1, 127); changed = changed or c
    c, state.accent = ImGui.SliderInt(ctx, "Accent", state.accent, 0, 48); changed = changed or c
    c, state.channels = ImGui.SliderInt(ctx, "MIDI channels / source lanes", state.channels, 1, 16); changed = changed or c
    c, state.seed = ImGui.InputInt(ctx, "Seed", state.seed); changed = changed or c

    if changed then generate_preview() end

    if ImGui.Button(ctx, "Generate MIDI Item", 160, 30) then generate_item() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Refresh Preview", 130, 30) then generate_preview() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "New Seed", 100, 30) then
      state.seed = state.seed + 1
      generate_preview()
    end
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, COLORS.dim, status)
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
