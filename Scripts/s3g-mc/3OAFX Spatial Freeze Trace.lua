-- @description 3OAFX Spatial Freeze Trace
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline ambisonic spectral freeze/trace render.
-- @method Select one WAV-backed ACN/SN3D ambisonic media item. The renderer applies a shared STFT freeze or trace process across the encoded channels, preserving channel coherence while adding optional HOA yaw drift and order weighting.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed.", "3OAFX Spatial Freeze Trace", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local ui_theme = nil
do
  local _s3g_theme_path = ({ reaper.get_action_context() })[2]
  if not _s3g_theme_path or _s3g_theme_path == "" then
    _s3g_theme_path = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
  end
  local _s3g_theme_dir = _s3g_theme_path:match("^(.*[/\\])") or ""
  package.path = _s3g_theme_dir .. "?.lua;" .. package.path
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme then
    ui_theme = _s3g_theme
    if _s3g_theme.install then _s3g_theme.install(ImGui) end
  end
end


local TITLE = "3OAFX Spatial Freeze Trace"
local EXT = "s3g_mc_3oafx_spatial_freeze_trace_v1"
local MODES = { "Freeze", "Trace", "Formant Ghost", "Residue Cloud" }
local MODE_KEYS = { "freeze", "trace", "formant_ghost", "residue_cloud" }
local FFT_NAMES = { "1024", "2048", "4096", "8192" }
local FFT_VALUES = { 1024, 2048, 4096, 8192 }
local ORDER_NAMES = { "1OA / 4ch", "2OA / 9ch", "3OA / 16ch" }

local CANVAS = {
  bg = ImGui.ColorConvertDouble4ToU32(0.035, 0.039, 0.042, 1),
  panel = ImGui.ColorConvertDouble4ToU32(0.055, 0.062, 0.064, 1),
  edge = ImGui.ColorConvertDouble4ToU32(0.35, 0.39, 0.39, 1),
  grid = ImGui.ColorConvertDouble4ToU32(0.55, 0.62, 0.62, 0.18),
  text = ImGui.ColorConvertDouble4ToU32(0.78, 0.83, 0.82, 1),
  muted = ImGui.ColorConvertDouble4ToU32(0.50, 0.56, 0.56, 1),
  cyan = ImGui.ColorConvertDouble4ToU32(0.24, 0.72, 0.86, 0.95),
  amber = ImGui.ColorConvertDouble4ToU32(0.92, 0.67, 0.26, 0.95),
  violet = ImGui.ColorConvertDouble4ToU32(0.66, 0.54, 0.92, 0.80),
}

local function muted_wrapped_text(value)
  if ui_theme and ui_theme.wrapped_text and ui_theme.palette then
    ui_theme.wrapped_text(ImGui, ctx, value, ui_theme.palette(ImGui).muted, 560)
  else
    ImGui.TextWrapped(ctx, value)
  end
end

local function getn(key, default)
  return tonumber(reaper.GetExtState(EXT, key)) or default
end

local function getb(key, default)
  local value = reaper.GetExtState(EXT, key)
  if value == "" then return default end
  return value ~= "0"
end

local function setv(key, value)
  if type(value) == "boolean" then
    reaper.SetExtState(EXT, key, value and "1" or "0", true)
  else
    reaper.SetExtState(EXT, key, tostring(value), true)
  end
end

local function combo(label, index, names)
  if ImGui.BeginCombo(ctx, label, names[index] or "") then
    for i, name in ipairs(names) do
      local selected = index == i
      if ImGui.Selectable(ctx, name, selected) then index = i end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return index
end

local function order_for_channels(channels)
  if channels >= 16 then return 3 end
  if channels >= 9 then return 2 end
  return 1
end

local function order_channels(order_index)
  local order = math.max(1, math.min(3, math.floor(order_index or 3)))
  return (order + 1) * (order + 1)
end

local entries = nr.selected_entries()
local entry = entries[1]
if not entry then
  mc.show_error("Select one WAV-backed ACN/SN3D ambisonic media item.")
  return
end

ctx = ImGui.CreateContext(TITLE)
local open = true
local should_render = false

