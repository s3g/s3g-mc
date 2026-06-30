-- @description 3OAFX Ambisonic Kernel Collage
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline ambisonic creative convolution render.
-- @method Select one ACN/SN3D ambisonic source WAV as the earliest selected item on the timeline, plus one or more same-order ambisonic recordings to use as convolution kernels. The renderer treats the kernel recordings as spatial/spectral imprints and writes a new ambisonic media item.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

local TITLE = "3OAFX Ambisonic Kernel Collage"

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", TITLE, 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local WINDOW_OPEN_COND = ImGui.Cond_Appearing
local EXT = "s3g_mc_ambisonic_kernel_collage_v1"
local COLOR_BG = ImGui.ColorConvertDouble4ToU32(0.035, 0.039, 0.042, 1.0)
local COLOR_PANEL = ImGui.ColorConvertDouble4ToU32(0.060, 0.066, 0.070, 1.0)
local COLOR_EDGE = ImGui.ColorConvertDouble4ToU32(0.34, 0.38, 0.38, 1.0)
local COLOR_TEXT = ImGui.ColorConvertDouble4ToU32(0.78, 0.83, 0.82, 1.0)
local COLOR_MUTED = ImGui.ColorConvertDouble4ToU32(0.48, 0.54, 0.54, 1.0)
local COLOR_FLOW = ImGui.ColorConvertDouble4ToU32(0.95, 0.68, 0.25, 0.95)
local COLOR_WET = ImGui.ColorConvertDouble4ToU32(0.25, 0.68, 0.90, 0.92)
local COLOR_WARN = ImGui.ColorConvertDouble4ToU32(1.0, 0.70, 0.25, 1.0)
local COLOR_ERROR = ImGui.ColorConvertDouble4ToU32(1.0, 0.35, 0.22, 1.0)

local ORDER_NAMES = { "1OA / 4ch", "2OA / 9ch", "3OA / 16ch" }
local ORDER_VALUES = { 1, 2, 3 }
local LAYER_NAMES = { "Auto by order", "4-direction tetrahedral / 1OA mic", "Axial/cube direction layer" }
local LAYER_KEYS = { "auto", "tetra", "virtual" }
local ASSIGNMENT_NAMES = { "Cycle kernels across directions", "Random one per direction", "Dense all kernels per direction", "Kernel index equals direction", "Region smear" }
local ASSIGNMENT_KEYS = { "cycle", "random", "all", "indexed", "region" }
local TAIL_NAMES = { "Limit tail", "Full convolution tail", "Trim to source length" }
local TAIL_KEYS = { "max_tail", "full", "source" }

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

local function combo(ctx, label, index, names)
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

local function direction_count(order_index)
  local order = ORDER_VALUES[order_index] or 1
  if order == 1 then return 4 end
  return 8
end

local function direction_count_for(settings)
  if settings.layer_index == 2 then return 4 end
  if settings.layer_index == 3 and settings.order_index == 1 then return 6 end
  if settings.layer_index == 3 then return 8 end
  return direction_count(settings.order_index)
end

local function is_wav(path)
  return tostring(path or ""):lower():match("%.wav$") ~= nil
end

local function basename(path)
  return tostring(path or ""):match("[^/\\]+$") or tostring(path or "")
end

local function source_duration(entry)
  return entry.length * math.max(0.000001, entry.playrate or 1.0)
end

