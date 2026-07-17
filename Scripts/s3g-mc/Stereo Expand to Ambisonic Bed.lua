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
  return select(2, theme.combo_row(ImGui, ctx, label, labels, idx))
end

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local STYLE = {
  bg = THEME.bg,
  grid = THEME.grid,
  ring = THEME.edge,
  text = THEME.text,
  muted = THEME.value,
  left = color(0.82, 0.54, 0.42, 0.92),
  right = color(0.54, 0.62, 0.66, 0.92),
  mid = THEME.amber,
  side = color(0.52, 0.62, 0.56, 0.82),
  rear = color(0.58, 0.54, 0.64, 0.72),
  height = color(0.72, 0.72, 0.62, 0.72),
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
  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x0 + w, y0 + h, STYLE.bg)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x0 + w, y0 + h, STYLE.grid)
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 12, STYLE.text, "Stereo source to ambisonic bed")
  ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 32, STYLE.muted, MODE_LABELS[settings.mode] .. " / " .. ORDER_LABELS[settings.output_order])
  ImGui.DrawList_AddCircle(draw_list, cx, cy, r, STYLE.ring, 96, 1.5)
  ImGui.DrawList_AddCircle(draw_list, cx, cy, r * 0.55, STYLE.grid, 96, 1)
  ImGui.DrawList_AddLine(draw_list, cx - r, cy, cx + r, cy, STYLE.grid, 1)
  ImGui.DrawList_AddLine(draw_list, cx, cy - r, cx, cy + r, STYLE.grid, 1)
  ImGui.DrawList_AddText(draw_list, cx - 9, cy - r - 20, STYLE.muted, "F")
  ImGui.DrawList_AddText(draw_list, cx - 9, cy + r + 6, STYLE.muted, "R")

  local angle = 30 + settings.stereo_width * 35
  local spread_r = 0.62 + math.min(0.28, settings.source_spread * 0.35)
  draw_node(draw_list, cx, cy, r, angle, spread_r, STYLE.left, 8)
  draw_node(draw_list, cx, cy, r, -angle, spread_r, STYLE.right, 8)
  draw_node(draw_list, cx, cy, r, 0, 0.36, STYLE.mid, 6 + settings.center_amount * 3)
  draw_node(draw_list, cx, cy, r, 90, 0.72, STYLE.side, 4 + settings.side_amount * 3)
  draw_node(draw_list, cx, cy, r, -90, 0.72, STYLE.side, 4 + settings.side_amount * 3)
  draw_node(draw_list, cx, cy, r, 180, 0.58 + settings.rear_amount * 0.22, STYLE.rear, 4 + settings.rear_amount * 4)
  if settings.height_amount > 0.01 then
    ImGui.DrawList_AddCircle(draw_list, cx, cy, r * (0.20 + settings.height_amount * 0.38), STYLE.height, 48, 2)
    draw_node(draw_list, cx, cy, r, 0, 0.12, STYLE.height, 4 + settings.height_amount * 5)
  end

  local bx = x0 + 16
  local by = y0 + h - 34
  local bw = w - 32
  ImGui.DrawList_AddRect(draw_list, bx, by, bx + bw, by + 12, STYLE.grid)
  ImGui.DrawList_AddRectFilled(draw_list, bx, by, bx + bw * math.min(1, settings.decorrelation), by + 12, STYLE.rear)
  ImGui.DrawList_AddText(draw_list, bx, by + 15, STYLE.muted, "decorrelation / diffuse support")
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
  local field_mix_h = settings.normalize and 298 or 273
  local body_target_h = 22 + 253 + (123 + 10) + (field_mix_h + 10) + 24
  ImGui.SetNextWindowSize(ctx, 700, body_target_h + 72, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local footer_h = 48
    local avail_h = ImGui.GetContentRegionAvail(ctx)
    local body_h = math.min(body_target_h, math.max(360, (avail_h or body_target_h + footer_h) - footer_h))
    if ImGui.BeginChild(ctx, "##stereo_expand_bed_controls", 0, body_h, 0) then
      theme.muted(ImGui, ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
      draw_preview()
      local sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Bed", 123)
      settings.mode = combo("Expansion mode", settings.mode, MODE_LABELS)
      settings.output_order = combo("Output order", settings.output_order, ORDER_LABELS)
      local changed
      changed, settings.stereo_width = theme.slider_double(ImGui, ctx, "Stereo width", settings.stereo_width, 0.0, 2.0, "%.2f")
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)

      sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Field Mix", field_mix_h)
      changed, settings.center_amount = theme.slider_double(ImGui, ctx, "Center amount", settings.center_amount, 0.0, 1.5, "%.2f")
      changed, settings.front_weight = theme.slider_double(ImGui, ctx, "Front weight", settings.front_weight, 0.0, 1.5, "%.2f")
      changed, settings.side_amount = theme.slider_double(ImGui, ctx, "Side amount", settings.side_amount, 0.0, 1.5, "%.2f")
      changed, settings.rear_amount = theme.slider_double(ImGui, ctx, "Rear amount", settings.rear_amount, 0.0, 1.5, "%.2f")
      changed, settings.height_amount = theme.slider_double(ImGui, ctx, "Height amount", settings.height_amount, 0.0, 1.0, "%.2f")
      changed, settings.source_spread = theme.slider_double(ImGui, ctx, "Source spread", settings.source_spread, 0.0, 1.0, "%.2f")
      changed, settings.decorrelation = theme.slider_double(ImGui, ctx, "Decorrelation", settings.decorrelation, 0.0, 1.0, "%.2f")
      changed, settings.bass_mono_hz = theme.slider_double(ImGui, ctx, "Bass mono Hz", settings.bass_mono_hz, 0.0, 300.0, "%.0f")
      changed, settings.normalize = theme.checkbox_row(ImGui, ctx, "PK NORM", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = theme.slider_double(ImGui, ctx, "Norm dB", settings.normalize_db, -24.0, 0.0, "%.1f")
      end
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)
      theme.muted(ImGui, ctx, "Mono sources are center objects; stereo sources derive bed cues from L/R and M/S material.")
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
