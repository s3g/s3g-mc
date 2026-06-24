-- @description Spectral Offline Library
-- @browser hidden

local M = {}

local mc = dofile((debug.getinfo(1, "S").source:match("^@(.+[/\\])") or "") .. "Multichannel Library.lua")

function M.shell_quote(path)
  return "'" .. tostring(path):gsub("'", "'\\''") .. "'"
end

function M.dirname(path)
  return tostring(path or ""):match("^(.*)[/\\][^/\\]+$") or ""
end

function M.trim(text)
  return (text or ""):match("^%s*(.-)%s*$")
end

function M.file_exists(path)
  local file = io.open(path, "rb")
  if file then file:close() return true end
  return false
end

function M.read_file(path)
  local file = io.open(path, "rb")
  if not file then return "" end
  local text = file:read("*a") or ""
  file:close()
  return text
end

function M.run_command(command, log_path)
  if log_path then command = command .. " > " .. M.shell_quote(log_path) .. " 2>&1" end
  local result = os.execute(command)
  return result == true or result == 0
end

function M.json_string(value)
  local text = tostring(value or "")
  text = text:gsub("\\", "\\\\")
  text = text:gsub("\"", "\\\"")
  text = text:gsub("\n", "\\n")
  text = text:gsub("\r", "\\r")
  text = text:gsub("\t", "\\t")
  return "\"" .. text .. "\""
end

function M.media_source_filename(source)
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
  if parent and parent ~= source then return M.media_source_filename(parent) end
  return ""
end

