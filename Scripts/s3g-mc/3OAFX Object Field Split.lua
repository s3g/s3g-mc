-- @description 3OAFX Object / Field Split
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline ambisonic split render.
-- @method Select one WAV-backed ACN/SN3D ambisonic media item. The renderer decodes it to the 3OAFX direction layer, estimates object-like and field-like material from transient, directional coherence, and spectral contrast cues, then re-encodes one or two new ambisonic items.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

local TITLE = "3OAFX Object / Field Split"

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", TITLE, 0)
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
package.loaded["s3g-mc ImGui Theme"] = nil
local theme = require("s3g-mc ImGui Theme")

local EXT = "s3g_mc_foafx_object_field_split_v1"

local ORDER_NAMES = { "1OA / 4ch", "2OA / 9ch", "3OA / 16ch" }
local ORDER_VALUES = { 1, 2, 3 }
local OUTPUT_NAMES = { "Both object and field", "Object only", "Field only" }
local OUTPUT_KEYS = { "both", "object", "field" }
local FFT_NAMES = { "1024", "2048", "4096" }
local FFT_VALUES = { 1024, 2048, 4096 }

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local COLORS = {
  bg = color(0.035, 0.039, 0.042, 1),
  panel = color(0.060, 0.066, 0.070, 1),
  edge = color(0.34, 0.38, 0.38, 1),
  text = color(0.78, 0.83, 0.82, 1),
  muted = color(0.48, 0.54, 0.54, 1),
  source = color(0.95, 0.68, 0.25, 0.95),
  object = color(0.98, 0.52, 0.28, 0.95),
  field = color(0.25, 0.68, 0.90, 0.92),
  arrow = color(0.62, 0.66, 0.66, 0.92),
}

local function get_number(key, default)
  return tonumber(reaper.GetExtState(EXT, key)) or default
end

local function get_bool(key, default)
  local value = reaper.GetExtState(EXT, key)
  if value == "" then return default end
  return value == "1"
end

local function set_value(key, value)
  reaper.SetExtState(EXT, key, type(value) == "boolean" and (value and "1" or "0") or tostring(value), true)
end

local function combo(ctx, label, index, names)
  return select(2, theme.combo_row(ImGui, ctx, label, names, index))
end

local function order_index_for_channels(channels)
  if channels >= 16 then return 3 end
  if channels >= 9 then return 2 end
  return 1
end

local function order_channels(order_index)
  local order = ORDER_VALUES[order_index] or 1
  return (order + 1) * (order + 1)
end

local function direction_count(order_index)
  local order = ORDER_VALUES[order_index] or 1
  if order <= 1 then return 6 end
  if order == 2 then return 12 end
  return 24
end

local function is_wav(path)
  return tostring(path or ""):lower():match("%.wav$") ~= nil
end

local function source_duration(entry)
  return entry.length * math.max(0.000001, entry.playrate or 1.0)
end

local function draw_box(draw_list, x0, y0, x1, y1, title, detail, border)
  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, COLORS.panel)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, border or COLORS.edge)
  ImGui.DrawList_AddText(draw_list, x0 + 10, y0 + 9, COLORS.text, title)
  ImGui.DrawList_AddText(draw_list, x0 + 10, y0 + 31, COLORS.muted, detail)
end

local function draw_arrow(draw_list, x0, y0, x1, y1, color)
  ImGui.DrawList_AddLine(draw_list, x0, y0, x1, y1, color, 2.0)
  ImGui.DrawList_AddTriangleFilled(draw_list, x1, y1, x1 - 7, y1 - 4, x1 - 7, y1 + 4, color)
end

