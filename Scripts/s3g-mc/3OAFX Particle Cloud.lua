-- @description 3OAFX Particle Cloud
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline ambisonic particle-cloud render.
-- @method Select one WAV-backed ACN/SN3D ambisonic media item. The renderer emits coherent grains across all encoded channels, with density, asynchronicity, intermittency, scan motion, playback rate, envelope shape, and ambisonic yaw controls.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "3OAFX Particle Cloud", 0) return end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "3OAFX Particle Cloud"
local EXT = "s3g_mc_foafx_particle_cloud_v1"

local function getn(k, d) return tonumber(reaper.GetExtState(EXT, k)) or d end
local function getb(k, d) local v = reaper.GetExtState(EXT, k); if v == "" then return d end; return v ~= "0" end
local function set(k, v) reaper.SetExtState(EXT, k, type(v) == "boolean" and (v and "1" or "0") or tostring(v), true) end
local function order_for(ch) if ch >= 16 then return 3 elseif ch >= 9 then return 2 else return 1 end end
local function order_channels(order) return (order + 1) * (order + 1) end

local entries = nr.selected_entries()
local entry = entries[1]
if not entry then mc.show_error("Select one WAV-backed ambisonic media item.") return end

local settings = {
  order = math.max(1, math.min(3, math.floor(getn("order", order_for(entry.channels))))),
  duration = getn("duration", entry.length),
  density = getn("density", 48.0),
  asynchronicity = getn("asynchronicity", 0.65),
  intermittency = getn("intermittency", 0.15),
  streams = math.max(1, math.min(16, math.floor(getn("streams", 4)))),
  grain_ms = getn("grain_ms", 90.0),
  grain_jitter = getn("grain_jitter", 0.35),
  playback_rate = getn("playback_rate", 1.0),
  playback_jitter = getn("playback_jitter", 0.15),
  scan_begin = getn("scan_begin", 0.0),
  scan_range = getn("scan_range", 1.0),
  scan_speed = getn("scan_speed", 1.0),
  envelope_shape = getn("envelope_shape", 0.5),
  yaw_start = getn("yaw_start", 0.0),
  yaw_end = getn("yaw_end", 0.0),
  yaw_scatter = getn("yaw_scatter", 35.0),
  order_blur = getn("order_blur", 0.0),
  gain_db = getn("gain_db", -9.0),
  normalize = getb("normalize", true),
  normalize_db = getn("normalize_db", -6.0),
  seed = math.floor(getn("seed", 1)),
}

local ctx = ImGui.CreateContext(TITLE)
local open, should_render = true, false
local function persist() for k, v in pairs(settings) do set(k, v) end end

