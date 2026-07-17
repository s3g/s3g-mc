-- @description 3OAFX Particle Cloud
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline ambisonic particle-cloud render.
-- @method Select one or more WAV-backed media items. Ambisonic sources are processed coherently across encoded channels; non-ambisonic sources can be placed onto the 3OAFX directional layer before rendering. Breakpoint curves can vary amplitude, density, grain duration, playback rate, scan position, yaw, and higher-order blur.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")
local be = dofile(script_dir .. "Breakpoint Envelope Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "3OAFX Particle Cloud", 0) return end
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


local TITLE = "3OAFX Particle Cloud"
local EXT = "s3g_mc_foafx_particle_cloud_v1"
local SOURCE_KEYS = { "auto", "ambisonic", "non_ambisonic" }
local SOURCE_LABELS = { "Auto by channel count", "Force ambisonic", "Force non-ambisonic objects" }
local POOL_KEYS = { "first", "cycle", "random", "stream_per_file" }
local POOL_LABELS = { "First selected item", "Cycle selected items", "Random item per grain", "One file per stream" }
local ENV_DEFS = {
  { key = "amplitude", label = "Amplitude", min = 0.0, max = 1.5, default = 1.0, fmt = "%.2f" },
  { key = "density", label = "Grain rate", min = 0.5, max = 240.0, default = 48.0, fmt = "%.1f" },
  { key = "grain_ms", label = "Grain duration", min = 4.0, max = 1000.0, default = 90.0, fmt = "%.1f ms" },
  { key = "playback_rate", label = "Playback rate", min = -4.0, max = 4.0, default = 1.0, fmt = "%.3f" },
  { key = "scan", label = "Scan position", min = 0.0, max = 1.0, default = 0.0, fmt = "%.3f" },
  { key = "yaw", label = "Yaw", min = -360.0, max = 360.0, default = 0.0, fmt = "%.1f deg" },
  { key = "order_blur", label = "Order blur", min = 0.0, max = 1.0, default = 0.0, fmt = "%.2f" },
}

local function getn(k, d) return tonumber(reaper.GetExtState(EXT, k)) or d end
local function getb(k, d) local v = reaper.GetExtState(EXT, k); if v == "" then return d end; return v ~= "0" end
local function set(k, v) reaper.SetExtState(EXT, k, type(v) == "boolean" and (v and "1" or "0") or tostring(v), true) end
local function order_for(ch) if ch >= 16 then return 3 elseif ch >= 9 then return 2 else return 1 end end
local function order_channels(order) return (order + 1) * (order + 1) end
local settings
local function combo(ctx, label, idx, names)
  local _, next_idx = theme.combo_row(ImGui, ctx, label, names, idx)
  return next_idx
end


local entries = nr.selected_entries()
local entry = entries[1]
if not entry then mc.show_error("Select one or more WAV-backed media items.") return end

settings = {
  order = math.max(1, math.min(3, math.floor(getn("order", order_for(entry.channels))))),
  duration = getn("duration", entry.length),
  source_format = math.max(1, math.min(#SOURCE_KEYS, math.floor(getn("source_format", 1)))),
  source_pool = math.max(1, math.min(#POOL_KEYS, math.floor(getn("source_pool", 1)))),
  source_spread = getn("source_spread", 0.20),
  stereo_expand = getb("stereo_expand", true),
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
local env_points, env_enabled = be.init(ENV_DEFS, settings)
be.load_extstate(EXT, ENV_DEFS, env_points, env_enabled)
local selected_env = 1
local selected_env_point = nil
local env_opts = { height = 150, overview_lane_h = 50, random_amount = 0.35, random_count = 10, random_dispersion = 0.25, random_smooth = true, collapse_editor = true, compact_window_h = 760, expanded_window_h = 760 }

local function render(env_points_arg, env_enabled_arg)
  local needed = order_channels(settings.order)
  if SOURCE_KEYS[settings.source_format] == "ambisonic" then
    for _, e in ipairs(entries) do
      if e.channels < needed then
        mc.show_error("Selected item '" .. e.name .. "' has " .. tostring(e.channels) .. " channels; selected order needs " .. tostring(needed) .. ".")
        return
      end
    end
  end
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_foafx_particle_cloud_renders", entry.filename, script_dir)
  local output_path = out_dir .. "/s3g_foafx_particle_cloud_" .. stamp .. "_" .. tostring(settings.order) .. "oa.wav"
  local manifest = {
    source_count = #entries,
    sample_rate = nr.source_sample_rate(entry),
    output_path = output_path,
    order = settings.order,
    duration = settings.duration,
    source_format = SOURCE_KEYS[settings.source_format],
    source_pool = POOL_KEYS[settings.source_pool],
    source_spread = settings.source_spread,
    stereo_expand = settings.stereo_expand,
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
  be.add_to_manifest(manifest, ENV_DEFS, env_points_arg, env_enabled_arg)
  for i, e in ipairs(entries) do
    manifest["source_path_" .. tostring(i)] = e.filename
    manifest["source_start_" .. tostring(i)] = e.start_offset
    manifest["source_duration_" .. tostring(i)] = e.length * math.max(0.000001, e.playrate)
  end
  local log, elapsed = nr.run_backend(script_dir, "foafx_particle_cloud", manifest, TITLE)
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path, "3OAFX Particle Cloud (" .. tostring(settings.order) .. "OA)", entry.position, needed, { master_send = false, track_gain = 0.5 })
  reaper.Undo_EndBlock(TITLE, -1)
  if not item then mc.show_error(err or "Could not insert rendered item.") return end
  mc.print_plan(TITLE, { "Sources: " .. tostring(#entries), "Source format: " .. SOURCE_LABELS[settings.source_format], "Source pool: " .. POOL_LABELS[settings.source_pool], "Output: " .. output_path, "Master send: off", string.format("NumPy time: %.2f sec", elapsed), log })
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 760, env_opts._editor_was_open and env_opts.expanded_window_h or env_opts.compact_window_h, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    local control_h = math.max(420, (avail_h or 780) - 44)
    if ImGui.BeginChild(ctx, "##particle_controls", 0, control_h) then
      theme.muted(ImGui, ctx, "Selected sources: " .. tostring(#entries))
      theme.muted(ImGui, ctx, "First: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
      local changed
      selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env, selected_env_point, settings, env_opts)
      ImGui.Separator(ctx)
      local sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Source", 180)
      changed, settings.order = theme.slider_int(ImGui, ctx, "Ambisonic order", math.floor(settings.order), 1, 3)
      changed, settings.duration = theme.slider_double(ImGui, ctx, "Output duration sec", settings.duration, 0.25, 240.0, "%.2f")
      settings.source_format = combo(ctx, "Source format", settings.source_format, SOURCE_LABELS)
      settings.source_pool = combo(ctx, "Source pool", settings.source_pool, POOL_LABELS)
      changed, settings.source_spread = theme.slider_double(ImGui, ctx, "Non-ambisonic source spread", settings.source_spread, 0.0, 1.0, "%.2f")
      changed, settings.stereo_expand = theme.checkbox_row(ImGui, ctx, "Stereo sum/difference expansion", settings.stereo_expand)
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)

      sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Cloud", 136)
      changed, settings.density = theme.slider_double(ImGui, ctx, "Grain rate", settings.density, 0.5, 240.0, "%.1f")
      changed, settings.streams = theme.slider_int(ImGui, ctx, "Streams", math.floor(settings.streams), 1, 16)
      changed, settings.asynchronicity = theme.slider_double(ImGui, ctx, "Asynchronicity", settings.asynchronicity, 0.0, 1.0, "%.2f")
      changed, settings.intermittency = theme.slider_double(ImGui, ctx, "Intermittency", settings.intermittency, 0.0, 0.95, "%.2f")
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)

      sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Grains", 158)
      changed, settings.grain_ms = theme.slider_double(ImGui, ctx, "Grain duration ms", settings.grain_ms, 4.0, 1000.0, "%.1f")
      changed, settings.grain_jitter = theme.slider_double(ImGui, ctx, "Duration jitter", settings.grain_jitter, 0.0, 1.0, "%.2f")
      changed, settings.envelope_shape = theme.slider_double(ImGui, ctx, "Envelope shape", settings.envelope_shape, 0.0, 1.0, "%.2f")
      changed, settings.playback_rate = theme.slider_double(ImGui, ctx, "Playback rate", settings.playback_rate, -4.0, 4.0, "%.3f")
      changed, settings.playback_jitter = theme.slider_double(ImGui, ctx, "Playback jitter oct", settings.playback_jitter, 0.0, 2.0, "%.2f")
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)

      sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Scan", 114)
      changed, settings.scan_begin = theme.slider_double(ImGui, ctx, "Scan begin", settings.scan_begin, 0.0, 1.0, "%.3f")
      changed, settings.scan_range = theme.slider_double(ImGui, ctx, "Scan range", settings.scan_range, -1.0, 1.0, "%.3f")
      changed, settings.scan_speed = theme.slider_double(ImGui, ctx, "Scan speed", settings.scan_speed, -4.0, 4.0, "%.3f")
      theme.finish_section(ImGui, ctx, sx, sy, sh, stack)

      sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Spatial / Output", settings.normalize and 224 or 199)
      changed, settings.yaw_start = theme.slider_double(ImGui, ctx, "Yaw start deg", settings.yaw_start, -360.0, 360.0, "%.1f")
      changed, settings.yaw_end = theme.slider_double(ImGui, ctx, "Yaw end deg", settings.yaw_end, -360.0, 360.0, "%.1f")
      changed, settings.yaw_scatter = theme.slider_double(ImGui, ctx, "Per-grain yaw scatter", settings.yaw_scatter, 0.0, 180.0, "%.1f")
      changed, settings.order_blur = theme.slider_double(ImGui, ctx, "Higher-order blur", settings.order_blur, 0.0, 1.0, "%.2f")
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
