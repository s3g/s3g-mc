-- @description Vertical Timeline Navigator
-- @author s3g
-- @version 0.1
-- @requires ReaImGui
-- @category Channel Mixing / Automation
-- @method Lite vertical project navigator: time runs top-to-bottom, tracks run left-to-right, with media items, markers, regions, edit cursor, time selection, item moves, mouse scroll, and mouse zoom.
-- @about
--   A live ReaImGui viewer/controller for REAPER's project timeline. It does
--   not replace the arrange view; it provides a top-down companion view for
--   navigating items, markers, regions, edit cursor, and time selection.

local TITLE = "Vertical Timeline Navigator"
local EXT = "s3g_mc_vertical_timeline_navigator_v1"
local PROJECT = 0

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", TITLE, 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local ui_theme = nil
do
  local script_path = ({ reaper.get_action_context() })[2]
  local script_dir = script_path:match("^(.*[/\\])") or ""
  package.path = script_dir .. "?.lua;" .. package.path
  local ok, theme = pcall(require, "s3g-mc ImGui Theme")
  if ok and theme then
    ui_theme = theme
    if theme.install then theme.install(ImGui) end
  end
end

local ctx = ImGui.CreateContext(TITLE)
local open = true

local function getn(key, default)
  local value = tonumber(reaper.GetExtState(EXT, key))
  if value == nil then return default end
  return value
end

local function getb(key, default)
  local value = reaper.GetExtState(EXT, key)
  if value == "" then return default end
  return value ~= "0"
end

local seconds_per_pixel = getn("seconds_per_pixel", 0.05)
local view_start = getn("view_start", 0.0)
local track_start = math.floor(getn("track_start", 1))
local visible_tracks = math.floor(getn("visible_tracks", 12))
local follow_play = getb("follow_play", false)
local show_markers = getb("show_markers", true)
local show_regions = getb("show_regions", true)
local show_time_selection = getb("show_time_selection", true)
local snap_enabled = getb("snap_enabled", false)
local track_filter = math.floor(getn("track_filter", 1))
if track_filter < 1 or track_filter > 2 then track_filter = 1 end
local drag_select_start = nil
local item_drag = nil
local marker_drag = nil
local view_pan = nil
local play_visual_pos = nil
local play_visual_time = nil
local selected_marker = nil
local selected_marker_name = ""
local status = "Vertical timeline view. Time runs top-to-bottom."

local function set_ext(key, value)
  reaper.SetExtState(EXT, key, type(value) == "boolean" and (value and "1" or "0") or tostring(value), true)
end

local function persist()
  set_ext("seconds_per_pixel", seconds_per_pixel)
  set_ext("view_start", view_start)
  set_ext("track_start", track_start)
  set_ext("visible_tracks", visible_tracks)
  set_ext("follow_play", follow_play)
  set_ext("show_markers", show_markers)
  set_ext("show_regions", show_regions)
  set_ext("show_time_selection", show_time_selection)
  set_ext("snap_enabled", snap_enabled)
  set_ext("track_filter", track_filter)
end

local function clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

local function snap_pixel(value)
  return math.floor((tonumber(value) or 0) + 0.5)
end

