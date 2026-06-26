-- @description 17ch Cube XYZ Panner
-- @author s3g
-- @version 0.4
-- @requires ReaImGui; JSFX: s3g 17ch Cube XYZ Panner
-- @category Spatial / HOA
-- @method Auto-loads the JSFX on the selected track and pans up to 8 mono source channels across a 17-speaker cube layout using 3D DBAP-style Cartesian amplitude panning.
-- @about
--   ReaImGui companion controller for JS: s3g 17ch Cube XYZ Panner.
--   Automatically loads or repairs the JSFX on the selected track. The track
--   carries 8 source channels into the panner and the JSFX distributes them
--   across the 17-channel cube output. Source positions are stored as XYZ
--   parameters; AED controls are provided as a mirrored editing view. The
--   panning model is 3D DBAP-style Cartesian amplitude panning with a compact
--   spread radius, so focused settings can isolate a source to one speaker.
--   The cube edge is +/-1; source controls extend to +/-2 for outside-cube
--   distance effects. Global offsets extend to +/-4, while the final source
--   position after source + global offset is hard-clamped to +/-2.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "17ch Cube XYZ Panner", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local ctx = ImGui.CreateContext("17ch Cube XYZ Panner")
local open = true
local PROJECT = 0
local FX_NAME = "s3g 17ch Cube XYZ Panner"
local FX_NAME_CLEAN = "17ch Cube XYZ Panner"
local FX_NAME_LEGACY = "s3g/17ch Cube XYZ Panner"
local selected_source = 1
local view_yaw_deg = -35
local view_pitch_deg = -42
local view_roll_deg = 0
local view_zoom = 0.72
local dragging_source = 0
local load_error = ""
local auto_load_attempted_guid = ""
local CUBE_EDGE_RADIUS = 1.55
local SOURCE_LIMIT = 2
local GLOBAL_OFFSET_LIMIT = 4

local speakers = {
  { id = 1, az = 45, el = -35.2644, r = 2.68468 },
  { id = 2, az = 135, el = -35.2644, r = 2.68468 },
  { id = 3, az = -135, el = -35.2644, r = 2.68468 },
  { id = 4, az = -45, el = -35.2644, r = 2.68468 },
  { id = 5, az = 45, el = 0, r = 2.19203 },
  { id = 6, az = 90, el = 0, r = 1.55 },
  { id = 7, az = 135, el = 0, r = 2.19203 },
  { id = 8, az = 180, el = 0, r = 1.55 },
  { id = 9, az = -135, el = 0, r = 2.19203 },
  { id = 10, az = -90, el = 0, r = 1.55 },
  { id = 11, az = -45, el = 0, r = 2.19203 },
  { id = 12, az = 0, el = 0, r = 1.55 },
  { id = 13, az = 45, el = 35.2644, r = 2.68468 },
  { id = 14, az = 135, el = 35.2644, r = 2.68468 },
  { id = 15, az = -135, el = 35.2644, r = 2.68468 },
  { id = 16, az = -45, el = 35.2644, r = 2.68468 },
  { id = 17, az = 0, el = 90, r = 1.55 },
}

local source_colors = {
  { 0.98, 0.36, 0.28 }, { 0.98, 0.58, 0.18 }, { 0.90, 0.74, 0.18 }, { 0.45, 0.78, 0.22 },
  { 0.18, 0.70, 0.47 }, { 0.12, 0.70, 0.74 }, { 0.18, 0.52, 0.95 }, { 0.55, 0.42, 0.95 },
}

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local COLORS = {
  bg = color(0.035, 0.04, 0.045, 1),
  shell = color(0.22, 0.23, 0.24, 0.32),
  shell_line = color(0.62, 0.65, 0.68, 0.30),
  facet = color(0.46, 0.48, 0.50, 0.11),
  facet_line = color(0.66, 0.68, 0.70, 0.24),
  speaker = color(0.74, 0.78, 0.82, 0.95),
  speaker_back = color(0.28, 0.30, 0.32, 0.38),
  text = color(0.82, 0.88, 0.9, 1),
  muted = color(0.5, 0.58, 0.6, 1),
  selected = color(1.0, 0.95, 0.5, 1),
}

