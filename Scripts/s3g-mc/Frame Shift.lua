-- @description Frame Shift
-- @author s3g
-- @version 0.2
-- @requires ReaImGui; Multichannel Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; bounds to source item length.
-- @method ReaImGui controller for rendering channel-frame rotation, mirror, odd/even split, pair interleave, or half-swap maps.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Frame Shift", 0)
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

local MODES = {
  [1] = "Rotate",
  [2] = "Mirror",
  [3] = "Odd/even split",
  [4] = "Pair interleave",
  [5] = "Swap halves",
}

local function map_for_mode(mode, channel_count, offset)
  if mode == 1 then return mc.rotate_map(channel_count, offset), "Frame rotate" end
  if mode == 2 then return mc.mirror_map(channel_count), "Frame mirror" end
  if mode == 3 then return mc.odd_even_map(channel_count), "Frame odd even" end
  if mode == 4 then return mc.interleave_pairs_map(channel_count), "Frame interleave" end
  return mc.swap_halves_map(channel_count), "Frame swap halves"
end

local ROW_H = 25
local LABEL_W = 86
local CONTROL_GAP = 8
local VALUE_W = 76

local LABEL_ABBR = {
  ["ROTATE OFFSET"] = "OFFSET",
}

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function row_label_text(label)
  local upper = tostring(label or ""):upper()
  return LABEL_ABBR[upper] or upper
end

local function row_layout(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local avail = ImGui.GetContentRegionAvail(ctx)
  if type(avail) ~= "number" then avail = 340 end
  local control_x = x + LABEL_W
  local control_w = math.max(120, avail - LABEL_W - CONTROL_GAP)
  return x, y, control_x, control_w
end

local function text_width(ctx, text)
  text = tostring(text or "")
  if ImGui.CalcTextSize then
    local ok, width = pcall(ImGui.CalcTextSize, ctx, text)
    if ok and type(width) == "number" then return width end
  end
  return #text * 7
end

local function combo_width(ctx, labels, current, max_width)
  local width = text_width(ctx, labels[current or 1] or "") + 38
  for _, label in ipairs(labels or {}) do
    width = math.max(width, text_width(ctx, label) + 38)
  end
  return math.max(80, math.min(max_width or width, width))
end

local function row_label(ctx, x, y, label)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 4, THEME.label, row_label_text(label))
end

local function finish_row(ctx, x, y)
  ImGui.SetCursorScreenPos(ctx, x, y + ROW_H)
end

local function draw_custom_slider(ctx, label, value, lo, hi, fmt, integer)
  local x, y, control_x, control_w = row_layout(ctx)
  local slider_w = math.max(80, control_w - VALUE_W - CONTROL_GAP)
  local value_x = control_x + slider_w + CONTROL_GAP
  local track_y = y + 8
  local track_h = 8
  local norm = hi ~= lo and clamp((value - lo) / (hi - lo), 0, 1) or 0

  row_label(ctx, x, y, label)
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
  ImGui.DrawList_AddText(draw, value_x, y + 4, THEME.value, integer and tostring(math.floor(value + 0.5)) or string.format(fmt or "%.3f", value))
  finish_row(ctx, x, y)
  return changed, value
end

local function draw_combo(ctx, label, value)
  local x, y, control_x, control_w = row_layout(ctx)
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, combo_width(ctx, MODES, value, control_w))
  if ImGui.BeginCombo(ctx, "##" .. label, MODES[value]) then
    for index = 1, #MODES do
      local selected = value == index
      if ImGui.Selectable(ctx, MODES[index], selected) then value = index end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  finish_row(ctx, x, y)
  return value
end

local function section(ctx, label, height)
  local stack = theme.push_soft_panel(ImGui, ctx)
  local draw = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + height, THEME.panel_soft)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + 2, THEME.active)
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 10)
  theme.text(ImGui, ctx, label:upper())
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 36)
  return x, y, height, stack
end

local function finish_section(ctx, x, y, height, stack)
  theme.pop_soft_panel(ImGui, ctx, stack)
  ImGui.SetCursorScreenPos(ctx, x, y + height + 10)
  ImGui.Dummy(ctx, 1, 1)
end

local function main()
  local item, take, channel_count = mc.require_selected_multichannel_item()
  if not item then return end

  local ctx = ImGui.CreateContext("Frame Shift")
  local open = true
  local mode = 1
  local offset = 1
  local should_render = false

  local function loop()
    ImGui.SetNextWindowSize(ctx, 420, 520, ImGui.Cond_Appearing)
    local visible
    visible, open = ImGui.Begin(ctx, "Frame Shift", open)
    if visible then
      theme.muted(ImGui, ctx, "Source: " .. mc.item_label(item) .. "  (" .. tostring(channel_count) .. " ch)")
      ImGui.Spacing(ctx)
      local sx, sy, sh, stack = section(ctx, "Settings", 126)
      mode = draw_combo(ctx, "Mode", mode)
      if mode == 1 then
        local changed
        changed, offset = draw_custom_slider(ctx, "Rotate offset", offset, -channel_count + 1, channel_count - 1, nil, true)
      else
        theme.muted(ImGui, ctx, "Offset is not used by this mode.")
      end
      local map, label = map_for_mode(mode, channel_count, offset)
      theme.muted(ImGui, ctx, "Map: " .. mc.describe_map(map))
      finish_section(ctx, sx, sy, sh, stack)
      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Spacing(ctx)
      if ImGui.Button(ctx, "RENDER", 92, 26) then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "CANCEL", 92, 26) then open = false end
      ImGui.End(ctx)
    end

    if should_render then
      local map, label = map_for_mode(mode, channel_count, offset)
      open = false
      reaper.Undo_BeginBlock()
      local did_render = mc.with_ui_refresh_block(function()
        return mc.build_multichannel_render_from_item(item, channel_count, map, label, { mute_source_item = true })
      end)
      reaper.Undo_EndBlock(label, -1)
      if did_render then mc.print_plan(label, mc.render_plan_for_item(item, channel_count, map, label)) end
      return
    end

    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
