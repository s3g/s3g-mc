-- @description MC to Stereo Autogain
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; JSFX: s3g MC to Stereo Autogain
-- @category Channel Mixing / Automation
-- @method Auto-loads the JSFX and folds a multichannel track to stereo using selectable layouts, width/rotation, layout weighting, autogain, and output gain.
-- @about
--   ReaImGui control surface for JS: s3g MC to Stereo Autogain. Downmixes a
--   multichannel track to stereo with width, rotation, layout, output gain,
--   and autogain controls.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "MC to Stereo Autogain", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local PROJECT = 0
local FX_NAME = "s3g MC to Stereo Autogain"
local FX_NAME_OLD = "s3g Stereo Autogain"
local FX_NAME_OLDER = "s3g MC Stereo Autogain"
local FX_NAME_CLEAN = "MC Stereo Autogain"
local FX_NAME_LEGACY = "s3g/MC Stereo Autogain"

local PARAM = {
  input_channels = 0,
  width = 1,
  rotation = 2,
  autogain = 3,
  output_gain = 4,
  layout = 5,
  extra = 6,
  weight = 7,
}

local AUTOGAIN = { "Off", "Power/sqrt(N)", "Energy sum" }
local LAYOUT = {
  "Ring projection",
  "Linear left-right",
  "Odd/even stereo",
  "Center-out",
  "Pair-preserving",
}
local EXTRA = { "Keep extra channels", "Clear extra channels" }

local ctx = ImGui.CreateContext("MC to Stereo Autogain")
local open = true

local COLORS = {
  bg = ImGui.ColorConvertDouble4ToU32(0.055, 0.060, 0.065, 1),
  panel = ImGui.ColorConvertDouble4ToU32(0.075, 0.082, 0.088, 1),
  edge = ImGui.ColorConvertDouble4ToU32(0.29, 0.31, 0.33, 1),
  text = ImGui.ColorConvertDouble4ToU32(0.78, 0.82, 0.84, 1),
  muted = ImGui.ColorConvertDouble4ToU32(0.48, 0.52, 0.54, 1),
  fill = ImGui.ColorConvertDouble4ToU32(0.24, 0.58, 0.66, 1),
  meter = ImGui.ColorConvertDouble4ToU32(0.46, 0.86, 0.56, 1),
  warn = ImGui.ColorConvertDouble4ToU32(0.95, 0.46, 0.34, 1),
  active = ImGui.ColorConvertDouble4ToU32(0.16, 0.63, 0.38, 1),
  button = ImGui.ColorConvertDouble4ToU32(0.12, 0.13, 0.14, 1),
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

local function maybe_load(track, force)
  if not track then return -1 end
  local fx = find_fx(track)
  if fx >= 0 and not force then return fx end
  if fx < 0 then fx = add_named_jsfx(track, FX_NAME) end
  if fx < 0 then fx = add_named_jsfx(track, FX_NAME_OLD) end
  if fx < 0 then fx = add_named_jsfx(track, FX_NAME_OLDER) end
  if fx < 0 then fx = add_named_jsfx(track, FX_NAME_CLEAN) end
  if fx < 0 then fx = add_named_jsfx(track, FX_NAME_LEGACY) end
  return fx
end

local function get_track_channels(track)
  if not track then return 2 end
  return clamp(math.floor(reaper.GetMediaTrackInfo_Value(track, "I_NCHAN") + 0.5), 2, 128)
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

local function option_buttons(track, fx, title, param, labels, columns)
  local current = math.floor(get_param(track, fx, param, 0) + 0.5)
  columns = columns or #labels
  ImGui.TextColored(ctx, COLORS.muted, title)
  for index, label in ipairs(labels) do
    if index > 1 and ((index - 1) % columns) ~= 0 then ImGui.SameLine(ctx) end
    local value = index - 1
    if current == value then
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, COLORS.active)
    else
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, COLORS.button)
    end
    if ImGui.Button(ctx, label .. "##" .. title .. tostring(index)) then
      set_param(track, fx, param, value)
    end
    ImGui.PopStyleColor(ctx)
  end
end

local function slider_param(track, fx, label, param, min_value, max_value, fmt)
  local value = get_param(track, fx, param, min_value)
  ImGui.SetNextItemWidth(ctx, 310)
  local changed, new_value = ImGui.SliderDouble(ctx, label, value, min_value, max_value, fmt)
  if changed then set_param(track, fx, param, new_value) end
  return new_value or value
end

