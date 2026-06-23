-- @description 25ch Region Dome Panner
-- @author s3g
-- @version 0.6
-- @requires ReaImGui; JSFX: s3g 25ch Region Dome Panner
-- @category Spatial / HOA
-- @method Auto-loads the JSFX on the selected track and constrains up to 8 mono source channels to speaker-defined rings, arcs, ribs, triangles, and caps across the 25-speaker dome layout of the RISD SRST Spatial Audio Studio.
-- @about
--   ReaImGui companion controller for JS: s3g 25ch Region Dome Panner.
--   Automatically loads or repairs the JSFX on the selected track. The track
--   carries 8 source channels into the panner and the JSFX distributes them
--   across the 25-channel dome output. The speaker layout models the
--   loudspeaker array of the RISD SRST Spatial Audio Studio.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "25ch Region Dome Panner", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local ctx = ImGui.CreateContext("25ch Region Dome Panner")
local open = true
local PROJECT = 0
local FX_NAME = "s3g 25ch Region Dome Panner"
local FX_NAME_CLEAN = "25ch Region Dome Panner"
local FX_NAME_LEGACY = "s3g/25ch Region Dome Panner"
local selected_source = 1
local view_yaw_deg = -35
local view_pitch_deg = -42
local view_roll_deg = 0
local view_zoom = 1.0
local dragging_source = 0
local load_error = ""
local auto_load_attempted_guid = ""

local speakers = {
  { id = 1, az = 30, el = 0 }, { id = 2, az = 60, el = 0 }, { id = 3, az = 90, el = 0 },
  { id = 4, az = 120, el = 0 }, { id = 5, az = 150, el = 0 }, { id = 6, az = 180, el = 0 },
  { id = 7, az = -150, el = 0 }, { id = 8, az = -120, el = 0 }, { id = 9, az = -90, el = 0 },
  { id = 10, az = -60, el = 0 }, { id = 11, az = -30, el = 0 }, { id = 12, az = 0, el = 0 },
  { id = 13, az = 45, el = 32 }, { id = 14, az = 90, el = 32 }, { id = 15, az = 135, el = 32 },
  { id = 16, az = 180, el = 32 }, { id = 17, az = -135, el = 32 }, { id = 18, az = -90, el = 32 },
  { id = 19, az = -45, el = 32 }, { id = 20, az = 0, el = 32 },
  { id = 21, az = 90, el = 66.6 }, { id = 22, az = 180, el = 66.6 },
  { id = 23, az = -90, el = 66.6 }, { id = 24, az = 0, el = 66.6 },
  { id = 25, az = 0, el = 90 },
}

local SHAPES = {
  "Ring lower 1-12",
  "Ring middle 13-20",
  "Ring upper 21-24",
  "Arc diagonal 9-18-23-25-21-14-3",
  "Rib front 12-20-24-25",
  "Rib left 9-18-23-25",
  "Triangle 10-19-11",
  "Cap crown 21-22-23-24-25",
  "Arc diagonal 12-20-24-25-22-16-6",
  "Triangle 1-13-2",
  "Triangle 4-15-5",
  "Triangle 7-17-8",
  "Spiral 1-25",
  "Constellation",
}

