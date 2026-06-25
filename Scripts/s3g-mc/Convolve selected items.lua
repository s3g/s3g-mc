-- @description Convolve selected items
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spectral / Convolution
-- @render Yes; writes a new convolved media item with optional full tail or source-length trim.
-- @method Offline file convolution. Select two audio items: source and impulse response. Supports mono, stereo, multichannel pairing, and summed matrix modes.
-- @about
--   Uses Python/NumPy to read selected WAV media, convolve channel pairs, and
--   write a 24-bit PCM WAV inserted on a new track at the source item position.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Convolve selected items", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local MODE_MATCHED_WRAP = 1
local MODE_IMPULSE_MONO = 2
local MODE_SOURCE_MONO = 3
local MODE_MATRIX = 4

local MODE_NAMES = {
  [MODE_MATCHED_WRAP] = "Matched / wrap impulse",
  [MODE_IMPULSE_MONO] = "Each source ch x impulse mix",
  [MODE_SOURCE_MONO] = "Source mix x each impulse ch",
  [MODE_MATRIX] = "Matrix sum",
}

local TAIL_FULL = 1
local TAIL_TRIM = 2
local DEFAULT_INSERT_GAIN = 0.5

local TAIL_NAMES = {
  [TAIL_FULL] = "Full convolution tail",
  [TAIL_TRIM] = "Trim to source length",
}

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
  if parent and parent ~= source then
    return media_source_filename(parent)
  end
  return ""
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
  local candidates = {
    "/opt/homebrew/bin/python3",
    "/usr/local/bin/python3",
    "/usr/bin/python3",
  }
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

local function read_file(path)
  local file = io.open(path, "rb")
  if not file then return "" end
  local text = file:read("*a") or ""
  file:close()
  return text
end

local function run_command(command, log_path)
  if log_path then command = command .. " > " .. shell_quote(log_path) .. " 2>&1" end
  local result = os.execute(command)
  return result == true or result == 0
end

local function selected_audio_entries()
  local entries = {}
  for index = 0, reaper.CountSelectedMediaItems(mc.PROJECT) - 1 do
    local item = reaper.GetSelectedMediaItem(mc.PROJECT, index)
    local take = item and reaper.GetActiveTake(item)
    local source = take and reaper.GetMediaItemTake_Source(take)
    local channels = take and mc.get_take_source_channels(take)
    local filename = media_source_filename(source)
    if take and source and channels and channels > 0 then
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

local function channel_plan(source_channels, impulse_channels, mode)
  local plan = {}
  local output_channels = source_channels
  if mode == MODE_IMPULSE_MONO then
    output_channels = source_channels
    for source_channel = 1, source_channels do
      plan[#plan + 1] = {
        source = source_channel,
        impulse = "mix",
        output = source_channel,
        label = "src" .. source_channel .. "_irmix",
      }
    end
  elseif mode == MODE_SOURCE_MONO then
    output_channels = impulse_channels
    for impulse_channel = 1, impulse_channels do
      plan[#plan + 1] = {
        source = "mix",
        impulse = impulse_channel,
        output = impulse_channel,
        label = "srcmix_ir" .. impulse_channel,
      }
    end
  elseif mode == MODE_MATRIX then
    output_channels = impulse_channels
    for source_channel = 1, source_channels do
      for impulse_channel = 1, impulse_channels do
        plan[#plan + 1] = {
          source = source_channel,
          impulse = impulse_channel,
          output = impulse_channel,
          label = "src" .. source_channel .. "_ir" .. impulse_channel .. "_to_out" .. impulse_channel,
        }
      end
    end
  else
    output_channels = source_channels
    for source_channel = 1, source_channels do
      local impulse_channel = ((source_channel - 1) % impulse_channels) + 1
      plan[#plan + 1] = {
        source = source_channel,
        impulse = impulse_channel,
        output = source_channel,
        label = "src" .. source_channel .. "_ir" .. impulse_channel,
      }
    end
  end
  return plan, output_channels
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

