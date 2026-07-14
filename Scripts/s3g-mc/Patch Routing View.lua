-- @description Patch Routing View
-- @author s3g
-- @version 0.1
-- @requires ReaImGui
-- @category Channel Mixing / Automation
-- @method Max-like bottom-up REAPER routing canvas. Draws tracks as draggable patch nodes with folder, send, receive, master-send, channel-count, and FX-state information; Edit mode can create and adjust sends.
-- @about
--   A live patch-canvas view for REAPER track routing. View mode selects
--   tracks, opens FX chains, shows sends/folders, and saves node positions.
--   Edit mode can create, adjust, and remove sends.

local TITLE = "Patch Routing View"
local EXT = "s3g_mc_patch_routing_view_v1"
local PROJECT = 0

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", TITLE, 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
do
  local script_path = ({ reaper.get_action_context() })[2]
  local script_dir = script_path:match("^(.*[/\\])") or ""
  package.path = script_dir .. "?.lua;" .. package.path
  local ok, theme = pcall(require, "s3g-mc ImGui Theme")
  if ok and theme and theme.install then theme.install(ImGui) end
end

local ctx = ImGui.CreateContext(TITLE)
local open = true

local function rgba(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local COLORS = {
  bg = rgba(0.030, 0.032, 0.034, 1),
  panel = rgba(0.060, 0.064, 0.068, 1),
  node = rgba(0.105, 0.112, 0.118, 0.96),
  node_bus = rgba(0.118, 0.135, 0.145, 0.98),
  node_sel = rgba(0.205, 0.190, 0.135, 0.98),
  edge = rgba(0.310, 0.325, 0.340, 1),
  grid = rgba(0.50, 0.54, 0.55, 0.10),
  text = rgba(0.83, 0.85, 0.86, 1),
  muted = rgba(0.56, 0.59, 0.60, 1),
  send = rgba(0.42, 0.70, 0.78, 0.85),
  receive = rgba(0.58, 0.62, 0.66, 0.65),
  folder = rgba(0.90, 0.70, 0.36, 0.88),
  master = rgba(0.42, 0.82, 0.56, 0.78),
  warn = rgba(0.94, 0.50, 0.34, 0.90),
  pin = rgba(0.72, 0.76, 0.78, 1),
}

local NODE_W = 178
local NODE_H = 126
local MASTER_W = 178
local MASTER_H = 86

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

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

local function set_ext(key, value)
  reaper.SetExtState(EXT, key, type(value) == "boolean" and (value and "1" or "0") or tostring(value), true)
end

local zoom = getn("zoom", 1.0)
local pan_x = getn("pan_x", 24)
local pan_y = getn("pan_y", 24)
local view_mode = math.floor(getn("view_mode", 1))
local show_folders = getb("show_folders", true)
local show_sends = getb("show_sends", true)
local show_master = getb("show_master", true)
local show_selected_only = getb("show_selected_only", false)
local show_multichannel_only = getb("show_multichannel_only", false)
local show_connected_only = getb("show_connected_only", false)
local collapse_folder_children = getb("collapse_folder_children", false)
local collapsed_folders = {}
local labels_hover_only = getb("labels_hover_only", false)
local wires_front = getb("wires_front", false)
local edit_mode = getb("edit_mode", true)
local window_size_mode = math.floor(getn("window_size_mode", 1))
local pending_window_size_mode = nil
local search_text = reaper.GetExtState(EXT, "search_text") or ""
local selected_node_key = nil
local selected_node_keys = {}
local selected_connection_key = nil
local dragging_key = nil
local drag_group = nil
local patch_drag = nil
local marquee_drag = nil
local drag_dx, drag_dy = 0, 0
local drag_origin_x, drag_origin_y = 0, 0
local panning = false
local pan_start_x, pan_start_y = 0, 0
local pan_base_x, pan_base_y = 0, 0
local hovered_connection_key = nil
local status = "View mode. Drag nodes to arrange the view."

local VIEW_MODES = { "Manual", "Track order", "Folder lanes" }

local function persist()
  set_ext("zoom", zoom)
  set_ext("pan_x", pan_x)
  set_ext("pan_y", pan_y)
  set_ext("view_mode", view_mode)
  set_ext("show_folders", show_folders)
  set_ext("show_sends", show_sends)
  set_ext("show_master", show_master)
  set_ext("show_selected_only", show_selected_only)
  set_ext("show_multichannel_only", show_multichannel_only)
  set_ext("show_connected_only", show_connected_only)
  set_ext("collapse_folder_children", collapse_folder_children)
  set_ext("labels_hover_only", labels_hover_only)
  set_ext("wires_front", wires_front)
  set_ext("edit_mode", edit_mode)
  set_ext("window_size_mode", window_size_mode)
  set_ext("search_text", search_text)
end

local function track_guid(track)
  if not track then return "master" end
  local ok, guid = pcall(reaper.GetTrackGUID, track)
  if ok and guid and guid ~= "" then return guid end
  return "track_" .. tostring(math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") or 0))
end

local function pos_key(guid, axis)
  return "node_" .. tostring(guid):gsub("[{}%-]", "_") .. "_" .. axis
end

local function saved_pos(guid)
  local x = tonumber(reaper.GetExtState(EXT, pos_key(guid, "x")))
  local y = tonumber(reaper.GetExtState(EXT, pos_key(guid, "y")))
  return x, y
end

local function save_pos(guid, x, y)
  reaper.SetExtState(EXT, pos_key(guid, "x"), tostring(math.floor(x + 0.5)), true)
  reaper.SetExtState(EXT, pos_key(guid, "y"), tostring(math.floor(y + 0.5)), true)
end

local function track_name(track, fallback)
  local ok, name = reaper.GetTrackName(track, "")
  if ok and name ~= "" then return name end
  return fallback
end

local function track_display_name(track, index)
  local ok, name = reaper.GetTrackName(track, "")
  if not ok or name == "" then return "" end
  if name == ("Track " .. tostring(index)) then return "" end
  return name
end

local function short_name(name, limit)
  limit = limit or 24
  if #name <= limit then return name end
  return name:sub(1, limit - 3) .. "..."
end

local function node_label(node, limit)
  if not node then return "" end
  if node.master then return "MASTER" end
  local label = "TR" .. tostring(node.index)
  if node.display_name and node.display_name ~= "" then
    label = label .. " " .. short_name(node.display_name, limit or 18)
  end
  return label
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
  local sat = 0.45
  r = gray + (r - gray) * sat
  g = gray + (g - gray) * sat
  b = gray + (b - gray) * sat
  return rgba(r * 0.86, g * 0.86, b * 0.86, alpha or 1)
end

local function track_color(track, alpha, fallback)
  local color = 0
  if track and reaper.GetTrackColor then
    local ok, c = pcall(reaper.GetTrackColor, track)
    if ok then color = c or 0 end
  end
  return muted_native_color(color, alpha or 1, fallback)
end

local function track_depth(track)
  return math.floor(reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") or 0)
end

local function find_parent_index(entries, index)
  local depth = 0
  for i = index - 1, 1, -1 do
    depth = depth - entries[i].folder_depth
    if depth < 0 then return i end
  end
  return nil
end

local function source_channel_label(flag)
  flag = math.floor(tonumber(flag) or 0)
  if flag < 0 then return "none" end
  local start = (flag & 1023) + 1
  local count = flag >> 10
  if count <= 0 then count = 2 end
  return tostring(start) .. "-" .. tostring(start + count - 1)
end

local function db_label(vol)
  vol = tonumber(vol) or 0
  if vol <= 0.000001 then return "-inf dB" end
  return string.format("%.1f dB", 20 * math.log(vol, 10))
end

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

local SEND_MODES = {
  { value = 0, name = "Post-fader" },
  { value = 1, name = "Pre-FX" },
  { value = 3, name = "Pre-fader" },
}

local function send_mode_name(value)
  value = math.floor(tonumber(value) or 0)
  for _, mode in ipairs(SEND_MODES) do
    if mode.value == value then return mode.name end
  end
  return "Mode " .. tostring(value)
end

local function send_mode_combo(label, value)
  local current = send_mode_name(value)
  if ImGui.BeginCombo(ctx, label, current) then
    for _, mode in ipairs(SEND_MODES) do
      local selected = math.floor(value or 0) == mode.value
      if ImGui.Selectable(ctx, mode.name, selected) then value = mode.value end
    end
    ImGui.EndCombo(ctx)
  end
  return value
end

local function matches_search(entry)
  local q = (search_text or ""):lower():match("^%s*(.-)%s*$")
  if q == "" then return true end
  local tr = "tr" .. tostring(entry.index)
  local num = tostring(entry.index)
  local name = (entry.name or ""):lower()
  local display = (entry.display_name or ""):lower()
  return tr:find(q, 1, true) or num == q or name:find(q, 1, true) or display:find(q, 1, true)
end

local function key_pressed(key)
  if not (key and ImGui.IsKeyPressed) then return false end
  local ok, pressed = pcall(ImGui.IsKeyPressed, ctx, key)
  return ok and pressed
end

local function imgui_value(name)
  local ok, value = pcall(function() return ImGui[name] end)
  if ok then return value end
  return nil
end

local function key_down(key)
  if key == nil or not ImGui.IsKeyDown then return false end
  local ok, down = pcall(ImGui.IsKeyDown, ctx, key)
  return ok and down
end

local function shift_is_down()
  return key_down(imgui_value("Mod_Shift"))
end

local function delete_key_pressed()
  return key_pressed(ImGui.Key_Delete or ImGui.Key_NamedKey_DELETE)
    or key_pressed(ImGui.Key_Backspace or ImGui.Key_NamedKey_BACKSPACE)
end

local function send_key(source_guid, send_index)
  return tostring(source_guid) .. ":send:" .. tostring(send_index)
end

local function folder_collapse_key(guid)
  return "folder_collapsed_" .. tostring(guid):gsub("[{}%-]", "_")
end

local function is_folder_collapsed(entry)
  if not (entry and entry.guid and (entry.child_count or 0) > 0) then return false end
  if collapsed_folders[entry.guid] == nil then
    collapsed_folders[entry.guid] = getb(folder_collapse_key(entry.guid), false)
  end
  return collapsed_folders[entry.guid] == true
end

local function set_folder_collapsed(entry, collapsed)
  if not (entry and entry.guid) then return end
  collapsed_folders[entry.guid] = collapsed and true or false
  set_ext(folder_collapse_key(entry.guid), collapsed and true or false)
end

local function set_all_folders_collapsed(entries, collapsed)
  local count = 0
  for _, entry in ipairs(entries or {}) do
    if (entry.child_count or 0) > 0 then
      set_folder_collapsed(entry, collapsed)
      count = count + 1
    end
  end
  status = collapsed and ("Collapsed " .. tostring(count) .. " folder nodes.") or ("Expanded " .. tostring(count) .. " folder nodes.")
end

local function decode_channel_flag(flag, fallback_count)
  flag = math.floor(tonumber(flag) or 0)
  if flag < 0 then return 1, 0 end
  local start = (flag & 1023) + 1
  local count = flag >> 10
  if count <= 0 then count = fallback_count or 2 end
  return start, count
end

local function channel_flag(start_channel, count)
  start_channel = clamp(math.floor(tonumber(start_channel) or 1), 1, 128)
  count = clamp(math.floor(tonumber(count) or 2), 1, 128)
  return (start_channel - 1) | (count << 10)
end

local function find_connection(connections, key)
  if not key then return nil end
  for _, c in ipairs(connections) do
    if c.key == key then return c end
  end
  return nil
end

local function find_existing_send_index(source_track, dest_track)
  if not (source_track and dest_track) then return nil end
  for s = 0, reaper.GetTrackNumSends(source_track, 0) - 1 do
    local existing_dest = reaper.GetTrackSendInfo_Value(source_track, 0, s, "P_DESTTRACK")
    if existing_dest == dest_track then return s end
  end
  return nil
end

local function create_track_send(source_node, dest_node)
  if not (source_node and dest_node and source_node.track and dest_node.track) then return false end
  if source_node.track == dest_node.track then
    status = "Cannot create a send to the same track."
    return false
  end
  local existing_index = find_existing_send_index(source_node.track, dest_node.track)
  if existing_index ~= nil then
    selected_connection_key = send_key(source_node.guid, existing_index)
    selected_node_key = nil
    status = "Send already exists. Selected existing wire."
    return false
  end
  reaper.Undo_BeginBlock()
  local send_index = reaper.CreateTrackSend(source_node.track, dest_node.track)
  if send_index and send_index >= 0 then
    local count = math.max(1, math.min(source_node.channels or 2, dest_node.channels or 2))
    reaper.SetTrackSendInfo_Value(source_node.track, 0, send_index, "D_VOL", 1.0)
    reaper.SetTrackSendInfo_Value(source_node.track, 0, send_index, "I_SRCCHAN", channel_flag(1, count))
    reaper.SetTrackSendInfo_Value(source_node.track, 0, send_index, "I_DSTCHAN", channel_flag(1, count))
    selected_connection_key = send_key(source_node.guid, send_index)
    status = "Created send: " .. source_node.name .. " > " .. dest_node.name
    reaper.Undo_EndBlock("Patch Routing View Create Send", -1)
    reaper.UpdateArrange()
    return true
  end
  reaper.Undo_EndBlock("Patch Routing View Create Send", -1)
  status = "Could not create send."
  return false
end

local function remove_track_send(connection)
  if not (connection and connection.kind == "send" and connection.source and connection.source.track) then return end
  reaper.Undo_BeginBlock()
  reaper.RemoveTrackSend(connection.source.track, 0, connection.send_index)
  selected_connection_key = nil
  status = "Removed send: " .. connection.source.name .. " > " .. connection.dest.name
  reaper.Undo_EndBlock("Patch Routing View Remove Send", -1)
  reaper.UpdateArrange()
end

local function collect_graph()
  local nodes = {}
  local by_track = {}
  local entries = {}

  for i = 0, reaper.CountTracks(PROJECT) - 1 do
    local track = reaper.GetTrack(PROJECT, i)
    local channels = math.floor(reaper.GetMediaTrackInfo_Value(track, "I_NCHAN") or 2)
    local selected = reaper.IsTrackSelected(track)
    local entry = {
      track = track,
      index = i + 1,
      guid = track_guid(track),
      name = track_name(track, "Track " .. tostring(i + 1)),
      display_name = track_display_name(track, i + 1),
      channels = channels,
      selected = selected,
      folder_depth = track_depth(track),
      fx_count = reaper.TrackFX_GetCount(track),
      send_count = reaper.GetTrackNumSends(track, 0),
      recv_count = reaper.GetTrackNumSends(track, -1),
      muted = (reaper.GetMediaTrackInfo_Value(track, "B_MUTE") or 0) > 0.5,
      solo = (reaper.GetMediaTrackInfo_Value(track, "I_SOLO") or 0) > 0,
      master_send = (reaper.GetMediaTrackInfo_Value(track, "B_MAINSEND") or 0) > 0.5,
      child_count = 0,
    }
    entries[#entries + 1] = entry
  end

  local connections = {}

  for i, entry in ipairs(entries) do
    local parent_index = find_parent_index(entries, i)
    if parent_index then
      entry.parent = entries[parent_index]
      entry.folder_level = (entry.parent.folder_level or 0) + 1
      entry.parent.child_count = (entry.parent.child_count or 0) + 1
    else
      entry.folder_level = 0
    end
  end

  for _, entry in ipairs(entries) do
    local include = true
    if show_selected_only and not entry.selected then include = false end
    if show_multichannel_only and entry.channels <= 2 then include = false end
    if entry.parent and is_folder_collapsed(entry.parent) then include = false end
    if show_connected_only then
      local connected = (entry.send_count or 0) > 0 or (entry.recv_count or 0) > 0 or entry.parent ~= nil or (entry.child_count or 0) > 0 or (entry.master_send and not entry.parent)
      if not connected then include = false end
    end
    if not matches_search(entry) then include = false end
    if include then
      nodes[#nodes + 1] = entry
      by_track[entry.track] = entry
    end
  end

  if show_folders then
    for _, entry in ipairs(entries) do
      if entry.parent and by_track[entry.track] and by_track[entry.parent.track] then
        connections[#connections + 1] = {
          kind = "folder",
          source = entry,
          dest = entry.parent,
          label = "folder",
        }
      end
    end
  end

  if show_sends then
    for _, entry in ipairs(entries) do
      if by_track[entry.track] then
        for s = 0, entry.send_count - 1 do
          local dest = reaper.GetTrackSendInfo_Value(entry.track, 0, s, "P_DESTTRACK")
          local dest_entry = by_track[dest]
          if dest_entry then
            local src_flag = reaper.GetTrackSendInfo_Value(entry.track, 0, s, "I_SRCCHAN")
            local dst_flag = reaper.GetTrackSendInfo_Value(entry.track, 0, s, "I_DSTCHAN")
            local vol = reaper.GetTrackSendInfo_Value(entry.track, 0, s, "D_VOL")
            local mute = reaper.GetTrackSendInfo_Value(entry.track, 0, s, "B_MUTE")
            local mode = reaper.GetTrackSendInfo_Value(entry.track, 0, s, "I_SENDMODE")
            connections[#connections + 1] = {
              kind = "send",
              source = entry,
              dest = dest_entry,
              send_index = s,
              key = send_key(entry.guid, s),
              src_flag = src_flag,
              dst_flag = dst_flag,
              label = source_channel_label(src_flag) .. " > " .. source_channel_label(dst_flag),
              vol = vol,
              mute = (mute or 0) > 0.5,
              mode = math.floor(mode or 0),
            }
          end
        end
      end
    end
  end

  local master = nil
  if show_master then
    master = {
      guid = "master",
      name = "Master",
      index = 0,
      channels = math.floor(reaper.GetMediaTrackInfo_Value(reaper.GetMasterTrack(PROJECT), "I_NCHAN") or 2),
      selected = false,
      fx_count = reaper.TrackFX_GetCount(reaper.GetMasterTrack(PROJECT)),
      send_count = 0,
      recv_count = 0,
      master = true,
    }
    nodes[#nodes + 1] = master
    for _, entry in ipairs(entries) do
      if by_track[entry.track] and entry.master_send and not entry.parent then
        connections[#connections + 1] = { kind = "master", source = entry, dest = master, label = "master" }
      end
    end
  end

  return nodes, connections, entries, master
end

local function layout_nodes(nodes)
  local lane_y = {}
  local track_nodes = {}
  for _, node in ipairs(nodes) do
    if not node.master then track_nodes[#track_nodes + 1] = node end
  end
  local row_count = math.max(1, math.ceil(#track_nodes / 4))
  local max_x = 0
  for _, node in ipairs(nodes) do
    local x, y = saved_pos(node.guid)
    if view_mode == 1 and x and y then
      node.x, node.y = x, y
    elseif view_mode == 3 then
      local lane = node.master and 0 or ((node.folder_level or 0) + 1)
      lane_y[lane] = (lane_y[lane] or 0) + 1
      node.x = 44 + lane * 236
      node.y = 44 + (lane_y[lane] - 1) * 156
    else
      local row = node.master and 0 or (math.floor((node.index - 1) / 4) + 1)
      local col = node.master and 1 or ((node.index - 1) % 4)
      node.x = 40 + col * 220
      node.y = 34 + row * 124
    end
    max_x = math.max(max_x, node.x or 0)
  end
end

local function world_to_screen(x, y, ox, oy)
  return ox + pan_x + x * zoom, oy + pan_y + y * zoom
end

local function screen_to_world(x, y, ox, oy)
  return (x - ox - pan_x) / zoom, (y - oy - pan_y) / zoom
end

local function draw_grid(dl, x0, y0, x1, y1)
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x1, y1, COLORS.bg)
  local step = 64 * zoom
  if step < 18 then step = step * 2 end
  local start_x = x0 + (pan_x % step)
  local start_y = y0 + (pan_y % step)
  local x = start_x
  while x < x1 do
    ImGui.DrawList_AddLine(dl, x, y0, x, y1, COLORS.grid, 1)
    x = x + step
  end
  local y = start_y
  while y < y1 do
    ImGui.DrawList_AddLine(dl, x0, y, x1, y, COLORS.grid, 1)
    y = y + step
  end
end

local function push_canvas_clip(dl, x0, y0, x1, y1)
  if not ImGui.DrawList_PushClipRect then return false end
  local ok = pcall(ImGui.DrawList_PushClipRect, dl, x0, y0, x1, y1, true)
  if not ok then ok = pcall(ImGui.DrawList_PushClipRect, dl, x0, y0, x1, y1) end
  return ok
end

local function pop_canvas_clip(dl, pushed)
  if pushed and ImGui.DrawList_PopClipRect then
    pcall(ImGui.DrawList_PopClipRect, dl)
  end
end

local function bezier(dl, x1, y1, x2, y2, color, thickness)
  local dy = math.max(70 * zoom, math.abs(y2 - y1) * 0.45)
  local dir = y2 >= y1 and 1 or -1
  ImGui.DrawList_AddBezierCubic(dl, x1, y1, x1, y1 + dy * dir, x2, y2 - dy * dir, x2, y2, color, thickness or 2.0)
end

local function node_rect(node, ox, oy)
  local w = (node.master and MASTER_W or NODE_W) * zoom
  local h = (node.master and MASTER_H or NODE_H) * zoom
  local x, y = world_to_screen(node.x, node.y, ox, oy)
  return x, y, x + w, y + h
end

local function node_output(node, ox, oy)
  local x0, y0, x1, y1 = node_rect(node, ox, oy)
  return x0 + (x1 - x0) * 0.50, y0
end

local function node_input(node, ox, oy)
  local x0, _, x1, y1 = node_rect(node, ox, oy)
  return x0 + (x1 - x0) * 0.50, y1
end

local function cubic_point(a, b, c, d, t)
  local mt = 1 - t
  return mt * mt * mt * a + 3 * mt * mt * t * b + 3 * mt * t * t * c + t * t * t * d
end

local function connection_screen_points(c, ox, oy)
  local sx, sy = node_output(c.source, ox, oy)
  local dx, dy2 = node_input(c.dest, ox, oy)
  local bend = math.max(70 * zoom, math.abs(dy2 - sy) * 0.45)
  local dir = dy2 >= sy and 1 or -1
  return sx, sy, sx, sy + bend * dir, dx, dy2 - bend * dir, dx, dy2
end

local function distance_to_segment(px, py, ax, ay, bx, by)
  local vx, vy = bx - ax, by - ay
  local wx, wy = px - ax, py - ay
  local len2 = vx * vx + vy * vy
  if len2 <= 0.000001 then return math.sqrt((px - ax) ^ 2 + (py - ay) ^ 2) end
  local t = clamp((wx * vx + wy * vy) / len2, 0, 1)
  local x, y = ax + vx * t, ay + vy * t
  return math.sqrt((px - x) ^ 2 + (py - y) ^ 2)
end

local function connection_hit(c, mx, my, ox, oy)
  local x1, y1, cx1, cy1, cx2, cy2, x2, y2 = connection_screen_points(c, ox, oy)
  local last_x, last_y = x1, y1
  local best = math.huge
  for i = 1, 20 do
    local t = i / 20
    local x = cubic_point(x1, cx1, cx2, x2, t)
    local y = cubic_point(y1, cy1, cy2, y2, t)
    best = math.min(best, distance_to_segment(mx, my, last_x, last_y, x, y))
    last_x, last_y = x, y
  end
  return best <= math.max(7, 6 * zoom)
end

local function draw_connections(dl, connections, ox, oy)
  for i, c in ipairs(connections) do
    local sx, sy = node_output(c.source, ox, oy)
    local dx, dy = node_input(c.dest, ox, oy)
    local color = COLORS.send
    local thick = 2.0
    if c.kind == "folder" then
      color = COLORS.folder
      thick = 1.8
    elseif c.kind == "master" then
      color = COLORS.master
      thick = 1.4
    end
    if c.mute or (c.source and c.source.muted) then
      color = rgba(0.32, 0.35, 0.36, 0.38)
      thick = math.max(1.0, thick - 0.5)
    end
    if hovered_connection_key and c.key == hovered_connection_key then thick = thick + 1.2 end
    if selected_connection_key and c.key == selected_connection_key then thick = thick + 1.8 end
    bezier(dl, sx, sy, dx, dy, color, thick)
    local mx, my = (sx + dx) * 0.5, (sy + dy) * 0.5
    local label_visible = not labels_hover_only or (c.key and (c.key == hovered_connection_key or c.key == selected_connection_key))
    if zoom > 0.72 and c.kind ~= "master" and label_visible then
      ImGui.DrawList_AddText(dl, mx + 5, my - 7, COLORS.muted, c.label or c.kind)
    end
  end
end

local function draw_node(dl, node, ox, oy)
  local x0, y0, x1, y1 = node_rect(node, ox, oy)
  local selected = selected_node_key == node.guid or selected_node_keys[node.guid]
  local fill = node.master and COLORS.node_bus or COLORS.node
  if selected then fill = COLORS.node_sel end
  if node.solo and not selected then fill = rgba(0.130, 0.125, 0.075, 0.96) end
  if node.muted and not selected then fill = rgba(0.070, 0.074, 0.078, 0.68) end
  local accent = node.master and COLORS.master or track_color(node.track, 0.92, COLORS.edge)
  if node.solo then accent = rgba(0.95, 0.78, 0.32, 0.95) end
  if node.muted then accent = rgba(0.25, 0.27, 0.28, 0.80) end
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x1, y1, fill)
  ImGui.DrawList_AddRect(dl, x0, y0, x1, y1, selected and COLORS.text or COLORS.edge, 0, 0, selected and 2.2 or 1.2)
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x0 + 5 * zoom, y1, accent)

  local in_x, in_y = node_input(node, ox, oy)
  local out_x, out_y = node_output(node, ox, oy)
  local pin = math.max(4, 4 * zoom)
  ImGui.DrawList_AddRectFilled(dl, in_x - pin, in_y - pin, in_x + pin, in_y + pin, COLORS.pin)
  ImGui.DrawList_AddRectFilled(dl, out_x - pin, out_y - pin, out_x + pin, out_y + pin, COLORS.pin)

  if zoom > 0.42 and not node.master then
    local badge_w = math.max(18, 18 * zoom)
    local badge_h = math.max(15, 15 * zoom)
    local bx = x1 - 9 * zoom - badge_w
    local by = y0 + 8 * zoom
    local function badge(label, color, text_color)
      ImGui.DrawList_AddRectFilled(dl, bx, by, bx + badge_w, by + badge_h, color)
      ImGui.DrawList_AddRect(dl, bx, by, bx + badge_w, by + badge_h, rgba(0.02, 0.02, 0.02, 0.55), 0, 0, 1)
      if zoom > 0.58 then
        ImGui.DrawList_AddText(dl, bx + 5 * zoom, by + 1 * zoom, text_color or COLORS.text, label)
      end
      bx = bx - badge_w - 4 * zoom
    end
    if node.muted then badge("M", rgba(0.55, 0.17, 0.14, 0.92), rgba(1.0, 0.82, 0.76, 1)) end
    if node.solo then badge("S", rgba(0.88, 0.63, 0.20, 0.94), rgba(0.08, 0.07, 0.04, 1)) end
  end

  if zoom > 0.48 then
    local tx = x0 + 12 * zoom
    local ty = y0 + 9 * zoom
    local id_label = node.master and "MASTER" or ("TR" .. tostring(node.index))
    ImGui.DrawList_AddText(dl, tx, ty, COLORS.text, id_label)
    local name_label = node.master and "master output" or short_name(node.display_name or "", 13)
    if name_label ~= "" then
      ImGui.DrawList_AddText(dl, tx, ty + 18 * zoom, COLORS.muted, name_label)
    end
    local info = string.format("%dch  FX:%d", node.channels or 2, node.fx_count or 0)
    ImGui.DrawList_AddText(dl, tx, ty + 36 * zoom, COLORS.muted, info)
    if not node.master then
      ImGui.DrawList_AddText(dl, tx, ty + 54 * zoom, COLORS.muted, string.format("Sends: %d", node.send_count or 0))
      ImGui.DrawList_AddText(dl, tx, ty + 72 * zoom, COLORS.muted, string.format("Receives: %d", node.recv_count or 0))
      local route_label = node.parent and "parent on" or (node.master_send and "master on" or "master off")
      local route_color = (node.parent or node.master_send) and COLORS.master or COLORS.warn
      ImGui.DrawList_AddText(dl, tx, ty + 90 * zoom, route_color, route_label)
    end
  end

  if is_folder_collapsed(node) and not node.master and (node.child_count or 0) > 0 then
    local count = math.min(node.child_count or 0, 10)
    local bar_w = math.max(10, (x1 - x0 - 24 * zoom) / math.max(1, count))
    local y = y1 - 9 * zoom
    for i = 1, count do
      local bx0 = x0 + 12 * zoom + (i - 1) * bar_w
      local bx1 = bx0 + math.max(5, bar_w - 2)
      ImGui.DrawList_AddRectFilled(dl, bx0, y, bx1, y + 4 * zoom, COLORS.folder)
    end
    if (node.child_count or 0) > count then
      ImGui.DrawList_AddText(dl, x1 - 26 * zoom, y1 - 17 * zoom, COLORS.folder, "+" .. tostring((node.child_count or 0) - count))
    end
  end
end

local function hit_node(nodes, mx, my, ox, oy)
  for i = #nodes, 1, -1 do
    local node = nodes[i]
    local x0, y0, x1, y1 = node_rect(node, ox, oy)
    if mx >= x0 and mx <= x1 and my >= y0 and my <= y1 then return node end
  end
  return nil
end

local function rects_intersect(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1)
  return ax0 <= bx1 and ax1 >= bx0 and ay0 <= by1 and ay1 >= by0
end

local function marquee_bounds(drag)
  local x0 = math.min(drag.x0, drag.x1)
  local y0 = math.min(drag.y0, drag.y1)
  local x1 = math.max(drag.x0, drag.x1)
  local y1 = math.max(drag.y0, drag.y1)
  return x0, y0, x1, y1
end

local function clear_node_selection()
  selected_node_key = nil
  selected_node_keys = {}
  for i = 0, reaper.CountTracks(PROJECT) - 1 do
    reaper.SetTrackSelected(reaper.GetTrack(PROJECT, i), false)
  end
end

local function apply_reaper_node_selection(nodes)
  for i = 0, reaper.CountTracks(PROJECT) - 1 do
    reaper.SetTrackSelected(reaper.GetTrack(PROJECT, i), false)
  end
  for _, node in ipairs(nodes) do
    if node.track and selected_node_keys[node.guid] then
      reaper.SetTrackSelected(node.track, true)
    end
  end
  reaper.UpdateArrange()
end

local function select_single_node(node)
  selected_node_keys = {}
  selected_node_key = node and node.guid or nil
  if node and node.guid then selected_node_keys[node.guid] = true end
end

local function toggle_node_selection(node)
  if not (node and node.guid) then return end
  if selected_node_keys[node.guid] then
    selected_node_keys[node.guid] = nil
    if selected_node_key == node.guid then selected_node_key = nil end
  else
    selected_node_keys[node.guid] = true
    selected_node_key = node.guid
  end
end

local function selected_node_count()
  local count = 0
  for _, selected in pairs(selected_node_keys) do
    if selected then count = count + 1 end
  end
  return count
end

local function capture_drag_group(nodes)
  local group = {}
  for _, node in ipairs(nodes) do
    if selected_node_keys[node.guid] then
      group[#group + 1] = { node = node, x = node.x, y = node.y }
    end
  end
  return group
end

local function distance(x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

local function hit_output_pin(nodes, mx, my, ox, oy, pin_only)
  for i = #nodes, 1, -1 do
    local node = nodes[i]
    if node.track then
      local x0, y0, x1 = node_rect(node, ox, oy)
      local px, py = node_output(node, ox, oy)
      local band_h = math.max(18, 20 * zoom)
      if not pin_only and mx >= x0 and mx <= x1 and my >= y0 - band_h * 0.5 and my <= y0 + band_h then return node end
      if distance(mx, my, px, py) <= math.max(14, 12 * zoom) then return node end
    end
  end
  return nil
end

local function hit_input_pin(nodes, mx, my, ox, oy, exclude_node)
  for i = #nodes, 1, -1 do
    local node = nodes[i]
    if node.track and node ~= exclude_node then
      local x0, _, x1, y1 = node_rect(node, ox, oy)
      local px, py = node_input(node, ox, oy)
      local band_h = math.max(20, 22 * zoom)
      if mx >= x0 and mx <= x1 and my >= y1 - band_h and my <= y1 + band_h * 0.5 then return node end
      if distance(mx, my, px, py) <= math.max(16, 13 * zoom) then return node end
    end
  end
  return nil
end

local function select_track(node)
  select_single_node(node)
  if node and node.track then
    reaper.SetOnlyTrackSelected(node.track)
    reaper.SetMixerScroll(node.track)
    status = "Selected " .. node.name
  elseif node and node.master then
    status = "Selected master node"
  end
end

local function graph_bounds(nodes)
  local min_x, min_y = math.huge, math.huge
  local max_x, max_y = -math.huge, -math.huge
  for _, node in ipairs(nodes or {}) do
    local w = node.master and MASTER_W or NODE_W
    local h = node.master and MASTER_H or NODE_H
    min_x = math.min(min_x, node.x or 0)
    min_y = math.min(min_y, node.y or 0)
    max_x = math.max(max_x, (node.x or 0) + w)
    max_y = math.max(max_y, (node.y or 0) + h)
  end
  if min_x == math.huge then return 0, 0, 1, 1 end
  local margin = 120
  return min_x - margin, min_y - margin, max_x + margin, max_y + margin
end

local function draw_minimap(dl, nodes, canvas_x0, canvas_y0, canvas_x1, canvas_y1, mx, my)
  local map_w, map_h = 154, 104
  local pad = 12
  local mx0 = canvas_x1 - map_w - pad
  local my0 = canvas_y0 + pad
  local mx1 = mx0 + map_w
  local my1 = my0 + map_h
  local over = mx >= mx0 and mx <= mx1 and my >= my0 and my <= my1
  local bg = over and rgba(0.075, 0.080, 0.084, 0.94) or rgba(0.055, 0.060, 0.064, 0.86)
  ImGui.DrawList_AddRectFilled(dl, mx0, my0, mx1, my1, bg)
  ImGui.DrawList_AddRect(dl, mx0, my0, mx1, my1, COLORS.edge, 0, 0, 1.0)
  ImGui.DrawList_AddText(dl, mx0 + 8, my0 + 6, COLORS.muted, "map")

  local bx0, by0, bx1, by1 = graph_bounds(nodes)
  local bw, bh = math.max(1, bx1 - bx0), math.max(1, by1 - by0)
  local inner_x0, inner_y0 = mx0 + 10, my0 + 24
  local inner_x1, inner_y1 = mx1 - 10, my1 - 10
  local inner_w, inner_h = inner_x1 - inner_x0, inner_y1 - inner_y0
  local scale = math.min(inner_w / bw, inner_h / bh)
  local off_x = inner_x0 + (inner_w - bw * scale) * 0.5
  local off_y = inner_y0 + (inner_h - bh * scale) * 0.5

  local function map_point(wx, wy)
    return off_x + (wx - bx0) * scale, off_y + (wy - by0) * scale
  end

  for _, node in ipairs(nodes or {}) do
    local w = node.master and MASTER_W or NODE_W
    local h = node.master and MASTER_H or NODE_H
    local nx0, ny0 = map_point(node.x or 0, node.y or 0)
    local nx1, ny1 = map_point((node.x or 0) + w, (node.y or 0) + h)
    local selected = selected_node_key == node.guid or selected_node_keys[node.guid]
    local color = selected and COLORS.node_sel or (node.master and COLORS.master or track_color(node.track, 0.68, rgba(0.42, 0.45, 0.46, 0.70)))
    if node.solo then color = rgba(0.88, 0.63, 0.20, 0.82) end
    if node.muted then color = rgba(0.42, 0.14, 0.12, 0.78) end
    ImGui.DrawList_AddRectFilled(dl, nx0, ny0, nx1, ny1, color)
  end

  local vx0 = -pan_x / zoom
  local vy0 = -pan_y / zoom
  local vx1 = (canvas_x1 - canvas_x0 - pan_x) / zoom
  local vy1 = (canvas_y1 - canvas_y0 - pan_y) / zoom
  local sx0, sy0 = map_point(vx0, vy0)
  local sx1, sy1 = map_point(vx1, vy1)
  sx0, sx1 = clamp(sx0, inner_x0, inner_x1), clamp(sx1, inner_x0, inner_x1)
  sy0, sy1 = clamp(sy0, inner_y0, inner_y1), clamp(sy1, inner_y0, inner_y1)
  ImGui.DrawList_AddRect(dl, sx0, sy0, sx1, sy1, COLORS.text, 0, 0, 1.2)

  if over and not dragging_key and not patch_drag and not marquee_drag and ImGui.IsMouseDown(ctx, 0) then
    local wx = bx0 + ((mx - off_x) / scale)
    local wy = by0 + ((my - off_y) / scale)
    pan_x = (canvas_x1 - canvas_x0) * 0.5 - wx * zoom
    pan_y = (canvas_y1 - canvas_y0) * 0.5 - wy * zoom
    status = "Minimap: centered patch view."
  end

  return over
end

local function draw_canvas(nodes, connections)
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  avail_h = math.max(360, avail_h - 6)
  ImGui.InvisibleButton(ctx, "##patch_canvas", avail_w, avail_h)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = ImGui.GetItemRectMax(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  draw_grid(dl, x0, y0, x1, y1)
  ImGui.DrawList_AddRect(dl, x0, y0, x1, y1, COLORS.edge, 0, 0, 1.2)

  local clipped = push_canvas_clip(dl, x0 + 1, y0 + 1, x1 - 1, y1 - 1)
  if not wires_front then draw_connections(dl, connections, x0, y0) end
  for _, node in ipairs(nodes) do draw_node(dl, node, x0, y0) end
  if wires_front then draw_connections(dl, connections, x0, y0) end

  local mx, my = ImGui.GetMousePos(ctx)
  local hovered = ImGui.IsItemHovered(ctx)
  if hovered and edit_mode and not patch_drag then
    local send_node = hit_output_pin(nodes, mx, my, x0, y0)
    if send_node then
      local nx0, ny0, nx1 = node_rect(send_node, x0, y0)
      ImGui.DrawList_AddRectFilled(dl, nx0, ny0 - 4 * zoom, nx1, ny0 + 16 * zoom, rgba(0.94, 0.50, 0.34, 0.16))
      status = "Send band: drag upward to a receive band."
    else
      local receive_node = hit_input_pin(nodes, mx, my, x0, y0, nil)
      if receive_node then
        local nx0, _, nx1, ny1 = node_rect(receive_node, x0, y0)
        ImGui.DrawList_AddRectFilled(dl, nx0, ny1 - 18 * zoom, nx1, ny1 + 4 * zoom, rgba(0.94, 0.50, 0.34, 0.16))
        status = "Receive band: drag downward to a send band."
      end
    end
  end
  hovered_connection_key = nil
  if hovered and not patch_drag then
    for i = #connections, 1, -1 do
      local c = connections[i]
      if c.kind == "send" and connection_hit(c, mx, my, x0, y0) then
        hovered_connection_key = c.key
        status = "Wire: " .. c.source.name .. " > " .. c.dest.name .. "  " .. (c.label or "")
        break
      end
    end
  end
  if patch_drag then
    local sx, sy
    if patch_drag.kind == "receive" then
      sx, sy = node_input(patch_drag.dest, x0, y0)
    else
      sx, sy = node_output(patch_drag.source, x0, y0)
    end
    bezier(dl, sx, sy, mx, my, COLORS.warn, 2.4)
    local target = patch_drag.kind == "receive"
      and hit_output_pin(nodes, mx, my, x0, y0, false)
      or hit_input_pin(nodes, mx, my, x0, y0, patch_drag.source)
    if target then
      local tx, ty
      if patch_drag.kind == "receive" then
        tx, ty = node_output(target, x0, y0)
      else
        tx, ty = node_input(target, x0, y0)
      end
      local halo = math.max(10, 10 * zoom)
      local pin = math.max(4, 4 * zoom)
      local nx0, ny0, nx1, ny1 = node_rect(target, x0, y0)
      if patch_drag.kind == "receive" then
        ImGui.DrawList_AddRectFilled(dl, nx0, ny0 - 4 * zoom, nx1, ny0 + 16 * zoom, rgba(0.94, 0.50, 0.34, 0.18))
      else
        ImGui.DrawList_AddRectFilled(dl, nx0, ny1 - 18 * zoom, nx1, ny1 + 4 * zoom, rgba(0.94, 0.50, 0.34, 0.18))
      end
      ImGui.DrawList_AddRectFilled(dl, tx - halo, ty - halo, tx + halo, ty + halo, rgba(0.94, 0.50, 0.34, 0.28))
      ImGui.DrawList_AddRectFilled(dl, tx - pin, ty - pin, tx + pin, ty + pin, COLORS.warn)
    end
  end
  if marquee_drag then
    marquee_drag.x1, marquee_drag.y1 = mx, my
    local rx0, ry0, rx1, ry1 = marquee_bounds(marquee_drag)
    ImGui.DrawList_AddRectFilled(dl, rx0, ry0, rx1, ry1, rgba(0.62, 0.69, 0.72, 0.13))
    ImGui.DrawList_AddRect(dl, rx0, ry0, rx1, ry1, COLORS.active or COLORS.text, 0, 0, 1.2)
  end
  pop_canvas_clip(dl, clipped)
  local minimap_hovered = draw_minimap(dl, nodes, x0, y0, x1, y1, mx, my)
  local wheel = 0
  if ImGui.GetMouseWheel then
    local ok, value = pcall(ImGui.GetMouseWheel, ctx)
    if ok and value then wheel = value end
  end
  if hovered and wheel ~= 0 then
    local wx, wy = screen_to_world(mx, my, x0, y0)
    zoom = clamp(zoom * (wheel > 0 and 1.10 or 0.91), 0.35, 2.2)
    pan_x = mx - x0 - wx * zoom
    pan_y = my - y0 - wy * zoom
    status = string.format("Zoom %.0f%%", zoom * 100)
  end

  if hovered and not minimap_hovered and ImGui.IsMouseClicked(ctx, 0) then
    local shift_down = shift_is_down()
    local output_node = (edit_mode and not shift_down) and hit_output_pin(nodes, mx, my, x0, y0, false) or nil
    local input_node = (edit_mode and not shift_down and not output_node) and hit_input_pin(nodes, mx, my, x0, y0, nil) or nil
    local node = hit_node(nodes, mx, my, x0, y0)
    if output_node then
      patch_drag = { kind = "send", source = output_node }
      selected_node_key = output_node.guid
      status = "Drag from send band to a receive band to create a send."
    elseif input_node then
      patch_drag = { kind = "receive", dest = input_node }
      selected_node_key = input_node.guid
      status = "Drag from receive band to a send band to create a send."
    elseif hovered_connection_key then
      selected_connection_key = hovered_connection_key
      status = "Selected wire. Use inspector to edit or remove the send."
    elseif node then
      if shift_down then
        toggle_node_selection(node)
        apply_reaper_node_selection(nodes)
        status = "Toggled " .. node_label(node, 18)
      else
        if not selected_node_keys[node.guid] then
          select_track(node)
        else
          selected_node_key = node.guid
          apply_reaper_node_selection(nodes)
        end
        dragging_key = node.guid
        drag_group = selected_node_count() > 1 and capture_drag_group(nodes) or nil
        local wx, wy = screen_to_world(mx, my, x0, y0)
        drag_dx, drag_dy = wx - node.x, wy - node.y
        drag_origin_x, drag_origin_y = node.x, node.y
      end
    else
      marquee_drag = { x0 = mx, y0 = my, x1 = mx, y1 = my, add = shift_down }
      selected_connection_key = nil
    end
  end

  if hovered and not minimap_hovered and ImGui.IsMouseClicked(ctx, 1) then
    panning = true
    pan_start_x, pan_start_y = mx, my
    pan_base_x, pan_base_y = pan_x, pan_y
  end

  if panning and ImGui.IsMouseDown(ctx, 1) then
    pan_x = pan_base_x + (mx - pan_start_x)
    pan_y = pan_base_y + (my - pan_start_y)
  elseif panning then
    panning = false
  end

  if patch_drag and ImGui.IsMouseReleased(ctx, 0) then
    local target = patch_drag.kind == "receive"
      and hit_output_pin(nodes, mx, my, x0, y0, false)
      or hit_input_pin(nodes, mx, my, x0, y0, patch_drag.source)
    if target and patch_drag.kind == "receive" then
      create_track_send(target, patch_drag.dest)
    elseif target then
      create_track_send(patch_drag.source, target)
    else
      status = "Send creation cancelled."
    end
    patch_drag = nil
  end

  if marquee_drag and ImGui.IsMouseReleased(ctx, 0) then
    local rx0, ry0, rx1, ry1 = marquee_bounds(marquee_drag)
    local moved = math.abs(rx1 - rx0) > 4 or math.abs(ry1 - ry0) > 4
    if not marquee_drag.add and moved then selected_node_keys = {} end
    if moved then
      selected_node_key = nil
      for _, node in ipairs(nodes) do
        if node.track then
          local nx0, ny0, nx1, ny1 = node_rect(node, x0, y0)
          if rects_intersect(rx0, ry0, rx1, ry1, nx0, ny0, nx1, ny1) then
            selected_node_keys[node.guid] = true
            selected_node_key = node.guid
          end
        end
      end
      apply_reaper_node_selection(nodes)
      status = "Selected nodes by marquee."
    elseif not marquee_drag.add then
      clear_node_selection()
      selected_connection_key = nil
      status = "Cleared selection."
    end
    marquee_drag = nil
  end

  if dragging_key and not patch_drag and not marquee_drag and ImGui.IsMouseDown(ctx, 0) then
    local wx, wy = screen_to_world(mx, my, x0, y0)
    local target_x, target_y = wx - drag_dx, wy - drag_dy
    local dx, dy = target_x - drag_origin_x, target_y - drag_origin_y
    for _, node in ipairs(nodes) do
      if node.guid == dragging_key then
        if not drag_group then
          node.x = target_x
          node.y = target_y
          save_pos(node.guid, node.x, node.y)
        end
        if view_mode ~= 1 then view_mode = 1 end
        break
      end
    end
    if drag_group then
      for _, item in ipairs(drag_group) do
        item.node.x = item.x + dx
        item.node.y = item.y + dy
        save_pos(item.node.guid, item.node.x, item.node.y)
      end
      status = "Moved selected nodes."
    end
  elseif dragging_key then
    dragging_key = nil
    drag_group = nil
  end

  if hovered and not minimap_hovered and ImGui.IsMouseDoubleClicked(ctx, 0) then
    local node = hit_node(nodes, mx, my, x0, y0)
    if node and node.track then
      reaper.Main_OnCommand(40291, 0) -- Track: View FX chain for current/last touched track
      status = "Opened FX chain for " .. node.name
    end
  end

  if zoom > 0.55 then
    local help = edit_mode and "Edit: drag send > receive or receive > send. Shift-click toggles. Blank drag selects."
      or "View: drag nodes. Shift-click toggles. Blank drag selects. Right-drag pans. Wheel zooms."
    ImGui.DrawList_AddText(dl, x0 + 10, y1 - 22, COLORS.muted, help)
  end
end

local function selected_node(nodes)
  if not selected_node_key then return nil end
  for _, node in ipairs(nodes) do
    if node.guid == selected_node_key then return node end
  end
  return nil
end

local function clamp_channel_range(start_channel, count, max_channels)
  max_channels = math.max(1, math.floor(max_channels or 2))
  start_channel = clamp(math.floor(start_channel or 1), 1, max_channels)
  count = clamp(math.floor(count or 1), 1, max_channels - start_channel + 1)
  return start_channel, count
end

local function draw_send_editor(connection)
  if not (connection and connection.kind == "send") then return end
  ImGui.Text(ctx, "Selected Send")
  ImGui.TextColored(ctx, COLORS.muted, connection.source.name .. " > " .. connection.dest.name)
  ImGui.Separator(ctx)

  local changed, vol = ImGui.SliderDouble(ctx, "Level##selected_send_level", connection.vol or 1, 0.0, 2.0, "%.3f")
  if changed then
    reaper.SetTrackSendInfo_Value(connection.source.track, 0, connection.send_index, "D_VOL", vol)
    status = "Send level: " .. db_label(vol)
  end
  ImGui.SameLine(ctx)
  ImGui.TextColored(ctx, COLORS.muted, db_label(vol))

  local mute = connection.mute or false
  changed, mute = ImGui.Checkbox(ctx, "Mute send##selected_send_mute", mute)
  if changed then
    reaper.SetTrackSendInfo_Value(connection.source.track, 0, connection.send_index, "B_MUTE", mute and 1 or 0)
    status = mute and "Muted selected send." or "Unmuted selected send."
  end

  ImGui.SetNextItemWidth(ctx, 132)
  local new_mode = send_mode_combo("Mode##selected_send_mode", connection.mode or 0)
  if new_mode ~= (connection.mode or 0) then
    reaper.SetTrackSendInfo_Value(connection.source.track, 0, connection.send_index, "I_SENDMODE", new_mode)
    status = "Send mode: " .. send_mode_name(new_mode)
  end

  local src_start, src_count = decode_channel_flag(connection.src_flag, math.min(connection.source.channels or 2, connection.dest.channels or 2))
  local dst_start, dst_count = decode_channel_flag(connection.dst_flag, src_count)
  src_start, src_count = clamp_channel_range(src_start, src_count, connection.source.channels or 2)
  dst_start, dst_count = clamp_channel_range(dst_start, dst_count, connection.dest.channels or 2)

  ImGui.Spacing(ctx)
  ImGui.Text(ctx, "Channel Map")
  changed, src_start = ImGui.SliderInt(ctx, "Source start##selected_send_src_start", src_start, 1, math.max(1, connection.source.channels or 2))
  if changed then
    src_start, src_count = clamp_channel_range(src_start, src_count, connection.source.channels or 2)
    reaper.SetTrackSendInfo_Value(connection.source.track, 0, connection.send_index, "I_SRCCHAN", channel_flag(src_start, src_count))
    status = "Updated send source channels."
  end
  changed, src_count = ImGui.SliderInt(ctx, "Source count##selected_send_src_count", src_count, 1, math.max(1, (connection.source.channels or 2) - src_start + 1))
  if changed then
    src_start, src_count = clamp_channel_range(src_start, src_count, connection.source.channels or 2)
    reaper.SetTrackSendInfo_Value(connection.source.track, 0, connection.send_index, "I_SRCCHAN", channel_flag(src_start, src_count))
    status = "Updated send source channels."
  end
  changed, dst_start = ImGui.SliderInt(ctx, "Dest start##selected_send_dst_start", dst_start, 1, math.max(1, connection.dest.channels or 2))
  if changed then
    dst_start, dst_count = clamp_channel_range(dst_start, dst_count, connection.dest.channels or 2)
    reaper.SetTrackSendInfo_Value(connection.source.track, 0, connection.send_index, "I_DSTCHAN", channel_flag(dst_start, dst_count))
    status = "Updated send destination channels."
  end
  changed, dst_count = ImGui.SliderInt(ctx, "Dest count##selected_send_dst_count", dst_count, 1, math.max(1, (connection.dest.channels or 2) - dst_start + 1))
  if changed then
    dst_start, dst_count = clamp_channel_range(dst_start, dst_count, connection.dest.channels or 2)
    reaper.SetTrackSendInfo_Value(connection.source.track, 0, connection.send_index, "I_DSTCHAN", channel_flag(dst_start, dst_count))
    status = "Updated send destination channels."
  end

  ImGui.Spacing(ctx)
  if ImGui.Button(ctx, "Remove Send", 112, 24) then
    remove_track_send(connection)
  end
end

local function child_entries_for(node, entries)
  local children = {}
  if not node then return children end
  for _, entry in ipairs(entries) do
    if entry.parent == node then children[#children + 1] = entry end
  end
  return children
end

local function set_track_mute(node, muted)
  if not (node and node.track) then return end
  reaper.Undo_BeginBlock()
  reaper.SetMediaTrackInfo_Value(node.track, "B_MUTE", muted and 1 or 0)
  reaper.Undo_EndBlock("Patch Routing View Mute Track", -1)
  reaper.UpdateArrange()
  status = muted and ("Muted " .. node.name) or ("Unmuted " .. node.name)
end

local function set_track_solo(node, solo)
  if not (node and node.track) then return end
  reaper.Undo_BeginBlock()
  reaper.SetMediaTrackInfo_Value(node.track, "I_SOLO", solo and 1 or 0)
  reaper.Undo_EndBlock("Patch Routing View Solo Track", -1)
  reaper.UpdateArrange()
  status = solo and ("Soloed " .. node.name) or ("Unsoloed " .. node.name)
end

local function set_master_send(node, enabled)
  if not (node and node.track) then return end
  reaper.Undo_BeginBlock()
  reaper.SetMediaTrackInfo_Value(node.track, "B_MAINSEND", enabled and 1 or 0)
  reaper.Undo_EndBlock("Patch Routing View Master Send", -1)
  reaper.UpdateArrange()
  status = enabled and ("Master send on: " .. node.name) or ("Master send off: " .. node.name)
end

local function draw_wire_key()
  ImGui.Text(ctx, "Wire Colors")
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local function key_line(offset_y, color, label)
    ImGui.DrawList_AddRectFilled(dl, x, y + offset_y + 5, x + 34, y + offset_y + 9, color)
    ImGui.DrawList_AddText(dl, x + 42, y + offset_y, COLORS.muted, label)
  end
  key_line(0, COLORS.send, "send / receive")
  key_line(18, COLORS.folder, "folder: child / parent")
  key_line(36, COLORS.master, "master send")
  ImGui.Dummy(ctx, 1, 58)
end

local function draw_inspector(node, connections, entries)
  ImGui.Text(ctx, "Inspector")
  ImGui.Separator(ctx)
  local selected_send = find_connection(connections, selected_connection_key)
  if selected_send then
    draw_send_editor(selected_send)
    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
  end
  if not node then
    ImGui.TextColored(ctx, COLORS.muted, "Select a node.")
    ImGui.TextWrapped(ctx, edit_mode and "Edit mode: drag send to receive, or receive to send, to create a track send." or "View mode: select tracks, inspect routing, and arrange nodes without changing routing.")
    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    draw_wire_key()
    return
  end
  ImGui.Text(ctx, node.name)
  ImGui.TextColored(ctx, COLORS.muted, node.master and "Master track" or ("Track " .. tostring(node.index)))
  ImGui.Separator(ctx)
  ImGui.Text(ctx, string.format("Channels: %d", node.channels or 2))
    ImGui.Text(ctx, string.format("FX: %d", node.fx_count or 0))
  local children = child_entries_for(node, entries)
  if not node.master then
    ImGui.Text(ctx, string.format("Sends: %d", node.send_count or 0))
    ImGui.Text(ctx, string.format("Receives: %d", node.recv_count or 0))
    if #children > 0 then ImGui.Text(ctx, string.format("Children: %d", #children)) end
    if node.parent then
      ImGui.Text(ctx, "Parent folder: " .. node_label(node.parent, 18))
    else
      ImGui.Text(ctx, node.master_send and "Master send: on" or "Master send: off")
    end
    local changed_mute, muted = ImGui.Checkbox(ctx, "Mute track##selected_track_mute", node.muted or false)
    if changed_mute then set_track_mute(node, muted) end
    local changed_solo, solo = ImGui.Checkbox(ctx, "Solo track##selected_track_solo", node.solo or false)
    if changed_solo then set_track_solo(node, solo) end
    if #children > 0 then
      local collapsed = is_folder_collapsed(node)
      local changed_collapse
      changed_collapse, collapsed = ImGui.Checkbox(ctx, "Collapse children##selected_folder_collapse", collapsed)
      if changed_collapse then
        set_folder_collapsed(node, collapsed)
        status = collapsed and ("Collapsed children for " .. node.name) or ("Expanded children for " .. node.name)
      end
    end
    if not node.parent then
      local changed_master, master_enabled = ImGui.Checkbox(ctx, "Master send##selected_track_master_send", node.master_send or false)
      if changed_master then set_master_send(node, master_enabled) end
    end
    if ImGui.Button(ctx, "FX Chain", 88, 24) then
      select_track(node)
      reaper.Main_OnCommand(40291, 0)
    end
  end

  ImGui.Spacing(ctx)
  draw_wire_key()

  ImGui.Spacing(ctx)
  if (node.parent or #children > 0) and ImGui.CollapsingHeader(ctx, "Folder", ImGui.TreeNodeFlags_DefaultOpen or 32) then
    if node.parent then
      ImGui.Text(ctx, "Parent")
      ImGui.TextColored(ctx, COLORS.muted, "  " .. node_label(node.parent, 24))
    end
    if #children > 0 then
      ImGui.Text(ctx, "Children")
      for _, child in ipairs(children) do
        ImGui.TextColored(ctx, COLORS.muted, "  " .. node_label(child, 24))
      end
    end
  end

  ImGui.Spacing(ctx)
  if ImGui.CollapsingHeader(ctx, "Connections", ImGui.TreeNodeFlags_DefaultOpen or 32) then
    for _, c in ipairs(connections) do
      if c.source == node or c.dest == node then
        local arrow = c.source == node and ">" or "<"
        local other = c.source == node and c.dest or c.source
        local text = string.format("%s %s  %s", c.kind, arrow, other.name)
        if c.kind == "send" and c.vol then text = text .. "  " .. db_label(c.vol) end
        ImGui.TextWrapped(ctx, text)
        if c.kind == "send" then
          ImGui.TextColored(ctx, COLORS.muted, "  " .. (c.label or ""))
          ImGui.SameLine(ctx)
          if ImGui.Button(ctx, "Select##" .. c.key, 58, 22) then
            selected_connection_key = c.key
            status = "Selected send: " .. c.source.name .. " > " .. c.dest.name
          end
        end
      end
    end
  end

  ImGui.Spacing(ctx)
  if ImGui.CollapsingHeader(ctx, "Project Summary", ImGui.TreeNodeFlags_DefaultOpen or 32) then
    local multichannel = 0
    local sends = 0
    for _, entry in ipairs(entries) do
      if entry.channels > 2 then multichannel = multichannel + 1 end
      sends = sends + (entry.send_count or 0)
    end
    ImGui.Text(ctx, string.format("Tracks: %d", #entries))
    ImGui.Text(ctx, string.format("Multichannel tracks: %d", multichannel))
    ImGui.Text(ctx, string.format("Sends: %d", sends))
  end
end

local function auto_arrange()
  local nodes, _, entries = collect_graph()
  local visible = {}
  for _, node in ipairs(nodes) do visible[node.guid] = node end
  local row_counts = {}
  for _, node in ipairs(nodes) do
    if node.master then
      save_pos(node.guid, 40, 34)
    end
  end
  for _, entry in ipairs(entries) do
    local node = visible[entry.guid]
    if node then
      local level = entry.folder_level or 0
      row_counts[level] = (row_counts[level] or 0) + 1
      local x = 40 + (row_counts[level] - 1) * 218 + level * 28
      local y = 174 + level * 156
      save_pos(entry.guid, x, y)
    end
  end
  view_mode = 1
  status = "Auto-arranged with folder children below parents."
end

local function focus_search_node(nodes)
  local q = (search_text or ""):match("^%s*(.-)%s*$")
  if q == "" then
    status = "Enter a track number, TR label, or name to focus."
    return
  end
  for _, node in ipairs(nodes) do
    if not node.master and matches_search(node) then
      selected_node_key = node.guid
      select_track(node)
      pan_x = 90 - (node.x or 0) * zoom
      pan_y = 140 - (node.y or 0) * zoom
      status = "Focused " .. node_label(node, 24)
      return
    end
  end
  status = "No matching visible track for: " .. q
end

local function main_work_area()
  if ImGui.GetMainViewport and ImGui.Viewport_GetWorkPos and ImGui.Viewport_GetWorkSize then
    local ok_viewport, viewport = pcall(ImGui.GetMainViewport, ctx)
    if ok_viewport and viewport then
      local ok_pos, x, y = pcall(ImGui.Viewport_GetWorkPos, viewport)
      local ok_size, w, h = pcall(ImGui.Viewport_GetWorkSize, viewport)
      if ok_pos and ok_size and x and y and w and h then
        return x, y, w, h
      end
    end
  end
  return nil
end

local function preset_window_size(mode)
  if mode == 2 then return 1560, 940 end
  return 1120, 760
end

local function apply_window_size_preset(mode)
  local target_w, target_h = preset_window_size(mode)
  local x, y, w, h = main_work_area()
  if x then
    target_w = math.min(target_w, math.max(720, w - 80))
    target_h = math.min(target_h, math.max(520, h - 80))
    ImGui.SetNextWindowPos(ctx, x + math.max(20, (w - target_w) * 0.5), y + math.max(20, (h - target_h) * 0.5), ImGui.Cond_Always or 1)
  end
  ImGui.SetNextWindowSize(ctx, target_w, target_h, ImGui.Cond_Always or 1)
end

local function loop()
  if pending_window_size_mode then
    apply_window_size_preset(pending_window_size_mode)
    pending_window_size_mode = nil
  else
    ImGui.SetNextWindowSize(ctx, 1120, 760, ImGui.Cond_FirstUseEver or 4)
  end
  local visible
  local window_flags = ImGui.WindowFlags_NoCollapse or 0
  visible, open = ImGui.Begin(ctx, TITLE, open, window_flags)
  if visible then
    local nodes, connections, entries = collect_graph()
    layout_nodes(nodes)
    if delete_key_pressed() and selected_connection_key then
      local connection = find_connection(connections, selected_connection_key)
      if connection and connection.kind == "send" then
        remove_track_send(connection)
        nodes, connections, entries = collect_graph()
        layout_nodes(nodes)
      end
    end

    ImGui.Text(ctx, "Patch Routing View")
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, COLORS.muted, status)

    ImGui.SetNextItemWidth(ctx, 160)
    local changed_search
    changed_search, search_text = ImGui.InputText(ctx, "Search", search_text)
    if changed_search then status = search_text ~= "" and ("Search: " .. search_text) or "Search cleared." end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Focus", 54, 24) then focus_search_node(nodes) end
    ImGui.SameLine(ctx)
    local changed_edit
    changed_edit, edit_mode = ImGui.Checkbox(ctx, "Edit mode", edit_mode)
    if changed_edit then
      status = edit_mode and "Edit mode: drag send to receive, or receive to send, to create sends." or "View mode. Routing edits disabled."
      patch_drag = nil
    end
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 132)
    local old_mode = view_mode
    view_mode = combo_index("Layout", view_mode, VIEW_MODES)
    if view_mode ~= old_mode then status = "Layout: " .. (VIEW_MODES[view_mode] or "") end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Auto Arrange", 104, 24) then auto_arrange() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Reset View", 82, 24) then pan_x, pan_y, zoom = 24, 24, 1.0 end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Small", 60, 24) then
      window_size_mode = 1
      pending_window_size_mode = 1
      status = "Window size: small."
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Large", 60, 24) then
      window_size_mode = 2
      pending_window_size_mode = 2
      status = "Window size: large."
    end

    _, show_sends = ImGui.Checkbox(ctx, "Sends", show_sends)
    ImGui.SameLine(ctx)
    local changed_wires
    changed_wires, wires_front = ImGui.Checkbox(ctx, "Wires front", wires_front)
    if changed_wires then
      status = wires_front and "Wires draw in front of nodes." or "Wires draw behind nodes."
    end
    ImGui.SameLine(ctx)
    _, show_folders = ImGui.Checkbox(ctx, "Folders", show_folders)
    ImGui.SameLine(ctx)
    _, labels_hover_only = ImGui.Checkbox(ctx, "Labels hover", labels_hover_only)
    ImGui.SameLine(ctx)
    _, show_master = ImGui.Checkbox(ctx, "Master", show_master)
    ImGui.SameLine(ctx)
    _, show_selected_only = ImGui.Checkbox(ctx, "Selected", show_selected_only)
    ImGui.SameLine(ctx)
    _, show_connected_only = ImGui.Checkbox(ctx, "Connected", show_connected_only)
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Collapse", 86, 22) then set_all_folders_collapsed(entries, true) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Expand", 76, 22) then set_all_folders_collapsed(entries, false) end
    ImGui.SameLine(ctx)
    local changed_mc
    changed_mc, show_multichannel_only = ImGui.Checkbox(ctx, "MC only", show_multichannel_only)
    if changed_mc then
      status = show_multichannel_only and "MC only: showing tracks with more than two channels." or "MC only disabled: showing stereo and multichannel tracks."
    end

    ImGui.Separator(ctx)
    local inspector_w = 284
    local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
    local child_flags = ImGui.ChildFlags_Borders or 1
    if ImGui.BeginChild(ctx, "##patch_canvas_child", math.max(360, avail_w - inspector_w - 8), avail_h, child_flags) then
      draw_canvas(nodes, connections)
    end
    ImGui.EndChild(ctx)
    ImGui.SameLine(ctx)
    if ImGui.BeginChild(ctx, "##patch_inspector", inspector_w, avail_h, child_flags) then
      draw_inspector(selected_node(nodes), connections, entries)
    end
    ImGui.EndChild(ctx)

    persist()
  end
  ImGui.End(ctx)

  if open then
    reaper.defer(loop)
  else
    persist()
  end
end

reaper.defer(loop)