local PARAM = {
  spread = 0,
  focus = 1,
  smoothing = 2,
  global_x = 3,
  global_y = 4,
  global_z = 5,
  out_gain = 6,
}

local function source_param(source_index, offset)
  return 9 + ((source_index - 1) * 3) + offset
end

local function source_control_param(source_index, offset)
  return 33 + ((source_index - 1) * 3) + offset
end

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function find_fx(track)
  if not track then return -1 end
  for fx = 0, reaper.TrackFX_GetCount(track) - 1 do
    local ok, name = reaper.TrackFX_GetFXName(track, fx, "")
    if ok and (name:find(FX_NAME, 1, true) or name:find(FX_NAME_CLEAN, 1, true) or name:find(FX_NAME_LEGACY, 1, true)) then
      return fx
    end
  end
  return -1
end

local function get_param(track, fx, param, fallback)
  if not track or fx < 0 then return fallback end
  local value = reaper.TrackFX_GetParam(track, fx, param)
  return value == nil and fallback or value
end

local function set_param(track, fx, param, value)
  if track and fx >= 0 then
    reaper.TrackFX_SetParam(track, fx, param, value)
  end
end

local function slider_double(track, fx, label, param, lo, hi, fmt)
  local value = get_param(track, fx, param, lo)
  local changed, new_value = ImGui.SliderDouble(ctx, label, value, lo, hi, fmt or "%.2f")
  if changed then set_param(track, fx, param, new_value) end
  return new_value
end

local function slider_value(label, value, lo, hi, fmt)
  return ImGui.SliderDouble(ctx, label, value, lo, hi, fmt or "%.2f")
end

local function toggle_param(track, fx, label, param)
  local value = get_param(track, fx, param, 0)
  local enabled = value >= 0.5
  local visible, id = label:match("^(.-)(##.*)$")
  visible = visible or label
  id = id or ""
  local text = visible .. (enabled and ": on" or ": off") .. id
  if ImGui.Button(ctx, text) then
    set_param(track, fx, param, enabled and 0 or 1)
    enabled = not enabled
  end
  return enabled
end

local function maybe_load(track, force)
  if not track then return -1 end
  reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", 18)
  local fx = find_fx(track)
  local guid = reaper.GetTrackGUID(track)
  if fx < 0 and not force and auto_load_attempted_guid == guid then return -1 end
  if fx < 0 then
    auto_load_attempted_guid = guid
    fx = reaper.TrackFX_AddByName(track, "JS: " .. FX_NAME, false, -1)
    if fx < 0 then fx = reaper.TrackFX_AddByName(track, FX_NAME, false, -1) end
    if fx < 0 then fx = reaper.TrackFX_AddByName(track, "JS: " .. FX_NAME_CLEAN, false, -1) end
    if fx < 0 then fx = reaper.TrackFX_AddByName(track, FX_NAME_CLEAN, false, -1) end
    if fx < 0 then fx = reaper.TrackFX_AddByName(track, "JS: " .. FX_NAME_LEGACY, false, -1) end
    if fx < 0 then fx = reaper.TrackFX_AddByName(track, FX_NAME_LEGACY, false, -1) end
  end
  if fx < 0 then
    load_error = "Could not load JS: " .. FX_NAME
  else
    load_error = ""
  end
  return fx
end

local function point_from_az_el(az, el)
  local azr = math.rad(az)
  local elr = math.rad(el)
  return {
    x = math.sin(azr) * math.cos(elr),
    y = math.cos(azr) * math.cos(elr),
    z = math.sin(elr),
  }
end

