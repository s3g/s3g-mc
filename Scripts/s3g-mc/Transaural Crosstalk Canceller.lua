-- @description Transaural Crosstalk Canceller
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; JSFX: s3g Transaural Crosstalk Canceller
-- @category Channel Mixing / Automation
-- @method Auto-loads a package-native JSFX for stereo loudspeaker transaural playback. It uses delayed, filtered opposite-channel cancellation with feedforward and matrix-inverse approximation modes, speaker angle, head-width geometry, low-frequency protection, stereo preservation, and safety gain controls.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Transaural Crosstalk Canceller", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local PROJECT = 0
local FX_NAME = "s3g Transaural Crosstalk Canceller"
local FX_NAME_CLEAN = "Transaural Crosstalk Canceller"

local PARAM = {
  amount = 0,
  mode = 1,
  angle = 2,
  head = 3,
  trim = 4,
  hf = 5,
  low = 6,
  center = 7,
  limiter = 8,
  output = 9,
  extra = 10,
}

local PARAM_NAMES = {
  amount = "Cancellation amount (%)",
  mode = "Cancellation mode",
  angle = "Speaker half-angle (degrees)",
  head = "Head width (cm)",
  trim = "Delay trim (ms)",
  hf = "Cancel HF rolloff (Hz)",
  low = "Low protect (Hz)",
  center = "Stereo preserve (%)",
  limiter = "Safety limiter",
  output = "Output gain (dB)",
  extra = "Extra channel output",
}

local EXTRA = { "Keep extra channels", "Clear extra channels" }
local LIMITER = { "Off", "On" }
local MODES = { "Feedforward", "Matrix inverse" }
local PRESETS = {
  {
    name = "Gentle",
    amount = 60,
    mode = 0,
    angle = 30,
    head = 18,
    trim = 0,
    hf = 5200,
    low = 160,
    center = 25,
    limiter = 1,
    output = -6,
    extra = 1,
  },
  {
    name = "Standard",
    amount = 100,
    mode = 1,
    angle = 30,
    head = 18,
    trim = 0,
    hf = 6500,
    low = 120,
    center = 0,
    limiter = 1,
    output = -6,
    extra = 1,
  },
  {
    name = "Narrow Setup",
    amount = 95,
    mode = 1,
    angle = 22,
    head = 18,
    trim = 0,
    hf = 6000,
    low = 150,
    center = 10,
    limiter = 1,
    output = -6,
    extra = 1,
  },
  {
    name = "Wide Setup",
    amount = 110,
    mode = 1,
    angle = 45,
    head = 18,
    trim = 0,
    hf = 7000,
    low = 140,
    center = 8,
    limiter = 1,
    output = -7,
    extra = 1,
  },
  {
    name = "Careful / Roomy",
    amount = 75,
    mode = 0,
    angle = 30,
    head = 18,
    trim = 0,
    hf = 4200,
    low = 220,
    center = 35,
    limiter = 1,
    output = -8,
    extra = 1,
  },
}

local ctx = ImGui.CreateContext("Transaural Crosstalk Canceller")
local open = true
local load_error = ""
local param_warning = ""
local param_ready = true

