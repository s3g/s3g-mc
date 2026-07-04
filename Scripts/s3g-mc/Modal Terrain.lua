-- @description Modal Terrain
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Offline Synthesis / IR
-- @render Yes; renders a modal/resonator-bank terrain as a new media item.
-- @method Offline NumPy synthesis for large modal banks. Internal excitation events strike or swell through hundreds or thousands of resonant modes, distributed as a multichannel ring or encoded directly to 3OA ACN/SN3D.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")
local be = dofile(script_dir .. "Breakpoint Envelope Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Modal Terrain", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "Modal Terrain"
local EXT = "s3g_mc_modal_terrain_v1"
local OUTPUT_LABELS = { "3OA ACN/SN3D", "Multichannel ring" }
local OUTPUT_KEYS = { "3oa", "ring" }
local FREQ_LABELS = { "Inharmonic cloud", "Clustered metals", "Stretched harmonic", "Scale lattice" }
local FREQ_KEYS = { "inharmonic_cloud", "clustered_metals", "stretched_harmonic", "scale_lattice" }
local EXCITER_LABELS = { "Impulse cloud", "Dust", "Swells", "Strata" }
local EXCITER_KEYS = { "impulse_cloud", "dust", "swells", "strata" }
local SPATIAL_LABELS = { "Sphere scatter", "Orbiting bands", "Ring drift" }
local SPATIAL_KEYS = { "sphere_scatter", "orbiting_bands", "ring_drift" }
local PRESET_LABELS = { "Glass cloud", "Bronze strata", "Tuned lattice", "Dust halo", "Slow architecture" }

local ENV_DEFS = {
  { key = "amplitude", label = "Amplitude", min = 0.0, max = 1.5, default = 1.0, fmt = "%.2f" },
  { key = "density", label = "Density", min = 0.0, max = 1.0, default = 1.0, fmt = "%.2f" },
  { key = "motion", label = "Motion", min = 0.0, max = 1.0, default = 0.28, fmt = "%.2f" },
  { key = "spatial_width", label = "Spatial width", min = 0.02, max = 8.0, default = 0.65, fmt = "%.2f" },
}

local COLORS = {
  bg = ImGui.ColorConvertDouble4ToU32(0.035, 0.039, 0.042, 1),
  edge = ImGui.ColorConvertDouble4ToU32(0.34, 0.38, 0.38, 1),
  grid = ImGui.ColorConvertDouble4ToU32(0.55, 0.62, 0.62, 0.16),
  text = ImGui.ColorConvertDouble4ToU32(0.78, 0.83, 0.82, 1),
  muted = ImGui.ColorConvertDouble4ToU32(0.50, 0.56, 0.56, 1),
  cyan = ImGui.ColorConvertDouble4ToU32(0.24, 0.72, 0.86, 0.95),
  amber = ImGui.ColorConvertDouble4ToU32(0.92, 0.67, 0.26, 0.92),
  violet = ImGui.ColorConvertDouble4ToU32(0.62, 0.52, 0.92, 0.70),
}

local function getn(key, default)
  return tonumber(reaper.GetExtState(EXT, key)) or default
end

local function getb(key, default)
  local value = reaper.GetExtState(EXT, key)
  if value == "" then return default end
  return value ~= "0"
end

local function setv(key, value)
  if type(value) == "boolean" then
    reaper.SetExtState(EXT, key, value and "1" or "0", true)
  else
    reaper.SetExtState(EXT, key, tostring(value), true)
  end
end

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local ctx = ImGui.CreateContext(TITLE)

local function combo(label, index, names)
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

local settings = {
  output_mode = math.floor(getn("output_mode", 1)),
  channels = getn("channels", 8),
  duration = getn("duration", 14.0),
  sample_rate = getn("sample_rate", 48000),
  preset = math.floor(getn("preset", 1)),
  frequency_model = math.floor(getn("frequency_model", 1)),
  exciter = math.floor(getn("exciter", 1)),
  spatial_mode = math.floor(getn("spatial_mode", 1)),
  mode_count = getn("mode_count", 768),
  events = getn("events", 260),
  modes_per_event = getn("modes_per_event", 14),
  base_freq = getn("base_freq", 48.0),
  spread_oct = getn("spread_oct", 6.0),
  decay_ms = getn("decay_ms", 2200.0),
  damping_spread = getn("damping_spread", 0.58),
  brightness = getn("brightness", 0.56),
  detune = getn("detune", 0.20),
  density = getn("density", 1.0),
  motion = getn("motion", 0.28),
  spatial_width = getn("spatial_width", 0.65),
  excitation_tone = getn("excitation_tone", 0.42),
  normalize = getb("normalize", true),
  normalize_db = getn("normalize_db", -9.0),
  soft_limit = getb("soft_limit", true),
  insert_gain = getn("insert_gain", 0.5),
  seed = getn("seed", 1),
}

local env_points, env_enabled = be.init(ENV_DEFS, settings)
be.load_extstate(EXT, ENV_DEFS, env_points, env_enabled)
local selected_env = 1
local selected_env_point = nil
local env_opts = { height = 145, overview_lane_h = 52, random_amount = 0.35, random_count = 14, random_dispersion = 0.28, random_smooth = false, collapse_editor = true, compact_window_h = 780, expanded_window_h = 780 }

local function apply_preset(index)
  if index == 2 then
    settings.frequency_model, settings.exciter, settings.spatial_mode = 2, 4, 2
    settings.mode_count, settings.events, settings.modes_per_event = 640, 150, 18
    settings.base_freq, settings.spread_oct, settings.decay_ms = 42.0, 4.5, 3600.0
    settings.brightness, settings.detune, settings.excitation_tone = 0.42, 0.34, 0.28
    settings.motion, settings.spatial_width = 0.22, 0.86
  elseif index == 3 then
    settings.frequency_model, settings.exciter, settings.spatial_mode = 4, 1, 1
    settings.mode_count, settings.events, settings.modes_per_event = 512, 240, 10
    settings.base_freq, settings.spread_oct, settings.decay_ms = 65.0, 5.0, 1700.0
    settings.brightness, settings.detune, settings.excitation_tone = 0.72, 0.05, 0.70
    settings.motion, settings.spatial_width = 0.18, 0.48
  elseif index == 4 then
    settings.frequency_model, settings.exciter, settings.spatial_mode = 1, 2, 3
    settings.mode_count, settings.events, settings.modes_per_event = 1200, 900, 6
    settings.base_freq, settings.spread_oct, settings.decay_ms = 90.0, 7.0, 620.0
    settings.brightness, settings.detune, settings.excitation_tone = 0.92, 0.32, 0.18
    settings.motion, settings.spatial_width = 0.48, 1.2
  elseif index == 5 then
    settings.frequency_model, settings.exciter, settings.spatial_mode = 3, 3, 1
    settings.mode_count, settings.events, settings.modes_per_event = 384, 64, 28
    settings.base_freq, settings.spread_oct, settings.decay_ms = 32.0, 3.5, 7200.0
    settings.brightness, settings.detune, settings.excitation_tone = 0.30, 0.12, 0.88
    settings.motion, settings.spatial_width = 0.16, 1.6
  else
    settings.frequency_model, settings.exciter, settings.spatial_mode = 1, 1, 1
    settings.mode_count, settings.events, settings.modes_per_event = 768, 260, 14
    settings.base_freq, settings.spread_oct, settings.decay_ms = 48.0, 6.0, 2200.0
    settings.brightness, settings.detune, settings.excitation_tone = 0.56, 0.20, 0.42
    settings.motion, settings.spatial_width = 0.28, 0.65
  end
end

local function persist()
  for key, value in pairs(settings) do setv(key, value) end
  be.save_extstate(EXT, ENV_DEFS, env_points, env_enabled)
end

local function draw_preview()
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(420, ImGui.GetContentRegionAvail(ctx))
  local h = 166
  ImGui.InvisibleButton(ctx, "##modal_terrain_preview", w, h)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, COLORS.bg)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, COLORS.edge)
  ImGui.DrawList_AddText(dl, x + 12, y + 10, COLORS.text, "modal terrain")
  ImGui.DrawList_AddText(dl, x + 12, y + 29, COLORS.muted, FREQ_LABELS[settings.frequency_model] .. " / " .. EXCITER_LABELS[settings.exciter])
  local cx, cy = x + w * 0.30, y + 96
  local r = 48
  ImGui.DrawList_AddCircle(dl, cx, cy, r, COLORS.grid, 64, 1)
  ImGui.DrawList_AddCircle(dl, cx, cy, r * 0.58, COLORS.grid, 64, 1)
  local count = math.min(72, math.max(12, math.floor(settings.mode_count / 16)))
  for i = 1, count do
    local a = i * 2.399963 + settings.seed * 0.17
    local rr = r * math.sqrt(i / count)
    local px = cx + math.cos(a) * rr
    local py = cy + math.sin(a) * rr * 0.72
    local col = (i % 3 == 0) and COLORS.amber or ((i % 3 == 1) and COLORS.cyan or COLORS.violet)
    ImGui.DrawList_AddCircleFilled(dl, px, py, 2.0 + (i % 5) * 0.35, col, 10)
  end
  local gx = x + w * 0.52
  local gy = y + 64
  local gw = w * 0.40
  local gh = 70
  ImGui.DrawList_AddRect(dl, gx, gy, gx + gw, gy + gh, COLORS.grid)
  local lx, ly
  for i = 0, 96 do
    local u = i / 96
    local curve = math.exp(-u * (1.2 + settings.brightness * 3.0)) * (0.35 + 0.65 * math.sin(u * math.pi * 8.0 + settings.detune * 2.0) ^ 2)
    local px = gx + gw * u
    local py = gy + gh * (1.0 - curve)
    if lx then ImGui.DrawList_AddLine(dl, lx, ly, px, py, COLORS.cyan, 1.4) end
    lx, ly = px, py
  end
  ImGui.DrawList_AddText(dl, gx, y + h - 24, COLORS.muted, tostring(math.floor(settings.mode_count)) .. " modes")
  ImGui.DrawList_AddText(dl, gx + 118, y + h - 24, COLORS.muted, tostring(math.floor(settings.events)) .. " events")