local function aed_to_xyz(az, el, distance)
  local p = point_from_az_el(az, el)
  return p.x * distance, p.y * distance, p.z * distance
end

local function xyz_to_aed(x, y, z)
  local distance = math.sqrt(x * x + y * y + z * z)
  if distance < 0.000001 then
    return 0, 0, 0.1
  end
  local az = math.deg(math.atan(x, y))
  local horizontal = math.sqrt(x * x + y * y)
  local el = math.deg(math.atan(z, horizontal))
  return az, el, clamp(distance, 0.1, 3)
end

local function source_default_xyz(source_index)
  local corners = {
    { 1, 1, -1 },
    { 1, -1, -1 },
    { -1, -1, -1 },
    { -1, 1, -1 },
    { 1, 1, 1 },
    { 1, -1, 1 },
    { -1, -1, 1 },
    { -1, 1, 1 },
  }
  local corner = corners[source_index] or corners[1]
  return corner[1], corner[2], corner[3]
end

local function rotate_point(p)
  local yaw = math.rad(view_yaw_deg)
  local pitch = math.rad(view_pitch_deg)
  local roll = math.rad(view_roll_deg)
  local cy = math.cos(yaw)
  local sy = math.sin(yaw)
  local cp = math.cos(pitch)
  local sp = math.sin(pitch)
  local cr = math.cos(roll)
  local sr = math.sin(roll)

  local x1 = p.x * cy - p.y * sy
  local y1 = p.x * sy + p.y * cy
  local z1 = p.z

  local x2 = x1
  local y2 = y1 * cp - z1 * sp
  local z2 = y1 * sp + z1 * cp

  return {
    x = x2 * cr - y2 * sr,
    y = x2 * sr + y2 * cr,
    z = z2,
  }
end

local function source_dot_size(distance)
  local d = math.max(0.1, distance)
  if d < 1 then return 3.2 + d * 4.8 end
  return math.max(3.6, 8 / math.sqrt(d))
end

local projected_point

local function source_aed_from_screen(mx, my, cx, cy, radius)
  local best_az = 0
  local best_el = 0
  local best_x = cx
  local best_y = cy
  local best_distance_sq = math.huge

  local function test_candidate(az, el)
    local p = projected_point(az, el, 1, cx, cy, radius)
    local dx = mx - p.x
    local dy = my - p.y
    local distance_sq = dx * dx + dy * dy
    if distance_sq < best_distance_sq then
      best_distance_sq = distance_sq
      best_az = az
      best_el = el
      best_x = p.x
      best_y = p.y
    end
  end

  for el = -90, 90, 5 do
    for az = -180, 175, 5 do
      test_candidate(az, el)
    end
  end

  local coarse_az = best_az
  local coarse_el = best_el
  for el = math.max(-90, coarse_el - 6), math.min(90, coarse_el + 6), 1 do
    for az = coarse_az - 6, coarse_az + 6, 1 do
      test_candidate(az, el)
    end
  end

  local shell_dx = best_x - cx
  local shell_dy = best_y - cy
  local mouse_dx = mx - cx
  local mouse_dy = my - cy
  local shell_len = math.sqrt(shell_dx * shell_dx + shell_dy * shell_dy)
  local mouse_len = math.sqrt(mouse_dx * mouse_dx + mouse_dy * mouse_dy)
  local projected_distance = shell_len > 0.000001 and mouse_len / shell_len or 1
  if math.abs(projected_distance - 1) < 0.055 then projected_distance = 1 end
  local distance = clamp(projected_distance, 0.1, 3)
  return best_az, best_el, distance
end

function projected_point(az, el, distance, cx, cy, radius)
  local p = point_from_az_el(az, el)
  local scale = distance or 1
  p.x = p.x * scale
  p.y = p.y * scale
  p.z = p.z * scale
  local r = rotate_point(p)
  return {
    x = cx + r.x * radius * view_zoom,
    y = cy - r.y * radius * view_zoom,
    z = r.z,
  }
