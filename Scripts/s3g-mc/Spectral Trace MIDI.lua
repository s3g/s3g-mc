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
local ui_theme = nil
do
  local _s3g_theme_path = ({ reaper.get_action_context() })[2]
  if not _s3g_theme_path or _s3g_theme_path == "" then
    _s3g_theme_path = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
  end
  local _s3g_theme_dir = _s3g_theme_path:match("^(.*[/\\])") or ""
  package.path = _s3g_theme_dir .. "?.lua;" .. package.path
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme then
    ui_theme = _s3g_theme
    if _s3g_theme.install then _s3g_theme.install(ImGui) end
  end
end


local TITLE = "Spectral Trace MIDI"
local ctx = ImGui.CreateContext(TITLE)
local open = true
local status = ""

local function ui_slider_int(label, value, min_value, max_value)
  return ui_theme.slider_int(ImGui, ctx, label, value, min_value, max_value)
end

local function ui_slider_double(label, value, min_value, max_value, format)
  return ui_theme.slider_double(ImGui, ctx, label, value, min_value, max_value, format)
end

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
local function combo(label, labels, value, width)
  if ui_theme and ui_theme.combo_row then return ui_theme.combo_row(ImGui, ctx, label, labels, value, width) end
  local function text_width(text)
    if ImGui.CalcTextSize then
      local ok, w = pcall(ImGui.CalcTextSize, ctx, tostring(text or ""))
      if ok and type(w) == "number" then return w end
    end
    return #tostring(text or "") * 7
  end
  local combo_w = text_width(labels[value or 1] or "") + 38
  for _, item in ipairs(labels or {}) do combo_w = math.max(combo_w, text_width(item) + 38) end
  ImGui.SetNextItemWidth(ctx, math.max(80, math.min(width or 170, combo_w)))
  local changed, next_value = ImGui.Combo(ctx, "##combo_" .. tostring(label or ""), value - 1, table.concat(labels, "\0") .. "\0")
  return changed, next_value + 1
end

local function ui_input_int(label, value, step, step_fast, width)
  if ui_theme and ui_theme.input_int_row then return ui_theme.input_int_row(ImGui, ctx, label, value, step, step_fast, width) end
  return ImGui.InputInt(ctx, "##input_" .. tostring(label or ""), value, step or 1, step_fast or 10)
end

local function push_soft_panel()
  if ui_theme and ui_theme.push_soft_panel then return ui_theme.push_soft_panel(ImGui, ctx) end
  return nil
end

local function pop_soft_panel(stack)
  if ui_theme and ui_theme.pop_soft_panel then ui_theme.pop_soft_panel(ImGui, ctx, stack) end
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


local function draw_footer()
  ImGui.Dummy(ctx, 1, 6)
  if ImGui.Button(ctx, "LOAD SELECTED", 120, 28) then
    if load_selected_source(true) then
      state.duration_beats = math.floor(selected_item_beats() + 0.5)
      last_events = {}
    end
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "NEW SEED", 100, 28) then state.seed = state.seed + 1 end
  ImGui.SameLine(ctx)
  if not entry then ImGui.BeginDisabled(ctx) end
  if ImGui.Button(ctx, "GENERATE MIDI", 140, 28) then generate() end
  if not entry then ImGui.EndDisabled(ctx) end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "CLOSE", 92, 28) then open = false end
  ImGui.SameLine(ctx)
  muted_text(status)
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 860, 600, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local footer_height = 0
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    local content_height = math.max(220, avail_h - footer_height)
    local main_panel_style = push_soft_panel()
    local child_visible = ImGui.BeginChild(ctx, "##main_content", 0, content_height)
    if child_visible then
      _, state.mode = combo("TRACE", MODE_NAMES, state.mode, 170)
      _, state.quantize = combo("PITCH MAP", QUANT_NAMES, state.quantize, 150)
      _, state.channel_mode = combo("MIDI MODE", CHANNEL_NAMES, state.channel_mode, 170)

      _, state.fft = combo("FFT", FFT_NAMES, state.fft, 120)
      _, state.event_rate = ui_slider_double("EVENT RATE", state.event_rate, 0.5, 24.0, "%.1f")
      _, state.partials = ui_slider_int("PARTIALS", state.partials, 1, 12)
      _, state.density = ui_slider_double("DENS", state.density, 0.0, 1.0, "%.3f")
      _, state.floor_db = ui_slider_double("FLOOR DB", state.floor_db, -90.0, -12.0, "%.1f")
      _, state.min_hz = ui_slider_double("MIN HZ", state.min_hz, 20.0, 2000.0, "%.1f")
      _, state.max_hz = ui_slider_double("MAX HZ", state.max_hz, math.max(state.min_hz + 20.0, 100.0), 12000.0, "%.1f")
      _, state.pitch_smooth = ui_slider_double("SMOOTH", state.pitch_smooth, 0.0, 0.95, "%.3f")

      _, state.root = combo("ROOT", ROOTS, state.root, 90)
      _, state.scale = combo("SCALE", SCALES, state.scale, 190)
      _, state.lanes = ui_slider_int("MIDI LANES", state.lanes, 1, 16)
      _, state.min_note = ui_slider_double("MIN BEATS", state.min_note, 0.03125, 2.0, "%.3f")
      _, state.max_note = ui_slider_double("MAX BEATS", state.max_note, state.min_note, 8.0, "%.3f")
      _, state.velocity_floor = ui_slider_int("VFLOOR", state.velocity_floor, 1, 127)
      _, state.velocity_scale = ui_slider_int("VRNG", state.velocity_scale, 1, 127)
      _, state.follow_item_length = ImGui.Checkbox(ctx, "FOLLOW SELECTED ITEM LENGTH", state.follow_item_length)
      if not state.follow_item_length then
        _, state.duration_beats = ui_slider_int("BEATS", state.duration_beats, 1, 2048)
      end
      _, state.seed = ui_input_int("SEED", state.seed, 1, 10, 110)
      draw_footer()
    end
    ImGui.EndChild(ctx)
    pop_soft_panel(main_panel_style)
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
