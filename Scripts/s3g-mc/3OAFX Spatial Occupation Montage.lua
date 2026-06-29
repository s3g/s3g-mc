-- @description 3OAFX Spatial Occupation Montage
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed event montage into ACN/SN3D ambisonic space.
-- @method Select one or more WAV-backed media items. The renderer fragments the sources into overlapping events, interprets 4ch/10ch/16ch as ACN/SN3D ambisonic by default, encodes other channel counts as spatial objects, and renders an occupied ACN/SN3D ambisonic field.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "3OAFX Spatial Occupation Montage", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "3OAFX Spatial Occupation Montage"
local EXT = "s3g_mc_foafx_spatial_occupation_montage_v1"
local SOURCE_KEYS = { "auto", "non_ambisonic", "1oa", "2oa", "3oa" }
local SOURCE_LABELS = { "Auto by channel count", "Force non-ambisonic", "Force 1OA / 4ch", "Force 2OA / 9ch + pad", "Force 3OA / 16ch" }
local ORDER_LABELS = { "1OA / 4ch", "2OA / 9ch", "3OA / 16ch" }
local ctx
local settings
local entries

local function getn(key, default) return tonumber(reaper.GetExtState(EXT, key)) or default end
local function getb(key, default)
  local value = reaper.GetExtState(EXT, key)
  if value == "" then return default end
  return value ~= "0"
end
local function set_value(key, value)
  reaper.SetExtState(EXT, key, type(value) == "boolean" and (value and "1" or "0") or tostring(value), true)
end
local function combo(label, idx, labels)
  if ImGui.BeginCombo(ctx, label, labels[idx] or "") then
    for i, name in ipairs(labels) do
      local selected = i == idx
      if ImGui.Selectable(ctx, name, selected) then idx = i end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return idx
end
local function order_index_for_channels(channels)
  if channels == 16 then return 3 end
  if channels == 9 or channels == 10 then return 2 end
  if channels == 4 then return 1 end
  return 3
end
local function order_channels(order_index)
  local order = math.max(1, math.min(3, math.floor(order_index or 3)))
  return (order + 1) * (order + 1)
end
local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end
local COLORS = {
  bg = color(0.035, 0.039, 0.042, 1),
  grid = color(0.58, 0.63, 0.63, 0.15),
  ring = color(0.58, 0.63, 0.63, 0.27),
  text = color(0.76, 0.80, 0.78, 1),
  muted = color(0.50, 0.56, 0.56, 1),
  event = color(0.20, 0.72, 0.95, 0.72),
  event_soft = color(0.20, 0.72, 0.95, 0.15),
  source = color(0.98, 0.72, 0.25, 0.88),
  side = color(0.36, 0.88, 0.68, 0.75),
  motion = color(0.72, 0.58, 0.98, 0.78),
}
local function draw_node(draw_list, cx, cy, r, az_deg, radius, col, size)
  local az = math.rad(az_deg - 90)
  local x = cx + math.cos(az) * radius * r
  local y = cy + math.sin(az) * radius * r
  ImGui.DrawList_AddCircleFilled(draw_list, x, y, size or 4, col, 18)
  return x, y
