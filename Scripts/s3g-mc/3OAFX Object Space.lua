-- @description 3OAFX Object Space
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline ambisonic object-to-space render.
-- @method Select one WAV-backed media item. The renderer treats 4ch, 10ch, and 16ch sources as ACN/SN3D ambisonic by default, also accepts 9ch WAV as 2OA, treats other channel counts as non-ambisonic objects, and renders a new ACN/SN3D ambisonic item using object/space transformation modes.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "3OAFX Object Space", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "3OAFX Object Space"
local EXT = "s3g_mc_foafx_object_space_v1"
local MODES = { "resonance_bloom", "spatial_occupation", "motion_counterpoint", "spatial_allusion" }
local MODE_LABELS = { "Resonance bloom", "Spatial occupation", "Motion counterpoint", "Spatial allusion" }
local SOURCE_KEYS = { "auto", "non_ambisonic", "1oa", "2oa", "3oa" }
local SOURCE_LABELS = { "Auto by channel count", "Force non-ambisonic", "Force 1OA / 4ch", "Force 2OA / 9ch + pad", "Force 3OA / 16ch" }
local ORDER_LABELS = { "1OA / 4ch", "2OA / 9ch", "3OA / 16ch" }
local ctx
local settings

local function getn(key, default)
  return tonumber(reaper.GetExtState(EXT, key)) or default
end

local function getb(key, default)
  local value = reaper.GetExtState(EXT, key)
  if value == "" then return default end
  return value ~= "0"
end

