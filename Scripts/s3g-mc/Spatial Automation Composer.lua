-- @description Spatial Automation Composer
-- @author s3g
-- @version 0.2
-- @requires ReaImGui
-- @category Spatial Panners
-- @method Offline spatial choreography writer for s3g panners. Detects AED or XYZ source parameters on the selected track, previews path, graph, and topology-informed motion with source relationship modes, then commits automation points over the time selection or selected item range.
-- @about
--   Writes panner automation as an editable Reaper score rather than running
--   choreography in realtime. First pass supports 8-source s3g AED and XYZ
--   panners with path, graph, topology, and source-relationship modes.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Spatial Automation Composer", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local PROJECT = 0
local NUM_SOURCES = 8
local ctx = ImGui.CreateContext("Spatial Automation Composer")
local open = true
local last_status = ""
local view_yaw_deg = -35
local view_pitch_deg = -42
local view_zoom = 1.0
local preview_t = 0.0
local preview_play = false
local preview_speed = 1.0
local last_frame_time = reaper.time_precise()

local ALGORITHMS = { "Orbit", "Arc", "Spiral", "Lissajous", "Brownian", "Graph walk", "Hole field", "Attractor", "Boundary trace", "Scatter holds" }
local TARGET_MODES = { "Selected source", "Unison all", "Phase offset", "Canon", "Counter-rotation", "Scatter" }
local TIME_MODES = { "Time selection", "Selected item", "Edit cursor + duration" }

local settings = {
  algorithm = 1,
  target_mode = 2,
  selected_source = 1,
  time_mode = 1,
  duration = 12,
  point_rate = 8,
  cycles = 1,
  phase_spread = 1,
  canon_delay = 0.12,
  az_center = 0,
  az_width = 180,
  el_center = 25,
  el_width = 50,
  dist_center = 1,
  dist_width = 0.45,
  xyz_radius = 1.25,
  continuity = 0.72,
  tear = 0.0,
  boundary_push = 0.25,
  hole_radius = 0.28,
  graph_nodes = 6,
  graph_memory = 0.45,
  seed = 4321,
  clear_existing = true,
}

local COLORS = {
  bg = ImGui.ColorConvertDouble4ToU32(0.035, 0.04, 0.045, 1),
  panel = ImGui.ColorConvertDouble4ToU32(0.075, 0.082, 0.088, 1),
  edge = ImGui.ColorConvertDouble4ToU32(0.29, 0.31, 0.33, 1),
  text = ImGui.ColorConvertDouble4ToU32(0.82, 0.88, 0.9, 1),
  muted = ImGui.ColorConvertDouble4ToU32(0.50, 0.58, 0.60, 1),
  active = ImGui.ColorConvertDouble4ToU32(0.16, 0.63, 0.38, 1),
  warn = ImGui.ColorConvertDouble4ToU32(0.95, 0.46, 0.34, 1),
}

local source_colors = {
  { 0.98, 0.36, 0.28 }, { 0.98, 0.58, 0.18 }, { 0.90, 0.74, 0.18 }, { 0.45, 0.78, 0.22 },
  { 0.18, 0.70, 0.47 }, { 0.12, 0.70, 0.74 }, { 0.18, 0.52, 0.95 }, { 0.55, 0.42, 0.95 },
}

