-- @description Mass Partial Field
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Offline Synthesis / IR
-- @render Yes; renders a high-density multichannel additive partial field.
-- @method Offline NumPy synthesis that is intentionally heavier than a practical JSFX voice model: thousands of partial events with independent envelopes, frequency drift, and multichannel motion are rendered directly to a new media item.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")
local be = dofile(script_dir .. "Breakpoint Envelope Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Mass Partial Field", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local WINDOW_OPEN_COND = ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver

local EXT = "s3g_mc_mass_partial_field"

local ENV_DEFS = {
  { key = "amplitude", label = "Amplitude", min = 0.0, max = 1.5, default = 1.0, fmt = "%.2f" },
  { key = "density", label = "Density", min = 0.0, max = 1.0, default = 1.0, fmt = "%.2f" },
  { key = "event_ms", label = "Event length", min = 20.0, max = 5000.0, fmt = "%.1f ms" },
  { key = "brightness", label = "Brightness", min = 0.1, max = 3.0, fmt = "%.2f" },
  { key = "drift", label = "Drift", min = 0.0, max = 0.25, fmt = "%.3f" },
  { key = "spatial_width", label = "Spatial width", min = 0.05, max = 6.0, fmt = "%.2f" },
}

local function get_number(key, default)
  local value = tonumber(reaper.GetExtState(EXT, key))
  return value or default
end

local function get_bool(key, default)
  local value = reaper.GetExtState(EXT, key)
  if value == "" then return default end
  return value ~= "0"
end

local function store(settings)
  for key, value in pairs(settings) do
    reaper.SetExtState(EXT, key, type(value) == "boolean" and (value and "1" or "0") or tostring(value), true)
  end
end

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function render(settings, env_points, env_enabled)
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_mass_partial_renders", nil, script_dir)
  local output_path = out_dir .. "/s3g_mass_partial_field_" .. stamp .. "_" .. tostring(settings.channels) .. "ch.wav"
  local manifest = {
    output_path = output_path,
    sample_rate = settings.sample_rate,
    duration = settings.duration,
    channels = settings.channels,
    partials = settings.partials,
    base_freq = settings.base_freq,
    spread_oct = settings.spread_oct,
    density = settings.density,
    event_ms = settings.event_ms,
    drift = settings.drift,
    brightness = settings.brightness,
    spatial_width = settings.spatial_width,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    seed = settings.seed,
  }
  be.add_to_manifest(manifest, ENV_DEFS, env_points, env_enabled)
  local log, elapsed = nr.run_backend(script_dir, "mass_partial", manifest, "Mass Partial Field")
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path,
    "Mass partial field (" .. tostring(settings.channels) .. "ch)", reaper.GetCursorPosition(), settings.channels)
  reaper.Undo_EndBlock("Mass Partial Field", -1)
  if not item then mc.show_error(err or "Could not insert rendered partial field.") return end
  mc.print_plan("Mass Partial Field", {
    "Output: " .. output_path,
    "Duration: " .. tostring(settings.duration) .. " sec",
    "Channels: " .. tostring(settings.channels),
    "NumPy time: " .. string.format("%.2f sec", elapsed),
    log,
  })
end

local function main()
  local settings = {
    sample_rate = get_number("sample_rate", 48000),
    duration = get_number("duration", 12.0),
    channels = get_number("channels", 8),
    partials = get_number("partials", 1200),
    base_freq = get_number("base_freq", 55.0),
    spread_oct = get_number("spread_oct", 4.0),
    density = get_number("density", 1.0),
    event_ms = get_number("event_ms", 450.0),
    drift = get_number("drift", 0.035),
    brightness = get_number("brightness", 1.15),
    spatial_width = get_number("spatial_width", 0.9),
    normalize = get_bool("normalize", true),
    normalize_db = get_number("normalize_db", -6.0),
    seed = get_number("seed", 1),
  }
  local env_points, env_enabled = be.init(ENV_DEFS, settings)
  be.load_extstate(EXT, ENV_DEFS, env_points, env_enabled)
  local ctx = ImGui.CreateContext("Mass Partial Field")
  local open = true
  local should_render = false
  local selected_env = 1
  local selected_env_point = nil
  local env_opts = { height = 150, overview_lane_h = 56, random_amount = 0.35, random_count = 12, random_dispersion = 0.25, random_smooth = false }

  local function loop()
    ImGui.SetNextWindowSize(ctx, 720, 980, WINDOW_OPEN_COND)
    local visible
    visible, open = ImGui.Begin(ctx, "Mass Partial Field", open)
    if visible then
      local changed
      changed, settings.duration = ImGui.SliderDouble(ctx, "Duration sec", settings.duration, 0.5, 300.0, "%.2f")
      changed, settings.channels = ImGui.SliderInt(ctx, "Output channels", math.floor(settings.channels), 1, mc.MAX_REAPER_TRACK_CHANNELS)
      changed, settings.partials = ImGui.SliderInt(ctx, "Partial events", math.floor(settings.partials), 64, 12000)
      changed, settings.density = ImGui.SliderDouble(ctx, "Density", settings.density, 0.0, 1.0, "%.2f")
      changed, settings.base_freq = ImGui.SliderDouble(ctx, "Base frequency", settings.base_freq, 18.0, 440.0, "%.1f")
      changed, settings.spread_oct = ImGui.SliderDouble(ctx, "Frequency spread oct", settings.spread_oct, 0.1, 8.0, "%.2f")
      changed, settings.event_ms = ImGui.SliderDouble(ctx, "Event length ms", settings.event_ms, 20.0, 5000.0, "%.1f")
      changed, settings.drift = ImGui.SliderDouble(ctx, "Frequency drift", settings.drift, 0.0, 0.25, "%.3f")
      changed, settings.brightness = ImGui.SliderDouble(ctx, "Brightness slope", settings.brightness, 0.1, 3.0, "%.2f")
      changed, settings.spatial_width = ImGui.SliderDouble(ctx, "Spatial width", settings.spatial_width, 0.05, 6.0, "%.2f")
      changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -24.0, 0.0, "%.1f")
      end
      changed, settings.seed = ImGui.InputInt(ctx, "Seed", math.floor(settings.seed))
      settings.channels = clamp(math.floor(settings.channels), 1, mc.MAX_REAPER_TRACK_CHANNELS)
      ImGui.Separator(ctx)
      selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env,
        selected_env_point, settings, env_opts)
      if ImGui.Button(ctx, "Render", 96, 28) then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 96, 28) then open = false end
      ImGui.End(ctx)
    end
    if should_render then
      open = false
      store(settings)
      be.save_extstate(EXT, ENV_DEFS, env_points, env_enabled)
      render(settings, env_points, env_enabled)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