local function draw_preview(ctx, settings)
  local width = math.max(560, ImGui.GetContentRegionAvail(ctx) - 2)
  local height = 220
  ImGui.InvisibleButton(ctx, "##object_field_split_preview", width, height)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = x0 + width, y0 + height
  local draw_list = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, COLORS.bg)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, COLORS.edge)
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 12, COLORS.text, "automatic object / field estimate")

  local margin = 16
  local top = y0 + 58
  local box_h = 62
  local source_w = math.max(150, width * 0.24)
  local cue_w = math.max(175, width * 0.28)
  local out_w = math.max(150, width * 0.22)
  local gap = (width - margin * 2 - source_w - cue_w - out_w) / 2
  local sx = x0 + margin
  local cx = sx + source_w + gap
  local ox = cx + cue_w + gap

  draw_box(draw_list, sx, top + 35, sx + source_w, top + 35 + box_h, "source HOA", ORDER_NAMES[settings.order_index], COLORS.source)
  draw_box(draw_list, cx, top, cx + cue_w, top + box_h, "object cues", "transient / coherent / contrast", COLORS.object)
  draw_box(draw_list, cx, top + 82, cx + cue_w, top + 82 + box_h, "field cues", "sustained / diffuse / blended", COLORS.field)
  draw_box(draw_list, ox, top, ox + out_w, top + box_h, "object output", "foreground stream", COLORS.object)
  draw_box(draw_list, ox, top + 82, ox + out_w, top + 82 + box_h, "field output", "spatial bed", COLORS.field)

  draw_arrow(draw_list, sx + source_w + 3, top + 35 + box_h * 0.5, cx - 5, top + box_h * 0.5, COLORS.object)
  draw_arrow(draw_list, sx + source_w + 3, top + 35 + box_h * 0.5, cx - 5, top + 82 + box_h * 0.5, COLORS.field)
  draw_arrow(draw_list, cx + cue_w + 3, top + box_h * 0.5, ox - 5, top + box_h * 0.5, COLORS.object)
  draw_arrow(draw_list, cx + cue_w + 3, top + 82 + box_h * 0.5, ox - 5, top + 82 + box_h * 0.5, COLORS.field)

  local bx = x0 + 18
  local by = y1 - 25
  local bw = width - 36
  ImGui.DrawList_AddRect(draw_list, bx, by, bx + bw, by + 10, COLORS.edge)
  ImGui.DrawList_AddRectFilled(draw_list, bx, by, bx + bw * settings.object_bias, by + 10, COLORS.object)
  ImGui.DrawList_AddRectFilled(draw_list, bx + bw * settings.object_bias, by, bx + bw, by + 10, COLORS.field)
  ImGui.DrawList_AddText(draw_list, bx, by - 18, COLORS.muted, "object bias")
end

local function validate(entry, settings)
  if not entry then return "Select one WAV-backed ambisonic media item." end
  if entry.filename == "" or not nr.file_exists(entry.filename) or not is_wav(entry.filename) then
    return "The source item must be backed by a readable WAV file."
  end
  local needed = order_channels(settings.order_index)
  if entry.channels < needed then
    return "The source item has " .. tostring(entry.channels) .. " channels, but this order needs " .. tostring(needed) .. "."
  end
  return nil
end

local entries = nr.selected_entries()
local entry = entries[1]
if not entry then
  mc.show_error("Select one WAV-backed ambisonic media item.")
  return
end