end

local function projected_xyz(x, y, z, cx, cy, radius)
  local r = rotate_point({ x = x, y = y, z = z })
  return {
    x = cx + r.x * radius * view_zoom,
    y = cy - r.y * radius * view_zoom,
    z = r.z,
  }
end

local function speaker_projected_point(speaker, cx, cy, radius)
  local p = point_from_az_el(speaker.az, speaker.el)
  local scale = (speaker.r or CUBE_EDGE_RADIUS) / CUBE_EDGE_RADIUS
  p.x = p.x * scale
  p.y = p.y * scale
  p.z = p.z * scale
  local r = rotate_point(p)
  return {
    x = cx + r.x * radius * view_zoom,
    y = cy - r.y * radius * view_zoom,
    z = r.z,
  }
end

local function source_color(index, alpha)
  local c = source_colors[index]
  return color(c[1], c[2], c[3], alpha or 1)
end

local function draw_quad_filled(draw_list, a, b, c, d, col)
  local can_draw_filled_triangles, draw_triangle_filled = pcall(function()
    return ImGui.DrawList_AddTriangleFilled
  end)
  if can_draw_filled_triangles and draw_triangle_filled and a and b and c and d then
    draw_triangle_filled(draw_list, a.x, a.y, b.x, b.y, c.x, c.y, col)
    draw_triangle_filled(draw_list, a.x, a.y, c.x, c.y, d.x, d.y, col)
  end
end

local function draw_edge(draw_list, by_id, a_id, b_id, thickness)
  local a = by_id[a_id]
  local b = by_id[b_id]
  if a and b then
    local front = clamp(((a.z + b.z) * 0.5 + 1) * 0.5, 0, 1)
    ImGui.DrawList_AddLine(
      draw_list,
      a.x, a.y,
      b.x, b.y,
      color(0.66, 0.68, 0.70, 0.12 + 0.22 * front),
      thickness or 1.25
    )
  end
end

local function draw_cube_surface(draw_list, by_id)
  local faces = {
    { 1, 2, 3, 4 },
    { 13, 14, 15, 16 },
    { 1, 2, 14, 13 },
    { 2, 3, 15, 14 },
    { 3, 4, 16, 15 },
    { 4, 1, 13, 16 },
  }

  for _, face in ipairs(faces) do
    local a, b, c, d = by_id[face[1]], by_id[face[2]], by_id[face[3]], by_id[face[4]]
    if a and b and c and d then
      local front = clamp(((a.z + b.z + c.z + d.z) * 0.25 + 1) * 0.5, 0, 1)
      draw_quad_filled(draw_list, a, b, c, d, color(0.42, 0.45, 0.48, 0.025 + 0.055 * front))
    end
  end

  local edges = {
    { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 },
    { 13, 14 }, { 14, 15 }, { 15, 16 }, { 16, 13 },
    { 1, 13 }, { 2, 14 }, { 3, 15 }, { 4, 16 },
    { 13, 17 }, { 14, 17 }, { 15, 17 }, { 16, 17 },
  }

  for _, edge in ipairs(edges) do
    draw_edge(draw_list, by_id, edge[1], edge[2], 1.4)
  end

  local middle_tier_edges = {
    { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 9 },
    { 9, 10 }, { 10, 11 }, { 11, 12 }, { 12, 5 },
  }

  for _, edge in ipairs(middle_tier_edges) do
    draw_edge(draw_list, by_id, edge[1], edge[2], 2.1)
  end
end

local function hit_test_source(sources, mx, my)
  local best_source = 0
  local best_distance = math.huge
  for _, source in ipairs(sources) do
    local dx = mx - source.x
    local dy = my - source.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local hit_radius = source.size + 10
    if distance <= hit_radius and distance < best_distance then
      best_source = source.id
      best_distance = distance
    end
  end
  return best_source
end

