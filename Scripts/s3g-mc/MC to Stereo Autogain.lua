-- @description MC to Stereo Autogain
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; JSFX: s3g MC to Stereo Autogain
-- @category Channel Mixing / Automation
-- @method Auto-loads the JSFX and folds a multichannel track to stereo using selectable 2D and 3D projection layouts, width/rotation, layout weighting, 3D attenuation, autogain, and output gain. The JSFX declares only stereo outputs; in multichannel chains, set the plugin I/O to zero unmapped output channels.
-- @about
--   ReaImGui control surface for JS: s3g MC to Stereo Autogain. Downmixes a
--   multichannel track to stereo with width, rotation, layout, output gain,
--   3D attenuation, and autogain controls. The JSFX declares only stereo
--   outputs; in multichannel chains, set the plugin I/O to zero unmapped
--   output channels.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "MC to Stereo Autogain", 0)
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

local PROJECT = 0
local MAX_CH = 128
local PIN_MAP_BLOCK_SIZE = 64
local PIN_MAP_BLOCK_OFFSET = 0x1000000
local FX_NAME = "s3g MC to Stereo Autogain"
local FX_NAME_OLD = "s3g Stereo Autogain"
local FX_NAME_OLDER = "s3g MC Stereo Autogain"
local FX_NAME_CLEAN = "MC Stereo Autogain"
local FX_NAME_LEGACY = "s3g/MC Stereo Autogain"
local CONTENT_W = 640
local CONTROL_W = 420
local OUTPUT_W = 92
local METER_W = 112

local PARAM = {
  input_channels = 0,
  width = 1,
  rotation = 2,
  autogain = 3,
  output_gain = 4,
  layout = 5,
  weight = 7,
  attenuation = 8,
}

local AUTOGAIN = { "Off", "Power/sqrt(N)", "Energy sum" }
local LAYOUT = {
  "Ring projection",
  "Linear left-right",
  "Odd/even stereo",
  "Center-out",
  "Pair-preserving",
  "Sphere projection",
  "Hemisphere projection",
  "Cube projection",
}
local ctx = ImGui.CreateContext("MC to Stereo Autogain")
local open = true
local last_pin_track, last_pin_fx, last_pin_ch

local STYLE = {
  bg = THEME.bg,
  panel = THEME.panel,
  edge = THEME.edge,
  text = THEME.text,
  muted = THEME.value,
  fill = THEME.fill,
  meter = THEME.ok,
  warn = THEME.warn,
}

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function db_to_norm(db)
  return clamp((db + 60) / 72, 0, 1)
end

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local function peak_to_norm(peak)
  if peak <= 0.000001 then return 0 end
  local db = 20 * math.log(peak) / math.log(10)
  return clamp((db + 60) / 60, 0, 1)
end

local function fx_name_matches(name)
  return name:find(FX_NAME, 1, true) or
    name:find(FX_NAME_OLD, 1, true) or
    name:find(FX_NAME_OLDER, 1, true) or
    name:find(FX_NAME_CLEAN, 1, true) or
    name:find(FX_NAME_LEGACY, 1, true)
end

local function find_fx(track)
  if not track then return -1 end
  for fx = 0, reaper.TrackFX_GetCount(track) - 1 do
    local ok, name = reaper.TrackFX_GetFXName(track, fx, "")
    if ok and fx_name_matches(name) then return fx end
  end
  return -1
end

local function add_named_jsfx(track, name)
  local fx = reaper.TrackFX_AddByName(track, "JS: " .. name, false, -1)
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, name, false, -1) end
  return fx
end

local function capture_normalized_params(track, fx)
  if not track or fx < 0 then return nil end
  local values = {}
  for param = 0, reaper.TrackFX_GetNumParams(track, fx) - 1 do
    values[param] = reaper.TrackFX_GetParamNormalized(track, fx, param)
  end
  return values
end

local function restore_normalized_params(track, fx, values)
  if not values or not track or fx < 0 then return end
  local count = reaper.TrackFX_GetNumParams(track, fx)
  for param, value in pairs(values) do
    if param < count then
      reaper.TrackFX_SetParamNormalized(track, fx, param, value)
    end
  end
end

