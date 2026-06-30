-- @description 3OAFX AED Granulator
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline 3OA object-grain render.
-- @method Select one WAV-backed mono, stereo, or multichannel media item. Grains are read from source channels as object signals, assigned generated AED positions, and encoded directly to 3OA ACN/SN3D output. The engine adapts triggered voice-rotation, spray, pitch spread, reverse chance, quantized source position, window morph, and drive ideas into an offline ambisonic object-grain renderer.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")
local be = dofile(script_dir .. "Breakpoint Envelope Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "3OAFX AED Granulator", 0) return end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "3OAFX AED Granulator"
local EXT = "s3g_mc_foafx_aed_granulator_v1"
local TRAJECTORIES = { "braid", "orbit", "ribbon", "lattice", "spray" }
local TRAJECTORY_LABELS = { "AED braid", "Orbit", "Ribbon", "Lattice", "Spray" }
local SOURCE_MODES = { "cycle", "random", "position", "braid" }
local SOURCE_MODE_LABELS = { "Cycle channels", "Random channel", "Position follows channel", "Channel braid" }
local ENV_DEFS = {
  { key = "amplitude", label = "Amplitude", min = 0.0, max = 1.5, default = 1.0, fmt = "%.2f" },
  { key = "density", label = "Density", min = 0.5, max = 240.0, default = 36.0, fmt = "%.1f" },
  { key = "chance", label = "Chance", min = 0.0, max = 1.0, default = 1.0, fmt = "%.2f" },
  { key = "grain_ms", label = "Grain duration", min = 4.0, max = 1000.0, default = 90.0, fmt = "%.1f ms" },
  { key = "source_position", label = "Source position", min = 0.0, max = 1.0, default = 0.0, fmt = "%.3f" },
  { key = "transpose_semi", label = "Transpose", min = -36.0, max = 36.0, default = 0.0, fmt = "%.1f st" },
  { key = "azimuth", label = "Azimuth", min = -180.0, max = 180.0, default = 0.0, fmt = "%.1f deg" },
  { key = "elevation", label = "Elevation", min = -89.0, max = 89.0, default = 0.0, fmt = "%.1f deg" },
}

local function getn(k, d) return tonumber(reaper.GetExtState(EXT, k)) or d end
local function getb(k, d) local v = reaper.GetExtState(EXT, k); if v == "" then return d end; return v ~= "0" end
local function set(k, v) reaper.SetExtState(EXT, k, type(v) == "boolean" and (v and "1" or "0") or tostring(v), true) end
local function rgba(r, g, b, a) return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1) end
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

local entries = nr.selected_entries()
local entry = entries[1]
if not entry then mc.show_error("Select one WAV-backed media item.") return end