local function write_convolution_helper(path)
  local file = io.open(path, "w")
  if not file then return false end
  file:write([[
import json
import struct
import sys
import numpy as np

def convolve(src, ir, trim_samples, gain, label):
    if not np.all(np.isfinite(src)):
        raise RuntimeError(f"Non-finite source samples for {label}")
    if not np.all(np.isfinite(ir)):
        raise RuntimeError(f"Non-finite impulse samples for {label}")
    if src.size == 0 or ir.size == 0:
        return np.zeros(0, dtype=np.float32)
    src = src - np.mean(src, dtype=np.float64)
    ir = ir - np.mean(ir, dtype=np.float64)
    ir_peak = float(np.max(np.abs(ir))) if ir.size else 0.0
    if ir_peak > 0.0:
        ir = ir / ir_peak
    out_len = int(src.size + ir.size - 1)
    fft_len = 1 << (out_len - 1).bit_length()
    spec = np.fft.rfft(src, fft_len) * np.fft.rfft(ir, fft_len)
    out = np.fft.irfft(spec, fft_len)[:out_len]
    if trim_samples > 0:
        out = out[:int(trim_samples)]
    if not np.all(np.isfinite(out)):
        raise RuntimeError(f"Convolution produced non-finite samples for {label}")
    return (out * gain).astype(np.float32)

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
        bytes_per_sample = bits // 8
        if channels <= 0 or bytes_per_sample <= 0 or block_align <= 0:
            raise RuntimeError(f"Unsupported WAV format: {path}")

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

def channel_segment(cache, path, channel, start_seconds, duration_seconds, target_sample_rate):
    if path not in cache:
        cache[path] = read_wav(path)
    data, source_rate = cache[path]
    start = max(0, int(round(float(start_seconds) * source_rate)))
    count = max(1, int(round(float(duration_seconds) * source_rate)))
    segment = data[start:start + count]
    if segment.size == 0:
        return np.zeros(0, dtype=np.float32)
    if channel == "mix":
        out = np.mean(segment, axis=1, dtype=np.float64).astype(np.float32)
    else:
        channel_index = int(channel) - 1
        if channel_index < 0 or channel_index >= segment.shape[1]:
            raise RuntimeError(f"Channel {channel} is outside available channels for {path}")
        out = segment[:, channel_index].astype(np.float32)
    if source_rate != target_sample_rate and out.size > 1:
        old_x = np.arange(out.size, dtype=np.float64)
        new_size = max(1, int(round(out.size * target_sample_rate / source_rate)))
        new_x = np.linspace(0, out.size - 1, new_size, dtype=np.float64)
        out = np.interp(new_x, old_x, out).astype(np.float32)
    return out

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
        fmt = struct.pack(
            "<HHIIHHHHI",
            0xFFFE,
            channels,
            int(sample_rate),
            int(sample_rate) * channels * 3,
            channels * 3,
            24,
            22,
            24,
            0,
        ) + pcm_guid
    else:
        fmt = struct.pack("<HHIIHH", 1, channels, int(sample_rate), int(sample_rate) * channels * 3, channels * 3, 24)
    riff_size = 4 + (8 + len(fmt)) + (8 + len(payload))
    if riff_size > 0xFFFFFFFF:
        raise RuntimeError("Output WAV is larger than the standard RIFF limit.")
    with open(path, "wb") as handle:
        handle.write(b"RIFF")
        handle.write(struct.pack("<I", riff_size))
        handle.write(b"WAVE")
        handle.write(b"fmt ")
        handle.write(struct.pack("<I", len(fmt)))
        handle.write(fmt)
        handle.write(b"data")
        handle.write(struct.pack("<I", len(payload)))
        handle.write(bytes(payload))

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    manifest = json.load(handle)

gain = 10 ** (float(manifest.get("wet_gain_db", 0.0)) / 20.0)
wav_cache = {}
rendered = []
for pair in manifest["pairs"]:
    src = channel_segment(wav_cache, pair["source_path"], pair["source_channel"],
                          pair.get("source_start", 0.0), pair["source_duration"], int(manifest["sample_rate"]))
    ir = channel_segment(wav_cache, pair["impulse_path"], pair["impulse_channel"],
                         pair.get("impulse_start", 0.0), pair["impulse_duration"], int(manifest["sample_rate"]))
    print(f"{pair['label']} source peak:", float(np.max(np.abs(src))) if src.size else 0.0)
    print(f"{pair['label']} impulse peak:", float(np.max(np.abs(ir))) if ir.size else 0.0)
    rendered.append((int(pair.get("output_channel", len(rendered) + 1)), convolve(src, ir, int(pair.get("trim_samples", 0)), gain, pair["label"])))
if not rendered:
    raise RuntimeError("No channel pairs were provided.")
output_channel_count = int(manifest.get("output_channel_count", len(rendered)))
if output_channel_count <= 0:
    raise RuntimeError("Output channel count must be positive.")
max_len = max((channel.size for _output_channel, channel in rendered), default=0)
if max_len <= 0:
    max_len = 1
stacked = np.zeros((max_len, output_channel_count), dtype=np.float32)
for output_channel, channel in rendered:
    output_index = output_channel - 1
    if output_index < 0 or output_index >= output_channel_count:
        raise RuntimeError(f"Output channel {output_channel} is outside the rendered output.")
    if channel.size > 0:
        stacked[:channel.size, output_index] += channel

if manifest.get("normalize", False):
    peak = float(np.max(np.abs(stacked))) if stacked.size else 0.0
    if not np.isfinite(peak):
        raise RuntimeError("Output peak is not finite.")
    if peak > 0.0:
        target = 10 ** (float(manifest.get("normalize_db", -6.0)) / 20.0)
        stacked *= target / peak

output_peak = float(np.max(np.abs(stacked))) if stacked.size else 0.0
if not np.isfinite(output_peak):
    raise RuntimeError("Final output peak is not finite.")
print("Output peak:", output_peak)
write_pcm24_wav(manifest["output_path"], stacked, int(manifest["sample_rate"]))
]])
  file:close()
  return true
