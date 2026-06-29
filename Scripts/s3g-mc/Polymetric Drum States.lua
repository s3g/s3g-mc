-- @description Polymetric Drum States
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; MIDI Rule Library.lua
-- @category MIDI Composition
-- @render No
-- @method Creates an editable MIDI drum item from polymetric drum states. Each state stores Euclidean lane settings for a Superior-style or GM drum map, with either hard state changes or smooth interpolation between configurations.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local midi = dofile(script_dir .. "MIDI Rule Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Polymetric Drum States", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "Polymetric Drum States"
local ctx = ImGui.CreateContext(TITLE)
local open = true
local status = ""

local DRUM_TOKENS = { "KIK", "SNR", "CHH", "OHH", "PHH", "RIM", "LT", "MT", "HT", "FT", "CR1", "RD1" }
local DRUM_TOKEN_ITEMS = table.concat(DRUM_TOKENS, "\0") .. "\0"
local MAP_NAMES = { "Superior-style", "GM" }
local MAP_ITEMS = table.concat(MAP_NAMES, "\0") .. "\0"
local MAX_STATES = 16
local DEFAULT_CYCLE_BEATS = 4.0
local TRANSITION_NAMES = { "Jump", "Glide" }
local TRANSITION_ITEMS = table.concat(TRANSITION_NAMES, "\0") .. "\0"
local DURATION_NAMES = { "Trigger", "Step fraction" }
local DURATION_ITEMS = table.concat(DURATION_NAMES, "\0") .. "\0"
local GRID_NAMES = { "1/64", "1/32", "1/16", "1/8", "1/4", "1/2", "1 beat", "2 beats", "4 beats" }
local GRID_VALUES = { 1 / 16, 1 / 8, 1 / 4, 1 / 2, 1, 2, 4, 8, 16 }
local GRID_ITEMS = table.concat(GRID_NAMES, "\0") .. "\0"

local DRUM_MAPS = {
  ["GM"] = {
    KIK = 36, SNR = 38, RIM = 37, CHH = 42, PHH = 44, OHH = 46,
    LT = 45, MT = 47, HT = 50, FT = 41, CR1 = 49, RD1 = 51,
  },
  ["Superior-style"] = {
    KIK = 36, SNR = 38, RIM = 37, CHH = 61, PHH = 21, OHH = 46,
    LT = 41, MT = 45, HT = 48, FT = 43, CR1 = 49, RD1 = 51,
  },
}

local COLORS = {}

local function rgba(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

COLORS.bg = rgba(0.045, 0.050, 0.055, 1)
COLORS.panel = rgba(0.070, 0.076, 0.082, 1)
COLORS.edge = rgba(0.30, 0.32, 0.33, 1)
COLORS.grid = rgba(0.55, 0.60, 0.58, 0.20)
COLORS.dim = rgba(0.50, 0.55, 0.55, 1)
COLORS.text = rgba(0.82, 0.86, 0.86, 1)
COLORS.hot = rgba(1.00, 0.78, 0.22, 1)
COLORS.state = rgba(0.22, 0.74, 0.72, 1)
COLORS.play = rgba(1.00, 0.38, 0.28, 1)

local LANE_COLORS = {
  rgba(1.00, 0.74, 0.20, 1),
  rgba(0.12, 0.78, 0.94, 1),
  rgba(0.90, 0.26, 0.36, 1),
  rgba(0.30, 0.84, 0.38, 1),
  rgba(0.72, 0.48, 1.00, 1),
  rgba(1.00, 0.48, 0.12, 1),
  rgba(0.42, 0.58, 1.00, 1),
  rgba(0.86, 0.90, 0.28, 1),
  rgba(0.98, 0.52, 0.72, 1),
  rgba(0.42, 0.86, 0.72, 1),
  rgba(0.84, 0.62, 0.36, 1),
  rgba(0.62, 0.76, 0.96, 1),
}

local lane_count = 8
local map_index = 1
local midi_channel = 10
local seed = 1
local duration_mode = 1
local trigger_len_beats = 0.05
local step_note_len = 0.35
local global_density = 0.65
local min_lane_spacing = 0.0625
local min_same_pitch_spacing = 0.03125
local max_notes = 1500
local snap_to_grid = true
local grid_index = 1
local integer_state_lengths = true
local velocity_jitter = 7
local swing = 0.0
local transition_index = 1
local selected_state = 1
local preview_t = 0.0
local preview_play = false
local last_time = reaper.time_precise()
local states = {}
local state_lengths = {}
local lane_tokens = { "KIK", "SNR", "CHH", "OHH", "PHH", "RIM", "LT", "MT", "HT", "FT", "CR1", "RD1" }
local lane_enabled = {}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function grid_beats()
  return GRID_VALUES[grid_index] or 0.25
end

local function snap_beats(value, min_value, max_value)
  if not snap_to_grid then return value end
  local grid = math.max(0.0001, grid_beats())
  local snapped = math.floor((value / grid) + 0.5) * grid
  return clamp(snapped, min_value or grid, max_value or snapped)
end

local function slider_beats(label, value, min_value, max_value, format)
  local changed
  changed, value = ImGui.SliderDouble(ctx, label, value, min_value, max_value, format or "%.3f")
  if changed then value = snap_beats(value, min_value, max_value) end
  return changed, value
end

local function state_length_value(value)
  value = snap_beats(value, 1, 128)
  if integer_state_lengths then value = math.floor(value + 0.5) end
  return clamp(value, 1, 128)
end

local function lane_color(index)
  return LANE_COLORS[((index - 1) % #LANE_COLORS) + 1]
end

local function state_name(index)
  if index <= 26 then return string.char(64 + index) end
  return tostring(index)
end

local function total_state_beats()
  local total = 0
  for i = 1, #states do total = total + math.max(0.25, tonumber(state_lengths[i]) or 8) end
  return math.max(0.25, total)
end

local function current_start_qn()
  local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if end_time > start_time then return reaper.TimeMap2_timeToQN(0, start_time), true end
  return reaper.TimeMap2_timeToQN(0, reaper.GetCursorPosition()), false
end

local function tempo_at_qn(qn)
  local time = reaper.TimeMap2_QNToTime(0, qn)
  local bpm = reaper.TimeMap2_GetDividedBpmAtTime and reaper.TimeMap2_GetDividedBpmAtTime(0, time)
  return bpm or reaper.Master_GetTempo()
end

local function make_lane_state(lane, state)
  local base_steps = ({ 16, 15, 13, 12, 11, 10, 9, 7, 14, 17, 19, 21 })[lane] or 16
  local state_pulses = ({
    { 4, 5, 7, 6 },
    { 2, 3, 5, 4 },
    { 11, 9, 13, 7 },
    { 2, 1, 4, 3 },
  })[((lane - 1) % 4) + 1]
  return {
    steps = clamp(base_steps + (state - 1) * ((lane % 3) - 1), 4, 32),
    pulses = clamp(state_pulses[state] or 4, 0, 32),
    rotate = ((lane - 1) * 2 + (state - 1) * (lane % 5)) % 16,
    density = clamp(0.62 - (state - 1) * 0.08 + (lane % 3) * 0.025, 0.05, 0.85),
    velocity = clamp(96 - (lane - 1) * 3 + (state - 1) * 5, 1, 127),
    accent = 18,
  }
end

for state = 1, 4 do
  states[state] = {}
  state_lengths[state] = 16.0
  for lane = 1, 12 do
    states[state][lane] = make_lane_state(lane, state)
  end
end

for lane = 1, 12 do lane_enabled[lane] = lane <= lane_count end

local function map_name()
  return MAP_NAMES[map_index] or "Superior-style"
end

local function drum_pitch(token)
  local map = DRUM_MAPS[map_name()] or DRUM_MAPS["Superior-style"]
  return map[token] or 36
end

local function state_position_at_beat(beat)
  local total = total_state_beats()
  local shifted = beat % total
  local cursor = 0
  local a = #states
  local frac = 0
  for i = 1, #states do
    local span = math.max(0.25, state_lengths[i] or 8)
    if shifted < cursor + span or i == #states then
      a = i
      frac = clamp((shifted - cursor) / span, 0, 1)
      break
    end
    cursor = cursor + span
  end
  local b = (a % #states) + 1
  if transition_index == 1 then
    b = a
    frac = 0
  end
  return a, b, frac
end

local function interpolated_state(lane, beat)
  local a, b, frac = state_position_at_beat(beat)
  local sa = states[a][lane]
  local sb = states[b][lane]
  local steps = math.floor(lerp(sa.steps, sb.steps, frac) + 0.5)
  local pulses = math.floor(lerp(sa.pulses, sb.pulses, frac) + 0.5)
  return {
    steps = clamp(steps, 1, 64),
    pulses = clamp(pulses, 0, math.max(1, steps)),
    rotate = math.floor(lerp(sa.rotate, sb.rotate, frac) + 0.5),
    density = clamp(lerp(sa.density, sb.density, frac), 0, 1),
    velocity = clamp(math.floor(lerp(sa.velocity, sb.velocity, frac) + 0.5), 1, 127),
    accent = clamp(math.floor(lerp(sa.accent, sb.accent, frac) + 0.5), 0, 64),
  }
end

local function note_duration_beats(step_beats)
  if duration_mode == 1 then
    return math.max(0.005, math.min(trigger_len_beats, step_beats * 0.90))
  end
  return math.max(0.005, step_beats * step_note_len)
end

local function point_on_circle(cx, cy, radius, step, steps)
  local angle = -math.pi * 0.5 + (math.pi * 2 * step / math.max(1, steps))
  return cx + math.cos(angle) * radius, cy + math.sin(angle) * radius
end

local function draw_preview()
  local draw = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  local h = 340
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + h, COLORS.bg)
  ImGui.DrawList_AddRect(draw, x, y, x + w, y + h, COLORS.edge)

  local ring_w = math.max(300, w - 230)
  local cx = x + ring_w * 0.5
  local cy = y + h * 0.50
  local max_r = math.min(ring_w, h - 50) * 0.48
  local spacing = math.max(9, math.min(22, (max_r - 18) / math.max(1, lane_count)))

  local total_beats = total_state_beats()
  local preview_beat = preview_t * total_beats
  ImGui.DrawList_AddText(draw, x + 12, y + 10, COLORS.text, "POLYMETRIC DRUM STATES")
  local a, b, frac = state_position_at_beat(preview_beat)
  local state_label = transition_index == 1
    and string.format("state %s   beat %.2f", state_name(a), preview_beat)
    or string.format("%s -> %s   %.2f   beat %.2f", state_name(a), state_name(b), frac, preview_beat)
  ImGui.DrawList_AddText(draw, x + 12, y + 28, COLORS.dim, state_label)

  for lane = 1, lane_count do
    local state = interpolated_state(lane, preview_beat)
    local radius = max_r - (lane - 1) * spacing
    if radius < 14 then break end
    local col = lane_enabled[lane] and lane_color(lane) or COLORS.dim
    ImGui.DrawList_AddCircle(draw, cx, cy, radius, lane_enabled[lane] and COLORS.grid or rgba(0.25, 0.27, 0.27, 0.5), 96, 1)
    local pattern = midi.euclidean_pattern(state.pulses, state.steps, state.rotate)
    local hit_points = {}
    for step = 1, state.steps do
      local p1x, p1y = point_on_circle(cx, cy, radius - 3, step - 1, state.steps)
      local p2x, p2y = point_on_circle(cx, cy, radius + 3, step - 1, state.steps)
      ImGui.DrawList_AddLine(draw, p1x, p1y, p2x, p2y, pattern[step] and col or COLORS.grid, 1)
      if pattern[step] and lane_enabled[lane] then
        local hx, hy = point_on_circle(cx, cy, radius - spacing * 0.42, step - 1, state.steps)
        hit_points[#hit_points + 1] = { x = hx, y = hy }
        ImGui.DrawList_AddCircleFilled(draw, hx, hy, 3.2, col)
      end
    end
    for i = 1, #hit_points do
      local p = hit_points[i]
      local q = hit_points[(i % #hit_points) + 1]
      if q then ImGui.DrawList_AddLine(draw, p.x, p.y, q.x, q.y, col, 1.0) end
    end
  end

  local lx = x + ring_w + 10
  local ly = y + 26
  for lane = 1, lane_count do
    local state = interpolated_state(lane, preview_beat)
    local col = lane_enabled[lane] and lane_color(lane) or COLORS.dim
    local yy = ly + (lane - 1) * 22
    ImGui.DrawList_AddRectFilled(draw, lx, yy, lx + 10, yy + 10, col)
    ImGui.DrawList_AddText(draw, lx + 16, yy - 3, col,
      string.format("%02d %s %d/%d", lane, lane_tokens[lane] or "KIK", state.pulses, state.steps))
  end

  local tx = x + 18
  local ty = y + h - 42
  local tw = w - 36
  ImGui.DrawList_AddLine(draw, tx, ty, tx + tw, ty, COLORS.grid, 1)
  local cursor = 0
  for state = 1, #states do
    local span = math.max(0.25, state_lengths[state] or 8)
    local x1 = tx + tw * (cursor / total_beats)
    local x2 = tx + tw * ((cursor + span) / total_beats)
    local col = state == selected_state and COLORS.hot or COLORS.state
    ImGui.DrawList_AddRectFilled(draw, x1, ty - 9, x2, ty + 9, rgba(0.18, 0.42, 0.42, state == selected_state and 0.55 or 0.28))
    ImGui.DrawList_AddRect(draw, x1, ty - 9, x2, ty + 9, col)
    ImGui.DrawList_AddText(draw, x1 + 4, ty + 12, COLORS.text, state_name(state))
    if span >= 4 then
      ImGui.DrawList_AddText(draw, x1 + 4, ty - 26, COLORS.dim, string.format("%.0f-%.0f", cursor, cursor + span))
    end
    cursor = cursor + span
  end
  ImGui.DrawList_AddCircleFilled(draw, tx + tw * preview_t, ty, 4.5, COLORS.play)

  ImGui.SetCursorScreenPos(ctx, x, y + h + 10)
end

local function copy_state(src, dst)
  for lane = 1, 12 do
    local s = states[src][lane]
    local d = states[dst][lane]
    d.steps = s.steps
    d.pulses = s.pulses
    d.rotate = s.rotate
    d.density = s.density
    d.velocity = s.velocity
    d.accent = s.accent
  end
end

local function clone_state(src)
  local out = {}
  for lane = 1, 12 do
    local s = states[src][lane]
    out[lane] = {
      steps = s.steps,
      pulses = s.pulses,
      rotate = s.rotate,
      density = s.density,
      velocity = s.velocity,
      accent = s.accent,
    }
  end
  return out
end

local function add_state_after(index)
  if #states >= MAX_STATES then
    status = "Maximum state count is " .. tostring(MAX_STATES) .. "."
    return
  end
  index = clamp(index or #states, 1, #states)
  table.insert(states, index + 1, clone_state(index))
  table.insert(state_lengths, index + 1, state_lengths[index] or 16)
  selected_state = index + 1
  preview_t = 0
  status = "Added state " .. state_name(selected_state) .. "."
end

local function delete_state(index)
  if #states <= 1 then
    status = "Keep at least one state."
    return
  end
  index = clamp(index or selected_state, 1, #states)
  table.remove(states, index)
  table.remove(state_lengths, index)
  selected_state = clamp(index, 1, #states)
  preview_t = 0
  status = "Deleted state."
end

local function randomize_state(state)
  for lane = 1, 12 do
    local st = states[state][lane]
    st.steps = clamp(st.steps + math.random(-5, 5), 3, 64)
    st.pulses = clamp(st.pulses + math.random(-3, 3), 0, st.steps)
    st.rotate = math.random(0, math.max(1, st.steps - 1))
    st.density = clamp(st.density + (math.random() * 2 - 1) * 0.22, 0.05, 0.85)
    st.velocity = clamp(st.velocity + math.random(-16, 16), 1, 127)
    st.accent = clamp(st.accent + math.random(-8, 8), 0, 48)
  end
end

local function write_midi()
  midi.seed(seed)
  local track = midi.ensure_track()
  if not track then midi.show_error("Could not find or create a track.", TITLE) return end
  local duration_beats = total_state_beats()
  local start_qn = current_start_qn()
  local end_qn = start_qn + duration_beats
  local item, take = midi.create_midi_item(track, start_qn, end_qn, "Polymetric Drum States")
  if not take then midi.show_error("Could not create MIDI item.", TITLE) return end

  local event_count = 0
  local skipped_count = 0
  local note_channel = clamp(midi_channel - 1, 0, 15)
  local last_lane_note = {}
  local last_pitch_note = {}
  for lane = 1, lane_count do
    if lane_enabled[lane] then
      local beat = 0.0
      local guard = 0
      while beat < duration_beats - 0.0001 and guard < 10000 do
        guard = guard + 1
        local state = interpolated_state(lane, beat)
        local pattern = midi.euclidean_pattern(state.pulses, state.steps, state.rotate)
        local cycle = math.min(DEFAULT_CYCLE_BEATS, duration_beats - beat)
        local step_beats = cycle / math.max(1, state.steps)
        local hit_index = 0
        for step = 1, state.steps do
          if event_count >= max_notes then break end
          if pattern[step] and midi.chance(state.density * global_density) then
            hit_index = hit_index + 1
            local offset = (step - 1) * step_beats
            if swing ~= 0 and (step % 2) == 0 then
              offset = offset + step_beats * swing * 0.42
            end
            local note_start = start_qn + beat + offset
            if note_start < end_qn then
              local note_end = math.min(end_qn, note_start + note_duration_beats(step_beats))
              local pitch = drum_pitch(lane_tokens[lane])
              local lane_ok = not last_lane_note[lane] or (note_start - last_lane_note[lane]) >= min_lane_spacing
              local pitch_ok = not last_pitch_note[pitch] or (note_start - last_pitch_note[pitch]) >= min_same_pitch_spacing
              local vel = midi.velocity(state.velocity, state.accent, hit_index, 4, velocity_jitter)
              if lane_ok and pitch_ok then
                midi.insert_note_qn(take, note_start, note_end, note_channel, pitch, vel)
                last_lane_note[lane] = note_start
                last_pitch_note[pitch] = note_start
                event_count = event_count + 1
              else
                skipped_count = skipped_count + 1
              end
            end
          end
        end
        if event_count >= max_notes then break end
        beat = beat + DEFAULT_CYCLE_BEATS
      end
    end
    if event_count >= max_notes then break end
  end
  reaper.MIDI_Sort(take)
  reaper.UpdateItemInProject(item)
  reaper.UpdateArrange()
  status = string.format("Wrote %d %s notes over %.1f beats: %s, ch %d. Skipped %d.",
    event_count,
    DURATION_NAMES[duration_mode]:lower(),
    duration_beats,
    map_name(),
    midi_channel,
    skipped_count)
end

local function draw_global_controls()
  local changed
  local start_qn, using_time_selection = current_start_qn()
  local start_time = reaper.TimeMap2_QNToTime(0, start_qn)
  local start_measures = 0
  local start_beats = 0
  local ok, measures, cml, fullbeats = reaper.TimeMap2_timeToBeats(0, start_time)
  if ok ~= nil then
    start_measures = measures or 0
    start_beats = fullbeats or 0
  else
    start_measures = 0
    start_beats = start_qn
  end
  ImGui.TextColored(ctx, COLORS.dim, string.format(
    "Start: %s | QN %.2f | %.2f sec | tempo %.2f BPM",
    using_time_selection and "time selection" or "edit cursor",
    start_qn,
    start_time,
    tempo_at_qn(start_qn)))
  ImGui.TextColored(ctx, COLORS.dim, string.format(
    "State timeline: %.1f beats, %d states | approx measure %d beat %.2f",
    total_state_beats(),
    #states,
    start_measures + 1,
    start_beats + 1))
  changed, lane_count = ImGui.SliderInt(ctx, "Lanes", lane_count, 1, 12)
  for lane = 1, 12 do
    if lane > lane_count then lane_enabled[lane] = false elseif lane_enabled[lane] == nil then lane_enabled[lane] = true end
  end
  local map_zero = map_index - 1
  changed, map_zero = ImGui.Combo(ctx, "Drum map", map_zero, MAP_ITEMS)
  if changed then map_index = map_zero + 1 end
  changed, midi_channel = ImGui.SliderInt(ctx, "MIDI channel", midi_channel, 1, 16)
  changed, snap_to_grid = ImGui.Checkbox(ctx, "Snap beat sliders", snap_to_grid)
  ImGui.SameLine(ctx)
  local grid_zero = grid_index - 1
  ImGui.SetNextItemWidth(ctx, 112)
  changed, grid_zero = ImGui.Combo(ctx, "Grid", grid_zero, GRID_ITEMS)
  if changed then grid_index = grid_zero + 1 end
  local duration_zero = duration_mode - 1
  changed, duration_zero = ImGui.Combo(ctx, "Note duration mode", duration_zero, DURATION_ITEMS)
  if changed then duration_mode = duration_zero + 1 end
  if duration_mode == 1 then
    changed, trigger_len_beats = slider_beats("Trigger length beats", trigger_len_beats, 0.005, 0.25, "%.3f")
  else
    changed, step_note_len = ImGui.SliderDouble(ctx, "Step fraction length", step_note_len, 0.05, 1.5, "%.2f steps")
  end
  local transition_zero = transition_index - 1
  changed, transition_zero = ImGui.Combo(ctx, "Transition mode", transition_zero, TRANSITION_ITEMS)
  if changed then transition_index = transition_zero + 1 end
  changed, integer_state_lengths = ImGui.Checkbox(ctx, "Integer state lengths", integer_state_lengths)
  if changed and integer_state_lengths then
    for i = 1, #state_lengths do state_lengths[i] = state_length_value(state_lengths[i] or 16) end
  end
  if ImGui.CollapsingHeader(ctx, "Advanced generation limits") then
    changed, global_density = ImGui.SliderDouble(ctx, "Global probability trim", global_density, 0.05, 1.0, "%.3f")
    changed, min_lane_spacing = slider_beats("Min lane spacing beats", min_lane_spacing, 0, 0.5, "%.4f")
    changed, min_same_pitch_spacing = slider_beats("Min same-drum spacing beats", min_same_pitch_spacing, 0, 0.5, "%.4f")
    changed, max_notes = ImGui.SliderInt(ctx, "Max generated notes", max_notes, 64, 8000)
    changed, swing = ImGui.SliderDouble(ctx, "Swing", swing, -1.0, 1.0, "%.2f")
    changed, velocity_jitter = ImGui.SliderInt(ctx, "Velocity jitter", velocity_jitter, 0, 32)
    changed, seed = ImGui.InputInt(ctx, "Seed", seed)
  end
end

local function draw_preview_controls()
  local changed
  changed, preview_t = ImGui.SliderDouble(ctx, "Timeline preview", preview_t, 0, 1, "%.3f")
  if ImGui.Button(ctx, preview_play and "Stop Preview" or "Play Preview", 130, 26) then
    preview_play = not preview_play
    last_time = reaper.time_precise()
  end
  local total = total_state_beats()
  local cursor = 0
  for state = 1, #states do
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, state_name(state) .. "##preview_state_" .. tostring(state), 32, 26) then
      preview_t = cursor / total
      selected_state = state
    end
    cursor = cursor + math.max(0.25, state_lengths[state] or 8)
  end
end

local function draw_state_editor()
  ImGui.Separator(ctx)
  ImGui.Text(ctx, "State")
  for state = 1, #states do
    if state > 1 then ImGui.SameLine(ctx) end
    local label = (selected_state == state and "*" or "") .. state_name(state) .. "##state_select_" .. tostring(state)
    if ImGui.Button(ctx, label, 42, 26) then
      selected_state = state
      preview_t = (state - 1) / #states
    end
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Copy Prev", 86, 26) then
    local prev = selected_state - 1
    if prev < 1 then prev = #states end
    copy_state(prev, selected_state)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Copy Next", 86, 26) then
    local next_state = (selected_state % #states) + 1
    copy_state(next_state, selected_state)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Randomize State", 132, 26) then randomize_state(selected_state) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Add State", 92, 26) then add_state_after(selected_state) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Delete State", 104, 26) then delete_state(selected_state) end

  local len = state_lengths[selected_state] or 16
  local changed
  changed, len = slider_beats("Selected state length beats", len, 1, 128, "%.1f")
  if changed then state_lengths[selected_state] = state_length_value(len) end
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, 92)
  changed, len = ImGui.InputDouble(ctx, "Beats##state_length_input", state_lengths[selected_state] or len, 1, 4, "%.2f")
  if changed then state_lengths[selected_state] = state_length_value(len) end
  local state_start = 0
  for i = 1, selected_state - 1 do state_start = state_start + math.max(0.25, state_lengths[i] or 8) end
  local state_end = state_start + math.max(0.25, state_lengths[selected_state] or 8)
  ImGui.TextColored(ctx, COLORS.dim, string.format(
    "Selected state %s: item beat %.2f to %.2f",
    state_name(selected_state),
    state_start,
    state_end))

  if ImGui.BeginChild(ctx, "##state_lanes", 0, 330) then
    for lane = 1, lane_count do
      local st = states[selected_state][lane]
      ImGui.PushID(ctx, lane)
      ImGui.Separator(ctx)
      local enabled
      enabled, lane_enabled[lane] = ImGui.Checkbox(ctx, "##enabled", lane_enabled[lane])
      ImGui.SameLine(ctx)
      ImGui.TextColored(ctx, lane_color(lane), string.format("%02d", lane))
      ImGui.SameLine(ctx)
      local current_token = 0
      for index, token in ipairs(DRUM_TOKENS) do
        if token == lane_tokens[lane] then current_token = index - 1 break end
      end
      ImGui.SetNextItemWidth(ctx, 78)
      local changed, token_index = ImGui.Combo(ctx, "Drum", current_token, DRUM_TOKEN_ITEMS)
      if changed then lane_tokens[lane] = DRUM_TOKENS[token_index + 1] or "KIK" end
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, 76)
      changed, st.steps = ImGui.SliderInt(ctx, "Steps", st.steps, 1, 64)
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, 76)
      st.pulses = math.min(st.pulses, st.steps)
      changed, st.pulses = ImGui.SliderInt(ctx, "Pulses", st.pulses, 0, st.steps)
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, 76)
      changed, st.rotate = ImGui.SliderInt(ctx, "Rotate", st.rotate, -st.steps, st.steps)
      ImGui.SetNextItemWidth(ctx, 130)
      changed, st.density = ImGui.SliderDouble(ctx, "Hit probability", st.density, 0, 1, "%.2f")
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, 130)
      changed, st.velocity = ImGui.SliderInt(ctx, "Velocity", st.velocity, 1, 127)
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, 130)
      changed, st.accent = ImGui.SliderInt(ctx, "Accent", st.accent, 0, 64)
      ImGui.PopID(ctx)
    end
    ImGui.EndChild(ctx)
  end
end

local function draw_footer()
  ImGui.Separator(ctx)
  if ImGui.Button(ctx, "Generate MIDI Item", 170, 32) then write_midi() end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Reset Defaults", 120, 32) then
    states = {}
    state_lengths = {}
    for state = 1, 4 do
      states[state] = {}
      state_lengths[state] = 16.0
      for lane = 1, 12 do states[state][lane] = make_lane_state(lane, state) end
    end
    lane_tokens = { "KIK", "SNR", "CHH", "OHH", "PHH", "RIM", "LT", "MT", "HT", "FT", "CR1", "RD1" }
    selected_state = 1
    preview_t = 0
    status = "Reset drum states."
  end
  ImGui.SameLine(ctx)
  ImGui.TextColored(ctx, COLORS.dim, status)
end

local function loop()
  local now = reaper.time_precise()
  if preview_play then
    local dt = now - last_time
    preview_t = (preview_t + dt / 8.0) % 1.0
  end
  last_time = now

  ImGui.SetNextWindowSize(ctx, 980, 900, ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    draw_preview()
    draw_preview_controls()
    draw_global_controls()
    draw_state_editor()
    draw_footer()
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