local function get_track_channels(track)
  if not track then return 2 end
  return clamp(math.floor(reaper.GetMediaTrackInfo_Value(track, "I_NCHAN") + 0.5), 2, MAX_CH)
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

local function clear_pin_all_blocks(track, fx, side, source_ch)
  for block = 0, 1 do
    set_pin_mapping_block(track, fx, side, source_ch, block, 0, 0)
  end
end

local function repair_stereo_output_pins(track, fx, active_ch, force)
  if not track or fx < 0 then return end
  active_ch = clamp(math.floor((active_ch or 2) + 0.5), 2, MAX_CH)
  if not force and last_pin_track == track and last_pin_fx == fx and last_pin_ch == active_ch then return end
  for ch = 1, MAX_CH do
    if ch <= active_ch then
      set_pin_single(track, fx, 0, ch, ch)
    else
      clear_pin_all_blocks(track, fx, 0, ch)
    end

    if ch <= 2 then
      set_pin_single(track, fx, 1, ch, ch)
    else
      clear_pin_all_blocks(track, fx, 1, ch)
    end
  end
  last_pin_track, last_pin_fx, last_pin_ch = track, fx, active_ch
end

local function maybe_load(track, force)
  if not track then return -1 end
  local track_ch = get_track_channels(track)
  local fx = find_fx(track)
  if fx >= 0 and force then
    local _, _, output_pins = reaper.TrackFX_GetIOSize(track, fx)
    if (output_pins or 0) ~= 2 then
      local values = capture_normalized_params(track, fx)
      reaper.TrackFX_Delete(track, fx)
      fx = add_named_jsfx(track, FX_NAME)
      restore_normalized_params(track, fx, values)
    end
  end
  if fx >= 0 and not force then
    repair_stereo_output_pins(track, fx, track_ch, false)
    return fx
  end
  if fx < 0 then fx = add_named_jsfx(track, FX_NAME) end
  if fx < 0 then fx = add_named_jsfx(track, FX_NAME_OLD) end
  if fx < 0 then fx = add_named_jsfx(track, FX_NAME_OLDER) end
  if fx < 0 then fx = add_named_jsfx(track, FX_NAME_CLEAN) end
  if fx < 0 then fx = add_named_jsfx(track, FX_NAME_LEGACY) end
  if fx >= 0 then
    repair_stereo_output_pins(track, fx, track_ch, true)
  end
  return fx
end

local function get_param(track, fx, param, fallback)
  if fx < 0 then return fallback end
  local value = reaper.TrackFX_GetParamNormalized(track, fx, param)
  local _, min_value, max_value = reaper.TrackFX_GetParam(track, fx, param)
  if min_value and max_value and max_value ~= min_value then
    return min_value + value * (max_value - min_value)
  end
  return fallback
end

local function set_param(track, fx, param, value)
  local _, min_value, max_value = reaper.TrackFX_GetParam(track, fx, param)
  if not min_value or not max_value or max_value == min_value then return end
  value = clamp(value, min_value, max_value)
  reaper.TrackFX_SetParamNormalized(track, fx, param, (value - min_value) / (max_value - min_value))
end

local function slider_param(track, fx, label, param, min_value, max_value, fmt)
  local value = get_param(track, fx, param, min_value)
  local changed, new_value = theme.slider_double(ImGui, ctx, label, value, min_value, max_value, fmt, 360)
  if changed then set_param(track, fx, param, new_value) end
  return new_value or value
end

local function combo_param(track, fx, label, param, labels)
  local current = math.floor(get_param(track, fx, param, 0) + 0.5) + 1
  local changed, next_value = theme.combo_row(ImGui, ctx, label, labels, current, 210)
  if changed then set_param(track, fx, param, (next_value or current) - 1) end
  return (next_value or current) - 1
end

