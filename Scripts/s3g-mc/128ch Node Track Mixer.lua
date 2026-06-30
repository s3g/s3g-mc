-- @description 128ch Node Track Mixer
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; JSFX: s3g 128ch Node Track Mixer
-- @category Channel Mixing / Automation
-- @method Creates or controls a multichannel node-mixer bus. Selected source tracks are routed as whole channel-shape nodes into JS: s3g 128ch Node Track Mixer, with spatial-object and stacked-shape mixing modes for stereo, ring, cube, double-ring, and dome sources.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "128ch Node Track Mixer", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")

local TITLE = "128ch Node Track Mixer"
local FX_NAME = "s3g 128ch Node Track Mixer"
local GMEM = "s3g_128ch_node_track_mixer"
local MAGIC = 128128
local MAX_NODES = 16
local MAX_CH = 128
local MATRIX_BASE = 1
local TRIM_BASE = 1 + MAX_NODES * MAX_CH
local MIX_MODE_PARAM = 163
local ROTATE_PARAM_BASE = 164
local CURSOR_INFLUENCE_PARAM = 180
local CURSOR_X_PARAM = 181
local CURSOR_Y_PARAM = 182
local CURSOR_Z_PARAM = 183
local STACK_POSITION_PARAM = 184
local CURSOR_RADIUS_PARAM = 185
local CURSOR_FOCUS_PARAM = 186
local CURSOR_GATE_PARAM = 187

local LAYOUTS = {
  "Linear",
  "Ring",
  "Cube",
  "Double ring",
  "Dome",
  "SRST dome",
}
local MIX_MODES = { "Spatial objects", "Stacked shapes" }

local ctx = ImGui.CreateContext(TITLE)
local open = true
local selected_node = 1
local matrix_start = 1
local view_zoom = 1.0
local view_pan_x = 0.0
local view_pan_y = 0.0
local view_azim_deg = 0.0
local view_elev_deg = 0.0
local view_mode = 1
local drag_kind = nil
local drag_node = nil
local bus = nil
local fx = -1
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
  bg = ImGui.ColorConvertDouble4ToU32(0.035, 0.039, 0.042, 1),
  edge = ImGui.ColorConvertDouble4ToU32(0.34, 0.38, 0.38, 1),
  grid = ImGui.ColorConvertDouble4ToU32(0.55, 0.60, 0.60, 0.18),
  text = ImGui.ColorConvertDouble4ToU32(0.78, 0.83, 0.82, 1),
  muted = ImGui.ColorConvertDouble4ToU32(0.48, 0.54, 0.54, 1),
  hot = ImGui.ColorConvertDouble4ToU32(0.98, 0.72, 0.25, 1),
  node = ImGui.ColorConvertDouble4ToU32(0.25, 0.68, 0.90, 0.92),
  node_sel = ImGui.ColorConvertDouble4ToU32(0.98, 0.72, 0.25, 0.98),
  speaker = ImGui.ColorConvertDouble4ToU32(0.78, 0.82, 0.84, 0.88),
  matrix_on = ImGui.ColorConvertDouble4ToU32(0.18, 0.64, 0.42, 1),
  matrix_off = ImGui.ColorConvertDouble4ToU32(0.12, 0.13, 0.14, 1),
}

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local function draw_color(value, fallback)
  if type(value) == "number" then return value end
  if type(fallback) == "number" then return fallback end
  return color(0.78, 0.83, 0.82, 1)
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

local function even_channels(count)
  count = math.max(2, math.min(MAX_CH, math.floor(count or 2)))
  if count % 2 == 1 then count = count + 1 end
  return math.min(MAX_CH, count)
end

local function track_name(track, fallback)
  local ok, name = reaper.GetTrackName(track, "")
  if ok and name ~= "" then return name end
  return fallback
end

local function node_name_key(node)
  return "P_EXT:s3g_mc_node_track_name_" .. tostring(node)
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

local function layout_for_channels(channels)
  channels = math.floor(channels or 2)
  if channels == 24 then return 4 end
  if channels == 25 then return 5 end
  if channels > 2 then return 1 end
  return 0
end

local function infer_layout_for_track(track, channels)
  local name = track_name(track, ""):lower()
  if name:find("srst", 1, true) or name:find("25", 1, true) and name:find("dome", 1, true) then return 5 end
  if name:find("dome", 1, true) then return 4 end
  if name:find("double", 1, true) and name:find("ring", 1, true) then return 3 end
  if name:find("cube", 1, true) then return 2 end
  if name:find("ring", 1, true) then return 1 end
  return layout_for_channels(channels)
end

local function track_count()
  return reaper.CountSelectedTracks(0)
end

local function selected_tracks()
  local tracks = {}
  for i = 0, track_count() - 1 do
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
  local fx = find_fx(track)
  if fx >= 0 then return fx end
  fx = reaper.TrackFX_AddByName(track, "JS: " .. FX_NAME, false, -1)
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, FX_NAME, false, -1) end
  return fx
end

local function set_param(track, fx, param, value)
  reaper.TrackFX_SetParam(track, fx, param, value)
end

local function get_param(track, fx, param, fallback)
  local value = reaper.TrackFX_GetParam(track, fx, param)
  if value == nil or value ~= value then return fallback end
  return value
end

local function node_param(node, offset)
  return 3 + (node - 1) * 10 + offset
end

local function node_rotate_param(node)
  return ROTATE_PARAM_BASE + (node - 1)
end

