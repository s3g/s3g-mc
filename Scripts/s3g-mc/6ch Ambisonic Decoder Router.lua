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
do
  local _s3g_theme_path = ({ reaper.get_action_context() })[2]
  if not _s3g_theme_path or _s3g_theme_path == "" then
    _s3g_theme_path = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
  end
  local _s3g_theme_dir = _s3g_theme_path:match("^(.*[/\\])") or ""
  package.path = _s3g_theme_dir .. "?.lua;" .. package.path
  package.loaded["s3g-mc ImGui Theme"] = nil
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme and _s3g_theme.install then _s3g_theme.install(ImGui) end
end
local theme = require("s3g-mc ImGui Theme")
local THEME = theme.palette(ImGui)

local PROJECT = 0
local FX_NAME = "s3g 6ch Ambisonic Decoder Router"
local FX_NAME_CLEAN = "6ch Ambisonic Decoder Router"
local ctx = ImGui.CreateContext("6ch Ambisonic Decoder Router")
local open = true
local selected_speaker = 1
local view_yaw_deg = 0
local view_pitch_deg = 0
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

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a)
end

local STYLE = {
  bg = THEME.bg,
  panel = THEME.panel,
  edge = THEME.edge,
  grid = THEME.grid,
  text = THEME.text,
  muted = THEME.value,
  selected = THEME.amber,
  speaker = THEME.fill,
  overhead = color(0.50, 0.60, 0.54, 1),
}

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
  local changed, next_index = theme.combo_row(ImGui, ctx, label, names, index)
  if changed then
    index = next_index
    set_param(track, fx, param, (index - 1) / math.max(1, #names - 1))
  end
end

local function slider_actual(track, fx, label, param, lo, hi, fmt)
  local value = actual_param(track, fx, param)
  local changed
  changed, value = theme.slider_double(ImGui, ctx, label, value, lo, hi, fmt)
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
  theme.muted(ImGui, ctx, "CAMERA")
  nudge_camera("UP##decodercam", 68, 24, function()
    view_pitch_deg = clamp(view_pitch_deg + 4, -180, 180)
  end)
  nudge_camera("L##decodercam", 32, 24, function()
    view_yaw_deg = view_yaw_deg - 4
  end)
  ImGui.SameLine(ctx)
  nudge_camera("R##decodercam", 32, 24, function()
    view_yaw_deg = view_yaw_deg + 4
  end)
  nudge_camera("DN##decodercam", 68, 24, function()
    view_pitch_deg = clamp(view_pitch_deg - 4, -180, 180)
  end)
  nudge_camera("-##decoderzoom", 32, 24, function()
    view_zoom = clamp(view_zoom - 0.025, 0.5, 2.2)
  end)
  ImGui.SameLine(ctx)
  nudge_camera("+##decoderzoom", 32, 24, function()
    view_zoom = clamp(view_zoom + 0.025, 0.5, 2.2)
  end)
  if ImGui.Button(ctx, "TOP##decodercam", 68, 24) then reset_camera(0, 0) end
  if ImGui.Button(ctx, "FRONT##decodercam", 68, 24) then reset_camera(0, -90) end
  if ImGui.Button(ctx, "3/4##decodercam", 68, 24) then reset_camera(-35, -42) end
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
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x1, y1, STYLE.bg)
  ImGui.DrawList_AddText(dl, x0 + 14, y0 + 14, STYLE.text, "6ch Ambisonic Decoder Router")
  ImGui.DrawList_AddText(dl, x0 + 14, y0 + 34, STYLE.muted, "4 speaker bed + 2 elevated side speakers")

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
    local fill = overhead and STYLE.overhead or STYLE.speaker
    local selected = p.id == selected_speaker
    local front = clamp((p.z + 1) * 0.5, 0, 1)
    local size = (overhead and 7.5 or 6.0) + 2.0 * front
    ImGui.DrawList_AddCircleFilled(dl, p.x, p.y, size + 5, color(0.04, 0.045, 0.05, 0.78), 24)
    ImGui.DrawList_AddCircleFilled(dl, p.x, p.y, size + 2, color(0.10, 0.12, 0.13, 0.95), 24)
    ImGui.DrawList_AddCircleFilled(dl, p.x, p.y, size, fill, 24)
    ImGui.DrawList_AddCircle(dl, p.x, p.y, selected and size + 7 or size + 3, selected and STYLE.selected or color(0.66, 0.70, 0.72, 0.40 + 0.35 * front), 24, selected and 3 or 1.5)
    ImGui.DrawList_AddText(dl, p.x - 4, p.y - 7, STYLE.bg, tostring(p.id))
    ImGui.DrawList_AddText(dl, p.x + size + 6, p.y - 7, color(0.82, 0.88, 0.90, 0.52 + 0.35 * front), p.name .. "  " .. string.format("%.0f/%.0f", p.az, p.el))
  end

  ImGui.DrawList_AddText(dl, x0 + canvas_width - 205, y0 + 14, STYLE.muted, "speaker outputs 1-6")
  ImGui.DrawList_AddText(dl, x0 + canvas_width - 212, y0 + 34, STYLE.muted, "click a dot to edit az / el")

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
  changed, selected_speaker = theme.slider_int(ImGui, ctx, "Selected speaker", selected_speaker, 1, #SPEAKERS)
  local speaker = SPEAKERS[selected_speaker]
  local d = DEFAULT_LAYOUT[selected_speaker]
  theme.note_row(ImGui, ctx, "SPEAKER " .. tostring(selected_speaker) .. " / " .. speaker.name:upper() .. "  default " .. tostring(d.az) .. " / " .. tostring(d.el))
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
  theme.note_row(ImGui, ctx, "Default layout:")
  for i, speaker in ipairs(SPEAKERS) do
    local d = DEFAULT_LAYOUT[i]
    if i % 2 == 1 then
      local other = SPEAKERS[i + 1]
      local od = DEFAULT_LAYOUT[i + 1]
      local text = string.format("%d %s  AZ %g  EL %g", i, speaker.name:upper(), d.az, d.el)
      if other and od then
        text = text .. string.format("    %d %s  AZ %g  EL %g", i + 1, other.name:upper(), od.az, od.el)
      end
      theme.note_row(ImGui, ctx, text)
    end
  end
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 780, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, "6ch Ambisonic Decoder Router", open)
  if visible then
    local track = reaper.GetSelectedTrack(PROJECT, 0)
    local fx = find_fx(track)
    if not track then
      theme.status_row(ImGui, ctx, "SELECT THE TARGET TRACK.", "muted")
    else
      local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
      theme.status_row(ImGui, ctx, "TARGET: " .. (name ~= "" and name or "(UNNAMED)"), "muted")
      if theme.action_row(ImGui, ctx, "REPAIR JSFX") then fx = maybe_load(track, true) end
      if fx < 0 then fx = maybe_load(track, false) end
      if fx < 0 then
        theme.status_row(ImGui, ctx, load_error ~= "" and load_error or ("JS: " .. FX_NAME .. " IS NOT ON THE SELECTED TRACK."), "warn")
      else
        reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", math.max(16, reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")))
        resolve_param_indices(track, fx)
        migrate_old_default_layout(track, fx)
        draw_layout(track, fx)
        local sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Decode / Routing", 224)
        combo_param(track, fx, "Input mode", 0, MODE_NAMES)
        combo_param(track, fx, "Ambisonic order", 1, ORDER_NAMES)
        combo_param(track, fx, "Decode weighting", 2, WEIGHT_NAMES)
        combo_param(track, fx, "Extra channel output", 4, EXTRA_NAMES)
        slider_actual(track, fx, "Output gain", 3, -24, 24, "%.1f dB")
        slider_actual(track, fx, "Direct input mix", 5, 0, 150, "%.0f %%")
        slider_actual(track, fx, "Ambisonic decode mix", 6, 0, 150, "%.0f %%")
        theme.finish_section(ImGui, ctx, sx, sy, sh, stack)

        sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Speaker Coordinates", 282)
          local action = theme.button_row(ImGui, ctx, {
            { label = "RESET 6CH LAYOUT" },
            { label = "SHOW JSFX" },
          })
          if action == 1 then reset_layout(track, fx) end
          if action == 2 then reaper.TrackFX_Show(track, fx, 3) end
          draw_default_layout_summary()
          draw_speaker_controls(track, fx)
          local speaker_labels = {}
          for i, speaker in ipairs(SPEAKERS) do
            speaker_labels[i] = tostring(i) .. " " .. speaker.name
          end
          local speaker_changed, next_speaker = theme.combo_row(ImGui, ctx, "Speaker", speaker_labels, selected_speaker)
          if speaker_changed then selected_speaker = next_speaker end
        theme.finish_section(ImGui, ctx, sx, sy, sh, stack)
        theme.note_row(ImGui, ctx, "Monitor decoder for sketching. For formal calibrated playback, use a measured decoder such as IEM AllRADecoder.")
      end
    end
    ImGui.End(ctx)
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