function M.selected_entries()
  local entries = {}
  for index = 0, reaper.CountSelectedMediaItems(mc.PROJECT) - 1 do
    local item = reaper.GetSelectedMediaItem(mc.PROJECT, index)
    local take = item and reaper.GetActiveTake(item)
    local source = take and reaper.GetMediaItemTake_Source(take)
    local channels = take and mc.get_take_source_channels(take)
    if item and take and source and channels and channels > 0 then
      entries[#entries + 1] = {
        item = item,
        take = take,
        source = source,
        filename = M.media_source_filename(source),
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

function M.source_sample_rate(entry)
  local sr = reaper.GetMediaSourceSampleRate(entry.source)
  if not sr or sr <= 0 then return 48000 end
  return math.floor(sr + 0.5)
end

function M.find_python(script_dir)
  local configured_path = script_dir .. "python3_path.txt"
  if M.file_exists(configured_path) then
    local file = io.open(configured_path, "rb")
    local configured = file and M.trim(file:read("*a") or "") or ""
    if file then file:close() end
    if configured ~= "" and M.file_exists(configured) then return configured end
  end
  local home = os.getenv("HOME") or ""
  local candidates = { "/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3" }
  if home ~= "" then
    table.insert(candidates, 1, home .. "/miniconda3/bin/python3")
    table.insert(candidates, 2, home .. "/miniforge3/bin/python3")
    table.insert(candidates, 3, home .. "/anaconda3/bin/python3")
  end
  for _, path in ipairs(candidates) do
    if M.file_exists(path) then return path end
  end
  local handle = io.popen("command -v python3 2>/dev/null")
  if handle then
    local path = M.trim(handle:read("*a"))
    handle:close()
    if path ~= "" and M.file_exists(path) then return path end
  end
  return nil
end

function M.draw_combo(ImGui, ctx, label, value, names, first_index, last_index)
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

function M.insert_output_item(path, label, position, channel_count)
  local source = reaper.PCM_Source_CreateFromFile(path)
  if not source then return nil, "REAPER could not create a PCM source from output file." end
  local source_length = ({ reaper.GetMediaSourceLength(source) })[1] or 0
  reaper.InsertTrackAtIndex(reaper.CountTracks(mc.PROJECT), true)
  local track = reaper.GetTrack(mc.PROJECT, reaper.CountTracks(mc.PROJECT) - 1)
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", label, true)
  reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", mc.reaper_track_channel_count(channel_count))
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

function M.write_helper(path)
  local file = io.open(path, "w")
  if not file then return false end
  file:write([=[
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
                          int(sample_rate) * channels * 3, channels * 3, 24, 22, 24, 0) + pcm_guid
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
        out = np.stack([np.interp(new_x, old_x, out[:, ch]).astype(np.float32) for ch in range(out.shape[1])], axis=1)
    return out.astype(np.float32)

def load_item(cfg, key):
    data, rate = read_wav(cfg[key + "_path"])
    return segment(data, rate, cfg[key + "_start_offset"], cfg[key + "_duration"], int(cfg["sample_rate"]))

def stft_frames(audio, fft_size, hop, window):
    padded = np.pad(audio.astype(np.float32), (0, fft_size))
    specs = []
    for start in range(0, padded.size - fft_size + 1, hop):
        specs.append(np.fft.rfft(padded[start:start + fft_size] * window))
    return specs, audio.size

def istft_frames(specs, original_size, fft_size, hop, window):
    out = np.zeros(original_size + fft_size * 2, dtype=np.float64)
    norm = np.zeros_like(out)
    for i, spec in enumerate(specs):
        start = i * hop
        frame = np.fft.irfft(spec, fft_size)
        out[start:start + fft_size] += frame * window
        norm[start:start + fft_size] += window * window
    nz = norm > 1e-9
    out[nz] /= norm[nz]
    return out[:original_size].astype(np.float32)

def smooth_time(values, radius):
    radius = int(max(0, radius))
    if radius <= 0 or values.shape[0] < 2:
        return values
    kernel = np.ones(radius * 2 + 1, dtype=np.float64) / (radius * 2 + 1)
    return np.apply_along_axis(lambda x: np.convolve(x, kernel, mode="same"), 0, values)

def smooth_bins(values, bins):
    bins = int(max(1, bins))
    if bins <= 1:
        return values
    kernel = np.ones(bins, dtype=np.float64) / bins
    return np.convolve(values, kernel, mode="same")

def phase_vocoder_stretch(audio, stretch, fft_size, overlap):
    stretch = max(1.0, float(stretch))
    if stretch <= 1.0001 or audio.size < fft_size:
        return audio.astype(np.float32)
    hop = fft_size // int(overlap)
    window = np.hanning(fft_size).astype(np.float32)
    specs, _ = stft_frames(audio, fft_size, hop, window)
    if len(specs) < 2:
        return audio.astype(np.float32)
    out_count = max(1, int(math.ceil(len(specs) * stretch)))
    phase = np.angle(specs[0])
    last_phase = np.angle(specs[0])
    expected = 2.0 * math.pi * hop * np.arange(specs[0].size) / fft_size
    out_specs = []
    for out_idx in range(out_count):
        pos = min((len(specs) - 1.001), out_idx / stretch)
        i0 = int(math.floor(pos))
        frac = pos - i0
        s0 = specs[i0]
        s1 = specs[min(i0 + 1, len(specs) - 1)]
        mag = np.abs(s0) * (1.0 - frac) + np.abs(s1) * frac
        current_phase = np.angle(s1)
        delta = current_phase - last_phase - expected
        delta -= 2.0 * math.pi * np.round(delta / (2.0 * math.pi))
        phase += expected + delta
        last_phase = current_phase
        out_specs.append(mag * np.exp(1j * phase))
    return istft_frames(out_specs, int(round(audio.size * stretch)), fft_size, hop, window)

def maybe_expand(data, cfg):
    expand = max(1.0, float(cfg.get("expand", 1.0)))
    if expand <= 1.0001:
        return data
    fft_size = int(cfg["fft_size"])
    overlap = int(cfg["overlap"])
    channels = [phase_vocoder_stretch(data[:, ch], expand, fft_size, overlap) for ch in range(data.shape[1])]
    max_len = max(ch.size for ch in channels)
    out = np.zeros((max_len, data.shape[1]), dtype=np.float32)
    for ch, channel in enumerate(channels):
        out[:channel.size, ch] = channel
    return out

def process_blur(audio, cfg):
    fft_size = int(cfg["fft_size"]); hop = fft_size // int(cfg["overlap"])
    window = np.hanning(fft_size).astype(np.float32)
    amount = float(cfg["amount"]); mix = float(cfg["mix"])
    radius = int(cfg["time_radius"])
    safe = bool(cfg.get("safe", True))
    out_channels = []
    total = 0
    for ch in range(audio.shape[1]):
        specs, size = stft_frames(audio[:, ch], fft_size, hop, window)
        mags = np.array([np.abs(s) for s in specs])
        phases = np.array([np.exp(1j * np.angle(s)) for s in specs])
        blurred = smooth_time(mags, radius)
        new_specs = []
        for i in range(len(specs)):
            if safe:
                m_mean = float(np.mean(mags[i])) if mags[i].size else 0.0
                b_mean = float(np.mean(blurred[i])) if blurred[i].size else 0.0
                env = np.ones_like(blurred[i]) if b_mean <= 1e-12 else blurred[i] / b_mean
                target = mags[i] * ((1.0 - amount) + amount * env)
                if m_mean > 1e-12:
                    t_mean = float(np.mean(target))
                    if t_mean > 1e-12:
                        target *= m_mean / t_mean
            else:
                target = mags[i] * (1 - amount) + blurred[i] * amount
            new_specs.append(target * phases[i])
        wet = istft_frames(new_specs, size, fft_size, hop, window)
        out_channels.append(audio[:, ch] * (1 - mix) + wet * mix)
        total += len(specs)
    return maybe_expand(np.stack(out_channels, axis=1), cfg), total

def process_freeze(audio, cfg):
    fft_size = int(cfg["fft_size"]); hop = fft_size // int(cfg["overlap"])
    window = np.hanning(fft_size).astype(np.float32)
    amount = float(cfg["amount"]); mix = float(cfg["mix"])
    pos = np.clip(float(cfg["freeze_pos"]), 0.0, 1.0)
    safe = bool(cfg.get("safe", True))
    floor = max(0.001, float(cfg.get("floor", 0.05)))
    out_channels = []
    total = 0
    for ch in range(audio.shape[1]):
        specs, size = stft_frames(audio[:, ch], fft_size, hop, window)
        mags = np.array([np.abs(s) for s in specs])
        phases = np.array([np.exp(1j * np.angle(s)) for s in specs])
        idx = min(len(specs) - 1, max(0, int(round(pos * (len(specs) - 1)))))
        frozen = smooth_bins(mags[idx], int(cfg["smooth_bins"]))
        frozen_mean = float(np.mean(frozen)) if frozen.size else 0.0
        env = np.ones_like(frozen) if frozen_mean <= 1e-12 else frozen / frozen_mean
        env = np.maximum(env, floor)
        new_specs = []
        for i in range(len(specs)):
            if safe:
                target = mags[i] * ((1.0 - amount) + amount * env)
            else:
                m_mean = float(np.mean(mags[i])) if mags[i].size else 0.0
                scaled_frozen = frozen
                if frozen_mean > 1e-12:
                    scaled_frozen = frozen * (m_mean / frozen_mean)
                target = mags[i] * (1 - amount) + scaled_frozen * amount
            new_specs.append(target * phases[i])
        wet = istft_frames(new_specs, size, fft_size, hop, window)
        out_channels.append(audio[:, ch] * (1 - mix) + wet * mix)
        total += len(specs)
    return maybe_expand(np.stack(out_channels, axis=1), cfg), total

def process_cross(carrier, modulator, cfg):
    fft_size = int(cfg["fft_size"]); hop = fft_size // int(cfg["overlap"])
    window = np.hanning(fft_size).astype(np.float32)
    amount = float(cfg["amount"]); mix = float(cfg["mix"])
    contrast = max(0.05, float(cfg["contrast"]))
    floor = max(0.001, float(cfg["floor"]))
    modulator = np.stack([np.interp(np.linspace(0, modulator.shape[0]-1, carrier.shape[0]), np.arange(modulator.shape[0]), modulator[:, ch % modulator.shape[1]]) for ch in range(carrier.shape[1])], axis=1).astype(np.float32)
    out_channels = []
    total = 0
    for ch in range(carrier.shape[1]):
        c_specs, size = stft_frames(carrier[:, ch], fft_size, hop, window)
        m_specs, _ = stft_frames(modulator[:, ch], fft_size, hop, window)
        new_specs = []
        for i, c in enumerate(c_specs):
            c_mag = np.abs(c)
            mag = smooth_bins(np.abs(m_specs[min(i, len(m_specs)-1)]), int(cfg["smooth_bins"]))
            c_mean = float(np.mean(c_mag)) if c_mag.size else 0.0
            m_mean = float(np.mean(mag)) if mag.size else 0.0
            if m_mean > 1e-12:
                mag = mag * (c_mean / m_mean)
            mag = np.power(np.maximum(mag, floor * max(c_mean, 1e-9)), contrast)
            target_mag = c_mag * (1.0 - amount) + mag * amount
            phase = np.exp(1j * np.angle(c))
            new_specs.append(target_mag * phase)
        wet = istft_frames(new_specs, size, fft_size, hop, window)
        out_channels.append(carrier[:, ch] * (1 - mix) + wet * mix)
        total += len(c_specs)
    return np.stack(out_channels, axis=1), total

def process_spatialize(audio, cfg):
    fft_size = int(cfg["fft_size"]); hop = fft_size // int(cfg["overlap"])
    window = np.hanning(fft_size).astype(np.float32)
    out_ch = int(cfg["output_channels"])
    spread = float(cfg["spread"])
    mono = np.mean(audio, axis=1).astype(np.float32)
    specs, size = stft_frames(mono, fft_size, hop, window)
    bins = specs[0].size if specs else fft_size // 2 + 1
    bin_pos = np.linspace(0, out_ch - 1, bins)
    channel_specs = [[] for _ in range(out_ch)]
    for spec in specs:
        for ch in range(out_ch):
            dist = np.abs(bin_pos - ch)
            dist = np.minimum(dist, out_ch - dist)
            weights = np.exp(-(dist ** 2) / max(0.001, spread * spread))
            weights /= np.sqrt(np.sum(weights * weights) + 1e-12)
            channel_specs[ch].append(spec * weights)
    outs = [istft_frames(channel_specs[ch], size, fft_size, hop, window) for ch in range(out_ch)]
    return np.stack(outs, axis=1), len(specs) * out_ch

def normalize(data, db):
    peak = float(np.max(np.abs(data))) if data.size else 0.0
    if peak > 0.0:
        data = data * ((10 ** (float(db) / 20.0)) / peak)
    return data

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    cfg = json.load(handle)

mode = cfg["mode"]
sample_rate = int(cfg["sample_rate"])
audio = load_item(cfg, "source")
if mode == "blur":
    result, frames = process_blur(audio, cfg)
elif mode == "freeze":
    result, frames = process_freeze(audio, cfg)
elif mode == "cross":
    result, frames = process_cross(audio, load_item(cfg, "modulator"), cfg)
elif mode == "spatialize":
    result, frames = process_spatialize(audio, cfg)
else:
    raise RuntimeError(f"Unknown spectral mode: {mode}")
if cfg.get("normalize", False):
    result = normalize(result, cfg.get("normalize_db", -6.0))
print("Input peak:", float(np.max(np.abs(audio))) if audio.size else 0.0)
print("Output peak:", float(np.max(np.abs(result))) if result.size else 0.0)
print("STFT frames:", frames)
write_pcm24_wav(cfg["output_path"], result.astype(np.float32), sample_rate)
]=])
  file:close()
  return true
