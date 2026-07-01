-- @description 128ch Ambisonic Node Track Mixer
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; JSFX: s3g 128ch Ambisonic Node Track Mixer
-- @category Channel Mixing / Automation
-- @method Creates or controls a node mixer for ambisonic encoded source tracks. Each node is weighted as a whole ACN/SN3D stream, preserving channel-to-channel ambisonic relationships without decoding, encoding, or speaker-shape remapping.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "128ch Ambisonic Node Track Mixer", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")

local TITLE = "128ch Ambisonic Node Track Mixer"
local FX_NAME = "s3g 128ch Ambisonic Node Track Mixer"
local MAX_NODES = 16
local MAX_CH = 128
local ORDER_PARAM = 0
local NODE_COUNT_PARAM = 1
local MIX_MODE_PARAM = 2
local CURSOR_INFLUENCE_PARAM = 131
local CURSOR_X_PARAM = 132
local CURSOR_Y_PARAM = 133
local CURSOR_Z_PARAM = 134
local STACK_POSITION_PARAM = 135
local CURSOR_RADIUS_PARAM = 136
local CURSOR_FOCUS_PARAM = 137
local CURSOR_GATE_PARAM = 138

local ORDERS = {
  { label = "1OA / 4ch", channels = 4 },
  { label = "2OA / 10ch", channels = 10 },
  { label = "3OA / 16ch", channels = 16 },
}
local MIX_MODES = { "Spatial field", "Stack scan" }

local ctx = ImGui.CreateContext(TITLE)
local open = true
local bus = nil
local fx = -1
local selected_node = 1
local drag_kind = nil
local drag_node = nil
local view_zoom = 1.0
local view_pan_x = 0
local view_pan_y = 0
local view_azim_deg = 0
local view_elev_deg = 0
local automation_status = ""

local AUTO_MODE_NAMES = {
  [0] = "Trim/Read",
  [1] = "Read",
  [2] = "Touch",
  [3] = "Write",
  [4] = "Latch",
  [5] = "Latch Preview",
}

local COLORS = {
  bg = ImGui.ColorConvertDouble4ToU32(0.025, 0.030, 0.040, 1),
  panel = ImGui.ColorConvertDouble4ToU32(0.052, 0.060, 0.078, 1),
  edge = ImGui.ColorConvertDouble4ToU32(0.31, 0.36, 0.45, 1),
  grid = ImGui.ColorConvertDouble4ToU32(0.62, 0.68, 0.78, 0.16),
  text = ImGui.ColorConvertDouble4ToU32(0.80, 0.86, 0.92, 1),
  muted = ImGui.ColorConvertDouble4ToU32(0.50, 0.58, 0.66, 1),
  node = ImGui.ColorConvertDouble4ToU32(0.30, 0.54, 1.00, 0.92),
  node_sel = ImGui.ColorConvertDouble4ToU32(0.96, 0.48, 1.00, 0.98),
  cursor = ImGui.ColorConvertDouble4ToU32(0.20, 0.96, 0.82, 1),
  warm = ImGui.ColorConvertDouble4ToU32(1.00, 0.72, 0.30, 1),
  warn = ImGui.ColorConvertDouble4ToU32(0.95, 0.42, 0.32, 1),
}

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function finite(value, fallback)
  value = tonumber(value)
  if value == nil or value ~= value or value == math.huge or value == -math.huge then return fallback end
  return value
end

local function track_name(track, fallback)
  local ok, name = reaper.GetTrackName(track, "")
  if ok and name ~= "" then return name end
  return fallback or "Track"
end

local function node_name_key(node)
  return "P_EXT:s3g_mc_ambi_node_track_name_" .. tostring(node)
end

local function set_node_name(bus_track, node, name)
  reaper.GetSetMediaTrackInfo_String(bus_track, node_name_key(node), name or "", true)
end

local function node_name(node)
  local ok, name = reaper.GetSetMediaTrackInfo_String(bus, node_name_key(node), "", false)
  if ok and name ~= "" then return name end
  return "Node " .. tostring(node)
end

local function short_name(name, max_len)
  max_len = max_len or 22
  if #name <= max_len then return name end
  return name:sub(1, max_len - 3) .. "..."
end

local function ambi_order_for_channels(channels)
  channels = math.floor(channels or 0)
  if channels == 4 then return 0 end
  if channels == 9 or channels == 10 then return 1 end
  if channels == 16 then return 2 end
  return nil
end

local function order_channels(order)
  local spec = ORDERS[(order or 0) + 1] or ORDERS[3]
  return spec.channels
end