local function draw_stereo_meter(track, x, y, w, h)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, COLORS.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, COLORS.edge)
  ImGui.DrawList_AddText(draw_list, x + 10, y + 8, COLORS.text, "Stereo output")

  local labels = { "L", "R" }
  for ch = 0, 1 do
    local meter_x = x + 18 + ch * 38
    local meter_y = y + 34
    local meter_h = h - 52
    local norm = peak_to_norm(reaper.Track_GetPeakInfo(track, ch) or 0)
    ImGui.DrawList_AddRectFilled(draw_list, meter_x, meter_y, meter_x + 22, meter_y + meter_h, COLORS.bg)
    ImGui.DrawList_AddRectFilled(draw_list, meter_x, meter_y + meter_h * (1 - norm), meter_x + 22, meter_y + meter_h, COLORS.meter)
    ImGui.DrawList_AddRect(draw_list, meter_x, meter_y, meter_x + 22, meter_y + meter_h, COLORS.edge)
    ImGui.DrawList_AddText(draw_list, meter_x + 6, meter_y + meter_h + 5, COLORS.muted, labels[ch + 1])
  end
end

local function layout_label(layout)
  if layout > 4 then return LAYOUT[1] end
  return LAYOUT[layout + 1] or LAYOUT[1]
end

local function pan_for_channel(index, count, width_percent, rotation_deg, layout, weight_percent)
  if layout > 4 then layout = 0 end
  local width = math.max(0, width_percent / 100)
  local weight = clamp((weight_percent or 100) / 100, 0, 1)
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
  else
    local pair = math.floor(zero_index / 2)
    local pair_count = math.max(1, math.floor((count + 1) / 2))
    local pair_pos = pair_count <= 1 and 0 or -1 + ((2 * pair) / (pair_count - 1))
    local pair_width = zero_index % 2 == 0 and -0.16 or 0.16
    pan = (pair_pos * 0.82 + pair_width) * width * weight
  end

  return clamp(pan, -1, 1)
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

local function draw_downmix_map(track, fx)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(520, ImGui.GetContentRegionAvail(ctx))
  local h = 190
  local input_count = math.floor(get_param(track, fx, PARAM.input_channels, 8) + 0.5)
  local width_percent = get_param(track, fx, PARAM.width, 100)
  local rotation_deg = get_param(track, fx, PARAM.rotation, 0)
  local layout = math.floor(get_param(track, fx, PARAM.layout, 0) + 0.5)
  local weight_percent = get_param(track, fx, PARAM.weight, 100)
  local autogain = math.floor(get_param(track, fx, PARAM.autogain, 1) + 0.5)

  ImGui.InvisibleButton(ctx, "##downmix_map", w, h)
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, COLORS.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, COLORS.edge)
  ImGui.DrawList_AddText(draw_list, x + 12, y + 10, COLORS.text, "Downmix map")
  ImGui.DrawList_AddText(draw_list, x + 120, y + 10, COLORS.muted,
    string.format("%d inputs / %s / width %.0f%% / weight %.0f%% / rot %.0f / %s",
      input_count, layout_label(layout), width_percent, weight_percent, rotation_deg,
      autogain_label(autogain, input_count)))

  local left_x = x + 58
  local right_x = x + w - 58
  local speaker_y = y + h - 34
  local center_x = x + w * 0.5
  local map_y = y + 76
  local map_w = w - 150
  local map_left = x + 75

  ImGui.DrawList_AddCircleFilled(draw_list, left_x, speaker_y, 18, color(0.18, 0.36, 0.46, 1), 32)
  ImGui.DrawList_AddCircleFilled(draw_list, right_x, speaker_y, 18, color(0.18, 0.36, 0.46, 1), 32)
  ImGui.DrawList_AddText(draw_list, left_x - 4, speaker_y - 8, COLORS.text, "L")
  ImGui.DrawList_AddText(draw_list, right_x - 4, speaker_y - 8, COLORS.text, "R")
  ImGui.DrawList_AddLine(draw_list, map_left, map_y, map_left + map_w, map_y, color(0.54, 0.60, 0.62, 0.22), 1)
  ImGui.DrawList_AddLine(draw_list, center_x, map_y - 22, center_x, map_y + 22, color(0.54, 0.60, 0.62, 0.18), 1)

  for index = 1, input_count do
    local pan = pan_for_channel(index, input_count, width_percent, rotation_deg, layout, weight_percent)
    local left_gain, right_gain = equal_power_lr(pan)
    local src_x = map_left + ((pan + 1) * 0.5) * map_w
    local row = (index - 1) % 3
    local src_y = map_y - 22 + row * 18
    local dot = input_count <= 16 and 5 or 3.5
    local alpha = input_count <= 24 and 0.42 or 0.24

    ImGui.DrawList_AddLine(draw_list, src_x, src_y + 5, left_x, speaker_y - 18,
      color(0.24, 0.58, 0.66, alpha * left_gain), 1 + left_gain * 1.5)
    ImGui.DrawList_AddLine(draw_list, src_x, src_y + 5, right_x, speaker_y - 18,
      color(0.46, 0.86, 0.56, alpha * right_gain), 1 + right_gain * 1.5)
    ImGui.DrawList_AddCircleFilled(draw_list, src_x, src_y, dot, COLORS.fill, 16)
    if input_count <= 24 then
      ImGui.DrawList_AddText(draw_list, src_x + 5, src_y - 7, COLORS.muted, tostring(index))
    end
  end

  ImGui.DrawList_AddText(draw_list, map_left - 8, map_y + 30, COLORS.muted, "L")
  ImGui.DrawList_AddText(draw_list, center_x - 5, map_y + 30, COLORS.muted, "C")
  ImGui.DrawList_AddText(draw_list, map_left + map_w - 8, map_y + 30, COLORS.muted, "R")