local function attach_gmem()
  if reaper.gmem_attach then
    reaper.gmem_attach(GMEM)
    local existed = reaper.gmem_read and reaper.gmem_read(0) == MAGIC
    if not existed then reaper.gmem_write(0, MAGIC) end
    return existed
  end
  return false
end

local function matrix_addr(node, ch)
  return MATRIX_BASE + (node - 1) * MAX_CH + (ch - 1)
end

local function trim_addr(node, ch)
  return TRIM_BASE + (node - 1) * MAX_CH + (ch - 1)
end

local function matrix_get(node, ch)
  if not reaper.gmem_read then return 1 end
  local v = reaper.gmem_read(matrix_addr(node, ch))
  if v == nil or v == 0 then return 0 end
  return 1
end

local function matrix_set(node, ch, value)
  if reaper.gmem_write then
    reaper.gmem_write(matrix_addr(node, ch), value and 1 or 0)
    reaper.gmem_write(trim_addr(node, ch), 1)
  end
end

local function matrix_repair_trims(nodes, channels)
  if not reaper.gmem_read or not reaper.gmem_write then return end
  for n = 1, nodes do
    for ch = 1, channels do
      local addr = trim_addr(n, ch)
      local trim = reaper.gmem_read(addr)
      if trim == nil or trim <= 0 then reaper.gmem_write(addr, 1) end
    end
  end
end

local function matrix_fill(nodes, channels, value)
  attach_gmem()
  for n = 1, nodes do
    for ch = 1, channels do matrix_set(n, ch, value) end
  end
end

