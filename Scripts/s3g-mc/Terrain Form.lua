-- @description Terrain Form
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3; NumPy; MIDI Rule Library.lua; NumPy Render Library.lua
-- @category MIDI Composition
-- @render No
-- @method NumPy-backed song-duration MIDI composer. Generates a section map, terrain-shaped density/register/channel fields, and ordinary editable MIDI events for procedural synths or other instruments.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local midi = dofile(script_dir .. "MIDI Rule Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Terrain Form", 0)
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

local TITLE = "Terrain Form"
local ctx = ImGui.CreateContext(TITLE)
local open = true
local status = ""

local function ui_slider_int(label, value, min_value, max_value)
  return theme.slider_int(ImGui, ctx, label, value, min_value, max_value)
end

local function ui_slider_double(label, value, min_value, max_value, format)
  return theme.slider_double(ImGui, ctx, label, value, min_value, max_value, format)
end

local ROOTS = midi.ROOT_NAMES
local SCALES = midi.SCALE_NAMES
local FORM_NAMES = { "Arc", "Episodes", "Return", "Drift", "Blocks", "TERRAIN", "Ritual", "Cascade", "Constellation" }
local FORM_KEYS = { "arc", "episodes", "return", "drift", "blocks", "terrain", "ritual", "cascade", "constellation" }
local TERRAIN_NAMES = { "Ridge", "Basin", "Spiral", "Fault", "Cellular", "Attractor" }
local TERRAIN_KEYS = { "ridge", "basin", "spiral", "fault", "cellular", "attractor" }

local state = {
  duration_beats = 384,
  sections = 9,
  lanes = 8,
  root = 1,
  scale = 4,
  form = 3,
  terrain = 1,
  density = 0.48,
  contrast = 0.58,
  recurrence = 0.42,
  channel_motion = 0.68,
  octave = 3,
  register_span = 4,
  pitch_span = 30,
  min_note = 0.25,
  max_note = 2.0,
  velocity = 78,
  velocity_range = 34,
  seed = 21,
  add_markers = true,
}

local last_sections = {}
local last_events = {}

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local STYLE = {
  panel = THEME.panel,
  edge = THEME.edge,
  grid = THEME.grid,
  text = THEME.text,
  dim = THEME.value,
  line = color(0.42, 0.62, 0.58, 1),
  hit = THEME.amber,
  section = color(0.22, 0.27, 0.28, 1),
}

local function combo(label, labels, value, width)
  if theme and theme.combo_row then return theme.combo_row(ImGui, ctx, label, labels, value, width) end
  local function text_width(text)
    if ImGui.CalcTextSize then
      local ok, w = pcall(ImGui.CalcTextSize, ctx, tostring(text or ""))
      if ok and type(w) == "number" then return w end
    end
    return #tostring(text or "") * 7
  end
  local combo_w = text_width(labels[value or 1] or "") + 38
  for _, item in ipairs(labels or {}) do combo_w = math.max(combo_w, text_width(item) + 38) end
  ImGui.SetNextItemWidth(ctx, math.max(80, math.min(width or 160, combo_w)))
  local changed, next_value = ImGui.Combo(ctx, "##combo_" .. tostring(label or ""), value - 1, table.concat(labels, "\0") .. "\0")
  return changed, next_value + 1
end

local function ui_input_int(label, value, step, step_fast, width)
  if theme and theme.input_int_row then return theme.input_int_row(ImGui, ctx, label, value, step, step_fast, width) end
  return ImGui.InputInt(ctx, "##input_" .. tostring(label or ""), value, step or 1, step_fast or 10)
end

local function push_soft_panel()
  if theme and theme.push_soft_panel then return theme.push_soft_panel(ImGui, ctx) end
  return nil
end

local function pop_soft_panel(stack)
  if theme and theme.pop_soft_panel then theme.pop_soft_panel(ImGui, ctx, stack) end
end

local function qn_to_time(qn)
  return reaper.TimeMap2_QNToTime(0, qn)
end

