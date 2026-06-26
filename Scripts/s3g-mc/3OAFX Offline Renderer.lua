-- @description 3OAFX Offline Renderer
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spatial / HOA
-- @render Yes; NumPy-backed offline ambisonic decode/process/re-encode render.
-- @method Select one ACN/SN3D ambisonic media item. The renderer decodes 1OA, 2OA, or 3OA to an order-specific virtual speaker layer, applies a moving AED focus with 3OAFX-style dry attenuation, then re-encodes a new ambisonic item.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")
local be = dofile(script_dir .. "Breakpoint Envelope Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "3OAFX Offline Renderer", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local WINDOW_OPEN_COND = ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver
local EXT = "s3g_mc_3oafx_offline_renderer_v1"
local COLOR_WARN = ImGui.ColorConvertDouble4ToU32(1.0, 0.35, 0.22, 1.0)

local ORDER_NAMES = { "1OA / 4ch", "2OA / 9ch", "3OA / 16ch" }
local ORDER_VALUES = { 1, 2, 3 }
local EFFECT_NAMES = {
  "Band-pass region",
  "Comb resonator",
  "Delay region",
  "Diffusion region",
  "Focus gain",
  "Low-pass region",
  "Pitch shift",
  "Ring mod region",
  "Soft saturation",
  "Spectral smear",
  "Tremolo region",
}
local EFFECT_KEYS = {
  "bandpass",
  "comb",
  "delay",
  "diffusion",
  "gain",
  "filter",
  "pitch_shift",
  "ringmod",
  "saturation",
  "spectral_smear",
  "tremolo",
}

local ENV_DEFS = {
  { key = "azimuth", label = "Azimuth", min = -180.0, max = 180.0, default = 0.0, fmt = "%.1f deg" },
  { key = "elevation", label = "Elevation", min = -90.0, max = 90.0, default = 0.0, fmt = "%.1f deg" },
  { key = "focus_width", label = "Focus width", min = 2.0, max = 140.0, default = 38.0, fmt = "%.1f deg" },
  { key = "wet", label = "Wet amount", min = 0.0, max = 2.0, default = 1.0, fmt = "%.2f" },
  { key = "dry_attenuation", label = "Dry attenuation", min = 0.0, max = 1.0, default = 0.18, fmt = "%.2f" },
  { key = "amplitude", label = "Output amp", min = 0.0, max = 1.5, default = 1.0, fmt = "%.2f" },
}

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function get_number(key, default)
  local value = tonumber(reaper.GetExtState(EXT, key))
  return value or default
end

local function set_value(key, value)
  if type(value) == "boolean" then
    reaper.SetExtState(EXT, key, value and "1" or "0", true)
  else
    reaper.SetExtState(EXT, key, tostring(value), true)
  end
end

local function draw_combo(label, index, names)
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
  local order = ORDER_VALUES[order_index] or 3
  return (order + 1) * (order + 1)
end

local function effect_param_label(effect_index)
  local key = EFFECT_KEYS[effect_index]
  if key == "bandpass" then return "Center Hz" end
  if key == "comb" then return "Resonance Hz" end
  if key == "delay" then return "Delay ms" end
  if key == "diffusion" then return "Diffusion ms" end
  if key == "filter" then return "Cutoff Hz" end
  if key == "pitch_shift" then return "Pitch semitones" end
  if key == "ringmod" then return "Ring frequency Hz" end
  if key == "saturation" then return "Drive" end
  if key == "spectral_smear" then return "Smear frames" end
  if key == "tremolo" then return "Tremolo rate Hz" end
  return "Focus gain##effect_param"
end

local function effect_param_range(effect_index)
  local key = EFFECT_KEYS[effect_index]
  if key == "bandpass" then return 60.0, 12000.0, "%.0f" end
  if key == "comb" then return 40.0, 4000.0, "%.0f" end
  if key == "delay" then return 5.0, 900.0, "%.1f" end
  if key == "diffusion" then return 3.0, 80.0, "%.1f" end
  if key == "filter" then return 80.0, 12000.0, "%.0f" end
  if key == "pitch_shift" then return -24.0, 24.0, "%.1f" end
  if key == "ringmod" then return 0.1, 2000.0, "%.1f" end
  if key == "saturation" then return 0.25, 12.0, "%.2f" end
  if key == "spectral_smear" then return 1.0, 48.0, "%.0f" end
  if key == "tremolo" then return 0.05, 30.0, "%.2f" end
  return 0.0, 2.5, "%.2f"
end

local function effect_uses_feedback(effect_index)
  local key = EFFECT_KEYS[effect_index]
  return key == "delay" or key == "comb" or key == "diffusion"
end

local function render(entry, settings, env_points, env_enabled)
  local needed_channels = order_channels(settings.order_index)
  if entry.filename == "" or not nr.file_exists(entry.filename) then
    mc.show_error("The selected source item must be backed by a readable WAV file.")
    return
  end
  if entry.channels < needed_channels then
    mc.show_error("The selected item has " .. tostring(entry.channels) .. " channels, but " ..
      ORDER_NAMES[settings.order_index] .. " needs " .. tostring(needed_channels) .. " channels.")
    return
  end

  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_3oafx_offline_renders", entry.filename, script_dir)
  local output_path = out_dir .. "/s3g_3oafx_offline_" .. stamp .. "_" .. tostring(needed_channels) .. "ch.wav"
  local effect_key = EFFECT_KEYS[settings.effect_index] or "gain"
  local manifest = {
    source_path = entry.filename,
    source_start = entry.start_offset,
    source_duration = entry.length * math.max(0.000001, entry.playrate),
    output_path = output_path,
    sample_rate = nr.source_sample_rate(entry),
    order = ORDER_VALUES[settings.order_index] or 3,
    effect = effect_key,
    azimuth = settings.azimuth,
    elevation = settings.elevation,
    focus_width = settings.focus_width,
    wet = settings.wet,
    dry_attenuation = settings.dry_attenuation,
    amplitude = settings.amplitude,
    effect_gain = settings.effect_gain,
    effect_param = settings.effect_param,
    tremolo_rate = effect_key == "tremolo" and settings.effect_param or settings.tremolo_rate,
    ring_hz = effect_key == "ringmod" and settings.effect_param or settings.ring_hz,
    drive = effect_key == "saturation" and settings.effect_param or settings.drive,
    delay_ms = effect_key == "delay" and settings.effect_param or settings.delay_ms,
    center_hz = effect_key == "bandpass" and settings.effect_param or settings.center_hz,
    reson_hz = effect_key == "comb" and settings.effect_param or settings.reson_hz,
    diffusion_ms = effect_key == "diffusion" and settings.effect_param or settings.diffusion_ms,
    smear_frames = effect_key == "spectral_smear" and settings.effect_param or settings.smear_frames,
    pitch_semitones = effect_key == "pitch_shift" and settings.effect_param or settings.pitch_semitones,
    cutoff_hz = effect_key == "filter" and settings.effect_param or settings.cutoff_hz,
    feedback = settings.feedback,
    damp = settings.damp,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    dc_protect = settings.dc_protect,
    soft_limit = settings.soft_limit,
  }
  be.add_to_manifest(manifest, ENV_DEFS, env_points, env_enabled)

  local log, elapsed = nr.run_backend(script_dir, "foafx_offline", manifest, "3OAFX Offline Renderer")
  if not log then return end

  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path,
    "3OAFX offline " .. tostring(ORDER_VALUES[settings.order_index]) .. "OA", entry.position, needed_channels)
  reaper.Undo_EndBlock("3OAFX Offline Renderer", -1)
  if not item then mc.show_error(err or "Could not insert rendered 3OAFX item.") return end

  mc.print_plan("3OAFX Offline Renderer", {
    "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. "ch)",
    "Order: " .. ORDER_NAMES[settings.order_index],
    "Effect: " .. (EFFECT_NAMES[settings.effect_index] or "Focus gain"),
    "Dry attenuation at focus: " .. string.format("%.2f", settings.dry_attenuation),
    "Output: " .. output_path,
    "NumPy time: " .. string.format("%.2f sec", elapsed),
    log,
  })
