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
do
  local _s3g_theme_path = ({ reaper.get_action_context() })[2]
  if not _s3g_theme_path or _s3g_theme_path == "" then
    _s3g_theme_path = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
  end
  local _s3g_theme_dir = _s3g_theme_path:match("^(.*[/\\])") or ""
  package.path = _s3g_theme_dir .. "?.lua;" .. package.path
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme and _s3g_theme.install then _s3g_theme.install(ImGui) end
end
local theme = require("s3g-mc ImGui Theme")
local THEME = theme.palette(ImGui)


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

local ROW_H = 25
local LABEL_W = 86
local CONTROL_GAP = 8
local VALUE_W = 76
local LABEL_ABBR = {
  ["FREQUENCY MODEL"] = "FREQ",
  ["SPATIAL MODE"] = "SPACE",
  ["RING CHANNELS"] = "RING",
  ["DURATION SEC"] = "DUR",
  ["MODE COUNT"] = "MODES",
  ["EXCITATION EVENTS"] = "EVENTS",
  ["MODES PER EVENT"] = "PER EVT",
  ["BASE FREQUENCY"] = "BASE",
  ["FREQUENCY SPREAD OCT"] = "SPREAD",
  ["DECAY MS"] = "DECAY",
  ["DAMPING SPREAD"] = "DAMP",
  ["DETUNE / INSTABILITY"] = "DETUNE",
  ["SPATIAL WIDTH"] = "WIDTH",
  ["EXCITATION TONE"] = "TONE",
  ["SOFT LIMIT BEFORE NORMALIZE"] = "LIMIT",
  ["PEAK NORMALIZE"] = "PK NORM",
  ["NORMALIZE DB"] = "NORM DB",
  ["INSERTED TRACK GAIN"] = "INSERT",
}

local function row_label_text(label)
  local upper = tostring(label or ""):upper()
  return LABEL_ABBR[upper] or upper
end

local function row_layout()
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local avail = ImGui.GetContentRegionAvail(ctx)
  if type(avail) ~= "number" then avail = 580 end
  local control_x = x + LABEL_W
  local control_w = math.max(120, avail - LABEL_W - CONTROL_GAP)
  return x, y, control_x, control_w
end

local function text_width(text)
  text = tostring(text or "")
  if ImGui.CalcTextSize then
    local ok, width = pcall(ImGui.CalcTextSize, ctx, text)
    if ok and type(width) == "number" then return width end
  end
  return #text * 7
end

local function combo_width(names, current, max_width)
  local width = text_width(names[current or 1] or "") + 38
  for _, name in ipairs(names or {}) do
    width = math.max(width, text_width(name) + 38)
  end
  return math.max(80, math.min(max_width or width, width))
end

local function row_label(x, y, label)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 4, THEME.label, row_label_text(label))
end

local function finish_row(x, y)
  ImGui.SetCursorScreenPos(ctx, x, y + ROW_H)
end

local function draw_custom_slider(label, value, lo, hi, fmt, integer)
  local x, y, control_x, control_w = row_layout()
  local slider_w = math.max(80, control_w - VALUE_W - CONTROL_GAP)
  local value_x = control_x + slider_w + CONTROL_GAP
  local track_y = y + 8
  local track_h = 8
  local norm = hi ~= lo and clamp((value - lo) / (hi - lo), 0, 1) or 0
  row_label(x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.InvisibleButton(ctx, "##" .. label, slider_w, ROW_H)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local changed = false
  if (hovered or active) and ImGui.IsMouseDown(ctx, 0) then
    local mx = ImGui.GetMousePos(ctx)
    local next_norm = clamp((mx - control_x) / slider_w, 0, 1)
    local next_value = lo + (hi - lo) * next_norm
    if integer then next_value = math.floor(next_value + 0.5) end
    if math.abs(next_value - value) > (integer and 0 or 0.0000001) then
      value = next_value
      norm = next_norm
      changed = true
    end
  end
  local draw = ImGui.GetWindowDrawList(ctx)
  local frame = active and THEME.frame_active or (hovered and THEME.frame_hover or THEME.frame)
  local fill = active and THEME.active or THEME.fill
  local handle = active and THEME.active_hover or THEME.active
  ImGui.DrawList_AddRectFilled(draw, control_x, track_y, control_x + slider_w, track_y + track_h, frame)
  ImGui.DrawList_AddRectFilled(draw, control_x + 1, track_y + 1, control_x + math.max(2, slider_w * norm), track_y + track_h - 1, fill)
  local hx = clamp(control_x + slider_w * norm - 1.5, control_x + 1, control_x + slider_w - 4)
  ImGui.DrawList_AddRectFilled(draw, hx, track_y - 2, hx + 3, track_y + track_h + 2, handle)
  ImGui.DrawList_AddText(draw, value_x, y + 4, THEME.value, integer and tostring(math.floor(value + 0.5)) or string.format(fmt or "%.3f", value))
  finish_row(x, y)
  return changed, value
end

local function draw_int_input(label, value)
  local x, y, control_x, control_w = row_layout()
  row_label(x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, math.min(control_w, 104))
  local changed, next_value = ImGui.InputInt(ctx, "##" .. label, math.floor(value))
  finish_row(x, y)
  return changed, next_value
end

local function draw_checkbox(label, value)
  local x, y, control_x = row_layout()
  row_label(x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y + 2)
  local changed, next_value = ImGui.Checkbox(ctx, "##" .. label, value)
  finish_row(x, y)
  return changed, next_value
end

local function section(label, height)
  local stack = theme.push_soft_panel(ImGui, ctx)
  local draw = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + height, THEME.panel_soft)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + 21, THEME.bg_alt)
  ImGui.DrawList_AddRect(draw, x, y, x + w, y + height, THEME.edge)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + 2, THEME.active)
  ImGui.SetCursorScreenPos(ctx, x + 8, y + 6)
  theme.text(ImGui, ctx, label:upper())
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 36)
  return x, y, height, stack
