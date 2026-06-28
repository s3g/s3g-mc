-- @description Ambisonic Stereo Decoder
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; JSFX: s3g Ambisonic Stereo Decoder
-- @category 3OAFX
-- @method Auto-loads a package-native JSFX that decodes ACN/SN3D ambisonic input to a virtual speaker field, then derives a practical loudspeaker stereo fold-down using common stereo pickup models rather than binaural rendering.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Ambisonic Stereo Decoder", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local PROJECT = 0
local FX_NAME = "s3g Ambisonic Stereo Decoder"
local FX_NAME_CLEAN = "Ambisonic Stereo Decoder"

local PARAM = {
  order = 0,
  field = 1,
  method = 2,
  width = 3,
  angle = 4,
  rotation = 5,
  directivity = 6,
  rear = 7,
  height = 8,
  diffuse = 9,
  weighting = 10,
  autogain = 11,
  output = 12,
  extra = 13,
  custom_w = 14,
  custom_o1 = 15,
  custom_o2 = 16,
  custom_o3 = 17,
  ab_spacing = 18,
  bass_mono = 19,
  height_mode = 20,
  front_rear = 21,
  rear_mode = 22,
  mic_elevation = 23,
  rotation_image = 24,
}

local PARAM_NAMES = {
  order = "Ambisonic order",
  field = "Virtual speaker field",
  method = "Stereo method",
  width = "Stereo width (%)",
  angle = "Mic angle (degrees)",
  rotation = "Listening rotation (degrees)",
  directivity = "Directivity (%)",
  rear = "Rear rejection (%)",
  height = "Height fold (%)",
  diffuse = "Diffuse blend (%)",
  weighting = "Decode weighting",
  autogain = "Autogain",
  output = "Output gain (dB)",
  extra = "Extra channel output",
  custom_w = "Custom W weight (%)",
  custom_o1 = "Custom 1st order weight (%)",
  custom_o2 = "Custom 2nd order weight (%)",
  custom_o3 = "Custom 3rd order weight (%)",
  ab_spacing = "A/B spacing (cm)",
  bass_mono = "Bass mono below (Hz)",
  height_mode = "Height image mode",
  front_rear = "Front/rear balance (%)",
  rear_mode = "Rear image mode",
  mic_elevation = "Mic elevation (degrees)",
  rotation_image = "Rotation image (%)",
}

local ORDER = { "1OA / 4ch", "2OA / 9ch", "3OA / 16ch" }
local FIELD = { "Quad virtual", "8ch cube", "12ch dodeca", "24ch dome", "32ch sphere" }
local METHOD = { "XY cardioid", "ORTF-style", "MS cardioid", "Blumlein", "Spaced omni" }
local WEIGHTING = { "Projection", "Energy-normalized", "Max-rE-ish", "Custom" }
local AUTOGAIN = { "Off", "Power/sqrt(N)", "Energy sum" }
local EXTRA = { "Keep extra channels", "Clear extra channels" }
local HEIGHT_MODE = { "Fold center", "Fold wide", "Attenuate", "Diffuse" }
local REAR_MODE = { "Quieter", "Narrower", "Wrap wide" }

local PRESETS = {
  {
    name = "Stable Stereo",
    field = 3, method = 0, width = 100, angle = 90, directivity = 82,
    rear = 45, height = 35, diffuse = 8, weighting = 1, autogain = 1, output = 0,
  },
  {
    name = "Wide Field",
    field = 3, method = 1, width = 135, angle = 110, directivity = 76,
    rear = 28, height = 22, diffuse = 14, weighting = 1, autogain = 1, output = -1.5,
  },
  {
    name = "Front Focus",
    field = 3, method = 0, width = 82, angle = 75, directivity = 92,
    rear = 70, height = 42, diffuse = 0, weighting = 2, autogain = 1, output = 0,
  },
  {
    name = "Room Image",
    field = 4, method = 4, width = 115, angle = 90, directivity = 0,
    rear = 12, height = 10, diffuse = 34, weighting = 1, autogain = 1, output = -2,
  },
  {
    name = "MS Master",
    field = 3, method = 2, width = 95, angle = 90, directivity = 86,
    rear = 38, height = 26, diffuse = 6, weighting = 1, autogain = 1, output = 0,
  },
  {
    name = "Blumlein",
    field = 2, method = 3, width = 100, angle = 90, directivity = 100,
    rear = 0, height = 18, diffuse = 0, weighting = 1, autogain = 1, output = -3,
  },
  {
    name = "A/B Soft",
    field = 4, method = 4, width = 125, angle = 90, directivity = 0,
    rear = 20, height = 20, diffuse = 22, weighting = 1, autogain = 1, output = -1,
  },
}

