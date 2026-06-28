-- @description 6ch Ambisonic Decoder Router
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; JSFX: s3g 6ch Ambisonic Decoder Router
-- @category 3OAFX
-- @method Companion controller for the package-native 6-channel JSFX decoder/router. Auto-loads the JSFX on the selected track, draws the 6-speaker monitor layout, and exposes ACN/SN3D decode, direct-routing, speaker coordinate, and output controls.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "6ch Ambisonic Decoder Router", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local PROJECT = 0
local FX_NAME = "s3g 6ch Ambisonic Decoder Router"
local FX_NAME_CLEAN = "6ch Ambisonic Decoder Router"
local ctx = ImGui.CreateContext("6ch Ambisonic Decoder Router")
local open = true
local selected_speaker = 1
local view_yaw_deg = -35
local view_pitch_deg = -42
local view_roll_deg = 0
local view_zoom = 1.0
local load_error = ""
local migrated_layout = {}

local MODE_NAMES = { "Ambisonic ACN/SN3D", "Direct 6ch", "Ambisonic + Direct" }
local ORDER_NAMES = { "1OA / 4ch", "2OA / 9ch", "3OA / 16ch" }
local WEIGHT_NAMES = { "Projection", "Energy-normalized", "Max-rE-ish" }
local EXTRA_NAMES = { "Keep extra channels", "Clear extra channels" }

local SPEAKERS = {
  { name = "FL", az_label = "S1 FL azimuth", el_label = "S1 FL elevation", az_param = 9, el_param = 10 },
  { name = "FR", az_label = "S2 FR azimuth", el_label = "S2 FR elevation", az_param = 11, el_param = 12 },
  { name = "BR", az_label = "S3 BR azimuth", el_label = "S3 BR elevation", az_param = 13, el_param = 14 },
  { name = "BL", az_label = "S4 BL azimuth", el_label = "S4 BL elevation", az_param = 15, el_param = 16 },
  { name = "OH-L", az_label = "S5 OH-L azimuth", el_label = "S5 OH-L elevation", az_param = 17, el_param = 18 },
  { name = "OH-R", az_label = "S6 OH-R azimuth", el_label = "S6 OH-R elevation", az_param = 19, el_param = 20 },
}

local DEFAULT_LAYOUT = {
  { az = 45, el = 0 },
  { az = -45, el = 0 },
  { az = -135, el = 0 },
  { az = 135, el = 0 },
  { az = 90, el = 60 },
  { az = -90, el = 60 },
}

local COLORS = {
  bg = ImGui.ColorConvertDouble4ToU32(0.035, 0.039, 0.042, 1),
  panel = ImGui.ColorConvertDouble4ToU32(0.060, 0.066, 0.070, 1),
  edge = ImGui.ColorConvertDouble4ToU32(0.32, 0.35, 0.36, 1),
  grid = ImGui.ColorConvertDouble4ToU32(0.18, 0.20, 0.20, 1),
  text = ImGui.ColorConvertDouble4ToU32(0.78, 0.82, 0.84, 1),
  muted = ImGui.ColorConvertDouble4ToU32(0.48, 0.52, 0.54, 1),
  selected = ImGui.ColorConvertDouble4ToU32(0.96, 0.72, 0.28, 1),
  speaker = ImGui.ColorConvertDouble4ToU32(0.25, 0.70, 0.92, 1),
  overhead = ImGui.ColorConvertDouble4ToU32(0.48, 0.82, 0.62, 1),
}

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a)
end

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function find_fx(track)
  if not track then return -1 end
  local count = reaper.TrackFX_GetCount(track)
  for i = 0, count - 1 do
    local ok, name = reaper.TrackFX_GetFXName(track, i, "")
    if ok and name and (name:find(FX_NAME, 1, true) or name:find(FX_NAME_CLEAN, 1, true)) then
      return i
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

local function resolve_param_indices(track, fx)
  if not track or fx < 0 or not reaper.TrackFX_GetNumParams or not reaper.TrackFX_GetParamName then return end
  local count = reaper.TrackFX_GetNumParams(track, fx)
  local names = {}
  for param = 0, count - 1 do
    local ok, name = reaper.TrackFX_GetParamName(track, fx, param, "")
    if ok and name and name ~= "" then names[name] = param end
  end
  for _, speaker in ipairs(SPEAKERS) do
    speaker.az_param = names[speaker.az_label] or speaker.az_param
    speaker.el_param = names[speaker.el_label] or speaker.el_param
  end
end

