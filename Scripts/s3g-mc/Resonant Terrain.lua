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

local ROW_H = 25
local LABEL_W = 86
local CONTROL_GAP = 8
local VALUE_W = 76
local LABEL_ABBR = {
  ["DURATION SEC"] = "DUR",
  ["OUTPUT CHANNELS"] = "OUT CH",
  ["EXCITATION EVENTS"] = "EVENTS",
  ["RESONATORS"] = "RES",
  ["BASE FREQUENCY"] = "BASE",
  ["FREQUENCY SPREAD OCT"] = "SPREAD",
  ["DECAY MS"] = "DECAY",
  ["STRIKE MS"] = "STRIKE",
  ["INHARMONICITY"] = "INHARM",
  ["RESONATOR DOUBLING"] = "DOUBLE",
  ["SPATIAL WIDTH"] = "WIDTH",
  ["NORMALIZE DB"] = "NORM DB",
  ["INSERTED TRACK GAIN"] = "INSERT",
}

local function row_label_text(label)
  local upper = tostring(label or ""):upper()
  return LABEL_ABBR[upper] or upper
end

local function row_layout(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local avail = ImGui.GetContentRegionAvail(ctx)
  if type(avail) ~= "number" then avail = 560 end
  local control_x = x + LABEL_W
  local control_w = math.max(120, avail - LABEL_W - CONTROL_GAP)
  return x, y, control_x, control_w
end

local function row_label(ctx, x, y, label)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 4, THEME.label, row_label_text(label))
end

local function finish_row(ctx, x, y)
  ImGui.SetCursorScreenPos(ctx, x, y + ROW_H)
end

local function draw_custom_slider(ctx, label, value, lo, hi, fmt, integer)
  local x, y, control_x, control_w = row_layout(ctx)
  local slider_w = math.max(80, control_w - VALUE_W - CONTROL_GAP)
  local value_x = control_x + slider_w + CONTROL_GAP
  local track_y = y + 8
  local track_h = 8
  local norm = hi ~= lo and clamp((value - lo) / (hi - lo), 0, 1) or 0
  row_label(ctx, x, y, label)
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
  finish_row(ctx, x, y)
  return changed, value
end

local function draw_int_input(ctx, label, value)
  local x, y, control_x, control_w = row_layout(ctx)
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, math.min(control_w, 104))
  local changed, next_value = ImGui.InputInt(ctx, "##" .. label, math.floor(value))
  finish_row(ctx, x, y)
  return changed, next_value
end

local function draw_checkbox(ctx, label, value)
  local x, y, control_x = row_layout(ctx)
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y + 2)
  local changed, next_value = ImGui.Checkbox(ctx, "##" .. label, value)
  finish_row(ctx, x, y)
  return changed, next_value
end

local function section(ctx, label, height)
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

local function finish_section(ctx, x, y, height, stack)
  theme.pop_soft_panel(ImGui, ctx, stack)
  ImGui.SetCursorScreenPos(ctx, x, y + height + 10)
  ImGui.Dummy(ctx, 1, 1)
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
      local footer_h = 48
      local control_h = math.max(260, (avail_h or env_opts.compact_window_h) - footer_h)
      if ImGui.BeginChild(ctx, "##resonant_terrain_controls", 0, control_h) then
      local changed
      selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env,
        selected_env_point, settings, env_opts)
      ImGui.Separator(ctx)
      local sx, sy, sh, stack = section(ctx, "Render", 148)
      changed, settings.duration = draw_custom_slider(ctx, "Duration sec", settings.duration, 0.5, 300.0, "%.2f", false)
      changed, settings.channels = draw_custom_slider(ctx, "Output channels", math.floor(settings.channels), 1, mc.MAX_REAPER_TRACK_CHANNELS, nil, true)
      changed, settings.events = draw_custom_slider(ctx, "Excitation events", math.floor(settings.events), 4, 2000, nil, true)
      changed, settings.density = draw_custom_slider(ctx, "Density", settings.density, 0.0, 1.0, "%.2f", false)
      finish_section(ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = section(ctx, "Resonators", 252)
      changed, settings.resonators = draw_custom_slider(ctx, "Resonators", math.floor(settings.resonators), 4, 256, nil, true)
      changed, settings.base_freq = draw_custom_slider(ctx, "Base frequency", settings.base_freq, 18.0, 440.0, "%.1f", false)
      changed, settings.spread_oct = draw_custom_slider(ctx, "Frequency spread oct", settings.spread_oct, 0.1, 8.0, "%.2f", false)
      changed, settings.decay_ms = draw_custom_slider(ctx, "Decay ms", settings.decay_ms, 20.0, 8000.0, "%.1f", false)
      changed, settings.strike_ms = draw_custom_slider(ctx, "Strike ms", settings.strike_ms, 0.2, 80.0, "%.1f", false)
      changed, settings.inharmonic = draw_custom_slider(ctx, "Inharmonicity", settings.inharmonic, 0.0, 1.0, "%.2f", false)
      changed, settings.roughness = draw_custom_slider(ctx, "Roughness", settings.roughness, 0.0, 1.0, "%.2f", false)
      changed, settings.feedback = draw_custom_slider(ctx, "Resonator doubling", settings.feedback, 0.0, 1.0, "%.2f", false)
      finish_section(ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = section(ctx, "Render", settings.normalize and 174 or 148)
      changed, settings.spatial_width = draw_custom_slider(ctx, "Spatial width", settings.spatial_width, 0.05, 6.0, "%.2f", false)
      changed, settings.normalize = draw_checkbox(ctx, "Peak normalize", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = draw_custom_slider(ctx, "Normalize dB", settings.normalize_db, -36.0, -3.0, "%.1f", false)
      end
      changed, settings.insert_gain = draw_custom_slider(ctx, "Inserted track gain", settings.insert_gain, 0.05, 1.0, "%.2f", false)
      changed, settings.seed = draw_int_input(ctx, "Seed", settings.seed)
      finish_section(ctx, sx, sy, sh, stack)
      settings.channels = clamp(math.floor(settings.channels), 1, mc.MAX_REAPER_TRACK_CHANNELS)
        ImGui.EndChild(ctx)
      end
      local render_pressed, cancel_pressed = theme.footer_buttons(ImGui, ctx, "RENDER", "CANCEL", 104, 104)
      if render_pressed then should_render = true end
      if cancel_pressed then open = false end
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
