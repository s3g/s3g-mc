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
do
  local _s3g_theme_path = ({ reaper.get_action_context() })[2]
  if not _s3g_theme_path or _s3g_theme_path == "" then
    _s3g_theme_path = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
  end
  local _s3g_theme_dir = _s3g_theme_path:match("^(.*[/\\])") or ""
  package.path = _s3g_theme_dir .. "?.lua;" .. package.path
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme and _s3g_theme.install then _s3g_theme.install(ImGui) end
end

local theme = require("s3g-mc ImGui Theme")
local THEME = theme.palette(ImGui)

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
local active_preset = 2

local STYLE = {
  bg = THEME.bg,
  panel = THEME.panel,
  edge = THEME.edge,
  text = THEME.text,
  muted = THEME.value,
  speaker = THEME.fill,
  cancel = THEME.warn,
  direct = THEME.ok,
  meter = THEME.ok,
  fill = THEME.fill,
}

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
  local changed, new_value = theme.slider_double(ImGui, ctx, label, value, min_value, max_value, fmt, 360)
  if changed then set_param(track, fx, param, new_value) end
  return new_value or value
end

local function combo_option(track, fx, title, param, labels)
  local norm = fx >= 0 and reaper.TrackFX_GetParamNormalized(track, fx, param) or 0
  local current = math.floor(norm * (#labels - 1) + 0.5) + 1
  local changed, next_value = theme.combo_row(ImGui, ctx, title, labels, current, 210)
  if changed then
    reaper.TrackFX_SetParamNormalized(track, fx, param, ((next_value or current) - 1) / math.max(1, #labels - 1))
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
  local labels = {}
  for index, preset in ipairs(PRESETS) do labels[index] = preset.name end
  local changed, next_preset = theme.combo_row(ImGui, ctx, "Preset", labels, active_preset, 260)
  if changed and PRESETS[next_preset] then
    active_preset = next_preset
    apply_preset(track, fx, PRESETS[active_preset])
  end
end

local function peak_to_norm(peak)
  if peak <= 0.000001 then return 0 end
  local db = 20 * math.log(peak) / math.log(10)
  return clamp((db + 60) / 60, 0, 1)
end

local function draw_meter(track, x, y, w, h)
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, STYLE.panel)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, STYLE.edge)
  ImGui.DrawList_AddText(dl, x + 12, y + 10, STYLE.text, "Output")
  for ch = 0, 1 do
    local mx = x + 80 + ch * 40
    local norm = peak_to_norm(reaper.Track_GetPeakInfo(track, ch) or 0)
    ImGui.DrawList_AddRectFilled(dl, mx, y + 16, mx + 24, y + h - 18, STYLE.bg)
    ImGui.DrawList_AddRectFilled(dl, mx, y + 16 + (h - 34) * (1 - norm), mx + 24, y + h - 18, STYLE.meter)
    ImGui.DrawList_AddRect(dl, mx, y + 16, mx + 24, y + h - 18, STYLE.edge)
    ImGui.DrawList_AddText(dl, mx + 7, y + h - 16, STYLE.muted, ch == 0 and "L" or "R")
  end
end

local function loop()
  local tool_area_h = 366
  local window_h = 536
  ImGui.SetNextWindowSize(ctx, 780, window_h, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, "Transaural Crosstalk Canceller", open)
  if visible then
    local track = reaper.GetSelectedTrack(PROJECT, 0)
    local fx = find_fx(track)
    if not track then
      theme.muted(ImGui, ctx, "SELECT THE TARGET STEREO TRACK.")
    else
      local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
      theme.muted(ImGui, ctx, "TARGET: " .. (name ~= "" and name or "(UNNAMED)"))
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "REPAIR JSFX") then fx = maybe_load(track, true) end
      if fx < 0 then fx = maybe_load(track, false) end
      if fx < 0 then
        theme.muted(ImGui, ctx, load_error ~= "" and load_error or ("JS: " .. FX_NAME .. " IS NOT ON THE SELECTED TRACK."))
      else
        resolve_param_indices(track, fx)
        if param_warning ~= "" then theme.status(ImGui, ctx, param_warning, "amber") end
        if not param_ready then
          theme.muted(ImGui, ctx, "CLICK REPAIR JSFX TO REPLACE THE STALE EFFECT INSTANCE.")
        else
          reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", math.max(2, reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")))
          draw_presets(track, fx)
          local meter_x, meter_y = ImGui.GetCursorScreenPos(ctx)
          draw_meter(track, meter_x, meter_y, 220, 92)
          ImGui.Dummy(ctx, 220, 102)
          local tool_panel = theme.push_soft_panel(ImGui, ctx)
          if ImGui.BeginChild(ctx, "##transaural_tool_area", 0, tool_area_h, 0) then
          if theme.toolbox_header(ImGui, ctx, "CANCELLATION", ImGui.TreeNodeFlags_DefaultOpen) then
            combo_option(track, fx, "Cancellation mode", PARAM.mode, MODES)
            slider_param(track, fx, "Cancellation amount", PARAM.amount, 0, 140, "%.0f %%")
            slider_param(track, fx, "Stereo preserve", PARAM.center, 0, 100, "%.0f %%")
          end
          if theme.toolbox_header(ImGui, ctx, "GEOMETRY", ImGui.TreeNodeFlags_DefaultOpen) then
            slider_param(track, fx, "Speaker half-angle", PARAM.angle, 10, 60, "%.1f deg")
            slider_param(track, fx, "Head width", PARAM.head, 12, 24, "%.1f cm")
            slider_param(track, fx, "Delay trim", PARAM.trim, -0.5, 0.5, "%.3f ms")
          end
          if theme.toolbox_header(ImGui, ctx, "TONE / SAFETY", ImGui.TreeNodeFlags_DefaultOpen) then
            slider_param(track, fx, "Cancel HF rolloff", PARAM.hf, 1000, 16000, "%.0f Hz")
            slider_param(track, fx, "Low protect", PARAM.low, 20, 500, "%.0f Hz")
            combo_option(track, fx, "Safety limiter", PARAM.limiter, LIMITER)
            combo_option(track, fx, "Extra channel output", PARAM.extra, EXTRA)
            slider_param(track, fx, "Output gain", PARAM.output, -24, 12, "%.1f dB")
          end
          theme.muted(ImGui, ctx, "Transaural processing is speaker/listener-position dependent; small geometry changes matter.")
          end
          ImGui.EndChild(ctx)
          theme.pop_soft_panel(ImGui, ctx, tool_panel)
        end
      end
    end
    ImGui.End(ctx)
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
