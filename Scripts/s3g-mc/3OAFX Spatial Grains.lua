-- @description 3OAFX Spatial Grains
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline ambisonic spatial-grain render.
-- @method Select one WAV-backed ACN/SN3D ambisonic media item. The renderer applies identical grain position, envelope, duration, rate, and overlap decisions to all encoded channels, preserving spatial-grain coherence while adding time navigation, cloud selection, room-memory grain sizing, and optional HOA yaw/order transforms.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "3OAFX Spatial Grains", 0) return end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local EXT = "s3g_mc_foafx_spatial_grains_v1"
local MODES = { "scan", "cloud", "dual", "jump", "freeze" }
local MODE_LABELS = { "Index scan", "Cloud", "Dual state", "Jump scan", "Freeze cloud" }

local function getn(k, d) return tonumber(reaper.GetExtState(EXT, k)) or d end
local function getb(k, d) local v = reaper.GetExtState(EXT, k); if v == "" then return d end; return v ~= "0" end
local function set(k, v) reaper.SetExtState(EXT, k, type(v) == "boolean" and (v and "1" or "0") or tostring(v), true) end
local function combo(ctx, label, idx, names)
  if ImGui.BeginCombo(ctx, label, names[idx] or "") then
    for i, name in ipairs(names) do
      local selected = i == idx
      if ImGui.Selectable(ctx, name, selected) then idx = i end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return idx
end
local function order_for(ch) if ch >= 16 then return 3 elseif ch >= 9 then return 2 else return 1 end end
local function order_channels(order) return (order + 1) * (order + 1) end

local entries = nr.selected_entries()
local entry = entries[1]
if not entry then mc.show_error("Select one WAV-backed ambisonic media item.") return end