local function set_value(key, value)
  reaper.SetExtState(EXT, key, type(value) == "boolean" and (value and "1" or "0") or tostring(value), true)
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

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local COLORS = {
  bg = color(0.035, 0.039, 0.042, 1),
  grid = color(0.58, 0.63, 0.63, 0.16),
  ring = color(0.58, 0.63, 0.63, 0.26),
  text = color(0.76, 0.80, 0.78, 1),
  muted = color(0.50, 0.56, 0.56, 1),
  object = color(0.98, 0.72, 0.25, 0.96),
  object_soft = color(0.98, 0.72, 0.25, 0.20),
  field = color(0.20, 0.72, 0.95, 0.70),
  field_soft = color(0.20, 0.72, 0.95, 0.16),
  motion = color(0.72, 0.58, 0.98, 0.82),
  side = color(0.36, 0.88, 0.68, 0.72),
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
  local w = math.max(420, ImGui.GetContentRegionAvail(ctx))
  local h = 235
  local cx = x0 + w * 0.50
  local cy = y0 + h * 0.55
  local r = math.min(w * 0.36, h * 0.36)
  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x0 + w, y0 + h, COLORS.bg)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x0 + w, y0 + h, COLORS.grid)
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 12, COLORS.text, "Object / Space Field")
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 32, COLORS.muted, MODE_LABELS[settings.mode] .. " / " .. ORDER_LABELS[settings.output_order])
  ImGui.DrawList_AddCircle(draw_list, cx, cy, r, COLORS.ring, 96, 1.5)
  ImGui.DrawList_AddCircle(draw_list, cx, cy, r * 0.58, COLORS.grid, 96, 1)
  ImGui.DrawList_AddLine(draw_list, cx - r, cy, cx + r, cy, COLORS.grid, 1)
  ImGui.DrawList_AddLine(draw_list, cx, cy - r, cx, cy + r, COLORS.grid, 1)

  local dirs = { 0, 45, 90, 135, 180, -135, -90, -45 }
  for _, az in ipairs(dirs) do
    draw_node(draw_list, cx, cy, r, az, 1.0, COLORS.grid, 3)
  end

  local object_r = 0.18 + 0.34 * (1.0 - math.min(1.0, settings.source_spread))
  local halo = r * (0.16 + 0.52 * math.min(1.0, settings.spread_deg / 180.0)) * math.max(0.15, settings.space_amount)
  local ox, oy = draw_node(draw_list, cx, cy, r, -25, object_r, COLORS.object, 6 + 5 * settings.object_clarity)
  ImGui.DrawList_AddCircle(draw_list, ox, oy, halo, COLORS.field_soft, 64, 2)
  ImGui.DrawList_AddCircleFilled(draw_list, ox, oy, 18 + 28 * settings.object_clarity, COLORS.object_soft, 48)
  ImGui.DrawList_AddCircleFilled(draw_list, ox, oy, 5 + 5 * settings.object_clarity, COLORS.object, 24)

  local mode = MODES[settings.mode]
  if mode == "motion_counterpoint" then
    for i = 0, 4 do
      local a0 = -150 + i * 58
      local x1, y1 = draw_node(draw_list, cx, cy, r, a0, 0.35 + i * 0.11, COLORS.motion, 3)
      local x2, y2 = draw_node(draw_list, cx, cy, r, a0 + 55 + settings.motion * 90, 0.45 + i * 0.08, COLORS.field, 4)
      ImGui.DrawList_AddLine(draw_list, x1, y1, x2, y2, COLORS.motion, 1.7)
    end
  elseif mode == "spatial_occupation" then
    for i = 1, 18 do
      local az = (i * 137 + settings.seed * 19) % 360
      local rr = 0.22 + ((i * 29) % 70) / 100
      draw_node(draw_list, cx, cy, r, az, rr, i % 3 == 0 and COLORS.side or COLORS.field, 2.5 + settings.space_amount * 2)
    end
  elseif mode == "spatial_allusion" then
    for i = 1, 4 do
      ImGui.DrawList_AddCircle(draw_list, cx, cy, r * (0.18 + i * 0.17), i % 2 == 0 and COLORS.field_soft or COLORS.object_soft, 96, 2)
    end
    draw_node(draw_list, cx, cy, r, 160, 0.82, COLORS.side, 6)
    draw_node(draw_list, cx, cy, r, -110, 0.70, COLORS.field, 5)
  else
    for i = 1, 5 do
      ImGui.DrawList_AddCircle(draw_list, ox, oy, halo * i / 5, i % 2 == 0 and COLORS.field_soft or COLORS.object_soft, 72, 1.5)
    end
    draw_node(draw_list, cx, cy, r, 180, 0.82, COLORS.field, 7)
  end

  local bar_x = x0 + 16
  local bar_y = y0 + h - 28
  local bar_w = w - 32
  ImGui.DrawList_AddRect(draw_list, bar_x, bar_y, bar_x + bar_w, bar_y + 10, COLORS.grid)
  ImGui.DrawList_AddRectFilled(draw_list, bar_x, bar_y, bar_x + bar_w * math.min(1.0, settings.object_clarity), bar_y + 10, COLORS.object_soft)
  ImGui.DrawList_AddRectFilled(draw_list, bar_x + bar_w * (1.0 - math.min(1.0, settings.space_amount / 2.0)), bar_y, bar_x + bar_w, bar_y + 10, COLORS.field_soft)
  ImGui.DrawList_AddText(draw_list, bar_x, bar_y + 13, COLORS.muted, "object clarity / spatial field")
  ImGui.Dummy(ctx, w, h + 8)
end

local entries = nr.selected_entries()
local entry = entries[1]
if not entry then
  mc.show_error("Select one WAV-backed media item.")
  return
end

