-- @description Render MC Spectra Synth
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; JSFX: s3g MC Spectra Synth Engine
-- @category Procedural Synthesis
-- @render Yes; creates a temporary synth track and renders it to a multichannel media item.
-- @method Offline controller for the multichannel Spectra synth engine. CDP synthesis-inspired algorithms generate partial clouds, comb strata, formant bands, impulse resonators, and noise spectra with algorithm-specific channel-motion models. Choose duration, algorithm, and map-route breakpoint curves; the action writes automation to a temporary generator track, renders the selected range as a multichannel stem, then removes the temporary track.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Render MC Spectra Synth", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local FX_NAME = "s3g MC Spectra Synth Engine"
local FX_NAME_CLEAN = "MC Spectra Synth Engine"
local SYNTH_GMEM_NAME = "s3g_spectra_synth"
local EXTSTATE_SECTION = "s3g_mc_render_spectra_synth"
local MAX_ROUTE_POINTS = 32

local ALGO_NAMES = {
  [1] = "Partial cloud",
  [2] = "Comb strata",
  [3] = "Formant bands",
  [4] = "Impulse resonator",
  [5] = "Noise spectra",
}
local FORM_NAMES = { [1] = "Static", [2] = "Crescendo", [3] = "Dissolve", [4] = "Chaos bloom", [5] = "Pulse field", [6] = "Slow drift" }
local CH_NAMES, CH_VALUES = {}, {}
for ch = 2, 64, 2 do
  CH_VALUES[#CH_VALUES + 1] = ch
  CH_NAMES[#CH_NAMES + 1] = tostring(ch)
end
CH_VALUES[#CH_VALUES + 1] = 128
CH_NAMES[#CH_NAMES + 1] = "128"

local PARAM = {
  channels = 0,
  algorithm = 1,
  rate = 2,
  base_freq = 3,
  density = 4,
  brightness = 5,
  decay = 6,
  spread = 7,
  correlation = 8,
  drift = 9,
  crush = 10,
  output_gain = 11,
  seed = 12,
  clear_extra = 13,
}

local ROUTE_DEFS = {
  { key = "rate", label = "Rate", param = PARAM.rate, min = 0, max = 1, fmt = "%.3f" },
  { key = "density", label = "Density", param = PARAM.density, min = 0, max = 1, fmt = "%.3f" },
  { key = "brightness", label = "Brightness", param = PARAM.brightness, min = 0, max = 1, fmt = "%.3f" },
  { key = "decay", label = "Decay", param = PARAM.decay, min = 0, max = 1, fmt = "%.3f" },
  { key = "spread", label = "Spread", param = PARAM.spread, min = 0, max = 1, fmt = "%.3f" },
  { key = "correlation", label = "Correlation", param = PARAM.correlation, min = 0, max = 1, fmt = "%.3f" },
  { key = "drift", label = "Drift", param = PARAM.drift, min = 0, max = 1, fmt = "%.3f" },
  { key = "crush", label = "Crush", param = PARAM.crush, min = 0, max = 1, fmt = "%.3f" },
  { key = "gain_db", label = "Amplitude", param = PARAM.output_gain, min = -60, max = 0, fmt = "%.1f dB" },
}

local ROUTE_NAMES = {}
for index, def in ipairs(ROUTE_DEFS) do ROUTE_NAMES[index] = def.label end

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local COLORS = {
  bg = color(0.035, 0.040, 0.043, 1),
  panel = color(0.060, 0.066, 0.070, 1),
  panel_soft = color(0.075, 0.078, 0.074, 1),
  grid = color(0.50, 0.56, 0.56, 0.18),
  grid_soft = color(0.50, 0.56, 0.56, 0.09),
  text = color(0.84, 0.88, 0.86, 1),
  muted = color(0.56, 0.62, 0.60, 1),
  route = color(0.90, 0.72, 0.32, 1),
  route_fill = color(0.90, 0.72, 0.32, 0.16),
  route_alt = color(0.28, 0.78, 0.70, 1),
  point = color(0.94, 0.88, 0.64, 1),
  point_selected = color(1.00, 0.96, 0.42, 1),
  contour = color(0.26, 0.62, 0.58, 0.22),
  contour_hot = color(0.92, 0.60, 0.28, 0.55),
  edge = color(0.55, 0.60, 0.58, 0.34),
}

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function route_value(def, y)
  return lerp(def.min, def.max, clamp(y or 0, 0, 1))
end

local function route_norm(def, value)
  if def.max == def.min then return 0 end
  return clamp(((value or def.min) - def.min) / (def.max - def.min), 0, 1)
end

local function sort_route_points(points)
  table.sort(points, function(a, b) return a.x < b.x end)
  points[1].x = 0
  points[#points].x = 1
  for index, point in ipairs(points) do
    point.y = clamp(point.y, 0, 1)
    if index > 1 and index < #points then
      point.x = clamp(point.x, points[index - 1].x + 0.01, points[index + 1].x - 0.01)
    end
  end
end

local function route_at(points, x)
  if not points or #points == 0 then return 0 end
  x = clamp(x, 0, 1)
  for index = 1, #points - 1 do
    local a = points[index]
    local b = points[index + 1]
    if x >= a.x and x <= b.x then
      local t = (x - a.x) / math.max(0.0001, b.x - a.x)
      return lerp(a.y, b.y, t)
    end
  end
  return points[#points].y
end

local function copy_route_points(points)
  local copy = {}
  for index, point in ipairs(points or {}) do
    copy[index] = { x = point.x, y = point.y }
  end
  return copy
end

local function copy_routes(route_points, route_enabled)
  local routes = {}
  for index, points in ipairs(route_points or {}) do
    if route_enabled[index] then
      routes[index] = copy_route_points(points)
    end
  end
  return routes
end

local function set_route(points, values)
  for index = #points, 1, -1 do points[index] = nil end
  for index, point in ipairs(values) do
    points[index] = { x = point[1], y = point[2] }
  end
  sort_route_points(points)
end

local function get_time_defaults()
  local start_pos, end_pos = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if end_pos > start_pos then return start_pos, end_pos - start_pos, true end
  return reaper.GetCursorPosition(), 20.0, false
end

local function find_fx(track)
  for fx = 0, reaper.TrackFX_GetCount(track) - 1 do
    local ok, name = reaper.TrackFX_GetFXName(track, fx, "")
    if ok and (name:find(FX_NAME, 1, true) or name:find(FX_NAME_CLEAN, 1, true)) then
      return fx
    end
  end
  return -1
end

local function add_named_jsfx(track, name)
  local fx = reaper.TrackFX_AddByName(track, "JS: " .. name, false, -1)
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, name, false, -1) end
  return fx
end

local function add_synth_fx(track)
  local fx = find_fx(track)
  if fx < 0 then fx = add_named_jsfx(track, FX_NAME) end
  if fx < 0 then fx = add_named_jsfx(track, FX_NAME_CLEAN) end
  return fx
end

local function set_param(track, fx, param, value)
  reaper.TrackFX_SetParam(track, fx, param, value)
end

local function param_norm(track, fx, param, value)
  local _, min_value, max_value = reaper.TrackFX_GetParam(track, fx, param)
  if not min_value or not max_value or max_value == min_value then return value end
  return clamp((value - min_value) / (max_value - min_value), 0, 1)
end

local function db_to_amp(db)
  return 10 ^ ((db or 0) / 20)
end

local function amp_to_db(amp)
  if not amp or amp <= 0 then return -150 end
  return 20 * math.log(amp, 10)
end

local function item_peak(item)
  if not item or not reaper.ValidatePtr2(0, item, "MediaItem*") then return 0 end
  if not reaper.CreateTakeAudioAccessor or not reaper.GetAudioAccessorSamples or not reaper.new_array then
    return 0, "REAPER audio accessor API is unavailable."
  end

  local take = reaper.GetActiveTake(item)
  if not take or reaper.TakeIsMIDI(take) then return 0 end

  local channels = mc.get_take_source_channels(take) or 1
  channels = math.max(1, math.min(128, channels))

  local project_rate = reaper.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
  local sample_rate = (project_rate and project_rate > 0) and project_rate or 48000
  local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH") or 0
  if item_length <= 0 then return 0 end

  local accessor = reaper.CreateTakeAudioAccessor(take)
  if not accessor then return 0 end
  local accessor_start = reaper.GetAudioAccessorStartTime and reaper.GetAudioAccessorStartTime(accessor) or
    (reaper.GetMediaItemInfo_Value(item, "D_POSITION") or 0)

  local peak = 0
  local chunk_frames = 8192
  local buffer = reaper.new_array(chunk_frames * channels)
  local offset = 0

  while offset < item_length do
    local frames = math.floor(math.min(chunk_frames, (item_length - offset) * sample_rate))
    if frames <= 0 then break end
    buffer.clear()
    reaper.GetAudioAccessorSamples(accessor, sample_rate, channels, accessor_start + offset, frames, buffer)
    local values = buffer.table()
    local sample_count = frames * channels
    for index = 1, sample_count do
      local sample = values[index]
      if sample then
        local abs_sample = math.abs(sample)
        if abs_sample > peak then peak = abs_sample end
      end
    end
    offset = offset + frames / sample_rate
  end

  reaper.DestroyAudioAccessor(accessor)
  return peak
end

local function normalize_rendered_track(track, target_db)
  if not track or not reaper.ValidatePtr2(0, track, "MediaTrack*") then return nil end

  local peak = 0
  local item_count = reaper.CountTrackMediaItems(track)
  for item_index = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    local item_peak_value, err = item_peak(item)
    if err then return nil, err end
    peak = math.max(peak, item_peak_value or 0)
  end

  if peak <= 0 then return nil, "Rendered item peak is silent; normalize skipped." end

  local target = db_to_amp(target_db)
  local gain = target / peak
  gain = math.min(gain, db_to_amp(60))

  for item_index = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    local current_vol = reaper.GetMediaItemInfo_Value(item, "D_VOL") or 1
    reaper.SetMediaItemInfo_Value(item, "D_VOL", current_vol * gain)
  end

  return {
    peak = peak,
    gain = gain,
    target_db = target_db,
  }
end

local function set_envelope_points(track, fx, param, start_pos, duration, points)
  local env = reaper.GetFXEnvelope(track, fx, param, true)
  if not env then return end
  reaper.DeleteEnvelopePointRange(env, start_pos - 0.001, start_pos + duration + 0.001)
  for _, point in ipairs(points) do
    local pos = start_pos + clamp(point.t or 0, 0, 1) * duration
    local value = param_norm(track, fx, param, point.v or 0)
    reaper.InsertEnvelopePoint(env, pos, value, 0, 0, false, true)
  end
  reaper.Envelope_SortPoints(env)
end

local function linear_points(a, b)
  return { { t = 0, v = a }, { t = 1, v = b } }
end

local function pulse_points(low, high, pulses)
  local points = {}
  pulses = math.max(1, math.floor(pulses or 6))
  for i = 0, pulses * 2 do
    points[#points + 1] = { t = i / (pulses * 2), v = (i % 2 == 0) and low or high }
  end
  return points
end

local function write_form(track, fx, start_pos, duration, form, settings)
  local density = settings.density
  local rate = settings.rate
  local spread = settings.spread
  local correlation = settings.correlation
  local drift = settings.drift
  local brightness = settings.brightness
  local decay = settings.decay

  if form == 2 then
    set_envelope_points(track, fx, PARAM.density, start_pos, duration, linear_points(math.max(0.02, density * 0.18), density))
    set_envelope_points(track, fx, PARAM.spread, start_pos, duration, linear_points(math.max(0.05, spread * 0.35), spread))
    set_envelope_points(track, fx, PARAM.correlation, start_pos, duration, linear_points(math.min(1, correlation + 0.25), correlation))
  elseif form == 3 then
    set_envelope_points(track, fx, PARAM.density, start_pos, duration, linear_points(density, 0.03))
    set_envelope_points(track, fx, PARAM.brightness, start_pos, duration, linear_points(brightness, math.max(0, brightness * 0.35)))
    set_envelope_points(track, fx, PARAM.decay, start_pos, duration, linear_points(decay, math.min(1, decay + 0.35)))
  elseif form == 4 then
    set_envelope_points(track, fx, PARAM.rate, start_pos, duration, { { t = 0, v = math.max(0.02, rate * 0.35) }, { t = 0.65, v = rate }, { t = 1, v = math.min(1, rate + 0.22) } })
    set_envelope_points(track, fx, PARAM.density, start_pos, duration, { { t = 0, v = math.max(0.04, density * 0.25) }, { t = 0.72, v = density }, { t = 1, v = math.min(1, density + 0.28) } })
    set_envelope_points(track, fx, PARAM.spread, start_pos, duration, linear_points(math.max(0.1, spread * 0.4), math.min(1, spread + 0.25)))
    set_envelope_points(track, fx, PARAM.correlation, start_pos, duration, linear_points(math.min(1, correlation + 0.25), math.max(0, correlation - 0.45)))
    set_envelope_points(track, fx, PARAM.drift, start_pos, duration, linear_points(drift, math.min(1, drift + 0.35)))
  elseif form == 5 then
    set_envelope_points(track, fx, PARAM.density, start_pos, duration, pulse_points(math.max(0, density * 0.18), density, 7))
    set_envelope_points(track, fx, PARAM.rate, start_pos, duration, pulse_points(math.max(0.01, rate * 0.5), math.min(1, rate * 1.2), 7))
    set_envelope_points(track, fx, PARAM.spread, start_pos, duration, pulse_points(math.max(0.05, spread * 0.5), spread, 4))
  elseif form == 6 then
    set_envelope_points(track, fx, PARAM.drift, start_pos, duration, linear_points(math.max(0.02, drift), math.min(1, drift + 0.45)))
    set_envelope_points(track, fx, PARAM.spread, start_pos, duration, { { t = 0, v = spread * 0.65 }, { t = 0.5, v = math.min(1, spread + 0.18) }, { t = 1, v = spread } })
    set_envelope_points(track, fx, PARAM.correlation, start_pos, duration, { { t = 0, v = correlation }, { t = 0.5, v = math.max(0, correlation - 0.25) }, { t = 1, v = math.min(1, correlation + 0.1) } })
  end
end

local function write_routes(track, fx, start_pos, duration, routes)
  for route_index, points in pairs(routes or {}) do
    local def = ROUTE_DEFS[route_index]
    if def and def.key ~= "gain_db" and points and #points >= 2 then
      local env_points = {}
      sort_route_points(points)
      for _, point in ipairs(points) do
        env_points[#env_points + 1] = {
          t = point.x,
          v = route_value(def, point.y),
        }
      end
      set_envelope_points(track, fx, def.param, start_pos, duration, env_points)
    end
  end
end

local function write_amplitude_curve_to_gmem(routes, duration)
  if not reaper.gmem_attach or not reaper.gmem_write then return nil, "REAPER gmem API is unavailable." end

  reaper.gmem_attach(SYNTH_GMEM_NAME)

  local amplitude_points = nil
  local def = nil
  for route_index, route_def in ipairs(ROUTE_DEFS) do
    if route_def.key == "gain_db" then
      def = route_def
      amplitude_points = routes and routes[route_index] or nil
      break
    end
  end

  local generation = math.floor((reaper.time_precise and reaper.time_precise() or os.clock()) * 1000000)
  reaper.gmem_write(1, generation)
  reaper.gmem_write(2, duration or 1)

  if not def or not amplitude_points or #amplitude_points < 2 then
    reaper.gmem_write(0, 0)
    reaper.gmem_write(3, 0)
    return nil
  end

  sort_route_points(amplitude_points)
  local count = math.min(MAX_ROUTE_POINTS, #amplitude_points)
  reaper.gmem_write(0, 1)
  reaper.gmem_write(3, count)
  for index = 1, count do
    local point = amplitude_points[index]
    reaper.gmem_write(4 + (index - 1) * 2, clamp(point.x or 0, 0, 1))
    reaper.gmem_write(5 + (index - 1) * 2, db_to_amp(route_value(def, point.y)))
  end

  return true
end

local function clear_amplitude_curve_gmem()
  if not reaper.gmem_attach or not reaper.gmem_write then return end
  reaper.gmem_attach(SYNTH_GMEM_NAME)
  reaper.gmem_write(0, 0)
  reaper.gmem_write(3, 0)
end

local function active_route_names(routes)
  local names = {}
  for route_index, points in pairs(routes or {}) do
    local def = ROUTE_DEFS[route_index]
    if def and points and #points >= 2 then names[#names + 1] = def.label end
  end
  table.sort(names)
  if #names == 0 then return "none" end
  return table.concat(names, ", ")
end

local function render_texture(settings)
  local start_pos = settings.start_pos
  local duration = settings.duration
  local channels = settings.channels
  local render_track = nil
  local did_render = false
  local render_error = nil
  local normalize_result = nil
  local normalize_warning = nil
  local amplitude_warning = nil

  reaper.Undo_BeginBlock()
  mc.with_ui_refresh_block(function()
    local insert_index = reaper.CountTracks(0)
    local synth_track = mc.insert_track_at(insert_index, "tmp MC Spectra Synth", mc.reaper_track_channel_count(channels))
    reaper.SetMediaTrackInfo_Value(synth_track, "B_MAINSEND", 0)
    local placeholder = reaper.AddMediaItemToTrack(synth_track)
    reaper.SetMediaItemInfo_Value(placeholder, "D_POSITION", start_pos)
    reaper.SetMediaItemInfo_Value(placeholder, "D_LENGTH", duration)

    local fx = add_synth_fx(synth_track)
    if fx < 0 then
      render_error = "Could not load JS: " .. FX_NAME
      reaper.DeleteTrack(synth_track)
      return
    end

    set_param(synth_track, fx, PARAM.channels, channels)
    set_param(synth_track, fx, PARAM.algorithm, settings.algorithm - 1)
    set_param(synth_track, fx, PARAM.rate, settings.rate)
    set_param(synth_track, fx, PARAM.base_freq, settings.base_freq)
    set_param(synth_track, fx, PARAM.density, settings.density)
    set_param(synth_track, fx, PARAM.brightness, settings.brightness)
    set_param(synth_track, fx, PARAM.decay, settings.decay)
    set_param(synth_track, fx, PARAM.spread, settings.spread)
    set_param(synth_track, fx, PARAM.correlation, settings.correlation)
    set_param(synth_track, fx, PARAM.drift, settings.drift)
    set_param(synth_track, fx, PARAM.crush, settings.crush)
    set_param(synth_track, fx, PARAM.output_gain, settings.gain_db)
    set_param(synth_track, fx, PARAM.seed, settings.seed)
    set_param(synth_track, fx, PARAM.clear_extra, 1)
    write_form(synth_track, fx, start_pos, duration, settings.form, settings)
    write_routes(synth_track, fx, start_pos, duration, settings.routes)
    local _, amplitude_err = write_amplitude_curve_to_gmem(settings.routes, duration)
    if amplitude_err then amplitude_warning = amplitude_err end

    mc.select_only_track(synth_track)
    mc.with_render_bounds_for_range(start_pos, start_pos + duration, function()
      local before_guids = mc.snapshot_track_guids()
      local before_count = reaper.CountTracks(0)
      reaper.Main_OnCommand(mc.render_multichannel_post_fader_stem_command(), 0)
      did_render = reaper.CountTracks(0) > before_count
      if did_render then
        render_track = mc.find_new_track(before_guids) or mc.get_selected_track_excluding({ synth_track })
        if render_track then
          reaper.GetSetMediaTrackInfo_String(render_track, "P_NAME",
            "MC Spectra Synth render (" .. tostring(channels) .. "ch)", true)
          reaper.SetMediaTrackInfo_Value(render_track, "I_NCHAN", mc.reaper_track_channel_count(channels))
          reaper.SetMediaTrackInfo_Value(render_track, "B_MAINSEND", 1)
          reaper.SetMediaTrackInfo_Value(render_track, "D_VOL", settings.insert_gain or 0.25)
          mc.set_track_items_length(render_track, duration)
          local rendered_start = mc.track_items_bounds({ render_track })
          mc.move_track_items_by(render_track, start_pos - rendered_start)
          if settings.normalize then
            normalize_result, normalize_warning = normalize_rendered_track(render_track, settings.normalize_db or -6.0)
          end
        end
      end
    end)

    if did_render and reaper.ValidatePtr2(0, synth_track, "MediaTrack*") then
      reaper.DeleteTrack(synth_track)
    end
    clear_amplitude_curve_gmem()
    if render_track and reaper.ValidatePtr2(0, render_track, "MediaTrack*") then
      mc.select_only_track(render_track)
    end
  end)
  reaper.Undo_EndBlock("Render MC Spectra Synth", -1)

  if render_error then
    reaper.MB(render_error .. "\n\nMake sure the s3g JSFX files are installed in REAPER/Effects/s3g.", "Render MC Spectra Synth", 0)
  elseif not did_render then
    reaper.MB("REAPER did not create a rendered multichannel Spectra synth item.\n\nThe temporary synth track was left in place if possible. Check the render action:\n" .. mc.RENDER_MULTICHANNEL_POST_FADER_STEM_NAME, "Render MC Spectra Synth", 0)
  else
    local lines = {
      "Algorithm: " .. (ALGO_NAMES[settings.algorithm] or "?"),
      "Form: " .. (FORM_NAMES[settings.form] or "?"),
      "Duration: " .. string.format("%.3f sec", duration),
      "Output channels: " .. tostring(channels),
      "Print gain: " .. string.format("%.1f dB", settings.gain_db),
      "Inserted track gain: " .. string.format("%.1f dB", amp_to_db(settings.insert_gain or 0.25)),
      "Active routes: " .. active_route_names(settings.routes),
      "Seed: " .. tostring(settings.seed),
      "Render bounds: " .. string.format("%.3f to %.3f sec", start_pos, start_pos + duration),
    }
    if normalize_result then
      lines[#lines + 1] = "Peak normalize: " .. string.format("%.1f dB", normalize_result.target_db)
      lines[#lines + 1] = "Measured peak before item gain: " .. string.format("%.2f dBFS", amp_to_db(normalize_result.peak))
      lines[#lines + 1] = "Applied item gain: " .. string.format("%+.2f dB", amp_to_db(normalize_result.gain))
    elseif normalize_warning then
      lines[#lines + 1] = "Peak normalize: skipped (" .. normalize_warning .. ")"
    end
    if amplitude_warning then
      lines[#lines + 1] = "Amplitude curve: skipped (" .. amplitude_warning .. ")"
    elseif settings.routes then
      lines[#lines + 1] = "Amplitude curve: baked into synth render when active"
    end
    reaper.ShowConsoleMsg("\n[Render MC Spectra Synth]\n" .. table.concat(lines, "\n") .. "\n")
  end
end

local function combo(ctx, label, names, value)
  local changed = false
  if ImGui.BeginCombo(ctx, label, names[value] or names[1] or "") then
    for index, name in ipairs(names) do
      local selected = index == value
      if ImGui.Selectable(ctx, name, selected) then
        value = index
        changed = true
      end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return changed, value
end

local function current_value_for_key(values, key)
  return values[key] or 0
end

local function set_flat_route(points, def, value)
  local y = route_norm(def, value)
  set_route(points, { { 0, y }, { 1, y } })
end

local function set_route_shape(points, mode, base)
  base = clamp(base or 0.5, 0, 1)
  if mode == "rise" then
    set_route(points, { { 0, math.max(0, base * 0.22) }, { 0.65, base }, { 1, math.min(1, base + 0.18) } })
  elseif mode == "fall" then
    set_route(points, { { 0, math.min(1, base + 0.20) }, { 0.55, base }, { 1, math.max(0, base * 0.20) } })
  elseif mode == "ridge" then
    set_route(points, { { 0, math.max(0, base * 0.25) }, { 0.5, math.min(1, base + 0.35) }, { 1, math.max(0, base * 0.25) } })
  elseif mode == "valley" then
    set_route(points, { { 0, math.min(1, base + 0.20) }, { 0.5, math.max(0, base * 0.18) }, { 1, math.min(1, base + 0.20) } })
  elseif mode == "terrace" then
    set_route(points, { { 0, base }, { 0.24, base }, { 0.25, math.min(1, base + 0.22) }, { 0.58, math.min(1, base + 0.22) }, { 0.59, math.max(0, base - 0.18) }, { 1, math.max(0, base - 0.18) } })
  elseif mode == "switchback" then
    set_route(points, { { 0, base }, { 0.20, math.max(0, base - 0.30) }, { 0.42, math.min(1, base + 0.30) }, { 0.66, math.max(0, base - 0.20) }, { 0.84, math.min(1, base + 0.22) }, { 1, base } })
  else
    set_route(points, { { 0, base }, { 1, base } })
  end
end

local function randomize_route(points, base, amount, count, smooth, dispersion)
  count = math.max(2, math.min(MAX_ROUTE_POINTS, math.floor(count or 10)))
  amount = clamp(amount or 0.6, 0, 1)
  smooth = clamp(smooth or 0.35, 0, 1)
  dispersion = clamp(dispersion or 0, 0, 1)
  base = clamp(base or 0.5, 0, 1)

  for index = #points, 1, -1 do points[index] = nil end
  local random_x = {}
  random_x[1] = 0
  random_x[count] = 1
  for index = 2, count - 1 do
    random_x[index] = math.random()
  end
  table.sort(random_x)

  local value = clamp(base + (math.random() * 2 - 1) * amount * 0.5, 0, 1)
  for index = 1, count do
    local uniform_x = (index - 1) / (count - 1)
    local x = lerp(uniform_x, random_x[index] or uniform_x, dispersion)
    local jump = (math.random() * 2 - 1) * amount
    local target = clamp(base + jump, 0, 1)
    value = lerp(target, value, smooth)
    points[index] = {
      x = clamp(x, 0, 1),
      y = value,
    }
  end
  sort_route_points(points)
end

local function randomize_route_set(route_points, route_enabled, values, selected_route, scope, amount, count, smooth, dispersion)
  for index, def in ipairs(ROUTE_DEFS) do
    local include = scope == "all" or index == selected_route
    if include then
      local base = route_norm(def, current_value_for_key(values, def.key))
      if def.key == "gain_db" then base = clamp(base + 0.20, 0, 1) end
      randomize_route(route_points[index], base, amount, count, smooth, dispersion)
      route_enabled[index] = true
    end
  end
end

local function apply_route_preset(route_points, route_enabled, form, values)
  for index, def in ipairs(ROUTE_DEFS) do
    route_enabled[index] = false
    set_flat_route(route_points[index], def, current_value_for_key(values, def.key))
  end

  local function shape(key, mode, base_override)
    for index, def in ipairs(ROUTE_DEFS) do
      if def.key == key then
        route_enabled[index] = true
        local base = base_override or route_norm(def, current_value_for_key(values, key))
        set_route_shape(route_points[index], mode, base)
        return
      end
    end
  end

  if form == 2 then
    shape("density", "rise")
    shape("spread", "rise")
    shape("correlation", "fall")
  elseif form == 3 then
    shape("density", "fall")
    shape("brightness", "fall")
    shape("decay", "rise")
  elseif form == 4 then
    shape("rate", "rise")
    shape("density", "rise")
    shape("spread", "rise")
    shape("correlation", "fall")
    shape("drift", "rise")
  elseif form == 5 then
    shape("density", "switchback")
    shape("rate", "switchback")
    shape("spread", "terrace")
  elseif form == 6 then
    shape("drift", "rise")
    shape("spread", "ridge")
    shape("correlation", "valley")
  else
    shape("density", "ridge")
  end
end

local function draw_spectra_map(ctx, route_points, route_enabled, selected_route, selected_point, channels, values, algorithm)
  local width = ImGui.GetContentRegionAvail(ctx)
  local height = 178
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local x1, y1 = x0 + width, y0 + height
  ImGui.InvisibleButton(ctx, "##spectra_map", width, height)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local mx, my = ImGui.GetMousePos(ctx)

  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, COLORS.bg)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, COLORS.edge)

  local pad = 14
  local px0, py0 = x0 + pad, y0 + 28
  local px1, py1 = x1 - pad, y1 - 58
  local route_x0, route_y0 = x0 + pad, y1 - 42
  local route_x1, route_y1 = x1 - pad, y1 - 12
  local selected_def = ROUTE_DEFS[selected_route]
  local selected_points = route_points[selected_route]

  for grid = 0, 8 do
    local gx = px0 + (px1 - px0) * grid / 8
    ImGui.DrawList_AddLine(draw_list, gx, py0, gx, py1, COLORS.grid_soft, 1)
  end
  for grid = 0, 4 do
    local gy = py0 + (py1 - py0) * grid / 4
    ImGui.DrawList_AddLine(draw_list, px0, gy, px1, gy, COLORS.grid_soft, 1)
  end

  local base_norm = clamp((math.log(math.max(20, values.base_freq or 120)) - math.log(20)) /
    math.max(0.0001, math.log(4000) - math.log(20)), 0, 1)
  local base_density = route_enabled[2] and 0.55 or route_norm(ROUTE_DEFS[2], values.density)
  local contour_count = math.max(4, math.min(13, math.floor(4 + base_density * 9)))
  local algo_phase = ((algorithm or 1) - 1) * 0.17

  for contour = 1, contour_count do
    local last_x, last_y = nil, nil
    for step = 0, 128 do
      local u = step / 128
      local density_y = route_enabled[2] and route_at(route_points[2], u) or route_norm(ROUTE_DEFS[2], values.density)
      local rate_y = route_enabled[1] and route_at(route_points[1], u) or route_norm(ROUTE_DEFS[1], values.rate)
      local bright_y = route_enabled[3] and route_at(route_points[3], u) or route_norm(ROUTE_DEFS[3], values.brightness)
      local decay_y = route_enabled[4] and route_at(route_points[4], u) or route_norm(ROUTE_DEFS[4], values.decay)
      local drift_y = route_enabled[7] and route_at(route_points[7], u) or route_norm(ROUTE_DEFS[7], values.drift)
      local crush_y = route_enabled[8] and route_at(route_points[8], u) or route_norm(ROUTE_DEFS[8], values.crush)
      local freq = 1.2 + rate_y * 5.5 + base_norm * 2.4
      local step_u = crush_y > 0.02 and math.floor(u * lerp(16, 5, crush_y)) / lerp(16, 5, crush_y) or u
      local wave_a = math.sin((step_u * freq + contour * (0.13 + algo_phase) + drift_y * 0.9) * math.pi * 2)
      local wave_b = math.cos((step_u * (freq * 0.37 + 0.4) + contour * 0.31 + base_norm) * math.pi * 2)
      local amp = 0.012 + drift_y * 0.070 + crush_y * 0.035
      local ridge = (contour - 0.35) / (contour_count + 0.55)
      local y_norm = clamp(ridge + wave_a * amp + wave_b * amp * 0.35 + (density_y - 0.5) * 0.10 +
        (decay_y - 0.5) * 0.045, 0, 1)
      local y = lerp(py1, py0, y_norm)
      local x = lerp(px0, px1, u)
      if last_x then
        local alpha = 0.10 + bright_y * 0.26 + density_y * 0.12
        local thickness = 0.8 + bright_y * 0.9 + crush_y * 0.7
        local contour_color = color(0.18 + bright_y * 0.32, 0.45 + bright_y * 0.22, 0.45 + base_norm * 0.18, alpha)
        ImGui.DrawList_AddLine(draw_list, last_x, last_y, x, y, contour_color, thickness)
      end
      last_x, last_y = x, y
    end
  end

  local shown_channels = math.min(channels or 8, 32)
  for ch = 1, shown_channels do
    local u = shown_channels == 1 and 0.5 or (ch - 1) / (shown_channels - 1)
    local preview_t = ((ch - 1) % 8) / 7
    local spread_y = route_enabled[5] and route_at(route_points[5], preview_t) or route_norm(ROUTE_DEFS[5], values.spread)
    local corr_y = route_enabled[6] and route_at(route_points[6], preview_t) or route_norm(ROUTE_DEFS[6], values.correlation)
    local density_y = route_enabled[2] and route_at(route_points[2], preview_t) or route_norm(ROUTE_DEFS[2], values.density)
    local bright_y = route_enabled[3] and route_at(route_points[3], preview_t) or route_norm(ROUTE_DEFS[3], values.brightness)
    local x = lerp(px0, px1, u)
    local y = lerp(py1, py0, clamp(0.10 + spread_y * 0.74 + math.sin((u * lerp(1.0, 5.0, 1 - corr_y) + corr_y) * math.pi * 2) * 0.055, 0, 1))
    local r = 2.8 + density_y * 4.8 + (1 - corr_y) * 2.2
    ImGui.DrawList_AddCircleFilled(draw_list, x, y, r + 4, color(0.20, 0.55, 0.50, 0.09 + density_y * 0.16), 16)
    ImGui.DrawList_AddCircleFilled(draw_list, x, y, r, color(0.20 + 0.58 * u, 0.52 + bright_y * 0.28, 0.52 + base_norm * 0.24, 0.72 + bright_y * 0.25), 16)
  end

  ImGui.DrawList_AddRectFilled(draw_list, route_x0, route_y0, route_x1, route_y1, color(0.045, 0.050, 0.052, 0.96))
  ImGui.DrawList_AddRect(draw_list, route_x0, route_y0, route_x1, route_y1, COLORS.edge)
  for grid = 1, 7 do
    local gx = route_x0 + (route_x1 - route_x0) * grid / 8
    ImGui.DrawList_AddLine(draw_list, gx, route_y0, gx, route_y1, COLORS.grid_soft, 1)
  end
  ImGui.DrawList_AddText(draw_list, route_x0 + 7, route_y0 + 6, COLORS.muted,
    selected_def and (selected_def.label .. " over time") or "route over time")

  if selected_def and selected_points then
    local last_x, last_y = nil, nil
    for step = 0, 96 do
      local u = step / 96
      local y_norm = route_enabled[selected_route] and route_at(selected_points, u) or
        route_norm(selected_def, current_value_for_key(values, selected_def.key))
      local x = lerp(route_x0, route_x1, u)
      local y = lerp(route_y1, route_y0, y_norm)
      if last_x then ImGui.DrawList_AddLine(draw_list, last_x, last_y, x, y, COLORS.contour_hot, 2.2) end
      last_x, last_y = x, y
    end
  end

  if selected_def and selected_points then
    local nearest, nearest_dist = nil, 999999
    for index, point in ipairs(selected_points) do
      local px = lerp(route_x0, route_x1, point.x)
      local py = lerp(route_y1, route_y0, point.y)
      local dist = ((mx - px) ^ 2 + (my - py) ^ 2) ^ 0.5
      if dist < nearest_dist then
        nearest, nearest_dist = index, dist
      end
      ImGui.DrawList_AddCircle(draw_list, px, py, index == selected_point and 7.5 or 5.8,
        index == selected_point and COLORS.point_selected or COLORS.point, 18, 1.5)
    end

    local route_hovered = hovered and mx >= route_x0 and mx <= route_x1 and my >= route_y0 and my <= route_y1
    if route_hovered and ImGui.IsMouseClicked(ctx, 0) then
      route_enabled[selected_route] = true
      if nearest and nearest_dist < 15 then
        selected_point = nearest
      elseif #selected_points < MAX_ROUTE_POINTS then
        local new_point = {
          x = clamp((mx - route_x0) / math.max(1, route_x1 - route_x0), 0, 1),
          y = clamp((route_y1 - my) / math.max(1, route_y1 - route_y0), 0, 1),
        }
        selected_points[#selected_points + 1] = new_point
        sort_route_points(selected_points)
        for index, point in ipairs(selected_points) do
          if point == new_point then
            selected_point = index
            break
          end
        end
      end
    end

    if selected_point and active and ImGui.IsMouseDown(ctx, 0) then
      local point = selected_points[selected_point]
      if point then
        if selected_point > 1 and selected_point < #selected_points then
          point.x = clamp((mx - route_x0) / math.max(1, route_x1 - route_x0), 0, 1)
        end
        point.y = clamp((route_y1 - my) / math.max(1, route_y1 - route_y0), 0, 1)
        sort_route_points(selected_points)
        for index, candidate in ipairs(selected_points) do
          if candidate == point then selected_point = index break end
        end
      end
    end
  end

  ImGui.DrawList_AddText(draw_list, x0 + 12, y0 + 8, COLORS.text, "Spectra map")
  ImGui.DrawList_AddText(draw_list, x1 - 230, y0 + 8, COLORS.muted, tostring(channels) .. "ch channel preview")
  return selected_point
end

local function draw_route_editor(ctx, points, def, selected_index, enabled)
  sort_route_points(points)
  local width = ImGui.GetContentRegionAvail(ctx)
  local height = 138
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local x1, y1 = x0 + width, y0 + height
  local pad = 12
  local px0, py0 = x0 + pad, y0 + 26
  local px1, py1 = x1 - pad, y1 - 18

  ImGui.InvisibleButton(ctx, "##route_editor", width, height)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local mx, my = ImGui.GetMousePos(ctx)

  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, enabled and COLORS.panel or COLORS.panel_soft)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, COLORS.edge)
  ImGui.DrawList_AddText(draw_list, x0 + 10, y0 + 7, enabled and COLORS.text or COLORS.muted, (def and def.label or "Route") .. " route")

  for grid = 1, 3 do
    local gx = px0 + (px1 - px0) * grid / 4
    local gy = py0 + (py1 - py0) * grid / 4
    ImGui.DrawList_AddLine(draw_list, gx, py0, gx, py1, COLORS.grid, 1)
    ImGui.DrawList_AddLine(draw_list, px0, gy, px1, gy, COLORS.grid, 1)
  end

  local prev_x, prev_y = nil, nil
  for _, point in ipairs(points) do
    local px = lerp(px0, px1, point.x)
    local py = lerp(py1, py0, point.y)
    if prev_x then
      ImGui.DrawList_AddLine(draw_list, prev_x, prev_y, px, py, enabled and COLORS.route or COLORS.muted, 2)
      ImGui.DrawList_AddTriangleFilled(draw_list, prev_x, py1, px, py1, px, py, COLORS.route_fill)
      ImGui.DrawList_AddTriangleFilled(draw_list, prev_x, py1, prev_x, prev_y, px, py, COLORS.route_fill)
    end
    prev_x, prev_y = px, py
  end

  local nearest, nearest_dist = nil, 999999
  for index, point in ipairs(points) do
    local px = lerp(px0, px1, point.x)
    local py = lerp(py1, py0, point.y)
    local dist = ((mx - px) ^ 2 + (my - py) ^ 2) ^ 0.5
    if dist < nearest_dist then
      nearest, nearest_dist = index, dist
    end
    ImGui.DrawList_AddCircleFilled(draw_list, px, py, index == selected_index and 5.8 or 4.4,
      index == selected_index and COLORS.point_selected or COLORS.point, 18)
  end

  if hovered and ImGui.IsMouseClicked(ctx, 0) and nearest and nearest_dist < 13 then
    selected_index = nearest
  end
  if selected_index and active and ImGui.IsMouseDown(ctx, 0) then
    local point = points[selected_index]
    if point then
      if selected_index > 1 and selected_index < #points then
        point.x = clamp((mx - px0) / math.max(1, px1 - px0), 0, 1)
      end
      point.y = clamp((py1 - my) / math.max(1, py1 - py0), 0, 1)
      sort_route_points(points)
      for index, candidate in ipairs(points) do
        if candidate == point then selected_index = index break end
      end
    end
  end

  if def and selected_index and points[selected_index] then
    local p = points[selected_index]
    local text = string.format("t %.2f / " .. def.fmt, p.x, route_value(def, p.y))
    ImGui.DrawList_AddText(draw_list, x1 - 150, y0 + 7, COLORS.muted, text)
  end

  return selected_index
end

local function draw_route_overview(ctx, route_points, route_enabled, selected_route, selected_point, values)
  local width = ImGui.GetContentRegionAvail(ctx)
  local gap = 8
  local columns = 2
  local lane_w = math.max(180, (width - gap) / columns)
  local lane_h = 62

  for index, def in ipairs(ROUTE_DEFS) do
    local col = (index - 1) % columns
    if col > 0 then ImGui.SameLine(ctx) end

    local x0, y0 = ImGui.GetCursorScreenPos(ctx)
    local x1, y1 = x0 + lane_w, y0 + lane_h
    local points = route_points[index]
    local enabled = route_enabled[index]
    local is_selected = selected_route == index
    local draw_list = ImGui.GetWindowDrawList(ctx)

    ImGui.InvisibleButton(ctx, "##route_overview_" .. tostring(index), lane_w, lane_h)
    local hovered = ImGui.IsItemHovered(ctx)
    local active = ImGui.IsItemActive(ctx)
    local mx, my = ImGui.GetMousePos(ctx)

    local bg = is_selected and color(0.075, 0.082, 0.078, 1) or color(0.048, 0.054, 0.056, 1)
    ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, bg)
    ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, is_selected and COLORS.route or COLORS.edge, 0, 0, is_selected and 1.8 or 1)

    local px0, py0 = x0 + 10, y0 + 20
    local px1, py1 = x1 - 10, y1 - 9
    for grid = 1, 3 do
      local gx = px0 + (px1 - px0) * grid / 4
      ImGui.DrawList_AddLine(draw_list, gx, py0, gx, py1, COLORS.grid_soft, 1)
    end

    ImGui.DrawList_AddText(draw_list, x0 + 9, y0 + 5, enabled and COLORS.text or COLORS.muted, def.label)
    local value_text = string.format(def.fmt, current_value_for_key(values, def.key))
    ImGui.DrawList_AddText(draw_list, x1 - 62, y0 + 5, COLORS.muted, value_text)

    local nearest, nearest_dist = nil, 999999
    local last_x, last_y = nil, nil
    sort_route_points(points)
    for point_index, point in ipairs(points) do
      local px = lerp(px0, px1, point.x)
      local py = lerp(py1, py0, enabled and point.y or route_norm(def, current_value_for_key(values, def.key)))
      if last_x then
        ImGui.DrawList_AddLine(draw_list, last_x, last_y, px, py, enabled and COLORS.route or COLORS.muted,
          enabled and 1.8 or 1.2)
      end
      local dist = ((mx - px) ^ 2 + (my - py) ^ 2) ^ 0.5
      if dist < nearest_dist then
        nearest, nearest_dist = point_index, dist
      end
      if enabled or is_selected then
        ImGui.DrawList_AddCircleFilled(draw_list, px, py, is_selected and point_index == selected_point and 4.8 or 3.5,
          is_selected and point_index == selected_point and COLORS.point_selected or COLORS.point, 14)
      end
      last_x, last_y = px, py
    end

    if hovered and ImGui.IsMouseClicked(ctx, 0) then
      if selected_route ~= index then
        selected_route = index
        selected_point = nil
      end
      route_enabled[index] = true
      if nearest and nearest_dist < 12 then
        selected_point = nearest
      elseif #points < MAX_ROUTE_POINTS then
        local new_point = {
          x = clamp((mx - px0) / math.max(1, px1 - px0), 0, 1),
          y = clamp((py1 - my) / math.max(1, py1 - py0), 0, 1),
        }
        points[#points + 1] = new_point
        sort_route_points(points)
        for point_index, point in ipairs(points) do
          if point == new_point then
            selected_point = point_index
            break
          end
        end
      end
    end

    if selected_route == index and selected_point and active and ImGui.IsMouseDown(ctx, 0) then
      local point = points[selected_point]
      if point then
        if selected_point > 1 and selected_point < #points then
          point.x = clamp((mx - px0) / math.max(1, px1 - px0), 0, 1)
        end
        point.y = clamp((py1 - my) / math.max(1, py1 - py0), 0, 1)
        sort_route_points(points)
        for point_index, candidate in ipairs(points) do
          if candidate == point then selected_point = point_index break end
        end
      end
    end
  end

  return selected_route, selected_point
end

local start_pos, duration, from_time_selection = get_time_defaults()
local ctx = ImGui.CreateContext("Render MC Spectra Synth")
math.randomseed(math.floor(((reaper.time_precise and reaper.time_precise()) or os.clock()) * 1000000))
local open = true
local channel_index = 4 -- 8ch
local algorithm = 1
local form = 2
local rate = 0.45
local base_freq = 120
local density = 0.45
local brightness = 0.55
local decay = 0.35
local spread = 0.55
local correlation = 0.65
local drift = 0.18
local crush = 0.0
local gain_db = -18.0
local normalize = true
local normalize_db = -12.0
local insert_gain = 0.25
local seed = 1
local should_render = false
local selected_route = 2 -- Density
local selected_route_point = nil
local route_enabled = {}
local route_points = {}
local random_point_count = 16
local random_amount = 0.72
local random_smooth = 0.30
local random_dispersion = 0.35

local function synth_values()
  return {
    rate = rate,
    base_freq = base_freq,
    density = density,
    brightness = brightness,
    decay = decay,
    spread = spread,
    correlation = correlation,
    drift = drift,
    crush = crush,
    gain_db = gain_db,
  }
end

for index, def in ipairs(ROUTE_DEFS) do
  route_enabled[index] = false
  route_points[index] = {}
  set_flat_route(route_points[index], def, current_value_for_key(synth_values(), def.key))
end
apply_route_preset(route_points, route_enabled, form, synth_values())

local function serialize_route(points)
  local parts = {}
  for index, point in ipairs(points or {}) do
    parts[index] = string.format("%.9f:%.9f", clamp(point.x or 0, 0, 1), clamp(point.y or 0, 0, 1))
  end
  return table.concat(parts, ",")
end

local function parse_route(text)
  local points = {}
  for pair in tostring(text or ""):gmatch("[^,]+") do
    local x, y = pair:match("^([%-%d%.]+):([%-%d%.]+)$")
    if x and y then
      points[#points + 1] = { x = clamp(tonumber(x) or 0, 0, 1), y = clamp(tonumber(y) or 0, 0, 1) }
    end
  end
  if #points >= 2 then
    sort_route_points(points)
    return points
  end
  return nil
end

local function save_last_settings()
  local lines = {
    "version=1",
    "duration=" .. tostring(duration),
    "channel_index=" .. tostring(channel_index),
    "algorithm=" .. tostring(algorithm),
    "form=" .. tostring(form),
    "rate=" .. tostring(rate),
    "base_freq=" .. tostring(base_freq),
    "density=" .. tostring(density),
    "brightness=" .. tostring(brightness),
    "decay=" .. tostring(decay),
    "spread=" .. tostring(spread),
    "correlation=" .. tostring(correlation),
    "drift=" .. tostring(drift),
    "crush=" .. tostring(crush),
    "gain_db=" .. tostring(gain_db),
    "normalize=" .. (normalize and "1" or "0"),
    "normalize_db=" .. tostring(normalize_db),
    "insert_gain=" .. tostring(insert_gain),
    "seed=" .. tostring(seed),
    "selected_route=" .. tostring(selected_route),
    "random_point_count=" .. tostring(random_point_count),
    "random_amount=" .. tostring(random_amount),
    "random_smooth=" .. tostring(random_smooth),
    "random_dispersion=" .. tostring(random_dispersion),
  }
  for index = 1, #ROUTE_DEFS do
    lines[#lines + 1] = "route_enabled_" .. index .. "=" .. (route_enabled[index] and "1" or "0")
    lines[#lines + 1] = "route_" .. index .. "=" .. serialize_route(route_points[index])
  end
  reaper.SetExtState(EXTSTATE_SECTION, "last_settings", table.concat(lines, "\n"), true)
end

local function load_last_settings()
  local text = reaper.GetExtState(EXTSTATE_SECTION, "last_settings")
  if not text or text == "" then return end
  local values = {}
  for line in text:gmatch("[^\n]+") do
    local key, value = line:match("^([^=]+)=(.*)$")
    if key then values[key] = value end
  end
  local function number_value(key, fallback)
    local value = tonumber(values[key])
    return value ~= nil and value or fallback
  end
  duration = math.max(0.1, number_value("duration", duration))
  channel_index = math.max(1, math.min(#CH_VALUES, math.floor(number_value("channel_index", channel_index) + 0.5)))
  algorithm = math.max(1, math.min(#ALGO_NAMES, math.floor(number_value("algorithm", algorithm) + 0.5)))
  form = math.max(1, math.min(#FORM_NAMES, math.floor(number_value("form", form) + 0.5)))
  rate = clamp(number_value("rate", rate), 0, 1)
  base_freq = math.max(20, math.min(4000, number_value("base_freq", base_freq)))
  density = clamp(number_value("density", density), 0, 1)
  brightness = clamp(number_value("brightness", brightness), 0, 1)
  decay = clamp(number_value("decay", decay), 0, 1)
  spread = clamp(number_value("spread", spread), 0, 1)
  correlation = clamp(number_value("correlation", correlation), 0, 1)
  drift = clamp(number_value("drift", drift), 0, 1)
  crush = clamp(number_value("crush", crush), 0, 1)
  gain_db = math.max(-60, math.min(0, number_value("gain_db", gain_db)))
  normalize = values.normalize == nil and normalize or values.normalize == "1"
  normalize_db = math.max(-24, math.min(0, number_value("normalize_db", normalize_db)))
  insert_gain = math.max(0.05, math.min(1.0, number_value("insert_gain", insert_gain)))
  seed = math.max(1, math.min(9999, math.floor(number_value("seed", seed) + 0.5)))
  selected_route = math.max(1, math.min(#ROUTE_DEFS, math.floor(number_value("selected_route", selected_route) + 0.5)))
  random_point_count = math.max(4, math.min(MAX_ROUTE_POINTS, math.floor(number_value("random_point_count", random_point_count) + 0.5)))
  random_amount = clamp(number_value("random_amount", random_amount), 0, 1)
  random_smooth = clamp(number_value("random_smooth", random_smooth), 0, 1)
  random_dispersion = clamp(number_value("random_dispersion", random_dispersion), 0, 1)
  for index, def in ipairs(ROUTE_DEFS) do
    route_enabled[index] = values["route_enabled_" .. index] == "1"
    local parsed = parse_route(values["route_" .. index])
    if parsed then
      route_points[index] = parsed
    else
      set_flat_route(route_points[index], def, current_value_for_key(synth_values(), def.key))
    end
  end
end

load_last_settings()

local function loop()
  ImGui.SetNextWindowSize(ctx, 820, 880, ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, "Render MC Spectra Synth", open)
  if visible then
    local changed
    local values = synth_values()
    selected_route, selected_route_point = draw_route_overview(ctx, route_points, route_enabled, selected_route,
      selected_route_point, values)
    ImGui.Separator(ctx)
    ImGui.SetNextItemWidth(ctx, 135)
    changed, start_pos = ImGui.InputDouble(ctx, "Start time", start_pos, 0.1, 1.0, "%.3f")
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 135)
    changed, duration = ImGui.InputDouble(ctx, "Duration (sec)", duration, 1.0, 10.0, "%.3f")
    duration = math.max(0.1, duration)
    ImGui.SameLine(ctx)
    ImGui.Text(ctx, string.format("End %.3f sec", math.max(0, start_pos) + duration))
    ImGui.SetNextItemWidth(ctx, 135)
    changed, channel_index = combo(ctx, "Output channels", CH_NAMES, channel_index)
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 180)
    changed, algorithm = combo(ctx, "Algorithm", ALGO_NAMES, algorithm)
    ImGui.SetNextItemWidth(ctx, 180)
    changed, form = combo(ctx, "Map preset", FORM_NAMES, form)
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Load preset") then
      apply_route_preset(route_points, route_enabled, form, synth_values())
      selected_route_point = nil
    end
    ImGui.SetNextItemWidth(ctx, 120)
    changed, random_point_count = ImGui.SliderInt(ctx, "Random points", random_point_count, 4, MAX_ROUTE_POINTS)
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 120)
    changed, random_amount = ImGui.SliderDouble(ctx, "Amount", random_amount, 0, 1, "%.2f")
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 120)
    changed, random_smooth = ImGui.SliderDouble(ctx, "Smooth", random_smooth, 0, 1, "%.2f")
    ImGui.SetNextItemWidth(ctx, 160)
    changed, random_dispersion = ImGui.SliderDouble(ctx, "Dispersion", random_dispersion, 0, 1, "%.2f")
    if ImGui.Button(ctx, "Randomize selected") then
      randomize_route_set(route_points, route_enabled, synth_values(), selected_route, "selected",
        random_amount, random_point_count, random_smooth, random_dispersion)
      selected_route_point = nil
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Randomize all") then
      randomize_route_set(route_points, route_enabled, synth_values(), selected_route, "all",
        random_amount, random_point_count, random_smooth, random_dispersion)
      selected_route_point = nil
    end
    ImGui.Separator(ctx)
    changed, rate = ImGui.SliderDouble(ctx, "Rate", rate, 0, 1, "%.3f")
    changed, base_freq = ImGui.SliderDouble(ctx, "Base frequency", base_freq, 20, 4000, "%.1f Hz")
    changed, density = ImGui.SliderDouble(ctx, "Density / chaos", density, 0, 1, "%.3f")
    changed, brightness = ImGui.SliderDouble(ctx, "Brightness", brightness, 0, 1, "%.3f")
    changed, decay = ImGui.SliderDouble(ctx, "Decay / sustain", decay, 0, 1, "%.3f")
    ImGui.Separator(ctx)
    changed, spread = ImGui.SliderDouble(ctx, "Field spread", spread, 0, 1, "%.3f")
    changed, correlation = ImGui.SliderDouble(ctx, "Channel correlation", correlation, 0, 1, "%.3f")
    changed, drift = ImGui.SliderDouble(ctx, "Drift", drift, 0, 1, "%.3f")
    changed, crush = ImGui.SliderDouble(ctx, "Crush / decimate", crush, 0, 1, "%.3f")
    ImGui.Separator(ctx)
    ImGui.SetNextItemWidth(ctx, 180)
    local route_changed
    route_changed, selected_route = combo(ctx, "Edit route", ROUTE_NAMES, selected_route)
    if route_changed then selected_route_point = nil end
    ImGui.SameLine(ctx)
    changed, route_enabled[selected_route] = ImGui.Checkbox(ctx, "Active", route_enabled[selected_route])
    local selected_def = ROUTE_DEFS[selected_route]
    selected_route_point = draw_route_editor(ctx, route_points[selected_route], selected_def, selected_route_point,
      route_enabled[selected_route])
    local current_norm = selected_def and route_norm(selected_def, current_value_for_key(synth_values(), selected_def.key)) or 0.5
    if ImGui.Button(ctx, "Flat") then set_route_shape(route_points[selected_route], "flat", current_norm) selected_route_point = nil end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Rise") then set_route_shape(route_points[selected_route], "rise", current_norm) route_enabled[selected_route] = true selected_route_point = nil end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Fall") then set_route_shape(route_points[selected_route], "fall", current_norm) route_enabled[selected_route] = true selected_route_point = nil end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Ridge") then set_route_shape(route_points[selected_route], "ridge", current_norm) route_enabled[selected_route] = true selected_route_point = nil end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Valley") then set_route_shape(route_points[selected_route], "valley", current_norm) route_enabled[selected_route] = true selected_route_point = nil end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Terrace") then set_route_shape(route_points[selected_route], "terrace", current_norm) route_enabled[selected_route] = true selected_route_point = nil end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Switchback") then set_route_shape(route_points[selected_route], "switchback", current_norm) route_enabled[selected_route] = true selected_route_point = nil end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Add") and #route_points[selected_route] < MAX_ROUTE_POINTS then
      route_points[selected_route][#route_points[selected_route] + 1] = { x = 0.5, y = current_norm }
      selected_route_point = #route_points[selected_route]
      route_enabled[selected_route] = true
      sort_route_points(route_points[selected_route])
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Delete") and selected_route_point and selected_route_point > 1 and selected_route_point < #route_points[selected_route] then
      table.remove(route_points[selected_route], selected_route_point)
      selected_route_point = nil
      sort_route_points(route_points[selected_route])
    end
    ImGui.Separator(ctx)
    changed, gain_db = ImGui.SliderDouble(ctx, "Print gain", gain_db, -60, 0, "%.1f dB")
    changed, normalize = ImGui.Checkbox(ctx, "Peak normalize", normalize)
    if normalize then
      changed, normalize_db = ImGui.SliderDouble(ctx, "Normalize peak dB", normalize_db, -36, -3, "%.1f")
    end
    changed, insert_gain = ImGui.SliderDouble(ctx, "Inserted track gain", insert_gain, 0.05, 1.0, "%.2f")
    changed, seed = ImGui.SliderInt(ctx, "Seed", seed, 1, 9999)
    ImGui.Separator(ctx)
    if ImGui.Button(ctx, "Render", 92, 26) then should_render = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 92, 26) then open = false end
    ImGui.End(ctx)
  end

  if should_render then
    save_last_settings()
    open = false
    render_texture({
      start_pos = math.max(0, start_pos),
      duration = math.max(0.1, duration),
      channels = CH_VALUES[channel_index] or 8,
      algorithm = algorithm,
      form = form,
      rate = rate,
      base_freq = base_freq,
      density = density,
      brightness = brightness,
      decay = decay,
      spread = spread,
      correlation = correlation,
      drift = drift,
      crush = crush,
      gain_db = gain_db,
      normalize = normalize,
      normalize_db = normalize_db,
      insert_gain = insert_gain,
      routes = copy_routes(route_points, route_enabled),
      seed = seed,
    })
    return
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
