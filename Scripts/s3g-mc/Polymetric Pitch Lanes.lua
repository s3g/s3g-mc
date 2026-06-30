-- @description Polymetric Pitch Lanes
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; MIDI Rule Library.lua
-- @category MIDI Composition
-- @render No
-- @method Creates a new MIDI item with multiple polymetric Euclidean pitch lanes. Each lane can use a different step count, pulse count, and scale degree; output can use one MIDI channel per lane or group all lanes onto a single MIDI channel.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local midi = dofile(script_dir .. "MIDI Rule Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Polymetric Pitch Lanes", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "Polymetric Pitch Lanes"
local ctx = ImGui.CreateContext(TITLE)
local open = true
local status = ""

local GRID_NAMES = { "1/64", "1/32", "1/16", "1/8", "1/4", "1/2", "1 beat", "2 beats", "4 beats" }
local GRID_VALUES = { 1 / 16, 1 / 8, 1 / 4, 1 / 2, 1, 2, 4, 8, 16 }
local GRID_ITEMS = table.concat(GRID_NAMES, "\0") .. "\0"
local EUCLIDEAN_PRESETS = {
  { name = "Manual", pulses = nil, steps = nil, rotate = nil },
  { name = "Sparse Dot E(1,5)", pulses = 1, steps = 5, rotate = 0 },
  { name = "Tresillo E(3,8)", pulses = 3, steps = 8, rotate = 0 },
  { name = "Cinquillo E(5,8)", pulses = 5, steps = 8, rotate = 0 },
  { name = "Six Eight E(4,6)", pulses = 4, steps = 6, rotate = 0 },
  { name = "Take Five E(2,5)", pulses = 2, steps = 5, rotate = 0 },
  { name = "Three Five E(3,5)", pulses = 3, steps = 5, rotate = 0 },
  { name = "Ruchenitza E(3,7)", pulses = 3, steps = 7, rotate = 0 },
  { name = "Four Seven E(4,7)", pulses = 4, steps = 7, rotate = 0 },
  { name = "Aksak E(4,9)", pulses = 4, steps = 9, rotate = 0 },
  { name = "Five Nine E(5,9)", pulses = 5, steps = 9, rotate = 0 },
  { name = "Five Eleven E(5,11)", pulses = 5, steps = 11, rotate = 0 },
  { name = "Six Thirteen E(6,13)", pulses = 6, steps = 13, rotate = 0 },
  { name = "Fandango E(4,12)", pulses = 4, steps = 12, rotate = 0 },
  { name = "West African Bell E(7,12)", pulses = 7, steps = 12, rotate = 0 },
  { name = "Bossa E(5,16)", pulses = 5, steps = 16, rotate = 0 },
  { name = "Samba E(7,16)", pulses = 7, steps = 16, rotate = 0 },
  { name = "Nine Sixteen E(9,16)", pulses = 9, steps = 16, rotate = 0 },
  { name = "Sparse Marker E(1,16)", pulses = 1, steps = 16, rotate = 0 },
  { name = "Long Marker E(2,31)", pulses = 2, steps = 31, rotate = 0 },
}
local EUCLIDEAN_PRESET_NAMES = {}
for index, preset in ipairs(EUCLIDEAN_PRESETS) do EUCLIDEAN_PRESET_NAMES[index] = preset.name end
local EUCLIDEAN_PRESET_ITEMS = table.concat(EUCLIDEAN_PRESET_NAMES, "\0") .. "\0"
local FORM_BANK_NAMES = {
  "No bank",
  "Polymetric Field",
  "Bell Harmonics",
  "Aksak Ladder",
  "Sparse Constellation",
  "Pentatonic Hocket",
  "Quartal Mesh",
  "Octave Phasing",
  "Mirror Canon",
  "Low Pulse / High Dust",
  "Chromatic Drift",
  "Whole Tone Tilt",
  "Tritone Gates",
  "Cluster Shimmer",
  "Wide Register",
  "Minimal Pulse",
}
local FORM_BANK_ITEMS = table.concat(FORM_BANK_NAMES, "\0") .. "\0"
local CHANNEL_MODE_NAMES = { "Lane channels", "Single channel" }
local CHANNEL_MODE_ITEMS = table.concat(CHANNEL_MODE_NAMES, "\0") .. "\0"

local lane_count = 8
local duration_beats = 32
local root_index = 1
local scale_index = 2
local base_octave = 3
local lane_spread = 2
local channel_mode_index = 1
local single_channel = 1
local seed = 1
local density = 1.0
local note_len = 0.55
local note_len_variation = 0.18
local velocity = 82
local velocity_slope = 4
local grid_index = 3
local form_bank_index = 1
local preview_t = 0.0
local preview_play = false
local preview_sync_project_bpm = true
local preview_speed = 1.0
local preview_loop_seconds = 8.0
local last_time = reaper.time_precise()

local lanes = {}
for i = 1, 16 do
  lanes[i] = {
    steps = 8 + i,
    pulses = 2 + (i % 5),
    rotate = i - 1,
    degree = (i - 1) * 2,
    custom_pattern = nil,
    pattern_input = "",
    muted = i > 8,
  }
end

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local COLORS = {
  panel = color(0.055, 0.060, 0.064, 1),
  edge = color(0.30, 0.32, 0.33, 1),
  grid = color(0.50, 0.55, 0.54, 0.20),
  dim = color(0.50, 0.55, 0.54, 1),
  lane = color(0.26, 0.74, 0.70, 1),
  hit = color(0.95, 0.74, 0.28, 1),
  playhead = color(1.00, 1.00, 1.00, 1),
  play = color(1.00, 0.38, 0.28, 1),
  muted = color(0.22, 0.24, 0.25, 1),
}

local RING_COLORS = {
  color(1.00, 0.78, 0.18, 1),
  color(0.08, 0.78, 0.92, 1),
  color(0.96, 0.22, 0.34, 1),
  color(0.26, 0.86, 0.36, 1),
  color(0.70, 0.42, 1.00, 1),
  color(1.00, 0.45, 0.08, 1),
  color(0.24, 0.48, 1.00, 1),
  color(0.90, 0.92, 0.22, 1),
}

local function ring_color(index)
  return RING_COLORS[((index - 1) % #RING_COLORS) + 1]
end

local function point_on_circle(cx, cy, radius, step, steps)
  local angle = -math.pi * 0.5 + (math.pi * 2 * step / math.max(1, steps))
  return cx + math.cos(angle) * radius, cy + math.sin(angle) * radius
end

local function grid_beats()
  return GRID_VALUES[grid_index] or 0.25
end

local function lane_pitch(lane)
  return midi.scale_pitch(
    midi.ROOT_NAMES[root_index],
    midi.SCALE_NAMES[scale_index],
    lane and lane.degree or 0,
    base_octave,
    lane_spread)
end

local function pitch_name(pitch)
  pitch = math.max(0, math.min(127, math.floor(tonumber(pitch) or 60)))
  local note = midi.ROOT_NAMES[(pitch % 12) + 1] or "C"
  local octave = math.floor(pitch / 12) - 1
  return note .. tostring(octave)
end

local function lane_pitch_label(lane)
  local degree = lane and lane.degree or 0
  return string.format("%s d%+d", pitch_name(lane_pitch(lane)), degree)
end

local function output_channel_for_lane(index)
  if channel_mode_index == 2 then return math.max(1, math.min(16, single_channel)) end
  return math.max(1, math.min(16, index or 1))
end

local function varied_note_len(lane_index, event_index)
  local variation = midi.clamp(note_len_variation or 0, 0, 1)
  local scale = 1.0
  if variation > 0 then
    local drift = math.sin((event_index or 1) * 0.53 + (lane_index or 1) * 0.91) * variation * 0.30
    local jitter = (math.random() * 2 - 1) * variation
    scale = 1.0 + drift + jitter
  end
  return midi.clamp((note_len or 0.55) * scale, 0.04, 2.4)
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

local function parse_custom_pattern(text)
  local pattern = {}
  local cleaned = {}
  local pulses = 0
  text = tostring(text or "")
  for char in text:gmatch(".") do
    if char == "x" or char == "X" or char == "1" or char == "*" then
      if #pattern < 64 then
        pattern[#pattern + 1] = true
        cleaned[#cleaned + 1] = "x"
        pulses = pulses + 1
      end
    elseif char == "-" or char == "." or char == "_" or char == "0" then
      if #pattern < 64 then
        pattern[#pattern + 1] = false
        cleaned[#cleaned + 1] = "-"
      end
    end
  end
  if #pattern == 0 then return nil, "", 0 end
  return pattern, table.concat(cleaned), pulses
end

local function rotate_pattern(pattern, rotate)
  local steps = #(pattern or {})
  if steps <= 0 then return nil end
  local out = {}
  rotate = math.floor(rotate or 0)
  for index = 1, steps do
    local shifted = ((index - 1 - rotate) % steps) + 1
    out[index] = pattern[shifted] and true or false
  end
  return out
end

local function pattern_from_lane(lane)
  if lane and lane.custom_pattern and lane.custom_pattern ~= "" then
    local pattern = parse_custom_pattern(lane.custom_pattern)
    if pattern then return rotate_pattern(pattern, lane.rotate) end
  end
  return midi.euclidean_pattern(lane and lane.pulses or 0, lane and lane.steps or 1, lane and lane.rotate or 0)
end

local function interval_vector(pattern)
  local hits = {}
  for index, hit in ipairs(pattern or {}) do if hit then hits[#hits + 1] = index end end
  if #hits == 0 then return "-" end
  if #hits == 1 then return tostring(#pattern) end
  local intervals = {}
  for index = 1, #hits do
    local a = hits[index]
    local b = hits[(index % #hits) + 1]
    if b <= a then b = b + #pattern end
    intervals[#intervals + 1] = tostring(b - a)
  end
  return table.concat(intervals, "-")
end

local function apply_euclidean_preset(lane, preset)
  if not lane or not preset or not preset.steps then return end
  lane.steps = math.max(1, math.min(64, preset.steps))
  lane.pulses = math.max(0, math.min(lane.steps, preset.pulses or 0))
  lane.rotate = preset.rotate or 0
  lane.custom_pattern = nil
  lane.pattern_input = ""
end

local function euclidean_preset_index(lane)
  if not lane or (lane.custom_pattern and lane.custom_pattern ~= "") then return 0 end
  local rot = ((lane.rotate or 0) % math.max(1, lane.steps or 1))
  for index = 2, #EUCLIDEAN_PRESETS do
    local preset = EUCLIDEAN_PRESETS[index]
    if preset.steps == lane.steps and preset.pulses == lane.pulses then
      local preset_rot = (preset.rotate or 0) % math.max(1, preset.steps or 1)
      if rot == preset_rot then return index - 1 end
    end
  end
  return 0
end

local function set_lane_pattern(lane, pulses, steps, rotate)
  if not lane then return end
  lane.steps = math.max(1, math.min(64, steps or lane.steps or 16))
  lane.pulses = math.max(0, math.min(lane.steps, pulses or lane.pulses or 0))
  lane.rotate = rotate or 0
  lane.custom_pattern = nil
  lane.pattern_input = ""
end

local function apply_custom_pattern(lane)
  if not lane then return false end
  local pattern, cleaned, pulses = parse_custom_pattern(lane.pattern_input or "")
  if not pattern then return false end
  lane.custom_pattern = cleaned
  lane.pattern_input = cleaned
  lane.steps = #pattern
  lane.pulses = pulses
  lane.rotate = 0
  return true
end

local FORM_BANKS = {
  ["Polymetric Field"] = {
    { 3, 8, 0, 0 }, { 5, 12, 2, 2 }, { 7, 16, 0, 4 }, { 4, 9, 1, 5 },
    { 3, 11, 2, 7 }, { 5, 14, 3, 9 }, { 4, 13, 5, 11 }, { 7, 18, 4, 12 },
  },
  ["Bell Harmonics"] = {
    { 7, 12, 0, 0 }, { 5, 12, 4, 2 }, { 4, 12, 3, 4 }, { 7, 16, 2, 7 },
    { 5, 16, 5, 9 }, { 3, 8, 0, 12 }, { 2, 7, 4, 14 }, { 1, 16, 12, 16 },
  },
  ["Aksak Ladder"] = {
    { 4, 9, 0, 0 }, { 3, 7, 3, 1 }, { 5, 9, 1, 3 }, { 2, 7, 4, 5 },
    { 3, 11, 2, 8 }, { 4, 13, 3, 10 }, { 5, 14, 1, 13 }, { 3, 8, 5, 15 },
  },
  ["Sparse Constellation"] = {
    { 1, 5, 0, 0 }, { 2, 7, 3, 2 }, { 3, 11, 1, 5 }, { 2, 13, 6, 7 },
    { 4, 17, 2, 11 }, { 3, 19, 5, 14 }, { 4, 21, 8, 17 }, { 1, 16, 12, 21 },
  },
  ["Pentatonic Hocket"] = {
    { 3, 8, 0, 0 }, { 2, 5, 1, 2 }, { 3, 7, 2, 4 }, { 5, 12, 3, 7 },
    { 4, 9, 5, 9 }, { 5, 11, 4, 12 }, { 6, 13, 8, 14 }, { 7, 16, 6, 16 },
  },
  ["Quartal Mesh"] = {
    { 2, 5, 0, 0 }, { 3, 7, 2, 3 }, { 4, 9, 4, 6 }, { 5, 11, 6, 9 },
    { 6, 13, 8, 12 }, { 7, 15, 10, 15 }, { 5, 16, 12, 18 }, { 3, 19, 14, 21 },
  },
  ["Octave Phasing"] = {
    { 4, 8, 0, 0 }, { 4, 9, 1, 7 }, { 4, 10, 2, 12 }, { 4, 11, 3, 19 },
    { 4, 12, 4, 24 }, { 3, 13, 5, 31 }, { 3, 14, 6, 36 }, { 2, 15, 7, 43 },
  },
  ["Mirror Canon"] = {
    { 3, 8, 0, 0 }, { 5, 12, 1, 2 }, { 7, 16, 2, 4 }, { 4, 9, 3, 7 },
    { 4, 9, 6, 5 }, { 7, 16, 10, 3 }, { 5, 12, 8, 1 }, { 3, 8, 4, -2 },
  },
  ["Low Pulse / High Dust"] = {
    { 2, 8, 0, -14 }, { 3, 12, 4, -7 }, { 1, 16, 8, 0 }, { 2, 21, 5, 4 },
    { 3, 19, 9, 9 }, { 4, 23, 11, 14 }, { 5, 29, 13, 19 }, { 7, 31, 17, 24 },
  },
  ["Chromatic Drift"] = {
    { 3, 8, 0, 0 }, { 3, 9, 1, 1 }, { 4, 10, 2, 2 }, { 4, 11, 3, 3 },
    { 5, 12, 4, 4 }, { 5, 13, 5, 5 }, { 6, 14, 6, 6 }, { 7, 15, 7, 7 },
  },
  ["Whole Tone Tilt"] = {
    { 2, 5, 0, 0 }, { 3, 8, 2, 2 }, { 4, 11, 4, 4 }, { 5, 14, 6, 6 },
    { 6, 17, 8, 8 }, { 5, 19, 10, 10 }, { 4, 21, 12, 12 }, { 3, 23, 14, 14 },
  },
  ["Tritone Gates"] = {
    { 1, 8, 0, 0 }, { 2, 11, 5, 6 }, { 1, 13, 3, 12 }, { 3, 16, 9, 18 },
    { 2, 19, 7, 24 }, { 4, 23, 11, 30 }, { 2, 29, 13, 36 }, { 1, 31, 17, 42 },
  },
  ["Cluster Shimmer"] = {
    { 7, 16, 0, 0 }, { 6, 15, 2, 1 }, { 7, 17, 4, 2 }, { 8, 19, 6, 3 },
    { 5, 13, 8, 4 }, { 6, 21, 10, 5 }, { 7, 23, 12, 6 }, { 9, 29, 14, 7 },
  },
  ["Wide Register"] = {
    { 3, 8, 0, -21 }, { 5, 12, 2, -12 }, { 4, 9, 1, -5 }, { 7, 16, 4, 0 },
    { 5, 11, 6, 7 }, { 3, 13, 8, 14 }, { 2, 17, 10, 21 }, { 1, 23, 12, 35 },
  },
  ["Minimal Pulse"] = {
    { 1, 8, 0, 0 }, { 1, 9, 2, 2 }, { 1, 10, 4, 4 }, { 1, 11, 6, 7 },
    { 1, 12, 8, 9 }, { 1, 13, 10, 12 }, { 1, 14, 12, 14 }, { 1, 15, 14, 16 },
  },
}

local function apply_form_bank(name)
  local bank = FORM_BANKS[name]
  if not bank then return end
  lane_count = math.max(1, math.min(16, #bank))
  for i = 1, math.min(#bank, 16) do
    local data = bank[i]
    local lane = lanes[i]
    set_lane_pattern(lane, data[1], data[2], data[3])
    lane.degree = data[4] or lane.degree
    lane.muted = false
  end
  for i = #bank + 1, 16 do
    lanes[i].muted = true
  end
  status = "Applied " .. name .. "."
end

local function draw_lane_preview()
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  local h = 380
  local timeline_h = 46
  local geo_h = h - timeline_h
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, COLORS.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, COLORS.edge)
  ImGui.DrawList_AddLine(draw_list, x, y + geo_h, x + w, y + geo_h, COLORS.edge, 1)

  local legend_w = 230
  local cx = x + (w - legend_w) * 0.5
  local cy = y + geo_h * 0.54
  local max_r = math.max(34, math.min(w - legend_w, geo_h - 42) * 0.5 - 12)
  local spacing = math.max(7, math.min(20, (max_r - 14) / math.max(1, lane_count)))
  local preview_beat = preview_t * math.max(0.25, duration_beats)
  local preview_grid_step = math.floor((preview_beat / math.max(0.0001, grid_beats())) + 0.000001)

  ImGui.DrawList_AddText(draw_list, x + 12, y + 10, COLORS.dim, "RHYTHM + PITCH MAP")
  ImGui.DrawList_AddText(draw_list, x + 12, y + 28, COLORS.dim,
    string.format("%s %s  oct %d  span %d  %s",
      midi.ROOT_NAMES[root_index] or "C",
      midi.SCALE_NAMES[scale_index] or "Major",
      base_octave,
      lane_spread,
      CHANNEL_MODE_NAMES[channel_mode_index] or "Lane channels"))
  for i = 1, lane_count do
    local lane = lanes[i]
    local radius = max_r - (i - 1) * spacing
    if radius < 14 then break end
    local col = lane.muted and COLORS.dim or ring_color(i)
    ImGui.DrawList_AddCircle(draw_list, cx, cy, radius, lane.muted and COLORS.muted or COLORS.grid, 96, 1)
    if not lane.muted then
      local pattern = pattern_from_lane(lane)
      local hit_points = {}
      for step = 1, lane.steps do
        local p1x, p1y = point_on_circle(cx, cy, radius - 3, step - 1, lane.steps)
        local p2x, p2y = point_on_circle(cx, cy, radius + 3, step - 1, lane.steps)
        ImGui.DrawList_AddLine(draw_list, p1x, p1y, p2x, p2y, pattern[step] and col or COLORS.grid, 1)
        if pattern[step] then
          local hx, hy = point_on_circle(cx, cy, radius - spacing * 0.42, step - 1, lane.steps)
          hit_points[#hit_points + 1] = { x = hx, y = hy }
          ImGui.DrawList_AddCircleFilled(draw_list, hx, hy, 4.8, col)
        end
      end
      for p = 1, #hit_points do
        local a = hit_points[p]
        local b = hit_points[(p % #hit_points) + 1]
        if b then ImGui.DrawList_AddLine(draw_list, a.x, a.y, b.x, b.y, col, 1.1) end
      end
      local active_point = nil
      if #hit_points > 0 then
        local passed_hits = 0
        for step = 1, lane.steps do
          if pattern[step] and (step - 1) <= (preview_grid_step % math.max(1, lane.steps)) then
            passed_hits = passed_hits + 1
          end
        end
        local hit_index = ((math.max(1, passed_hits) - 1) % #hit_points) + 1
        active_point = hit_points[hit_index]
      end
      if active_point then
        ImGui.DrawList_AddCircleFilled(draw_list, active_point.x, active_point.y, 6.8, COLORS.panel)
        ImGui.DrawList_AddCircleFilled(draw_list, active_point.x, active_point.y, 5.0, COLORS.playhead)
      end
    end
    local label_y = y + 34 + (i - 1) * 16
    if label_y < y + geo_h - 8 then
      ImGui.DrawList_AddRectFilled(draw_list, x + w - legend_w + 14, label_y - 8, x + w - legend_w + 23, label_y + 1, col)
      ImGui.DrawList_AddText(draw_list, x + w - legend_w + 30, label_y - 10, lane.muted and COLORS.dim or col,
        string.format("ch%02d %s", output_channel_for_lane(i), lane_pitch_label(lane)))
      ImGui.DrawList_AddText(draw_list, x + w - legend_w + 136, label_y - 10, COLORS.dim,
        string.format("%d/%d %s", lane.pulses, lane.steps, interval_vector(pattern_from_lane(lane))))
    end
  end

  local tx = x + 18
  local ty = y + geo_h + 17
  local tw = w - 36
  ImGui.DrawList_AddLine(draw_list, tx, ty, tx + tw, ty, color(0.55, 0.60, 0.58, 0.32), 1)
  ImGui.DrawList_AddRectFilled(draw_list, tx, ty - 4, tx + tw, ty + 4, color(0.18, 0.42, 0.42, 0.22))
  ImGui.DrawList_AddRect(draw_list, tx, ty - 4, tx + tw, ty + 4, COLORS.lane)
  ImGui.DrawList_AddCircleFilled(draw_list, tx + tw * preview_t, ty, 3.4, COLORS.play)
  ImGui.SetCursorScreenPos(ctx, x, y + h + 12)
end

local function write_midi()
  midi.seed(seed)
  local track = midi.ensure_track()
  if not track then midi.show_error("Could not find or create a track.", TITLE) return end
  local start_qn, _ = midi.time_selection_or_cursor_qn(duration_beats)
  local end_qn = start_qn + duration_beats
  local item, take = midi.create_midi_item(track, start_qn, end_qn, "Polymetric Pitch Lanes")
  if not take then midi.show_error("Could not create MIDI item.", TITLE) return end

  local root = midi.ROOT_NAMES[root_index]
  local scale = midi.SCALE_NAMES[scale_index]
  local event_count = 0
  local step_beats = math.max(0.0001, grid_beats())
  for i = 1, lane_count do
    local lane = lanes[i]
    if not lane.muted then
      local pitch = midi.scale_pitch(root, scale, lane.degree, base_octave, lane_spread)
      local beat = 0.0
      local guard = 0
      while beat < duration_beats - 0.0001 and guard < 10000 do
        guard = guard + 1
        local pattern = pattern_from_lane(lane)
        local step = (math.floor((beat / step_beats) + 0.000001) % math.max(1, lane.steps)) + 1
        if pattern[step] and midi.chance(density) then
          local note_start = start_qn + beat
          local note_end = note_start + step_beats * varied_note_len(i, event_count + 1)
          note_end = math.min(end_qn, math.max(note_start + 0.0001, note_end))
          local vel = midi.velocity(velocity + (i - 1) * velocity_slope, 18, guard, 4, 6)
          midi.insert_note_qn(take, note_start, note_end, output_channel_for_lane(i) - 1, pitch, vel)
          event_count = event_count + 1
        end
        beat = beat + step_beats
      end
    end
  end
  reaper.MIDI_Sort(take)
  reaper.UpdateArrange()
  status = "Wrote " .. tostring(event_count) .. " notes across " .. tostring(lane_count) .. " lanes."
end

local function reset_lanes()
  for i = 1, 16 do
    lanes[i].steps = 8 + i
    lanes[i].pulses = 2 + (i % 5)
    lanes[i].rotate = i - 1
    lanes[i].degree = (i - 1) * 2
    lanes[i].custom_pattern = nil
    lanes[i].pattern_input = ""
    lanes[i].muted = i > lane_count
  end
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

local function draw_global_controls()
  local changed
  if ImGui.CollapsingHeader(ctx, "Pitch / Output", nil, ImGui.TreeNodeFlags_DefaultOpen) then
    changed, lane_count = ImGui.SliderInt(ctx, "Pitch lanes", lane_count, 1, 16)
    changed, duration_beats = ImGui.SliderDouble(ctx, "Duration beats", duration_beats, 1, 256, "%.1f")
    local channel_mode_zero = channel_mode_index - 1
    ImGui.SetNextItemWidth(ctx, 150)
    changed, channel_mode_zero = ImGui.Combo(ctx, "MIDI channel mode", channel_mode_zero, CHANNEL_MODE_ITEMS)
    if changed then channel_mode_index = channel_mode_zero + 1 end
    if channel_mode_index == 2 then
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, 90)
      changed, single_channel = ImGui.SliderInt(ctx, "Channel", single_channel, 1, 16)
    end
    ImGui.SetNextItemWidth(ctx, 90)
    local root_zero = root_index - 1
    changed, root_zero = ImGui.Combo(ctx, "Root", root_zero, table.concat(midi.ROOT_NAMES, "\0") .. "\0")
    if changed then root_index = root_zero + 1 end
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 170)
    local scale_zero = scale_index - 1
    changed, scale_zero = ImGui.Combo(ctx, "Scale", scale_zero, table.concat(midi.SCALE_NAMES, "\0") .. "\0")
    if changed then scale_index = scale_zero + 1 end
    changed, base_octave = ImGui.SliderInt(ctx, "Base octave", base_octave, 0, 8)
    changed, lane_spread = ImGui.SliderInt(ctx, "Lane register span", lane_spread, 1, 6)
  end
  if ImGui.CollapsingHeader(ctx, "Timing / Generation", nil, ImGui.TreeNodeFlags_DefaultOpen) then
    local grid_zero = grid_index - 1
    ImGui.SetNextItemWidth(ctx, 112)
    changed, grid_zero = ImGui.Combo(ctx, "Grid", grid_zero, GRID_ITEMS)
    if changed then grid_index = grid_zero + 1 end
    changed, density = ImGui.SliderDouble(ctx, "Hit probability", density, 0, 1, "%.3f")
    changed, note_len = ImGui.SliderDouble(ctx, "Note length", note_len, 0.05, 1.5, "%.2f grid")
    changed, note_len_variation = ImGui.SliderDouble(ctx, "Note length variation", note_len_variation, 0, 1, "%.3f")
    changed, velocity = ImGui.SliderInt(ctx, "Base velocity", velocity, 1, 127)
    changed, velocity_slope = ImGui.SliderInt(ctx, "Lane velocity slope", velocity_slope, -10, 10)
    changed, seed = ImGui.InputInt(ctx, "Seed", seed)
  end
end

local function draw_lane_editor()
  ImGui.Separator(ctx)
  ImGui.Text(ctx, "Pitch Lanes")
  local changed
  local bank_zero = form_bank_index - 1
  ImGui.SetNextItemWidth(ctx, 190)
  changed, bank_zero = ImGui.Combo(ctx, "Preset bank", bank_zero, FORM_BANK_ITEMS)
  if changed then form_bank_index = bank_zero + 1 end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Apply Bank", 92, 24) then
    apply_form_bank(FORM_BANK_NAMES[form_bank_index] or "No bank")
  end
  if ImGui.BeginChild(ctx, "##lanes", 0, 390) then
    for i = 1, lane_count do
      local lane = lanes[i]
      ImGui.PushID(ctx, i)
      ImGui.Separator(ctx)
      changed, lane.muted = ImGui.Checkbox(ctx, "Mute", lane.muted)
      ImGui.SameLine(ctx)
      ImGui.TextColored(ctx, ring_color(i), string.format("%02d", i))
      ImGui.SameLine(ctx)
      local preset_zero = euclidean_preset_index(lane)
      ImGui.SetNextItemWidth(ctx, 168)
      changed, preset_zero = ImGui.Combo(ctx, "Preset", preset_zero, EUCLIDEAN_PRESET_ITEMS)
      if changed then apply_euclidean_preset(lane, EUCLIDEAN_PRESETS[preset_zero + 1]) end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "<##rotate_left", 24, 22) then lane.rotate = lane.rotate - 1 end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, ">##rotate_right", 24, 22) then lane.rotate = lane.rotate + 1 end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Comp##complement", 42, 22) and i > 1 then
        local prev = lanes[i - 1]
        set_lane_pattern(lane, math.max(0, prev.steps - prev.pulses), prev.steps, prev.rotate)
      end
      ImGui.SetNextItemWidth(ctx, 90)
      changed, lane.steps = ImGui.SliderInt(ctx, "Steps", lane.steps, 1, 64)
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, 90)
      lane.pulses = math.min(lane.pulses, lane.steps)
      changed, lane.pulses = ImGui.SliderInt(ctx, "Pulses", lane.pulses, 0, lane.steps)
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, 90)
      changed, lane.rotate = ImGui.SliderInt(ctx, "Rotate", lane.rotate, -lane.steps, lane.steps)
      ImGui.SameLine(ctx)
      ImGui.SetNextItemWidth(ctx, 90)
      changed, lane.degree = ImGui.SliderInt(ctx, "Degree", lane.degree, -24, 48)
      ImGui.SameLine(ctx)
      ImGui.TextColored(ctx, COLORS.dim, interval_vector(pattern_from_lane(lane)))
      ImGui.SetNextItemWidth(ctx, 300)
      changed, lane.pattern_input = ImGui.InputText(ctx, "Pattern", lane.pattern_input or lane.custom_pattern or "")
      if changed then
        if (lane.pattern_input or "") == "" then
          lane.custom_pattern = nil
        else
          apply_custom_pattern(lane)
        end
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Clear Pattern", 104, 22) then
        lane.custom_pattern = nil
        lane.pattern_input = ""
      end
      ImGui.PopID(ctx)
    end
    ImGui.EndChild(ctx)
  end
end

local function draw_footer()
  ImGui.Separator(ctx)
  if ImGui.Button(ctx, "Generate MIDI Item", 170, 32) then write_midi() end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Reset Lanes", 110, 32) then reset_lanes() end
  ImGui.SameLine(ctx)
  ImGui.TextColored(ctx, COLORS.dim, status)
end

local function loop()
  local now = reaper.time_precise()
  if preview_play then
    local dt = now - last_time
    if preview_sync_project_bpm then
      local start_qn = current_start_qn()
      local bpm = tempo_at_qn(start_qn + preview_t * math.max(0.25, duration_beats))
      local beat_delta = dt * (bpm / 60.0) * preview_speed
      preview_t = (preview_t + beat_delta / math.max(0.0001, duration_beats)) % 1.0
    else
      preview_t = (preview_t + dt * preview_speed / math.max(0.1, preview_loop_seconds)) % 1.0
    end
  end
  last_time = now

  ImGui.SetNextWindowSize(ctx, 860, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local footer_height = 52
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    local content_height = math.max(220, avail_h - footer_height)
    local child_visible = ImGui.BeginChild(ctx, "##main_content", 0, content_height)
    if child_visible then
      draw_lane_preview()
      draw_preview_controls()
      draw_lane_editor()
      draw_global_controls()
    end
    ImGui.EndChild(ctx)
    draw_footer()
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
