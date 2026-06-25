-- @description Spectral Shaper
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spectral / Convolution
-- @render Yes; writes a new spectrally-shaped media item.
-- @method Offline spectral envelope transfer with an alternate formant-vocode algorithm. Select two WAV-backed media items: carrier first, shaper second. The carrier keeps timing and phase while the shaper supplies either the spectral envelope or broad formant contour.
-- @about
--   Uses NumPy STFT/ISTFT to apply the shaper item's spectral envelope to the
--   carrier item. The result is inserted on a new track and REAPER is asked to
--   build peaks immediately.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Spectral Shaper", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local FFT_NAMES = {
  [1] = "1024",
  [2] = "2048",
  [3] = "4096",
  [4] = "8192",
}

local FFT_VALUES = {
  [1] = 1024,
  [2] = 2048,
  [3] = 4096,
  [4] = 8192,
}

local ALGORITHM_NAMES = {
  [1] = "Envelope transfer",
  [2] = "Formant vocode",
}

local ALGORITHM_VALUES = {
  [1] = "shapee",
  [2] = "formant_vocode",
}
local DEFAULT_INSERT_GAIN = 0.5

local function shell_quote(path)
  return "'" .. tostring(path):gsub("'", "'\\''") .. "'"
end

local function dirname(path)
  return tostring(path or ""):match("^(.*)[/\\][^/\\]+$") or ""
end

local function trim(text)
  return (text or ""):match("^%s*(.-)%s*$")
end

local function file_exists(path)
  local file = io.open(path, "rb")
  if file then file:close() return true end
  return false
end

local function media_source_filename(source)
  if not source then return "" end
  local ok, a, b = pcall(reaper.GetMediaSourceFileName, source, "", 4096)
  if ok then
    if type(b) == "string" and b ~= "" then return b end
    if type(a) == "string" and a ~= "" then return a end
  end
  ok, a, b = pcall(reaper.GetMediaSourceFileName, source, "")
  if ok then
    if type(b) == "string" and b ~= "" then return b end
    if type(a) == "string" and a ~= "" then return a end
  end
  local parent = reaper.GetMediaSourceParent and reaper.GetMediaSourceParent(source)
  if parent and parent ~= source then return media_source_filename(parent) end
  return ""
end

local function read_file(path)
  local file = io.open(path, "rb")
  if not file then return "" end
  local text = file:read("*a") or ""
  file:close()
  return text
end

local function find_python()
  local configured_path = script_dir .. "python3_path.txt"
  if file_exists(configured_path) then
    local file = io.open(configured_path, "rb")
    local configured = file and trim(file:read("*a") or "") or ""
    if file then file:close() end
    if configured ~= "" and file_exists(configured) then return configured end
  end

  local home = os.getenv("HOME") or ""
  local candidates = { "/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3" }
  if home ~= "" then
    table.insert(candidates, 1, home .. "/miniconda3/bin/python3")
    table.insert(candidates, 2, home .. "/miniforge3/bin/python3")
    table.insert(candidates, 3, home .. "/anaconda3/bin/python3")
  end
  for _, path in ipairs(candidates) do
    if file_exists(path) then return path end
  end
  local handle = io.popen("command -v python3 2>/dev/null")
  if handle then
    local path = trim(handle:read("*a"))
    handle:close()
    if path ~= "" and file_exists(path) then return path end
  end
  return nil
end

local function run_command(command, log_path)
  if log_path then command = command .. " > " .. shell_quote(log_path) .. " 2>&1" end
  local result = os.execute(command)
  return result == true or result == 0
end

local function json_string(value)
  local text = tostring(value or "")
  text = text:gsub("\\", "\\\\")
  text = text:gsub("\"", "\\\"")
  text = text:gsub("\n", "\\n")
  text = text:gsub("\r", "\\r")
  text = text:gsub("\t", "\\t")
  return "\"" .. text .. "\""
end

local function selected_entries()
  local entries = {}
  for index = 0, reaper.CountSelectedMediaItems(mc.PROJECT) - 1 do
    local item = reaper.GetSelectedMediaItem(mc.PROJECT, index)
    local take = item and reaper.GetActiveTake(item)
    local source = take and reaper.GetMediaItemTake_Source(take)
    local channels = take and mc.get_take_source_channels(take)
    local filename = media_source_filename(source)
    if item and take and source and channels and channels > 0 then
      entries[#entries + 1] = {
        item = item,
        take = take,
        source = source,
        filename = filename,
        channels = channels,
        position = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
        length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
        start_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS"),
        playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE"),
        name = mc.item_label(item),
      }
    end
  end
  table.sort(entries, function(a, b) return a.position < b.position end)
  return entries