local function draw_stereo_meter(track, x, y, w, h)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, STYLE.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, STYLE.edge)
  ImGui.DrawList_AddText(draw_list, x + 10, y + 8, STYLE.text, "STEREO OUTPUT")

  local labels = { "L", "R" }
  for ch = 0, 1 do
    local meter_x = x + 18 + ch * 38
    local meter_y = y + 34
    local meter_h = h - 52
    local norm = peak_to_norm(reaper.Track_GetPeakInfo(track, ch) or 0)
    ImGui.DrawList_AddRectFilled(draw_list, meter_x, meter_y, meter_x + 22, meter_y + meter_h, STYLE.bg)
    ImGui.DrawList_AddRectFilled(draw_list, meter_x, meter_y + meter_h * (1 - norm), meter_x + 22, meter_y + meter_h, STYLE.meter)
    ImGui.DrawList_AddRect(draw_list, meter_x, meter_y, meter_x + 22, meter_y + meter_h, STYLE.edge)
    ImGui.DrawList_AddText(draw_list, meter_x + 6, meter_y + meter_h + 5, STYLE.muted, labels[ch + 1])
  end
end

local function layout_label(layout)
  if layout > 7 then return LAYOUT[1] end
  return LAYOUT[layout + 1] or LAYOUT[1]
end

local function wrap_degrees(deg)
  local wrapped = deg - math.floor(deg / 360) * 360
  if wrapped > 180 then wrapped = wrapped - 360 end
  return wrapped
end

local function ring_pos(index, count, start_az, el)
  return wrap_degrees(start_az + index * 360 / math.max(1, count)), el
end

local function cube_pos(index)
  local slot = index % 8
  local az = ({ 45, 135, -135, -45, 45, 135, -135, -45 })[slot + 1]
  local el = slot < 4 and -35.2644 or 35.2644
  return az, el
end

local function dodeca_pos(index)
  local points = {
    { -31.717474, 0 }, { 31.717474, 0 }, { -148.282526, 0 }, { 148.282526, 0 },
    { 180, 58.282526 }, { 0, 58.282526 }, { 180, -58.282526 }, { 0, -58.282526 },
    { 90, -31.717474 }, { 90, 31.717474 }, { -90, -31.717474 }, { -90, 31.717474 },
  }
  local point = points[(index % 12) + 1]
  return point[1], point[2]
end

local function dome24_pos(index)
  local slot = index % 24
  if slot < 12 then return ring_pos(slot, 12, 30, 0) end
  if slot < 20 then return ring_pos(slot - 12, 8, 45, 32) end
  return ring_pos(slot - 20, 4, 90, 66.6)
end

local function sphere_pos(index, count)
  if count == 8 then return cube_pos(index) end
  if count == 12 then return dodeca_pos(index) end
  if count == 16 then
    if index < 8 then return ring_pos(index, 8, 30, -32) end
    return ring_pos(index - 8, 8, 30, 32)
  end
  if count == 24 then return dome24_pos(index) end
  if count == 25 then
    if index < 24 then return dome24_pos(index) end
    return 0, 90
  end
  local frac = (index + 0.5) / math.max(1, count)
  local z = 1 - 2 * frac
  return wrap_degrees(30 + index * 137.507764), math.deg(math.asin(z))
end

local function hemisphere_pos(index, count)
  if count == 16 then
    if index < 8 then return ring_pos(index, 8, 30, 0) end
    return ring_pos(index - 8, 8, 30, 45)
  end
  if count == 24 or count == 25 then return dome24_pos(index) end
  local frac = (index + 0.5) / math.max(1, count)
  return wrap_degrees(30 + index * 360 / math.max(1, count)), 65 * frac
end

local function projection_pan_gain(index, count, width, rotation_deg, layout, weight, attenuation)
  local az, el
  if layout == 5 then
    az, el = sphere_pos(index, count)
  elseif layout == 6 then
    az, el = hemisphere_pos(index, count)
  else
    az, el = cube_pos(index)
  end

  local azr = math.rad(az + rotation_deg)
  local frontness = (math.cos(azr) + 1) * 0.5
  local rear = 1 - frontness
  local heightness = math.abs(el) / 90
  local atten = attenuation * weight
  local gain
  if layout == 6 then
    gain = 1 - atten * (heightness * 0.55 + rear * 0.22)
  elseif layout == 7 then
    gain = 1 - atten * (heightness * 0.38 + rear * 0.30)
  else
    gain = 1 - atten * (heightness * 0.42 + rear * 0.24)
  end
  local pan = math.sin(azr) * width * (frontness + (1 - frontness) * weight)
  return clamp(pan, -1, 1), clamp(gain, 0.15, 1)
