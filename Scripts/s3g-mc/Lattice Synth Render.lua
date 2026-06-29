-- @description Lattice Synth Render
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; MIDI Rule Library.lua; JSFX: s3g MC Lattice Synth Engine
-- @category Procedural Synthesis
-- @render Yes; creates a temporary MIDI-driven synth track and renders it to a multichannel media item.
-- @method Offline renderer for the Lattice Synth engine. The script creates a temporary MIDI score from a table-scanning gesture model, feeds it to the Lattice Synth JSFX, renders the selected duration as a multichannel stem, then removes the temporary generator track.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local midi = dofile(script_dir .. "MIDI Rule Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Lattice Synth Render", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "Lattice Synth Render"
local FX_NAME = "s3g MC Lattice Synth Engine"
local FX_NAME_CLEAN = "MC Lattice Synth Engine"
local EXTSTATE_SECTION = "s3g_mc_lattice_synth_render"

local ROOTS = midi.ROOT_NAMES
local SCALES = midi.SCALE_NAMES
local TEMPLATES = { "Circulating", "Diagonal fold", "Spiral", "Cross address", "Egress pull" }
local RHYTHMS = { "Even path", "Euclidean path", "Ingress bursts", "Egress pull phrases" }
local PITCH_MODES = { "Pitch sets frequency", "Pitch transposes base", "Gate only" }
local CH_NAMES, CH_VALUES = {}, {}
for ch = 2, 64, 2 do
  CH_VALUES[#CH_VALUES + 1] = ch
  CH_NAMES[#CH_NAMES + 1] = tostring(ch)
end
CH_VALUES[#CH_VALUES + 1] = 128
CH_NAMES[#CH_NAMES + 1] = "128"

local PARAM = {
  channels = 0, template = 1, rows = 2, cols = 3, layers = 4,
  in_row = 5, in_col = 6, out_row = 7, out_col = 8,
  gesture_pos = 9, mutation = 10, resonance = 11, damping = 12,
  brightness = 13, divider = 14, feedback = 15, spread = 16,
  base_freq = 17, gain = 18, seed = 19, clear = 20, midi = 21,
  pitch = 22, focus = 23, vel_excitation = 24, vel_brightness = 25,
  gate = 26, focus_width = 27,
}

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function db_to_amp(db) return 10 ^ ((db or 0) / 20) end

local function amp_to_db(amp)
  if not amp or amp <= 0 then return -150 end
  return 20 * math.log(amp, 10)
end

local function hash01(x)
  local v = math.sin((x + 1.2345) * 12.9898) * 43758.5453
  return v - math.floor(v)
end

local function wrap(value, count)
  return ((math.floor(value) - 1) % math.max(1, count)) + 1
end

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local COLORS = {
  panel = color(0.055, 0.060, 0.064, 1),
  edge = color(0.30, 0.32, 0.33, 1),
  grid = color(0.48, 0.52, 0.51, 0.32),
  text = color(0.80, 0.84, 0.82, 1),
  dim = color(0.50, 0.55, 0.54, 1),
  line = color(0.28, 0.72, 0.68, 1),
  hit = color(0.95, 0.74, 0.28, 1),
  ingress = color(0.16, 0.80, 0.95, 1),
  egress = color(1.00, 0.36, 0.28, 1),
}

local ctx

local function get_time_defaults()
  local start_pos, end_pos = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if end_pos > start_pos then return start_pos, end_pos - start_pos end
  return reaper.GetCursorPosition(), 20.0
end

local function combo(label, labels, value, width)
  ImGui.SetNextItemWidth(ctx, width or 170)
  local changed, next_value = ImGui.Combo(ctx, label, value - 1, table.concat(labels, "\0") .. "\0")
  return changed, next_value + 1
end

local function add_named_jsfx(track, name)
  local fx = reaper.TrackFX_AddByName(track, "JS: " .. name, false, -1)
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, name, false, -1) end
  return fx
end

local function add_synth_fx(track)
  local fx = add_named_jsfx(track, FX_NAME)
  if fx < 0 then fx = add_named_jsfx(track, FX_NAME_CLEAN) end
  return fx
end

local function set_param(track, fx, param, value)
  reaper.TrackFX_SetParam(track, fx, param, value)
end

local function item_peak(item)
  if not item or not reaper.ValidatePtr2(0, item, "MediaItem*") then return 0 end
  if not reaper.CreateTakeAudioAccessor or not reaper.GetAudioAccessorSamples or not reaper.new_array then
    return 0, "REAPER audio accessor API is unavailable."
  end
  local take = reaper.GetActiveTake(item)
  if not take or reaper.TakeIsMIDI(take) then return 0 end
  local channels = math.max(1, math.min(128, mc.get_take_source_channels(take) or 1))
  local sample_rate = reaper.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
  sample_rate = sample_rate and sample_rate > 0 and sample_rate or 48000
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH") or 0
  if item_length <= 0 then return 0 end
  local accessor = reaper.CreateTakeAudioAccessor(take)
  if not accessor then return 0 end
  local accessor_start = reaper.GetAudioAccessorStartTime and reaper.GetAudioAccessorStartTime(accessor) or
    (reaper.GetMediaItemInfo_Value(item, "D_POSITION") or 0)
  local peak, offset, chunk_frames = 0, 0, 8192
  local buffer = reaper.new_array(chunk_frames * channels)
  while offset < item_length do
    local frames = math.floor(math.min(chunk_frames, (item_length - offset) * sample_rate))
    if frames <= 0 then break end
    buffer.clear()
    reaper.GetAudioAccessorSamples(accessor, sample_rate, channels, accessor_start + offset, frames, buffer)
    local values = buffer.table()
    for index = 1, frames * channels do
      local sample = values[index]
      if sample then peak = math.max(peak, math.abs(sample)) end
    end
    offset = offset + frames / sample_rate
  end
  reaper.DestroyAudioAccessor(accessor)
  return peak
end

local function normalize_rendered_track(track, target_db)
  local peak = 0
  for item_index = 0, reaper.CountTrackMediaItems(track) - 1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    local item_peak_value, err = item_peak(item)
    if err then return nil, err end
    peak = math.max(peak, item_peak_value or 0)
  end
  if peak <= 0 then return nil, "Rendered item peak is silent; normalize skipped." end
  local gain = math.min(db_to_amp(target_db) / peak, db_to_amp(60))
  for item_index = 0, reaper.CountTrackMediaItems(track) - 1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    local current_vol = reaper.GetMediaItemInfo_Value(item, "D_VOL") or 1
    reaper.SetMediaItemInfo_Value(item, "D_VOL", current_vol * gain)
  end
  return { peak = peak, gain = gain, target_db = target_db }
end

local function table_value(row, col, layer, settings)
  row = wrap(row, settings.rows)
  col = wrap(col, settings.cols)
  layer = wrap(layer, settings.layers)
  local diag = (row * 7 + col * 11 + layer * 13 + settings.seed * 3) % 23
  local wave = math.sin(row * 1.73 + col * 2.11 + layer * 0.83 + settings.seed * 0.07)
  return clamp((diag / 22) * 0.62 + ((wave + 1) * 0.5) * 0.38, 0, 1)
end

local function step_position(row, col, layer, index, settings)
  if settings.template == 2 then
    row = row + 1
    col = col + ((index % 2 == 0) and -1 or 1)
  elseif settings.template == 3 then
    local phase = index % 4
    if phase == 0 then col = col + 1
    elseif phase == 1 then row = row + 1
    elseif phase == 2 then col = col - 1
    else row = row - 1 end
  elseif settings.template == 4 then
    if index % 3 == 0 then
      row = settings.egress_row
      col = col + 1
    elseif index % 3 == 1 then
      col = settings.egress_col
      row = row + 1
    else
      row = row - 1
      col = col - 1
    end
  elseif settings.template == 5 then
    row = row + (settings.egress_row > row and 1 or (settings.egress_row < row and -1 or 0))
    col = col + (settings.egress_col > col and 1 or (settings.egress_col < col and -1 or 0))
    if row == settings.egress_row and col == settings.egress_col then
      row, col = settings.ingress_row, settings.ingress_col
    end
  else
    col = col + 1
    if col > settings.cols then
      col = 1
      row = row + 1
    end
  end
  if math.random() < settings.mutation then
    row = row + math.floor(math.random() * 3) - 1
    col = col + math.floor(math.random() * 3) - 1
  end
  return wrap(row, settings.rows), wrap(col, settings.cols), wrap(layer + 1, settings.layers)
end

local function make_events(settings)
  midi.seed(settings.seed + 991)
  local pattern = midi.euclidean_pattern(settings.pulses, settings.events, settings.rotate)
  local row, col, layer = settings.ingress_row, settings.ingress_col, 1
  local events, accepted = {}, 0
  for index = 1, settings.events do
    local rhythm_ok = settings.rhythm == 1 or pattern[index]
    if settings.rhythm == 3 then rhythm_ok = (index % settings.burst_gap) <= settings.burst_len end
    if settings.rhythm == 4 then rhythm_ok = (index % 5 == 1) or pattern[index] end
    if rhythm_ok and midi.chance(settings.density) then
      accepted = accepted + 1
      local a = table_value(row, col, layer, settings)
      local b = table_value(row + 1, col - 1, layer + 1, settings)
      local c = table_value(row - 1, col + 1, layer + 2, settings)
      local degree = math.floor((a * settings.pitch_span) - settings.pitch_span * 0.35 + b * 7 + 0.5)
      local pitch = midi.scale_pitch(ROOTS[settings.root], SCALES[settings.scale], degree, settings.octave, settings.register_span)
      local channel = math.floor(c * math.max(0, settings.channels - 1) + 0.5)
      local velocity = midi.velocity(settings.velocity + b * 18, settings.accent, accepted, 5, 6)
      events[#events + 1] = {
        step = index,
        row = row,
        col = col,
        pitch = pitch,
        channel = clamp(channel, 0, math.min(15, settings.channels - 1)),
        velocity = velocity,
        length = clamp(settings.note_len * (0.35 + a * 1.15), 0.05, 2.0),
      }
    end
    row, col, layer = step_position(row, col, layer, index, settings)
  end
  return events
end

local function write_midi_item(track, settings, events)
  local start_qn = reaper.TimeMap2_timeToQN(0, settings.start_pos)
  local end_qn = reaper.TimeMap2_timeToQN(0, settings.start_pos + settings.duration)
  local item, take = midi.create_midi_item(track, start_qn, end_qn, "Lattice render MIDI")
  local total_beats = math.max(0.25, end_qn - start_qn)
  local step_beats = total_beats / math.max(1, settings.events)
  for _, event in ipairs(events) do
    local note_start = start_qn + (event.step - 1) * step_beats
    midi.insert_note_qn(take, note_start, note_start + step_beats * event.length, event.channel, event.pitch, event.velocity)
  end
  reaper.MIDI_Sort(take)
  return item
end

local function render_lattice(settings)
  local channels = CH_VALUES[settings.channel_index] or 8
  settings.channels = channels
  reaper.Undo_BeginBlock()
  local selected_tracks = mc.save_selected_tracks()
  local insert_index = reaper.CountTracks(0)
  local synth_track, render_track, render_error, did_render = nil, nil, nil, false
  local normalize_result, normalize_warning
  local events = make_events(settings)
  local ok, err = xpcall(function()
    synth_track = mc.insert_track_at(insert_index, "tmp Lattice Synth", mc.reaper_track_channel_count(channels))
    reaper.SetMediaTrackInfo_Value(synth_track, "B_MAINSEND", 0)
    local fx = add_synth_fx(synth_track)
    if fx < 0 then
      render_error = "Could not load JS: " .. FX_NAME
      return
    end
    set_param(synth_track, fx, PARAM.channels, channels)
    set_param(synth_track, fx, PARAM.template, settings.template - 1)
    set_param(synth_track, fx, PARAM.rows, settings.rows)
    set_param(synth_track, fx, PARAM.cols, settings.cols)
    set_param(synth_track, fx, PARAM.layers, settings.layers)
    set_param(synth_track, fx, PARAM.in_row, settings.ingress_row)
    set_param(synth_track, fx, PARAM.in_col, settings.ingress_col)
    set_param(synth_track, fx, PARAM.out_row, settings.egress_row)
    set_param(synth_track, fx, PARAM.out_col, settings.egress_col)
    set_param(synth_track, fx, PARAM.gesture_pos, settings.gesture_pos)
    set_param(synth_track, fx, PARAM.mutation, settings.mutation)
    set_param(synth_track, fx, PARAM.resonance, settings.resonance)
    set_param(synth_track, fx, PARAM.damping, settings.damping)
    set_param(synth_track, fx, PARAM.brightness, settings.brightness)
    set_param(synth_track, fx, PARAM.divider, settings.divider)
    set_param(synth_track, fx, PARAM.feedback, settings.feedback)
    set_param(synth_track, fx, PARAM.spread, settings.spread)
    set_param(synth_track, fx, PARAM.base_freq, settings.base_freq)
    set_param(synth_track, fx, PARAM.gain, settings.gain_db)
    set_param(synth_track, fx, PARAM.seed, settings.seed)
    set_param(synth_track, fx, PARAM.clear, 1)
    set_param(synth_track, fx, PARAM.midi, 1)
    set_param(synth_track, fx, PARAM.pitch, settings.pitch_mode - 1)
    set_param(synth_track, fx, PARAM.focus, 1)
    set_param(synth_track, fx, PARAM.vel_excitation, settings.vel_excitation)
    set_param(synth_track, fx, PARAM.vel_brightness, settings.vel_brightness)
    set_param(synth_track, fx, PARAM.gate, settings.gate)
    set_param(synth_track, fx, PARAM.focus_width, settings.focus_width)
    write_midi_item(synth_track, settings, events)
    local before_guids = mc.snapshot_track_guids()
    mc.select_only_track(synth_track)
    mc.with_render_bounds_for_range(settings.start_pos, settings.start_pos + settings.duration, function()
      local before_count = reaper.CountTracks(0)
      reaper.Main_OnCommand(mc.render_multichannel_post_fader_stem_command(), 0)
      did_render = reaper.CountTracks(0) > before_count
      if did_render then
        render_track = mc.find_new_track(before_guids) or mc.get_selected_track_excluding({ synth_track })
        if render_track then
          reaper.GetSetMediaTrackInfo_String(render_track, "P_NAME", "Lattice Synth render (" .. tostring(channels) .. "ch)", true)
          reaper.SetMediaTrackInfo_Value(render_track, "I_NCHAN", mc.reaper_track_channel_count(channels))
          reaper.SetMediaTrackInfo_Value(render_track, "B_MAINSEND", 1)
          reaper.SetMediaTrackInfo_Value(render_track, "D_VOL", settings.insert_gain or 0.25)
          mc.set_track_items_length(render_track, settings.duration)
          local rendered_start = mc.track_items_bounds({ render_track })
          mc.move_track_items_by(render_track, settings.start_pos - rendered_start)
          if settings.normalize then
            normalize_result, normalize_warning = normalize_rendered_track(render_track, settings.normalize_db or -12.0)
          end
        end
      end
    end)
  end, debug.traceback)
  if not ok then render_error = err end
  if synth_track and reaper.ValidatePtr2(0, synth_track, "MediaTrack*") then
    reaper.DeleteTrack(synth_track)
  end
  if render_track and reaper.ValidatePtr2(0, render_track, "MediaTrack*") then
    mc.select_only_track(render_track)
  else
    mc.restore_selected_tracks(selected_tracks)
  end
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Lattice Synth Render", -1)
  if render_error then
    reaper.MB(render_error .. "\n\nMake sure the s3g JSFX files are installed in REAPER/Effects/s3g.", TITLE, 0)
  elseif not did_render then
    reaper.MB("REAPER did not create a rendered multichannel Lattice synth item.", TITLE, 0)
  else
    local lines = {
      "Duration: " .. string.format("%.2f sec", settings.duration),
      "Output channels: " .. tostring(channels),
      "Template: " .. (TEMPLATES[settings.template] or "?"),
      "Rhythm: " .. (RHYTHMS[settings.rhythm] or "?"),
      "MIDI events: " .. tostring(#events),
    }
    if normalize_result then
      lines[#lines + 1] = "Peak normalize: " .. string.format("%.1f dB", normalize_result.target_db)
      lines[#lines + 1] = "Measured peak before item gain: " .. string.format("%.2f dBFS", amp_to_db(normalize_result.peak))
      lines[#lines + 1] = "Applied item gain: " .. string.format("%+.2f dB", amp_to_db(normalize_result.gain))
    elseif normalize_warning then
      lines[#lines + 1] = "Peak normalize: skipped (" .. normalize_warning .. ")"
    end
    reaper.ShowConsoleMsg("\n[Lattice Synth Render]\n" .. table.concat(lines, "\n") .. "\n")
  end
end

local start_pos, duration = get_time_defaults()
ctx = ImGui.CreateContext(TITLE)
local open = true
local channel_index = 4
local root, scale = 1, 2
local template, rhythm, pitch_mode = 1, 2, 1
local rows, cols, layers = 7, 7, 4
local ingress_row, ingress_col, egress_row, egress_col = 2, 2, 6, 6
local events, pulses, rotate = 64, 21, 0
local density, mutation, gesture_pos = 0.92, 0.18, 0.35
local octave, register_span, pitch_span = 3, 4, 28
local note_len, velocity, accent = 0.55, 82, 26
local burst_len, burst_gap = 3, 8
local resonance, damping, brightness = 0.72, 0.44, 0.56
local divider, feedback, spread = 0.30, 0.18, 0.60
local base_freq, gain_db = 110, -18.0
local vel_excitation, vel_brightness, gate, focus_width = 0.80, 0.35, 0.42, 0.26
local normalize, normalize_db, insert_gain = true, -12.0, 0.25
local seed = 11
local should_render = false

local function make_settings()
  local resolved_channels = CH_VALUES[channel_index] or 8
  return {
    start_pos = start_pos, duration = math.max(0.1, duration), channel_index = channel_index,
    channels = resolved_channels,
    root = root, scale = scale, template = template, rhythm = rhythm, pitch_mode = pitch_mode,
    rows = rows, cols = cols, layers = layers,
    ingress_row = math.min(ingress_row, rows), ingress_col = math.min(ingress_col, cols),
    egress_row = math.min(egress_row, rows), egress_col = math.min(egress_col, cols),
    events = events, pulses = pulses, rotate = rotate, density = density, mutation = mutation,
    gesture_pos = gesture_pos, octave = octave, register_span = register_span, pitch_span = pitch_span,
    note_len = note_len, velocity = velocity, accent = accent, burst_len = burst_len, burst_gap = burst_gap,
    resonance = resonance, damping = damping, brightness = brightness, divider = divider,
    feedback = feedback, spread = spread, base_freq = base_freq, gain_db = gain_db,
    vel_excitation = vel_excitation, vel_brightness = vel_brightness, gate = gate,
    focus_width = focus_width, normalize = normalize, normalize_db = normalize_db,
    insert_gain = insert_gain, seed = seed,
  }
end

local function draw_preview(settings)
  local events_preview = make_events(settings)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w, h = ImGui.GetContentRegionAvail(ctx), 285
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, COLORS.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, COLORS.edge)
  ImGui.DrawList_AddText(draw_list, x + 12, y + 10, COLORS.dim, "LATTICE RENDER SCORE")
  local cell = math.max(13, math.min(28, math.floor(math.min((w * 0.58) / settings.cols, (h - 58) / settings.rows))))
  local gx, gy = x + 22, y + 42
  local grid_w, grid_h = cell * settings.cols, cell * settings.rows
  for layer = settings.layers, 1, -1 do
    local off = (layer - 1) * 4
    ImGui.DrawList_AddRect(draw_list, gx + off, gy - off, gx + grid_w + off, gy + grid_h - off, COLORS.grid)
  end
  for row = 1, settings.rows do
    for col = 1, settings.cols do
      local v = table_value(row, col, 1, settings)
      local shade = 0.08 + v * 0.13
      local cx1, cy1 = gx + (col - 1) * cell, gy + (row - 1) * cell
      ImGui.DrawList_AddRectFilled(draw_list, cx1, cy1, cx1 + cell - 1, cy1 + cell - 1, color(shade, shade + 0.012, shade + 0.014, 1))
      ImGui.DrawList_AddRect(draw_list, cx1, cy1, cx1 + cell, cy1 + cell, COLORS.grid)
    end
  end
  local last_x, last_y
  for index, event in ipairs(events_preview) do
    if index > 48 then break end
    local px, py = gx + (event.col - 0.5) * cell, gy + (event.row - 0.5) * cell
    if last_x then ImGui.DrawList_AddLine(draw_list, last_x, last_y, px, py, COLORS.line, 1.1) end
    ImGui.DrawList_AddCircleFilled(draw_list, px, py, 2.8 + event.velocity / 127 * 2.8, COLORS.hit)
    last_x, last_y = px, py
  end
  local ix, iy = gx + (settings.ingress_col - 0.5) * cell, gy + (settings.ingress_row - 0.5) * cell
  local ox, oy = gx + (settings.egress_col - 0.5) * cell, gy + (settings.egress_row - 0.5) * cell
  ImGui.DrawList_AddCircle(draw_list, ix, iy, 9, COLORS.ingress, 16, 2)
  ImGui.DrawList_AddCircle(draw_list, ox, oy, 9, COLORS.egress, 16, 2)
  local sx = gx + grid_w + 42
  ImGui.DrawList_AddText(draw_list, sx, y + 44, COLORS.text, TEMPLATES[settings.template])
  ImGui.DrawList_AddText(draw_list, sx, y + 70, COLORS.dim, RHYTHMS[settings.rhythm])
  ImGui.DrawList_AddText(draw_list, sx, y + 104, COLORS.dim, tostring(#events_preview) .. " MIDI events")
  ImGui.DrawList_AddText(draw_list, sx, y + 128, COLORS.dim, "channels " .. tostring(CH_VALUES[settings.channel_index] or 8))
  ImGui.SetCursorScreenPos(ctx, x, y + h + 12)
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 860, 940, ImGui.Cond_Always)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local settings = make_settings()
    draw_preview(settings)
    ImGui.SetNextItemWidth(ctx, 130)
    _, start_pos = ImGui.InputDouble(ctx, "Start time", start_pos, 0.1, 1.0, "%.3f")
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 130)
    _, duration = ImGui.InputDouble(ctx, "Duration", duration, 1.0, 10.0, "%.3f")
    duration = math.max(0.1, duration)
    _, channel_index = combo("Output channels", CH_NAMES, channel_index, 130)
    ImGui.SameLine(ctx)
    _, template = combo("Gesture template", TEMPLATES, template, 190)
    ImGui.SameLine(ctx)
    _, rhythm = combo("Rhythm", RHYTHMS, rhythm, 180)
    _, root = combo("Root", ROOTS, root, 90)
    ImGui.SameLine(ctx)
    _, scale = combo("Scale", SCALES, scale, 170)
    ImGui.SameLine(ctx)
    _, pitch_mode = combo("Synth pitch mode", PITCH_MODES, pitch_mode, 190)
    ImGui.Separator(ctx)
    _, rows = ImGui.SliderInt(ctx, "Rows", rows, 3, 12)
    _, cols = ImGui.SliderInt(ctx, "Columns", cols, 3, 12)
    _, layers = ImGui.SliderInt(ctx, "Layers", layers, 1, 8)
    ingress_row, ingress_col = math.min(ingress_row, rows), math.min(ingress_col, cols)
    egress_row, egress_col = math.min(egress_row, rows), math.min(egress_col, cols)
    _, ingress_row = ImGui.SliderInt(ctx, "Ingress row", ingress_row, 1, rows)
    _, ingress_col = ImGui.SliderInt(ctx, "Ingress column", ingress_col, 1, cols)
    _, egress_row = ImGui.SliderInt(ctx, "Egress row", egress_row, 1, rows)
    _, egress_col = ImGui.SliderInt(ctx, "Egress column", egress_col, 1, cols)
    ImGui.Separator(ctx)
    _, events = ImGui.SliderInt(ctx, "Events", events, 4, 512)
    pulses = math.min(pulses, events)
    _, pulses = ImGui.SliderInt(ctx, "Euclidean pulses", pulses, 0, events)
    _, rotate = ImGui.SliderInt(ctx, "Euclidean rotate", rotate, -events, events)
    _, density = ImGui.SliderDouble(ctx, "Density", density, 0, 1, "%.3f")
    _, mutation = ImGui.SliderDouble(ctx, "Gesture mutation", mutation, 0, 1, "%.3f")
    _, gesture_pos = ImGui.SliderDouble(ctx, "Synth gesture position", gesture_pos, 0, 1, "%.3f")
    _, note_len = ImGui.SliderDouble(ctx, "Note length", note_len, 0.05, 1.5, "%.2f")
    _, velocity = ImGui.SliderInt(ctx, "Velocity", velocity, 1, 127)
    _, octave = ImGui.SliderInt(ctx, "Base octave", octave, 0, 8)
    _, register_span = ImGui.SliderInt(ctx, "Register span", register_span, 1, 6)
    _, pitch_span = ImGui.SliderInt(ctx, "Pitch span degrees", pitch_span, 4, 64)
    ImGui.Separator(ctx)
    _, resonance = ImGui.SliderDouble(ctx, "Resonance", resonance, 0, 1, "%.3f")
    _, damping = ImGui.SliderDouble(ctx, "Damping", damping, 0, 1, "%.3f")
    _, brightness = ImGui.SliderDouble(ctx, "Brightness", brightness, 0, 1, "%.3f")
    _, divider = ImGui.SliderDouble(ctx, "Divider shadow", divider, 0, 1, "%.3f")
    _, feedback = ImGui.SliderDouble(ctx, "Feedback drive", feedback, 0, 1, "%.3f")
    _, spread = ImGui.SliderDouble(ctx, "Channel spread", spread, 0, 1, "%.3f")
    _, base_freq = ImGui.SliderDouble(ctx, "Base frequency", base_freq, 20, 4000, "%.1f Hz")
    _, gain_db = ImGui.SliderDouble(ctx, "Output gain", gain_db, -60, 0, "%.1f dB")
    _, vel_excitation = ImGui.SliderDouble(ctx, "Velocity to excitation", vel_excitation, 0, 1, "%.3f")
    _, vel_brightness = ImGui.SliderDouble(ctx, "Velocity to brightness", vel_brightness, 0, 1, "%.3f")
    _, gate = ImGui.SliderDouble(ctx, "Note gate depth", gate, 0, 1, "%.3f")
    _, focus_width = ImGui.SliderDouble(ctx, "Focus width", focus_width, 0.02, 1, "%.3f")
    ImGui.Separator(ctx)
    _, normalize = ImGui.Checkbox(ctx, "Peak normalize", normalize)
    if normalize then _, normalize_db = ImGui.SliderDouble(ctx, "Normalize peak dB", normalize_db, -36, -3, "%.1f") end
    _, insert_gain = ImGui.SliderDouble(ctx, "Inserted item gain", insert_gain, 0.05, 1, "%.2f")
    _, seed = ImGui.InputInt(ctx, "Seed", seed)
    if ImGui.Button(ctx, "New Seed", 100, 28) then seed = seed + 1 end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Render", 100, 28) then should_render = true end
  end
  ImGui.End(ctx)
  if should_render then
    should_render = false
    render_lattice(make_settings())
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