local function join_paths(entries, key)
  local parts = {}
  for _, entry in ipairs(entries) do
    parts[#parts + 1] = tostring(entry[key] or "")
  end
  return table.concat(parts, "||")
end

local function validate(source, kernels, settings)
  if not source then return "Select an ambisonic source item." end
  if #kernels < 1 then return "Select one or more ambisonic recordings to use as kernels." end
  if source.filename == "" or not nr.file_exists(source.filename) or not is_wav(source.filename) then
    return "The source item must be backed by a readable WAV file."
  end
  local needed = order_channels(settings.order_index)
  if source.channels < needed then
    return "The source item has " .. tostring(source.channels) .. " channels, but this order needs " .. tostring(needed) .. "."
  end
  for index, kernel in ipairs(kernels) do
    if kernel.filename == "" or not nr.file_exists(kernel.filename) or not is_wav(kernel.filename) then
      return "Kernel item " .. tostring(index) .. " must be backed by a readable WAV file."
    end
    if settings.adapt_mixed_order_kernels then
      if kernel.channels < 4 then
        return "Kernel item " .. tostring(index) .. " has " .. tostring(kernel.channels) .. " channels, but mixed-order kernels need at least 1OA / 4ch."
      end
    elseif kernel.channels < needed then
      return "Kernel item " .. tostring(index) .. " has " .. tostring(kernel.channels) .. " channels, but this order needs " .. tostring(needed) .. "."
    end
  end
  return nil
end

local function draw_flow(ctx, settings, kernel_count)
  local width = math.max(560, ImGui.GetContentRegionAvail(ctx) - 2)
  local height = 142
  ImGui.InvisibleButton(ctx, "##kernel_collage_flow", width, height)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = x0 + width, y0 + height
  local draw_list = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, COLOR_BG)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, COLOR_EDGE)
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 12, COLOR_TEXT, "ambisonic recording-as-kernel collage")

  local margin, gap = 14, 14
  local box_w = (width - margin * 2 - gap * 3) / 4
  local by = y0 + 40
  local box_h = 64
  local function box(x, title, detail, color)
    ImGui.DrawList_AddRectFilled(draw_list, x, by, x + box_w, by + box_h, COLOR_PANEL)
    ImGui.DrawList_AddRect(draw_list, x, by, x + box_w, by + box_h, color or COLOR_EDGE)
    ImGui.DrawList_AddText(draw_list, x + 8, by + 9, COLOR_TEXT, title)
    ImGui.DrawList_AddText(draw_list, x + 8, by + 30, COLOR_MUTED, detail)
  end
  local a = x0 + margin
  local b = a + box_w + gap
  local c = b + box_w + gap
  local d = c + box_w + gap
  box(a, "ACN/SN3D source", ORDER_NAMES[settings.order_index] or "Ambisonic", COLOR_EDGE)
  box(b, "direction feeds", tostring(direction_count_for(settings)) .. " virtual", COLOR_FLOW)
  box(c, "kernel recordings", tostring(kernel_count) .. " ambisonic", COLOR_WET)
  box(d, "summed output", ORDER_NAMES[settings.order_index] or "Ambisonic", COLOR_EDGE)
  local cy = by + box_h * 0.5
  ImGui.DrawList_AddLine(draw_list, a + box_w + 3, cy, b - 5, cy, COLOR_FLOW, 2.0)
  ImGui.DrawList_AddLine(draw_list, b + box_w + 3, cy, c - 5, cy, COLOR_FLOW, 2.0)
  ImGui.DrawList_AddLine(draw_list, c + box_w + 3, cy, d - 5, cy, COLOR_FLOW, 2.0)
  ImGui.DrawList_AddText(draw_list, a + 4, by + box_h + 10, COLOR_MUTED, "Kernels are recordings, so short windows and low wet gain are usually safer starting points.")
end