end

local function projection_position(index, count, layout, rotation_deg)
  local zero_index = index - 1
  local az, el
  if layout == 5 then
    az, el = sphere_pos(zero_index, count)
  elseif layout == 6 then
    az, el = hemisphere_pos(zero_index, count)
  elseif layout == 7 then
    az, el = cube_pos(zero_index)
  else
    return nil
  end
  local azr = math.rad(az + rotation_deg)
  return {
    az = az,
    el = el,
    frontness = (math.cos(azr) + 1) * 0.5,
  }
end

local function pan_gain_for_channel(index, count, width_percent, rotation_deg, layout, weight_percent, attenuation_percent)
  if layout > 7 then layout = 0 end
  local width = math.max(0, width_percent / 100)
  local weight = clamp((weight_percent or 100) / 100, 0, 1)
  local attenuation = clamp((attenuation_percent or 45) / 100, 0, 1)
  local zero_index = index - 1
  local angle = math.rad(rotation_deg) + ((2 * math.pi * zero_index) / count)
  local pan

  if layout == 0 then
    local frontness = (math.cos(angle) + 1) * 0.5
    local rear_fold = frontness + (1 - frontness) * weight
    pan = math.sin(angle) * width * rear_fold
  elseif layout == 1 then
    local rotated_index = (zero_index + ((rotation_deg / 360) * count)) % count
    if count <= 1 then
      pan = 0
    else
      pan = -1 + ((2 * rotated_index) / (count - 1))
    end
    pan = pan * width * weight
  elseif layout == 2 then
    pan = (zero_index % 2 == 0 and -1 or 1) * width * weight
  elseif layout == 3 then
    local center = (count - 1) * 0.5
    local offset = zero_index - center
    local rank = math.floor(math.abs(offset) + 0.5)
    local side = offset < 0 and -1 or 1
    if rank == 0 then
      pan = 0
    else
      pan = side * (rank / math.max(1, center)) * width * weight
    end
  elseif layout == 4 then
    local pair = math.floor(zero_index / 2)
    local pair_count = math.max(1, math.floor((count + 1) / 2))
    local pair_pos = pair_count <= 1 and 0 or -1 + ((2 * pair) / (pair_count - 1))
    local pair_width = zero_index % 2 == 0 and -0.16 or 0.16
    pan = (pair_pos * 0.82 + pair_width) * width * weight
  else
    return projection_pan_gain(zero_index, count, width, rotation_deg, layout, weight, attenuation)
  end

  return clamp(pan, -1, 1), 1
end

local function label_interval(count)
  if count <= 24 then return 1 end
  if count <= 32 then return 4 end
  if count <= 48 then return 6 end
  return 8
end

local function should_label_channel(index, count)
  local interval = label_interval(count)
  return index == 1 or index == count or ((index - 1) % interval == 0)
end

local function equal_power_lr(pan)
  local theta = (pan + 1) * math.pi / 4
  return math.cos(theta), math.sin(theta)
end

local function autogain_label(mode, count)
  if mode == 1 then return string.format("x %.3f power", 1 / math.sqrt(math.max(1, count))) end
  if mode == 2 then return string.format("x %.3f energy", 1 / math.max(1, count)) end
  return "x 1.000"
end

