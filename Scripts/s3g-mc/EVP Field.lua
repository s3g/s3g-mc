-- @description EVP Field
-- @author s3g
-- @version 0.5
-- @requires ReaImGui; Python 3 with NumPy; eSpeak NG; optional Speex
-- @category Offline Synthesis / IR
-- @render Yes; NumPy-backed synthetic voice/formant field.
-- @method Offline speech/formant synth for EVP/glossolalia textures. eSpeak NG provides the text-to-speech source; voice treatments bend it toward chant, melody, choir, apparition, damaged broadcast, and optional Speex codec damage behavior. Output can be fixed 3OA ACN/SN3D or a multichannel speaker shape such as ring, double ring, cube, or dome.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")
local be = dofile(script_dir .. "Breakpoint Envelope Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "EVP Field", 0) return end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
do
  local _s3g_theme_path = ({ reaper.get_action_context() })[2]
  if not _s3g_theme_path or _s3g_theme_path == "" then
    _s3g_theme_path = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
  end
  local _s3g_theme_dir = _s3g_theme_path:match("^(.*[/\\])") or ""
  package.path = _s3g_theme_dir .. "?.lua;" .. package.path
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme and _s3g_theme.install then _s3g_theme.install(ImGui) end
end
local theme = require("s3g-mc ImGui Theme")
local THEME = theme.palette(ImGui)


local TITLE = "EVP Field"
local EXT = "s3g_mc_evp_field_v1"
local OUTPUT_KEYS = { "3oa", "multichannel" }
local OUTPUT_LABELS = { "3OA ACN/SN3D", "Multichannel shape" }
local LAYOUT_KEYS = { "ring", "double_ring", "cube", "dome" }
local LAYOUT_LABELS = { "Ring", "Double ring", "Cube", "Dome" }
local TREATMENT_KEYS = { "clear", "chant", "melodic", "choir", "whisper_ghost", "possession", "broken_radio" }
local TREATMENT_LABELS = { "Clear speech", "Sung chant", "Melodic", "Choir", "Whisper ghost", "Possession", "Broken radio" }
local SCALE_KEYS = { "minor_pentatonic", "major_pentatonic", "minor", "dorian", "whole_tone", "chromatic" }
local SCALE_LABELS = { "Minor pentatonic", "Major pentatonic", "Minor", "Dorian", "Whole tone", "Chromatic" }
local SHAPER_KEYS = { "off", "preset", "tone_list", "profile_item" }
local SHAPER_LABELS = { "Off", "Preset", "Tone list", "Profile item" }
local SHAPER_PRESET_KEYS = { "throat", "telephone", "glass", "choir_air", "metal_mouth", "submerged", "thin_radio" }
local SHAPER_PRESET_LABELS = { "Throat", "Telephone", "Glass", "Choir air", "Metal mouth", "Submerged", "Thin radio" }
local CODEC_KEYS = { "off", "speex_nb", "speex_wb", "speex_uwb" }
local CODEC_LABELS = { "Off", "Speex narrowband", "Speex wideband", "Speex ultra-wideband" }
local TIME_KEYS = { "fill_duration", "manual_expand", "speech_length" }
local TIME_LABELS = { "Fill duration", "Manual expansion", "Speech length" }
local CHANNEL_VALUES = { 2, 4, 6, 8, 10, 12, 16, 20, 24, 32, 48, 64 }
local CHANNEL_LABELS = {}
for i, ch in ipairs(CHANNEL_VALUES) do CHANNEL_LABELS[i] = tostring(ch) .. " ch" end
local ENV_DEFS = {
  { key = "amplitude", label = "Amplitude", min = 0.0, max = 1.5, default = 1.0, fmt = "%.2f" },
  { key = "melody_depth", label = "Melody depth", min = 0.0, max = 1.0, default = 0.55, fmt = "%.2f" },
  { key = "vowel_sustain", label = "Vowel sustain", min = 0.0, max = 1.0, default = 0.25, fmt = "%.2f" },
  { key = "pitch_hz", label = "Pitch", min = 35.0, max = 420.0, default = 95.0, fmt = "%.1f Hz" },
  { key = "breath", label = "Breath", min = 0.0, max = 1.0, default = 0.35, fmt = "%.2f" },
  { key = "noise", label = "Noise", min = 0.0, max = 1.0, default = 0.28, fmt = "%.2f" },
  { key = "whisper", label = "Whisper", min = 0.0, max = 1.0, default = 0.25, fmt = "%.2f" },
  { key = "ghost_mix", label = "Ghost mix", min = 0.0, max = 1.0, default = 0.35, fmt = "%.2f" },
  { key = "azimuth", label = "Azimuth", min = -180.0, max = 180.0, default = 0.0, fmt = "%.1f deg" },
  { key = "elevation", label = "Elevation", min = -89.0, max = 89.0, default = 0.0, fmt = "%.1f deg" },
}

local function getn(k, d) return tonumber(reaper.GetExtState(EXT, k)) or d end
local function gets(k, d) local v = reaper.GetExtState(EXT, k); if v == "" then return d end; return v end
local function getb(k, d) local v = reaper.GetExtState(EXT, k); if v == "" then return d end; return v ~= "0" end
local function set(k, v) reaper.SetExtState(EXT, k, type(v) == "boolean" and (v and "1" or "0") or tostring(v), true) end
local function rgba(r, g, b, a) return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1) end
local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local ROW_H = 25
local LABEL_W = 86
local CONTROL_GAP = 8
local VALUE_W = 76
local LABEL_ABBR = {
  ["VOICE TREATMENT"] = "TREAT",
  ["OUTPUT"] = "OUTPUT",
  ["SHAPE"] = "SHAPE",
  ["CHANNELS"] = "CHANNELS",
  ["ESPEAK VOICE"] = "VOICE",
  ["SPEECH SPEED WPM"] = "SPEED",
  ["SPEECH PITCH"] = "PITCH",
  ["TIME EXPANSION"] = "TIME",
  ["EXPANSION FACTOR"] = "EXPAND",
  ["ROOT SEMITONE"] = "ROOT",
  ["MELODY DEPTH"] = "MELODY",
  ["VOWEL SUSTAIN"] = "VOWEL",
  ["CHOIR VOICES"] = "CHOIR",
  ["SHADOW VOICE"] = "SHADOW",
  ["GHOST MIX"] = "GHOST",
  ["SPECTRAL SHAPER"] = "SHAPER",
  ["SHAPER PRESET"] = "PRESET",
  ["TONE LIST"] = "TONES",
  ["SHAPER STRENGTH"] = "STRENGTH",
  ["SHAPER BANDWIDTH"] = "WIDTH",
  ["SHAPER PARTIALS"] = "PARTIAL",
  ["SHAPER BRIGHTNESS"] = "BRIGHT",
  ["FOLLOW MELODY"] = "FOLLOW",
  ["CODEC DAMAGE"] = "CODEC",
  ["CODEC AMOUNT"] = "AMOUNT",
  ["CODEC QUALITY"] = "QUALITY",
  ["PACKET LOSS"] = "LOSS",
  ["RESIDUE INSTEAD OF DECODED SPEECH"] = "RESIDUE",
  ["PITCH HZ"] = "PITCH",
  ["PITCH SPREAD"] = "SPREAD",
  ["FORMANT SHIFT"] = "FORMANT",
  ["MOUTH SIZE"] = "MOUTH",
  ["FORMANT SMEAR"] = "SMEAR",
  ["AZIMUTH WIDTH"] = "AZ WIDTH",
  ["ELEVATION WIDTH"] = "EL WIDTH",
  ["SPATIAL MOTION"] = "MOTION",
  ["SPEAKER SPREAD"] = "SPREAD",
  ["PRE-GAIN DB"] = "GAIN",
  ["PEAK NORMALIZE"] = "PEAK",
  ["NORMALIZE DB"] = "NORM DB",
}