local function parse_plan(path)
  local sections, events = {}, {}
  local file = io.open(path, "r")
  if not file then return sections, events end
  for line in file:lines() do
    if not line:match("^type,") then
      local kind, index, start_b, dur_b, pitch, velocity, channel, section, label =
        line:match("^([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),(.+)$")
      if kind == "section" then
        sections[#sections + 1] = {
          index = tonumber(index) or (#sections + 1),
          start = tonumber(start_b) or 0,
          duration = tonumber(dur_b) or 0,
          label = label or ("S" .. tostring(#sections + 1)),
        }
      elseif kind == "event" then
        events[#events + 1] = {
          start = tonumber(start_b) or 0,
          duration = tonumber(dur_b) or 0.25,
          pitch = tonumber(pitch) or 60,
          velocity = tonumber(velocity) or 80,
          channel = tonumber(channel) or 0,
          section = tonumber(section) or 1,
        }
      end
    end
  end
  file:close()
  return sections, events
end

local function call_backend(output_path)
  local manifest = {
    output_path = output_path,
    duration_beats = state.duration_beats,
    sections = state.sections,
    lanes = state.lanes,
    root = midi.ROOTS[ROOTS[state.root]] or 0,
    scale = SCALES[state.scale],
    form = FORM_KEYS[state.form],
    terrain = TERRAIN_KEYS[state.terrain],
    density = state.density,
    contrast = state.contrast,
    recurrence = state.recurrence,
    channel_motion = state.channel_motion,
    octave = state.octave,
    register_span = state.register_span,
    pitch_span = state.pitch_span,
    min_note_beats = state.min_note,
    max_note_beats = state.max_note,
    velocity = state.velocity,
    velocity_range = state.velocity_range,
    seed = state.seed,
  }
  return nr.run_backend(script_dir, "midi_terrain_form", manifest, TITLE)
end

local function write_midi(sections, events)
  local track = midi.ensure_track()
  if not track then midi.show_error("Could not find or create a track.", TITLE) return end
  local start_qn = reaper.TimeMap2_timeToQN(0, reaper.GetCursorPosition())
  local item, take = midi.create_midi_item(track, start_qn, start_qn + state.duration_beats, "Terrain Form")
  if not take then midi.show_error("Could not create MIDI item.", TITLE) return end
  for _, event in ipairs(events) do
    local note_start = start_qn + event.start
    local note_end = note_start + math.max(0.03125, event.duration)
    midi.insert_note_qn(take, note_start, note_end, event.channel, event.pitch, event.velocity)
  end
  reaper.MIDI_Sort(take)
  if state.add_markers then
    for _, section in ipairs(sections) do
      local pos = qn_to_time(start_qn + section.start)
      reaper.AddProjectMarker2(0, false, pos, 0, "MTF " .. section.label, -1, 0)
    end
  end
  reaper.UpdateArrange()
end

local function generate()
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local path = (os.getenv("TMPDIR") or "/tmp") .. "/s3g_midi_terrain_form_" .. stamp .. ".csv"
  local log, elapsed = call_backend(path)
  if not log then return end
  local sections, events = parse_plan(path)
  os.remove(path)
  if #events == 0 then
    reaper.MB("NumPy generated no MIDI events. Increase density or duration.", TITLE, 0)
    return
  end
  reaper.Undo_BeginBlock()
  write_midi(sections, events)
  reaper.Undo_EndBlock(TITLE, -1)
  last_sections, last_events = sections, events
  status = string.format("Wrote %d events across %d sections. NumPy %.2f sec.", #events, #sections, elapsed or 0)
  reaper.ShowConsoleMsg("\n[Terrain Form]\n" .. log .. "\n")
end

local function loop()
  local body_target_h = 548
  ImGui.SetNextWindowSize(ctx, 820, body_target_h + 72, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local footer_height = 48
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    local content_height = math.min(body_target_h, math.max(300, (avail_h or body_target_h + footer_height) - footer_height))
    local main_panel_style = push_soft_panel()
    local child_visible = ImGui.BeginChild(ctx, "##main_content", 0, content_height)
    if child_visible then
      _, state.form = combo("FORM", FORM_NAMES, state.form, 170)
      _, state.terrain = combo("TERRAIN", TERRAIN_NAMES, state.terrain, 170)
      _, state.duration_beats = ui_slider_int("BEATS", state.duration_beats, 16, 4096)
      _, state.sections = ui_slider_int("SECTIONS", state.sections, 1, 32)
      _, state.lanes = ui_slider_int("MIDI LANES", state.lanes, 1, 16)
      _, state.root = combo("ROOT", ROOTS, state.root, 90)
      _, state.scale = combo("SCALE", SCALES, state.scale, 170)
      _, state.density = ui_slider_double("DENS", state.density, 0, 1, "%.3f")
      _, state.contrast = ui_slider_double("CONTRAST", state.contrast, 0, 1, "%.3f")
      _, state.recurrence = ui_slider_double("RECUR", state.recurrence, 0, 1, "%.3f")
      _, state.channel_motion = ui_slider_double("CH MOTION", state.channel_motion, 0, 1, "%.3f")
      _, state.octave = ui_slider_int("OCT", state.octave, 0, 8)
      _, state.register_span = ui_slider_int("SPAN", state.register_span, 1, 7)
      _, state.pitch_span = ui_slider_int("PITCH SPAN", state.pitch_span, 4, 80)
      _, state.min_note = ui_slider_double("MIN BEATS", state.min_note, 0.03125, 4, "%.3f")
      _, state.max_note = ui_slider_double("MAX BEATS", state.max_note, state.min_note, 16, "%.3f")
      _, state.velocity = ui_slider_int("VELO", state.velocity, 1, 127)
      _, state.velocity_range = ui_slider_int("VRNG", state.velocity_range, 0, 80)
      _, state.seed = ui_input_int("SEED", state.seed, 1, 10, 110)
      _, state.add_markers = ImGui.Checkbox(ctx, "ADD MARKERS", state.add_markers)
    end
    ImGui.EndChild(ctx)
    pop_soft_panel(main_panel_style)
    local new_seed, generate_midi = theme.footer_buttons(ImGui, ctx, "NEW SEED", "GENERATE MIDI", 104, 148)
    if new_seed then state.seed = state.seed + 1 end
    if generate_midi then generate() end
    if status ~= "" then
      ImGui.SameLine(ctx)
      theme.muted(ImGui, ctx, status)
    end
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