local function update_source_from_mouse(track, fx, source_index, mx, my, cx, cy, radius, global_x, global_y, global_z)
  if source_index < 1 or source_index > 8 then return end
  local az, el, distance = source_aed_from_screen(mx, my, cx, cy, radius)
  local x, y, z = aed_to_xyz(az, el, distance)
  set_param(track, fx, source_param(source_index, 0), clamp(x - global_x, -SOURCE_LIMIT, SOURCE_LIMIT))
  set_param(track, fx, source_param(source_index, 1), clamp(y - global_y, -SOURCE_LIMIT, SOURCE_LIMIT))
  set_param(track, fx, source_param(source_index, 2), clamp(z - global_z, -SOURCE_LIMIT, SOURCE_LIMIT))
end

local function reset_source_positions(track, fx)
  for source = 1, 8 do
    local x, y, z = source_default_xyz(source)
    set_param(track, fx, source_param(source, 0), x)
    set_param(track, fx, source_param(source, 1), y)
    set_param(track, fx, source_param(source, 2), z)
  end
  set_param(track, fx, PARAM.global_x, 0)
  set_param(track, fx, PARAM.global_y, 0)
  set_param(track, fx, PARAM.global_z, 0)
end

local function clear_mutes(track, fx)
  for source = 1, 8 do
    set_param(track, fx, source_control_param(source, 1), 0)
  end
end

local function clear_solos(track, fx)
  for source = 1, 8 do
    set_param(track, fx, source_control_param(source, 2), 0)
  end
end

local function nudge_camera(label, width, height, apply)
  if ImGui.Button(ctx, label, width, height) or ImGui.IsItemActive(ctx) then
    apply()
  end
end

local function reset_camera(yaw, pitch)
  view_yaw_deg = yaw
  view_pitch_deg = pitch
  view_roll_deg = 0
  view_zoom = 0.72
end

local function draw_camera_controls()
  ImGui.BeginGroup(ctx)
  ImGui.Text(ctx, "Camera")
  nudge_camera("up##cam", 68, 24, function()
    view_pitch_deg = clamp(view_pitch_deg + 4, -180, 180)
  end)
  nudge_camera("left##cam", 32, 24, function()
    view_yaw_deg = view_yaw_deg - 4
  end)
  ImGui.SameLine(ctx)
  nudge_camera("right##cam", 32, 24, function()
    view_yaw_deg = view_yaw_deg + 4
  end)
  nudge_camera("down##cam", 68, 24, function()
    view_pitch_deg = clamp(view_pitch_deg - 4, -180, 180)
  end)
  nudge_camera("-##camzoom", 32, 24, function()
    view_zoom = clamp(view_zoom - 0.025, 0.35, 2.5)
  end)
  ImGui.SameLine(ctx)
  nudge_camera("+##camzoom", 32, 24, function()
    view_zoom = clamp(view_zoom + 0.025, 0.35, 2.5)
  end)
  if ImGui.Button(ctx, "3/4##cam", 68, 24) then
    reset_camera(-35, -42)
  end
  if ImGui.Button(ctx, "top##cam", 68, 24) then
    reset_camera(0, 0)
  end
  if ImGui.Button(ctx, "front##cam", 68, 24) then
    reset_camera(0, -90)
  end
  ImGui.EndGroup(ctx)
end