local PANNERS = {
  { match = "17ch Cube XYZ Panner", coord = "XYZ", x = 9, y = 10, z = 11, min = -2, max = 2, label = "17ch Cube XYZ Panner" },
  { match = "Layout Panner", coord = "AED", az = 9, el = 10, dist = 11, el_min = -90, el_max = 90, dist_min = 0.1, dist_max = 3, label = "Layout Panner" },
  { match = "12ch Dodeca Panner", coord = "AED", az = 9, el = 10, dist = 11, el_min = -90, el_max = 90, dist_min = 0.1, dist_max = 3, label = "12ch Dodeca Panner" },
  { match = "25ch Region Dome Panner", coord = "AED", az = 9, el = 10, dist = 11, el_min = 0, el_max = 90, dist_min = 0.1, dist_max = 3, label = "25ch Region Dome Panner" },
  { match = "25ch Vector Morph Dome Panner", coord = "AED", az = 9, el = 10, dist = 11, el_min = 0, el_max = 90, dist_min = 0.1, dist_max = 3, label = "25ch Vector Morph Dome Panner" },
  { match = "25ch LBAP Dome Panner", coord = "AED", az = 9, el = 10, dist = 11, el_min = 0, el_max = 90, dist_min = 0.1, dist_max = 3, label = "25ch LBAP Dome Panner" },
  { match = "25ch VBAP Dome Panner", coord = "AED", az = 9, el = 10, dist = 11, el_min = 0, el_max = 90, dist_min = 0.1, dist_max = 3, label = "25ch VBAP Dome Panner" },
  { match = "25ch DBAP Dome Panner", coord = "AED", az = 9, el = 10, dist = 11, el_min = 0, el_max = 90, dist_min = 0.1, dist_max = 3, label = "25ch DBAP Dome Panner" },
  { match = "25ch Cosine Dome Panner", coord = "AED", az = 9, el = 10, dist = 11, el_min = 0, el_max = 90, dist_min = 0.1, dist_max = 3, label = "25ch Cosine Dome Panner" },
}

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local function source_color(index, alpha)
  local c = source_colors[((index - 1) % #source_colors) + 1]
  return color(c[1], c[2], c[3], alpha or 1)
end

local function clamp(value, lo, hi)
  value = value == nil and lo or value
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function wrap_degrees(deg)
  local wrapped = deg - math.floor(deg / 360) * 360
  if wrapped > 180 then wrapped = wrapped - 360 end
  return wrapped
end

local function rotate_preview_point(p)
  local yaw = math.rad(view_yaw_deg)
  local pitch = math.rad(view_pitch_deg)
  local cy, sy = math.cos(yaw), math.sin(yaw)
  local cp, sp = math.cos(pitch), math.sin(pitch)
  local x1 = p.x * cy - p.y * sy
  local y1 = p.x * sy + p.y * cy
  local z1 = p.z
  return {
    x = x1,
    y = y1 * cp - z1 * sp,
    z = y1 * sp + z1 * cp,
  }
end

local function reset_camera(yaw, pitch)
  view_yaw_deg = yaw
  view_pitch_deg = pitch
  view_zoom = 1.0
end

local function nudge_camera(label, width, height, apply)
  if ImGui.Button(ctx, label, width, height) or ImGui.IsItemActive(ctx) then apply() end
end

local function draw_preview_camera_controls()
  ImGui.BeginGroup(ctx)
  ImGui.Text(ctx, "Camera")
  nudge_camera("up##motioncam", 68, 24, function() view_pitch_deg = clamp(view_pitch_deg + 4, -180, 180) end)
  nudge_camera("left##motioncam", 32, 24, function() view_yaw_deg = view_yaw_deg - 4 end)
  ImGui.SameLine(ctx)
  nudge_camera("right##motioncam", 32, 24, function() view_yaw_deg = view_yaw_deg + 4 end)
  nudge_camera("down##motioncam", 68, 24, function() view_pitch_deg = clamp(view_pitch_deg - 4, -180, 180) end)
  nudge_camera("-##motioncamzoom", 32, 24, function() view_zoom = clamp(view_zoom - 0.025, 0.45, 2.5) end)
  ImGui.SameLine(ctx)
  nudge_camera("+##motioncamzoom", 32, 24, function() view_zoom = clamp(view_zoom + 0.025, 0.45, 2.5) end)
  if ImGui.Button(ctx, "3/4##motioncam", 68, 24) then reset_camera(-35, -42) end
  if ImGui.Button(ctx, "top##motioncam", 68, 24) then reset_camera(0, 0) end
  if ImGui.Button(ctx, "front##motioncam", 68, 24) then reset_camera(0, -90) end
  ImGui.EndGroup(ctx)
end

local function detect_panner(track)
  if not track then return nil, -1 end
  for fx = 0, reaper.TrackFX_GetCount(track) - 1 do
    local ok, name = reaper.TrackFX_GetFXName(track, fx, "")
    if ok then
      for _, spec in ipairs(PANNERS) do
        if name:find(spec.match, 1, true) then return spec, fx end
      end
    end
  end
  return nil, -1
end

local function target_sources()
  if settings.target_mode == 1 then return { settings.selected_source } end
  local sources = {}
  for source = 1, NUM_SOURCES do sources[#sources + 1] = source end
  return sources
end

local function source_count_active()
  return settings.target_mode == 1 and 1 or NUM_SOURCES
end

local function time_range()
  if settings.time_mode == 1 then
    local start_pos, end_pos = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if end_pos > start_pos then return start_pos, end_pos end
  elseif settings.time_mode == 2 then
    local item = reaper.GetSelectedMediaItem(PROJECT, 0)
    if item then
      local start_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      return start_pos, start_pos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    end
  end
  local start_pos = reaper.GetCursorPosition()
  return start_pos, start_pos + math.max(0.1, settings.duration)
end

local function hash_noise(n)
  local x = math.sin(n * 12.9898 + settings.seed * 78.233) * 43758.5453
  return x - math.floor(x)
end

local function source_phase(source)
  if settings.target_mode == 1 or settings.target_mode == 2 then return 0 end
  if settings.target_mode == 5 then
    return (source % 2 == 0 and math.pi or 0) * settings.phase_spread
  end
  if settings.target_mode == 6 then
    return hash_noise(source * 131 + 7) * math.pi * 2 * settings.phase_spread
  end
  return ((source - 1) / NUM_SOURCES) * math.pi * 2 * settings.phase_spread
end

local function source_time(source, t)
  if settings.target_mode == 4 then
    return (t - (source - 1) * settings.canon_delay) % 1
  end
  return t
end

local function source_direction(source)
  if settings.target_mode == 5 and source % 2 == 0 then return -1 end
  return 1
end

local function source_spread(source)
  if settings.target_mode ~= 6 then return 1 end
  return 0.45 + 0.9 * hash_noise(source * 71 + 19)
end

local function smooth_noise(source, step, channel_offset)
  local a = hash_noise(source * 97 + step * 13 + channel_offset * 233)
  local b = hash_noise(source * 97 + (step + 1) * 13 + channel_offset * 233)
  return (a + b) * 0.5 * 2 - 1
end

local function scatter_value(source, t, channel_offset, lo, hi)
  local holds = math.max(2, math.floor(settings.cycles * 4 + 0.5))
  local step = math.floor(t * holds)
  local v = hash_noise(source * 101 + step * 17 + channel_offset * 271)
  return lo + v * (hi - lo)
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function smoothstep(t)
  t = clamp(t, 0, 1)
  return t * t * (3 - 2 * t)
end

local function continuity_t(t)
  local c = clamp(settings.continuity, 0, 1)
  return lerp(t, smoothstep(t), c)
end

local function maybe_tear(source, t)
  local tear = clamp(settings.tear, 0, 1)
  if tear <= 0 then return t end
  local zones = math.max(2, math.floor(settings.cycles * 5 + 0.5))
  local zone = math.floor(t * zones)
  local jump = hash_noise(source * 911 + zone * 41)
  if jump < tear * 0.45 then
    return (t + hash_noise(source * 317 + zone * 89) * tear) % 1
  end
  return t
end

local function graph_segment_t(source, t)
  local nodes = math.max(3, math.floor(settings.graph_nodes + 0.5))
  local travel = t * math.max(0.1, settings.cycles) * nodes
  local index = math.floor(travel)
  local frac = continuity_t(travel - index)
  local a = (index % nodes) + 1
  local memory = clamp(settings.graph_memory, 0, 1)
  local skip = 1 + math.floor(hash_noise(source * 173 + index * 29) * math.max(1, nodes - 1) * (1 - memory))
  local b = ((a - 1 + skip) % nodes) + 1
  return nodes, a, b, frac
end

local function graph_aed_node(node, nodes)
  local u = (node - 1) / math.max(1, nodes)
  local az = settings.az_center + settings.az_width * math.sin(u * math.pi * 2)
  local el = settings.el_center + settings.el_width * 0.5 * math.sin(u * math.pi * 4 + math.pi * 0.25)
  local dist = settings.dist_center + settings.dist_width * 0.5 * math.cos(u * math.pi * 2)
  return az, el, dist
end

local function graph_xyz_node(node, nodes, radius)
  local u = (node - 1) / math.max(1, nodes)
  local az = u * math.pi * 2
  local z = math.sin(u * math.pi * 4 + math.pi * 0.25) * radius * 0.65
  return math.sin(az) * radius, math.cos(az) * radius, z
end

local function apply_aed_hole(az, el)
  local radius = math.max(1, settings.hole_radius * 180)
  local da = wrap_degrees(az - settings.az_center)
  local de = el - settings.el_center
  local d = math.sqrt(da * da + de * de)
  if d < radius and d > 0.0001 then
    local push = (radius - d) / radius * settings.boundary_push
    az = az + (da / d) * push * radius
    el = el + (de / d) * push * radius * 0.5
  elseif d <= 0.0001 then
    az = az + radius * settings.boundary_push
  end
  return az, el
end

local function apply_xyz_hole(x, y, z)
  local radius = math.max(0.05, settings.xyz_radius * settings.hole_radius)
  local d = math.sqrt(x * x + y * y + z * z)
  if d < radius and d > 0.0001 then
    local push = (radius - d) / radius * settings.boundary_push
    x = x + (x / d) * push * radius
    y = y + (y / d) * push * radius
    z = z + (z / d) * push * radius
  elseif d <= 0.0001 then
    x = x + radius * settings.boundary_push
  end
  return x, y, z
end

local function aed_position(source, t, spec)
  t = maybe_tear(source, source_time(source, t))
  local phase = source_phase(source)
  local direction = source_direction(source)
  local spread = source_spread(source)
  local cycle = direction * math.pi * 2 * settings.cycles * t + phase
  local az, el, dist
  if settings.algorithm == 1 then
    az = settings.az_center + settings.az_width * spread * math.sin(cycle)
    el = settings.el_center + settings.el_width * 0.25 * math.sin(cycle * 0.5 + phase)
    dist = settings.dist_center + settings.dist_width * 0.25 * math.cos(cycle)
  elseif settings.algorithm == 2 then
    az = settings.az_center + settings.az_width * spread * math.sin(cycle) * 0.65
    el = settings.el_center + settings.el_width * 0.35 * math.sin(cycle * 0.5 + phase)
    dist = settings.dist_center
  elseif settings.algorithm == 3 then
    az = settings.az_center + math.deg(cycle)
    el = settings.el_center + settings.el_width * (t - 0.5)
    dist = settings.dist_center + settings.dist_width * math.sin(cycle * 0.5)
  elseif settings.algorithm == 4 then
    az = settings.az_center + settings.az_width * math.sin(cycle)
    el = settings.el_center + settings.el_width * 0.5 * math.sin(cycle * 1.5 + phase)
    dist = settings.dist_center + settings.dist_width * math.sin(cycle * 0.75 + phase * 0.5)
  elseif settings.algorithm == 5 then
    local step = math.floor(t * settings.point_rate * math.max(1, settings.cycles))
    az = settings.az_center + settings.az_width * smooth_noise(source, step, 0)
    el = settings.el_center + settings.el_width * 0.5 * smooth_noise(source, step, 1)
    dist = settings.dist_center + settings.dist_width * smooth_noise(source, step, 2)
  elseif settings.algorithm == 6 then
    local nodes, a, b, frac = graph_segment_t(source, t)
    local az1, el1, d1 = graph_aed_node(a, nodes)
    local az2, el2, d2 = graph_aed_node(b, nodes)
    az = lerp(az1, az2, frac)
    el = lerp(el1, el2, frac)
    dist = lerp(d1, d2, frac)
  elseif settings.algorithm == 7 then
    az = settings.az_center + settings.az_width * math.sin(cycle)
    el = settings.el_center + settings.el_width * 0.5 * math.sin(cycle * 0.75 + phase)
    dist = settings.dist_center + settings.dist_width * 0.25 * math.cos(cycle)
    az, el = apply_aed_hole(az, el)
  elseif settings.algorithm == 8 then
    local pull = 1 - math.exp(-t * (1.0 + settings.boundary_push * 4))
    az = lerp(settings.az_center - settings.az_width, settings.az_center, pull) + settings.az_width * 0.2 * math.sin(cycle)
    el = lerp(settings.el_center - settings.el_width * 0.5, settings.el_center, pull)
    dist = lerp(settings.dist_center + settings.dist_width, settings.dist_center, pull)
  elseif settings.algorithm == 9 then
    local edge = (t * math.max(1, settings.graph_nodes)) % 1
    local side = math.floor(t * math.max(4, settings.graph_nodes)) % 4
    local a = side == 0 and edge or side == 1 and 1 or side == 2 and (1 - edge) or 0
    local b = side == 0 and 0 or side == 1 and edge or side == 2 and 1 or (1 - edge)
    az = settings.az_center + settings.az_width * (a * 2 - 1)
    el = settings.el_center + settings.el_width * (b - 0.5)
    dist = settings.dist_center
  else
    az = scatter_value(source, t, 0, settings.az_center - settings.az_width, settings.az_center + settings.az_width)
    el = scatter_value(source, t, 1, settings.el_center - settings.el_width * 0.5, settings.el_center + settings.el_width * 0.5)
    dist = scatter_value(source, t, 2, settings.dist_center - settings.dist_width, settings.dist_center + settings.dist_width)
  end
  return az, clamp(el, spec.el_min, spec.el_max), clamp(dist, spec.dist_min, spec.dist_max)
end

local function xyz_position(source, t, spec)
  t = maybe_tear(source, source_time(source, t))
  local phase = source_phase(source)
  local direction = source_direction(source)
  local spread = source_spread(source)
  local cycle = direction * math.pi * 2 * settings.cycles * t + phase
  local r = settings.xyz_radius
  local x, y, z
  if settings.algorithm == 1 then
    x = r * spread * math.sin(cycle); y = r * spread * math.cos(cycle); z = 0.35 * r * math.sin(cycle * 0.5 + phase)
  elseif settings.algorithm == 2 then
    x = r * 0.85 * math.sin(cycle); y = r * 0.25 * math.cos(cycle); z = r * 0.35 * math.sin(cycle * 0.5 + phase)
  elseif settings.algorithm == 3 then
    x = r * math.sin(cycle); y = r * math.cos(cycle); z = r * (t * 2 - 1)
  elseif settings.algorithm == 4 then
    x = r * math.sin(cycle); y = r * math.sin(cycle * 1.5 + phase); z = r * math.sin(cycle * 0.75 + phase * 0.5)
  elseif settings.algorithm == 5 then
    local step = math.floor(t * settings.point_rate * math.max(1, settings.cycles))
    x = r * smooth_noise(source, step, 0); y = r * smooth_noise(source, step, 1); z = r * smooth_noise(source, step, 2)
  elseif settings.algorithm == 6 then
    local nodes, a, b, frac = graph_segment_t(source, t)
    local x1, y1, z1 = graph_xyz_node(a, nodes, r)
    local x2, y2, z2 = graph_xyz_node(b, nodes, r)
    x = lerp(x1, x2, frac); y = lerp(y1, y2, frac); z = lerp(z1, z2, frac)
  elseif settings.algorithm == 7 then
    x = r * math.sin(cycle); y = r * math.cos(cycle); z = r * 0.45 * math.sin(cycle * 0.5 + phase)
    x, y, z = apply_xyz_hole(x, y, z)
  elseif settings.algorithm == 8 then
    local pull = 1 - math.exp(-t * (1.0 + settings.boundary_push * 4))
    x = lerp(-r, 0, pull) + r * 0.2 * math.sin(cycle)
    y = lerp(r, 0, pull)
    z = lerp(-r * 0.5, 0, pull)
  elseif settings.algorithm == 9 then
    local edge = (t * math.max(1, settings.graph_nodes)) % 1
    local side = math.floor(t * math.max(4, settings.graph_nodes)) % 4
    x = r * ((side == 0 and edge or side == 1 and 1 or side == 2 and (1 - edge) or 0) * 2 - 1)
    y = r * ((side == 0 and 0 or side == 1 and edge or side == 2 and 1 or (1 - edge)) * 2 - 1)
    z = r * 0.4 * math.sin(cycle)
  else
    x = scatter_value(source, t, 0, -r, r); y = scatter_value(source, t, 1, -r, r); z = scatter_value(source, t, 2, -r, r)
  end
  return clamp(x, spec.min, spec.max), clamp(y, spec.min, spec.max), clamp(z, spec.min, spec.max)
end

local function point_count(start_pos, end_pos)
  return math.max(2, math.floor((end_pos - start_pos) * settings.point_rate + 0.5) + 1)
end

local function build_preview(spec, start_pos, end_pos)
  local points = {}
  local count = math.min(240, point_count(start_pos, end_pos))
  for _, source in ipairs(target_sources()) do
    local path = {}
    for i = 0, count - 1 do
      local t = count <= 1 and 0 or i / (count - 1)
      if spec.coord == "XYZ" then
        local x, y, z = xyz_position(source, t, spec)
        path[#path + 1] = { x = x, y = y, z = z }
      else
        local az, el, dist = aed_position(source, t, spec)
        local azr, elr = math.rad(az), math.rad(el)
        path[#path + 1] = {
          x = math.sin(azr) * math.cos(elr) * dist,
          y = math.cos(azr) * math.cos(elr) * dist,
          z = math.sin(elr) * dist,
        }
      end
    end
    points[source] = path
  end
  return points
end

local function write_param_points(track, fx, param, start_pos, end_pos, values)
  local env = reaper.GetFXEnvelope(track, fx, param, true)
  if not env then return false end
  if settings.clear_existing then
    reaper.DeleteEnvelopePointRange(env, start_pos - 0.0001, end_pos + 0.0001)
  end
  for _, point in ipairs(values) do
    reaper.InsertEnvelopePoint(env, point.time, point.value, 0, 0, false, true)
  end
  reaper.Envelope_SortPoints(env)
  return true
end

local function unwrap_azimuth_points(points)
  local previous
  for _, point in ipairs(points) do
    local az = point.value
    if previous == nil then
      az = wrap_degrees(az)
    else
      while az - previous > 180 do az = az - 360 end
      while previous - az > 180 do az = az + 360 end
    end
    point.value = az
    previous = point.value
  end
  local min_az, max_az = math.huge, -math.huge
  for _, point in ipairs(points) do
    min_az = math.min(min_az, point.value)
    max_az = math.max(max_az, point.value)
  end
  local shift = 0
  if max_az > 360 or min_az < -360 then
    local mid = (min_az + max_az) * 0.5
    shift = 360 * math.floor((mid + 180) / 360)
  end
  for _, point in ipairs(points) do
    point.value = clamp(point.value - shift, -360, 360)
  end
end

local function commit_automation(track, fx, spec, start_pos, end_pos)
  local count = point_count(start_pos, end_pos)
  local stats = {}
  reaper.Undo_BeginBlock()
  for _, source in ipairs(target_sources()) do
    local p1, p2, p3 = {}, {}, {}
    for i = 0, count - 1 do
      local t = count <= 1 and 0 or i / (count - 1)
      local time = start_pos + (end_pos - start_pos) * t
      if spec.coord == "XYZ" then
        local x, y, z = xyz_position(source, t, spec)
        p1[#p1 + 1] = { time = time, value = x }
        p2[#p2 + 1] = { time = time, value = y }
        p3[#p3 + 1] = { time = time, value = z }
      else
        local az, el, dist = aed_position(source, t, spec)
        p1[#p1 + 1] = { time = time, value = az }
        p2[#p2 + 1] = { time = time, value = el }
        p3[#p3 + 1] = { time = time, value = dist }
      end
    end
    local base = 9 + (source - 1) * 3
    if spec.coord == "AED" then unwrap_azimuth_points(p1) end
    stats[#stats + 1] = {
      source = source,
      p1_min = math.huge, p1_max = -math.huge,
      p2_min = math.huge, p2_max = -math.huge,
      p3_min = math.huge, p3_max = -math.huge,
    }
    local st = stats[#stats]
    for _, p in ipairs(p1) do st.p1_min = math.min(st.p1_min, p.value); st.p1_max = math.max(st.p1_max, p.value) end
    for _, p in ipairs(p2) do st.p2_min = math.min(st.p2_min, p.value); st.p2_max = math.max(st.p2_max, p.value) end
    for _, p in ipairs(p3) do st.p3_min = math.min(st.p3_min, p.value); st.p3_max = math.max(st.p3_max, p.value) end
    write_param_points(track, fx, base, start_pos, end_pos, p1)
    write_param_points(track, fx, base + 1, start_pos, end_pos, p2)
    write_param_points(track, fx, base + 2, start_pos, end_pos, p3)
  end
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Write s3g spatial automation", -1)
  return stats
end

local function draw_combo(label, index, labels)
  if ImGui.BeginCombo(ctx, label, labels[index] or labels[1]) then
    for i, name in ipairs(labels) do
      local selected = i == index
      if ImGui.Selectable(ctx, name, selected) then index = i end
    end
    ImGui.EndCombo(ctx)
  end
  return index
end

local function slider(label, value, lo, hi, fmt)
  local changed, new_value = ImGui.SliderDouble(ctx, label, value, lo, hi, fmt or "%.2f")
  return changed and new_value or value
end

local function draw_preview(spec, start_pos, end_pos)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(520, ImGui.GetContentRegionAvail(ctx))
  local h = 310
  local control_width = 82
  local control_gap = 10
  local controls_inline = w >= 640
  local canvas_w = controls_inline and math.max(420, w - control_width - control_gap) or w
  ImGui.InvisibleButton(ctx, "##spatial_motion_preview", canvas_w, h)
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + canvas_w, y + h, COLORS.bg)
  ImGui.DrawList_AddRect(draw_list, x, y, x + canvas_w, y + h, COLORS.edge)
  ImGui.DrawList_AddText(draw_list, x + 14, y + 12, COLORS.text, "Motion preview")
  ImGui.DrawList_AddText(draw_list, x + 150, y + 12, COLORS.muted, string.format("%.2fs to %.2fs / %s", start_pos, end_pos, spec.coord))
  ImGui.DrawList_AddText(draw_list, x + canvas_w - 170, y + 12, COLORS.muted,
    string.format("yaw %.0f / pitch %.0f / zoom %.2f", view_yaw_deg, view_pitch_deg, view_zoom))

  local cx, cy = x + canvas_w * 0.5, y + h * 0.56
  local radius = math.min(canvas_w, h) * 0.34 * view_zoom
  ImGui.DrawList_AddCircle(draw_list, cx, cy, radius, color(0.62, 0.65, 0.68, 0.22), 96, 1)
  ImGui.DrawList_AddCircle(draw_list, cx, cy, radius * 0.5, color(0.62, 0.65, 0.68, 0.10), 96, 1)
  ImGui.DrawList_AddLine(draw_list, cx - radius, cy, cx + radius, cy, color(0.62, 0.65, 0.68, 0.14), 1)
  ImGui.DrawList_AddLine(draw_list, cx, cy - radius, cx, cy + radius, color(0.62, 0.65, 0.68, 0.14), 1)

  local paths = build_preview(spec, start_pos, end_pos)
  for source, path in pairs(paths) do
    local prev
    local active_index = math.max(1, math.min(#path, math.floor(preview_t * math.max(1, #path - 1) + 1.5)))
    for i, p in ipairs(path) do
      local r = rotate_preview_point(p)
      local front = clamp((r.z + 2) / 4, 0.18, 1)
      local px = cx + clamp(r.x / 2, -1.2, 1.2) * radius
      local py = cy - clamp(r.y / 2, -1.2, 1.2) * radius
      if prev then
        ImGui.DrawList_AddLine(draw_list, prev.x, prev.y, px, py, source_color(source, 0.14 + 0.42 * front), 1.5)
      end
      if i == 1 then
        ImGui.DrawList_AddCircleFilled(draw_list, px, py, 4.2, source_color(source, 0.95), 16)
      elseif i == #path then
        ImGui.DrawList_AddRectFilled(draw_list, px - 4, py - 4, px + 4, py + 4, source_color(source, 0.95))
      end
      if i == active_index then
        ImGui.DrawList_AddCircleFilled(draw_list, px, py, 6.5, color(1.0, 0.88, 0.18, 0.95), 20)
        ImGui.DrawList_AddCircle(draw_list, px, py, 9.5, source_color(source, 0.92), 20, 1.5)
      end
      prev = { x = px, y = py }
    end
  end
  local tx0, ty = x + 16, y + h - 20
  local tx1 = x + canvas_w - 16
  ImGui.DrawList_AddLine(draw_list, tx0, ty, tx1, ty, color(0.80, 0.84, 0.82, 0.28), 1)
  ImGui.DrawList_AddCircleFilled(draw_list, tx0 + (tx1 - tx0) * preview_t, ty, 4.0, color(1.0, 0.88, 0.18, 0.95), 16)
  if controls_inline then
    ImGui.SameLine(ctx)
    ImGui.Dummy(ctx, control_gap, 1)
    ImGui.SameLine(ctx)
  end
  draw_preview_camera_controls()
end

local function draw_preview_transport()
  local changed
  changed, preview_t = ImGui.SliderDouble(ctx, "Timeline preview", preview_t, 0, 1, "%.3f")
  if ImGui.Button(ctx, preview_play and "Stop Preview" or "Play Preview", 130, 26) then
    preview_play = not preview_play
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Reset Preview", 110, 26) then preview_t = 0 end
  changed, preview_speed = ImGui.SliderDouble(ctx, "Preview speed", preview_speed, 0.125, 4.0, "%.3fx")
end

local function loop()
  local now = reaper.time_precise()
  local dt = math.max(0, math.min(0.2, now - last_frame_time))
  last_frame_time = now
  if preview_play then
    preview_t = (preview_t + dt * preview_speed / math.max(0.1, settings.duration)) % 1.0
  end
  ImGui.SetNextWindowSize(ctx, 820, 740, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, "Spatial Automation Composer", open)
  if visible then
    local footer_track, footer_fx, footer_spec, footer_start, footer_end = nil, nil, nil, nil, nil
    local footer_h = 58
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    local control_h = math.max(280, avail_h - footer_h)
    if ImGui.BeginChild(ctx, "##spatial_automation_controls", 0, control_h) then
    local track = reaper.GetSelectedTrack(PROJECT, 0)
    local spec, fx = detect_panner(track)
    if not track then
      ImGui.Text(ctx, "Select a track with an s3g panner.")
    elseif not spec then
      ImGui.TextColored(ctx, COLORS.warn, "No supported s3g AED/XYZ panner found on the selected track.")
      ImGui.TextColored(ctx, COLORS.muted, "Supported: Layout, 12ch Dodeca, 17ch Cube XYZ, 25ch Dome panners.")
    else
      local start_pos, end_pos = time_range()
      footer_track, footer_fx, footer_spec, footer_start, footer_end = track, fx, spec, start_pos, end_pos
      ImGui.Text(ctx, "Target: " .. spec.label)
      ImGui.SameLine(ctx)
      ImGui.TextColored(ctx, COLORS.muted, spec.coord .. " / FX #" .. tostring(fx + 1))

      settings.algorithm = draw_combo("Path method", settings.algorithm, ALGORITHMS)
      settings.target_mode = draw_combo("Source relationship", settings.target_mode, TARGET_MODES)
      if settings.target_mode == 1 then
        local changed
        changed, settings.selected_source = ImGui.SliderInt(ctx, "Selected source", settings.selected_source, 1, NUM_SOURCES)
      end
      if settings.target_mode == 4 then
        settings.canon_delay = slider("Canon delay", settings.canon_delay, 0.0, 0.5, "%.3f")
      end
      settings.time_mode = draw_combo("Range", settings.time_mode, TIME_MODES)
      if settings.time_mode == 3 then settings.duration = slider("Duration", settings.duration, 0.25, 240, "%.2f sec") end
      settings.point_rate = slider("Point rate", settings.point_rate, 1, 30, "%.0f / sec")
      settings.cycles = slider("Cycles", settings.cycles, 0.1, 12, "%.2f")
      settings.phase_spread = slider("Source phase spread", settings.phase_spread, 0, 3, "%.2f")
      settings.continuity = slider("Continuity", settings.continuity, 0, 1, "%.2f")
      settings.tear = slider("Tear / jump chance", settings.tear, 0, 1, "%.2f")
      if settings.algorithm == 6 then
        local changed
        changed, settings.graph_nodes = ImGui.SliderInt(ctx, "Graph nodes", settings.graph_nodes, 3, 16)
        settings.graph_memory = slider("Graph memory", settings.graph_memory, 0, 1, "%.2f")
      elseif settings.algorithm == 7 then
        settings.hole_radius = slider("Hole radius", settings.hole_radius, 0.02, 0.95, "%.2f")
        settings.boundary_push = slider("Hole repulsion", settings.boundary_push, 0, 1, "%.2f")
      elseif settings.algorithm == 8 or settings.algorithm == 9 then
        settings.boundary_push = slider("Boundary force", settings.boundary_push, 0, 1, "%.2f")
        local changed
        changed, settings.graph_nodes = ImGui.SliderInt(ctx, "Path corners", settings.graph_nodes, 4, 16)
      end
      local changed
      changed, settings.clear_existing = ImGui.Checkbox(ctx, "Clear existing points in range", settings.clear_existing)

      if spec.coord == "XYZ" then
        settings.xyz_radius = slider("XYZ radius", settings.xyz_radius, 0.05, 2, "%.2f")
      else
        settings.az_center = slider("Azimuth center", settings.az_center, -180, 180, "%.0f deg")
        settings.az_width = slider("Azimuth range", settings.az_width, 0, 360, "%.0f deg")
        settings.el_center = slider("Elevation center", settings.el_center, spec.el_min, spec.el_max, "%.0f deg")
        settings.el_width = slider("Elevation range", settings.el_width, 0, spec.el_max - spec.el_min, "%.0f deg")
        settings.dist_center = slider("Distance center", settings.dist_center, spec.dist_min, spec.dist_max, "%.2f")
        settings.dist_width = slider("Distance range", settings.dist_width, 0, spec.dist_max - spec.dist_min, "%.2f")
      end
      local seed_changed
      seed_changed, settings.seed = ImGui.SliderInt(ctx, "Seed", settings.seed, 1, 99999)

      ImGui.Spacing(ctx)
      draw_preview(spec, start_pos, end_pos)
      draw_preview_transport()
      ImGui.Spacing(ctx)
      ImGui.TextColored(ctx, COLORS.muted, string.format("Will write %d points per parameter over %.2f seconds.", point_count(start_pos, end_pos), end_pos - start_pos))
      if last_status ~= "" then ImGui.TextColored(ctx, COLORS.muted, last_status) end
    end
    ImGui.EndChild(ctx)
    end
    if not footer_spec then ImGui.BeginDisabled(ctx) end
    if ImGui.Button(ctx, "Write automation", 180, 30) and footer_spec then
      local stats = commit_automation(footer_track, footer_fx, footer_spec, footer_start, footer_end)
      local first = stats and stats[1]
      if first then
        if footer_spec.coord == "XYZ" then
          last_status = string.format("Wrote %d source path(s). S%d X %.2f..%.2f / Y %.2f..%.2f / Z %.2f..%.2f",
            #stats, first.source, first.p1_min, first.p1_max, first.p2_min, first.p2_max, first.p3_min, first.p3_max)
        else
          last_status = string.format("Wrote %d source path(s). S%d az %.1f..%.1f / el %.1f..%.1f / dist %.2f..%.2f",
            #stats, first.source, first.p1_min, first.p1_max, first.p2_min, first.p2_max, first.p3_min, first.p3_max)
        end
      else
        last_status = "No automation points written."
      end
    end
    if not footer_spec then ImGui.EndDisabled(ctx) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Close", 100, 30) then open = false end
    ImGui.End(ctx)
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
