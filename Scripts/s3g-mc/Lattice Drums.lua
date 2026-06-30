-- @description Lattice Drums
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; MIDI Rule Library.lua
-- @category MIDI Composition
-- @render No
-- @method Creates an editable MIDI drum item from a table-scanning gesture model. Each lattice layer is assigned to a drum voice, and visible cells are translated into velocity, duration, and density using either a Superior-style or GM drum map.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local midi = dofile(script_dir .. "MIDI Rule Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Lattice Drums", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "Lattice Drums"
local ctx = ImGui.CreateContext(TITLE)
local open = true
local status = ""

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
local LAYER_RULES = { "Velocity / duration / density", "Density / velocity / duration", "Duration / density / velocity", "Velocity / density / accent" }
local DRUM_TOKENS = { "KIK", "SNR", "CHH", "OHH", "PHH", "RIM", "LT", "MT", "HT", "FT", "CR1", "RD1" }
local DRUM_TOKEN_ITEMS = table.concat(DRUM_TOKENS, "\0") .. "\0"
local MAP_NAMES = { "Superior-style", "GM" }
local MAP_ITEMS = table.concat(MAP_NAMES, "\0") .. "\0"
local PRESET_NAMES = {
  "Manual",
  "Tight Linear Groove",
  "Broken Funk Line",
  "Tom Contour",
  "Playable Erratic",
  "Hat / Snare Braid",
  "Sparse Kick Thread",
  "Orbiting Kit",
}
local PRESET_ITEMS = table.concat(PRESET_NAMES, "\0") .. "\0"

local DRUM_MAPS = {
  ["GM"] = {
    KIK = 36, SNR = 38, RIM = 37, CHH = 42, PHH = 44, OHH = 46,
    LT = 45, MT = 47, HT = 50, FT = 41, CR1 = 49, RD1 = 51,
  },
  ["Superior-style"] = {
    KIK = 36, SNR = 38, RIM = 37, CHH = 61, PHH = 21, OHH = 46,
    LT = 41, MT = 45, HT = 48, FT = 43, CR1 = 49, RD1 = 51,
  },
}

local state = {
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
  note_len = 0.35,
  velocity = 76,
  accent = 26,
  velocity_jitter = 7,
  map = 1,
  midi_channel = 10,
  seed = 11,
  preset = 1,
}

local layer_tokens = { "KIK", "SNR", "CHH", "OHH", "PHH", "RIM", "LT", "MT" }

local preview = {}
local table_cache = {}
local generate_preview
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

local function index_of(list, name, fallback)
  for index, value in ipairs(list) do
    if value == name then return index end
  end
  return fallback or 1
end

local function map_name()
  return MAP_NAMES[state.map] or "Superior-style"
end

local function drum_pitch(token)
  local map = DRUM_MAPS[map_name()] or DRUM_MAPS["Superior-style"]
  return map[token] or 36
end

local function layer_token(layer)
  local index = ((math.max(1, math.floor(layer or 1)) - 1) % #layer_tokens) + 1
  return layer_tokens[index] or DRUM_TOKENS[index] or "KIK"
end

local function apply_preset(name)
  if name == "Manual" then return end
  local presets = {
    ["Tight Linear Groove"] = {
      template = "Row snake",
      rule = "Velocity / duration / density",
      rows = 7, cols = 7, layers = 4, events = 64,
      ingress = { 2, 2 }, egress = { 6, 6 },
      density = 0.78, mutation = 0.08, note_len = 0.28,
      velocity = 82, accent = 22, jitter = 5,
      tokens = { "KIK", "SNR", "CHH", "OHH" },
    },
    ["Broken Funk Line"] = {
      template = "Braid",
      rule = "Velocity / density / accent",
      rows = 7, cols = 8, layers = 5, events = 72,
      ingress = { 2, 2 }, egress = { 6, 7 },
      density = 0.72, mutation = 0.22, note_len = 0.24,
      velocity = 84, accent = 30, jitter = 9,
      tokens = { "KIK", "SNR", "CHH", "RIM", "OHH" },
    },
    ["Tom Contour"] = {
      template = "Diagonal climb",
      rule = "Duration / density / velocity",
      rows = 8, cols = 8, layers = 6, events = 56,
      ingress = { 7, 2 }, egress = { 2, 7 },
      density = 0.68, mutation = 0.12, note_len = 0.40,
      velocity = 86, accent = 24, jitter = 6,
      tokens = { "KIK", "SNR", "LT", "MT", "HT", "FT" },
    },
    ["Playable Erratic"] = {
      template = "Knight walk",
      rule = "Density / velocity / duration",
      rows = 7, cols = 7, layers = 4, events = 56,
      ingress = { 2, 2 }, egress = { 6, 6 },
      density = 0.58, mutation = 0.18, note_len = 0.22,
      velocity = 80, accent = 18, jitter = 12,
      tokens = { "KIK", "SNR", "CHH", "RIM" },
    },
    ["Hat / Snare Braid"] = {
      template = "Column snake",
      rule = "Velocity / density / accent",
      rows = 6, cols = 9, layers = 4, events = 80,
      ingress = { 1, 2 }, egress = { 6, 8 },
      density = 0.82, mutation = 0.10, note_len = 0.18,
      velocity = 74, accent = 20, jitter = 8,
      tokens = { "CHH", "SNR", "PHH", "OHH" },
    },
    ["Sparse Kick Thread"] = {
      template = "Attractor",
      rule = "Density / velocity / duration",
      rows = 7, cols = 7, layers = 3, events = 48,
      ingress = { 2, 2 }, egress = { 6, 5 },
      density = 0.45, mutation = 0.05, note_len = 0.34,
      velocity = 88, accent = 32, jitter = 4,
      tokens = { "KIK", "CHH", "SNR" },
    },
    ["Orbiting Kit"] = {
      template = "Box orbit",
      rule = "Velocity / duration / density",
      rows = 7, cols = 7, layers = 6, events = 72,
      ingress = { 1, 1 }, egress = { 7, 7 },
      density = 0.70, mutation = 0.16, note_len = 0.30,
      velocity = 78, accent = 22, jitter = 7,
      tokens = { "KIK", "SNR", "CHH", "RIM", "LT", "OHH" },
    },
  }
  local preset = presets[name]
  if not preset then return end
  state.template = index_of(TEMPLATES, preset.template, state.template)
  state.layer_rule = index_of(LAYER_RULES, preset.rule, state.layer_rule)
  state.rows = preset.rows or state.rows
  state.cols = preset.cols or state.cols
  state.layers = preset.layers or state.layers
  state.events = preset.events or state.events
  state.ingress_row = preset.ingress and preset.ingress[1] or state.ingress_row
  state.ingress_col = preset.ingress and preset.ingress[2] or state.ingress_col
  state.egress_row = preset.egress and preset.egress[1] or state.egress_row
  state.egress_col = preset.egress and preset.egress[2] or state.egress_col
  state.density = preset.density or state.density
  state.mutation = preset.mutation or state.mutation
  state.note_len = preset.note_len or state.note_len
  state.velocity = preset.velocity or state.velocity
  state.accent = preset.accent or state.accent
  state.velocity_jitter = preset.jitter or state.velocity_jitter
  if preset.tokens then
    for index, token in ipairs(preset.tokens) do layer_tokens[index] = token end
  end
  status = "Applied preset: " .. name
  generate_preview()
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
  local active_event = nil
  local active_index = nil
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
  local vel_v, dur_v, dens_v, accent_v = a, b, c, (a + b + c) / 3
  if rule == "Density / velocity / duration" then
    dens_v, vel_v, dur_v, accent_v = a, b, c, (a * 0.35 + c * 0.65)
  elseif rule == "Duration / density / velocity" then
    dur_v, dens_v, vel_v, accent_v = a, b, c, (b * 0.5 + c * 0.5)
  elseif rule == "Velocity / density / accent" then
    vel_v, dens_v, accent_v, dur_v = a, b, c, (a * 0.35 + b * 0.65)
  end

  local token = layer_token(layer)
  local velocity = midi.velocity(state.velocity + vel_v * 22, state.accent * accent_v, event_index, 5, state.velocity_jitter)
  local note_len = lerp(0.12, 1.05, dur_v) * state.note_len
  local density = midi.clamp((state.density * 0.45) + (dens_v * state.density * 0.70), 0, 1)
  return token, drum_pitch(token), velocity, note_len, density
end

function generate_preview()
  build_table()
  preview = {}
  midi.seed(state.seed + 7919)
  local row = wrap(state.ingress_row, state.rows)
  local col = wrap(state.ingress_col, state.cols)
  local layer = 1
  local accepted = 0
  for index = 1, math.max(1, state.events) do
    local token, pitch, velocity, note_len, cell_density = translate_cell(row, col, layer, accepted + 1)
    if midi.chance(cell_density) then
      accepted = accepted + 1
      preview[#preview + 1] = {
        scan_index = index,
        row = row,
        col = col,
        layer = layer,
        token = token,
        pitch = pitch,
        velocity = velocity,
        note_len = note_len,
        density = cell_density,
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
    ImGui.DrawList_AddText(draw_list, gx + off_x + grid_w + 6, gy + off_y - 8, layer_color(layer),
      "L" .. tostring(layer) .. " " .. layer_token(layer))
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
    if index == active_index then
      ImGui.DrawList_AddCircleFilled(draw_list, px, py, radius + 5.0, COLORS.panel)
      ImGui.DrawList_AddCircleFilled(draw_list, px, py, radius + 2.6, event_col)
      ImGui.DrawList_AddCircle(draw_list, px, py, radius + 6.4, COLORS.text, 24, 1.5)
    end
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
    ImGui.DrawList_AddText(draw_list, strip_x, ly - 7, layer_color(layer), "L" .. tostring(layer) .. " " .. layer_token(layer))
    ImGui.DrawList_AddRect(draw_list, strip_x + 28, ly - 8, strip_x + strip_w, ly + 8, layer_tint(layer, 0.34))
    for step = 1, 16 do
      local sx = strip_x + 30 + (strip_w - 34) * ((step - 1) / 15)
      local value = cell_value(((step - 1) % state.rows) + 1, ((step + layer - 2) % state.cols) + 1, layer)
      local sy = ly + lerp(6, -6, value)
      ImGui.DrawList_AddCircleFilled(draw_list, sx, sy, 2.4, layer_color(layer))
    end
  end
  local active_text = active_event and
    string.format("event %d  %s  note %d  L%d %d,%d",
      active_index,
      active_event.token or "KIK",
      active_event.pitch or 36,
      active_event.layer,
      active_event.row,
      active_event.col) or
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
  local item, take = midi.create_midi_item(track, start_qn, end_qn, "Lattice Drums")
  if not take then midi.show_error("Could not create MIDI item.", TITLE) return end

  generate_preview()
  local total_beats = math.max(0.25, end_qn - start_qn)
  local step_beats = total_beats / math.max(1, state.events)
  local note_channel = midi.clamp((state.midi_channel or 10) - 1, 0, 15)
  for event_index, event in ipairs(preview) do
    local scan_index = event.scan_index or event_index
    local note_start = start_qn + (scan_index - 1) * step_beats
    local note_end = note_start + step_beats * event.note_len
    midi.insert_note_qn(take, note_start, note_end, note_channel, event.pitch, event.velocity)
  end
  reaper.MIDI_Sort(take)
  reaper.UpdateArrange()
  status = string.format("Wrote %d %s drum events on ch %d.", #preview, map_name(), state.midi_channel)
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

  ImGui.SetNextWindowSize(ctx, 900, 760, ImGui.Cond_Appearing)
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

      if ImGui.CollapsingHeader(ctx, "Gesture", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        local preset_zero = state.preset - 1
        ImGui.SetNextItemWidth(ctx, 190)
        c, preset_zero = ImGui.Combo(ctx, "Linear preset", preset_zero, PRESET_ITEMS)
        if c then state.preset = preset_zero + 1 end
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Apply Preset", 108, 24) then
          apply_preset(PRESET_NAMES[state.preset] or "Manual")
          changed = false
        end
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
        ImGui.Separator(ctx)
        ImGui.Text(ctx, "Layer drum voices")
        for layer = 1, state.layers do
          ImGui.PushID(ctx, layer)
          ImGui.TextColored(ctx, layer_color(layer), string.format("L%d", layer))
          ImGui.SameLine(ctx)
          local token_index = 0
          for index, token in ipairs(DRUM_TOKENS) do
            if token == layer_token(layer) then token_index = index - 1 break end
          end
          ImGui.SetNextItemWidth(ctx, 140)
          c, token_index = ImGui.Combo(ctx, "Drum", token_index, DRUM_TOKEN_ITEMS)
          if c then
            layer_tokens[layer] = DRUM_TOKENS[token_index + 1] or "KIK"
            changed = true
          end
          if layer % 2 == 1 and layer < state.layers then ImGui.SameLine(ctx) end
          ImGui.PopID(ctx)
        end
      end

      if ImGui.CollapsingHeader(ctx, "Output", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        c, state.density = ImGui.SliderDouble(ctx, "Density", state.density, 0, 1, "%.3f"); changed = changed or c
        c, state.mutation = ImGui.SliderDouble(ctx, "Gesture mutation", state.mutation, 0, 1, "%.3f"); changed = changed or c
        c, state.note_len = ImGui.SliderDouble(ctx, "Note length scale", state.note_len, 0.05, 1.5, "%.2f"); changed = changed or c
        c, state.velocity = ImGui.SliderInt(ctx, "Base velocity", state.velocity, 1, 127); changed = changed or c
        c, state.accent = ImGui.SliderInt(ctx, "Accent", state.accent, 0, 48); changed = changed or c
        c, state.velocity_jitter = ImGui.SliderInt(ctx, "Velocity jitter", state.velocity_jitter, 0, 48); changed = changed or c
        local map_zero = state.map - 1
        ImGui.SetNextItemWidth(ctx, 150)
        c, map_zero = ImGui.Combo(ctx, "Drum map", map_zero, MAP_ITEMS); changed = changed or c
        if c then state.map = map_zero + 1 end
        c, state.midi_channel = ImGui.SliderInt(ctx, "MIDI channel", state.midi_channel, 1, 16); changed = changed or c
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
