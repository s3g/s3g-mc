-- @description MIDI Form Learner
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3; NumPy; MIDI Rule Library.lua; NumPy Render Library.lua
-- @category MIDI Composition
-- @render No
-- @method NumPy-backed MIDI composer that analyzes selected MIDI items and generates a new song-duration MIDI item from extracted rhythm, pitch, velocity, duration, channel, and recurrence traits.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local midi = dofile(script_dir .. "MIDI Rule Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "MIDI Form Learner", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "MIDI Form Learner"
local ctx = ImGui.CreateContext(TITLE)
local open = true
local status = ""

local STRATEGY_NAMES = { "Channel canon", "Drift variation", "Expanded return", "Fragmented blocks", "Source echo", "Terrain hybrid" }
local STRATEGY_KEYS = { "channel_canon", "drift_variation", "expanded_return", "fragmented_blocks", "source_echo", "terrain_hybrid" }

local state = {
  duration_beats = 384,
  sections = 9,
  lanes = 8,
  bar_beats = 4,
  strategy = 3,
  density_scale = 1.0,
  source_influence = 0.72,
  variation = 0.35,
  recurrence = 0.55,
  transpose_range = 12,
  time_warp = 0.22,
  seed = 31,
  add_markers = true,
}

local last_sections = {}
local last_events = {}
local last_source_stats = nil

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local COLORS = {
  panel = color(0.055, 0.060, 0.064, 1),
  edge = color(0.30, 0.32, 0.33, 1),
  grid = color(0.48, 0.52, 0.51, 0.22),
  text = color(0.80, 0.84, 0.82, 1),
  dim = color(0.50, 0.55, 0.54, 1),
  source = color(0.42, 0.72, 0.72, 1),
  learned = color(0.92, 0.66, 0.26, 1),
  section = color(0.22, 0.30, 0.32, 1),
}

local function combo(label, labels, value, width)
  ImGui.SetNextItemWidth(ctx, width or 180)
  local changed, next_value = ImGui.Combo(ctx, label, value - 1, table.concat(labels, "\0") .. "\0")
  return changed, next_value + 1
end

local function selected_midi_notes()
  local notes = {}
  local min_qn = math.huge
  local max_qn = 0
  local item_count = reaper.CountSelectedMediaItems(0)
  for item_index = 0, item_count - 1 do
    local item = reaper.GetSelectedMediaItem(0, item_index)
    local take = item and reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then
      local ok, note_count = reaper.MIDI_CountEvts(take)
      if ok then
        for i = 0, note_count - 1 do
          local ok_note, _, _, start_ppq, end_ppq, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
          if ok_note then
            local start_qn = reaper.MIDI_GetProjQNFromPPQPos(take, start_ppq)
            local end_qn = reaper.MIDI_GetProjQNFromPPQPos(take, end_ppq)
            min_qn = math.min(min_qn, start_qn)
            max_qn = math.max(max_qn, end_qn)
            notes[#notes + 1] = {
              start = start_qn,
              duration = math.max(0.03125, end_qn - start_qn),
              pitch = pitch,
              velocity = vel,
              channel = chan,
            }
          end
        end
      end
    end
  end
  if min_qn == math.huge then return {}, nil end
  table.sort(notes, function(a, b)
    if a.start == b.start then return a.pitch < b.pitch end
    return a.start < b.start
  end)
  for _, note in ipairs(notes) do
    note.start = note.start - min_qn
  end
  return notes, { count = #notes, span = math.max(0.03125, max_qn - min_qn) }
end

local function write_source_csv(path, notes)
  local file = io.open(path, "w")
  if not file then return false end
  file:write("start,duration,pitch,velocity,channel\n")
  for _, note in ipairs(notes) do
    file:write(string.format("%.6f,%.6f,%d,%d,%d\n",
      note.start, note.duration, note.pitch, note.velocity, note.channel))
  end
  file:close()
  return true
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

local function call_backend(source_path, output_path)
  local manifest = {
    source_path = source_path,
    output_path = output_path,
    duration_beats = state.duration_beats,
    sections = state.sections,
    lanes = state.lanes,
    bar_beats = state.bar_beats,
    strategy = STRATEGY_KEYS[state.strategy],
    density_scale = state.density_scale,
    source_influence = state.source_influence,
    variation = state.variation,
    recurrence = state.recurrence,
    transpose_range = state.transpose_range,
    time_warp = state.time_warp,
    seed = state.seed,
  }
  return nr.run_backend(script_dir, "midi_form_learner", manifest, TITLE)
end

local function write_midi(sections, events)
  local track = midi.ensure_track()
  if not track then midi.show_error("Could not find or create a track.", TITLE) return end
  local start_qn = reaper.TimeMap2_timeToQN(0, reaper.GetCursorPosition())
  local item, take = midi.create_midi_item(track, start_qn, start_qn + state.duration_beats, "MIDI Form Learner")
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
      reaper.AddProjectMarker2(0, false, pos, 0, "MFL " .. section.label, -1, 0)
    end
  end
  reaper.UpdateArrange()
end

local function generate()
  local notes, stats = selected_midi_notes()
  if #notes == 0 then
    reaper.MB("Select one or more MIDI items with notes before running the learner.", TITLE, 0)
    return
  end
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local base = (os.getenv("TMPDIR") or "/tmp") .. "/s3g_midi_form_learner_" .. stamp
  local source_path = base .. "_source.csv"
  local output_path = base .. "_plan.csv"
  if not write_source_csv(source_path, notes) then
    reaper.MB("Could not write temporary MIDI source data.", TITLE, 0)
    return
  end
  local log, elapsed = call_backend(source_path, output_path)
  os.remove(source_path)
  if not log then return end
  local sections, events = parse_plan(output_path)
  os.remove(output_path)
  if #events == 0 then
    reaper.MB("NumPy generated no MIDI events. Increase density or source influence.", TITLE, 0)
    return
  end
  reaper.Undo_BeginBlock()
  write_midi(sections, events)
  reaper.Undo_EndBlock(TITLE, -1)
  last_sections, last_events, last_source_stats = sections, events, stats
  status = string.format("Learned %d source notes -> %d events. NumPy %.2f sec.", stats.count, #events, elapsed or 0)
  reaper.ShowConsoleMsg("\n[MIDI Form Learner]\n" .. log .. "\n")
end

local function draw_preview()
  local notes, stats = selected_midi_notes()
  last_source_stats = stats or last_source_stats
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  local h = 260
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, COLORS.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, COLORS.edge)
  ImGui.DrawList_AddText(draw_list, x + 12, y + 10, COLORS.dim, "MIDI FORM LEARNER")
  local info = "Select MIDI notes as source vocabulary"
  if stats then
    info = string.format("%d selected source notes / %.1f source beats", stats.count, stats.span)
  end
  ImGui.DrawList_AddText(draw_list, x + 12, y + 30, COLORS.text, info)

  local left, top, right = x + 18, y + 66, x + w - 18
  local source_top, source_bottom = top, top + 70
  local form_top, form_bottom = top + 110, y + h - 32
  ImGui.DrawList_AddText(draw_list, left, source_top - 18, COLORS.dim, "SOURCE DENSITY / REGISTER")
  ImGui.DrawList_AddText(draw_list, left, form_top - 18, COLORS.dim, "GENERATED FORM INTENTION")
  ImGui.DrawList_AddRect(draw_list, left, source_top, right, source_bottom, COLORS.grid)
  ImGui.DrawList_AddRect(draw_list, left, form_top, right, form_bottom, COLORS.grid)

  if stats and #notes > 0 then
    local low, high = 127, 0
    for _, note in ipairs(notes) do
      low = math.min(low, note.pitch)
      high = math.max(high, note.pitch)
    end
    local span = math.max(1, high - low)
    for _, note in ipairs(notes) do
      local px = left + (note.start / math.max(0.03125, stats.span)) * (right - left)
      local py = source_bottom - ((note.pitch - low) / span) * (source_bottom - source_top - 8) - 4
      local pw = math.max(2, note.duration / math.max(0.25, stats.span) * (right - left))
      ImGui.DrawList_AddRectFilled(draw_list, px, py - 2, px + pw, py + 2, COLORS.source)
    end
  end

  local section_w = (right - left) / math.max(1, state.sections)
  for section = 1, state.sections do
    local sx0 = left + (section - 1) * section_w
    local sx1 = sx0 + section_w - 2
    local t = (section - 0.5) / math.max(1, state.sections)
    local energy
    local key = STRATEGY_KEYS[state.strategy]
    if key == "drift_variation" then energy = 0.25 + 0.7 * t
    elseif key == "fragmented_blocks" then energy = (section % 2 == 1) and 0.8 or 0.32
    elseif key == "channel_canon" then energy = 0.45 + 0.42 * (math.sin(section * 0.73) ^ 2)
    elseif key == "source_echo" then energy = 0.58
    elseif key == "terrain_hybrid" then energy = 0.20 + 0.75 * (math.sin(math.pi * t) ^ 0.55)
    else energy = (section % 3 == 1) and 0.85 or (0.36 + 0.45 * math.sin(math.pi * t)) end
    energy = math.max(0.08, math.min(1, energy * state.density_scale))
    local sy = form_bottom - energy * (form_bottom - form_top)
    ImGui.DrawList_AddRectFilled(draw_list, sx0, sy, sx1, form_bottom, COLORS.section)
    ImGui.DrawList_AddRect(draw_list, sx0, form_top, sx1, form_bottom, COLORS.grid)
    ImGui.DrawList_AddText(draw_list, sx0 + 5, form_bottom + 7, COLORS.dim, tostring(section))
  end
  local line_y = form_top + (1 - state.source_influence) * (form_bottom - form_top)
  ImGui.DrawList_AddLine(draw_list, left, line_y, right, line_y, COLORS.learned, 1.4)
  ImGui.DrawList_AddText(draw_list, left, y + h - 18, COLORS.dim,
    string.format("%s / %.0f beats / %d lanes", STRATEGY_NAMES[state.strategy], state.duration_beats, state.lanes))
  ImGui.SetCursorScreenPos(ctx, x, y + h + 12)
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 840, 780, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    draw_preview()
    _, state.strategy = combo("Learning strategy", STRATEGY_NAMES, state.strategy, 210)
    _, state.duration_beats = ImGui.SliderInt(ctx, "Duration beats", state.duration_beats, 16, 4096)
    _, state.sections = ImGui.SliderInt(ctx, "Sections", state.sections, 1, 32)
    _, state.lanes = ImGui.SliderInt(ctx, "MIDI channels / lanes", state.lanes, 1, 16)
    _, state.bar_beats = ImGui.SliderDouble(ctx, "Bar beats", state.bar_beats, 1, 16, "%.2f")
    ImGui.Separator(ctx)
    _, state.density_scale = ImGui.SliderDouble(ctx, "Density scale", state.density_scale, 0.05, 2.5, "%.3f")
    _, state.source_influence = ImGui.SliderDouble(ctx, "Source influence", state.source_influence, 0, 1, "%.3f")
    _, state.variation = ImGui.SliderDouble(ctx, "Variation", state.variation, 0, 1, "%.3f")
    _, state.recurrence = ImGui.SliderDouble(ctx, "Motif recurrence", state.recurrence, 0, 1, "%.3f")
    _, state.time_warp = ImGui.SliderDouble(ctx, "Timing warp", state.time_warp, 0, 1, "%.3f")
    _, state.transpose_range = ImGui.SliderInt(ctx, "Transpose range", state.transpose_range, 0, 36)
    _, state.seed = ImGui.InputInt(ctx, "Seed", state.seed)
    _, state.add_markers = ImGui.Checkbox(ctx, "Add project markers for sections", state.add_markers)
    if ImGui.Button(ctx, "New Seed", 100, 28) then state.seed = state.seed + 1 end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Generate Learned Form", 190, 28) then generate() end
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, COLORS.dim, status)
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