settings = {
  mode = math.max(1, math.min(#MODES, math.floor(getn("mode", 1)))),
  source_format = math.max(1, math.min(#SOURCE_KEYS, math.floor(getn("source_format", 1)))),
  output_order = math.max(1, math.min(3, math.floor(getn("output_order", order_index_for_channels(entry.channels))))),
  source_spread = getn("source_spread", 0.18),
  object_clarity = getn("object_clarity", 0.55),
  dry_level = getn("dry_level", 0.35),
  space_amount = getn("space_amount", 0.85),
  spread_deg = getn("spread_deg", 42.0),
  motion = getn("motion", 0.35),
  resonance_hz = getn("resonance_hz", 220.0),
  feedback = getn("feedback", 0.35),
  smear = getn("smear", 0.45),
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
  local out_dir = nr.output_dir("s3g_foafx_object_space_renders", entry.filename, script_dir)
  local output_path = out_dir .. "/s3g_foafx_object_space_" .. stamp .. "_" .. tostring(settings.output_order) .. "oa.wav"
  local manifest = {
    source_path = entry.filename,
    source_start = entry.start_offset,
    source_duration = entry.length * math.max(0.000001, entry.playrate),
    sample_rate = nr.source_sample_rate(entry),
    output_path = output_path,
    mode = MODES[settings.mode],
    source_format = SOURCE_KEYS[settings.source_format],
    output_order = settings.output_order,
    source_spread = settings.source_spread,
    object_clarity = settings.object_clarity,
    dry_level = settings.dry_level,
    space_amount = settings.space_amount,
    spread_deg = settings.spread_deg,
    motion = settings.motion,
    resonance_hz = settings.resonance_hz,
    feedback = settings.feedback,
    smear = settings.smear,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    seed = settings.seed,
  }
  local log, elapsed = nr.run_backend(script_dir, "foafx_object_space", manifest, TITLE)
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path, "3OAFX Object Space (" .. tostring(settings.output_order) .. "OA)", entry.position, out_channels, { master_send = false, track_gain = 0.5 })
  reaper.Undo_EndBlock(TITLE, -1)
  if not item then mc.show_error(err or "Could not insert rendered item.") return end
  mc.print_plan(TITLE, {
    "Source: " .. entry.name,
    "Mode: " .. MODE_LABELS[settings.mode],
    "Source format: " .. SOURCE_LABELS[settings.source_format],
    "Output: " .. output_path,
    "Master send: off",
    string.format("NumPy time: %.2f sec", elapsed),
    log,
  })
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 720, 850, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    ImGui.Text(ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
    draw_preview()
    settings.mode = combo("Mode", settings.mode, MODE_LABELS)
    settings.source_format = combo("Source format", settings.source_format, SOURCE_LABELS)
    settings.output_order = combo("Output order", settings.output_order, ORDER_LABELS)
    ImGui.Separator(ctx)
    local changed
    changed, settings.source_spread = ImGui.SliderDouble(ctx, "Source object spread", settings.source_spread, 0.0, 1.0, "%.2f")
    changed, settings.object_clarity = ImGui.SliderDouble(ctx, "Object clarity", settings.object_clarity, 0.0, 1.0, "%.2f")
    changed, settings.dry_level = ImGui.SliderDouble(ctx, "Dry object level", settings.dry_level, 0.0, 1.5, "%.2f")
    changed, settings.space_amount = ImGui.SliderDouble(ctx, "Space amount", settings.space_amount, 0.0, 2.0, "%.2f")
    changed, settings.spread_deg = ImGui.SliderDouble(ctx, "Spatial spread deg", settings.spread_deg, 1.0, 180.0, "%.1f")
    changed, settings.motion = ImGui.SliderDouble(ctx, "Spatial motion", settings.motion, 0.0, 1.0, "%.2f")
    changed, settings.resonance_hz = ImGui.SliderDouble(ctx, "Resonance Hz", settings.resonance_hz, 30.0, 6000.0, "%.1f")
    changed, settings.feedback = ImGui.SliderDouble(ctx, "Resonant feedback", settings.feedback, 0.0, 0.92, "%.2f")
    changed, settings.smear = ImGui.SliderDouble(ctx, "Spectral smear", settings.smear, 0.0, 1.0, "%.2f")
    changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
    if settings.normalize then
      changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -24.0, 0.0, "%.1f")
    end
    changed, settings.seed = ImGui.InputInt(ctx, "Seed", math.floor(settings.seed))
    ImGui.Separator(ctx)
    ImGui.TextWrapped(ctx, "Auto treats 4ch, 10ch, and 16ch as ACN/SN3D ambisonic in REAPER practice; 9ch WAVs are also accepted as 2OA. Other channel counts are encoded as source objects.")
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
