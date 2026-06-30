-- @description Musical Space
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; MIDI Rule Library.lua
-- @category MIDI Composition
-- @render No
-- @method Creates a new editable MIDI item from a path through a chosen musical space. The rule set combines scale-degree movement, multiple rhythm models, probability, velocity shaping, voicing, and MIDI-channel spatial focus for procedural synths or general algorithmic composition.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local midi = dofile(script_dir .. "MIDI Rule Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Musical Space", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "Musical Space"
local ctx = ImGui.CreateContext(TITLE)
local open = true
local status = ""

local ROOTS = midi.ROOT_NAMES
local SCALES = midi.SCALE_NAMES
local SPACES = {
  "Scale walk",
  "Contour",
  "Triadic",
  "Axis mirror",
  "Pendulum",
  "Orbit",
  "Spiral",
  "Constellation",
  "Gravity well",
  "Mirror pair",
  "Chord field",
  "Step / leap",
  "Brownian",
  "Attractor nodes",
  "Tidal",
  "Register gates",
}
local CHANNEL_MODES = { "Single channel", "Round-robin", "Path position", "Random" }
local VOICINGS = { "Mono", "Dyad", "Triad", "Quartal", "Cluster" }
local RHYTHM_MODES = {
  "Euclidean grid",
  "Swing grid",
  "Aksak cycle",
  "Burst / rest",
  "Brownian clock",
  "Contour pulse",
  "Clave cells",
  "Fibonacci gaps",
  "Morse cells",
  "Irrational drift",
  "Logistic clock",
}
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
  rhythm_mode = 1,
  rhythm_variation = 0.35,
  density = 0.92,
  surprise = 0.24,
  octave = 3,
  span = 3,
  note_len = 0.72,
  note_len_variation = 0.22,
  velocity = 78,
  accent = 28,
  jitter = 8,
  channels = 8,
  channel_mode = 3,
  single_channel = 1,
  voicing = 1,
  voicing_variation = 0.0,
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

local VOICE_COLORS = {
  color(0.95, 0.74, 0.28, 1),
  color(0.08, 0.78, 0.92, 1),
  color(0.96, 0.30, 0.42, 1),
  color(0.48, 0.86, 0.40, 1),
  color(0.72, 0.48, 1.00, 1),
}

local function voice_color(voice)
  return VOICE_COLORS[((math.max(1, math.floor(voice or 1)) - 1) % #VOICE_COLORS) + 1]
end

local PC_NAMES = { "C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B" }

local preview = {}
local preview_t = 0.0
local preview_play = false
local preview_sync_project_bpm = true
local preview_speed = 1.0
local preview_loop_seconds = 8.0
local last_time = reaper.time_precise()

local function combo(label, labels, value, width)
  ImGui.SetNextItemWidth(ctx, width or 160)
  local changed, next_value = ImGui.Combo(ctx, label, value - 1, table.concat(labels, "\0") .. "\0")
  return changed, next_value + 1
end

local function choose_from(list)
  return list[math.floor(math.random() * #list) + 1]
end

local function next_degree(space, degree, hit_index, axis, scale_len)
  local surprise = state.surprise
  if space == "Scale walk" or space == "Contour" or space == "Triadic" then
    return degree + midi.weighted_step(space, surprise)
  elseif space == "Axis mirror" then
    degree = degree + midi.weighted_step("Contour", surprise)
    if hit_index % 2 == 0 then degree = axis - (degree - axis) end
    return degree
  elseif space == "Pendulum" then
    local span = math.max(3, math.floor(3 + surprise * 10))
    local phase = (hit_index - 1) % (span * 2)
    local offset = phase < span and phase or (span * 2 - phase)
    return axis + ((hit_index % 2 == 0) and offset or -offset)
  elseif space == "Orbit" then
    local orbit = { 0, 2, 4, 2, 0, -2, -4, -2 }
    return axis + orbit[((hit_index - 1) % #orbit) + 1] + (math.random() < surprise and choose_from({ -1, 1, 3, -3 }) or 0)
  elseif space == "Spiral" then
    local direction = math.random() < 0.5 and -1 or 1
    return degree + direction + (hit_index % math.max(2, scale_len) == 0 and direction * 2 or 0)
  elseif space == "Constellation" then
    local points = { 0, 2, 4, 7, 9, 12, 14 }
    return choose_from(points) + (math.random() < surprise and choose_from({ -1, 1, 5, -5 }) or 0)
  elseif space == "Gravity well" then
    local drift = choose_from({ -2, -1, 1, 2, 3, -3 })
    degree = degree + drift
    local pull = math.floor((axis - degree) * (0.18 + surprise * 0.32) + 0.5)
    return degree + pull
  elseif space == "Mirror pair" then
    local source = degree + choose_from({ 1, 2, 3, -1, -2, -3 })
    return hit_index % 2 == 0 and axis - (source - axis) or source
  elseif space == "Chord field" then
    local field = { 0, 2, 4, 5, 7, 9, 11, 12, 14 }
    return field[((hit_index - 1) % #field) + 1] + (math.random() < surprise and choose_from({ -2, 2, 5 }) or 0)
  elseif space == "Step / leap" then
    return degree + (hit_index % 3 == 0 and choose_from({ -7, -5, 5, 7, 9, -9 }) or choose_from({ -2, -1, 1, 2 }))
  elseif space == "Brownian" then
    return degree + (math.random() < surprise and choose_from({ -6, -5, 5, 6 }) or choose_from({ -1, 0, 1 }))
  elseif space == "Attractor nodes" then
    local nodes = { -7, -3, 0, 4, 7, 11, 14 }
    local target = choose_from(nodes)
    return degree + math.floor((target - degree) * (0.35 + surprise * 0.40) + 0.5)
  elseif space == "Tidal" then
    local wave = math.sin(hit_index * (0.55 + surprise * 1.15))
    return math.floor(axis + wave * (4 + surprise * 12) + 0.5)
  elseif space == "Register gates" then
    local gate = math.floor((hit_index - 1) / math.max(1, math.floor(2 + surprise * 5))) % 4
    return choose_from({ 0, 2, 4, 7 }) + gate * scale_len
  end
  return degree + midi.weighted_step("Contour", surprise)
end

local function voicing_offsets(base_degree)
  local mode = VOICINGS[state.voicing] or "Mono"
  local offsets
  if mode == "Dyad" then offsets = { 0, 4 }
  elseif mode == "Triad" then offsets = { 0, 2, 4 }
  elseif mode == "Quartal" then offsets = { 0, 3, 6 }
  elseif mode == "Cluster" then offsets = { 0, 1, 2, 4 }
  else offsets = { 0 } end

  local variation = midi.clamp(state.voicing_variation or 0, 0, 1)
  if variation <= 0 or #offsets <= 1 then return offsets end

  local out = { offsets[1] }
  for i = 2, #offsets do
    if math.random() > variation * 0.55 then out[#out + 1] = offsets[i] end
  end
  if math.random() < variation * 0.45 then
    out[#out + 1] = choose_from({ -2, 5, 7, 9 })
  end
  if #out > 1 and math.random() < variation * 0.35 then
    local shift = choose_from({ -7, -5, 5, 7 })
    out[1] = out[1] + shift
  end
  table.sort(out)
  return out
end

local function note_length_scale(base_scale, hit_index, voice)
  local variation = midi.clamp(state.note_len_variation or 0, 0, 1)
  local scale = tonumber(base_scale) or 1.0
  if variation > 0 and (voice or 1) <= 1 then
    local random_span = (math.random() * 2 - 1) * variation
    local phrase_shape = math.sin((hit_index or 1) * 0.71 + (state.rotate or 0) * 0.11) * variation * 0.35
    scale = scale * (1.0 + random_span + phrase_shape)
  end
  if (voice or 1) > 1 then
    scale = scale * (1.0 - math.min(0.28, ((voice or 1) - 1) * 0.08 * (0.5 + variation)))
  end
  return midi.clamp(scale, 0.12, 3.0)
end

local function add_candidate(list, time, step, length_scale)
  time = midi.clamp(time or 0, 0, 0.999999)
  list[#list + 1] = {
    time = time,
    step = math.max(1, math.min(state.steps, math.floor(step or (time * math.max(1, state.steps - 1) + 1.5)))),
    length_scale = length_scale or 1.0,
  }
end

local function rhythm_candidates()
  local mode = RHYTHM_MODES[state.rhythm_mode] or "Euclidean grid"
  local candidates = {}
  local steps = math.max(1, state.steps)
  if (state.pulses or 0) <= 0 then return candidates end
  local pulses = math.max(1, state.pulses)
  local variation = midi.clamp(state.rhythm_variation or 0, 0, 1)

  if mode == "Euclidean grid" then
    local pattern = midi.euclidean_pattern(state.pulses, state.steps, state.rotate)
    for step = 1, steps do
      if pattern[step] then add_candidate(candidates, (step - 1) / steps, step, 1.0) end
    end
  elseif mode == "Swing grid" then
    local pattern = midi.euclidean_pattern(state.pulses, state.steps, state.rotate)
    local swing = 0.06 + variation * 0.16
    for step = 1, steps do
      if pattern[step] then
        local t = (step - 1) / steps
        if step % 2 == 0 then t = t + swing / steps end
        add_candidate(candidates, t, step, step % 2 == 0 and 0.88 or 1.12)
      end
    end
  elseif mode == "Aksak cycle" then
    local cycle = { 2, 2, 3, 2, 3, 3, 2 }
    local total = 0
    for i = 1, pulses do total = total + cycle[((i - 1 + state.rotate) % #cycle) + 1] end
    local acc = 0
    for i = 1, pulses do
      local gap = cycle[((i - 1 + state.rotate) % #cycle) + 1]
      add_candidate(candidates, acc / math.max(1, total), nil, gap / 2.5)
      acc = acc + gap
    end
  elseif mode == "Burst / rest" then
    local count = math.max(1, pulses + math.floor(pulses * variation))
    local time = 0
    for i = 1, count do
      add_candidate(candidates, time, nil, 0.55 + variation * 0.55)
      local in_burst = (i % 4) ~= 0
      time = time + (in_burst and (0.025 + 0.055 * (1 - variation)) or (0.16 + 0.20 * variation))
      if time >= 1 then break end
    end
  elseif mode == "Brownian clock" then
    local count = math.max(1, pulses + math.floor(pulses * 1.5))
    local gap = 1 / count
    local time = 0
    for i = 1, count do
      add_candidate(candidates, time, nil, 0.8 + math.random() * 0.6)
      gap = midi.clamp(gap + (math.random() * 2 - 1) * 0.045 * variation, 0.015, 0.22)
      time = time + gap
      if time >= 1 then break end
    end
  elseif mode == "Contour pulse" then
    local count = math.max(1, pulses + math.floor(pulses * variation))
    local weights = {}
    local total = 0
    for i = 1, count do
      local w = 0.5 + (math.sin(i * 0.9 + state.rotate * 0.3) + 1) * (0.45 + variation * 0.75)
      weights[i] = w
      total = total + w
    end
    local acc = 0
    for i = 1, count do
      add_candidate(candidates, acc / math.max(1, total), nil, weights[i])
      acc = acc + weights[i]
    end
  elseif mode == "Clave cells" then
    local cells = { 0, 3, 6, 10, 12, 16, 19, 22, 26, 29 }
    local span = 32
    for i = 1, math.min(#cells, math.max(3, pulses + 3)) do
      local shifted = (cells[((i - 1 + state.rotate) % #cells) + 1] % span) / span
      add_candidate(candidates, shifted, nil, (i % 3 == 1) and 1.2 or 0.8)
    end
    table.sort(candidates, function(a, b) return a.time < b.time end)
  elseif mode == "Fibonacci gaps" then
    local gaps = { 1, 1, 2, 3, 5, 8, 13 }
    local count = math.max(1, pulses + math.floor(pulses * variation))
    local total = 0
    for i = 1, count do total = total + gaps[((i - 1 + state.rotate) % #gaps) + 1] end
    local acc = 0
    for i = 1, count do
      local gap = gaps[((i - 1 + state.rotate) % #gaps) + 1]
      add_candidate(candidates, acc / math.max(1, total), nil, midi.clamp(gap / 3.0, 0.45, 1.8))
      acc = acc + gap
    end
  elseif mode == "Morse cells" then
    local cells = {
      { 1, 1, 3, 3, 1 },
      { 3, 1, 1, 1, 3 },
      { 1, 3, 1, 3, 1, 1 },
      { 3, 3, 1, 1, 3, 1 },
    }
    local cell = cells[((state.rotate % #cells) + #cells) % #cells + 1]
    local repeats = math.max(1, math.ceil(pulses / #cell))
    local total = 0
    for i = 1, repeats * #cell do total = total + cell[((i - 1) % #cell) + 1] end
    local acc = 0
    for i = 1, repeats * #cell do
      if #candidates >= pulses + math.floor(pulses * variation * 0.5) then break end
      local gap = cell[((i - 1) % #cell) + 1]
      add_candidate(candidates, acc / math.max(1, total), nil, gap == 1 and 0.62 or 1.28)
      acc = acc + gap
    end
  elseif mode == "Irrational drift" then
    local count = math.max(1, pulses + math.floor(pulses * 1.25))
    local phase = (state.rotate % math.max(1, steps)) / math.max(1, steps)
    for i = 1, count do
      local t = (phase + i * 0.61803398875) % 1
      t = (t + (math.random() * 2 - 1) * 0.025 * variation) % 1
      add_candidate(candidates, t, nil, 0.75 + math.random() * 0.6)
    end
    table.sort(candidates, function(a, b) return a.time < b.time end)
  elseif mode == "Logistic clock" then
    local count = math.max(1, pulses + math.floor(pulses * 1.4))
    local x = 0.21 + ((state.rotate % math.max(1, steps)) / math.max(1, steps)) * 0.58
    local r = 3.55 + variation * 0.42
    for i = 1, count do
      x = r * x * (1 - x)
      local t = midi.clamp(x, 0, 0.999999)
      add_candidate(candidates, t, nil, 0.55 + (1 - math.abs(0.5 - x) * 2) * 0.95)
    end
    table.sort(candidates, function(a, b) return a.time < b.time end)
  end

  return candidates
end

local function generate_preview()
  local root = ROOTS[state.root]
  local scale = SCALES[state.scale]
  local space = SPACES[state.space]
  local degree = 0
  local scale_len = #(midi.SCALES[scale] or midi.SCALES.Major)
  local axis = math.floor((scale_len - 1) / 2)
  local events = {}
  midi.seed(state.seed)
  local rhythm = rhythm_candidates()
  local hit_index = 0
  for _, candidate in ipairs(rhythm) do
    if midi.chance(state.density) then
      hit_index = hit_index + 1
      if hit_index > 1 then degree = next_degree(space, degree, hit_index, axis, scale_len) end
      local offsets = voicing_offsets(degree)
      local hit_length_scale = note_length_scale(candidate.length_scale or 1.0, hit_index, 1)
      for voice, offset in ipairs(offsets) do
        if offset then
          local voice_degree = degree + offset
          local pitch = midi.scale_pitch(root, scale, voice_degree, state.octave, state.span)
          local channel = 0
          if CHANNEL_MODES[state.channel_mode] == "Single channel" then
            channel = (state.single_channel or 1) - 1
          elseif CHANNEL_MODES[state.channel_mode] == "Round-robin" then
            channel = (hit_index + voice - 2) % math.max(1, state.channels)
          elseif CHANNEL_MODES[state.channel_mode] == "Path position" then
            channel = math.floor(((pitch - 24) / 72) * math.max(1, state.channels - 1) + 0.5)
          elseif CHANNEL_MODES[state.channel_mode] == "Random" then
            channel = math.floor(math.random() * math.max(1, state.channels))
          end
          events[#events + 1] = {
            step = candidate.step,
            time = candidate.time,
            degree = voice_degree,
            pitch = pitch,
            channel = midi.clamp(channel, 0, math.min(15, math.max(0, state.channels - 1))),
            velocity = midi.clamp(midi.velocity(state.velocity, state.accent, hit_index, 4, state.jitter) - (voice - 1) * 7, 1, 127),
            voice = voice,
            length_scale = note_length_scale(hit_length_scale, hit_index, voice),
          }
        end
      end
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

local function note_name(pitch)
  pitch = midi.clamp(math.floor(tonumber(pitch) or 60), 0, 127)
  return (PC_NAMES[(pitch % 12) + 1] or "C") .. tostring(math.floor(pitch / 12) - 1)
end

local function current_start_qn()
  local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if end_time > start_time then return reaper.TimeMap2_timeToQN(0, start_time) end
  return reaper.TimeMap2_timeToQN(0, reaper.GetCursorPosition())
end

local function tempo_at_qn(qn)
  local time = reaper.TimeMap2_QNToTime(0, qn)
  local bpm = reaper.TimeMap2_GetDividedBpmAtTime and reaper.TimeMap2_GetDividedBpmAtTime(0, time)
  return bpm or reaper.Master_GetTempo()
end

local function current_preview_event()
  if #preview == 0 then return nil end
  local active_event = nil
  local active_index = nil
  for index, event in ipairs(preview) do
    if (event.time or 0) <= preview_t then
      active_event = event
      active_index = index
    else
      break
    end
  end
  return active_event, active_index
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
  local h = 330
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, COLORS.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, COLORS.edge)
  local active_event, active_index = current_preview_event()
  local active_time = active_event and active_event.time or nil

  local compass_w = math.min(190, w * 0.25)
  local map_x = x + 18
  local map_y = y + 50
  local map_w = math.max(280, w - compass_w - 46)
  local map_h = h - 76
  local compass_cx = x + w - compass_w * 0.5 - 14
  local compass_cy = y + 150
  local pc_radius = math.min(74, compass_w * 0.36)
  local scale_lookup = scale_pc_lookup()

  local degree_min, degree_max = 0, 0
  for _, event in ipairs(preview) do
    degree_min = math.min(degree_min, event.degree or 0)
    degree_max = math.max(degree_max, event.degree or 0)
  end
  if degree_max == degree_min then
    degree_min = degree_min - 1
    degree_max = degree_max + 1
  end
  local degree_pad = math.max(2, math.floor((degree_max - degree_min) * 0.15 + 0.5))
  degree_min = degree_min - degree_pad
  degree_max = degree_max + degree_pad

  local function event_xy(event)
    local t = event.time or ((event.step or 1) - 1) / math.max(1, state.steps)
    local degree_norm = ((event.degree or 0) - degree_min) / math.max(1, degree_max - degree_min)
    local channel_offset = ((event.channel or 0) / math.max(1, state.channels - 1) - 0.5) * 16
    return map_x + t * map_w, map_y + map_h * (1 - degree_norm) + channel_offset
  end

  ImGui.DrawList_AddText(draw_list, x + 12, y + 10, COLORS.dim, "MUSICAL SPACE PATH")
  ImGui.DrawList_AddText(draw_list, x + 12, y + 28, COLORS.dim,
    string.format("%s %s  %s  %s",
      ROOTS[state.root] or "C",
      SCALES[state.scale] or "Major",
      SPACES[state.space] or "Scale walk",
      RHYTHM_MODES[state.rhythm_mode] or "Euclidean grid"))

  ImGui.DrawList_AddRectFilled(draw_list, map_x, map_y, map_x + map_w, map_y + map_h, color(0.04, 0.045, 0.047, 1))
  ImGui.DrawList_AddRect(draw_list, map_x, map_y, map_x + map_w, map_y + map_h, COLORS.edge)
  for channel = 0, math.max(0, state.channels - 1) do
    local band_y1 = map_y + map_h * (channel / math.max(1, state.channels))
    local band_y2 = map_y + map_h * ((channel + 1) / math.max(1, state.channels))
    local alpha = channel % 2 == 0 and 0.08 or 0.035
    ImGui.DrawList_AddRectFilled(draw_list, map_x, band_y1, map_x + map_w, band_y2, color(0.12, 0.22, 0.22, alpha))
  end
  for line = 0, 4 do
    local ly = map_y + map_h * (line / 4)
    local degree = degree_max - (degree_max - degree_min) * (line / 4)
    ImGui.DrawList_AddLine(draw_list, map_x, ly, map_x + map_w, ly, color(0.55, 0.60, 0.58, 0.18), 1)
    ImGui.DrawList_AddText(draw_list, map_x + 5, ly - 8, color(0.50, 0.55, 0.54, 0.72), string.format("d%+.0f", degree))
  end
  for step = 1, state.steps do
    local tx = map_x + map_w * ((step - 1) / math.max(1, state.steps))
    if step == 1 or step == state.steps or step % math.max(1, math.floor(state.steps / 8)) == 1 then
      ImGui.DrawList_AddLine(draw_list, tx, map_y, tx, map_y + map_h, color(0.55, 0.60, 0.58, 0.13), 1)
    end
  end
  local rhythm_marks = {}
  for _, event in ipairs(preview) do
    if event.voice == 1 then rhythm_marks[#rhythm_marks + 1] = event end
  end
  for _, event in ipairs(rhythm_marks) do
    local tx = map_x + map_w * (event.time or 0)
    ImGui.DrawList_AddLine(draw_list, tx, map_y + 4, tx, map_y + map_h - 4, color(0.28, 0.72, 0.68, 0.22), 1)
    ImGui.DrawList_AddCircleFilled(draw_list, tx, map_y + map_h - 9, 3.2, COLORS.line)
  end

  local last_x, last_y = nil, nil
  for index, event in ipairs(preview) do
    local px, py = event_xy(event)
    if last_x then ImGui.DrawList_AddLine(draw_list, last_x, last_y, px, py, COLORS.line, 1.6) end
    local radius = 3.8 + (event.velocity / 127) * 3.2
    local event_col = voice_color(event.voice)
    local shadow = color(0.0, 0.0, 0.0, 0.42)
    local dur_x = math.min(map_x + map_w, px + map_w * ((state.note_len or 0.72) / math.max(1, state.steps)) * (event.length_scale or 1))
    ImGui.DrawList_AddLine(draw_list, px, py, dur_x, py, color(0.95, 0.74, 0.28, 0.38), 2.0)
    ImGui.DrawList_AddCircleFilled(draw_list, px + 1.5, py + 1.5, radius + 1.4, shadow)
    ImGui.DrawList_AddCircleFilled(draw_list, px, py, radius, event_col)
    ImGui.DrawList_AddText(draw_list, px + 6, py - 7, COLORS.dim, tostring(event.channel + 1))
    if active_time and math.abs((event.time or 0) - active_time) < 0.000001 then
      ImGui.DrawList_AddCircleFilled(draw_list, px, py, radius + 5.0, COLORS.panel)
      ImGui.DrawList_AddCircleFilled(draw_list, px, py, radius + 2.5, event_col)
      ImGui.DrawList_AddCircle(draw_list, px, py, radius + 6.2, COLORS.text, 24, 1.7)
    end
    if index == 1 or index == #preview then
      ImGui.DrawList_AddText(draw_list, px + 8, py + 6, COLORS.text, index == 1 and "start" or "end")
    end
    last_x, last_y = px, py
  end

  local play_x = map_x + map_w * preview_t
  ImGui.DrawList_AddLine(draw_list, play_x, map_y - 6, play_x, map_y + map_h + 6, COLORS.hit, 1.2)

  ImGui.DrawList_AddText(draw_list, compass_cx - 58, y + 10, COLORS.dim, "PITCH COMPASS")
  ImGui.DrawList_AddCircle(draw_list, compass_cx, compass_cy, pc_radius, COLORS.muted, 96, 1)
  for pc = 0, 11 do
    local px, py = point_on_circle(compass_cx, compass_cy, pc_radius, pc, 12)
    local active = scale_lookup[pc] == true
    ImGui.DrawList_AddCircleFilled(draw_list, px, py, active and 4.5 or 2.2, active and COLORS.line or COLORS.muted)
    ImGui.DrawList_AddText(draw_list, px + 6, py - 6, active and COLORS.text or COLORS.dim, PC_NAMES[pc + 1])
  end
  for index, event in ipairs(preview) do
    local pc = pitch_class(event.pitch)
    local register_r = pc_radius * (0.34 + 0.42 * ((event.channel or 0) / math.max(1, state.channels - 1)))
    local px, py = point_on_circle(compass_cx, compass_cy, register_r, pc, 12)
    local active = active_time and math.abs((event.time or 0) - active_time) < 0.000001
    ImGui.DrawList_AddCircleFilled(draw_list, px, py, active and 4.8 or 2.8, active and COLORS.text or voice_color(event.voice))
  end

  local active_text = active_event and
    string.format("event %d  %s  ch %d  degree %+d  len %.2fx  v%d",
      active_index,
      note_name(active_event.pitch),
      active_event.channel + 1,
      active_event.degree,
      active_event.length_scale or 1,
      active_event.velocity or 1) or
    "no events"
  ImGui.DrawList_AddText(draw_list, compass_cx - 80, y + h - 58, COLORS.dim,
    tostring(#preview) .. " events")
  ImGui.DrawList_AddText(draw_list, compass_cx - 80, y + h - 40, COLORS.text, active_text)

  local tx = x + 18
  local ty = y + h - 10
  local tw = w - 36
  ImGui.DrawList_AddLine(draw_list, tx, ty, tx + tw, ty, color(0.55, 0.60, 0.58, 0.32), 1)
  ImGui.DrawList_AddRectFilled(draw_list, tx, ty - 3, tx + tw, ty + 3, color(0.18, 0.42, 0.42, 0.22))
  ImGui.DrawList_AddCircleFilled(draw_list, tx + tw * preview_t, ty, 3.4, COLORS.hit)
  ImGui.SetCursorScreenPos(ctx, x + 12, y + h + 10)
end

local function draw_preview_controls()
  local changed
  changed, preview_t = ImGui.SliderDouble(ctx, "Timeline preview", preview_t, 0, 1, "%.3f")
  if ImGui.Button(ctx, preview_play and "Stop Preview" or "Play Preview", 130, 26) then
    preview_play = not preview_play
    last_time = reaper.time_precise()
  end
  ImGui.SameLine(ctx)
  changed, preview_sync_project_bpm = ImGui.Checkbox(ctx, "Project BPM", preview_sync_project_bpm)
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, 120)
  changed, preview_speed = ImGui.SliderDouble(ctx, "Preview speed", preview_speed, 0.125, 4.0, "%.3fx")
  if not preview_sync_project_bpm then
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 112)
    changed, preview_loop_seconds = ImGui.SliderDouble(ctx, "Loop seconds", preview_loop_seconds, 1.0, 30.0, "%.1f")
  else
    local start_qn = current_start_qn()
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, COLORS.dim, string.format("%.1f BPM", tempo_at_qn(start_qn)))
  end
end

local function generate_item()
  local track = midi.ensure_track()
  if not track then midi.show_error("Could not find or create a track.", TITLE) return end
  local default_beats = LENGTH_BEATS[state.length] > 0 and LENGTH_BEATS[state.length] or 16
  local start_qn, end_qn = midi.time_selection_or_cursor_qn(default_beats)
  if LENGTH_BEATS[state.length] > 0 then end_qn = start_qn + LENGTH_BEATS[state.length] end
  local item, take = midi.create_midi_item(track, start_qn, end_qn, "Musical Space")
  if not take then midi.show_error("Could not create MIDI item.", TITLE) return end
  generate_preview()
  local total_beats = math.max(0.25, end_qn - start_qn)
  for _, event in ipairs(preview) do
    local note_start = start_qn + (event.time or 0) * total_beats
    local note_end = note_start + (total_beats / math.max(1, state.steps)) * state.note_len * (event.length_scale or 1)
    note_end = math.min(end_qn, math.max(note_start + 0.0001, note_end))
    midi.insert_note_qn(take, note_start, note_end, event.channel, event.pitch, event.velocity)
  end
  reaper.MIDI_Sort(take)
  reaper.UpdateArrange()
  status = "Wrote " .. tostring(#preview) .. " notes to a new MIDI item."
end

generate_preview()

local function draw_footer()
  ImGui.Separator(ctx)
  if ImGui.Button(ctx, "Generate MIDI Item", 160, 30) then generate_item() end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Refresh Preview", 130, 30) then generate_preview() end
  ImGui.SameLine(ctx)
  ImGui.TextColored(ctx, COLORS.dim, status)
end

local function loop()
  local now = reaper.time_precise()
  if preview_play then
    local dt = now - last_time
    if preview_sync_project_bpm then
      local start_qn = current_start_qn()
      local bpm = tempo_at_qn(start_qn + preview_t * math.max(0.25, LENGTH_BEATS[state.length] > 0 and LENGTH_BEATS[state.length] or 16))
      local beat_delta = dt * (bpm / 60.0) * preview_speed
      preview_t = (preview_t + beat_delta / math.max(0.25, LENGTH_BEATS[state.length] > 0 and LENGTH_BEATS[state.length] or state.steps)) % 1.0
    else
      preview_t = (preview_t + dt * preview_speed / math.max(0.1, preview_loop_seconds)) % 1.0
    end
  end
  last_time = now

  ImGui.SetNextWindowSize(ctx, 820, 720, ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local footer_height = 52
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    local content_height = math.max(220, avail_h - footer_height)
    local child_visible = ImGui.BeginChild(ctx, "##main_content", 0, content_height)
    if child_visible then
      draw_preview()
      draw_preview_controls()
      local changed = false
      local c
      if ImGui.CollapsingHeader(ctx, "Pitch Space", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        c, state.root = combo("Root", ROOTS, state.root, 90); changed = changed or c
        ImGui.SameLine(ctx)
        c, state.scale = combo("Scale", SCALES, state.scale, 170); changed = changed or c
        ImGui.SameLine(ctx)
        c, state.space = combo("Space", SPACES, state.space, 210); changed = changed or c
        c, state.length = combo("Length", LENGTHS, state.length, 160); changed = changed or c
        c, state.octave = ImGui.SliderInt(ctx, "Base octave", state.octave, 0, 8); changed = changed or c
        c, state.span = ImGui.SliderInt(ctx, "Register span", state.span, 1, 6); changed = changed or c
      end
      if ImGui.CollapsingHeader(ctx, "Rhythm Path", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        c, state.rhythm_mode = combo("Rhythm model", RHYTHM_MODES, state.rhythm_mode, 180); changed = changed or c
        c, state.rhythm_variation = ImGui.SliderDouble(ctx, "Rhythm variation", state.rhythm_variation, 0, 1, "%.3f"); changed = changed or c
        c, state.steps = ImGui.SliderInt(ctx, "Steps", state.steps, 3, 128); changed = changed or c
        c, state.pulses = ImGui.SliderInt(ctx, "Pulses", state.pulses, 0, state.steps); changed = changed or c
        c, state.rotate = ImGui.SliderInt(ctx, "Rotate", state.rotate, -state.steps, state.steps); changed = changed or c
        c, state.density = ImGui.SliderDouble(ctx, "Density", state.density, 0, 1, "%.3f"); changed = changed or c
        c, state.surprise = ImGui.SliderDouble(ctx, "Path surprise", state.surprise, 0, 1, "%.3f"); changed = changed or c
      end
      if ImGui.CollapsingHeader(ctx, "Output", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        c, state.note_len = ImGui.SliderDouble(ctx, "Note length", state.note_len, 0.05, 1.5, "%.2f steps"); changed = changed or c
        c, state.note_len_variation = ImGui.SliderDouble(ctx, "Note length variation", state.note_len_variation, 0, 1, "%.3f"); changed = changed or c
        c, state.voicing = combo("Voicing", VOICINGS, state.voicing, 140); changed = changed or c
        c, state.voicing_variation = ImGui.SliderDouble(ctx, "Voicing variation", state.voicing_variation, 0, 1, "%.3f"); changed = changed or c
        c, state.velocity = ImGui.SliderInt(ctx, "Velocity", state.velocity, 1, 127); changed = changed or c
        c, state.jitter = ImGui.SliderInt(ctx, "Velocity jitter", state.jitter, 0, 48); changed = changed or c
        c, state.channel_mode = combo("Channel mode", CHANNEL_MODES, state.channel_mode, 180); changed = changed or c
        if CHANNEL_MODES[state.channel_mode] == "Single channel" then
          c, state.single_channel = ImGui.SliderInt(ctx, "MIDI channel", state.single_channel, 1, 16); changed = changed or c
        else
          c, state.channels = ImGui.SliderInt(ctx, "MIDI channels / source lanes", state.channels, 1, 16); changed = changed or c
        end
        c, state.seed = ImGui.InputInt(ctx, "Seed", state.seed); changed = changed or c
      end
      if changed then generate_preview() end
    end
    ImGui.EndChild(ctx)
    draw_footer()
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