local function row_label_text(label)
  local upper = tostring(label or ""):upper()
  return LABEL_ABBR[upper] or upper
end

local function row_layout(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local avail = ImGui.GetContentRegionAvail(ctx)
  if type(avail) ~= "number" then avail = 560 end
  local control_x = x + LABEL_W
  local control_w = math.max(120, avail - LABEL_W - CONTROL_GAP)
  return x, y, control_x, control_w
end

local function row_label(ctx, x, y, label)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 4, THEME.label, row_label_text(label))
end

local function finish_row(ctx, x, y)
  ImGui.SetCursorScreenPos(ctx, x, y + ROW_H)
end

local function draw_custom_slider(ctx, label, value, lo, hi, fmt, integer)
  local x, y, control_x, control_w = row_layout(ctx)
  local slider_w = math.max(80, control_w - VALUE_W - CONTROL_GAP)
  local value_x = control_x + slider_w + CONTROL_GAP
  local track_y = y + 8
  local track_h = 8
  local norm = hi ~= lo and clamp((value - lo) / (hi - lo), 0, 1) or 0
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.InvisibleButton(ctx, "##" .. label, slider_w, ROW_H)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local changed = false
  if (hovered or active) and ImGui.IsMouseDown(ctx, 0) then
    local mx = ImGui.GetMousePos(ctx)
    local next_norm = clamp((mx - control_x) / slider_w, 0, 1)
    local next_value = lo + (hi - lo) * next_norm
    if integer then next_value = math.floor(next_value + 0.5) end
    if math.abs(next_value - value) > (integer and 0 or 0.0000001) then
      value = next_value
      norm = next_norm
      changed = true
    end
  end
  local draw = ImGui.GetWindowDrawList(ctx)
  local frame = active and THEME.frame_active or (hovered and THEME.frame_hover or THEME.frame)
  local fill = active and THEME.active or THEME.fill
  local handle = active and THEME.active_hover or THEME.active
  ImGui.DrawList_AddRectFilled(draw, control_x, track_y, control_x + slider_w, track_y + track_h, frame)
  ImGui.DrawList_AddRectFilled(draw, control_x + 1, track_y + 1, control_x + math.max(2, slider_w * norm), track_y + track_h - 1, fill)
  local hx = clamp(control_x + slider_w * norm - 1.5, control_x + 1, control_x + slider_w - 4)
  ImGui.DrawList_AddRectFilled(draw, hx, track_y - 2, hx + 3, track_y + track_h + 2, handle)
  ImGui.DrawList_AddText(draw, value_x, y + 4, THEME.value, integer and tostring(math.floor(value + 0.5)) or string.format(fmt or "%.3f", value))
  finish_row(ctx, x, y)
  return changed, value