local COLORS = {
  bg = ImGui.ColorConvertDouble4ToU32(0.035, 0.039, 0.042, 1),
  panel = ImGui.ColorConvertDouble4ToU32(0.060, 0.066, 0.070, 1),
  edge = ImGui.ColorConvertDouble4ToU32(0.30, 0.33, 0.34, 1),
  text = ImGui.ColorConvertDouble4ToU32(0.78, 0.82, 0.84, 1),
  muted = ImGui.ColorConvertDouble4ToU32(0.48, 0.52, 0.54, 1),
  active = ImGui.ColorConvertDouble4ToU32(0.16, 0.63, 0.38, 1),
  button = ImGui.ColorConvertDouble4ToU32(0.12, 0.13, 0.14, 1),
  speaker = ImGui.ColorConvertDouble4ToU32(0.42, 0.74, 0.96, 1),
  cancel = ImGui.ColorConvertDouble4ToU32(0.95, 0.58, 0.38, 1),
  direct = ImGui.ColorConvertDouble4ToU32(0.46, 0.86, 0.56, 1),
  meter = ImGui.ColorConvertDouble4ToU32(0.46, 0.86, 0.56, 1),
}

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
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
  if fx >= 0 and force and reaper.TrackFX_Delete then
    reaper.TrackFX_Delete(track, fx)
  end
  reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", math.max(2, reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")))
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
  param_ready = true
  if #missing > 0 then
    param_warning = "This JSFX instance may be stale. Rescan/reinsert if controls behave oddly. Missing: " .. table.concat(missing, ", ")
    param_ready = false
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
  if not track or fx < 0 or not preset then return end
  set_param(track, fx, PARAM.amount, preset.amount)
  set_param(track, fx, PARAM.mode, preset.mode)
  set_param(track, fx, PARAM.angle, preset.angle)
  set_param(track, fx, PARAM.head, preset.head)
  set_param(track, fx, PARAM.trim, preset.trim)
  set_param(track, fx, PARAM.hf, preset.hf)
  set_param(track, fx, PARAM.low, preset.low)
  set_param(track, fx, PARAM.center, preset.center)
  set_param(track, fx, PARAM.limiter, preset.limiter)
  set_param(track, fx, PARAM.output, preset.output)
  set_param(track, fx, PARAM.extra, preset.extra)
end

local function draw_presets(track, fx)
  ImGui.TextColored(ctx, COLORS.muted, "Presets")
  for index, preset in ipairs(PRESETS) do
    if index > 1 and index ~= 4 then ImGui.SameLine(ctx) end
    if ImGui.Button(ctx, preset.name .. "##preset" .. index) then
      apply_preset(track, fx, preset)
    end
  end
end

local function peak_to_norm(peak)
  if peak <= 0.000001 then return 0 end
  local db = 20 * math.log(peak) / math.log(10)
  return clamp((db + 60) / 60, 0, 1)
end

local function draw_meter(track, x, y, w, h)
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, COLORS.panel)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, COLORS.edge)
  ImGui.DrawList_AddText(dl, x + 12, y + 10, COLORS.text, "Output")
  for ch = 0, 1 do
    local mx = x + 80 + ch * 40
    local norm = peak_to_norm(reaper.Track_GetPeakInfo(track, ch) or 0)
    ImGui.DrawList_AddRectFilled(dl, mx, y + 16, mx + 24, y + h - 18, COLORS.bg)
    ImGui.DrawList_AddRectFilled(dl, mx, y + 16 + (h - 34) * (1 - norm), mx + 24, y + h - 18, COLORS.meter)
    ImGui.DrawList_AddRect(dl, mx, y + 16, mx + 24, y + h - 18, COLORS.edge)
    ImGui.DrawList_AddText(dl, mx + 7, y + h - 16, COLORS.muted, ch == 0 and "L" or "R")
  end
end