end

function main()
  local entries = nr.selected_entries()
  if #entries < 1 then
    mc.show_error("Select one WAV-backed ambisonic media item first.")
    return
  end
  local entry = entries[1]
  local default_order = order_index_for_channels(entry.channels)
  local settings = {
    order_index = clamp(math.floor(get_number("order_index", default_order)), 1, 3),
    effect_index = clamp(math.floor(get_number("effect_index", 1)), 1, #EFFECT_NAMES),
    azimuth = get_number("azimuth", 0.0),
    elevation = get_number("elevation", 0.0),
    focus_width = get_number("focus_width", 38.0),
    wet = get_number("wet", 1.0),
    dry_attenuation = get_number("dry_attenuation", 0.18),
    amplitude = get_number("amplitude", 1.0),
    effect_gain = get_number("effect_gain", 1.0),
    effect_param = get_number("effect_param", 1.0),
    tremolo_rate = get_number("tremolo_rate", 4.0),
    ring_hz = get_number("ring_hz", 90.0),
    drive = get_number("drive", 2.5),
    delay_ms = get_number("delay_ms", 120.0),
    center_hz = get_number("center_hz", 1200.0),
    reson_hz = get_number("reson_hz", 220.0),
    diffusion_ms = get_number("diffusion_ms", 18.0),
    smear_frames = get_number("smear_frames", 8.0),
    pitch_semitones = get_number("pitch_semitones", 7.0),
    cutoff_hz = get_number("cutoff_hz", 1400.0),
    feedback = get_number("feedback", 0.28),
    damp = get_number("damp", 0.45),
    normalize = reaper.GetExtState(EXT, "normalize") ~= "0",
    normalize_db = get_number("normalize_db", -6.0),
    dc_protect = reaper.GetExtState(EXT, "dc_protect") ~= "0",
    soft_limit = reaper.GetExtState(EXT, "soft_limit") ~= "0",
  }
  local env_points, env_enabled = be.init(ENV_DEFS, settings)
  be.load_extstate(EXT, ENV_DEFS, env_points, env_enabled)

  ctx = ImGui.CreateContext("3OAFX Offline Renderer")
  local open = true
  local should_render = false
  local selected_env = 1
  local selected_env_point = nil
  local env_opts = { height = 150, overview_lane_h = 54, random_amount = 0.28, random_count = 10, random_dispersion = 0.25, random_smooth = true }

  local function loop()
    ImGui.SetNextWindowSize(ctx, 760, 900, WINDOW_OPEN_COND)
    local visible
    visible, open = ImGui.Begin(ctx, "3OAFX Offline Renderer", open)
    if visible then
      ImGui.Text(ctx, "Source: " .. entry.name .. "  (" .. tostring(entry.channels) .. " ch)")
      ImGui.Text(ctx, "Input convention: ACN/SN3D ambisonics")
      settings.order_index = draw_combo("Ambisonic order", settings.order_index, ORDER_NAMES)
      local needed = order_channels(settings.order_index)
      if entry.channels < needed then
        ImGui.TextColored(ctx, COLOR_WARN, "Selected item does not have enough channels for this order.")
      end
      settings.effect_index = draw_combo("Effect region", settings.effect_index, EFFECT_NAMES)
      local changed
      changed, settings.azimuth = ImGui.SliderDouble(ctx, "Azimuth", settings.azimuth, -180.0, 180.0, "%.1f deg")
      changed, settings.elevation = ImGui.SliderDouble(ctx, "Elevation", settings.elevation, -90.0, 90.0, "%.1f deg")
      changed, settings.focus_width = ImGui.SliderDouble(ctx, "Focus width", settings.focus_width, 2.0, 140.0, "%.1f deg")
      changed, settings.wet = ImGui.SliderDouble(ctx, "Wet amount", settings.wet, 0.0, 2.0, "%.2f")
      changed, settings.dry_attenuation = ImGui.SliderDouble(ctx, "Dry attenuation at focus", settings.dry_attenuation, 0.0, 1.0, "%.2f")
      changed, settings.amplitude = ImGui.SliderDouble(ctx, "Output amp", settings.amplitude, 0.0, 1.5, "%.2f")
      changed, settings.effect_gain = ImGui.SliderDouble(ctx, "Effect amount / gain", settings.effect_gain, 0.0, 2.5, "%.2f")
      local pmin, pmax, pfmt = effect_param_range(settings.effect_index)
      settings.effect_param = clamp(settings.effect_param, pmin, pmax)
      changed, settings.effect_param = ImGui.SliderDouble(ctx, effect_param_label(settings.effect_index), settings.effect_param, pmin, pmax, pfmt)
      if effect_uses_feedback(settings.effect_index) then
        changed, settings.feedback = ImGui.SliderDouble(ctx, "Feedback", settings.feedback, 0.0, 0.92, "%.2f")
        changed, settings.damp = ImGui.SliderDouble(ctx, "Damping / smoothing", settings.damp, 0.0, 0.98, "%.2f")
      end
      changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -36.0, -1.0, "%.1f")
      end
      changed, settings.dc_protect = ImGui.Checkbox(ctx, "DC protect", settings.dc_protect)
      ImGui.SameLine(ctx)
      changed, settings.soft_limit = ImGui.Checkbox(ctx, "Soft limit", settings.soft_limit)
      ImGui.Separator(ctx)
      ImGui.Text(ctx, "Dry attenuation is always part of the render: the focus region ducks the dry decode before the effected region is re-encoded.")
      selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env,
        selected_env_point, settings, env_opts)
      if ImGui.Button(ctx, "Render", 96, 28) then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 96, 28) then open = false end
      ImGui.End(ctx)
    end

    if should_render then
      open = false
      for key, value in pairs(settings) do set_value(key, value) end
      be.save_extstate(EXT, ENV_DEFS, env_points, env_enabled)
      render(entry, settings, env_points, env_enabled)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
