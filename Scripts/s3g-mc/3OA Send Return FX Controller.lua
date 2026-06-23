-- @description 3OA Send/Return FX Controller
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; JSFX: s3g 3OA Send, s3g 3OA Return Mask, s3g 3OA Mixer
-- @category Spatial / HOA
-- @method Requires SPARTA AmbiDEC before Send, set to MMD, and SPARTA AmbiENC after Mixer; both must load the included 24-point JSON layouts.
-- @about
--   ReaImGui companion controller for a 3OA 24-channel insert lane.
--   Use on a 72-channel 3OA FX track with:
--   1. JS: s3g 3OA Send
--   2. one 24-channel effect insert
--   3. JS: s3g 3OA Return Mask
--   4. JS: s3g 3OA Mixer
--   Requires an ambisonic decoder and encoder around the 24-channel virtual
--   speaker lane. Recommended: SPARTA AmbiDEC before JS: s3g 3OA Send, and
--   SPARTA AmbiENC after JS: s3g 3OA Mixer. Set AmbiDEC to MMD / multi-mode
--   decoder for the custom irregular 24-point virtual speaker cloud. Both
--   plugins must load the included 24-point coordinate JSON layouts from this
--   script folder's sparta_json directory.
--   The effect must be inserted between Send and Return Mask so it processes
--   the masked 24-channel send before the return mask and mixer recombine it.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "3OA Send Return FX Controller", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local ctx = ImGui.CreateContext("3OA Send Return FX Controller")
local open = true
local PROJECT = 0

local SEND_NAME = "s3g 3OA Send"
local RETURN_NAME = "s3g 3OA Return Mask"
local MIXER_NAME = "s3g 3OA Mixer"
local LEGACY_FX_NAMES = {
  ["s3g 3OA Send"] = { "3OA Send", "s3g/3OA Send" },
  ["s3g 3OA Return Mask"] = { "3OA Return Mask", "s3g/3OA Return/Mask" },
  ["s3g 3OA Mixer"] = { "3OA Mixer", "s3g/3OA Mixer" },
}
local MASK_GMEM_NAME = "s3g_3oa_mask_meter"

local link_send_return = true
local link_mask_shape = true
local dragging_direction = nil
local dragging_mode = nil
local active_direction = "send"
local mask_gmem_attached = false
local view_yaw_deg = -35
local view_pitch_deg = 55
local view_roll_deg = 0
local view_zoom = 1.0

local PARAM = {
  send = {
    az = 0, el = 1, smooth = 2, width = 3, focus = 4, level = 5,
    floor = 6, rear = 7, comp = 8, gamma = 9, dry = 10, monitor = 11,
  },
  ret = {
    az = 0, el = 1, smooth = 2, width = 3, focus = 4, level = 5,
    floor = 6, rear = 7, comp = 8, gamma = 9, in_bank = 10, out_bank = 11, monitor = 12, route = 13,
  },
  mix = {
    insert = 0, wet = 1, dry = 2, out = 3, contrast = 4, ceiling = 5,
    curve = 6, limiter = 7, attack = 8, release = 9, mask = 10,
  }
}

local speakers = {
  { 0.285652275, 0.000000000, 0.958333333 }, { -0.356977173, 0.327020333, 0.875000000 },
  { 0.053413032, -0.608613947, 0.791666667 }, { 0.429483666, 0.560185389, 0.708333333 },
  { -0.768691718, -0.135970741, 0.625000000 }, { 0.709255111, -0.451170045, 0.541666667 },
  { -0.230731212, 0.858308606, 0.458333333 }, { -0.427272247, -0.822686712, 0.375000000 },
  { 0.898479629, 0.328123319, 0.291666667 }, { -0.904063458, 0.373184253, 0.208333333 },
  { 0.420521661, -0.898630365, 0.125000000 }, { 0.299023957, 0.953335493, 0.041666667 },
  { -0.864459832, -0.500972143, -0.041666667 }, { 0.969015453, -0.213035329, -0.125000000 },
  { -0.562509872, 0.800112409, -0.208333333 }, { -0.122923048, -0.948588678, -0.291666667 },
  { 0.708848590, 0.597418342, -0.375000000 }, { -0.888021405, 0.036722473, -0.458333333 },
  { 0.595837310, -0.592937705, -0.541666667 }, { -0.036058186, 0.779791515, -0.625000000 },
  { -0.452262552, -0.541961689, -0.708333333 }, { 0.605497091, 0.081468777, -0.791666667 },
  { -0.397396334, 0.276498018, -0.875000000 }, { 0.062695352, -0.278687127, -0.958333333 },
}

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local COLORS = {
  bg = color(0.035, 0.04, 0.045, 1),
  panel = color(0.12, 0.14, 0.15, 1),
  line = color(0.54, 0.60, 0.62, 0.82),
  dry = color(0.22, 0.70, 0.90, 1),
  wet = color(0.96, 0.58, 0.20, 1),
  mask = color(0.46, 0.86, 0.60, 1),
  text = color(0.82, 0.88, 0.90, 1),
  muted = color(0.48, 0.55, 0.57, 1),
  warn = color(0.96, 0.42, 0.32, 1),
  node = color(0.36, 0.40, 0.42, 1),
  send = color(0.12, 0.78, 0.95, 1),
  ret = color(0.98, 0.70, 0.18, 1),
}

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
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

