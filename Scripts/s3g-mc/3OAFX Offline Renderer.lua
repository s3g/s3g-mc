-- @description 3OAFX Offline Renderer
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline ambisonic decode/process/re-encode render.
-- @method Select one ACN/SN3D ambisonic media item. The renderer decodes 1OA, 2OA, or 3OA to an order-specific virtual speaker layer, applies one of the included regional effects over a moving AED focus with 3OAFX-style dry control, then re-encodes a new ambisonic item.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")
local be = dofile(script_dir .. "Breakpoint Envelope Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "3OAFX Offline Renderer", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local WINDOW_OPEN_COND = ImGui.Cond_Appearing
local EXT = "s3g_mc_3oafx_offline_renderer_v1"
local COLOR_WARN = ImGui.ColorConvertDouble4ToU32(1.0, 0.35, 0.22, 1.0)
local COLOR_BG = ImGui.ColorConvertDouble4ToU32(0.035, 0.039, 0.042, 1.0)
local COLOR_GRID = ImGui.ColorConvertDouble4ToU32(0.58, 0.63, 0.63, 0.13)
local COLOR_EDGE = ImGui.ColorConvertDouble4ToU32(0.62, 0.66, 0.66, 0.32)
local COLOR_TEXT = ImGui.ColorConvertDouble4ToU32(0.76, 0.80, 0.78, 1.0)
local COLOR_MUTED = ImGui.ColorConvertDouble4ToU32(0.50, 0.56, 0.56, 1.0)
local COLOR_PATH = ImGui.ColorConvertDouble4ToU32(0.98, 0.74, 0.26, 0.94)
local COLOR_PATH_FADE = ImGui.ColorConvertDouble4ToU32(0.98, 0.74, 0.26, 0.24)
local COLOR_FOCUS = ImGui.ColorConvertDouble4ToU32(0.20, 0.72, 0.95, 0.90)
local COLOR_FOCUS_SOFT = ImGui.ColorConvertDouble4ToU32(0.20, 0.72, 0.95, 0.18)
local COLOR_DRY = ImGui.ColorConvertDouble4ToU32(0.95, 0.36, 0.22, 0.76)
local COLOR_WET = ImGui.ColorConvertDouble4ToU32(0.30, 0.72, 0.95, 0.78)
local COLOR_WIDTH = ImGui.ColorConvertDouble4ToU32(0.92, 0.82, 0.38, 0.72)
local COLOR_SHARP = ImGui.ColorConvertDouble4ToU32(0.72, 0.58, 0.98, 0.82)

local ORDER_NAMES = { "1OA / 4ch", "2OA / 9ch", "3OA / 16ch" }
local ORDER_VALUES = { 1, 2, 3 }
local EFFECT_NAMES = {
  "Band-pass region",
  "Comb resonator",
  "Delay region",
  "Diffusion region",
  "Focus gain",
  "Low-pass region",
  "Pitch shift",
  "Ring mod region",
  "Soft saturation",
  "Spectral smear",
  "Tremolo region",
}
local EFFECT_KEYS = {
  "bandpass",
  "comb",
  "delay",
  "diffusion",
  "gain",
  "filter",
  "pitch_shift",
  "ringmod",
  "saturation",
  "spectral_smear",
  "tremolo",
}

local ENV_DEFS = {
  { key = "azimuth", label = "Azimuth", min = -180.0, max = 180.0, default = 0.0, fmt = "%.1f deg" },
  { key = "elevation", label = "Elevation", min = -90.0, max = 90.0, default = 0.0, fmt = "%.1f deg" },
  { key = "focus_width", label = "Focus width", min = 2.0, max = 140.0, default = 38.0, fmt = "%.1f deg" },
  { key = "focus_sharpness", label = "Focus sharpness", min = 0.0, max = 1.0, default = 0.65, fmt = "%.2f" },
  { key = "wet", label = "Wet amount", min = 0.0, max = 2.0, default = 1.0, fmt = "%.2f" },
  { key = "dry_level", label = "Dry level", min = 0.0, max = 1.5, default = 0.65, fmt = "%.2f" },
  { key = "dry_attenuation", label = "Dry remaining at focus", min = 0.0, max = 1.0, default = 0.18, fmt = "%.2f" },
  { key = "amplitude", label = "Output amp", min = 0.0, max = 1.5, default = 1.0, fmt = "%.2f" },
}

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function get_number(key, default)
  local value = tonumber(reaper.GetExtState(EXT, key))
  return value or default
end

local function set_value(key, value)
  if type(value) == "boolean" then
    reaper.SetExtState(EXT, key, value and "1" or "0", true)
  else
    reaper.SetExtState(EXT, key, tostring(value), true)
  end
end

local function draw_combo(label, index, names)
  if ImGui.BeginCombo(ctx, label, names[index] or "") then
    for i, name in ipairs(names) do
      local selected = i == index
      if ImGui.Selectable(ctx, name, selected) then index = i end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return index
end

local function order_index_for_channels(channels)
  if channels >= 16 then return 3 end
  if channels >= 9 then return 2 end
  return 1
end

local function order_channels(order_index)
  local order = ORDER_VALUES[order_index] or 3
  return (order + 1) * (order + 1)
end

local function effect_param_label(effect_index)
  local key = EFFECT_KEYS[effect_index]
  if key == "bandpass" then return "Center Hz" end
  if key == "comb" then return "Resonance Hz" end
  if key == "delay" then return "Delay ms" end
  if key == "diffusion" then return "Diffusion ms" end
  if key == "filter" then return "Cutoff Hz" end
  if key == "pitch_shift" then return "Pitch semitones" end
  if key == "ringmod" then return "Ring frequency Hz" end
  if key == "saturation" then return "Drive" end
  if key == "spectral_smear" then return "Smear frames" end
  if key == "tremolo" then return "Tremolo rate Hz" end
  return "Focus gain##effect_param"
end

local function effect_param_range(effect_index)
  local key = EFFECT_KEYS[effect_index]
  if key == "bandpass" then return 60.0, 12000.0, "%.0f" end
  if key == "comb" then return 40.0, 4000.0, "%.0f" end
  if key == "delay" then return 5.0, 900.0, "%.1f" end
  if key == "diffusion" then return 3.0, 80.0, "%.1f" end
  if key == "filter" then return 80.0, 12000.0, "%.0f" end
  if key == "pitch_shift" then return -24.0, 24.0, "%.1f" end
  if key == "ringmod" then return 0.1, 2000.0, "%.1f" end
  if key == "saturation" then return 0.25, 12.0, "%.2f" end
  if key == "spectral_smear" then return 1.0, 48.0, "%.0f" end
  if key == "tremolo" then return 0.05, 30.0, "%.2f" end
  return 0.0, 2.5, "%.2f"
end

local function effect_uses_feedback(effect_index)
  local key = EFFECT_KEYS[effect_index]
  return key == "delay" or key == "comb" or key == "diffusion"
end

local VIRTUAL_LAYOUTS = {
  {
    { 0.0, 0.0 }, { 90.0, 0.0 }, { 180.0, 0.0 }, { -90.0, 0.0 },
    { 0.0, 90.0 }, { 0.0, -90.0 },
  },
  {
    { 0.0, 0.0 }, { 45.0, 0.0 }, { 90.0, 0.0 }, { 135.0, 0.0 },
    { 180.0, 0.0 }, { -135.0, 0.0 }, { -90.0, 0.0 }, { -45.0, 0.0 },
    { 45.0, 45.0 }, { 135.0, 45.0 }, { -135.0, -45.0 }, { -45.0, -45.0 },
  },
  {
    { 0.000000, 73.402158 }, { 137.507764, 61.044976 }, { -84.984472, 52.341538 },
    { 52.523292, 45.099472 }, { -169.968944, 38.682187 }, { -32.461180, 32.797168 },
    { 105.046584, 27.279613 }, { -117.445652, 22.024313 }, { 20.062112, 16.957763 },
    { 157.569876, 12.024699 }, { -64.922360, 7.180756 }, { 72.585405, 2.388015 },
    { -149.906831, -2.388015 }, { -12.399067, -7.180756 }, { 125.108697, -12.024699 },
    { -97.383539, -16.957763 }, { 40.124225, -22.024313 }, { 177.631989, -27.279613 },
    { -44.860247, -32.797168 }, { 92.647517, -38.682187 }, { -129.844719, -45.099472 },
    { 7.663045, -52.341538 }, { 145.170809, -61.044976 }, { -77.321427, -73.402158 },
  },
}

local function color_rgba(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1.0)
end

local function env_index_for_key(key)
  for index, def in ipairs(ENV_DEFS) do
    if def.key == key then return index, def end
  end
  return nil, nil
end

local function sample_env_value(key, t, settings, env_points, env_enabled)
  local index, def = env_index_for_key(key)
  if not index or not def then return settings[key] or 0 end
  if not env_enabled[index] then return settings[key] or def.default or def.min end
  local points = env_points[index]
  if not points or #points < 2 then return settings[key] or def.default or def.min end
  be.sort(points)
  if t <= points[1].x then return be.value(def, points[1].y) end
  for point_index = 1, #points - 1 do
    local a = points[point_index]
    local b = points[point_index + 1]
    if t <= b.x then
      local span = math.max(0.000001, b.x - a.x)
      local u = clamp((t - a.x) / span, 0, 1)
      return be.value(def, be.lerp(a.y, b.y, u))
    end
  end
  return be.value(def, points[#points].y)
end

local function project_aed(az, el, cx, cy, radius)
  local azr = math.rad(az or 0)
  local eln = clamp((el or 0) / 90.0, -1, 1)
  local r = radius * (0.18 + 0.78 * math.cos(math.asin(eln)))
  local x = cx + math.sin(azr) * r
  local y = cy - math.cos(azr) * r * 0.62 - eln * radius * 0.35
  return x, y
end

local function angular_distance(a_az, a_el, b_az, b_el)
  local function unit(az, el)
    local azr = math.rad(az)
    local elr = math.rad(el)
    local ce = math.cos(elr)
    return ce * math.cos(azr), ce * math.sin(azr), math.sin(elr)
  end
  local ax, ay, az = unit(a_az or 0, a_el or 0)
  local bx, by, bz = unit(b_az or 0, b_el or 0)
  local dot = clamp(ax * bx + ay * by + az * bz, -1, 1)
  return math.deg(math.acos(dot))
end

local function focus_mask_for_speaker(focus_az, focus_el, width, sharpness, speaker)
  local dist = angular_distance(focus_az, focus_el, speaker[1], speaker[2])
  local mask = math.exp(-0.5 * (dist / math.max(2.0, width or 38.0)) ^ 2)
  return clamp(mask ^ (1.0 + clamp(sharpness or 0.0, 0, 1) * 5.0), 0, 1)
end

local function draw_preview(settings, env_points, env_enabled, entry)
  local width = math.max(420, ImGui.GetContentRegionAvail(ctx) - 2)
  local height = 270
  ImGui.InvisibleButton(ctx, "##foafx_preview", width, height)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = ImGui.GetItemRectMax(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x1, y1, COLOR_BG)
  ImGui.DrawList_AddRect(dl, x0, y0, x1, y1, COLOR_EDGE)

  local cx = x0 + width * 0.38
  local cy = y0 + height * 0.50
  local radius = math.min(width * 0.36, height * 0.43)
  ImGui.DrawList_AddCircle(dl, cx, cy, radius, COLOR_GRID, 96, 1)
  ImGui.DrawList_AddCircle(dl, cx, cy, radius * 0.62, COLOR_GRID, 96, 1)
  ImGui.DrawList_AddLine(dl, cx - radius, cy, cx + radius, cy, COLOR_GRID, 1)
  ImGui.DrawList_AddLine(dl, cx, cy - radius, cx, cy + radius, COLOR_GRID, 1)

  local layout = VIRTUAL_LAYOUTS[settings.order_index] or VIRTUAL_LAYOUTS[3]
  local samples = 48
  local path = {}
  local speaker_energy = {}
  local max_energy = 0.000001
  for index = 1, #layout do
    speaker_energy[index] = { sum = 0.0, peak = 0.0, last = 0.0 }
  end
  for i = 1, samples do
    local t = (i - 1) / (samples - 1)
    local az = sample_env_value("azimuth", t, settings, env_points, env_enabled)
    local el = sample_env_value("elevation", t, settings, env_points, env_enabled)
    local fw = sample_env_value("focus_width", t, settings, env_points, env_enabled)
    local wet = sample_env_value("wet", t, settings, env_points, env_enabled)
    local dry_level = sample_env_value("dry_level", t, settings, env_points, env_enabled)
    local dry = sample_env_value("dry_attenuation", t, settings, env_points, env_enabled)
    local amp = sample_env_value("amplitude", t, settings, env_points, env_enabled)
    local sharp = sample_env_value("focus_sharpness", t, settings, env_points, env_enabled)
    local px, py = project_aed(az, el, cx, cy, radius)
    path[#path + 1] = { x = px, y = py, az = az, el = el, width = fw, wet = wet, dry_level = dry_level, dry = dry, amp = amp, sharp = sharp, t = t }
    for speaker_index, speaker in ipairs(layout) do
      local mask = focus_mask_for_speaker(az, el, fw, sharp, speaker)
      local changed_energy = mask * amp * (math.max(0, wet) + math.max(0, dry_level) * math.max(0, 1.0 - dry))
      local stat = speaker_energy[speaker_index]
      stat.sum = stat.sum + changed_energy
      stat.peak = math.max(stat.peak, changed_energy)
      stat.last = changed_energy
      max_energy = math.max(max_energy, changed_energy)
    end
  end

  for index, speaker in ipairs(layout) do
    local stat = speaker_energy[index]
    local avg = stat.sum / samples
    local peak = stat.peak / max_energy
    local last = stat.last / max_energy
    local sx, sy = project_aed(speaker[1], speaker[2], cx, cy, radius)
    local avg_norm = avg / max_energy
    ImGui.DrawList_AddCircleFilled(dl, sx, sy, 3.5 + avg_norm * 22.0,
      color_rgba(0.23, 0.70, 0.95, 0.04 + avg_norm * 0.26), 24)
    ImGui.DrawList_AddCircle(dl, sx, sy, 5.5 + peak * 17.0,
      color_rgba(0.30, 0.76, 0.98, 0.18 + peak * 0.50), 24, 1.4)
    ImGui.DrawList_AddCircleFilled(dl, sx, sy, 2.8 + last * 5.8,
      color_rgba(0.80, 0.86, 0.86, 0.32 + last * 0.56), 18)
    ImGui.DrawList_AddText(dl, sx + 6, sy - 6, color_rgba(0.72, 0.78, 0.78, 0.52 + 0.30 * peak), tostring(index))
  end

  for i = 2, #path do
    ImGui.DrawList_AddLine(dl, path[i - 1].x, path[i - 1].y, path[i].x, path[i].y, COLOR_PATH_FADE, 5)
    ImGui.DrawList_AddLine(dl, path[i - 1].x, path[i - 1].y, path[i].x, path[i].y, COLOR_PATH, 2)
  end
  for i = 1, #path, 8 do
    local p = path[i]
    local circle_r = 4 + clamp(p.width, 2, 140) / 140 * 34
    ImGui.DrawList_AddCircle(dl, p.x, p.y, circle_r, COLOR_FOCUS_SOFT, 48, 1.5)
  end
  local p0 = path[1]
  local p1 = path[#path]
  local end_focus_az = p1 and p1.az or settings.azimuth or 0
  local end_focus_el = p1 and p1.el or settings.elevation or 0
  local end_width = p1 and p1.width or settings.focus_width or 38
  ImGui.DrawList_AddCircleFilled(dl, p0.x, p0.y, 5, color_rgba(0.45, 0.90, 0.48, 0.95), 24)
  ImGui.DrawList_AddCircleFilled(dl, p1.x, p1.y, 6, COLOR_FOCUS, 24)

  local panel_x0 = x0 + width * 0.72
  local panel_x1 = x1 - 14
  local strip_y0 = y0 + 86
  local strip_h = 18
  ImGui.DrawList_AddText(dl, x0 + 12, y0 + 10, COLOR_TEXT, "Offline 3OAFX energy preview")
  ImGui.DrawList_AddText(dl, x0 + 12, y0 + 30, COLOR_MUTED,
    tostring(#layout) .. " virtual speakers / " .. string.format("%.2f sec", entry.length * math.max(0.000001, entry.playrate)))
  ImGui.DrawList_AddText(dl, panel_x0, y0 + 18, COLOR_TEXT, EFFECT_NAMES[settings.effect_index] or "Focus gain")
  ImGui.DrawList_AddText(dl, panel_x0, y0 + 40, COLOR_MUTED,
    string.format("End focus: %.1f az / %.1f el", end_focus_az, end_focus_el))
  ImGui.DrawList_AddText(dl, panel_x0, y0 + 58, COLOR_MUTED,
    string.format("Width %.1f deg", end_width))

  local function draw_strip(label, y, key, col, lo, hi)
    ImGui.DrawList_AddText(dl, panel_x0, y - 3, COLOR_MUTED, label)
    local sx0 = panel_x0 + 86
    local sx1 = panel_x1
    ImGui.DrawList_AddRect(dl, sx0, y, sx1, y + strip_h, COLOR_GRID)
    local last_x, last_y
    for i = 1, samples do
      local t = (i - 1) / (samples - 1)
      local v = sample_env_value(key, t, settings, env_points, env_enabled)
      local n = clamp((v - lo) / math.max(0.000001, hi - lo), 0, 1)
      local px = be.lerp(sx0 + 2, sx1 - 2, t)
      local py = be.lerp(y + strip_h - 3, y + 3, n)
      if last_x then ImGui.DrawList_AddLine(dl, last_x, last_y, px, py, col, 2) end
      last_x, last_y = px, py
    end
  end
  draw_strip("wet", strip_y0, "wet", COLOR_WET, 0.0, 2.0)
  draw_strip("dry focus", strip_y0 + 34, "dry_attenuation", COLOR_DRY, 0.0, 1.0)
  draw_strip("width", strip_y0 + 68, "focus_width", COLOR_WIDTH, 2.0, 140.0)
  draw_strip("sharp", strip_y0 + 102, "focus_sharpness", COLOR_SHARP, 0.0, 1.0)

  ImGui.DrawList_AddText(dl, panel_x0, y1 - 56, COLOR_MUTED, "blue halo=duration energy")
  ImGui.DrawList_AddText(dl, panel_x0, y1 - 38, COLOR_MUTED, "white core=end energy")
  ImGui.DrawList_AddText(dl, panel_x0, y1 - 20, COLOR_MUTED, "green=start / blue=end")
end

local function render(entry, settings, env_points, env_enabled)
  local needed_channels = order_channels(settings.order_index)
  if entry.filename == "" or not nr.file_exists(entry.filename) then
    mc.show_error("The selected source item must be backed by a readable WAV file.")
    return
  end
  if entry.channels < needed_channels then
    mc.show_error("The selected item has " .. tostring(entry.channels) .. " channels, but " ..
      ORDER_NAMES[settings.order_index] .. " needs " .. tostring(needed_channels) .. " channels.")
    return
  end

  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_3oafx_offline_renders", entry.filename, script_dir)
  local output_path = out_dir .. "/s3g_3oafx_offline_" .. stamp .. "_" .. tostring(needed_channels) .. "ch.wav"
  local effect_key = EFFECT_KEYS[settings.effect_index] or "gain"
  local manifest = {
    source_path = entry.filename,
    source_start = entry.start_offset,
    source_duration = entry.length * math.max(0.000001, entry.playrate),
    output_path = output_path,
    sample_rate = nr.source_sample_rate(entry),
    order = ORDER_VALUES[settings.order_index] or 3,
    effect = effect_key,
    azimuth = settings.azimuth,
    elevation = settings.elevation,
    focus_width = settings.focus_width,
    focus_sharpness = settings.focus_sharpness,
    wet = settings.wet,
    dry_level = settings.dry_level,
    move_wet_on_array = settings.move_wet_on_array,
    dry_attenuation = settings.dry_attenuation,
    amplitude = settings.amplitude,
    effect_gain = settings.effect_gain,
    effect_param = settings.effect_param,
    tremolo_rate = effect_key == "tremolo" and settings.effect_param or settings.tremolo_rate,
    ring_hz = effect_key == "ringmod" and settings.effect_param or settings.ring_hz,
    drive = effect_key == "saturation" and settings.effect_param or settings.drive,
    delay_ms = effect_key == "delay" and settings.effect_param or settings.delay_ms,
    center_hz = effect_key == "bandpass" and settings.effect_param or settings.center_hz,
    reson_hz = effect_key == "comb" and settings.effect_param or settings.reson_hz,
    diffusion_ms = effect_key == "diffusion" and settings.effect_param or settings.diffusion_ms,
    smear_frames = effect_key == "spectral_smear" and settings.effect_param or settings.smear_frames,
    pitch_semitones = effect_key == "pitch_shift" and settings.effect_param or settings.pitch_semitones,
    cutoff_hz = effect_key == "filter" and settings.effect_param or settings.cutoff_hz,
    feedback = settings.feedback,
    damp = settings.damp,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    dc_protect = settings.dc_protect,
    soft_limit = settings.soft_limit,
  }
  be.add_to_manifest(manifest, ENV_DEFS, env_points, env_enabled)

  local log, elapsed = nr.run_backend(script_dir, "foafx_offline", manifest, "3OAFX Offline Renderer")
  if not log then return end

  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path,
    "3OAFX offline " .. tostring(ORDER_VALUES[settings.order_index]) .. "OA", entry.position, needed_channels, {
      master_send = false,
      track_gain = 0.5,
    })
  reaper.Undo_EndBlock("3OAFX Offline Renderer", -1)
  if not item then mc.show_error(err or "Could not insert rendered 3OAFX item.") return end

  mc.print_plan("3OAFX Offline Renderer", {
    "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. "ch)",
    "Order: " .. ORDER_NAMES[settings.order_index],
    "Effect: " .. (EFFECT_NAMES[settings.effect_index] or "Focus gain"),
    "Dry level: " .. string.format("%.2f", settings.dry_level),
    "Dry remaining at focus: " .. string.format("%.2f", settings.dry_attenuation),
    "Inserted track: master send off, gain -6 dB",
    "Output: " .. output_path,
    "NumPy time: " .. string.format("%.2f sec", elapsed),
    log,
  })
end

function main()
  local entries = nr.selected_entries()
  if #entries < 1 then
    mc.show_error("Select one WAV-backed ambisonic media item first.")
    return
  end
  local entry = entries[1]
  local default_order = order_index_for_channels(entry.channels)
  local settings = {
    order_index = clamp(math.floor(get_number("order_index", default_order)), 1, 3),
    effect_index = clamp(math.floor(get_number("effect_index", 1)), 1, #EFFECT_NAMES),
    azimuth = get_number("azimuth", 0.0),
    elevation = get_number("elevation", 0.0),
    focus_width = get_number("focus_width", 38.0),
    focus_sharpness = get_number("focus_sharpness", 0.65),
    wet = get_number("wet", 1.0),
    dry_level = get_number("dry_level", 0.65),
    move_wet_on_array = reaper.GetExtState(EXT, "move_wet_on_array") ~= "0",
    dry_attenuation = get_number("dry_attenuation", 0.18),
    amplitude = get_number("amplitude", 1.0),
    effect_gain = get_number("effect_gain", 1.0),
    effect_param = get_number("effect_param", 1.0),
    tremolo_rate = get_number("tremolo_rate", 4.0),
    ring_hz = get_number("ring_hz", 90.0),
    drive = get_number("drive", 2.5),
    delay_ms = get_number("delay_ms", 120.0),
    center_hz = get_number("center_hz", 1200.0),
    reson_hz = get_number("reson_hz", 220.0),
    diffusion_ms = get_number("diffusion_ms", 18.0),
    smear_frames = get_number("smear_frames", 8.0),
    pitch_semitones = get_number("pitch_semitones", 7.0),
    cutoff_hz = get_number("cutoff_hz", 1400.0),
    feedback = get_number("feedback", 0.28),
    damp = get_number("damp", 0.45),
    normalize = reaper.GetExtState(EXT, "normalize") ~= "0",
    normalize_db = get_number("normalize_db", -6.0),
    dc_protect = reaper.GetExtState(EXT, "dc_protect") ~= "0",
    soft_limit = reaper.GetExtState(EXT, "soft_limit") ~= "0",
  }
  local env_points, env_enabled = be.init(ENV_DEFS, settings)
  be.load_extstate(EXT, ENV_DEFS, env_points, env_enabled)

  ctx = ImGui.CreateContext("3OAFX Offline Renderer")
  local open = true
  local should_render = false
  local selected_env = 1
  local selected_env_point = nil
  local env_opts = { height = 150, overview_lane_h = 54, random_amount = 0.28, random_count = 10, random_dispersion = 0.25, random_smooth = true }

  local function loop()
    ImGui.SetNextWindowSize(ctx, 900, 760, WINDOW_OPEN_COND)
    local visible
    visible, open = ImGui.Begin(ctx, "3OAFX Offline Renderer", open)
    if visible then
      local _, avail_h = ImGui.GetContentRegionAvail(ctx)
      local control_h = math.max(300, (avail_h or 1060) - 44)
      if ImGui.BeginChild(ctx, "##3oafx_offline_controls", 0, control_h) then
      ImGui.Text(ctx, "Source: " .. entry.name .. "  (" .. tostring(entry.channels) .. " ch)")
      ImGui.Text(ctx, "Input convention: ACN/SN3D ambisonics")
      if ImGui.CollapsingHeader(ctx, "Render Setup", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        settings.order_index = draw_combo("Ambisonic order", settings.order_index, ORDER_NAMES)
        local needed = order_channels(settings.order_index)
        if entry.channels < needed then
          ImGui.TextColored(ctx, COLOR_WARN, "Selected item does not have enough channels for this order.")
        end
      end
      local changed
      if ImGui.CollapsingHeader(ctx, "Focus And Effect", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        settings.effect_index = draw_combo("Effect region", settings.effect_index, EFFECT_NAMES)
        changed, settings.azimuth = ImGui.SliderDouble(ctx, "Azimuth", settings.azimuth, -180.0, 180.0, "%.1f deg")
        changed, settings.elevation = ImGui.SliderDouble(ctx, "Elevation", settings.elevation, -90.0, 90.0, "%.1f deg")
        changed, settings.focus_width = ImGui.SliderDouble(ctx, "Focus width", settings.focus_width, 2.0, 140.0, "%.1f deg")
        changed, settings.focus_sharpness = ImGui.SliderDouble(ctx, "Focus sharpness", settings.focus_sharpness, 0.0, 1.0, "%.2f")
        changed, settings.effect_gain = ImGui.SliderDouble(ctx, "Effect amount / gain", settings.effect_gain, 0.0, 2.5, "%.2f")
        local pmin, pmax, pfmt = effect_param_range(settings.effect_index)
        settings.effect_param = clamp(settings.effect_param, pmin, pmax)
        changed, settings.effect_param = ImGui.SliderDouble(ctx, effect_param_label(settings.effect_index), settings.effect_param, pmin, pmax, pfmt)
        if effect_uses_feedback(settings.effect_index) then
          changed, settings.feedback = ImGui.SliderDouble(ctx, "Feedback", settings.feedback, 0.0, 0.92, "%.2f")
          changed, settings.damp = ImGui.SliderDouble(ctx, "Damping / smoothing", settings.damp, 0.0, 0.98, "%.2f")
        end
      end
      if ImGui.CollapsingHeader(ctx, "Wet Dry Mix", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        changed, settings.wet = ImGui.SliderDouble(ctx, "Wet amount", settings.wet, 0.0, 2.0, "%.2f")
        changed, settings.dry_level = ImGui.SliderDouble(ctx, "Dry level", settings.dry_level, 0.0, 1.5, "%.2f")
        changed, settings.move_wet_on_array = ImGui.Checkbox(ctx, "Move wet across virtual speaker array", settings.move_wet_on_array)
        changed, settings.dry_attenuation = ImGui.SliderDouble(ctx, "Dry remaining at focus", settings.dry_attenuation, 0.0, 1.0, "%.2f")
        changed, settings.amplitude = ImGui.SliderDouble(ctx, "Output amp", settings.amplitude, 0.0, 1.5, "%.2f")
      end
      if ImGui.CollapsingHeader(ctx, "Output", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
        if settings.normalize then
          changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -36.0, -1.0, "%.1f")
        end
        changed, settings.dc_protect = ImGui.Checkbox(ctx, "DC protect", settings.dc_protect)
        ImGui.SameLine(ctx)
        changed, settings.soft_limit = ImGui.Checkbox(ctx, "Soft limit", settings.soft_limit)
      end
      ImGui.Separator(ctx)
      ImGui.Text(ctx, "Dry remaining at focus sets how much dry signal stays under the moving effect mask before re-encoding.")
      if ImGui.CollapsingHeader(ctx, "Preview", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        draw_preview(settings, env_points, env_enabled, entry)
      end
      ImGui.Separator(ctx)
      if ImGui.CollapsingHeader(ctx, "Breakpoint Envelopes", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env,
          selected_env_point, settings, env_opts)
      end
        ImGui.EndChild(ctx)
      end
      if ImGui.Button(ctx, "Render", 96, 28) then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 96, 28) then open = false end
      ImGui.End(ctx)
    end

    if should_render then
      open = false
      for key, value in pairs(settings) do set_value(key, value) end
      be.save_extstate(EXT, ENV_DEFS, env_points, env_enabled)
      render(entry, settings, env_points, env_enabled)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