local function selected_tracks()
  local tracks = {}
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    tracks[#tracks + 1] = reaper.GetSelectedTrack(0, i)
  end
  return tracks
end

local function find_fx(track)
  if not track then return -1 end
  for i = 0, reaper.TrackFX_GetCount(track) - 1 do
    local ok, name = reaper.TrackFX_GetFXName(track, i, "")
    if ok and name:find(FX_NAME, 1, true) then return i end
  end
  return -1
end

local function add_fx(track)
  local existing = find_fx(track)
  if existing >= 0 then return existing end
  local added = reaper.TrackFX_AddByName(track, "JS: " .. FX_NAME, false, -1)
  if added < 0 then added = reaper.TrackFX_AddByName(track, FX_NAME, false, -1) end
  return added
end

local function set_param(track, fx_index, param, value)
  reaper.TrackFX_SetParam(track, fx_index, param, value)
end

local function get_param(track, fx_index, param, fallback)
  local value = reaper.TrackFX_GetParam(track, fx_index, param)
  if value == nil or value ~= value then return fallback end
  return value
end

local function node_param(node, offset)
  return 3 + (node - 1) * 8 + offset
end

local function setup_from_selected_tracks()
  local tracks = selected_tracks()
  if #tracks < 1 then return nil, "Select one or more ambisonic source tracks." end
  if #tracks > MAX_NODES then return nil, "Select no more than " .. tostring(MAX_NODES) .. " source tracks." end

  local source_orders = {}
  local source_counts = {}
  local order = 0
  for i, src in ipairs(tracks) do
    local src_ch = math.floor(reaper.GetMediaTrackInfo_Value(src, "I_NCHAN") or 2)
    local src_order = ambi_order_for_channels(src_ch)
    if not src_order then
      return nil, "Track " .. tostring(i) .. " is " .. tostring(src_ch) .. " channels. Ambisonic node mixer expects 4, 10, or 16 channel source tracks."
    end
    source_orders[i] = src_order
    source_counts[i] = ORDERS[src_order + 1].channels
    order = math.max(order, src_order)
  end

  local ambi_ch = order_channels(order)
  local input_total = #tracks * ambi_ch
  if input_total > MAX_CH then
    return nil, "Selected tracks need " .. tostring(input_total) .. " bus input channels. The mixer supports up to 128."
  end

  reaper.Undo_BeginBlock()
  local insert_idx = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(insert_idx, true)
  local new_bus = reaper.GetTrack(0, insert_idx)
  reaper.GetSetMediaTrackInfo_String(new_bus, "P_NAME", "s3g 128ch Ambisonic Node Track Mixer bus", true)
  reaper.SetMediaTrackInfo_Value(new_bus, "I_NCHAN", math.max(ambi_ch, input_total))
  local new_fx = add_fx(new_bus)
  if new_fx >= 0 then
    set_param(new_bus, new_fx, ORDER_PARAM, order)
    set_param(new_bus, new_fx, NODE_COUNT_PARAM, #tracks)
    set_param(new_bus, new_fx, MIX_MODE_PARAM, 0)
    set_param(new_bus, new_fx, CURSOR_INFLUENCE_PARAM, 1)
    set_param(new_bus, new_fx, CURSOR_RADIUS_PARAM, 1.1)
    set_param(new_bus, new_fx, CURSOR_FOCUS_PARAM, 2)
    set_param(new_bus, new_fx, CURSOR_GATE_PARAM, 0.02)
    local input_start = 1
    for i, src in ipairs(tracks) do
      if source_counts[i] ~= ambi_ch then
        reaper.ShowConsoleMsg("s3g-mc: " .. track_name(src, "Track " .. tostring(i)) .. " is lower order than the bus; missing higher-order channels will be silent in the input block.\n")
      end
      set_node_name(new_bus, i, track_name(src, "Source " .. tostring(i)))
      mc.create_postfx_send(src, new_bus, source_counts[i], input_start - 1)
      reaper.SetMediaTrackInfo_Value(src, "B_MAINSEND", 0)
      local a = (i - 1) / math.max(1, #tracks) * math.pi * 2
      set_param(new_bus, new_fx, node_param(i, 0), 1)
      set_param(new_bus, new_fx, node_param(i, 1), 0)
      set_param(new_bus, new_fx, node_param(i, 2), input_start)
      set_param(new_bus, new_fx, node_param(i, 3), math.cos(a) * 0.55)
      set_param(new_bus, new_fx, node_param(i, 4), math.sin(a) * 0.55)
      set_param(new_bus, new_fx, node_param(i, 5), 0)
      set_param(new_bus, new_fx, node_param(i, 6), 0.9)
      set_param(new_bus, new_fx, node_param(i, 7), 2)
      input_start = input_start + ambi_ch
    end
    for i = #tracks + 1, MAX_NODES do set_node_name(new_bus, i, "") end
  end
  reaper.SetOnlyTrackSelected(new_bus)
  reaper.Undo_EndBlock("Create 128ch Ambisonic Node Track Mixer bus", -1)
  return new_bus, nil
end

local function current_bus()
  local tracks = selected_tracks()
  if #tracks == 1 and find_fx(tracks[1]) >= 0 then return tracks[1] end
  local new_bus, err = setup_from_selected_tracks()
  if not new_bus then reaper.MB(err or "Could not create ambisonic node mixer bus.", TITLE, 0) end
  return new_bus
end

bus = current_bus()
if not bus then return end
fx = add_fx(bus)
if fx < 0 then
  reaper.MB("Could not load JS: " .. FX_NAME, TITLE, 0)
  return
end

local function rotate_view(x, y, z)
  x = finite(x, 0)
  y = finite(y, 0)
  z = finite(z, 0)
  local yaw = math.rad(view_azim_deg)
  local pitch = math.rad(view_elev_deg)
  local cy, sy = math.cos(yaw), math.sin(yaw)
  local cp, sp = math.cos(pitch), math.sin(pitch)
  local x1 = x * cy - y * sy
  local y1 = x * sy + y * cy
  local y2 = y1 * cp - z * sp
  return x1, y2
end

local function project(x, y, z, x0, y0, w, h)
  local rx, ry = rotate_view(x, y, z)
  local s = math.min(w, h) * 0.38 * math.max(0.001, view_zoom)
  return x0 + w * 0.5 + (rx + view_pan_x) * s, y0 + h * 0.5 - (ry + view_pan_y) * s
end

local function screen_to_xy(px, py, z, x0, y0, w, h)
  local s = math.min(w, h) * 0.38 * math.max(0.001, view_zoom)
  local rx = ((finite(px, x0 + w * 0.5) - (x0 + w * 0.5)) / s) - view_pan_x
  local ry = -((finite(py, y0 + h * 0.5) - (y0 + h * 0.5)) / s) - view_pan_y
  local yaw = math.rad(view_azim_deg)
  local pitch = math.rad(view_elev_deg)
  local cy, sy = math.cos(yaw), math.sin(yaw)
  local cp, sp = math.cos(pitch), math.sin(pitch)
  if math.abs(cp) < 0.001 then cp = cp < 0 and -0.001 or 0.001 end
  local y1 = (ry + finite(z, 0) * sp) / cp
  return clamp(rx * cy + y1 * sy, -2, 2), clamp(-rx * sy + y1 * cy, -2, 2)
end

local function dist2(ax, ay, bx, by)
  local dx = ax - bx
  local dy = ay - by
  return dx * dx + dy * dy
end

local function cursor_weight_for_node(node, mix_mode)
  local influence = get_param(bus, fx, CURSOR_INFLUENCE_PARAM, 0)
  if influence <= 0 then return 1 end
  local gate = clamp(get_param(bus, fx, CURSOR_GATE_PARAM, 0), 0, 0.95)
  local dist, radius, focus
  if mix_mode == 1 then
    dist = math.abs(node - get_param(bus, fx, STACK_POSITION_PARAM, 1))
    radius = get_param(bus, fx, CURSOR_RADIUS_PARAM, 1)
    focus = get_param(bus, fx, CURSOR_FOCUS_PARAM, 2)
  else
    local x = get_param(bus, fx, node_param(node, 3), 0)
    local y = get_param(bus, fx, node_param(node, 4), 0)
    local z = get_param(bus, fx, node_param(node, 5), 0)
    local cx = get_param(bus, fx, CURSOR_X_PARAM, 0)
    local cy = get_param(bus, fx, CURSOR_Y_PARAM, 0)
    local cz = get_param(bus, fx, CURSOR_Z_PARAM, 0)
    dist = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy) + (z - cz) * (z - cz))
    radius = get_param(bus, fx, node_param(node, 6), 0.9) * get_param(bus, fx, CURSOR_RADIUS_PARAM, 1)
    focus = get_param(bus, fx, node_param(node, 7), 2) * get_param(bus, fx, CURSOR_FOCUS_PARAM, 2) * 0.5
  end
  local raw = math.exp(-((dist / math.max(0.001, radius)) ^ math.max(0.1, focus)))
  if gate > 0 then raw = raw <= gate and 0 or (raw - gate) / math.max(0.0001, 1 - gate) end
  return (1 - influence) + influence * raw
end

local function cursor_weight_for_distance(dist, influence, radius, focus, gate)
  if influence <= 0 then return 1 end
  local raw = math.exp(-((math.max(0, dist) / math.max(0.001, radius)) ^ math.max(0.1, focus)))
  if gate > 0 then raw = raw <= gate and 0 or (raw - gate) / math.max(0.0001, 1 - gate) end
  return (1 - influence) + influence * raw
end

local function draw_curve_display(influence, radius, focus, gate)
  local draw = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(260, ImGui.GetContentRegionAvail(ctx))
  local h = 88
  ImGui.InvisibleButton(ctx, "##ambi_cursor_curve", w, h)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + h, COLORS.bg)
  ImGui.DrawList_AddRect(draw, x, y, x + w, y + h, COLORS.edge)
  ImGui.DrawList_AddText(draw, x + 10, y + 8, COLORS.muted, "cursor falloff")
  local gx1, gy1 = x + 16, y + h - 16
  local gx2, gy2 = x + w - 14, y + 22
  ImGui.DrawList_AddLine(draw, gx1, gy1, gx2, gy1, COLORS.grid, 1)
  ImGui.DrawList_AddLine(draw, gx1, gy1, gx1, gy2, COLORS.grid, 1)
  local max_dist = math.max(1, radius * 3)
  local last_x, last_y
  for i = 0, 96 do
    local t = i / 96
    local weight = cursor_weight_for_distance(t * max_dist, influence, radius, focus, gate)
    local px = gx1 + (gx2 - gx1) * t
    local py = gy1 - (gy1 - gy2) * clamp(weight, 0, 1)
    if last_x then ImGui.DrawList_AddLine(draw, last_x, last_y, px, py, COLORS.cursor, 2) end
    last_x, last_y = px, py
  end
