-- @description 128ch Automation Mixer
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; JSFX: s3g MC Channel Automation Mixer 128
-- @category Channel Mixing / Automation
-- @method Auto-loads the 128-channel JSFX and provides fader automation, mute/solo, channel grouping, meters, and plugin pin remapping for the selected track.
-- @about
--   ReaImGui control surface for JS: s3g MC Channel Automation Mixer 128.
--   The JSFX exposes 128 automatable channel-level parameters; this controller
--   shows only the selected track's active channel count.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "128ch Automation Mixer", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local PROJECT = 0
local FX_NAME = "s3g MC Channel Automation Mixer 128"
local FX_NAME_CLEAN = "MC Channel Automation Mixer 128"
local FX_NAME_LEGACY = "s3g/MC Channel Automation Mixer 128"
local MAX_CH = 128
local PIN_MAP_BLOCK_SIZE = 64
local PIN_MAP_BLOCK_OFFSET = 0x1000000
local FADER_MIN_DB = -60
local FADER_MAX_DB = 12

local ctx = ImGui.CreateContext("128ch Automation Mixer")
local open = true
local page_start = 1
local page_size = 16
local matrix_start = 1
local matrix_dest_start = 1
local pin_side = 1 -- 0 = input pins, 1 = output pins
local quick_group = "none"
local manual_selected_channels = {}
local dragging_channel = nil
local group_drag_channels = {}
local group_drag_start_levels = {}
local group_drag_anchor_db = 0
local solo_active_channel = nil
local solo_restore_levels = {}
local db_input_values = {}
local db_input_editing = {}
local COLOR_METER_BG = ImGui.ColorConvertDouble4ToU32(0.09, 0.095, 0.10, 1)
local COLOR_METER_FILL = ImGui.ColorConvertDouble4ToU32(0.46, 0.86, 0.56, 1)
local COLOR_METER_EDGE = ImGui.ColorConvertDouble4ToU32(0.30, 0.32, 0.34, 1)
local COLOR_PANEL_BG = ImGui.ColorConvertDouble4ToU32(0.055, 0.060, 0.065, 1)
local COLOR_CELL_OFF = ImGui.ColorConvertDouble4ToU32(0.13, 0.14, 0.15, 1)
local COLOR_CELL_ON = ImGui.ColorConvertDouble4ToU32(0.16, 0.63, 0.38, 1)
local COLOR_CELL_EDGE = ImGui.ColorConvertDouble4ToU32(0.29, 0.31, 0.33, 1)
local COLOR_TEXT = ImGui.ColorConvertDouble4ToU32(0.78, 0.82, 0.84, 1)
local COLOR_TEXT_DIM = ImGui.ColorConvertDouble4ToU32(0.48, 0.52, 0.54, 1)
local COLOR_FADER_BG = ImGui.ColorConvertDouble4ToU32(0.10, 0.11, 0.12, 1)
local COLOR_FADER_FILL = ImGui.ColorConvertDouble4ToU32(0.24, 0.58, 0.66, 1)
local COLOR_FADER_TICK = ImGui.ColorConvertDouble4ToU32(0.055, 0.060, 0.065, 0.82)
local COLOR_UNITY_TICK = ImGui.ColorConvertDouble4ToU32(0.72, 0.76, 0.70, 0.92)
local COLOR_GROUP_SELECT = ImGui.ColorConvertDouble4ToU32(0.22, 0.72, 0.52, 1)
local COLOR_BUTTON_BG = ImGui.ColorConvertDouble4ToU32(0.12, 0.13, 0.14, 1)
local COLOR_BUTTON_ACTIVE = ImGui.ColorConvertDouble4ToU32(0.58, 0.22, 0.18, 1)

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function format_db(db)
  if db <= FADER_MIN_DB + 0.000001 then return "-inf" end
  return string.format("%+.1f dB", db)
end

local function format_db_input(db)
  if db <= FADER_MIN_DB + 0.000001 then return "-inf" end
  return string.format("%.1f", db)
end

local function parse_db_input(text)
  local cleaned = tostring(text or ""):lower():gsub("db", ""):gsub("%s+", "")
  if cleaned == "-inf" or cleaned == "inf-" or cleaned == "mute" then return FADER_MIN_DB end
  local value = tonumber(cleaned)
  if not value then return nil end
  return clamp(value, FADER_MIN_DB, FADER_MAX_DB)
end

local function db_to_fader_pos(db)
  db = clamp(db, FADER_MIN_DB, FADER_MAX_DB)
  return (db - FADER_MIN_DB) / (FADER_MAX_DB - FADER_MIN_DB)
end

