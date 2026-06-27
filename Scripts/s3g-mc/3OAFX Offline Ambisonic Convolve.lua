-- @description 3OAFX Offline Ambisonic Convolve
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spatial / HOA
-- @render Yes; NumPy-backed offline ambisonic convolution render.
-- @method Select one ACN/SN3D ambisonic source WAV as the earliest selected item on the timeline, plus one or more ambisonic IR WAV items. The renderer decodes the source to virtual directions, convolves each direction with an ambisonic IR, sums the wet result, and writes a new ambisonic media item.
-- @about
--   Inspired by Bruce Wiggins' ambisonic measured reverb workflow described in
--   Sounds in Space 2017: transform ambisonic source material to a directional
--   intermediate, convolve each direction with a corresponding ambisonic impulse
--   response, then sum the result back to ambisonic B/HOA format.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

local TITLE = "3OAFX Offline Ambisonic Convolve"

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", TITLE, 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local WINDOW_OPEN_COND = ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver
local EXT = "s3g_mc_ambisonic_convolve_v1"
local COLOR_WARN = ImGui.ColorConvertDouble4ToU32(1.0, 0.70, 0.25, 1.0)
local COLOR_ERROR = ImGui.ColorConvertDouble4ToU32(1.0, 0.35, 0.22, 1.0)
local COLOR_BG = ImGui.ColorConvertDouble4ToU32(0.035, 0.039, 0.042, 1.0)
local COLOR_PANEL = ImGui.ColorConvertDouble4ToU32(0.060, 0.066, 0.070, 1.0)
local COLOR_EDGE = ImGui.ColorConvertDouble4ToU32(0.34, 0.38, 0.38, 1.0)
local COLOR_TEXT = ImGui.ColorConvertDouble4ToU32(0.78, 0.83, 0.82, 1.0)
local COLOR_MUTED = ImGui.ColorConvertDouble4ToU32(0.48, 0.54, 0.54, 1.0)
local COLOR_FLOW = ImGui.ColorConvertDouble4ToU32(0.95, 0.68, 0.25, 0.95)
local COLOR_WET = ImGui.ColorConvertDouble4ToU32(0.25, 0.68, 0.90, 0.92)
local COLOR_DRY = ImGui.ColorConvertDouble4ToU32(0.95, 0.38, 0.24, 0.80)

local ORDER_NAMES = { "1OA / 4ch", "2OA / 9ch", "3OA / 16ch" }
local ORDER_VALUES = { 1, 2, 3 }
local LAYOUT_NAMES = { "Wiggins tetrahedral / P-format", "Order virtual speaker layout" }
local LAYOUT_KEYS = { "tetra", "virtual" }
local TAIL_NAMES = { "Full convolution tail", "Trim to source length" }

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function get_number(key, default)
  local value = tonumber(reaper.GetExtState(EXT, key))
  return value or default
end

local function get_bool(key, default)
  local value = reaper.GetExtState(EXT, key)
  if value == "" then return default end
  return value == "1"
end

local function set_value(key, value)
  if type(value) == "boolean" then
    reaper.SetExtState(EXT, key, value and "1" or "0", true)
  else
    reaper.SetExtState(EXT, key, tostring(value), true)
  end
end

local function draw_combo(ctx, label, index, names)
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
  local order = ORDER_VALUES[order_index] or 1
  return (order + 1) * (order + 1)
end

local function direction_count(order_index, layout_index)
  local order = ORDER_VALUES[order_index] or 1
  if order == 1 and layout_index == 1 then return 4 end
  if order == 1 then return 6 end
  return 8
end

local function is_wav(path)
  return tostring(path or ""):lower():match("%.wav$") ~= nil
end

local function basename(path)
  return tostring(path or ""):match("[^/\\]+$") or tostring(path or "")
end

