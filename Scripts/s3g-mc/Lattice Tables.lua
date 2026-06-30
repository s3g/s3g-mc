-- @description Lattice Tables
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
  reaper.MB("ReaImGui is not installed or not loaded.", "Lattice Tables", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "Lattice Tables"
local ctx = ImGui.CreateContext(TITLE)
local open = true
local status = ""

local ROOTS = midi.ROOT_NAMES
local SCALES = midi.SCALE_NAMES
local LENGTHS = { "Use time selection", "1 bar", "2 bars", "4 bars", "8 bars", "16 bars" }
local LENGTH_BEATS = { 0, 4, 8, 16, 32, 64 }
local TEMPLATES = {
  "Circulating",
  "Reverse scan",
  "Column scan",
  "Column snake",
  "Row snake",
  "Diagonal fold",
  "Diagonal climb",
  "Anti-diagonal",
  "Spiral",
  "Box orbit",
  "Center orbit",
  "Pendulum",
  "Knight walk",
  "Cross address",
  "Egress pull",
  "Attractor",
  "Repel center",
  "Random walk",
  "Drunken diagonal",
  "Braid",
  "Layer bounce",
  "Layer skip",
  "Star jump",
  "Corner bounce",
}
local LAYER_RULES = { "Pitch / velocity / channel", "Pitch / duration / channel", "Channel / pitch / velocity", "Velocity / channel / pitch" }
local CHANNEL_MODES = { "Table channels", "Single channel" }
local VOICINGS = { "Mono", "Dyad", "Triad", "Quartal", "Cluster" }

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
  note_len_variation = 0.20,
  voicing = 1,
  voicing_variation = 0.0,
  velocity = 76,
  accent = 26,
  channels = 8,
  channel_mode = 1,
  single_channel = 1,
  seed = 11,
}

local preview = {}
local table_cache = {}
local preview_t = 0.0
local preview_play = false
local preview_sync_project_bpm = true
local preview_speed = 1.0
local preview_loop_seconds = 8.0
local last_time = reaper.time_precise()

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

local LAYER_COLORS = {
  color(1.00, 0.78, 0.18, 1),
  color(0.08, 0.78, 0.92, 1),
  color(0.96, 0.22, 0.34, 1),
  color(0.26, 0.86, 0.36, 1),
  color(0.70, 0.42, 1.00, 1),
  color(1.00, 0.45, 0.08, 1),
  color(0.24, 0.48, 1.00, 1),
  color(0.90, 0.92, 0.22, 1),
}

local LAYER_RGBA = {
  { 1.00, 0.78, 0.18 },
  { 0.08, 0.78, 0.92 },
  { 0.96, 0.22, 0.34 },
  { 0.26, 0.86, 0.36 },
  { 0.70, 0.42, 1.00 },
  { 1.00, 0.45, 0.08 },
  { 0.24, 0.48, 1.00 },
  { 0.90, 0.92, 0.22 },
}