local SHAPE_OPTIONS = {}
for index, name in ipairs(SHAPES) do
  SHAPE_OPTIONS[#SHAPE_OPTIONS + 1] = { id = index - 1, name = name }
end
table.sort(SHAPE_OPTIONS, function(a, b) return a.name < b.name end)

local function az_key(az)
  return az < 0 and az + 360 or az
end

local function speakers_for_elevation(el)
  local result = {}
  for _, speaker in ipairs(speakers) do
    if math.abs(speaker.el - el) < 0.01 then
      result[#result + 1] = speaker
    end
  end
  table.sort(result, function(a, b) return az_key(a.az) < az_key(b.az) end)
  return result
end

local function ids_for_elevation(el)
  local result = {}
  for _, speaker in ipairs(speakers_for_elevation(el)) do
    result[#result + 1] = speaker.id
  end
  return result
end

local function speaker_az(id)
  for _, speaker in ipairs(speakers) do
    if speaker.id == id then return speaker.az end
  end
  return 0
end

local function speaker_by_id(id)
  for _, speaker in ipairs(speakers) do
    if speaker.id == id then return speaker end
  end
  return speakers[1]
end

local function lower_bracket_ids(upper_id, lower_ids)
  local upper_az = az_key(speaker_az(upper_id))
  local lower = {}
  for i, id in ipairs(lower_ids) do lower[i] = id end
  table.sort(lower, function(a, b) return az_key(speaker_az(a)) < az_key(speaker_az(b)) end)

  for i, id in ipairs(lower) do
    if math.abs(az_key(speaker_az(id)) - upper_az) < 0.01 then
      return {
        lower[((i - 2) % #lower) + 1],
        lower[i],
        lower[(i % #lower) + 1],
      }
    end
  end

  for i, a in ipairs(lower) do
    local b = lower[(i % #lower) + 1]
    local a_az = az_key(speaker_az(a))
    local b_az = az_key(speaker_az(b))
    if b_az < a_az then b_az = b_az + 360 end
    local test_az = upper_az < a_az and upper_az + 360 or upper_az
    if test_az > a_az and test_az < b_az then
      return { a, b }
    end
  end
  return { lower[1], lower[2] }
end

local function add_fan_facets(facets, lower_ids, upper_ids)
  if #lower_ids < 2 or #upper_ids < 1 then return end
  if #upper_ids == 1 then
    for i, id in ipairs(lower_ids) do
      facets[#facets + 1] = { id, lower_ids[(i % #lower_ids) + 1], upper_ids[1] }
    end
    return
  end

  for _, upper_id in ipairs(upper_ids) do
    local bracket = lower_bracket_ids(upper_id, lower_ids)
    if #bracket == 2 then
      facets[#facets + 1] = { bracket[1], bracket[2], upper_id }
    elseif #bracket == 3 then
      facets[#facets + 1] = { bracket[1], bracket[2], upper_id }
      facets[#facets + 1] = { bracket[2], bracket[3], upper_id }
    end
  end
end

local function build_speaker_facets()
  local facets = {}
  add_fan_facets(facets, ids_for_elevation(0), ids_for_elevation(32))
  add_fan_facets(facets, ids_for_elevation(32), ids_for_elevation(66.6))
  add_fan_facets(facets, ids_for_elevation(66.6), ids_for_elevation(90))
  return facets
end

local function add_unique_edge(edges, seen, a, b)
  local lo = math.min(a, b)
  local hi = math.max(a, b)
  local key = tostring(lo) .. ":" .. tostring(hi)
  if not seen[key] then
    edges[#edges + 1] = { a, b }
    seen[key] = true
  end
end

local function build_speaker_edges(facets)
  local edges = {}
  local seen = {}
  for _, facet in ipairs(facets) do
    add_unique_edge(edges, seen, facet[1], facet[2])
    add_unique_edge(edges, seen, facet[2], facet[3])
    add_unique_edge(edges, seen, facet[3], facet[1])
  end
  return edges
end

local speaker_facets = build_speaker_facets()
local speaker_edges = build_speaker_edges(speaker_facets)

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
  sharpness = 0,
  rolloff = 1,
  smoothing = 2,
  global_az = 3,
  global_el = 4,
  global_dist = 5,
  out_gain = 6,
}

local function source_param(source_index, offset)
  return 9 + ((source_index - 1) * 3) + offset
end

local function source_control_param(source_index, offset)
  return 33 + ((source_index - 1) * 3) + offset
end

local function source_shape_param(source_index, offset)
  return 57 + ((source_index - 1) * 4) + offset
end

local function constellation_mask_param(source_index)
  return 89 + (source_index - 1)
end

local function constellation_closed_param(source_index)
  return 97 + (source_index - 1)
end

local function constellation_bit(speaker_id)
  return 2 ^ (speaker_id - 1)
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

local function constellation_mask(track, fx, source)
  return math.max(0, math.floor(get_param(track, fx, constellation_mask_param(source), 0) + 0.5))
end

local function constellation_speaker_enabled(track, fx, source, speaker_id)
  local bit = constellation_bit(speaker_id)
  local mask = constellation_mask(track, fx, source)
  return math.floor(mask / bit) % 2 >= 1
end

local function set_constellation_speaker(track, fx, source, speaker_id, enabled)
  local bit = constellation_bit(speaker_id)
  local mask = constellation_mask(track, fx, source)
  local already_enabled = math.floor(mask / bit) % 2 >= 1
  if enabled and not already_enabled then
    mask = mask + bit
  elseif not enabled and already_enabled then
    mask = mask - bit
  end
  set_param(track, fx, constellation_mask_param(source), mask)
end

local function slider_double(track, fx, label, param, lo, hi, fmt)
  local value = get_param(track, fx, param, lo)
  local changed, new_value = ImGui.SliderDouble(ctx, label, value, lo, hi, fmt or "%.2f")
  if changed then set_param(track, fx, param, new_value) end
  return new_value
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

local function shape_combo(track, fx, source)
  local param = source_shape_param(source, 0)
  local value = math.floor(get_param(track, fx, param, 0) + 0.5)
  value = math.floor(clamp(value, 0, #SHAPES - 1))
  local label = "Shape##shape" .. tostring(source)
  if ImGui.BeginCombo(ctx, label, SHAPES[value + 1]) then
    for _, option in ipairs(SHAPE_OPTIONS) do
      local shape_index = option.id
      local selected = value == shape_index
      if ImGui.Selectable(ctx, option.name, selected) then
        set_param(track, fx, param, shape_index)
        value = shape_index
      end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return value
end

local function maybe_load(track, force)
  if not track then return -1 end
  reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", 26)
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

local function distance_projection(distance)
  local d = math.max(0, distance)
  if d <= 1 then return d end
  return 1 + (d - 1) * 0.55
end

local function inverse_distance_projection(projected_distance)
  local d = math.max(0, projected_distance)
  if d <= 1 then return d end
  return 1 + (d - 1) / 0.55
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

  for el = 0, 90, 5 do
    for az = -180, 175, 5 do
      test_candidate(az, el)
    end
  end

  local coarse_az = best_az
  local coarse_el = best_el
  for el = math.max(0, coarse_el - 6), math.min(90, coarse_el + 6), 1 do
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
  local distance = clamp(inverse_distance_projection(projected_distance), 0.1, 3)
  return best_az, best_el, distance
end

function projected_point(az, el, distance, cx, cy, radius)
  local p = point_from_az_el(az, el)
  local scale = distance and distance_projection(distance) or 1
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

local function interpolate_speakers(a, b, t)
  local pa = point_from_az_el(a.az, a.el)
  local pb = point_from_az_el(b.az, b.el)
  local x = pa.x + (pb.x - pa.x) * t
  local y = pa.y + (pb.y - pa.y) * t
  local z = pa.z + (pb.z - pa.z) * t
  local len = math.sqrt(x * x + y * y + z * z)
  if len < 0.000001 then return { x = 0, y = 1, z = 0 } end
  return { x = x / len, y = y / len, z = z / len }
end

local function path_point(ids, pos, closed)
  local count = #ids
  if count == 0 then return { x = 0, y = 1, z = 0 } end
  if count == 1 then
    local speaker = speaker_by_id(ids[1])
    return point_from_az_el(speaker.az, speaker.el)
  end

  pos = clamp(pos or 0, 0, 1)
  local segments = closed and count or (count - 1)
  local scaled = pos * segments
  if not closed and scaled >= segments then
    local speaker = speaker_by_id(ids[count])
    return point_from_az_el(speaker.az, speaker.el)
  end

  local index = math.floor(scaled)
  local t = scaled - index
  local a = speaker_by_id(ids[(index % count) + 1])
  local b = speaker_by_id(ids[((index + 1) % count) + 1])
  return interpolate_speakers(a, b, t)
end

local function triangle_point(a_id, b_id, c_id, pos, depth)
  local perimeter = path_point({ a_id, b_id, c_id }, pos, true)
  local a = point_from_az_el(speaker_by_id(a_id).az, speaker_by_id(a_id).el)
  local b = point_from_az_el(speaker_by_id(b_id).az, speaker_by_id(b_id).el)
  local c = point_from_az_el(speaker_by_id(c_id).az, speaker_by_id(c_id).el)
  local center_x = (a.x + b.x + c.x) / 3
  local center_y = (a.y + b.y + c.y) / 3
  local center_z = (a.z + b.z + c.z) / 3
  local center_len = math.sqrt(center_x * center_x + center_y * center_y + center_z * center_z)
  if center_len > 0.000001 then
    center_x = center_x / center_len
    center_y = center_y / center_len
    center_z = center_z / center_len
  end
  local blend = clamp(depth or 0, 0, 1)
  local x = perimeter.x * (1 - blend) + center_x * blend
  local y = perimeter.y * (1 - blend) + center_y * blend
  local z = perimeter.z * (1 - blend) + center_z * blend
  local len = math.sqrt(x * x + y * y + z * z)
  if len < 0.000001 then return perimeter end
  return { x = x / len, y = y / len, z = z / len }
end

local function constellation_ids(track, fx, source)
  local ids = {}
  for speaker_id = 1, 25 do
    if constellation_speaker_enabled(track, fx, source, speaker_id) then
      ids[#ids + 1] = speaker_id
    end
  end
  return ids
end

local function constellation_point(track, fx, source, pos)
  local ids = constellation_ids(track, fx, source)
  if #ids == 0 then return path_point({ 1 }, pos, false) end
  local closed = get_param(track, fx, constellation_closed_param(source), 0) >= 0.5
  return path_point(ids, pos, closed)
end

local function region_point(shape, pos, depth, track, fx, source)
  shape = math.floor(clamp(shape or 0, 0, #SHAPES - 1))
  if shape == 0 then return path_point({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }, pos, true) end
  if shape == 1 then return path_point({ 13, 14, 15, 16, 17, 18, 19, 20 }, pos, true) end
  if shape == 2 then return path_point({ 21, 22, 23, 24 }, pos, true) end
  if shape == 3 then return path_point({ 9, 18, 23, 25, 21, 14, 3 }, pos, false) end
  if shape == 4 then return path_point({ 12, 20, 24, 25 }, pos, false) end
  if shape == 5 then return path_point({ 9, 18, 23, 25 }, pos, false) end
  if shape == 6 then return triangle_point(10, 19, 11, pos, depth) end
  if shape == 7 then return path_point({ 21, 22, 23, 24, 25 }, pos, true) end
  if shape == 8 then return path_point({ 12, 20, 24, 25, 22, 16, 6 }, pos, false) end
  if shape == 9 then return triangle_point(1, 13, 2, pos, depth) end
  if shape == 10 then return triangle_point(4, 15, 5, pos, depth) end
  if shape == 11 then return triangle_point(7, 17, 8, pos, depth) end
  if shape == 12 then return path_point({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25 }, pos, false) end
  return constellation_point(track, fx, source, pos)
end

local function projected_region_point(shape, pos, depth, distance, cx, cy, radius, track, fx, source)
  local p = region_point(shape, pos, depth, track, fx, source)
  local scale = distance_projection(distance or 1)
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

local function draw_speaker_geometry(draw_list, by_id)
  local can_draw_filled_triangles, draw_triangle_filled = pcall(function()
    return ImGui.DrawList_AddTriangleFilled
  end)
  if can_draw_filled_triangles and draw_triangle_filled then
    for _, facet in ipairs(speaker_facets) do
      local a = by_id[facet[1]]
      local b = by_id[facet[2]]
      local c = by_id[facet[3]]
      if a and b and c then
        local front = clamp(((a.z + b.z + c.z) / 3 + 1) * 0.5, 0, 1)
        draw_triangle_filled(
          draw_list,
          a.x, a.y,
          b.x, b.y,
          c.x, c.y,
          color(0.46, 0.48, 0.50, 0.035 + 0.055 * front)
        )
      end
    end
  end

  for _, edge in ipairs(speaker_edges) do
    local a = by_id[edge[1]]
    local b = by_id[edge[2]]
    if a and b then
      local front = clamp(((a.z + b.z) * 0.5 + 1) * 0.5, 0, 1)
      ImGui.DrawList_AddLine(
        draw_list,
        a.x, a.y,
        b.x, b.y,
        color(0.66, 0.68, 0.70, 0.10 + 0.18 * front),
        1
      )
    end
  end
end

local function bottom_tier_points(by_id, cx, cy)
  local points = {}
  for _, speaker in ipairs(speakers_for_elevation(0)) do
    local p = by_id[speaker.id]
    if p then points[#points + 1] = p end
  end
  table.sort(points, function(a, b)
    return math.atan(a.y - cy, a.x - cx) < math.atan(b.y - cy, b.x - cx)
  end)
  return points
end

local function draw_shell_edge(draw_list, by_id, cx, cy)
  local points = bottom_tier_points(by_id, cx, cy)
  if #points < 3 then return end

  local can_draw_filled_triangles, draw_triangle_filled = pcall(function()
    return ImGui.DrawList_AddTriangleFilled
  end)
  if can_draw_filled_triangles and draw_triangle_filled then
    for i = 1, #points do
      local a = points[i]
      local b = points[(i % #points) + 1]
      draw_triangle_filled(draw_list, cx, cy, a.x, a.y, b.x, b.y, color(0.22, 0.23, 0.24, 0.18))
    end
  end

  for i = 1, #points do
    local a = points[i]
    local b = points[(i % #points) + 1]
    ImGui.DrawList_AddLine(draw_list, a.x, a.y, b.x, b.y, COLORS.shell_line, 1.5)
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

local function hit_test_speaker(projected, mx, my)
  local best_speaker = 0
  local best_distance = math.huge
  for _, speaker in ipairs(projected) do
    local dx = mx - speaker.x
    local dy = my - speaker.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local hit_radius = 12
    if distance <= hit_radius and distance < best_distance then
      best_speaker = speaker.id
      best_distance = distance
    end
  end
  return best_speaker
end

local function update_source_from_mouse(track, fx, source_index, mx, my, cx, cy, radius, global_az, global_el, global_dist)
  if source_index < 1 or source_index > 8 then return end
  local az, el, distance = source_aed_from_screen(mx, my, cx, cy, radius)
  set_param(track, fx, source_param(source_index, 0), az - global_az)
  set_param(track, fx, source_param(source_index, 1), clamp(el - global_el, 0, 90))
  set_param(track, fx, source_param(source_index, 2), clamp(distance - global_dist, 0.1, 3))
end

local function reset_source_distances(track, fx)
  for source = 1, 8 do
    set_param(track, fx, source_param(source, 2), 1)
  end
  set_param(track, fx, PARAM.global_dist, 0)
end

local function neutralize_global_region_offsets(track, fx)
  if math.abs(get_param(track, fx, PARAM.global_az, 0)) > 0.000001 then
    set_param(track, fx, PARAM.global_az, 0)
  end
  if math.abs(get_param(track, fx, PARAM.global_el, 0)) > 0.000001 then
    set_param(track, fx, PARAM.global_el, 0)
  end
  if math.abs(get_param(track, fx, PARAM.global_dist, 0)) > 0.000001 then
    set_param(track, fx, PARAM.global_dist, 0)
  end
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

local function set_constellation(track, fx, source, mode)
  local mask = 0
  for speaker_id = 1, 25 do
    if mode == "all" then
      mask = mask + constellation_bit(speaker_id)
    elseif mode == "invert" then
      if not constellation_speaker_enabled(track, fx, source, speaker_id) then
        mask = mask + constellation_bit(speaker_id)
      end
    elseif mode == "seed" then
      if speaker_id == 1 or speaker_id == 13 or speaker_id == 25 then
        mask = mask + constellation_bit(speaker_id)
      end
    end
  end
  set_param(track, fx, constellation_mask_param(source), mask)
end

local function draw_dome(track, fx)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local width = ImGui.GetContentRegionAvail(ctx)
  local height = 430
  local cx = x0 + width * 0.5
  local cy = y0 + height * 0.56
  local radius = math.min(width, height) * 0.36
  ImGui.InvisibleButton(ctx, "dome_canvas", width, height)
  local canvas_hovered = ImGui.IsItemHovered(ctx)
  local canvas_active = ImGui.IsItemActive(ctx)

  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x0 + width, y0 + height, COLORS.bg)

  local projected = {}
  local projected_by_id = {}
  for _, speaker in ipairs(speakers) do
    local p = projected_point(speaker.az, speaker.el, nil, cx, cy, radius)
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

  draw_shell_edge(draw_list, projected_by_id, cx, cy)
  draw_speaker_geometry(draw_list, projected_by_id)

  local selected_shape = math.floor(get_param(track, fx, source_shape_param(selected_source, 0), 0) + 0.5)
  local constellation_active = selected_shape == 13
  local constellation_selected = {}
  if constellation_active then
    for speaker_id = 1, 25 do
      constellation_selected[speaker_id] = constellation_speaker_enabled(track, fx, selected_source, speaker_id)
    end
  end

  for _, speaker in ipairs(projected) do
    local front = clamp((speaker.z + 1) * 0.5, 0, 1)
    local size = 2.5 + 2 * front
    if constellation_selected[speaker.id] then
      ImGui.DrawList_AddCircleFilled(draw_list, speaker.x, speaker.y, size + 8, source_color(selected_source, 0.28), 24)
      ImGui.DrawList_AddCircle(draw_list, speaker.x, speaker.y, size + 9, COLORS.selected, 24, 2)
    end
    ImGui.DrawList_AddCircleFilled(draw_list, speaker.x, speaker.y, size + 2, COLORS.speaker_back, 18)
    ImGui.DrawList_AddCircleFilled(draw_list, speaker.x, speaker.y, size, COLORS.speaker, 18)
    ImGui.DrawList_AddText(draw_list, speaker.x + size + 3, speaker.y - 6, color(0.82, 0.88, 0.9, 0.48 + 0.36 * front), tostring(speaker.id))
  end

  local solo_count = 0
  for source = 1, 8 do
    if get_param(track, fx, source_control_param(source, 2), 0) >= 0.5 then
      solo_count = solo_count + 1
    end
  end

  local sources = {}
  for source = 1, 8 do
    local dist = clamp(get_param(track, fx, source_param(source, 2), 1), 0.1, 3)
    local shape = get_param(track, fx, source_shape_param(source, 0), 0)
    local pos = get_param(track, fx, source_shape_param(source, 1), 0)
    local depth = get_param(track, fx, source_shape_param(source, 2), 0)
    local mute = get_param(track, fx, source_control_param(source, 1), 0) >= 0.5
    local solo = get_param(track, fx, source_control_param(source, 2), 0) >= 0.5
    local gain_db = get_param(track, fx, source_control_param(source, 0), 0)
    local p = projected_region_point(shape, pos, depth, dist, cx, cy, radius, track, fx, source)
    p.id = source
    p.distance = dist
    p.shape = shape
    p.position = pos
    p.depth = depth
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
      local speaker_hit = constellation_active and hit_test_speaker(projected, mx, my) or 0
      if speaker_hit > 0 then
        local enabled = constellation_speaker_enabled(track, fx, selected_source, speaker_hit)
        set_constellation_speaker(track, fx, selected_source, speaker_hit, not enabled)
      else
        local hit = hit_test_source(sources, mx, my)
        if hit > 0 then
          selected_source = hit
          dragging_source = hit
        end
      end
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

  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 14, COLORS.text, "25ch Region Dome Panner")
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 34, COLORS.muted, "speaker-defined rings, arcs, ribs, triangles, and caps")
  ImGui.DrawList_AddText(draw_list, x0 + width - 330, y0 + 14, COLORS.muted, "dots follow shape / position / depth")
end

local function draw_source_controls(track, fx)
  local changed
  changed, selected_source = ImGui.SliderInt(ctx, "Selected source", selected_source, 1, 8)
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Reset distances") then reset_source_distances(track, fx) end
  local base_label = "S" .. tostring(selected_source)
  local shape = shape_combo(track, fx, selected_source)
  local triangle = shape == 6 or shape == 9 or shape == 10 or shape == 11
  local constellation = shape == 13
  slider_double(track, fx, triangle and (base_label .. " triangle path") or (base_label .. " position"), source_shape_param(selected_source, 1), 0, 1, "%.3f")
  if triangle then
    slider_double(track, fx, base_label .. " center blend", source_shape_param(selected_source, 2), 0, 1, "%.3f")
    slider_double(track, fx, base_label .. " vertex width", source_shape_param(selected_source, 3), 0, 1, "%.3f")
  else
    slider_double(track, fx, base_label .. " width", source_shape_param(selected_source, 3), 0, 1, "%.3f")
  end
  if constellation then
    toggle_param(track, fx, base_label .. " closed path", constellation_closed_param(selected_source))
    if ImGui.Button(ctx, "Clear constellation") then set_constellation(track, fx, selected_source, "clear") end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "All speakers") then set_constellation(track, fx, selected_source, "all") end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Invert") then set_constellation(track, fx, selected_source, "invert") end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Seed 1-13-25") then set_constellation(track, fx, selected_source, "seed") end
  end
  slider_double(track, fx, base_label .. " distance (dome radius, edge=1)", source_param(selected_source, 2), 0.1, 3, "%.2f")
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
  visible, open = ImGui.Begin(ctx, "25ch Region Dome Panner", open)
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
        neutralize_global_region_offsets(track, fx)
        draw_dome(track, fx)

        if ImGui.CollapsingHeader(ctx, "Global", nil, ImGui.TreeNodeFlags_DefaultOpen) then
          slider_double(track, fx, "Region sharpness", PARAM.sharpness, 0.25, 4, "%.2f")
          slider_double(track, fx, "Distance rolloff", PARAM.rolloff, 0, 48, "%.1f dB/oct")
          slider_double(track, fx, "Distance smoothing", PARAM.smoothing, 1, 250, "%.0f ms")
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
            view_yaw_deg = -35
            view_pitch_deg = -42
            view_roll_deg = 0
            view_zoom = 1.0
          end
          ImGui.SameLine(ctx)
          if ImGui.Button(ctx, "Top") then
            view_yaw_deg = 0
            view_pitch_deg = 0
            view_roll_deg = 0
            view_zoom = 1.0
          end
          ImGui.SameLine(ctx)
          if ImGui.Button(ctx, "Front") then
            view_yaw_deg = 0
            view_pitch_deg = -90
            view_roll_deg = 0
            view_zoom = 1.0
          end
          local changed
          changed, view_yaw_deg = ImGui.SliderDouble(ctx, "Yaw", view_yaw_deg, -180, 180, "%.0f deg")
          changed, view_pitch_deg = ImGui.SliderDouble(ctx, "Pitch", view_pitch_deg, -180, 180, "%.0f deg")
          changed, view_roll_deg = ImGui.SliderDouble(ctx, "Roll", view_roll_deg, -180, 180, "%.0f deg")
          changed, view_zoom = ImGui.SliderDouble(ctx, "Zoom", view_zoom, 0.45, 2.5, "%.2f")
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