end

local function draw_int_input(ctx, label, value)
  local x, y, control_x, control_w = row_layout(ctx)
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, control_w)
  local changed, next_value = ImGui.InputInt(ctx, "##" .. label, math.floor(value))
  finish_row(ctx, x, y)
  return changed, next_value
end

local function draw_text_input(ctx, label, value)
  local x, y, control_x, control_w = row_layout(ctx)
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, control_w)
  local changed, next_value = ImGui.InputText(ctx, "##" .. label, value or "")
  finish_row(ctx, x, y)
  return changed, next_value
end

local function draw_checkbox(ctx, label, value)
  local x, y, control_x = row_layout(ctx)
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y + 2)
  local changed, next_value = ImGui.Checkbox(ctx, "##" .. label, value)
  finish_row(ctx, x, y)
  return changed, next_value
end

local function section(ctx, label, height)
  local stack = theme.push_soft_panel(ImGui, ctx)
  local draw = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + height, THEME.panel_soft)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + 2, THEME.active)
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 10)
  theme.text(ImGui, ctx, label:upper())
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 36)
  return x, y, height, stack
end

local function finish_section(ctx, x, y, height, stack)
  theme.pop_soft_panel(ImGui, ctx, stack)
  ImGui.SetCursorScreenPos(ctx, x, y + height + 10)
end

local function combo(ctx, label, idx, names)
  local x, y, control_x, control_w = row_layout(ctx)
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, control_w)
  if ImGui.BeginCombo(ctx, "##" .. label, names[idx] or "") then
    for i, name in ipairs(names) do
      local selected = i == idx
      if ImGui.Selectable(ctx, name, selected) then idx = i end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  finish_row(ctx, x, y)
  return idx
end