end

local function finish_section(x, y, height, stack)
  theme.pop_soft_panel(ImGui, ctx, stack)
  ImGui.SetCursorScreenPos(ctx, x, y + height + 10)
  ImGui.Dummy(ctx, 1, 1)
end

local function combo(label, index, names)
  local x, y, control_x, control_w = row_layout()
  row_label(x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, combo_width(names, index, control_w))
  if ImGui.BeginCombo(ctx, "##" .. label, names[index] or "") then
    for i, name in ipairs(names) do
      local selected = i == index
      if ImGui.Selectable(ctx, name, selected) then index = i end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  finish_row(x, y)
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
    local footer_h = 48
    local control_h = math.max(280, (avail_h or env_opts.compact_window_h) - footer_h)
    if ImGui.BeginChild(ctx, "##modal_terrain_controls", 0, control_h) then
      selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env, selected_env_point, settings, env_opts)
      ImGui.Separator(ctx)
      local sx, sy, sh, stack = section("Preset", 98)
      settings.preset = combo("Preset", settings.preset, PRESET_LABELS)
      if ImGui.Button(ctx, "APPLY PRESET", 112, 24) then apply_preset(settings.preset) end
      finish_section(sx, sy, sh, stack)
      sx, sy, sh, stack = section("Output / Models", OUTPUT_KEYS[settings.output_mode] == "ring" and 226 or 200)
      settings.output_mode = combo("Output", settings.output_mode, OUTPUT_LABELS)
      if OUTPUT_KEYS[settings.output_mode] == "ring" then
        local changed
        changed, settings.channels = draw_custom_slider("Ring channels", math.floor(settings.channels), 2, 128, nil, true)
      else
        theme.muted(ImGui, ctx, "Output channels: 16 (3OA ACN/SN3D)")
      end
      settings.frequency_model = combo("Frequency model", settings.frequency_model, FREQ_LABELS)
      settings.exciter = combo("Exciter", settings.exciter, EXCITER_LABELS)
      settings.spatial_mode = combo("Spatial mode", settings.spatial_mode, SPATIAL_LABELS)
      finish_section(sx, sy, sh, stack)
      local changed
      sx, sy, sh, stack = section("Synthesis", 356)
      changed, settings.duration = draw_custom_slider("Duration sec", settings.duration, 0.5, 600.0, "%.2f", false)
      changed, settings.mode_count = draw_custom_slider("Mode count", math.floor(settings.mode_count), 8, 4096, nil, true)
      changed, settings.events = draw_custom_slider("Excitation events", math.floor(settings.events), 1, 6000, nil, true)
      changed, settings.modes_per_event = draw_custom_slider("Modes per event", math.floor(settings.modes_per_event), 1, 96, nil, true)
      changed, settings.base_freq = draw_custom_slider("Base frequency", settings.base_freq, 12.0, 440.0, "%.1f", false)
      changed, settings.spread_oct = draw_custom_slider("Frequency spread oct", settings.spread_oct, 0.1, 9.0, "%.2f", false)
      changed, settings.decay_ms = draw_custom_slider("Decay ms", settings.decay_ms, 8.0, 12000.0, "%.1f", false)
      changed, settings.damping_spread = draw_custom_slider("Damping spread", settings.damping_spread, 0.0, 1.0, "%.2f", false)
      changed, settings.brightness = draw_custom_slider("Brightness", settings.brightness, 0.0, 1.5, "%.2f", false)
      changed, settings.detune = draw_custom_slider("Detune / instability", settings.detune, 0.0, 1.0, "%.2f", false)
      changed, settings.density = draw_custom_slider("Density", settings.density, 0.0, 1.0, "%.2f", false)
      changed, settings.motion = draw_custom_slider("Motion", settings.motion, 0.0, 1.0, "%.2f", false)
      changed, settings.spatial_width = draw_custom_slider("Spatial width", settings.spatial_width, 0.02, 8.0, "%.2f", false)
      finish_section(sx, sy, sh, stack)
      sx, sy, sh, stack = section("Render", settings.normalize and 200 or 174)
      changed, settings.excitation_tone = draw_custom_slider("Excitation tone", settings.excitation_tone, 0.0, 1.0, "%.2f", false)
      changed, settings.soft_limit = draw_checkbox("Soft limit before normalize", settings.soft_limit)
      changed, settings.normalize = draw_checkbox("Peak normalize", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = draw_custom_slider("Normalize dB", settings.normalize_db, -36.0, -3.0, "%.1f", false)
      end
      changed, settings.insert_gain = draw_custom_slider("Inserted track gain", settings.insert_gain, 0.05, 1.0, "%.2f", false)
      changed, settings.seed = draw_int_input("Seed", settings.seed)
      finish_section(sx, sy, sh, stack)
      settings.channels = clamp(math.floor(settings.channels), 2, 128)
      settings.mode_count = clamp(math.floor(settings.mode_count), 8, 4096)
      settings.events = clamp(math.floor(settings.events), 1, 6000)
      settings.modes_per_event = clamp(math.floor(settings.modes_per_event), 1, 96)
      ImGui.EndChild(ctx)
    end
    local render_pressed, cancel_pressed = theme.footer_buttons(ImGui, ctx, "RENDER", "CANCEL", 104, 104)
    if render_pressed then should_render = true end
    if cancel_pressed then open = false end
    ImGui.End(ctx)
  end
  persist()
  if should_render then open = false; render(); return end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
