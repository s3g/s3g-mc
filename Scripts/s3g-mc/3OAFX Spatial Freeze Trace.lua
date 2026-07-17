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
  package.loaded["s3g-mc ImGui Theme"] = nil
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme then
    ui_theme = _s3g_theme
    if _s3g_theme.install then _s3g_theme.install(ImGui) end
  end
end
local theme = ui_theme or require("s3g-mc ImGui Theme")


local TITLE = "3OAFX Spatial Freeze Trace"
local EXT = "s3g_mc_3oafx_spatial_freeze_trace_v1"
local MODES = { "Freeze", "Trace", "Formant Ghost", "Residue Cloud" }
local MODE_KEYS = { "freeze", "trace", "formant_ghost", "residue_cloud" }
local FFT_NAMES = { "1024", "2048", "4096", "8192" }
local FFT_VALUES = { 1024, 2048, 4096, 8192 }
local ORDER_NAMES = { "1OA / 4ch", "2OA / 9ch", "3OA / 16ch" }


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
  return select(2, theme.combo_row(ImGui, ctx, label, names, index))
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
      theme.muted(ImGui, ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
      local sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Mode", 123)
      settings.order = combo("Ambisonic order", settings.order, ORDER_NAMES)
      settings.mode = combo("Mode", settings.mode, MODES)
      settings.fft = combo("FFT size", settings.fft, FFT_NAMES)
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)
      local changed
      sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Spectral", 248)
      changed, settings.duration = theme.slider_double(ImGui, ctx, "Output duration sec", settings.duration, 0.25, 600.0, "%.2f")
      changed, settings.freeze_pos = theme.slider_double(ImGui, ctx, "Freeze position", settings.freeze_pos, 0.0, 1.0, "%.3f")
      changed, settings.trace_width = theme.slider_double(ImGui, ctx, "Trace width", settings.trace_width, 0.01, 1.0, "%.3f")
      changed, settings.amount = theme.slider_double(ImGui, ctx, "Freeze/trace amount", settings.amount, 0.0, 1.0, "%.3f")
      changed, settings.wet_mix = theme.slider_double(ImGui, ctx, "Wet mix", settings.wet_mix, 0.0, 1.0, "%.3f")
      changed, settings.smooth_bins = theme.slider_int(ImGui, ctx, "Spectral smoothing bins", math.floor(settings.smooth_bins), 0, 96)
      changed, settings.ghost_smooth_bins = theme.slider_int(ImGui, ctx, "Ghost smoothing bins", math.floor(settings.ghost_smooth_bins), 0, 160)
      changed, settings.floor = theme.slider_double(ImGui, ctx, "Envelope floor", settings.floor, 0.0, 0.5, "%.3f")
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Spatial / Output", settings.normalize and 198 or 173)
      changed, settings.yaw_start = theme.slider_double(ImGui, ctx, "Yaw start deg", settings.yaw_start, -360.0, 360.0, "%.1f")
      changed, settings.yaw_end = theme.slider_double(ImGui, ctx, "Yaw end deg", settings.yaw_end, -360.0, 360.0, "%.1f")
      changed, settings.higher_order_weight = theme.slider_double(ImGui, ctx, "Higher-order weight", settings.higher_order_weight, 0.0, 2.0, "%.2f")
      changed, settings.w_weight = theme.slider_double(ImGui, ctx, "W weight", settings.w_weight, 0.0, 2.0, "%.2f")
      changed, settings.soft_limit = theme.checkbox_row(ImGui, ctx, "Soft limit before normalize", settings.soft_limit)
      changed, settings.normalize = theme.checkbox_row(ImGui, ctx, "Peak normalize", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = theme.slider_double(ImGui, ctx, "Normalize dB", settings.normalize_db, -24.0, 0.0, "%.1f")
      end
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)
      muted_wrapped_text("The same spectral frame or trace path is applied across all encoded channels, keeping the ambisonic channel set coherent.")
      ImGui.EndChild(ctx)
    end
    local render_pressed, cancel_pressed = theme.footer_buttons(ImGui, ctx, "RENDER", "CANCEL", 104, 104)
    if render_pressed then should_render = true end
    if cancel_pressed then open = false end
    ImGui.End(ctx)
  end
  persist()
  if should_render then open = false; render(); return end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
