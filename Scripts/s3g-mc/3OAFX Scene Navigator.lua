-- @description 3OAFX Scene Navigator
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline ambisonic scene traversal.
-- @method Select multiple WAV-backed ACN/SN3D ambisonic media items. Each item becomes a soundfield node on an editable scene map; the listener path uses XYZ, head-orientation, and time breakpoints with visual preview before rendering a new ambisonic traversal.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

local TITLE = "3OAFX Scene Navigator"
local EXT = "s3g_mc_foafx_scene_navigator_v1"

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", TITLE, 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local ORDER_LABELS = { "1OA / 4ch", "2OA / 9ch", "3OA / 16ch" }
local MODE_LABELS = { "Blend field", "Nearest field" }
local MODE_KEYS = { "blend", "nearest" }
local ORIENTATION_LABELS = { "Face trajectory", "Manual AED" }
local ORIENTATION_KEYS = { "path", "manual" }
local VIEW_LABELS = { "3/4", "Top", "Side" }
local ctx
local open = true
local selected_node = 1
local selected_point = 1
local drag_kind = nil
local drag_index = 0
local preview_playing = false
local preview_t = tonumber(reaper.GetExtState(EXT, "preview_t")) or 0.0
local preview_last_time = reaper.time_precise()
local preview_speed = tonumber(reaper.GetExtState(EXT, "preview_speed")) or 1.0
local view_zoom = tonumber(reaper.GetExtState(EXT, "view_zoom")) or 1.0
local view_pan_x = tonumber(reaper.GetExtState(EXT, "view_pan_x")) or 0.0
local view_pan_y = tonumber(reaper.GetExtState(EXT, "view_pan_y")) or 0.0
local view_mode = math.max(1, math.min(#VIEW_LABELS, math.floor(tonumber(reaper.GetExtState(EXT, "view_mode")) or 1)))
local view_azim_deg = tonumber(reaper.GetExtState(EXT, "view_azim_deg")) or -38.0
local view_elev_deg = tonumber(reaper.GetExtState(EXT, "view_elev_deg")) or -28.0

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local COLORS = {
  bg = color(0.035, 0.039, 0.042, 1),
  panel = color(0.060, 0.066, 0.070, 1),
  edge = color(0.34, 0.38, 0.38, 1),
  grid = color(0.55, 0.60, 0.60, 0.18),
  text = color(0.78, 0.83, 0.82, 1),
  muted = color(0.48, 0.54, 0.54, 1),
  node = color(0.25, 0.68, 0.90, 0.92),
  node_sel = color(0.98, 0.72, 0.25, 0.98),
  path = color(0.90, 0.56, 0.95, 0.92),
  path_soft = color(0.90, 0.56, 0.95, 0.24),
  listener = color(0.98, 0.42, 0.28, 0.96),
  influence = color(0.25, 0.68, 0.90, 0.13),
}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function lerp_angle(a, b, t)
  local diff = ((b - a + 180) % 360) - 180
  return a + diff * t
end

local function getn(key, default)
  return tonumber(reaper.GetExtState(EXT, key)) or default
end

local function getb(key, default)
  local value = reaper.GetExtState(EXT, key)
  if value == "" then return default end
  return value ~= "0"
end

local function set_value(key, value)
  reaper.SetExtState(EXT, key, type(value) == "boolean" and (value and "1" or "0") or tostring(value), true)
end

local function combo(label, idx, labels)
  if ImGui.BeginCombo(ctx, label, labels[idx] or "") then
    for i, name in ipairs(labels) do
      local selected = i == idx
      if ImGui.Selectable(ctx, name, selected) then idx = i end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return idx
end

local function order_channels(order_index)
  local order = math.max(1, math.min(3, math.floor(order_index or 3)))
  return (order + 1) * (order + 1)
end

local function source_duration(entry)
  return entry.length * math.max(0.000001, entry.playrate or 1.0)
end

local function join_values(entries, key)
  local values = {}
  for _, entry in ipairs(entries) do values[#values + 1] = tostring(entry[key] or 0) end
  return table.concat(values, ",")
end

local function join_source_durations(entries)
  local values = {}
  for _, entry in ipairs(entries) do values[#values + 1] = tostring(source_duration(entry)) end
  return table.concat(values, ",")
end

local function join_paths(entries)
  local values = {}
  for _, entry in ipairs(entries) do values[#values + 1] = entry.filename end
  return table.concat(values, "\n")
end

local function rows_to_text(rows, width)
  local parts = {}
  for _, row in ipairs(rows) do
    local vals = {}
    for i = 1, width do vals[#vals + 1] = string.format("%.6f", row[i] or 0) end
    parts[#parts + 1] = table.concat(vals, ",")
  end
  return table.concat(parts, ";")
end

local function parse_rows(text, width)
  local rows = {}
  for row in tostring(text or ""):gmatch("[^;]+") do
    local vals = {}
    for part in row:gmatch("[^,]+") do vals[#vals + 1] = tonumber(part) end
    if #vals >= width then
      local out = {}
      for i = 1, width do out[i] = vals[i] or 0 end
      rows[#rows + 1] = out
    end
  end
  return rows
end

local function default_nodes(count)
  local rows = {}
  for i = 1, count do
    local a = (i - 1) / math.max(1, count) * math.pi * 2
    rows[i] = { math.cos(a) * 0.85, math.sin(a) * 0.85, ((i - 1) % 3 - 1) * 0.22, 1.0 }
  end
  return rows
end

local function default_path()
  return {
    { -0.85, -0.55, 0.00, 0, 0, 0, 0.00 },
    { -0.30, 0.40, 0.18, 35, 8, 0, 0.25 },
    { 0.15, -0.18, -0.10, -15, -6, 0, 0.50 },
    { 0.55, 0.20, 0.20, -55, 6, 0, 0.75 },
    { 0.90, 0.55, 0.00, 0, 0, 0, 1.00 },
  }
end

local function load_rows(key, width, fallback)
  local rows = parse_rows(reaper.GetExtState(EXT, key), width)
  return #rows > 0 and rows or fallback
end

local function load_nodes(count)
  local stored = reaper.GetExtState(EXT, "nodes")
  local rows = parse_rows(stored, 4)
  if #rows == 0 then
    rows = parse_rows(stored, 3)
    for _, row in ipairs(rows) do row[4] = 1.0 end
  end
  if #rows == 0 then rows = default_nodes(count) end
  return rows
end

local function save_scene(nodes, path)
  set_value("nodes", rows_to_text(nodes, 4))
  set_value("path", rows_to_text(path, 7))
  set_value("preview_t", preview_t)
  set_value("preview_speed", preview_speed)
  set_value("view_zoom", view_zoom)
  set_value("view_pan_x", view_pan_x)
  set_value("view_pan_y", view_pan_y)
  set_value("view_mode", view_mode)
  set_value("view_azim_deg", view_azim_deg)
  set_value("view_elev_deg", view_elev_deg)
end

local function sorted_path(path)
  local copy = {}
  for i, p in ipairs(path) do
    copy[i] = { p[1], p[2], p[3], p[4], p[5], p[6], clamp(p[7] or 0, 0, 1), i }
  end
  table.sort(copy, function(a, b)
    if a[7] == b[7] then return (a[8] or 0) < (b[8] or 0) end
    return a[7] < b[7]
  end)
  return copy
end

local function interp_path(path, t)
  if #path == 0 then return { 0, 0, 0, 0, 0, 0, 0 } end
  if #path == 1 then return path[1] end
  local rows = sorted_path(path)
  t = clamp(t or 0, 0, 1)
  if t <= rows[1][7] then return rows[1] end
  for i = 1, #rows - 1 do
    local a, b = rows[i], rows[i + 1]
    if t <= b[7] then
      local span = math.max(0.000001, b[7] - a[7])
      local f = clamp((t - a[7]) / span, 0, 1)
      return {
        lerp(a[1], b[1], f),
        lerp(a[2], b[2], f),
        lerp(a[3], b[3], f),
        lerp_angle(a[4], b[4], f),
        lerp_angle(a[5], b[5], f),
        lerp_angle(a[6], b[6], f),
        t,
      }
    end
  end
  return rows[#rows]
end

local function path_facing_orientation(path, t)
  local a = interp_path(path, clamp((t or 0) - 0.006, 0, 1))
  local b = interp_path(path, clamp((t or 0) + 0.006, 0, 1))
  local dx = b[1] - a[1]
  local dy = b[2] - a[2]
  local dz = b[3] - a[3]
  local horiz = math.sqrt(dx * dx + dy * dy)
  if horiz < 0.00001 and math.abs(dz) < 0.00001 then return 0, 0, 0 end
  local yaw = -math.deg(math.atan(dx, dy))
  local pitch = math.deg(math.atan(dz, math.max(0.000001, horiz)))
  return yaw, clamp(pitch, -90, 90), 0
end

local function oriented_path_row(path, t, orientation_mode)
  local row = interp_path(path, t)
  if orientation_mode == 1 then
    row = { row[1], row[2], row[3], row[4], row[5], row[6], row[7] }
    row[4], row[5], row[6] = path_facing_orientation(path, t)
  end
  return row
end

local function rotate_view_point(x, y, z)
  local yaw = math.rad(view_azim_deg)
  local pitch = math.rad(view_elev_deg)
  local cy, sy = math.cos(yaw), math.sin(yaw)
  local cp, sp = math.cos(pitch), math.sin(pitch)
  local x1 = x * cy - y * sy
  local y1 = x * sy + y * cy
  local z1 = z
  local y2 = y1 * cp - z1 * sp
  local z2 = y1 * sp + z1 * cp
  return x1, y2, z2
end

local function world_to_top(x, y, x0, y0, w, h, z)
  z = z or 0
  local rx, ry = rotate_view_point(x, y, z)
  local s = math.min(w, h) * 0.42 * view_zoom
  return x0 + w * 0.5 + (rx + view_pan_x) * s, y0 + h * 0.5 - (ry + view_pan_y) * s
end

local function top_to_world(mx, my, x0, y0, w, h, current)
  local s = math.min(w, h) * 0.42 * view_zoom
  local sx = (mx - (x0 + w * 0.5)) / s - view_pan_x
  local sy = ((y0 + h * 0.5) - my) / s - view_pan_y
  current = current or { 0, 0, 0 }
  if view_mode == 2 then
    return clamp(sx, -2, 2), clamp(sy, -2, 2), current[3] or 0
  elseif view_mode == 3 then
    return clamp(sx, -2, 2), current[2] or 0, clamp(sy, -2, 2)
  end
  local yaw = math.rad(view_azim_deg)
  local pitch = math.rad(view_elev_deg)
  local cy, syaw = math.cos(yaw), math.sin(yaw)
  local cp, sp = math.cos(pitch), math.sin(pitch)
  local z = current[3] or 0
  local y1 = (sy + z * sp) / math.max(0.000001, cp)
  local x = sx * cy + y1 * syaw
  local y = -sx * syaw + y1 * cy
  return clamp(x, -2, 2), clamp(y, -2, 2), z
end

local function set_camera_preset(mode, azim, elev)
  view_mode = mode
  view_azim_deg = azim
  view_elev_deg = elev
end

local function world_to_side(x, z, x0, y0, w, h)
  return x0 + w * 0.08 + (x + 2) / 4 * w * 0.84, y0 + h * 0.5 - z / 2 * h * 0.42
end

local function side_to_world(mx, my, x0, y0, w, h)
  return clamp(((mx - (x0 + w * 0.08)) / (w * 0.84)) * 4 - 2, -2, 2), clamp(((y0 + h * 0.5) - my) / (h * 0.42) * 2, -2, 2)
end

local function draw_grid(draw_list, x0, y0, w, h)
  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x0 + w, y0 + h, COLORS.bg)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x0 + w, y0 + h, COLORS.edge)
  local fx, fy = world_to_top(0, 1.0, x0, y0, w, h, 0)
  local rx, ry = world_to_top(0, -1.0, x0, y0, w, h, 0)
  local lx, ly = world_to_top(1.0, 0, x0, y0, w, h, 0)
  local bx, by = world_to_top(-1.0, 0, x0, y0, w, h, 0)
  ImGui.DrawList_AddLine(draw_list, fx, fy, rx, ry, COLORS.grid, 1)
  ImGui.DrawList_AddLine(draw_list, lx, ly, bx, by, COLORS.grid, 1)
  local ux, uy = world_to_top(0, 0, x0, y0, w, h, 0)
  local zx, zy = world_to_top(0, 0, x0, y0, w, h, 1.0)
  ImGui.DrawList_AddLine(draw_list, ux, uy, zx, zy, COLORS.grid, 1.4)
  ImGui.DrawList_AddText(draw_list, zx + 5, zy - 8, COLORS.muted, "Z")
  local degree_marks = {
    { 0, "0 front" },
    { -90, "-90 right" },
    { 90, "+90 left" },
    { 180, "180 rear" },
  }
  for _, mark in ipairs(degree_marks) do
    local deg = mark[1]
    local rad = math.rad(deg)
    local wx = -math.sin(rad)
    local wy = math.cos(rad)
    local x, y = world_to_top(wx, wy, x0, y0, w, h, 0)
    ImGui.DrawList_AddText(draw_list, x + 6, y - 8, COLORS.muted, mark[2])
  end
end

local function camera_controls()
  local function nudge(label, width, height, apply)
    if ImGui.Button(ctx, label, width, height) or ImGui.IsItemActive(ctx) then apply() end
  end
  ImGui.Text(ctx, "View")
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, (view_mode == 1 and "[3/4]" or "3/4"), 54, 24) then set_camera_preset(1, -38, -28) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, (view_mode == 2 and "[Top]" or "Top"), 54, 24) then set_camera_preset(2, 0, 0) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, (view_mode == 3 and "[Side]" or "Side"), 54, 24) then set_camera_preset(3, 0, -90) end
  ImGui.SameLine(ctx)
  nudge("Zoom -", 74, 24, function() view_zoom = clamp(view_zoom * 0.975, 0.35, 3.0) end)
  ImGui.SameLine(ctx)
  nudge("Zoom +", 74, 24, function() view_zoom = clamp(view_zoom * 1.025, 0.35, 3.0) end)
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Reset View", 94, 24) then view_zoom, view_pan_x, view_pan_y = 1.0, 0.0, 0.0 end
  ImGui.SameLine(ctx)
  nudge("Left", 48, 24, function() view_pan_x = clamp(view_pan_x + 0.035 / view_zoom, -2, 2) end)
  ImGui.SameLine(ctx)
  nudge("Right", 54, 24, function() view_pan_x = clamp(view_pan_x - 0.035 / view_zoom, -2, 2) end)
  ImGui.SameLine(ctx)
  nudge("Up", 42, 24, function() view_pan_y = clamp(view_pan_y - 0.035 / view_zoom, -2, 2) end)
  ImGui.SameLine(ctx)
  nudge("Down", 54, 24, function() view_pan_y = clamp(view_pan_y + 0.035 / view_zoom, -2, 2) end)
  ImGui.SameLine(ctx)
  ImGui.Text(ctx, string.format("view %.2fx", view_zoom))
  nudge("Az -##scene_cam", 58, 24, function() view_mode = 1; view_azim_deg = view_azim_deg - 2 end)
  ImGui.SameLine(ctx)
  nudge("Az +##scene_cam", 58, 24, function() view_mode = 1; view_azim_deg = view_azim_deg + 2 end)
  ImGui.SameLine(ctx)
  nudge("El +##scene_cam", 58, 24, function() view_mode = 1; view_elev_deg = clamp(view_elev_deg + 2, -89, 89) end)
  ImGui.SameLine(ctx)
  nudge("El -##scene_cam", 58, 24, function() view_mode = 1; view_elev_deg = clamp(view_elev_deg - 2, -89, 89) end)
  local changed
  changed, view_azim_deg = ImGui.SliderDouble(ctx, "Camera azim", view_azim_deg, -180, 180, "%.0f deg")
  if changed then view_mode = 1 end
  changed, view_elev_deg = ImGui.SliderDouble(ctx, "Camera elev", view_elev_deg, -89, 89, "%.0f deg")
  if changed then view_mode = 1 end
end

local function draw_head(draw_list, cx, cy, yaw_deg, pitch_deg, roll_deg, scale, body_col, line_col, label)
  local yaw = math.rad(yaw_deg or 0)
  local pitch = clamp(pitch_deg or 0, -90, 90) / 90
  local roll = math.rad(roll_deg or 0)
  local rx = -math.sin(yaw)
  local ry = -math.cos(yaw)
  local side_x = -ry
  local side_y = rx
  local r = scale or 14
  ImGui.DrawList_AddCircleFilled(draw_list, cx, cy, r, body_col, 28)
  ImGui.DrawList_AddCircle(draw_list, cx, cy, r, line_col, 28, 1.2)
  local nose_x = cx + rx * (r + 12)
  local nose_y = cy + ry * (r + 12)
  ImGui.DrawList_AddLine(draw_list, cx, cy, nose_x, nose_y, line_col, 2.4)
  ImGui.DrawList_AddTriangleFilled(draw_list,
    nose_x, nose_y,
    cx + rx * (r + 3) + side_x * 4, cy + ry * (r + 3) + side_y * 4,
    cx + rx * (r + 3) - side_x * 4, cy + ry * (r + 3) - side_y * 4,
    line_col)
  local ear_r = 3.0 + math.abs(pitch) * 3.0
  local roll_off = math.sin(roll) * 3.0
  ImGui.DrawList_AddCircleFilled(draw_list, cx + side_x * (r + 3), cy + side_y * (r + 3) + roll_off, ear_r, line_col, 12)
  ImGui.DrawList_AddCircleFilled(draw_list, cx - side_x * (r + 3), cy - side_y * (r + 3) - roll_off, ear_r, line_col, 12)
  if label then ImGui.DrawList_AddText(draw_list, cx + r + 5, cy - r - 2, COLORS.text, label) end
end

local function draw_preview_cursor(draw_list, cx, cy, yaw_deg, label)
  local yaw = math.rad(yaw_deg or 0)
  local rx = -math.sin(yaw)
  local ry = -math.cos(yaw)
  local side_x = -ry
  local side_y = rx
  ImGui.DrawList_AddCircle(draw_list, cx, cy, 16, COLORS.listener, 28, 1.8)
  ImGui.DrawList_AddLine(draw_list, cx - 5, cy, cx + 5, cy, COLORS.listener, 1.2)
  ImGui.DrawList_AddLine(draw_list, cx, cy - 5, cx, cy + 5, COLORS.listener, 1.2)
  local tip_x = cx + rx * 28
  local tip_y = cy + ry * 28
  ImGui.DrawList_AddLine(draw_list, cx, cy, tip_x, tip_y, COLORS.listener, 2.2)
  ImGui.DrawList_AddTriangleFilled(draw_list,
    tip_x, tip_y,
    cx + rx * 20 + side_x * 4, cy + ry * 20 + side_y * 4,
    cx + rx * 20 - side_x * 4, cy + ry * 20 - side_y * 4,
    COLORS.listener)
  if label then ImGui.DrawList_AddText(draw_list, tip_x + 5, tip_y - 8, COLORS.text, label) end
end

local function draw_node_field(draw_list, cx, cy, radius, selected)
  local steps = 14
  local base_r, base_g, base_b = 0.25, 0.68, 0.90
  if selected then base_r, base_g, base_b = 0.98, 0.72, 0.25 end
  for step = steps, 1, -1 do
    local t = step / steps
    local alpha = 0.015 + (1.0 - t) * (1.0 - t) * 0.20
    ImGui.DrawList_AddCircleFilled(draw_list, cx, cy, radius * t, color(base_r, base_g, base_b, alpha), 72)
  end
  ImGui.DrawList_AddCircle(draw_list, cx, cy, radius, color(base_r, base_g, base_b, selected and 0.40 or 0.22), 72, selected and 1.8 or 1.1)
end

local function draw_top_map(nodes, path, settings, preview_row)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(620, ImGui.GetContentRegionAvail(ctx))
  local h = 405
  ImGui.InvisibleButton(ctx, "##scene_top_map", w, h)
  local hovered = ImGui.IsItemHovered(ctx)
  local mx, my = ImGui.GetMousePos(ctx)
  draw_grid(draw_list, x0, y0, w, h)
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 12, COLORS.text, "Scene map: nodes and listener path")
  local drag_hint = view_mode == 3 and "drag in side view = X/Z" or "drag = X/Y; use sliders for Z"
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 32, COLORS.muted, drag_hint)

  for i, node in ipairs(nodes) do
    local nx, ny = world_to_top(node[1], node[2], x0, y0, w, h, node[3] or 0)
    local node_radius = math.max(0.05, settings.influence_radius * (node[4] or 1.0))
    local radius = node_radius * math.min(w, h) * 0.42 * view_zoom
    local ball = clamp(5.5 + node_radius * 4.8 + math.abs(node[3] or 0) * 2.0, 6, 22)
    draw_node_field(draw_list, nx, ny, radius, i == selected_node)
    ImGui.DrawList_AddCircleFilled(draw_list, nx, ny, i == selected_node and ball + 2 or ball, i == selected_node and COLORS.node_sel or COLORS.node, 28)
    ImGui.DrawList_AddText(draw_list, nx + ball + 4, ny - 9, COLORS.text, tostring(i))
    ImGui.DrawList_AddText(draw_list, nx + ball + 4, ny + 7, COLORS.muted, string.format("r %.2f z %.2f", node_radius, node[3] or 0))
  end

  for i = 1, #path - 1 do
    local ax, ay = world_to_top(path[i][1], path[i][2], x0, y0, w, h, path[i][3] or 0)
    local bx, by = world_to_top(path[i + 1][1], path[i + 1][2], x0, y0, w, h, path[i + 1][3] or 0)
    ImGui.DrawList_AddLine(draw_list, ax, ay, bx, by, COLORS.path, 2.4)
  end
  for i, point in ipairs(path) do
    local px, py = world_to_top(point[1], point[2], x0, y0, w, h, point[3] or 0)
    local display = point
    if settings.orientation_mode == 1 then
      display = oriented_path_row(path, point[7] or 0, settings.orientation_mode)
    end
    ImGui.DrawList_AddCircleFilled(draw_list, px, py, i == selected_point and 8 or 5, i == selected_point and COLORS.listener or COLORS.path, 20)
    ImGui.DrawList_AddCircle(draw_list, px, py, 18, COLORS.path_soft, 28, 1.2)
    local yaw = math.rad(display[4] or 0)
    local tick_col = i == selected_point and COLORS.listener or COLORS.path
    local tick_len = i == selected_point and 22 or 18
    ImGui.DrawList_AddLine(draw_list, px, py, px - math.sin(yaw) * tick_len, py - math.cos(yaw) * tick_len, tick_col, i == selected_point and 2.0 or 1.5)
  end

  if preview_row then
    local hx, hy = world_to_top(preview_row[1], preview_row[2], x0, y0, w, h, preview_row[3] or 0)
    draw_preview_cursor(draw_list, hx, hy, preview_row[4], "preview")
  end

  if hovered and ImGui.IsMouseClicked(ctx, 0) then
    local best_kind, best_i, best_d = nil, 0, 1e9
    for i, node in ipairs(nodes) do
      local x, y = world_to_top(node[1], node[2], x0, y0, w, h, node[3] or 0)
      local d = (mx - x) * (mx - x) + (my - y) * (my - y)
      if d < best_d and d < 22 * 22 then best_kind, best_i, best_d = "node", i, d end
    end
    for i, point in ipairs(path) do
      local x, y = world_to_top(point[1], point[2], x0, y0, w, h, point[3] or 0)
      local d = (mx - x) * (mx - x) + (my - y) * (my - y)
      if d < best_d and d < 22 * 22 then best_kind, best_i, best_d = "path", i, d end
    end
    if best_kind then
      drag_kind, drag_index = best_kind, best_i
      if best_kind == "node" then selected_node = best_i else selected_point = best_i end
    end
  end

  if drag_kind and ImGui.IsMouseDown(ctx, 0) then
    if drag_kind == "node" and nodes[drag_index] then
      local wx, wy, wz = top_to_world(mx, my, x0, y0, w, h, nodes[drag_index])
      nodes[drag_index][1], nodes[drag_index][2], nodes[drag_index][3] = wx, wy, wz
    elseif drag_kind == "path" and path[drag_index] then
      local wx, wy, wz = top_to_world(mx, my, x0, y0, w, h, path[drag_index])
      path[drag_index][1], path[drag_index][2], path[drag_index][3] = wx, wy, wz
    end
  elseif drag_kind and not ImGui.IsMouseDown(ctx, 0) then
    drag_kind, drag_index = nil, 0
  end
end

local function draw_side_view(nodes, path, preview_row)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(620, ImGui.GetContentRegionAvail(ctx))
  local h = 180
  ImGui.InvisibleButton(ctx, "##scene_side_view", w, h)
  local hovered = ImGui.IsItemHovered(ctx)
  local mx, my = ImGui.GetMousePos(ctx)
  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x0 + w, y0 + h, COLORS.bg)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x0 + w, y0 + h, COLORS.edge)
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 12, COLORS.text, "Height view: X-Z")
  ImGui.DrawList_AddLine(draw_list, x0 + 12, y0 + h * 0.5, x0 + w - 12, y0 + h * 0.5, COLORS.grid, 1)

  for i = 1, #path - 1 do
    local ax, ay = world_to_side(path[i][1], path[i][3], x0, y0, w, h)
    local bx, by = world_to_side(path[i + 1][1], path[i + 1][3], x0, y0, w, h)
    ImGui.DrawList_AddLine(draw_list, ax, ay, bx, by, COLORS.path, 2)
  end
  for i, node in ipairs(nodes) do
    local x, y = world_to_side(node[1], node[3], x0, y0, w, h)
    ImGui.DrawList_AddCircleFilled(draw_list, x, y, i == selected_node and 9 or 6, i == selected_node and COLORS.node_sel or COLORS.node, 20)
    ImGui.DrawList_AddText(draw_list, x + 10, y - 8, COLORS.text, tostring(i))
  end
  for i, point in ipairs(path) do
    local x, y = world_to_side(point[1], point[3], x0, y0, w, h)
    ImGui.DrawList_AddCircleFilled(draw_list, x, y, i == selected_point and 7 or 4, i == selected_point and COLORS.listener or COLORS.path, 18)
  end
  if preview_row then
    local x, y = world_to_side(preview_row[1], preview_row[3], x0, y0, w, h)
    ImGui.DrawList_AddCircle(draw_list, x, y, 18, COLORS.listener, 28, 2.0)
    ImGui.DrawList_AddText(draw_list, x + 20, y - 9, COLORS.text, "preview")
  end

  if hovered and ImGui.IsMouseClicked(ctx, 0) then
    local best_kind, best_i, best_d = nil, 0, 1e9
    for i, node in ipairs(nodes) do
      local x, y = world_to_side(node[1], node[3], x0, y0, w, h)
      local d = (mx - x) * (mx - x) + (my - y) * (my - y)
      if d < best_d and d < 18 * 18 then best_kind, best_i, best_d = "node_z", i, d end
    end
    for i, point in ipairs(path) do
      local x, y = world_to_side(point[1], point[3], x0, y0, w, h)
      local d = (mx - x) * (mx - x) + (my - y) * (my - y)
      if d < best_d and d < 18 * 18 then best_kind, best_i, best_d = "path_z", i, d end
    end
    if best_kind then
      drag_kind, drag_index = best_kind, best_i
      if best_kind == "node_z" then selected_node = best_i else selected_point = best_i end
    end
  end
  if drag_kind and (drag_kind == "node_z" or drag_kind == "path_z") and ImGui.IsMouseDown(ctx, 0) then
    local wx, wz = side_to_world(mx, my, x0, y0, w, h)
    if drag_kind == "node_z" and nodes[drag_index] then
      nodes[drag_index][1], nodes[drag_index][3] = wx, wz
    elseif drag_kind == "path_z" and path[drag_index] then
      path[drag_index][1], path[drag_index][3] = wx, wz
    end
  end