local settings = {
  order = math.min(3, math.max(1, math.floor(getn("order", order_for(entry.channels))))),
  duration = getn("duration", entry.length),
  mode = math.min(#MODES, math.max(1, math.floor(getn("mode", 1)))),
  density = getn("density", 28.0),
  grain_ms = getn("grain_ms", 80.0),
  position_jitter = getn("position_jitter", 0.12),
  rate = getn("rate", 1.0),
  rate_jitter = getn("rate_jitter", 0.04),
  reverse_probability = getn("reverse_probability", 0.0),
  freeze_position = getn("freeze_position", 0.5),
  dual_a = getn("dual_a", 0.18),
  dual_b = getn("dual_b", 0.82),
  jump_steps = getn("jump_steps", 8),
  room_memory = getn("room_memory", 0.35),
  doppler_rate = getn("doppler_rate", 0.0),
  yaw_start = getn("yaw_start", 0.0),
  yaw_end = getn("yaw_end", 0.0),
  yaw_scatter = getn("yaw_scatter", 0.0),
  higher_order_weight = getn("higher_order_weight", 1.0),
  w_weight = getn("w_weight", 1.0),
  normalize = getb("normalize", true),
  normalize_db = getn("normalize_db", -6.0),
  seed = getn("seed", 1),
}

local ctx = ImGui.CreateContext("3OAFX Spatial Grains")
local open, should_render = true, false
local function persist() for k, v in pairs(settings) do set(k, v) end end

local function render()
  local needed = order_channels(settings.order)
  if entry.channels < needed then mc.show_error("Selected item has " .. tostring(entry.channels) .. " channels; selected order needs " .. tostring(needed) .. ".") return end
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_foafx_spatial_grains_renders", entry.filename, script_dir)
  local output_path = out_dir .. "/s3g_foafx_spatial_grains_" .. stamp .. "_" .. tostring(settings.order) .. "oa.wav"
  local manifest = {
    source_path = entry.filename,
    source_start = entry.start_offset,
    source_duration = entry.length * math.max(0.000001, entry.playrate),
    sample_rate = nr.source_sample_rate(entry),
    output_path = output_path,
    order = settings.order,
    duration = settings.duration,
    navigation_mode = MODES[settings.mode],
    density = settings.density,
    grain_ms = settings.grain_ms,
    position_jitter = settings.position_jitter,
    rate = settings.rate,
    rate_jitter = settings.rate_jitter,
    reverse_probability = settings.reverse_probability,
    freeze_position = settings.freeze_position,
    dual_a = settings.dual_a,
    dual_b = settings.dual_b,
    jump_steps = settings.jump_steps,
    room_memory = settings.room_memory,
    doppler_rate = settings.doppler_rate,
    yaw_start = settings.yaw_start,
    yaw_end = settings.yaw_end,
    yaw_scatter = settings.yaw_scatter,
    higher_order_weight = settings.higher_order_weight,
    w_weight = settings.w_weight,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    seed = settings.seed,
  }
  local log, elapsed = nr.run_backend(script_dir, "foafx_spatial_grains", manifest, "3OAFX Spatial Grains")
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path, "3OAFX spatial grains (" .. tostring(settings.order) .. "OA)", entry.position, needed, { master_send = false, track_gain = 0.5 })
  reaper.Undo_EndBlock("3OAFX Spatial Grains", -1)
  if not item then mc.show_error(err or "Could not insert rendered item.") return end
  mc.print_plan("3OAFX Spatial Grains", { "Source: " .. entry.name, "Mode: " .. MODE_LABELS[settings.mode], "Output: " .. output_path, "Master send: off", string.format("NumPy time: %.2f sec", elapsed), log })
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 640, 650, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, "3OAFX Spatial Grains", open)
  if visible then
    ImGui.Text(ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
    local changed
    changed, settings.order = ImGui.SliderInt(ctx, "Ambisonic order", math.floor(settings.order), 1, 3)
    settings.mode = combo(ctx, "Navigation mode", settings.mode, MODE_LABELS)
    changed, settings.duration = ImGui.SliderDouble(ctx, "Output duration sec", settings.duration, 0.25, 300.0, "%.2f")
    changed, settings.density = ImGui.SliderDouble(ctx, "Density grains/sec", settings.density, 1.0, 240.0, "%.1f")
    changed, settings.grain_ms = ImGui.SliderDouble(ctx, "Grain size ms", settings.grain_ms, 8.0, 600.0, "%.1f")
    changed, settings.position_jitter = ImGui.SliderDouble(ctx, "Source-time scatter", settings.position_jitter, 0.0, 1.0, "%.2f")
    changed, settings.rate = ImGui.SliderDouble(ctx, "Playback rate", settings.rate, 0.125, 4.0, "%.3f")
    changed, settings.rate_jitter = ImGui.SliderDouble(ctx, "Rate jitter oct", settings.rate_jitter, 0.0, 1.0, "%.3f")
    changed, settings.reverse_probability = ImGui.SliderDouble(ctx, "Reverse probability", settings.reverse_probability, 0.0, 1.0, "%.2f")
    changed, settings.freeze_position = ImGui.SliderDouble(ctx, "Freeze position", settings.freeze_position, 0.0, 1.0, "%.3f")
    changed, settings.dual_a = ImGui.SliderDouble(ctx, "Dual state A", settings.dual_a, 0.0, 1.0, "%.3f")
    changed, settings.dual_b = ImGui.SliderDouble(ctx, "Dual state B", settings.dual_b, 0.0, 1.0, "%.3f")
    changed, settings.jump_steps = ImGui.SliderInt(ctx, "Jump steps", math.floor(settings.jump_steps), 2, 64)
    changed, settings.room_memory = ImGui.SliderDouble(ctx, "Room memory", settings.room_memory, 0.0, 1.0, "%.2f")
    changed, settings.doppler_rate = ImGui.SliderDouble(ctx, "Doppler-like rate", settings.doppler_rate, 0.0, 1.0, "%.2f")
    ImGui.Separator(ctx)
    changed, settings.yaw_start = ImGui.SliderDouble(ctx, "Yaw start deg", settings.yaw_start, -360.0, 360.0, "%.1f")
    changed, settings.yaw_end = ImGui.SliderDouble(ctx, "Yaw end deg", settings.yaw_end, -360.0, 360.0, "%.1f")
    changed, settings.yaw_scatter = ImGui.SliderDouble(ctx, "Per-grain yaw scatter", settings.yaw_scatter, 0.0, 180.0, "%.1f")
    changed, settings.higher_order_weight = ImGui.SliderDouble(ctx, "Higher-order weight", settings.higher_order_weight, 0.0, 2.0, "%.2f")
    changed, settings.w_weight = ImGui.SliderDouble(ctx, "W weight", settings.w_weight, 0.0, 2.0, "%.2f")
    changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
    if settings.normalize then changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -24.0, 0.0, "%.1f") end
    changed, settings.seed = ImGui.InputInt(ctx, "Seed", math.floor(settings.seed))
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Every grain event is shared across all encoded HOA channels.")
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