local function setup_from_selected_tracks()
  local tracks = selected_tracks()
  if #tracks < 1 then return nil, "Select one or more source tracks." end
  if #tracks > MAX_NODES then return nil, "Select no more than " .. tostring(MAX_NODES) .. " source tracks." end

  reaper.Undo_BeginBlock()
  local insert_idx = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(insert_idx, true)
  local bus = reaper.GetTrack(0, insert_idx)
  reaper.GetSetMediaTrackInfo_String(bus, "P_NAME", "s3g 128ch Node Track Mixer bus", true)
  local source_counts = {}
  local input_total = 0
  local out_ch = 2
  for i, src in ipairs(tracks) do
    local src_ch = even_channels(reaper.GetMediaTrackInfo_Value(src, "I_NCHAN") or 2)
    source_counts[i] = src_ch
    input_total = input_total + src_ch
    out_ch = math.max(out_ch, src_ch)
  end
  if input_total > MAX_CH then
    reaper.DeleteTrack(bus)
    reaper.Undo_EndBlock("Create 128ch Node Track Mixer bus", -1)
    return nil, "Selected tracks need " .. tostring(input_total) .. " bus input channels. The mixer supports up to 128."
  end
  out_ch = even_channels(out_ch)
  reaper.SetMediaTrackInfo_Value(bus, "I_NCHAN", even_channels(math.max(input_total, out_ch)))
  local fx = add_fx(bus)
  if fx >= 0 then
    set_param(bus, fx, 0, layout_for_channels(out_ch))
    set_param(bus, fx, 1, out_ch)
    set_param(bus, fx, 2, #tracks)
    set_param(bus, fx, CURSOR_INFLUENCE_PARAM, 1)
    set_param(bus, fx, CURSOR_RADIUS_PARAM, 1.25)
    set_param(bus, fx, CURSOR_FOCUS_PARAM, 2)
    set_param(bus, fx, CURSOR_GATE_PARAM, 0.02)
    local input_start = 1
    for i, src in ipairs(tracks) do
      local src_ch = source_counts[i]
      set_node_name(bus, i, track_name(src, "Source " .. tostring(i)))
      mc.create_postfx_send(src, bus, src_ch, input_start - 1)
      reaper.SetMediaTrackInfo_Value(src, "B_MAINSEND", 0)
      local a = (i - 1) / math.max(1, #tracks) * math.pi * 2
      set_param(bus, fx, node_param(i, 0), 1)
      set_param(bus, fx, node_param(i, 1), 0)
      set_param(bus, fx, node_param(i, 2), infer_layout_for_track(src, src_ch))
      set_param(bus, fx, node_param(i, 3), src_ch)
      set_param(bus, fx, node_param(i, 4), input_start)
      set_param(bus, fx, node_param(i, 5), math.cos(a) * 0.35)
      set_param(bus, fx, node_param(i, 6), math.sin(a) * 0.35)
      set_param(bus, fx, node_param(i, 7), 0)
      set_param(bus, fx, node_param(i, 8), 0.62)
      set_param(bus, fx, node_param(i, 9), 3.0)
      set_param(bus, fx, node_rotate_param(i), 0)
      input_start = input_start + src_ch
    end
    for i = #tracks + 1, MAX_NODES do set_node_name(bus, i, "") end
  end
  attach_gmem()
  matrix_fill(#tracks, out_ch, true)
  reaper.SetOnlyTrackSelected(bus)
  reaper.Undo_EndBlock("Create 128ch Node Track Mixer bus", -1)
  return bus, nil
end

local function current_bus()
  local tracks = selected_tracks()
  if #tracks == 1 and find_fx(tracks[1]) >= 0 then return tracks[1] end
  local bus, err = setup_from_selected_tracks()
  if not bus then reaper.MB(err or "Could not create node mixer bus.", TITLE, 0) end
  return bus
end

bus = current_bus()
if not bus then return end
fx = add_fx(bus)
if fx < 0 then
  reaper.MB("Could not load JS: " .. FX_NAME, TITLE, 0)
  return
end

local matrix_existed = attach_gmem()
if not matrix_existed then matrix_fill(math.floor(get_param(bus, fx, 2, 4) + 0.5), math.floor(get_param(bus, fx, 1, 8) + 0.5), true) end
matrix_repair_trims(math.floor(get_param(bus, fx, 2, 4) + 0.5), math.floor(get_param(bus, fx, 1, 8) + 0.5))

local function speaker_xyz(ch, count, layout)
  local idx = ch - 1
  if layout == 0 then
    return count <= 1 and 0 or idx / (count - 1) * 2 - 1, 0, 0
  elseif layout == 1 then
    local az = -45 - idx * 360 / math.max(1, count)
    return -math.sin(math.rad(az)), math.cos(math.rad(az)), 0
  elseif layout == 2 then
    return (idx % 2 == 1) and -1 or 1, (math.floor(idx / 2) % 2 == 1) and -1 or 1, (math.floor(idx / 4) % 2 == 1) and 1 or -1
  elseif layout == 3 then
    local half = math.max(1, math.floor(count / 2))
    local layer = idx < half and 0 or 1
    local pos = idx % half
    local az = -45 - pos * 360 / half
    local ring = layer == 1 and 0.74 or 1.0
    return -math.sin(math.rad(az)) * ring, math.cos(math.rad(az)) * ring, layer == 1 and 0.65 or -0.10
  elseif layout == 4 then
    local layer = idx < 12 and 0 or 1
    local pos = layer == 1 and idx - 12 or idx
    local az = -45 - pos * 360 / (layer == 1 and math.max(1, count - 12) or 12)
    local el = layer == 1 and 45 or 0
    return -math.sin(math.rad(az)) * math.cos(math.rad(el)), math.cos(math.rad(az)) * math.cos(math.rad(el)), math.sin(math.rad(el))
  else
    if idx == 24 then return 0, 0, 1 end
    local layer = idx < 12 and 0 or 1
    local pos = layer == 1 and idx - 12 or idx
    local az = -45 - pos * 360 / 12
    local el = layer == 1 and 45 or 0
    return -math.sin(math.rad(az)) * math.cos(math.rad(el)), math.cos(math.rad(az)) * math.cos(math.rad(el)), math.sin(math.rad(el))
  end
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
  x0 = finite(x0, 0)
  y0 = finite(y0, 0)
  w = math.max(1, finite(w, 1))
  h = math.max(1, finite(h, 1))
  local rx, ry = rotate_view(x, y, z)
  local s = math.min(w, h) * 0.42 * math.max(0.001, view_zoom)
  return x0 + w * 0.5 + (rx + view_pan_x) * s, y0 + h * 0.5 - (ry + view_pan_y) * s
end

local function screen_to_xy(px, py, z, x0, y0, w, h)
  x0 = finite(x0, 0)
  y0 = finite(y0, 0)
  w = math.max(1, finite(w, 1))
  h = math.max(1, finite(h, 1))
  z = finite(z, 0)
  local s = math.min(w, h) * 0.42 * math.max(0.001, view_zoom)
  local rx = ((finite(px, x0 + w * 0.5) - (x0 + w * 0.5)) / s) - view_pan_x
  local ry = -((finite(py, y0 + h * 0.5) - (y0 + h * 0.5)) / s) - view_pan_y
  local yaw = math.rad(view_azim_deg)
  local pitch = math.rad(view_elev_deg)
  local cy, sy = math.cos(yaw), math.sin(yaw)
  local cp, sp = math.cos(pitch), math.sin(pitch)
  if math.abs(cp) < 0.001 then cp = cp < 0 and -0.001 or 0.001 end
  local y1 = (ry + z * sp) / cp
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
  local radius = math.max(0.001, get_param(bus, fx, CURSOR_RADIUS_PARAM, 1))
  local focus = math.max(0.1, get_param(bus, fx, CURSOR_FOCUS_PARAM, 2))
  local gate = clamp(get_param(bus, fx, CURSOR_GATE_PARAM, 0), 0, 0.95)
  local dist
  if mix_mode == 1 then
    local stack_pos = get_param(bus, fx, STACK_POSITION_PARAM, 1)
    dist = math.abs(node - stack_pos)
  else
    local x = get_param(bus, fx, node_param(node, 5), 0)
    local y = get_param(bus, fx, node_param(node, 6), 0)
    local z = get_param(bus, fx, node_param(node, 7), 0)
    local cx = get_param(bus, fx, CURSOR_X_PARAM, 0)
    local cy = get_param(bus, fx, CURSOR_Y_PARAM, 0)
    local cz = get_param(bus, fx, CURSOR_Z_PARAM, 0)
    dist = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy) + (z - cz) * (z - cz))
  end
  local raw = math.exp(-((dist / radius) ^ focus))
  if gate > 0 then
    raw = raw <= gate and 0 or (raw - gate) / math.max(0.0001, 1 - gate)
  end
  return (1 - influence) + influence * raw
end

local function cursor_weight_for_distance(dist, influence, radius, focus, gate)
  if influence <= 0 then return 1 end
  radius = math.max(0.001, radius or 1)
  focus = math.max(0.1, focus or 2)
  gate = clamp(gate or 0, 0, 0.95)
  local raw = math.exp(-((math.max(0, dist) / radius) ^ focus))
  if gate > 0 then raw = raw <= gate and 0 or (raw - gate) / math.max(0.0001, 1 - gate) end
  return (1 - influence) + influence * raw
end

local function draw_curve_display(influence, radius, focus, gate)
  local draw = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(260, ImGui.GetContentRegionAvail(ctx))
  local h = 96
  ImGui.InvisibleButton(ctx, "##cursor_curve_display", w, h)
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
    local dist = t * max_dist
    local weight = cursor_weight_for_distance(dist, influence, radius, focus, gate)
    local px = gx1 + (gx2 - gx1) * t
    local py = gy1 - (gy1 - gy2) * clamp(weight, 0, 1)
    if last_x then ImGui.DrawList_AddLine(draw, last_x, last_y, px, py, COLORS.hot, 2) end
    last_x, last_y = px, py
  end
  ImGui.DrawList_AddText(draw, gx1 + 2, gy1 - 14, COLORS.muted, "0")
  ImGui.DrawList_AddText(draw, gx2 - 44, gy1 - 14, COLORS.muted, string.format("%.1f", max_dist))
end

local function automation_mode_name(track)
  if not track or not reaper.GetTrackAutomationMode then return "Unknown" end
  local mode = reaper.GetTrackAutomationMode(track)
  return AUTO_MODE_NAMES[mode] or ("Mode " .. tostring(mode))
end

local function set_track_write_mode(track, write_enabled)
  if not track or not reaper.SetTrackAutomationMode then return false end
  reaper.SetTrackAutomationMode(track, write_enabled and 3 or 0)
  automation_status = write_enabled
    and "Track set to Write; GUI moves will write automation."
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

local function draw_node_field(dl, x, y, r, selected)
  local br, bg, bb = selected and 0.98 or 0.25, selected and 0.72 or 0.68, selected and 0.25 or 0.90
  for step = 12, 1, -1 do
    local t = step / 12
    local a = 0.012 + (1 - t) * (1 - t) * 0.18
    ImGui.DrawList_AddCircleFilled(dl, x, y, r * t, color(br, bg, bb, a), 64)
  end
  ImGui.DrawList_AddCircle(dl, x, y, r, color(br, bg, bb, selected and 0.42 or 0.22), 64, selected and 1.7 or 1.0)
end

local function draw_node_shape(dl, node, layout, x0, y0, w, h, selected)
  local src_ch = math.floor(get_param(bus, fx, node_param(node, 3), 2) + 0.5)
  local cx = get_param(bus, fx, node_param(node, 5), 0)
  local cy = get_param(bus, fx, node_param(node, 6), 0)
  local cz = get_param(bus, fx, node_param(node, 7), 0)
  local scale = get_param(bus, fx, node_param(node, 8), 0.62)
  local col = selected and COLORS.node_sel or COLORS.node
  local last_px, last_py
  for ch = 1, math.min(src_ch, 64) do
    local sx, sy, sz = speaker_xyz(ch, src_ch, layout)
    local px, py = project(cx + sx * scale, cy + sy * scale, cz + sz * scale, x0, y0, w, h)
    if last_px and (layout == 1 or layout == 3 or layout == 4 or layout == 5) then
      ImGui.DrawList_AddLine(dl, last_px, last_py, px, py, color(0.72, 0.84, 0.92, selected and 0.44 or 0.26), 1)
    end
    ImGui.DrawList_AddCircleFilled(dl, px, py, selected and 4.5 or 3.5, col, 12)
    if src_ch <= 16 then ImGui.DrawList_AddText(dl, px + 5, py - 6, COLORS.muted, tostring(ch)) end
    last_px, last_py = px, py
  end
end

local function nudge(label, w, h, apply)
  if ImGui.Button(ctx, label, w, h) or ImGui.IsItemActive(ctx) then apply() end
end

local function draw_stacked_view(layout, out_ch, node_count)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(620, ImGui.GetContentRegionAvail(ctx))
  local h = 430
  ImGui.InvisibleButton(ctx, "##node_track_stacked_view", w, h)
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x0 + w, y0 + h, COLORS.bg)
  ImGui.DrawList_AddRect(dl, x0, y0, x0 + w, y0 + h, COLORS.edge)
  ImGui.DrawList_AddText(dl, x0 + 14, y0 + 12, COLORS.text, "Stacked shape mixer")
  ImGui.DrawList_AddText(dl, x0 + 14, y0 + 30, COLORS.muted, "Shapes share one bed; channel rotate shifts each node's corner/ring assignment.")

  local rail_x1 = x0 + 26
  local rail_x2 = x0 + w - 26
  local rail_y = y0 + 54
  local stack_pos = get_param(bus, fx, STACK_POSITION_PARAM, 1)
  if ImGui.IsItemHovered(ctx) then
    local mx, my = ImGui.GetMousePos(ctx)
    if ImGui.IsMouseClicked(ctx, 0) and my >= rail_y - 24 and my <= rail_y + 24 then drag_kind = "stack_cursor" end
  end
  if drag_kind == "stack_cursor" and ImGui.IsMouseDown(ctx, 0) then
    local mx = ImGui.GetMousePos(ctx)
    local t = clamp((mx - rail_x1) / math.max(1, rail_x2 - rail_x1), 0, 1)
    stack_pos = 1 + t * math.max(0, node_count - 1)
    set_param(bus, fx, STACK_POSITION_PARAM, stack_pos)
  elseif drag_kind == "stack_cursor" and not ImGui.IsMouseDown(ctx, 0) then
    drag_kind = nil
  end
  ImGui.DrawList_AddLine(dl, rail_x1, rail_y, rail_x2, rail_y, COLORS.grid, 1)
  for n = 1, node_count do
    local tx = rail_x1 + (rail_x2 - rail_x1) * ((n - 1) / math.max(1, node_count - 1))
    local weight = cursor_weight_for_node(n, 1)
    ImGui.DrawList_AddCircleFilled(dl, tx, rail_y, 3 + weight * 4, n == selected_node and COLORS.node_sel or COLORS.node, 16)
    ImGui.DrawList_AddText(dl, tx - 4, rail_y - 22, COLORS.muted, tostring(n))
  end
  local cursor_x = rail_x1 + (rail_x2 - rail_x1) * ((stack_pos - 1) / math.max(1, node_count - 1))
  ImGui.DrawList_AddLine(dl, cursor_x, rail_y - 16, cursor_x, y0 + h - 16, COLORS.hot, 2)

  local cols = math.min(4, math.max(1, node_count))
  local rows = math.ceil(node_count / cols)
  local cell_w = (w - 52) / cols
  local cell_h = math.max(92, (h - 78) / math.max(1, rows))
  local points = {}
  for n = 1, node_count do
    local col = (n - 1) % cols
    local row = math.floor((n - 1) / cols)
    local cx = x0 + 26 + cell_w * col + cell_w * 0.5
    local cy = y0 + 70 + cell_h * row + cell_h * 0.5
    local src_layout = math.floor(get_param(bus, fx, node_param(n, 2), 0) + 0.5)
    local src_ch = math.floor(get_param(bus, fx, node_param(n, 3), 2) + 0.5)
    local rotate = math.floor(get_param(bus, fx, node_rotate_param(n), 0) + 0.5)
    local scale = math.min(cell_w, cell_h) * 0.30
    local selected = n == selected_node
    local cweight = cursor_weight_for_node(n, 1)
    local col_u32 = selected and COLORS.node_sel or COLORS.node
    points[n] = {}
    ImGui.DrawList_AddText(dl, cx - 24, cy - scale - 22, selected and COLORS.node_sel or COLORS.text,
      string.format("N%d %.2f %s", n, cweight, short_name(node_name(n), 16)))
    for ch = 1, math.min(src_ch, 32) do
      local rotated = ((ch - 1 + rotate) % src_ch) + 1
      local sx, sy = speaker_xyz(rotated, src_ch, src_layout)
      local px = cx + sx * scale
      local py = cy - sy * scale
      points[n][ch] = { x = px, y = py }
      if ch > 1 and (src_layout == 1 or src_layout == 3 or src_layout == 4 or src_layout == 5) and points[n][ch - 1] then
        local p = points[n][ch - 1]
        ImGui.DrawList_AddLine(dl, p.x, p.y, px, py, color(0.72, 0.84, 0.92, selected and 0.40 or 0.22), 1)
      end
      ImGui.DrawList_AddCircleFilled(dl, px, py, selected and 4.5 or 3.5, col_u32, 12)
      if src_ch <= 12 then ImGui.DrawList_AddText(dl, px + 5, py - 6, COLORS.muted, tostring(ch)) end
      if n > 1 and points[n - 1] and points[n - 1][ch] then
        local p = points[n - 1][ch]
        ImGui.DrawList_AddLine(dl, p.x, p.y, px, py, color(0.68, 0.72, 0.74, selected and 0.30 or 0.15), 1)
      end
    end
  end