end

local function draw_output_gain(track, fx)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w, h = 88, 220
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

  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, COLORS.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, COLORS.edge)
  ImGui.DrawList_AddText(draw_list, x + 12, y + 8, COLORS.text, "Output")

  local fx0, fy0 = x + 32, y + 34
  local fw, fh = 24, 145
  ImGui.DrawList_AddRectFilled(draw_list, fx0, fy0, fx0 + fw, fy0 + fh, COLORS.bg)
  ImGui.DrawList_AddRectFilled(draw_list, fx0, fy0 + fh * (1 - norm), fx0 + fw, fy0 + fh, COLORS.fill)
  ImGui.DrawList_AddRect(draw_list, fx0, fy0, fx0 + fw, fy0 + fh, COLORS.edge)
  local unity_y = fy0 + fh * (1 - db_to_norm(0))
  ImGui.DrawList_AddLine(draw_list, fx0 - 5, unity_y, fx0 + fw + 5, unity_y, COLORS.text, 1.2)
  ImGui.DrawList_AddText(draw_list, x + 18, y + 184, COLORS.text, string.format("%+.1f", db))
  ImGui.DrawList_AddText(draw_list, x + 31, y + 202, COLORS.muted, "dB")
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 760, 560, ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, "MC to Stereo Autogain", open)

  if visible then
    local track = reaper.GetSelectedTrack(PROJECT, 0)
    if not track then
      ImGui.Text(ctx, "No selected track.")
    else
      local _, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
      local track_ch = get_track_channels(track)
      ImGui.Text(ctx, "Selected track: " .. (track_name ~= "" and track_name or "(unnamed)"))
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Load/repair JSFX") then maybe_load(track, true) end
      ImGui.SameLine(ctx)
      ImGui.TextColored(ctx, COLORS.muted, tostring(track_ch) .. "ch")

      local fx = maybe_load(track, false)
      if fx < 0 then
        ImGui.TextColored(ctx, COLORS.warn, "Could not load JS: " .. FX_NAME)
      else
        local input_ch = math.floor(get_param(track, fx, PARAM.input_channels, math.min(track_ch, 64)) + 0.5)
        if ImGui.Button(ctx, "Use track channels") then
          set_param(track, fx, PARAM.input_channels, math.min(track_ch, 64))
        end
        ImGui.SameLine(ctx)
        ImGui.TextColored(ctx, COLORS.muted, "Input channels: " .. tostring(input_ch))

        ImGui.Separator(ctx)
        ImGui.BeginGroup(ctx)
          slider_param(track, fx, "Input channels", PARAM.input_channels, 2, 64, "%.0f")
          slider_param(track, fx, "Spread / width", PARAM.width, 0, 200, "%.0f%%")
          slider_param(track, fx, "Rotation", PARAM.rotation, -180, 180, "%.0f deg")
          option_buttons(track, fx, "Layout", PARAM.layout, LAYOUT, 2)
          slider_param(track, fx, "Layout weighting", PARAM.weight, 0, 100, "%.0f%%")
          option_buttons(track, fx, "Autogain", PARAM.autogain, AUTOGAIN)
          option_buttons(track, fx, "Extra channel output", PARAM.extra, EXTRA)
          ImGui.Spacing(ctx)
          if ImGui.Button(ctx, "-6 dB") then set_param(track, fx, PARAM.output_gain, -6) end
          ImGui.SameLine(ctx)
          if ImGui.Button(ctx, "Unity") then set_param(track, fx, PARAM.output_gain, 0) end
          ImGui.SameLine(ctx)
          if ImGui.Button(ctx, "+3 dB") then set_param(track, fx, PARAM.output_gain, 3) end
        ImGui.EndGroup(ctx)

        ImGui.SameLine(ctx)
        ImGui.BeginGroup(ctx)
          draw_output_gain(track, fx)
        ImGui.EndGroup(ctx)

        ImGui.SameLine(ctx)
        local x, y = ImGui.GetCursorScreenPos(ctx)
        draw_stereo_meter(track, x, y, 112, 220)
        ImGui.Dummy(ctx, 112, 220)
        ImGui.Spacing(ctx)
        draw_downmix_map(track, fx)
      end
    end
    ImGui.End(ctx)
  end

  if open then reaper.defer(loop) end
end

reaper.defer(loop)