local function draw_downmix_map(track, fx, width)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = width or math.max(520, ImGui.GetContentRegionAvail(ctx))
  local h = 220
  local input_count = math.floor(get_param(track, fx, PARAM.input_channels, 8) + 0.5)
  local width_percent = get_param(track, fx, PARAM.width, 100)
  local rotation_deg = get_param(track, fx, PARAM.rotation, 0)
  local layout = math.floor(get_param(track, fx, PARAM.layout, 0) + 0.5)
  local weight_percent = get_param(track, fx, PARAM.weight, 100)
  local attenuation_percent = get_param(track, fx, PARAM.attenuation, 45)
  local autogain = math.floor(get_param(track, fx, PARAM.autogain, 1) + 0.5)

  ImGui.InvisibleButton(ctx, "##downmix_map", w, h)
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, STYLE.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, STYLE.edge)
  ImGui.DrawList_AddText(draw_list, x + 12, y + 10, STYLE.text, "DOWNMIX MAP")
  ImGui.DrawList_AddText(draw_list, x + 120, y + 10, STYLE.muted,
    string.format("%d inputs / %s / width %.0f%% / weight %.0f%% / 3D %.0f%% / rot %.0f / %s",
      input_count, layout_label(layout), width_percent, weight_percent, attenuation_percent,
      rotation_deg, autogain_label(autogain, input_count)))

  local left_x = x + 58
  local right_x = x + w - 58
  local speaker_y = y + h - 34
  local center_x = x + w * 0.5
  local map_y = y + 76
  local map_w = w - 150
  local map_left = x + 75
  local projection_mode = layout >= 5 and layout <= 7

  ImGui.DrawList_AddCircleFilled(draw_list, left_x, speaker_y, 18, color(0.18, 0.36, 0.46, 1), 32)
  ImGui.DrawList_AddCircleFilled(draw_list, right_x, speaker_y, 18, color(0.18, 0.36, 0.46, 1), 32)
  ImGui.DrawList_AddText(draw_list, left_x - 4, speaker_y - 8, STYLE.text, "L")
  ImGui.DrawList_AddText(draw_list, right_x - 4, speaker_y - 8, STYLE.text, "R")
  ImGui.DrawList_AddLine(draw_list, map_left, map_y, map_left + map_w, map_y, color(0.54, 0.60, 0.62, 0.22), 1)
  ImGui.DrawList_AddLine(draw_list, center_x, map_y - 22, center_x, map_y + 22, color(0.54, 0.60, 0.62, 0.18), 1)
  if projection_mode then
    ImGui.DrawList_AddLine(draw_list, map_left, map_y - 54, map_left + map_w, map_y - 54, color(0.54, 0.60, 0.62, 0.10), 1)
    ImGui.DrawList_AddLine(draw_list, map_left, map_y + 54, map_left + map_w, map_y + 54, color(0.54, 0.60, 0.62, 0.10), 1)
    ImGui.DrawList_AddText(draw_list, map_left - 42, map_y - 61, STYLE.muted, "HIGH")
    ImGui.DrawList_AddText(draw_list, map_left - 38, map_y - 7, STYLE.muted, "MID")
    ImGui.DrawList_AddText(draw_list, map_left - 38, map_y + 47, STYLE.muted, "LOW")
  end

  local weight_norm = clamp(weight_percent / 100, 0, 1)
  local atten_norm = clamp(attenuation_percent / 100, 0, 1)
  local rail_y = y + h - 67
  local rail_x = map_left
  local rail_w = map_w
  ImGui.DrawList_AddText(draw_list, rail_x, rail_y - 26, STYLE.muted, "LAYOUT WEIGHT")
  ImGui.DrawList_AddRect(draw_list, rail_x, rail_y - 9, rail_x + rail_w * 0.45, rail_y - 2, color(0.54, 0.60, 0.62, 0.20))
  ImGui.DrawList_AddRectFilled(draw_list, rail_x, rail_y - 9, rail_x + rail_w * 0.45 * weight_norm, rail_y - 2, color(0.24, 0.58, 0.66, 0.65))
  ImGui.DrawList_AddText(draw_list, rail_x + rail_w * 0.52, rail_y - 26, STYLE.muted, "3D ATTENUATION")
  ImGui.DrawList_AddRect(draw_list, rail_x + rail_w * 0.52, rail_y - 9, rail_x + rail_w * 0.97, rail_y - 2, color(0.54, 0.60, 0.62, 0.20))
  ImGui.DrawList_AddRectFilled(draw_list, rail_x + rail_w * 0.52, rail_y - 9, rail_x + rail_w * (0.52 + 0.45 * atten_norm), rail_y - 2, color(0.95, 0.46, 0.34, 0.58))

  for index = 1, input_count do
    local pan, projection_gain = pan_gain_for_channel(index, input_count, width_percent, rotation_deg, layout, weight_percent, attenuation_percent)
    local reference_pan = pan_gain_for_channel(index, input_count, width_percent, rotation_deg, layout, 100, 0)
    local left_gain, right_gain = equal_power_lr(pan)
    local src_x = map_left + ((pan + 1) * 0.5) * map_w
    local ref_x = map_left + ((reference_pan + 1) * 0.5) * map_w
    local row = (index - 1) % 3
    local src_y = map_y - 22 + row * 18
    local info = projection_position(index, input_count, layout, rotation_deg)
    if info then
      local rear_offset = (1 - info.frontness) * 14
      src_y = map_y - (info.el / 90) * 54 + rear_offset
    end
    local dot = input_count <= 16 and 5 or (input_count <= 32 and 4.2 or 3.4)
    local attenuation_visibility = projection_mode and (projection_gain ^ 1.8) or projection_gain
    local alpha = (input_count <= 24 and 0.42 or 0.24) * attenuation_visibility
    local labeled = should_label_channel(index, input_count)
    local label_color = labeled and STYLE.text or STYLE.muted

    ImGui.DrawList_AddCircle(draw_list, ref_x, src_y, dot + 2, color(0.84, 0.88, 0.90, 0.16), 12, 1)
    if math.abs(ref_x - src_x) > 2 then
      ImGui.DrawList_AddLine(draw_list, ref_x, src_y, src_x, src_y, color(0.84, 0.88, 0.90, 0.16), 1)
    end
    ImGui.DrawList_AddLine(draw_list, src_x, src_y + 5, left_x, speaker_y - 18,
      color(0.24, 0.58, 0.66, alpha * left_gain), 1 + left_gain * 1.5)
    ImGui.DrawList_AddLine(draw_list, src_x, src_y + 5, right_x, speaker_y - 18,
      color(0.46, 0.86, 0.56, alpha * right_gain), 1 + right_gain * 1.5)
    local dot_scale = projection_mode and (0.18 + 0.82 * (projection_gain ^ 1.65)) or (0.72 + projection_gain * 0.28)
    ImGui.DrawList_AddCircleFilled(draw_list, src_x, src_y, dot * dot_scale, STYLE.fill, 16)
    if projection_mode and projection_gain < 0.82 then
      ImGui.DrawList_AddCircle(draw_list, src_x, src_y, dot + 3, color(0.95, 0.46, 0.34, 0.28 * (1 - projection_gain)), 16, 1.2)
    end
    if labeled then
      local label_y = src_y + (row == 2 and 8 or -14)
      ImGui.DrawList_AddText(draw_list, src_x + 5, label_y, label_color, tostring(index))
    end
  end

  ImGui.DrawList_AddText(draw_list, map_left - 8, map_y + 30, STYLE.muted, "L")
  ImGui.DrawList_AddText(draw_list, center_x - 5, map_y + 30, STYLE.muted, "C")
  ImGui.DrawList_AddText(draw_list, map_left + map_w - 8, map_y + 30, STYLE.muted, "R")
