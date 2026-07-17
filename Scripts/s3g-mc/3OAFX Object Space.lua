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
local theme
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
    theme = _s3g_theme
    if _s3g_theme.install then _s3g_theme.install(ImGui) end
  end
end


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
  local _, next_idx = theme.combo_row(ImGui, ctx, label, labels, idx)
  return next_idx
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
  ImGui.SetNextWindowSize(ctx, 720, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local footer_h = 64
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    local control_h = math.max(260, avail_h - footer_h)
    if ImGui.BeginChild(ctx, "##object_space_controls", 0, control_h) then
      theme.muted(ImGui, ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
      local changed
      local sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Routing", 123)
      settings.mode = combo("Mode", settings.mode, MODE_LABELS)
      settings.source_format = combo("Source format", settings.source_format, SOURCE_LABELS)
      settings.output_order = combo("Output order", settings.output_order, ORDER_LABELS)
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)

      sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Object / Space", 180)
      changed, settings.source_spread = theme.slider_double(ImGui, ctx, "Source object spread", settings.source_spread, 0.0, 1.0, "%.2f")
      changed, settings.object_clarity = theme.slider_double(ImGui, ctx, "Object clarity", settings.object_clarity, 0.0, 1.0, "%.2f")
      changed, settings.dry_level = theme.slider_double(ImGui, ctx, "Dry object level", settings.dry_level, 0.0, 1.5, "%.2f")
      changed, settings.space_amount = theme.slider_double(ImGui, ctx, "Space amount", settings.space_amount, 0.0, 2.0, "%.2f")
      changed, settings.spread_deg = theme.slider_double(ImGui, ctx, "Spatial spread deg", settings.spread_deg, 1.0, 180.0, "%.1f")
      changed, settings.motion = theme.slider_double(ImGui, ctx, "Spatial motion", settings.motion, 0.0, 1.0, "%.2f")
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)

      sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Spectral", 114)
      changed, settings.resonance_hz = theme.slider_double(ImGui, ctx, "Resonance Hz", settings.resonance_hz, 30.0, 6000.0, "%.1f")
      changed, settings.feedback = theme.slider_double(ImGui, ctx, "Resonant feedback", settings.feedback, 0.0, 0.92, "%.2f")
      changed, settings.smear = theme.slider_double(ImGui, ctx, "Spectral smear", settings.smear, 0.0, 1.0, "%.2f")
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)

      sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Output", settings.normalize and 123 or 98)
      changed, settings.normalize = theme.checkbox_row(ImGui, ctx, "Peak normalize", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = theme.slider_double(ImGui, ctx, "Normalize dB", settings.normalize_db, -24.0, 0.0, "%.1f")
      end
      changed, settings.seed = theme.input_int_row(ImGui, ctx, "Seed", math.floor(settings.seed))
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)

      theme.muted(ImGui, ctx, "Auto treats 4ch, 10ch, and 16ch as ACN/SN3D; 9ch WAVs are accepted as 2OA.")
      ImGui.EndChild(ctx)
    end
    local render_pressed, cancel_pressed = theme.footer_buttons(ImGui, ctx, "RENDER", "CANCEL")
    if render_pressed then should_render = true end
    if cancel_pressed then open = false end
    ImGui.Dummy(ctx, 1, 10)
    ImGui.End(ctx)
  end
  persist()
  if should_render then open = false; render(); return end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