local function join_paths(entries, key)
  local parts = {}
  for _, entry in ipairs(entries) do
    parts[#parts + 1] = tostring(entry[key] or "")
  end
  return table.concat(parts, "||")
end

local function source_duration(entry)
  return entry.length * math.max(0.000001, entry.playrate or 1.0)
end

local function validate_entries(source, irs, order_index)
  if not source then return "Select an ambisonic source item." end
  if #irs < 1 then return "Select one or more ambisonic IR items with the source item." end
  if source.filename == "" or not nr.file_exists(source.filename) or not is_wav(source.filename) then
    return "The source item must be backed by a readable WAV file."
  end
  local needed = order_channels(order_index)
  if source.channels < needed then
    return "The source item has " .. tostring(source.channels) .. " channels, but this order needs " .. tostring(needed) .. "."
  end
  for index, ir in ipairs(irs) do
    if ir.filename == "" or not nr.file_exists(ir.filename) or not is_wav(ir.filename) then
      return "IR item " .. tostring(index) .. " must be backed by a readable WAV file."
    end
    if ir.channels < needed then
      return "IR item " .. tostring(index) .. " has " .. tostring(ir.channels) .. " channels, but this order needs " .. tostring(needed) .. "."
    end
  end
  return nil
end

local function draw_arrow(draw_list, x0, y0, x1, y1, color)
  ImGui.DrawList_AddLine(draw_list, x0, y0, x1, y1, color, 2.0)
  ImGui.DrawList_AddTriangleFilled(draw_list, x1, y1, x1 - 8, y1 - 5, x1 - 8, y1 + 5, color)
end

local function draw_box(draw_list, x0, y0, x1, y1, title, detail, color)
  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, COLOR_PANEL)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, color or COLOR_EDGE)
  ImGui.DrawList_AddText(draw_list, x0 + 9, y0 + 9, COLOR_TEXT, title)
  ImGui.DrawList_AddText(draw_list, x0 + 9, y0 + 30, COLOR_MUTED, detail)
end

local function draw_flow_graphic(ctx, settings, ir_count, stacked_bank)
  local width = math.max(520, ImGui.GetContentRegionAvail(ctx) - 2)
  local height = 154
  ImGui.InvisibleButton(ctx, "##ambi_convolve_flow", width, height)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1 = x0 + width
  local y1 = y0 + height
  local draw_list = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, COLOR_BG)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, COLOR_EDGE)

  local margin = 14
  local gap = 16
  local box_w = (width - margin * 2 - gap * 3) / 4
  local box_h = 76
  local by = y0 + 38
  local order_name = ORDER_NAMES[settings.order_index] or "Ambisonic"
  local directions = direction_count(settings.order_index, settings.layout_index)
  local assignment = stacked_bank and "stacked bank" or (ir_count == directions and "matched IR bank" or "wrapped IR bank")

  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 12, COLOR_TEXT, "offline ambisonic convolution path")
  local a0 = x0 + margin
  local b0 = a0 + box_w + gap
  local c0 = b0 + box_w + gap
  local d0 = c0 + box_w + gap
  draw_box(draw_list, a0, by, a0 + box_w, by + box_h, "ACN/SN3D source", order_name, COLOR_EDGE)
  draw_box(draw_list, b0, by, b0 + box_w, by + box_h, "direction feeds", tostring(directions) .. " P/virtual", COLOR_FLOW)
  draw_box(draw_list, c0, by, c0 + box_w, by + box_h, "ACN/SN3D IR bank", assignment, COLOR_WET)
  draw_box(draw_list, d0, by, d0 + box_w, by + box_h, "summed ACN/SN3D", order_name, COLOR_EDGE)
  local cy = by + box_h * 0.5
  draw_arrow(draw_list, a0 + box_w + 3, cy, b0 - 5, cy, COLOR_FLOW)
  draw_arrow(draw_list, b0 + box_w + 3, cy, c0 - 5, cy, COLOR_FLOW)
  draw_arrow(draw_list, c0 + box_w + 3, cy, d0 - 5, cy, COLOR_FLOW)
  ImGui.DrawList_AddLine(draw_list, a0 + box_w * 0.5, by + box_h + 8, d0 + box_w * 0.5, by + box_h + 8, COLOR_DRY, 1.5)
  ImGui.DrawList_AddText(draw_list, a0 + 6, by + box_h + 16, COLOR_MUTED, "IRs stay encoded ambisonic; only the source feed layer is P-format / virtual directional")
end

