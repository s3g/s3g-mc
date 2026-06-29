-- @description Stereo Expand to Ambisonic Bed
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline render.
-- @method Select one WAV-backed mono or stereo media item. The renderer derives left/right, mid/side, rear, side, and optional height cues from the source, then writes a new ACN/SN3D ambisonic bed.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Stereo Expand to Ambisonic Bed", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "Stereo Expand to Ambisonic Bed"
local EXT = "s3g_mc_stereo_expand_ambisonic_bed_v1"
local MODES = { "balanced", "front_focus", "wide_room", "height_lift" }
local MODE_LABELS = { "Balanced bed", "Front focus", "Wide room", "Height lift" }
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
  grid = color(0.58, 0.63, 0.63, 0.17),
  ring = color(0.58, 0.63, 0.63, 0.27),
  text = color(0.76, 0.80, 0.78, 1),
  muted = color(0.50, 0.56, 0.56, 1),
  left = color(0.95, 0.58, 0.38, 0.92),
  right = color(0.42, 0.74, 0.96, 0.92),
  mid = color(0.98, 0.78, 0.32, 0.92),
  side = color(0.36, 0.88, 0.68, 0.82),
  rear = color(0.73, 0.56, 0.96, 0.72),
  height = color(0.92, 0.92, 0.72, 0.72),
}

local function draw_node(draw_list, cx, cy, r, az_deg, radius, col, size)
  local az = math.rad(az_deg - 90)
  local x = cx + math.cos(az) * radius * r
  local y = cy + math.sin(az) * radius * r
  ImGui.DrawList_AddCircleFilled(draw_list, x, y, size or 5, col, 20)
  return x, y
end

local function draw_preview()
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(420, ImGui.GetContentRegionAvail(ctx))
  local h = 245
  local cx = x0 + w * 0.50
  local cy = y0 + h * 0.56
  local r = math.min(w * 0.35, h * 0.35)
  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x0 + w, y0 + h, COLORS.bg)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x0 + w, y0 + h, COLORS.grid)
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 12, COLORS.text, "Stereo source to ambisonic bed")
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 32, COLORS.muted, MODE_LABELS[settings.mode] .. " / " .. ORDER_LABELS[settings.output_order])
  ImGui.DrawList_AddCircle(draw_list, cx, cy, r, COLORS.ring, 96, 1.5)
  ImGui.DrawList_AddCircle(draw_list, cx, cy, r * 0.55, COLORS.grid, 96, 1)
  ImGui.DrawList_AddLine(draw_list, cx - r, cy, cx + r, cy, COLORS.grid, 1)
  ImGui.DrawList_AddLine(draw_list, cx, cy - r, cx, cy + r, COLORS.grid, 1)
  ImGui.DrawList_AddText(draw_list, cx - 9, cy - r - 20, COLORS.muted, "F")
  ImGui.DrawList_AddText(draw_list, cx - 9, cy + r + 6, COLORS.muted, "R")

  local angle = 30 + settings.stereo_width * 35
  local spread_r = 0.62 + math.min(0.28, settings.source_spread * 0.35)
  draw_node(draw_list, cx, cy, r, angle, spread_r, COLORS.left, 8)
  draw_node(draw_list, cx, cy, r, -angle, spread_r, COLORS.right, 8)
  draw_node(draw_list, cx, cy, r, 0, 0.36, COLORS.mid, 6 + settings.center_amount * 3)
  draw_node(draw_list, cx, cy, r, 90, 0.72, COLORS.side, 4 + settings.side_amount * 3)
  draw_node(draw_list, cx, cy, r, -90, 0.72, COLORS.side, 4 + settings.side_amount * 3)
  draw_node(draw_list, cx, cy, r, 180, 0.58 + settings.rear_amount * 0.22, COLORS.rear, 4 + settings.rear_amount * 4)
  if settings.height_amount > 0.01 then
    ImGui.DrawList_AddCircle(draw_list, cx, cy, r * (0.20 + settings.height_amount * 0.38), COLORS.height, 48, 2)
    draw_node(draw_list, cx, cy, r, 0, 0.12, COLORS.height, 4 + settings.height_amount * 5)
  end

  local bx = x0 + 16
  local by = y0 + h - 34
  local bw = w - 32
  ImGui.DrawList_AddRect(draw_list, bx, by, bx + bw, by + 12, COLORS.grid)
  ImGui.DrawList_AddRectFilled(draw_list, bx, by, bx + bw * math.min(1, settings.decorrelation), by + 12, COLORS.rear)
  ImGui.DrawList_AddText(draw_list, bx, by + 15, COLORS.muted, "decorrelation / diffuse support")
  ImGui.Dummy(ctx, w, h + 8)