local settings = {
  order = math.max(1, math.min(3, math.floor(getn("order", order_for_channels(entry.channels))))),
  mode = math.max(1, math.min(#MODES, math.floor(getn("mode", 1)))),
  fft = math.max(1, math.min(#FFT_NAMES, math.floor(getn("fft", 2)))),
  duration = getn("duration", entry.length),
  freeze_pos = getn("freeze_pos", 0.5),
  trace_width = getn("trace_width", 0.25),
  amount = getn("amount", 0.85),
  wet_mix = getn("wet_mix", 1.0),
  smooth_bins = getn("smooth_bins", 9),
  ghost_smooth_bins = getn("ghost_smooth_bins", 48),
  floor = getn("floor", 0.035),
  yaw_start = getn("yaw_start", 0.0),
  yaw_end = getn("yaw_end", 0.0),
  higher_order_weight = getn("higher_order_weight", 1.0),
  w_weight = getn("w_weight", 1.0),
  soft_limit = getb("soft_limit", true),
  normalize = getb("normalize", true),
  normalize_db = getn("normalize_db", -6.0),
}

local function persist()
  for key, value in pairs(settings) do setv(key, value) end
end

local function draw_preview()
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(420, ImGui.GetContentRegionAvail(ctx))
  local h = 168
  ImGui.InvisibleButton(ctx, "##freeze_trace_preview", w, h)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, CANVAS.bg)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, CANVAS.edge)
  ImGui.DrawList_AddText(dl, x + 12, y + 10, CANVAS.text, "spatial spectral imprint")
  ImGui.DrawList_AddText(dl, x + 12, y + 29, CANVAS.muted, MODES[settings.mode] .. " / " .. ORDER_NAMES[settings.order])
  local gx = x + 24
  local gy = y + 62
  local gw = w - 48
  local gh = 68
  ImGui.DrawList_AddRect(dl, gx, gy, gx + gw, gy + gh, CANVAS.grid)
  for i = 0, 8 do
    local px = gx + gw * i / 8
    ImGui.DrawList_AddLine(dl, px, gy, px, gy + gh, CANVAS.grid, 1)
  end
  for i = 0, 5 do
    local py = gy + gh * i / 5
    ImGui.DrawList_AddLine(dl, gx, py, gx + gw, py, CANVAS.grid, 1)
  end
  local center = gx + gw * settings.freeze_pos
  local half = gw * settings.trace_width * 0.5
  ImGui.DrawList_AddRectFilled(dl, math.max(gx, center - half), gy, math.min(gx + gw, center + half), gy + gh, CANVAS.violet)
  ImGui.DrawList_AddLine(dl, center, gy - 8, center, gy + gh + 8, CANVAS.amber, 2.2)
  local last_x, last_y
  for i = 0, 80 do
    local u = i / 80
    local px = gx + gw * u
    local py = gy + gh * (0.55 - 0.30 * math.sin(u * math.pi * 5.0 + settings.amount * 2.0) * (0.25 + settings.amount * 0.75))
    if last_x then ImGui.DrawList_AddLine(dl, last_x, last_y, px, py, CANVAS.cyan, 1.5) end
    last_x, last_y = px, py
  end
  local yaw_a = x + 24
  local yaw_b = x + 24 + (w - 48) * 0.5
  local yaw_c = x + w - 24
  local yy = y + h - 22
  ImGui.DrawList_AddText(dl, yaw_a, yy, CANVAS.muted, string.format("yaw %.0f", settings.yaw_start))
  ImGui.DrawList_AddLine(dl, yaw_b - 56, yy + 6, yaw_b + 56, yy + 6, CANVAS.amber, 1.5)
  ImGui.DrawList_AddTriangleFilled(dl, yaw_b + 56, yy + 6, yaw_b + 47, yy + 1, yaw_b + 47, yy + 11, CANVAS.amber)
  ImGui.DrawList_AddText(dl, yaw_c - 58, yy, CANVAS.muted, string.format("%.0f", settings.yaw_end))
end

local function render()
  local needed = order_channels(settings.order)
  if entry.channels < needed then
    mc.show_error("Selected item has " .. tostring(entry.channels) .. " channels; selected order needs " .. tostring(needed) .. ".")
    return
  end
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_foafx_spatial_freeze_trace_renders", entry.filename, script_dir)
  local output_path = out_dir .. "/s3g_foafx_spatial_freeze_trace_" .. stamp .. "_" .. tostring(settings.order) .. "oa.wav"
  local manifest = {
    source_path = entry.filename,
    source_start = entry.start_offset,
    source_duration = entry.length * math.max(0.000001, entry.playrate),
    sample_rate = nr.source_sample_rate(entry),
    output_path = output_path,
    order = settings.order,
    mode = MODE_KEYS[settings.mode],
    fft_size = FFT_VALUES[settings.fft] or 2048,
    overlap = 4,
    duration = settings.duration,
    freeze_pos = settings.freeze_pos,
    trace_width = settings.trace_width,
    amount = settings.amount,
    wet_mix = settings.wet_mix,
    smooth_bins = settings.smooth_bins,
    ghost_smooth_bins = settings.ghost_smooth_bins,
    floor = settings.floor,
    yaw_start = settings.yaw_start,
    yaw_end = settings.yaw_end,
    higher_order_weight = settings.higher_order_weight,
    w_weight = settings.w_weight,
    soft_limit = settings.soft_limit,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
  }
  local log, elapsed = nr.run_backend(script_dir, "foafx_spatial_freeze_trace", manifest, TITLE)
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path, "3OAFX spatial freeze trace (" .. tostring(settings.order) .. "OA)", entry.position, needed, {
    master_send = false,
    track_gain = 0.5,
  })
  reaper.Undo_EndBlock(TITLE, -1)
  if not item then mc.show_error(err or "Could not insert rendered item.") return end
  mc.print_plan(TITLE, {
    "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. "ch)",
    "Mode: " .. MODES[settings.mode],
    "Order: " .. tostring(settings.order) .. "OA",
    "Output: " .. output_path,
    "Master send: off",
    string.format("NumPy time: %.2f sec", elapsed),
    log,
  })
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 700, 780, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local footer_h = 42
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    if ImGui.BeginChild(ctx, "##body", 0, math.max(280, avail_h - footer_h)) then
      ImGui.Text(ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
      draw_preview()
      settings.order = combo("Ambisonic order", settings.order, ORDER_NAMES)
      settings.mode = combo("Mode", settings.mode, MODES)
      settings.fft = combo("FFT size", settings.fft, FFT_NAMES)
      local changed
      changed, settings.duration = ImGui.SliderDouble(ctx, "Output duration sec", settings.duration, 0.25, 600.0, "%.2f")
      changed, settings.freeze_pos = ImGui.SliderDouble(ctx, "Freeze position", settings.freeze_pos, 0.0, 1.0, "%.3f")
      changed, settings.trace_width = ImGui.SliderDouble(ctx, "Trace width", settings.trace_width, 0.01, 1.0, "%.3f")
      changed, settings.amount = ImGui.SliderDouble(ctx, "Freeze/trace amount", settings.amount, 0.0, 1.0, "%.3f")
      changed, settings.wet_mix = ImGui.SliderDouble(ctx, "Wet mix", settings.wet_mix, 0.0, 1.0, "%.3f")
      changed, settings.smooth_bins = ImGui.SliderInt(ctx, "Spectral smoothing bins", math.floor(settings.smooth_bins), 0, 96)
      changed, settings.ghost_smooth_bins = ImGui.SliderInt(ctx, "Ghost smoothing bins", math.floor(settings.ghost_smooth_bins), 0, 160)
      changed, settings.floor = ImGui.SliderDouble(ctx, "Envelope floor", settings.floor, 0.0, 0.5, "%.3f")
      ImGui.Separator(ctx)
      changed, settings.yaw_start = ImGui.SliderDouble(ctx, "Yaw start deg", settings.yaw_start, -360.0, 360.0, "%.1f")
      changed, settings.yaw_end = ImGui.SliderDouble(ctx, "Yaw end deg", settings.yaw_end, -360.0, 360.0, "%.1f")
      changed, settings.higher_order_weight = ImGui.SliderDouble(ctx, "Higher-order weight", settings.higher_order_weight, 0.0, 2.0, "%.2f")
      changed, settings.w_weight = ImGui.SliderDouble(ctx, "W weight", settings.w_weight, 0.0, 2.0, "%.2f")
      changed, settings.soft_limit = ImGui.Checkbox(ctx, "Soft limit before normalize", settings.soft_limit)
      changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -24.0, 0.0, "%.1f")
      end
      ImGui.Separator(ctx)
      muted_wrapped_text("The same spectral frame or trace path is applied across all encoded channels, keeping the ambisonic channel set coherent.")
      ImGui.EndChild(ctx)
    end
    if ImGui.Button(ctx, "Render", 104, 28) then should_render = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 104, 28) then open = false end
    ImGui.End(ctx)
  end
  persist()
  if should_render then open = false; render(); return end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