local function fader_pos_to_db(pos)
  pos = clamp(pos, 0, 1)
  if pos <= 0 then return FADER_MIN_DB end
  return FADER_MIN_DB + pos * (FADER_MAX_DB - FADER_MIN_DB)
end

local function shift_is_down()
  return ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)
end

local function peak_to_norm(peak)
  if peak <= 0.000001 then return 0 end
  local db = 20 * math.log(peak) / math.log(10)
  return clamp((db + 60) / 60, 0, 1)
end

local function pin_block_for_channel(ch)
  if ch < 1 or ch > MAX_CH then return nil, nil end
  local block = math.floor((ch - 1) / PIN_MAP_BLOCK_SIZE)
  local block_ch = ((ch - 1) % PIN_MAP_BLOCK_SIZE) + 1
  return block, block_ch
end

local function pin_index_for_block(source_ch, block)
  return (source_ch - 1) + block * PIN_MAP_BLOCK_OFFSET
end

local function mask_for_block_channel(block_ch)
  if block_ch < 1 or block_ch > PIN_MAP_BLOCK_SIZE then return nil, nil end
  if block_ch <= 32 then return 1 << (block_ch - 1), 0 end
  return 0, 1 << (block_ch - 33)
end

local function mapping_has_channel(low, high, ch)
  local mask_low, mask_high = mask_for_block_channel(ch)
  if not mask_low then return false end
  return (mask_low ~= 0 and (low & mask_low) ~= 0) or (mask_high ~= 0 and (high & mask_high) ~= 0)
end

local function get_pin_mapping_block(track, fx, side, source_ch, block)
  local low, high = reaper.TrackFX_GetPinMappings(track, fx, side, pin_index_for_block(source_ch, block))
  return low or 0, high or 0
end

local function set_pin_mapping_block(track, fx, side, source_ch, block, low, high)
  return reaper.TrackFX_SetPinMappings(track, fx, side, pin_index_for_block(source_ch, block), low or 0, high or 0)
end

local function set_pin_single(track, fx, side, source_ch, dest_ch)
  local dest_block, dest_block_ch = pin_block_for_channel(dest_ch)
  if not dest_block then return false end
  for block = 0, 1 do
    local low, high = 0, 0
    if block == dest_block then
      low, high = mask_for_block_channel(dest_block_ch)
    end
    set_pin_mapping_block(track, fx, side, source_ch, block, low, high)
  end
  return true
end

local function add_block_channel_to_masks(low, high, ch)
  local mask_low, mask_high = mask_for_block_channel(ch)
  if not mask_low then return low, high end
  if mask_low ~= 0 then low = low | mask_low end
  if mask_high ~= 0 then high = high | mask_high end
  return low, high
end

