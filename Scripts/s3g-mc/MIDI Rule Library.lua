-- @description MIDI Rule Library
-- @browser hidden

local M = {}

M.PROJECT = 0

M.SCALES = {
  ["Chromatic"] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },
  ["Major"] = { 0, 2, 4, 5, 7, 9, 11 },
  ["Natural minor"] = { 0, 2, 3, 5, 7, 8, 10 },
  ["Dorian"] = { 0, 2, 3, 5, 7, 9, 10 },
  ["Phrygian"] = { 0, 1, 3, 5, 7, 8, 10 },
  ["Lydian"] = { 0, 2, 4, 6, 7, 9, 11 },
  ["Mixolydian"] = { 0, 2, 4, 5, 7, 9, 10 },
  ["Minor pentatonic"] = { 0, 3, 5, 7, 10 },
  ["Whole tone"] = { 0, 2, 4, 6, 8, 10 },
}

M.SCALE_NAMES = {
  "Chromatic",
  "Major",
  "Natural minor",
  "Dorian",
  "Phrygian",
  "Lydian",
  "Mixolydian",
  "Minor pentatonic",
  "Whole tone",
}

M.ROOTS = {
  C = 0, Db = 1, D = 2, Eb = 3, E = 4, F = 5, Gb = 6, G = 7, Ab = 8, A = 9, Bb = 10, B = 11,
}

M.ROOT_NAMES = { "C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B" }

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

M.clamp = clamp

function M.show_error(message, title)
  reaper.MB(message, title or "s3g-mc MIDI", 0)
end

function M.selected_or_first_track()
  return reaper.GetSelectedTrack(M.PROJECT, 0) or reaper.GetTrack(M.PROJECT, 0)
end

function M.ensure_track()
  local track = M.selected_or_first_track()
  if track then return track end
  reaper.InsertTrackAtIndex(reaper.CountTracks(M.PROJECT), true)
  track = reaper.GetTrack(M.PROJECT, reaper.CountTracks(M.PROJECT) - 1)
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "Generated MIDI", true)
  return track
end

function M.time_selection_or_cursor_qn(default_beats)
  local start_time, end_time = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if end_time > start_time then
    return reaper.TimeMap2_timeToQN(M.PROJECT, start_time), reaper.TimeMap2_timeToQN(M.PROJECT, end_time)
  end
  local start_qn = reaper.TimeMap2_timeToQN(M.PROJECT, reaper.GetCursorPosition())
  return start_qn, start_qn + math.max(0.25, default_beats or 16)
end

function M.create_midi_item(track, start_qn, end_qn, name)
  local start_time = reaper.TimeMap2_QNToTime(M.PROJECT, start_qn)
  local end_time = reaper.TimeMap2_QNToTime(M.PROJECT, math.max(start_qn + 0.25, end_qn))
  local item = reaper.CreateNewMIDIItemInProj(track, start_time, end_time, false)
  if not item then return nil, nil end
  local take = reaper.GetActiveTake(item)
  if name and name ~= "" then
    reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true)
  end
  return item, take
end

function M.clear_take(take)
  if not take then return end
  local ok, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
  if not ok then return end
  for index = notes - 1, 0, -1 do reaper.MIDI_DeleteNote(take, index) end
  for index = ccs - 1, 0, -1 do reaper.MIDI_DeleteCC(take, index) end
  for index = sysex - 1, 0, -1 do reaper.MIDI_DeleteTextSysexEvt(take, index) end
end

function M.insert_note_qn(take, start_qn, end_qn, channel, pitch, velocity, selected)
  local start_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, start_qn)
  local end_ppq = reaper.MIDI_GetPPQPosFromProjQN(take, math.max(start_qn + 0.01, end_qn))
  reaper.MIDI_InsertNote(take, selected or false, false, start_ppq, end_ppq,
    clamp(math.floor(channel or 0), 0, 15),
    clamp(math.floor(pitch or 60), 0, 127),
    clamp(math.floor(velocity or 96), 1, 127),
    true)
end

function M.euclidean_pattern(pulses, steps, rotate)
  steps = math.max(1, math.floor(steps or 16))
  pulses = clamp(math.floor(pulses or 4), 0, steps)
  rotate = math.floor(rotate or 0)
  local pattern = {}
  if pulses <= 0 then
    for index = 1, steps do pattern[index] = false end
    return pattern
  end
  for index = 0, steps - 1 do
    local shifted = (index - rotate) % steps
    pattern[index + 1] = math.floor(((shifted + 1) * pulses) / steps) ~= math.floor((shifted * pulses) / steps)
  end
  return pattern
end

function M.seed(seed)
  seed = math.floor(tonumber(seed) or os.time())
  math.randomseed(seed)
  return seed
end

function M.chance(amount)
  return math.random() <= clamp(tonumber(amount) or 0, 0, 1)
end

function M.scale_pitch(root_name, scale_name, degree, octave, register_span)
  local root = M.ROOTS[root_name] or 0
  local scale = M.SCALES[scale_name] or M.SCALES.Major
  local len = #scale
  degree = math.floor(degree or 0)
  octave = math.floor(octave or 4)
  register_span = math.max(1, math.floor(register_span or 2))
  local octave_offset = math.floor(degree / len)
  local scale_degree = ((degree % len) + len) % len
  local folded_octave = octave + (octave_offset % register_span)
  return clamp((folded_octave + 1) * 12 + root + scale[scale_degree + 1], 0, 127)
end

function M.velocity(base, accent, hit_index, accent_every, jitter)
  local value = tonumber(base) or 88
  accent_every = math.max(1, math.floor(accent_every or 4))
  if ((hit_index - 1) % accent_every) == 0 then value = value + (tonumber(accent) or 22) end
  jitter = tonumber(jitter) or 0
  if jitter > 0 then value = value + math.floor((math.random() * 2 - 1) * jitter) end
  return clamp(value, 1, 127)
end

function M.weighted_step(mode, surprise)
  surprise = clamp(tonumber(surprise) or 0.2, 0, 1)
  local r = math.random()
  if mode == "Triadic" then
    local pool = { -4, -3, -2, 2, 3, 4, 5, -5 }
    return pool[math.floor(math.random() * #pool) + 1]
  elseif mode == "Contour" then
    local pool = surprise > r and { -5, -4, 4, 5, 7, -7 } or { -2, -1, 1, 2, 3, -3 }
    return pool[math.floor(math.random() * #pool) + 1]
  end
  local pool = surprise > r and { -7, -5, 5, 7 } or { -2, -1, 1, 2 }
  return pool[math.floor(math.random() * #pool) + 1]
end

return M