end

local entries = nr.selected_entries()
local entry = entries[1]
if not entry then
  mc.show_error("Select one WAV-backed mono or stereo media item.")
  return
end

settings = {
  mode = math.max(1, math.min(#MODES, math.floor(getn("mode", 1)))),
  output_order = math.max(1, math.min(3, math.floor(getn("output_order", 3)))),
  stereo_width = getn("stereo_width", 1.0),
  center_amount = getn("center_amount", 0.55),
  front_weight = getn("front_weight", 0.80),
  side_amount = getn("side_amount", 0.65),
  rear_amount = getn("rear_amount", 0.35),
  height_amount = getn("height_amount", 0.12),
  source_spread = getn("source_spread", 0.16),
  decorrelation = getn("decorrelation", 0.20),
  bass_mono_hz = getn("bass_mono_hz", 120.0),
  normalize = getb("normalize", true),
  normalize_db = getn("normalize_db", -6.0),
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
  local out_dir = nr.output_dir("s3g_stereo_expand_ambisonic_renders", entry.filename, script_dir)
  local output_path = out_dir .. "/s3g_stereo_expand_ambisonic_" .. stamp .. "_" .. tostring(settings.output_order) .. "oa.wav"
  local manifest = {
    source_path = entry.filename,
    source_start = entry.start_offset,
    source_duration = entry.length * math.max(0.000001, entry.playrate),
    sample_rate = nr.source_sample_rate(entry),
    output_path = output_path,
    mode = MODES[settings.mode],
    output_order = settings.output_order,
    stereo_width = settings.stereo_width,
    center_amount = settings.center_amount,
    front_weight = settings.front_weight,
    side_amount = settings.side_amount,
    rear_amount = settings.rear_amount,
    height_amount = settings.height_amount,
    source_spread = settings.source_spread,
    decorrelation = settings.decorrelation,
    bass_mono_hz = settings.bass_mono_hz,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
  }
  local log, elapsed = nr.run_backend(script_dir, "stereo_expand_ambisonic_bed", manifest, TITLE)
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path, "Stereo Expand Ambisonic Bed (" .. tostring(settings.output_order) .. "OA)", entry.position, out_channels, { master_send = false, track_gain = 0.5 })
  reaper.Undo_EndBlock(TITLE, -1)
  if not item then mc.show_error(err or "Could not insert rendered item.") return end
  mc.print_plan(TITLE, {
    "Source: " .. entry.name,
    "Mode: " .. MODE_LABELS[settings.mode],
    "Output: " .. output_path,
    "Master send: off",
    string.format("NumPy time: %.2f sec", elapsed),
    log,
  })
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 700, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    ImGui.Text(ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
    draw_preview()
    settings.mode = combo("Expansion mode", settings.mode, MODE_LABELS)
    settings.output_order = combo("Output order", settings.output_order, ORDER_LABELS)
    ImGui.Separator(ctx)
    local changed
    changed, settings.stereo_width = ImGui.SliderDouble(ctx, "Stereo width", settings.stereo_width, 0.0, 2.0, "%.2f")
    changed, settings.center_amount = ImGui.SliderDouble(ctx, "Center amount", settings.center_amount, 0.0, 1.5, "%.2f")
    changed, settings.front_weight = ImGui.SliderDouble(ctx, "Front weight", settings.front_weight, 0.0, 1.5, "%.2f")
    changed, settings.side_amount = ImGui.SliderDouble(ctx, "Side amount", settings.side_amount, 0.0, 1.5, "%.2f")
    changed, settings.rear_amount = ImGui.SliderDouble(ctx, "Rear amount", settings.rear_amount, 0.0, 1.5, "%.2f")
    changed, settings.height_amount = ImGui.SliderDouble(ctx, "Height amount", settings.height_amount, 0.0, 1.0, "%.2f")
    changed, settings.source_spread = ImGui.SliderDouble(ctx, "Source spread", settings.source_spread, 0.0, 1.0, "%.2f")
    changed, settings.decorrelation = ImGui.SliderDouble(ctx, "Decorrelation", settings.decorrelation, 0.0, 1.0, "%.2f")
    changed, settings.bass_mono_hz = ImGui.SliderDouble(ctx, "Bass mono below Hz", settings.bass_mono_hz, 0.0, 300.0, "%.0f")
    changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
    if settings.normalize then
      changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -24.0, 0.0, "%.1f")
    end
    ImGui.Separator(ctx)
    ImGui.TextWrapped(ctx, "Mono sources are treated as a center object. Stereo sources derive spatial cues from left/right plus mid/side material, then render a new ACN/SN3D ambisonic WAV.")
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