end

local function automation_mode_name(track)
  if not track or not reaper.GetTrackAutomationMode then return "Unknown" end
  return AUTO_MODE_NAMES[reaper.GetTrackAutomationMode(track)] or "Unknown"
end

local function set_track_write_mode(track, write_enabled)
  if not track or not reaper.SetTrackAutomationMode then return false end
  reaper.SetTrackAutomationMode(track, write_enabled and 3 or 0)
  automation_status = write_enabled
    and "Track set to Write; GUI movement will write automation."
    or "Track set to Trim/Read; GUI control is automation-safe."
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  return true
end

local set_envelope_chunk_visibility

local function show_arm_fx_envelope(track, fx_index, param)
  if not track or fx_index < 0 then return false end
  local env = reaper.GetFXEnvelope(track, fx_index, param, true)
  if not env then return false end
  if reaper.SetEnvelopeInfo_Value then
    pcall(reaper.SetEnvelopeInfo_Value, env, "B_VISIBLE", 1)
    pcall(reaper.SetEnvelopeInfo_Value, env, "B_ACTIVE", 1)
    pcall(reaper.SetEnvelopeInfo_Value, env, "B_ARM", 1)
    pcall(reaper.SetEnvelopeInfo_Value, env, "I_TCPH", 72)
  end
  set_envelope_chunk_visibility(env, true)
  return true