local function direction_layout_points(settings)
  if settings.layer_index == 2 or (settings.layer_index == 1 and settings.order_index == 1) then
    return {
      { az = 45.0, el = 35.26438968 },
      { az = -45.0, el = -35.26438968 },
      { az = 135.0, el = -35.26438968 },
      { az = -135.0, el = 35.26438968 },
    }
  end
  if settings.layer_index == 3 and settings.order_index == 1 then
    return {
      { az = 0.0, el = 0.0 },
      { az = 90.0, el = 0.0 },
      { az = 180.0, el = 0.0 },
      { az = -90.0, el = 0.0 },
      { az = 0.0, el = 90.0 },
      { az = 0.0, el = -90.0 },
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

local function axial_map_point(index, cx, cy, scale)
  local positions = {
    { 0.0, -0.56 },
    { 0.56, 0.0 },
    { 0.0, 0.56 },
    { -0.56, 0.0 },
    { -0.24, -0.24 },
    { 0.24, 0.24 },
  }
  local pos = positions[index] or { 0, 0 }
  return cx + pos[1] * scale, cy + pos[2] * scale, 0
end

local function kernel_assignment_label(settings, direction_index, kernel_count)
  if kernel_count < 1 then return "none" end
  local mode = ASSIGNMENT_KEYS[settings.assignment_index] or "cycle"
  if mode == "all" then return "all kernels" end
  if mode == "random" then return "seeded random" end
  if mode == "indexed" then
    if direction_index <= kernel_count then return "kernel " .. tostring(direction_index) end
    return "silent"
  end
  if mode == "region" then return "nearby kernels" end
  return "kernel " .. tostring(((direction_index - 1) % kernel_count) + 1)
end

local function draw_direction_map(ctx, settings, kernel_count)
  local points = direction_layout_points(settings)
  local width = math.max(560, ImGui.GetContentRegionAvail(ctx) - 2)
  local height = 214
  ImGui.InvisibleButton(ctx, "##kernel_collage_direction_map", width, height)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = x0 + width, y0 + height
  local draw_list = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, COLOR_BG)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, COLOR_EDGE)
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 12, COLOR_TEXT, "direction / kernel assignment")

  local cx = x0 + math.min(210, width * 0.34)
  local cy = y0 + 118
  local scale = math.min(76, width * 0.14)
  local label_x = x0 + math.min(330, width * 0.52)
  local label_y = y0 + 40
  local line_color = ImGui.ColorConvertDouble4ToU32(0.36, 0.40, 0.40, 1.0)
  local far_line_color = ImGui.ColorConvertDouble4ToU32(0.20, 0.23, 0.24, 1.0)
  local axis_color = ImGui.ColorConvertDouble4ToU32(0.25, 0.29, 0.30, 1.0)

  ImGui.DrawList_AddLine(draw_list, cx - scale * 1.08, cy, cx + scale * 1.08, cy, axis_color, 1.0)
  ImGui.DrawList_AddLine(draw_list, cx, cy + scale * 0.82, cx, cy - scale * 1.08, axis_color, 1.0)

  local projected = {}
  for index, point in ipairs(points) do
    local px, py, depth
    if #points == 4 then
      px, py = mic_capsule_point(index, cx, cy, scale)
      depth = 0
    elseif #points == 8 then
      px, py, depth = cube_map_point(index, cx, cy, scale)
    elseif #points == 6 then
      px, py, depth = axial_map_point(index, cx, cy, scale)
    else
      px, py, depth = projected_point(point, cx, cy, scale)
    end
    projected[index] = { x = px, y = py, depth = depth }
  end
  if #points == 8 then
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
  elseif #points == 6 then
    ImGui.DrawList_AddLine(draw_list, projected[4].x, projected[4].y, projected[2].x, projected[2].y, line_color, 1.2)
    ImGui.DrawList_AddLine(draw_list, projected[1].x, projected[1].y, projected[3].x, projected[3].y, line_color, 1.2)
    ImGui.DrawList_AddLine(draw_list, projected[5].x, projected[5].y, projected[6].x, projected[6].y, far_line_color, 1.0)
    ImGui.DrawList_AddText(draw_list, cx - 50, y0 + 38, COLOR_MUTED, "6-dir map")
    ImGui.DrawList_AddText(draw_list, projected[1].x - 16, projected[1].y - 18, COLOR_MUTED, "front")
    ImGui.DrawList_AddText(draw_list, projected[3].x - 12, projected[3].y + 9, COLOR_MUTED, "rear")
    ImGui.DrawList_AddText(draw_list, projected[4].x - 18, projected[4].y - 7, COLOR_MUTED, "L")
    ImGui.DrawList_AddText(draw_list, projected[2].x + 10, projected[2].y - 7, COLOR_MUTED, "R")
    ImGui.DrawList_AddText(draw_list, projected[5].x - 20, projected[5].y - 18, COLOR_MUTED, "up +")
    ImGui.DrawList_AddText(draw_list, projected[6].x - 14, projected[6].y + 9, COLOR_MUTED, "down -")
  else
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
  for index, point in ipairs(projected) do
    draw_points[#draw_points + 1] = { index = index, x = point.x, y = point.y, depth = point.depth }
  end
  table.sort(draw_points, function(a, b) return a.depth < b.depth end)
  for _, point in ipairs(draw_points) do
    local radius = 12
    ImGui.DrawList_AddCircleFilled(draw_list, point.x, point.y, radius, COLOR_WET, 16)
    ImGui.DrawList_AddText(draw_list, point.x - 4, point.y - 7, COLOR_BG, tostring(point.index))
  end

  ImGui.DrawList_AddText(draw_list, label_x, label_y - 20, COLOR_MUTED, "direction -> kernel source")
  for index, point in ipairs(points) do
    local label = kernel_assignment_label(settings, index, kernel_count)
    local text = string.format("%02d  %-14s  %s  az %.0f  el %.0f", index, label, direction_name(point), point.az, point.el)
    ImGui.DrawList_AddText(draw_list, label_x, label_y + (index - 1) * 18, COLOR_TEXT, text)
  end
end

local function run_render(source, kernels, settings)
  local err = validate(source, kernels, settings)
  if err then mc.show_error(err) return end

  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local order = ORDER_VALUES[settings.order_index] or 1
  local channels = order_channels(settings.order_index)
  local output_dir = nr.output_dir("s3g_ambisonic_kernel_collage_renders", source.filename, script_dir)
  local output_path = output_dir .. "/s3g_ambisonic_kernel_collage_" .. stamp .. "_" .. tostring(order) .. "oa.wav"
  local kernel_starts, kernel_durations = {}, {}
  for _, kernel in ipairs(kernels) do
    kernel_starts[#kernel_starts + 1] = tostring(kernel.start_offset or 0)
    kernel_durations[#kernel_durations + 1] = tostring(source_duration(kernel))
  end

  local manifest = {
    source_path = source.filename,
    source_start = source.start_offset or 0,
    source_duration = source_duration(source),
    sample_rate = nr.source_sample_rate(source),
    output_path = output_path,
    order = order,
    direction_layer = LAYER_KEYS[settings.layer_index] or "auto",
    kernel_paths = join_paths(kernels, "filename"),
    kernel_starts = table.concat(kernel_starts, "||"),
    kernel_durations = table.concat(kernel_durations, "||"),
    assignment_mode = ASSIGNMENT_KEYS[settings.assignment_index] or "cycle",
    region_width_deg = settings.region_width_deg,
    adapt_mixed_order_kernels = settings.adapt_mixed_order_kernels,
    max_kernel_seconds = settings.max_kernel_seconds,
    kernel_fade_ms = settings.kernel_fade_ms,
    kernel_normalize = settings.kernel_normalize,
    wet_gain_db = settings.wet_gain_db,
    wet_level = settings.wet_level,
    dry_level = settings.dry_level,
    tail_mode = TAIL_KEYS[settings.tail_index] or "max_tail",
    max_tail_seconds = settings.max_tail_seconds,
    seed = math.floor(settings.seed + 0.5),
    dc_protect = settings.dc_protect,
    soft_limit = settings.soft_limit,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
  }

  local total_start = reaper.time_precise()
  local log, elapsed = nr.run_backend(script_dir, "ambisonic_kernel_collage", manifest, TITLE)
  if not log then return end

  reaper.Undo_BeginBlock()
  local item, insert_err = nr.insert_output_item(output_path, "3OAFX kernel collage (" .. tostring(order) .. "OA)", source.position, channels, {
    master_send = false,
    track_gain = 0.5,
  })
  reaper.Undo_EndBlock(TITLE, -1)
  if not item then mc.show_error(insert_err or "Could not insert output item.") return end

  local lines = {
    "Source: " .. source.name .. " (" .. tostring(source.channels) .. "ch)",
    "Kernels: " .. tostring(#kernels),
    "Order: " .. tostring(order) .. "OA",
    "Direction layer: " .. (LAYER_NAMES[settings.layer_index] or "?"),
    "Assignment: " .. (ASSIGNMENT_NAMES[settings.assignment_index] or "?"),
    "Kernel window: " .. string.format("%.2f sec", settings.max_kernel_seconds),
    "Backend: Python WAV reader + NumPy",
  }
  for index, kernel in ipairs(kernels) do
    lines[#lines + 1] = "Kernel " .. tostring(index) .. ": " .. basename(kernel.filename) .. " (" .. tostring(kernel.channels) .. "ch)"
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
    mc.show_error("Select one ambisonic source item and one or more same-order ambisonic recordings to use as kernels. The earliest selected item is the source.")
    return
  end
  local source = entries[1]
  local kernels = {}
  for index = 2, #entries do kernels[#kernels + 1] = entries[index] end

  local ctx = ImGui.CreateContext(TITLE)
  local open = true
  local should_render = false
  local settings = {
    order_index = clamp(math.floor(get_number("order_index", order_index_for_channels(source.channels))), 1, 3),
    layer_index = clamp(math.floor(get_number("layer_index", 1)), 1, #LAYER_NAMES),
    assignment_index = clamp(math.floor(get_number("assignment_index", 1)), 1, #ASSIGNMENT_NAMES),
    tail_index = clamp(math.floor(get_number("tail_index", 1)), 1, #TAIL_NAMES),
    max_kernel_seconds = get_number("max_kernel_seconds", 3.0),
    region_width_deg = get_number("region_width_deg", 70.0),
    adapt_mixed_order_kernels = get_bool("adapt_mixed_order_kernels", true),
    kernel_fade_ms = get_number("kernel_fade_ms", 30.0),
    kernel_normalize = get_bool("kernel_normalize", true),
    wet_gain_db = get_number("wet_gain_db", -18.0),
    wet_level = get_number("wet_level", 1.0),
    dry_level = get_number("dry_level", 0.0),
    max_tail_seconds = get_number("max_tail_seconds", 12.0),
    seed = get_number("seed", 1),
    dc_protect = get_bool("dc_protect", true),
    soft_limit = get_bool("soft_limit", true),
    normalize = get_bool("normalize", true),
    normalize_db = get_number("normalize_db", -6.0),
  }

  local function persist()
    for key, value in pairs(settings) do set_value(key, value) end
  end

  local function loop()
    ImGui.SetNextWindowSize(ctx, 760, 760, WINDOW_OPEN_COND)
    local visible
    visible, open = ImGui.Begin(ctx, TITLE, open)
    if visible then
      local validation = validate(source, kernels, settings)
      local footer_h = 54
      local control_h = math.max(280, ImGui.GetWindowHeight(ctx) - footer_h)
      if ImGui.BeginChild(ctx, "##kernel_collage_controls", 0, control_h) then
      ImGui.Text(ctx, "Source: " .. source.name .. "  (" .. tostring(source.channels) .. " ch)")
      ImGui.Text(ctx, "Kernel recordings: " .. tostring(#kernels))
      ImGui.Spacing(ctx)
      draw_flow(ctx, settings, #kernels)
      ImGui.Spacing(ctx)
      draw_direction_map(ctx, settings, #kernels)
      ImGui.Spacing(ctx)
      local changed
      settings.order_index = combo(ctx, "Ambisonic order", settings.order_index, ORDER_NAMES)
      settings.layer_index = combo(ctx, "Direction layer", settings.layer_index, LAYER_NAMES)
      if settings.layer_index == 2 and settings.order_index > 1 then
        ImGui.Text(ctx, "Uses four tetrahedral first-order microphone directions as a sparse higher-order layer.")
      elseif settings.layer_index == 3 and settings.order_index == 1 then
        ImGui.TextColored(ctx, COLOR_WARN, "1OA practical mode uses a 6-direction axial layer; spatial resolution remains first-order.")
      elseif settings.layer_index == 3 then
        ImGui.Text(ctx, "Uses eight cube-corner directions for 2OA/3OA.")
      end
      settings.assignment_index = combo(ctx, "Kernel assignment", settings.assignment_index, ASSIGNMENT_NAMES)
      if settings.assignment_index == 3 then
        ImGui.TextColored(ctx, COLOR_WARN, "Dense mode can get large quickly: directions x kernels x channels.")
      elseif settings.assignment_index == 4 then
        ImGui.Text(ctx, "Extra kernels are ignored; missing direction kernels are silent.")
      elseif settings.assignment_index == 5 then
        ImGui.Text(ctx, "Each direction blends nearby kernel positions rather than using a single kernel.")
        changed, settings.region_width_deg = ImGui.SliderDouble(ctx, "Region width deg", settings.region_width_deg, 12.0, 180.0, "%.1f")
      end
      settings.tail_index = combo(ctx, "Output length", settings.tail_index, TAIL_NAMES)
      ImGui.Spacing(ctx)
      changed, settings.adapt_mixed_order_kernels = ImGui.Checkbox(ctx, "Adapt mixed-order kernels", settings.adapt_mixed_order_kernels)
      if settings.adapt_mixed_order_kernels then
        ImGui.Text(ctx, "1OA/2OA/3OA kernels are adapted to the selected output order.")
      end
      changed, settings.max_kernel_seconds = ImGui.SliderDouble(ctx, "Max kernel window sec", settings.max_kernel_seconds, 0.05, 30.0, "%.2f")
      changed, settings.kernel_fade_ms = ImGui.SliderDouble(ctx, "Kernel fade ms", settings.kernel_fade_ms, 0.0, 500.0, "%.1f")
      changed, settings.kernel_normalize = ImGui.Checkbox(ctx, "Normalize each kernel window", settings.kernel_normalize)
      changed, settings.wet_gain_db = ImGui.SliderDouble(ctx, "Wet pre-gain dB", settings.wet_gain_db, -48.0, 0.0, "%.1f")
      changed, settings.wet_level = ImGui.SliderDouble(ctx, "Wet level", settings.wet_level, 0.0, 2.0, "%.2f")
      changed, settings.dry_level = ImGui.SliderDouble(ctx, "Dry level", settings.dry_level, 0.0, 1.5, "%.2f")
      if settings.tail_index == 1 then
        changed, settings.max_tail_seconds = ImGui.SliderDouble(ctx, "Max tail sec", settings.max_tail_seconds, 0.0, 60.0, "%.1f")
      end
      if settings.assignment_index == 2 then
        changed, settings.seed = ImGui.SliderDouble(ctx, "Random seed", settings.seed, 1, 9999, "%.0f")
      end
      changed, settings.dc_protect = ImGui.Checkbox(ctx, "DC protect", settings.dc_protect)
      changed, settings.soft_limit = ImGui.Checkbox(ctx, "Soft limit before normalize", settings.soft_limit)
      changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize output", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize peak dB", settings.normalize_db, -24.0, 0.0, "%.1f")
      end
      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Text(ctx, "Virtual directions: " .. tostring(direction_count_for(settings)))
      if settings.adapt_mixed_order_kernels then
        ImGui.Text(ctx, "Kernel channels: 1OA / 4ch minimum; adapted to output order")
      else
        ImGui.Text(ctx, "Required channels per item: " .. tostring(order_channels(settings.order_index)))
      end
      if validation then
        ImGui.TextColored(ctx, COLOR_ERROR, validation)
      else
        ImGui.Text(ctx, "Renders offline from WAV media with NumPy.")
      end
      ImGui.Spacing(ctx)
      ImGui.EndChild(ctx)
      end
      if ImGui.Button(ctx, "Render", 104, 28) and not validation then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 104, 28) then open = false end
      ImGui.End(ctx)
    end

    persist()
    if should_render then
      open = false
      run_render(source, kernels, settings)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