end

local function source_sample_rate(entry)
  local sr = reaper.GetMediaSourceSampleRate(entry.source)
  if not sr or sr <= 0 then return 48000 end
  return math.floor(sr + 0.5)
end

local function frame_count(entry, sample_rate)
  return math.max(1, math.floor(entry.length * sample_rate + 0.5))
end

local function write_manifest(path, data)
  local file = io.open(path, "w")
  if not file then return false end
  file:write("{\n")
  file:write("  \"output_path\": " .. json_string(data.output_path) .. ",\n")
  file:write("  \"sample_rate\": " .. tostring(data.sample_rate) .. ",\n")
  file:write("  \"normalize\": " .. (data.normalize and "true" or "false") .. ",\n")
  file:write("  \"normalize_db\": " .. tostring(data.normalize_db or -6.0) .. ",\n")
  file:write("  \"wet_gain_db\": " .. tostring(data.wet_gain_db or 0.0) .. ",\n")
  file:write("  \"output_channel_count\": " .. tostring(data.output_channel_count or #data.pairs) .. ",\n")
  file:write("  \"pairs\": [\n")
  for index, pair in ipairs(data.pairs) do
    file:write("    {\"label\": " .. json_string(pair.label) ..
      ", \"source_path\": " .. json_string(pair.source_path) ..
      ", \"source_channel\": " .. json_string(pair.source_channel) ..
      ", \"source_start\": " .. tostring(pair.source_start or 0) ..
      ", \"source_duration\": " .. tostring(pair.source_duration or 0) ..
      ", \"impulse_path\": " .. json_string(pair.impulse_path) ..
      ", \"impulse_channel\": " .. json_string(pair.impulse_channel) ..
      ", \"impulse_start\": " .. tostring(pair.impulse_start or 0) ..
      ", \"impulse_duration\": " .. tostring(pair.impulse_duration or 0) ..
      ", \"output_channel\": " .. tostring(pair.output_channel or index) ..
      ", \"trim_samples\": " .. tostring(pair.trim_samples or 0) .. "}")
    if index < #data.pairs then file:write(",") end
    file:write("\n")
  end
  file:write("  ]\n")
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
  reaper.Main_OnCommand(40245, 0) -- Peaks: Build any missing peaks for selected items.
  reaper.UpdateArrange()
  return item, nil
end

local function run_convolution(source, impulse, mode, tail_mode, normalize, normalize_db, wet_gain_db, swap)
  if swap then source, impulse = impulse, source end
  local python = find_python()
  if not python then mc.show_error("python3 was not found.") return end
  local numpy_log = (os.getenv("TMPDIR") or "/tmp") .. "/s3g-mc_numpy_check.log"
  if not run_command(shell_quote(python) .. " -c " .. shell_quote("import numpy"), numpy_log) then
    mc.show_error("Python was found, but NumPy could not be imported.\n\n" .. read_file(numpy_log))
    return
  end

  local plan, output_channels = channel_plan(source.channels, impulse.channels, mode)
  if output_channels > mc.MAX_REAPER_TRACK_CHANNELS then
    mc.show_error("This channel mode would create " .. tostring(output_channels) .. " output channels. REAPER maximum is 128.")
    return
  end
  if source.filename == "" or not file_exists(source.filename) then
    mc.show_error("The source item must be backed by a readable WAV file for this convolution action.")
    return
  end
  if impulse.filename == "" or not file_exists(impulse.filename) then
    mc.show_error("The impulse item must be backed by a readable WAV file for this convolution action.")
    return
  end

  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local temp_root = os.getenv("TMPDIR") or "/tmp"
  local temp_dir = temp_root .. "/s3g-mc_temp_convolve_" .. stamp
  reaper.RecursiveCreateDirectory(temp_dir, 0)
  local helper_path = temp_dir .. "/s3g_numpy_convolve.py"
  if not write_convolution_helper(helper_path) then
    mc.show_error("Could not write temporary NumPy convolution helper.")
    return
  end
  local project_path = ({ reaper.EnumProjects(-1, "") })[2] or ""
  project_path = project_path ~= "" and dirname(project_path) or ""
  local source_dir = source.filename ~= "" and dirname(source.filename) or ""
  local fallback_dir = reaper.GetResourcePath and reaper.GetResourcePath() or temp_root
  local output_dir = project_path ~= "" and (project_path .. "/s3g_convolution_renders") or
    ((source_dir ~= "" and source_dir or fallback_dir) .. "/s3g_convolution_renders")
  reaper.RecursiveCreateDirectory(output_dir, 0)
  local sample_rate = source_sample_rate(source)
  local source_samples = frame_count(source, sample_rate)
  local output_path = output_dir .. "/s3g_convolved_" .. stamp .. "_" .. tostring(output_channels) .. "ch.wav"
  local manifest_path = temp_dir .. "/manifest.json"
  local render_log_path = temp_dir .. "/render.log"
  local cleanup_paths = { helper_path, manifest_path, render_log_path }
  local manifest_pairs = {}
  local total_start = reaper.time_precise()
  local log_lines = {
    "Source: " .. source.name .. " (" .. tostring(source.channels) .. "ch)",
    "Impulse: " .. impulse.name .. " (" .. tostring(impulse.channels) .. "ch)",
    "Backend: Python WAV reader + NumPy",
    "Mode: " .. (MODE_NAMES[mode] or "?"),
    "Tail: " .. (TAIL_NAMES[tail_mode] or "?"),
  }

  local function cleanup_temp()
    for _, path in ipairs(cleanup_paths) do os.remove(path) end
    os.remove(temp_dir)
  end

  for index, pair in ipairs(plan) do
    manifest_pairs[#manifest_pairs + 1] = {
      label = pair.label,
      source_path = source.filename,
      source_channel = pair.source,
      source_start = source.start_offset,
      source_duration = source.length * math.max(0.000001, source.playrate),
      impulse_path = impulse.filename,
      impulse_channel = pair.impulse,
      impulse_start = impulse.start_offset,
      impulse_duration = impulse.length * math.max(0.000001, impulse.playrate),
      output_channel = pair.output,
      trim_samples = tail_mode == TAIL_TRIM and source_samples or 0,
    }
    if mode == MODE_MATRIX then
      log_lines[#log_lines + 1] = "Path " .. tostring(index) .. " -> out" .. tostring(pair.output) .. ": " .. pair.label
    else
      log_lines[#log_lines + 1] = "Channel " .. tostring(pair.output or index) .. ": " .. pair.label
    end
  end

  if not write_manifest(manifest_path, {
    output_path = output_path,
    sample_rate = sample_rate,
    output_channel_count = output_channels,
    normalize = normalize,
    normalize_db = normalize_db,
    wet_gain_db = wet_gain_db,
    pairs = manifest_pairs,
  }) then
    cleanup_temp()
    mc.show_error("Could not write temporary convolution manifest.")
    return
  end

  local command = shell_quote(python) .. " " .. shell_quote(helper_path) .. " " .. shell_quote(manifest_path)
  local python_start = reaper.time_precise()
  if not run_command(command, render_log_path) or not file_exists(output_path) then
    local details = read_file(render_log_path)
    cleanup_temp()
    reaper.MB("NumPy convolution failed.\n\n" .. details .. "\n\nCommand:\n" .. command, "Convolve selected items", 0)
    return
  end
  local python_elapsed = reaper.time_precise() - python_start
  local render_details = trim(read_file(render_log_path))
  if render_details ~= "" then
    log_lines[#log_lines + 1] = render_details
  end

  reaper.Undo_BeginBlock()
  local item, err = insert_output_item(output_path, "Convolved items (" .. tostring(output_channels) .. "ch)", source.position, output_channels)
  reaper.Undo_EndBlock("Convolve selected items", -1)
  cleanup_temp()
  if not item then mc.show_error(err or "Could not insert output item.") return end

  log_lines[#log_lines + 1] = "Convolution paths: " .. tostring(#plan)
  log_lines[#log_lines + 1] = "Output channels: " .. tostring(output_channels)
  log_lines[#log_lines + 1] = "Inserted track gain: -6.0 dB"
  log_lines[#log_lines + 1] = "Sample rate: " .. tostring(sample_rate) .. " Hz"
  log_lines[#log_lines + 1] = string.format("NumPy time: %.2f sec", python_elapsed)
  log_lines[#log_lines + 1] = string.format("Total time: %.2f sec", reaper.time_precise() - total_start)
  log_lines[#log_lines + 1] = "Peak build: requested for selected output item"
  log_lines[#log_lines + 1] = "Output: " .. output_path
  if normalize then log_lines[#log_lines + 1] = "Peak normalize: " .. tostring(normalize_db) .. " dB" end
  mc.print_plan("Convolve selected items", log_lines)
end

local function main()
  local entries = selected_audio_entries()
  if #entries < 2 then
    mc.show_error("Select two audio media items: source first in the project, impulse second. Use Swap if needed.")
    return
  end

  local ctx = ImGui.CreateContext("Convolve selected items")
  local open = true
  local mode = MODE_MATCHED_WRAP
  local tail_mode = TAIL_FULL
  local normalize = true
  local normalize_db = -6.0
  local wet_gain_db = 0.0
  local swap = false
  local should_render = false

  local function loop()
    ImGui.SetNextWindowSize(ctx, 520, 330, ImGui.Cond_FirstUseEver)
    local visible
    visible, open = ImGui.Begin(ctx, "Convolve selected items", open)
    if visible then
      local source = swap and entries[2] or entries[1]
      local impulse = swap and entries[1] or entries[2]
      local plan, output_channels = channel_plan(source.channels, impulse.channels, mode)
      ImGui.Text(ctx, "Source: " .. source.name .. "  (" .. tostring(source.channels) .. " ch)")
      ImGui.Text(ctx, "Impulse: " .. impulse.name .. "  (" .. tostring(impulse.channels) .. " ch)")
      if ImGui.Button(ctx, "Swap source / impulse") then swap = not swap end
      ImGui.Spacing(ctx)
      local changed
      changed, mode = draw_combo(ctx, "Channel mode", mode, MODE_NAMES, MODE_MATCHED_WRAP, MODE_MATRIX)
      changed, tail_mode = draw_combo(ctx, "Output length", tail_mode, TAIL_NAMES, TAIL_FULL, TAIL_TRIM)
      changed, wet_gain_db = ImGui.SliderDouble(ctx, "Pre-normalize gain dB", wet_gain_db, -36, 12, "%.1f")
      changed, normalize = ImGui.Checkbox(ctx, "Peak normalize", normalize)
      if normalize then
        changed, normalize_db = ImGui.SliderDouble(ctx, "Normalize peak dB", normalize_db, -24, 0, "%.1f")
      end
      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Spacing(ctx)
      ImGui.Text(ctx, "Convolution paths: " .. tostring(#plan))
      ImGui.Text(ctx, "Output channels: " .. tostring(output_channels))
      if output_channels > mc.MAX_REAPER_TRACK_CHANNELS then
        ImGui.Text(ctx, "Too many output channels for REAPER.")
      else
        ImGui.Text(ctx, "Renders offline from WAV media with NumPy.")
      end
      if ImGui.Button(ctx, "Render", 92, 26) and output_channels <= mc.MAX_REAPER_TRACK_CHANNELS then
        should_render = true
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 92, 26) then open = false end
      ImGui.End(ctx)
    end

    if should_render then
      open = false
      run_convolution(entries[1], entries[2], mode, tail_mode, normalize, normalize_db, wet_gain_db, swap)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