local function draw_cube(track, fx)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local width = ImGui.GetContentRegionAvail(ctx)
  local control_width = 82
  local control_gap = 10
  local controls_inline = width >= 430
  local canvas_width = controls_inline and math.max(320, width - control_width - control_gap) or width
  local height = 430
  local cx = x0 + canvas_width * 0.5
  local cy = y0 + height * 0.56
  local radius = math.min(canvas_width, height) * 0.36
  ImGui.InvisibleButton(ctx, "cube_canvas", canvas_width, height)
  local canvas_hovered = ImGui.IsItemHovered(ctx)
  local canvas_active = ImGui.IsItemActive(ctx)

  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x0 + canvas_width, y0 + height, COLORS.bg)

  local projected = {}
  local projected_by_id = {}
  for _, speaker in ipairs(speakers) do
    local p = speaker_projected_point(speaker, cx, cy, radius)
    local item = {
      id = speaker.id,
      x = p.x,
      y = p.y,
      z = p.z,
      az = speaker.az,
      el = speaker.el,
    }
    projected[#projected + 1] = item
    projected_by_id[speaker.id] = item
  end
  table.sort(projected, function(a, b) return a.z < b.z end)

  draw_cube_surface(draw_list, projected_by_id)

  for _, speaker in ipairs(projected) do
    local front = clamp((speaker.z + 1) * 0.5, 0, 1)
    local size = 2.5 + 2 * front
    ImGui.DrawList_AddCircleFilled(draw_list, speaker.x, speaker.y, size + 2, COLORS.speaker_back, 18)
    ImGui.DrawList_AddCircleFilled(draw_list, speaker.x, speaker.y, size, COLORS.speaker, 18)
    ImGui.DrawList_AddText(draw_list, speaker.x + size + 3, speaker.y - 6, color(0.82, 0.88, 0.9, 0.48 + 0.36 * front), tostring(speaker.id))
  end

  local global_x = get_param(track, fx, PARAM.global_x, 0)
  local global_y = get_param(track, fx, PARAM.global_y, 0)
  local global_z = get_param(track, fx, PARAM.global_z, 0)
  local solo_count = 0
  for source = 1, 8 do
    if get_param(track, fx, source_control_param(source, 2), 0) >= 0.5 then
      solo_count = solo_count + 1
    end
  end

  local sources = {}
  for source = 1, 8 do
    local default_x, default_y, default_z = source_default_xyz(source)
    local x = clamp(get_param(track, fx, source_param(source, 0), default_x) + global_x, -SOURCE_LIMIT, SOURCE_LIMIT)
    local y = clamp(get_param(track, fx, source_param(source, 1), default_y) + global_y, -SOURCE_LIMIT, SOURCE_LIMIT)
    local z = clamp(get_param(track, fx, source_param(source, 2), default_z) + global_z, -SOURCE_LIMIT, SOURCE_LIMIT)
    local dist = clamp(math.sqrt(x * x + y * y + z * z), 0.1, 3.464)
    local mute = get_param(track, fx, source_control_param(source, 1), 0) >= 0.5
    local solo = get_param(track, fx, source_control_param(source, 2), 0) >= 0.5
    local gain_db = get_param(track, fx, source_control_param(source, 0), 0)
    local p = projected_xyz(x, y, z, cx, cy, radius)
    p.id = source
    p.distance = dist
    p.gain_db = gain_db
    p.mute = mute
    p.solo = solo
    p.audible = not mute and (solo_count == 0 or solo)
    p.size = source_dot_size(dist) + 2 * clamp((p.z + 1) * 0.5, 0, 1)
    sources[#sources + 1] = p
  end
  table.sort(sources, function(a, b) return a.z < b.z end)

  if canvas_hovered or canvas_active or dragging_source > 0 then
    local mx, my = ImGui.GetMousePos(ctx)
    if canvas_hovered and ImGui.IsMouseClicked(ctx, 0) then
      local hit = hit_test_source(sources, mx, my)
      if hit > 0 then
        selected_source = hit
        dragging_source = hit
      end
    end

    if dragging_source > 0 and ImGui.IsMouseDown(ctx, 0) then
      update_source_from_mouse(track, fx, dragging_source, mx, my, cx, cy, radius, global_x, global_y, global_z)
    end

    if ImGui.IsMouseReleased(ctx, 0) then
      dragging_source = 0
    end
  end

  for _, source in ipairs(sources) do
    local front = clamp((source.z + 1) * 0.5, 0, 1)
    local size = source_dot_size(source.distance) + 2 * front
    local outline = source.id == selected_source and COLORS.selected or source_color(source.id, 0.35)
    local alpha = source.audible and 0.92 or 0.22
    local halo_alpha = source.audible and 0.22 or 0.08
    ImGui.DrawList_AddCircleFilled(draw_list, source.x, source.y, size + 7, source_color(source.id, halo_alpha), 32)
    ImGui.DrawList_AddCircleFilled(draw_list, source.x, source.y, size, source_color(source.id, alpha), 32)
    ImGui.DrawList_AddCircle(draw_list, source.x, source.y, size + 3, source.solo and COLORS.selected or outline, 32, source.id == selected_source and 3 or 1.5)
    ImGui.DrawList_AddText(draw_list, source.x - 4, source.y - 8, color(0.04, 0.045, 0.05, 1), tostring(source.id))
  end

  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 14, COLORS.text, "17ch Cube XYZ Panner")
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 34, COLORS.muted, "17 speakers / 8 mono sources / distance 1.0 = cube edge")
  ImGui.DrawList_AddText(draw_list, x0 + canvas_width - 300, y0 + 14, COLORS.muted, "drag source dots to edit position")
  if controls_inline then
    ImGui.SameLine(ctx)
    ImGui.Dummy(ctx, control_gap, 1)
    ImGui.SameLine(ctx)
  end
  draw_camera_controls()