local settings = {
  duration = getn("duration", entry.length),
  trajectory = math.max(1, math.min(#TRAJECTORIES, math.floor(getn("trajectory", 1)))),
  source_mode = math.max(1, math.min(#SOURCE_MODES, math.floor(getn("source_mode", 1)))),
  density = getn("density", 36.0),
  chance = getn("chance", 1.0),
  voices = math.max(1, math.min(32, math.floor(getn("voices", 8)))),
  grain_ms = getn("grain_ms", 90.0),
  min_ms = getn("min_ms", 4.0),
  grain_jitter = getn("grain_jitter", 0.35),
  spray_ms = getn("spray_ms", 120.0),
  source_position = getn("source_position", 0.0),
  position_quantize = math.max(0, math.floor(getn("position_quantize", 0))),
  transpose_semi = getn("transpose_semi", 0.0),
  pitch_spread_semi = getn("pitch_spread_semi", 4.0),
  reverse_probability = getn("reverse_probability", 0.08),
  window_shape = getn("window_shape", 0.25),
  drift = getn("drift", 0.002),
  az_center = getn("az_center", 0.0),
  az_width = getn("az_width", 160.0),
  el_center = getn("el_center", 0.0),
  el_width = getn("el_width", 45.0),
  distance = getn("distance", 1.0),
  distance_depth = getn("distance_depth", 0.35),
  trim = getn("trim", 1.0),
  drive = getn("drive", 0.18),
  gain_db = getn("gain_db", -9.0),
  normalize = getb("normalize", true),
  normalize_db = getn("normalize_db", -6.0),
  seed = math.floor(getn("seed", 1)),
}

local function draw_diagram(ctx)
  local w = math.max(420, ImGui.GetContentRegionAvail(ctx) - 2)
  local h = 150
  ImGui.InvisibleButton(ctx, "##aed_granulator_diagram", w, h)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = ImGui.GetItemRectMax(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local c_bg = rgba(0.035, 0.038, 0.040, 1)
  local c_grid = rgba(0.55, 0.60, 0.58, 0.12)
  local c_text = rgba(0.76, 0.79, 0.76, 1)
  local c_dim = rgba(0.54, 0.58, 0.56, 1)
  local c_a = rgba(0.98, 0.74, 0.25, 1)
  local c_b = rgba(0.34, 0.72, 0.86, 1)
  local c_c = rgba(0.80, 0.62, 0.95, 1)
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x1, y1, c_bg)
  ImGui.DrawList_AddRect(dl, x0, y0, x1, y1, rgba(0.45, 0.50, 0.48, 0.38), 0, 0, 1)
  local left = x0 + 24
  local cx = x0 + w * 0.62
  local cy = y0 + h * 0.56
  ImGui.DrawList_AddText(dl, left, y0 + 10, c_text, "source channels")
  ImGui.DrawList_AddText(dl, x0 + w * 0.36, y0 + 10, c_text, "voice grains")
  ImGui.DrawList_AddText(dl, cx - 34, y0 + 10, c_text, "AED / 3OA")
  for ch = 1, math.min(8, entry.channels) do
    local yy = y0 + 36 + (ch - 1) * 10
    ImGui.DrawList_AddRect(dl, left, yy, left + 102, yy + 6, c_dim, 0, 0, 1)
    ImGui.DrawList_AddLine(dl, left + 108, yy + 3, x0 + w * 0.36, y0 + 34 + ((ch * 17) % 72), c_grid, 1)
  end
  for v = 1, math.min(16, settings.voices) do
    local px = x0 + w * 0.34 + (v % 4) * 20
    local py = y0 + 44 + math.floor((v - 1) / 4) * 14
    ImGui.DrawList_AddCircleFilled(dl, px, py, 3.0 + settings.window_shape * 2.0, (v % 2 == 0) and c_a or c_b)
    ImGui.DrawList_AddLine(dl, px + 8, py, cx - 58, cy + math.sin(v) * 42, c_grid, 1)
  end
  for i = 1, 3 do ImGui.DrawList_AddCircle(dl, cx, cy, 18 + i * 16, c_grid, 0, 1) end
  local spread = math.rad(settings.az_width)
  local center = math.rad(settings.az_center)
  local a0 = center - spread * 0.5
  local a1 = center + spread * 0.5
  ImGui.DrawList_AddLine(dl, cx, cy, cx + math.cos(a0) * 58, cy - math.sin(a0) * 58, c_c, 2)
  ImGui.DrawList_AddLine(dl, cx, cy, cx + math.cos(a1) * 58, cy - math.sin(a1) * 58, c_a, 2)
  ImGui.DrawList_AddCircleFilled(dl, cx + math.cos(center) * 46, cy - math.sin(center) * 46, 4.5, c_a)
  ImGui.DrawList_AddText(dl, left, y1 - 24, c_dim, "each grain is a mono object with its own generated AED position, then encoded to 3OA")
end

local ctx = ImGui.CreateContext(TITLE)
local open, should_render = true, false
local function persist() for k, v in pairs(settings) do set(k, v) end end
local env_points, env_enabled = be.init(ENV_DEFS, settings)
be.load_extstate(EXT, ENV_DEFS, env_points, env_enabled)
local selected_env = 1
local selected_env_point = nil
local env_opts = { height = 150, overview_lane_h = 50, random_amount = 0.35, random_count = 10, random_dispersion = 0.25, random_smooth = true, collapse_editor = true, compact_window_h = 760, expanded_window_h = 760 }

local function render()
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_foafx_aed_granulator_renders", entry.filename, script_dir)
  local output_path = out_dir .. "/s3g_foafx_aed_granulator_" .. stamp .. "_3oa.wav"
  local manifest = {
    source_path = entry.filename,
    source_start = entry.start_offset,
    source_duration = entry.length * math.max(0.000001, entry.playrate),
    sample_rate = nr.source_sample_rate(entry),
    output_path = output_path,
    duration = settings.duration,
    trajectory = TRAJECTORIES[settings.trajectory],
    source_mode = SOURCE_MODES[settings.source_mode],
    density = settings.density,
    chance = settings.chance,
    voices = settings.voices,
    grain_ms = settings.grain_ms,
    min_ms = settings.min_ms,
    grain_jitter = settings.grain_jitter,
    spray_ms = settings.spray_ms,
    source_position = settings.source_position,
    position_quantize = settings.position_quantize,
    transpose_semi = settings.transpose_semi,
    pitch_spread_semi = settings.pitch_spread_semi,
    reverse_probability = settings.reverse_probability,
    window_shape = settings.window_shape,
    drift = settings.drift,
    az_center = settings.az_center,
    az_width = settings.az_width,
    el_center = settings.el_center,
    el_width = settings.el_width,
    distance = settings.distance,
    distance_depth = settings.distance_depth,
    trim = settings.trim,
    drive = settings.drive,
    gain_db = settings.gain_db,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    seed = settings.seed,
  }
  be.add_to_manifest(manifest, ENV_DEFS, env_points, env_enabled)
  local log, elapsed = nr.run_backend(script_dir, "foafx_aed_granulator", manifest, TITLE)
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path, "3OAFX AED Granulator (3OA)", entry.position, 16, { master_send = false, track_gain = 0.5 })
  reaper.Undo_EndBlock(TITLE, -1)
  if not item then mc.show_error(err or "Could not insert rendered item.") return end
  mc.print_plan(TITLE, { "Source: " .. entry.name, "Trajectory: " .. TRAJECTORY_LABELS[settings.trajectory], "Output: " .. output_path, "Master send: off", string.format("NumPy time: %.2f sec", elapsed), log })
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 760, env_opts._editor_was_open and env_opts.expanded_window_h or env_opts.compact_window_h, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    draw_diagram(ctx)
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    local control_h = math.max(440, (avail_h or 820) - 44)
    if ImGui.BeginChild(ctx, "##aed_granulator_controls", 0, control_h) then
      ImGui.Text(ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
      ImGui.Text(ctx, "Output: 3OA ACN/SN3D (16 ch)")
      settings.trajectory = combo(ctx, "AED trajectory", settings.trajectory, TRAJECTORY_LABELS)
      settings.source_mode = combo(ctx, "Source channel mode", settings.source_mode, SOURCE_MODE_LABELS)
      local changed
      changed, settings.duration = ImGui.SliderDouble(ctx, "Output duration sec", settings.duration, 0.25, 300.0, "%.2f")
      changed, settings.density = ImGui.SliderDouble(ctx, "Trigger density", settings.density, 0.5, 240.0, "%.1f")
      changed, settings.chance = ImGui.SliderDouble(ctx, "Trigger chance", settings.chance, 0.0, 1.0, "%.2f")
      changed, settings.voices = ImGui.SliderInt(ctx, "Voice rotation", math.floor(settings.voices), 1, 32)
      changed, settings.grain_ms = ImGui.SliderDouble(ctx, "Grain duration ms", settings.grain_ms, 4.0, 1000.0, "%.1f")
      changed, settings.min_ms = ImGui.SliderDouble(ctx, "Minimum grain ms", settings.min_ms, 1.0, 80.0, "%.1f")
      changed, settings.grain_jitter = ImGui.SliderDouble(ctx, "Duration variation", settings.grain_jitter, 0.0, 1.0, "%.2f")
      changed, settings.spray_ms = ImGui.SliderDouble(ctx, "Source spray ms", settings.spray_ms, 0.0, 2000.0, "%.1f")
      changed, settings.source_position = ImGui.SliderDouble(ctx, "Source position", settings.source_position, 0.0, 1.0, "%.3f")
      changed, settings.position_quantize = ImGui.SliderInt(ctx, "Position quantize", math.floor(settings.position_quantize), 0, 64)
      ImGui.Separator(ctx)
      changed, settings.transpose_semi = ImGui.SliderDouble(ctx, "Transpose semitones", settings.transpose_semi, -36.0, 36.0, "%.1f")
      changed, settings.pitch_spread_semi = ImGui.SliderDouble(ctx, "Pitch spread semitones", settings.pitch_spread_semi, 0.0, 48.0, "%.1f")
      changed, settings.reverse_probability = ImGui.SliderDouble(ctx, "Reverse chance", settings.reverse_probability, 0.0, 1.0, "%.2f")
      changed, settings.window_shape = ImGui.SliderDouble(ctx, "Window morph", settings.window_shape, 0.0, 1.0, "%.2f")
      changed, settings.drift = ImGui.SliderDouble(ctx, "Rate drift", settings.drift, 0.0, 0.05, "%.4f")
      ImGui.Separator(ctx)
      changed, settings.az_center = ImGui.SliderDouble(ctx, "Azimuth center", settings.az_center, -180.0, 180.0, "%.1f")
      changed, settings.az_width = ImGui.SliderDouble(ctx, "Azimuth width", settings.az_width, 0.0, 360.0, "%.1f")
      changed, settings.el_center = ImGui.SliderDouble(ctx, "Elevation center", settings.el_center, -89.0, 89.0, "%.1f")
      changed, settings.el_width = ImGui.SliderDouble(ctx, "Elevation width", settings.el_width, 0.0, 178.0, "%.1f")
      changed, settings.distance = ImGui.SliderDouble(ctx, "Distance", settings.distance, 0.1, 4.0, "%.2f")
      changed, settings.distance_depth = ImGui.SliderDouble(ctx, "Distance motion", settings.distance_depth, 0.0, 1.0, "%.2f")
      ImGui.Separator(ctx)
      changed, settings.trim = ImGui.SliderDouble(ctx, "Trim", settings.trim, 0.0, 2.0, "%.2f")
      changed, settings.drive = ImGui.SliderDouble(ctx, "Drive", settings.drive, 0.0, 1.0, "%.2f")
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
    render()
    return
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