local settings = {
  text = gets("text", "the hidden signal speaks through the field"),
  output = math.max(1, math.min(#OUTPUT_KEYS, math.floor(getn("output", 1)))),
  layout = math.max(1, math.min(#LAYOUT_KEYS, math.floor(getn("layout", 1)))),
  channels_index = math.max(1, math.min(#CHANNEL_VALUES, math.floor(getn("channels_index", 4)))),
  treatment = math.max(1, math.min(#TREATMENT_KEYS, math.floor(getn("treatment", 1)))),
  scale = math.max(1, math.min(#SCALE_KEYS, math.floor(getn("scale", 1)))),
  shaper = math.max(1, math.min(#SHAPER_KEYS, math.floor(getn("shaper", 1)))),
  shaper_preset = math.max(1, math.min(#SHAPER_PRESET_KEYS, math.floor(getn("shaper_preset", 1)))),
  time_mode = math.max(1, math.min(#TIME_KEYS, math.floor(getn("time_mode", 1)))),
  duration = getn("duration", 12.0),
  time_expand = getn("time_expand", 2.5),
  density = getn("density", 3.6),
  syllable_ms = getn("syllable_ms", 180.0),
  timing_jitter = getn("timing_jitter", 0.35),
  pitch_hz = getn("pitch_hz", 95.0),
  pitch_spread = getn("pitch_spread", 0.38),
  formant_shift = getn("formant_shift", 0.0),
  mouth_size = getn("mouth_size", 0.55),
  breath = getn("breath", 0.35),
  noise = getn("noise", 0.28),
  intelligibility = getn("intelligibility", 0.35),
  consonants = getn("consonants", 0.45),
  smear = getn("smear", 0.18),
  whisper = getn("whisper", 0.25),
  az_width = getn("az_width", 180.0),
  el_width = getn("el_width", 55.0),
  spatial_motion = getn("spatial_motion", 0.65),
  spatial_width = getn("spatial_width", 0.22),
  distance = getn("distance", 1.0),
  drive = getn("drive", 0.12),
  tts_voice = gets("tts_voice", "en-us"),
  tts_speed = getn("tts_speed", 150),
  tts_pitch = getn("tts_pitch", 45),
  root_note = math.floor(getn("root_note", 0)),
  melody_depth = getn("melody_depth", 0.55),
  vowel_sustain = getn("vowel_sustain", 0.25),
  choir_voices = math.floor(getn("choir_voices", 4)),
  shadow_voice = getn("shadow_voice", 0.45),
  ghost_mix = getn("ghost_mix", 0.35),
  tone_list = gets("tone_list", "C3 Eb3 G3 Bb3"),
  shaper_strength = getn("shaper_strength", 0.45),
  shaper_bandwidth = getn("shaper_bandwidth", 0.18),
  shaper_partials = math.floor(getn("shaper_partials", 6)),
  shaper_brightness = getn("shaper_brightness", 0.0),
  shaper_follow_melody = getb("shaper_follow_melody", true),
  codec_damage = math.max(1, math.min(#CODEC_KEYS, math.floor(getn("codec_damage", 1)))),
  codec_amount = getn("codec_amount", 0.65),
  codec_quality = math.floor(getn("codec_quality", 3)),
  codec_packet_loss = getn("codec_packet_loss", 0.0),
  codec_residue = getb("codec_residue", false),
  gain_db = getn("gain_db", -12.0),
  normalize = getb("normalize", true),
  normalize_db = getn("normalize_db", -9.0),
  seed = math.floor(getn("seed", 1)),
}

local function output_channels()
  if OUTPUT_KEYS[settings.output] == "3oa" then return 16 end
  return CHANNEL_VALUES[settings.channels_index] or 8
end

local function draw_diagram(ctx)
  local w = math.max(420, ImGui.GetContentRegionAvail(ctx) - 2)
  local h = 148
  ImGui.InvisibleButton(ctx, "##evp_diagram", w, h)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = ImGui.GetItemRectMax(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local c_bg = rgba(0.035, 0.038, 0.040, 1)
  local c_grid = rgba(0.55, 0.60, 0.58, 0.12)
  local c_text = rgba(0.76, 0.79, 0.76, 1)
  local c_dim = rgba(0.54, 0.58, 0.56, 1)
  local c_a = rgba(0.98, 0.74, 0.25, 1)
  local c_b = rgba(0.34, 0.72, 0.86, 1)
  local c_c = rgba(0.80, 0.62, 0.95, 1)
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x1, y1, c_bg)
  ImGui.DrawList_AddRect(dl, x0, y0, x1, y1, rgba(0.45, 0.50, 0.48, 0.38), 0, 0, 1)
  local left = x0 + 22
  local mid = x0 + w * 0.43
  local right = x0 + w * 0.78
  local cy = y0 + h * 0.56
  ImGui.DrawList_AddText(dl, left, y0 + 10, c_text, "text / phoneme seed")
  ImGui.DrawList_AddText(dl, mid - 42, y0 + 10, c_text, "formant voices")
  ImGui.DrawList_AddText(dl, right - 46, y0 + 10, c_text, OUTPUT_LABELS[settings.output])
  for i = 1, math.min(18, #settings.text) do
    local yy = y0 + 36 + ((i - 1) % 6) * 12
    local xx = left + math.floor((i - 1) / 6) * 22
    ImGui.DrawList_AddText(dl, xx, yy, (i % 3 == 0) and c_b or c_dim, settings.text:sub(i, i))
  end
  for i = 1, 5 do
    local yy = y0 + 40 + i * 13
    ImGui.DrawList_AddLine(dl, mid - 60, yy, mid + 55, yy + math.sin(i + settings.mouth_size) * 8, (i % 2 == 0) and c_a or c_b, 1.6)
    ImGui.DrawList_AddCircleFilled(dl, mid - 64, yy, 2.7 + settings.breath * 2.5, c_a)
  end
  ImGui.DrawList_AddLine(dl, left + 98, cy - 20, mid - 74, cy - 4, c_grid, 1)
  ImGui.DrawList_AddLine(dl, mid + 68, cy, right - 62, cy, c_grid, 1)
  if OUTPUT_KEYS[settings.output] == "3oa" then
    for i = 1, 3 do ImGui.DrawList_AddCircle(dl, right, cy, 17 + i * 14, c_grid, 0, 1) end
    ImGui.DrawList_AddText(dl, right - 15, cy - 7, c_c, "3OA")
  else
    local n = math.min(32, output_channels())
    for i = 1, n do
      local a = -math.pi / 4 - (i - 1) * 2 * math.pi / n
      local rr = 46
      ImGui.DrawList_AddCircleFilled(dl, right + math.cos(a) * rr, cy - math.sin(a) * rr, 2.5, c_c)
    end
  end
  local a0 = math.rad(-settings.az_width * 0.5)
  local a1 = math.rad(settings.az_width * 0.5)
  ImGui.DrawList_AddLine(dl, right, cy, right + math.cos(a0) * 55, cy - math.sin(a0) * 55, c_a, 1.8)
  ImGui.DrawList_AddLine(dl, right, cy, right + math.cos(a1) * 55, cy - math.sin(a1) * 55, c_b, 1.8)
  ImGui.DrawList_AddText(dl, left, y1 - 23, c_dim, "letters seed speech-like formants; events move through the selected spatial output")
end

local ctx = ImGui.CreateContext(TITLE)
local open, should_render = true, false
local function persist() for k, v in pairs(settings) do set(k, v) end end
local env_points, env_enabled = be.init(ENV_DEFS, settings)
be.load_extstate(EXT, ENV_DEFS, env_points, env_enabled)
local selected_env = 1
local selected_env_point = nil
local env_opts = { height = 150, overview_lane_h = 50, random_amount = 0.35, random_count = 10, random_dispersion = 0.25, random_smooth = true, collapse_editor = true, compact_window_h = 760, expanded_window_h = 760 }

local function render()
  local channels = output_channels()
  local profile_path = ""
  if SHAPER_KEYS[settings.shaper] == "profile_item" then
    local entries = nr.selected_entries()
    if #entries < 1 or entries[1].filename == "" then
      mc.show_error("Select one WAV media item to use as the EVP spectral profile.")
      return
    end
    profile_path = entries[1].filename
  end
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_evp_field_renders", nil, script_dir)
  local output_path = out_dir .. "/s3g_evp_field_" .. stamp .. "_" .. tostring(channels) .. "ch.wav"
  local manifest = {
    output_path = output_path,
    sample_rate = 48000,
    text = settings.text,
    output_mode = OUTPUT_KEYS[settings.output],
    layout = LAYOUT_KEYS[settings.layout],
    channels = channels,
    voice_mode = "tts_espeak",
    treatment = TREATMENT_KEYS[settings.treatment],
    scale = SCALE_KEYS[settings.scale],
    time_mode = TIME_KEYS[settings.time_mode],
    time_expand = settings.time_expand,
    spectral_shaper = SHAPER_KEYS[settings.shaper],
    shaper_preset = SHAPER_PRESET_KEYS[settings.shaper_preset],
    tone_list = settings.tone_list,
    profile_path = profile_path,
    duration = settings.duration,
    density = settings.density,
    syllable_ms = settings.syllable_ms,
    timing_jitter = settings.timing_jitter,
    pitch_hz = settings.pitch_hz,
    pitch_spread = settings.pitch_spread,
    formant_shift = settings.formant_shift,
    mouth_size = settings.mouth_size,
    breath = settings.breath,
    noise = settings.noise,
    intelligibility = settings.intelligibility,
    consonants = settings.consonants,
    smear = settings.smear,
    whisper = settings.whisper,
    az_width = settings.az_width,
    el_width = settings.el_width,
    spatial_motion = settings.spatial_motion,
    spatial_width = settings.spatial_width,
    distance = settings.distance,
    drive = settings.drive,
    tts_voice = settings.tts_voice,
    tts_speed = settings.tts_speed,
    tts_pitch = settings.tts_pitch,
    root_note = settings.root_note,
    melody_depth = settings.melody_depth,
    vowel_sustain = settings.vowel_sustain,
    choir_voices = settings.choir_voices,
    shadow_voice = settings.shadow_voice,
    ghost_mix = settings.ghost_mix,
    shaper_strength = settings.shaper_strength,
    shaper_bandwidth = settings.shaper_bandwidth,
    shaper_partials = settings.shaper_partials,
    shaper_brightness = settings.shaper_brightness,
    shaper_follow_melody = settings.shaper_follow_melody,
    codec_damage = CODEC_KEYS[settings.codec_damage],
    codec_amount = settings.codec_amount,
    codec_quality = settings.codec_quality,
    codec_packet_loss = settings.codec_packet_loss,
    codec_residue = settings.codec_residue,
    gain_db = settings.gain_db,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    seed = settings.seed,
  }
  be.add_to_manifest(manifest, ENV_DEFS, env_points, env_enabled)
  local log, elapsed = nr.run_backend(script_dir, "evp_field", manifest, TITLE)
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path, "EVP Field (" .. tostring(channels) .. "ch)", reaper.GetCursorPosition(), channels, { master_send = false, track_gain = 0.5 })
  reaper.Undo_EndBlock(TITLE, -1)
  if not item then mc.show_error(err or "Could not insert rendered item.") return end
  mc.print_plan(TITLE, { "Treatment: " .. TREATMENT_LABELS[settings.treatment], "Output: " .. output_path, "Master send: off", string.format("NumPy time: %.2f sec", elapsed), log })
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 760, env_opts._editor_was_open and env_opts.expanded_window_h or env_opts.compact_window_h, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    draw_diagram(ctx)
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    local control_h = math.max(460, (avail_h or 860) - 44)
    if ImGui.BeginChild(ctx, "##evp_controls", 0, control_h) then
      local changed
      local sx, sy, sh, stack = section(ctx, "Text / Output", OUTPUT_KEYS[settings.output] ~= "3oa" and 252 or 200)
      changed, settings.text = ImGui.InputTextMultiline(ctx, "##Text seed", settings.text, math.max(360, ImGui.GetContentRegionAvail(ctx)), 76)
      ImGui.SetCursorScreenPos(ctx, sx + 12, select(2, ImGui.GetCursorScreenPos(ctx)))
      settings.output = combo(ctx, "Output", settings.output, OUTPUT_LABELS)
      if OUTPUT_KEYS[settings.output] ~= "3oa" then
        settings.layout = combo(ctx, "Shape", settings.layout, LAYOUT_LABELS)
        settings.channels_index = combo(ctx, "Channels", settings.channels_index, CHANNEL_LABELS)
      else
        theme.muted(ImGui, ctx, "Output channels: 16")
      end
      finish_section(ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = section(ctx, "Speech", TIME_KEYS[settings.time_mode] == "manual_expand" and 252 or 226)
      settings.treatment = combo(ctx, "Voice treatment", settings.treatment, TREATMENT_LABELS)
      changed, settings.tts_voice = draw_text_input(ctx, "eSpeak voice", settings.tts_voice)
      changed, settings.tts_speed = draw_custom_slider(ctx, "Speech speed wpm", settings.tts_speed, 80.0, 280.0, "%.0f", false)
      changed, settings.tts_pitch = draw_custom_slider(ctx, "Speech pitch", settings.tts_pitch, 0.0, 99.0, "%.0f", false)
      changed, settings.duration = draw_custom_slider(ctx, "Duration sec", settings.duration, 0.5, 300.0, "%.2f", false)
      settings.time_mode = combo(ctx, "Time expansion", settings.time_mode, TIME_LABELS)
      if TIME_KEYS[settings.time_mode] == "manual_expand" then
        changed, settings.time_expand = draw_custom_slider(ctx, "Expansion factor", settings.time_expand, 1.0, 12.0, "%.2f", false)
      elseif TIME_KEYS[settings.time_mode] == "fill_duration" then
        theme.muted(ImGui, ctx, "Stretches speech to fill the requested duration.")
      else
        theme.muted(ImGui, ctx, "Uses the natural eSpeak phrase length.")
      end
      finish_section(ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = section(ctx, "Melody / Choir", 226)
      settings.scale = combo(ctx, "Scale", settings.scale, SCALE_LABELS)
      changed, settings.root_note = draw_custom_slider(ctx, "Root semitone", settings.root_note, -12, 12, nil, true)
      changed, settings.melody_depth = draw_custom_slider(ctx, "Melody depth", settings.melody_depth, 0.0, 1.0, "%.2f", false)
      changed, settings.vowel_sustain = draw_custom_slider(ctx, "Vowel sustain", settings.vowel_sustain, 0.0, 1.0, "%.2f", false)
      changed, settings.choir_voices = draw_custom_slider(ctx, "Choir voices", settings.choir_voices, 1, 8, nil, true)
      changed, settings.shadow_voice = draw_custom_slider(ctx, "Shadow voice", settings.shadow_voice, 0.0, 1.0, "%.2f", false)
      changed, settings.ghost_mix = draw_custom_slider(ctx, "Ghost mix", settings.ghost_mix, 0.0, 1.0, "%.2f", false)
      finish_section(ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = section(ctx, "Spectral Shaper", SHAPER_KEYS[settings.shaper] == "off" and 70 or (SHAPER_KEYS[settings.shaper] == "tone_list" and 252 or 226))
      settings.shaper = combo(ctx, "Spectral shaper", settings.shaper, SHAPER_LABELS)
      if SHAPER_KEYS[settings.shaper] == "preset" then
        settings.shaper_preset = combo(ctx, "Shaper preset", settings.shaper_preset, SHAPER_PRESET_LABELS)
      elseif SHAPER_KEYS[settings.shaper] == "tone_list" then
        changed, settings.tone_list = draw_text_input(ctx, "Tone list", settings.tone_list)
        theme.muted(ImGui, ctx, "Use MIDI, note names, or Hz.")
      elseif SHAPER_KEYS[settings.shaper] == "profile_item" then
        theme.muted(ImGui, ctx, "Uses the first selected WAV item as spectral imprint.")
      end
      if SHAPER_KEYS[settings.shaper] ~= "off" then
        changed, settings.shaper_strength = draw_custom_slider(ctx, "Shaper strength", settings.shaper_strength, 0.0, 1.0, "%.2f", false)
        changed, settings.shaper_bandwidth = draw_custom_slider(ctx, "Shaper bandwidth", settings.shaper_bandwidth, 0.03, 0.80, "%.2f", false)
        changed, settings.shaper_partials = draw_custom_slider(ctx, "Shaper partials", settings.shaper_partials, 1, 16, nil, true)
        changed, settings.shaper_brightness = draw_custom_slider(ctx, "Shaper brightness", settings.shaper_brightness, -1.0, 1.0, "%.2f", false)
        changed, settings.shaper_follow_melody = draw_checkbox(ctx, "Follow melody", settings.shaper_follow_melody)
      end
      finish_section(ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = section(ctx, "Codec", CODEC_KEYS[settings.codec_damage] ~= "off" and 174 or 70)
      settings.codec_damage = combo(ctx, "Codec damage", settings.codec_damage, CODEC_LABELS)
      if CODEC_KEYS[settings.codec_damage] ~= "off" then
        changed, settings.codec_amount = draw_custom_slider(ctx, "Codec amount", settings.codec_amount, 0.0, 1.0, "%.2f", false)
        changed, settings.codec_quality = draw_custom_slider(ctx, "Codec quality", settings.codec_quality, 0, 10, nil, true)
        changed, settings.codec_packet_loss = draw_custom_slider(ctx, "Packet loss", settings.codec_packet_loss, 0.0, 0.45, "%.2f", false)
        changed, settings.codec_residue = draw_checkbox(ctx, "Residue instead of decoded speech", settings.codec_residue)
      end
      finish_section(ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = section(ctx, "Voice", 252)
      changed, settings.pitch_hz = draw_custom_slider(ctx, "Pitch Hz", settings.pitch_hz, 35.0, 420.0, "%.1f", false)
      changed, settings.pitch_spread = draw_custom_slider(ctx, "Pitch spread", settings.pitch_spread, 0.0, 2.0, "%.2f", false)
      changed, settings.formant_shift = draw_custom_slider(ctx, "Formant shift", settings.formant_shift, -1.0, 1.0, "%.2f", false)
      changed, settings.mouth_size = draw_custom_slider(ctx, "Mouth size", settings.mouth_size, 0.0, 1.0, "%.2f", false)
      changed, settings.breath = draw_custom_slider(ctx, "Breath", settings.breath, 0.0, 1.0, "%.2f", false)
      changed, settings.noise = draw_custom_slider(ctx, "Noise", settings.noise, 0.0, 1.0, "%.2f", false)
      changed, settings.whisper = draw_custom_slider(ctx, "Whisper", settings.whisper, 0.0, 1.0, "%.2f", false)
      changed, settings.smear = draw_custom_slider(ctx, "Formant smear", settings.smear, 0.0, 1.0, "%.2f", false)
      finish_section(ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = section(ctx, "Spatial / Output", settings.normalize and 252 or 226)
      changed, settings.az_width = draw_custom_slider(ctx, "Azimuth width", settings.az_width, 0.0, 360.0, "%.1f", false)
      changed, settings.el_width = draw_custom_slider(ctx, "Elevation width", settings.el_width, 0.0, 178.0, "%.1f", false)
      changed, settings.spatial_motion = draw_custom_slider(ctx, "Spatial motion", settings.spatial_motion, 0.0, 1.0, "%.2f", false)
      changed, settings.spatial_width = draw_custom_slider(ctx, "Speaker spread", settings.spatial_width, 0.02, 1.0, "%.2f", false)
      changed, settings.distance = draw_custom_slider(ctx, "Distance", settings.distance, 0.2, 4.0, "%.2f", false)
      changed, settings.drive = draw_custom_slider(ctx, "Drive", settings.drive, 0.0, 1.0, "%.2f", false)
      changed, settings.gain_db = draw_custom_slider(ctx, "Pre-gain dB", settings.gain_db, -36.0, 0.0, "%.1f", false)
      changed, settings.normalize = draw_checkbox(ctx, "Peak normalize", settings.normalize)
      if settings.normalize then changed, settings.normalize_db = draw_custom_slider(ctx, "Normalize dB", settings.normalize_db, -24.0, 0.0, "%.1f", false) end
      changed, settings.seed = draw_int_input(ctx, "Seed", settings.seed)
      finish_section(ctx, sx, sy, sh, stack)
      selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env, selected_env_point, settings, env_opts)
      ImGui.EndChild(ctx)
    end
    if ImGui.Button(ctx, "RENDER", 96, 28) then should_render = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "CANCEL", 96, 28) then open = false end
    ImGui.End(ctx)
  end
  persist()
  if should_render then
    open = false
    be.save_extstate(EXT, ENV_DEFS, env_points, env_enabled)
    render()
    return
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