end

local function draw_source_controls(track, fx)
  local changed
  changed, selected_source = ImGui.SliderInt(ctx, "Selected source", selected_source, 1, 8)
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Reset positions") then reset_source_positions(track, fx) end
  local base_label = "S" .. tostring(selected_source)
  local x_param = source_param(selected_source, 0)
  local y_param = source_param(selected_source, 1)
  local z_param = source_param(selected_source, 2)
  local default_x, default_y, default_z = source_default_xyz(selected_source)
  local x = slider_double(track, fx, base_label .. " X", x_param, -SOURCE_LIMIT, SOURCE_LIMIT, "%.2f")
  local y = slider_double(track, fx, base_label .. " Y", y_param, -SOURCE_LIMIT, SOURCE_LIMIT, "%.2f")
  local z = slider_double(track, fx, base_label .. " Z", z_param, -SOURCE_LIMIT, SOURCE_LIMIT, "%.2f")
  if x == nil then x = default_x end
  if y == nil then y = default_y end
  if z == nil then z = default_z end

  local az, el, dist = xyz_to_aed(x, y, z)
  local az_changed, new_az = slider_value(base_label .. " azimuth (deg)##aed", az, -360, 360, "%.1f")
  local el_changed, new_el = slider_value(base_label .. " elevation (deg)##aed", el, -90, 90, "%.1f")
  local dist_changed, new_dist = slider_value(base_label .. " distance (cube radius, edge=1)##aed", dist, 0.1, 3.464, "%.2f")
  if az_changed or el_changed or dist_changed then
    local new_x, new_y, new_z = aed_to_xyz(new_az, new_el, new_dist)
    set_param(track, fx, x_param, clamp(new_x, -SOURCE_LIMIT, SOURCE_LIMIT))
    set_param(track, fx, y_param, clamp(new_y, -SOURCE_LIMIT, SOURCE_LIMIT))
    set_param(track, fx, z_param, clamp(new_z, -SOURCE_LIMIT, SOURCE_LIMIT))
  end

  slider_double(track, fx, base_label .. " gain (dB)", source_control_param(selected_source, 0), -60, 24, "%.1f")
  toggle_param(track, fx, "Mute " .. base_label, source_control_param(selected_source, 1))
  ImGui.SameLine(ctx)
  toggle_param(track, fx, "Solo " .. base_label, source_control_param(selected_source, 2))
end