end

function M.write_manifest(path, data)
  local file = io.open(path, "w")
  if not file then return false end
  file:write("{\n")
  local first = true
  for key, value in pairs(data) do
    if not first then file:write(",\n") end
    first = false
    file:write("  " .. M.json_string(key) .. ": ")
    if type(value) == "boolean" then
      file:write(value and "true" or "false")
    elseif type(value) == "number" then
      file:write(tostring(value))
    else
      file:write(M.json_string(value))
    end
  end
  file:write("\n}\n")
  file:close()
  return true
end

function M.render(script_dir, title, entry, manifest, label, log_lines)
  local python = M.find_python(script_dir)
  if not python then mc.show_error("python3 was not found.") return nil end
  local numpy_log = (os.getenv("TMPDIR") or "/tmp") .. "/s3g-mc_numpy_check.log"
  if not M.run_command(M.shell_quote(python) .. " -c " .. M.shell_quote("import numpy"), numpy_log) then
    mc.show_error("Python was found, but NumPy could not be imported.\n\n" .. M.read_file(numpy_log))
    return nil
  end
  if entry.filename == "" or not M.file_exists(entry.filename) then
    mc.show_error("The selected item must be backed by a readable WAV file.")
    return nil
  end
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local temp_root = os.getenv("TMPDIR") or "/tmp"
  local temp_dir = temp_root .. "/s3g-mc_temp_spectral_" .. stamp
  reaper.RecursiveCreateDirectory(temp_dir, 0)
  local helper_path = temp_dir .. "/s3g_spectral.py"
  local manifest_path = temp_dir .. "/manifest.json"
  local log_path = temp_dir .. "/spectral.log"
  local function cleanup()
    os.remove(helper_path)
    os.remove(manifest_path)
    os.remove(log_path)
    os.remove(temp_dir)
  end
  if not M.write_helper(helper_path) then cleanup() mc.show_error("Could not write temporary spectral helper.") return nil end
  local project_path = ({ reaper.EnumProjects(-1, "") })[2] or ""
  project_path = project_path ~= "" and M.dirname(project_path) or ""
  local source_dir = entry.filename ~= "" and M.dirname(entry.filename) or ""
  local fallback_dir = reaper.GetResourcePath and reaper.GetResourcePath() or temp_root
  local output_dir = project_path ~= "" and (project_path .. "/s3g_spectral_renders") or
    ((source_dir ~= "" and source_dir or fallback_dir) .. "/s3g_spectral_renders")
  reaper.RecursiveCreateDirectory(output_dir, 0)
  local output_channels = manifest.output_channels or entry.channels
  local output_path = output_dir .. "/" .. label .. "_" .. stamp .. "_" .. tostring(output_channels) .. "ch.wav"
  manifest.output_path = output_path
  if not M.write_manifest(manifest_path, manifest) then cleanup() mc.show_error("Could not write temporary spectral manifest.") return nil end
  local start_time = reaper.time_precise()
  local command = M.shell_quote(python) .. " " .. M.shell_quote(helper_path) .. " " .. M.shell_quote(manifest_path)
  if not M.run_command(command, log_path) or not M.file_exists(output_path) then
    local details = M.read_file(log_path)
    cleanup()
    reaper.MB(title .. " failed.\n\n" .. details .. "\n\nCommand:\n" .. command, title, 0)
    return nil
  end
  reaper.Undo_BeginBlock()
  local item, err = M.insert_output_item(output_path, title .. " (" .. tostring(output_channels) .. "ch)", entry.position, output_channels)
  reaper.Undo_EndBlock(title, -1)
  local details = M.trim(M.read_file(log_path))
  cleanup()
  if not item then mc.show_error(err or "Could not insert output item.") return nil end
  local lines = log_lines or {}
  if details ~= "" then lines[#lines + 1] = details end
  lines[#lines + 1] = "Output channels: " .. tostring(output_channels)
  lines[#lines + 1] = string.format("Total time: %.2f sec", reaper.time_precise() - start_time)
  lines[#lines + 1] = "Peak build: requested for selected output item"
  lines[#lines + 1] = "Output: " .. output_path
  mc.print_plan(title, lines)
  return item
end

return M
