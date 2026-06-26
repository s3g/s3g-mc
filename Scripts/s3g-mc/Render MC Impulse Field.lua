-- @description Render MC Impulse Field
-- @author s3g
-- @version 0.1
-- @requires ReaImGui
-- @category Spectral / Convolution
-- @render Yes; writes a procedural multichannel impulse media item.
-- @method Procedural impulse-field generator for convolution work. Choose channel count, duration, impulse count, spacing rule, and impulse profile; the action writes a multichannel WAV that can be used directly with Convolve selected items or convolution reverb plugins.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Render MC Impulse Field", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local EXTSTATE_SECTION = "s3g_mc_render_impulse_field"
local SAMPLE_RATE = 48000

local RULE_NAMES = {
  [1] = "Uniform grid",
  [2] = "Random safe",
  [3] = "Round-robin scatter",
  [4] = "Clustered bursts",
  [5] = "Channel sweep",
}

local PROFILE_NAMES = {
  [1] = "Dirac",
  [2] = "Gaussian click",
  [3] = "Damped sine",
  [4] = "Noise tick",
  [5] = "Tiny chirp",
}

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function shell_quote(path)
  return "'" .. tostring(path):gsub("'", "'\\''") .. "'"
end

local function ensure_dir(path)
  reaper.RecursiveCreateDirectory(path, 0)
end

local function output_dir()
  local project_path = reaper.GetProjectPath("")
  if type(project_path) ~= "string" or project_path == "" then project_path = script_dir end
  local dir = project_path .. "/s3g_impulse_fields"
  ensure_dir(dir)
  return dir
end

local function combo(ctx, label, names, value)
  local changed = false
  if ImGui.BeginCombo(ctx, label, names[value] or names[1] or "") then
    for index, name in ipairs(names) do
      local selected = value == index
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