local function render()
  local needed = order_channels(settings.order)
  if entry.channels < needed then mc.show_error("Selected item has " .. tostring(entry.channels) .. " channels; selected order needs " .. tostring(needed) .. ".") return end
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_foafx_particle_cloud_renders", entry.filename, script_dir)
  local output_path = out_dir .. "/s3g_foafx_particle_cloud_" .. stamp .. "_" .. tostring(settings.order) .. "oa.wav"
  local manifest = {
    source_path = entry.filename,
    source_start = entry.start_offset,
    source_duration = entry.length * math.max(0.000001, entry.playrate),
    sample_rate = nr.source_sample_rate(entry),
    output_path = output_path,
    order = settings.order,
    duration = settings.duration,
    density = settings.density,
    asynchronicity = settings.asynchronicity,
    intermittency = settings.intermittency,
    streams = settings.streams,
    grain_ms = settings.grain_ms,
    grain_jitter = settings.grain_jitter,
    playback_rate = settings.playback_rate,
    playback_jitter = settings.playback_jitter,
    scan_begin = settings.scan_begin,
    scan_range = settings.scan_range,
    scan_speed = settings.scan_speed,
    envelope_shape = settings.envelope_shape,
    yaw_start = settings.yaw_start,
    yaw_end = settings.yaw_end,
    yaw_scatter = settings.yaw_scatter,
    order_blur = settings.order_blur,
    gain_db = settings.gain_db,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    seed = settings.seed,
  }
  local log, elapsed = nr.run_backend(script_dir, "foafx_particle_cloud", manifest, TITLE)
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path, "3OAFX Particle Cloud (" .. tostring(settings.order) .. "OA)", entry.position, needed, { master_send = false, track_gain = 0.5 })
  reaper.Undo_EndBlock(TITLE, -1)
  if not item then mc.show_error(err or "Could not insert rendered item.") return end
  mc.print_plan(TITLE, { "Source: " .. entry.name, "Output: " .. output_path, "Master send: off", string.format("NumPy time: %.2f sec", elapsed), log })
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 640, 690, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    ImGui.Text(ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
    local changed
    changed, settings.order = ImGui.SliderInt(ctx, "Ambisonic order", math.floor(settings.order), 1, 3)
    changed, settings.duration = ImGui.SliderDouble(ctx, "Output duration sec", settings.duration, 0.25, 240.0, "%.2f")
    changed, settings.density = ImGui.SliderDouble(ctx, "Grain rate", settings.density, 0.5, 240.0, "%.1f")
    changed, settings.streams = ImGui.SliderInt(ctx, "Streams", math.floor(settings.streams), 1, 16)
    changed, settings.asynchronicity = ImGui.SliderDouble(ctx, "Asynchronicity", settings.asynchronicity, 0.0, 1.0, "%.2f")
    changed, settings.intermittency = ImGui.SliderDouble(ctx, "Intermittency", settings.intermittency, 0.0, 0.95, "%.2f")
    ImGui.Separator(ctx)
    changed, settings.grain_ms = ImGui.SliderDouble(ctx, "Grain duration ms", settings.grain_ms, 4.0, 1000.0, "%.1f")
    changed, settings.grain_jitter = ImGui.SliderDouble(ctx, "Duration jitter", settings.grain_jitter, 0.0, 1.0, "%.2f")
    changed, settings.envelope_shape = ImGui.SliderDouble(ctx, "Envelope shape", settings.envelope_shape, 0.0, 1.0, "%.2f")
    changed, settings.playback_rate = ImGui.SliderDouble(ctx, "Playback rate", settings.playback_rate, -4.0, 4.0, "%.3f")
    changed, settings.playback_jitter = ImGui.SliderDouble(ctx, "Playback jitter oct", settings.playback_jitter, 0.0, 2.0, "%.2f")
    ImGui.Separator(ctx)
    changed, settings.scan_begin = ImGui.SliderDouble(ctx, "Scan begin", settings.scan_begin, 0.0, 1.0, "%.3f")
    changed, settings.scan_range = ImGui.SliderDouble(ctx, "Scan range", settings.scan_range, -1.0, 1.0, "%.3f")
    changed, settings.scan_speed = ImGui.SliderDouble(ctx, "Scan speed", settings.scan_speed, -4.0, 4.0, "%.3f")
    ImGui.Separator(ctx)
    changed, settings.yaw_start = ImGui.SliderDouble(ctx, "Yaw start deg", settings.yaw_start, -360.0, 360.0, "%.1f")
    changed, settings.yaw_end = ImGui.SliderDouble(ctx, "Yaw end deg", settings.yaw_end, -360.0, 360.0, "%.1f")
    changed, settings.yaw_scatter = ImGui.SliderDouble(ctx, "Per-grain yaw scatter", settings.yaw_scatter, 0.0, 180.0, "%.1f")
    changed, settings.order_blur = ImGui.SliderDouble(ctx, "Higher-order blur", settings.order_blur, 0.0, 1.0, "%.2f")
    changed, settings.gain_db = ImGui.SliderDouble(ctx, "Pre-gain dB", settings.gain_db, -36.0, 0.0, "%.1f")
    changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
    if settings.normalize then changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -24.0, 0.0, "%.1f") end
    changed, settings.seed = ImGui.InputInt(ctx, "Seed", math.floor(settings.seed))
    ImGui.Separator(ctx)
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
