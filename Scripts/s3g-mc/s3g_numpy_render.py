#!/usr/bin/env python3
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
    if data.ndim == 1:
        data = data[:, None]
    channels = int(data.shape[1])
    clipped = np.clip(np.nan_to_num(data, nan=0.0, posinf=0.0, neginf=0.0), -1.0, 1.0)
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
    payload = bytes(payload)
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
        handle.write(payload)


def segment(data, source_rate, start_seconds, duration_seconds, target_rate):
    start = max(0, int(round(float(start_seconds) * source_rate)))
    count = max(1, int(round(float(duration_seconds) * source_rate)))
    out = data[start:start + count]
    if out.size == 0:
        return np.zeros((1, data.shape[1]), dtype=np.float32)
    if source_rate != target_rate and out.shape[0] > 1:
        old_x = np.arange(out.shape[0], dtype=np.float64)
        new_size = max(1, int(round(out.shape[0] * target_rate / source_rate)))
        new_x = np.linspace(0, out.shape[0] - 1, new_size, dtype=np.float64)
        out = np.stack([np.interp(new_x, old_x, out[:, ch]).astype(np.float32) for ch in range(out.shape[1])], axis=1)
    return out.astype(np.float32)


def normalize_peak(audio, db):
    peak = float(np.max(np.abs(audio))) if audio.size else 0.0
    if peak > 1e-12:
        audio = audio * ((10.0 ** (float(db) / 20.0)) / peak)
    return audio.astype(np.float32), peak


def mean_neighbor_correlation(audio):
    if audio.ndim < 2 or audio.shape[1] < 2 or audio.shape[0] < 8:
        return 0.0
    values = []
    for ch in range(audio.shape[1]):
        a = audio[:, ch]
        b = audio[:, (ch + 1) % audio.shape[1]]
        a = a - float(np.mean(a))
        b = b - float(np.mean(b))
        denom = math.sqrt(float(np.sum(a * a) * np.sum(b * b))) + 1e-12
        values.append(float(np.sum(a * b)) / denom)
    return float(np.mean(values)) if values else 0.0


def parse_envelope(text):
    points = []
    for part in str(text or "").split(";"):
        if ":" not in part:
            continue
        x, y = part.split(":", 1)
        try:
            points.append((float(x), float(y)))
        except ValueError:
            pass
    if len(points) < 2:
        return None
    points.sort(key=lambda p: p[0])
    return np.array(points, dtype=np.float64)


def env_value(cfg, key, x, default):
    env = parse_envelope(cfg.get("env_" + key, ""))
    if env is None:
        return float(default)
    x = float(np.clip(x, 0.0, 1.0))
    y = float(np.interp(x, env[:, 0], env[:, 1]))
    return float(y)


def apply_output_envelope(audio, cfg, key="amplitude"):
    env = parse_envelope(cfg.get("env_" + key, ""))
    if env is None or audio.size == 0:
        return audio
    x = np.linspace(0.0, 1.0, audio.shape[0], dtype=np.float64)
    values = np.interp(x, env[:, 0], env[:, 1]).astype(np.float32)
    return (audio * values[:, None]).astype(np.float32)


def env_array(cfg, key, frames, default):
    env = parse_envelope(cfg.get("env_" + key, ""))
    if env is None or frames <= 0:
        return np.full(max(1, frames), float(default), dtype=np.float32)
    x = np.linspace(0.0, 1.0, frames, dtype=np.float64)
    return np.interp(x, env[:, 0], env[:, 1]).astype(np.float32)


def pan_weights(position, channels, width):
    position = float(np.clip(position, 0.0, max(0, channels - 1)))
    width = max(0.001, float(width))
    idx = np.arange(channels, dtype=np.float64)
    d = np.abs(idx - position)
    d = np.minimum(d, channels - d)
    weights = np.exp(-(d * d) / (2.0 * width * width))
    weights /= math.sqrt(float(np.sum(weights * weights)) + 1e-12)
    return weights.astype(np.float32)


def render_dense_grain(cfg):
    sample_rate = int(cfg.get("sample_rate", 48000))
    source, source_rate = read_wav(cfg["source_path"])
    source = segment(source, source_rate, cfg.get("source_start", 0.0), cfg.get("source_duration", 1.0), sample_rate)
    source = source - np.mean(source, axis=0, keepdims=True)
    channels = int(cfg["channels"])
    duration = float(cfg["duration"])
    frames = max(1, int(round(duration * sample_rate)))
    out = np.zeros((frames, channels), dtype=np.float32)
    grains = int(cfg["grains"])
    grain_ms = float(cfg["grain_ms"])
    grain_jitter = float(cfg.get("grain_jitter", 0.6))
    pitch_scatter = float(cfg["pitch_scatter"])
    spread = float(cfg["spread"])
    density = float(cfg.get("density", 1.0))
    channel_contrast = float(cfg.get("channel_contrast", 0.75))
    source_bias = float(cfg.get("source_bias", 0.55))
    density_shape = float(cfg.get("density_shape", 0.0))
    rng = np.random.default_rng(int(cfg.get("seed", 1)))
    max_source_start = max(1, source.shape[0] - 2)
    accepted = 0
    for _ in range(grains):
        center = rng.random()
        if density_shape < -0.05:
            t = duration * (center ** (1.0 + abs(density_shape) * 3.0))
        elif density_shape > 0.05:
            t = duration * (1.0 - ((1.0 - center) ** (1.0 + density_shape * 3.0)))
        else:
            t = duration * center
        event_u = t / max(0.000001, duration)
        local_density = env_value(cfg, "density", event_u, density)
        local_density = float(np.clip(local_density, 0.0, 1.0))
        if rng.random() > local_density:
            continue
        local_spread = env_value(cfg, "spread", event_u, spread)
        local_pitch_scatter = env_value(cfg, "pitch_scatter", event_u, pitch_scatter)
        glen = max(8, int(round((grain_ms / 1000.0) * sample_rate * rng.uniform(1.0 - grain_jitter, 1.0 + grain_jitter))))
        rate = 2.0 ** rng.uniform(-local_pitch_scatter, local_pitch_scatter)
        src_len = max(2, int(math.ceil(glen * rate)) + 2)
        pos = rng.random() * max(0, channels - 1)
        primary_channel = int(round(pos)) % max(1, channels)
        source_u = (rng.random() * (1.0 - source_bias) + (primary_channel / max(1, channels)) * source_bias) % 1.0
        src_start = int(source_u * max(1, max_source_start - src_len))
        src_channel = (primary_channel + int(rng.integers(0, max(1, source.shape[1])))) % source.shape[1]
        src = source[src_start:src_start + src_len, src_channel]
        if src.size < 2:
            continue
        x = np.linspace(0, src.size - 1, glen)
        grain = np.interp(x, np.arange(src.size), src).astype(np.float32)
        grain *= np.hanning(glen).astype(np.float32)
        start = int(round(t * sample_rate)) - glen // 2
        if start >= frames or start + glen <= 0:
            continue
        g0 = max(0, -start)
        g1 = min(glen, frames - start)
        weights = pan_weights(pos, channels, local_spread)
        if channel_contrast > 0.001:
            power = 1.0 + channel_contrast * 8.0
            weights = np.power(weights, power)
            weights /= math.sqrt(float(np.sum(weights * weights)) + 1e-12)
        out[start + g0:start + g1, :] += grain[g0:g1, None] * weights[None, :]
        accepted += 1
    out *= float(cfg.get("gain", 1.0)) / math.sqrt(max(1.0, grains / 160.0))
    out = apply_output_envelope(out, cfg, "amplitude")
    corr = mean_neighbor_correlation(out)
    if cfg.get("normalize", True):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -6.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out, sample_rate)
    print(f"Dense grain cloud grains: {grains}")
    print(f"Accepted grains: {accepted}")
    print(f"Density: {density:.3f}")
    print(f"Output channels: {channels}")
    print(f"Spatial spread: {spread:.3f}")
    print(f"Channel contrast: {channel_contrast:.3f}")
    print(f"Source bias: {source_bias:.3f}")
    print(f"Mean neighbor correlation: {corr:.3f}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")


def interpolated_read(channel, positions):
    size = int(channel.shape[0])
    wrapped = np.mod(positions, size)
    idx0 = np.floor(wrapped).astype(np.int64)
    frac = (wrapped - idx0).astype(np.float32)
    idx1 = (idx0 + 1) % size
    return (channel[idx0] * (1.0 - frac) + channel[idx1] * frac).astype(np.float32)