end

local function draw_output_gain(track, fx, width)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w, h = width or OUTPUT_W, 220
  local db = get_param(track, fx, PARAM.output_gain, 0)
  local norm = db_to_norm(db)

  ImGui.InvisibleButton(ctx, "##output_gain_fader", w, h)
  local hovered = ImGui.IsItemHovered(ctx)
  if hovered and ImGui.IsMouseDragging(ctx, 0) then
    local _, my = ImGui.GetMousePos(ctx)
    local pos = clamp(1 - ((my - (y + 30)) / 145), 0, 1)
    set_param(track, fx, PARAM.output_gain, -24 + pos * 48)
  elseif hovered and ImGui.IsMouseDoubleClicked(ctx, 0) then
    set_param(track, fx, PARAM.output_gain, 0)
  end

  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, STYLE.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, STYLE.edge)
  ImGui.DrawList_AddText(draw_list, x + 12, y + 8, STYLE.text, "OUTPUT")

  local fx0, fy0 = x + 32, y + 34
  local fw, fh = 24, 145
  ImGui.DrawList_AddRectFilled(draw_list, fx0, fy0, fx0 + fw, fy0 + fh, STYLE.bg)
  ImGui.DrawList_AddRectFilled(draw_list, fx0, fy0 + fh * (1 - norm), fx0 + fw, fy0 + fh, STYLE.fill)
  ImGui.DrawList_AddRect(draw_list, fx0, fy0, fx0 + fw, fy0 + fh, STYLE.edge)
  local unity_y = fy0 + fh * (1 - db_to_norm(0))
  ImGui.DrawList_AddLine(draw_list, fx0 - 5, unity_y, fx0 + fw + 5, unity_y, STYLE.text, 1.2)
  ImGui.DrawList_AddText(draw_list, x + 18, y + 184, STYLE.text, string.format("%+.1f", db))
  ImGui.DrawList_AddText(draw_list, x + 31, y + 202, STYLE.muted, "dB")