end

local function draw_view(layout, out_ch, node_count, mix_mode)
  if mix_mode == 1 then
    draw_stacked_view(layout, out_ch, node_count)
    return
  end
  local dl = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(620, ImGui.GetContentRegionAvail(ctx))
  local h = 430
  ImGui.InvisibleButton(ctx, "##node_track_view", w, h)
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x0 + w, y0 + h, COLORS.bg)
  ImGui.DrawList_AddRect(dl, x0, y0, x0 + w, y0 + h, COLORS.edge)
  ImGui.DrawList_AddText(dl, x0 + 14, y0 + 12, COLORS.text, "Node Track Mixer field")

  local cursor_x = get_param(bus, fx, CURSOR_X_PARAM, 0)
  local cursor_y = get_param(bus, fx, CURSOR_Y_PARAM, 0)
  local cursor_z = get_param(bus, fx, CURSOR_Z_PARAM, 0)
  local cpx, cpy = project(cursor_x, cursor_y, cursor_z, x0, y0, w, h)
  local cursor_col = draw_color(COLORS.hot)
  local node_positions = {}
  for n = 1, node_count do
    local x = get_param(bus, fx, node_param(n, 5), 0)
    local y = get_param(bus, fx, node_param(n, 6), 0)
    local z = get_param(bus, fx, node_param(n, 7), 0)
    local px, py = project(x, y, z, x0, y0, w, h)
    node_positions[n] = { x = x, y = y, z = z, px = px, py = py }
  end

  if ImGui.IsItemHovered(ctx) then
    local mx, my = ImGui.GetMousePos(ctx)
    if ImGui.IsMouseClicked(ctx, 0) then
      local best_kind = nil
      local best_node = nil
      local best_d2 = dist2(mx, my, cpx, cpy)
      if best_d2 <= 24 * 24 then best_kind = "cursor" end
      for n = 1, node_count do
        local pos = node_positions[n]
        local d2 = dist2(mx, my, pos.px, pos.py)
        if d2 <= 22 * 22 and (not best_kind or d2 < best_d2) then
          best_kind = "node"
          best_node = n
          best_d2 = d2
        end
      end
      drag_kind = best_kind
      drag_node = best_node
      if drag_kind == "node" and drag_node then selected_node = drag_node end
    end
  end
  if drag_kind and ImGui.IsMouseDown(ctx, 0) then
    local mx, my = ImGui.GetMousePos(ctx)
    if drag_kind == "cursor" then
      local nx, ny = screen_to_xy(mx, my, cursor_z, x0, y0, w, h)
      set_param(bus, fx, CURSOR_X_PARAM, nx)
      set_param(bus, fx, CURSOR_Y_PARAM, ny)
      cursor_x, cursor_y = nx, ny
      cpx, cpy = project(cursor_x, cursor_y, cursor_z, x0, y0, w, h)
    elseif drag_kind == "node" and drag_node then
      local pos = node_positions[drag_node]
      local nx, ny = screen_to_xy(mx, my, pos and pos.z or 0, x0, y0, w, h)
      set_param(bus, fx, node_param(drag_node, 5), nx)
      set_param(bus, fx, node_param(drag_node, 6), ny)
      if pos then
        pos.x, pos.y = nx, ny
        pos.px, pos.py = project(nx, ny, pos.z, x0, y0, w, h)
      end
    end
  elseif drag_kind and not ImGui.IsMouseDown(ctx, 0) then
    drag_kind = nil
    drag_node = nil
  end

  ImGui.DrawList_AddCircle(dl, cpx, cpy, 13, cursor_col, 24, 2)
  ImGui.DrawList_AddLine(dl, cpx - 18, cpy, cpx + 18, cpy, cursor_col, 1.5)
  ImGui.DrawList_AddLine(dl, cpx, cpy - 18, cpx, cpy + 18, cursor_col, 1.5)

  for n = 1, node_count do
    local src_layout = math.floor(get_param(bus, fx, node_param(n, 2), 0) + 0.5)
    local pos = node_positions[n] or { x = 0, y = 0, z = 0, px = x0 + w * 0.5, py = y0 + h * 0.5 }
    local radius = get_param(bus, fx, node_param(n, 8), 1)
    local px, py = pos.px, pos.py
    local cweight = cursor_weight_for_node(n, 0)
    draw_node_field(dl, px, py, radius * math.min(w, h) * 0.18 * view_zoom, n == selected_node)
    draw_node_shape(dl, n, src_layout, x0, y0, w, h, n == selected_node)
    ImGui.DrawList_AddCircleFilled(dl, px, py, n == selected_node and 12 or 9, n == selected_node and COLORS.node_sel or COLORS.node, 24)
    ImGui.DrawList_AddText(dl, px + 14, py - 8, COLORS.text,
      string.format("%d %.2f %s", n, cweight, short_name(node_name(n), 18)))
  end
