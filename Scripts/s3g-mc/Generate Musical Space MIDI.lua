-- @description Generate Musical Space MIDI
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; MIDI Rule Library.lua
-- @category MIDI Composition
-- @render No
-- @method Creates a new editable MIDI item from a path through a chosen musical space. The rule set combines scale-degree movement, Euclidean timing, probability, velocity shaping, and MIDI-channel spatial focus for procedural synths or general algorithmic composition.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local midi = dofile(script_dir .. "MIDI Rule Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Generate Musical Space MIDI", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "Generate Musical Space MIDI"
local ctx = ImGui.CreateContext(TITLE)
local open = true
local status = ""

local ROOTS = midi.ROOT_NAMES
local SCALES = midi.SCALE_NAMES
local SPACES = { "Scale walk", "Contour", "Triadic", "Axis mirror" }
local CHANNEL_MODES = { "Fixed", "Round-robin", "Path position", "Random" }
local LENGTHS = { "Use time selection", "1 bar", "2 bars", "4 bars", "8 bars", "16 bars" }
local LENGTH_BEATS = { 0, 4, 8, 16, 32, 64 }

local state = {
  root = 1,
  scale = 2,
  space = 1,
  length = 3,
  steps = 16,
  pulses = 7,
  rotate = 0,
  density = 0.92,
  surprise = 0.24,
  octave = 3,
  span = 3,
  note_len = 0.72,
  velocity = 78,
  accent = 28,
  jitter = 8,
  channels = 8,
  channel_mode = 3,
  seed = 1,
  replace_time_selection = true,
}

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local COLORS = {
  panel = color(0.055, 0.060, 0.064, 1),
  edge = color(0.30, 0.32, 0.33, 1),
  text = color(0.80, 0.84, 0.82, 1),
  dim = color(0.50, 0.55, 0.54, 1),
  hit = color(0.95, 0.74, 0.28, 1),
  line = color(0.27, 0.73, 0.68, 1),
  muted = color(0.34, 0.37, 0.38, 1),
}

local PC_NAMES = { "C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B" }

local preview = {}

local function combo(label, labels, value, width)
  ImGui.SetNextItemWidth(ctx, width or 160)
  local changed, next_value = ImGui.Combo(ctx, label, value, table.concat(labels, "\0") .. "\0")
  return changed, next_value
end

local function generate_preview()
  local root = ROOTS[state.root]
  local scale = SCALES[state.scale]
  local space = SPACES[state.space]
  local pattern = midi.euclidean_pattern(state.pulses, state.steps, state.rotate)
  local degree = 0
  local axis = math.floor((#(midi.SCALES[scale] or midi.SCALES.Major) - 1) / 2)
  local events = {}
  midi.seed(state.seed)
  local hit_index = 0
  for step = 1, state.steps do
    if pattern[step] and midi.chance(state.density) then
      hit_index = hit_index + 1
      if hit_index > 1 then degree = degree + midi.weighted_step(space, state.surprise) end
      if space == "Axis mirror" and hit_index % 2 == 0 then degree = axis - (degree - axis) end
      local pitch = midi.scale_pitch(root, scale, degree, state.octave, state.span)
      local channel = 0
      if CHANNEL_MODES[state.channel_mode] == "Round-robin" then
        channel = (hit_index - 1) % math.max(1, state.channels)
      elseif CHANNEL_MODES[state.channel_mode] == "Path position" then
        channel = math.floor(((pitch - 24) / 72) * math.max(1, state.channels - 1) + 0.5)
      elseif CHANNEL_MODES[state.channel_mode] == "Random" then
        channel = math.floor(math.random() * math.max(1, state.channels))
      end
      events[#events + 1] = {
        step = step,
        degree = degree,
        pitch = pitch,
        channel = midi.clamp(channel, 0, math.min(15, state.channels - 1)),
        velocity = midi.velocity(state.velocity, state.accent, hit_index, 4, state.jitter),
      }
    end
  end
  preview = events
end

local function point_on_circle(cx, cy, radius, index, count)
  local angle = -math.pi * 0.5 + (math.pi * 2 * index / math.max(1, count))
  return cx + math.cos(angle) * radius, cy + math.sin(angle) * radius
end

local function pitch_class(pitch)
  return ((math.floor(pitch or 0) % 12) + 12) % 12
end

local function scale_pc_lookup()
  local lookup = {}
  local root = midi.ROOTS[ROOTS[state.root]] or 0
  local scale = midi.SCALES[SCALES[state.scale]] or midi.SCALES.Major
  for _, interval in ipairs(scale) do
    lookup[(root + interval) % 12] = true
  end
  return lookup
end

local function draw_preview()
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  local h = 250
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, COLORS.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, COLORS.edge)

  local left_cx = x + math.min(160, w * 0.26)
  local cy = y + h * 0.55
  local pc_radius = math.min(92, h * 0.36)
  local scale_lookup = scale_pc_lookup()

  ImGui.DrawList_AddText(draw_list, x + 12, y + 10, COLORS.dim, "PITCH SPACE")
  ImGui.DrawList_AddCircle(draw_list, left_cx, cy, pc_radius, COLORS.muted, 96, 1)
  for pc = 0, 11 do
    local px, py = point_on_circle(left_cx, cy, pc_radius, pc, 12)
    local active = scale_lookup[pc] == true
    ImGui.DrawList_AddCircleFilled(draw_list, px, py, active and 4.5 or 2.2, active and COLORS.line or COLORS.muted)
    ImGui.DrawList_AddText(draw_list, px + 6, py - 6, active and COLORS.text or COLORS.dim, PC_NAMES[pc + 1])
  end

  local last_x, last_y = nil, nil
  for index, event in ipairs(preview) do
    local pc = pitch_class(event.pitch)
    local register_r = pc_radius * (0.42 + 0.36 * ((event.channel or 0) / math.max(1, state.channels - 1)))
    local px, py = point_on_circle(left_cx, cy, register_r, pc, 12)
    if last_x then ImGui.DrawList_AddLine(draw_list, last_x, last_y, px, py, COLORS.line, 1.2) end
    local radius = 3 + (event.velocity / 127) * 3
    ImGui.DrawList_AddCircleFilled(draw_list, px, py, radius, COLORS.hit)
    if index == 1 or index == #preview then
      ImGui.DrawList_AddText(draw_list, px + 6, py - 7, COLORS.text, index == 1 and "start" or "end")
    end
    last_x, last_y = px, py
  end

  local ring_cx = x + w - math.min(160, w * 0.27)
  local ring_r = math.min(92, h * 0.36)
  ImGui.DrawList_AddText(draw_list, ring_cx - 58, y + 10, COLORS.dim, "RHYTHM / CHANNEL")
  ImGui.DrawList_AddCircle(draw_list, ring_cx, cy, ring_r, COLORS.muted, 96, 1)
  local pattern = midi.euclidean_pattern(state.pulses, state.steps, state.rotate)
  local event_by_step = {}
  for _, event in ipairs(preview) do event_by_step[event.step] = event end
  for step = 1, state.steps do
    local p1x, p1y = point_on_circle(ring_cx, cy, ring_r - 4, step - 1, state.steps)
    local p2x, p2y = point_on_circle(ring_cx, cy, ring_r + 4, step - 1, state.steps)
    local event = event_by_step[step]
    ImGui.DrawList_AddLine(draw_list, p1x, p1y, p2x, p2y, pattern[step] and COLORS.line or COLORS.muted, 1)
    if event then
      local event_r = ring_r * (0.42 + 0.44 * ((event.channel or 0) / math.max(1, state.channels - 1)))
      local hx, hy = point_on_circle(ring_cx, cy, event_r, step - 1, state.steps)
      ImGui.DrawList_AddCircleFilled(draw_list, hx, hy, 3.5 + event.velocity / 127 * 2.5, COLORS.hit)
      ImGui.DrawList_AddText(draw_list, hx + 5, hy - 6, COLORS.dim, tostring(event.channel + 1))
    end
  end

  local mid_x = x + w * 0.5
  ImGui.DrawList_AddText(draw_list, mid_x - 62, y + h - 28, COLORS.dim,
    tostring(#preview) .. " events  /  " .. SPACES[state.space])
  ImGui.SetCursorScreenPos(ctx, x + 12, y + h + 10)
end

local function generate_item()
  local track = midi.ensure_track()
  if not track then midi.show_error("Could not find or create a track.", TITLE) return end
  local default_beats = LENGTH_BEATS[state.length] > 0 and LENGTH_BEATS[state.length] or 16
  local start_qn, end_qn = midi.time_selection_or_cursor_qn(default_beats)
  if LENGTH_BEATS[state.length] > 0 then end_qn = start_qn + LENGTH_BEATS[state.length] end
  local item, take = midi.create_midi_item(track, start_qn, end_qn, "Musical Space MIDI")
  if not take then midi.show_error("Could not create MIDI item.", TITLE) return end
  generate_preview()
  local total_beats = math.max(0.25, end_qn - start_qn)
  local step_beats = total_beats / math.max(1, state.steps)
  for _, event in ipairs(preview) do
    local note_start = start_qn + (event.step - 1) * step_beats
    local note_end = note_start + step_beats * state.note_len
    midi.insert_note_qn(take, note_start, note_end, event.channel, event.pitch, event.velocity)
  end
  reaper.MIDI_Sort(take)
  reaper.UpdateArrange()
  status = "Wrote " .. tostring(#preview) .. " notes to a new MIDI item."
end

generate_preview()

local function loop()
  ImGui.SetNextWindowSize(ctx, 820, 720, ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    draw_preview()
    local changed = false
    local c
    c, state.root = combo("Root", ROOTS, state.root, 90); changed = changed or c
    ImGui.SameLine(ctx)
    c, state.scale = combo("Scale", SCALES, state.scale, 170); changed = changed or c
    ImGui.SameLine(ctx)
    c, state.space = combo("Space", SPACES, state.space, 160); changed = changed or c
    c, state.length = combo("Length", LENGTHS, state.length, 160); changed = changed or c

    ImGui.Separator(ctx)
    c, state.steps = ImGui.SliderInt(ctx, "Steps", state.steps, 3, 128); changed = changed or c
    c, state.pulses = ImGui.SliderInt(ctx, "Pulses", state.pulses, 0, state.steps); changed = changed or c
    c, state.rotate = ImGui.SliderInt(ctx, "Rotate", state.rotate, -state.steps, state.steps); changed = changed or c
    c, state.density = ImGui.SliderDouble(ctx, "Density", state.density, 0, 1, "%.3f"); changed = changed or c
    c, state.surprise = ImGui.SliderDouble(ctx, "Path surprise", state.surprise, 0, 1, "%.3f"); changed = changed or c

    ImGui.Separator(ctx)
    c, state.octave = ImGui.SliderInt(ctx, "Base octave", state.octave, 0, 8); changed = changed or c
    c, state.span = ImGui.SliderInt(ctx, "Register span", state.span, 1, 6); changed = changed or c
    c, state.note_len = ImGui.SliderDouble(ctx, "Note length", state.note_len, 0.05, 1.5, "%.2f steps"); changed = changed or c
    c, state.velocity = ImGui.SliderInt(ctx, "Velocity", state.velocity, 1, 127); changed = changed or c
    c, state.jitter = ImGui.SliderInt(ctx, "Velocity jitter", state.jitter, 0, 48); changed = changed or c

    ImGui.Separator(ctx)
    c, state.channels = ImGui.SliderInt(ctx, "MIDI channels / source lanes", state.channels, 1, 16); changed = changed or c
    c, state.channel_mode = combo("Channel mode", CHANNEL_MODES, state.channel_mode, 180); changed = changed or c
    c, state.seed = ImGui.InputInt(ctx, "Seed", state.seed); changed = changed or c
    if changed then generate_preview() end

    if ImGui.Button(ctx, "Generate MIDI Item", 160, 30) then generate_item() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Refresh Preview", 130, 30) then generate_preview() end
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, COLORS.dim, status)
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
