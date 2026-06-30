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

local TITLE = "Terrain Form"
local ctx = ImGui.CreateContext(TITLE)
local open = true
local status = ""

local ROOTS = midi.ROOT_NAMES
local SCALES = midi.SCALE_NAMES
local FORM_NAMES = { "Arc", "Episodes", "Return", "Drift", "Blocks", "Terrain", "Ritual", "Cascade", "Constellation" }
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

local COLORS = {
  panel = color(0.055, 0.060, 0.064, 1),
  edge = color(0.30, 0.32, 0.33, 1),
  grid = color(0.48, 0.52, 0.51, 0.22),
  text = color(0.80, 0.84, 0.82, 1),
  dim = color(0.50, 0.55, 0.54, 1),
  line = color(0.28, 0.72, 0.68, 1),
  hit = color(0.95, 0.74, 0.28, 1),
  section = color(0.22, 0.30, 0.32, 1),
}

local function combo(label, labels, value, width)
  ImGui.SetNextItemWidth(ctx, width or 160)
  local changed, next_value = ImGui.Combo(ctx, label, value - 1, table.concat(labels, "\0") .. "\0")
  return changed, next_value + 1
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

local function draw_preview()
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  local h = 250
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, COLORS.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, COLORS.edge)
  ImGui.DrawList_AddText(draw_list, x + 12, y + 10, COLORS.dim, "MIDI TERRAIN FORM")
  local left, top, right, bottom = x + 18, y + 48, x + w - 18, y + h - 30
  local section_w = (right - left) / math.max(1, state.sections)
  for section = 1, state.sections do
    local sx0 = left + (section - 1) * section_w
    local sx1 = sx0 + section_w - 2
    local t = (section - 0.5) / math.max(1, state.sections)
    local energy
    if FORM_KEYS[state.form] == "arc" then energy = math.sin(math.pi * t)
    elseif FORM_KEYS[state.form] == "cascade" then energy = t
    elseif FORM_KEYS[state.form] == "drift" then energy = 0.25 + 0.7 * t
    elseif FORM_KEYS[state.form] == "return" then energy = (section % 3 == 1) and 0.8 or (0.35 + 0.45 * math.sin(math.pi * t))
    else energy = 0.35 + 0.5 * ((section * 37 + state.seed) % 11) / 10 end
    local sy = bottom - energy * (bottom - top)
    ImGui.DrawList_AddRectFilled(draw_list, sx0, sy, sx1, bottom, COLORS.section)
    ImGui.DrawList_AddRect(draw_list, sx0, top, sx1, bottom, COLORS.grid)
    ImGui.DrawList_AddText(draw_list, sx0 + 5, bottom + 7, COLORS.dim, tostring(section))
  end
  local last_x, last_y
  local points = 96
  for i = 0, points do
    local t = i / points
    local terrain = 0.5 + 0.45 * math.sin(2 * math.pi * (t * (1 + state.contrast * 4) + state.seed * 0.013))
    if TERRAIN_KEYS[state.terrain] == "ridge" then terrain = math.exp(-((t - 0.5) ^ 2) / 0.08)
    elseif TERRAIN_KEYS[state.terrain] == "basin" then terrain = 1 - math.exp(-((t - 0.5) ^ 2) / 0.08)
    elseif TERRAIN_KEYS[state.terrain] == "fault" then terrain = t > 0.45 and 0.88 or 0.22 end
    local px = left + t * (right - left)
    local py = bottom - terrain * (bottom - top)
    if last_x then ImGui.DrawList_AddLine(draw_list, last_x, last_y, px, py, COLORS.line, 1.4) end
    last_x, last_y = px, py
  end
  ImGui.DrawList_AddText(draw_list, x + 18, y + h - 20, COLORS.dim,
    string.format("%s / %s / %d beats / %d lanes", FORM_NAMES[state.form], TERRAIN_NAMES[state.terrain], state.duration_beats, state.lanes))
  ImGui.SetCursorScreenPos(ctx, x, y + h + 12)
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 820, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    draw_preview()
    _, state.form = combo("Form", FORM_NAMES, state.form, 170)
    ImGui.SameLine(ctx)
    _, state.terrain = combo("Terrain", TERRAIN_NAMES, state.terrain, 170)
    _, state.duration_beats = ImGui.SliderInt(ctx, "Duration beats", state.duration_beats, 16, 4096)
    _, state.sections = ImGui.SliderInt(ctx, "Sections", state.sections, 1, 32)
    _, state.lanes = ImGui.SliderInt(ctx, "MIDI channels / lanes", state.lanes, 1, 16)
    _, state.root = combo("Root", ROOTS, state.root, 90)
    ImGui.SameLine(ctx)
    _, state.scale = combo("Scale", SCALES, state.scale, 170)
    ImGui.Separator(ctx)
    _, state.density = ImGui.SliderDouble(ctx, "Density", state.density, 0, 1, "%.3f")
    _, state.contrast = ImGui.SliderDouble(ctx, "Section contrast", state.contrast, 0, 1, "%.3f")
    _, state.recurrence = ImGui.SliderDouble(ctx, "Motif recurrence", state.recurrence, 0, 1, "%.3f")
    _, state.channel_motion = ImGui.SliderDouble(ctx, "Channel motion", state.channel_motion, 0, 1, "%.3f")
    ImGui.Separator(ctx)
    _, state.octave = ImGui.SliderInt(ctx, "Base octave", state.octave, 0, 8)
    _, state.register_span = ImGui.SliderInt(ctx, "Register span", state.register_span, 1, 7)
    _, state.pitch_span = ImGui.SliderInt(ctx, "Pitch span degrees", state.pitch_span, 4, 80)
    _, state.min_note = ImGui.SliderDouble(ctx, "Minimum note beats", state.min_note, 0.03125, 4, "%.3f")
    _, state.max_note = ImGui.SliderDouble(ctx, "Maximum note beats", state.max_note, state.min_note, 16, "%.3f")
    _, state.velocity = ImGui.SliderInt(ctx, "Velocity center", state.velocity, 1, 127)
    _, state.velocity_range = ImGui.SliderInt(ctx, "Velocity range", state.velocity_range, 0, 80)
    _, state.seed = ImGui.InputInt(ctx, "Seed", state.seed)
    _, state.add_markers = ImGui.Checkbox(ctx, "Add project markers for sections", state.add_markers)
    if ImGui.Button(ctx, "New Seed", 100, 28) then state.seed = state.seed + 1 end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Generate MIDI Form", 170, 28) then generate() end
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, COLORS.dim, status)
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
