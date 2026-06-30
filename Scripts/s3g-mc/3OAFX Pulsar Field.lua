-- @description 3OAFX Pulsar Field
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed ambisonic pulsar synthesis render.
-- @method Creates a new ACN/SN3D ambisonic item from multiple pulsar streams. Fundamental rate, formant frequency, pulse masking, pulsaret shape, envelope shape, and AED trajectory define the field.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "3OAFX Pulsar Field", 0) return end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "3OAFX Pulsar Field"
local EXT = "s3g_mc_foafx_pulsar_field_v1"
local CURVES = { "rise", "fall", "arch", "valley", "wander" }
local CURVE_LABELS = { "Rise", "Fall", "Arch", "Valley", "Wander" }
local MASKS = { "stochastic", "burst", "channel", "none" }
local MASK_LABELS = { "Stochastic", "Burst", "Channel dialogue", "None" }
local PULSARETS = { "sine", "overtone", "fold", "impulse", "noise" }
local PULSARET_LABELS = { "Sine", "Overtone", "Fold", "Impulse", "Noise" }
local ENVS = { "hann", "expo", "reverse expo", "rect" }
local ENV_LABELS = { "Hann / Tukey", "Exponential decay", "Reverse exponential", "Rectangular" }

local function getn(k, d) return tonumber(reaper.GetExtState(EXT, k)) or d end
local function getb(k, d) local v = reaper.GetExtState(EXT, k); if v == "" then return d end; return v ~= "0" end
local function set(k, v) reaper.SetExtState(EXT, k, type(v) == "boolean" and (v and "1" or "0") or tostring(v), true) end
local function order_channels(order) return (order + 1) * (order + 1) end
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