end

local function output_channels()
  if OUTPUT_KEYS[settings.output_mode] == "ring" then return math.floor(settings.channels) end
  return 16
end

local function render()
  local channels = output_channels()
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_modal_terrain_renders", nil, script_dir)
  local output_path = out_dir .. "/s3g_modal_terrain_" .. stamp .. "_" .. tostring(channels) .. "ch.wav"
  local manifest = {
    output_path = output_path,
    sample_rate = settings.sample_rate,
    duration = settings.duration,
    output_mode = OUTPUT_KEYS[settings.output_mode],
    order = 3,
    channels = settings.channels,
    frequency_model = FREQ_KEYS[settings.frequency_model],
    exciter = EXCITER_KEYS[settings.exciter],
    spatial_mode = SPATIAL_KEYS[settings.spatial_mode],
    mode_count = settings.mode_count,
    events = settings.events,
    modes_per_event = settings.modes_per_event,
    base_freq = settings.base_freq,
    spread_oct = settings.spread_oct,
    decay_ms = settings.decay_ms,
    damping_spread = settings.damping_spread,
    brightness = settings.brightness,
    detune = settings.detune,
    density = settings.density,
    motion = settings.motion,
    spatial_width = settings.spatial_width,
    excitation_tone = settings.excitation_tone,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    soft_limit = settings.soft_limit,
    seed = settings.seed,
  }
  be.add_to_manifest(manifest, ENV_DEFS, env_points, env_enabled)
  local log, elapsed = nr.run_backend(script_dir, "modal_terrain", manifest, TITLE)
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path, "Modal Terrain (" .. tostring(channels) .. "ch)", reaper.GetCursorPosition(), channels, { track_gain = settings.insert_gain, master_send = false })
  reaper.Undo_EndBlock(TITLE, -1)
  if not item then mc.show_error(err or "Could not insert rendered Modal Terrain.") return end
  mc.print_plan(TITLE, {
    "Output: " .. output_path,
    "Output mode: " .. OUTPUT_LABELS[settings.output_mode],
    "Frequency model: " .. FREQ_LABELS[settings.frequency_model],
    "Exciter: " .. EXCITER_LABELS[settings.exciter],
    "Channels: " .. tostring(channels),
    "Master send: off",
    string.format("NumPy time: %.2f sec", elapsed),
    log,
  })