end

local function combo_layout(label, layout)
  if ImGui.BeginCombo(ctx, label, LAYOUTS[layout + 1] or LAYOUTS[1]) then
    for i, label in ipairs(LAYOUTS) do
      local selected = layout == i - 1
      if ImGui.Selectable(ctx, label, selected) then layout = i - 1 end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return layout
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

local function required_bus_channels(node_count, out_ch)
  local required = out_ch
  for n = 1, node_count do
    local start_ch = math.floor(get_param(bus, fx, node_param(n, 4), 1) + 0.5)
    local src_ch = math.floor(get_param(bus, fx, node_param(n, 3), 2) + 0.5)
    required = math.max(required, start_ch + src_ch - 1)
  end
  return even_channels(required)
end

local function draw_output_strip(id, node, out_ch)
  local draw = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(180, ImGui.GetContentRegionAvail(ctx))
  local h = 18
  ImGui.InvisibleButton(ctx, id, w, h)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + h, COLORS.matrix_off)
  local gap = 1
  local cell_w = math.max(1, (w - gap * (out_ch - 1)) / out_ch)
  for ch = 1, out_ch do
    local on = matrix_get(node, ch) > 0
    local x1 = x + (ch - 1) * (cell_w + gap)
    local x2 = ch == out_ch and x + w or x1 + cell_w
    ImGui.DrawList_AddRectFilled(draw, x1, y, x2, y + h, on and COLORS.matrix_on or color(0.08, 0.09, 0.10, 1))
  end
  ImGui.DrawList_AddRect(draw, x, y, x + w, y + h, COLORS.edge)