local function get_param(track, fx, param)
  return reaper.TrackFX_GetParamNormalized(track, fx, param)
end

local function set_param(track, fx, param, value)
  reaper.TrackFX_SetParamNormalized(track, fx, param, value)
end

local function actual_param(track, fx, param)
  local value = reaper.TrackFX_GetParam(track, fx, param)
  return tonumber(value) or 0
end

local function set_actual(track, fx, param, value, lo, hi)
  local norm = (value - lo) / (hi - lo)
  set_param(track, fx, param, math.max(0, math.min(1, norm)))
end

local function combo_param(track, fx, label, param, names)
  local index = math.floor(get_param(track, fx, param) * (#names - 1) + 0.5) + 1
  if ImGui.BeginCombo(ctx, label, names[index] or "") then
    for i, name in ipairs(names) do
      local selected = i == index
      if ImGui.Selectable(ctx, name, selected) then
        set_param(track, fx, param, (i - 1) / math.max(1, #names - 1))
        index = i
      end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
end

local function slider_actual(track, fx, label, param, lo, hi, fmt)
  local value = actual_param(track, fx, param)
  local changed
  changed, value = ImGui.SliderDouble(ctx, label, value, lo, hi, fmt)
  if changed then set_actual(track, fx, param, value, lo, hi) end
end

local function point_from_az_el(az_deg, el_deg)
  local azr = math.rad(az_deg)
  local elr = math.rad(el_deg)
  return {
    x = -math.sin(azr) * math.cos(elr),
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
  local y2 = y1 * math.cos(pitch) - z1 * math.sin(pitch)
  local z2 = y1 * math.sin(pitch) + z1 * math.cos(pitch)
  return { x = x2 * cr - y2 * sr, y = x2 * sr + y2 * cr, z = z2 }
end

local function project_point(az_deg, el_deg, cx, cy, radius)
  local p = rotate_point(point_from_az_el(az_deg, el_deg))
  return { x = cx + p.x * radius * view_zoom, y = cy - p.y * radius * view_zoom, z = p.z, az = az_deg, el = el_deg }
end

local function draw_edge(dl, points, a, b, alpha)
  local pa = points[a]
  local pb = points[b]
  if not pa or not pb then return end
  local front = clamp(((pa.z + pb.z) * 0.5 + 1) * 0.5, 0, 1)
  ImGui.DrawList_AddLine(dl, pa.x, pa.y, pb.x, pb.y, color(0.66, 0.68, 0.70, (alpha or 0.22) * (0.45 + 0.55 * front)), 1.3)
end

local function draw_reference_ring(dl, cx, cy, radius)
  local ring = {}
  for i = 0, 31 do
    ring[#ring + 1] = project_point(i * 360 / 32, 0, cx, cy, radius)
  end
  for i = 1, #ring do
    local a = ring[i]
    local b = ring[(i % #ring) + 1]
    local front = clamp(((a.z + b.z) * 0.5 + 1) * 0.5, 0, 1)
    ImGui.DrawList_AddLine(dl, a.x, a.y, b.x, b.y, color(0.62, 0.65, 0.68, 0.08 + 0.12 * front), 1.0)
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
  view_zoom = 1.0
end

local function draw_camera_controls()
  ImGui.BeginGroup(ctx)
  ImGui.Text(ctx, "Camera")
  nudge_camera("up##decodercam", 68, 24, function()
    view_pitch_deg = clamp(view_pitch_deg + 4, -180, 180)
  end)
  nudge_camera("left##decodercam", 32, 24, function()
    view_yaw_deg = view_yaw_deg - 4
  end)
  ImGui.SameLine(ctx)
  nudge_camera("right##decodercam", 32, 24, function()
    view_yaw_deg = view_yaw_deg + 4
  end)
  nudge_camera("down##decodercam", 68, 24, function()
    view_pitch_deg = clamp(view_pitch_deg - 4, -180, 180)
  end)
  nudge_camera("-##decoderzoom", 32, 24, function()
    view_zoom = clamp(view_zoom - 0.025, 0.5, 2.2)
  end)
  ImGui.SameLine(ctx)
  nudge_camera("+##decoderzoom", 32, 24, function()
    view_zoom = clamp(view_zoom + 0.025, 0.5, 2.2)
  end)
  if ImGui.Button(ctx, "3/4##decodercam", 68, 24) then reset_camera(-35, -42) end
  if ImGui.Button(ctx, "top##decodercam", 68, 24) then reset_camera(0, 0) end
  if ImGui.Button(ctx, "front##decodercam", 68, 24) then reset_camera(0, -90) end
  ImGui.EndGroup(ctx)
end

local function draw_layout(track, fx)
  local width = math.max(560, ImGui.GetContentRegionAvail(ctx) - 2)
  local control_width = 82
  local control_gap = 10
  local controls_inline = width >= 500
  local canvas_width = controls_inline and math.max(420, width - control_width - control_gap) or width
  local height = 430
  ImGui.InvisibleButton(ctx, "##decoder_layout", canvas_width, height)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = x0 + canvas_width, y0 + height
  local cx, cy = x0 + canvas_width * 0.5, y0 + height * 0.58
  local radius = math.min(canvas_width, height) * 0.36
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x1, y1, COLORS.bg)
  ImGui.DrawList_AddText(dl, x0 + 14, y0 + 14, COLORS.text, "6ch Ambisonic Decoder Router")
  ImGui.DrawList_AddText(dl, x0 + 14, y0 + 34, COLORS.muted, "4 speaker bed + 2 elevated side speakers")

  local points = {}
  local by_id = {}
  for i, speaker in ipairs(SPEAKERS) do
    local az = actual_param(track, fx, speaker.az_param)
    local el = actual_param(track, fx, speaker.el_param)
    local p = project_point(az, el, cx, cy, radius)
    p.id = i
    p.name = speaker.name
    points[#points + 1] = p
    by_id[i] = p
  end

  draw_reference_ring(dl, cx, cy, radius)
  draw_edge(dl, by_id, 1, 2, 0.30)
  draw_edge(dl, by_id, 2, 3, 0.30)
  draw_edge(dl, by_id, 3, 4, 0.30)
  draw_edge(dl, by_id, 4, 1, 0.30)
  draw_edge(dl, by_id, 5, 6, 0.24)
  draw_edge(dl, by_id, 5, 1, 0.12)
  draw_edge(dl, by_id, 5, 4, 0.12)
  draw_edge(dl, by_id, 6, 2, 0.12)
  draw_edge(dl, by_id, 6, 3, 0.12)

  local center = project_point(0, 0, cx, cy, radius)
  ImGui.DrawList_AddCircleFilled(dl, center.x, center.y, 3.5, color(0.72, 0.76, 0.78, 0.30), 16)
  ImGui.DrawList_AddText(dl, center.x + 7, center.y - 7, color(0.70, 0.74, 0.76, 0.42), "C")

  table.sort(points, function(a, b) return a.z < b.z end)
  for _, p in ipairs(points) do
    local overhead = math.abs(p.el) > 20
    local fill = overhead and COLORS.overhead or COLORS.speaker
    local selected = p.id == selected_speaker
    local front = clamp((p.z + 1) * 0.5, 0, 1)
    local size = (overhead and 7.5 or 6.0) + 2.0 * front
    ImGui.DrawList_AddCircleFilled(dl, p.x, p.y, size + 5, color(0.04, 0.045, 0.05, 0.78), 24)
    ImGui.DrawList_AddCircleFilled(dl, p.x, p.y, size + 2, color(0.10, 0.12, 0.13, 0.95), 24)
    ImGui.DrawList_AddCircleFilled(dl, p.x, p.y, size, fill, 24)
    ImGui.DrawList_AddCircle(dl, p.x, p.y, selected and size + 7 or size + 3, selected and COLORS.selected or color(0.66, 0.70, 0.72, 0.40 + 0.35 * front), 24, selected and 3 or 1.5)
    ImGui.DrawList_AddText(dl, p.x - 4, p.y - 7, COLORS.bg, tostring(p.id))
    ImGui.DrawList_AddText(dl, p.x + size + 6, p.y - 7, color(0.82, 0.88, 0.90, 0.52 + 0.35 * front), p.name .. "  " .. string.format("%.0f/%.0f", p.az, p.el))
  end

  ImGui.DrawList_AddText(dl, x0 + canvas_width - 205, y0 + 14, COLORS.muted, "speaker outputs 1-6")
  ImGui.DrawList_AddText(dl, x0 + canvas_width - 212, y0 + 34, COLORS.muted, "click a dot to edit az / el")

  if ImGui.IsItemHovered(ctx) and ImGui.IsMouseClicked(ctx, 0) then
    local mx, my = ImGui.GetMousePos(ctx)
    local best, best_d = selected_speaker, 999999
    for _, p in ipairs(points) do
      local dx, dy = mx - p.x, my - p.y
      local d = dx * dx + dy * dy
      if d < best_d then best, best_d = p.id, d end
    end
    if best_d < 900 then selected_speaker = best end
  end

  if controls_inline then
    ImGui.SameLine(ctx)
    ImGui.Dummy(ctx, control_gap, 1)
    ImGui.SameLine(ctx)
  end
  draw_camera_controls()
end

local function draw_speaker_controls(track, fx)
  local changed
  changed, selected_speaker = ImGui.SliderInt(ctx, "Selected speaker", selected_speaker, 1, #SPEAKERS)
  local speaker = SPEAKERS[selected_speaker]
  local d = DEFAULT_LAYOUT[selected_speaker]
  ImGui.Text(ctx, "Speaker " .. tostring(selected_speaker) .. " / " .. speaker.name)
  ImGui.SameLine(ctx)
  ImGui.TextColored(ctx, COLORS.muted, "default " .. tostring(d.az) .. " / " .. tostring(d.el))
  slider_actual(track, fx, speaker.name .. " azimuth", speaker.az_param, -180, 180, "%.1f deg")
  slider_actual(track, fx, speaker.name .. " elevation", speaker.el_param, -90, 90, "%.1f deg")
end

local function reset_layout(track, fx)
  for i, speaker in ipairs(SPEAKERS) do
    local d = DEFAULT_LAYOUT[i]
    set_actual(track, fx, speaker.az_param, d.az, -180, 180)
    set_actual(track, fx, speaker.el_param, d.el, -90, 90)
  end
end

local function migrate_old_default_layout(track, fx)
  local key = tostring(track) .. ":" .. tostring(fx)
  if migrated_layout[key] then return end
  migrated_layout[key] = true
  local s6 = SPEAKERS[6]
  local az = actual_param(track, fx, s6.az_param)
  local el = actual_param(track, fx, s6.el_param)
  if math.abs(az - -90) < 0.01 and math.abs(el) < 0.01 then
    set_actual(track, fx, s6.el_param, DEFAULT_LAYOUT[6].el, -90, 90)
  end
end

local function draw_default_layout_summary()
  ImGui.TextColored(ctx, COLORS.muted, "Default layout:")
  for i, speaker in ipairs(SPEAKERS) do
    local d = DEFAULT_LAYOUT[i]
    ImGui.Text(ctx, string.format("%d %s  AZ %g  EL %g", i, speaker.name, d.az, d.el))
    if i % 3 ~= 0 and i < #SPEAKERS then ImGui.SameLine(ctx, 0, 18) end
  end
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 780, 820, ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, "6ch Ambisonic Decoder Router", open)
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
        reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", math.max(16, reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")))
        resolve_param_indices(track, fx)
        migrate_old_default_layout(track, fx)
        draw_layout(track, fx)
        if ImGui.CollapsingHeader(ctx, "Decode / Routing", nil, ImGui.TreeNodeFlags_DefaultOpen) then
          combo_param(track, fx, "Input mode", 0, MODE_NAMES)
          combo_param(track, fx, "Ambisonic order", 1, ORDER_NAMES)
          combo_param(track, fx, "Decode weighting", 2, WEIGHT_NAMES)
          combo_param(track, fx, "Extra channel output", 4, EXTRA_NAMES)
          slider_actual(track, fx, "Output gain", 3, -24, 24, "%.1f dB")
          slider_actual(track, fx, "Direct input mix", 5, 0, 150, "%.0f %%")
          slider_actual(track, fx, "Ambisonic decode mix", 6, 0, 150, "%.0f %%")
        end
        if ImGui.CollapsingHeader(ctx, "Speaker Coordinates", nil, ImGui.TreeNodeFlags_DefaultOpen) then
          if ImGui.Button(ctx, "Reset 6ch layout") then reset_layout(track, fx) end
          ImGui.SameLine(ctx)
          if ImGui.Button(ctx, "Show JSFX") then reaper.TrackFX_Show(track, fx, 3) end
          draw_default_layout_summary()
          draw_speaker_controls(track, fx)
          for i, speaker in ipairs(SPEAKERS) do
            if ImGui.Button(ctx, tostring(i) .. " " .. speaker.name .. "##spkselect" .. tostring(i), 72, 24) then selected_speaker = i end
            if i < #SPEAKERS then ImGui.SameLine(ctx) end
          end
        end
        ImGui.TextColored(ctx, COLORS.muted, "Native monitor decoder: useful for sketching. For formal calibrated playback, use a measured decoder such as IEM AllRADecoder.")
      end
    end
    ImGui.End(ctx)
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
