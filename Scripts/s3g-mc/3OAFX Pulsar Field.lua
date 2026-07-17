-- @description 3OAFX Pulsar Field
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed ambisonic pulsar synthesis render.
-- @method Creates a new ACN/SN3D ambisonic item from multiple pulsar streams. Breakpoint curves can vary amplitude, fundamental, formant, probability, spatial spread, and azimuth over time.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")
local be = dofile(script_dir .. "Breakpoint Envelope Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "3OAFX Pulsar Field", 0) return end
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
local ENV_DEFS = {
  { key = "amplitude", label = "Amplitude", min = 0.0, max = 1.5, default = 1.0, fmt = "%.2f" },
  { key = "fundamental", label = "Fundamental", min = 0.25, max = 250.0, default = 18.0, fmt = "%.2f Hz" },
  { key = "formant", label = "Formant", min = 40.0, max = 8000.0, default = 900.0, fmt = "%.1f Hz" },
  { key = "probability", label = "Probability", min = 0.0, max = 1.0, default = 0.86, fmt = "%.2f" },
  { key = "spatial_spread", label = "Spatial spread", min = 0.0, max = 1.0, default = 0.25, fmt = "%.2f" },
  { key = "yaw", label = "Azimuth", min = -180.0, max = 180.0, default = 0.0, fmt = "%.1f deg" },
}

local function getn(k, d) return tonumber(reaper.GetExtState(EXT, k)) or d end
local function getb(k, d) local v = reaper.GetExtState(EXT, k); if v == "" then return d end; return v ~= "0" end
local function set(k, v) reaper.SetExtState(EXT, k, type(v) == "boolean" and (v and "1" or "0") or tostring(v), true) end
local function order_channels(order) return (order + 1) * (order + 1) end
local settings
local function combo(ctx, label, idx, names)
  local _, next_idx = theme.combo_row(ImGui, ctx, label, names, idx)
  return next_idx
end


settings = {
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

local function render(env_points, env_enabled)
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
  be.add_to_manifest(manifest, ENV_DEFS, env_points, env_enabled)
  local log, elapsed = nr.run_backend(script_dir, "foafx_pulsar_field", manifest, TITLE)
  if not log then return end
  local channels = order_channels(settings.order)
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path, "3OAFX Pulsar Field (" .. tostring(settings.order) .. "OA)", reaper.GetCursorPosition(), channels, { master_send = false, track_gain = 0.5 })
  reaper.Undo_EndBlock(TITLE, -1)
  if not item then mc.show_error(err or "Could not insert rendered item.") return end
  mc.print_plan(TITLE, { "Output: " .. output_path, "Master send: off", string.format("NumPy time: %.2f sec", elapsed), log })
end

local env_points, env_enabled = be.init(ENV_DEFS, settings)
be.load_extstate(EXT, ENV_DEFS, env_points, env_enabled)
local selected_env = 1
local selected_env_point = nil
local env_opts = { height = 150, overview_lane_h = 52, random_amount = 0.35, random_count = 10, random_dispersion = 0.25, random_smooth = true, collapse_editor = true, compact_window_h = 760, expanded_window_h = 760 }

local function loop()
  ImGui.SetNextWindowSize(ctx, 760, env_opts._editor_was_open and env_opts.expanded_window_h or env_opts.compact_window_h, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    local control_h = math.max(400, (avail_h or 760) - 44)
    if ImGui.BeginChild(ctx, "##pulsar_controls", 0, control_h) then
      local changed
      selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env, selected_env_point, settings, env_opts)
      ImGui.Separator(ctx)
      local sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Pulsar", 158)
      changed, settings.order = theme.slider_int(ImGui, ctx, "Ambisonic order", math.floor(settings.order), 1, 3)
      changed, settings.duration = theme.slider_double(ImGui, ctx, "Duration sec", settings.duration, 0.25, 120.0, "%.2f")
      changed, settings.streams = theme.slider_int(ImGui, ctx, "Pulsar streams", math.floor(settings.streams), 1, 12)
      settings.curve = combo(ctx, "Train curve", settings.curve, CURVE_LABELS)
      settings.mask = combo(ctx, "Pulse mask", settings.mask, MASK_LABELS)
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)

      sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Spectrum", 180)
      changed, settings.fund_start = theme.slider_double(ImGui, ctx, "Fundamental start Hz", settings.fund_start, 0.25, 250.0, "%.2f")
      changed, settings.fund_end = theme.slider_double(ImGui, ctx, "Fundamental end Hz", settings.fund_end, 0.25, 250.0, "%.2f")
      changed, settings.form_start = theme.slider_double(ImGui, ctx, "Formant start Hz", settings.form_start, 40.0, 8000.0, "%.1f")
      changed, settings.form_end = theme.slider_double(ImGui, ctx, "Formant end Hz", settings.form_end, 40.0, 8000.0, "%.1f")
      changed, settings.formant_scatter = theme.slider_double(ImGui, ctx, "Formant scatter", settings.formant_scatter, 0.0, 1.0, "%.2f")
      changed, settings.drift = theme.slider_double(ImGui, ctx, "Train drift", settings.drift, 0.0, 1.0, "%.2f")
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)

      sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Pulsaret", 180)
      settings.pulsaret = combo(ctx, "Pulsaret", settings.pulsaret, PULSARET_LABELS)
      settings.envelope = combo(ctx, "Pulsaret envelope", settings.envelope, ENV_LABELS)
      changed, settings.edge = theme.slider_double(ImGui, ctx, "Edge / cutoff softness", settings.edge, 0.0, 1.0, "%.2f")
      changed, settings.probability = theme.slider_double(ImGui, ctx, "Stochastic probability", settings.probability, 0.0, 1.0, "%.2f")
      changed, settings.burst_on = theme.slider_int(ImGui, ctx, "Burst on", math.floor(settings.burst_on), 1, 32)
      changed, settings.burst_off = theme.slider_int(ImGui, ctx, "Burst off", math.floor(settings.burst_off), 0, 32)
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)

      sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Spatial / Output", settings.normalize and 246 or 221)
      changed, settings.yaw_start = theme.slider_double(ImGui, ctx, "Azimuth start deg", settings.yaw_start, -180.0, 180.0, "%.1f")
      changed, settings.yaw_end = theme.slider_double(ImGui, ctx, "Azimuth end deg", settings.yaw_end, -180.0, 180.0, "%.1f")
      changed, settings.elevation = theme.slider_double(ImGui, ctx, "Elevation deg", settings.elevation, -89.0, 89.0, "%.1f")
      changed, settings.spatial_spread = theme.slider_double(ImGui, ctx, "Stream spatial spread", settings.spatial_spread, 0.0, 1.0, "%.2f")
      changed, settings.channel_mask = theme.slider_double(ImGui, ctx, "Per-pulse channel mask", settings.channel_mask, 0.0, 1.0, "%.2f")
      changed, settings.gain_db = theme.slider_double(ImGui, ctx, "Pre-gain dB", settings.gain_db, -36.0, 0.0, "%.1f")
      changed, settings.normalize = theme.checkbox_row(ImGui, ctx, "Peak normalize", settings.normalize)
      if settings.normalize then changed, settings.normalize_db = theme.slider_double(ImGui, ctx, "Normalize dB", settings.normalize_db, -24.0, 0.0, "%.1f") end
      changed, settings.seed = theme.input_int_row(ImGui, ctx, "Seed", math.floor(settings.seed))
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)

      ImGui.EndChild(ctx)
    end
    local render_pressed, cancel_pressed = theme.footer_buttons(ImGui, ctx, "RENDER", "CANCEL")
    if render_pressed then should_render = true end
    if cancel_pressed then open = false end
    ImGui.End(ctx)
  end
  persist()
  if should_render then
    open = false
    be.save_extstate(EXT, ENV_DEFS, env_points, env_enabled)
    render(env_points, env_enabled)
    return
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