end

set_envelope_chunk_visibility = function(env, visible)
  if not env or not reaper.GetEnvelopeStateChunk or not reaper.SetEnvelopeStateChunk then return false end
  local ok, chunk = reaper.GetEnvelopeStateChunk(env, "", false)
  if not ok or chunk == "" then return false end
  local vis = visible and "1" or "0"
  local changed = false
  chunk = chunk:gsub("(\nVIS%s+)%d", function(prefix)
    changed = true
    return prefix .. vis
  end, 1)
  if not changed then
    chunk = chunk:gsub("^(VIS%s+)%d", function(prefix)
      changed = true
      return prefix .. vis
    end, 1)
  end
  if not changed then return false end
  return reaper.SetEnvelopeStateChunk(env, chunk, false)
end

local function hide_fx_envelope(track, fx_index, param)
  if not track or fx_index < 0 then return false end
  local env = reaper.GetFXEnvelope(track, fx_index, param, false)
  if not env then return false end
  if reaper.SetEnvelopeInfo_Value then
    pcall(reaper.SetEnvelopeInfo_Value, env, "B_VISIBLE", 0)
    pcall(reaper.SetEnvelopeInfo_Value, env, "I_TCPH", 0)
  end
  set_envelope_chunk_visibility(env, false)
  return true
end

local function show_params(params)
  local count = 0
  for _, param in ipairs(params) do
    if show_arm_fx_envelope(bus, fx, param) then count = count + 1 end
  end
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  return count
end

local function hide_params(params)
  local count = 0
  for _, param in ipairs(params) do
    if hide_fx_envelope(bus, fx, param) then count = count + 1 end
  end
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  return count
end

local function nudge(label, w, h, apply)
  if ImGui.Button(ctx, label, w, h) or ImGui.IsItemActive(ctx) then apply() end
end

local function draw_node_field(dl, x, y, r, selected)
  local br, bg, bb = selected and 0.96 or 0.30, selected and 0.48 or 0.54, selected and 1.00 or 1.00
  for step = 14, 1, -1 do
    local t = step / 14
    local a = 0.01 + (1 - t) * (1 - t) * 0.23
    ImGui.DrawList_AddCircleFilled(dl, x, y, r * t, color(br, bg, bb, a), 64)
  end
  ImGui.DrawList_AddCircle(dl, x, y, r, color(br, bg, bb, selected and 0.48 or 0.25), 64, selected and 2.0 or 1.0)
end

local function draw_ambi_glyph(dl, x, y, r, order, selected)
  local col = selected and COLORS.node_sel or COLORS.node
  ImGui.DrawList_AddCircle(dl, x, y, r, col, 36, 1.3)
  ImGui.DrawList_AddLine(dl, x - r, y, x + r, y, color(0.72, 0.84, 1.0, selected and 0.45 or 0.25), 1)
  ImGui.DrawList_AddLine(dl, x, y - r, x, y + r, color(0.72, 0.84, 1.0, selected and 0.45 or 0.25), 1)
  if order >= 1 then ImGui.DrawList_AddCircle(dl, x, y, r * 0.62, color(0.88, 0.80, 1.0, selected and 0.45 or 0.22), 36, 1) end
  if order >= 2 then ImGui.DrawList_AddCircle(dl, x, y, r * 0.34, color(0.36, 0.96, 0.88, selected and 0.55 or 0.28), 36, 1) end
end

