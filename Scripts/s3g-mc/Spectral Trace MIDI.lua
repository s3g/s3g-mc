-- @description Spectral Trace MIDI
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3; NumPy; MIDI Rule Library.lua; NumPy Render Library.lua
-- @category MIDI Composition
-- @render No
-- @method NumPy-backed audio-to-MIDI analyzer. Select one WAV-backed media item; spectral peaks, centroid motion, or partial stacks are traced into an ordinary editable MIDI item with optional scale quantization and MIDI-channel lane mapping.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local midi = dofile(script_dir .. "MIDI Rule Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Spectral Trace MIDI", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "Spectral Trace MIDI"
local ctx = ImGui.CreateContext(TITLE)
local open = true
local status = ""

local ROOTS = midi.ROOT_NAMES
local SCALES = midi.SCALE_NAMES
local MODE_NAMES = { "Partial stack", "Melody trace", "Centroid trace" }
local MODE_KEYS = { "partials", "melody", "centroid" }
local QUANT_NAMES = { "Scale", "Raw chromatic" }
local QUANT_KEYS = { "scale", "raw" }
local CHANNEL_NAMES = { "Audio channel", "Partial rank", "Time sweep", "Round-robin", "Single channel" }
local CHANNEL_KEYS = { "audio", "rank", "time", "source", "single" }
local FFT_NAMES = { "1024", "2048", "4096", "8192" }
local FFT_VALUES = { 1024, 2048, 4096, 8192 }

local function source_is_wav(path)
  return tostring(path or ""):lower():match("%.wav$") ~= nil
end

local entry = nil

local function selected_item_beats()
  if not entry then return 16 end
  local start_time = entry.position or reaper.GetCursorPosition()
  local end_time = start_time + math.max(0.001, entry.length or 1.0)
  local start_qn = reaper.TimeMap2_timeToQN(0, start_time)
  local end_qn = reaper.TimeMap2_timeToQN(0, end_time)
  return math.max(0.25, end_qn - start_qn)
end

local function load_selected_source(show_message)
  local entries = nr.selected_entries()
  local next_entry = entries[1]
  if not next_entry then
    if show_message then status = "Select a WAV-backed audio item, then click Load Selected." end
    return false
  end
  if not source_is_wav(next_entry.filename) then
    status = "Selected item is not WAV-backed."
    if show_message then reaper.MB("Spectral Trace MIDI requires a WAV-backed media item.", TITLE, 0) end
    return false
  end
  entry = next_entry
  status = "Loaded " .. entry.name
  return true
end

local state = {
  mode = 1,
  quantize = 1,
  channel_mode = 1,
  fft = 2,
  event_rate = 6.0,
  partials = 3,
  density = 0.82,
  floor_db = -48.0,
  min_hz = 55.0,
  max_hz = 6000.0,
  pitch_smooth = 0.35,
  lanes = 8,
  root = 1,
  scale = 1,
  min_note = 0.125,
  max_note = 0.75,
  velocity_floor = 28,
  velocity_scale = 92,
  seed = 17,
  follow_item_length = true,
  duration_beats = math.floor(selected_item_beats() + 0.5),
}

local last_events = {}
load_selected_source(false)
if entry then state.duration_beats = math.floor(selected_item_beats() + 0.5) end

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local COLORS = {
  panel = color(0.055, 0.060, 0.064, 1),
  edge = color(0.30, 0.32, 0.33, 1),
  grid = color(0.48, 0.52, 0.51, 0.20),
  text = color(0.80, 0.84, 0.82, 1),
  dim = color(0.50, 0.55, 0.54, 1),
  trace = color(0.30, 0.78, 0.72, 1),
  trace2 = color(0.95, 0.74, 0.28, 1),
  trace3 = color(0.72, 0.48, 1.00, 1),
}

local function combo(label, labels, value, width)
  ImGui.SetNextItemWidth(ctx, width or 170)
  local changed, next_value = ImGui.Combo(ctx, label, value - 1, table.concat(labels, "\0") .. "\0")
  return changed, next_value + 1
end

local function parse_plan(path)
  local events = {}
  local file = io.open(path, "r")
  if not file then return events end
  for line in file:lines() do
    if not line:match("^type,") then
      local kind, _index, start_b, dur_b, pitch, velocity, channel =
        line:match("^([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),")
      if kind == "event" then
        events[#events + 1] = {
          start = tonumber(start_b) or 0,
          duration = tonumber(dur_b) or 0.125,
          pitch = tonumber(pitch) or 60,
          velocity = tonumber(velocity) or 80,
          channel = tonumber(channel) or 0,
        }
      end
    end
  end
  file:close()
  return events
end

local function call_backend(output_path)
  if not entry then return nil end
  local duration_beats = state.follow_item_length and selected_item_beats() or state.duration_beats
  local scale_name = SCALES[state.scale]
  local scale_intervals = table.concat(midi.SCALES[scale_name] or midi.SCALES.Chromatic, " ")
  local manifest = {
    output_path = output_path,
    source_path = entry.filename,
    source_start = entry.start_offset,
    source_duration = entry.length * math.max(0.000001, entry.playrate),
    sample_rate = nr.source_sample_rate(entry),
    duration_beats = duration_beats,
    trace_mode = MODE_KEYS[state.mode],
    quantize = QUANT_KEYS[state.quantize],
    channel_mode = CHANNEL_KEYS[state.channel_mode],
    fft_size = FFT_VALUES[state.fft] or 2048,
    hop = math.floor((FFT_VALUES[state.fft] or 2048) / 4),
    event_rate = state.event_rate,
    partials = state.partials,
    density = state.density,
    floor_db = state.floor_db,
    min_hz = state.min_hz,
    max_hz = state.max_hz,
    pitch_smooth = state.pitch_smooth,
    lanes = state.lanes,
    root = midi.ROOTS[ROOTS[state.root]] or 0,
    scale = scale_name,
    scale_intervals = scale_intervals,
    min_note_beats = state.min_note,
    max_note_beats = state.max_note,
    velocity_floor = state.velocity_floor,
    velocity_scale = state.velocity_scale,
    seed = state.seed,
  }
  return nr.run_backend(script_dir, "midi_spectral_trace", manifest, TITLE)
end

local function write_midi(events)
  if not entry then return end
  local track = midi.ensure_track()
  if not track then midi.show_error("Could not find or create a track.", TITLE) return end
  local start_qn = reaper.TimeMap2_timeToQN(0, reaper.GetCursorPosition())
  local duration_beats = state.follow_item_length and selected_item_beats() or state.duration_beats
  local item, take = midi.create_midi_item(track, start_qn, start_qn + duration_beats, "Spectral Trace MIDI")
  if not take then midi.show_error("Could not create MIDI item.", TITLE) return end
  for _, event in ipairs(events) do
    local note_start = start_qn + event.start
    local note_end = note_start + math.max(0.03125, event.duration)
    midi.insert_note_qn(take, note_start, note_end, event.channel, event.pitch, event.velocity)
  end
  reaper.MIDI_Sort(take)
  reaper.UpdateArrange()
end

local function generate()
  if not entry then
    if not load_selected_source(true) then return end
  end
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local path = (os.getenv("TMPDIR") or "/tmp") .. "/s3g_midi_spectral_trace_" .. stamp .. ".csv"
  local log, elapsed = call_backend(path)
  if not log then return end
  local events = parse_plan(path)
  os.remove(path)
  if #events == 0 then
    reaper.MB("No spectral MIDI events were generated. Lower the floor dB, raise density, or widen the frequency range.", TITLE, 0)
    return
  end
  reaper.Undo_BeginBlock()
  write_midi(events)
  reaper.Undo_EndBlock(TITLE, -1)
  last_events = events
  status = string.format("Wrote %d MIDI events. NumPy %.2f sec.", #events, elapsed or 0)
  reaper.ShowConsoleMsg("\n[Spectral Trace MIDI]\n" .. log .. "\n")
end

local function draw_preview()
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  local h = 245
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, COLORS.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, COLORS.edge)
  ImGui.DrawList_AddText(draw_list, x + 12, y + 10, COLORS.dim, "SPECTRAL TRACE MIDI")
  local source_label = entry and
    (entry.name .. "  /  " .. tostring(entry.channels) .. "ch  /  " .. string.format("%.2fs", entry.length or 0)) or
    "No source loaded. Select a WAV item and click Load Selected."
  ImGui.DrawList_AddText(draw_list, x + 12, y + 28, entry and COLORS.text or COLORS.dim, source_label)

  local left, top, right, bottom = x + 18, y + 62, x + w - 18, y + h - 34
  for i = 0, 8 do
    local gy = top + (bottom - top) * i / 8
    ImGui.DrawList_AddLine(draw_list, left, gy, right, gy, COLORS.grid, 1)
  end
  for i = 0, 12 do
    local gx = left + (right - left) * i / 12
    ImGui.DrawList_AddLine(draw_list, gx, top, gx, bottom, COLORS.grid, 1)
  end

  local points = 96
  local last_x, last_y
  for i = 0, points do
    local t = i / points
    local contour = 0.52 + 0.32 * math.sin(t * math.pi * (2.0 + state.partials * 0.42) + state.seed * 0.07)
    contour = contour + 0.12 * math.sin(t * math.pi * 13.0)
    contour = math.max(0.02, math.min(0.98, contour))
    local px = left + t * (right - left)
    local py = bottom - contour * (bottom - top)
    if last_x then ImGui.DrawList_AddLine(draw_list, last_x, last_y, px, py, COLORS.trace, 1.4) end
    last_x, last_y = px, py
  end

  for i = 1, math.min(160, #last_events) do
    local event = last_events[i]
    local t = event.start / math.max(0.25, state.follow_item_length and selected_item_beats() or state.duration_beats)
    local p = (event.pitch - 24) / 72
    local px = left + math.max(0, math.min(1, t)) * (right - left)
    local py = bottom - math.max(0, math.min(1, p)) * (bottom - top)
    local col = (event.channel % 3 == 0) and COLORS.trace2 or ((event.channel % 3 == 1) and COLORS.trace or COLORS.trace3)
    ImGui.DrawList_AddCircleFilled(draw_list, px, py, 2.8, col)
  end

  local caption = string.format("%s / %s / %.1f events-sec / %d lanes",
    MODE_NAMES[state.mode], QUANT_NAMES[state.quantize], state.event_rate, state.lanes)
  ImGui.DrawList_AddText(draw_list, x + 18, y + h - 23, COLORS.dim, caption)
  if entry and entry.channels > 16 then
    ImGui.DrawList_AddText(draw_list, x + w - 210, y + h - 23, COLORS.dim, "first 16 source channels")
  end
  ImGui.SetCursorScreenPos(ctx, x, y + h + 12)
end

local function draw_footer()
  ImGui.Separator(ctx)
  if ImGui.Button(ctx, "Load Selected", 120, 28) then
    if load_selected_source(true) then
      state.duration_beats = math.floor(selected_item_beats() + 0.5)
      last_events = {}
    end
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "New Seed", 100, 28) then state.seed = state.seed + 1 end
  ImGui.SameLine(ctx)
  if not entry then ImGui.BeginDisabled(ctx) end
  if ImGui.Button(ctx, "Generate MIDI", 140, 28) then generate() end
  if not entry then ImGui.EndDisabled(ctx) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Close", 92, 28) then open = false end
  ImGui.SameLine(ctx)
  ImGui.TextColored(ctx, COLORS.dim, status)
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 860, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    draw_preview()
    _, state.mode = combo("Trace mode", MODE_NAMES, state.mode, 170)
    ImGui.SameLine(ctx)
    _, state.quantize = combo("Pitch mapping", QUANT_NAMES, state.quantize, 150)
    ImGui.SameLine(ctx)
    _, state.channel_mode = combo("MIDI channel mode", CHANNEL_NAMES, state.channel_mode, 170)

    _, state.fft = combo("FFT size", FFT_NAMES, state.fft, 120)
    ImGui.SameLine(ctx)
    _, state.event_rate = ImGui.SliderDouble(ctx, "Events per second", state.event_rate, 0.5, 24.0, "%.1f")
    _, state.partials = ImGui.SliderInt(ctx, "Partials per event", state.partials, 1, 12)
    _, state.density = ImGui.SliderDouble(ctx, "Density", state.density, 0.0, 1.0, "%.3f")
    _, state.floor_db = ImGui.SliderDouble(ctx, "Spectral floor dB", state.floor_db, -90.0, -12.0, "%.1f")
    _, state.min_hz = ImGui.SliderDouble(ctx, "Minimum Hz", state.min_hz, 20.0, 2000.0, "%.1f")
    _, state.max_hz = ImGui.SliderDouble(ctx, "Maximum Hz", state.max_hz, math.max(state.min_hz + 20.0, 100.0), 12000.0, "%.1f")
    _, state.pitch_smooth = ImGui.SliderDouble(ctx, "Pitch smoothing", state.pitch_smooth, 0.0, 0.95, "%.3f")

    ImGui.Separator(ctx)
    _, state.root = combo("Root", ROOTS, state.root, 90)
    ImGui.SameLine(ctx)
    _, state.scale = combo("Scale", SCALES, state.scale, 190)
    _, state.lanes = ImGui.SliderInt(ctx, "MIDI channels / lanes", state.lanes, 1, 16)
    _, state.min_note = ImGui.SliderDouble(ctx, "Minimum note beats", state.min_note, 0.03125, 2.0, "%.3f")
    _, state.max_note = ImGui.SliderDouble(ctx, "Maximum note beats", state.max_note, state.min_note, 8.0, "%.3f")
    _, state.velocity_floor = ImGui.SliderInt(ctx, "Velocity floor", state.velocity_floor, 1, 127)
    _, state.velocity_scale = ImGui.SliderInt(ctx, "Velocity range", state.velocity_scale, 1, 127)
    _, state.follow_item_length = ImGui.Checkbox(ctx, "Follow selected item length", state.follow_item_length)
    if not state.follow_item_length then
      _, state.duration_beats = ImGui.SliderInt(ctx, "Duration beats", state.duration_beats, 1, 2048)
    end
    _, state.seed = ImGui.InputInt(ctx, "Seed", state.seed)
    draw_footer()
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