def seamless_loop_read(channel, positions, xfade_frames, xfade_duck=0.12):
    size = int(channel.shape[0])
    if size < 2:
        return np.zeros(positions.shape[0], dtype=np.float32)
    xfade_frames = int(min(max(0, xfade_frames), max(0, (size - 2) // 2)))
    if xfade_frames <= 1:
        return interpolated_read(channel, positions)
    period = max(2, size - xfade_frames)
    phase = np.mod(positions, period)
    normal = interpolated_read(channel, phase)
    overlap = phase < xfade_frames
    if np.any(overlap):
        u = (phase[overlap] / max(1, xfade_frames)).astype(np.float32)
        head = interpolated_read(channel, phase[overlap])
        tail = interpolated_read(channel, phase[overlap] + period)
        fade_in = 0.5 - 0.5 * np.cos(np.pi * u)
        fade_out = 1.0 - fade_in
        duck = 1.0 - float(np.clip(xfade_duck, 0.0, 0.75)) * np.sin(np.pi * u)
        normal[overlap] = (tail * fade_out + head * fade_in) * duck
    return normal.astype(np.float32)


def load_source_pool(cfg, sample_rate):
    count = max(1, int(cfg.get("source_count", 1)))
    pool = []
    for index in range(count):
        suffix = "" if index == 0 else f"_{index + 1}"
        path = cfg.get("source_path" + suffix, cfg.get("source_path"))
        start = cfg.get("source_start" + suffix, cfg.get("source_start", 0.0))
        duration = cfg.get("source_duration" + suffix, cfg.get("source_duration", 1.0))
        data, source_rate = read_wav(path)
        audio = segment(data, source_rate, start, duration, sample_rate)
        if audio.shape[0] < 16:
            continue
        audio = audio - np.mean(audio, axis=0, keepdims=True)
        pool.append({
            "audio": audio,
            "mono": np.mean(audio, axis=1).astype(np.float32),
            "channels": int(audio.shape[1]),
            "path": path,
        })
    if not pool:
        raise RuntimeError("No selected source segment was long enough to loop.")
    return pool


def source_pool_index(mode, dst, group_start, source_count, rng):
    if source_count <= 1 or mode == "first":
        return 0
    if mode == "item_per_group":
        return (group_start if group_start is not None else dst) % source_count
    if mode == "random_channel":
        return int(rng.integers(0, source_count))
    return dst % source_count


def source_channel_index(distribution, source_channels, dst, rng):
    if distribution == "mono_sum":
        return -1
    if distribution == "mirror":
        period = max(1, source_channels * 2 - 2)
        pos = dst % period
        return pos if pos < source_channels else period - pos
    if distribution == "random":
        return int(rng.integers(0, source_channels))
    if distribution == "paired":
        return (dst // 2) % source_channels
    return dst % source_channels


def render_loop_drift_bed(cfg):
    sample_rate = int(cfg.get("sample_rate", 48000))
    source_pool = load_source_pool(cfg, sample_rate)
    source_count = len(source_pool)
    channels = int(cfg["channels"])
    duration = float(cfg["duration"])
    frames = max(1, int(round(duration * sample_rate)))
    out = np.zeros((frames, channels), dtype=np.float32)
    base_rate = float(cfg.get("base_rate", 1.0))
    rate_amount = float(cfg.get("rate_amount", 0.08))
    rate_mode = str(cfg.get("rate_mode", "deviation"))
    rate_quantize = str(cfg.get("rate_quantize", "free"))
    distribution = str(cfg.get("distribution", "cycle"))
    source_mode = str(cfg.get("source_mode", "cycle_items"))
    source_group_size = max(1, int(cfg.get("source_group_size", 4)))
    phase_mode = str(cfg.get("phase_mode", "even"))
    direction_mode = str(cfg.get("direction_mode", "forward"))
    reverse_probability = float(cfg.get("reverse_probability", 0.0))
    start_jitter_ms = float(cfg.get("start_jitter_ms", 0.0))
    drift_amount = float(cfg.get("drift_amount", 0.0))
    spread = float(cfg.get("spatial_spread", 0.0))
    gain_variation_db = float(cfg.get("gain_variation_db", 0.0))
    output_motion = float(cfg.get("output_motion", 0.0))
    gain = float(cfg.get("gain", 0.85))
    xfade_frames = int(round(float(cfg.get("xfade_ms", 80.0)) * sample_rate / 1000.0))
    xfade_duck = float(cfg.get("xfade_duck", 0.12))
    rng = np.random.default_rng(int(cfg.get("seed", 1)))
    t = np.arange(frames, dtype=np.float64)
    time_u = np.linspace(0.0, 1.0, frames, dtype=np.float32)
    rate_amount_env = env_array(cfg, "rate_amount", frames, rate_amount)
    drift_amount_env = env_array(cfg, "drift_amount", frames, drift_amount)
    spread_env = env_array(cfg, "spatial_spread", frames, spread)
    gain_var_env = env_array(cfg, "gain_variation_db", frames, gain_variation_db)
    motion_env = env_array(cfg, "output_motion", frames, output_motion)

    channel_rates = []
    rate_offsets = []
    source_items = []
    source_maps = []
    directions = []
    gain_offsets_db = []
    motion_offsets = []
    start_jitter_frames = max(0.0, start_jitter_ms * sample_rate / 1000.0)
    ratio_choices = np.array([0.5, 2.0 / 3.0, 0.75, 1.0, 4.0 / 3.0, 1.5, 2.0], dtype=np.float64)

    def quantize_rate(rate):
        if rate_quantize == "semitone":
            return 2.0 ** (round(12.0 * math.log(max(0.000001, rate) / base_rate, 2.0)) / 12.0) * base_rate
        if rate_quantize == "quartertone":
            return 2.0 ** (round(24.0 * math.log(max(0.000001, rate) / base_rate, 2.0)) / 24.0) * base_rate
        if rate_quantize == "simple_ratios":
            return float(ratio_choices[np.argmin(np.abs(ratio_choices * base_rate - rate))] * base_rate)
        return rate

    for dst in range(channels):
        u = dst / max(1, channels - 1)
        if rate_mode == "spread":
            offset = u * 2.0 - 1.0
        elif rate_mode == "ascending":
            offset = u
        elif rate_mode == "descending":
            offset = 1.0 - u
        elif rate_mode == "random_steps":
            choices = np.array([-1.0, -0.5, -0.25, 0.0, 0.25, 0.5, 1.0], dtype=np.float64)
            offset = float(rng.choice(choices))
        else:
            offset = rng.uniform(-1.0, 1.0)
        rate_offsets.append(float(offset))
        rate = quantize_rate(base_rate * (1.0 + offset * rate_amount))
        channel_rates.append(max(0.05, float(rate)))
        if direction_mode == "reverse":
            directions.append(-1.0)
        elif direction_mode == "alternating":
            directions.append(-1.0 if (dst % 2) == 1 else 1.0)
        elif direction_mode == "mirror_pairs":
            directions.append(-1.0 if ((dst // 2) % 2) == 1 else 1.0)
        elif direction_mode == "random":
            directions.append(-1.0 if rng.random() < reverse_probability else 1.0)
        else:
            directions.append(1.0)
        gain_offsets_db.append(rng.uniform(-1.0, 1.0))
        motion_offsets.append(rng.uniform(0.0, 2.0 * math.pi))

        group_start = (dst // source_group_size) * source_group_size
        item_index = source_pool_index(source_mode, dst, group_start, source_count, rng)
        source_items.append(item_index)
        src = source_pool[item_index]
        source_maps.append(source_channel_index(distribution, src["channels"], dst, rng))

    for dst in range(channels):
        layer_indices = list(range(source_count)) if source_mode == "layer_all" else [source_items[dst]]
        if phase_mode == "random":
            phase_unit = rng.random()
        elif phase_mode == "aligned":
            phase_unit = 0.0
        else:
            phase_unit = dst / max(1, channels)
        if start_jitter_frames > 0.0:
            phase_jitter = rng.uniform(-start_jitter_frames, start_jitter_frames)
        else:
            phase_jitter = 0.0
        rate = channel_rates[dst]
        if rate_quantize == "free":
            rate_curve = base_rate * (1.0 + rate_offsets[dst] * rate_amount_env.astype(np.float64))
            rate_curve = np.maximum(0.05, rate_curve)
        else:
            rate_curve = np.full(frames, rate, dtype=np.float64)
        if np.max(np.abs(drift_amount_env)) > 0.0001:
            drift_freq = rng.uniform(0.015, 0.09)
            drift_phase = rng.uniform(0.0, 2.0 * math.pi)
            drift = 1.0 + drift_amount_env.astype(np.float64) * np.sin(2.0 * math.pi * drift_freq * t / sample_rate + drift_phase)
            positions = np.cumsum(rate_curve * drift * directions[dst])
        else:
            positions = np.cumsum(rate_curve * directions[dst])
        loop_mix = np.zeros(frames, dtype=np.float32)
        for layer_index in layer_indices:
            src = source_pool[layer_index]
            local_xfade = int(min(max(0, xfade_frames), max(0, (src["audio"].shape[0] - 2) // 2)))
            loop_period = max(2, src["audio"].shape[0] - local_xfade)
            phase = phase_unit * loop_period + phase_jitter
            local_positions = positions + phase
            ch_index = source_channel_index(distribution, src["channels"], dst + layer_index, rng) if source_mode == "layer_all" else source_maps[dst]
            source_channel = src["mono"] if ch_index < 0 else src["audio"][:, ch_index]
            loop_mix += seamless_loop_read(source_channel, local_positions, local_xfade, xfade_duck)
        loop = loop_mix / math.sqrt(max(1.0, len(layer_indices)))
        gain_curve = gain * (10.0 ** ((gain_offsets_db[dst] * gain_var_env.astype(np.float64)) / 20.0))
        gain_curve /= math.sqrt(max(1.0, channels / 2.0))
        if (np.max(spread_env) > 0.001 or np.max(motion_env) > 0.001) and channels > 1:
            block = 1024
            speed = rng.uniform(0.35, 1.35)
            phase_offset = motion_offsets[dst]
            for start in range(0, frames, block):
                end = min(frames, start + block)
                mid = (start + end - 1) * 0.5 / max(1, frames - 1)
                local_spread = float(spread_env[min(frames - 1, (start + end) // 2)])
                local_motion = float(motion_env[min(frames - 1, (start + end) // 2)])
                pos = dst + math.sin(2.0 * math.pi * speed * mid + phase_offset) * local_motion * max(1.0, channels * 0.20)
                width = 0.08 + local_spread * max(1.0, channels * 0.08)
                weights = pan_weights(pos, channels, width)
                out[start:end, :] += loop[start:end, None] * weights[None, :] * gain_curve[start:end, None]
        else:
            out[:, dst] += loop * gain_curve.astype(np.float32)

    out = apply_output_envelope(out, cfg, "amplitude")
    corr = mean_neighbor_correlation(out)
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -6.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out, sample_rate)
    print(f"Sources: {source_count}")
    print(f"Output channels: {channels}")
    print(f"Duration: {duration:.3f} sec")
    print(f"Rate mode: {rate_mode}")
    print(f"Rate quantize: {rate_quantize}")
    print(f"Base rate: {base_rate:.5f}")
    print(f"Rate amount: {rate_amount:.5f}")
    print(f"Distribution: {distribution}")
    print(f"Source mode: {source_mode}")
    print(f"Source group size: {source_group_size}")
    print(f"Phase mode: {phase_mode}")
    print(f"Direction mode: {direction_mode}")
    print(f"Reverse probability: {reverse_probability:.3f}")
    print(f"Start jitter: {start_jitter_ms:.2f} ms")
    print(f"Crossfade: {1000.0 * xfade_frames / sample_rate:.2f} ms")
    print(f"Crossfade duck: {xfade_duck:.3f}")
    print(f"Spatial spread: {spread:.3f}")
    print(f"Gain variation: {gain_variation_db:.2f} dB")
    print(f"Output motion: {output_motion:.3f}")
    print(f"Rate min/max: {min(channel_rates):.5f} / {max(channel_rates):.5f}")
    print(f"Mean neighbor correlation: {corr:.3f}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")


def render_loop_rift(cfg):
    sample_rate = int(cfg.get("sample_rate", 48000))
    source_pool = load_source_pool(cfg, sample_rate)
    source_count = len(source_pool)
    channels = int(cfg["channels"])
    duration = float(cfg["duration"])
    frames = max(1, int(round(duration * sample_rate)))
    base_rate = float(cfg.get("base_rate", 1.0))
    rate_amount = float(cfg.get("rate_amount", 0.08))
    rate_mode = str(cfg.get("rate_mode", "deviation"))
    distribution = str(cfg.get("distribution", "cycle"))
    source_mode = str(cfg.get("source_mode", "random_section"))
    phase_mode = str(cfg.get("phase_mode", "even"))
    direction_mode = str(cfg.get("direction_mode", "forward"))
    reverse_probability = float(cfg.get("reverse_probability", 0.0))
    rift_density = float(cfg.get("rift_density", 0.8))
    section_ms = float(cfg.get("section_ms", cfg.get("gap_ms", 650.0)))
    min_section_ms = float(cfg.get("min_section_ms", 140.0))
    rate_instability = float(cfg.get("rate_instability", 0.035))
    fade_ms = float(cfg.get("fade_ms", cfg.get("repair_ms", 28.0)))
    fill_mode = str(cfg.get("fill_mode", "silence"))
    group_size = max(1, int(cfg.get("group_size", 1)))
    gain = float(cfg.get("gain", 0.85))
    xfade_frames = int(round(float(cfg.get("xfade_ms", 80.0)) * sample_rate / 1000.0))
    xfade_duck = float(cfg.get("xfade_duck", 0.12))
    rng = np.random.default_rng(int(cfg.get("seed", 1)))
    t = np.arange(frames, dtype=np.float64)

    rift_density_env = env_array(cfg, "rift_density", frames, rift_density)
    section_env = env_array(cfg, "section_ms", frames, section_ms)
    rate_instability_env = env_array(cfg, "rate_instability", frames, rate_instability)
    fade_env = env_array(cfg, "fade_ms", frames, fade_ms)
    amplitude_env = env_array(cfg, "amplitude", frames, 1.0)

    rate_offsets = []
    source_items = []
    source_maps = []
    directions = []
    for dst in range(channels):
        u = dst / max(1, channels - 1)
        if rate_mode == "spread":
            offset = u * 2.0 - 1.0
        elif rate_mode == "ascending":
            offset = u
        elif rate_mode == "descending":
            offset = 1.0 - u
        elif rate_mode == "random_steps":
            choices = np.array([-1.0, -0.5, -0.25, 0.0, 0.25, 0.5, 1.0], dtype=np.float64)
            offset = float(rng.choice(choices))
        else:
            offset = rng.uniform(-1.0, 1.0)
        rate_offsets.append(offset)
        if direction_mode == "reverse":
            directions.append(-1.0)
        elif direction_mode == "alternating":
            directions.append(-1.0 if (dst % 2) == 1 else 1.0)
        elif direction_mode == "random":
            directions.append(-1.0 if rng.random() < reverse_probability else 1.0)
        else:
            directions.append(1.0)

        group_start = (dst // group_size) * group_size
        item_index = source_pool_index(source_mode, dst, group_start, source_count, rng)
        source_items.append(item_index)
        src = source_pool[item_index]
        source_maps.append(source_channel_index(distribution, src["channels"], dst, rng))

    loops = np.zeros((frames, channels), dtype=np.float32)
    gap_masks = np.ones((frames, channels), dtype=np.float32)
    total_sections = 0
    for group_start in range(0, channels, group_size):
        group_end = min(channels, group_start + group_size)
        estimated = max(0.0, duration * float(np.mean(rift_density_env)))
        section_count = int(rng.poisson(estimated))
        if estimated > 0.05 and section_count < 1:
            section_count = 1
        sections = []
        for _ in range(section_count):
            start = int(rng.integers(0, max(1, frames)))
            section_len = int(round(float(section_env[start]) * sample_rate / 1000.0 * rng.uniform(0.75, 1.45)))
            min_len = int(round(min_section_ms * sample_rate / 1000.0))
            section_len = max(max(16, min_len), section_len)
            fade = max(2, int(round(float(fade_env[start]) * sample_rate / 1000.0)))
            end = min(frames, start + section_len)
            if end - start >= max(16, min_len):
                sections.append((start, end, fade))
        sections.sort(key=lambda item: item[0])
        total_sections += len(sections) * (group_end - group_start)

        for dst in range(group_start, group_end):
            phase_unit = rng.random() if phase_mode == "random" else (0.0 if phase_mode == "aligned" else dst / max(1, channels))
            rate = max(0.05, base_rate * (1.0 + rate_offsets[dst] * rate_amount))
            instability = rate_instability_env.astype(np.float64)
            if np.max(instability) > 0.0001:
                control_count = max(4, int(math.ceil(duration / 0.35)) + 2)
                control_x = np.linspace(0.0, frames - 1, control_count)
                control_y = rng.normal(0.0, 1.0, control_count)
                for _ in range(2):
                    control_y[1:-1] = (control_y[:-2] + control_y[1:-1] * 2.0 + control_y[2:]) / 4.0
                wobble = np.interp(np.arange(frames), control_x, control_y)
                rate_curve = rate * (1.0 + wobble * instability)
                rate_curve = np.maximum(0.025, rate_curve)
            else:
                rate_curve = np.full(frames, rate, dtype=np.float64)
            positions = np.cumsum(rate_curve * directions[dst])
            layer_indices = list(range(source_count)) if source_mode == "layer_all" else [source_items[dst]]
            loop_mix = np.zeros(frames, dtype=np.float32)
            for layer_index in layer_indices:
                src = source_pool[layer_index]
                local_xfade = int(min(max(0, xfade_frames), max(0, (src["audio"].shape[0] - 2) // 2)))
                loop_period = max(2, src["audio"].shape[0] - local_xfade)
                phase = phase_unit * loop_period
                ch_index = source_channel_index(distribution, src["channels"], dst + layer_index, rng) if source_mode == "layer_all" else source_maps[dst]
                source_channel = src["mono"] if ch_index < 0 else src["audio"][:, ch_index]
                loop_mix += seamless_loop_read(source_channel, positions + phase, local_xfade, xfade_duck)
            loop = loop_mix / math.sqrt(max(1.0, len(layer_indices)))
            mask = np.zeros(frames, dtype=np.float32)
            section_sources = []
            for start, end, fade in sections:
                if end <= start:
                    continue
                length = end - start
                local = np.ones(length, dtype=np.float32)
                local_fade = min(fade, max(2, length // 3))
                if local_fade > 1:
                    ramp_in = 0.5 - 0.5 * np.cos(np.linspace(0.0, math.pi, local_fade, dtype=np.float32))
                    ramp_out = ramp_in[::-1]
                    local[:local_fade] *= ramp_in
                    local[-local_fade:] *= ramp_out
                mask[start:end] = np.maximum(mask[start:end], local)
                if source_mode == "random_section" and source_count > 1:
                    section_sources.append((start, end, int(rng.integers(0, source_count)), local.copy()))
            loop = loop * mask
            if section_sources:
                loop = np.zeros(frames, dtype=np.float32)
                for start, end, item_index, local in section_sources:
                    src = source_pool[item_index]
                    local_xfade = int(min(max(0, xfade_frames), max(0, (src["audio"].shape[0] - 2) // 2)))
                    loop_period = max(2, src["audio"].shape[0] - local_xfade)
                    phase = phase_unit * loop_period
                    ch_index = source_channel_index(distribution, src["channels"], dst + item_index, rng)
                    source_channel = src["mono"] if ch_index < 0 else src["audio"][:, ch_index]
                    loop[start:end] += seamless_loop_read(source_channel, positions[start:end] + phase, local_xfade, xfade_duck) * local
            loops[:, dst] = loop
            gap_masks[:, dst] = mask

    if fill_mode == "neighbor_bleed" and channels > 1:
        bled = loops.copy()
        for ch in range(channels):
            neighbor = loops[:, (ch - 1) % channels] * 0.55 + loops[:, (ch + 1) % channels] * 0.45
            bled[:, ch] = loops[:, ch] * gap_masks[:, ch] + neighbor * (1.0 - gap_masks[:, ch])
        loops = bled

    out = loops * (gain / math.sqrt(max(1.0, channels / 2.0)))
    out *= amplitude_env[:, None]
    corr = mean_neighbor_correlation(out)
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -6.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out, sample_rate)
    print(f"Sources: {source_count}")
    print(f"Output channels: {channels}")
    print(f"Duration: {duration:.3f} sec")
    print(f"Rate mode: {rate_mode}")
    print(f"Distribution: {distribution}")
    print(f"Source mode: {source_mode}")
    print(f"Direction mode: {direction_mode}")
    print(f"Sections opened: {total_sections}")
    print(f"Section density: {rift_density:.3f}")
    print(f"Section length: {section_ms:.2f} ms")
    print(f"Minimum section: {min_section_ms:.2f} ms")
    print(f"Rate instability: {rate_instability:.4f}")
    print(f"Fade: {fade_ms:.2f} ms")
    print(f"Fill mode: {fill_mode}")
    print(f"Group size: {group_size}")
    print(f"Mean neighbor correlation: {corr:.3f}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")


def render_ir_toolkit(cfg):
    sample_rate = int(cfg.get("sample_rate", 48000))
    data, source_rate = read_wav(cfg["source_path"])
    audio = segment(data, source_rate, cfg.get("source_start", 0.0), cfg.get("source_duration", 1.0), sample_rate)
    threshold = 10.0 ** (float(cfg.get("trim_db", -70.0)) / 20.0)
    mono = np.max(np.abs(audio), axis=1)
    active = np.where(mono > threshold)[0]
    if bool(cfg.get("trim", True)) and active.size:
        pad = int(round(float(cfg.get("pad_ms", 5.0)) * sample_rate / 1000.0))
        start = max(0, int(active[0]) - pad)
        end = min(audio.shape[0], int(active[-1]) + pad + 1)
        audio = audio[start:end]
    if bool(cfg.get("early_reflections", False)):
        count = int(cfg.get("reflection_count", 12))
        rng = np.random.default_rng(int(cfg.get("seed", 1)))
        extra = int(round(float(cfg.get("reflection_ms", 120.0)) * sample_rate / 1000.0))
        wet = np.zeros((audio.shape[0] + extra, audio.shape[1]), dtype=np.float32)
        wet[:audio.shape[0], :] += audio
        for _ in range(count):
            delay = int(rng.integers(16, max(17, extra)))
            gain = rng.uniform(0.08, 0.45) * math.exp(-delay / max(1.0, extra * 0.55))
            src_ch = int(rng.integers(0, audio.shape[1]))
            dst_ch = int(rng.integers(0, audio.shape[1]))
            wet[delay:delay + audio.shape[0], dst_ch] += audio[:, src_ch] * gain
        audio = wet
    decor = float(cfg.get("decorrelate", 0.0))
    if decor > 0.001 and audio.shape[1] > 1:
        rng = np.random.default_rng(int(cfg.get("seed", 1)) + 31)
        wet = audio.copy()
        max_delay = max(1, int(round(float(cfg.get("decor_ms", 18.0)) * sample_rate / 1000.0)))
        for ch in range(audio.shape[1]):
            delay = int(rng.integers(1, max_delay + 1))
            shifted = np.zeros(audio.shape[0], dtype=np.float32)
            shifted[delay:] = audio[:-delay, ch]
            wet[:, ch] = audio[:, ch] * (1.0 - decor) + shifted * decor * rng.choice([-1.0, 1.0])
        audio = wet
    fade = int(round(float(cfg.get("tail_fade_ms", 25.0)) * sample_rate / 1000.0))
    if fade > 1 and audio.shape[0] > fade:
        audio[-fade:, :] *= np.linspace(1.0, 0.0, fade, dtype=np.float32)[:, None]
    if bool(cfg.get("normalize", True)):
        audio, pre_peak = normalize_peak(audio, float(cfg.get("normalize_db", -6.0)))
    else:
        pre_peak = float(np.max(np.abs(audio))) if audio.size else 0.0
    write_pcm24_wav(cfg["output_path"], audio, sample_rate)
    print(f"IR toolkit output frames: {audio.shape[0]}")
    print(f"Output channels: {audio.shape[1]}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")


def render_mass_partial(cfg):
    sample_rate = int(cfg.get("sample_rate", 48000))
    duration = float(cfg["duration"])
    channels = int(cfg["channels"])
    frames = max(1, int(round(duration * sample_rate)))
    out = np.zeros((frames, channels), dtype=np.float32)
    partials = int(cfg["partials"])
    base = float(cfg["base_freq"])
    spread_oct = float(cfg["spread_oct"])
    event_ms = float(cfg["event_ms"])
    drift = float(cfg["drift"])
    brightness = float(cfg["brightness"])
    spatial_width = float(cfg["spatial_width"])
    density = float(cfg.get("density", 1.0))
    rng = np.random.default_rng(int(cfg.get("seed", 1)))
    accepted = 0
    for _ in range(partials):
        start = int(rng.integers(0, max(1, frames)))
        event_u = start / max(1, frames - 1)
        local_density = env_value(cfg, "density", event_u, density)
        local_density = float(np.clip(local_density, 0.0, 1.0))
        if rng.random() > local_density:
            continue
        local_drift = env_value(cfg, "drift", event_u, drift)
        local_brightness = env_value(cfg, "brightness", event_u, brightness)
        local_spatial_width = env_value(cfg, "spatial_width", event_u, spatial_width)
        local_event_ms = env_value(cfg, "event_ms", event_u, event_ms)
        length = max(64, int(round(local_event_ms * sample_rate / 1000.0 * rng.uniform(0.45, 1.8))))
        if start + length > frames:
            length = frames - start
        if length < 16:
            continue
        harmonic = rng.choice([1, 2, 3, 4, 5, 7, 9, 11])
        freq = base * harmonic * (2.0 ** rng.uniform(-spread_oct, spread_oct))
        freq = float(np.clip(freq, 18.0, sample_rate * 0.42))
        bend = 1.0 + local_drift * rng.uniform(-1.0, 1.0) * np.linspace(0.0, 1.0, length)
        phase = 2.0 * math.pi * np.cumsum(freq * bend) / sample_rate + rng.uniform(0, 2 * math.pi)
        env = np.sin(np.linspace(0, math.pi, length)) ** rng.uniform(1.2, 3.8)
        amp = (0.12 / math.sqrt(max(1.0, partials / 80.0))) * (harmonic ** (-local_brightness))
        tone = (np.sin(phase) * env * amp).astype(np.float32)
        pos0 = rng.random() * max(0, channels - 1)
        pos1 = np.clip(pos0 + rng.normal(0.0, channels * 0.18), 0.0, max(0, channels - 1))
        w0 = pan_weights(pos0, channels, local_spatial_width)
        w1 = pan_weights(pos1, channels, local_spatial_width)
        u = np.linspace(0.0, 1.0, length, dtype=np.float32)[:, None]
        weights = w0[None, :] * (1.0 - u) + w1[None, :] * u
        weights /= np.sqrt(np.sum(weights * weights, axis=1, keepdims=True) + 1e-12)
        out[start:start + length, :] += tone[:, None] * weights.astype(np.float32, copy=False)
        accepted += 1
    out = apply_output_envelope(out, cfg, "amplitude")
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -6.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out, sample_rate)
    print(f"Partial events: {partials}")
    print(f"Accepted partial events: {accepted}")
    print(f"Density: {density:.3f}")
    print(f"Output channels: {channels}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")


def render_resonant_terrain(cfg):
    sample_rate = int(cfg.get("sample_rate", 48000))
    duration = float(cfg["duration"])
    channels = int(cfg["channels"])
    frames = max(1, int(round(duration * sample_rate)))
    out = np.zeros((frames, channels), dtype=np.float32)
    events = int(cfg["events"])
    resonators = int(cfg["resonators"])
    base = float(cfg["base_freq"])
    spread_oct = float(cfg["spread_oct"])
    decay_ms = float(cfg["decay_ms"])
    strike_ms = float(cfg["strike_ms"])
    inharmonic = float(cfg["inharmonic"])
    roughness = float(cfg["roughness"])
    spatial_width = float(cfg["spatial_width"])
    feedback = float(cfg.get("feedback", 0.2))
    density = float(cfg.get("density", 1.0))
    rng = np.random.default_rng(int(cfg.get("seed", 1)))
    ratios = np.array([1.0, 1.414, 1.618, 2.236, 2.718, 3.142, 4.236, 5.385, 6.854], dtype=np.float64)
    resonator_freqs = []
    for i in range(resonators):
        ratio = ratios[i % ratios.size] * (1.0 + inharmonic * rng.normal(0.0, 0.08))
        freq = base * ratio * (2.0 ** rng.uniform(-spread_oct, spread_oct))
        resonator_freqs.append(float(np.clip(freq, 18.0, sample_rate * 0.43)))
    resonator_freqs = np.array(resonator_freqs, dtype=np.float64)
    strike_len = max(2, int(round(strike_ms * sample_rate / 1000.0)))
    accepted = 0
    for event in range(events):
        t = (event + rng.random() * 0.9) / max(1, events)
        local_density = env_value(cfg, "density", t, density)
        local_density = float(np.clip(local_density, 0.0, 1.0))
        if rng.random() > local_density:
            continue
        start = int(round(t * frames))
        if start >= frames:
            continue
        local_decay_ms = env_value(cfg, "decay_ms", t, decay_ms)
        local_roughness = env_value(cfg, "roughness", t, roughness)
        local_spatial_width = env_value(cfg, "spatial_width", t, spatial_width)
        pos0 = rng.random() * max(0, channels - 1)
        pos1 = np.clip(pos0 + rng.normal(0.0, channels * 0.22), 0.0, max(0, channels - 1))
        picked = rng.choice(resonators, size=max(1, min(4, resonators)), replace=False)
        event_gain = rng.uniform(0.5, 1.0) / math.sqrt(max(1.0, events / 48.0))
        for r_index in picked:
            freq = resonator_freqs[int(r_index)] * (1.0 + local_roughness * rng.normal(0.0, 0.015))
            local_decay = local_decay_ms * rng.uniform(0.45, 1.65)
            length = min(frames - start, max(32, int(round(local_decay * sample_rate / 1000.0 * 3.0))))
            if length <= 16:
                continue
            time = np.arange(length, dtype=np.float64) / sample_rate
            env = np.exp(-time / max(0.001, local_decay / 1000.0))
            strike = np.ones(length, dtype=np.float64)
            attack = min(length, strike_len)
            if attack > 1:
                strike[:attack] = np.linspace(0.0, 1.0, attack)
            phase = rng.uniform(0, 2 * math.pi)
            carrier = np.sin(2.0 * math.pi * freq * time + phase)
            if feedback > 0.001:
                carrier += feedback * np.sin(2.0 * math.pi * freq * (1.0 + rng.uniform(0.006, 0.04)) * time + phase * 0.7)
            tone = (carrier * env * strike * event_gain * 0.09).astype(np.float32)
            w0 = pan_weights(pos0, channels, local_spatial_width)
            w1 = pan_weights(pos1, channels, local_spatial_width)
            u = np.linspace(0.0, 1.0, length, dtype=np.float32)[:, None]
            weights = w0[None, :] * (1.0 - u) + w1[None, :] * u
            weights /= np.sqrt(np.sum(weights * weights, axis=1, keepdims=True) + 1e-12)
            out[start:start + length, :] += tone[:, None] * weights.astype(np.float32, copy=False)
        accepted += 1
    out = apply_output_envelope(out, cfg, "amplitude")
    corr = mean_neighbor_correlation(out)
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -6.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out, sample_rate)
    print(f"Excitation events: {events}")
    print(f"Accepted excitation events: {accepted}")
    print(f"Density: {density:.3f}")
    print(f"Resonators: {resonators}")
    print(f"Output channels: {channels}")
    print(f"Mean neighbor correlation: {corr:.3f}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")


def render_partial_trace_resynth(cfg):
    sample_rate = int(cfg.get("sample_rate", 48000))
    source, source_rate = read_wav(cfg["source_path"])
    source = segment(source, source_rate, cfg.get("source_start", 0.0), cfg.get("source_duration", 1.0), sample_rate)
    if source.shape[0] < 8:
        raise RuntimeError("Selected source segment is too short for partial trace resynthesis.")
    mono = np.mean(source, axis=1).astype(np.float32)
    mono = mono - float(np.mean(mono))
    channels = int(cfg["channels"])
    duration = float(cfg["duration"])
    frames = max(1, int(round(duration * sample_rate)))
    out = np.zeros((frames, channels), dtype=np.float32)
    fft_size = max(128, int(cfg.get("fft_size", 2048)))
    hop = max(16, int(cfg.get("hop", fft_size // 4)))
    partials_per_frame = max(1, int(cfg.get("partials_per_frame", 10)))
    partial_ms = float(cfg.get("partial_ms", 120.0))
    floor_db = float(cfg.get("floor_db", -62.0))
    pitch_scale = float(cfg.get("pitch_scale", 1.0))
    trace_gain = float(cfg.get("trace_gain", 1.0))
    density = float(cfg.get("density", 1.0))
    drift = float(cfg.get("drift", 0.012))
    brightness = float(cfg.get("brightness", 1.0))
    spatial_width = float(cfg.get("spatial_width", 0.65))
    trace_behavior = str(cfg.get("trace_behavior", "linked"))
    track_tolerance_cents = float(cfg.get("track_tolerance_cents", 90.0))
    min_track_frames = max(2, int(cfg.get("min_track_frames", 3)))
    clarity_protect = bool(cfg.get("clarity_protect", True))
    low_cut_hz = float(cfg.get("low_cut_hz", 30.0))
    soft_limit = bool(cfg.get("soft_limit", False))
    rng = np.random.default_rng(int(cfg.get("seed", 1)))

    window = np.hanning(fft_size).astype(np.float32)
    padded = np.pad(mono, (fft_size // 2, fft_size), mode="constant")
    freqs = np.fft.rfftfreq(fft_size, 1.0 / sample_rate)
    starts = list(range(0, max(1, padded.shape[0] - fft_size + 1), hop))
    if not starts:
        starts = [0]
    max_mag = 0.0
    spectra = []
    for start in starts:
        frame = padded[start:start + fft_size]
        if frame.shape[0] < fft_size:
            frame = np.pad(frame, (0, fft_size - frame.shape[0]), mode="constant")
        mag = np.abs(np.fft.rfft(frame * window))
        spectra.append(mag.astype(np.float32))
        local_max = float(np.max(mag)) if mag.size else 0.0
        if local_max > max_mag:
            max_mag = local_max
    if max_mag <= 1e-12:
        raise RuntimeError("Selected source segment appears silent.")

    floor = max_mag * (10.0 ** (floor_db / 20.0))
    min_peak_hz = max(20.0, low_cut_hz if clarity_protect else 20.0)
    skipped_low = freqs < min_peak_hz
    peak_frames = []
    admitted_peaks = 0
    for frame_index, mag in enumerate(spectra):
        u = frame_index / max(1, len(spectra) - 1)
        candidate = mag.copy()
        candidate[skipped_low] = 0.0
        candidate[candidate < floor] = 0.0
        nonzero = np.flatnonzero(candidate > 0.0)
        if nonzero.size == 0:
            peak_frames.append([])
            continue
        local_density = env_value(cfg, "density", u, density)
        local_density = float(np.clip(local_density, 0.0, 1.0))
        n = min(partials_per_frame, int(nonzero.size))
        n = int(round(n * local_density))
        if n < 1:
            peak_frames.append([])
            continue
        if n < nonzero.size:
            picked = np.argpartition(candidate, -n)[-n:]
        else:
            picked = nonzero
        picked = picked[np.argsort(candidate[picked])[::-1]]
        peaks = []
        for rank, bin_index in enumerate(picked):
            freq = float(freqs[int(bin_index)] * pitch_scale)
            if freq < 20.0 or freq > sample_rate * 0.45:
                continue
            mag_norm = float(candidate[int(bin_index)] / max_mag)
            peaks.append({"u": u, "freq": freq, "mag": mag_norm, "rank": rank, "count": n})
            admitted_peaks += 1
        peak_frames.append(peaks)

    def spectral_position(freq, rank, count, u):
        freq_pos = math.log2(max(20.0, freq) / 20.0) / math.log2(max(21.0, sample_rate * 0.45) / 20.0)
        rank_pos = rank / max(1, count - 1)
        return (freq_pos * 0.65 + rank_pos * 0.20 + u * 0.15) * max(0, channels - 1)

    def add_trace(start_u, freq0, mag0, rank, count, length_mult, phase=None):
        local_gain = env_value(cfg, "trace_gain", start_u, trace_gain)
        local_drift = env_value(cfg, "drift", start_u, drift)
        local_spatial_width = env_value(cfg, "spatial_width", start_u, spatial_width)
        out_start = int(round(start_u * max(0, frames - 1)))
        length = max(32, int(round(partial_ms * length_mult * sample_rate / 1000.0 * rng.uniform(0.75, 1.35))))
        if out_start + length > frames:
            length = frames - out_start
        if length < 16:
            return 0
        amp = (mag0 ** brightness) * local_gain * 0.085 / math.sqrt(max(1.0, partials_per_frame / 6.0))
        if amp <= 1e-7:
            return 0
        env_power = 0.85 if length_mult > 1.5 else 1.35
        env = np.sin(np.linspace(0.0, math.pi, length, dtype=np.float64)) ** env_power
        bend = 1.0 + local_drift * rng.normal(0.0, 0.55) * np.linspace(0.0, 1.0, length)
        phase0 = rng.uniform(0.0, 2.0 * math.pi) if phase is None else phase
        phase_array = phase0 + 2.0 * math.pi * np.cumsum(freq0 * bend) / sample_rate
        tone = (np.sin(phase_array) * env * amp).astype(np.float32)
        pos0 = spectral_position(freq0, rank, count, start_u)
        wander = channels * (0.10 + local_drift * (0.45 if length_mult <= 1.5 else 0.90))
        pos1 = (pos0 + rng.normal(0.0, wander)) % max(1, channels)
        w0 = pan_weights(pos0, channels, local_spatial_width)
        w1 = pan_weights(pos1, channels, local_spatial_width)
        motion = np.linspace(0.0, 1.0, length, dtype=np.float32)[:, None]
        weights = w0[None, :] * (1.0 - motion) + w1[None, :] * motion
        weights /= np.sqrt(np.sum(weights * weights, axis=1, keepdims=True) + 1e-12)
        out[out_start:out_start + length, :] += tone[:, None] * weights.astype(np.float32, copy=False)
        return 1

    def highpass(audio, cutoff_hz):
        if cutoff_hz <= 0.0 or audio.shape[0] < 2:
            return audio
        cutoff_hz = min(float(cutoff_hz), sample_rate * 0.24)
        rc = 1.0 / (2.0 * math.pi * cutoff_hz)
        dt = 1.0 / sample_rate
        alpha = rc / (rc + dt)
        wet = np.empty_like(audio)
        wet[0, :] = audio[0, :]
        for index in range(1, audio.shape[0]):
            wet[index, :] = alpha * (wet[index - 1, :] + audio[index, :] - audio[index - 1, :])
        return wet.astype(np.float32)

    traces = 0
    linked_tracks = 0
    if trace_behavior == "linked":
        tracks = []
        active = []
        max_gap = 2
        for frame_index, peaks in enumerate(peak_frames):
            used_tracks = set()
            next_active = []
            for peak in sorted(peaks, key=lambda p: p["mag"], reverse=True):
                best_track = None
                best_cents = track_tolerance_cents
                for track_index in active:
                    if track_index in used_tracks:
                        continue
                    track = tracks[track_index]
                    if frame_index - track["last_frame"] > max_gap:
                        continue
                    cents = abs(1200.0 * math.log2(max(1e-9, peak["freq"]) / max(1e-9, track["last_freq"])))
                    if cents < best_cents:
                        best_cents = cents
                        best_track = track_index
                if best_track is None:
                    tracks.append({
                        "points": [peak],
                        "last_freq": peak["freq"],
                        "last_frame": frame_index,
                    })
                    next_active.append(len(tracks) - 1)
                else:
                    tracks[best_track]["points"].append(peak)
                    tracks[best_track]["last_freq"] = peak["freq"]
                    tracks[best_track]["last_frame"] = frame_index
                    used_tracks.add(best_track)
                    next_active.append(best_track)
            for track_index in active:
                if frame_index - tracks[track_index]["last_frame"] <= max_gap and track_index not in next_active:
                    next_active.append(track_index)
            active = next_active

        for track in tracks:
            points = track["points"]
            if len(points) < min_track_frames:
                continue
            phase = rng.uniform(0.0, 2.0 * math.pi)
            linked_tracks += 1
            for index in range(len(points) - 1):
                p0 = points[index]
                p1 = points[index + 1]
                start = int(round(p0["u"] * max(0, frames - 1)))
                end = int(round(p1["u"] * max(0, frames - 1)))
                length = max(8, end - start)
                if start >= frames:
                    continue
                if start + length > frames:
                    length = frames - start
                if length < 8:
                    continue
                mid_u = (p0["u"] + p1["u"]) * 0.5
                local_gain = env_value(cfg, "trace_gain", mid_u, trace_gain)
                local_drift = env_value(cfg, "drift", mid_u, drift)
                local_spatial_width = env_value(cfg, "spatial_width", mid_u, spatial_width)
                freq_line = np.linspace(p0["freq"], p1["freq"], length, dtype=np.float64)
                if local_drift > 0.0001:
                    freq_line *= 1.0 + local_drift * rng.normal(0.0, 0.15)
                amp_line = np.linspace(p0["mag"], p1["mag"], length, dtype=np.float64) ** brightness
                amp_line *= local_gain * 0.060 / math.sqrt(max(1.0, partials_per_frame / 6.0))
                if index == 0:
                    ramp = min(length, max(8, int(0.015 * sample_rate)))
                    amp_line[:ramp] *= np.linspace(0.0, 1.0, ramp)
                if index == len(points) - 2:
                    ramp = min(length, max(8, int(0.020 * sample_rate)))
                    amp_line[-ramp:] *= np.linspace(1.0, 0.0, ramp)
                phase_array = phase + 2.0 * math.pi * np.cumsum(freq_line) / sample_rate
                phase = float(phase_array[-1] % (2.0 * math.pi))
                tone = (np.sin(phase_array) * amp_line).astype(np.float32)
                pos0 = spectral_position(p0["freq"], p0["rank"], p0["count"], p0["u"])
                pos1 = spectral_position(p1["freq"], p1["rank"], p1["count"], p1["u"])
                w0 = pan_weights(pos0, channels, local_spatial_width)
                w1 = pan_weights(pos1, channels, local_spatial_width)
                motion = np.linspace(0.0, 1.0, length, dtype=np.float32)[:, None]
                weights = w0[None, :] * (1.0 - motion) + w1[None, :] * motion
                weights /= np.sqrt(np.sum(weights * weights, axis=1, keepdims=True) + 1e-12)
                out[start:start + length, :] += tone[:, None] * weights.astype(np.float32, copy=False)
                traces += 1
    else:
        if trace_behavior == "smear":
            length_mult = 2.8
            stride = 1
        elif trace_behavior == "freeze":
            length_mult = 7.5
            stride = max(1, int(round(700.0 / max(1.0, partial_ms))))
        else:
            length_mult = 1.0
            stride = 1
        for frame_index, peaks in enumerate(peak_frames):
            if frame_index % stride != 0:
                continue
            for peak in peaks:
                traces += add_trace(peak["u"], peak["freq"], peak["mag"], peak["rank"], peak["count"], length_mult)

    if clarity_protect:
        out -= np.mean(out, axis=0, keepdims=True)
        if low_cut_hz > 0.0:
            out = highpass(out, low_cut_hz)
        if soft_limit:
            protect_peak = float(np.max(np.abs(out))) if out.size else 0.0
            if protect_peak > 1.20:
                ceiling = 0.88
                out = (ceiling * np.tanh(out / ceiling)).astype(np.float32)
    out = apply_output_envelope(out, cfg, "amplitude")
    corr = mean_neighbor_correlation(out)
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -6.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out, sample_rate)
    print(f"Trace behavior: {trace_behavior}")
    print(f"Analysis frames: {len(spectra)}")
    print(f"Admitted peaks: {admitted_peaks}")
    print(f"Oscillator traces: {traces}")
    print(f"Density: {density:.3f}")
    if trace_behavior == "linked":
        print(f"Linked tracks: {linked_tracks}")
    print(f"FFT size: {fft_size}")
    print(f"Hop: {hop}")
    print(f"Output channels: {channels}")
    print(f"Clarity protect: {clarity_protect}")
    if clarity_protect:
        print(f"Low cut: {low_cut_hz:.1f} Hz")
        print(f"Soft limit: {soft_limit}")
    print(f"Mean neighbor correlation: {corr:.3f}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")


def analyze_peak_frames(path, start_seconds, duration_seconds, sample_rate, fft_size, hop, floor_db, pitch_scale, min_peak_hz):
    source, source_rate = read_wav(path)
    source = segment(source, source_rate, start_seconds, duration_seconds, sample_rate)
    if source.shape[0] < 8:
        raise RuntimeError(f"Source is too short for hybrid resynthesis: {path}")
    mono = np.mean(source, axis=1).astype(np.float32)
    mono = mono - float(np.mean(mono))
    window = np.hanning(fft_size).astype(np.float32)
    padded = np.pad(mono, (fft_size // 2, fft_size), mode="constant")
    freqs = np.fft.rfftfreq(fft_size, 1.0 / sample_rate)
    starts = list(range(0, max(1, padded.shape[0] - fft_size + 1), hop))
    if not starts:
        starts = [0]
    spectra = []
    max_mag = 0.0
    for start in starts:
        frame = padded[start:start + fft_size]
        if frame.shape[0] < fft_size:
            frame = np.pad(frame, (0, fft_size - frame.shape[0]), mode="constant")
        mag = np.abs(np.fft.rfft(frame * window))
        spectra.append(mag.astype(np.float32))
        max_mag = max(max_mag, float(np.max(mag)) if mag.size else 0.0)
    if max_mag <= 1e-12:
        raise RuntimeError(f"Source appears silent: {path}")
    floor = max_mag * (10.0 ** (floor_db / 20.0))
    skipped_low = freqs < max(20.0, min_peak_hz)
    peak_frames = []
    for frame_index, mag in enumerate(spectra):
        u = frame_index / max(1, len(spectra) - 1)
        candidate = mag.copy()
        candidate[skipped_low] = 0.0
        candidate[candidate < floor] = 0.0
        nonzero = np.flatnonzero(candidate > 0.0)
        peaks = []
        if nonzero.size:
            picked_count = min(96, int(nonzero.size))
            picked = np.argpartition(candidate, -picked_count)[-picked_count:] if picked_count < nonzero.size else nonzero
            picked = picked[np.argsort(candidate[picked])[::-1]]
            for rank, bin_index in enumerate(picked):
                freq = float(freqs[int(bin_index)] * pitch_scale)
                if 20.0 <= freq <= sample_rate * 0.45:
                    peaks.append({
                        "u": u,
                        "freq": freq,
                        "mag": float(candidate[int(bin_index)] / max_mag),
                        "rank": rank,
                        "count": picked_count,
                    })
        peak_frames.append(peaks)
    return peak_frames


def render_fata_morgana(cfg):
    sample_rate = int(cfg.get("sample_rate", 48000))
    duration = float(cfg["duration"])
    channels = int(cfg["channels"])
    frames = max(1, int(round(duration * sample_rate)))
    out = np.zeros((frames, channels), dtype=np.float32)
    source_count = max(2, min(16, int(cfg.get("source_count", 2))))
    fft_size = max(128, int(cfg.get("fft_size", 2048)))
    hop = max(16, int(cfg.get("hop", fft_size // 4)))
    partials_per_frame = max(1, int(cfg.get("partials_per_frame", 12)))
    partial_ms = float(cfg.get("partial_ms", 140.0))
    floor_db = float(cfg.get("floor_db", -62.0))
    pitch_scale = float(cfg.get("pitch_scale", 1.0))
    trace_gain = float(cfg.get("trace_gain", 1.0))
    density = float(cfg.get("density", 1.0))
    mutation = float(cfg.get("mutation", 0.65))
    texture_bias = float(np.clip(cfg.get("texture_bias", 0.55), 0.0, 1.0))
    drift = float(cfg.get("drift", 0.012))
    brightness = float(cfg.get("brightness", 1.0))
    spatial_width = float(cfg.get("spatial_width", 0.75))
    hybrid_mode = str(cfg.get("hybrid_mode", "chimera"))
    trace_behavior = str(cfg.get("trace_behavior", "point"))
    clarity_protect = bool(cfg.get("clarity_protect", True))
    low_cut_hz = float(cfg.get("low_cut_hz", 30.0))
    soft_limit = bool(cfg.get("soft_limit", False))
    rng = np.random.default_rng(int(cfg.get("seed", 1)))

    sources = []
    min_peak_hz = max(20.0, low_cut_hz if clarity_protect else 20.0)
    for index in range(1, source_count + 1):
        path = cfg.get(f"source{index}_path", "")
        if not path:
            continue
        peak_frames = analyze_peak_frames(
            path,
            float(cfg.get(f"source{index}_start", 0.0)),
            float(cfg.get(f"source{index}_duration", duration)),
            sample_rate,
            fft_size,
            hop,
            floor_db,
            pitch_scale,
            min_peak_hz,
        )
        sources.append({"path": path, "frames": peak_frames})
    if len(sources) < 2:
        raise RuntimeError("Fata Morgana Resynth needs at least two readable WAV sources.")

    def source_frame(source_index, u):
        frames_for_source = sources[source_index]["frames"]
        frame_index = int(round(float(np.clip(u, 0.0, 1.0)) * max(0, len(frames_for_source) - 1)))
        return frames_for_source[frame_index] if frames_for_source else []

    def spectral_position(freq, rank, count, u, source_index):
        freq_pos = math.log2(max(20.0, freq) / 20.0) / math.log2(max(21.0, sample_rate * 0.45) / 20.0)
        src_pos = source_index / max(1, len(sources) - 1)
        rank_pos = rank / max(1, count - 1)
        return (freq_pos * 0.52 + src_pos * 0.28 + rank_pos * 0.12 + u * 0.08) * max(0, channels - 1)

    def choose_source(base, u, role):
        if hybrid_mode == "mirage":
            if role in ("time", "amp") and rng.random() > mutation:
                return 0
            return int(rng.integers(0, len(sources)))
        if hybrid_mode == "graft":
            if role == "time":
                return 0
            if role == "pitch":
                return min(1, len(sources) - 1)
            return int(rng.integers(0, len(sources))) if rng.random() < mutation else base
        if hybrid_mode == "mask":
            return 0 if role in ("time", "amp") else min(1, len(sources) - 1)
        if hybrid_mode == "swarm":
            return int((u * len(sources) + rng.integers(0, 2)) % len(sources))
        return int(rng.integers(0, len(sources))) if rng.random() < mutation else base

    def add_trace(start_u, freq0, amp0, rank, count, source_index, length_mult):
        local_gain = env_value(cfg, "trace_gain", start_u, trace_gain)
        local_drift = env_value(cfg, "drift", start_u, drift)
        local_spatial_width = env_value(cfg, "spatial_width", start_u, spatial_width) * (1.0 + texture_bias * 1.7)
        out_start = int(round(start_u * max(0, frames - 1)))
        length_scale = 1.0 - texture_bias * 0.58
        length = max(32, int(round(partial_ms * length_mult * length_scale * sample_rate / 1000.0 * rng.uniform(0.65, 1.25))))
        if out_start + length > frames:
            length = frames - out_start
        if length < 16:
            return 0
        mag_curve = max(0.35, brightness * (1.0 - texture_bias * 0.35))
        amp = (amp0 ** mag_curve) * local_gain * 0.080 / math.sqrt(max(1.0, partials_per_frame / 6.0))
        if amp <= 1e-7:
            return 0
        env_power = 0.85 if length_mult > 1.5 else 1.35
        env = np.sin(np.linspace(0.0, math.pi, length, dtype=np.float64)) ** env_power
        random_walk = np.cumsum(rng.normal(0.0, 1.0, length))
        random_walk /= max(1e-9, np.max(np.abs(random_walk)))
        bend = 1.0 + local_drift * rng.normal(0.0, 0.55) * np.linspace(0.0, 1.0, length)
        bend += texture_bias * 0.018 * random_walk
        phase = rng.uniform(0.0, 2.0 * math.pi) + 2.0 * math.pi * np.cumsum(freq0 * bend) / sample_rate
        sine = np.sin(phase)
        residual = rng.normal(0.0, 1.0, length)
        smooth = max(3, int(round(sample_rate * (0.0015 + texture_bias * 0.005))))
        kernel = np.ones(smooth, dtype=np.float64) / float(smooth)
        residual = np.convolve(residual, kernel, mode="same")
        residual_peak = np.max(np.abs(residual))
        if residual_peak > 1e-9:
            residual /= residual_peak
        tonal_mix = 1.0 - texture_bias * 0.72
        residual_mix = texture_bias * 0.58
        tone = ((sine * tonal_mix + residual * residual_mix) * env * amp).astype(np.float32)
        pos0 = spectral_position(freq0, rank, count, start_u, source_index)
        pos1 = (pos0 + rng.normal(0.0, channels * (0.08 + local_drift * 0.65))) % max(1, channels)
        w0 = pan_weights(pos0, channels, local_spatial_width)
        w1 = pan_weights(pos1, channels, local_spatial_width)
        motion = np.linspace(0.0, 1.0, length, dtype=np.float32)[:, None]
        weights = w0[None, :] * (1.0 - motion) + w1[None, :] * motion
        weights /= np.sqrt(np.sum(weights * weights, axis=1, keepdims=True) + 1e-12)
        out[out_start:out_start + length, :] += tone[:, None] * weights.astype(np.float32, copy=False)
        return 1

    reference_frames = max(len(src["frames"]) for src in sources)
    if trace_behavior == "smear":
        length_mult = 2.8
        stride = 1
    elif trace_behavior == "freeze":
        length_mult = 7.5
        stride = max(1, int(round(700.0 / max(1.0, partial_ms))))
    else:
        length_mult = 1.0
        stride = 1

    admitted = 0
    traces = 0
    for frame_index in range(reference_frames):
        if frame_index % stride != 0:
            continue
        u = frame_index / max(1, reference_frames - 1)
        local_density = float(np.clip(env_value(cfg, "density", u, density), 0.0, 1.0))
        n = int(round(partials_per_frame * local_density * (1.0 - texture_bias * 0.25)))
        if n < 1:
            continue
        time_source = choose_source(frame_index % len(sources), u, "time")
        base_peaks = source_frame(time_source, u)
        if not base_peaks:
            continue
        if hybrid_mode == "mask" and len(sources) > 1:
            mask_peaks = source_frame(1, u)
            if mask_peaks:
                mask_freqs = np.array([p["freq"] for p in mask_peaks[:partials_per_frame * 2]], dtype=np.float64)
                filtered = []
                for peak in base_peaks:
                    cents = np.min(np.abs(1200.0 * np.log2(np.maximum(1e-9, mask_freqs) / max(1e-9, peak["freq"]))))
                    if cents < 180.0:
                        filtered.append(peak)
                base_peaks = filtered
        if not base_peaks:
            continue
        for rank, base_peak in enumerate(base_peaks[:n]):
            pitch_source = choose_source(time_source, u, "pitch")
            amp_source = choose_source(time_source, u, "amp")
            pitch_peaks = source_frame(pitch_source, u)
            amp_peaks = source_frame(amp_source, u)
            pitch_peak = pitch_peaks[min(rank, len(pitch_peaks) - 1)] if pitch_peaks else base_peak
            amp_peak = amp_peaks[min(rank, len(amp_peaks) - 1)] if amp_peaks else base_peak
            freq = pitch_peak["freq"]
            amp = (base_peak["mag"] * 0.35 + amp_peak["mag"] * 0.65)
            admitted += 1
            traces += add_trace(u, freq, amp, rank, max(1, n), pitch_source, length_mult)

    if clarity_protect:
        out -= np.mean(out, axis=0, keepdims=True)
        if low_cut_hz > 0.0:
            # Reuse the same one-pole high-pass shape as Partial Trace.
            cutoff_hz = min(float(low_cut_hz), sample_rate * 0.24)
            rc = 1.0 / (2.0 * math.pi * cutoff_hz)
            dt = 1.0 / sample_rate
            alpha = rc / (rc + dt)
            wet = np.empty_like(out)
            wet[0, :] = out[0, :]
            for index in range(1, out.shape[0]):
                wet[index, :] = alpha * (wet[index - 1, :] + out[index, :] - out[index - 1, :])
            out = wet.astype(np.float32)
        if soft_limit:
            protect_peak = float(np.max(np.abs(out))) if out.size else 0.0
            if protect_peak > 1.20:
                ceiling = 0.88
                out = (ceiling * np.tanh(out / ceiling)).astype(np.float32)
    out = apply_output_envelope(out, cfg, "amplitude")
    corr = mean_neighbor_correlation(out)
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -6.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out, sample_rate)
    print(f"Hybrid mode: {hybrid_mode}")
    print(f"Trace behavior: {trace_behavior}")
    print(f"Sources: {len(sources)}")
    print(f"Admitted hybrid peaks: {admitted}")
    print(f"Oscillator traces: {traces}")
    print(f"Density: {density:.3f}")
    print(f"Mutation: {mutation:.3f}")
    print(f"Texture bias: {texture_bias:.3f}")
    print(f"FFT size: {fft_size}")
    print(f"Hop: {hop}")
    print(f"Output channels: {channels}")
    print(f"Clarity protect: {clarity_protect}")
    if clarity_protect:
        print(f"Low cut: {low_cut_hz:.1f} Hz")
        print(f"Soft limit: {soft_limit}")
    print(f"Mean neighbor correlation: {corr:.3f}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")


def associated_legendre(n, m, x):
    m = abs(int(m))
    if m > n:
        return 0.0
    pmm = 1.0
    if m > 0:
        somx2 = math.sqrt(max(0.0, 1.0 - x * x))
        fact = 1.0
        for _ in range(1, m + 1):
            pmm *= -fact * somx2
            fact += 2.0
    if n == m:
        return pmm
    pmmp1 = x * (2.0 * m + 1.0) * pmm
    if n == m + 1:
        return pmmp1
    pll = 0.0
    for ll in range(m + 2, n + 1):
        pll = ((2.0 * ll - 1.0) * x * pmmp1 - (ll + m - 1.0) * pmm) / (ll - m)
        pmm = pmmp1
        pmmp1 = pll
    return pll


def sn3d_norm(n, m):
    m = abs(int(m))
    return math.sqrt((2.0 if m > 0 else 1.0) * math.factorial(n - m) / math.factorial(n + m))


def ambisonic_basis(order, az_deg, el_deg):
    az = math.radians(float(az_deg))
    el = math.radians(float(el_deg))
    z = math.sin(el)
    values = []
    for n in range(order + 1):
        for m in range(-n, n + 1):
            am = abs(m)
            p = associated_legendre(n, am, z)
            norm = sn3d_norm(n, am)
            if m < 0:
                y = norm * p * math.sin(am * az)
            elif m == 0:
                y = norm * p
            else:
                y = norm * p * math.cos(m * az)
            values.append(y)
    return values


def foafx_layout(order):
    if order <= 1:
        return [
            (0.0, 0.0), (90.0, 0.0), (180.0, 0.0), (-90.0, 0.0),
            (0.0, 90.0), (0.0, -90.0),
        ]
    if order == 2:
        return [
            (0.0, 0.0), (45.0, 0.0), (90.0, 0.0), (135.0, 0.0),
            (180.0, 0.0), (-135.0, 0.0), (-90.0, 0.0), (-45.0, 0.0),
            (45.0, 45.0), (135.0, 45.0), (-135.0, -45.0), (-45.0, -45.0),
        ]
    return [
        (0.000000, 73.402158), (137.507764, 61.044976), (-84.984472, 52.341538),
        (52.523292, 45.099472), (-169.968944, 38.682187), (-32.461180, 32.797168),
        (105.046584, 27.279613), (-117.445652, 22.024313), (20.062112, 16.957763),
        (157.569876, 12.024699), (-64.922360, 7.180756), (72.585405, 2.388015),
        (-149.906831, -2.388015), (-12.399067, -7.180756), (125.108697, -12.024699),
        (-97.383539, -16.957763), (40.124225, -22.024313), (177.631989, -27.279613),
        (-44.860247, -32.797168), (92.647517, -38.682187), (-129.844719, -45.099472),
        (7.663045, -52.341538), (145.170809, -61.044976), (-77.321427, -73.402158),
    ]


def unit_from_aed(az_deg, el_deg):
    az = math.radians(float(az_deg))
    el = math.radians(float(el_deg))
    ce = math.cos(el)
    return np.array([ce * math.cos(az), ce * math.sin(az), math.sin(el)], dtype=np.float64)


def wrap_degrees(values):
    return ((values + 180.0) % 360.0) - 180.0


def simple_delay(signal, sample_rate, delay_ms, feedback, damp):
    delay = max(1, int(round(float(delay_ms) * sample_rate / 1000.0)))
    out = np.zeros_like(signal, dtype=np.float32)
    fb = float(np.clip(feedback, 0.0, 0.92))
    damp = float(np.clip(damp, 0.0, 0.98))
    state = np.zeros(signal.shape[1], dtype=np.float32)
    for index in range(signal.shape[0]):
        dry = signal[index]
        wet = out[index - delay] if index >= delay else 0.0
        state = state * damp + wet * (1.0 - damp)
        out[index] = dry + state * fb
    return out


def one_pole_lowpass(signal, sample_rate, cutoff_hz):
    cutoff = max(20.0, min(float(cutoff_hz), sample_rate * 0.45))
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / sample_rate)
    out = np.empty_like(signal, dtype=np.float32)
    state = np.zeros(signal.shape[1], dtype=np.float32)
    for index in range(signal.shape[0]):
        state += alpha * (signal[index] - state)
        out[index] = state
    return out


def tremolo_region(signal, sample_rate, rate_hz, depth):
    depth = float(np.clip(depth, 0.0, 1.0))
    t = np.arange(signal.shape[0], dtype=np.float32) / float(sample_rate)
    mod = 1.0 - depth * 0.5 + depth * 0.5 * np.sin(2.0 * math.pi * float(rate_hz) * t)
    return (signal * mod[:, None]).astype(np.float32)


def ringmod_region(signal, sample_rate, freq_hz, depth):
    depth = float(np.clip(depth, 0.0, 1.0))
    t = np.arange(signal.shape[0], dtype=np.float32) / float(sample_rate)
    carrier = np.sin(2.0 * math.pi * float(freq_hz) * t)
    mod = (1.0 - depth) + depth * carrier
    return (signal * mod[:, None]).astype(np.float32)


def biquad_bandpass(signal, sample_rate, center_hz, q):
    center = max(20.0, min(float(center_hz), sample_rate * 0.45))
    q = max(0.1, min(float(q), 20.0))
    omega = 2.0 * math.pi * center / sample_rate
    alpha = math.sin(omega) / (2.0 * q)
    cosw = math.cos(omega)
    b0 = alpha
    b1 = 0.0
    b2 = -alpha
    a0 = 1.0 + alpha
    a1 = -2.0 * cosw
    a2 = 1.0 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    out = np.zeros_like(signal, dtype=np.float32)
    x1 = np.zeros(signal.shape[1], dtype=np.float32)
    x2 = np.zeros(signal.shape[1], dtype=np.float32)
    y1 = np.zeros(signal.shape[1], dtype=np.float32)
    y2 = np.zeros(signal.shape[1], dtype=np.float32)
    for index in range(signal.shape[0]):
        x0 = signal[index]
        y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        out[index] = y0
        x2, x1 = x1, x0
        y2, y1 = y1, y0
    return out


def comb_resonator(signal, sample_rate, freq_hz, feedback, damp):
    delay = max(1, int(round(sample_rate / max(20.0, float(freq_hz)))))
    fb = float(np.clip(feedback, 0.0, 0.96))
    damp = float(np.clip(damp, 0.0, 0.98))
    out = np.zeros_like(signal, dtype=np.float32)
    state = np.zeros(signal.shape[1], dtype=np.float32)
    for index in range(signal.shape[0]):
        delayed = out[index - delay] if index >= delay else 0.0
        state = state * damp + delayed * (1.0 - damp)
        out[index] = signal[index] + state * fb
    return out


def diffusion_region(signal, sample_rate, base_ms, feedback, damp):
    out = signal.astype(np.float32, copy=True)
    channels = signal.shape[1]
    fb = float(np.clip(feedback, 0.0, 0.9))
    damp = float(np.clip(damp, 0.0, 0.98))
    base = max(1, int(round(float(base_ms) * sample_rate / 1000.0)))
    acc = out.copy()
    for tap in range(1, 5):
        delay = base * tap
        if delay >= signal.shape[0]:
            continue
        gain = fb / (tap + 1.0)
        shifted = np.zeros_like(signal, dtype=np.float32)
        cross = np.roll(signal[:-delay], tap % max(1, channels), axis=1)
        shifted[delay:] = cross
        acc += shifted * gain
    if damp > 0.0:
        acc = one_pole_lowpass(acc, sample_rate, sample_rate * (0.08 + 0.34 * (1.0 - damp)))
    return (acc / max(1.0, 1.0 + fb)).astype(np.float32)


def stft_process(signal, fft_size, hop, process_frame):
    fft_size = int(fft_size)
    hop = int(hop)
    window = np.hanning(fft_size).astype(np.float32)
    pad = fft_size
    padded = np.pad(signal, ((pad, pad), (0, 0)), mode="constant")
    out = np.zeros_like(padded, dtype=np.float32)
    norm = np.zeros(padded.shape[0], dtype=np.float32)
    frame_count = 1 + max(0, (padded.shape[0] - fft_size) // hop)
    for frame_index in range(frame_count):
        start = frame_index * hop
        frame = padded[start:start + fft_size] * window[:, None]
        spec = np.fft.rfft(frame, axis=0)
        new_spec = process_frame(spec, frame_index)
        resynth = np.fft.irfft(new_spec, n=fft_size, axis=0).real.astype(np.float32)
        out[start:start + fft_size] += resynth * window[:, None]
        norm[start:start + fft_size] += window * window
    out /= np.maximum(norm[:, None], 1e-8)
    return out[pad:pad + signal.shape[0]].astype(np.float32)


def spectral_smear_region(signal, smear_frames, amount):
    fft_size = 1024
    hop = 256
    window = np.hanning(fft_size).astype(np.float32)
    pad = fft_size
    padded = np.pad(signal, ((pad, pad), (0, 0)), mode="constant")
    frame_count = 1 + max(0, (padded.shape[0] - fft_size) // hop)
    specs = []
    for frame_index in range(frame_count):
        start = frame_index * hop
        specs.append(np.fft.rfft(padded[start:start + fft_size] * window[:, None], axis=0))
    specs = np.stack(specs, axis=0)
    mags = np.abs(specs)
    phase = np.exp(1j * np.angle(specs))
    radius = max(1, int(round(float(smear_frames))))
    smooth = np.zeros_like(mags)
    for index in range(frame_count):
        lo = max(0, index - radius)
        hi = min(frame_count, index + radius + 1)
        smooth[index] = np.mean(mags[lo:hi], axis=0)
    amount = float(np.clip(amount, 0.0, 1.0))
    new_specs = ((1.0 - amount) * mags + amount * smooth) * phase
    out = np.zeros_like(padded, dtype=np.float32)
    norm = np.zeros(padded.shape[0], dtype=np.float32)
    for frame_index in range(frame_count):
        start = frame_index * hop
        resynth = np.fft.irfft(new_specs[frame_index], n=fft_size, axis=0).real.astype(np.float32)
        out[start:start + fft_size] += resynth * window[:, None]
        norm[start:start + fft_size] += window * window
    out /= np.maximum(norm[:, None], 1e-8)
    return out[pad:pad + signal.shape[0]].astype(np.float32)


def spectral_pitch_shift_region(signal, semitones):
    ratio = 2.0 ** (float(semitones) / 12.0)
    fft_size = 2048
    hop = 512
    bins = fft_size // 2 + 1

    def shift_frame(spec, _frame_index):
        shifted = np.zeros_like(spec)
        for source_bin in range(1, bins):
            target = source_bin * ratio
            lo = int(math.floor(target))
            frac = target - lo
            if 0 <= lo < bins:
                shifted[lo] += spec[source_bin] * (1.0 - frac)
            if 0 <= lo + 1 < bins:
                shifted[lo + 1] += spec[source_bin] * frac
        shifted[0] = spec[0]
        return shifted

    return stft_process(signal, fft_size, hop, shift_frame)


def render_foafx_offline(cfg):
    source, source_rate = read_wav(cfg["source_path"])
    sample_rate = int(cfg.get("sample_rate", source_rate))
    audio = segment(source, source_rate, cfg.get("source_start", 0.0), cfg.get("source_duration", 1.0), sample_rate)
    order = int(cfg.get("order", 3))
    order = max(1, min(3, order))
    ambi_channels = (order + 1) * (order + 1)
    if audio.shape[1] < ambi_channels:
        raise RuntimeError(f"Selected item has {audio.shape[1]} channels, but {order}OA needs {ambi_channels}.")
    audio = audio[:, :ambi_channels].astype(np.float32, copy=False)
    frames = audio.shape[0]
    layout = foafx_layout(order)
    basis = np.array([ambisonic_basis(order, az, el) for az, el in layout], dtype=np.float64)
    decode = basis.T
    encode = np.linalg.pinv(basis).T
    virtual = (audio.astype(np.float64) @ decode).astype(np.float32)

    effect = str(cfg.get("effect", "gain"))
    effect_gain = float(cfg.get("effect_gain", 1.0))
    if effect == "tremolo":
        rate_hz = float(cfg.get("tremolo_rate", cfg.get("effect_param", 4.0)))
        processed = tremolo_region(virtual, sample_rate, rate_hz, min(1.0, max(0.0, effect_gain))).astype(np.float32)
    elif effect == "ringmod":
        freq_hz = float(cfg.get("ring_hz", cfg.get("effect_param", 90.0)))
        processed = ringmod_region(virtual, sample_rate, freq_hz, min(1.0, max(0.0, effect_gain))).astype(np.float32)
    elif effect == "saturation":
        drive = max(0.01, float(cfg.get("drive", cfg.get("effect_param", 2.0))))
        processed = np.tanh(virtual * drive) / math.tanh(drive)
        processed = (processed * effect_gain).astype(np.float32)
    elif effect == "delay":
        delay_ms = float(cfg.get("delay_ms", cfg.get("effect_param", 120.0)))
        feedback = float(cfg.get("feedback", 0.28))
        damp = float(cfg.get("damp", 0.45))
        processed = simple_delay(virtual, sample_rate, delay_ms, feedback, damp)
        processed = (processed * effect_gain).astype(np.float32)
    elif effect == "bandpass":
        center = float(cfg.get("center_hz", cfg.get("effect_param", 1200.0)))
        q = 0.65 + max(0.0, effect_gain) * 2.6
        processed = biquad_bandpass(virtual, sample_rate, center, q).astype(np.float32)
    elif effect == "comb":
        freq = float(cfg.get("reson_hz", cfg.get("effect_param", 220.0)))
        feedback = float(cfg.get("feedback", 0.28))
        damp = float(cfg.get("damp", 0.45))
        processed = comb_resonator(virtual, sample_rate, freq, feedback, damp)
        processed = (processed * effect_gain).astype(np.float32)
    elif effect == "diffusion":
        diffusion_ms = float(cfg.get("diffusion_ms", cfg.get("effect_param", 18.0)))
        feedback = float(cfg.get("feedback", 0.28))
        damp = float(cfg.get("damp", 0.45))
        processed = diffusion_region(virtual, sample_rate, diffusion_ms, feedback, damp)
        processed = (processed * effect_gain).astype(np.float32)
    elif effect == "spectral_smear":
        smear_frames = float(cfg.get("smear_frames", cfg.get("effect_param", 8.0)))
        processed = spectral_smear_region(virtual, smear_frames, min(1.0, max(0.0, effect_gain))).astype(np.float32)
    elif effect == "pitch_shift":
        semitones = float(cfg.get("pitch_semitones", cfg.get("effect_param", 7.0)))
        processed = spectral_pitch_shift_region(virtual, semitones)
        processed = (processed * effect_gain).astype(np.float32)
    elif effect == "filter":
        cutoff = float(cfg.get("cutoff_hz", cfg.get("effect_param", 1200.0)))
        processed = one_pole_lowpass(virtual, sample_rate, cutoff)
        processed = (processed * effect_gain).astype(np.float32)
    else:
        focus_boost = float(cfg.get("effect_param", 1.0))
        processed = (virtual * effect_gain * focus_boost).astype(np.float32)

    focus_width = env_array(cfg, "focus_width", frames, float(cfg.get("focus_width", 38.0)))
    focus_sharpness = env_array(cfg, "focus_sharpness", frames, float(cfg.get("focus_sharpness", 0.65)))
    wet_amount = env_array(cfg, "wet", frames, float(cfg.get("wet", 1.0)))
    dry_atten = env_array(cfg, "dry_attenuation", frames, float(cfg.get("dry_attenuation", 0.18)))
    az_env = env_array(cfg, "azimuth", frames, float(cfg.get("azimuth", 0.0)))
    el_env = env_array(cfg, "elevation", frames, float(cfg.get("elevation", 0.0)))
    amp_env = env_array(cfg, "amplitude", frames, float(cfg.get("amplitude", 1.0)))

    directions = np.array([unit_from_aed(az, el) for az, el in layout], dtype=np.float64)
    rendered = np.empty_like(virtual, dtype=np.float32)
    block = 2048
    for start in range(0, frames, block):
        end = min(frames, start + block)
        count = end - start
        focus = np.stack([unit_from_aed(az_env[start + i], el_env[start + i]) for i in range(count)], axis=0)
        cosang = np.clip(focus @ directions.T, -1.0, 1.0)
        angle = np.degrees(np.arccos(cosang))
        width = np.maximum(2.0, focus_width[start:end])[:, None]
        mask = np.exp(-0.5 * (angle / width) ** 2).astype(np.float32)
        sharpness = np.clip(focus_sharpness[start:end, None], 0.0, 1.0).astype(np.float32)
        mask = mask ** (1.0 + sharpness * 5.0)
        mask = np.clip(mask, 0.0, 1.0)
        wet = wet_amount[start:end, None].astype(np.float32)
        dry = np.clip(dry_atten[start:end, None], 0.0, 1.0).astype(np.float32)
        amp = amp_env[start:end, None].astype(np.float32)
        dry_gain = 1.0 - mask * (1.0 - dry)
        rendered[start:end] = (virtual[start:end] * dry_gain + processed[start:end] * mask * wet) * amp

    out = (rendered.astype(np.float64) @ encode).astype(np.float32)
    if bool(cfg.get("dc_protect", True)):
        out -= np.mean(out, axis=0, keepdims=True)
    if bool(cfg.get("soft_limit", True)):
        peak = float(np.max(np.abs(out))) if out.size else 0.0
        if peak > 1.0:
            ceiling = 0.92
            out = (ceiling * np.tanh(out / ceiling)).astype(np.float32)
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -6.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out, sample_rate)
    print(f"Ambisonic order: {order}OA")
    print(f"Ambisonic channels: {ambi_channels}")
    print(f"Virtual speakers: {len(layout)}")
    print(f"Effect: {effect}")
    print(f"Dry attenuation at focus: {float(cfg.get('dry_attenuation', 0.18)):.3f}")
    print(f"Focus width: {float(cfg.get('focus_width', 38.0)):.2f} deg")
    print(f"Focus sharpness: {float(cfg.get('focus_sharpness', 0.65)):.3f}")
    print(f"Wet amount: {float(cfg.get('wet', 1.0)):.3f}")
    print(f"Output channels: {ambi_channels}")
    print(f"Sample rate: {sample_rate} Hz")
    print(f"Pre-normalize peak: {pre_peak:.6f}")


def main():
    if len(sys.argv) != 3:
        raise SystemExit("Usage: s3g_numpy_render.py <dense_grain|loop_drift_bed|loop_rift|ir_toolkit|mass_partial|resonant_terrain|partial_trace_resynth|fata_morgana|foafx_offline> <manifest.json>")
    mode = sys.argv[1]
    with open(sys.argv[2], "r", encoding="utf-8") as handle:
        cfg = json.load(handle)
    if mode == "dense_grain":
        render_dense_grain(cfg)
    elif mode == "loop_drift_bed":
        render_loop_drift_bed(cfg)
    elif mode == "loop_rift":
        render_loop_rift(cfg)
    elif mode == "ir_toolkit":
        render_ir_toolkit(cfg)
    elif mode == "mass_partial":
        render_mass_partial(cfg)
    elif mode == "resonant_terrain":
        render_resonant_terrain(cfg)
    elif mode == "partial_trace_resynth":
        render_partial_trace_resynth(cfg)
    elif mode == "fata_morgana":
        render_fata_morgana(cfg)
    elif mode == "foafx_offline":
        render_foafx_offline(cfg)
    else:
        raise RuntimeError(f"Unknown render mode: {mode}")


if __name__ == "__main__":
    main()
