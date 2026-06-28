-- @description 3OAFX Offline Ambisonic Convolve
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline ambisonic convolution render.
-- @method Select one ACN/SN3D ambisonic source WAV as the earliest selected item on the timeline, plus either one same-order ambisonic IR WAV or a direction-accurate ambisonic IR bank. Directional banks can optionally adapt lower-order IRs to the selected output order. The renderer writes a new ambisonic media item.
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
local METHOD_NAMES = { "Same-order direct convolution", "Directional IR bank" }
local METHOD_KEYS = { "direct", "bank" }
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

local function order_for_channels(channels)
  if channels >= 16 then return 3 end
  if channels >= 9 then return 2 end
  if channels >= 4 then return 1 end
  return 0
end

local function direction_count(order_index)
  local order = ORDER_VALUES[order_index] or 1
  if order == 1 then return 4 end
  return 8
end

local function uses_sparse_foa_bank(settings, irs)
  if settings.method_index ~= 2 or not settings.adapt_lower_order_ir or not settings.allow_sparse_foa_bank or settings.order_index <= 1 then
    return false
  end
  if #irs == 4 then
    for _, ir in ipairs(irs) do
      if ir.channels < 4 then return false end
    end
    return true
  end
  if #irs == 1 and irs[1].channels >= 16 and irs[1].channels < order_channels(settings.order_index) * direction_count(settings.order_index) then
    return true
  end
  return false
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