local function draw_stack_view(node_count, order)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(620, ImGui.GetContentRegionAvail(ctx))
  local h = 380
  ImGui.InvisibleButton(ctx, "##ambi_stack_view", w, h)
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x0 + w, y0 + h, COLORS.bg)
  ImGui.DrawList_AddRect(dl, x0, y0, x0 + w, y0 + h, COLORS.edge)
  ImGui.DrawList_AddText(dl, x0 + 14, y0 + 12, COLORS.text, "Ambisonic stack scan")
  ImGui.DrawList_AddText(dl, x0 + 14, y0 + 30, COLORS.muted, "Cursor scans between complete encoded streams; channels remain aligned.")

  local rail_x1, rail_x2 = x0 + 28, x0 + w - 28
  local rail_y = y0 + 62
  local stack_pos = get_param(bus, fx, STACK_POSITION_PARAM, 1)
  if ImGui.IsItemHovered(ctx) then
    local mx, my = ImGui.GetMousePos(ctx)
    if ImGui.IsMouseClicked(ctx, 0) and my >= rail_y - 26 and my <= rail_y + 26 then drag_kind = "stack_cursor" end
  end
  if drag_kind == "stack_cursor" and ImGui.IsMouseDown(ctx, 0) then
    local mx = ImGui.GetMousePos(ctx)
    local t = clamp((mx - rail_x1) / math.max(1, rail_x2 - rail_x1), 0, 1)
    set_param(bus, fx, STACK_POSITION_PARAM, 1 + t * math.max(0, node_count - 1))
  elseif drag_kind == "stack_cursor" and not ImGui.IsMouseDown(ctx, 0) then
    drag_kind = nil
  end

  ImGui.DrawList_AddLine(dl, rail_x1, rail_y, rail_x2, rail_y, COLORS.grid, 1)
  for n = 1, node_count do
    local tx = rail_x1 + (rail_x2 - rail_x1) * ((n - 1) / math.max(1, node_count - 1))
    local weight = cursor_weight_for_node(n, 1)
    local selected = n == selected_node
    ImGui.DrawList_AddCircleFilled(dl, tx, rail_y, 4 + weight * 5, selected and COLORS.node_sel or COLORS.node, 18)
    ImGui.DrawList_AddText(dl, tx - 4, rail_y - 24, COLORS.muted, tostring(n))
  end
  local cursor_x = rail_x1 + (rail_x2 - rail_x1) * ((get_param(bus, fx, STACK_POSITION_PARAM, 1) - 1) / math.max(1, node_count - 1))
  ImGui.DrawList_AddLine(dl, cursor_x, rail_y - 18, cursor_x, y0 + h - 18, COLORS.cursor, 2)

  local cols = math.min(4, math.max(1, node_count))
  local rows = math.ceil(node_count / cols)
  local cell_w = (w - 56) / cols
  local cell_h = math.max(86, (h - 96) / math.max(1, rows))
  for n = 1, node_count do
    local col = (n - 1) % cols
    local row = math.floor((n - 1) / cols)
    local cx = x0 + 28 + cell_w * col + cell_w * 0.5
    local cy = y0 + 94 + cell_h * row + cell_h * 0.5
    local selected = n == selected_node
    local weight = cursor_weight_for_node(n, 1)
    draw_ambi_glyph(dl, cx, cy, math.min(cell_w, cell_h) * 0.22, order, selected)
    ImGui.DrawList_AddText(dl, cx - 42, cy + math.min(cell_w, cell_h) * 0.25, selected and COLORS.node_sel or COLORS.text,
      string.format("N%d %.2f", n, weight))
  end
end