local function read_pin_destinations(track, fx, side, source_ch, pin_ch)
  local dests = {}
  for block = 0, 1 do
    local low, high = get_pin_mapping_block(track, fx, side, source_ch, block)
    local block_start = block * PIN_MAP_BLOCK_SIZE
    local block_end = math.min(PIN_MAP_BLOCK_SIZE, pin_ch - block_start)
    for block_ch = 1, block_end do
      if mapping_has_channel(low, high, block_ch) then
        dests[#dests + 1] = block_start + block_ch
      end
    end
  end
  return dests
end

local function write_pin_destinations(track, fx, side, source_ch, dests)
  local lows = { [0] = 0, [1] = 0 }
  local highs = { [0] = 0, [1] = 0 }
  for _, dest_ch in ipairs(dests) do
    local block, block_ch = pin_block_for_channel(dest_ch)
    if block then
      lows[block], highs[block] = add_block_channel_to_masks(lows[block], highs[block], block_ch)
    end
  end
  for block = 0, 1 do
    set_pin_mapping_block(track, fx, side, source_ch, block, lows[block], highs[block])
  end
end

local function rotate_destinations(dests, pin_ch, offset)
  local rotated = {}
  for _, ch in ipairs(dests) do
    if ch >= 1 and ch <= pin_ch then
      rotated[#rotated + 1] = ((ch - 1 + offset) % pin_ch) + 1
    end
  end
  return rotated
end

local function pin_has_destination(track, fx, side, source_ch, dest_ch)
  local block, block_ch = pin_block_for_channel(dest_ch)
  if not block then return false end
  local low, high = get_pin_mapping_block(track, fx, side, source_ch, block)
  return mapping_has_channel(low, high, block_ch)
end

local function clear_pin_all_blocks(track, fx, side, source_ch)
  for block = 0, 1 do
    set_pin_mapping_block(track, fx, side, source_ch, block, 0, 0)
  end
end

local function toggle_pin_dest(track, fx, side, source_ch, dest_ch)
  local block, block_ch = pin_block_for_channel(dest_ch)
  if not block then return false end
  local mask_low, mask_high = mask_for_block_channel(block_ch)
  local low, high = get_pin_mapping_block(track, fx, side, source_ch, block)
  if mask_low ~= 0 then low = low ~ mask_low end
  if mask_high ~= 0 then high = high ~ mask_high end
  set_pin_mapping_block(track, fx, side, source_ch, block, low, high)
  return true
end

local function set_identity_pins(track, fx, active_ch)
  reaper.Undo_BeginBlock()
  active_ch = math.min(active_ch, MAX_CH)
  for ch = 1, active_ch do
    set_pin_single(track, fx, 0, ch, ch)
    set_pin_single(track, fx, 1, ch, ch)
  end
  for ch = active_ch + 1, MAX_CH do
    clear_pin_all_blocks(track, fx, 0, ch)
    clear_pin_all_blocks(track, fx, 1, ch)
  end
  reaper.Undo_EndBlock("Set MC channel automation mixer identity pins", -1)
end

local function clear_pins(track, fx, side, active_ch)
  reaper.Undo_BeginBlock()
  for ch = 1, math.min(active_ch, MAX_CH) do
    clear_pin_all_blocks(track, fx, side, ch)
  end
  reaper.Undo_EndBlock("Clear MC channel automation mixer pins", -1)
end

local function rotate_pins(track, fx, side, active_ch, offset)
  local pin_ch = math.min(active_ch, MAX_CH)
  reaper.Undo_BeginBlock()
  for ch = 1, pin_ch do
    local dests = read_pin_destinations(track, fx, side, ch, pin_ch)
    write_pin_destinations(track, fx, side, ch, rotate_destinations(dests, pin_ch, offset))
  end
  reaper.Undo_EndBlock("Rotate MC channel automation mixer pins", -1)
end

local function reverse_pins(track, fx, side, active_ch)
  local pin_ch = math.min(active_ch, MAX_CH)
  reaper.Undo_BeginBlock()
  for ch = 1, pin_ch do
    set_pin_single(track, fx, side, ch, pin_ch - ch + 1)
  end
  reaper.Undo_EndBlock("Reverse MC channel automation mixer pins", -1)
end

local function find_fx(track)
  if not track then return -1 end
  for fx = 0, reaper.TrackFX_GetCount(track) - 1 do
    local ok, name = reaper.TrackFX_GetFXName(track, fx, "")
    if ok and (name:find(FX_NAME, 1, true) or name:find(FX_NAME_CLEAN, 1, true) or name:find(FX_NAME_LEGACY, 1, true)) then return fx end
  end
  return -1
end

local function maybe_load(track, active_ch, force_identity)
  if not track then return -1 end
  active_ch = active_ch or 2
  local fx = find_fx(track)
  if fx >= 0 then
    if force_identity then set_identity_pins(track, fx, active_ch) end
    return fx
  end
  fx = reaper.TrackFX_AddByName(track, "JS: " .. FX_NAME, false, -1)
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, FX_NAME, false, -1) end
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, "JS: " .. FX_NAME_CLEAN, false, -1) end
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, FX_NAME_CLEAN, false, -1) end
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, "JS: " .. FX_NAME_LEGACY, false, -1) end
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, FX_NAME_LEGACY, false, -1) end
  if fx >= 0 then set_identity_pins(track, fx, active_ch) end
  return fx
end

local function get_track_channels(track)
  if not track then return 2 end
  return clamp(math.floor(reaper.GetMediaTrackInfo_Value(track, "I_NCHAN") + 0.5), 2, MAX_CH)
end

local function get_param(track, fx, param)
  local value = reaper.TrackFX_GetParam(track, fx, param)
  if value == nil then return 0 end
  return value
end

local function set_param(track, fx, param, value)
  reaper.TrackFX_SetParam(track, fx, param, clamp(value, FADER_MIN_DB, FADER_MAX_DB))
end

local function channel_matches_group(ch, first_ch, last_ch, group)
  if group == "none" then return false end
  if group == "odd" then return ch % 2 == 1 end
  if group == "even" then return ch % 2 == 0 end
  if group == "first_half" then return ch <= first_ch + math.floor((last_ch - first_ch) / 2) end
  if group == "second_half" then return ch > first_ch + math.floor((last_ch - first_ch) / 2) end
  if group == "every4" then return ((ch - first_ch) % 4) == 0 end
  return true
end

local function has_manual_selection()
  for _ in pairs(manual_selected_channels) do return true end
  return false
end