end

local function loop()
  ImGui.SetNextWindowSize(ctx, CONTENT_W + 18, 760, ImGui.Cond_Always)
  local visible
  visible, open = ImGui.Begin(ctx, "MC to Stereo Autogain", open)

  if visible then
    local track = reaper.GetSelectedTrack(PROJECT, 0)
    if not track then
      theme.muted(ImGui, ctx, "NO SELECTED TRACK.")
    else
      local _, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
      local track_ch = get_track_channels(track)
      theme.muted(ImGui, ctx, "TARGET: " .. (track_name ~= "" and track_name or "(UNNAMED)"))
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "LOAD / REPAIR JSFX") then maybe_load(track, true) end
      ImGui.SameLine(ctx)
      theme.muted(ImGui, ctx, tostring(track_ch) .. "ch")

      local fx = maybe_load(track, false)
      if fx < 0 then
        theme.status(ImGui, ctx, "Could not load JS: " .. FX_NAME, "warn")
      else
        local input_ch = math.floor(get_param(track, fx, PARAM.input_channels, math.min(track_ch, MAX_CH)) + 0.5)
        if ImGui.Button(ctx, "USE TRACK CHANNELS") then
          set_param(track, fx, PARAM.input_channels, math.min(track_ch, MAX_CH))
        end
        ImGui.SameLine(ctx)
        theme.muted(ImGui, ctx, "Input channels: " .. tostring(input_ch))

        ImGui.Separator(ctx)
        draw_downmix_map(track, fx, CONTENT_W)
        ImGui.Spacing(ctx)
        ImGui.BeginGroup(ctx)
          local panel_stack = theme.push_soft_panel(ImGui, ctx)
          ImGui.BeginChild(ctx, "##autogain_controls", CONTROL_W, 220)
          slider_param(track, fx, "Input channels", PARAM.input_channels, 2, MAX_CH, "%.0f")
          slider_param(track, fx, "Spread / width", PARAM.width, 0, 200, "%.0f%%")
          slider_param(track, fx, "Rotation", PARAM.rotation, -180, 180, "%.0f deg")
          combo_param(track, fx, "Layout", PARAM.layout, LAYOUT)
          slider_param(track, fx, "Layout weighting", PARAM.weight, 0, 100, "%.0f%%")
          slider_param(track, fx, "3D attenuation", PARAM.attenuation, 0, 100, "%.0f%%")
          combo_param(track, fx, "Autogain", PARAM.autogain, AUTOGAIN)
          ImGui.Spacing(ctx)
          if ImGui.Button(ctx, "-6 DB") then set_param(track, fx, PARAM.output_gain, -6) end
          ImGui.SameLine(ctx)
          if ImGui.Button(ctx, "UNITY") then set_param(track, fx, PARAM.output_gain, 0) end
          ImGui.SameLine(ctx)
          if ImGui.Button(ctx, "+3 DB") then set_param(track, fx, PARAM.output_gain, 3) end
          ImGui.EndChild(ctx)
          theme.pop_soft_panel(ImGui, ctx, panel_stack)
        ImGui.EndGroup(ctx)

        ImGui.SameLine(ctx)
        ImGui.BeginGroup(ctx)
          draw_output_gain(track, fx, OUTPUT_W)
        ImGui.EndGroup(ctx)

        ImGui.SameLine(ctx)
        local x, y = ImGui.GetCursorScreenPos(ctx)
        draw_stereo_meter(track, x, y, METER_W, 220)
        ImGui.Dummy(ctx, METER_W, 220)
      end
    end
    ImGui.End(ctx)
  end

  if open then reaper.defer(loop) end
end

reaper.defer(loop)