local function draw_source_mixer(track, fx)
  if ImGui.Button(ctx, "Clear mutes") then clear_mutes(track, fx) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Clear solos") then clear_solos(track, fx) end

  for source = 1, 8 do
    local label = "S" .. tostring(source)
    if ImGui.Button(ctx, label .. "##select" .. tostring(source)) then
      selected_source = source
    end
    ImGui.SameLine(ctx)
    toggle_param(track, fx, "M##mix" .. tostring(source), source_control_param(source, 1))
    ImGui.SameLine(ctx)
    toggle_param(track, fx, "S##mix" .. tostring(source), source_control_param(source, 2))
    ImGui.SameLine(ctx)
    slider_double(track, fx, "Gain##mix" .. tostring(source), source_control_param(source, 0), -60, 24, "%.1f dB")
  end
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 820, 760, ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, "17ch Cube XYZ Panner", open)
  if visible then
    local track = reaper.GetSelectedTrack(PROJECT, 0)
    local fx = find_fx(track)

    if not track then
      ImGui.Text(ctx, "Select the target track.")
    else
      local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
      ImGui.Text(ctx, "Selected track: " .. (name ~= "" and name or "(unnamed)"))
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Repair JSFX") then fx = maybe_load(track, true) end

      if fx < 0 then
        fx = maybe_load(track, false)
      end

      if fx < 0 then
        ImGui.Text(ctx, load_error ~= "" and load_error or ("JS: " .. FX_NAME .. " is not on the selected track."))
      else
        draw_cube(track, fx)

        if ImGui.CollapsingHeader(ctx, "Global", nil, ImGui.TreeNodeFlags_DefaultOpen) then
          slider_double(track, fx, "XYZ spread radius", PARAM.spread, 0.05, 4, "%.2f")
          slider_double(track, fx, "Focus amount", PARAM.focus, 0, 1, "%.2f")
          slider_double(track, fx, "Motion smoothing", PARAM.smoothing, 1, 250, "%.0f ms")
          slider_double(track, fx, "Global X offset", PARAM.global_x, -GLOBAL_OFFSET_LIMIT, GLOBAL_OFFSET_LIMIT, "%.2f")
          slider_double(track, fx, "Global Y offset", PARAM.global_y, -GLOBAL_OFFSET_LIMIT, GLOBAL_OFFSET_LIMIT, "%.2f")
          slider_double(track, fx, "Global Z offset", PARAM.global_z, -GLOBAL_OFFSET_LIMIT, GLOBAL_OFFSET_LIMIT, "%.2f")
          slider_double(track, fx, "Output gain", PARAM.out_gain, -48, 24, "%.1f dB")
        end

        if ImGui.CollapsingHeader(ctx, "Selected Source", nil, ImGui.TreeNodeFlags_DefaultOpen) then
          draw_source_controls(track, fx)
        end

        if ImGui.CollapsingHeader(ctx, "Source Mixer", nil, ImGui.TreeNodeFlags_DefaultOpen) then
          draw_source_mixer(track, fx)
        end

        if ImGui.CollapsingHeader(ctx, "View") then
          if ImGui.Button(ctx, "3/4 view") then
            reset_camera(-35, -42)
          end
          ImGui.SameLine(ctx)
          if ImGui.Button(ctx, "Top") then
            reset_camera(0, 0)
          end
          ImGui.SameLine(ctx)
          if ImGui.Button(ctx, "Front") then
            reset_camera(0, -90)
          end
          local changed
          changed, view_yaw_deg = ImGui.SliderDouble(ctx, "Yaw", view_yaw_deg, -180, 180, "%.0f deg")
          changed, view_pitch_deg = ImGui.SliderDouble(ctx, "Pitch", view_pitch_deg, -180, 180, "%.0f deg")
          changed, view_roll_deg = ImGui.SliderDouble(ctx, "Roll", view_roll_deg, -180, 180, "%.0f deg")
          changed, view_zoom = ImGui.SliderDouble(ctx, "Zoom", view_zoom, 0.35, 2.5, "%.2f")
        end
      end
    end

    ImGui.End(ctx)
  end

  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)