local function toggle_manual_channel(ch)
  if manual_selected_channels[ch] then
    manual_selected_channels[ch] = nil
  else
    manual_selected_channels[ch] = true
  end
end

local function group_channels(first_ch, last_ch, group)
  local channels = {}
  if group == "__selected" and not has_manual_selection() then group = quick_group end
  for ch = first_ch, last_ch do
    if group == "__selected" and has_manual_selection() then
      if manual_selected_channels[ch] then channels[#channels + 1] = ch end
    elseif channel_matches_group(ch, first_ch, last_ch, group) then
      channels[#channels + 1] = ch
    end
  end
  return channels
end

local function channel_is_selected(ch, first_ch, last_ch)
  if has_manual_selection() then return manual_selected_channels[ch] == true end
  return channel_matches_group(ch, first_ch, last_ch, quick_group)
end

local function selected_or_single_channels(ch, first_ch, last_ch)
  if channel_is_selected(ch, first_ch, last_ch) then
    return group_channels(first_ch, last_ch, "__selected")
  end
  return {ch}
end

local function set_channels(track, fx, channels, value)
  for _, ch in ipairs(channels) do
    set_param(track, fx, ch - 1, value)
  end
end

local function set_channels_relative_to_anchor(track, fx, channels, anchor_ch, anchor_value)
  local delta = anchor_value - get_param(track, fx, anchor_ch - 1)
  for _, ch in ipairs(channels) do
    set_param(track, fx, ch - 1, get_param(track, fx, ch - 1) + delta)
  end
end

local function reset_range(track, fx, first_ch, last_ch, group)
  local channels = group_channels(first_ch, last_ch, group or "all")
  reaper.Undo_BeginBlock()
  for _, ch in ipairs(channels) do
    set_param(track, fx, ch - 1, 0)
  end
  reaper.Undo_EndBlock("Reset MC channel automation mixer range", -1)
end

local function set_range(track, fx, first_ch, last_ch, value, group)
  local channels = group_channels(first_ch, last_ch, group or "all")
  reaper.Undo_BeginBlock()
  for _, ch in ipairs(channels) do
    set_param(track, fx, ch - 1, value)
  end
  reaper.Undo_EndBlock("Set MC channel automation mixer range", -1)
end

local function trim_range(track, fx, first_ch, last_ch, delta_db, group)
  local channels = group_channels(first_ch, last_ch, group or "all")
  reaper.Undo_BeginBlock()
  for _, ch in ipairs(channels) do
    set_param(track, fx, ch - 1, get_param(track, fx, ch - 1) + delta_db)
  end
  reaper.Undo_EndBlock("Trim MC channel automation mixer range", -1)
end

local function shape_range(track, fx, first_ch, last_ch, shape, group)
  local channels = group_channels(first_ch, last_ch, group or "all")
  local count = #channels
  if count <= 0 then return end

  reaper.Undo_BeginBlock()
  for index, ch in ipairs(channels) do
    local zero_index = index - 1
    local t = count <= 1 and 0.5 or zero_index / (count - 1)
    local distance_from_center = math.abs(t * 2 - 1)
    local level_db = 0

    if shape == "ramp_up" then
      level_db = -18 + t * 18
    elseif shape == "ramp_down" then
      level_db = -18 + (1 - t) * 18
    elseif shape == "center_high" then
      level_db = -18 * distance_from_center
    elseif shape == "edges_high" then
      level_db = -18 * (1 - distance_from_center)
    elseif shape == "alternate" then
      level_db = (zero_index % 2 == 0) and 0 or -12
    end

    set_param(track, fx, ch - 1, level_db)
  end
  reaper.Undo_EndBlock("Shape MC channel automation mixer range", -1)
end

local function group_button(label, value)
  local clicked = ImGui.Button(ctx, (not has_manual_selection() and quick_group == value and "*" or "") .. label)
  if clicked then
    quick_group = value
    manual_selected_channels = {}
  end
end

local function solo_channel(track, fx, solo_ch, active_ch)
  reaper.Undo_BeginBlock()
  if solo_active_channel == solo_ch and #solo_restore_levels > 0 then
    for ch = 1, math.min(active_ch, #solo_restore_levels) do
      set_param(track, fx, ch - 1, solo_restore_levels[ch] or 0)
    end
    solo_active_channel = nil
    solo_restore_levels = {}
  else
    if #solo_restore_levels == 0 then
      for ch = 1, active_ch do
        solo_restore_levels[ch] = get_param(track, fx, ch - 1)
      end
    end
    solo_active_channel = solo_ch
    for ch = 1, active_ch do
      set_param(track, fx, ch - 1, ch == solo_ch and (solo_restore_levels[ch] or 0) or FADER_MIN_DB)
    end
  end
  reaper.Undo_EndBlock("Solo MC channel automation mixer channel", -1)
end

local function draw_vertical_meter(norm, width, height)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local fill_h = height * clamp(norm, 0, 1)
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + width, y + height, COLOR_METER_BG)
  ImGui.DrawList_AddRectFilled(draw_list, x, y + height - fill_h, x + width, y + height, COLOR_METER_FILL)
  ImGui.DrawList_AddRect(draw_list, x, y, x + width, y + height, COLOR_METER_EDGE)
  ImGui.Dummy(ctx, width, height)
end

local function begin_channel_drag(track, fx, ch, first_ch, last_ch, fader_top, fader_h, mouse_y)
  local norm = (fader_top + fader_h - mouse_y) / fader_h
  local pointer_db = fader_pos_to_db(norm)

  dragging_channel = ch
  group_drag_channels = selected_or_single_channels(ch, first_ch, last_ch)
  group_drag_start_levels = {}
  group_drag_anchor_db = get_param(track, fx, ch - 1)

  for _, group_ch in ipairs(group_drag_channels) do
    group_drag_start_levels[group_ch] = get_param(track, fx, group_ch - 1)
  end

  local delta = pointer_db - group_drag_anchor_db
  for _, group_ch in ipairs(group_drag_channels) do
    set_param(track, fx, group_ch - 1, group_drag_start_levels[group_ch] + delta)
  end
end

local function update_group_drag(track, fx, fader_top, fader_h, mouse_y)
  if not dragging_channel then return end
  local norm = (fader_top + fader_h - mouse_y) / fader_h
  local pointer_db = fader_pos_to_db(norm)
  local delta = pointer_db - group_drag_anchor_db

  for _, ch in ipairs(group_drag_channels) do
    local start_level = group_drag_start_levels[ch]
    if start_level then set_param(track, fx, ch - 1, start_level + delta) end
  end
end

local function clear_group_drag()
  dragging_channel = nil
  group_drag_channels = {}
  group_drag_start_levels = {}
  group_drag_anchor_db = 0
end

local function draw_channel_controls(track, fx, active_ch)
  local strip_w = 58
  local slider_w = 20
  local meter_w = 7
  local max_visible = clamp(math.floor(ImGui.GetContentRegionAvail(ctx) / strip_w), 2, math.min(32, active_ch))
  page_size = clamp(page_size, 2, max_visible)
  page_start = clamp(page_start, 1, math.max(1, active_ch - page_size + 1))
  local page_end = math.min(active_ch, page_start + page_size - 1)
  local visible_count = page_end - page_start + 1

  ImGui.Text(ctx, string.format("Showing channels %d-%d of %d", page_start, page_end, active_ch))
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "<") then page_start = clamp(page_start - page_size, 1, active_ch) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, ">") then page_start = clamp(page_start + page_size, 1, math.max(1, active_ch - page_size + 1)) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Reset") then reset_range(track, fx, page_start, page_end, "__selected") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Reset Active") then reset_range(track, fx, 1, active_ch) end

  local changed
  changed, page_size = ImGui.SliderInt(ctx, "Visible channels", page_size, 2, max_visible)
  if changed then page_start = clamp(page_start, 1, math.max(1, active_ch - page_size + 1)) end

  group_button("None", "none")
  ImGui.SameLine(ctx)
  group_button("All", "all")
  ImGui.SameLine(ctx)
  group_button("Odd", "odd")
  ImGui.SameLine(ctx)
  group_button("Even", "even")
  ImGui.SameLine(ctx)
  group_button("1st Half", "first_half")
  ImGui.SameLine(ctx)
  group_button("2nd Half", "second_half")
  ImGui.SameLine(ctx)
  group_button("Every 4", "every4")
  if has_manual_selection() then
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "*Clear Sel") then
      manual_selected_channels = {}
      quick_group = "none"
    end
  end

  if ImGui.Button(ctx, "Mute") then set_range(track, fx, page_start, page_end, FADER_MIN_DB, "__selected") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "-6 dB") then set_range(track, fx, page_start, page_end, -6, "__selected") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "-12 dB") then set_range(track, fx, page_start, page_end, -12, "__selected") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Unity") then set_range(track, fx, page_start, page_end, 0, "__selected") end

  if ImGui.Button(ctx, "Trim -3") then trim_range(track, fx, page_start, page_end, -3, "__selected") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Trim -1") then trim_range(track, fx, page_start, page_end, -1, "__selected") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Trim +1") then trim_range(track, fx, page_start, page_end, 1, "__selected") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Trim +3") then trim_range(track, fx, page_start, page_end, 3, "__selected") end

  if ImGui.Button(ctx, "Ramp Up") then shape_range(track, fx, page_start, page_end, "ramp_up", "__selected") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Ramp Down") then shape_range(track, fx, page_start, page_end, "ramp_down", "__selected") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Center High") then shape_range(track, fx, page_start, page_end, "center_high", "__selected") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Edges High") then shape_range(track, fx, page_start, page_end, "edges_high", "__selected") end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Alternate") then shape_range(track, fx, page_start, page_end, "alternate", "__selected") end

  ImGui.Separator(ctx)

  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local fader_top = y0 + 24
  local fader_h = 184
  local canvas_w = visible_count * strip_w
  local canvas_h = fader_h + 92
  ImGui.SetNextItemAllowOverlap(ctx)
  ImGui.InvisibleButton(ctx, "##channel_strip_canvas", canvas_w, canvas_h)
  local hovered = ImGui.IsItemHovered(ctx)
  local mx, my = ImGui.GetMousePos(ctx)

  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x0 + canvas_w, y0 + canvas_h, COLOR_PANEL_BG)

  local function fader_hit(strip_x)
    local fader_x = strip_x + 12
    return mx >= fader_x - 5 and mx <= fader_x + slider_w + 5 and my >= fader_top and my <= fader_top + fader_h
  end

  local function selection_hit(strip_x)
    local value_y = fader_top + fader_h + 5
    local button_y = fader_top + fader_h + 32
    local in_strip = mx >= strip_x + 2 and mx <= strip_x + strip_w - 2 and my >= y0 + 2 and my <= y0 + canvas_h - 2
    local in_value = my >= value_y - 2 and my <= value_y + 22
    local in_buttons = my >= button_y - 2 and my <= button_y + 20
    return in_strip and not in_value and not in_buttons
  end

  if hovered and ImGui.IsMouseDoubleClicked(ctx, 0) then
    for i = 0, visible_count - 1 do
      local ch = page_start + i
      local strip_x = x0 + i * strip_w
      if fader_hit(strip_x) then
        clear_group_drag()
        set_channels(track, fx, selected_or_single_channels(ch, page_start, page_end), 0)
      end
    end
  elseif hovered and ImGui.IsMouseClicked(ctx, 0) then
    for i = 0, visible_count - 1 do
      local ch = page_start + i
      local strip_x = x0 + i * strip_w
      if shift_is_down() then
        if selection_hit(strip_x) then
          clear_group_drag()
          toggle_manual_channel(ch)
        end
      elseif fader_hit(strip_x) then
        begin_channel_drag(track, fx, ch, page_start, page_end, fader_top, fader_h, my)
      end
    end
  end
  if dragging_channel and ImGui.IsMouseDown(ctx, 0) then
    update_group_drag(track, fx, fader_top, fader_h, my)
  end
  if ImGui.IsMouseReleased(ctx, 0) then clear_group_drag() end

  for i = 0, visible_count - 1 do
    local ch = page_start + i
    local level_db = get_param(track, fx, ch - 1)
    local peak_norm = peak_to_norm(reaper.Track_GetPeakInfo(track, ch - 1) or 0)
    local strip_x = x0 + i * strip_w
    local fader_x = strip_x + 12
    local meter_x = fader_x + slider_w + 11
    local value_y = fader_top + fader_h + 5
    local button_y = fader_top + fader_h + 32
    local mute_x = strip_x + 5
    local solo_x = strip_x + 31
    local muted = level_db <= FADER_MIN_DB + 0.000001
    local soloed = solo_active_channel == ch
    local selected = channel_is_selected(ch, page_start, page_end)
    local fader_pos = db_to_fader_pos(level_db)
    local fill_h = fader_h * fader_pos
    local fill_top = fader_top + fader_h - fill_h
    local tick_db = {-48, -36, -24, -18, -12, -6, 0, 6}

    ImGui.DrawList_AddRectFilled(draw_list, strip_x + 2, y0 + 2, strip_x + strip_w - 2, y0 + canvas_h - 2, COLOR_PANEL_BG)
    ImGui.DrawList_AddRect(draw_list, strip_x + 2, y0 + 2, strip_x + strip_w - 2, y0 + canvas_h - 2, selected and COLOR_GROUP_SELECT or COLOR_CELL_EDGE)
    ImGui.DrawList_AddText(draw_list, strip_x + 11, y0 + 5, COLOR_TEXT, string.format("%02d", ch))

    ImGui.DrawList_AddRectFilled(draw_list, fader_x, fader_top, fader_x + slider_w, fader_top + fader_h, COLOR_FADER_BG)
    if fill_h > 0 then
      ImGui.DrawList_AddRectFilled(draw_list, fader_x, fill_top, fader_x + slider_w, fader_top + fader_h, COLOR_FADER_FILL)
    end
    for _, db in ipairs(tick_db) do
      local tick_y = fader_top + fader_h * (1 - db_to_fader_pos(db))
      local tick_color = db == 0 and COLOR_UNITY_TICK or COLOR_FADER_TICK
      ImGui.DrawList_AddLine(draw_list, fader_x + 1, tick_y, fader_x + slider_w - 1, tick_y, tick_color)
    end
    ImGui.DrawList_AddRect(draw_list, fader_x, fader_top, fader_x + slider_w, fader_top + fader_h, COLOR_CELL_EDGE)

    ImGui.DrawList_AddRectFilled(draw_list, meter_x, fader_top, meter_x + meter_w, fader_top + fader_h, COLOR_METER_BG)
    ImGui.DrawList_AddRectFilled(draw_list, meter_x, fader_top + fader_h * (1 - peak_norm), meter_x + meter_w, fader_top + fader_h, COLOR_METER_FILL)
    ImGui.DrawList_AddRect(draw_list, meter_x, fader_top, meter_x + meter_w, fader_top + fader_h, COLOR_METER_EDGE)

    ImGui.DrawList_AddRectFilled(draw_list, mute_x, button_y, mute_x + 22, button_y + 18, muted and COLOR_BUTTON_ACTIVE or COLOR_BUTTON_BG)
    ImGui.DrawList_AddRect(draw_list, mute_x, button_y, mute_x + 22, button_y + 18, COLOR_CELL_EDGE)
    ImGui.DrawList_AddText(draw_list, mute_x + 6, button_y + 2, COLOR_TEXT, "M")
    ImGui.DrawList_AddRectFilled(draw_list, solo_x, button_y, solo_x + 22, button_y + 18, soloed and COLOR_CELL_ON or COLOR_BUTTON_BG)
    ImGui.DrawList_AddRect(draw_list, solo_x, button_y, solo_x + 22, button_y + 18, COLOR_CELL_EDGE)
    ImGui.DrawList_AddText(draw_list, solo_x + 7, button_y + 2, COLOR_TEXT, "S")

    ImGui.SetCursorScreenPos(ctx, strip_x + 4, value_y)
    ImGui.SetNextItemWidth(ctx, strip_w - 8)
    if not db_input_editing[ch] then
      db_input_values[ch] = format_db_input(level_db)
    end
    local changed, input_value = ImGui.InputText(ctx, "##db_input_" .. ch, db_input_values[ch])
    db_input_values[ch] = input_value
    db_input_editing[ch] = ImGui.IsItemActive(ctx)
    if changed then
      local parsed = parse_db_input(input_value)
      if parsed then
        set_channels_relative_to_anchor(track, fx, selected_or_single_channels(ch, page_start, page_end), ch, parsed)
      end
    end
  end

  if hovered and ImGui.IsMouseClicked(ctx, 0) then
    for i = 0, visible_count - 1 do
      local ch = page_start + i
      local strip_x = x0 + i * strip_w
      local button_y = fader_top + fader_h + 32
      local mute_x = strip_x + 5
      local solo_x = strip_x + 31
      if my >= button_y and my <= button_y + 18 then
        if mx >= mute_x and mx <= mute_x + 22 then
          local muted = get_param(track, fx, ch - 1) <= FADER_MIN_DB + 0.000001
          set_param(track, fx, ch - 1, muted and 0 or FADER_MIN_DB)
        elseif mx >= solo_x and mx <= solo_x + 22 then
          solo_channel(track, fx, ch, active_ch)
        end
      end
    end
  end

  ImGui.SetCursorScreenPos(ctx, x0, y0 + canvas_h)