local function draw_field_view(node_count, order)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(620, ImGui.GetContentRegionAvail(ctx))
  local h = 430
  ImGui.InvisibleButton(ctx, "##ambi_node_view", w, h)
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x0 + w, y0 + h, COLORS.bg)
  ImGui.DrawList_AddRect(dl, x0, y0, x0 + w, y0 + h, COLORS.edge)
  ImGui.DrawList_AddText(dl, x0 + 14, y0 + 12, COLORS.text, "Ambisonic node field")
  ImGui.DrawList_AddText(dl, x0 + 14, y0 + 30, COLORS.muted, "Each node is a full encoded stream; cursor distance controls whole-stream weighting.")

  for g = -2, 2 do
    local ax, ay = project(g * 0.5, -1.1, 0, x0, y0, w, h)
    local bx, by = project(g * 0.5, 1.1, 0, x0, y0, w, h)
    ImGui.DrawList_AddLine(dl, ax, ay, bx, by, COLORS.grid, 1)
    ax, ay = project(-1.1, g * 0.5, 0, x0, y0, w, h)
    bx, by = project(1.1, g * 0.5, 0, x0, y0, w, h)
    ImGui.DrawList_AddLine(dl, ax, ay, bx, by, COLORS.grid, 1)
  end

  local cx = get_param(bus, fx, CURSOR_X_PARAM, 0)
  local cy = get_param(bus, fx, CURSOR_Y_PARAM, 0)
  local cz = get_param(bus, fx, CURSOR_Z_PARAM, 0)
  local cpx, cpy = project(cx, cy, cz, x0, y0, w, h)
  local node_positions = {}
  for n = 1, node_count do
    local nx = get_param(bus, fx, node_param(n, 3), 0)
    local ny = get_param(bus, fx, node_param(n, 4), 0)
    local nz = get_param(bus, fx, node_param(n, 5), 0)
    local px, py = project(nx, ny, nz, x0, y0, w, h)
    node_positions[n] = { x = nx, y = ny, z = nz, px = px, py = py }
  end

  if ImGui.IsItemHovered(ctx) then
    local mx, my = ImGui.GetMousePos(ctx)
    if ImGui.IsMouseClicked(ctx, 0) then
      local best_kind, best_node
      local best_d2 = dist2(mx, my, cpx, cpy)
      if best_d2 <= 24 * 24 then best_kind = "cursor" end
      for n = 1, node_count do
        local pos = node_positions[n]
        local d2 = dist2(mx, my, pos.px, pos.py)
        if d2 <= 24 * 24 and (not best_kind or d2 < best_d2) then
          best_kind, best_node, best_d2 = "node", n, d2
        end
      end
      drag_kind, drag_node = best_kind, best_node
      if drag_kind == "node" and drag_node then selected_node = drag_node end
    end
  end
  if drag_kind and ImGui.IsMouseDown(ctx, 0) then
    local mx, my = ImGui.GetMousePos(ctx)
    if drag_kind == "cursor" then
      local nx, ny = screen_to_xy(mx, my, cz, x0, y0, w, h)
      set_param(bus, fx, CURSOR_X_PARAM, nx)
      set_param(bus, fx, CURSOR_Y_PARAM, ny)
    elseif drag_kind == "node" and drag_node then
      local pos = node_positions[drag_node] or { z = 0 }
      local nx, ny = screen_to_xy(mx, my, pos.z, x0, y0, w, h)
      set_param(bus, fx, node_param(drag_node, 3), nx)
      set_param(bus, fx, node_param(drag_node, 4), ny)
    end
  elseif drag_kind and not ImGui.IsMouseDown(ctx, 0) then
    drag_kind, drag_node = nil, nil
  end

  ImGui.DrawList_AddCircle(dl, cpx, cpy, 13, COLORS.cursor, 28, 2)
  ImGui.DrawList_AddLine(dl, cpx - 18, cpy, cpx + 18, cpy, COLORS.cursor, 1.5)
  ImGui.DrawList_AddLine(dl, cpx, cpy - 18, cpx, cpy + 18, COLORS.cursor, 1.5)

  for n = 1, node_count do
    local pos = node_positions[n] or { px = x0 + w * 0.5, py = y0 + h * 0.5 }
    local selected = n == selected_node
    local radius = get_param(bus, fx, node_param(n, 6), 0.9)
    local weight = cursor_weight_for_node(n, 0)
    draw_node_field(dl, pos.px, pos.py, radius * math.min(w, h) * 0.16 * view_zoom, selected)
    draw_ambi_glyph(dl, pos.px, pos.py, selected and 18 or 15, order, selected)
    ImGui.DrawList_AddText(dl, pos.px + 18, pos.py - 9, selected and COLORS.node_sel or COLORS.text,
      string.format("%d %.2f %s", n, weight, short_name(node_name(n), 20)))
  end
end

local function combo_mix_mode(mode)
  if ImGui.BeginCombo(ctx, "Mix mode", MIX_MODES[mode + 1] or MIX_MODES[1]) then
    for i, label in ipairs(MIX_MODES) do
      local selected = mode == i - 1
      if ImGui.Selectable(ctx, label, selected) then mode = i - 1 end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return mode
end