end

local function draw_orientation_breakpoints(path, orientation_mode)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(620, ImGui.GetContentRegionAvail(ctx))
  local h = 170
  ImGui.InvisibleButton(ctx, "##orientation_breakpoints", w, h)
  local hovered = ImGui.IsItemHovered(ctx)
  local mx, my = ImGui.GetMousePos(ctx)
  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x0 + w, y0 + h, COLORS.bg)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x0 + w, y0 + h, COLORS.edge)
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 10, COLORS.text, "Listener AED / time breakpoints")
  if orientation_mode == 1 then
    ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 30, COLORS.muted, "horizontal = render time; yaw/pitch are derived from trajectory direction")
  else
    ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 30, COLORS.muted, "horizontal = render time; vertical lanes show yaw, pitch, and roll")
  end
  local left, right = x0 + 70, x0 + w - 18
  local lanes = {
    { label = "Yaw", index = 4, min = -180, max = 180, col = color(0.98, 0.42, 0.28, 1) },
    { label = "Pitch", index = 5, min = -90, max = 90, col = color(0.25, 0.68, 0.90, 1) },
    { label = "Roll", index = 6, min = -180, max = 180, col = color(0.90, 0.56, 0.95, 1) },
  }
  for li, lane in ipairs(lanes) do
    local cy = y0 + 60 + (li - 1) * 34
    ImGui.DrawList_AddText(draw_list, x0 + 16, cy - 8, COLORS.text, lane.label)
    ImGui.DrawList_AddLine(draw_list, left, cy, right, cy, COLORS.grid, 1)
    local sorted = sorted_path(path)
    for i = 1, #sorted - 1 do
      local a, b = sorted[i], sorted[i + 1]
      local ax = left + clamp(a[7], 0, 1) * (right - left)
      local bx = left + clamp(b[7], 0, 1) * (right - left)
      local av = a[lane.index]
      local bv = b[lane.index]
      if orientation_mode == 1 then
        av = oriented_path_row(path, a[7], orientation_mode)[lane.index]
        bv = oriented_path_row(path, b[7], orientation_mode)[lane.index]
      end
      local ay = cy - ((clamp(av, lane.min, lane.max) - lane.min) / (lane.max - lane.min) - 0.5) * 24
      local by = cy - ((clamp(bv, lane.min, lane.max) - lane.min) / (lane.max - lane.min) - 0.5) * 24
      ImGui.DrawList_AddLine(draw_list, ax, ay, bx, by, lane.col, 1.8)
    end
    for i, p in ipairs(path) do
      local px = left + clamp(p[7] or 0, 0, 1) * (right - left)
      local v = p[lane.index]
      if orientation_mode == 1 then v = oriented_path_row(path, p[7] or 0, orientation_mode)[lane.index] end
      local py = cy - ((clamp(v, lane.min, lane.max) - lane.min) / (lane.max - lane.min) - 0.5) * 24
      ImGui.DrawList_AddCircleFilled(draw_list, px, py, i == selected_point and 5.5 or 3.5, i == selected_point and COLORS.node_sel or lane.col, 14)
    end
  end
  local play_x = left + preview_t * (right - left)
  ImGui.DrawList_AddLine(draw_list, play_x, y0 + 54, play_x, y0 + h - 16, COLORS.listener, 2.0)

  if hovered and ImGui.IsMouseClicked(ctx, 0) then
    local best_i, best_d = selected_point, 1e9
    for i, p in ipairs(path) do
      local px = left + clamp(p[7] or 0, 0, 1) * (right - left)
      local d = math.abs(mx - px)
      if d < best_d and d < 14 then best_i, best_d = i, d end
    end
    selected_point = best_i
    preview_t = clamp((mx - left) / math.max(1, right - left), 0, 1)
  end
