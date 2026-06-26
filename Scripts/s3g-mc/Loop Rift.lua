-- @description Loop Rift
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Multichannel Texture / Montage
-- @render Yes; NumPy-backed render from one selected media item.
-- @method Offline NumPy renderer. Select one or more WAV-backed media items and render source-preserving multichannel loop sections with source-pool routing, graceful dropouts, minimum section lengths, overlap-add fades, channel grouping, and unstable playback-rate motion. Breakpoint curves shape amplitude, section density, section length, rate instability, and fade time.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")
local be = dofile(script_dir .. "Breakpoint Envelope Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Loop Rift", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local WINDOW_OPEN_COND = ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver
local EXT = "s3g_mc_loop_rift_v1"

local ENV_DEFS = {
  { key = "amplitude", label = "Amplitude", min = 0.0, max = 1.5, default = 1.0, fmt = "%.2f" },
  { key = "rift_density", label = "Section density", min = 0.0, max = 6.0, default = 0.8, fmt = "%.2f" },
  { key = "section_ms", label = "Section length", min = 80.0, max = 4000.0, default = 650.0, fmt = "%.1f ms" },
  { key = "rate_instability", label = "Rate instability", min = 0.0, max = 0.18, default = 0.035, fmt = "%.4f" },
  { key = "fade_ms", label = "Fade / duck", min = 5.0, max = 500.0, default = 28.0, fmt = "%.1f ms" },
}

local RATE_MODES = {
  { label = "Deviation", value = "deviation" },
  { label = "Spread", value = "spread" },
  { label = "Ascending", value = "ascending" },
  { label = "Descending", value = "descending" },
  { label = "Random steps", value = "random_steps" },
}

local DISTRIBUTIONS = {
  { label = "Cycle source channels", value = "cycle" },
  { label = "Mono sum to all", value = "mono_sum" },
  { label = "Adjacent pairs", value = "paired" },
  { label = "Mirror source channels", value = "mirror" },
  { label = "Random source per output", value = "random" },
}

local DIRECTION_MODES = {
  { label = "Forward", value = "forward" },
  { label = "Reverse", value = "reverse" },
  { label = "Alternating", value = "alternating" },
  { label = "Random", value = "random" },
}

local PHASE_MODES = {
  { label = "Even phase", value = "even" },
  { label = "Aligned", value = "aligned" },
  { label = "Random phase", value = "random" },
}

local FILL_MODES = {
  { label = "Silence", value = "silence" },
  { label = "Neighbor bleed", value = "neighbor_bleed" },
}

local SOURCE_MODES = {
  { label = "First selected only", value = "first" },
  { label = "Cycle selected items", value = "cycle_items" },
  { label = "Item per channel group", value = "item_per_group" },
  { label = "Random item per channel", value = "random_channel" },
  { label = "Random item per section", value = "random_section" },
  { label = "Layer all selected", value = "layer_all" },
}

local function get_number(key, default)
  local value = tonumber(reaper.GetExtState(EXT, key))
  return value or default
end

local function set_number(key, value)
  reaper.SetExtState(EXT, key, tostring(value), true)
end

local function get_string(key, default)
  local value = reaper.GetExtState(EXT, key)
  if value == "" then return default end
  return value
end

local function set_string(key, value)
  reaper.SetExtState(EXT, key, tostring(value), true)
end

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function combo_from_options(ctx, label, current, options)
  local current_index = 1
  for index, option in ipairs(options) do
    if option.value == current then current_index = index end
  end
  local preview = options[current_index].label
  local changed = false
  if ImGui.BeginCombo(ctx, label, preview) then
    for index, option in ipairs(options) do
      local selected = index == current_index
      if ImGui.Selectable(ctx, option.label, selected) then
        current = option.value
        changed = true
      end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return changed, current
end

local function add_sources_to_manifest(manifest, entries)
  manifest.source_count = #entries
  for index, entry in ipairs(entries) do
    if entry.filename == "" or not nr.file_exists(entry.filename) then
      return false, "Every selected source item must be backed by a readable WAV file."
    end
    local suffix = index == 1 and "" or ("_" .. tostring(index))
    manifest["source_path" .. suffix] = entry.filename
    manifest["source_start" .. suffix] = entry.start_offset
    manifest["source_duration" .. suffix] = entry.length * math.max(0.000001, entry.playrate)
  end
  return true, nil
end

local function render(entries, settings, env_points, env_enabled)
  local entry = entries[1]
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_loop_rift_renders", entry.filename, script_dir)
  local output_path = out_dir .. "/s3g_loop_rift_" .. stamp .. "_" .. tostring(settings.channels) .. "ch.wav"
  local manifest = {
    output_path = output_path,
    sample_rate = nr.source_sample_rate(entry),
    duration = settings.duration,
    channels = settings.channels,
    xfade_ms = settings.xfade_ms,
    xfade_duck = settings.xfade_duck,
    base_rate = settings.base_rate,
    rate_amount = settings.rate_amount,
    rate_mode = settings.rate_mode,
    distribution = settings.distribution,
    source_mode = settings.source_mode,
    phase_mode = settings.phase_mode,
    direction_mode = settings.direction_mode,
    reverse_probability = settings.reverse_probability,
    rift_density = settings.rift_density,
    section_ms = settings.section_ms,
    min_section_ms = settings.min_section_ms,
    rate_instability = settings.rate_instability,
    fade_ms = settings.fade_ms,
    fill_mode = settings.fill_mode,
    group_size = settings.group_size,
    gain = settings.gain,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    seed = settings.seed,
  }
  local ok, err = add_sources_to_manifest(manifest, entries)
  if not ok then mc.show_error(err) return end
  be.add_to_manifest(manifest, ENV_DEFS, env_points, env_enabled)

  local log, elapsed = nr.run_backend(script_dir, "loop_rift", manifest, "Loop Rift")
  if not log then return end

  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path,
    "Loop Rift (" .. tostring(settings.channels) .. "ch)", entry.position, settings.channels)
  reaper.Undo_EndBlock("Loop Rift", -1)
  if not item then mc.show_error(err or "Could not insert rendered loop rift.") return end

  mc.print_plan("Loop Rift", {
    "Sources: " .. tostring(#entries),
    "Output: " .. output_path,
    "Duration: " .. string.format("%.2f sec", settings.duration),
    "Channels: " .. tostring(settings.channels),
    "Section density: " .. string.format("%.2f", settings.rift_density),
    "Source mode: " .. settings.source_mode,
    "Fill mode: " .. settings.fill_mode,
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
    xfade_ms = get_number("xfade_ms", 80.0),
    xfade_duck = get_number("xfade_duck", 0.12),
    base_rate = get_number("base_rate", 1.0),
    rate_amount = get_number("rate_amount", 0.08),
    rate_mode = get_string("rate_mode", "deviation"),
    source_mode = get_string("source_mode", #entries > 1 and "random_section" or "first"),
    distribution = get_string("distribution", entry.channels == 1 and "mono_sum" or "cycle"),
    phase_mode = get_string("phase_mode", "even"),
    direction_mode = get_string("direction_mode", "forward"),
    reverse_probability = get_number("reverse_probability", 0.25),
    rift_density = get_number("rift_density", 0.8),
    section_ms = get_number("section_ms", 650.0),
    min_section_ms = get_number("min_section_ms", 140.0),
    rate_instability = get_number("rate_instability", 0.035),
    fade_ms = get_number("fade_ms", 28.0),
    fill_mode = get_string("fill_mode", "silence"),
    group_size = get_number("group_size", 1),
    gain = get_number("gain", 0.85),
    normalize = reaper.GetExtState(EXT, "normalize") ~= "0",
    normalize_db = get_number("normalize_db", -6.0),
    seed = get_number("seed", 1),
  }
  local env_points, env_enabled = be.init(ENV_DEFS, settings)
  be.load_extstate(EXT, ENV_DEFS, env_points, env_enabled)

  local ctx = ImGui.CreateContext("Loop Rift")
  local open = true
  local should_render = false
  local selected_env = 1
  local selected_env_point = nil
  local env_opts = { height = 150, overview_lane_h = 58, random_amount = 0.35, random_count = 12, random_dispersion = 0.3, random_smooth = false }

  local function loop()
    ImGui.SetNextWindowSize(ctx, 720, 1000, WINDOW_OPEN_COND)
    local visible
    visible, open = ImGui.Begin(ctx, "Loop Rift", open)
    if visible then
      ImGui.Text(ctx, "Sources: " .. tostring(#entries) .. " selected")
      local changed
      if ImGui.CollapsingHeader(ctx, "Render Setup", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        changed, settings.duration = ImGui.SliderDouble(ctx, "Duration sec", settings.duration, 0.25, 1800.0, "%.2f")
        changed, settings.channels = ImGui.SliderInt(ctx, "Output channels", math.floor(settings.channels), 1, mc.MAX_REAPER_TRACK_CHANNELS)
        changed, settings.xfade_ms = ImGui.SliderDouble(ctx, "Loop crossfade ms", settings.xfade_ms, 1.0, 2000.0, "%.1f")
        changed, settings.xfade_duck = ImGui.SliderDouble(ctx, "Seam duck", settings.xfade_duck, 0.0, 0.75, "%.2f")
      end
      if ImGui.CollapsingHeader(ctx, "Rift Sections", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        changed, settings.rift_density = ImGui.SliderDouble(ctx, "Section density", settings.rift_density, 0.0, 6.0, "%.2f")
        changed, settings.section_ms = ImGui.SliderDouble(ctx, "Section length ms", settings.section_ms, 80.0, 4000.0, "%.1f")
        changed, settings.min_section_ms = ImGui.SliderDouble(ctx, "Minimum section ms", settings.min_section_ms, 80.0, 1000.0, "%.1f")
        changed, settings.fade_ms = ImGui.SliderDouble(ctx, "Fade / duck ms", settings.fade_ms, 5.0, 500.0, "%.1f")
      end
      if ImGui.CollapsingHeader(ctx, "Rate And Spatial Drift", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        changed, settings.base_rate = ImGui.SliderDouble(ctx, "Base rate", settings.base_rate, 0.125, 4.0, "%.4f")
        changed, settings.rate_amount = ImGui.SliderDouble(ctx, "Rate spread/deviation", settings.rate_amount, 0.0, 1.0, "%.4f")
        changed, settings.rate_instability = ImGui.SliderDouble(ctx, "Rate instability", settings.rate_instability, 0.0, 0.18, "%.4f")
        changed, settings.group_size = ImGui.SliderInt(ctx, "Channel group size", math.floor(settings.group_size), 1, 32)
        changed, settings.gain = ImGui.SliderDouble(ctx, "Render gain", settings.gain, 0.05, 2.0, "%.2f")
      end
      settings.channels = clamp(math.floor(settings.channels), 1, mc.MAX_REAPER_TRACK_CHANNELS)
      settings.group_size = clamp(math.floor(settings.group_size), 1, math.max(1, settings.channels))
      settings.seed = math.floor(settings.seed)
      if ImGui.CollapsingHeader(ctx, "Source And Output Rules", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        changed, settings.rate_mode = combo_from_options(ctx, "Rate mode", settings.rate_mode, RATE_MODES)
        changed, settings.source_mode = combo_from_options(ctx, "Source mode", settings.source_mode, SOURCE_MODES)
        changed, settings.distribution = combo_from_options(ctx, "Source distribution", settings.distribution, DISTRIBUTIONS)
        changed, settings.phase_mode = combo_from_options(ctx, "Loop phase", settings.phase_mode, PHASE_MODES)
        changed, settings.direction_mode = combo_from_options(ctx, "Direction", settings.direction_mode, DIRECTION_MODES)
        if settings.direction_mode == "random" then
          changed, settings.reverse_probability = ImGui.SliderDouble(ctx, "Reverse probability", settings.reverse_probability, 0.0, 1.0, "%.2f")
        end
        changed, settings.fill_mode = combo_from_options(ctx, "Gap fill", settings.fill_mode, FILL_MODES)
      end
      if ImGui.CollapsingHeader(ctx, "Output", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
        if settings.normalize then
          changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -36.0, -1.0, "%.1f")
        end
        changed, settings.seed = ImGui.InputInt(ctx, "Seed", math.floor(settings.seed))
      end
      ImGui.Separator(ctx)
      if ImGui.CollapsingHeader(ctx, "Breakpoint Envelopes", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env,
          selected_env_point, settings, env_opts)
      end
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
        elseif type(value) == "number" then
          set_number(key, value)
        else
          set_string(key, value)
        end
      end
      be.save_extstate(EXT, ENV_DEFS, env_points, env_enabled)
      render(entries, settings, env_points, env_enabled)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
