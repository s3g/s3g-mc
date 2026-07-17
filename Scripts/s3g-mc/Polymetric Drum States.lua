-- @description Polymetric Drum States
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; MIDI Rule Library.lua
-- @category MIDI Composition
-- @render No
-- @method Creates an editable MIDI drum item from polymetric drum states. Each state stores Euclidean lane settings for a Superior-style or GM drum map, with either hard state changes or smooth interpolation between configurations.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local midi = dofile(script_dir .. "MIDI Rule Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Polymetric Drum States", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local ui_theme = nil
do
  local _s3g_theme_path = ({ reaper.get_action_context() })[2]
  if not _s3g_theme_path or _s3g_theme_path == "" then
    _s3g_theme_path = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
  end
  local _s3g_theme_dir = _s3g_theme_path:match("^(.*[/\\])") or ""
  package.path = _s3g_theme_dir .. "?.lua;" .. package.path
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme and _s3g_theme.install then _s3g_theme.install(ImGui); ui_theme = _s3g_theme end
end


local TITLE = "Polymetric Drum States"
local ctx = ImGui.CreateContext(TITLE)
local open = true
local status = ""

local DRUM_TOKENS = { "KIK", "SNR", "CHH", "OHH", "PHH", "RIM", "LT", "MT", "HT", "FT", "CR1", "RD1" }
local DRUM_TOKEN_ITEMS = table.concat(DRUM_TOKENS, "\0") .. "\0"
local MAP_NAMES = { "Superior-style", "GM" }
local MAP_ITEMS = table.concat(MAP_NAMES, "\0") .. "\0"
local MAX_STATES = 16
local TRANSITION_NAMES = { "Jump", "Glide" }
local TRANSITION_ITEMS = table.concat(TRANSITION_NAMES, "\0") .. "\0"
local DURATION_NAMES = { "Trigger", "Step fraction" }
local DURATION_ITEMS = table.concat(DURATION_NAMES, "\0") .. "\0"
local GRID_NAMES = { "1/64", "1/32", "1/16", "1/8", "1/4", "1/2", "1 beat", "2 beats", "4 beats" }
local GRID_VALUES = { 1 / 16, 1 / 8, 1 / 4, 1 / 2, 1, 2, 4, 8, 16 }
local GRID_ITEMS = table.concat(GRID_NAMES, "\0") .. "\0"
local EUCLIDEAN_PRESETS = {
  { name = "Manual", pulses = nil, steps = nil, rotate = nil },
  { name = "Tresillo E(3,8)", pulses = 3, steps = 8, rotate = 0 },
  { name = "Cinquillo E(5,8)", pulses = 5, steps = 8, rotate = 0 },
  { name = "Take Five E(2,5)", pulses = 2, steps = 5, rotate = 0 },
  { name = "Ruchenitza E(3,7)", pulses = 3, steps = 7, rotate = 0 },
  { name = "Aksak E(4,9)", pulses = 4, steps = 9, rotate = 0 },
  { name = "Fandango E(4,12)", pulses = 4, steps = 12, rotate = 0 },
  { name = "West African Bell E(7,12)", pulses = 7, steps = 12, rotate = 0 },
  { name = "Bossa E(5,16)", pulses = 5, steps = 16, rotate = 0 },
  { name = "Samba E(7,16)", pulses = 7, steps = 16, rotate = 0 },
  { name = "Sparse Marker E(1,16)", pulses = 1, steps = 16, rotate = 0 },
}
local EUCLIDEAN_PRESET_NAMES = {}
for index, preset in ipairs(EUCLIDEAN_PRESETS) do EUCLIDEAN_PRESET_NAMES[index] = preset.name end
local EUCLIDEAN_PRESET_ITEMS = table.concat(EUCLIDEAN_PRESET_NAMES, "\0") .. "\0"

local BANK_NAMES = { "No bank", "Tresillo Engine", "Bell Web", "Aksak Machine", "Bossa / Samba Cross", "Sparse Polymeter" }
local BANK_ITEMS = table.concat(BANK_NAMES, "\0") .. "\0"

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

local CANVAS = {}

local function rgba(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

CANVAS.bg = rgba(0.045, 0.050, 0.055, 1)
CANVAS.panel = rgba(0.070, 0.076, 0.082, 1)
CANVAS.edge = rgba(0.22, 0.24, 0.25, 0.42)
CANVAS.grid = rgba(0.55, 0.60, 0.58, 0.20)
CANVAS.dim = rgba(0.50, 0.55, 0.55, 1)
CANVAS.text = rgba(0.58, 0.62, 0.62, 1)
CANVAS.hot = rgba(1.00, 0.78, 0.22, 1)
CANVAS.state = rgba(0.22, 0.74, 0.72, 1)
CANVAS.play = rgba(1.00, 0.38, 0.28, 1)
CANVAS.playhead = rgba(1.00, 1.00, 1.00, 1)

local LANE_PALETTE = {
  rgba(1.00, 0.74, 0.20, 1),
  rgba(0.12, 0.78, 0.94, 1),
  rgba(0.90, 0.26, 0.36, 1),
  rgba(0.30, 0.84, 0.38, 1),
  rgba(0.72, 0.48, 1.00, 1),
  rgba(1.00, 0.48, 0.12, 1),
  rgba(0.42, 0.58, 1.00, 1),
  rgba(0.86, 0.90, 0.28, 1),
  rgba(0.98, 0.52, 0.72, 1),
  rgba(0.42, 0.86, 0.72, 1),
  rgba(0.84, 0.62, 0.36, 1),
  rgba(0.62, 0.76, 0.96, 1),
}

local LANE_BG_PALETTE = {
  rgba(0.20, 0.17, 0.10, 0.52),
  rgba(0.08, 0.16, 0.18, 0.52),
  rgba(0.18, 0.09, 0.10, 0.52),
  rgba(0.08, 0.17, 0.10, 0.52),
  rgba(0.15, 0.11, 0.19, 0.52),
  rgba(0.19, 0.12, 0.08, 0.52),
  rgba(0.10, 0.12, 0.20, 0.52),
  rgba(0.17, 0.18, 0.09, 0.52),
  rgba(0.19, 0.11, 0.14, 0.52),
  rgba(0.09, 0.17, 0.14, 0.52),
  rgba(0.17, 0.13, 0.09, 0.52),
  rgba(0.12, 0.15, 0.19, 0.52),
}

local lane_count = 8
local map_index = 1
local midi_channel = 10
local seed = 1
local duration_mode = 1
local trigger_len_beats = 0.05
local step_note_len = 0.35
local global_density = 1.0
local min_lane_spacing = 0.0
local min_same_pitch_spacing = 0.0
local max_notes = 8000
local snap_to_grid = true
local grid_index = 3
local integer_state_lengths = true
local velocity_jitter = 7
local swing = 0.0
local transition_index = 1
local selected_state = 1
local bank_index = 1
local preview_t = 0.0
local preview_play = false
local preview_sync_project_bpm = true
local preview_speed = 1.0
local preview_loop_seconds = 8.0
local last_time = reaper.time_precise()
local states = {}
local state_lengths = {}
local lane_tokens = { "KIK", "SNR", "CHH", "OHH", "PHH", "RIM", "LT", "MT", "HT", "FT", "CR1", "RD1" }
local lane_enabled = {}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function grid_beats()
  return GRID_VALUES[grid_index] or 0.25
end

local function snap_beats(value, min_value, max_value)
  if not snap_to_grid then return value end
  local grid = math.max(0.0001, grid_beats())
  local snapped = math.floor((value / grid) + 0.5) * grid
  return clamp(snapped, min_value or grid, max_value or snapped)
end

local function slider_beats(label, value, min_value, max_value, format)
  local changed
  changed, value = ui_theme.slider_double(ImGui, ctx, label, value, min_value, max_value, format or "%.3f")
  if changed then value = snap_beats(value, min_value, max_value) end
  return changed, value
end

local function state_length_value(value)
  value = snap_beats(value, 1, 128)
  if integer_state_lengths then value = math.floor(value + 0.5) end
  return clamp(value, 1, 128)
end

local function lane_color(index)
  return LANE_PALETTE[((index - 1) % #LANE_PALETTE) + 1]
end

local function lane_bg_color(index)
  return LANE_BG_PALETTE[((index - 1) % #LANE_BG_PALETTE) + 1]
end

local function muted_text(value)
  ui_theme.muted(ImGui, ctx, value)
end

local SLIDER_ABBR = {
  ["Timeline preview"] = "TIME",
  ["Preview speed"] = "SPEED",
  ["Loop seconds"] = "LOOP",
  ["MIDI channel"] = "MIDI",
  ["Trigger length beats"] = "TRIG",
  ["Step fraction length"] = "STEP",
  ["Global probability trim"] = "PROB",
  ["Min lane spacing beats"] = "LANE GAP",
  ["Min same-drum spacing beats"] = "DRUM GAP",
  ["Max generated notes"] = "MAX",
  ["Velocity jitter"] = "VJIT",
  ["Selected state length beats"] = "STATE",
  ["Hit probability"] = "PROB",
  ["Steps"] = "STEP",
  ["Pulses"] = "PULS",
  ["Rotate"] = "ROT",
  ["Velocity"] = "VELO",
  ["Accent"] = "ACNT",
  ["Drum map"] = "MAP",
  ["Note duration mode"] = "DUR",
  ["Grid"] = "GRID",
  ["Transition mode"] = "MODE",
  ["State preset bank"] = "BANK",
  ["Drum"] = "DRUM",
  ["Preset"] = "PSET",
  ["Pattern"] = "PTRN",
  ["Beats"] = "BEATS",
  ["Seed"] = "SEED",
}

local MAX_SLIDER_LABEL_CHARS = 8

local function clamp_slider_label(value)
  value = tostring(value or ""):upper():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if #value <= MAX_SLIDER_LABEL_CHARS then return value end
  local compact = value:gsub("[AEIOU]", "")
  if #compact <= MAX_SLIDER_LABEL_CHARS then return compact end
  return compact:sub(1, MAX_SLIDER_LABEL_CHARS)
end

local function slider_label(label)
  return clamp_slider_label(SLIDER_ABBR[label] or label)
end

local function display_slider_value(value, format, integer)
  if integer then return tostring(math.floor(value + 0.5)) end
  if format and format ~= "" then return string.format(format, value) end
  return string.format("%.3f", value)
end

local function custom_slider_row(label, value, min_value, max_value, format, integer)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local avail = ImGui.GetContentRegionAvail(ctx)
  if type(avail) ~= "number" or avail < 280 then
    if integer then return ui_theme.slider_int(ImGui, ctx, label, math.floor(value + 0.5), min_value, max_value) end
    return ui_theme.slider_double(ImGui, ctx, label, value, min_value, max_value, format or "%.3f")
  end

  local h = 22
  local label_w = 82
  local value_w = 76
  local track_x = x + label_w
  local track_w = math.max(52, avail - label_w - value_w - 8)
  local value_x = track_x + track_w + 8
  local track_y = y + 6
  local track_h = 8
  local norm = 0
  if max_value ~= min_value then norm = clamp((value - min_value) / (max_value - min_value), 0, 1) end

  ImGui.InvisibleButton(ctx, "##custom_slider_" .. label, avail, h)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local changed = false
  if (hovered or active) and ImGui.IsMouseDown(ctx, 0) then
    local mx = ImGui.GetMousePos(ctx)
    local new_norm = clamp((mx - track_x) / track_w, 0, 1)
    local new_value = min_value + (max_value - min_value) * new_norm
    if integer then new_value = math.floor(new_value + 0.5) end
    if math.abs(new_value - value) > (integer and 0 or 0.0000001) then
      value = new_value
      changed = true
      norm = new_norm
    end
  end

  local draw = ImGui.GetWindowDrawList(ctx)
  local label_col = rgba(0.66, 0.66, 0.66, 1.0)
  local value_col = rgba(0.57, 0.57, 0.57, 1.0)
  local track_col = active and rgba(0.070, 0.072, 0.074, 1.0) or rgba(0.044, 0.046, 0.048, 1.0)
  local fill_col = active and rgba(0.58, 0.59, 0.58, 1.0) or rgba(0.40, 0.41, 0.41, 1.0)
  local handle_col = active and rgba(0.78, 0.78, 0.76, 1.0) or rgba(0.62, 0.63, 0.62, 1.0)
  ImGui.DrawList_AddText(draw, x, y + 2, label_col, slider_label(label))
  ImGui.DrawList_AddRectFilled(draw, track_x, track_y, track_x + track_w, track_y + track_h, track_col)
  ImGui.DrawList_AddRectFilled(draw, track_x + 1, track_y + 1, track_x + math.max(2, track_w * norm), track_y + track_h - 1, fill_col)
  local hx = clamp(track_x + track_w * norm - 1.5, track_x + 1, track_x + track_w - 4)
  ImGui.DrawList_AddRectFilled(draw, hx, track_y - 2, hx + 3, track_y + track_h + 2, handle_col)
  ImGui.DrawList_AddText(draw, value_x, y + 2, value_col, display_slider_value(value, format, integer))
  return changed, value
end

local function custom_slider_beats(label, value, min_value, max_value, format)
  local changed
  changed, value = custom_slider_row(label, value, min_value, max_value, format or "%.3f", false)
  if changed then value = snap_beats(value, min_value, max_value) end
  return changed, value
end

local function custom_combo_row(label, index, items, width)
  if ui_theme and ui_theme.combo_row then
    local labels = {}
    for item in tostring(items or ""):gmatch("([^\0]+)") do labels[#labels + 1] = item end
    local changed, next_index = ui_theme.combo_row(ImGui, ctx, label, labels, index + 1, width)
    return changed, next_index - 1
  end
  width = width or 126
  local function text_width(text)
    if ImGui.CalcTextSize then
      local ok, w = pcall(ImGui.CalcTextSize, ctx, tostring(text or ""))
      if ok and type(w) == "number" then return w end
    end
    return #tostring(text or "") * 7
  end
  local labels = {}
  for item in tostring(items or ""):gmatch("([^\0]+)") do labels[#labels + 1] = item end
  local combo_w = text_width(labels[index + 1] or "") + 38
  for _, item in ipairs(labels) do combo_w = math.max(combo_w, text_width(item) + 38) end
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 2, rgba(0.66, 0.66, 0.66, 1.0), slider_label(label))
  ImGui.SetCursorScreenPos(ctx, x + 82, y)
  ImGui.SetNextItemWidth(ctx, math.max(74, math.min(width, combo_w)))
  local changed
  changed, index = ImGui.Combo(ctx, "##combo_" .. label, index, items)
  ImGui.SetCursorScreenPos(ctx, x, y + 22)
  ImGui.Dummy(ctx, 1, 1)
  return changed, index
end

local function custom_combo_action_row(label, index, items, width, button_label, button_width)
  if ui_theme and ui_theme.combo_action_row then
    local labels = {}
    for item in tostring(items or ""):gmatch("([^\0]+)") do labels[#labels + 1] = item end
    local changed, next_index, pressed = ui_theme.combo_action_row(ImGui, ctx, label, labels, index + 1, width, button_label, button_width)
    return changed, next_index - 1, pressed
  end
  width = width or 126
  button_width = button_width or 62
  local function text_width(text)
    if ImGui.CalcTextSize then
      local ok, w = pcall(ImGui.CalcTextSize, ctx, tostring(text or ""))
      if ok and type(w) == "number" then return w end
    end
    return #tostring(text or "") * 7
  end
  local labels = {}
  for item in tostring(items or ""):gmatch("([^\0]+)") do labels[#labels + 1] = item end
  local combo_w = text_width(labels[index + 1] or "") + 38
  for _, item in ipairs(labels) do combo_w = math.max(combo_w, text_width(item) + 38) end
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 2, rgba(0.66, 0.66, 0.66, 1.0), slider_label(label))
  ImGui.SetCursorScreenPos(ctx, x + 82, y)
  ImGui.SetNextItemWidth(ctx, math.max(74, math.min(width, combo_w)))
  local changed
  changed, index = ImGui.Combo(ctx, "##combo_" .. label, index, items)
  ImGui.SameLine(ctx)
  local pressed = ImGui.Button(ctx, button_label, button_width, 22)
  ImGui.SetCursorScreenPos(ctx, x, y + 24)
  ImGui.Dummy(ctx, 1, 1)
  return changed, index, pressed
end

local function custom_mini_combo(label, index, items, width)
  width = width or 74
  local function text_width(text)
    if ImGui.CalcTextSize then
      local ok, w = pcall(ImGui.CalcTextSize, ctx, tostring(text or ""))
      if ok and type(w) == "number" then return w end
    end
    return #tostring(text or "") * 7
  end
  local labels = {}
  for item in tostring(items or ""):gmatch("([^\0]+)") do labels[#labels + 1] = item end
  local combo_w = text_width(labels[index + 1] or "") + 34
  for _, item in ipairs(labels) do combo_w = math.max(combo_w, text_width(item) + 34) end
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 2, rgba(0.62, 0.62, 0.62, 1.0), slider_label(label))
  ImGui.SetCursorScreenPos(ctx, x + 34, y)
  ImGui.SetNextItemWidth(ctx, math.max(48, math.min(width, combo_w)))
  local changed
  changed, index = ImGui.Combo(ctx, "##combo_" .. label, index, items)
  return changed, index
end

local function toolbox_gap()
  ImGui.Dummy(ctx, 1, 9)
end

local function section_label(text)
  ImGui.Dummy(ctx, 1, 2)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y, rgba(0.43, 0.45, 0.45, 1.0), tostring(text or ""):upper())
  ImGui.Dummy(ctx, 1, 14)
end

local function custom_input_double_row(label, value, step, step_fast, format, width, suffix)
  width = width or 112
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local draw = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddText(draw, x, y + 3, rgba(0.66, 0.66, 0.66, 1.0), slider_label(label))
  if suffix and suffix ~= "" then
    ImGui.DrawList_AddText(draw, x + 42, y + 3, rgba(0.48, 0.50, 0.50, 1.0), suffix)
  end
  local input_x = suffix and suffix ~= "" and x + 162 or x + 82
  ImGui.SetCursorScreenPos(ctx, input_x, y)
  ImGui.SetNextItemWidth(ctx, width)
  local changed
  changed, value = ImGui.InputDouble(ctx, "##input_" .. label, value, step or 0, step_fast or 0, format or "%.2f")
  ImGui.SetCursorScreenPos(ctx, x, y + 22)
  ImGui.Dummy(ctx, 1, 1)
  return changed, value
end

local function custom_input_int_row(label, value, step, step_fast, width)
  if ui_theme and ui_theme.input_int_row then return ui_theme.input_int_row(ImGui, ctx, label, value, step, step_fast, width) end
  width = width or 112
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 3, rgba(0.66, 0.66, 0.66, 1.0), slider_label(label))
  ImGui.SetCursorScreenPos(ctx, x + 82, y)
  ImGui.SetNextItemWidth(ctx, width)
  local changed
  changed, value = ImGui.InputInt(ctx, "##input_" .. label, value, step or 1, step_fast or 10)
  ImGui.SetCursorScreenPos(ctx, x, y + 22)
  ImGui.Dummy(ctx, 1, 1)
  return changed, value
end

local function custom_mini_slider(label, value, min_value, max_value, format, integer, width)
  width = width or 108
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local h = 20
  local label_w = 36
  local value_w = 34
  local track_x = x + label_w
  local track_w = math.max(22, width - label_w - value_w - 4)
  local value_x = track_x + track_w + 4
  local track_y = y + 7
  local track_h = 6
  local norm = max_value ~= min_value and clamp((value - min_value) / (max_value - min_value), 0, 1) or 0
  ImGui.InvisibleButton(ctx, "##custom_mini_slider_" .. label, width, h)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local changed = false
  if (hovered or active) and ImGui.IsMouseDown(ctx, 0) then
    local mx = ImGui.GetMousePos(ctx)
    local new_norm = clamp((mx - track_x) / track_w, 0, 1)
    local new_value = min_value + (max_value - min_value) * new_norm
    if integer then new_value = math.floor(new_value + 0.5) end
    if math.abs(new_value - value) > (integer and 0 or 0.0000001) then
      value = new_value
      changed = true
      norm = new_norm
    end
  end
  local draw = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddText(draw, x, y + 2, rgba(0.62, 0.62, 0.62, 1.0), slider_label(label))
  ImGui.DrawList_AddRectFilled(draw, track_x, track_y, track_x + track_w, track_y + track_h, active and rgba(0.070, 0.072, 0.074, 1.0) or rgba(0.044, 0.046, 0.048, 1.0))
  ImGui.DrawList_AddRectFilled(draw, track_x + 1, track_y + 1, track_x + math.max(2, track_w * norm), track_y + track_h - 1, active and rgba(0.58, 0.59, 0.58, 1.0) or rgba(0.40, 0.41, 0.41, 1.0))
  local hx = clamp(track_x + track_w * norm - 1, track_x + 1, track_x + track_w - 3)
  ImGui.DrawList_AddRectFilled(draw, hx, track_y - 2, hx + 2, track_y + track_h + 2, active and rgba(0.78, 0.78, 0.76, 1.0) or rgba(0.62, 0.63, 0.62, 1.0))
  ImGui.DrawList_AddText(draw, value_x, y + 2, rgba(0.55, 0.55, 0.55, 1.0), display_slider_value(value, format, integer))
  return changed, value
end

local function push_soft_panel_style()
  if ui_theme and ui_theme.push_soft_panel then return ui_theme.push_soft_panel(ImGui, ctx) end
  return nil
end

local function pop_soft_panel_style(stack)
  if ui_theme and ui_theme.pop_soft_panel then ui_theme.pop_soft_panel(ImGui, ctx, stack) end
end

local function draw_lane_row_background(lane)
  if not (ImGui.GetWindowDrawList and ImGui.GetCursorScreenPos and ImGui.GetContentRegionAvail) then return end
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  if type(w) ~= "number" or w <= 0 then return end
  ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), x, y - 1, x + w, y + 74, lane_bg_color(lane))
end

local function lane_row_bg(lane)
  return lane_bg_color(lane)
end

local function toolbox_header(title, flags)
  title = tostring(title or ""):upper()
  local open_state
  if flags then
    open_state = ImGui.CollapsingHeader(ctx, title, nil, flags)
  else
    open_state = ImGui.CollapsingHeader(ctx, title)
  end
  if ImGui.GetItemRectMin and ImGui.GetItemRectMax and ImGui.GetWindowDrawList then
    local x0, y0 = ImGui.GetItemRectMin(ctx)
    local x1 = ImGui.GetItemRectMax(ctx)
    local draw = ImGui.GetWindowDrawList(ctx)
    ImGui.DrawList_AddLine(draw, x0 + 1, y0 + 1, x1 - 1, y0 + 1, rgba(0.88, 0.88, 0.86, 0.58), 1.0)
  end
  ImGui.Dummy(ctx, 1, 3)
  return open_state
end

local function state_name(index)
  if index <= 26 then return string.char(64 + index) end
  return tostring(index)
end

local function total_state_beats()
  local total = 0
  for i = 1, #states do total = total + math.max(0.25, tonumber(state_lengths[i]) or 8) end
  return math.max(0.25, total)
end

local function current_start_qn()
  local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if end_time > start_time then return reaper.TimeMap2_timeToQN(0, start_time), true end
  return reaper.TimeMap2_timeToQN(0, reaper.GetCursorPosition()), false
end

local function tempo_at_qn(qn)
  local time = reaper.TimeMap2_QNToTime(0, qn)
  local bpm = reaper.TimeMap2_GetDividedBpmAtTime and reaper.TimeMap2_GetDividedBpmAtTime(0, time)
  return bpm or reaper.Master_GetTempo()
end

local function make_lane_state(lane, state)
  local base_steps = ({ 16, 15, 13, 12, 11, 10, 9, 7, 14, 17, 19, 21 })[lane] or 16
  local state_pulses = ({
    { 4, 5, 7, 6 },
    { 2, 3, 5, 4 },
    { 11, 9, 13, 7 },
    { 2, 1, 4, 3 },
  })[((lane - 1) % 4) + 1]
  return {
    steps = clamp(base_steps + (state - 1) * ((lane % 3) - 1), 4, 32),
    pulses = clamp(state_pulses[state] or 4, 0, 32),
    rotate = ((lane - 1) * 2 + (state - 1) * (lane % 5)) % 16,
    custom_pattern = nil,
    pattern_input = "",
    density = 1.0,
    velocity = clamp(96 - (lane - 1) * 3 + (state - 1) * 5, 1, 127),
    accent = 18,
  }
end

for state = 1, 4 do
  states[state] = {}
  state_lengths[state] = 16.0
  for lane = 1, 12 do
    states[state][lane] = make_lane_state(lane, state)
  end
end

for lane = 1, 12 do lane_enabled[lane] = lane <= lane_count end

local function map_name()
  return MAP_NAMES[map_index] or "Superior-style"
end

local function drum_pitch(token)
  local map = DRUM_MAPS[map_name()] or DRUM_MAPS["Superior-style"]
  return map[token] or 36
end

local function state_position_at_beat(beat)
  local total = total_state_beats()
  local shifted = beat % total
  local cursor = 0
  local a = #states
  local frac = 0
  for i = 1, #states do
    local span = math.max(0.25, state_lengths[i] or 8)
    if shifted < cursor + span or i == #states then
      a = i
      frac = clamp((shifted - cursor) / span, 0, 1)
      break
    end
    cursor = cursor + span
  end
  local b = (a % #states) + 1
  if transition_index == 1 then
    b = a
    frac = 0
  end
  return a, b, frac
end

local function interpolated_state(lane, beat)
  local a, b, frac = state_position_at_beat(beat)
  local sa = states[a][lane]
  local sb = states[b][lane]
  local custom_source = nil
  if sa.custom_pattern or sb.custom_pattern then custom_source = frac < 0.5 and sa or sb end
  local steps = math.floor(lerp(sa.steps, sb.steps, frac) + 0.5)
  local pulses = math.floor(lerp(sa.pulses, sb.pulses, frac) + 0.5)
  return {
    steps = custom_source and custom_source.steps or clamp(steps, 1, 64),
    pulses = custom_source and custom_source.pulses or clamp(pulses, 0, math.max(1, steps)),
    rotate = custom_source and custom_source.rotate or math.floor(lerp(sa.rotate, sb.rotate, frac) + 0.5),
    custom_pattern = custom_source and custom_source.custom_pattern or nil,
    pattern_input = custom_source and (custom_source.pattern_input or "") or nil,
    density = clamp(lerp(sa.density, sb.density, frac), 0, 1),
    velocity = clamp(math.floor(lerp(sa.velocity, sb.velocity, frac) + 0.5), 1, 127),
    accent = clamp(math.floor(lerp(sa.accent, sb.accent, frac) + 0.5), 0, 64),
  }
end

local function note_duration_beats(step_beats)
  if duration_mode == 1 then
    return math.max(0.005, math.min(trigger_len_beats, step_beats * 0.90))
  end
  return math.max(0.005, step_beats * step_note_len)
end

local function point_on_circle(cx, cy, radius, step, steps)
  local angle = -math.pi * 0.5 + (math.pi * 2 * step / math.max(1, steps))
  return cx + math.cos(angle) * radius, cy + math.sin(angle) * radius
end

local function parse_custom_pattern(text)
  local pattern = {}
  local cleaned = {}
  local pulses = 0
  text = tostring(text or "")
  for char in text:gmatch(".") do
    if char == "x" or char == "X" or char == "1" or char == "*" then
      if #pattern < 64 then
        pattern[#pattern + 1] = true
        cleaned[#cleaned + 1] = "x"
        pulses = pulses + 1
      end
    elseif char == "-" or char == "." or char == "_" or char == "0" then
      if #pattern < 64 then
        pattern[#pattern + 1] = false
        cleaned[#cleaned + 1] = "-"
      end
    end
  end
  if #pattern == 0 then return nil, "", 0 end
  return pattern, table.concat(cleaned), pulses
end

local function pattern_to_text(pattern)
  local out = {}
  for index = 1, #(pattern or {}) do out[index] = pattern[index] and "x" or "-" end
  return table.concat(out)
end

local function rotate_pattern(pattern, rotate)
  local steps = #(pattern or {})
  if steps <= 0 then return nil end
  local out = {}
  rotate = math.floor(rotate or 0)
  for index = 1, steps do
    local shifted = ((index - 1 - rotate) % steps) + 1
    out[index] = pattern[shifted] and true or false
  end
  return out
end

local function pattern_from_state(st)
  if st and st.custom_pattern and st.custom_pattern ~= "" then
    local pattern = parse_custom_pattern(st.custom_pattern)
    if pattern then return rotate_pattern(pattern, st.rotate) end
  end
  return midi.euclidean_pattern(st and st.pulses or 0, st and st.steps or 1, st and st.rotate or 0)
end

local function interval_vector(pattern)
  local hits = {}
  for index, hit in ipairs(pattern) do
    if hit then hits[#hits + 1] = index end
  end
  if #hits == 0 then return "-" end
  if #hits == 1 then return tostring(#pattern) end
  local intervals = {}
  for index = 1, #hits do
    local a = hits[index]
    local b = hits[(index % #hits) + 1]
    if b <= a then b = b + #pattern end
    intervals[#intervals + 1] = tostring(b - a)
  end
  return table.concat(intervals, "-")
end

local function apply_euclidean_preset(st, preset)
  if not st or not preset or not preset.steps then return end
  st.steps = clamp(preset.steps, 1, 64)
  st.pulses = clamp(preset.pulses or 0, 0, st.steps)
  st.rotate = preset.rotate or 0
  st.custom_pattern = nil
  st.pattern_input = ""
end

local function euclidean_preset_index(st)
  if not st then return 0 end
  if st.custom_pattern and st.custom_pattern ~= "" then return 0 end
  local rot = ((st.rotate or 0) % math.max(1, st.steps or 1))
  for index = 2, #EUCLIDEAN_PRESETS do
    local preset = EUCLIDEAN_PRESETS[index]
    if preset.steps == st.steps and preset.pulses == st.pulses then
      local preset_rot = (preset.rotate or 0) % math.max(1, preset.steps or 1)
      if rot == preset_rot then return index - 1 end
    end
  end
  return 0
end

local function set_lane_pattern(st, pulses, steps, rotate)
  if not st then return end
  st.steps = clamp(steps or st.steps or 16, 1, 64)
  st.pulses = clamp(pulses or st.pulses or 0, 0, st.steps)
  st.rotate = rotate or 0
  st.custom_pattern = nil
  st.pattern_input = ""
end

local function apply_custom_pattern(st)
  if not st then return false end
  local pattern, cleaned, pulses = parse_custom_pattern(st.pattern_input or "")
  if not pattern then return false end
  st.custom_pattern = cleaned
  st.pattern_input = cleaned
  st.steps = #pattern
  st.pulses = pulses
  st.rotate = 0
  return true
end

local BANKS = {
  ["Tresillo Engine"] = {
    { "KIK", 3, 8, 0, 0.96, 110 }, { "SNR", 2, 8, 4, 0.95, 100 },
    { "CHH", 7, 16, 0, 0.85, 82 }, { "OHH", 3, 16, 6, 0.70, 78 },
    { "RIM", 5, 16, 2, 0.82, 92 }, { "LT", 2, 7, 0, 0.62, 82 },
    { "MT", 3, 11, 2, 0.58, 82 }, { "CR1", 1, 16, 0, 0.35, 96 },
  },
  ["Bell Web"] = {
    { "KIK", 3, 8, 0, 0.92, 106 }, { "SNR", 5, 12, 4, 0.70, 94 },
    { "CHH", 7, 12, 0, 0.86, 78 }, { "OHH", 4, 12, 3, 0.62, 76 },
    { "RIM", 7, 12, 5, 0.78, 92 }, { "LT", 2, 9, 1, 0.55, 82 },
    { "MT", 3, 10, 2, 0.55, 82 }, { "RD1", 7, 12, 0, 0.82, 88 },
  },
  ["Aksak Machine"] = {
    { "KIK", 4, 9, 0, 0.95, 108 }, { "SNR", 3, 7, 3, 0.78, 100 },
    { "CHH", 5, 9, 1, 0.80, 80 }, { "OHH", 2, 7, 4, 0.55, 78 },
    { "RIM", 3, 11, 2, 0.72, 90 }, { "LT", 4, 13, 3, 0.60, 84 },
    { "MT", 5, 14, 1, 0.56, 84 }, { "HT", 3, 8, 5, 0.50, 86 },
  },
  ["Bossa / Samba Cross"] = {
    { "KIK", 4, 16, 0, 0.94, 108 }, { "SNR", 5, 16, 2, 0.86, 96 },
    { "CHH", 7, 16, 0, 0.88, 78 }, { "OHH", 3, 16, 7, 0.58, 78 },
    { "RIM", 5, 16, 5, 0.82, 92 }, { "LT", 2, 8, 2, 0.50, 82 },
    { "MT", 3, 12, 4, 0.52, 84 }, { "RD1", 7, 16, 3, 0.76, 88 },
  },
  ["Sparse Polymeter"] = {
    { "KIK", 1, 5, 0, 0.82, 106 }, { "SNR", 2, 7, 3, 0.72, 98 },
    { "CHH", 3, 11, 1, 0.76, 78 }, { "OHH", 2, 13, 6, 0.48, 78 },
    { "RIM", 4, 17, 2, 0.68, 90 }, { "LT", 3, 19, 5, 0.54, 82 },
    { "MT", 4, 21, 8, 0.50, 82 }, { "CR1", 1, 16, 12, 0.38, 96 },
  },
}

local function apply_bank(name)
  local bank = BANKS[name]
  if not bank then return end
  lane_count = math.max(lane_count, math.min(8, #bank))
  for lane = 1, math.min(#bank, 12) do
    local data = bank[lane]
    local st = states[selected_state][lane]
    lane_tokens[lane] = data[1]
    set_lane_pattern(st, data[2], data[3], data[4])
    st.density = 1.0
    st.velocity = data[6] or st.velocity
    lane_enabled[lane] = true
  end
  status = "Applied " .. name .. " to state " .. state_name(selected_state) .. "."
end

local function draw_preview()
  local draw = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  local h = 380
  local timeline_h = 46
  local geo_h = h - timeline_h
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + h, CANVAS.bg)
  ImGui.DrawList_AddRect(draw, x, y, x + w, y + h, CANVAS.edge)
  ImGui.DrawList_AddLine(draw, x, y + geo_h, x + w, y + geo_h, CANVAS.edge, 1)

  local ring_w = math.max(300, w - 230)
  local cx = x + ring_w * 0.5
  local cy = y + geo_h * 0.53
  local max_r = math.min(ring_w, geo_h - 58) * 0.48
  local spacing = math.max(9, math.min(22, (max_r - 18) / math.max(1, lane_count)))

  local total_beats = total_state_beats()
  local preview_beat = preview_t * total_beats
  local preview_grid_step = math.floor((preview_beat / math.max(0.0001, grid_beats())) + 0.000001)
  ImGui.DrawList_AddText(draw, x + 12, y + 10, CANVAS.text, "POLYMETRIC DRUM STATES")
  local a, b, frac = state_position_at_beat(preview_beat)
  local state_label = transition_index == 1
    and string.format("state %s   beat %.2f", state_name(a), preview_beat)
    or string.format("%s -> %s   %.2f   beat %.2f", state_name(a), state_name(b), frac, preview_beat)
  ImGui.DrawList_AddText(draw, x + 12, y + 28, CANVAS.dim, state_label)

  for lane = 1, lane_count do
    local state = interpolated_state(lane, preview_beat)
    local radius = max_r - (lane - 1) * spacing
    if radius < 14 then break end
    local col = lane_enabled[lane] and lane_color(lane) or CANVAS.dim
    ImGui.DrawList_AddCircle(draw, cx, cy, radius, lane_enabled[lane] and CANVAS.grid or rgba(0.25, 0.27, 0.27, 0.5), 96, 1)
    local pattern = pattern_from_state(state)
    local hit_points = {}
    for step = 1, state.steps do
      local p1x, p1y = point_on_circle(cx, cy, radius - 3, step - 1, state.steps)
      local p2x, p2y = point_on_circle(cx, cy, radius + 3, step - 1, state.steps)
      ImGui.DrawList_AddLine(draw, p1x, p1y, p2x, p2y, pattern[step] and col or CANVAS.grid, 1)
      if pattern[step] and lane_enabled[lane] then
        local hx, hy = point_on_circle(cx, cy, radius - spacing * 0.42, step - 1, state.steps)
        hit_points[#hit_points + 1] = { x = hx, y = hy }
        ImGui.DrawList_AddCircleFilled(draw, hx, hy, 4.8, col)
      end
    end
    for i = 1, #hit_points do
      local p = hit_points[i]
      local q = hit_points[(i % #hit_points) + 1]
      if q then ImGui.DrawList_AddLine(draw, p.x, p.y, q.x, q.y, col, 1.0) end
    end
    local active_point = nil
    if #hit_points > 0 then
      local passed_hits = 0
      for step = 1, state.steps do
        if pattern[step] and (step - 1) <= (preview_grid_step % math.max(1, state.steps)) then
          passed_hits = passed_hits + 1
        end
      end
      local hit_index = ((math.max(1, passed_hits) - 1) % #hit_points) + 1
      active_point = hit_points[hit_index]
    end
    if active_point then
      ImGui.DrawList_AddCircleFilled(draw, active_point.x, active_point.y, 6.8, CANVAS.bg)
      ImGui.DrawList_AddCircleFilled(draw, active_point.x, active_point.y, 5.0, CANVAS.playhead)
    end
  end

  local lx = x + ring_w + 10
  local ly = y + 26
  for lane = 1, lane_count do
    local state = interpolated_state(lane, preview_beat)
    local col = lane_enabled[lane] and lane_color(lane) or CANVAS.dim
    local yy = ly + (lane - 1) * 22
    ImGui.DrawList_AddRectFilled(draw, lx, yy, lx + 10, yy + 10, col)
    ImGui.DrawList_AddText(draw, lx + 16, yy - 3, col,
      string.format("%02d %s %d/%d", lane, lane_tokens[lane] or "KIK", state.pulses, state.steps))
    ImGui.DrawList_AddText(draw, lx + 112, yy - 3, CANVAS.dim,
      interval_vector(pattern_from_state(state)))
  end

  local tx = x + 18
  local ty = y + geo_h + 17
  local tw = w - 36
  ImGui.DrawList_AddLine(draw, tx, ty, tx + tw, ty, rgba(0.55, 0.60, 0.58, 0.32), 1)
  local cursor = 0
  for state = 1, #states do
    local span = math.max(0.25, state_lengths[state] or 8)
    local x1 = tx + tw * (cursor / total_beats)
    local x2 = tx + tw * ((cursor + span) / total_beats)
    local col = state == selected_state and CANVAS.hot or CANVAS.state
    ImGui.DrawList_AddRectFilled(draw, x1, ty - 4, x2, ty + 4, rgba(0.18, 0.42, 0.42, state == selected_state and 0.52 or 0.22))
    ImGui.DrawList_AddRect(draw, x1, ty - 4, x2, ty + 4, col)
    ImGui.DrawList_AddText(draw, x1 + 4, ty + 8, CANVAS.text, state_name(state))
    cursor = cursor + span
  end
  ImGui.DrawList_AddCircleFilled(draw, tx + tw * preview_t, ty, 3.4, CANVAS.play)

  ImGui.SetCursorScreenPos(ctx, x, y + h + 10)
end

local function copy_state(src, dst)
  for lane = 1, 12 do
    local s = states[src][lane]
    local d = states[dst][lane]
    d.steps = s.steps
    d.pulses = s.pulses
    d.rotate = s.rotate
    d.custom_pattern = s.custom_pattern
    d.pattern_input = s.pattern_input or ""
    d.density = s.density
    d.velocity = s.velocity
    d.accent = s.accent
  end
end

local function clone_state(src)
  local out = {}
  for lane = 1, 12 do
    local s = states[src][lane]
    out[lane] = {
      steps = s.steps,
      pulses = s.pulses,
      rotate = s.rotate,
      custom_pattern = s.custom_pattern,
      pattern_input = s.pattern_input or "",
      density = s.density,
      velocity = s.velocity,
      accent = s.accent,
    }
  end
  return out
end

local function add_state_after(index)
  if #states >= MAX_STATES then
    status = "Maximum state count is " .. tostring(MAX_STATES) .. "."
    return
  end
  index = clamp(index or #states, 1, #states)
  table.insert(states, index + 1, clone_state(index))
  table.insert(state_lengths, index + 1, state_lengths[index] or 16)
  selected_state = index + 1
  preview_t = 0
  status = "Added state " .. state_name(selected_state) .. "."
end

local function delete_state(index)
  if #states <= 1 then
    status = "Keep at least one state."
    return
  end
  index = clamp(index or selected_state, 1, #states)
  table.remove(states, index)
  table.remove(state_lengths, index)
  selected_state = clamp(index, 1, #states)
  preview_t = 0
  status = "Deleted state."
end

local function randomize_state(state)
  for lane = 1, 12 do
    local st = states[state][lane]
    st.steps = clamp(st.steps + math.random(-5, 5), 3, 64)
    st.pulses = clamp(st.pulses + math.random(-3, 3), 0, st.steps)
    st.rotate = math.random(0, math.max(1, st.steps - 1))
    st.density = clamp(st.density + (math.random() * 2 - 1) * 0.22, 0.05, 1.0)
    st.velocity = clamp(st.velocity + math.random(-16, 16), 1, 127)
    st.accent = clamp(st.accent + math.random(-8, 8), 0, 48)
  end
end

local function write_midi()
  midi.seed(seed)
  local track = midi.ensure_track()
  if not track then midi.show_error("Could not find or create a track.", TITLE) return end
  local duration_beats = total_state_beats()
  local start_qn = current_start_qn()
  local end_qn = start_qn + duration_beats
  local item, take = midi.create_midi_item(track, start_qn, end_qn, "Polymetric Drum States")
  if not take then midi.show_error("Could not create MIDI item.", TITLE) return end

  local event_count = 0
  local skipped_count = 0
  local note_channel = clamp(midi_channel - 1, 0, 15)
  local last_lane_note = {}
  local last_pitch_note = {}
  local step_beats = math.max(0.0001, grid_beats())
  for lane = 1, lane_count do
    if lane_enabled[lane] then
      local beat = 0.0
      local guard = 0
      while beat < duration_beats - 0.0001 and guard < 10000 do
        guard = guard + 1
        local state = interpolated_state(lane, beat)
        local pattern = pattern_from_state(state)
        local step = (math.floor((beat / step_beats) + 0.000001) % math.max(1, state.steps)) + 1
        if pattern[step] and midi.chance(state.density * global_density) then
          local note_start = start_qn + beat
          if swing ~= 0 and (step % 2) == 0 then
            note_start = note_start + step_beats * swing * 0.42
          end
          if note_start < end_qn then
            local note_end = math.min(end_qn, note_start + note_duration_beats(step_beats))
            local pitch = drum_pitch(lane_tokens[lane])
            local lane_ok = not last_lane_note[lane] or (note_start - last_lane_note[lane]) >= min_lane_spacing
            local pitch_ok = not last_pitch_note[pitch] or (note_start - last_pitch_note[pitch]) >= min_same_pitch_spacing
            local vel = midi.velocity(state.velocity, state.accent, guard, 4, velocity_jitter)
            if lane_ok and pitch_ok then
              midi.insert_note_qn(take, note_start, note_end, note_channel, pitch, vel)
              last_lane_note[lane] = note_start
              last_pitch_note[pitch] = note_start
              event_count = event_count + 1
            else
              skipped_count = skipped_count + 1
            end
          end
        end
        if event_count >= max_notes then break end
        beat = beat + step_beats
      end
    end
    if event_count >= max_notes then break end
  end
  reaper.MIDI_Sort(take)
  reaper.UpdateItemInProject(item)
  reaper.UpdateArrange()
  status = string.format("Wrote %d %s notes over %.1f beats: %s, ch %d. Skipped %d.",
    event_count,
    DURATION_NAMES[duration_mode]:lower(),
    duration_beats,
    map_name(),
    midi_channel,
    skipped_count)
end

local function draw_global_controls()
  local changed
  local start_qn, using_time_selection = current_start_qn()
  local start_time = reaper.TimeMap2_QNToTime(0, start_qn)
  local start_measures = 0
  local start_beats = 0
  local ok, measures, cml, fullbeats = reaper.TimeMap2_timeToBeats(0, start_time)
  if ok ~= nil then
    start_measures = measures or 0
    start_beats = fullbeats or 0
  else
    start_measures = 0
    start_beats = start_qn
  end
  if toolbox_header("Setup / Output", ImGui.TreeNodeFlags_DefaultOpen) then
    muted_text(string.format(
      "%s  %.2f BPM  QN %.2f  %.1f beats  %d states  M%d B%.2f",
      using_time_selection and "TIME SEL" or "CURSOR",
      tempo_at_qn(start_qn),
      start_qn,
      total_state_beats(),
      #states,
      start_measures + 1,
      start_beats + 1))
    changed, lane_count = custom_slider_row("Lanes", lane_count, 1, 12, nil, true)
    for lane = 1, 12 do
      if lane > lane_count then lane_enabled[lane] = false elseif lane_enabled[lane] == nil then lane_enabled[lane] = true end
    end
    local map_zero = map_index - 1
    changed, map_zero = custom_combo_row("Drum map", map_zero, MAP_ITEMS, 112)
    if changed then map_index = map_zero + 1 end
    changed, midi_channel = custom_slider_row("MIDI channel", midi_channel, 1, 16, nil, true)
    local duration_zero = duration_mode - 1
    changed, duration_zero = custom_combo_row("Note duration mode", duration_zero, DURATION_ITEMS, 116)
    if changed then duration_mode = duration_zero + 1 end
    if duration_mode == 1 then
      changed, trigger_len_beats = custom_slider_beats("Trigger length beats", trigger_len_beats, 0.005, 0.25, "%.3f")
    else
      changed, step_note_len = custom_slider_row("Step fraction length", step_note_len, 0.05, 1.5, "%.2f steps", false)
    end
  end
  toolbox_gap()
  if toolbox_header("Timing / State Movement", ImGui.TreeNodeFlags_DefaultOpen) then
    changed, snap_to_grid = ImGui.Checkbox(ctx, "SNAP BEAT SLIDERS", snap_to_grid)
    local grid_zero = grid_index - 1
    changed, grid_zero = custom_combo_row("Grid", grid_zero, GRID_ITEMS, 92)
    if changed then grid_index = grid_zero + 1 end
    local transition_zero = transition_index - 1
    changed, transition_zero = custom_combo_row("Transition mode", transition_zero, TRANSITION_ITEMS, 104)
    if changed then transition_index = transition_zero + 1 end
    changed, integer_state_lengths = ImGui.Checkbox(ctx, "INTEGER STATE LENGTHS", integer_state_lengths)
    if changed and integer_state_lengths then
      for i = 1, #state_lengths do state_lengths[i] = state_length_value(state_lengths[i] or 16) end
    end
  end
  toolbox_gap()
  if toolbox_header("Advanced generation limits") then
    changed, global_density = custom_slider_row("Global probability trim", global_density, 0.05, 1.0, "%.3f", false)
    changed, min_lane_spacing = custom_slider_beats("Min lane spacing beats", min_lane_spacing, 0, 0.5, "%.4f")
    changed, min_same_pitch_spacing = custom_slider_beats("Min same-drum spacing beats", min_same_pitch_spacing, 0, 0.5, "%.4f")
    changed, max_notes = custom_slider_row("Max generated notes", max_notes, 64, 8000, nil, true)
    changed, swing = custom_slider_row("Swing", swing, -1.0, 1.0, "%.2f", false)
    changed, velocity_jitter = custom_slider_row("Velocity jitter", velocity_jitter, 0, 32, nil, true)
    changed, seed = custom_input_int_row("Seed", seed, 1, 10, 112)
  end
end

local function draw_preview_controls()
  local changed
  changed, preview_t = custom_slider_row("Timeline preview", preview_t, 0, 1, "%.3f", false)
  local bx, by = ImGui.GetCursorScreenPos(ctx)
  ImGui.SetCursorScreenPos(ctx, bx + 10, by)
  if ImGui.Button(ctx, preview_play and "STOP" or "PLAY", 86, 26) then
    preview_play = not preview_play
    last_time = reaper.time_precise()
  end
  ImGui.SameLine(ctx)
  changed, preview_sync_project_bpm = ImGui.Checkbox(ctx, "PROJECT BPM", preview_sync_project_bpm)
  changed, preview_speed = custom_slider_row("Preview speed", preview_speed, 0.125, 4.0, "%.3fx", false)
  if not preview_sync_project_bpm then
    changed, preview_loop_seconds = custom_slider_row("Loop seconds", preview_loop_seconds, 1.0, 30.0, "%.1f", false)
  else
    local start_qn = current_start_qn()
    muted_text(string.format("%.1f BPM", tempo_at_qn(start_qn)))
  end
  local total = total_state_beats()
  local cursor = 0
  for state = 1, #states do
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, state_name(state) .. "##preview_state_" .. tostring(state), 32, 26) then
      preview_t = cursor / total
      selected_state = state
    end
    cursor = cursor + math.max(0.25, state_lengths[state] or 8)
  end
end

local function draw_state_editor()
  ImGui.Spacing(ctx)
  section_label("states")
  for state = 1, #states do
    if state > 1 then ImGui.SameLine(ctx) end
    local label = (selected_state == state and "*" or "") .. state_name(state) .. "##state_select_" .. tostring(state)
    if ImGui.Button(ctx, label, 42, 26) then
      selected_state = state
      preview_t = (state - 1) / #states
    end
  end
  if ImGui.Button(ctx, "COPY PREV", 74, 24) then
    local prev = selected_state - 1
    if prev < 1 then prev = #states end
    copy_state(prev, selected_state)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "COPY NEXT", 74, 24) then
    local next_state = (selected_state % #states) + 1
    copy_state(next_state, selected_state)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "RAND", 54, 24) then randomize_state(selected_state) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "ADD", 48, 24) then add_state_after(selected_state) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "DELETE", 62, 24) then delete_state(selected_state) end

  local len = state_lengths[selected_state] or 16
  local changed
  changed, len = custom_slider_beats("Selected state length beats", len, 1, 128, "%.1f")
  if changed then state_lengths[selected_state] = state_length_value(len) end
  local state_start = 0
  for i = 1, selected_state - 1 do state_start = state_start + math.max(0.25, state_lengths[i] or 8) end
  local state_end = state_start + math.max(0.25, state_lengths[selected_state] or 8)
  changed, len = custom_input_double_row("Beats", state_lengths[selected_state] or len, 1, 4, "%.2f", 112, string.format("%s %.2f-%.2f", state_name(selected_state), state_start, state_end))
  if changed then state_lengths[selected_state] = state_length_value(len) end
  local bank_zero = bank_index - 1
  local apply_bank_pressed
  changed, bank_zero, apply_bank_pressed = custom_combo_action_row("State preset bank", bank_zero, BANK_ITEMS, 126, "APPLY", 62)
  if changed then bank_index = bank_zero + 1 end
  if apply_bank_pressed then
    local name = BANK_NAMES[bank_index] or "No bank"
    apply_bank(name)
  end

  section_label("lanes")
  local lane_panel_style = push_soft_panel_style()
  if ImGui.BeginChild(ctx, "##state_lanes", 0, 390) then
    for lane = 1, lane_count do
      local st = states[selected_state][lane]
      local lane_x, lane_y = ImGui.GetCursorScreenPos(ctx)
      draw_lane_row_background(lane)
      ImGui.PushID(ctx, lane)
      local enabled
      enabled, lane_enabled[lane] = ImGui.Checkbox(ctx, "##enabled", lane_enabled[lane])
      ImGui.SameLine(ctx)
      local lane_num_x, lane_num_y = ImGui.GetCursorScreenPos(ctx)
      ImGui.Dummy(ctx, 18, 18)
      ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), lane_num_x, lane_num_y, lane_color(lane), string.format("%02d", lane))
      ImGui.SameLine(ctx)
      local current_token = 0
      for index, token in ipairs(DRUM_TOKENS) do
        if token == lane_tokens[lane] then current_token = index - 1 break end
      end
      local changed, token_index = custom_mini_combo("Drum", current_token, DRUM_TOKEN_ITEMS, 54)
      if changed then lane_tokens[lane] = DRUM_TOKENS[token_index + 1] or "KIK" end
      ImGui.SameLine(ctx)
      local preset_zero = euclidean_preset_index(st)
      changed, preset_zero = custom_mini_combo("Preset", preset_zero, EUCLIDEAN_PRESET_ITEMS, 116)
      if changed then apply_euclidean_preset(st, EUCLIDEAN_PRESETS[preset_zero + 1]) end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "<##rotate_left", 24, 22) then st.rotate = st.rotate - 1 end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, ">##rotate_right", 24, 22) then st.rotate = st.rotate + 1 end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "COMP##complement", 42, 22) and lane > 1 then
        local prev = states[selected_state][lane - 1]
        set_lane_pattern(st, math.max(0, prev.steps - prev.pulses), prev.steps, prev.rotate)
      end
      ImGui.SameLine(ctx)
      changed, st.steps = custom_mini_slider("Steps", st.steps, 1, 64, nil, true, 108)
      ImGui.SameLine(ctx)
      st.pulses = math.min(st.pulses, st.steps)
      changed, st.pulses = custom_mini_slider("Pulses", st.pulses, 0, st.steps, nil, true, 108)
      ImGui.SameLine(ctx)
      changed, st.rotate = custom_mini_slider("Rotate", st.rotate, -st.steps, st.steps, nil, true, 108)
      ui_theme.muted(ImGui, ctx, interval_vector(pattern_from_state(st)))
      local px, py = ImGui.GetCursorScreenPos(ctx)
      ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), px, py + 3, rgba(0.62, 0.62, 0.62, 1.0), slider_label("Pattern"))
      ImGui.SetCursorScreenPos(ctx, px + 42, py)
      local pattern_avail = ImGui.GetContentRegionAvail(ctx)
      ImGui.SetNextItemWidth(ctx, math.max(150, math.min(300, pattern_avail - 420)))
      changed, st.pattern_input = ImGui.InputText(ctx, "##pattern", st.pattern_input or st.custom_pattern or "")
      if changed then
        if (st.pattern_input or "") == "" then
          st.custom_pattern = nil
        else
          apply_custom_pattern(st)
        end
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "CLEAR", 58, 22) then
        st.custom_pattern = nil
        st.pattern_input = ""
      end
      ImGui.SameLine(ctx)
      changed, st.density = custom_mini_slider("Hit probability", st.density, 0, 1, "%.2f", false, 108)
      ImGui.SameLine(ctx)
      changed, st.velocity = custom_mini_slider("Velocity", st.velocity, 1, 127, nil, true, 108)
      ImGui.SameLine(ctx)
      changed, st.accent = custom_mini_slider("Accent", st.accent, 0, 64, nil, true, 108)
      ImGui.PopID(ctx)
      ImGui.SetCursorScreenPos(ctx, lane_x, lane_y + 76)
      ImGui.Dummy(ctx, 1, 1)
    end
    ImGui.EndChild(ctx)
  end
  pop_soft_panel_style(lane_panel_style)
end

local function draw_footer()
  ImGui.Spacing(ctx)
  if ImGui.Button(ctx, "GENERATE MIDI", 170, 32) then write_midi() end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "RESET", 120, 32) then
    states = {}
    state_lengths = {}
    for state = 1, 4 do
      states[state] = {}
      state_lengths[state] = 16.0
      for lane = 1, 12 do states[state][lane] = make_lane_state(lane, state) end
    end
    lane_tokens = { "KIK", "SNR", "CHH", "OHH", "PHH", "RIM", "LT", "MT", "HT", "FT", "CR1", "RD1" }
    selected_state = 1
    preview_t = 0
    status = "Reset drum states."
  end
  ImGui.SameLine(ctx)
  muted_text(status)
end

local function loop()
  local now = reaper.time_precise()
  if preview_play then
    local dt = now - last_time
    local total_beats = total_state_beats()
    if preview_sync_project_bpm then
      local start_qn = current_start_qn()
      local bpm = tempo_at_qn(start_qn + preview_t * total_beats)
      local beat_delta = dt * (bpm / 60.0) * preview_speed
      preview_t = (preview_t + beat_delta / math.max(0.0001, total_beats)) % 1.0
    else
      preview_t = (preview_t + dt * preview_speed / math.max(0.1, preview_loop_seconds)) % 1.0
    end
  end
  last_time = now

  ImGui.SetNextWindowSize(ctx, 980, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local footer_height = 52
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    local content_height = math.max(220, avail_h - footer_height)
    local main_panel_style = push_soft_panel_style()
    local child_visible = ImGui.BeginChild(ctx, "##main_content", 0, content_height)
    if child_visible then
      draw_preview()
      draw_preview_controls()
      draw_state_editor()
      draw_global_controls()
    end
    ImGui.EndChild(ctx)
    pop_soft_panel_style(main_panel_style)
    draw_footer()
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