local function draw_routing_overview(node_count, ambi_ch)
  if not ImGui.CollapsingHeader(ctx, "Routing overview", ImGui.TreeNodeFlags_DefaultOpen) then return end
  ImGui.TextColored(ctx, COLORS.muted, "Whole encoded streams are weighted, then summed channel-for-channel to the output.")
  if ImGui.BeginTable(ctx, "ambi_routing_overview", 5, ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg | ImGui.TableFlags_SizingStretchProp) then
    ImGui.TableSetupColumn(ctx, "Node", ImGui.TableColumnFlags_WidthFixed, 54)
    ImGui.TableSetupColumn(ctx, "Track", ImGui.TableColumnFlags_WidthFixed, 240)
    ImGui.TableSetupColumn(ctx, "Input", ImGui.TableColumnFlags_WidthFixed, 110)
    ImGui.TableSetupColumn(ctx, "Output", ImGui.TableColumnFlags_WidthFixed, 110)
    ImGui.TableSetupColumn(ctx, "Weight")
    ImGui.TableHeadersRow(ctx)
    local mix_mode = math.floor(get_param(bus, fx, MIX_MODE_PARAM, 0) + 0.5)
    for n = 1, node_count do
      local input_start = math.floor(get_param(bus, fx, node_param(n, 2), 1) + 0.5)
      ImGui.TableNextRow(ctx)
      ImGui.TableSetColumnIndex(ctx, 0)
      if ImGui.Selectable(ctx, "N" .. tostring(n), selected_node == n) then selected_node = n end
      ImGui.TableSetColumnIndex(ctx, 1)
      ImGui.Text(ctx, short_name(node_name(n), 34))
      ImGui.TableSetColumnIndex(ctx, 2)
      ImGui.Text(ctx, string.format("%d-%d", input_start, input_start + ambi_ch - 1))
      ImGui.TableSetColumnIndex(ctx, 3)
      ImGui.Text(ctx, string.format("1-%d", ambi_ch))
      ImGui.TableSetColumnIndex(ctx, 4)
      ImGui.Text(ctx, string.format("%.3f", cursor_weight_for_node(n, mix_mode)))
    end
    ImGui.EndTable(ctx)
  end
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 1000, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local _, bus_name = reaper.GetTrackName(bus, "")
    ImGui.Text(ctx, bus_name ~= "" and bus_name or "Ambisonic Node Track Mixer bus")
    ImGui.TextColored(ctx, COLORS.muted, "Whole ACN/SN3D streams are mixed as nodes. No decode, encode, or speaker-channel remapping is applied.")

    local order = math.floor(get_param(bus, fx, ORDER_PARAM, 2) + 0.5)
    ImGui.Text(ctx, "Ambisonic order: " .. (ORDERS[order + 1] and ORDERS[order + 1].label or ORDERS[3].label))
    ImGui.TextColored(ctx, COLORS.muted, "Order is set when the bus is created so input blocks stay aligned.")
    local ambi_ch = order_channels(order)
    local node_count = math.floor(get_param(bus, fx, NODE_COUNT_PARAM, 4) + 0.5)
    local changed
    changed, node_count = ImGui.SliderInt(ctx, "Node count", node_count, 1, MAX_NODES)
    if changed then set_param(bus, fx, NODE_COUNT_PARAM, node_count) end
    selected_node = clamp(selected_node, 1, node_count)
    local bus_channels = math.max(ambi_ch, node_count * ambi_ch)
    if reaper.GetMediaTrackInfo_Value(bus, "I_NCHAN") < bus_channels then
      reaper.SetMediaTrackInfo_Value(bus, "I_NCHAN", math.min(MAX_CH, bus_channels))
    end

    local mix_mode = math.floor(get_param(bus, fx, MIX_MODE_PARAM, 0) + 0.5)
    mix_mode = combo_mix_mode(mix_mode)
    set_param(bus, fx, MIX_MODE_PARAM, mix_mode)

    if ImGui.CollapsingHeader(ctx, "Automation", ImGui.TreeNodeFlags_DefaultOpen) then
      local mode_name = automation_mode_name(bus)
      ImGui.Text(ctx, "Track automation: " .. mode_name)
      ImGui.SameLine(ctx)
      local write_mode = mode_name == "Write"
      if ImGui.Button(ctx, write_mode and "Set Trim/Read + safe" or "Set Write + GUI") then
        set_track_write_mode(bus, not write_mode)
      end
      local cursor_params = { CURSOR_X_PARAM, CURSOR_Y_PARAM, CURSOR_Z_PARAM }
      local curve_params = { CURSOR_INFLUENCE_PARAM, CURSOR_RADIUS_PARAM, CURSOR_FOCUS_PARAM, CURSOR_GATE_PARAM }
      local stack_params = { STACK_POSITION_PARAM }
      if ImGui.Button(ctx, "Show cursor lanes") then automation_status = "Shown/armed " .. tostring(show_params(cursor_params)) .. " cursor envelopes." end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Hide cursor") then automation_status = "Hidden " .. tostring(hide_params(cursor_params)) .. " cursor envelopes." end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Show curve lanes") then automation_status = "Shown/armed " .. tostring(show_params(curve_params)) .. " curve envelopes." end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Hide curve") then automation_status = "Hidden " .. tostring(hide_params(curve_params)) .. " curve envelopes." end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Show stack") then automation_status = "Shown/armed " .. tostring(show_params(stack_params)) .. " stack envelope." end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Hide stack") then automation_status = "Hidden " .. tostring(hide_params(stack_params)) .. " stack envelope." end
      ImGui.TextColored(ctx, COLORS.muted, write_mode and "Write mode: GUI movement writes to armed automation lanes." or "Trim/Read: GUI controls parameters live without writing automation.")
      if automation_status ~= "" then ImGui.TextColored(ctx, COLORS.muted, automation_status) end
    end

    if ImGui.CollapsingHeader(ctx, "Mix Cursor", ImGui.TreeNodeFlags_DefaultOpen) then
      local influence = get_param(bus, fx, CURSOR_INFLUENCE_PARAM, 1)
      changed, influence = ImGui.SliderDouble(ctx, "Cursor influence", influence, 0, 1, "%.3f")
      if changed then set_param(bus, fx, CURSOR_INFLUENCE_PARAM, influence) end
      if mix_mode == 1 then
        local stack_pos = get_param(bus, fx, STACK_POSITION_PARAM, 1)
        changed, stack_pos = ImGui.SliderDouble(ctx, "Stack position", stack_pos, 1, node_count, "%.3f")
        if changed then set_param(bus, fx, STACK_POSITION_PARAM, stack_pos) end
      else
        local cx = get_param(bus, fx, CURSOR_X_PARAM, 0)
        local cy = get_param(bus, fx, CURSOR_Y_PARAM, 0)
        local cz = get_param(bus, fx, CURSOR_Z_PARAM, 0)
        changed, cx = ImGui.SliderDouble(ctx, "Cursor X", cx, -2, 2, "%.3f")
        if changed then set_param(bus, fx, CURSOR_X_PARAM, cx) end
        changed, cy = ImGui.SliderDouble(ctx, "Cursor Y", cy, -2, 2, "%.3f")
        if changed then set_param(bus, fx, CURSOR_Y_PARAM, cy) end
        changed, cz = ImGui.SliderDouble(ctx, "Cursor Z", cz, -2, 2, "%.3f")
        if changed then set_param(bus, fx, CURSOR_Z_PARAM, cz) end
        if ImGui.Button(ctx, "Center Cursor", 120, 24) then
          set_param(bus, fx, CURSOR_X_PARAM, 0)
          set_param(bus, fx, CURSOR_Y_PARAM, 0)
          set_param(bus, fx, CURSOR_Z_PARAM, 0)
        end
      end
      local radius = get_param(bus, fx, CURSOR_RADIUS_PARAM, 1)
      local focus = get_param(bus, fx, CURSOR_FOCUS_PARAM, 2)
      local gate = get_param(bus, fx, CURSOR_GATE_PARAM, 0)
      changed, radius = ImGui.SliderDouble(ctx, "Global radius", radius, 0.05, 8, "%.3f")
      if changed then set_param(bus, fx, CURSOR_RADIUS_PARAM, radius) end
      changed, focus = ImGui.SliderDouble(ctx, "Global focus", focus, 0.2, 12, "%.3f")
      if changed then set_param(bus, fx, CURSOR_FOCUS_PARAM, focus) end
      changed, gate = ImGui.SliderDouble(ctx, "Cursor gate", gate, 0, 0.95, "%.3f")
      if changed then set_param(bus, fx, CURSOR_GATE_PARAM, gate) end
      draw_curve_display(influence, radius, focus, gate)
    end

    if ImGui.Button(ctx, "3/4", 48, 24) then view_azim_deg, view_elev_deg = -38, -28 end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Top", 48, 24) then view_azim_deg, view_elev_deg = 0, 0 end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Side", 48, 24) then view_azim_deg, view_elev_deg = 0, -89 end
    ImGui.SameLine(ctx)
    nudge("Az -", 44, 24, function() view_azim_deg = view_azim_deg - 2 end)
    ImGui.SameLine(ctx)
    nudge("Az +", 44, 24, function() view_azim_deg = view_azim_deg + 2 end)
    ImGui.SameLine(ctx)
    nudge("El +", 44, 24, function() view_elev_deg = clamp(view_elev_deg + 2, -89, 89) end)
    ImGui.SameLine(ctx)
    nudge("El -", 44, 24, function() view_elev_deg = clamp(view_elev_deg - 2, -89, 89) end)
    ImGui.SameLine(ctx)
    nudge("-", 28, 24, function() view_zoom = clamp(view_zoom * 0.975, 0.35, 3.0) end)
    ImGui.SameLine(ctx)
    nudge("+", 28, 24, function() view_zoom = clamp(view_zoom * 1.025, 0.35, 3.0) end)

    if mix_mode == 1 then draw_stack_view(node_count, order) else draw_field_view(node_count, order) end

    if ImGui.CollapsingHeader(ctx, "Selected Node", ImGui.TreeNodeFlags_DefaultOpen) then
      ImGui.Text(ctx, "Node " .. tostring(selected_node) .. ": " .. node_name(selected_node))
      local active = get_param(bus, fx, node_param(selected_node, 0), 1) >= 0.5
      changed, active = ImGui.Checkbox(ctx, "Active", active)
      if changed then set_param(bus, fx, node_param(selected_node, 0), active and 1 or 0) end
      local input_start = math.floor(get_param(bus, fx, node_param(selected_node, 2), 1) + 0.5)
      changed, input_start = ImGui.SliderInt(ctx, "Input start channel", input_start, 1, MAX_CH)
      if changed then set_param(bus, fx, node_param(selected_node, 2), input_start) end
      local labels = mix_mode == 1 and { "Level dB" } or { "Level dB", "X", "Y", "Z", "Node radius", "Node focus" }
      local offsets = mix_mode == 1 and { 1 } or { 1, 3, 4, 5, 6, 7 }
      local ranges = mix_mode == 1
        and { { -60, 12, "%.1f" } }
        or { { -60, 12, "%.1f" }, { -2, 2, "%.3f" }, { -2, 2, "%.3f" }, { -2, 2, "%.3f" }, { 0.05, 8, "%.3f" }, { 0.2, 12, "%.3f" } }
      for i = 1, #labels do
        local v = get_param(bus, fx, node_param(selected_node, offsets[i]), 0)
        changed, v = ImGui.SliderDouble(ctx, labels[i], v, ranges[i][1], ranges[i][2], ranges[i][3])
        if changed then set_param(bus, fx, node_param(selected_node, offsets[i]), v) end
      end
    end

    draw_routing_overview(node_count, ambi_ch)

    if ImGui.Button(ctx, "Close", 100, 28) then open = false end
    ImGui.End(ctx)
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