local function validate_entries(source, irs, settings)
  local order_index = settings.order_index
  local method_index = settings.method_index
  if not source then return "Select an ambisonic source item." end
  if #irs < 1 then return "Select one or more ambisonic IR items with the source item." end
  if source.filename == "" or not nr.file_exists(source.filename) or not is_wav(source.filename) then
    return "The source item must be backed by a readable WAV file."
  end
  local needed = order_channels(order_index)
  if source.channels < needed then
    return "The source item has " .. tostring(source.channels) .. " channels, but this order needs " .. tostring(needed) .. "."
  end
  local sparse_foa_bank = uses_sparse_foa_bank(settings, irs)
  local directions = sparse_foa_bank and 4 or direction_count(order_index)
  local stacked_bank = #irs == 1 and irs[1].channels >= needed * directions
  local adapted_stacked = false
  if method_index == 2 and settings.adapt_lower_order_ir and order_index > 1 and #irs == 1 then
    local lower_order = order_for_channels(math.floor(irs[1].channels / directions))
    adapted_stacked = lower_order > 0 and lower_order < order_index and irs[1].channels >= order_channels(lower_order) * directions
  end
  if method_index == 1 and #irs ~= 1 then
    return "Same-order direct convolution needs exactly one ambisonic IR item."
  end
  if method_index == 2 and not stacked_bank and not adapted_stacked and #irs ~= directions then
    return "Directional IR bank needs " .. tostring(directions) .. " IR items, or one stacked " .. tostring(needed * directions) .. "-channel bank."
  end
  for index, ir in ipairs(irs) do
    if ir.filename == "" or not nr.file_exists(ir.filename) or not is_wav(ir.filename) then
      return "IR item " .. tostring(index) .. " must be backed by a readable WAV file."
    end
    local required = (method_index == 2 and #irs == 1 and index == 1) and (needed * directions) or needed
    if method_index == 2 and settings.adapt_lower_order_ir and order_index > 1 then
      if #irs == 1 then
        required = adapted_stacked and order_channels(order_for_channels(math.floor(ir.channels / directions))) * directions or required
      else
        local ir_order = order_for_channels(ir.channels)
        if ir_order > 0 and ir_order < order_index then required = order_channels(ir_order) end
      end
    end
    if ir.channels < required then
      return "IR item " .. tostring(index) .. " has " .. tostring(ir.channels) .. " channels, but this method needs " .. tostring(required) .. "."
    end
    if method_index == 2 and settings.adapt_lower_order_ir and #irs ~= 1 and order_index > 1 then
      local ir_order = order_for_channels(ir.channels)
      if ir_order == 0 then return "IR item " .. tostring(index) .. " has too few channels for ambisonic adaptation." end
      if ir_order > order_index then return "IR item " .. tostring(index) .. " is higher order than the selected output order." end
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

local function draw_flow_graphic(ctx, settings, ir_count, stacked_bank, adapted_stacked, directions)
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
  directions = directions or direction_count(settings.order_index)
  local is_bank = settings.method_index == 2
  local assignment = settings.method_index == 1 and "one matching IR" or ((stacked_bank or adapted_stacked) and "stacked bank" or tostring(directions) .. " matched IRs")
  local middle_title = is_bank and "direction feeds" or "channel convolution"
  local middle_detail = is_bank and tostring(directions) .. " P/virtual" or "same-order"

  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 12, COLOR_TEXT, "offline ambisonic convolution path")
  local a0 = x0 + margin
  local b0 = a0 + box_w + gap
  local c0 = b0 + box_w + gap
  local d0 = c0 + box_w + gap
  draw_box(draw_list, a0, by, a0 + box_w, by + box_h, "ACN/SN3D source", order_name, COLOR_EDGE)
  draw_box(draw_list, b0, by, b0 + box_w, by + box_h, middle_title, middle_detail, COLOR_FLOW)
  draw_box(draw_list, c0, by, c0 + box_w, by + box_h, "ACN/SN3D IR bank", assignment, COLOR_WET)
  draw_box(draw_list, d0, by, d0 + box_w, by + box_h, "summed ACN/SN3D", order_name, COLOR_EDGE)
  local cy = by + box_h * 0.5
  draw_arrow(draw_list, a0 + box_w + 3, cy, b0 - 5, cy, COLOR_FLOW)
  draw_arrow(draw_list, b0 + box_w + 3, cy, c0 - 5, cy, COLOR_FLOW)
  draw_arrow(draw_list, c0 + box_w + 3, cy, d0 - 5, cy, COLOR_FLOW)
  ImGui.DrawList_AddLine(draw_list, a0 + box_w * 0.5, by + box_h + 8, d0 + box_w * 0.5, by + box_h + 8, COLOR_DRY, 1.5)
  if is_bank then
    ImGui.DrawList_AddText(draw_list, a0 + 6, by + box_h + 16, COLOR_MUTED, "IRs stay encoded ambisonic; only the source feed layer is P-format / virtual directional")
  else
    ImGui.DrawList_AddText(draw_list, a0 + 6, by + box_h + 16, COLOR_MUTED, "One ambisonic source convolved channel-for-channel with one same-order ambisonic IR")
  end
end

local function direction_layout_points(settings, sparse_foa_bank)
  if settings.method_index ~= 2 then return {} end
  if settings.order_index == 1 or sparse_foa_bank then
    return {
      { az = 45.0, el = 35.26438968 },
      { az = -45.0, el = -35.26438968 },
      { az = 135.0, el = -35.26438968 },
      { az = -135.0, el = 35.26438968 },
    }
  end
  return {
    { az = 45.0, el = 35.26438968 },
    { az = -45.0, el = 35.26438968 },
    { az = 135.0, el = 35.26438968 },
    { az = -135.0, el = 35.26438968 },
    { az = 45.0, el = -35.26438968 },
    { az = -45.0, el = -35.26438968 },
    { az = 135.0, el = -35.26438968 },
    { az = -135.0, el = -35.26438968 },
  }
end

local function projected_point(point, cx, cy, scale)
  local az = math.rad(point.az)
  local el = math.rad(point.el)
  local x = math.sin(az) * math.cos(el)
  local y = math.cos(az) * math.cos(el)
  local z = math.sin(el)
  local view = math.rad(28.0)
  local rx = x * math.cos(view) - y * math.sin(view)
  local ry = x * math.sin(view) + y * math.cos(view)
  local sx = rx * 0.92
  local sy = ry * 0.32 - z * 0.92
  local depth = -x
  return cx + sx * scale, cy + sy * scale, depth
