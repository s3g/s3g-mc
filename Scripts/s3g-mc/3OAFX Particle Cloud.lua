-- @description 3OAFX Particle Cloud
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline ambisonic particle-cloud render.
-- @method Select one or more WAV-backed media items. Ambisonic sources are processed coherently across encoded channels; non-ambisonic sources can be placed onto the 3OAFX directional layer before rendering. A diagram previews source flow, grain cloud behavior, and ambisonic output. Breakpoint curves can vary amplitude, density, grain duration, playback rate, scan position, yaw, and higher-order blur.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")
local be = dofile(script_dir .. "Breakpoint Envelope Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "3OAFX Particle Cloud", 0) return end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

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
local function rgba(r, g, b, a) return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1) end
local settings
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

local function draw_diagram(ctx, source_entries)
  local w = math.max(420, ImGui.GetContentRegionAvail(ctx) - 2)
  local h = 136
  ImGui.InvisibleButton(ctx, "##particle_diagram", w, h)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = ImGui.GetItemRectMax(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local c_bg = rgba(0.035, 0.038, 0.040, 1)
  local c_grid = rgba(0.55, 0.60, 0.58, 0.11)
  local c_text = rgba(0.76, 0.79, 0.76, 1)
  local c_dim = rgba(0.54, 0.58, 0.56, 1)
  local c_a = rgba(0.98, 0.74, 0.25, 1)
  local c_b = rgba(0.34, 0.72, 0.86, 1)
  local c_c = rgba(0.80, 0.62, 0.95, 1)
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x1, y1, c_bg)
  ImGui.DrawList_AddRect(dl, x0, y0, x1, y1, rgba(0.45, 0.50, 0.48, 0.38), 0, 0, 1)
  for i = 1, 5 do
    local gx = x0 + w * i / 6
    ImGui.DrawList_AddLine(dl, gx, y0 + 12, gx, y1 - 12, c_grid, 1)
  end
  local left = x0 + 24
  local midx = x0 + w * 0.50
  local right = x0 + w * 0.80
  local cy = y0 + h * 0.55
  ImGui.DrawList_AddText(dl, left, y0 + 10, c_text, "selected media")
  ImGui.DrawList_AddText(dl, midx - 48, y0 + 10, c_text, "grain cloud")
  ImGui.DrawList_AddText(dl, right - 42, y0 + 10, c_text, tostring(settings.order) .. "OA")
  for i = 1, math.min(5, #source_entries) do
    local yy = y0 + 38 + (i - 1) * 13
    ImGui.DrawList_AddRect(dl, left, yy, left + 106, yy + 8, c_dim, 0, 0, 1)
    ImGui.DrawList_AddLine(dl, left + 112, yy + 4, midx - 62, cy + math.sin(i * 1.7) * 28, c_grid, 1.2)
  end
  local dot_count = math.max(16, math.min(58, math.floor(settings.density / 4)))
  for i = 1, dot_count do
    local px = midx - 54 + (i % 8) * 15 + math.sin(i * 2.1) * settings.asynchronicity * 5
    local py = cy - 36 + math.floor((i - 1) / 8) * 11 + math.cos(i * 1.3) * settings.intermittency * 14
    local r = 1.5 + math.min(4.0, settings.grain_ms / 260.0)
    ImGui.DrawList_AddCircleFilled(dl, px, py, r, (i % 3 == 0) and c_b or c_a)
  end
  for i = 1, 3 do ImGui.DrawList_AddCircle(dl, right, cy, 16 + i * 13, c_grid, 0, 1) end
  local yaw = math.rad(settings.yaw_end)
  ImGui.DrawList_AddLine(dl, right, cy, right + math.cos(yaw) * 50, cy - math.sin(yaw) * 50, c_c, 2)
  ImGui.DrawList_AddCircleFilled(dl, right + math.cos(yaw) * 50, cy - math.sin(yaw) * 50, 4, c_c)
  ImGui.DrawList_AddText(dl, left, y1 - 22, c_dim, "sources become coherent grains, then rotate and blur inside the ambisonic field")
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
local env_opts = { height = 150, overview_lane_h = 50, random_amount = 0.35, random_count = 10, random_dispersion = 0.25, random_smooth = true, collapse_editor = true, compact_window_h = 940, expanded_window_h = 1100 }

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
    draw_diagram(ctx, entries)
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    local control_h = math.max(420, (avail_h or 780) - 44)
    if ImGui.BeginChild(ctx, "##particle_controls", 0, control_h) then
    ImGui.Text(ctx, "Selected sources: " .. tostring(#entries))
    ImGui.Text(ctx, "First: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
    local changed
    changed, settings.order = ImGui.SliderInt(ctx, "Ambisonic order", math.floor(settings.order), 1, 3)
    changed, settings.duration = ImGui.SliderDouble(ctx, "Output duration sec", settings.duration, 0.25, 240.0, "%.2f")
    settings.source_format = combo(ctx, "Source format", settings.source_format, SOURCE_LABELS)
    settings.source_pool = combo(ctx, "Source pool", settings.source_pool, POOL_LABELS)
    changed, settings.source_spread = ImGui.SliderDouble(ctx, "Non-ambisonic source spread", settings.source_spread, 0.0, 1.0, "%.2f")
    changed, settings.stereo_expand = ImGui.Checkbox(ctx, "Stereo sum/difference expansion", settings.stereo_expand)
    ImGui.Separator(ctx)
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
    selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env, selected_env_point, settings, env_opts)
      ImGui.EndChild(ctx)
    end
    if ImGui.Button(ctx, "Render", 96, 28) then should_render = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 96, 28) then open = false end
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