end

local function draw_preview_transport(path, settings)
  local now = reaper.time_precise()
  local dt = now - preview_last_time
  preview_last_time = now
  if preview_playing then
    preview_t = preview_t + dt * preview_speed / math.max(0.001, settings.duration)
    if preview_t >= 1.0 then preview_t = 1.0; preview_playing = false end
  end
  if ImGui.Button(ctx, preview_playing and "Stop Preview" or "Play Preview", 118, 28) then
    preview_playing = not preview_playing
    preview_last_time = reaper.time_precise()
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Reset Preview", 112, 28) then preview_t = 0.0; preview_playing = false end
  ImGui.SameLine(ctx)
  local changed
  changed, preview_speed = ImGui.SliderDouble(ctx, "Preview speed", preview_speed, 0.1, 8.0, "%.2fx")
  changed, preview_t = ImGui.SliderDouble(ctx, "Preview time", preview_t, 0.0, 1.0, "%.3f")
  local row = oriented_path_row(path, preview_t, settings.orientation_mode)
  ImGui.Text(ctx, string.format("Preview head: X %.2f  Y %.2f  Z %.2f  yaw %.1f  pitch %.1f  roll %.1f", row[1], row[2], row[3], row[4], row[5], row[6]))
  return row
end

local function add_path_point(path)
  local src = path[selected_point] or path[#path] or { 0, 0, 0, 0, 0, 0, 1 }
  local copy = { src[1], src[2], src[3], src[4], src[5], src[6], src[7] }
  table.insert(path, math.min(#path + 1, selected_point + 1), copy)
  selected_point = math.min(#path, selected_point + 1)
end

local function remove_path_point(path)
  if #path <= 2 then return end
  table.remove(path, selected_point)
  selected_point = clamp(selected_point, 1, #path)
end

local function preset_line(path)
  path[1] = { -0.95, -0.65, 0.0, 0, 0, 0, 0.0 }
  path[2] = { -0.35, 0.20, 0.1, 35, 5, 0, 0.33 }
  path[3] = { 0.35, -0.10, -0.1, -35, -5, 0, 0.66 }
  path[4] = { 0.95, 0.65, 0.0, 0, 0, 0, 1.0 }
  while #path > 4 do table.remove(path) end
end

local function preset_orbit(path)
  while #path > 0 do table.remove(path) end
  for i = 0, 7 do
    local t = i / 7
    local a = t * math.pi * 2
    path[#path + 1] = { math.cos(a) * 1.05, math.sin(a) * 1.05, math.sin(a * 2) * 0.25, t * 360, math.sin(a) * 15, 0, t }
  end
  selected_point = 1
end

local function preset_head_scan(path)
  while #path > 0 do table.remove(path) end
  path[1] = { -0.70, -0.35, 0.00, 0, 0, 0, 0.00 }
  path[2] = { -0.25, 0.10, 0.10, 70, 4, 0, 0.22 }
  path[3] = { 0.05, 0.20, 0.08, -70, -3, 0, 0.52 }
  path[4] = { 0.45, -0.05, 0.00, 45, 2, 0, 0.76 }
  path[5] = { 0.80, 0.35, 0.00, 0, 0, 0, 1.00 }
  selected_point = 1
end

local entries = nr.selected_entries()
if #entries < 2 then
  mc.show_error("Select two or more WAV-backed ambisonic media items.")
  return
end

local nodes = load_nodes(#entries)
while #nodes < #entries do nodes[#nodes + 1] = default_nodes(#entries)[#nodes + 1] end
while #nodes > #entries do table.remove(nodes) end
local path_points = load_rows("path", 7, default_path())

local settings = {
  source_order = math.max(1, math.min(3, math.floor(getn("source_order", 3)))),
  output_order = math.max(1, math.min(3, math.floor(getn("output_order", 3)))),
  mode = math.max(1, math.min(#MODE_KEYS, math.floor(getn("mode", 1)))),
  orientation_mode = math.max(1, math.min(#ORIENTATION_KEYS, math.floor(getn("orientation_mode", 1)))),
  duration = getn("duration", math.max(8.0, entries[#entries].position + entries[#entries].length - entries[1].position)),
  influence_radius = getn("influence_radius", 1.25),
  distance_falloff = getn("distance_falloff", 1.4),
  blend_sharpness = getn("blend_sharpness", 1.2),
  perspective_rotation = getn("perspective_rotation", 0.80),
  near_field_blur = getn("near_field_blur", 0.25),
  height_sensitivity = getn("height_sensitivity", 0.65),
  motion_smoothing = getn("motion_smoothing", 0.35),
  loop_crossfade_ms = getn("loop_crossfade_ms", 80.0),
  output_gain_db = getn("output_gain_db", 0.0),
  normalize = getb("normalize", true),
  normalize_db = getn("normalize_db", -6.0),
  soft_limit = getb("soft_limit", true),
}

local function persist()
  for key, value in pairs(settings) do set_value(key, value) end
  save_scene(nodes, path_points)
end

local function validate()
  local needed = order_channels(settings.source_order)
  for i, entry in ipairs(entries) do
    if entry.channels < needed then
      return "Source " .. tostring(i) .. " has " .. tostring(entry.channels) .. " channels, but " .. ORDER_LABELS[settings.source_order] .. " needs " .. tostring(needed) .. "."
    end
    if entry.filename == "" or not nr.file_exists(entry.filename) or not entry.filename:lower():match("%.wav$") then
      return "Source " .. tostring(i) .. " must be backed by a readable WAV file."
    end
  end
  return nil
end

local function render()
  local err = validate()
  if err then mc.show_error(err) return end
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_foafx_scene_navigator_renders", entries[1].filename, script_dir)
  local output_path = out_dir .. "/s3g_foafx_scene_navigator_" .. stamp .. "_" .. tostring(settings.output_order) .. "oa.wav"
  local manifest = {
    source_paths = join_paths(entries),
    source_starts = join_values(entries, "start_offset"),
    source_durations = join_source_durations(entries),
    sample_rate = nr.source_sample_rate(entries[1]),
    output_path = output_path,
    source_order = settings.source_order,
    output_order = settings.output_order,
    duration = settings.duration,
    navigation_mode = MODE_KEYS[settings.mode],
    orientation_mode = ORIENTATION_KEYS[settings.orientation_mode],
    node_positions = rows_to_text(nodes, 4),
    path_points = rows_to_text(path_points, 7),
    influence_radius = settings.influence_radius,
    distance_falloff = settings.distance_falloff,
    blend_sharpness = settings.blend_sharpness,
    perspective_rotation = settings.perspective_rotation,
    near_field_blur = settings.near_field_blur,
    height_sensitivity = settings.height_sensitivity,
    motion_smoothing = settings.motion_smoothing,
    loop_crossfade_ms = settings.loop_crossfade_ms,
    output_gain_db = settings.output_gain_db,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    soft_limit = settings.soft_limit,
  }
  local log, elapsed = nr.run_backend(script_dir, "foafx_scene_navigator", manifest, TITLE)
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, insert_err = nr.insert_output_item(output_path, "3OAFX Scene Navigator (" .. tostring(settings.output_order) .. "OA)", entries[1].position, order_channels(settings.output_order), { master_send = false, track_gain = 0.5 })
  reaper.Undo_EndBlock(TITLE, -1)
  if not item then mc.show_error(insert_err or "Could not insert rendered item.") return end
  mc.print_plan(TITLE, {
    "Sources: " .. tostring(#entries),
    "Source order: " .. ORDER_LABELS[settings.source_order],
    "Output order: " .. ORDER_LABELS[settings.output_order],
    "Mode: " .. MODE_LABELS[settings.mode],
    "Output: " .. output_path,
    "Master send: off",
    string.format("NumPy time: %.2f sec", elapsed),
    log,
  })
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 980, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local footer_h = 58
    local control_h = math.max(300, ImGui.GetWindowHeight(ctx) - footer_h)
    if ImGui.BeginChild(ctx, "##scene_navigator_controls", 0, control_h) then
    ImGui.Text(ctx, "Selected 3OAFX scene nodes: " .. tostring(#entries))
    ImGui.TextColored(ctx, COLORS.muted, "Each selected item is a movable soundfield node; the path is the listener trajectory.")
    local preview_row = draw_preview_transport(path_points, settings)
    camera_controls()
    draw_top_map(nodes, path_points, settings, preview_row)
    draw_orientation_breakpoints(path_points, settings.orientation_mode)

    ImGui.Separator(ctx)
    settings.source_order = combo("Source order", settings.source_order, ORDER_LABELS)
    settings.output_order = combo("Output order", settings.output_order, ORDER_LABELS)
    settings.mode = combo("Navigation mode", settings.mode, MODE_LABELS)
    settings.orientation_mode = combo("Head orientation", settings.orientation_mode, ORIENTATION_LABELS)
    local changed
    changed, settings.duration = ImGui.SliderDouble(ctx, "Duration sec", settings.duration, 0.25, 900.0, "%.2f")
    changed, settings.influence_radius = ImGui.SliderDouble(ctx, "Global node radius", settings.influence_radius, 0.05, 4.0, "%.2f")
    changed, settings.distance_falloff = ImGui.SliderDouble(ctx, "Distance falloff", settings.distance_falloff, 0.2, 5.0, "%.2f")
    changed, settings.blend_sharpness = ImGui.SliderDouble(ctx, "Blend sharpness", settings.blend_sharpness, 0.1, 5.0, "%.2f")
    changed, settings.perspective_rotation = ImGui.SliderDouble(ctx, "Perspective rotation", settings.perspective_rotation, 0.0, 1.0, "%.2f")
    changed, settings.near_field_blur = ImGui.SliderDouble(ctx, "Near-field blur", settings.near_field_blur, 0.0, 1.0, "%.2f")
    changed, settings.height_sensitivity = ImGui.SliderDouble(ctx, "Height sensitivity", settings.height_sensitivity, 0.0, 2.0, "%.2f")
    changed, settings.motion_smoothing = ImGui.SliderDouble(ctx, "Motion smoothing", settings.motion_smoothing, 0.0, 0.98, "%.2f")
    changed, settings.loop_crossfade_ms = ImGui.SliderDouble(ctx, "Source loop crossfade ms", settings.loop_crossfade_ms, 0.0, 1000.0, "%.0f")
    changed, settings.output_gain_db = ImGui.SliderDouble(ctx, "Output gain dB", settings.output_gain_db, -24.0, 24.0, "%.1f")

    if ImGui.CollapsingHeader(ctx, "Selected Node", ImGui.TreeNodeFlags_DefaultOpen) then
      selected_node = clamp(selected_node, 1, #nodes)
      ImGui.Text(ctx, entries[selected_node] and entries[selected_node].name or ("Node " .. tostring(selected_node)))
      changed, nodes[selected_node][1] = ImGui.SliderDouble(ctx, "Node X", nodes[selected_node][1], -2.0, 2.0, "%.3f")
      changed, nodes[selected_node][2] = ImGui.SliderDouble(ctx, "Node Y", nodes[selected_node][2], -2.0, 2.0, "%.3f")
      changed, nodes[selected_node][3] = ImGui.SliderDouble(ctx, "Node Z", nodes[selected_node][3], -2.0, 2.0, "%.3f")
      nodes[selected_node][4] = nodes[selected_node][4] or 1.0
      changed, nodes[selected_node][4] = ImGui.SliderDouble(ctx, "Node radius", nodes[selected_node][4], 0.10, 3.00, "%.2f")
      ImGui.TextColored(ctx, COLORS.muted, string.format("Effective radius: %.2f", settings.influence_radius * nodes[selected_node][4]))
    end

    if ImGui.CollapsingHeader(ctx, "Listener Path", ImGui.TreeNodeFlags_DefaultOpen) then
      selected_point = clamp(selected_point, 1, #path_points)
      if ImGui.Button(ctx, "Line") then preset_line(path_points) end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Orbit") then preset_orbit(path_points) end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Head Scan") then preset_head_scan(path_points) end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Add Point") then add_path_point(path_points) end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Remove Point") then remove_path_point(path_points) end
      ImGui.Text(ctx, "Point " .. tostring(selected_point) .. " / " .. tostring(#path_points))
      local p = path_points[selected_point]
      changed, p[1] = ImGui.SliderDouble(ctx, "Listener X", p[1], -2.0, 2.0, "%.3f")
      changed, p[2] = ImGui.SliderDouble(ctx, "Listener Y", p[2], -2.0, 2.0, "%.3f")
      changed, p[3] = ImGui.SliderDouble(ctx, "Listener Z", p[3], -2.0, 2.0, "%.3f")
      if settings.orientation_mode == 1 then
        local o = oriented_path_row(path_points, p[7] or 0, settings.orientation_mode)
        ImGui.TextColored(ctx, COLORS.muted, string.format("Head faces path: yaw %.1f / pitch %.1f / roll %.1f", o[4], o[5], o[6]))
      else
        changed, p[4] = ImGui.SliderDouble(ctx, "Yaw deg", p[4], -360.0, 360.0, "%.1f")
        changed, p[5] = ImGui.SliderDouble(ctx, "Pitch deg", p[5], -90.0, 90.0, "%.1f")
        changed, p[6] = ImGui.SliderDouble(ctx, "Roll deg", p[6], -180.0, 180.0, "%.1f")
      end
      changed, p[7] = ImGui.SliderDouble(ctx, "Time", p[7], 0.0, 1.0, "%.3f")
    end

    changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
    if settings.normalize then
      changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -24.0, 0.0, "%.1f")
    end
    changed, settings.soft_limit = ImGui.Checkbox(ctx, "Soft limit", settings.soft_limit)
    ImGui.Separator(ctx)
    ImGui.TextWrapped(ctx, "This is a scene-interpolation / perspective traversal renderer. It does not claim literal physical 6DoF translation inside a single HOA recording; it navigates between selected soundfield nodes.")
    ImGui.EndChild(ctx)
    end
    if ImGui.Button(ctx, "Render", 110, 30) then render() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 110, 30) then open = false end
    ImGui.End(ctx)
  end
  persist()
  if open then reaper.defer(loop) end
end

ctx = ImGui.CreateContext(TITLE)
reaper.defer(loop)