local function rgba(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local function color_from_native(native_color)
  native_color = tonumber(native_color) or 0
  if native_color == 0 then return nil end
  local ok, r, g, b = pcall(reaper.ColorFromNative, native_color)
  if not ok or r == nil then return nil end
  return (r or 0) / 255, (g or 0) / 255, (b or 0) / 255
end

local function muted_native_color(native_color, alpha, fallback)
  local r, g, b = color_from_native(native_color)
  if not r then return fallback end
  local gray = (r + g + b) / 3
  local sat = 0.42
  local level = 0.78
  r = (gray + (r - gray) * sat) * level
  g = (gray + (g - gray) * sat) * level
  b = (gray + (b - gray) * sat) * level
  return rgba(r, g, b, alpha or 1)
end

local CANVAS = {
  bg = rgba(0.035, 0.038, 0.041, 1),
  panel = rgba(0.070, 0.074, 0.078, 1),
  edge = rgba(0.34, 0.36, 0.37, 1),
  grid = rgba(0.58, 0.62, 0.64, 0.12),
  text = rgba(0.82, 0.84, 0.82, 1),
  muted = rgba(0.52, 0.56, 0.56, 1),
  item = rgba(0.35, 0.36, 0.36, 0.86),
  item_sel = rgba(0.94, 0.72, 0.32, 0.96),
  region = rgba(0.45, 0.36, 0.65, 0.30),
  marker = rgba(0.88, 0.72, 0.36, 0.85),
  cursor = rgba(0.92, 0.92, 0.90, 1),
  play = rgba(0.38, 0.80, 0.58, 1),
  selection = rgba(0.76, 0.78, 0.82, 0.20),
}

local function muted_text(value)
  if ui_theme and ui_theme.muted then
    ui_theme.muted(ImGui, ctx, value)
  else
    ImGui.Text(ctx, value)
  end
end

local function displayed_item_color(item, track)
  if reaper.GetDisplayedMediaItemColor then
    local ok, color = pcall(reaper.GetDisplayedMediaItemColor, item)
    if ok and color and color ~= 0 then return color end
  end
  if track and reaper.GetTrackColor then
    local ok, color = pcall(reaper.GetTrackColor, track)
    if ok and color and color ~= 0 then return color end
  end
  return 0
end

local function track_tint(track)
  local color = 0
  if track and reaper.GetTrackColor then
    local ok, c = pcall(reaper.GetTrackColor, track)
    if ok then color = c or 0 end
  end
  return muted_native_color(color, 0.10, rgba(0.18, 0.18, 0.18, 0.18))
end

local function item_fill_color(item, track, selected)
  local color = displayed_item_color(item, track)
  if selected then
    return muted_native_color(color, 0.96, CANVAS.item_sel)
  end
  return muted_native_color(color, 0.84, CANVAS.item)
end

local function item_accent_color(item, track, selected)
  local color = displayed_item_color(item, track)
  return muted_native_color(color, selected and 1.0 or 0.92, selected and CANVAS.item_sel or CANVAS.item)
end

local TRACK_FILTERS = { "All tracks", "Selected tracks" }

local function combo_index(label, value, names)
  if ImGui.BeginCombo(ctx, label, names[value] or names[1] or "") then
    for i, name in ipairs(names) do
      local selected = i == value
      if ImGui.Selectable(ctx, name, selected) then value = i end
    end
    ImGui.EndCombo(ctx)
  end
  return value
end

local function time_to_string(t)
  t = math.max(0, tonumber(t) or 0)
  local minutes = math.floor(t / 60)
  local seconds = t - minutes * 60
  return string.format("%d:%05.2f", minutes, seconds)
end

local function track_name(track, fallback)
  local ok, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  if ok and name ~= "" then return name end
  return "Track " .. tostring(fallback)
end

local function abbreviate(text, max_chars)
  text = tostring(text or "")
  max_chars = math.max(1, math.floor(max_chars or 1))
  if #text <= max_chars then return text end
  if max_chars <= 1 then return "." end
  return text:sub(1, max_chars - 1) .. "."
end

local function track_header_lines(track_index, name, track_w)
  local max_chars = math.max(4, math.floor((track_w - 10) / 7))
  local one_line = tostring(track_index) .. " " .. tostring(name or "")
  if #one_line <= max_chars then
    return one_line, nil
  end
  return tostring(track_index), abbreviate(name, max_chars)
end

local function project_length()
  local length = reaper.GetProjectLength(PROJECT) or 0
  local item_count = reaper.CountMediaItems(PROJECT)
  for i = 0, item_count - 1 do
    local item = reaper.GetMediaItem(PROJECT, i)
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") or 0
    local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH") or 0
    length = math.max(length, pos + len)
  end
  local _, num_markers, num_regions = reaper.CountProjectMarkers(PROJECT)
  local marker_total = (num_markers or 0) + (num_regions or 0)
  for i = 0, marker_total - 1 do
    local ok, is_region, pos, rgnend = reaper.EnumProjectMarkers3(PROJECT, i)
    if ok and ok > 0 then
      length = math.max(length, is_region and rgnend or pos)
    end
  end
  return math.max(length, 1)
end

local function marker_count()
  local _, num_markers, num_regions = reaper.CountProjectMarkers(PROJECT)
  return (num_markers or 0) + (num_regions or 0)
end

local function nearest_marker_or_region_time(t)
  local best, dist = nil, math.huge
  for i = 0, marker_count() - 1 do
    local ok, is_region, pos, rgnend = reaper.EnumProjectMarkers3(PROJECT, i)
    if ok and ok > 0 then
      local d = math.abs(t - pos)
      if d < dist then best, dist = pos, d end
      if is_region then
        d = math.abs(t - rgnend)
        if d < dist then best, dist = rgnend, d end
      end
    end
  end
  return best, dist
end

local function nearest_item_edge_time(t, exclude_item)
  local best, dist = nil, math.huge
  for i = 0, reaper.CountMediaItems(PROJECT) - 1 do
    local item = reaper.GetMediaItem(PROJECT, i)
    if item ~= exclude_item then
      local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") or 0
      local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH") or 0
      local d = math.abs(t - pos)
      if d < dist then best, dist = pos, d end
      d = math.abs(t - (pos + len))
      if d < dist then best, dist = pos + len, d end
    end
  end
  return best, dist
end

local function snap_time(t, exclude_item)
  t = math.max(0, tonumber(t) or 0)
  if not snap_enabled then return t end
  local threshold = math.max(0.015, seconds_per_pixel * 10)
  local best, dist = t, threshold
  if reaper.SnapToGrid then
    local ok, grid_t = pcall(reaper.SnapToGrid, PROJECT, t)
    if ok and grid_t then
      local d = math.abs(t - grid_t)
      if d <= dist then best, dist = grid_t, d end
    end
  end
  local mt, md = nearest_marker_or_region_time(t)
  if mt and md <= dist then best, dist = mt, md end
  local it, id = nearest_item_edge_time(t, exclude_item)
  if it and id <= dist then best, dist = it, id end
  return math.max(0, best)
end

local function build_track_list()
  local tracks = {}
  for i = 0, reaper.CountTracks(PROJECT) - 1 do
    local track = reaper.GetTrack(PROJECT, i)
    local include = true
    if track_filter == 2 then
      include = reaper.IsTrackSelected(track)
    end
    if include then
      tracks[#tracks + 1] = { track = track, num = i + 1 }
    end
  end
  if #tracks == 0 then
    for i = 0, reaper.CountTracks(PROJECT) - 1 do
      local track = reaper.GetTrack(PROJECT, i)
      tracks[#tracks + 1] = { track = track, num = i + 1 }
    end
  end
  return tracks
end

local function item_display_name(item)
  local take = reaper.GetActiveTake(item)
  if take then
    local ok, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    if ok and name ~= "" then return name end
  end
  return "item"
end

local function item_channel_count(item)
  local take = reaper.GetActiveTake(item)
  if not take then return 0 end
  local source = reaper.GetMediaItemTake_Source(take)
  if not source or not reaper.GetMediaSourceNumChannels then return 0 end
  local ok, channels = pcall(reaper.GetMediaSourceNumChannels, source)
  if ok and tonumber(channels) then return math.max(0, math.floor(channels)) end
  return 0
end

local function draw_item_channels(dl, item, ix0, iy0, ix1, iy1)
  local channels = item_channel_count(item)
  if channels <= 1 or iy1 - iy0 < 9 or ix1 - ix0 < 12 then return end
  local visible_lanes = math.min(channels, 16)
  local line_color = rgba(0.02, 0.025, 0.025, channels > 16 and 0.22 or 0.28)
  for ch = 1, visible_lanes - 1 do
    local x = ix0 + (ix1 - ix0) * ch / visible_lanes
    ImGui.DrawList_AddLine(dl, x, iy0 + 2, x, iy1 - 2, line_color, 1)
  end
  if iy1 - iy0 > 18 and ix1 - ix0 > 42 then
    local label = tostring(channels) .. "ch"
    ImGui.DrawList_AddText(dl, ix1 - 32, iy1 - 15, rgba(0.04, 0.045, 0.045, 0.78), label)
  end
end

local function select_marker(marker)
  selected_marker = marker
  selected_marker_name = marker and marker.name or ""
end

local function set_marker_or_region(marker, pos, rgnend, name)
  if not marker then return end
  local ok = reaper.SetProjectMarker4(PROJECT, marker.id, marker.is_region, pos, rgnend or 0, name or marker.name or "", marker.color or 0, 0)
  if ok then
    marker.pos = pos
    marker.rgnend = rgnend or 0
    marker.name = name or marker.name or ""
    selected_marker = marker
    selected_marker_name = marker.name
    reaper.UpdateArrange()
  end
end

local function add_marker_at_cursor()
  local pos = snap_time(reaper.GetCursorPosition())
  reaper.AddProjectMarker2(PROJECT, false, pos, 0, "marker", -1, 0)
  status = "Added marker at " .. time_to_string(pos)
  reaper.UpdateArrange()
end

local function add_region_from_time_selection()
  local a, b = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if b <= a then
    status = "No time selection for region."
    return
  end
  a, b = snap_time(a), snap_time(b)
  if b < a then a, b = b, a end
  reaper.AddProjectMarker2(PROJECT, true, a, b, "region", -1, 0)
  status = "Added region " .. time_to_string(a) .. " - " .. time_to_string(b)
  reaper.UpdateArrange()
end

local function fit_project(canvas_h)
  local length = project_length()
  view_start = 0
  seconds_per_pixel = clamp(length / math.max(1, canvas_h - 32), 0.002, 5.0)
end

local function fit_time_selection(canvas_h)
  local start_pos, end_pos = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if end_pos > start_pos then
    view_start = math.max(0, start_pos - (end_pos - start_pos) * 0.08)
    seconds_per_pixel = clamp((end_pos - start_pos) * 1.16 / math.max(1, canvas_h - 32), 0.002, 5.0)
  else
    status = "No active time selection to fit."
  end
end

local function select_item(item)
  reaper.Undo_BeginBlock()
  for i = 0, reaper.CountMediaItems(PROJECT) - 1 do
    reaper.SetMediaItemSelected(reaper.GetMediaItem(PROJECT, i), false)
  end
  reaper.SetMediaItemSelected(item, true)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Vertical Timeline Select Item", -1)
end

local function imgui_value(name)
  local ok, value = pcall(function() return ImGui[name] end)
  if ok then return value end
  return nil
end

local function key_down(key)
  if key == nil then return false end
  local ok, down = pcall(ImGui.IsKeyDown, ctx, key)
  return ok and down
end

local function shift_is_down()
  return key_down(imgui_value("Mod_Shift"))
end

local function zoom_key_is_down()
  return key_down(imgui_value("Mod_Ctrl"))
    or key_down(imgui_value("Mod_Super"))
    or key_down(imgui_value("Mod_Shortcut"))
end

local function key_pressed(name)
  local key = imgui_value(name)
  if key == nil then return false end
  local ok_fn, fn = pcall(function() return ImGui.IsKeyPressed end)
  if not ok_fn then return false end
  if not fn then return false end
  local ok, pressed = pcall(fn, ctx, key)
  return ok and pressed
end

local function imgui_fn(name)
  local ok, fn = pcall(function() return ImGui[name] end)
  if ok and type(fn) == "function" then return fn end
  return nil
end

local function mouse_wheel_axis(name)
  local fn = imgui_fn(name)
  if not fn then return 0 end
  local ok, wheel = pcall(fn, ctx)
  if ok then return tonumber(wheel) or 0 end
  return 0
end

local function mouse_wheel()
  return mouse_wheel_axis("GetMouseWheel")
end

local function mouse_wheel_h()
  return mouse_wheel_axis("GetMouseWheelH")
end

local function mouse_drag_delta(button)
  local fn = imgui_fn("GetMouseDragDelta")
  if fn then
    local ok, dx, dy = pcall(fn, ctx, button or 0)
    if ok then return tonumber(dx) or 0, tonumber(dy) or 0 end
  end
  if view_pan then
    local mx, my = ImGui.GetMousePos(ctx)
    return mx - (view_pan.mx or mx), my - (view_pan.my or my)
  end
  return 0, 0
end

local function now_seconds()
  local fn = imgui_fn("GetTime")
  if fn then
    local ok, t = pcall(fn, ctx)
    if ok and tonumber(t) then return tonumber(t) end
  end
  return reaper.time_precise()
end

local function smooth_play_position(actual_pos, playing)
  local now = now_seconds()
  if not playing then
    play_visual_pos = actual_pos
    play_visual_time = now
    return actual_pos
  end
  if not play_visual_pos or not play_visual_time then
    play_visual_pos = actual_pos
    play_visual_time = now
    return actual_pos
  end

  local dt = clamp(now - play_visual_time, 0, 0.12)
  local predicted = play_visual_pos + dt
  local drift = actual_pos - predicted
  if math.abs(drift) > 0.18 then
    play_visual_pos = actual_pos
  else
    play_visual_pos = predicted + drift * 0.22
  end
  play_visual_time = now
  return play_visual_pos
end

local function transport_state_label()
  local state = reaper.GetPlayState()
  if state >= 4 then return "recording", reaper.GetPlayPosition() end
  if (state % 2) == 1 then return "playing", reaper.GetPlayPosition() end
  if state >= 2 then return "paused", reaper.GetPlayPosition() end
  return "stopped", reaper.GetCursorPosition()
end

local function draw_transport()
  local state_label, display_pos = transport_state_label()
  if ImGui.Button(ctx, "|<##transport_start", 34, 24) then
    reaper.Main_OnCommand(40042, 0) -- Transport: Go to start of project
    status = "Transport: start"
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Stop##transport_stop", 48, 24) then
    reaper.OnStopButton()
    status = "Transport: stop"
  end
  ImGui.SameLine(ctx)
  local play_label = ((reaper.GetPlayState() % 2) == 1) and "Pause" or "Play"
  if ImGui.Button(ctx, play_label .. "##transport_play_pause", 58, 24) then
    if (reaper.GetPlayState() % 2) == 1 then
      reaper.Main_OnCommand(1008, 0) -- Transport: Pause
      status = "Transport: pause"
    else
      reaper.OnPlayButton()
      status = "Transport: play"
    end
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Cursor##transport_center_cursor", 64, 24) then
    view_start = math.max(0, reaper.GetCursorPosition() - 6 * seconds_per_pixel * 84)
    status = "View centered near edit cursor"
  end
  ImGui.SameLine(ctx)
  muted_text(string.format("%s  %s", state_label, time_to_string(display_pos)))
end

local function draw_timeline(canvas_w, canvas_h)
  ImGui.InvisibleButton(ctx, "##vertical_timeline_canvas", canvas_w, canvas_h)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local full_x1, y1 = ImGui.GetItemRectMax(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local minimap_w = 58
  local minimap_gap = 8
  local x1 = math.max(x0 + 240, full_x1 - minimap_w - minimap_gap)
  ImGui.DrawList_AddRectFilled(dl, x0, y0, full_x1, y1, CANVAS.bg)
  ImGui.DrawList_AddRect(dl, x0, y0, full_x1, y1, CANVAS.edge, 0, 0, 1.2)

  local ruler_w = 68
  local header_h = 42
  local usable_x0 = x0 + ruler_w
  local usable_y0 = y0 + header_h
  local usable_w = math.max(1, x1 - usable_x0)
  local usable_h = math.max(1, y1 - usable_y0)
  local track_w = usable_w / math.max(1, visible_tracks)
  local view_end = view_start + usable_h * seconds_per_pixel
  local project_len = project_length()
  local track_list = build_track_list()
  local track_count = #track_list
  visible_tracks = clamp(math.floor(visible_tracks), 1, math.max(1, track_count))
  track_start = clamp(math.floor(track_start), 1, math.max(1, track_count))
  if track_start + visible_tracks - 1 > track_count then
    track_start = math.max(1, track_count - visible_tracks + 1)
  end
  track_w = usable_w / math.max(1, visible_tracks)
  local hit_items = {}
  local hit_markers = {}
  local visible_track_map = {}
  for i = 0, visible_tracks - 1 do
    local entry = track_list[track_start + i]
    if entry then visible_track_map[entry.track] = { col = i, num = entry.num } end
  end

  local function y_for_time(t)
    return usable_y0 + (t - view_start) / seconds_per_pixel
  end

  local function time_for_y(y)
    return clamp(view_start + (y - usable_y0) * seconds_per_pixel, 0, project_len)
  end

  local function track_for_x(x)
    local col = math.floor((x - usable_x0) / track_w)
    col = clamp(col, 0, math.max(0, visible_tracks - 1))
    local entry = track_list[track_start + col]
    if not entry then return nil, 0 end
    return entry.track, entry.num
  end

  local function clamp_view()
    local max_start = math.max(0, project_len - usable_h * seconds_per_pixel * 0.25)
    view_start = clamp(view_start, 0, max_start)
    track_start = clamp(math.floor(track_start), 1, math.max(1, track_count))
    if track_start + visible_tracks - 1 > track_count then
      track_start = math.max(1, track_count - visible_tracks + 1)
    end
  end

  ImGui.DrawList_AddRectFilled(dl, x0, y0, x1, usable_y0, CANVAS.panel)
  ImGui.DrawList_AddText(dl, x0 + 10, y0 + 10, CANVAS.muted, "time")

  for i = 0, visible_tracks - 1 do
    local entry = track_list[track_start + i]
    local track = entry and entry.track
    local track_index = entry and entry.num or (track_start + i)
    local tx0 = usable_x0 + i * track_w
    local tx1 = tx0 + track_w
    if track then
      ImGui.DrawList_AddRectFilled(dl, tx0, usable_y0, tx1, y1, track_tint(track))
    end
    ImGui.DrawList_AddLine(dl, tx0, y0, tx0, y1, CANVAS.grid, 1)
    if track then
      local name = track_name(track, track_index)
      local line1, line2 = track_header_lines(track_index, name, track_w)
      ImGui.DrawList_AddText(dl, tx0 + 5, y0 + (line2 and 6 or 13), CANVAS.text, line1)
      if line2 then
        ImGui.DrawList_AddText(dl, tx0 + 5, y0 + 22, CANVAS.muted, line2)
      end
    end
  end

  local grid_step = 1
  local target_px = 58
  local raw_step = target_px * seconds_per_pixel
  local candidates = { 0.25, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600 }
  for _, step in ipairs(candidates) do
    grid_step = step
    if step >= raw_step then break end
  end
  local first_grid = math.floor(view_start / grid_step) * grid_step
  local t = first_grid
  while t <= view_end + grid_step do
    local y = y_for_time(t)
    if y >= usable_y0 and y <= y1 then
      ImGui.DrawList_AddLine(dl, x0, y, x1, y, CANVAS.grid, 1)
      ImGui.DrawList_AddText(dl, x0 + 8, y + 3, CANVAS.muted, time_to_string(t))
    end
    t = t + grid_step
  end

  if show_time_selection then
    local start_pos, end_pos = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if end_pos > start_pos and end_pos >= view_start and start_pos <= view_end then
      local sy0 = clamp(y_for_time(start_pos), usable_y0, y1)
      local sy1 = clamp(y_for_time(end_pos), usable_y0, y1)
      ImGui.DrawList_AddRectFilled(dl, usable_x0, sy0, x1, sy1, CANVAS.selection)
      ImGui.DrawList_AddRect(dl, usable_x0, sy0, x1, sy1, rgba(0.78, 0.80, 0.82, 0.38), 0, 0, 1)
    end
  end

  local item_count = reaper.CountMediaItems(PROJECT)
  for i = 0, item_count - 1 do
    local item = reaper.GetMediaItem(PROJECT, i)
    local track = reaper.GetMediaItem_Track(item)
    local mapped = visible_track_map[track]
    if mapped then
      local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") or 0
      local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH") or 0
      local item_end = pos + len
      if item_end >= view_start and pos <= view_end then
        local col = mapped.col
        local ix0 = usable_x0 + col * track_w + 5
        local ix1 = usable_x0 + (col + 1) * track_w - 5
        local iy0 = clamp(y_for_time(pos), usable_y0, y1)
        local iy1 = clamp(y_for_time(item_end), usable_y0, y1)
        if iy1 - iy0 < 5 then iy1 = iy0 + 5 end
        local selected = reaper.IsMediaItemSelected(item)
        local fill = item_fill_color(item, track, selected)
        ImGui.DrawList_AddRectFilled(dl, ix0, iy0, ix1, iy1, fill)
        ImGui.DrawList_AddRectFilled(dl, ix0, iy0, ix1, math.min(iy1, iy0 + 3), item_accent_color(item, track, selected))
        draw_item_channels(dl, item, ix0, iy0 + 3, ix1, iy1)
        ImGui.DrawList_AddRect(dl, ix0, iy0, ix1, iy1, selected and CANVAS.text or CANVAS.edge, 0, 0, selected and 1.6 or 1)
        if iy1 - iy0 > 16 then
          local name = item_display_name(item)
          if #name > 16 then name = name:sub(1, 15) .. "." end
          ImGui.DrawList_AddText(dl, ix0 + 4, iy0 + 4, rgba(0.05, 0.06, 0.06, 0.95), name)
        end
        hit_items[#hit_items + 1] = { item = item, x0 = ix0, x1 = ix1, y0 = iy0, y1 = iy1, pos = pos, len = len }
      end
    end
  end

  if show_markers or show_regions then
    local marker_total = marker_count()
    for i = 0, marker_total - 1 do
      local ok, is_region, pos, rgnend, name, id, color = reaper.EnumProjectMarkers3(PROJECT, i)
      if ok and ok > 0 then
        local marker = { id = id, is_region = is_region, pos = pos, rgnend = rgnend, name = name or "", color = color or 0 }
        local selected = selected_marker and selected_marker.id == id
        if is_region and show_regions and rgnend >= view_start and pos <= view_end then
          local ry0 = clamp(y_for_time(pos), usable_y0, y1)
          local ry1 = clamp(y_for_time(rgnend), usable_y0, y1)
          ImGui.DrawList_AddRectFilled(dl, usable_x0, ry0, x1, ry1, rgba(0.45, 0.36, 0.65, selected and 0.34 or 0.22))
          ImGui.DrawList_AddRect(dl, usable_x0, ry0, x1, ry1, selected and CANVAS.marker or rgba(0.72, 0.68, 0.92, 0.48), 0, 0, selected and 2 or 1)
          ImGui.DrawList_AddText(dl, usable_x0 + 8, ry0 + 4, CANVAS.text, name ~= "" and name or "region")
          hit_markers[#hit_markers + 1] = { marker = marker, x0 = usable_x0, x1 = x1, y0 = ry0, y1 = ry1, click_kind = "region" }
        elseif (not is_region) and show_markers and pos >= view_start and pos <= view_end then
          local my = y_for_time(pos)
          ImGui.DrawList_AddLine(dl, usable_x0, my, x1, my, selected and CANVAS.text or CANVAS.marker, selected and 3 or 2)
          ImGui.DrawList_AddText(dl, usable_x0 + 8, my + 4, CANVAS.marker, name ~= "" and name or "marker")
          hit_markers[#hit_markers + 1] = { marker = marker, x0 = usable_x0, x1 = x1, y0 = my - 6, y1 = my + 10, click_kind = "marker" }
        end
      end
    end
  end

  local map_x0 = x1 + minimap_gap
  local map_x1 = full_x1 - 8
  local map_y0 = usable_y0
  local map_y1 = y1 - 8
  if map_x1 > map_x0 + 12 and map_y1 > map_y0 + 40 then
    ImGui.DrawList_AddRectFilled(dl, map_x0, map_y0, map_x1, map_y1, rgba(0.055, 0.058, 0.060, 1))
    ImGui.DrawList_AddRect(dl, map_x0, map_y0, map_x1, map_y1, CANVAS.edge, 0, 0, 1)
    ImGui.DrawList_AddText(dl, map_x0 + 4, y0 + 10, CANVAS.muted, "map")
    for i = 0, item_count - 1 do
      local item = reaper.GetMediaItem(PROJECT, i)
      local track = reaper.GetMediaItem_Track(item)
      local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") or 0
      local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH") or 0
      local ty = (reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") or 1) / math.max(1, reaper.CountTracks(PROJECT))
      local iy0 = map_y0 + (pos / project_len) * (map_y1 - map_y0)
      local iy1 = map_y0 + ((pos + len) / project_len) * (map_y1 - map_y0)
      local ix0 = map_x0 + 4 + ty * math.max(1, map_x1 - map_x0 - 10)
      ImGui.DrawList_AddRectFilled(dl, ix0, iy0, ix0 + 3, math.max(iy0 + 2, iy1), item_fill_color(item, track, false))
    end
    local vy0 = map_y0 + (view_start / project_len) * (map_y1 - map_y0)
    local vy1 = map_y0 + (math.min(project_len, view_end) / project_len) * (map_y1 - map_y0)
    ImGui.DrawList_AddRect(dl, map_x0 + 1, vy0, map_x1 - 1, math.max(vy0 + 8, vy1), CANVAS.cursor, 0, 0, 1.4)
  end

  local edit_pos = reaper.GetCursorPosition()
  if edit_pos >= view_start and edit_pos <= view_end then
    local cy = y_for_time(edit_pos)
    ImGui.DrawList_AddLine(dl, x0, cy, x1, cy, CANVAS.cursor, 2.0)
  end
  local playing = (reaper.GetPlayState() % 2) == 1
  local play_pos = smooth_play_position(reaper.GetPlayPosition(), playing)
  if playing and play_pos >= view_start and play_pos <= view_end then
    local py = y_for_time(play_pos)
    local glow = rgba(0.38, 0.80, 0.58, 0.18)
    ImGui.DrawList_AddRectFilled(dl, x0, py - 2, x1, py + 2, glow)
    ImGui.DrawList_AddLine(dl, x0, py, x1, py, CANVAS.play, 2.0)
    local label_y = clamp(py - 16, usable_y0 + 3, y1 - 18)
    ImGui.DrawList_AddText(dl, snap_pixel(x1 - 58), snap_pixel(label_y), CANVAS.play, "play")
  end

  local mx, my = ImGui.GetMousePos(ctx)
  local hovered = ImGui.IsItemHovered(ctx)
  local over_minimap = hovered and mx >= map_x0 and mx <= map_x1 and my >= map_y0 and my <= map_y1
  if over_minimap and (ImGui.IsMouseClicked(ctx, 0) or ImGui.IsMouseDragging(ctx, 0)) then
    local norm = clamp((my - map_y0) / math.max(1, map_y1 - map_y0), 0, 1)
    local center = norm * project_len
    view_start = center - (usable_h * seconds_per_pixel) * 0.5
    clamp_view()
    status = "Map view: " .. time_to_string(view_start)
  end
  local wheel = mouse_wheel()
  local wheel_h = mouse_wheel_h()
  if hovered and not item_drag and wheel ~= 0 then
    if zoom_key_is_down() then
      local anchor_y = clamp(my, usable_y0, y1)
      local anchor_time = time_for_y(anchor_y)
      seconds_per_pixel = clamp(seconds_per_pixel * (0.82 ^ wheel), 0.001, 8.0)
      view_start = anchor_time - (anchor_y - usable_y0) * seconds_per_pixel
      status = "Zoom: " .. string.format("%.3f sec/px", seconds_per_pixel)
    elseif shift_is_down() then
      local step = wheel > 0 and -3 or 3
      track_start = track_start + step
      status = "Track view starts at " .. tostring(track_start)
    else
      view_start = view_start - wheel * seconds_per_pixel * 84
      status = "View start: " .. time_to_string(view_start)
    end
    clamp_view()
  end
  if hovered and not item_drag and wheel_h ~= 0 then
    local step = wheel_h > 0 and 3 or -3
    track_start = track_start + step
    clamp_view()
    status = "Track view starts at " .. tostring(track_start)
  end

  if hovered and not item_drag then
    if key_pressed("Key_LeftArrow") then
      track_start = track_start - 1
      clamp_view()
      status = "Track view starts at " .. tostring(track_start)
    elseif key_pressed("Key_RightArrow") then
      track_start = track_start + 1
      clamp_view()
      status = "Track view starts at " .. tostring(track_start)
    elseif key_pressed("Key_UpArrow") then
      view_start = view_start - seconds_per_pixel * 84
      clamp_view()
      status = "View start: " .. time_to_string(view_start)
    elseif key_pressed("Key_DownArrow") then
      view_start = view_start + seconds_per_pixel * 84
      clamp_view()
      status = "View start: " .. time_to_string(view_start)
    end
  end

  if hovered and not item_drag and ImGui.IsMouseClicked(ctx, 1) then
    view_pan = {
      mx = mx,
      my = my,
      view_start = view_start,
      track_start = track_start,
    }
  end

  if view_pan and ImGui.IsMouseDown(ctx, 1) then
    local dx, dy = mouse_drag_delta(1)
    view_start = view_pan.view_start - dy * seconds_per_pixel
    local track_delta = 0
    if math.abs(dx) >= 10 then
      track_delta = math.floor(math.abs(dx) / 28)
      if dx > 0 then track_delta = -track_delta end
    end
    track_start = view_pan.track_start + track_delta
    clamp_view()
    status = "Pan view: track " .. tostring(track_start) .. " / " .. time_to_string(view_start)
  end

  if ImGui.IsMouseReleased(ctx, 1) then
    view_pan = nil
  end

  if hovered and (not over_minimap) and ImGui.IsMouseClicked(ctx, 0) then
    for _, rect in ipairs(hit_markers) do
      if mx >= rect.x0 and mx <= rect.x1 and my >= rect.y0 and my <= rect.y1 then
        select_marker(rect.marker)
        marker_drag = {
          marker = rect.marker,
          offset = time_for_y(my) - rect.marker.pos,
          length = rect.marker.is_region and math.max(0, rect.marker.rgnend - rect.marker.pos) or 0,
          undo_started = false,
        }
        status = (rect.marker.is_region and "Selected region: " or "Selected marker: ") .. (rect.marker.name ~= "" and rect.marker.name or tostring(rect.marker.id))
        break
      end
    end
  end

  if marker_drag and ImGui.IsMouseDown(ctx, 0) and ImGui.IsMouseDragging(ctx, 0) then
    if not marker_drag.undo_started then
      reaper.Undo_BeginBlock()
      marker_drag.undo_started = true
    end
    local new_pos = snap_time(time_for_y(my) - marker_drag.offset)
    local new_end = marker_drag.marker.is_region and (new_pos + marker_drag.length) or 0
    set_marker_or_region(marker_drag.marker, new_pos, new_end, marker_drag.marker.name)
    status = (marker_drag.marker.is_region and "Moved region to " or "Moved marker to ") .. time_to_string(new_pos)
  end

  if hovered and (not over_minimap) and (not marker_drag) and ImGui.IsMouseClicked(ctx, 0) then
    local hit = nil
    for _, rect in ipairs(hit_items) do
      if mx >= rect.x0 and mx <= rect.x1 and my >= rect.y0 and my <= rect.y1 then
        hit = rect
        break
      end
    end
    if hit then
      select_item(hit.item)
      reaper.SetEditCurPos(hit.pos, true, false)
      item_drag = {
        item = hit.item,
        click_offset = time_for_y(my) - hit.pos,
        last_pos = hit.pos,
        last_track = math.floor(reaper.GetMediaTrackInfo_Value(reaper.GetMediaItem_Track(hit.item), "IP_TRACKNUMBER") or 0),
        undo_started = false,
        moved = false,
      }
      status = "Selected item at " .. time_to_string(hit.pos)
    elseif mx >= usable_x0 and my >= usable_y0 then
      local tpos = snap_time(time_for_y(my))
      reaper.SetEditCurPos(tpos, true, false)
      drag_select_start = tpos
      status = "Cursor: " .. time_to_string(tpos)
    end
  end

  if item_drag and ImGui.IsMouseDown(ctx, 0) and ImGui.IsMouseDragging(ctx, 0) then
    if not item_drag.undo_started then
      reaper.Undo_BeginBlock()
      item_drag.undo_started = true
    end
    local new_pos = snap_time(math.max(0, time_for_y(my) - item_drag.click_offset), item_drag.item)
    local target_track, target_track_num = track_for_x(mx)
    if item_drag.item then
      reaper.SetMediaItemInfo_Value(item_drag.item, "D_POSITION", new_pos)
      if target_track and target_track_num ~= item_drag.last_track then
        reaper.MoveMediaItemToTrack(item_drag.item, target_track)
        item_drag.last_track = target_track_num
      end
      item_drag.last_pos = new_pos
      item_drag.moved = true
      reaper.SetEditCurPos(new_pos, false, false)
      reaper.UpdateArrange()
      status = "Moved item to track " .. tostring(item_drag.last_track) .. " at " .. time_to_string(new_pos)
    end
  elseif hovered and ImGui.IsMouseDragging(ctx, 0) and drag_select_start then
    local tpos = snap_time(time_for_y(my))
    local a = math.min(drag_select_start, tpos)
    local b = math.max(drag_select_start, tpos)
    reaper.GetSet_LoopTimeRange(true, false, a, b, false)
    status = "Time selection: " .. time_to_string(a) .. " - " .. time_to_string(b)
  end
  if ImGui.IsMouseReleased(ctx, 0) then
    if marker_drag and marker_drag.undo_started then
      reaper.Undo_EndBlock("Vertical Timeline Move Marker/Region", -1)
      reaper.UpdateArrange()
    end
    marker_drag = nil
    if item_drag and item_drag.undo_started then
      reaper.Undo_EndBlock("Vertical Timeline Move Item", -1)
      reaper.UpdateArrange()
    end
    item_drag = nil
    drag_select_start = nil
  end
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 1120, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local project_len = project_length()
    local track_count = math.max(1, #build_track_list())
    if follow_play and (reaper.GetPlayState() % 2) == 1 then
      local _, avail_h = ImGui.GetContentRegionAvail(ctx)
      local play_pos = play_visual_pos or reaper.GetPlayPosition()
      view_start = clamp(play_pos - (avail_h * seconds_per_pixel * 0.45), 0, math.max(0, project_len - 1))
    end

    draw_transport()

    if ImGui.Button(ctx, "Fit Project", 92, 24) then
      local _, avail_h = ImGui.GetContentRegionAvail(ctx)
      fit_project(math.max(240, avail_h - 92))
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Fit Selection", 104, 24) then
      local _, avail_h = ImGui.GetContentRegionAvail(ctx)
      fit_time_selection(math.max(240, avail_h - 92))
    end
    ImGui.SameLine(ctx)
    _, follow_play = ImGui.Checkbox(ctx, "Follow play", follow_play)
    ImGui.SameLine(ctx)
    _, show_time_selection = ImGui.Checkbox(ctx, "Time selection", show_time_selection)
    ImGui.SameLine(ctx)
    _, show_markers = ImGui.Checkbox(ctx, "Markers", show_markers)
    ImGui.SameLine(ctx)
    _, show_regions = ImGui.Checkbox(ctx, "Regions", show_regions)
    ImGui.SameLine(ctx)
    _, snap_enabled = ImGui.Checkbox(ctx, "Snap", snap_enabled)

    ImGui.SetNextItemWidth(ctx, 188)
    local previous_filter = track_filter
    track_filter = combo_index("Track filter", track_filter, TRACK_FILTERS)
    if track_filter ~= previous_filter then
      local filtered_count = math.max(1, #build_track_list())
      if track_filter == 1 then
        visible_tracks = math.min(64, filtered_count)
      else
        visible_tracks = clamp(visible_tracks, 1, math.min(64, filtered_count))
      end
      track_start = clamp(track_start, 1, filtered_count)
      status = "Track filter: " .. (TRACK_FILTERS[track_filter] or "")
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Add Marker", 90, 24) then add_marker_at_cursor() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Add Region", 88, 24) then add_region_from_time_selection() end
    if selected_marker then
      ImGui.SetNextItemWidth(ctx, 260)
      local changed_name
      changed_name, selected_marker_name = ImGui.InputText(ctx, "Marker / region name", selected_marker_name or "")
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Save Name", 86, 24) then
        set_marker_or_region(selected_marker, selected_marker.pos, selected_marker.rgnend, selected_marker_name)
        status = "Saved marker/region name"
      end
    end

    local changed
    changed, seconds_per_pixel = ImGui.SliderDouble(ctx, "Seconds / pixel", seconds_per_pixel, 0.002, 2.0, "%.3f")
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "-", 26, 22) then seconds_per_pixel = clamp(seconds_per_pixel * 1.25, 0.002, 5.0) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "+", 26, 22) then seconds_per_pixel = clamp(seconds_per_pixel / 1.25, 0.002, 5.0) end
    changed, view_start = ImGui.SliderDouble(ctx, "View start", view_start, 0.0, math.max(0.0, project_len), "%.2f sec")
    track_count = math.max(1, #build_track_list())
    visible_tracks = clamp(visible_tracks, 1, math.min(64, track_count))
    track_start = clamp(track_start, 1, track_count)
    changed, visible_tracks = ImGui.SliderInt(ctx, "Visible tracks", visible_tracks, 1, math.max(1, math.min(64, track_count)))
    if track_start + visible_tracks - 1 > track_count then
      track_start = math.max(1, track_count - visible_tracks + 1)
    end
    local first_track_max = math.max(1, track_count - visible_tracks + 1)
    changed, track_start = ImGui.SliderInt(ctx, "First track", track_start, 1, first_track_max)
    muted_text("Wheel scrolls time. Cmd/Ctrl-wheel zooms. First track slider moves side-to-side.")

    local canvas_w, avail_h = ImGui.GetContentRegionAvail(ctx)
    local canvas_h = math.max(320, avail_h - 26)
    draw_timeline(canvas_w, canvas_h)
    muted_text(status)
  end
  ImGui.End(ctx)
  persist()
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