local ctx = ImGui.CreateContext("Ambisonic Stereo Decoder")
local open = true
local view_yaw_deg = -35
local view_pitch_deg = -42
local view_zoom = 1.0
local load_error = ""
local param_warning = ""

local COLORS = {
  bg = ImGui.ColorConvertDouble4ToU32(0.035, 0.039, 0.042, 1),
  panel = ImGui.ColorConvertDouble4ToU32(0.060, 0.066, 0.070, 1),
  edge = ImGui.ColorConvertDouble4ToU32(0.30, 0.33, 0.34, 1),
  text = ImGui.ColorConvertDouble4ToU32(0.78, 0.82, 0.84, 1),
  muted = ImGui.ColorConvertDouble4ToU32(0.48, 0.52, 0.54, 1),
  speaker = ImGui.ColorConvertDouble4ToU32(0.25, 0.70, 0.92, 1),
  pickup_l = ImGui.ColorConvertDouble4ToU32(0.95, 0.58, 0.38, 1),
  pickup_r = ImGui.ColorConvertDouble4ToU32(0.42, 0.74, 0.96, 1),
  meter = ImGui.ColorConvertDouble4ToU32(0.46, 0.86, 0.56, 1),
  active = ImGui.ColorConvertDouble4ToU32(0.16, 0.63, 0.38, 1),
  button = ImGui.ColorConvertDouble4ToU32(0.12, 0.13, 0.14, 1),
}

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function wrap_degrees(deg)
  local wrapped = deg - math.floor(deg / 360) * 360
  if wrapped > 180 then wrapped = wrapped - 360 end
  return wrapped
end

local function find_fx(track)
  if not track then return -1 end
  for fx = 0, reaper.TrackFX_GetCount(track) - 1 do
    local ok, name = reaper.TrackFX_GetFXName(track, fx, "")
    if ok and name and (name:find(FX_NAME, 1, true) or name:find(FX_NAME_CLEAN, 1, true)) then
      return fx
    end
  end
  return -1
end

local function maybe_load(track, force)
  if not track then return -1 end
  local fx = find_fx(track)
  if fx >= 0 and not force then return fx end
  reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", math.max(16, reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")))
  fx = reaper.TrackFX_AddByName(track, "JS: " .. FX_NAME, false, -1)
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, FX_NAME, false, -1) end
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, "JS: " .. FX_NAME_CLEAN, false, -1) end
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, FX_NAME_CLEAN, false, -1) end
  if fx < 0 then
    load_error = "Could not load JSFX. Confirm Effects/s3g is installed or symlinked, then rescan JSFX."
  else
    load_error = ""
  end
  return fx
end

local function normalized_param_name(name)
  name = (name or ""):lower()
  name = name:gsub("%b()", "")
  name = name:gsub("%s+", " ")
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  return name
end