local settings = {
  order = math.max(1, math.min(3, math.floor(getn("order", 3)))),
  duration = getn("duration", 12.0),
  streams = math.max(1, math.min(12, math.floor(getn("streams", 3)))),
  fund_start = getn("fund_start", 7.0),
  fund_end = getn("fund_end", 34.0),
  form_start = getn("form_start", 180.0),
  form_end = getn("form_end", 1800.0),
  curve = math.max(1, math.min(#CURVES, math.floor(getn("curve", 1)))),
  mask = math.max(1, math.min(#MASKS, math.floor(getn("mask", 1)))),
  probability = getn("probability", 0.86),
  burst_on = math.max(1, math.floor(getn("burst_on", 5))),
  burst_off = math.max(0, math.floor(getn("burst_off", 3))),
  pulsaret = math.max(1, math.min(#PULSARETS, math.floor(getn("pulsaret", 1)))),
  envelope = math.max(1, math.min(#ENVS, math.floor(getn("envelope", 1)))),
  edge = getn("edge", 0.35),
  gain_db = getn("gain_db", -12.0),
  yaw_start = getn("yaw_start", -90.0),
  yaw_end = getn("yaw_end", 90.0),
  elevation = getn("elevation", 0.0),
  spatial_spread = getn("spatial_spread", 0.25),
  formant_scatter = getn("formant_scatter", 0.18),
  drift = getn("drift", 0.12),
  channel_mask = getn("channel_mask", 0.0),
  normalize = getb("normalize", true),
  normalize_db = getn("normalize_db", -6.0),
  seed = math.floor(getn("seed", 1)),
}

local ctx = ImGui.CreateContext(TITLE)
local open, should_render = true, false

local function persist()
  for k, v in pairs(settings) do set(k, v) end
end

local function render()
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_foafx_pulsar_field_renders", nil, script_dir)
  local output_path = out_dir .. "/s3g_foafx_pulsar_field_" .. stamp .. "_" .. tostring(settings.order) .. "oa.wav"
  local manifest = {
    output_path = output_path,
    sample_rate = 48000,
    order = settings.order,
    duration = settings.duration,
    streams = settings.streams,
    fund_start = settings.fund_start,
    fund_end = settings.fund_end,
    form_start = settings.form_start,
    form_end = settings.form_end,
    train_curve = CURVES[settings.curve],
    mask_mode = MASKS[settings.mask],
    pulse_probability = settings.probability,
    burst_on = settings.burst_on,
    burst_off = settings.burst_off,
    pulsaret = PULSARETS[settings.pulsaret],
    envelope = ENVS[settings.envelope],
    edge = settings.edge,
    gain_db = settings.gain_db,
    yaw_start = settings.yaw_start,
    yaw_end = settings.yaw_end,
    elevation = settings.elevation,
    spatial_spread = settings.spatial_spread,
    formant_scatter = settings.formant_scatter,
    drift = settings.drift,
    channel_mask = settings.channel_mask,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    seed = settings.seed,
  }
  local log, elapsed = nr.run_backend(script_dir, "foafx_pulsar_field", manifest, TITLE)
  if not log then return end
  local channels = order_channels(settings.order)
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path, "3OAFX Pulsar Field (" .. tostring(settings.order) .. "OA)", reaper.GetCursorPosition(), channels, { master_send = false, track_gain = 0.5 })
  reaper.Undo_EndBlock(TITLE, -1)
  if not item then mc.show_error(err or "Could not insert rendered item.") return end
  mc.print_plan(TITLE, { "Output: " .. output_path, "Master send: off", string.format("NumPy time: %.2f sec", elapsed), log })
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 640, 720, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local changed
    changed, settings.order = ImGui.SliderInt(ctx, "Ambisonic order", math.floor(settings.order), 1, 3)
    changed, settings.duration = ImGui.SliderDouble(ctx, "Duration sec", settings.duration, 0.25, 120.0, "%.2f")
    changed, settings.streams = ImGui.SliderInt(ctx, "Pulsar streams", math.floor(settings.streams), 1, 12)
    settings.curve = combo(ctx, "Train curve", settings.curve, CURVE_LABELS)
    settings.mask = combo(ctx, "Pulse mask", settings.mask, MASK_LABELS)
    ImGui.Separator(ctx)
    changed, settings.fund_start = ImGui.SliderDouble(ctx, "Fundamental start Hz", settings.fund_start, 0.25, 250.0, "%.2f")
    changed, settings.fund_end = ImGui.SliderDouble(ctx, "Fundamental end Hz", settings.fund_end, 0.25, 250.0, "%.2f")
    changed, settings.form_start = ImGui.SliderDouble(ctx, "Formant start Hz", settings.form_start, 40.0, 8000.0, "%.1f")
    changed, settings.form_end = ImGui.SliderDouble(ctx, "Formant end Hz", settings.form_end, 40.0, 8000.0, "%.1f")
    changed, settings.formant_scatter = ImGui.SliderDouble(ctx, "Formant scatter", settings.formant_scatter, 0.0, 1.0, "%.2f")
    changed, settings.drift = ImGui.SliderDouble(ctx, "Train drift", settings.drift, 0.0, 1.0, "%.2f")
    ImGui.Separator(ctx)
    settings.pulsaret = combo(ctx, "Pulsaret", settings.pulsaret, PULSARET_LABELS)
    settings.envelope = combo(ctx, "Pulsaret envelope", settings.envelope, ENV_LABELS)
    changed, settings.edge = ImGui.SliderDouble(ctx, "Edge / cutoff softness", settings.edge, 0.0, 1.0, "%.2f")
    changed, settings.probability = ImGui.SliderDouble(ctx, "Stochastic probability", settings.probability, 0.0, 1.0, "%.2f")
    changed, settings.burst_on = ImGui.SliderInt(ctx, "Burst on", math.floor(settings.burst_on), 1, 32)
    changed, settings.burst_off = ImGui.SliderInt(ctx, "Burst off", math.floor(settings.burst_off), 0, 32)
    ImGui.Separator(ctx)
    changed, settings.yaw_start = ImGui.SliderDouble(ctx, "Azimuth start deg", settings.yaw_start, -180.0, 180.0, "%.1f")
    changed, settings.yaw_end = ImGui.SliderDouble(ctx, "Azimuth end deg", settings.yaw_end, -180.0, 180.0, "%.1f")
    changed, settings.elevation = ImGui.SliderDouble(ctx, "Elevation deg", settings.elevation, -89.0, 89.0, "%.1f")
    changed, settings.spatial_spread = ImGui.SliderDouble(ctx, "Stream spatial spread", settings.spatial_spread, 0.0, 1.0, "%.2f")
    changed, settings.channel_mask = ImGui.SliderDouble(ctx, "Per-pulse channel mask", settings.channel_mask, 0.0, 1.0, "%.2f")
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