local function run_render(source, irs, settings)
  local err = validate_entries(source, irs, settings.order_index)
  if err then mc.show_error(err) return end

  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local order = ORDER_VALUES[settings.order_index] or 1
  local output_channels = order_channels(settings.order_index)
  local output_dir = nr.output_dir("s3g_ambisonic_convolution_renders", source.filename, script_dir)
  local output_path = output_dir .. "/s3g_ambisonic_convolve_" .. stamp .. "_" .. tostring(order) .. "oa.wav"
  local ir_starts = {}
  local ir_durations = {}
  for _, ir in ipairs(irs) do
    ir_starts[#ir_starts + 1] = tostring(ir.start_offset or 0)
    ir_durations[#ir_durations + 1] = tostring(source_duration(ir))
  end

  local manifest = {
    source_path = source.filename,
    source_start = source.start_offset or 0,
    source_duration = source_duration(source),
    sample_rate = nr.source_sample_rate(source),
    output_path = output_path,
    order = order,
    direction_layout = LAYOUT_KEYS[settings.layout_index] or "tetra",
    ir_paths = join_paths(irs, "filename"),
    ir_starts = table.concat(ir_starts, "||"),
    ir_durations = table.concat(ir_durations, "||"),
    dry_level = settings.dry_level,
    wet_level = settings.wet_level,
    wet_gain_db = settings.wet_gain_db,
    trim_to_source = settings.tail_index == 2,
    ir_normalize = settings.ir_normalize,
    dc_protect = settings.dc_protect,
    soft_limit = settings.soft_limit,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
  }

  local total_start = reaper.time_precise()
  local log, elapsed = nr.run_backend(script_dir, "ambisonic_convolve", manifest, TITLE)
  if not log then return end

  reaper.Undo_BeginBlock()
  local item, insert_err = nr.insert_output_item(output_path, "3OAFX convolve (" .. tostring(order) .. "OA)", source.position, output_channels, {
    track_gain = 0.5,
  })
  reaper.Undo_EndBlock(TITLE, -1)
  if not item then mc.show_error(insert_err or "Could not insert output item.") return end

  local lines = {
    "Source: " .. source.name .. " (" .. tostring(source.channels) .. "ch)",
    "IR items: " .. tostring(#irs),
    "Order: " .. tostring(order) .. "OA",
    "Virtual directions: " .. tostring(direction_count(settings.order_index, settings.layout_index)),
    "Direction layout: " .. (LAYOUT_NAMES[settings.layout_index] or "?"),
    "Tail: " .. (TAIL_NAMES[settings.tail_index] or "?"),
    "Backend: Python WAV reader + NumPy",
  }
  for index, ir in ipairs(irs) do
    lines[#lines + 1] = "IR " .. tostring(index) .. ": " .. basename(ir.filename) .. " (" .. tostring(ir.channels) .. "ch)"
  end
  if log ~= "" then lines[#lines + 1] = log end
  lines[#lines + 1] = "Inserted track gain: -6.0 dB"
  lines[#lines + 1] = string.format("NumPy time: %.2f sec", elapsed)
  lines[#lines + 1] = string.format("Total time: %.2f sec", reaper.time_precise() - total_start)
  lines[#lines + 1] = "Output: " .. output_path
  mc.print_plan(TITLE, lines)
end

local function main()
  local entries = nr.selected_entries()
  if #entries < 2 then
    mc.show_error("Select one ambisonic source item and one or more ambisonic IR items. The earliest selected item on the timeline is used as the source.")
    return
  end

  local source = entries[1]
  local irs = {}
  for index = 2, #entries do irs[#irs + 1] = entries[index] end

  local ctx = ImGui.CreateContext(TITLE)
  local open = true
  local should_render = false
  local settings = {
    order_index = clamp(math.floor(get_number("order_index", order_index_for_channels(source.channels))), 1, 3),
    layout_index = clamp(math.floor(get_number("layout_index", 1)), 1, #LAYOUT_NAMES),
    tail_index = clamp(math.floor(get_number("tail_index", 1)), 1, #TAIL_NAMES),
    dry_level = get_number("dry_level", 0.0),
    wet_level = get_number("wet_level", 1.0),
    wet_gain_db = get_number("wet_gain_db", -9.0),
    normalize = get_bool("normalize", true),
    normalize_db = get_number("normalize_db", -6.0),
    ir_normalize = get_bool("ir_normalize", true),
    dc_protect = get_bool("dc_protect", true),
    soft_limit = get_bool("soft_limit", true),
  }

  local function persist()
    for key, value in pairs(settings) do set_value(key, value) end
  end

  local function loop()
    ImGui.SetNextWindowSize(ctx, 720, 790, WINDOW_OPEN_COND)
    local visible
    visible, open = ImGui.Begin(ctx, TITLE, open)
    if visible then
      local needed = order_channels(settings.order_index)
      local directions = direction_count(settings.order_index, settings.layout_index)
      local stacked_bank = #irs == 1 and irs[1].channels >= needed * directions
      local validation = validate_entries(source, irs, settings.order_index)
      ImGui.Text(ctx, "Source: " .. source.name .. "  (" .. tostring(source.channels) .. " ch)")
      ImGui.Text(ctx, "IR items: " .. tostring(#irs))
      ImGui.Text(ctx, "Output: " .. ORDER_NAMES[settings.order_index])
      ImGui.Spacing(ctx)
      draw_flow_graphic(ctx, settings, #irs, stacked_bank)
      ImGui.Spacing(ctx)
      settings.order_index = draw_combo(ctx, "Ambisonic order", settings.order_index, ORDER_NAMES)
      settings.layout_index = draw_combo(ctx, "Direction layer", settings.layout_index, LAYOUT_NAMES)
      if settings.order_index ~= 1 and settings.layout_index == 1 then
        ImGui.TextColored(ctx, COLOR_WARN, "Tetrahedral mode is first-order only; higher orders use the order virtual layout.")
      end
      if settings.order_index >= 2 then
        ImGui.Text(ctx, "Higher-order convolve uses a practical 8-direction IR bank.")
      end
      settings.tail_index = draw_combo(ctx, "Output length", settings.tail_index, TAIL_NAMES)
      ImGui.Spacing(ctx)
      local changed
      changed, settings.dry_level = ImGui.SliderDouble(ctx, "Dry level", settings.dry_level, 0.0, 1.5, "%.2f")
      changed, settings.wet_level = ImGui.SliderDouble(ctx, "Wet level", settings.wet_level, 0.0, 2.0, "%.2f")
      changed, settings.wet_gain_db = ImGui.SliderDouble(ctx, "Wet pre-gain dB", settings.wet_gain_db, -36.0, 12.0, "%.1f")
      changed, settings.ir_normalize = ImGui.Checkbox(ctx, "Normalize each IR before convolution", settings.ir_normalize)
      changed, settings.dc_protect = ImGui.Checkbox(ctx, "DC protect", settings.dc_protect)
      changed, settings.soft_limit = ImGui.Checkbox(ctx, "Soft limit before normalize", settings.soft_limit)
      changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize output", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize peak dB", settings.normalize_db, -24.0, 0.0, "%.1f")
      end
      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Text(ctx, "Virtual directions: " .. tostring(directions))
      ImGui.Text(ctx, "Required channels per ambisonic item: " .. tostring(needed))
      if stacked_bank then
        ImGui.Text(ctx, "IR assignment: stacked bank detected (" .. tostring(irs[1].channels) .. " channels)")
      elseif #irs == directions then
        ImGui.Text(ctx, "IR assignment: one selected IR per virtual direction")
      else
        ImGui.Text(ctx, "IR assignment: selected IRs wrap across virtual directions")
      end
      ImGui.Spacing(ctx)
      if validation then
        ImGui.TextColored(ctx, COLOR_ERROR, validation)
      else
        ImGui.Text(ctx, "Renders offline from WAV media with NumPy.")
      end
      ImGui.Spacing(ctx)
      if ImGui.Button(ctx, "Render", 104, 28) and not validation then
        should_render = true
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 104, 28) then open = false end
      ImGui.End(ctx)
    end

    persist()
    if should_render then
      open = false
      run_render(source, irs, settings)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