local function resolve_param_indices(track, fx)
  if not track or fx < 0 or not reaper.TrackFX_GetNumParams or not reaper.TrackFX_GetParamName then return end
  local names = {}
  local count = reaper.TrackFX_GetNumParams(track, fx)
  for param = 0, count - 1 do
    local ok, name = reaper.TrackFX_GetParamName(track, fx, param, "")
    if ok and name and name ~= "" then
      names[name] = param
      names[normalized_param_name(name)] = param
    end
  end

  local missing = {}
  for key, expected in pairs(PARAM_NAMES) do
    local found = names[expected] or names[normalized_param_name(expected)]
    if found then
      PARAM[key] = found
    else
      missing[#missing + 1] = expected
    end
  end

  param_warning = ""
  if #missing > 0 then
    param_warning = "This JSFX instance may be stale. Rescan/reinsert if controls behave oddly. Missing: " .. table.concat(missing, ", ")
  end
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

local function slider_param(track, fx, label, param, min_value, max_value, fmt)
  local value = get_param(track, fx, param, min_value)
  ImGui.SetNextItemWidth(ctx, 330)
  local changed, new_value = ImGui.SliderDouble(ctx, label, value, min_value, max_value, fmt)
  if changed then set_param(track, fx, param, new_value) end
  return new_value or value
end

local function set_weighting_mode(track, fx, mode)
  reaper.TrackFX_SetParamNormalized(track, fx, PARAM.weighting, mode / (#WEIGHTING - 1))
end

local function option_buttons(track, fx, title, param, labels, columns)
  local norm = fx >= 0 and reaper.TrackFX_GetParamNormalized(track, fx, param) or 0
  local current = math.floor(norm * (#labels - 1) + 0.5) + 1
  columns = columns or #labels
  ImGui.TextColored(ctx, COLORS.muted, title)
  for index, label in ipairs(labels) do
    if index > 1 and ((index - 1) % columns) ~= 0 then ImGui.SameLine(ctx) end
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, current == index and COLORS.active or COLORS.button)
    if ImGui.Button(ctx, label .. "##" .. title .. tostring(index)) then
      reaper.TrackFX_SetParamNormalized(track, fx, param, (index - 1) / math.max(1, #labels - 1))
    end
    ImGui.PopStyleColor(ctx)
  end
end

local function apply_preset(track, fx, preset)
  set_param(track, fx, PARAM.field, preset.field)
  set_param(track, fx, PARAM.method, preset.method)
  set_param(track, fx, PARAM.width, preset.width)
  set_param(track, fx, PARAM.angle, preset.angle)
  set_param(track, fx, PARAM.directivity, preset.directivity)
  set_param(track, fx, PARAM.rear, preset.rear)
  set_param(track, fx, PARAM.height, preset.height)
  set_param(track, fx, PARAM.diffuse, preset.diffuse)
  set_param(track, fx, PARAM.weighting, preset.weighting)
  set_param(track, fx, PARAM.autogain, preset.autogain)
  set_param(track, fx, PARAM.output, preset.output)
end

local function draw_presets(track, fx)
  ImGui.TextColored(ctx, COLORS.muted, "Starting points")
  for index, preset in ipairs(PRESETS) do
    if index > 1 and (index - 1) % 4 ~= 0 then ImGui.SameLine(ctx) end
    if ImGui.Button(ctx, preset.name .. "##preset" .. tostring(index), 132, 26) then
      apply_preset(track, fx, preset)
    end
  end
end

local function peak_to_norm(peak)
  if peak <= 0.000001 then return 0 end
  local db = 20 * math.log(peak) / math.log(10)
  return clamp((db + 60) / 60, 0, 1)
end

local function point_from_az_el(az, el)
  local azr = math.rad(az)
  local elr = math.rad(el)
  return {
    x = -math.sin(azr) * math.cos(elr),
    y = math.cos(azr) * math.cos(elr),
    z = math.sin(elr),
  }
end

local function rotate_point(p)
  local yaw = math.rad(view_yaw_deg)
  local pitch = math.rad(view_pitch_deg)
  local cy = math.cos(yaw)
  local sy = math.sin(yaw)
  local cp = math.cos(pitch)
  local sp = math.sin(pitch)
  local x1 = p.x * cy - p.y * sy
  local y1 = p.x * sy + p.y * cy
  local z1 = p.z
  return { x = x1, y = y1 * cp - z1 * sp, z = y1 * sp + z1 * cp }
end

local function project_point(az, el, cx, cy, radius)
  local p = rotate_point(point_from_az_el(az, el))
  return { x = cx + p.x * radius * view_zoom, y = cy - p.y * radius * view_zoom, z = p.z, az = az, el = el }
end

local function ring_pos(index, count, start_az, el)
  return wrap_degrees(start_az - index * 360 / math.max(1, count)), el
end

local function cube_pos(index)
  local slot = index % 8
  local az = ({ -45, -135, 135, 45, -45, -135, 135, 45 })[slot + 1]
  local el = slot < 4 and -35.2644 or 35.2644
  return az, el
end

local function dodeca_pos(index)
  local points = {
    { -31.717474, 0 }, { -90, -31.717474 }, { -90, 31.717474 }, { -148.282526, 0 },
    { 180, -58.282526 }, { 180, 58.282526 }, { 148.282526, 0 }, { 90, 31.717474 },
    { 90, -31.717474 }, { 31.717474, 0 }, { 0, 58.282526 }, { 0, -58.282526 },
  }
  local p = points[(index % 12) + 1]
  return p[1], p[2]
end

local function dome24_pos(index)
  local slot = index % 24
  if slot < 12 then return ring_pos(slot, 12, -30, 0) end
  if slot < 20 then return ring_pos(slot - 12, 8, -45, 32) end
  return ring_pos(slot - 20, 4, -90, 66.6)
end

local function sphere32_pos(index)
  local frac = (index + 0.5) / 32
  local z = 1 - 2 * frac
  return wrap_degrees(-30 - index * 137.507764), math.deg(math.asin(z))
end

local function virtual_points(layout)
  local count = ({ 4, 8, 12, 24, 32 })[layout + 1] or 24
  local points = {}
  for i = 0, count - 1 do
    local az, el
    if layout == 0 then az, el = ring_pos(i, 4, -45, 0)
    elseif layout == 1 then az, el = cube_pos(i)
    elseif layout == 2 then az, el = dodeca_pos(i)
    elseif layout == 3 then az, el = dome24_pos(i)
    else az, el = sphere32_pos(i) end
    points[#points + 1] = { id = i + 1, az = az, el = el }
  end
  return points
end

local function nudge_camera(label, width, height, apply)
  if ImGui.Button(ctx, label, width, height) or ImGui.IsItemActive(ctx) then apply() end
end

local function reset_camera(yaw, pitch)
  view_yaw_deg = yaw
  view_pitch_deg = pitch
  view_zoom = 1.0
end

local function draw_camera_controls()
  ImGui.BeginGroup(ctx)
  ImGui.Text(ctx, "Camera")
  nudge_camera("up##ambstcam", 68, 24, function() view_pitch_deg = clamp(view_pitch_deg + 4, -180, 180) end)
  nudge_camera("left##ambstcam", 32, 24, function() view_yaw_deg = view_yaw_deg - 4 end)
  ImGui.SameLine(ctx)
  nudge_camera("right##ambstcam", 32, 24, function() view_yaw_deg = view_yaw_deg + 4 end)
  nudge_camera("down##ambstcam", 68, 24, function() view_pitch_deg = clamp(view_pitch_deg - 4, -180, 180) end)
  nudge_camera("-##ambstzoom", 32, 24, function() view_zoom = clamp(view_zoom - 0.025, 0.5, 2.2) end)
  ImGui.SameLine(ctx)
  nudge_camera("+##ambstzoom", 32, 24, function() view_zoom = clamp(view_zoom + 0.025, 0.5, 2.2) end)
  if ImGui.Button(ctx, "3/4##ambstcam", 68, 24) then reset_camera(-35, -42) end
  if ImGui.Button(ctx, "top##ambstcam", 68, 24) then reset_camera(0, 0) end
  if ImGui.Button(ctx, "front##ambstcam", 68, 24) then reset_camera(0, -90) end
  ImGui.EndGroup(ctx)
end

local function draw_pickup_lobe(dl, cx, cy, radius, rotation, facing, mic_el, directivity, method, col, mirror_side)
  local steps = 72
  local prev = nil
  local figure8 = method == 3
  local omni = method == 4
  local lobe_scale = radius * 0.30
  for i = 0, steps do
    local rel = -180 + 360 * i / steps
    local relr = math.rad(rel)
    local response
    if omni then
      response = 1
    elseif figure8 then
      response = math.abs(math.cos(relr))
    else
      local cardioid = 0.5 + 0.5 * math.cos(relr)
      response = (1 - directivity) + directivity * cardioid
    end
    local az = rotation + facing + rel
    local p = project_point(az, mic_el, cx, cy, lobe_scale * response)
    if prev then ImGui.DrawList_AddLine(dl, prev.x, prev.y, p.x, p.y, col, 1.4) end
    prev = p
  end
  local axis = project_point(rotation + facing, mic_el, cx, cy, radius * 0.30)
  ImGui.DrawList_AddLine(dl, cx, cy, axis.x, axis.y, col, 1.0)
  if method == 2 then
    local side_a = project_point(rotation + mirror_side * 90, mic_el, cx, cy, radius * 0.20)
    local side_b = project_point(rotation - mirror_side * 90, mic_el, cx, cy, radius * 0.20)
    ImGui.DrawList_AddLine(dl, side_a.x, side_a.y, side_b.x, side_b.y, color(0.86, 0.78, 0.42, 0.22), 1.2)
  end
end

local function draw_ms_lobes(dl, cx, cy, radius, rotation, mic_el, directivity)
  draw_pickup_lobe(dl, cx, cy, radius, rotation, 0, mic_el, directivity, 0, color(0.95, 0.58, 0.38, 0.50), 1)
  draw_pickup_lobe(dl, cx, cy, radius, rotation, 90, mic_el, 1, 3, color(0.42, 0.74, 0.96, 0.48), 1)
  local mid = project_point(rotation, mic_el, cx, cy, radius * 0.34)
  local side_l = project_point(rotation + 90, mic_el, cx, cy, radius * 0.27)
  local side_r = project_point(rotation - 90, mic_el, cx, cy, radius * 0.27)
  ImGui.DrawList_AddText(dl, mid.x + 6, mid.y - 8, COLORS.pickup_l, "M")
  ImGui.DrawList_AddText(dl, side_l.x + 6, side_l.y - 8, COLORS.pickup_r, "S+")
  ImGui.DrawList_AddText(dl, side_r.x + 6, side_r.y - 8, COLORS.pickup_r, "S-")
  ImGui.DrawList_AddLine(dl, side_l.x, side_l.y, side_r.x, side_r.y, color(0.42, 0.74, 0.96, 0.28), 1.5)
end

local function draw_custom_weight_controls(track, fx)
  local order = math.floor(get_param(track, fx, PARAM.order, 2) + 0.5) + 1
  local mode = math.floor(get_param(track, fx, PARAM.weighting, 1) + 0.5)
  ImGui.Separator(ctx)
  ImGui.Text(ctx, "Custom band weights")
  ImGui.TextColored(ctx, COLORS.muted, mode == 3 and "Custom weighting is active" or "Move a slider to switch Decode weighting to Custom")
  local labels = { "W", "1st", "2nd", "3rd" }
  local params = { PARAM.custom_w, PARAM.custom_o1, PARAM.custom_o2, PARAM.custom_o3 }
  for band = 0, 3 do
    local active = band <= order
    if not active and ImGui.BeginDisabled then ImGui.BeginDisabled(ctx, true) end
    local before = get_param(track, fx, params[band + 1], 100)
    slider_param(track, fx, labels[band + 1] .. " weight", params[band + 1], 0, 100, "%.0f %%")
    if active and get_param(track, fx, params[band + 1], 100) ~= before then
      set_weighting_mode(track, fx, 3)
    end
    if not active and ImGui.EndDisabled then ImGui.EndDisabled(ctx) end
  end
  if ImGui.Button(ctx, "Flat##custom_weights") then
    set_param(track, fx, PARAM.custom_w, 100)
    set_param(track, fx, PARAM.custom_o1, 100)
    set_param(track, fx, PARAM.custom_o2, 100)
    set_param(track, fx, PARAM.custom_o3, 100)
    set_weighting_mode(track, fx, 3)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Max-rE-ish##custom_weights") then
    set_param(track, fx, PARAM.custom_w, 100)
    set_param(track, fx, PARAM.custom_o1, 100)
    set_param(track, fx, PARAM.custom_o2, 82)
    set_param(track, fx, PARAM.custom_o3, 64)
    set_weighting_mode(track, fx, 3)
  end
end

local function draw_visual(track, fx)
  local width = math.max(560, ImGui.GetContentRegionAvail(ctx) - 2)
  local controls_inline = width >= 500
  local control_width = 82
  local control_gap = 10
  local canvas_width = controls_inline and math.max(420, width - control_width - control_gap) or width
  local height = 410
  ImGui.InvisibleButton(ctx, "##ambisonic_stereo_visual", canvas_width, height)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = x0 + canvas_width, y0 + height
  local cx, cy = x0 + canvas_width * 0.5, y0 + height * 0.57
  local radius = math.min(canvas_width, height) * 0.35
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x1, y1, COLORS.bg)
  ImGui.DrawList_AddText(dl, x0 + 14, y0 + 14, COLORS.text, "Ambisonic Stereo Decoder")
  ImGui.DrawList_AddText(dl, x0 + 14, y0 + 34, COLORS.muted, "virtual speaker field -> stereo pickup")

  local layout = math.floor(get_param(track, fx, PARAM.field, 3) + 0.5)
  local rotation = get_param(track, fx, PARAM.rotation, 0)
  local angle = get_param(track, fx, PARAM.angle, 90)
  local mic_el = get_param(track, fx, PARAM.mic_elevation, 0)
  local rotation_image = get_param(track, fx, PARAM.rotation_image, 100)
  local stereo_width = get_param(track, fx, PARAM.width, 100)
  local width_scale = clamp(stereo_width / 100, 0, 2)
  local directivity = clamp(get_param(track, fx, PARAM.directivity, 70) / 100, 0, 1)
  local method = math.floor(get_param(track, fx, PARAM.method, 0) + 0.5)
  local pts = {}
  for _, p in ipairs(virtual_points(layout)) do
    local pp = project_point(p.az, p.el, cx, cy, radius)
    pp.id = p.id
    pts[#pts + 1] = pp
  end
  table.sort(pts, function(a, b) return a.z < b.z end)

  local ring = {}
  for i = 0, 47 do ring[#ring + 1] = project_point(i * 360 / 48, 0, cx, cy, radius) end
  for i = 1, #ring do
    local a, b = ring[i], ring[(i % #ring) + 1]
    ImGui.DrawList_AddLine(dl, a.x, a.y, b.x, b.y, color(0.62, 0.65, 0.68, 0.10), 1)
  end

  local visual_angle = angle * 0.5 * width_scale
  local pickup_radius = radius * (0.34 + 0.20 * width_scale)
  local arc_radius = radius * (0.46 + 0.18 * width_scale)
  local arc_steps = 24
  local arc_prev = nil
  for step = 0, arc_steps do
    local t = step / arc_steps
    local az = rotation - visual_angle + visual_angle * 2 * t
    local p = project_point(az, 0, cx, cy, arc_radius)
    if arc_prev then
      ImGui.DrawList_AddLine(dl, arc_prev.x, arc_prev.y, p.x, p.y, color(0.86, 0.78, 0.42, 0.16 + 0.20 * clamp(width_scale / 2, 0, 1)), 2)
    end
    arc_prev = p
  end

  if method == 2 then
    draw_ms_lobes(dl, cx, cy, radius, rotation, mic_el, directivity)
    ImGui.DrawList_AddCircleFilled(dl, cx, cy, 4, color(0.82, 0.84, 0.84, 0.55), 16)
    ImGui.DrawList_AddText(dl, cx + 12, cy + 10, COLORS.muted, "L = M + S / R = M - S")
  else
    local capsule_offset = (method == 1 or method == 4) and radius * (0.05 + 0.06 * width_scale) or 0
    local left_origin = project_point(rotation + 90, mic_el, cx, cy, capsule_offset)
    local right_origin = project_point(rotation - 90, mic_el, cx, cy, capsule_offset)
    local left_mic = project_point(rotation + visual_angle, mic_el, left_origin.x, left_origin.y, pickup_radius)
    local right_mic = project_point(rotation - visual_angle, mic_el, right_origin.x, right_origin.y, pickup_radius)
    draw_pickup_lobe(dl, left_origin.x, left_origin.y, radius, rotation, visual_angle, mic_el, directivity, method, color(0.95, 0.58, 0.38, 0.46), 1)
    draw_pickup_lobe(dl, right_origin.x, right_origin.y, radius, rotation, -visual_angle, mic_el, directivity, method, color(0.42, 0.74, 0.96, 0.46), -1)
    ImGui.DrawList_AddLine(dl, left_mic.x, left_mic.y, right_mic.x, right_mic.y, color(0.86, 0.78, 0.42, 0.22), 1.5)
    ImGui.DrawList_AddLine(dl, left_origin.x, left_origin.y, left_mic.x, left_mic.y, COLORS.pickup_l, 2)
    ImGui.DrawList_AddLine(dl, right_origin.x, right_origin.y, right_mic.x, right_mic.y, COLORS.pickup_r, 2)
    ImGui.DrawList_AddCircleFilled(dl, cx, cy, 4, color(0.82, 0.84, 0.84, 0.55), 16)
    ImGui.DrawList_AddCircleFilled(dl, left_origin.x, left_origin.y, 3.5, COLORS.pickup_l, 16)
    ImGui.DrawList_AddCircleFilled(dl, right_origin.x, right_origin.y, 3.5, COLORS.pickup_r, 16)
    ImGui.DrawList_AddText(dl, left_mic.x + 6, left_mic.y - 8, COLORS.pickup_l, "L")
    ImGui.DrawList_AddText(dl, right_mic.x + 6, right_mic.y - 8, COLORS.pickup_r, "R")
  end

  local bar_x = x0 + 14
  local bar_y = y0 + height - 28
  local bar_w = 170
  local bar_h = 8
  ImGui.DrawList_AddText(dl, bar_x, bar_y - 18, COLORS.muted, string.format("width %.0f%% / rot %.0f%% / el %.0f", stereo_width, rotation_image, mic_el))
  ImGui.DrawList_AddRectFilled(dl, bar_x, bar_y, bar_x + bar_w, bar_y + bar_h, color(0.10, 0.11, 0.12, 1))
  ImGui.DrawList_AddRectFilled(dl, bar_x, bar_y, bar_x + bar_w * clamp(width_scale / 2, 0, 1), bar_y + bar_h, color(0.86, 0.78, 0.42, 0.74))
  ImGui.DrawList_AddLine(dl, bar_x + bar_w * 0.5, bar_y - 3, bar_x + bar_w * 0.5, bar_y + bar_h + 3, color(0.82, 0.86, 0.88, 0.40), 1)
  local dir_x = bar_x + bar_w + 22
  ImGui.DrawList_AddRectFilled(dl, dir_x, bar_y, dir_x + bar_w, bar_y + bar_h, color(0.10, 0.11, 0.12, 1))
  ImGui.DrawList_AddRectFilled(dl, dir_x, bar_y, dir_x + bar_w * directivity, bar_y + bar_h, color(0.52, 0.78, 0.86, 0.70))
  ImGui.DrawList_AddText(dl, dir_x, bar_y - 18, COLORS.muted, directivity < 0.25 and "omni" or directivity > 0.85 and "cardioid" or "subcardioid")

  for _, p in ipairs(pts) do
    local front = clamp((p.z + 1) * 0.5, 0, 1)
    local size = 2.5 + 2.5 * front
    ImGui.DrawList_AddCircleFilled(dl, p.x, p.y, size + 2, color(0.04, 0.045, 0.05, 0.80), 18)
    ImGui.DrawList_AddCircleFilled(dl, p.x, p.y, size, COLORS.speaker, 18)
    if p.id <= 32 then
      ImGui.DrawList_AddText(dl, p.x + size + 3, p.y - 6, color(0.82, 0.88, 0.90, 0.35 + 0.40 * front), tostring(p.id))
    end
  end

  ImGui.DrawList_AddText(dl, x0 + canvas_width - 255, y0 + 14, COLORS.muted, FIELD[layout + 1] or FIELD[4])
  ImGui.DrawList_AddText(dl, x0 + canvas_width - 255, y0 + 34, COLORS.muted, METHOD[method + 1] or METHOD[1])
  ImGui.DrawList_AddText(dl, x0 + canvas_width - 255, y0 + 54, COLORS.muted, "spk 1 right-front / clockwise")
  ImGui.DrawList_AddText(dl, x0 + canvas_width - 255, y0 + 74, COLORS.muted, "stereo output on channels 1-2")

  if controls_inline then
    ImGui.SameLine(ctx)
    ImGui.Dummy(ctx, control_gap, 1)
    ImGui.SameLine(ctx)
  end
  draw_camera_controls()
end

local function draw_stereo_meter(track, fx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w, h = ImGui.GetContentRegionAvail(ctx), 80
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.InvisibleButton(ctx, "##ambisonic_stereo_meter", w, h)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, COLORS.panel)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, COLORS.edge)
  ImGui.DrawList_AddText(dl, x + 12, y + 10, COLORS.text, "Stereo output")
  for ch = 0, 1 do
    local mx = x + 128 + ch * 42
    local norm = peak_to_norm(reaper.Track_GetPeakInfo(track, ch) or 0)
    ImGui.DrawList_AddRectFilled(dl, mx, y + 16, mx + 24, y + h - 18, COLORS.bg)
    ImGui.DrawList_AddRectFilled(dl, mx, y + 16 + (h - 34) * (1 - norm), mx + 24, y + h - 18, COLORS.meter)
    ImGui.DrawList_AddRect(dl, mx, y + 16, mx + 24, y + h - 18, COLORS.edge)
    ImGui.DrawList_AddText(dl, mx + 7, y + h - 16, COLORS.muted, ch == 0 and "L" or "R")
  end
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 820, 900, ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, "Ambisonic Stereo Decoder", open)
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
      if fx < 0 then fx = maybe_load(track, false) end
      if fx < 0 then
        ImGui.Text(ctx, load_error ~= "" and load_error or ("JS: " .. FX_NAME .. " is not on the selected track."))
      else
        resolve_param_indices(track, fx)
        if param_warning ~= "" then
          ImGui.TextColored(ctx, color(0.95, 0.70, 0.35, 1), param_warning)
        end
        reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", math.max(16, reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")))
        draw_visual(track, fx)
        draw_stereo_meter(track, fx)
        if ImGui.CollapsingHeader(ctx, "Presets", nil, ImGui.TreeNodeFlags_DefaultOpen) then
          draw_presets(track, fx)
        end
        if ImGui.CollapsingHeader(ctx, "Ambisonic Decode", nil, ImGui.TreeNodeFlags_DefaultOpen) then
          option_buttons(track, fx, "Ambisonic order", PARAM.order, ORDER, 3)
          option_buttons(track, fx, "Virtual speaker field", PARAM.field, FIELD, 3)
          option_buttons(track, fx, "Decode weighting", PARAM.weighting, WEIGHTING, 4)
          draw_custom_weight_controls(track, fx)
        end
        if ImGui.CollapsingHeader(ctx, "Stereo Pickup", nil, ImGui.TreeNodeFlags_DefaultOpen) then
          option_buttons(track, fx, "Stereo method", PARAM.method, METHOD, 3)
          slider_param(track, fx, "Stereo width", PARAM.width, 0, 200, "%.0f %%")
          slider_param(track, fx, "Mic angle", PARAM.angle, 20, 140, "%.0f deg")
          slider_param(track, fx, "Listening rotation", PARAM.rotation, -180, 180, "%.1f deg")
          slider_param(track, fx, "Rotation image", PARAM.rotation_image, 0, 200, "%.0f %%")
          slider_param(track, fx, "Mic elevation", PARAM.mic_elevation, -90, 90, "%.1f deg")
          slider_param(track, fx, "Directivity", PARAM.directivity, 0, 100, "%.0f %%")
          slider_param(track, fx, "Rear rejection", PARAM.rear, 0, 100, "%.0f %%")
          slider_param(track, fx, "Front/rear balance", PARAM.front_rear, -100, 100, "%.0f %%")
          option_buttons(track, fx, "Rear fold", PARAM.rear_mode, REAR_MODE, 3)
          slider_param(track, fx, "Height fold", PARAM.height, 0, 100, "%.0f %%")
          option_buttons(track, fx, "Height image", PARAM.height_mode, HEIGHT_MODE, 4)
          slider_param(track, fx, "Diffuse blend", PARAM.diffuse, 0, 100, "%.0f %%")
          slider_param(track, fx, "A/B spacing", PARAM.ab_spacing, 0, 120, "%.0f cm")
        end
        if ImGui.CollapsingHeader(ctx, "Output", nil, ImGui.TreeNodeFlags_DefaultOpen) then
          option_buttons(track, fx, "Autogain", PARAM.autogain, AUTOGAIN, 3)
          option_buttons(track, fx, "Extra channel output", PARAM.extra, EXTRA, 2)
          slider_param(track, fx, "Bass mono below", PARAM.bass_mono, 0, 300, "%.0f Hz")
          slider_param(track, fx, "Output gain", PARAM.output, -24, 24, "%.1f dB")
        end
        ImGui.TextColored(ctx, COLORS.muted, "Stereo decoder for loudspeaker monitoring or renders; not a binaural headphone decoder.")
      end
    end
    ImGui.End(ctx)
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