local function put_u16(bytes, value)
  bytes[#bytes + 1] = string.char(value & 255, (value >> 8) & 255)
end

local function put_u32(bytes, value)
  bytes[#bytes + 1] = string.char(value & 255, (value >> 8) & 255, (value >> 16) & 255, (value >> 24) & 255)
end

local function put_i24(bytes, value)
  local v = math.floor(clamp(value, -1, 1) * 8388607)
  if v < 0 then v = v + 16777216 end
  bytes[#bytes + 1] = string.char(v & 255, (v >> 8) & 255, (v >> 16) & 255)
end

local function write_wav(path, data, channels, sample_rate, frames)
  local bytes_per_sample = 3
  local data_bytes = frames * channels * bytes_per_sample
  local fmt = {}
  local use_extensible = channels > 2
  if use_extensible then
    put_u16(fmt, 0xFFFE)
    put_u16(fmt, channels)
    put_u32(fmt, sample_rate)
    put_u32(fmt, sample_rate * channels * bytes_per_sample)
    put_u16(fmt, channels * bytes_per_sample)
    put_u16(fmt, 24)
    put_u16(fmt, 22)
    put_u16(fmt, 24)
    put_u32(fmt, 0)
    fmt[#fmt + 1] = string.char(1, 0, 0, 0, 0, 0, 16, 0, 128, 0, 0, 170, 0, 56, 155, 113)
  else
    put_u16(fmt, 1)
    put_u16(fmt, channels)
    put_u32(fmt, sample_rate)
    put_u32(fmt, sample_rate * channels * bytes_per_sample)
    put_u16(fmt, channels * bytes_per_sample)
    put_u16(fmt, 24)
  end
  local fmt_payload = table.concat(fmt)

  local file = io.open(path, "wb")
  if not file then return false, "Could not write " .. path end
  file:write("RIFF")
  file:write(string.pack("<I4", 4 + 8 + #fmt_payload + 8 + data_bytes))
  file:write("WAVEfmt ")
  file:write(string.pack("<I4", #fmt_payload))
  file:write(fmt_payload)
  file:write("data")
  file:write(string.pack("<I4", data_bytes))

  local chunk = {}
  for frame = 1, frames do
    for ch = 1, channels do
      put_i24(chunk, data[ch][frame] or 0)
    end
    if #chunk > 8192 then
      file:write(table.concat(chunk))
      chunk = {}
    end
  end
  if #chunk > 0 then file:write(table.concat(chunk)) end
  file:close()
  return true
end

local function event_fits(events, t, ch, safe_sec, global_safe)
  for _, event in ipairs(events) do
    if math.abs(event.t - t) < safe_sec and (global_safe or event.ch == ch) then return false end
  end
  return true
end

local function add_safe_event(events, t, ch, duration, safe_sec, global_safe)
  t = clamp(t, 0, math.max(0, duration - 0.001))
  ch = math.max(1, math.floor(ch + 0.5))
  if event_fits(events, t, ch, safe_sec, global_safe) then
    events[#events + 1] = { t = t, ch = ch }
    return true
  end
  return false
end

local function make_events(rule, duration, channels, count, safe_ms, jitter, global_safe)
  local events = {}
  local safe_sec = safe_ms / 1000
  local usable_count = math.max(1, math.floor(count))
  if rule == 1 then
    for i = 1, usable_count do
      local u = usable_count == 1 and 0.5 or (i - 1) / (usable_count - 1)
      local t = duration * (0.04 + u * 0.92)
      local ch = ((i - 1) % channels) + 1
      add_safe_event(events, t, ch, duration, safe_sec, global_safe)
    end
  elseif rule == 3 then
    for i = 1, usable_count do
      local u = i / (usable_count + 1)
      local t = duration * u + (math.random() * 2 - 1) * jitter * safe_sec
      local ch = ((i - 1) % channels) + 1
      add_safe_event(events, t, ch, duration, safe_sec, global_safe)
    end
  elseif rule == 4 then
    local clusters = math.max(2, math.min(12, math.floor(math.sqrt(usable_count))))
    for i = 1, usable_count do
      local c = ((i - 1) % clusters) + 1
      local center = duration * (c / (clusters + 1))
      local t = center + (math.random() * 2 - 1) * safe_sec * (1.5 + jitter * 6)
      local ch = 1 + math.floor(math.random() * channels)
      add_safe_event(events, t, ch, duration, safe_sec, global_safe)
    end
  elseif rule == 5 then
    for i = 1, usable_count do
      local u = usable_count == 1 and 0.5 or (i - 1) / (usable_count - 1)
      local t = duration * (0.04 + u * 0.92)
      local ch = 1 + math.floor(u * (channels - 1))
      add_safe_event(events, t, ch, duration, safe_sec, global_safe)
    end
  else
    local tries = 0
    while #events < usable_count and tries < usable_count * 80 do
      tries = tries + 1
      local t = duration * (0.02 + math.random() * 0.96)
      local ch = 1 + math.floor(math.random() * channels)
      add_safe_event(events, t, ch, duration, safe_sec, global_safe)
    end
  end
  table.sort(events, function(a, b) return a.t < b.t end)
  return events
end

local function add_profile(data, frame, ch, profile, width_ms, freq, gain)
  local frames = data._frames
  local width = math.max(1, math.floor(width_ms * SAMPLE_RATE / 1000))
  if profile == 1 then
    if frame >= 1 and frame <= frames then data[ch][frame] = (data[ch][frame] or 0) + gain end
  else
    local half = width
    for offset = -half, half do
      local index = frame + offset
      if index >= 1 and index <= frames then
        local x = offset / math.max(1, half)
        local env = math.exp(-x * x * 4.5)
        local value = 0
        if profile == 2 then
          value = env
        elseif profile == 3 then
          value = env * math.sin(2 * math.pi * freq * (offset + half) / SAMPLE_RATE)
        elseif profile == 4 then
          value = env * (math.random() * 2 - 1)
        else
          local u = (offset + half) / math.max(1, half * 2)
          local f = freq * (0.5 + u * 3.0)
          value = env * math.sin(2 * math.pi * f * (offset + half) / SAMPLE_RATE)
        end
        data[ch][index] = (data[ch][index] or 0) + value * gain
      end
    end
  end
end

local function normalize_data(data, target_db)
  local peak = 0
  for ch = 1, #data do
    for _, value in pairs(data[ch]) do peak = math.max(peak, math.abs(value)) end
  end
  if peak <= 0 then return 0 end
  local scale = (10 ^ (target_db / 20)) / peak
  for ch = 1, #data do
    for index, value in pairs(data[ch]) do data[ch][index] = value * scale end
  end
  return peak
end

local function insert_output(path, label, position, channels, duration)
  local track_index = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(track_index, true)
  local track = reaper.GetTrack(0, track_index)
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", label, true)
  reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", mc.reaper_track_channel_count(channels))
  local item = reaper.AddMediaItemToTrack(track)
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", position)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", duration)
  local take = reaper.AddTakeToMediaItem(item)
  local source = reaper.PCM_Source_CreateFromFile(path)
  if not source then return nil, "REAPER could not open generated WAV." end
  reaper.SetMediaItemTake_Source(take, source)
  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", label, true)
  reaper.SetMediaItemSelected(item, true)
  reaper.UpdateItemInProject(item)
  reaper.Main_OnCommand(40441, 0) -- Peaks: Rebuild peaks for selected items
  return item
end

local function render_impulse_field(settings)
  math.randomseed(settings.seed)
  local frames = math.max(1, math.floor(settings.duration * SAMPLE_RATE + 0.5))
  local data = {}
  data._frames = frames
  for ch = 1, settings.channels do
    data[ch] = {}
  end
  local events = make_events(settings.rule, settings.duration, settings.channels, settings.count,
    settings.safe_ms, settings.jitter, settings.global_safe)
  for _, event in ipairs(events) do
    local frame = 1 + math.floor(event.t * SAMPLE_RATE)
    local gain = settings.gain * (1 - settings.variation * 0.5 + math.random() * settings.variation)
    local width = settings.width_ms * (1 - settings.variation * 0.4 + math.random() * settings.variation * 0.8)
    local freq = settings.freq * (0.5 + math.random() * 1.5)
    add_profile(data, frame, event.ch, settings.profile, width, freq, gain)
  end
  normalize_data(data, settings.normalize_db)

  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local path = output_dir() .. "/s3g_impulse_field_" .. stamp .. "_" .. tostring(settings.channels) .. "ch.wav"
  local ok, err = write_wav(path, data, settings.channels, SAMPLE_RATE, frames)
  if not ok then mc.show_error(err or "Could not write impulse field WAV.") return end

  reaper.Undo_BeginBlock()
  local item, insert_err = insert_output(path, "MC Impulse Field (" .. tostring(settings.channels) .. "ch)", settings.position,
    settings.channels, settings.duration)
  reaper.Undo_EndBlock("Render MC Impulse Field", -1)
  if not item then mc.show_error(insert_err or "Could not insert generated impulse field.") return end

  mc.print_plan("Render MC Impulse Field", {
    "Duration: " .. string.format("%.3f sec", settings.duration),
    "Channels: " .. tostring(settings.channels),
    "Rule: " .. (RULE_NAMES[settings.rule] or "?"),
    "Profile: " .. (PROFILE_NAMES[settings.profile] or "?"),
    "Requested impulses: " .. tostring(settings.count),
    "Placed impulses: " .. tostring(#events),
    "Safe distance: " .. string.format("%.1f ms", settings.safe_ms),
    "Output: " .. path,
  })
end

local ctx = ImGui.CreateContext("Render MC Impulse Field")
local open = true
local position = reaper.GetCursorPosition()
local duration = 4.0
local channels = 8
local count = 32
local safe_ms = 35.0
local rule = 2
local profile = 2
local width_ms = 4.0
local freq = 1200.0
local gain = 0.8
local variation = 0.35
local jitter = 0.8
local global_safe = false
local normalize_db = -6.0
local seed = math.floor((reaper.time_precise() * 1000) % 9999) + 1
local should_render = false

local function save_last_settings()
  local lines = {
    "duration=" .. duration,
    "channels=" .. channels,
    "count=" .. count,
    "safe_ms=" .. safe_ms,
    "rule=" .. rule,
    "profile=" .. profile,
    "width_ms=" .. width_ms,
    "freq=" .. freq,
    "gain=" .. gain,
    "variation=" .. variation,
    "jitter=" .. jitter,
    "global_safe=" .. (global_safe and "1" or "0"),
    "normalize_db=" .. normalize_db,
    "seed=" .. seed,
  }
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
  local function n(key, fallback)
    local value = tonumber(values[key])
    return value ~= nil and value or fallback
  end
  duration = math.max(0.05, n("duration", duration))
  channels = math.max(1, math.min(128, math.floor(n("channels", channels) + 0.5)))
  count = math.max(1, math.min(4096, math.floor(n("count", count) + 0.5)))
  safe_ms = math.max(0, math.min(5000, n("safe_ms", safe_ms)))
  rule = math.max(1, math.min(#RULE_NAMES, math.floor(n("rule", rule) + 0.5)))
  profile = math.max(1, math.min(#PROFILE_NAMES, math.floor(n("profile", profile) + 0.5)))
  width_ms = math.max(0.02, math.min(1000, n("width_ms", width_ms)))
  freq = math.max(20, math.min(20000, n("freq", freq)))
  gain = clamp(n("gain", gain), 0, 1)
  variation = clamp(n("variation", variation), 0, 1)
  jitter = clamp(n("jitter", jitter), 0, 1)
  global_safe = values.global_safe == "1"
  normalize_db = math.max(-36, math.min(0, n("normalize_db", normalize_db)))
  seed = math.max(1, math.min(9999, math.floor(n("seed", seed) + 0.5)))
end

load_last_settings()

local function loop()
  ImGui.SetNextWindowSize(ctx, 560, 620, ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, "Render MC Impulse Field", open)
  if visible then
    local changed
    ImGui.SetNextItemWidth(ctx, 130)
    changed, position = ImGui.InputDouble(ctx, "Start time", position, 0.1, 1.0, "%.3f")
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 130)
    changed, duration = ImGui.InputDouble(ctx, "Duration (sec)", duration, 0.5, 2.0, "%.3f")
    duration = math.max(0.05, duration)
    ImGui.Text(ctx, string.format("End %.3f sec", math.max(0, position) + duration))

    ImGui.Separator(ctx)
    changed, channels = ImGui.SliderInt(ctx, "Channels", channels, 1, 128)
    changed, count = ImGui.SliderInt(ctx, "Impulses", count, 1, 512)
    changed, safe_ms = ImGui.SliderDouble(ctx, "Safe distance", safe_ms, 0, 1000, "%.1f ms")
    changed, global_safe = ImGui.Checkbox(ctx, "Global spacing", global_safe)
    changed, rule = combo(ctx, "Distribution", RULE_NAMES, rule)
    changed, jitter = ImGui.SliderDouble(ctx, "Timing variation", jitter, 0, 1, "%.2f")

    ImGui.Separator(ctx)
    changed, profile = combo(ctx, "Impulse profile", PROFILE_NAMES, profile)
    changed, width_ms = ImGui.SliderDouble(ctx, "Profile width", width_ms, 0.02, 100, "%.2f ms")
    changed, freq = ImGui.SliderDouble(ctx, "Profile frequency", freq, 20, 12000, "%.1f Hz")
    changed, gain = ImGui.SliderDouble(ctx, "Impulse gain", gain, 0, 1, "%.2f")
    changed, variation = ImGui.SliderDouble(ctx, "Profile variation", variation, 0, 1, "%.2f")
    changed, normalize_db = ImGui.SliderDouble(ctx, "Peak normalize", normalize_db, -36, 0, "%.1f dB")
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
    render_impulse_field({
      position = math.max(0, position),
      duration = math.max(0.05, duration),
      channels = channels,
      count = count,
      safe_ms = safe_ms,
      rule = rule,
      profile = profile,
      width_ms = width_ms,
      freq = freq,
      gain = gain,
      variation = variation,
      jitter = jitter,
      global_safe = global_safe,
      normalize_db = normalize_db,
      seed = seed,
    })
    return
  end
  if open then reaper.defer(loop) end
end

loop()