end

local function draw_pin_matrix(track, fx, active_ch)
  if not ImGui.CollapsingHeader(ctx, "Pin matrix / remap", nil, ImGui.TreeNodeFlags_DefaultOpen) then return end

  local pin_ch = math.min(active_ch, MAX_CH)
  local side_name = pin_side == 0 and "Input pins" or "Output pins"

  if ImGui.Button(ctx, side_name) then pin_side = pin_side == 0 and 1 or 0 end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Identity I/O") then set_identity_pins(track, fx, active_ch) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Clear side") then clear_pins(track, fx, pin_side, active_ch) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Rotate +1") then rotate_pins(track, fx, pin_side, active_ch, 1) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Rotate -1") then rotate_pins(track, fx, pin_side, active_ch, -1) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Reverse side") then reverse_pins(track, fx, pin_side, active_ch) end

  matrix_start = clamp(matrix_start, 1, math.max(1, pin_ch - page_size + 1))
  matrix_dest_start = clamp(matrix_dest_start, 1, math.max(1, pin_ch - page_size + 1))
  local matrix_end = math.min(pin_ch, matrix_start + page_size - 1)
  local matrix_dest_end = math.min(pin_ch, matrix_dest_start + page_size - 1)
  local matrix_rows = matrix_end - matrix_start + 1
  local matrix_cols = matrix_dest_end - matrix_dest_start + 1

  ImGui.Text(ctx, string.format("%s: FX pins %d-%d to track channels %d-%d",
    side_name, matrix_start, matrix_end, matrix_dest_start, matrix_dest_end))
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "<< FX##matrix_src") then matrix_start = clamp(matrix_start - page_size, 1, math.max(1, pin_ch - page_size + 1)) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "FX >>##matrix_src") then matrix_start = clamp(matrix_start + page_size, 1, math.max(1, pin_ch - page_size + 1)) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "<< Ch##matrix_dst") then matrix_dest_start = clamp(matrix_dest_start - page_size, 1, math.max(1, pin_ch - page_size + 1)) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Ch >>##matrix_dst") then matrix_dest_start = clamp(matrix_dest_start + page_size, 1, math.max(1, pin_ch - page_size + 1)) end

  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local label_w = 42
  local cell = 18
  local gap = 2
  local header_h = 24
  local matrix_w = label_w + matrix_cols * cell
  local matrix_h = header_h + matrix_rows * cell
  ImGui.InvisibleButton(ctx, "##pin_matrix_canvas", matrix_w, matrix_h)
  local hovered = ImGui.IsItemHovered(ctx)
  local mx, my = ImGui.GetMousePos(ctx)

  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x0 + matrix_w, y0 + matrix_h, COLOR_PANEL_BG)
  ImGui.DrawList_AddText(draw_list, x0 + 4, y0 + 5, COLOR_TEXT_DIM, pin_side == 0 and "in" or "out")

  for dst = matrix_dest_start, matrix_dest_end do
    local col = dst - matrix_dest_start
    local tx = x0 + label_w + col * cell + 2
    ImGui.DrawList_AddText(draw_list, tx, y0 + 5, COLOR_TEXT_DIM, string.format("%02d", dst))
  end

  for src = matrix_start, matrix_end do
    local row = src - matrix_start
    local row_y = y0 + header_h + row * cell
    ImGui.DrawList_AddText(draw_list, x0 + 5, row_y + 2, COLOR_TEXT_DIM, string.format("%02d", src))
    for dst = matrix_dest_start, matrix_dest_end do
      local col = dst - matrix_dest_start
      local cell_x = x0 + label_w + col * cell
      local on = pin_has_destination(track, fx, pin_side, src, dst)
      local fill = on and COLOR_CELL_ON or COLOR_CELL_OFF
      ImGui.DrawList_AddRectFilled(draw_list, cell_x + gap, row_y + gap, cell_x + cell - gap, row_y + cell - gap, fill)
      ImGui.DrawList_AddRect(draw_list, cell_x + gap, row_y + gap, cell_x + cell - gap, row_y + cell - gap, COLOR_CELL_EDGE)
    end
  end

  if hovered and ImGui.IsMouseClicked(ctx, 0) then
    local col = math.floor((mx - (x0 + label_w)) / cell)
    local row = math.floor((my - (y0 + header_h)) / cell)
    if col >= 0 and col < matrix_cols and row >= 0 and row < matrix_rows then
      local src = matrix_start + row
      local dst = matrix_dest_start + col
      toggle_pin_dest(track, fx, pin_side, src, dst)
    end
  end
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 920, 760, ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, "128ch Automation Mixer", open)
  if visible then
    local track = reaper.GetSelectedTrack(PROJECT, 0)
    if not track then
      ImGui.Text(ctx, "No selected track.")
    else
      local _, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
      local active_ch = get_track_channels(track)
      ImGui.Text(ctx, "Selected track: " .. (track_name ~= "" and track_name or "(unnamed)"))
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Load/repair JSFX") then maybe_load(track, active_ch, true) end
      ImGui.SameLine(ctx)
      ImGui.Text(ctx, string.format("%d track channels", active_ch))

      local fx = maybe_load(track, active_ch, false)
      if fx < 0 then
        ImGui.Text(ctx, "Could not load JS: " .. FX_NAME)
      else
        draw_channel_controls(track, fx, active_ch)
        draw_pin_matrix(track, fx, active_ch)
      end
    end
    ImGui.End(ctx)
  end

  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)