local function layer_color(layer)
  return LAYER_COLORS[((math.max(1, math.floor(layer or 1)) - 1) % #LAYER_COLORS) + 1]
end

local function layer_tint(layer, alpha, scale)
  local rgb = LAYER_RGBA[((math.max(1, math.floor(layer or 1)) - 1) % #LAYER_RGBA) + 1]
  scale = scale or 1
  return color(rgb[1] * scale, rgb[2] * scale, rgb[3] * scale, alpha or 1)
end

local function combo(label, labels, value, width)
  ImGui.SetNextItemWidth(ctx, width or 160)
  local changed, next_value = ImGui.Combo(ctx, label, value - 1, table.concat(labels, "\0") .. "\0")
  return changed, next_value + 1
end

local NOTE_NAMES = { "C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B" }

local function note_name(pitch)
  pitch = midi.clamp(math.floor(tonumber(pitch) or 60), 0, 127)
  return (NOTE_NAMES[(pitch % 12) + 1] or "C") .. tostring(math.floor(pitch / 12) - 1)
end

local function current_start_qn()
  local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if end_time > start_time then return reaper.TimeMap2_timeToQN(0, start_time) end
  return reaper.TimeMap2_timeToQN(0, reaper.GetCursorPosition())
end

local function tempo_at_qn(qn)
  local time = reaper.TimeMap2_QNToTime(0, qn)
  local bpm = reaper.TimeMap2_GetDividedBpmAtTime and reaper.TimeMap2_GetDividedBpmAtTime(0, time)
  return bpm or reaper.Master_GetTempo()
end

local function current_preview_event()
  if #preview == 0 then return nil end
  local play_index = math.floor(preview_t * math.max(1, state.events - 1)) + 1
  local active_event = preview[1]
  local active_index = 1
  for index, event in ipairs(preview) do
    if (event.scan_index or index) <= play_index then
      active_event = event
      active_index = index
    else
      break
    end
  end
  return active_event, active_index
end

local function template_uses_egress()
  local template = TEMPLATES[state.template]
  return template == "Cross address" or template == "Egress pull"
end

local function wrap(value, count)
  return ((math.floor(value) - 1) % math.max(1, count)) + 1
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function sign_to(target, value)
  if target > value then return 1 end
  if target < value then return -1 end
  return 0
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

local function varied_note_len(base_len, event_index, layer)
  local variation = midi.clamp(state.note_len_variation or 0, 0, 1)
  local scale = 1.0
  if variation > 0 then
    local table_wave = math.sin((event_index or 1) * 0.47 + (layer or 1) * 1.13) * variation * 0.28
    local jitter = (math.random() * 2 - 1) * variation
    scale = 1.0 + table_wave + jitter
  end
  return midi.clamp((base_len or 0.55) * scale, 0.04, 2.8)
end

local function output_channel(chan_v)
  if CHANNEL_MODES[state.channel_mode] == "Single channel" then
    return math.max(0, math.min(15, (state.single_channel or 1) - 1))
  end
  return math.floor((chan_v or 0) * math.max(0, state.channels - 1) + 0.5)
end

local function choose_from(list)
  return list[math.floor(math.random() * #list) + 1]
end

local function voicing_offsets()
  local mode = VOICINGS[state.voicing] or "Mono"
  local offsets
  if mode == "Dyad" then offsets = { 0, 4 }
  elseif mode == "Triad" then offsets = { 0, 2, 4 }
  elseif mode == "Quartal" then offsets = { 0, 3, 6 }
  elseif mode == "Cluster" then offsets = { 0, 1, 2, 4 }
  else offsets = { 0 } end

  local variation = midi.clamp(state.voicing_variation or 0, 0, 1)
  if variation <= 0 or #offsets <= 1 then return offsets end

  local out = { offsets[1] }
  for i = 2, #offsets do
    if math.random() > variation * 0.55 then out[#out + 1] = offsets[i] end
  end
  if math.random() < variation * 0.45 then
    out[#out + 1] = choose_from({ -2, 5, 7, 9 })
  end
  if #out > 1 and math.random() < variation * 0.35 then
    out[1] = out[1] + choose_from({ -7, -5, 5, 7 })
  end
  table.sort(out)
  return out
end

local function step_position(row, col, layer, index)
  local template = TEMPLATES[state.template]
  local center_row = (state.rows + 1) * 0.5
  local center_col = (state.cols + 1) * 0.5
  if template == "Reverse scan" then
    col = col - 1
    if col < 1 then
      col = state.cols
      row = row - 1
    end
  elseif template == "Column scan" then
    row = row + 1
    if row > state.rows then
      row = 1
      col = col + 1
    end
  elseif template == "Column snake" then
    row = row + ((col % 2 == 1) and 1 or -1)
    if row > state.rows then row = state.rows; col = col + 1 end
    if row < 1 then row = 1; col = col + 1 end
  elseif template == "Row snake" then
    col = col + ((row % 2 == 1) and 1 or -1)
    if col > state.cols then col = state.cols; row = row + 1 end
    if col < 1 then col = 1; row = row + 1 end
  elseif template == "Diagonal fold" then
    row = row + 1
    col = col + ((index % 2 == 0) and -1 or 1)
  elseif template == "Diagonal climb" then
    row = row - 1
    col = col + 1
    if row < 1 then row = state.rows end
  elseif template == "Anti-diagonal" then
    row = row + 1
    col = col - 1
  elseif template == "Spiral" then
    local phase = index % 4
    if phase == 0 then col = col + 1
    elseif phase == 1 then row = row + 1
    elseif phase == 2 then col = col - 1
    else row = row - 1 end
  elseif template == "Box orbit" then
    local top = 1
    local bottom = state.rows
    local left = 1
    local right = state.cols
    if row <= top and col < right then col = col + 1
    elseif col >= right and row < bottom then row = row + 1
    elseif row >= bottom and col > left then col = col - 1
    else row = row - 1 end
  elseif template == "Center orbit" then
    local phase = index % 8
    local moves = { { -1, 0 }, { -1, 1 }, { 0, 1 }, { 1, 1 }, { 1, 0 }, { 1, -1 }, { 0, -1 }, { -1, -1 } }
    row = math.floor(center_row + moves[phase + 1][1] * math.max(1, math.floor(state.rows * 0.32)) + 0.5)
    col = math.floor(center_col + moves[phase + 1][2] * math.max(1, math.floor(state.cols * 0.32)) + 0.5)
  elseif template == "Pendulum" then
    col = col + ((math.floor(index / math.max(1, state.cols)) % 2 == 0) and 1 or -1)
    row = math.floor(center_row + math.sin(index * 0.65) * (state.rows - 1) * 0.45 + 0.5)
  elseif template == "Knight walk" then
    local moves = { { 2, 1 }, { 1, 2 }, { -1, 2 }, { -2, 1 }, { -2, -1 }, { -1, -2 }, { 1, -2 }, { 2, -1 } }
    local move = moves[(index % #moves) + 1]
    row = row + move[1]
    col = col + move[2]
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
  elseif template == "Attractor" then
    row = row + sign_to(state.egress_row, row)
    col = col + sign_to(state.egress_col, col)
    if math.abs(state.egress_row - row) <= 1 and math.abs(state.egress_col - col) <= 1 then
      row = row + math.floor(math.random() * 3) - 1
      col = col + math.floor(math.random() * 3) - 1
    end
  elseif template == "Repel center" then
    row = row + sign_to(row, center_row)
    col = col + sign_to(col, center_col)
  elseif template == "Random walk" then
    row = row + math.floor(math.random() * 3) - 1
    col = col + math.floor(math.random() * 3) - 1
  elseif template == "Drunken diagonal" then
    row = row + 1 + math.floor(math.random() * 3) - 1
    col = col + 1 + math.floor(math.random() * 3) - 1
  elseif template == "Braid" then
    row = row + ((index % 2 == 0) and 1 or -1)
    col = col + ((index % 3 == 0) and 2 or 1)
  elseif template == "Layer bounce" then
    col = col + 1
    row = row + ((layer % 2 == 1) and 1 or -1)
    layer = layer + ((math.floor(index / 2) % 2 == 0) and 1 or -1)
  elseif template == "Layer skip" then
    col = col + 1
    row = row + ((index % 3) - 1)
    layer = layer + 2
  elseif template == "Star jump" then
    local points = {
      { 1, 1 }, { state.rows, state.cols }, { 1, state.cols }, { state.rows, 1 },
      { math.floor(center_row + 0.5), math.floor(center_col + 0.5) },
    }
    local point = points[(index % #points) + 1]
    row, col = point[1], point[2]
  elseif template == "Corner bounce" then
    local corners = { { 1, 1 }, { 1, state.cols }, { state.rows, state.cols }, { state.rows, 1 } }
    local point = corners[(math.floor(index / 2) % #corners) + 1]
    row = row + sign_to(point[1], row)
    col = col + sign_to(point[2], col)
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
  local channel = output_channel(chan_v)
  local velocity = midi.velocity(state.velocity + vel_v * 18, state.accent, event_index, 5, 5)
  local note_len = varied_note_len(lerp(0.16, 1.25, dur_v) * state.note_len, event_index, layer)
  return degree, channel, velocity, note_len
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
      local degree, channel, velocity, note_len = translate_cell(row, col, layer, accepted)
      local voices = {}
      for voice, offset in ipairs(voicing_offsets()) do
        local voice_degree = degree + offset
        voices[#voices + 1] = {
          voice = voice,
          degree = voice_degree,
          pitch = midi.scale_pitch(ROOTS[state.root], SCALES[state.scale], voice_degree, state.octave, state.span),
          velocity = midi.clamp(velocity - (voice - 1) * 7, 1, 127),
          note_len = midi.clamp(note_len * (1.0 - math.min(0.28, (voice - 1) * 0.08)), 0.04, 2.8),
        }
      end
      preview[#preview + 1] = {
        scan_index = index,
        row = row,
        col = col,
        layer = layer,
        pitch = voices[1] and voices[1].pitch or 60,
        channel = midi.clamp(channel, 0, 15),
        velocity = velocity,
        note_len = note_len,
        degree = degree,
        voices = voices,
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
  local active_event, active_index = current_preview_event()

  local table_w = math.min(w * 0.66, h * 1.05)
  local depth_x = math.max(5, math.min(10, 66 / math.max(1, state.layers)))
  local depth_y = -math.max(4, math.min(7, 48 / math.max(1, state.layers)))
  local depth_total_x = (state.layers - 1) * depth_x
  local depth_total_y = (state.layers - 1) * math.abs(depth_y)
  local table_h = h - 82 - depth_total_y
  local cell = math.floor(math.min(table_w / state.cols, table_h / state.rows))
  cell = math.max(15, math.min(36, cell))
  local grid_w = cell * state.cols
  local grid_h = cell * state.rows
  local gx = x + 24
  local gy = y + 52 + depth_total_y

  local function layer_offset(layer)
    local z = math.max(0, (layer or 1) - 1)
    return z * depth_x, z * depth_y
  end

  for layer = state.layers, 1, -1 do
    local off_x, off_y = layer_offset(layer)
    local layer_alpha = layer == 1 and 0.32 or 0.16
    local outline_col = layer_tint(layer, layer == 1 and 0.68 or 0.38)
    for row = 1, state.rows do
      for col = 1, state.cols do
        local v = cell_value(row, col, layer)
        local cx1 = gx + off_x + (col - 1) * cell
        local cy1 = gy + off_y + (row - 1) * cell
        local shade = 0.11 + v * 0.16
        ImGui.DrawList_AddRectFilled(draw_list, cx1, cy1, cx1 + cell - 1, cy1 + cell - 1,
          layer_tint(layer, layer_alpha, shade))
        ImGui.DrawList_AddRect(draw_list, cx1, cy1, cx1 + cell, cy1 + cell,
          layer_tint(layer, layer == 1 and 0.22 or 0.12))
      end
    end
    ImGui.DrawList_AddRect(draw_list, gx + off_x, gy + off_y, gx + grid_w + off_x, gy + grid_h + off_y,
      outline_col)
    ImGui.DrawList_AddText(draw_list, gx + off_x + grid_w + 6, gy + off_y - 8, layer_color(layer), "L" .. tostring(layer))
  end

  local last_x, last_y = nil, nil
  local last_layer = nil
  for index, event in ipairs(preview) do
    local off_x, off_y = layer_offset(event.layer)
    local px = gx + off_x + (event.col - 0.5) * cell
    local py = gy + off_y + (event.row - 0.5) * cell
    local event_col = layer_color(event.layer)
    if last_x then
      ImGui.DrawList_AddLine(draw_list, last_x, last_y, px, py,
        last_layer == event.layer and event_col or color(0.76, 0.80, 0.78, 0.58), 1.4)
    end
    local radius = 3 + (event.velocity / 127) * 3
    ImGui.DrawList_AddCircleFilled(draw_list, px + 1.3, py + 1.3, radius + 1.2, color(0, 0, 0, 0.38))
    ImGui.DrawList_AddCircleFilled(draw_list, px, py, radius, event_col)
    if event.voices and #event.voices > 1 then
      for voice = 2, math.min(#event.voices, 5) do
        local angle = -math.pi * 0.5 + (voice - 2) * (math.pi * 2 / math.max(1, #event.voices - 1))
        local vx = px + math.cos(angle) * (radius + 5)
        local vy = py + math.sin(angle) * (radius + 5)
        ImGui.DrawList_AddCircleFilled(draw_list, vx, vy, 2.2, COLORS.text)
      end
    end
    if index == active_index then
      ImGui.DrawList_AddCircleFilled(draw_list, px, py, radius + 5.0, COLORS.panel)
      ImGui.DrawList_AddCircleFilled(draw_list, px, py, radius + 2.6, event_col)
      ImGui.DrawList_AddCircle(draw_list, px, py, radius + 6.4, COLORS.text, 24, 1.5)
    end
    ImGui.DrawList_AddLine(draw_list, px, py + radius + 4, px + math.min(cell * 2.2, cell * (event.note_len or 1)), py + radius + 4,
      color(0.95, 0.74, 0.28, 0.38), 2.0)
    if index == 1 then ImGui.DrawList_AddText(draw_list, px + 7, py - 8, COLORS.ingress, "in") end
    if index == #preview then ImGui.DrawList_AddText(draw_list, px + 7, py - 8, COLORS.egress, "out") end
    last_x, last_y = px, py
    last_layer = event.layer
  end

  local in_x = gx + (state.ingress_col - 0.5) * cell
  local in_y = gy + (state.ingress_row - 0.5) * cell
  local out_x = gx + (state.egress_col - 0.5) * cell
  local out_y = gy + (state.egress_row - 0.5) * cell
  local egress_active = template_uses_egress()
  ImGui.DrawList_AddCircle(draw_list, in_x, in_y, 9, COLORS.ingress, 16, 2)
  ImGui.DrawList_AddText(draw_list, in_x + 8, in_y + 6, COLORS.ingress, "ingress")
  ImGui.DrawList_AddCircle(draw_list, out_x, out_y, 9, egress_active and COLORS.egress or COLORS.muted, 16, 2)
  ImGui.DrawList_AddText(draw_list, out_x + 8, out_y + 6, egress_active and COLORS.egress or COLORS.dim, "egress")

  local strip_x = gx + grid_w + depth_total_x + 58
  local strip_y = y + 50
  local strip_w = math.max(110, w - (strip_x - x) - 20)
  ImGui.DrawList_AddText(draw_list, strip_x, y + 10, COLORS.dim, "TRANSLATION LAYERS")
  for layer = 1, state.layers do
    local ly = strip_y + (layer - 1) * 32
    ImGui.DrawList_AddText(draw_list, strip_x, ly - 7, layer_color(layer), "L" .. tostring(layer))
    ImGui.DrawList_AddRect(draw_list, strip_x + 28, ly - 8, strip_x + strip_w, ly + 8, layer_tint(layer, 0.34))
    for step = 1, 16 do
      local sx = strip_x + 30 + (strip_w - 34) * ((step - 1) / 15)
      local value = cell_value(((step - 1) % state.rows) + 1, ((step + layer - 2) % state.cols) + 1, layer)
      local sy = ly + lerp(6, -6, value)
      ImGui.DrawList_AddCircleFilled(draw_list, sx, sy, 2.4, layer_color(layer))
    end
  end
  local active_text = active_event and
    string.format("event %d  %s  ch %d  voices %d  L%d %d,%d  len %.2fx",
      active_index,
      note_name(active_event.pitch),
      active_event.channel + 1,
      #(active_event.voices or { 1 }),
      active_event.layer,
      active_event.row,
      active_event.col,
      active_event.note_len or 1) or
    "no events"
  ImGui.DrawList_AddText(draw_list, strip_x, y + h - 58, COLORS.dim,
    tostring(#preview) .. " events  /  " .. TEMPLATES[state.template])
  ImGui.DrawList_AddText(draw_list, strip_x, y + h - 40, COLORS.text, active_text)
  ImGui.DrawList_AddText(draw_list, strip_x, y + h - 22, COLORS.dim,
    "ingress " .. state.ingress_row .. "," .. state.ingress_col ..
    "  egress " .. state.egress_row .. "," .. state.egress_col)

  local tx = x + 18
  local ty = y + h - 10
  local tw = w - 36
  ImGui.DrawList_AddLine(draw_list, tx, ty, tx + tw, ty, color(0.55, 0.60, 0.58, 0.32), 1)
  ImGui.DrawList_AddRectFilled(draw_list, tx, ty - 3, tx + tw, ty + 3, color(0.18, 0.42, 0.42, 0.22))
  ImGui.DrawList_AddCircleFilled(draw_list, tx + tw * preview_t, ty, 3.4, COLORS.hit)

  ImGui.SetCursorScreenPos(ctx, x, y + h + 12)
end

local function draw_preview_controls()
  local changed
  changed, preview_t = ImGui.SliderDouble(ctx, "Timeline preview", preview_t, 0, 1, "%.3f")
  if ImGui.Button(ctx, preview_play and "Stop Preview" or "Play Preview", 130, 26) then
    preview_play = not preview_play
    last_time = reaper.time_precise()
  end
  ImGui.SameLine(ctx)
  changed, preview_sync_project_bpm = ImGui.Checkbox(ctx, "Project BPM", preview_sync_project_bpm)
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, 120)
  changed, preview_speed = ImGui.SliderDouble(ctx, "Preview speed", preview_speed, 0.125, 4.0, "%.3fx")
  if not preview_sync_project_bpm then
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 112)
    changed, preview_loop_seconds = ImGui.SliderDouble(ctx, "Loop seconds", preview_loop_seconds, 1.0, 30.0, "%.1f")
  else
    local start_qn = current_start_qn()
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, COLORS.dim, string.format("%.1f BPM", tempo_at_qn(start_qn)))
  end
end

local function generate_item()
  local track = midi.ensure_track()
  if not track then midi.show_error("Could not find or create a track.", TITLE) return end
  local default_beats = LENGTH_BEATS[state.length] > 0 and LENGTH_BEATS[state.length] or 16
  local start_qn, end_qn = midi.time_selection_or_cursor_qn(default_beats)
  if LENGTH_BEATS[state.length] > 0 then end_qn = start_qn + LENGTH_BEATS[state.length] end
  local item, take = midi.create_midi_item(track, start_qn, end_qn, "Lattice Tables")
  if not take then midi.show_error("Could not create MIDI item.", TITLE) return end

  generate_preview()
  local total_beats = math.max(0.25, end_qn - start_qn)
  local step_beats = total_beats / math.max(1, state.events)
  local note_count = 0
  for event_index, event in ipairs(preview) do
    local scan_index = event.scan_index or event_index
    local note_start = start_qn + (scan_index - 1) * step_beats
    for _, voice in ipairs(event.voices or {}) do
      local note_end = note_start + step_beats * (voice.note_len or event.note_len or 1)
      note_end = math.min(end_qn, math.max(note_start + 0.0001, note_end))
      midi.insert_note_qn(take, note_start, note_end, event.channel, voice.pitch or event.pitch, voice.velocity or event.velocity)
      note_count = note_count + 1
    end
  end
  reaper.MIDI_Sort(take)
  reaper.UpdateArrange()
  status = "Wrote " .. tostring(note_count) .. " notes from " .. tostring(#preview) .. " lattice events."
end

generate_preview()

local function draw_footer()
  ImGui.Separator(ctx)
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

local function loop()
  local now = reaper.time_precise()
  if preview_play then
    local dt = now - last_time
    if preview_sync_project_bpm then
      local start_qn = current_start_qn()
      local bpm = tempo_at_qn(start_qn + preview_t * math.max(0.25, LENGTH_BEATS[state.length] > 0 and LENGTH_BEATS[state.length] or 16))
      local beat_delta = dt * (bpm / 60.0) * preview_speed
      preview_t = (preview_t + beat_delta / math.max(0.25, state.events)) % 1.0
    else
      preview_t = (preview_t + dt * preview_speed / math.max(0.1, preview_loop_seconds)) % 1.0
    end
  end
  last_time = now

  ImGui.SetNextWindowSize(ctx, 900, 790, ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local footer_height = 52
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    local content_height = math.max(220, avail_h - footer_height)
    local child_visible = ImGui.BeginChild(ctx, "##main_content", 0, content_height)
    if child_visible then
      draw_lattice()
      draw_preview_controls()
      local changed = false
      local c

      if ImGui.CollapsingHeader(ctx, "Pitch / Gesture", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        c, state.root = combo("Root", ROOTS, state.root, 90); changed = changed or c
        ImGui.SameLine(ctx)
        c, state.scale = combo("Scale", SCALES, state.scale, 170); changed = changed or c
        ImGui.SameLine(ctx)
        c, state.length = combo("Length", LENGTHS, state.length, 150); changed = changed or c
        c, state.template = combo("Gesture template", TEMPLATES, state.template, 190); changed = changed or c
        ImGui.SameLine(ctx)
        c, state.layer_rule = combo("Layer translation", LAYER_RULES, state.layer_rule, 220); changed = changed or c
      end

      if ImGui.CollapsingHeader(ctx, "Table", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        c, state.rows = ImGui.SliderInt(ctx, "Rows", state.rows, 3, 12); changed = changed or c
        c, state.cols = ImGui.SliderInt(ctx, "Columns", state.cols, 3, 12); changed = changed or c
        c, state.layers = ImGui.SliderInt(ctx, "Layers", state.layers, 1, 8); changed = changed or c
        c, state.events = ImGui.SliderInt(ctx, "Events", state.events, 4, 256); changed = changed or c
        state.ingress_row = math.min(state.ingress_row, state.rows)
        state.ingress_col = math.min(state.ingress_col, state.cols)
        state.egress_row = math.min(state.egress_row, state.rows)
        state.egress_col = math.min(state.egress_col, state.cols)
        c, state.ingress_row = ImGui.SliderInt(ctx, "Ingress row", state.ingress_row, 1, state.rows); changed = changed or c
        c, state.ingress_col = ImGui.SliderInt(ctx, "Ingress column", state.ingress_col, 1, state.cols); changed = changed or c
        c, state.egress_row = ImGui.SliderInt(ctx, "Egress row", state.egress_row, 1, state.rows); changed = changed or c
        c, state.egress_col = ImGui.SliderInt(ctx, "Egress column", state.egress_col, 1, state.cols); changed = changed or c
      end

      if ImGui.CollapsingHeader(ctx, "Output", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        c, state.density = ImGui.SliderDouble(ctx, "Density", state.density, 0, 1, "%.3f"); changed = changed or c
        c, state.mutation = ImGui.SliderDouble(ctx, "Gesture mutation", state.mutation, 0, 1, "%.3f"); changed = changed or c
        c, state.octave = ImGui.SliderInt(ctx, "Base octave", state.octave, 0, 8); changed = changed or c
        c, state.span = ImGui.SliderInt(ctx, "Register span", state.span, 1, 6); changed = changed or c
        c, state.note_len = ImGui.SliderDouble(ctx, "Note length scale", state.note_len, 0.05, 1.5, "%.2f"); changed = changed or c
        c, state.note_len_variation = ImGui.SliderDouble(ctx, "Note length variation", state.note_len_variation, 0, 1, "%.3f"); changed = changed or c
        c, state.voicing = combo("Voicing", VOICINGS, state.voicing, 140); changed = changed or c
        c, state.voicing_variation = ImGui.SliderDouble(ctx, "Voicing variation", state.voicing_variation, 0, 1, "%.3f"); changed = changed or c
        c, state.velocity = ImGui.SliderInt(ctx, "Base velocity", state.velocity, 1, 127); changed = changed or c
        c, state.accent = ImGui.SliderInt(ctx, "Accent", state.accent, 0, 48); changed = changed or c
        c, state.channel_mode = combo("MIDI channel mode", CHANNEL_MODES, state.channel_mode, 170); changed = changed or c
        if CHANNEL_MODES[state.channel_mode] == "Single channel" then
          c, state.single_channel = ImGui.SliderInt(ctx, "MIDI channel", state.single_channel, 1, 16); changed = changed or c
        else
          c, state.channels = ImGui.SliderInt(ctx, "MIDI channels / source lanes", state.channels, 1, 16); changed = changed or c
        end
        c, state.seed = ImGui.InputInt(ctx, "Seed", state.seed); changed = changed or c
      end

      if changed then generate_preview() end
    end
    ImGui.EndChild(ctx)
    draw_footer()
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