end

local open = true
local should_render = false

local function loop()
  ImGui.SetNextWindowSize(ctx, 760, env_opts._editor_was_open and env_opts.expanded_window_h or env_opts.compact_window_h, ImGui.Cond_Always)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    local control_h = math.max(280, (avail_h or env_opts.compact_window_h) - 44)
    if ImGui.BeginChild(ctx, "##modal_terrain_controls", 0, control_h) then
      draw_preview()
      settings.preset = combo("Preset", settings.preset, PRESET_LABELS)
      if ImGui.Button(ctx, "Apply preset", 112, 24) then apply_preset(settings.preset) end
      ImGui.Separator(ctx)
      settings.output_mode = combo("Output", settings.output_mode, OUTPUT_LABELS)
      if OUTPUT_KEYS[settings.output_mode] == "ring" then
        local changed
        changed, settings.channels = ImGui.SliderInt(ctx, "Ring channels", math.floor(settings.channels), 2, 128)
      else
        ImGui.Text(ctx, "Output channels: 16 (3OA ACN/SN3D)")
      end
      settings.frequency_model = combo("Frequency model", settings.frequency_model, FREQ_LABELS)
      settings.exciter = combo("Exciter", settings.exciter, EXCITER_LABELS)
      settings.spatial_mode = combo("Spatial mode", settings.spatial_mode, SPATIAL_LABELS)
      local changed
      changed, settings.duration = ImGui.SliderDouble(ctx, "Duration sec", settings.duration, 0.5, 600.0, "%.2f")
      changed, settings.mode_count = ImGui.SliderInt(ctx, "Mode count", math.floor(settings.mode_count), 8, 4096)
      changed, settings.events = ImGui.SliderInt(ctx, "Excitation events", math.floor(settings.events), 1, 6000)
      changed, settings.modes_per_event = ImGui.SliderInt(ctx, "Modes per event", math.floor(settings.modes_per_event), 1, 96)
      changed, settings.base_freq = ImGui.SliderDouble(ctx, "Base frequency", settings.base_freq, 12.0, 440.0, "%.1f")
      changed, settings.spread_oct = ImGui.SliderDouble(ctx, "Frequency spread oct", settings.spread_oct, 0.1, 9.0, "%.2f")
      changed, settings.decay_ms = ImGui.SliderDouble(ctx, "Decay ms", settings.decay_ms, 8.0, 12000.0, "%.1f")
      changed, settings.damping_spread = ImGui.SliderDouble(ctx, "Damping spread", settings.damping_spread, 0.0, 1.0, "%.2f")
      changed, settings.brightness = ImGui.SliderDouble(ctx, "Brightness", settings.brightness, 0.0, 1.5, "%.2f")
      changed, settings.detune = ImGui.SliderDouble(ctx, "Detune / instability", settings.detune, 0.0, 1.0, "%.2f")
      changed, settings.density = ImGui.SliderDouble(ctx, "Density", settings.density, 0.0, 1.0, "%.2f")
      changed, settings.motion = ImGui.SliderDouble(ctx, "Motion", settings.motion, 0.0, 1.0, "%.2f")
      changed, settings.spatial_width = ImGui.SliderDouble(ctx, "Spatial width", settings.spatial_width, 0.02, 8.0, "%.2f")
      changed, settings.excitation_tone = ImGui.SliderDouble(ctx, "Excitation tone", settings.excitation_tone, 0.0, 1.0, "%.2f")
      changed, settings.soft_limit = ImGui.Checkbox(ctx, "Soft limit before normalize", settings.soft_limit)
      changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -36.0, -3.0, "%.1f")
      end
      changed, settings.insert_gain = ImGui.SliderDouble(ctx, "Inserted track gain", settings.insert_gain, 0.05, 1.0, "%.2f")
      changed, settings.seed = ImGui.InputInt(ctx, "Seed", math.floor(settings.seed))
      settings.channels = clamp(math.floor(settings.channels), 2, 128)
      settings.mode_count = clamp(math.floor(settings.mode_count), 8, 4096)
      settings.events = clamp(math.floor(settings.events), 1, 6000)
      settings.modes_per_event = clamp(math.floor(settings.modes_per_event), 1, 96)
      ImGui.Separator(ctx)
      selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env, selected_env_point, settings, env_opts)
      ImGui.EndChild(ctx)
    end
    if ImGui.Button(ctx, "Render", 104, 28) then should_render = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 104, 28) then open = false end
    ImGui.End(ctx)
  end
  persist()
  if should_render then open = false; render(); return end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
