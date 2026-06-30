-- @description Resonant Terrain
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Offline Synthesis / IR
-- @render Yes; renders a multichannel field of struck resonators.
-- @method Offline NumPy synthesis for sparse excitation events ringing inharmonic resonator banks across channels. Designed for dense, polished multichannel resonant material that would be awkward as a realtime JSFX voice model.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")
local be = dofile(script_dir .. "Breakpoint Envelope Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Resonant Terrain", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local WINDOW_OPEN_COND = ImGui.Cond_Appearing

local EXT = "s3g_mc_resonant_terrain_v2"

local ENV_DEFS = {
  { key = "amplitude", label = "Amplitude", min = 0.0, max = 1.5, default = 1.0, fmt = "%.2f" },
  { key = "density", label = "Density", min = 0.0, max = 1.0, default = 1.0, fmt = "%.2f" },
  { key = "decay_ms", label = "Decay", min = 20.0, max = 8000.0, fmt = "%.1f ms" },
  { key = "roughness", label = "Roughness", min = 0.0, max = 1.0, fmt = "%.2f" },
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
  local out_dir = nr.output_dir("s3g_resonant_terrain_renders", nil, script_dir)
  local output_path = out_dir .. "/s3g_resonant_terrain_" .. stamp .. "_" .. tostring(settings.channels) .. "ch.wav"
  local manifest = {
    output_path = output_path,
    sample_rate = settings.sample_rate,
    duration = settings.duration,
    channels = settings.channels,
    events = settings.events,
    density = settings.density,
    resonators = settings.resonators,
    base_freq = settings.base_freq,
    spread_oct = settings.spread_oct,
    decay_ms = settings.decay_ms,
    strike_ms = settings.strike_ms,
    inharmonic = settings.inharmonic,
    roughness = settings.roughness,
    feedback = settings.feedback,
    spatial_width = settings.spatial_width,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    seed = settings.seed,
  }
  be.add_to_manifest(manifest, ENV_DEFS, env_points, env_enabled)
  local log, elapsed = nr.run_backend(script_dir, "resonant_terrain", manifest, "Resonant Terrain")
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path,
    "Resonant terrain (" .. tostring(settings.channels) .. "ch)", reaper.GetCursorPosition(), settings.channels,
    { track_gain = settings.insert_gain })
  reaper.Undo_EndBlock("Resonant Terrain", -1)
  if not item then mc.show_error(err or "Could not insert rendered resonant terrain.") return end
  mc.print_plan("Resonant Terrain", {
    "Output: " .. output_path,
    "Duration: " .. tostring(settings.duration) .. " sec",
    "Channels: " .. tostring(settings.channels),
    "Inserted track gain: " .. string.format("%.1f dB", 20 * math.log(settings.insert_gain, 10)),
    "NumPy time: " .. string.format("%.2f sec", elapsed),
    log,
  })
end

local function main()
  local settings = {
    sample_rate = get_number("sample_rate", 48000),
    duration = get_number("duration", 8.0),
    channels = get_number("channels", 8),
    events = get_number("events", 80),
    density = get_number("density", 1.0),
    resonators = get_number("resonators", 32),
    base_freq = get_number("base_freq", 72.0),
    spread_oct = get_number("spread_oct", 3.5),
    decay_ms = get_number("decay_ms", 520.0),
    strike_ms = get_number("strike_ms", 4.0),
    inharmonic = get_number("inharmonic", 0.55),
    roughness = get_number("roughness", 0.35),
    feedback = get_number("feedback", 0.18),
    spatial_width = get_number("spatial_width", 0.42),
    normalize = get_bool("normalize", true),
    normalize_db = get_number("normalize_db", -12.0),
    insert_gain = get_number("insert_gain", 0.25),
    seed = get_number("seed", 1),
  }
  local env_points, env_enabled = be.init(ENV_DEFS, settings)
  be.load_extstate(EXT, ENV_DEFS, env_points, env_enabled)
  local ctx = ImGui.CreateContext("Resonant Terrain")
  local open = true
  local should_render = false
  local selected_env = 1
  local selected_env_point = nil
  local env_opts = { height = 150, overview_lane_h = 56, random_amount = 0.35, random_count = 12, random_dispersion = 0.25, random_smooth = false, collapse_editor = true, compact_window_h = 760, expanded_window_h = 760 }

  local function loop()
    ImGui.SetNextWindowSize(ctx, 760, env_opts._editor_was_open and env_opts.expanded_window_h or env_opts.compact_window_h, ImGui.Cond_Always)
    local visible
    visible, open = ImGui.Begin(ctx, "Resonant Terrain", open)
    if visible then
      local _, avail_h = ImGui.GetContentRegionAvail(ctx)
      local control_h = math.max(260, (avail_h or env_opts.compact_window_h) - 44)
      if ImGui.BeginChild(ctx, "##resonant_terrain_controls", 0, control_h) then
      local changed
      changed, settings.duration = ImGui.SliderDouble(ctx, "Duration sec", settings.duration, 0.5, 300.0, "%.2f")
      changed, settings.channels = ImGui.SliderInt(ctx, "Output channels", math.floor(settings.channels), 1, mc.MAX_REAPER_TRACK_CHANNELS)
      changed, settings.events = ImGui.SliderInt(ctx, "Excitation events", math.floor(settings.events), 4, 2000)
      changed, settings.density = ImGui.SliderDouble(ctx, "Density", settings.density, 0.0, 1.0, "%.2f")
      changed, settings.resonators = ImGui.SliderInt(ctx, "Resonators", math.floor(settings.resonators), 4, 256)
      changed, settings.base_freq = ImGui.SliderDouble(ctx, "Base frequency", settings.base_freq, 18.0, 440.0, "%.1f")
      changed, settings.spread_oct = ImGui.SliderDouble(ctx, "Frequency spread oct", settings.spread_oct, 0.1, 8.0, "%.2f")
      changed, settings.decay_ms = ImGui.SliderDouble(ctx, "Decay ms", settings.decay_ms, 20.0, 8000.0, "%.1f")
      changed, settings.strike_ms = ImGui.SliderDouble(ctx, "Strike ms", settings.strike_ms, 0.2, 80.0, "%.1f")
      changed, settings.inharmonic = ImGui.SliderDouble(ctx, "Inharmonicity", settings.inharmonic, 0.0, 1.0, "%.2f")
      changed, settings.roughness = ImGui.SliderDouble(ctx, "Roughness", settings.roughness, 0.0, 1.0, "%.2f")
      changed, settings.feedback = ImGui.SliderDouble(ctx, "Resonator doubling", settings.feedback, 0.0, 1.0, "%.2f")
      changed, settings.spatial_width = ImGui.SliderDouble(ctx, "Spatial width", settings.spatial_width, 0.05, 6.0, "%.2f")
      changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -36.0, -3.0, "%.1f")
      end
      changed, settings.insert_gain = ImGui.SliderDouble(ctx, "Inserted track gain", settings.insert_gain, 0.05, 1.0, "%.2f")
      changed, settings.seed = ImGui.InputInt(ctx, "Seed", math.floor(settings.seed))
      settings.channels = clamp(math.floor(settings.channels), 1, mc.MAX_REAPER_TRACK_CHANNELS)
      ImGui.Separator(ctx)
      selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env,
        selected_env_point, settings, env_opts)
        ImGui.EndChild(ctx)
      end
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