end
local function draw_preview()
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(440, ImGui.GetContentRegionAvail(ctx))
  local h = 250
  local cx = x0 + w * 0.50
  local cy = y0 + h * 0.48
  local r = math.min(w * 0.34, h * 0.34)
  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x0 + w, y0 + h, COLORS.bg)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x0 + w, y0 + h, COLORS.grid)
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 12, COLORS.text, "Spatial Occupation")
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 32, COLORS.muted, tostring(#entries) .. " sources / " .. ORDER_LABELS[settings.output_order])
  ImGui.DrawList_AddCircle(draw_list, cx, cy, r, COLORS.ring, 96, 1.5)
  ImGui.DrawList_AddCircle(draw_list, cx, cy, r * 0.58, COLORS.grid, 96, 1)
  ImGui.DrawList_AddLine(draw_list, cx - r, cy, cx + r, cy, COLORS.grid, 1)
  ImGui.DrawList_AddLine(draw_list, cx, cy - r, cx, cy + r, COLORS.grid, 1)

  for _, az in ipairs({ 0, 45, 90, 135, 180, -135, -90, -45 }) do
    draw_node(draw_list, cx, cy, r, az, 1.0, COLORS.grid, 3)
  end

  local dot_count = math.max(8, math.min(72, math.floor(settings.events * math.max(0.05, settings.density) / 8)))
  local occ = math.max(0.05, math.min(1.0, settings.occupation))
  for i = 1, dot_count do
    local az = (i * 137 + settings.seed * 23) % 360
    local radius = 0.18 + (((i * 43 + settings.seed * 7) % 82) / 100) * (0.35 + occ * 0.65)
    local col = (i % 5 == 0) and COLORS.motion or ((i % 3 == 0) and COLORS.side or COLORS.event)
    local size = 2.2 + 3.8 * math.min(1.0, settings.overlap + settings.occupation * 0.4)
    local x, y = draw_node(draw_list, cx, cy, r, az, math.min(1.0, radius), col, size)
    if settings.motion > 0.05 and i % 4 == 0 then
      local x2, y2 = draw_node(draw_list, cx, cy, r, az + 28 + settings.motion * 80, math.min(1.0, radius + 0.08), COLORS.event_soft, 2)
      ImGui.DrawList_AddLine(draw_list, x, y, x2, y2, COLORS.motion, 1.2)
    end
  end

  if settings.stereo_expand then
    local lx, ly = draw_node(draw_list, cx, cy, r, 35, 0.92, COLORS.source, 6)
    local rx, ry = draw_node(draw_list, cx, cy, r, -35, 0.92, COLORS.source, 6)
    local fx, fy = draw_node(draw_list, cx, cy, r, 0, 0.68, COLORS.side, 5)
    local bx, by = draw_node(draw_list, cx, cy, r, 180, 0.68, COLORS.side, 5)
    ImGui.DrawList_AddLine(draw_list, lx, ly, fx, fy, COLORS.source, 1.2)
    ImGui.DrawList_AddLine(draw_list, rx, ry, fx, fy, COLORS.source, 1.2)
    ImGui.DrawList_AddLine(draw_list, fx, fy, bx, by, COLORS.side, 1.2)
  end

  local tx = x0 + 16
  local ty = y0 + h - 42
  local tw = w - 32
  ImGui.DrawList_AddRect(draw_list, tx, ty, tx + tw, ty + 18, COLORS.grid)
  local bars = math.max(12, math.min(64, math.floor(dot_count * 0.75)))
  for i = 1, bars do
    local t = (i - 1) / math.max(1, bars - 1)
    local bw = tw / bars
    local bh = 3 + 14 * (((i * 29 + settings.seed) % 100) / 100) * settings.density
    local bx = tx + (i - 1) * bw
    local by = ty + 18 - bh
    ImGui.DrawList_AddRectFilled(draw_list, bx, by, bx + bw * math.min(0.95, 0.35 + settings.overlap), ty + 18, i % 3 == 0 and COLORS.side or COLORS.event_soft)
    if settings.motion > 0.1 and i % 5 == 0 then
      ImGui.DrawList_AddLine(draw_list, bx, ty + 1, bx + bw, ty + 17, COLORS.motion, 1)
    end
  end
  ImGui.DrawList_AddText(draw_list, tx, ty + 22, COLORS.muted, "event timeline / field occupancy")
  ImGui.Dummy(ctx, w, h + 8)
end
local function join_values(entries, key)
  local values = {}
  for _, entry in ipairs(entries) do values[#values + 1] = tostring(entry[key] or 0) end
  return table.concat(values, ",")
end
local function join_source_durations(entries)
  local values = {}
  for _, entry in ipairs(entries) do values[#values + 1] = tostring((entry.length or 0) * math.max(0.000001, entry.playrate or 1)) end
  return table.concat(values, ",")
end
local function join_paths(entries)
  local values = {}
  for _, entry in ipairs(entries) do values[#values + 1] = entry.filename end
  return table.concat(values, "\n")
end

entries = nr.selected_entries()
if #entries == 0 then
  mc.show_error("Select one or more WAV-backed media items.")
  return
end

settings = {
  source_format = math.max(1, math.min(#SOURCE_KEYS, math.floor(getn("source_format", 1)))),
  output_order = math.max(1, math.min(3, math.floor(getn("output_order", order_index_for_channels(entries[1].channels))))),
  duration = getn("duration", math.max(8.0, entries[#entries].position + entries[#entries].length - entries[1].position)),
  events = getn("events", 180),
  min_segment_ms = getn("min_segment_ms", 80.0),
  max_segment_ms = getn("max_segment_ms", 900.0),
  density = getn("density", 0.72),
  overlap = getn("overlap", 0.55),
  source_spread = getn("source_spread", 0.22),
  occupation = getn("occupation", 0.72),
  motion = getn("motion", 0.35),
  stereo_expand = getb("stereo_expand", true),
  normalize = getb("normalize", true),
  normalize_db = getn("normalize_db", -6.0),
  seed = getn("seed", 1),
}

ctx = ImGui.CreateContext(TITLE)
local open = true
local should_render = false

local function persist()
  for key, value in pairs(settings) do set_value(key, value) end
end

local function render()
  local out_channels = order_channels(settings.output_order)
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_foafx_spatial_occupation_montage_renders", entries[1].filename, script_dir)
  local output_path = out_dir .. "/s3g_foafx_spatial_occupation_montage_" .. stamp .. "_" .. tostring(settings.output_order) .. "oa.wav"
  local manifest = {
    source_paths = join_paths(entries),
    source_starts = join_values(entries, "start_offset"),
    source_durations = join_source_durations(entries),
    sample_rate = nr.source_sample_rate(entries[1]),
    output_path = output_path,
    source_format = SOURCE_KEYS[settings.source_format],
    output_order = settings.output_order,
    duration = settings.duration,
    events = settings.events,
    min_segment_ms = settings.min_segment_ms,
    max_segment_ms = settings.max_segment_ms,
    density = settings.density,
    overlap = settings.overlap,
    source_spread = settings.source_spread,
    occupation = settings.occupation,
    motion = settings.motion,
    stereo_expand = settings.stereo_expand,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    seed = settings.seed,
  }
  local log, elapsed = nr.run_backend(script_dir, "foafx_spatial_occupation_montage", manifest, TITLE)
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path, "3OAFX Spatial Occupation Montage (" .. tostring(settings.output_order) .. "OA)", entries[1].position, out_channels, { master_send = false, track_gain = 0.5 })
  reaper.Undo_EndBlock(TITLE, -1)
  if not item then mc.show_error(err or "Could not insert rendered item.") return end
  mc.print_plan(TITLE, {
    "Sources: " .. tostring(#entries),
    "Source format: " .. SOURCE_LABELS[settings.source_format],
    "Output: " .. output_path,
    "Master send: off",
    string.format("NumPy time: %.2f sec", elapsed),
    log,
  })
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 740, 900, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    ImGui.Text(ctx, "Selected sources: " .. tostring(#entries))
    for index, entry in ipairs(entries) do
      if index <= 5 then ImGui.Text(ctx, "  " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)") end
    end
    if #entries > 5 then ImGui.Text(ctx, "  ...") end
    draw_preview()
    settings.source_format = combo("Source format", settings.source_format, SOURCE_LABELS)
    settings.output_order = combo("Output order", settings.output_order, ORDER_LABELS)
    ImGui.Separator(ctx)
    local changed
    changed, settings.duration = ImGui.SliderDouble(ctx, "Output duration sec", settings.duration, 0.25, 600.0, "%.2f")
    changed, settings.events = ImGui.SliderInt(ctx, "Events", math.floor(settings.events), 1, 20000)
    changed, settings.min_segment_ms = ImGui.SliderDouble(ctx, "Min segment ms", settings.min_segment_ms, 5.0, 5000.0, "%.1f")
    changed, settings.max_segment_ms = ImGui.SliderDouble(ctx, "Max segment ms", settings.max_segment_ms, settings.min_segment_ms, 30000.0, "%.1f")
    changed, settings.density = ImGui.SliderDouble(ctx, "Event density", settings.density, 0.0, 1.0, "%.2f")
    changed, settings.overlap = ImGui.SliderDouble(ctx, "Overlap build", settings.overlap, 0.0, 1.0, "%.2f")
    changed, settings.source_spread = ImGui.SliderDouble(ctx, "Source object spread", settings.source_spread, 0.0, 1.0, "%.2f")
    changed, settings.occupation = ImGui.SliderDouble(ctx, "Spatial occupation", settings.occupation, 0.0, 1.0, "%.2f")
    changed, settings.motion = ImGui.SliderDouble(ctx, "Spatial motion", settings.motion, 0.0, 1.0, "%.2f")
    changed, settings.stereo_expand = ImGui.Checkbox(ctx, "Stereo sum/difference expansion", settings.stereo_expand)
    changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
    if settings.normalize then
      changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -24.0, 0.0, "%.1f")
    end
    changed, settings.seed = ImGui.InputInt(ctx, "Seed", math.floor(settings.seed))
    ImGui.Separator(ctx)
    ImGui.TextWrapped(ctx, "Stereo expansion uses L/R plus mid/side-derived cues to seed front, rear, and side occupation before ACN/SN3D encoding.")
    if ImGui.Button(ctx, "Render", 96, 28) then should_render = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 96, 28) then open = false end
    ImGui.End(ctx)
  end
  persist()
  if should_render then open = false; render(); return end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