local settings = {
  order_index = math.max(1, math.min(3, math.floor(get_number("order_index", order_index_for_channels(entry.channels))))),
  output_index = math.max(1, math.min(#OUTPUT_NAMES, math.floor(get_number("output_index", 1)))),
  object_bias = get_number("object_bias", 0.55),
  transient_weight = get_number("transient_weight", 0.45),
  coherence_weight = get_number("coherence_weight", 0.45),
  contrast_weight = get_number("contrast_weight", 0.30),
  field_smoothing = get_number("field_smoothing", 0.45),
  crossfade = get_number("crossfade", 0.18),
  frequency_smoothing_bins = get_number("frequency_smoothing_bins", 3),
  temporal_smoothing = get_number("temporal_smoothing", 0.35),
  fft_index = math.max(1, math.min(#FFT_NAMES, math.floor(get_number("fft_index", 2)))),
  overlap = get_number("overlap", 4),
  normalize = get_bool("normalize", true),
  normalize_db = get_number("normalize_db", -6.0),
  dc_protect = get_bool("dc_protect", true),
}

local ctx = ImGui.CreateContext(TITLE)
local open = true
local should_render = false

local function persist()
  for key, value in pairs(settings) do set_value(key, value) end
end

local function render()
  local err = validate(entry, settings)
  if err then mc.show_error(err) return end
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local order = ORDER_VALUES[settings.order_index] or 1
  local output_channels = order_channels(settings.order_index)
  local out_dir = nr.output_dir("s3g_foafx_object_field_split_renders", entry.filename, script_dir)
  local object_path = out_dir .. "/s3g_foafx_object_" .. stamp .. "_" .. tostring(order) .. "oa.wav"
  local field_path = out_dir .. "/s3g_foafx_field_" .. stamp .. "_" .. tostring(order) .. "oa.wav"
  local fft_size = FFT_VALUES[settings.fft_index] or 2048
  local hop_size = math.floor(fft_size / math.max(1, settings.overlap) + 0.5)
  local manifest = {
    source_path = entry.filename,
    source_start = entry.start_offset or 0,
    source_duration = source_duration(entry),
    sample_rate = nr.source_sample_rate(entry),
    object_output_path = object_path,
    field_output_path = field_path,
    order = order,
    output_mode = OUTPUT_KEYS[settings.output_index] or "both",
    object_bias = settings.object_bias,
    transient_weight = settings.transient_weight,
    coherence_weight = settings.coherence_weight,
    contrast_weight = settings.contrast_weight,
    field_smoothing = settings.field_smoothing,
    crossfade = settings.crossfade,
    frequency_smoothing_bins = math.floor(settings.frequency_smoothing_bins + 0.5),
    temporal_smoothing = settings.temporal_smoothing,
    fft_size = fft_size,
    hop_size = hop_size,
    dc_protect = settings.dc_protect,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
  }
  local log, elapsed = nr.run_backend(script_dir, "foafx_object_field_split", manifest, TITLE)
  if not log then return end

  reaper.Undo_BeginBlock()
  local inserted = {}
  local mode = OUTPUT_KEYS[settings.output_index] or "both"
  if mode == "both" or mode == "object" then
    local item, insert_err = nr.insert_output_item(object_path, "3OAFX Object (" .. tostring(order) .. "OA)", entry.position, output_channels, { master_send = false, track_gain = 0.5 })
    if not item then reaper.Undo_EndBlock(TITLE, -1); mc.show_error(insert_err or "Could not insert object output.") return end
    inserted[#inserted + 1] = "Object: " .. object_path
  end
  if mode == "both" or mode == "field" then
    local item, insert_err = nr.insert_output_item(field_path, "3OAFX Field (" .. tostring(order) .. "OA)", entry.position, output_channels, { master_send = false, track_gain = 0.5 })
    if not item then reaper.Undo_EndBlock(TITLE, -1); mc.show_error(insert_err or "Could not insert field output.") return end
    inserted[#inserted + 1] = "Field: " .. field_path
  end
  reaper.Undo_EndBlock(TITLE, -1)

  local lines = {
    "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. "ch)",
    "Order: " .. tostring(order) .. "OA",
    "Output mode: " .. (OUTPUT_NAMES[settings.output_index] or "?"),
    "Direction feeds: " .. tostring(direction_count(settings.order_index)),
    "Master send: off",
    string.format("NumPy time: %.2f sec", elapsed),
  }
  if log ~= "" then lines[#lines + 1] = log end
  for _, line in ipairs(inserted) do lines[#lines + 1] = line end
  mc.print_plan(TITLE, lines)
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 720, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local footer_h = 40
    local body_h = math.max(360, ImGui.GetContentRegionAvail(ctx) - footer_h)
    if ImGui.BeginChild(ctx, "##object_field_split_body", 0, body_h) then
      theme.status_row(ImGui, ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)", "muted")
      draw_preview(ctx, settings)
      local sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Routing", 98)
      settings.order_index = combo(ctx, "Ambisonic order", settings.order_index, ORDER_NAMES)
      settings.output_index = combo(ctx, "Output", settings.output_index, OUTPUT_NAMES)
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)
      local changed
      sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Object / Field", 248)
      changed, settings.object_bias = theme.slider_double(ImGui, ctx, "Object bias", settings.object_bias, 0.0, 1.0, "%.2f")
      changed, settings.transient_weight = theme.slider_double(ImGui, ctx, "Transient weight", settings.transient_weight, 0.0, 1.0, "%.2f")
      changed, settings.coherence_weight = theme.slider_double(ImGui, ctx, "Directional coherence", settings.coherence_weight, 0.0, 1.0, "%.2f")
      changed, settings.contrast_weight = theme.slider_double(ImGui, ctx, "Spectral contrast", settings.contrast_weight, 0.0, 1.0, "%.2f")
      changed, settings.field_smoothing = theme.slider_double(ImGui, ctx, "Field smoothing", settings.field_smoothing, 0.0, 0.98, "%.2f")
      changed, settings.crossfade = theme.slider_double(ImGui, ctx, "Object / field crossfade", settings.crossfade, 0.0, 0.75, "%.2f")
      changed, settings.frequency_smoothing_bins = theme.slider_double(ImGui, ctx, "Frequency smoothing bins", settings.frequency_smoothing_bins, 0, 24, "%.0f")
      changed, settings.temporal_smoothing = theme.slider_double(ImGui, ctx, "Temporal smoothing", settings.temporal_smoothing, 0.0, 0.98, "%.2f")
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Analysis / Output", settings.normalize and 173 or 148)
      settings.fft_index = combo(ctx, "FFT size", settings.fft_index, FFT_NAMES)
      changed, settings.overlap = theme.slider_double(ImGui, ctx, "FFT overlap", settings.overlap, 2, 8, "%.0f")
      changed, settings.normalize = theme.checkbox_row(ImGui, ctx, "Peak normalize", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = theme.slider_double(ImGui, ctx, "Normalize dB", settings.normalize_db, -24.0, 0.0, "%.1f")
      end
      changed, settings.dc_protect = theme.checkbox_row(ImGui, ctx, "DC protect", settings.dc_protect)
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)
      theme.note_row(ImGui, ctx, "Object material is estimated from transient energy, concentration, and spectral contrast.")
    end
    ImGui.EndChild(ctx)
    ImGui.Spacing(ctx)
    local render_pressed, cancel_pressed = theme.footer_buttons(ImGui, ctx, "RENDER", "CANCEL")
    if render_pressed then should_render = true end
    if cancel_pressed then open = false end
    ImGui.End(ctx)
  end
  persist()
  if should_render then open = false; render(); return end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
