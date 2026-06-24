-- @description Dense Grain Cloud
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Offline Synthesis / IR
-- @render Yes; renders a dense multichannel grain cloud from the selected media item.
-- @method Offline NumPy grain renderer. Select one WAV-backed media item, choose duration, channel count, grain count, grain size, pitch scatter, and spatial spread; the action writes a new multichannel media item.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")
local be = dofile(script_dir .. "Breakpoint Envelope Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Dense Grain Cloud", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local WINDOW_OPEN_COND = ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver

local EXT = "s3g_mc_dense_grain_cloud"

local ENV_DEFS = {
  { key = "amplitude", label = "Amplitude", min = 0.0, max = 1.5, default = 1.0, fmt = "%.2f" },
  { key = "density", label = "Density", min = 0.0, max = 1.0, default = 1.0, fmt = "%.2f" },
  { key = "spread", label = "Spatial spread", min = 0.02, max = 6.0, fmt = "%.2f" },
  { key = "pitch_scatter", label = "Pitch scatter", min = 0.0, max = 2.0, fmt = "%.2f oct" },
}

local function get_number(key, default)
  local value = tonumber(reaper.GetExtState(EXT, key))
  return value or default
end

local function set_number(key, value)
  reaper.SetExtState(EXT, key, tostring(value), true)
end

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function render(entry, settings, env_points, env_enabled)
  if entry.filename == "" or not nr.file_exists(entry.filename) then
    mc.show_error("The selected source item must be backed by a readable WAV file.")
    return
  end
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_grain_cloud_renders", entry.filename, script_dir)
  local output_path = out_dir .. "/s3g_dense_grain_cloud_" .. stamp .. "_" .. tostring(settings.channels) .. "ch.wav"
  local manifest = {
    source_path = entry.filename,
    source_start = entry.start_offset,
    source_duration = entry.length * math.max(0.000001, entry.playrate),
    output_path = output_path,
    sample_rate = nr.source_sample_rate(entry),
    duration = settings.duration,
    channels = settings.channels,
    grains = settings.grains,
    grain_ms = settings.grain_ms,
    grain_jitter = settings.grain_jitter,
    density = settings.density,
    pitch_scatter = settings.pitch_scatter,
    spread = settings.spread,
    channel_contrast = settings.channel_contrast,
    source_bias = settings.source_bias,
    density_shape = settings.density_shape,
    gain = settings.gain,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    seed = settings.seed,
  }
  be.add_to_manifest(manifest, ENV_DEFS, env_points, env_enabled)

  local log, elapsed = nr.run_backend(script_dir, "dense_grain", manifest, "Dense Grain Cloud")
  if not log then return end

  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path,
    "Dense grain cloud (" .. tostring(settings.channels) .. "ch)", entry.position, settings.channels)
  reaper.Undo_EndBlock("Dense Grain Cloud", -1)
  if not item then mc.show_error(err or "Could not insert rendered grain cloud.") return end

  mc.print_plan("Dense Grain Cloud", {
    "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. "ch)",
    "Output: " .. output_path,
    "Duration: " .. tostring(settings.duration) .. " sec",
    "Channels: " .. tostring(settings.channels),
    "NumPy time: " .. string.format("%.2f sec", elapsed),
    log,
  })
end

local function main()
  local entries = nr.selected_entries()
  if #entries < 1 then
    mc.show_error("Select one WAV-backed audio media item first.")
    return
  end
  local entry = entries[1]
  local settings = {
    duration = get_number("duration", math.max(1.0, entry.length)),
    channels = get_number("channels", math.max(2, entry.channels)),
    grains = get_number("grains", 2400),
    grain_ms = get_number("grain_ms", 80),
    grain_jitter = get_number("grain_jitter", 0.55),
    density = get_number("density", 1.0),
    pitch_scatter = get_number("pitch_scatter", 0.35),
    spread = get_number("spread", 0.28),
    channel_contrast = get_number("channel_contrast", 0.75),
    source_bias = get_number("source_bias", 0.55),
    density_shape = get_number("density_shape", 0.0),
    gain = get_number("gain", 1.0),
    normalize = reaper.GetExtState(EXT, "normalize") ~= "0",
    normalize_db = get_number("normalize_db", -6.0),
    seed = get_number("seed", 1),
  }
  local env_points, env_enabled = be.init(ENV_DEFS, settings)
  be.load_extstate(EXT, ENV_DEFS, env_points, env_enabled)

  local ctx = ImGui.CreateContext("Dense Grain Cloud")
  local open = true
  local should_render = false
  local selected_env = 1
  local selected_env_point = nil
  local env_opts = { height = 150, overview_lane_h = 56, random_amount = 0.35, random_count = 12, random_dispersion = 0.25, random_smooth = false }

  local function loop()
    ImGui.SetNextWindowSize(ctx, 720, 920, WINDOW_OPEN_COND)
    local visible
    visible, open = ImGui.Begin(ctx, "Dense Grain Cloud", open)
    if visible then
      ImGui.Text(ctx, "Source: " .. entry.name .. "  (" .. tostring(entry.channels) .. " ch)")
      local changed
      changed, settings.duration = ImGui.SliderDouble(ctx, "Duration sec", settings.duration, 0.25, 300.0, "%.2f")
      changed, settings.channels = ImGui.SliderInt(ctx, "Output channels", math.floor(settings.channels), 1, mc.MAX_REAPER_TRACK_CHANNELS)
      changed, settings.grains = ImGui.SliderInt(ctx, "Grains", math.floor(settings.grains), 64, 20000)
      changed, settings.density = ImGui.SliderDouble(ctx, "Density", settings.density, 0.0, 1.0, "%.2f")
      changed, settings.grain_ms = ImGui.SliderDouble(ctx, "Grain ms", settings.grain_ms, 4.0, 800.0, "%.1f")
      changed, settings.grain_jitter = ImGui.SliderDouble(ctx, "Length variation", settings.grain_jitter, 0.0, 0.95, "%.2f")
      changed, settings.pitch_scatter = ImGui.SliderDouble(ctx, "Pitch scatter oct", settings.pitch_scatter, 0.0, 2.0, "%.2f")
      changed, settings.spread = ImGui.SliderDouble(ctx, "Spatial spread", settings.spread, 0.02, 6.0, "%.2f")
      changed, settings.channel_contrast = ImGui.SliderDouble(ctx, "Channel contrast", settings.channel_contrast, 0.0, 1.0, "%.2f")
      changed, settings.source_bias = ImGui.SliderDouble(ctx, "Source bias by channel", settings.source_bias, 0.0, 1.0, "%.2f")
      changed, settings.density_shape = ImGui.SliderDouble(ctx, "Density shape", settings.density_shape, -1.0, 1.0, "%.2f")
      changed, settings.gain = ImGui.SliderDouble(ctx, "Cloud gain", settings.gain, 0.05, 4.0, "%.2f")
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
      for key, value in pairs(settings) do
        if type(value) == "boolean" then
          reaper.SetExtState(EXT, key, value and "1" or "0", true)
        else
          set_number(key, value)
        end
      end
      be.save_extstate(EXT, ENV_DEFS, env_points, env_enabled)
      render(entry, settings, env_points, env_enabled)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