local function build_speaker_edges()
  local edges = {}
  local seen = {}
  for i, spk in ipairs(speakers) do
    local nearest = {}
    for j, other in ipairs(speakers) do
      if i ~= j then
        local dx = spk[1] - other[1]
        local dy = spk[2] - other[2]
        local dz = spk[3] - other[3]
        nearest[#nearest + 1] = { id = j, dist = dx * dx + dy * dy + dz * dz }
      end
    end
    table.sort(nearest, function(a, b) return a.dist < b.dist end)
    for n = 1, math.min(4, #nearest) do
      add_unique_edge(edges, seen, i, nearest[n].id)
    end
  end
  return edges
end

local speaker_edges = build_speaker_edges()

local function read_mask_meter()
  if not reaper.gmem_attach or not reaper.gmem_read then return nil end
  if not mask_gmem_attached then
    reaper.gmem_attach(MASK_GMEM_NAME)
    mask_gmem_attached = true
  end
  if reaper.gmem_read(0) ~= 1 then return nil end
  local stamp = reaper.gmem_read(1) or 0
  if reaper.time_precise and stamp > 0 and reaper.time_precise() - stamp > 2 then return nil end
  local values = {}
  for i = 1, 24 do
    values[i] = clamp(reaper.gmem_read(3 + i) or 0, 0, 1)
  end
  return {
    stamp = stamp,
    peak = clamp(reaper.gmem_read(2) or 0, 0, 1),
    peak_ch = clamp(math.floor((reaper.gmem_read(3) or 1) + 0.5), 1, 24),
    values = values,
  }
end

local function find_fx(track, needle)
  if not track then return -1 end
  local legacy_names = LEGACY_FX_NAMES[needle] or {}
  for fx = 0, reaper.TrackFX_GetCount(track) - 1 do
    local ok, name = reaper.TrackFX_GetFXName(track, fx, "")
    if ok then
      if name:find(needle, 1, true) then return fx end
      for _, legacy in ipairs(legacy_names) do
        if name:find(legacy, 1, true) then return fx end
      end
    end
  end
  return -1
end

local function add_jsfx(track, name)
  local fx = reaper.TrackFX_AddByName(track, "JS: " .. name, false, -1)
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, name, false, -1) end
  for _, legacy in ipairs(LEGACY_FX_NAMES[name] or {}) do
    if fx < 0 then fx = reaper.TrackFX_AddByName(track, "JS: " .. legacy, false, -1) end
    if fx < 0 then fx = reaper.TrackFX_AddByName(track, legacy, false, -1) end
  end
  return fx
end

local function pin_fx_to_wet_bank(track, fx)
  if not track or fx < 0 then return false end
  local ok, input_pins, output_pins = reaper.TrackFX_GetIOSize(track, fx)
  if not ok then return false end
  input_pins = input_pins or 0
  output_pins = output_pins or 0
  local max_pins = math.max(input_pins, output_pins)
  for pin = 0, max_pins - 1 do
    local low = pin < 24 and 2 ^ pin or 0
    if pin < input_pins then
      reaper.TrackFX_SetPinMappings(track, fx, 0, pin, low, 0)
    end
    if pin < output_pins then
      reaper.TrackFX_SetPinMappings(track, fx, 1, pin, low, 0)
    end
  end
  return true
end

local function pin_inserts_to_wet_bank(track, send_fx, ret_fx)
  if not track or send_fx < 0 or ret_fx < 0 or send_fx >= ret_fx then return 0 end
  local changed = 0
  for fx = send_fx + 1, ret_fx - 1 do
    if pin_fx_to_wet_bank(track, fx) then changed = changed + 1 end
  end
  return changed
end

local function maybe_load_chain(track)
  if not track then return end
  reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", 72)
  if find_fx(track, SEND_NAME) < 0 then add_jsfx(track, SEND_NAME) end
  if find_fx(track, RETURN_NAME) < 0 then add_jsfx(track, RETURN_NAME) end
  if find_fx(track, MIXER_NAME) < 0 then add_jsfx(track, MIXER_NAME) end
  local send_fx = find_fx(track, SEND_NAME)
  local ret_fx = find_fx(track, RETURN_NAME)
  if send_fx >= 0 then
    reaper.TrackFX_SetParam(track, send_fx, PARAM.send.dry, 1)
    reaper.TrackFX_SetParam(track, send_fx, PARAM.send.monitor, 0)
  end
  if ret_fx >= 0 then
    reaper.TrackFX_SetParam(track, ret_fx, PARAM.ret.in_bank, 0)
    reaper.TrackFX_SetParam(track, ret_fx, PARAM.ret.out_bank, 0)
    reaper.TrackFX_SetParam(track, ret_fx, PARAM.ret.monitor, 1)
    reaper.TrackFX_SetParam(track, ret_fx, PARAM.ret.route, 1)
  end
  local mix_fx = find_fx(track, MIXER_NAME)
  if mix_fx >= 0 then
    reaper.TrackFX_SetParam(track, mix_fx, PARAM.mix.insert, 1)
    reaper.TrackFX_SetParam(track, mix_fx, PARAM.mix.wet, 1.00)
    reaper.TrackFX_SetParam(track, mix_fx, PARAM.mix.dry, 0.65)
    reaper.TrackFX_SetParam(track, mix_fx, PARAM.mix.out, 0.90)
    reaper.TrackFX_SetParam(track, mix_fx, PARAM.mix.ceiling, 0.92)
    reaper.TrackFX_SetParam(track, mix_fx, PARAM.mix.curve, 0.00)
  end
  pin_inserts_to_wet_bank(track, send_fx, ret_fx)
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

local function sync_return_shape_to_send(track, send_fx, ret_fx)
  if not track or send_fx < 0 or ret_fx < 0 then return end
  set_param(track, ret_fx, PARAM.ret.width, get_param(track, send_fx, PARAM.send.width, 0.75))
  set_param(track, ret_fx, PARAM.ret.focus, get_param(track, send_fx, PARAM.send.focus, 0.05))
  set_param(track, ret_fx, PARAM.ret.rear, get_param(track, send_fx, PARAM.send.rear, 1))
end

local function sync_send_shape_to_return(track, send_fx, ret_fx)
  if not track or send_fx < 0 or ret_fx < 0 then return end
  set_param(track, send_fx, PARAM.send.width, get_param(track, ret_fx, PARAM.ret.width, 0.85))
  set_param(track, send_fx, PARAM.send.focus, get_param(track, ret_fx, PARAM.ret.focus, 0))
  set_param(track, send_fx, PARAM.send.rear, get_param(track, ret_fx, PARAM.ret.rear, 1))
end

local function slider(track, fx, label, param, lo, hi, fmt)
  local value = get_param(track, fx, param, lo)
  local changed, new_value = ImGui.SliderDouble(ctx, label, value, lo, hi, fmt or "%.2f")
  if changed then set_param(track, fx, param, new_value) end
  return changed, new_value
end

local function checkbox_param(track, fx, label, param)
  local enabled = get_param(track, fx, param, 0) >= 0.5
  local changed, new_value = ImGui.Checkbox(ctx, label, enabled)
  if changed then set_param(track, fx, param, new_value and 1 or 0) end
  return new_value
end

local function return_mask_value(spk, az, el, width, focus, beam_floor, rear_reject)
  local azr = math.rad(az)
  local elr = math.rad(el)
  local tx = math.cos(elr) * math.cos(azr)
  local ty = math.cos(elr) * math.sin(azr)
  local tz = math.sin(elr)
  local dot = clamp(spk[1] * tx + spk[2] * ty + spk[3] * tz, -1, 1)
  local reject_shape = rear_reject ^ 0.75
  local cone_edge = reject_shape * (0.35 + ((1 - width) ^ 1.15) * 0.55)
  local beam_pow = 1 + ((1 - width) ^ 1.5) * 20 + focus * 20
  local steep = 1 + focus * 4
  local f = clamp((dot - cone_edge) / math.max(0.000001, 1 - cone_edge), 0, 1)
  return clamp((beam_floor * f + (1 - beam_floor) * (f ^ beam_pow)) ^ steep, 0, 1)
end

local function draw_direction_dot(draw_list, x, y, label, col, is_active, lower)
  local r = is_active and 13 or 11
  if lower then
    ImGui.DrawList_AddCircleFilled(draw_list, x, y, r - 3, color(0.16, 0.10, 0.09, 0.82), 32)
    ImGui.DrawList_AddCircle(draw_list, x, y, r + 3, COLORS.warn, 32, 2)
  else
    ImGui.DrawList_AddCircleFilled(draw_list, x, y, r, col, 32)
  end
  if is_active then
    ImGui.DrawList_AddCircle(draw_list, x, y, 17, COLORS.text, 32, 2)
  end
  ImGui.DrawList_AddText(draw_list, x + 13, y - 8, col, label)
end

local function rotate_point(p)
  local yaw = math.rad(view_yaw_deg)
  local pitch = math.rad(view_pitch_deg - 90)
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

local function project_cartesian(p, cx, cy, radius)
  local r = rotate_point(p)
  return {
    x = cx + r.x * radius * view_zoom,
    y = cy - r.y * radius * view_zoom,
    z = r.z,
  }
end

local function speaker_projected_point(spk, cx, cy, radius)
  return project_cartesian({ x = -spk[2], y = spk[1], z = spk[3] }, cx, cy, radius)
end

local function direction_projected_point(az, el, cx, cy, radius)
  local azr = math.rad(az)
  local elr = math.rad(el)
  return project_cartesian({
    x = -math.sin(azr) * math.cos(elr),
    y = math.cos(azr) * math.cos(elr),
    z = math.sin(elr),
  }, cx, cy, radius)
end

local function direction_from_projected_xy(mx, my, cx, cy, radius)
  local best_az = 0
  local best_el = 0
  local best_distance_sq = math.huge

  local function test_candidate(az, el)
    local p = direction_projected_point(az, el, cx, cy, radius)
    local dx = mx - p.x
    local dy = my - p.y
    local distance_sq = dx * dx + dy * dy
    if distance_sq < best_distance_sq then
      best_distance_sq = distance_sq
      best_az = az
      best_el = el
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

  if best_az > 179.9 then best_az = best_az - 360 end
  if best_az < -179.9 then best_az = best_az + 360 end
  return clamp(best_az, -179.9, 179.9), clamp(best_el, -90, 90)
end

local function draw_speaker_geometry(draw_list, by_id)
  for _, edge in ipairs(speaker_edges) do
    local a = by_id[edge[1]]
    local b = by_id[edge[2]]
    if a and b then
      local front = clamp(((a.z + b.z) * 0.5 + 1) * 0.5, 0, 1)
      ImGui.DrawList_AddLine(draw_list, a.x, a.y, b.x, b.y, color(0.58, 0.64, 0.66, 0.08 + front * 0.22), 1)
    end
  end
end

local function draw_direction_map(track, send_fx, ret_fx)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local width = ImGui.GetContentRegionAvail(ctx)
  local height = 320
  local cx = x0 + width * 0.5
  local cy = y0 + height * 0.53
  local radius = math.min(width, height) * 0.36
  local send_az = get_param(track, send_fx, PARAM.send.az, 0)
  local send_el = get_param(track, send_fx, PARAM.send.el, 0)
  local ret_az = get_param(track, ret_fx, PARAM.ret.az, 0)
  local ret_el = get_param(track, ret_fx, PARAM.ret.el, 0)
  local ret_width = get_param(track, ret_fx, PARAM.ret.width, 0.85)
  local ret_focus = get_param(track, ret_fx, PARAM.ret.focus, 0)
  local ret_floor = get_param(track, ret_fx, PARAM.ret.floor, 0.03)
  local ret_rear = get_param(track, ret_fx, PARAM.ret.rear, 1)
  local live_mask = read_mask_meter()

  ImGui.InvisibleButton(ctx, "direction_map_canvas", width, height)
  local hovered = ImGui.IsItemHovered(ctx)
  local mx, my = ImGui.GetMousePos(ctx)

  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x0 + width, y0 + height, COLORS.bg)
  ImGui.DrawList_AddCircleFilled(draw_list, cx, cy, radius, color(0.08, 0.10, 0.11, 1), 96)
  ImGui.DrawList_AddCircle(draw_list, cx, cy, radius, color(0.54, 0.60, 0.62, 0.28), 96, 1)

  local max_mask = 0
  local max_mask_i = 1
  local projected = {}
  local projected_by_id = {}
  for i, spk in ipairs(speakers) do
    local p = speaker_projected_point(spk, cx, cy, radius)
    local item = { id = i, x = p.x, y = p.y, z = p.z, source_z = spk[3], spk = spk }
    projected[#projected + 1] = item
    projected_by_id[i] = item
  end
  table.sort(projected, function(a, b) return a.z < b.z end)
  draw_speaker_geometry(draw_list, projected_by_id)

  for _, speaker in ipairs(projected) do
    local i = speaker.id
    local spk = speaker.spk
    local sx, sy = speaker.x, speaker.y
    local front = clamp((speaker.z + 1) * 0.5, 0, 1)
    local lower = speaker.source_z < 0
    local predicted_mask = return_mask_value(spk, ret_az, ret_el, ret_width, ret_focus, ret_floor, ret_rear)
    local mask = live_mask and live_mask.values[i] or predicted_mask
    local c = lower and color(0.58, 0.42, 0.38, 0.48) or color(0.42 + front * 0.30, 0.45 + front * 0.30, 0.48 + front * 0.30, 0.45 + front * 0.45)
    local size = lower and 3.5 + front * 2 or 4 + front * 3
    if mask > max_mask then
      max_mask = mask
      max_mask_i = i
    end
    if mask > 0.001 then
      local glow = 4 + mask * 18
      ImGui.DrawList_AddCircleFilled(draw_list, sx, sy, glow, color(0.18, 0.88, 0.42, 0.07 + mask * 0.28), 32)
      ImGui.DrawList_AddCircle(draw_list, sx, sy, glow + 2, color(0.46, 0.86, 0.60, 0.04 + mask * 0.22), 32, 1.4)
    end
    ImGui.DrawList_AddCircleFilled(draw_list, sx, sy, size, c, 16)
    if mask > 0.03 then
      ImGui.DrawList_AddCircle(draw_list, sx, sy, size + 4 + mask * 7, color(0.46, 0.86, 0.60, 0.20 + mask * 0.55), 24, 1.5)
    end
    if lower then
      ImGui.DrawList_AddCircle(draw_list, sx, sy, size + 2, color(0.96, 0.42, 0.32, 0.30), 16, 1)
    end
    if i <= 24 then ImGui.DrawList_AddText(draw_list, sx + 6, sy - 6, color(0.82, 0.88, 0.90, 0.35), tostring(i)) end
  end

  local send_p = direction_projected_point(send_az, send_el, cx, cy, radius)
  local ret_p = direction_projected_point(ret_az, ret_el, cx, cy, radius)
  local sx, sy = send_p.x, send_p.y
  local rx, ry = ret_p.x, ret_p.y
  local elev_x = x0 + width - 44
  local elev_top = cy - radius
  local elev_bot = cy + radius
  local function elev_y(el)
    return cy - clamp(el, -90, 90) / 90 * radius
  end
  local function elev_from_y(y)
    return clamp((cy - y) / radius * 90, -90, 90)
  end

  if hovered and ImGui.IsMouseClicked(ctx, 0) then
    local side_ds = math.sqrt((mx - elev_x) * (mx - elev_x) + (my - elev_y(send_el)) * (my - elev_y(send_el)))
    local side_dr = math.sqrt((mx - elev_x) * (mx - elev_x) + (my - elev_y(ret_el)) * (my - elev_y(ret_el)))
    if mx > elev_x - 26 and mx < elev_x + 72 and my >= elev_top - 18 and my <= elev_bot + 18 then
      dragging_mode = "elevation"
      dragging_direction = side_ds <= side_dr and "send" or "return"
    else
      dragging_mode = "map"
      local ds = math.sqrt((mx - sx) * (mx - sx) + (my - sy) * (my - sy))
      local dr = math.sqrt((mx - rx) * (mx - rx) + (my - ry) * (my - ry))
      if ds < 28 or dr < 28 then
        dragging_direction = ds <= dr and "send" or "return"
      else
        local dx = mx - cx
        local dy = my - cy
        dragging_direction = math.sqrt(dx * dx + dy * dy) <= radius * view_zoom * 1.15 and active_direction or nil
      end
    end
    if dragging_direction then active_direction = dragging_direction end
  end
  if dragging_direction and ImGui.IsMouseDown(ctx, 0) then
    if dragging_mode == "elevation" then
      local new_el = elev_from_y(my)
      if dragging_direction == "send" then
        set_param(track, send_fx, PARAM.send.el, new_el)
        if link_send_return then
          set_param(track, ret_fx, PARAM.ret.el, new_el)
        end
        send_el = new_el
        if link_send_return then ret_el = new_el end
      else
        set_param(track, ret_fx, PARAM.ret.el, new_el)
        if link_send_return then
          set_param(track, send_fx, PARAM.send.el, new_el)
        end
        ret_el = new_el
        if link_send_return then send_el = new_el end
      end
    else
      local new_az, new_el = direction_from_projected_xy(mx, my, cx, cy, radius)
      if dragging_direction == "send" then
        set_param(track, send_fx, PARAM.send.az, new_az)
        set_param(track, send_fx, PARAM.send.el, new_el)
        if link_send_return then
          set_param(track, ret_fx, PARAM.ret.az, new_az)
          set_param(track, ret_fx, PARAM.ret.el, new_el)
        end
        send_az = new_az
        send_el = new_el
        if link_send_return then
          ret_az = new_az
          ret_el = new_el
        end
      else
        set_param(track, ret_fx, PARAM.ret.az, new_az)
        set_param(track, ret_fx, PARAM.ret.el, new_el)
        if link_send_return then
          set_param(track, send_fx, PARAM.send.az, new_az)
          set_param(track, send_fx, PARAM.send.el, new_el)
        end
        ret_az = new_az
        ret_el = new_el
        if link_send_return then
          send_az = new_az
          send_el = new_el
        end
      end
    end
    send_p = direction_projected_point(send_az, send_el, cx, cy, radius)
    ret_p = direction_projected_point(ret_az, ret_el, cx, cy, radius)
    sx, sy = send_p.x, send_p.y
    rx, ry = ret_p.x, ret_p.y
  end
  if not ImGui.IsMouseDown(ctx, 0) then
    dragging_direction = nil
    dragging_mode = nil
  end

  ImGui.DrawList_AddLine(draw_list, cx, cy, sx, sy, COLORS.send, 2.2)
  ImGui.DrawList_AddLine(draw_list, cx, cy, rx, ry, COLORS.ret, 2.2)
  draw_direction_dot(draw_list, sx, sy, "S", COLORS.send, active_direction == "send", send_el < 0)
  draw_direction_dot(draw_list, rx, ry, "R", COLORS.ret, active_direction == "return", ret_el < 0)

  ImGui.DrawList_AddLine(draw_list, elev_x, elev_top, elev_x, elev_bot, COLORS.line, 1.5)
  ImGui.DrawList_AddLine(draw_list, elev_x - 9, cy, elev_x + 9, cy, color(0.54, 0.60, 0.62, 0.40), 1)
  ImGui.DrawList_AddText(draw_list, elev_x + 12, elev_top - 7, color(0.82, 0.88, 0.90, 0.48), "+90")
  ImGui.DrawList_AddText(draw_list, elev_x + 12, cy - 7, color(0.82, 0.88, 0.90, 0.48), "0")
  ImGui.DrawList_AddText(draw_list, elev_x + 12, elev_bot - 7, color(0.82, 0.88, 0.90, 0.48), "-90")
  draw_direction_dot(draw_list, elev_x, elev_y(send_el), "S", COLORS.send, active_direction == "send", send_el < 0)
  draw_direction_dot(draw_list, elev_x, elev_y(ret_el), "R", COLORS.ret, active_direction == "return", ret_el < 0)

  ImGui.DrawList_AddText(draw_list, x0 + 12, y0 + 12, COLORS.text, "Send / Return direction")
  ImGui.DrawList_AddText(draw_list, x0 + 12, y0 + 32, COLORS.muted, "3/4 speaker-shell view; right strip shows elevation height.")
  ImGui.DrawList_AddText(draw_list, x0 + width - 240, y0 + 12, COLORS.send, string.format("S %.1f az / %.1f el", send_az, send_el))
  ImGui.DrawList_AddText(draw_list, x0 + width - 240, y0 + 32, COLORS.ret, string.format("R %.1f az / %.1f el", ret_az, ret_el))
  if live_mask then
    ImGui.DrawList_AddText(draw_list, x0 + 12, y0 + height - 24, COLORS.mask, string.format("Live mask peak ch %d  %.2f", live_mask.peak_ch, live_mask.peak))
  else
    ImGui.DrawList_AddText(draw_list, x0 + 12, y0 + height - 24, COLORS.mask, string.format("Predicted mask peak ch %d  %.2f", max_mask_i, max_mask))
  end
end

local function draw_linked_direction(track, send_fx, ret_fx)
  local send_az = get_param(track, send_fx, PARAM.send.az, 0)
  local send_el = get_param(track, send_fx, PARAM.send.el, 0)
  local ret_az = get_param(track, ret_fx, PARAM.ret.az, send_az)
  local ret_el = get_param(track, ret_fx, PARAM.ret.el, send_el)

  local changed
  changed, link_send_return = ImGui.Checkbox(ctx, "Lock send and return az/el", link_send_return)
  ImGui.SameLine(ctx)
  changed, link_mask_shape = ImGui.Checkbox(ctx, "Lock mask shape", link_mask_shape)
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Copy send -> return") then
    set_param(track, ret_fx, PARAM.ret.az, send_az)
    set_param(track, ret_fx, PARAM.ret.el, send_el)
    sync_return_shape_to_send(track, send_fx, ret_fx)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Copy return -> send") then
    set_param(track, send_fx, PARAM.send.az, ret_az)
    set_param(track, send_fx, PARAM.send.el, ret_el)
    sync_send_shape_to_return(track, send_fx, ret_fx)
  end

  if link_send_return then
    ImGui.Text(ctx, "Drag in the speaker map above to set linked azimuth/elevation.")
    local az = send_az
    local el = send_el
    local changed_az, new_az = ImGui.SliderDouble(ctx, "Linked azimuth (+L / -R)", az, -179.9, 179.9, "%.1f deg")
    local changed_el, new_el = ImGui.SliderDouble(ctx, "Linked elevation", el, -90, 90, "%.1f deg")
    if changed_az then
      set_param(track, send_fx, PARAM.send.az, new_az)
      set_param(track, ret_fx, PARAM.ret.az, new_az)
    end
    if changed_el then
      set_param(track, send_fx, PARAM.send.el, new_el)
      set_param(track, ret_fx, PARAM.ret.el, new_el)
    end
    if math.abs(ret_az - send_az) > 0.0001 then set_param(track, ret_fx, PARAM.ret.az, send_az) end
    if math.abs(ret_el - send_el) > 0.0001 then set_param(track, ret_fx, PARAM.ret.el, send_el) end
  else
    if ImGui.Button(ctx, active_direction == "send" and "Editing Send" or "Edit Send") then
      active_direction = "send"
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, active_direction == "return" and "Editing Return" or "Edit Return") then
      active_direction = "return"
    end
    ImGui.Text(ctx, "Click or drag in the speaker map above to set the active target.")
    slider(track, send_fx, "Send azimuth (+L / -R)", PARAM.send.az, -179.9, 179.9, "%.1f deg")
    slider(track, send_fx, "Send elevation", PARAM.send.el, -90, 90, "%.1f deg")
    slider(track, ret_fx, "Return azimuth (+L / -R)", PARAM.ret.az, -179.9, 179.9, "%.1f deg")
    slider(track, ret_fx, "Return elevation", PARAM.ret.el, -90, 90, "%.1f deg")
  end