end

local function draw_routing_overview(node_count, out_ch)
  if not ImGui.CollapsingHeader(ctx, "Routing overview", ImGui.TreeNodeFlags_DefaultOpen) then return end
  ImGui.TextColored(ctx, COLORS.muted, "Compact source-to-output view. Use the matrix below for exact channel masks.")
  if ImGui.BeginTable(ctx, "routing_overview", 6, ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg | ImGui.TableFlags_SizingStretchProp) then
    ImGui.TableSetupColumn(ctx, "Node", ImGui.TableColumnFlags_WidthFixed, 54)
    ImGui.TableSetupColumn(ctx, "Track", ImGui.TableColumnFlags_WidthFixed, 190)
    ImGui.TableSetupColumn(ctx, "Input", ImGui.TableColumnFlags_WidthFixed, 110)
    ImGui.TableSetupColumn(ctx, "Shape", ImGui.TableColumnFlags_WidthFixed, 120)
    ImGui.TableSetupColumn(ctx, "Mask", ImGui.TableColumnFlags_WidthFixed, 74)
    ImGui.TableSetupColumn(ctx, "Outputs")
    ImGui.TableHeadersRow(ctx)
    for n = 1, node_count do
      local active = get_param(bus, fx, node_param(n, 0), 1) >= 0.5
      local src_layout = math.floor(get_param(bus, fx, node_param(n, 2), 0) + 0.5)
      local src_ch = math.floor(get_param(bus, fx, node_param(n, 3), 2) + 0.5)
      local input_start = math.floor(get_param(bus, fx, node_param(n, 4), 1) + 0.5)
      local active_outputs = 0
      for ch = 1, out_ch do if matrix_get(n, ch) > 0 then active_outputs = active_outputs + 1 end end
      ImGui.TableNextRow(ctx)
      ImGui.TableSetColumnIndex(ctx, 0)
      if ImGui.Selectable(ctx, string.format("N%d", n), selected_node == n) then selected_node = n end
      ImGui.TableSetColumnIndex(ctx, 1)
      ImGui.Text(ctx, short_name(node_name(n), 30))
      ImGui.TableSetColumnIndex(ctx, 2)
      ImGui.Text(ctx, string.format("%d-%d", input_start, input_start + src_ch - 1))
      ImGui.TableSetColumnIndex(ctx, 3)
      ImGui.TextColored(ctx, active and COLORS.text or COLORS.muted, LAYOUTS[src_layout + 1] or LAYOUTS[1])
      ImGui.TableSetColumnIndex(ctx, 4)
      ImGui.Text(ctx, string.format("%d/%d", active_outputs, out_ch))
      ImGui.TableSetColumnIndex(ctx, 5)
      draw_output_strip("##route_strip_" .. tostring(n), n, out_ch)
    end
    ImGui.EndTable(ctx)
  end