end

local function direction_name(point)
  local lr = point.az < 0 and "L" or "R"
  local fb = math.abs(point.az) <= 90 and "front" or "rear"
  local ud = point.el >= 0 and "up" or "down"
  return lr .. " " .. fb .. " " .. ud
end

local function mic_capsule_point(index, cx, cy, scale)
  local angles = { -45, -135, 45, 135 }
  local angle = math.rad(angles[index] or 0)
  local radius = scale * 0.58
  return cx + math.cos(angle) * radius, cy + math.sin(angle) * radius
end

local function cube_map_point(index, cx, cy, scale)
  local is_down = index >= 5
  local local_index = is_down and (index - 4) or index
  local layer_y = cy + (is_down and scale * 0.42 or -scale * 0.42)
  local x = (local_index == 1 or local_index == 3) and scale * 0.36 or -scale * 0.36
  local y = (local_index == 1 or local_index == 2) and -scale * 0.20 or scale * 0.20
  return cx + x, layer_y + y, 0
end

local function draw_direction_map(ctx, settings, irs, stacked_bank, adapted_stacked, sparse_foa_bank)
  local points = direction_layout_points(settings, sparse_foa_bank)
  local width = math.max(520, ImGui.GetContentRegionAvail(ctx) - 2)
  local height = settings.method_index == 2 and 214 or 92
  ImGui.InvisibleButton(ctx, "##ambi_convolve_direction_map", width, height)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = x0 + width, y0 + height
  local draw_list = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, COLOR_BG)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, COLOR_EDGE)
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 12, COLOR_TEXT, "direction assignment")

  if settings.method_index ~= 2 then
    ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 38, COLOR_MUTED, "Direct mode does not use direction IRs; the selected IR is convolved channel-for-channel with the source.")
    return
  end

  local cx = x0 + math.min(210, width * 0.34)
  local cy = y0 + 118
  local scale = math.min(76, width * 0.14)
  local label_x = x0 + math.min(330, width * 0.52)
  local label_y = y0 + 40
  local point_color = stacked_bank and COLOR_WET or COLOR_FLOW
  local line_color = ImGui.ColorConvertDouble4ToU32(0.36, 0.40, 0.40, 1.0)
  local far_line_color = ImGui.ColorConvertDouble4ToU32(0.20, 0.23, 0.24, 1.0)
  local axis_color = ImGui.ColorConvertDouble4ToU32(0.25, 0.29, 0.30, 1.0)

  ImGui.DrawList_AddLine(draw_list, cx - scale * 1.08, cy, cx + scale * 1.08, cy, axis_color, 1.0)
  ImGui.DrawList_AddLine(draw_list, cx, cy + scale * 0.82, cx, cy - scale * 1.08, axis_color, 1.0)

  if #points == 8 then
    local projected = {}
    for index, point in ipairs(points) do
      local px, py, depth = cube_map_point(index, cx, cy, scale)
      projected[index] = { x = px, y = py, depth = 0 }
    end
    local edges = { {1, 2}, {2, 4}, {4, 3}, {3, 1}, {5, 6}, {6, 8}, {8, 7}, {7, 5} }
    for _, edge in ipairs(edges) do
      local color = line_color
      ImGui.DrawList_AddLine(draw_list, projected[edge[1]].x, projected[edge[1]].y, projected[edge[2]].x, projected[edge[2]].y, color, 1.2)
    end
    ImGui.DrawList_AddText(draw_list, cx - 44, y0 + 38, COLOR_MUTED, "8-dir map")
    ImGui.DrawList_AddText(draw_list, cx - 16, cy - scale * 0.82, COLOR_MUTED, "up +")
    ImGui.DrawList_AddText(draw_list, cx - 24, cy + scale * 0.72, COLOR_MUTED, "down -")
    ImGui.DrawList_AddText(draw_list, cx - scale * 0.68, cy - scale * 0.42 - 6, COLOR_MUTED, "L")
    ImGui.DrawList_AddText(draw_list, cx + scale * 0.56, cy - scale * 0.42 - 6, COLOR_MUTED, "R")
    ImGui.DrawList_AddText(draw_list, cx - scale * 0.68, cy + scale * 0.42 - 6, COLOR_MUTED, "L")
    ImGui.DrawList_AddText(draw_list, cx + scale * 0.56, cy + scale * 0.42 - 6, COLOR_MUTED, "R")
  else
    local projected = {}
    for index, point in ipairs(points) do
      local px, py = mic_capsule_point(index, cx, cy, scale)
      projected[index] = { x = px, y = py, depth = 0 }
    end
    ImGui.DrawList_AddCircleFilled(draw_list, cx, cy, 4.5, axis_color, 12)
    ImGui.DrawList_AddText(draw_list, cx - 14, cy - scale * 0.82, COLOR_MUTED, "front")
    ImGui.DrawList_AddText(draw_list, cx - 10, cy + scale * 0.72, COLOR_MUTED, "rear")
    ImGui.DrawList_AddText(draw_list, cx - scale * 0.92, cy - 7, COLOR_MUTED, "L")
    ImGui.DrawList_AddText(draw_list, cx + scale * 0.84, cy - 7, COLOR_MUTED, "R")
    for index, p in ipairs(projected) do
      ImGui.DrawList_AddLine(draw_list, cx, cy, p.x, p.y, line_color, 1.0)
      local marker = (index == 1 or index == 4) and "+" or "-"
      ImGui.DrawList_AddText(draw_list, p.x + 14, p.y - 7, COLOR_MUTED, marker)
    end
    ImGui.DrawList_AddText(draw_list, cx - 76, y0 + 38, COLOR_MUTED, "tetra 1OA map")
  end

  local draw_points = {}
  for index, point in ipairs(points) do
    local px, py, depth
    if #points == 4 then
      px, py = mic_capsule_point(index, cx, cy, scale)
      depth = 0
    elseif #points == 8 then
      px, py, depth = cube_map_point(index, cx, cy, scale)
    else
      px, py, depth = projected_point(point, cx, cy, scale)
    end
    draw_points[#draw_points + 1] = { index = index, x = px, y = py, depth = depth }
  end
  table.sort(draw_points, function(a, b) return a.depth < b.depth end)
  for _, point in ipairs(draw_points) do
    local radius = 12
    ImGui.DrawList_AddCircleFilled(draw_list, point.x, point.y, radius, point_color, 16)
    ImGui.DrawList_AddText(draw_list, point.x - (point.index >= 10 and 7 or 4), point.y - 7, COLOR_BG, tostring(point.index))
  end

  local assignment_detail
  if stacked_bank then
    assignment_detail = "stacked bank block"
  elseif adapted_stacked then
    assignment_detail = "adapted lower-order block"
  else
    assignment_detail = "selected IR"
  end
  ImGui.DrawList_AddText(draw_list, label_x, label_y - 20, COLOR_MUTED, assignment_detail .. " -> direction")
  for index, point in ipairs(points) do
    local source_label
    if stacked_bank or adapted_stacked then
      source_label = "block " .. tostring(index)
    else
      source_label = "IR " .. tostring(index)
    end
    local text = string.format("%s -> %02d  %s  az %.0f  el %.0f", source_label, index, direction_name(point), point.az, point.el)
    local text_color = (index <= #irs or stacked_bank or adapted_stacked) and COLOR_TEXT or COLOR_MUTED
    ImGui.DrawList_AddText(draw_list, label_x, label_y + (index - 1) * 18, text_color, text)
  end
end

local function run_render(source, irs, settings)
  local err = validate_entries(source, irs, settings)
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
    convolve_mode = METHOD_KEYS[settings.method_index] or "direct",
    direction_layout = uses_sparse_foa_bank(settings, irs) and "tetra" or (order == 1 and "tetra" or "virtual"),
    ir_paths = join_paths(irs, "filename"),
    ir_starts = table.concat(ir_starts, "||"),
    ir_durations = table.concat(ir_durations, "||"),
    dry_level = settings.dry_level,
    wet_level = settings.wet_level,
    wet_gain_db = settings.wet_gain_db,
    trim_to_source = settings.tail_index == 2,
    ir_normalize = settings.ir_normalize,
    adapt_lower_order_ir = settings.adapt_lower_order_ir,
    allow_sparse_foa_bank = settings.allow_sparse_foa_bank,
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
    master_send = false,
    track_gain = 0.5,
  })
  reaper.Undo_EndBlock(TITLE, -1)
  if not item then mc.show_error(insert_err or "Could not insert output item.") return end

  local lines = {
    "Source: " .. source.name .. " (" .. tostring(source.channels) .. "ch)",
    "IR items: " .. tostring(#irs),
    "Order: " .. tostring(order) .. "OA",
    "Convolution method: " .. (METHOD_NAMES[settings.method_index] or "?"),
    "Virtual directions: " .. (settings.method_index == 2 and tostring(direction_count(settings.order_index)) or "none"),
    "Tail: " .. (TAIL_NAMES[settings.tail_index] or "?"),
    "Backend: Python WAV reader + NumPy",
  }
  for index, ir in ipairs(irs) do
    lines[#lines + 1] = "IR " .. tostring(index) .. ": " .. basename(ir.filename) .. " (" .. tostring(ir.channels) .. "ch)"
  end
  if log ~= "" then lines[#lines + 1] = log end
  lines[#lines + 1] = "Inserted track gain: -6.0 dB"
  lines[#lines + 1] = "Master send: off"
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
    method_index = clamp(math.floor(get_number("method_index", 1)), 1, #METHOD_NAMES),
    tail_index = clamp(math.floor(get_number("tail_index", 1)), 1, #TAIL_NAMES),
    dry_level = get_number("dry_level", 0.0),
    wet_level = get_number("wet_level", 1.0),
    wet_gain_db = get_number("wet_gain_db", -9.0),
    normalize = get_bool("normalize", true),
    normalize_db = get_number("normalize_db", -6.0),
    ir_normalize = get_bool("ir_normalize", true),
    adapt_lower_order_ir = get_bool("adapt_lower_order_ir", false),
    allow_sparse_foa_bank = get_bool("allow_sparse_foa_bank", false),
    dc_protect = get_bool("dc_protect", true),
    soft_limit = get_bool("soft_limit", true),
  }

  local function persist()
    for key, value in pairs(settings) do set_value(key, value) end
  end

  local function loop()
    ImGui.SetNextWindowSize(ctx, 760, 960, WINDOW_OPEN_COND)
    local visible
    visible, open = ImGui.Begin(ctx, TITLE, open)
    if visible then
      local needed = order_channels(settings.order_index)
      local sparse_foa_bank = uses_sparse_foa_bank(settings, irs)
      local directions = sparse_foa_bank and 4 or direction_count(settings.order_index)
      local stacked_bank = settings.method_index == 2 and #irs == 1 and irs[1].channels >= needed * directions
      local adapted_stacked = settings.method_index == 2 and settings.adapt_lower_order_ir and #irs == 1 and irs[1].channels < needed * directions
      local validation = validate_entries(source, irs, settings)
      ImGui.Text(ctx, "Source: " .. source.name .. "  (" .. tostring(source.channels) .. " ch)")
      ImGui.Text(ctx, "IR items: " .. tostring(#irs))
      ImGui.Text(ctx, "Output: " .. ORDER_NAMES[settings.order_index])
      ImGui.Spacing(ctx)
      draw_flow_graphic(ctx, settings, #irs, stacked_bank, adapted_stacked, directions)
      ImGui.Spacing(ctx)
      draw_direction_map(ctx, settings, irs, stacked_bank, adapted_stacked, sparse_foa_bank)
      ImGui.Spacing(ctx)
      settings.order_index = draw_combo(ctx, "Ambisonic order", settings.order_index, ORDER_NAMES)
      settings.method_index = draw_combo(ctx, "Convolution method", settings.method_index, METHOD_NAMES)
      if settings.method_index == 2 then
        if settings.order_index == 1 then
          ImGui.Text(ctx, "First-order bank uses the four-direction P-format / tetrahedral method.")
        elseif sparse_foa_bank then
          ImGui.Text(ctx, "Sparse bank uses four P-format / tetrahedral directions.")
        else
          ImGui.Text(ctx, "Higher-order bank uses eight matched directions: 2OA stacked = 72ch, 3OA stacked = 128ch.")
        end
      else
        ImGui.Text(ctx, "Direct mode convolves one ambisonic source with one same-order ambisonic IR.")
      end
      settings.tail_index = draw_combo(ctx, "Output length", settings.tail_index, TAIL_NAMES)
      ImGui.Spacing(ctx)
      local changed
      changed, settings.dry_level = ImGui.SliderDouble(ctx, "Dry level", settings.dry_level, 0.0, 1.5, "%.2f")
      changed, settings.wet_level = ImGui.SliderDouble(ctx, "Wet level", settings.wet_level, 0.0, 2.0, "%.2f")
      changed, settings.wet_gain_db = ImGui.SliderDouble(ctx, "Wet pre-gain dB", settings.wet_gain_db, -36.0, 12.0, "%.1f")
      changed, settings.ir_normalize = ImGui.Checkbox(ctx, "Normalize each IR before convolution", settings.ir_normalize)
      if settings.method_index == 2 and settings.order_index > 1 then
        changed, settings.adapt_lower_order_ir = ImGui.Checkbox(ctx, "Adapt lower-order IRs to output order", settings.adapt_lower_order_ir)
        if settings.adapt_lower_order_ir then
          ImGui.Text(ctx, "Uses lower-order direction/energy to infer a higher-order encoded IR.")
          changed, settings.allow_sparse_foa_bank = ImGui.Checkbox(ctx, "Allow sparse 4-direction FOA bank", settings.allow_sparse_foa_bank)
          if settings.allow_sparse_foa_bank then
            ImGui.Text(ctx, "Uses the four P-format / tetrahedral directions; other directions are absent.")
          end
        end
      end
      changed, settings.dc_protect = ImGui.Checkbox(ctx, "DC protect", settings.dc_protect)
      changed, settings.soft_limit = ImGui.Checkbox(ctx, "Soft limit before normalize", settings.soft_limit)
      changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize output", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize peak dB", settings.normalize_db, -24.0, 0.0, "%.1f")
      end
      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Text(ctx, "Required channels per ambisonic item: " .. tostring(needed))
      if settings.method_index == 1 then
        ImGui.Text(ctx, "IR assignment: one same-order IR")
      else
        ImGui.Text(ctx, "Virtual directions: " .. tostring(directions))
        if stacked_bank then
          ImGui.Text(ctx, "IR assignment: stacked bank detected (" .. tostring(irs[1].channels) .. " channels)")
        elseif adapted_stacked then
          ImGui.Text(ctx, "IR assignment: lower-order stacked bank detected (" .. tostring(irs[1].channels) .. " channels)")
        elseif #irs == directions then
          ImGui.Text(ctx, "IR assignment: one selected IR per virtual direction")
        else
          ImGui.TextColored(ctx, COLOR_ERROR, "IR assignment is not direction-matched.")
        end
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