end

local function source_sample_rate(entry)
  local sr = reaper.GetMediaSourceSampleRate(entry.source)
  if not sr or sr <= 0 then return 48000 end
  return math.floor(sr + 0.5)
end

local function draw_combo(ctx, label, value, names, first_index, last_index)
  local changed = false
  if ImGui.BeginCombo(ctx, label, names[value] or "") then
    for index = first_index, last_index do
      local selected = value == index
      if ImGui.Selectable(ctx, names[index], selected) then
        value = index
        changed = true
      end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return changed, value
end

local function write_helper(path)
  local file = io.open(path, "w")
  if not file then return false end
  file:write([[
import json
import math
import struct
import sys
import numpy as np

def riff_chunks(handle):
    handle.seek(12)
    while True:
        header = handle.read(8)
        if len(header) < 8:
            break
        chunk_id, size = struct.unpack("<4sI", header)
        data_pos = handle.tell()
        yield chunk_id, size, data_pos
        handle.seek(data_pos + size + (size & 1))

def read_wav(path):
    with open(path, "rb") as handle:
        if handle.read(4) != b"RIFF":
            raise RuntimeError(f"Not a RIFF WAV file: {path}")
        handle.read(4)
        if handle.read(4) != b"WAVE":
            raise RuntimeError(f"Not a WAVE file: {path}")
        fmt = None
        data_pos = None
        data_size = None
        for chunk_id, size, pos in riff_chunks(handle):
            if chunk_id == b"fmt ":
                handle.seek(pos)
                fmt = handle.read(size)
            elif chunk_id == b"data":
                data_pos = pos
                data_size = size
        if fmt is None or data_pos is None:
            raise RuntimeError(f"WAV is missing fmt or data chunk: {path}")
        audio_format, channels, sample_rate, _byte_rate, block_align, bits = struct.unpack("<HHIIHH", fmt[:16])
        if audio_format == 0xFFFE and len(fmt) >= 40:
            audio_format = struct.unpack("<H", fmt[24:26])[0]
        handle.seek(data_pos)
        raw = handle.read(data_size)
        frames = len(raw) // block_align
        raw = raw[:frames * block_align]

    if audio_format == 3 and bits == 32:
        data = np.frombuffer(raw, dtype="<f4").astype(np.float32)
    elif audio_format == 1 and bits == 16:
        data = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    elif audio_format == 1 and bits == 24:
        u8 = np.frombuffer(raw, dtype=np.uint8).reshape(frames * channels, 3).astype(np.int32)
        vals = u8[:, 0] | (u8[:, 1] << 8) | (u8[:, 2] << 16)
        vals = np.where(vals & 0x800000, vals - 0x1000000, vals)
        data = vals.astype(np.float32) / 8388608.0
    elif audio_format == 1 and bits == 32:
        data = np.frombuffer(raw, dtype="<i4").astype(np.float32) / 2147483648.0
    else:
        raise RuntimeError(f"Unsupported WAV encoding {audio_format}, {bits} bit: {path}")
    return data.reshape(frames, channels), int(sample_rate)

def write_pcm24_wav(path, data, sample_rate):
    channels = int(data.shape[1])
    clipped = np.clip(data, -1.0, 1.0)
    ints = np.rint(clipped * 8388607.0).astype("<i4", copy=False)
    payload = bytearray(ints.shape[0] * ints.shape[1] * 3)
    cursor = 0
    for value in ints.reshape(-1):
        as_int = int(value)
        if as_int < 0:
            as_int += 1 << 24
        payload[cursor] = as_int & 0xFF
        payload[cursor + 1] = (as_int >> 8) & 0xFF
        payload[cursor + 2] = (as_int >> 16) & 0xFF
        cursor += 3
    if channels > 2:
        pcm_guid = bytes.fromhex("0100000000001000800000aa00389b71")
        fmt = struct.pack("<HHIIHHHHI", 0xFFFE, channels, int(sample_rate),
                          int(sample_rate) * channels * 3, channels * 3,
                          24, 22, 24, 0) + pcm_guid
    else:
        fmt = struct.pack("<HHIIHH", 1, channels, int(sample_rate),
                          int(sample_rate) * channels * 3, channels * 3, 24)
    payload = bytes(payload)
    riff_size = 4 + (8 + len(fmt)) + (8 + len(payload))
    with open(path, "wb") as handle:
        handle.write(b"RIFF")
        handle.write(struct.pack("<I", riff_size))
        handle.write(b"WAVE")
        handle.write(b"fmt ")
        handle.write(struct.pack("<I", len(fmt)))
        handle.write(fmt)
        handle.write(b"data")
        handle.write(struct.pack("<I", len(payload)))
        handle.write(payload)

def segment(data, source_rate, start_seconds, duration_seconds, target_rate):
    start = max(0, int(round(float(start_seconds) * source_rate)))
    count = max(1, int(round(float(duration_seconds) * source_rate)))
    out = data[start:start + count]
    if source_rate != target_rate and out.shape[0] > 1:
        old_x = np.arange(out.shape[0], dtype=np.float64)
        new_size = max(1, int(round(out.shape[0] * target_rate / source_rate)))
        new_x = np.linspace(0, out.shape[0] - 1, new_size, dtype=np.float64)
        channels = [np.interp(new_x, old_x, out[:, ch]).astype(np.float32) for ch in range(out.shape[1])]
        out = np.stack(channels, axis=1)
    return out.astype(np.float32)

def resample_1d(audio, target_size):
    if audio.size == target_size:
        return audio.astype(np.float32)
    if audio.size <= 1:
        return np.zeros(target_size, dtype=np.float32)
    old_x = np.arange(audio.size, dtype=np.float64)
    new_x = np.linspace(0, audio.size - 1, target_size, dtype=np.float64)
    return np.interp(new_x, old_x, audio).astype(np.float32)

def smooth_bins(values, bins):
    bins = max(1, int(bins))
    if bins <= 1:
        return values
    kernel = np.ones(bins, dtype=np.float64) / bins
    return np.convolve(values, kernel, mode="same")

def shape_transfer_channel(carrier, shaper, sample_rate, cfg):
    fft_size = int(cfg["fft_size"])
    overlap = int(cfg["overlap"])
    hop = max(1, fft_size // overlap)
    window = np.hanning(fft_size).astype(np.float32)
    if carrier.size == 0:
        return carrier, 0
    shaper = resample_1d(shaper, carrier.size)
    pad = fft_size
    carrier_padded = np.pad(carrier.astype(np.float32), (0, pad))
    shaper_padded = np.pad(shaper.astype(np.float32), (0, pad))
    out = np.zeros(carrier_padded.size + fft_size, dtype=np.float64)
    norm = np.zeros_like(out)
    amount = np.clip(float(cfg["amount"]), 0.0, 1.0)
    mix = np.clip(float(cfg["mix"]), 0.0, 1.0)
    contrast = max(0.05, float(cfg["contrast"]))
    floor = max(0.001, float(cfg["floor"]))
    smooth = int(cfg["smooth_bins"])
    frame_count = 0
    for start in range(0, carrier_padded.size - fft_size + 1, hop):
        carrier_frame = carrier_padded[start:start + fft_size] * window
        shaper_frame = shaper_padded[start:start + fft_size] * window
        carrier_spec = np.fft.rfft(carrier_frame)
        shaper_spec = np.fft.rfft(shaper_frame)
        shaper_mag = smooth_bins(np.abs(shaper_spec), smooth)
        mean = float(np.mean(shaper_mag)) if shaper_mag.size else 0.0
        if mean <= 1e-12:
            envelope = np.ones_like(shaper_mag)
        else:
            envelope = shaper_mag / mean
        envelope = np.power(np.maximum(envelope, floor), contrast)
        envelope = np.clip(envelope, floor, 12.0)
        shaped_spec = carrier_spec * ((1.0 - amount) + amount * envelope)
        wet = np.fft.irfft(shaped_spec, fft_size)
        out[start:start + fft_size] += wet * window
        norm[start:start + fft_size] += window * window
        frame_count += 1
    nz = norm > 1e-9
    out[nz] /= norm[nz]
    out = out[:carrier.size].astype(np.float32)
    return (carrier * (1.0 - mix) + out * mix).astype(np.float32), frame_count

def formant_vocode_channel(carrier, shaper, sample_rate, cfg):
    fft_size = int(cfg["fft_size"])
    overlap = int(cfg["overlap"])
    hop = max(1, fft_size // overlap)
    window = np.hanning(fft_size).astype(np.float32)
    if carrier.size == 0:
        return carrier, 0
    shaper = resample_1d(shaper, carrier.size)
    pad = fft_size
    carrier_padded = np.pad(carrier.astype(np.float32), (0, pad))
    shaper_padded = np.pad(shaper.astype(np.float32), (0, pad))
    out = np.zeros(carrier_padded.size + fft_size, dtype=np.float64)
    norm = np.zeros_like(out)
    amount = np.clip(float(cfg["amount"]), 0.0, 1.0)
    mix = np.clip(float(cfg["mix"]), 0.0, 1.0)
    contrast = max(0.05, float(cfg["contrast"]))
    floor = max(0.001, float(cfg["floor"]))
    smooth = max(3, int(cfg["smooth_bins"]))
    if smooth % 2 == 0:
        smooth += 1
    frame_count = 0
    for start in range(0, carrier_padded.size - fft_size + 1, hop):
        carrier_frame = carrier_padded[start:start + fft_size] * window
        shaper_frame = shaper_padded[start:start + fft_size] * window
        carrier_spec = np.fft.rfft(carrier_frame)
        shaper_spec = np.fft.rfft(shaper_frame)
        carrier_mag = np.abs(carrier_spec)
        shaper_mag = np.abs(shaper_spec)
        carrier_env = smooth_bins(carrier_mag, smooth)
        shaper_env = smooth_bins(shaper_mag, smooth)
        c_mean = float(np.mean(carrier_mag)) if carrier_mag.size else 0.0
        ce_mean = float(np.mean(carrier_env)) if carrier_env.size else 0.0
        se_mean = float(np.mean(shaper_env)) if shaper_env.size else 0.0
        if c_mean <= 1e-12 or ce_mean <= 1e-12 or se_mean <= 1e-12:
            target_mag = carrier_mag
        else:
            residual = carrier_mag / np.maximum(carrier_env, floor * ce_mean)
            envelope = shaper_env * (c_mean / se_mean)
            envelope = np.power(np.maximum(envelope, floor * c_mean), contrast)
            e_mean = float(np.mean(envelope)) if envelope.size else 0.0
            if e_mean > 1e-12:
                envelope *= c_mean / e_mean
            target_mag = residual * envelope
            t_mean = float(np.mean(target_mag)) if target_mag.size else 0.0
            if t_mean > 1e-12:
                target_mag *= c_mean / t_mean
        shaped_spec = (carrier_mag * (1.0 - amount) + target_mag * amount) * np.exp(1j * np.angle(carrier_spec))
        wet = np.fft.irfft(shaped_spec, fft_size)
        out[start:start + fft_size] += wet * window
        norm[start:start + fft_size] += window * window
        frame_count += 1
    nz = norm > 1e-9
    out[nz] /= norm[nz]
    out = out[:carrier.size].astype(np.float32)
    return (carrier * (1.0 - mix) + out * mix).astype(np.float32), frame_count

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    cfg = json.load(handle)

carrier_data, carrier_rate = read_wav(cfg["carrier_path"])
shaper_data, shaper_rate = read_wav(cfg["shaper_path"])
carrier_audio = segment(carrier_data, carrier_rate, cfg["carrier_start_offset"], cfg["carrier_duration"], int(cfg["sample_rate"]))
shaper_audio = segment(shaper_data, shaper_rate, cfg["shaper_start_offset"], cfg["shaper_duration"], int(cfg["sample_rate"]))
if not np.all(np.isfinite(carrier_audio)):
    raise RuntimeError("Carrier contains non-finite samples.")
if not np.all(np.isfinite(shaper_audio)):
    raise RuntimeError("Shaper contains non-finite samples.")

channels = []
total_frames = 0
for ch in range(carrier_audio.shape[1]):
    shaper_ch = ch % shaper_audio.shape[1]
    if cfg.get("algorithm", "shapee") == "formant_vocode":
        shaped, frames = formant_vocode_channel(carrier_audio[:, ch], shaper_audio[:, shaper_ch], int(cfg["sample_rate"]), cfg)
    else:
        shaped, frames = shape_transfer_channel(carrier_audio[:, ch], shaper_audio[:, shaper_ch], int(cfg["sample_rate"]), cfg)
    channels.append(shaped)
    total_frames += frames

result = np.stack(channels, axis=1)
if cfg.get("normalize", False):
    peak = float(np.max(np.abs(result))) if result.size else 0.0
    if peak > 0.0:
        result *= (10 ** (float(cfg.get("normalize_db", -6.0)) / 20.0)) / peak
peak = float(np.max(np.abs(result))) if result.size else 0.0
print("Carrier peak:", float(np.max(np.abs(carrier_audio))) if carrier_audio.size else 0.0)
print("Shaper peak:", float(np.max(np.abs(shaper_audio))) if shaper_audio.size else 0.0)
print("Algorithm:", cfg.get("algorithm", "shapee"))
print("Output peak:", peak)
print("STFT frames:", total_frames)
write_pcm24_wav(cfg["output_path"], result, int(cfg["sample_rate"]))
]])
  file:close()
  return true
end

local function write_manifest(path, data)
  local file = io.open(path, "w")
  if not file then return false end
  file:write("{\n")
  file:write("  \"carrier_path\": " .. json_string(data.carrier_path) .. ",\n")
  file:write("  \"shaper_path\": " .. json_string(data.shaper_path) .. ",\n")
  file:write("  \"output_path\": " .. json_string(data.output_path) .. ",\n")
  file:write("  \"algorithm\": " .. json_string(data.algorithm or "shapee") .. ",\n")
  file:write("  \"sample_rate\": " .. tostring(data.sample_rate) .. ",\n")
  file:write("  \"carrier_start_offset\": " .. tostring(data.carrier_start_offset or 0) .. ",\n")
  file:write("  \"carrier_duration\": " .. tostring(data.carrier_duration or 0) .. ",\n")
  file:write("  \"shaper_start_offset\": " .. tostring(data.shaper_start_offset or 0) .. ",\n")
  file:write("  \"shaper_duration\": " .. tostring(data.shaper_duration or 0) .. ",\n")
  file:write("  \"fft_size\": " .. tostring(data.fft_size) .. ",\n")
  file:write("  \"overlap\": " .. tostring(data.overlap) .. ",\n")
  file:write("  \"amount\": " .. tostring(data.amount) .. ",\n")
  file:write("  \"mix\": " .. tostring(data.mix) .. ",\n")
  file:write("  \"smooth_bins\": " .. tostring(data.smooth_bins) .. ",\n")
  file:write("  \"contrast\": " .. tostring(data.contrast) .. ",\n")
  file:write("  \"floor\": " .. tostring(data.floor) .. ",\n")
  file:write("  \"normalize\": " .. (data.normalize and "true" or "false") .. ",\n")
  file:write("  \"normalize_db\": " .. tostring(data.normalize_db or -6.0) .. "\n")
  file:write("}\n")
  file:close()
  return true
end

local function insert_output_item(path, label, position, channel_count)
  local source = reaper.PCM_Source_CreateFromFile(path)
  if not source then return nil, "REAPER could not create a PCM source from output file." end
  local source_length = ({ reaper.GetMediaSourceLength(source) })[1] or 0
  reaper.InsertTrackAtIndex(reaper.CountTracks(mc.PROJECT), true)
  local track = reaper.GetTrack(mc.PROJECT, reaper.CountTracks(mc.PROJECT) - 1)
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", label, true)
  reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", mc.reaper_track_channel_count(channel_count))
  reaper.SetMediaTrackInfo_Value(track, "D_VOL", DEFAULT_INSERT_GAIN)
  local item = reaper.AddMediaItemToTrack(track)
  local take = reaper.AddTakeToMediaItem(item)
  reaper.SetMediaItemTake_Source(take, source)
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", position)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", source_length)
  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", label, true)
  mc.select_only_track(track)
  mc.select_only_item(item)
  if reaper.UpdateItemInProject then reaper.UpdateItemInProject(item) end
  reaper.Main_OnCommand(40245, 0)
  reaper.UpdateArrange()
  return item, nil
end

local function run_shapee(carrier, shaper, algorithm_index, fft_index, amount, mix, smooth_bins, contrast, floor, normalize, normalize_db, swap)
  if swap then carrier, shaper = shaper, carrier end
  local python = find_python()
  if not python then mc.show_error("python3 was not found.") return end
  local numpy_log = (os.getenv("TMPDIR") or "/tmp") .. "/s3g-mc_numpy_check.log"
  if not run_command(shell_quote(python) .. " -c " .. shell_quote("import numpy"), numpy_log) then
    mc.show_error("Python was found, but NumPy could not be imported.\n\n" .. read_file(numpy_log))
    return
  end
  if carrier.filename == "" or not file_exists(carrier.filename) then
    mc.show_error("The carrier item must be backed by a readable WAV file.")
    return
  end
  if shaper.filename == "" or not file_exists(shaper.filename) then
    mc.show_error("The shaper item must be backed by a readable WAV file.")
    return
  end

  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local temp_root = os.getenv("TMPDIR") or "/tmp"
  local temp_dir = temp_root .. "/s3g-mc_temp_shapee_" .. stamp
  reaper.RecursiveCreateDirectory(temp_dir, 0)
  local helper_path = temp_dir .. "/s3g_shapee.py"
  local manifest_path = temp_dir .. "/manifest.json"
  local log_path = temp_dir .. "/shapee.log"
  local function cleanup()
    os.remove(helper_path)
    os.remove(manifest_path)
    os.remove(log_path)
    os.remove(temp_dir)
  end

  if not write_helper(helper_path) then
    cleanup()
    mc.show_error("Could not write temporary spectral shaper helper.")
    return
  end

  local project_path = ({ reaper.EnumProjects(-1, "") })[2] or ""
  project_path = project_path ~= "" and dirname(project_path) or ""
  local source_dir = carrier.filename ~= "" and dirname(carrier.filename) or ""
  local fallback_dir = reaper.GetResourcePath and reaper.GetResourcePath() or temp_root
  local output_dir = project_path ~= "" and (project_path .. "/s3g_spectral_renders") or
    ((source_dir ~= "" and source_dir or fallback_dir) .. "/s3g_spectral_renders")
  reaper.RecursiveCreateDirectory(output_dir, 0)
  local output_path = output_dir .. "/s3g_shapee_" .. stamp .. "_" .. tostring(carrier.channels) .. "ch.wav"
  local sample_rate = source_sample_rate(carrier)
  local start_time = reaper.time_precise()

  if not write_manifest(manifest_path, {
    carrier_path = carrier.filename,
    shaper_path = shaper.filename,
    output_path = output_path,
    algorithm = ALGORITHM_VALUES[algorithm_index] or "shapee",
    sample_rate = sample_rate,
    carrier_start_offset = carrier.start_offset,
    carrier_duration = carrier.length * math.max(0.000001, carrier.playrate),
    shaper_start_offset = shaper.start_offset,
    shaper_duration = shaper.length * math.max(0.000001, shaper.playrate),
    fft_size = FFT_VALUES[fft_index] or 2048,
    overlap = 4,
    amount = amount,
    mix = mix,
    smooth_bins = smooth_bins,
    contrast = contrast,
    floor = floor,
    normalize = normalize,
    normalize_db = normalize_db,
  }) then
    cleanup()
    mc.show_error("Could not write temporary spectral shaper manifest.")
    return
  end

  local command = shell_quote(python) .. " " .. shell_quote(helper_path) .. " " .. shell_quote(manifest_path)
  if not run_command(command, log_path) or not file_exists(output_path) then
    local details = read_file(log_path)
    cleanup()
    reaper.MB("Spectral shaper failed.\n\n" .. details .. "\n\nCommand:\n" .. command, "Spectral Shaper", 0)
    return
  end

  reaper.Undo_BeginBlock()
  local item, err = insert_output_item(output_path, "Spectral shaper transfer (" .. tostring(carrier.channels) .. "ch)", carrier.position, carrier.channels)
  reaper.Undo_EndBlock("Spectral Shaper", -1)
  local details = trim(read_file(log_path))
  cleanup()
  if not item then mc.show_error(err or "Could not insert output item.") return end

  local lines = {
    "Carrier: " .. carrier.name .. " (" .. tostring(carrier.channels) .. "ch)",
    "Shaper: " .. shaper.name .. " (" .. tostring(shaper.channels) .. "ch)",
    "Backend: Python WAV reader + NumPy STFT",
    "Algorithm: " .. (ALGORITHM_NAMES[algorithm_index] or "Spectral envelope transfer"),
    "FFT: " .. tostring(FFT_VALUES[fft_index] or 2048),
    (algorithm_index == 2 and "Formant amount: " or "Envelope amount: ") .. string.format("%.3f", amount),
    "Mix: " .. string.format("%.3f", mix),
    (algorithm_index == 2 and "Formant smoothing bins: " or "Envelope smoothing bins: ") .. tostring(smooth_bins),
    (algorithm_index == 2 and "Formant contrast: " or "Envelope contrast: ") .. string.format("%.3f", contrast),
    "Floor: " .. string.format("%.3f", floor),
  }
  if details ~= "" then lines[#lines + 1] = details end
  lines[#lines + 1] = "Output channels: " .. tostring(carrier.channels)
  lines[#lines + 1] = "Inserted track gain: -6.0 dB"
  lines[#lines + 1] = string.format("Total time: %.2f sec", reaper.time_precise() - start_time)
  lines[#lines + 1] = "Peak build: requested for selected output item"
  lines[#lines + 1] = "Output: " .. output_path
  if normalize then lines[#lines + 1] = "Peak normalize: " .. tostring(normalize_db) .. " dB" end
  mc.print_plan("Spectral Shaper", lines)
end

local function main()
  local entries = selected_entries()
  if #entries < 2 then
    mc.show_error("Select two WAV-backed audio media items: carrier first, shaper second. Use Swap if needed.")
    return
  end

  local ctx = ImGui.CreateContext("Spectral Shaper")
  local open = true
  local algorithm_index = 1
  local fft_index = 2
  local amount = 0.75
  local mix = 1.0
  local smooth_bins = 9
  local contrast = 1.0
  local floor = 0.05
  local normalize = true
  local normalize_db = -6.0
  local swap = false
  local should_render = false

  local function loop()
    ImGui.SetNextWindowSize(ctx, 560, 430, ImGui.Cond_FirstUseEver)
    local visible
    visible, open = ImGui.Begin(ctx, "Spectral Shaper", open)
    if visible then
      local carrier = swap and entries[2] or entries[1]
      local shaper = swap and entries[1] or entries[2]
      ImGui.Text(ctx, "Carrier: " .. carrier.name .. "  (" .. tostring(carrier.channels) .. " ch)")
      ImGui.Text(ctx, "Shaper: " .. shaper.name .. "  (" .. tostring(shaper.channels) .. " ch)")
      if ImGui.Button(ctx, "Swap carrier / shaper") then swap = not swap end
      ImGui.Spacing(ctx)
      local changed
      changed, algorithm_index = draw_combo(ctx, "Algorithm", algorithm_index, ALGORITHM_NAMES, 1, 2)
      changed, fft_index = draw_combo(ctx, "FFT size", fft_index, FFT_NAMES, 1, 4)
      changed, amount = ImGui.SliderDouble(ctx, algorithm_index == 2 and "Formant amount" or "Envelope amount", amount, 0, 1, "%.3f")
      changed, mix = ImGui.SliderDouble(ctx, "Wet mix", mix, 0, 1, "%.3f")
      changed, smooth_bins = ImGui.SliderInt(ctx, algorithm_index == 2 and "Formant smoothing bins" or "Envelope smoothing bins", smooth_bins, 1, 96)
      changed, contrast = ImGui.SliderDouble(ctx, algorithm_index == 2 and "Formant contrast" or "Envelope contrast", contrast, 0.1, 3.0, "%.2f")
      changed, floor = ImGui.SliderDouble(ctx, "Envelope floor", floor, 0.001, 0.5, "%.3f")
      changed, normalize = ImGui.Checkbox(ctx, "Peak normalize", normalize)
      if normalize then
        changed, normalize_db = ImGui.SliderDouble(ctx, "Normalize peak dB", normalize_db, -24, 0, "%.1f")
      end
      ImGui.Separator(ctx)
      if algorithm_index == 2 then
        ImGui.Text(ctx, "Carrier keeps timing/phase/detail; shaper supplies broad formant contour.")
      else
        ImGui.Text(ctx, "Carrier keeps timing/phase; shaper supplies the spectral envelope.")
      end
      if ImGui.Button(ctx, "Render", 92, 26) then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 92, 26) then open = false end
      ImGui.End(ctx)
    end

    if should_render then
      open = false
      run_shapee(entries[1], entries[2], algorithm_index, fft_index, amount, mix, smooth_bins, contrast, floor, normalize, normalize_db, swap)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