end

local function draw_matrix(node_count, out_ch)
  ImGui.Text(ctx, "Node / output matrix mask")
  if ImGui.Button(ctx, "All On") then matrix_fill(node_count, out_ch, true) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "All Off") then matrix_fill(node_count, out_ch, false) end
  ImGui.SameLine(ctx)
  local max_start = math.max(1, out_ch - 31)
  local changed
  changed, matrix_start = ImGui.SliderInt(ctx, "Matrix first channel", matrix_start, 1, max_start)
  matrix_start = clamp(matrix_start, 1, max_start)
  local shown = math.min(32, out_ch - matrix_start + 1)
  if ImGui.BeginTable(ctx, "node_matrix", shown + 1, ImGui.TableFlags_Borders | ImGui.TableFlags_SizingFixedFit) then
    ImGui.TableSetupColumn(ctx, "Node")
    for ch = matrix_start, matrix_start + shown - 1 do ImGui.TableSetupColumn(ctx, tostring(ch)) end
    ImGui.TableHeadersRow(ctx)
    for n = 1, node_count do
      ImGui.TableNextRow(ctx)
      ImGui.TableSetColumnIndex(ctx, 0)
      if ImGui.Selectable(ctx, "N" .. tostring(n) .. " " .. short_name(node_name(n), 14), selected_node == n) then selected_node = n end
      for ch = matrix_start, matrix_start + shown - 1 do
        ImGui.TableSetColumnIndex(ctx, ch - matrix_start + 1)
        local on = matrix_get(n, ch) > 0
        ImGui.PushStyleColor(ctx, ImGui.Col_Button, on and COLORS.matrix_on or COLORS.matrix_off)
        if ImGui.Button(ctx, "##m_" .. n .. "_" .. ch, 18, 18) then matrix_set(n, ch, not on) end
        ImGui.PopStyleColor(ctx)
      end
    end
    ImGui.EndTable(ctx)
  end
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 1040, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local _, bus_name = reaper.GetTrackName(bus, "")
    ImGui.Text(ctx, bus_name ~= "" and bus_name or "Node Track Mixer bus")
    ImGui.TextColored(ctx, COLORS.muted, "Each source track is a channel-shape node; use spatial objects or stacked shapes for the mix bed.")

    local layout = math.floor(get_param(bus, fx, 0, 1) + 0.5)
    layout = combo_layout("Mix bed shape", layout)
    set_param(bus, fx, 0, layout)
    local mix_mode = math.floor(get_param(bus, fx, MIX_MODE_PARAM, 0) + 0.5)
    mix_mode = combo_mix_mode(mix_mode)
    set_param(bus, fx, MIX_MODE_PARAM, mix_mode)
    local out_ch = math.floor(get_param(bus, fx, 1, 8) + 0.5)
    local node_count = math.floor(get_param(bus, fx, 2, 4) + 0.5)
    local changed
    changed, out_ch = ImGui.SliderInt(ctx, "Output channels", out_ch, 2, MAX_CH)
    if changed then
      set_param(bus, fx, 1, out_ch)
      reaper.SetMediaTrackInfo_Value(bus, "I_NCHAN", required_bus_channels(node_count, out_ch))
    end
    changed, node_count = ImGui.SliderInt(ctx, "Node count", node_count, 1, MAX_NODES)
    if changed then set_param(bus, fx, 2, node_count) end
    selected_node = clamp(selected_node, 1, node_count)
    local stack_pos = get_param(bus, fx, STACK_POSITION_PARAM, 1)
    if stack_pos > node_count then set_param(bus, fx, STACK_POSITION_PARAM, node_count) end

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
      if ImGui.Button(ctx, "Show cursor lanes") then
        automation_status = "Shown/armed " .. tostring(show_params(cursor_params)) .. " cursor envelopes."
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Hide cursor") then
        automation_status = "Hidden " .. tostring(hide_params(cursor_params)) .. " cursor envelopes."
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Show curve lanes") then
        automation_status = "Shown/armed " .. tostring(show_params(curve_params)) .. " curve envelopes."
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Hide curve") then
        automation_status = "Hidden " .. tostring(hide_params(curve_params)) .. " curve envelopes."
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Show stack") then
        automation_status = "Shown/armed " .. tostring(show_params(stack_params)) .. " stack envelope."
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Hide stack") then
        automation_status = "Hidden " .. tostring(hide_params(stack_params)) .. " stack envelope."
      end
      ImGui.TextColored(ctx, COLORS.muted,
        write_mode
          and "Write mode: GUI movement writes to armed automation lanes."
          or "Trim/Read: GUI controls parameters live without writing automation.")
      if automation_status ~= "" then ImGui.TextColored(ctx, COLORS.muted, automation_status) end
    end

    if ImGui.CollapsingHeader(ctx, "Mix Cursor", ImGui.TreeNodeFlags_DefaultOpen) then
      local influence = get_param(bus, fx, CURSOR_INFLUENCE_PARAM, 0)
      changed, influence = ImGui.SliderDouble(ctx, "Cursor influence", influence, 0, 1, "%.3f")
      if changed then set_param(bus, fx, CURSOR_INFLUENCE_PARAM, influence) end
      if mix_mode == 1 then
        stack_pos = get_param(bus, fx, STACK_POSITION_PARAM, 1)
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
      changed, radius = ImGui.SliderDouble(ctx, "Cursor radius", radius, 0.05, 8, "%.3f")
      if changed then set_param(bus, fx, CURSOR_RADIUS_PARAM, radius) end
      changed, focus = ImGui.SliderDouble(ctx, "Cursor focus", focus, 0.2, 12, "%.3f")
      if changed then set_param(bus, fx, CURSOR_FOCUS_PARAM, focus) end
      changed, gate = ImGui.SliderDouble(ctx, "Cursor gate", gate, 0, 0.95, "%.3f")
      if changed then set_param(bus, fx, CURSOR_GATE_PARAM, gate) end
      draw_curve_display(influence, radius, focus, gate)
      ImGui.TextColored(ctx, COLORS.muted, "Radius sets reach, focus shapes the curve, gate cuts distant node weights to zero. Use influence 1.0 for full silence outside the gate.")
      ImGui.TextColored(ctx, COLORS.muted, "Automate these JSFX parameters in REAPER to compose the movement/mix.")
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

    draw_view(layout, out_ch, node_count, mix_mode)

    if ImGui.CollapsingHeader(ctx, "Selected Node", ImGui.TreeNodeFlags_DefaultOpen) then
      ImGui.Text(ctx, "Node " .. tostring(selected_node) .. ": " .. node_name(selected_node))
      local active = get_param(bus, fx, node_param(selected_node, 0), 1) >= 0.5
      changed, active = ImGui.Checkbox(ctx, "Active", active)
      if changed then set_param(bus, fx, node_param(selected_node, 0), active and 1 or 0) end
      local src_layout = math.floor(get_param(bus, fx, node_param(selected_node, 2), 0) + 0.5)
      src_layout = combo_layout("Node source shape", src_layout)
      set_param(bus, fx, node_param(selected_node, 2), src_layout)
      local src_ch = math.floor(get_param(bus, fx, node_param(selected_node, 3), 2) + 0.5)
      changed, src_ch = ImGui.SliderInt(ctx, "Source channels", src_ch, 1, MAX_CH)
      if changed then
        set_param(bus, fx, node_param(selected_node, 3), src_ch)
        reaper.SetMediaTrackInfo_Value(bus, "I_NCHAN", required_bus_channels(node_count, out_ch))
      end
      local input_start = math.floor(get_param(bus, fx, node_param(selected_node, 4), 1) + 0.5)
      changed, input_start = ImGui.SliderInt(ctx, "Input start channel", input_start, 1, MAX_CH)
      if changed then
        set_param(bus, fx, node_param(selected_node, 4), input_start)
        reaper.SetMediaTrackInfo_Value(bus, "I_NCHAN", required_bus_channels(node_count, out_ch))
      end
      local labels = mix_mode == 1 and { "Level dB", "Focus" } or { "Level dB", "X", "Y", "Z", "Shape scale", "Focus" }
      local ranges = mix_mode == 1
        and { { -60, 12, "%.1f" }, { 0.2, 12, "%.3f" } }
        or {
          { -60, 12, "%.1f" }, { -2, 2, "%.3f" }, { -2, 2, "%.3f" },
          { -2, 2, "%.3f" }, { 0.05, 4, "%.3f" }, { 0.2, 12, "%.3f" },
        }
      local offsets = mix_mode == 1 and { 1, 9 } or { 1, 5, 6, 7, 8, 9 }
      for i = 1, #labels do
        local v = get_param(bus, fx, node_param(selected_node, offsets[i]), i == 5 and 0.62 or 0)
        changed, v = ImGui.SliderDouble(ctx, labels[i], v, ranges[i][1], ranges[i][2], ranges[i][3])
        if changed then set_param(bus, fx, node_param(selected_node, offsets[i]), v) end
      end
      local rotate = math.floor(get_param(bus, fx, node_rotate_param(selected_node), 0) + 0.5)
      changed, rotate = ImGui.SliderInt(ctx, "Channel rotate", rotate, -MAX_CH, MAX_CH)
      if changed then set_param(bus, fx, node_rotate_param(selected_node), rotate) end
      if mix_mode == 1 then
        ImGui.TextColored(ctx, COLORS.muted, "Stacked mode aligns node shapes; level, focus, and channel rotate affect the mix.")
      end
    end

    draw_routing_overview(node_count, out_ch)
    draw_matrix(node_count, out_ch)

    if ImGui.Button(ctx, "Close", 100, 28) then open = false end
    ImGui.End(ctx)
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