local function draw_visual(track, fx)
  local width = math.max(620, ImGui.GetContentRegionAvail(ctx) - 2)
  local height = 330
  ImGui.InvisibleButton(ctx, "##transaural_visual", width, height)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = x0 + width, y0 + height
  local cx, cy = x0 + width * 0.43, y0 + height * 0.58
  local r = math.min(width, height) * 0.30
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x1, y1, COLORS.bg)
  ImGui.DrawList_AddText(dl, x0 + 14, y0 + 14, COLORS.text, "Transaural Crosstalk Canceller")
  ImGui.DrawList_AddText(dl, x0 + 14, y0 + 34, COLORS.muted, "speaker playback / opposite-channel cancellation")

  local amount = get_param(track, fx, PARAM.amount, 100) / 100
  local mode = math.floor(get_param(track, fx, PARAM.mode, 1) + 0.5)
  local angle = math.rad(get_param(track, fx, PARAM.angle, 30))
  local head_cm = get_param(track, fx, PARAM.head, 18)
  local trim_ms = get_param(track, fx, PARAM.trim, 0)
  local hf_hz = get_param(track, fx, PARAM.hf, 6500)
  local low_hz = get_param(track, fx, PARAM.low, 120)
  local preserve = get_param(track, fx, PARAM.center, 0) / 100
  local out_db = get_param(track, fx, PARAM.output, -6)
  local delay_ms = head_cm * 0.01 * math.sin(angle) / 343 * 1000 + trim_ms

  local head_norm = clamp((head_cm - 12) / 12, 0, 1)
  local head_w = r * (0.34 + head_norm * 0.28)
  local ear_l = { x = cx - head_w * 0.5, y = cy }
  local ear_r = { x = cx + head_w * 0.5, y = cy }
  local spk_dist = r * 1.45
  local spk_l = { x = cx - math.sin(angle) * spk_dist, y = cy - math.cos(angle) * spk_dist }
  local spk_r = { x = cx + math.sin(angle) * spk_dist, y = cy - math.cos(angle) * spk_dist }

  ImGui.DrawList_AddCircle(dl, cx, cy, head_w * 0.52, color(0.65, 0.68, 0.70, 0.45), 48, 2)
  ImGui.DrawList_AddLine(dl, ear_l.x, ear_l.y + 18, ear_r.x, ear_r.y + 18, COLORS.edge, 1.5)
  ImGui.DrawList_AddLine(dl, ear_l.x, ear_l.y + 13, ear_l.x, ear_l.y + 23, COLORS.edge, 1.5)
  ImGui.DrawList_AddLine(dl, ear_r.x, ear_r.y + 13, ear_r.x, ear_r.y + 23, COLORS.edge, 1.5)
  ImGui.DrawList_AddCircleFilled(dl, ear_l.x, ear_l.y, 7, COLORS.direct, 18)
  ImGui.DrawList_AddCircleFilled(dl, ear_r.x, ear_r.y, 7, COLORS.direct, 18)
  ImGui.DrawList_AddRectFilled(dl, spk_l.x - 13, spk_l.y - 13, spk_l.x + 13, spk_l.y + 13, COLORS.speaker)
  ImGui.DrawList_AddRectFilled(dl, spk_r.x - 13, spk_r.y - 13, spk_r.x + 13, spk_r.y + 13, COLORS.speaker)
  ImGui.DrawList_AddText(dl, spk_l.x - 5, spk_l.y - 32, COLORS.text, "L")
  ImGui.DrawList_AddText(dl, spk_r.x - 5, spk_r.y - 32, COLORS.text, "R")

  local cancel_alpha = 0.18 + 0.60 * clamp(amount / 1.4, 0, 1)
  local cancel_thick = 1.0 + 3.0 * clamp(amount / 1.4, 0, 1)
  ImGui.DrawList_AddLine(dl, spk_l.x, spk_l.y, ear_l.x, ear_l.y, color(0.46, 0.86, 0.56, 0.72), 2.0)
  ImGui.DrawList_AddLine(dl, spk_r.x, spk_r.y, ear_r.x, ear_r.y, color(0.46, 0.86, 0.56, 0.72), 2.0)
  ImGui.DrawList_AddLine(dl, spk_l.x, spk_l.y, ear_r.x, ear_r.y, color(0.95, 0.58, 0.38, cancel_alpha), cancel_thick)
  ImGui.DrawList_AddLine(dl, spk_r.x, spk_r.y, ear_l.x, ear_l.y, color(0.95, 0.58, 0.38, cancel_alpha), cancel_thick)

  ImGui.DrawList_AddText(dl, x0 + 14, y1 - 58, COLORS.muted, string.format("%s / cancel %.0f%% / angle %.1f deg", MODES[mode + 1] or "Mode", amount * 100, math.deg(angle)))
  ImGui.DrawList_AddText(dl, x0 + 14, y1 - 36, COLORS.muted, string.format("derived ITD %.3f ms", delay_ms))
  ImGui.DrawList_AddText(dl, cx - 42, cy + 32, COLORS.muted, string.format("head %.1f cm", head_cm))
  ImGui.DrawList_AddText(dl, x0 + width - 260, y0 + 14, COLORS.muted, "Best on loudspeakers")
  ImGui.DrawList_AddText(dl, x0 + width - 260, y0 + 34, COLORS.muted, "Not a headphone binaural processor")

  local info_x = x0 + width - 260
  local info_y = y0 + 68
  local bar_w = 170
  local function info_bar(label, value, norm, bar_color)
    ImGui.DrawList_AddText(dl, info_x, info_y, COLORS.muted, label)
    ImGui.DrawList_AddText(dl, info_x + 92, info_y, COLORS.text, value)
    ImGui.DrawList_AddRectFilled(dl, info_x, info_y + 18, info_x + bar_w, info_y + 23, COLORS.panel)
    ImGui.DrawList_AddRectFilled(dl, info_x, info_y + 18, info_x + bar_w * clamp(norm, 0, 1), info_y + 23, bar_color)
    ImGui.DrawList_AddRect(dl, info_x, info_y + 18, info_x + bar_w, info_y + 23, COLORS.edge)
    info_y = info_y + 38
  end
  info_bar("HF rolloff", string.format("%.0f Hz", hf_hz), (hf_hz - 1000) / 15000, COLORS.cancel)
  info_bar("Low protect", string.format("%.0f Hz", low_hz), (low_hz - 20) / 480, color(0.42, 0.74, 0.96, 1))
  info_bar("Preserve", string.format("%.0f%%", preserve * 100), preserve, COLORS.direct)
  info_bar("Output", string.format("%.1f dB", out_db), (out_db + 24) / 36, COLORS.meter)

  draw_meter(track, x0 + width - 205, y1 - 110, 190, 92)
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 780, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, "Transaural Crosstalk Canceller", open)
  if visible then
    local track = reaper.GetSelectedTrack(PROJECT, 0)
    local fx = find_fx(track)
    if not track then
      ImGui.Text(ctx, "Select the target stereo track.")
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
        if param_warning ~= "" then ImGui.TextColored(ctx, color(0.95, 0.70, 0.35, 1), param_warning) end
        if not param_ready then
          ImGui.Text(ctx, "Click Repair JSFX to replace the stale effect instance with the current version.")
        else
          reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", math.max(2, reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")))
          draw_visual(track, fx)
          draw_presets(track, fx)
          if ImGui.CollapsingHeader(ctx, "Cancellation", nil, ImGui.TreeNodeFlags_DefaultOpen) then
            option_buttons(track, fx, "Cancellation mode", PARAM.mode, MODES, 2)
            slider_param(track, fx, "Cancellation amount", PARAM.amount, 0, 140, "%.0f %%")
            slider_param(track, fx, "Stereo preserve", PARAM.center, 0, 100, "%.0f %%")
          end
          if ImGui.CollapsingHeader(ctx, "Geometry", nil, ImGui.TreeNodeFlags_DefaultOpen) then
            slider_param(track, fx, "Speaker half-angle", PARAM.angle, 10, 60, "%.1f deg")
            slider_param(track, fx, "Head width", PARAM.head, 12, 24, "%.1f cm")
            slider_param(track, fx, "Delay trim", PARAM.trim, -0.5, 0.5, "%.3f ms")
          end
          if ImGui.CollapsingHeader(ctx, "Tone / Safety", nil, ImGui.TreeNodeFlags_DefaultOpen) then
            slider_param(track, fx, "Cancel HF rolloff", PARAM.hf, 1000, 16000, "%.0f Hz")
            slider_param(track, fx, "Low protect", PARAM.low, 20, 500, "%.0f Hz")
            option_buttons(track, fx, "Safety limiter", PARAM.limiter, LIMITER, 2)
            option_buttons(track, fx, "Extra channel output", PARAM.extra, EXTRA, 2)
            slider_param(track, fx, "Output gain", PARAM.output, -24, 12, "%.1f dB")
          end
          ImGui.TextColored(ctx, COLORS.muted, "Transaural processing is speaker/listener-position dependent; small geometry changes matter.")
        end
      end
    end
    ImGui.End(ctx)
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