end

local function draw_view_controls()
  if ImGui.Button(ctx, "3/4 view") then
    view_yaw_deg = -35
    view_pitch_deg = 55
    view_roll_deg = 0
    view_zoom = 1.0
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Top") then
    view_yaw_deg = 0
    view_pitch_deg = 90
    view_roll_deg = 0
    view_zoom = 1.0
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Side") then
    view_yaw_deg = 0
    view_pitch_deg = 0
    view_roll_deg = 0
    view_zoom = 1.0
  end
  local changed
  changed, view_yaw_deg = ImGui.SliderDouble(ctx, "Yaw", view_yaw_deg, -180, 180, "%.0f deg")
  changed, view_pitch_deg = ImGui.SliderDouble(ctx, "Pitch", view_pitch_deg, -90, 90, "%.0f deg")
end

local function draw_controls(track, send_fx, ret_fx, mix_fx)
  if link_mask_shape then
    sync_return_shape_to_send(track, send_fx, ret_fx)
  end

  if ImGui.CollapsingHeader(ctx, "Direction", nil, ImGui.TreeNodeFlags_DefaultOpen) then
    draw_linked_direction(track, send_fx, ret_fx)
  end

  if ImGui.CollapsingHeader(ctx, "View") then
    draw_view_controls()
  end

  if ImGui.CollapsingHeader(ctx, "Send Mask", nil, ImGui.TreeNodeFlags_DefaultOpen) then
    slider(track, send_fx, link_mask_shape and "Width##linked_shape" or "Send width", PARAM.send.width, 0, 1, "%.3f")
    slider(track, send_fx, link_mask_shape and "Focus##linked_shape" or "Send focus", PARAM.send.focus, 0, 1, "%.3f")
    slider(track, send_fx, "Send level", PARAM.send.level, 0, 1, "%.3f")
    slider(track, send_fx, "Send smoothing", PARAM.send.smooth, 0, 1, "%.3f")
    slider(track, send_fx, "Send beam floor", PARAM.send.floor, 0, 0.25, "%.3f")
    slider(track, send_fx, link_mask_shape and "Rear reject##linked_shape" or "Send rear reject", PARAM.send.rear, 0, 1, "%.3f")
    slider(track, send_fx, "Send energy comp", PARAM.send.comp, 0, 1, "%.3f")
    slider(track, send_fx, "Send mask gamma", PARAM.send.gamma, 0.25, 4, "%.3f")
    checkbox_param(track, send_fx, "Dry copy to 25-48", PARAM.send.dry)
    checkbox_param(track, send_fx, "Write send mask monitor 49-72", PARAM.send.monitor)
  end

  if ImGui.CollapsingHeader(ctx, "Return Mask", nil, ImGui.TreeNodeFlags_DefaultOpen) then
    if link_mask_shape then
      ImGui.Text(ctx, string.format("Shape locked: width %.3f   focus %.3f   rear %.3f",
        get_param(track, ret_fx, PARAM.ret.width, 0),
        get_param(track, ret_fx, PARAM.ret.focus, 0),
        get_param(track, ret_fx, PARAM.ret.rear, 0)))
    else
      slider(track, ret_fx, "Return width", PARAM.ret.width, 0, 1, "%.3f")
      slider(track, ret_fx, "Return focus", PARAM.ret.focus, 0, 1, "%.3f")
      slider(track, ret_fx, "Return rear reject", PARAM.ret.rear, 0, 1, "%.3f")
    end
    slider(track, ret_fx, "Return level", PARAM.ret.level, 0, 1, "%.3f")
    slider(track, ret_fx, "Return smoothing", PARAM.ret.smooth, 0, 1, "%.3f")
    slider(track, ret_fx, "Return beam floor", PARAM.ret.floor, 0, 0.25, "%.3f")
    slider(track, ret_fx, "Return energy comp", PARAM.ret.comp, 0, 1, "%.3f")
    slider(track, ret_fx, "Return mask gamma", PARAM.ret.gamma, 0.25, 4, "%.3f")
    checkbox_param(track, ret_fx, "Re-place wet through return mask", PARAM.ret.route)
    ImGui.Text(ctx, "Return emits wet 1-24, dry thru 25-48, and return mask 49-72.")
    checkbox_param(track, ret_fx, "Write return mask 49-72", PARAM.ret.monitor)
  end

  if ImGui.CollapsingHeader(ctx, "Mixer", nil, ImGui.TreeNodeFlags_DefaultOpen) then
    checkbox_param(track, mix_fx, "Insert duck mode", PARAM.mix.insert)
    slider(track, mix_fx, "Wet trim", PARAM.mix.wet, 0, 1, "%.3f")
    slider(track, mix_fx, "Dry trim", PARAM.mix.dry, 0, 1, "%.3f")
    slider(track, mix_fx, "Output trim", PARAM.mix.out, 0, 1, "%.3f")
    slider(track, mix_fx, "Mask contrast", PARAM.mix.contrast, 0, 1, "%.3f")
    slider(track, mix_fx, "Mask ceiling", PARAM.mix.ceiling, 0.5, 1, "%.3f")
    slider(track, mix_fx, "Duck curve", PARAM.mix.curve, 0, 1, "%.3f")
    slider(track, mix_fx, "Wet limiter", PARAM.mix.limiter, 0, 1, "%.3f")
    slider(track, mix_fx, "Mask attack lag", PARAM.mix.attack, 0, 1, "%.3f")
    slider(track, mix_fx, "Mask release lag", PARAM.mix.release, 0, 1, "%.3f")
    checkbox_param(track, mix_fx, "Write smoothed mask 49-72", PARAM.mix.mask)
  end
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 920, 860, ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, "3OA Send Return FX Controller", open)
  if visible then
    local track = reaper.GetSelectedTrack(PROJECT, 0)
    if not track then
      ImGui.Text(ctx, "Select the track that contains the HOA FX chain.")
    else
      local _, name = reaper.GetTrackName(track)
      local nchan = math.floor(reaper.GetMediaTrackInfo_Value(track, "I_NCHAN") + 0.5)
      local send_fx = find_fx(track, SEND_NAME)
      local ret_fx = find_fx(track, RETURN_NAME)
      local mix_fx = find_fx(track, MIXER_NAME)
      ImGui.Text(ctx, "Selected track: " .. (name ~= "" and name or "(unnamed)") .. string.format("   %d channels", nchan))
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Load/repair JSFX") then
        maybe_load_chain(track)
        send_fx = find_fx(track, SEND_NAME)
        ret_fx = find_fx(track, RETURN_NAME)
        mix_fx = find_fx(track, MIXER_NAME)
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Pin inserts 1-24") then
        pin_inserts_to_wet_bank(track, send_fx, ret_fx)
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Set track to 72ch") then
        reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", 72)
      end

      if nchan < 72 then
        ImGui.TextColored(ctx, COLORS.warn, "Track is below 72 channels; mask monitor and mixer sidechain channels may not be available.")
      end

      if send_fx < 0 or ret_fx < 0 or mix_fx < 0 then
        ImGui.Text(ctx, "Missing one or more 3OA JSFX. Use Load/repair JSFX.")
      else
        draw_direction_map(track, send_fx, ret_fx)
        draw_controls(track, send_fx, ret_fx, mix_fx)
      end
    end
    ImGui.End(ctx)
  end

  if open then
    reaper.defer(loop)
  end
end

reaper.defer(loop)
