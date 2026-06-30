#!/usr/bin/env python3
import json
import math
import os
import struct
import sys
import csv

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
    cleaned = np.nan_to_num(data, nan=0.0, posinf=0.0, neginf=0.0)
    cleaned = np.where(np.abs(cleaned) < 1e-20, 0.0, cleaned)
    clipped = np.clip(cleaned, -1.0, 1.0)
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


def ambisonic_order_from_channels(channels):
    channels = int(channels)
    if channels >= 16:
        return 3
    if channels >= 9:
        return 2
    if channels >= 4:
        return 1
    return 0


def adapt_ambisonic_ir_order(ir_audio, source_order, target_order):
    source_order = int(source_order)
    target_order = int(target_order)
    source_channels = (source_order + 1) * (source_order + 1)
    target_channels = (target_order + 1) * (target_order + 1)
    if source_order >= target_order:
        return ir_audio[:, :target_channels].astype(np.float32, copy=False)
    if source_order < 1:
        raise RuntimeError("Lower-order IR adaptation needs at least a first-order IR.")
    src = ir_audio[:, :source_channels].astype(np.float32, copy=False)
    out = np.zeros((src.shape[0], target_channels), dtype=np.float32)
    out[:, :source_channels] = src
    if src.shape[0] == 0:
        return out

    w = src[:, 0].astype(np.float64, copy=False)
    # ACN/SN3D order in this file is W, Y, Z, X for first order. The real
    # spherical harmonic basis uses negative X/Y signs, so invert those axes to
    # recover a conventional direction vector.
    x_raw = -src[:, 3].astype(np.float64, copy=False)
    y_raw = -src[:, 1].astype(np.float64, copy=False)
    z_raw = src[:, 2].astype(np.float64, copy=False)
    vector_norm = np.sqrt(x_raw * x_raw + y_raw * y_raw + z_raw * z_raw)
    active = (np.abs(w) > 1e-10) | (vector_norm > 1e-10)

    for frame in np.flatnonzero(active):
        amp = float(w[frame])
        if abs(amp) > 1e-10:
            x = float(x_raw[frame] / amp)
            y = float(y_raw[frame] / amp)
            z = float(z_raw[frame] / amp)
        else:
            amp = float(vector_norm[frame])
            x = float(x_raw[frame] / max(vector_norm[frame], 1e-10))
            y = float(y_raw[frame] / max(vector_norm[frame], 1e-10))
            z = float(z_raw[frame] / max(vector_norm[frame], 1e-10))
        radius = math.sqrt(x * x + y * y + z * z)
        if radius <= 1e-10:
            continue
        x /= radius
        y /= radius
        z /= radius
        az = math.degrees(math.atan2(y, x))
        el = math.degrees(math.asin(max(-1.0, min(1.0, z))))
        encoded = np.array(ambisonic_basis(target_order, az, el), dtype=np.float32) * amp
        out[frame, source_channels:] = encoded[source_channels:]
    return out


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


def smooth_profile_bins(profile, bins):
    bins = int(max(0, bins))
    if bins <= 0:
        return profile
    kernel_size = bins * 2 + 1
    kernel = np.ones(kernel_size, dtype=np.float64) / float(kernel_size)
    padded = np.pad(profile, ((bins, bins), (0, 0)), mode="edge")
    smoothed = np.empty_like(profile, dtype=np.float64)
    for channel in range(profile.shape[1]):
        smoothed[:, channel] = np.convolve(padded[:, channel], kernel, mode="valid")
    return smoothed


def spectral_profile_subtract_region(signal, profile, sample_rate, cfg):
    fft_size = int(cfg.get("fft_size", 2048))
    fft_size = max(256, min(8192, fft_size))
    hop = int(cfg.get("hop_size", fft_size // 4))
    hop = max(64, min(fft_size, hop))
    window = np.hanning(fft_size).astype(np.float32)
    output_mode = str(cfg.get("output_mode", "cleaned"))
    amount = float(np.clip(cfg.get("reduction_amount", 0.75), 0.0, 1.0))
    floor = float(np.clip(cfg.get("spectral_floor", 0.18), 0.0, 1.0))
    sensitivity = float(np.clip(cfg.get("profile_sensitivity", 1.15), 0.1, 8.0))
    profile_mode = str(cfg.get("profile_stat", "median"))
    freq_smoothing = int(cfg.get("frequency_smoothing_bins", 3))
    temporal_smoothing = float(np.clip(cfg.get("temporal_smoothing", 0.35), 0.0, 0.98))

    profile_pad = np.pad(profile, ((0, max(0, fft_size - min(profile.shape[0], fft_size))), (0, 0)), mode="constant")
    profile_frame_count = 1 + max(0, (profile_pad.shape[0] - fft_size) // hop)
    mags = []
    for frame_index in range(profile_frame_count):
        start = frame_index * hop
        frame = profile_pad[start:start + fft_size]
        if frame.shape[0] < fft_size:
            frame = np.pad(frame, ((0, fft_size - frame.shape[0]), (0, 0)), mode="constant")
        spec = np.fft.rfft(frame * window[:, None], axis=0)
        mags.append(np.abs(spec))
    if not mags:
        raise RuntimeError("The profile item is too short to analyze.")
    profile_mags = np.stack(mags, axis=0)
    if profile_mode == "mean":
        noise_profile = np.mean(profile_mags, axis=0)
    else:
        noise_profile = np.median(profile_mags, axis=0)
    noise_profile = smooth_profile_bins(noise_profile, freq_smoothing)

    pad = fft_size
    padded = np.pad(signal, ((pad, pad), (0, 0)), mode="constant")
    out = np.zeros_like(padded, dtype=np.float32)
    norm = np.zeros(padded.shape[0], dtype=np.float32)
    frame_count = 1 + max(0, (padded.shape[0] - fft_size) // hop)
    previous_gain = None
    min_gain_seen = 1.0
    max_reduction_seen = 0.0
    eps = 1e-10

    for frame_index in range(frame_count):
        start = frame_index * hop
        frame = padded[start:start + fft_size] * window[:, None]
        spec = np.fft.rfft(frame, axis=0)
        mag = np.abs(spec)
        phase = np.exp(1j * np.angle(spec))
        target = noise_profile * sensitivity
        subtraction = amount * target
        clean_mag = np.maximum(mag - subtraction, mag * floor)
        gain = clean_mag / np.maximum(mag, eps)
        gain = np.clip(gain, floor, 1.0)
        if previous_gain is not None and temporal_smoothing > 0.0:
            gain = previous_gain * temporal_smoothing + gain * (1.0 - temporal_smoothing)
        previous_gain = gain
        min_gain_seen = min(min_gain_seen, float(np.min(gain)))
        max_reduction_seen = max(max_reduction_seen, float(np.max(1.0 - gain)))
        if output_mode == "residue":
            new_spec = spec - (mag * gain * phase)
        else:
            new_spec = mag * gain * phase
        resynth = np.fft.irfft(new_spec, n=fft_size, axis=0).real.astype(np.float32)
        out[start:start + fft_size] += resynth * window[:, None]
        norm[start:start + fft_size] += window * window

    out /= np.maximum(norm[:, None], 1e-8)
    result = out[pad:pad + signal.shape[0]].astype(np.float32)
    stats = {
        "profile_frames": profile_frame_count,
        "source_frames": frame_count,
        "fft_size": fft_size,
        "hop_size": hop,
        "min_gain": min_gain_seen,
        "max_reduction": max_reduction_seen,
    }
    return result, stats


def spectral_profile_tool_region(signal, profile, sample_rate, cfg):
    mode = str(cfg.get("process_kind", "subtract"))
    if mode in ("subtract", "residue", "hole"):
        local_cfg = dict(cfg)
        if mode == "residue":
            local_cfg["output_mode"] = "residue"
        else:
            local_cfg["output_mode"] = "cleaned"
        return spectral_profile_subtract_region(signal, profile, sample_rate, local_cfg)

    fft_size = int(cfg.get("fft_size", 2048))
    fft_size = max(256, min(8192, fft_size))
    hop = int(cfg.get("hop_size", fft_size // 4))
    hop = max(64, min(fft_size, hop))
    window = np.hanning(fft_size).astype(np.float32)
    amount = float(np.clip(cfg.get("reduction_amount", 0.75), 0.0, 1.0))
    floor = float(np.clip(cfg.get("spectral_floor", 0.18), 0.0, 1.0))
    sensitivity = float(np.clip(cfg.get("profile_sensitivity", 1.15), 0.1, 8.0))
    profile_mode = str(cfg.get("profile_stat", "median"))
    freq_smoothing = int(cfg.get("frequency_smoothing_bins", 3))
    temporal_smoothing = float(np.clip(cfg.get("temporal_smoothing", 0.35), 0.0, 0.98))

    profile_pad = np.pad(profile, ((0, max(0, fft_size - min(profile.shape[0], fft_size))), (0, 0)), mode="constant")
    profile_frame_count = 1 + max(0, (profile_pad.shape[0] - fft_size) // hop)
    mags = []
    for frame_index in range(profile_frame_count):
        start = frame_index * hop
        frame = profile_pad[start:start + fft_size]
        if frame.shape[0] < fft_size:
            frame = np.pad(frame, ((0, fft_size - frame.shape[0]), (0, 0)), mode="constant")
        mags.append(np.abs(np.fft.rfft(frame * window[:, None], axis=0)))
    if not mags:
        raise RuntimeError("The profile item is too short to analyze.")
    profile_mags = np.stack(mags, axis=0)
    if profile_mode == "mean":
        profile_mag = np.mean(profile_mags, axis=0)
    else:
        profile_mag = np.median(profile_mags, axis=0)
    profile_mag = smooth_profile_bins(profile_mag, freq_smoothing)

    eps = 1e-10
    if mode == "match":
        profile_shape = profile_mag / np.maximum(np.mean(profile_mag, axis=0, keepdims=True), eps)
        profile_shape = 1.0 + (profile_shape - 1.0) * sensitivity
        profile_shape = np.clip(profile_shape, 0.05, 16.0)

    pad = fft_size
    padded = np.pad(signal, ((pad, pad), (0, 0)), mode="constant")
    out = np.zeros_like(padded, dtype=np.float32)
    norm = np.zeros(padded.shape[0], dtype=np.float32)
    frame_count = 1 + max(0, (padded.shape[0] - fft_size) // hop)
    previous_gain = None
    min_gain_seen = 1.0
    max_gain_seen = 0.0
    max_reduction_seen = 0.0

    for frame_index in range(frame_count):
        start = frame_index * hop
        frame = padded[start:start + fft_size] * window[:, None]
        spec = np.fft.rfft(frame, axis=0)
        mag = np.abs(spec)
        phase = np.exp(1j * np.angle(spec))

        if mode == "match":
            frame_energy = np.mean(mag, axis=0, keepdims=True)
            target_mag = frame_energy * profile_shape
            blend = amount
            new_mag = mag * (1.0 - blend) + target_mag * blend
            max_match_gain = 1.0 + 3.0 * amount
            gain = np.clip(new_mag / np.maximum(mag, eps), max(0.02, floor), max_match_gain)
        elif mode == "ambience":
            mask = (profile_mag * sensitivity) / np.maximum(mag + profile_mag * sensitivity, eps)
            mask = np.clip(mask, 0.0, 1.0)
            gain = np.clip(floor + (1.0 - floor) * mask * amount, 0.0, 1.0)
        else:
            gain = np.ones_like(mag)

        if previous_gain is not None and temporal_smoothing > 0.0:
            gain = previous_gain * temporal_smoothing + gain * (1.0 - temporal_smoothing)
        previous_gain = gain
        min_gain_seen = min(min_gain_seen, float(np.min(gain)))
        max_gain_seen = max(max_gain_seen, float(np.max(gain)))
        max_reduction_seen = max(max_reduction_seen, float(np.max(1.0 - np.minimum(gain, 1.0))))
        new_spec = mag * gain * phase
        resynth = np.fft.irfft(new_spec, n=fft_size, axis=0).real.astype(np.float32)
        out[start:start + fft_size] += resynth * window[:, None]
        norm[start:start + fft_size] += window * window

    out /= np.maximum(norm[:, None], 1e-8)
    result = out[pad:pad + signal.shape[0]].astype(np.float32)
    stats = {
        "profile_frames": profile_frame_count,
        "source_frames": frame_count,
        "fft_size": fft_size,
        "hop_size": hop,
        "min_gain": min_gain_seen,
        "max_gain": max_gain_seen,
        "max_reduction": max_reduction_seen,
    }
    return result, stats


def render_foafx_spectral_profile_tool(cfg):
    source, source_rate = read_wav(cfg["source_path"])
    profile, profile_rate = read_wav(cfg["profile_path"])
    sample_rate = int(cfg.get("sample_rate", source_rate))
    audio = segment(source, source_rate, cfg.get("source_start", 0.0), cfg.get("source_duration", 1.0), sample_rate)
    profile_audio = segment(profile, profile_rate, cfg.get("profile_start", 0.0), cfg.get("profile_duration", 1.0), sample_rate)
    order = int(cfg.get("order", 3))
    order = max(1, min(3, order))
    ambi_channels = (order + 1) * (order + 1)
    if audio.shape[1] < ambi_channels:
        raise RuntimeError(f"Selected source has {audio.shape[1]} channels, but {order}OA needs {ambi_channels}.")
    if profile_audio.shape[1] < ambi_channels:
        raise RuntimeError(f"Selected profile has {profile_audio.shape[1]} channels, but {order}OA needs {ambi_channels}.")
    audio = audio[:, :ambi_channels].astype(np.float32, copy=False)
    profile_audio = profile_audio[:, :ambi_channels].astype(np.float32, copy=False)

    layout = foafx_layout(order)
    basis = np.array([ambisonic_basis(order, az, el) for az, el in layout], dtype=np.float64)
    decode = basis.T
    encode = np.linalg.pinv(basis).T
    virtual_source = (audio.astype(np.float64) @ decode).astype(np.float32)
    virtual_profile = (profile_audio.astype(np.float64) @ decode).astype(np.float32)

    processed, stats = spectral_profile_tool_region(virtual_source, virtual_profile, sample_rate, cfg)
    out = (processed.astype(np.float64) @ encode).astype(np.float32)
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
    process_name = str(cfg.get("process_name", "3OAFX Spectral Profile Tool"))
    print(f"Process: {process_name}")
    print(f"Ambisonic order: {order}OA")
    print(f"Ambisonic channels: {ambi_channels}")
    print(f"Virtual speakers: {len(layout)}")
    print(f"Process kind: {str(cfg.get('process_kind', 'subtract'))}")
    print(f"Output mode: {str(cfg.get('output_mode', 'cleaned'))}")
    print(f"Profile statistic: {str(cfg.get('profile_stat', 'median'))}")
    print(f"Reduction amount: {float(cfg.get('reduction_amount', 0.75)):.3f}")
    print(f"Spectral floor: {float(cfg.get('spectral_floor', 0.18)):.3f}")
    print(f"Profile sensitivity: {float(cfg.get('profile_sensitivity', 1.15)):.3f}")
    print(f"Frequency smoothing bins: {int(cfg.get('frequency_smoothing_bins', 3))}")
    print(f"Temporal smoothing: {float(cfg.get('temporal_smoothing', 0.35)):.3f}")
    print(f"FFT / hop: {stats['fft_size']} / {stats['hop_size']}")
    print(f"Profile STFT frames: {stats['profile_frames']}")
    print(f"Source STFT frames: {stats['source_frames']}")
    print(f"Max spectral reduction: {stats['max_reduction']:.3f}")
    print(f"Minimum spectral gain: {stats['min_gain']:.3f}")
    if "max_gain" in stats:
        print(f"Maximum spectral gain: {stats['max_gain']:.3f}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")
    print(f"Output channels: {ambi_channels}")
    print(f"Sample rate: {sample_rate} Hz")


def render_foafx_profile_subtract(cfg):
    cfg = dict(cfg)
    cfg["process_kind"] = "subtract"
    cfg["process_name"] = "3OAFX Spectral Profile Subtract"
    render_foafx_spectral_profile_tool(cfg)


def spectral_object_field_split_region(signal, sample_rate, cfg):
    fft_size = int(cfg.get("fft_size", 2048))
    fft_size = max(256, min(8192, fft_size))
    hop = int(cfg.get("hop_size", fft_size // 4))
    hop = max(64, min(fft_size, hop))
    window = np.hanning(fft_size).astype(np.float32)
    object_bias = float(np.clip(cfg.get("object_bias", 0.55), 0.0, 1.0))
    transient_weight = float(np.clip(cfg.get("transient_weight", 0.45), 0.0, 1.0))
    coherence_weight = float(np.clip(cfg.get("coherence_weight", 0.45), 0.0, 1.0))
    contrast_weight = float(np.clip(cfg.get("contrast_weight", 0.30), 0.0, 1.0))
    field_smoothing = float(np.clip(cfg.get("field_smoothing", 0.45), 0.0, 0.98))
    crossfade = float(np.clip(cfg.get("crossfade", 0.18), 0.0, 0.75))
    freq_smoothing = int(max(0, cfg.get("frequency_smoothing_bins", 3)))
    temporal_smoothing = float(np.clip(cfg.get("temporal_smoothing", 0.35), 0.0, 0.98))
    eps = 1e-10

    pad = fft_size
    padded = np.pad(signal, ((pad, pad), (0, 0)), mode="constant")
    object_out = np.zeros_like(padded, dtype=np.float32)
    field_out = np.zeros_like(padded, dtype=np.float32)
    norm = np.zeros(padded.shape[0], dtype=np.float32)
    frame_count = 1 + max(0, (padded.shape[0] - fft_size) // hop)
    previous_mag = None
    previous_object = None
    object_mask_min = 1.0
    object_mask_max = 0.0
    object_mask_mean_sum = 0.0

    for frame_index in range(frame_count):
        start = frame_index * hop
        frame = padded[start:start + fft_size] * window[:, None]
        spec = np.fft.rfft(frame, axis=0)
        mag = np.abs(spec)
        phase = np.exp(1j * np.angle(spec))
        bins, channels = mag.shape

        total = np.sum(mag, axis=1, keepdims=True)
        max_dir = np.max(mag, axis=1, keepdims=True)
        coherence = np.clip((max_dir / np.maximum(total, eps) - (1.0 / max(1, channels))) /
                            max(eps, 1.0 - (1.0 / max(1, channels))), 0.0, 1.0)
        coherence = np.repeat(coherence, channels, axis=1)

        if previous_mag is None:
            transient = np.zeros_like(mag)
        else:
            flux = np.maximum(0.0, mag - previous_mag)
            transient = np.clip(flux / np.maximum(mag + previous_mag, eps), 0.0, 1.0)
        previous_mag = mag

        if freq_smoothing > 0:
            local_mean = smooth_profile_bins(mag, freq_smoothing)
            contrast = np.clip(np.maximum(0.0, mag - local_mean) / np.maximum(mag + local_mean, eps), 0.0, 1.0)
        else:
            contrast = np.zeros_like(mag)

        combined_weight = transient_weight + coherence_weight + contrast_weight + eps
        object_score = (
            transient * transient_weight +
            coherence * coherence_weight +
            contrast * contrast_weight
        ) / combined_weight
        object_score = np.clip(object_score * (0.55 + object_bias * 1.85), 0.0, 1.0)
        object_score = np.clip(object_score * (1.0 - crossfade) + crossfade * 0.5, 0.0, 1.0)
        if previous_object is not None and temporal_smoothing > 0.0:
            object_score = previous_object * temporal_smoothing + object_score * (1.0 - temporal_smoothing)
        previous_object = object_score
        field_score = 1.0 - object_score
        if field_smoothing > 0.0:
            field_blur = smooth_profile_bins(field_score, max(1, freq_smoothing + 1))
            field_score = field_score * (1.0 - field_smoothing) + field_blur * field_smoothing
            field_score = np.clip(field_score, 0.0, 1.0)
            object_score = np.clip(1.0 - field_score, 0.0, 1.0)

        object_mask_min = min(object_mask_min, float(np.min(object_score)))
        object_mask_max = max(object_mask_max, float(np.max(object_score)))
        object_mask_mean_sum += float(np.mean(object_score))
        object_spec = mag * object_score * phase
        field_spec = mag * field_score * phase
        object_frame = np.fft.irfft(object_spec, n=fft_size, axis=0).real.astype(np.float32)
        field_frame = np.fft.irfft(field_spec, n=fft_size, axis=0).real.astype(np.float32)
        object_out[start:start + fft_size] += object_frame * window[:, None]
        field_out[start:start + fft_size] += field_frame * window[:, None]
        norm[start:start + fft_size] += window * window

    object_out /= np.maximum(norm[:, None], 1e-8)
    field_out /= np.maximum(norm[:, None], 1e-8)
    stats = {
        "source_frames": frame_count,
        "fft_size": fft_size,
        "hop_size": hop,
        "object_mask_min": object_mask_min,
        "object_mask_max": object_mask_max,
        "object_mask_mean": object_mask_mean_sum / max(1, frame_count),
    }
    return object_out[pad:pad + signal.shape[0]].astype(np.float32), field_out[pad:pad + signal.shape[0]].astype(np.float32), stats


def render_foafx_object_field_split(cfg):
    source, source_rate = read_wav(cfg["source_path"])
    sample_rate = int(cfg.get("sample_rate", source_rate))
    audio = segment(source, source_rate, cfg.get("source_start", 0.0), cfg.get("source_duration", 1.0), sample_rate)
    order = int(cfg.get("order", 3))
    order = max(1, min(3, order))
    ambi_channels = (order + 1) * (order + 1)
    if audio.shape[1] < ambi_channels:
        raise RuntimeError(f"Selected source has {audio.shape[1]} channels, but {order}OA needs {ambi_channels}.")
    audio = audio[:, :ambi_channels].astype(np.float32, copy=False)

    layout = foafx_layout(order)
    basis = np.array([ambisonic_basis(order, az, el) for az, el in layout], dtype=np.float64)
    decode = basis.T
    encode = np.linalg.pinv(basis).T
    virtual_source = (audio.astype(np.float64) @ decode).astype(np.float32)
    object_virtual, field_virtual, stats = spectral_object_field_split_region(virtual_source, sample_rate, cfg)
    object_out = (object_virtual.astype(np.float64) @ encode).astype(np.float32)
    field_out = (field_virtual.astype(np.float64) @ encode).astype(np.float32)
    if bool(cfg.get("dc_protect", True)):
        object_out -= np.mean(object_out, axis=0, keepdims=True)
        field_out -= np.mean(field_out, axis=0, keepdims=True)
    object_pre = float(np.max(np.abs(object_out))) if object_out.size else 0.0
    field_pre = float(np.max(np.abs(field_out))) if field_out.size else 0.0
    if bool(cfg.get("normalize", True)):
        object_out, object_pre = normalize_peak(object_out, float(cfg.get("normalize_db", -6.0)))
        field_out, field_pre = normalize_peak(field_out, float(cfg.get("normalize_db", -6.0)))

    output_mode = str(cfg.get("output_mode", "both")).lower()
    written = []
    if output_mode in ("both", "object"):
        write_pcm24_wav(cfg["object_output_path"], object_out[:, :ambi_channels], sample_rate)
        written.append(cfg["object_output_path"])
    if output_mode in ("both", "field"):
        write_pcm24_wav(cfg["field_output_path"], field_out[:, :ambi_channels], sample_rate)
        written.append(cfg["field_output_path"])

    print("Process: 3OAFX Object / Field Split")
    print(f"Ambisonic order: {order}OA")
    print(f"Ambisonic channels: {ambi_channels}")
    print(f"Virtual speakers: {len(layout)}")
    print(f"Output mode: {output_mode}")
    print(f"Object bias: {float(cfg.get('object_bias', 0.55)):.3f}")
    print(f"Transient weight: {float(cfg.get('transient_weight', 0.45)):.3f}")
    print(f"Coherence weight: {float(cfg.get('coherence_weight', 0.45)):.3f}")
    print(f"Contrast weight: {float(cfg.get('contrast_weight', 0.30)):.3f}")
    print(f"FFT / hop: {stats['fft_size']} / {stats['hop_size']}")
    print(f"Source STFT frames: {stats['source_frames']}")
    print(f"Object mask min/mean/max: {stats['object_mask_min']:.3f} / {stats['object_mask_mean']:.3f} / {stats['object_mask_max']:.3f}")
    print(f"Object pre-normalize peak: {object_pre:.6f}")
    print(f"Field pre-normalize peak: {field_pre:.6f}")
    print(f"Written files: {len(written)}")
    for path in written:
        print(f"Output: {path}")


def map_profile_channels(profile_audio, source_channels, mode):
    mode = str(mode or "matched")
    profile_channels = int(profile_audio.shape[1])
    source_channels = int(source_channels)
    if profile_channels <= 0:
        raise RuntimeError("Profile audio has no channels.")
    if mode == "summed":
        mono = np.mean(profile_audio, axis=1, keepdims=True)
        return np.repeat(mono, source_channels, axis=1).astype(np.float32, copy=False)
    if mode == "wrap":
        indices = np.arange(source_channels) % profile_channels
        return profile_audio[:, indices].astype(np.float32, copy=False)
    if profile_channels < source_channels:
        raise RuntimeError(
            f"Matched channel mode needs at least {source_channels} profile channels; "
            f"selected profile has {profile_channels}."
        )
    return profile_audio[:, :source_channels].astype(np.float32, copy=False)


def render_multichannel_spectral_profile_tool(cfg):
    source, source_rate = read_wav(cfg["source_path"])
    profile, profile_rate = read_wav(cfg["profile_path"])
    sample_rate = int(cfg.get("sample_rate", source_rate))
    audio = segment(source, source_rate, cfg.get("source_start", 0.0), cfg.get("source_duration", 1.0), sample_rate)
    profile_audio = segment(profile, profile_rate, cfg.get("profile_start", 0.0), cfg.get("profile_duration", 1.0), sample_rate)
    if audio.ndim == 1:
        audio = audio[:, None]
    if profile_audio.ndim == 1:
        profile_audio = profile_audio[:, None]
    source_channels = int(audio.shape[1])
    if source_channels < 1:
        raise RuntimeError("Source audio has no channels.")
    if source_channels > 128:
        raise RuntimeError(f"REAPER supports up to 128 channels; source has {source_channels}.")
    channel_mode = str(cfg.get("channel_mode", "matched"))
    profile_mapped = map_profile_channels(profile_audio, source_channels, channel_mode)
    audio = audio[:, :source_channels].astype(np.float32, copy=False)

    processed, stats = spectral_profile_tool_region(audio, profile_mapped, sample_rate, cfg)
    out = processed.astype(np.float32, copy=False)
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
    process_name = str(cfg.get("process_name", "Spectral Profile Tool"))
    print(f"Process: {process_name}")
    print(f"Source channels: {source_channels}")
    print(f"Profile channels: {int(profile_audio.shape[1])}")
    print(f"Channel mode: {channel_mode}")
    print(f"Process kind: {str(cfg.get('process_kind', 'subtract'))}")
    print(f"Output mode: {str(cfg.get('output_mode', 'cleaned'))}")
    print(f"Profile statistic: {str(cfg.get('profile_stat', 'median'))}")
    print(f"Reduction amount: {float(cfg.get('reduction_amount', 0.75)):.3f}")
    print(f"Spectral floor: {float(cfg.get('spectral_floor', 0.18)):.3f}")
    print(f"Profile sensitivity: {float(cfg.get('profile_sensitivity', 1.15)):.3f}")
    print(f"Frequency smoothing bins: {int(cfg.get('frequency_smoothing_bins', 3))}")
    print(f"Temporal smoothing: {float(cfg.get('temporal_smoothing', 0.35)):.3f}")
    print(f"FFT / hop: {stats['fft_size']} / {stats['hop_size']}")
    print(f"Profile STFT frames: {stats['profile_frames']}")
    print(f"Source STFT frames: {stats['source_frames']}")
    print(f"Max spectral reduction: {stats['max_reduction']:.3f}")
    print(f"Minimum spectral gain: {stats['min_gain']:.3f}")
    if "max_gain" in stats:
        print(f"Maximum spectral gain: {stats['max_gain']:.3f}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")
    print(f"Output channels: {source_channels}")
    print(f"Sample rate: {sample_rate} Hz")


def apply_hoa_yaw(audio, order, angle_deg):
    order = int(max(1, min(3, order)))
    channels = (order + 1) * (order + 1)
    out = audio[:, :channels].astype(np.float32, copy=True)
    angle = math.radians(float(angle_deg))
    index = 0
    for n in range(order + 1):
        pairs = {}
        for m in range(-n, n + 1):
            pairs[m] = index
            index += 1
        for m in range(1, n + 1):
            sin_i = pairs.get(-m)
            cos_i = pairs.get(m)
            if sin_i is None or cos_i is None:
                continue
            c = math.cos(m * angle)
            s = math.sin(m * angle)
            sin_v = audio[:, sin_i].astype(np.float32, copy=False)
            cos_v = audio[:, cos_i].astype(np.float32, copy=False)
            out[:, sin_i] = sin_v * c - cos_v * s
            out[:, cos_i] = sin_v * s + cos_v * c
    return out


def apply_hoa_order_weights(audio, order, first_weight, second_weight, third_weight, w_weight=1.0):
    weights = {0: float(w_weight), 1: float(first_weight), 2: float(second_weight), 3: float(third_weight)}
    out = audio.copy()
    index = 0
    for n in range(int(order) + 1):
        count = 2 * n + 1
        out[:, index:index + count] *= weights.get(n, 1.0)
        index += count
    return out


def render_foafx_spatial_granulator(cfg):
    source, source_rate = read_wav(cfg["source_path"])
    sample_rate = int(cfg.get("sample_rate", source_rate))
    audio = segment(source, source_rate, cfg.get("source_start", 0.0), cfg.get("source_duration", 1.0), sample_rate)
    order = int(cfg.get("order", ambisonic_order_from_channels(audio.shape[1])))
    order = max(1, min(3, order))
    ambi_channels = (order + 1) * (order + 1)
    if audio.shape[1] < ambi_channels:
        raise RuntimeError(f"Selected source has {audio.shape[1]} channels, but {order}OA needs {ambi_channels}.")
    audio = audio[:, :ambi_channels].astype(np.float32, copy=False)
    duration = float(cfg.get("duration", audio.shape[0] / sample_rate))
    out_frames = max(1, int(round(duration * sample_rate)))
    grain_ms = float(cfg.get("grain_ms", 80.0))
    grain_frames = max(8, int(round(grain_ms * sample_rate / 1000.0)))
    density = max(0.1, float(cfg.get("density", 24.0)))
    event_count = max(1, int(round(duration * density)))
    overlap_gain = 1.0 / math.sqrt(max(1.0, density * grain_ms / 1000.0))
    rng = np.random.default_rng(int(cfg.get("seed", 1)))
    mode = str(cfg.get("navigation_mode", "scan"))
    jitter = float(np.clip(cfg.get("position_jitter", 0.12), 0.0, 1.0))
    rate = float(cfg.get("rate", 1.0))
    rate_jitter = float(np.clip(cfg.get("rate_jitter", 0.05), 0.0, 2.0))
    reverse_prob = float(np.clip(cfg.get("reverse_probability", 0.0), 0.0, 1.0))
    yaw_start = float(cfg.get("yaw_start", 0.0))
    yaw_end = float(cfg.get("yaw_end", 0.0))
    yaw_scatter = float(max(0.0, cfg.get("yaw_scatter", 0.0)))
    room_memory = float(np.clip(cfg.get("room_memory", 0.35), 0.0, 1.0))
    doppler = float(np.clip(cfg.get("doppler_rate", 0.0), 0.0, 1.0))
    dual_a = float(np.clip(cfg.get("dual_a", 0.18), 0.0, 1.0))
    dual_b = float(np.clip(cfg.get("dual_b", 0.82), 0.0, 1.0))
    higher_weight = float(np.clip(cfg.get("higher_order_weight", 1.0), 0.0, 2.0))
    w_weight = float(np.clip(cfg.get("w_weight", 1.0), 0.0, 2.0))
    if room_memory > 0.0:
        grain_frames = max(grain_frames, int(round((40.0 + 220.0 * room_memory) * sample_rate / 1000.0)))
    window = np.hanning(grain_frames).astype(np.float32)
    out = np.zeros((out_frames + grain_frames + 4, ambi_channels), dtype=np.float32)
    norm = np.zeros(out.shape[0], dtype=np.float32)
    max_start = max(1, audio.shape[0] - grain_frames - 2)
    positions = []

    def source_position(frac):
        if mode == "cloud":
            base = rng.random()
        elif mode == "dual":
            blend = 0.5 + 0.5 * math.sin(2.0 * math.pi * frac)
            base = dual_a * (1.0 - blend) + dual_b * blend
        elif mode == "jump":
            steps = max(2, int(cfg.get("jump_steps", 8)))
            base = math.floor(frac * steps) / max(1, steps - 1)
        elif mode == "freeze":
            base = float(cfg.get("freeze_position", 0.5))
        else:
            base = frac
        base += (rng.random() * 2.0 - 1.0) * jitter
        return float(np.clip(base, 0.0, 1.0))

    for event in range(event_count):
        frac = event / max(1, event_count - 1)
        out_start = int(round(frac * max(1, out_frames - 1)))
        src_frac = source_position(frac)
        src_start = int(round(src_frac * max_start))
        local_rate = rate * (2.0 ** ((rng.random() * 2.0 - 1.0) * rate_jitter))
        if doppler > 0.0 and event > 0:
            local_rate *= 1.0 + (src_frac - positions[-1]) * doppler * 2.0
        positions.append(src_frac)
        if rng.random() < reverse_prob:
            local_rate *= -1.0
        read = src_start + np.arange(grain_frames, dtype=np.float64) * local_rate
        read = np.clip(read, 0.0, audio.shape[0] - 1.0)
        i0 = np.floor(read).astype(np.int64)
        i1 = np.clip(i0 + 1, 0, audio.shape[0] - 1)
        frac_read = (read - i0)[:, None].astype(np.float32)
        grain = audio[i0] * (1.0 - frac_read) + audio[i1] * frac_read
        yaw = yaw_start + (yaw_end - yaw_start) * frac + (rng.random() * 2.0 - 1.0) * yaw_scatter
        if abs(yaw) > 1e-9:
            grain = apply_hoa_yaw(grain, order, yaw)
        if higher_weight != 1.0 or w_weight != 1.0:
            grain = apply_hoa_order_weights(grain, order, higher_weight, higher_weight, higher_weight, w_weight)
        end = min(out_start + grain_frames, out.shape[0])
        count = end - out_start
        if count <= 0:
            continue
        shaped = grain[:count] * window[:count, None] * overlap_gain
        out[out_start:end] += shaped
        norm[out_start:end] += window[:count] * window[:count]

    out = out[:out_frames]
    if bool(cfg.get("normalize_overlap", True)):
        out /= np.maximum(np.sqrt(norm[:out_frames, None]), 0.25)
    if bool(cfg.get("dc_protect", True)):
        out -= np.mean(out, axis=0, keepdims=True)
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -6.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out.astype(np.float32), sample_rate)
    print("Process: 3OAFX Spatial Grains")
    print(f"Ambisonic order: {order}OA")
    print(f"Output channels: {ambi_channels}")
    print(f"Navigation mode: {mode}")
    print(f"Grains: {event_count}")
    print(f"Grain size ms: {grain_ms:.2f}")
    print(f"Density: {density:.2f}")
    print(f"Yaw start/end/scatter: {yaw_start:.2f} / {yaw_end:.2f} / {yaw_scatter:.2f}")
    print(f"Room memory: {room_memory:.3f}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")
    print(f"Sample rate: {sample_rate} Hz")


def render_foafx_pulsar_field(cfg):
    sample_rate = int(cfg.get("sample_rate", 48000))
    duration = max(0.05, float(cfg.get("duration", 8.0)))
    order = max(1, min(3, int(cfg.get("order", 3))))
    ambi_channels = (order + 1) * (order + 1)
    frames = max(1, int(round(duration * sample_rate)))
    out = np.zeros((frames, ambi_channels), dtype=np.float32)
    rng = np.random.default_rng(int(cfg.get("seed", 1)))

    streams = max(1, min(12, int(cfg.get("streams", 3))))
    fund_start = max(0.05, float(cfg.get("fund_start", 8.0)))
    fund_end = max(0.05, float(cfg.get("fund_end", 38.0)))
    form_start = max(20.0, float(cfg.get("form_start", 220.0)))
    form_end = max(20.0, float(cfg.get("form_end", 1800.0)))
    train_curve = str(cfg.get("train_curve", "rise"))
    mask_mode = str(cfg.get("mask_mode", "stochastic"))
    pulse_probability = float(np.clip(cfg.get("pulse_probability", 0.86), 0.0, 1.0))
    burst_on = max(1, int(cfg.get("burst_on", 5)))
    burst_off = max(0, int(cfg.get("burst_off", 3)))
    edge = float(np.clip(cfg.get("edge", 0.35), 0.0, 1.0))
    pulsaret = str(cfg.get("pulsaret", "sine"))
    envelope_shape = str(cfg.get("envelope", "hann"))
    amp = 10.0 ** (float(cfg.get("gain_db", -12.0)) / 20.0)
    yaw_start = float(cfg.get("yaw_start", -90.0))
    yaw_end = float(cfg.get("yaw_end", 90.0))
    elevation = float(np.clip(cfg.get("elevation", 0.0), -89.0, 89.0))
    spatial_spread = float(np.clip(cfg.get("spatial_spread", 0.25), 0.0, 1.0))
    formant_scatter = float(np.clip(cfg.get("formant_scatter", 0.18), 0.0, 1.0))
    drift = float(np.clip(cfg.get("drift", 0.12), 0.0, 1.0))
    channel_mask = float(np.clip(cfg.get("channel_mask", 0.0), 0.0, 1.0))

    def curve_value(u):
        u = float(np.clip(u, 0.0, 1.0))
        if train_curve == "fall":
            return 1.0 - u
        if train_curve == "arch":
            return math.sin(math.pi * u)
        if train_curve == "valley":
            return 1.0 - math.sin(math.pi * u)
        if train_curve == "wander":
            return np.clip(u + 0.18 * math.sin(2.0 * math.pi * u * 3.0), 0.0, 1.0)
        return u

    def pulse_env(n):
        if envelope_shape == "expo":
            x = np.linspace(0.0, 1.0, n, dtype=np.float32)
            return np.exp(-5.0 * x).astype(np.float32)
        if envelope_shape == "reverse expo":
            x = np.linspace(0.0, 1.0, n, dtype=np.float32)
            return np.exp(-5.0 * (1.0 - x)).astype(np.float32)
        if envelope_shape == "rect":
            return np.ones(n, dtype=np.float32)
        alpha = 0.25 + 0.70 * (1.0 - edge)
        if n <= 2:
            return np.ones(n, dtype=np.float32)
        x = np.linspace(0.0, 1.0, n, dtype=np.float32)
        env = np.ones(n, dtype=np.float32)
        attack = x < alpha * 0.5
        release = x > 1.0 - alpha * 0.5
        env[attack] = 0.5 - 0.5 * np.cos(np.pi * x[attack] / max(1e-6, alpha * 0.5))
        env[release] = 0.5 - 0.5 * np.cos(np.pi * (1.0 - x[release]) / max(1e-6, alpha * 0.5))
        return env

    def pulsaret_wave(n, stream_index, local_form):
        phase = np.linspace(0.0, 1.0, n, endpoint=False, dtype=np.float32)
        if pulsaret == "overtone":
            sig = np.sin(2 * np.pi * phase)
            sig += 0.42 * np.sin(4 * np.pi * phase)
            sig += 0.22 * np.sin(6 * np.pi * phase)
            return (sig / 1.64).astype(np.float32)
        if pulsaret == "impulse":
            sig = np.zeros(n, dtype=np.float32)
            sig[0:max(1, min(n, 3))] = 1.0
            return sig
        if pulsaret == "fold":
            sig = np.sin(2 * np.pi * phase) + 0.35 * np.sin(2 * np.pi * phase * (2.0 + stream_index))
            return np.tanh(sig * 2.2).astype(np.float32)
        if pulsaret == "noise":
            return rng.normal(0.0, 0.55, n).astype(np.float32)
        return np.sin(2 * np.pi * phase).astype(np.float32)

    total_events = 0
    for stream in range(streams):
        t = 0.0
        phase_count = 0
        stream_gain = amp / math.sqrt(streams)
        stream_offset = (stream / max(1, streams - 1) - 0.5) * 2.0 if streams > 1 else 0.0
        while t < duration:
            u = t / duration
            cu = curve_value(u)
            fund = fund_start * (1.0 - cu) + fund_end * cu
            fund *= 2.0 ** (drift * 0.08 * math.sin((stream + 1) * 2.0 * math.pi * u + stream))
            period = 1.0 / max(0.05, fund)
            do_emit = True
            if mask_mode == "burst":
                cycle = burst_on + burst_off
                do_emit = cycle <= 0 or (phase_count % cycle) < burst_on
            elif mask_mode == "channel":
                do_emit = ((phase_count + stream) % max(2, streams)) == 0
            elif mask_mode == "stochastic":
                local_prob = pulse_probability * (0.65 + 0.35 * math.sin(math.pi * u))
                do_emit = rng.random() < local_prob
            if do_emit:
                form = form_start * (1.0 - cu) + form_end * cu
                form *= 2.0 ** (rng.normal(0.0, formant_scatter * 0.35))
                pulse_frames = max(8, int(round(sample_rate / max(20.0, form))))
                start = int(round(t * sample_rate))
                if start < frames:
                    count = min(pulse_frames, frames - start)
                    wave = pulsaret_wave(count, stream, form)
                    env = pulse_env(count)
                    az = yaw_start + (yaw_end - yaw_start) * u + stream_offset * spatial_spread * 120.0
                    el = elevation + math.sin(2.0 * math.pi * u + stream) * spatial_spread * 35.0
                    basis = np.array(ambisonic_basis(order, az, np.clip(el, -89.0, 89.0)), dtype=np.float32)
                    if channel_mask > 0.0:
                        basis *= (1.0 - channel_mask) + channel_mask * rng.uniform(0.25, 1.0, basis.shape[0]).astype(np.float32)
                    out[start:start + count] += (wave * env * stream_gain)[:, None] * basis[None, :]
                    total_events += 1
            t += period
            phase_count += 1

    if bool(cfg.get("dc_protect", True)):
        out -= np.mean(out, axis=0, keepdims=True)
    if bool(cfg.get("soft_limit", True)):
        out = np.tanh(out * 1.2).astype(np.float32) / 1.2
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -6.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out.astype(np.float32), sample_rate)
    print("Process: 3OAFX Pulsar Field")
    print(f"Ambisonic order: {order}OA")
    print(f"Output channels: {ambi_channels}")
    print(f"Streams: {streams}")
    print(f"Fundamental: {fund_start:.2f} -> {fund_end:.2f} Hz")
    print(f"Formant: {form_start:.2f} -> {form_end:.2f} Hz")
    print(f"Mask mode: {mask_mode}")
    print(f"Pulsars emitted: {total_events}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")


def render_foafx_particle_cloud(cfg):
    source, source_rate = read_wav(cfg["source_path"])
    sample_rate = int(cfg.get("sample_rate", source_rate))
    audio = segment(source, source_rate, cfg.get("source_start", 0.0), cfg.get("source_duration", 1.0), sample_rate)
    order = max(1, min(3, int(cfg.get("order", ambisonic_order_from_channels(audio.shape[1])))))
    ambi_channels = (order + 1) * (order + 1)
    if audio.shape[1] < ambi_channels:
        raise RuntimeError(f"Selected source has {audio.shape[1]} channels, but {order}OA needs {ambi_channels}.")
    audio = audio[:, :ambi_channels].astype(np.float32, copy=False)
    duration = max(0.05, float(cfg.get("duration", audio.shape[0] / sample_rate)))
    out_frames = max(1, int(round(duration * sample_rate)))
    rng = np.random.default_rng(int(cfg.get("seed", 1)))

    density = max(0.1, float(cfg.get("density", 48.0)))
    asynch = float(np.clip(cfg.get("asynchronicity", 0.65), 0.0, 1.0))
    intermittency = float(np.clip(cfg.get("intermittency", 0.15), 0.0, 0.98))
    streams = max(1, min(16, int(cfg.get("streams", 4))))
    grain_ms = max(2.0, float(cfg.get("grain_ms", 90.0)))
    grain_jitter = float(np.clip(cfg.get("grain_jitter", 0.35), 0.0, 1.0))
    playback = float(cfg.get("playback_rate", 1.0))
    playback_jitter = float(np.clip(cfg.get("playback_jitter", 0.15), 0.0, 2.0))
    scan_begin = float(np.clip(cfg.get("scan_begin", 0.0), 0.0, 1.0))
    scan_range = float(np.clip(cfg.get("scan_range", 1.0), -1.0, 1.0))
    scan_speed = float(cfg.get("scan_speed", 1.0))
    env_shape = float(np.clip(cfg.get("envelope_shape", 0.5), 0.0, 1.0))
    yaw_start = float(cfg.get("yaw_start", 0.0))
    yaw_end = float(cfg.get("yaw_end", 0.0))
    yaw_scatter = float(np.clip(cfg.get("yaw_scatter", 35.0), 0.0, 180.0))
    order_blur = float(np.clip(cfg.get("order_blur", 0.0), 0.0, 1.0))
    gain = 10.0 ** (float(cfg.get("gain_db", -9.0)) / 20.0)

    grain_base = max(8, int(round(grain_ms * sample_rate / 1000.0)))
    out = np.zeros((out_frames + grain_base * 4 + 4, ambi_channels), dtype=np.float32)
    norm = np.zeros(out.shape[0], dtype=np.float32)
    source_frames = audio.shape[0]
    event_slots = max(1, int(round(duration * density * streams)))
    period = 1.0 / max(0.1, density * streams)
    emitted = 0

    def grain_window(n):
        x = np.linspace(0.0, 1.0, n, dtype=np.float32)
        if env_shape < 0.45:
            return np.exp(-6.0 * x).astype(np.float32)
        if env_shape > 0.55:
            return np.exp(-6.0 * (1.0 - x)).astype(np.float32)
        return np.hanning(n).astype(np.float32)

    def scanner_position(u):
        start = scan_begin
        end = scan_begin + scan_range
        if scan_range == 0:
            pos = start
        else:
            pos = start + scan_range * ((u * abs(scan_speed)) % 1.0)
        return float(pos % 1.0)

    for event in range(event_slots):
        if rng.random() < intermittency:
            continue
        base_time = event * period
        jitter_time = rng.uniform(-period, period) * asynch
        t = base_time + jitter_time
        if t < 0.0 or t >= duration:
            continue
        u = t / duration
        n = max(8, int(round(grain_base * (1.0 + rng.uniform(-grain_jitter, grain_jitter)))))
        out_start = int(round(t * sample_rate))
        src_u = scanner_position(u)
        src_u = (src_u + rng.normal(0.0, 0.08 * asynch)) % 1.0
        src_start = int(round(src_u * max(1, source_frames - n - 2)))
        local_rate = playback * (2.0 ** rng.normal(0.0, playback_jitter))
        read = src_start + np.arange(n, dtype=np.float64) * local_rate
        read = np.clip(read, 0.0, source_frames - 1.0)
        i0 = np.floor(read).astype(np.int64)
        i1 = np.clip(i0 + 1, 0, source_frames - 1)
        frac = (read - i0)[:, None].astype(np.float32)
        grain = audio[i0] * (1.0 - frac) + audio[i1] * frac
        yaw = yaw_start + (yaw_end - yaw_start) * u + rng.uniform(-yaw_scatter, yaw_scatter)
        if abs(yaw) > 1e-9:
            grain = apply_hoa_yaw(grain, order, yaw)
        if order_blur > 0.0:
            higher = max(0.0, 1.0 - order_blur)
            grain = apply_hoa_order_weights(grain, order, 1.0, higher, higher * higher, 1.0)
        end = min(out_start + n, out.shape[0])
        count = end - out_start
        if count <= 0:
            continue
        win = grain_window(count)
        out[out_start:end] += grain[:count] * win[:, None] * gain / math.sqrt(max(1.0, streams))
        norm[out_start:end] += win * win
        emitted += 1

    out = out[:out_frames]
    out /= np.maximum(np.sqrt(norm[:out_frames, None]), 0.35)
    if bool(cfg.get("dc_protect", True)):
        out -= np.mean(out, axis=0, keepdims=True)
    if bool(cfg.get("soft_limit", True)):
        out = np.tanh(out * 1.1).astype(np.float32) / 1.1
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -6.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out.astype(np.float32), sample_rate)
    print("Process: 3OAFX Particle Cloud")
    print(f"Ambisonic order: {order}OA")
    print(f"Output channels: {ambi_channels}")
    print(f"Density: {density:.2f}")
    print(f"Streams: {streams}")
    print(f"Grains emitted: {emitted} of {event_slots}")
    print(f"Asynchronicity: {asynch:.3f}")
    print(f"Intermittency: {intermittency:.3f}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")


def spatial_weights(channels, center, width):
    idx = np.arange(channels, dtype=np.float64)
    dist = np.abs(((idx - center + channels / 2.0) % channels) - channels / 2.0)
    sigma = max(0.2, float(width))
    weights = np.exp(-0.5 * (dist / sigma) ** 2)
    total = math.sqrt(float(np.sum(weights * weights))) + 1e-12
    return (weights / total).astype(np.float32)


def render_karplus_field(cfg):
    sample_rate = int(cfg.get("sample_rate", 48000))
    duration = float(cfg.get("duration", 8.0))
    channels = int(max(1, min(128, cfg.get("channels", 8))))
    frames = max(1, int(round(duration * sample_rate)))
    events = int(max(1, cfg.get("events", 80)))
    base_freq = float(cfg.get("base_freq", 82.0))
    spread_oct = float(cfg.get("spread_oct", 3.0))
    decay = float(np.clip(cfg.get("decay", 0.985), 0.8, 0.9995))
    damping = float(np.clip(cfg.get("damping", 0.45), 0.0, 0.98))
    brightness = float(np.clip(cfg.get("brightness", 0.7), 0.0, 1.0))
    dispersion = float(np.clip(cfg.get("dispersion", 0.08), 0.0, 0.5))
    width = float(max(0.2, cfg.get("spatial_width", 1.4)))
    rng = np.random.default_rng(int(cfg.get("seed", 1)))
    out = np.zeros((frames, channels), dtype=np.float32)
    for event in range(events):
        t = rng.random() * max(0.001, duration - 0.02)
        start = int(t * sample_rate)
        freq = base_freq * (2.0 ** (rng.random() * spread_oct))
        delay = max(2, int(round(sample_rate / max(20.0, freq))))
        length = min(frames - start, int(sample_rate * (0.25 + 3.5 * (decay - 0.8) / 0.1995)))
        if length <= 8:
            continue
        buf = (rng.random(delay).astype(np.float32) * 2.0 - 1.0) * (0.25 + brightness)
        pos = rng.random() * channels
        weights = spatial_weights(channels, pos, width)
        y = np.zeros(length, dtype=np.float32)
        prev = 0.0
        for n in range(length):
            a = buf[n % delay]
            b = buf[(n + 1) % delay]
            val = ((1.0 - damping) * a + damping * 0.5 * (a + b)) * decay
            val += prev * dispersion
            val = math.tanh(val)
            buf[n % delay] = val
            prev = val
            y[n] = val
        env = np.exp(-np.linspace(0.0, 6.0, length, dtype=np.float32) * (1.0 - decay + 0.015))
        y *= env * (0.08 / math.sqrt(max(1, events / duration)))
        out[start:start + length] += y[:, None] * weights[None, :]
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -12.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out, sample_rate)
    print("Process: Karplus Field")
    print(f"Duration: {duration:.2f} sec")
    print(f"Channels: {channels}")
    print(f"Events: {events}")
    print(f"Base frequency: {base_freq:.2f}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")


def render_subharmonic_bank(cfg):
    sample_rate = int(cfg.get("sample_rate", 48000))
    duration = float(cfg.get("duration", 12.0))
    channels = int(max(1, min(128, cfg.get("channels", 8))))
    frames = max(1, int(round(duration * sample_rate)))
    root = float(cfg.get("root_freq", 110.0))
    voices = int(max(1, min(96, cfg.get("voices", 24))))
    instability = float(np.clip(cfg.get("instability", 0.12), 0.0, 1.0))
    pulse_blend = float(np.clip(cfg.get("pulse_blend", 0.55), 0.0, 1.0))
    fold = float(np.clip(cfg.get("fold", 0.2), 0.0, 1.0))
    mask = float(np.clip(cfg.get("event_mask", 0.55), 0.0, 1.0))
    width = float(max(0.2, cfg.get("spatial_width", 1.8)))
    rng = np.random.default_rng(int(cfg.get("seed", 1)))
    t = np.arange(frames, dtype=np.float64) / sample_rate
    out = np.zeros((frames, channels), dtype=np.float32)
    divs = np.array([1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 13, 16, 21, 24, 32], dtype=np.float64)
    for voice in range(voices):
        div = float(rng.choice(divs))
        freq = root / div * (2.0 ** rng.integers(-1, 2))
        drift = np.sin(2.0 * np.pi * (0.03 + rng.random() * 0.18) * t + rng.random() * 6.28) * instability * 0.035
        phase = 2.0 * np.pi * np.cumsum(freq * (1.0 + drift)) / sample_rate + rng.random() * 6.28
        sine = np.sin(phase)
        pulse = np.sign(np.sin(phase + 0.3 * np.sin(phase / max(1.0, div)))).astype(np.float64)
        sig = sine * (1.0 - pulse_blend) + pulse * pulse_blend
        gate_rate = 0.12 + rng.random() * 1.6
        gate_phase = rng.random() * 6.28
        gate = (0.5 + 0.5 * np.sin(2.0 * np.pi * gate_rate * t + gate_phase)) > (1.0 - mask)
        smooth = np.convolve(gate.astype(np.float32), np.hanning(max(16, int(0.025 * sample_rate))).astype(np.float32), mode="same")
        smooth /= max(1e-6, float(np.max(smooth)))
        sig *= smooth
        if fold > 0.0:
            sig = np.tanh(sig * (1.0 + fold * 8.0)) / math.tanh(1.0 + fold * 8.0)
        pos = (voice / max(1, voices) * channels + rng.normal(0.0, channels * 0.08)) % channels
        weights = spatial_weights(channels, pos, width)
        out += (sig.astype(np.float32)[:, None] * weights[None, :]) * (0.12 / math.sqrt(voices))
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -12.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out, sample_rate)
    print("Process: Subharmonic Bank")
    print(f"Duration: {duration:.2f} sec")
    print(f"Channels: {channels}")
    print(f"Voices: {voices}")
    print(f"Root frequency: {root:.2f}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")


def resonant_one_pole_bank(x, sample_rate, freqs, q, drive):
    y = np.zeros_like(x, dtype=np.float32)
    states = np.zeros((len(freqs), 2), dtype=np.float64)
    damp = math.exp(-math.pi / max(0.5, q))
    for n, sample in enumerate(x):
        total = 0.0
        for i, freq in enumerate(freqs):
            theta = 2.0 * math.pi * freq / sample_rate
            v = sample + 2.0 * damp * math.cos(theta) * states[i, 0] - (damp * damp) * states[i, 1]
            states[i, 1] = states[i, 0]
            states[i, 0] = math.tanh(v * drive)
            total += states[i, 0]
        y[n] = total / max(1, len(freqs))
    return y


def render_chaotic_resonant_eq(cfg):
    source, source_rate = read_wav(cfg["source_path"])
    sample_rate = int(cfg.get("sample_rate", source_rate))
    audio = segment(source, source_rate, cfg.get("source_start", 0.0), cfg.get("source_duration", 1.0), sample_rate)
    channels = min(int(audio.shape[1]), 128)
    audio = audio[:, :channels].astype(np.float32, copy=False)
    bands = int(max(2, min(48, cfg.get("bands", 12))))
    low = float(cfg.get("low_freq", 90.0))
    high = float(cfg.get("high_freq", 6000.0))
    q = float(np.clip(cfg.get("q", 18.0), 1.0, 120.0))
    feedback = float(np.clip(cfg.get("feedback", 0.18), 0.0, 0.92))
    chaos = float(np.clip(cfg.get("chaos", 0.25), 0.0, 1.0))
    wet = float(np.clip(cfg.get("wet", 0.55), 0.0, 1.0))
    drive = float(np.clip(cfg.get("drive", 1.2), 0.2, 8.0))
    rng = np.random.default_rng(int(cfg.get("seed", 1)))
    out = np.zeros_like(audio, dtype=np.float32)
    base_freqs = np.geomspace(low, high, bands)
    feedback_state = np.zeros(channels, dtype=np.float32)
    for ch in range(channels):
        detune = 2.0 ** rng.normal(0.0, chaos * 0.18, size=bands)
        filtered = resonant_one_pole_bank(audio[:, ch] + feedback_state[ch] * feedback, sample_rate, base_freqs * detune, q, drive)
        if feedback > 0.0:
            neighbor = audio[:, (ch - 1) % channels] if channels > 1 else audio[:, ch]
            filtered += resonant_one_pole_bank(neighbor * feedback * chaos, sample_rate, base_freqs[::-1] * detune, q * 0.7, drive)
        out[:, ch] = audio[:, ch] * (1.0 - wet) + np.tanh(filtered) * wet
    if bool(cfg.get("dc_protect", True)):
        out -= np.mean(out, axis=0, keepdims=True)
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -9.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out, sample_rate)
    print("Process: Chaotic Resonant EQ")
    print(f"Channels: {channels}")
    print(f"Bands: {bands}")
    print(f"Frequency range: {low:.2f} - {high:.2f} Hz")
    print(f"Feedback: {feedback:.3f}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")


def exact_ambisonic_order_from_channels(channels):
    channels = int(channels)
    if channels == 16:
        return 3
    if channels in (9, 10):
        return 2
    if channels == 4:
        return 1
    return 0


def virtual_blur_matrix(layout, width_deg):
    count = len(layout)
    width = max(1.0, float(width_deg))
    matrix = np.zeros((count, count), dtype=np.float64)
    for dst in range(count):
        for src in range(count):
            dist = angular_distance_deg(layout[dst], layout[src])
            matrix[dst, src] = math.exp(-0.5 * (dist / width) ** 2)
        norm = math.sqrt(float(np.sum(matrix[dst] * matrix[dst]))) + 1e-12
        matrix[dst] /= norm
    return matrix.astype(np.float32)


def rotate_virtual_blocks(signal, amount, rng, mode="smooth"):
    amount = float(np.clip(amount, 0.0, 1.0))
    if amount <= 1e-5 or signal.shape[1] <= 1:
        return signal.astype(np.float32, copy=True)
    out = np.zeros_like(signal, dtype=np.float32)
    frames, channels = signal.shape
    block = 1024
    max_shift = max(1, int(round(channels * amount * 0.5)))
    for start in range(0, frames, block):
        end = min(frames, start + block)
        t = (start + end) * 0.5 / max(1, frames)
        if mode == "counterpoint":
            shift = int(round(math.sin(2.0 * math.pi * (0.35 + amount) * t) * max_shift))
        elif mode == "stepped":
            shift = int(rng.integers(-max_shift, max_shift + 1))
        else:
            shift = int(round((t * 2.0 - 1.0) * max_shift))
        out[start:end] = np.roll(signal[start:end], shift, axis=1)
    return out


def prepare_object_space_virtual(cfg):
    source, source_rate = read_wav(cfg["source_path"])
    sample_rate = int(cfg.get("sample_rate", source_rate))
    audio = segment(source, source_rate, cfg.get("source_start", 0.0), cfg.get("source_duration", 1.0), sample_rate)
    output_order = max(1, min(3, int(cfg.get("output_order", 3))))
    layout = foafx_layout(output_order)
    out_channels = (output_order + 1) * (output_order + 1)
    basis_out = np.array([ambisonic_basis(output_order, az, el) for az, el in layout], dtype=np.float64)
    encode = np.linalg.pinv(basis_out).T
    source_format = str(cfg.get("source_format", "auto")).lower()
    if source_format == "auto":
        source_order = exact_ambisonic_order_from_channels(audio.shape[1])
    elif source_format in ("1oa", "foa", "ambisonic_1"):
        source_order = 1
    elif source_format in ("2oa", "ambisonic_2"):
        source_order = 2
    elif source_format in ("3oa", "ambisonic_3"):
        source_order = 3
    else:
        source_order = 0

    if source_order > 0:
        source_channels = (source_order + 1) * (source_order + 1)
        if audio.shape[1] < source_channels:
            raise RuntimeError(f"Source format needs {source_channels} channels, but selected media has {audio.shape[1]}.")
        basis_src = np.array([ambisonic_basis(source_order, az, el) for az, el in layout], dtype=np.float64)
        virtual = (audio[:, :source_channels].astype(np.float64) @ basis_src.T).astype(np.float32)
        source_label = f"{source_order}OA ACN/SN3D"
    else:
        spread = float(np.clip(cfg.get("source_spread", 0.18), 0.0, 1.0))
        virtual = np.zeros((audio.shape[0], len(layout)), dtype=np.float32)
        width_deg = 8.0 + spread * 82.0
        for ch in range(audio.shape[1]):
            center = int(round((ch / max(1, audio.shape[1])) * len(layout))) % len(layout)
            weights = np.array([
                math.exp(-0.5 * (angular_distance_deg(layout[idx], layout[center]) / width_deg) ** 2)
                for idx in range(len(layout))
            ], dtype=np.float64)
            weights /= math.sqrt(float(np.sum(weights * weights))) + 1e-12
            virtual += audio[:, ch:ch + 1] * weights.astype(np.float32)[None, :]
        source_label = f"non-ambisonic {audio.shape[1]}ch encoded"
    return virtual, encode, layout, sample_rate, output_order, out_channels, source_label


def non_ambisonic_to_virtual(audio, layout, source_spread, stereo_expand=True):
    spread = float(np.clip(source_spread, 0.0, 1.0))
    virtual = np.zeros((audio.shape[0], len(layout)), dtype=np.float32)
    width_deg = 8.0 + spread * 82.0

    def add_object(signal, az, el=0.0, gain=1.0):
        weights = np.array([
            math.exp(-0.5 * (angular_distance_deg(layout[idx], (az, el)) / width_deg) ** 2)
            for idx in range(len(layout))
        ], dtype=np.float64)
        weights /= math.sqrt(float(np.sum(weights * weights))) + 1e-12
        virtual[:] += signal[:, None].astype(np.float32) * weights.astype(np.float32)[None, :] * float(gain)

    if stereo_expand and audio.shape[1] == 2:
        left = audio[:, 0]
        right = audio[:, 1]
        mid = 0.5 * (left + right)
        side = 0.5 * (left - right)
        add_object(left, 35.0, 0.0, 0.82)
        add_object(right, -35.0, 0.0, 0.82)
        add_object(mid, 0.0, 0.0, 0.55)
        add_object(-mid, 180.0, 0.0, 0.28)
        add_object(side, 90.0, 0.0, 0.40)
        add_object(-side, -90.0, 0.0, 0.40)
        return virtual

    for ch in range(audio.shape[1]):
        center = int(round((ch / max(1, audio.shape[1])) * len(layout))) % len(layout)
        add_object(audio[:, ch], layout[center][0], layout[center][1], 1.0)
    return virtual


def render_stereo_expand_ambisonic_bed(cfg):
    source, source_rate = read_wav(cfg["source_path"])
    sample_rate = int(cfg.get("sample_rate", source_rate))
    audio = segment(source, source_rate, cfg.get("source_start", 0.0), cfg.get("source_duration", 1.0), sample_rate)
    output_order = max(1, min(3, int(cfg.get("output_order", 3))))
    out_channels = (output_order + 1) * (output_order + 1)
    layout = foafx_layout(output_order)
    basis_out = np.array([ambisonic_basis(output_order, az, el) for az, el in layout], dtype=np.float64)
    encode = np.linalg.pinv(basis_out).T
    frames = audio.shape[0]

    left = audio[:, 0].astype(np.float32, copy=False)
    if audio.shape[1] >= 2:
        right = audio[:, 1].astype(np.float32, copy=False)
        source_label = "stereo"
    else:
        right = left.copy()
        source_label = "mono copied to stereo expansion"

    mid = 0.5 * (left + right)
    side = 0.5 * (left - right)
    low_hz = float(cfg.get("bass_mono_hz", 0.0))
    if low_hz > 20.0:
        low_mid = one_pole_lowpass(mid[:, None], sample_rate, low_hz)[:, 0]
        low_l = one_pole_lowpass(left[:, None], sample_rate, low_hz)[:, 0]
        low_r = one_pole_lowpass(right[:, None], sample_rate, low_hz)[:, 0]
        left = left - low_l + low_mid
        right = right - low_r + low_mid
        mid = 0.5 * (left + right)
        side = 0.5 * (left - right)

    mode = str(cfg.get("mode", "balanced")).lower()
    width = float(np.clip(cfg.get("stereo_width", 1.0), 0.0, 2.0))
    front = float(np.clip(cfg.get("front_weight", 0.80), 0.0, 1.5))
    rear = float(np.clip(cfg.get("rear_amount", 0.35), 0.0, 1.5))
    side_amount = float(np.clip(cfg.get("side_amount", 0.65), 0.0, 1.5))
    height = float(np.clip(cfg.get("height_amount", 0.12), 0.0, 1.0))
    decorrelation = float(np.clip(cfg.get("decorrelation", 0.20), 0.0, 1.0))
    spread = float(np.clip(cfg.get("source_spread", 0.16), 0.0, 1.0))
    width_deg = 6.0 + spread * 96.0
    virtual = np.zeros((frames, len(layout)), dtype=np.float32)

    def add_object(signal, az, el=0.0, gain=1.0, width_scale=1.0):
        local_width = max(2.0, width_deg * float(width_scale))
        weights = np.array([
            math.exp(-0.5 * (angular_distance_deg(layout[idx], (az, el)) / local_width) ** 2)
            for idx in range(len(layout))
        ], dtype=np.float64)
        weights /= math.sqrt(float(np.sum(weights * weights))) + 1e-12
        virtual[:] += signal[:, None].astype(np.float32) * weights.astype(np.float32)[None, :] * float(gain)

    stereo_angle = 30.0 + width * 35.0
    center_gain = float(np.clip(cfg.get("center_amount", 0.55), 0.0, 1.5))
    if mode == "front_focus":
        rear *= 0.45
        side_amount *= 0.70
        center_gain *= 1.25
        stereo_angle *= 0.78
    elif mode == "wide_room":
        rear *= 1.25
        side_amount *= 1.35
        stereo_angle *= 1.15
    elif mode == "height_lift":
        height = max(height, 0.35)
        rear *= 0.90
        side_amount *= 1.05

    add_object(left, stereo_angle, 0.0, 0.82 * front, 0.85)
    add_object(right, -stereo_angle, 0.0, 0.82 * front, 0.85)
    add_object(mid, 0.0, 0.0, center_gain * front, 0.75)
    add_object(-mid, 180.0, 0.0, 0.32 * rear, 1.25)
    add_object(side, 90.0, 0.0, side_amount, 1.05)
    add_object(-side, -90.0, 0.0, side_amount, 1.05)
    if height > 0.0:
        add_object(mid, 0.0, 52.0, height * 0.55, 1.35)
        add_object(side, 90.0, 38.0, height * 0.28, 1.25)
        add_object(-side, -90.0, 38.0, height * 0.28, 1.25)

    if decorrelation > 0.0:
        diffuse = diffusion_region(virtual, sample_rate, 8.0 + 42.0 * decorrelation, 0.18 + 0.36 * decorrelation, 0.42)
        blur = virtual_blur_matrix(layout, 18.0 + decorrelation * 92.0)
        virtual = virtual * (1.0 - 0.45 * decorrelation) + (diffuse @ blur.T) * (0.45 * decorrelation)

    out = (virtual.astype(np.float64) @ encode).astype(np.float32)
    if bool(cfg.get("dc_protect", True)):
        out -= np.mean(out, axis=0, keepdims=True)
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -6.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out[:, :out_channels], sample_rate)
    print("Process: Stereo Expand to Ambisonic Bed")
    print(f"Source interpretation: {source_label}")
    print(f"Mode: {mode}")
    print(f"Output: {output_order}OA ACN/SN3D")
    print(f"Stereo width: {width:.3f}")
    print(f"Rear amount: {rear:.3f}")
    print(f"Height amount: {height:.3f}")
    print(f"Decorrelation: {decorrelation:.3f}")
    print(f"Bass mono below: {low_hz:.1f} Hz")
    print(f"Pre-normalize peak: {pre_peak:.6f}")
    print(f"Output: {cfg['output_path']}")


def render_foafx_object_space(cfg):
    virtual, encode, layout, sample_rate, output_order, out_channels, source_label = prepare_object_space_virtual(cfg)
    mode = str(cfg.get("mode", "resonance_bloom")).lower()
    dry_level = float(np.clip(cfg.get("dry_level", 0.35), 0.0, 1.5))
    space_amount = float(np.clip(cfg.get("space_amount", 0.85), 0.0, 2.0))
    object_clarity = float(np.clip(cfg.get("object_clarity", 0.55), 0.0, 1.0))
    spread_deg = float(np.clip(cfg.get("spread_deg", 42.0), 1.0, 180.0))
    motion = float(np.clip(cfg.get("motion", 0.35), 0.0, 1.0))
    resonance_hz = float(np.clip(cfg.get("resonance_hz", 220.0), 30.0, 6000.0))
    feedback = float(np.clip(cfg.get("feedback", 0.35), 0.0, 0.92))
    smear = float(np.clip(cfg.get("smear", 0.45), 0.0, 1.0))
    rng = np.random.default_rng(int(cfg.get("seed", 1)))

    blur = virtual_blur_matrix(layout, spread_deg)
    dry = virtual * dry_level * object_clarity
    center = virtual - one_pole_lowpass(virtual, sample_rate, 45.0)

    if mode == "spatial_occupation":
        field = spectral_smear_region(center, 4 + int(round(smear * 18)), smear)
        field = diffusion_region(field, sample_rate, 10.0 + spread_deg * 0.22, feedback, 0.45)
        field = rotate_virtual_blocks(field @ blur.T, motion, rng, "stepped")
        dry *= 0.45 + object_clarity * 0.55
    elif mode == "motion_counterpoint":
        low = one_pole_lowpass(virtual, sample_rate, max(80.0, resonance_hz))
        mid = biquad_bandpass(virtual, sample_rate, resonance_hz * 2.0, 3.0 + smear * 12.0)
        high = virtual - one_pole_lowpass(virtual, sample_rate, min(sample_rate * 0.42, resonance_hz * 4.0))
        field = (rotate_virtual_blocks(low, motion * 0.45, rng, "smooth") +
                 rotate_virtual_blocks(mid, motion * 0.75, rng, "counterpoint") +
                 rotate_virtual_blocks(high, motion, rng, "stepped")) / 3.0
        field = diffusion_region(field @ blur.T, sample_rate, 6.0 + spread_deg * 0.10, feedback * 0.55, 0.35)
    elif mode == "spatial_allusion":
        field = biquad_bandpass(virtual, sample_rate, resonance_hz, 1.2 + smear * 6.0)
        field = spectral_smear_region(field, 8 + int(round(smear * 28)), 0.55 + 0.4 * smear)
        field = diffusion_region(field @ blur.T, sample_rate, 22.0 + spread_deg * 0.28, feedback, 0.72)
        field = rotate_virtual_blocks(field, motion * 0.5, rng, "smooth")
        dry *= object_clarity * 0.55
    else:
        resonant = comb_resonator(biquad_bandpass(center, sample_rate, resonance_hz, 2.0 + smear * 12.0),
                                  sample_rate, resonance_hz, feedback, 0.55 + 0.30 * smear)
        field = spectral_smear_region(resonant, 6 + int(round(smear * 24)), smear)
        field = diffusion_region(field @ blur.T, sample_rate, 14.0 + spread_deg * 0.18, feedback * 0.85, 0.62)
        field = rotate_virtual_blocks(field, motion * 0.6, rng, "smooth")

    virtual_out = dry + field * space_amount
    out = (virtual_out.astype(np.float64) @ encode).astype(np.float32)
    if bool(cfg.get("dc_protect", True)):
        out -= np.mean(out, axis=0, keepdims=True)
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -6.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out[:, :out_channels], sample_rate)
    print("Process: 3OAFX Object Space")
    print(f"Mode: {mode}")
    print(f"Source interpretation: {source_label}")
    print(f"Output: {output_order}OA ACN/SN3D")
    print(f"Virtual directions: {len(layout)}")
    print(f"Spread: {spread_deg:.2f} deg")
    print(f"Motion: {motion:.3f}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")
    print(f"Output: {cfg['output_path']}")


def render_foafx_spatial_occupation_montage(cfg):
    output_order = max(1, min(3, int(cfg.get("output_order", 3))))
    out_channels = (output_order + 1) * (output_order + 1)
    layout = foafx_layout(output_order)
    basis_out = np.array([ambisonic_basis(output_order, az, el) for az, el in layout], dtype=np.float64)
    encode = np.linalg.pinv(basis_out).T
    sample_rate = int(cfg.get("sample_rate", 48000))
    duration = max(0.25, float(cfg.get("duration", 20.0)))
    frames = max(1, int(round(duration * sample_rate)))
    out_virtual = np.zeros((frames, len(layout)), dtype=np.float32)
    event_count = int(max(1, min(20000, cfg.get("events", 180))))
    min_ms = float(np.clip(cfg.get("min_segment_ms", 80.0), 5.0, 10000.0))
    max_ms = max(min_ms, float(np.clip(cfg.get("max_segment_ms", 900.0), min_ms, 30000.0)))
    density = float(np.clip(cfg.get("density", 0.72), 0.0, 1.0))
    overlap = float(np.clip(cfg.get("overlap", 0.55), 0.0, 1.0))
    source_spread = float(np.clip(cfg.get("source_spread", 0.22), 0.0, 1.0))
    occupation = float(np.clip(cfg.get("occupation", 0.72), 0.0, 1.0))
    motion = float(np.clip(cfg.get("motion", 0.35), 0.0, 1.0))
    stereo_expand = bool(cfg.get("stereo_expand", True))
    source_format = str(cfg.get("source_format", "auto")).lower()
    rng = np.random.default_rng(int(cfg.get("seed", 1)))
    paths = [line for line in str(cfg.get("source_paths", "")).splitlines() if line.strip()]
    starts = [float(x) for x in str(cfg.get("source_starts", "")).split(",") if x.strip()]
    durations = [float(x) for x in str(cfg.get("source_durations", "")).split(",") if x.strip()]
    if not paths:
        raise RuntimeError("No source paths were provided.")

    sources = []
    labels = []
    for idx, path in enumerate(paths):
        data, source_rate = read_wav(path)
        start = starts[idx] if idx < len(starts) else 0.0
        src_dur = durations[idx] if idx < len(durations) else data.shape[0] / max(1, source_rate)
        audio = segment(data, source_rate, start, src_dur, sample_rate)
        if source_format == "auto":
            order = exact_ambisonic_order_from_channels(audio.shape[1])
        elif source_format == "non_ambisonic":
            order = 0
        elif source_format in ("1oa", "foa"):
            order = 1
        elif source_format == "2oa":
            order = 2
        elif source_format == "3oa":
            order = 3
        else:
            order = 0
        if order > 0:
            needed = (order + 1) * (order + 1)
            if audio.shape[1] < needed:
                raise RuntimeError(f"Source {idx + 1} needs {needed} channels for selected source format.")
            basis_src = np.array([ambisonic_basis(order, az, el) for az, el in layout], dtype=np.float64)
            virtual = (audio[:, :needed].astype(np.float64) @ basis_src.T).astype(np.float32)
            labels.append(f"{idx + 1}:{order}OA")
        else:
            virtual = non_ambisonic_to_virtual(audio, layout, source_spread, stereo_expand)
            labels.append(f"{idx + 1}:non-ambi {audio.shape[1]}ch")
        if virtual.shape[0] > 8:
            sources.append(virtual)
    if not sources:
        raise RuntimeError("Sources were too short for montage rendering.")

    blur = virtual_blur_matrix(layout, 12.0 + occupation * 118.0)
    accepted = 0
    for event in range(event_count):
        if rng.random() > density:
            continue
        src = sources[int(rng.integers(0, len(sources)))]
        seg_frames = int(round(rng.uniform(min_ms, max_ms) * sample_rate / 1000.0))
        seg_frames = max(8, min(seg_frames, src.shape[0], frames))
        if seg_frames <= 8:
            continue
        out_start = int(round(rng.random() * max(1, frames - seg_frames)))
        src_start = int(round(rng.random() * max(1, src.shape[0] - seg_frames)))
        grain = src[src_start:src_start + seg_frames].copy()
        if motion > 0.0:
            grain = rotate_virtual_blocks(grain, motion * rng.random(), rng, "counterpoint" if event % 3 else "stepped")
        if occupation > 0.0:
            grain = grain @ blur.T
        window = np.hanning(seg_frames).astype(np.float32)
        gain = (0.30 + 0.70 * rng.random()) / math.sqrt(max(1.0, event_count * (0.35 + overlap)))
        out_virtual[out_start:out_start + seg_frames] += grain * window[:, None] * gain
        accepted += 1

    out = (out_virtual.astype(np.float64) @ encode).astype(np.float32)
    if bool(cfg.get("dc_protect", True)):
        out -= np.mean(out, axis=0, keepdims=True)
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -6.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out[:, :out_channels], sample_rate)
    print("Process: 3OAFX Spatial Occupation Montage")
    print(f"Sources: {len(sources)} ({', '.join(labels)})")
    print(f"Output: {output_order}OA ACN/SN3D")
    print(f"Duration: {duration:.2f} sec")
    print(f"Events requested/used: {event_count}/{accepted}")
    print(f"Stereo expansion: {'on' if stereo_expand else 'off'}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")
    print(f"Output: {cfg['output_path']}")


def parse_float_list(text, fallback=None):
    values = []
    for part in str(text or "").replace("\n", ",").split(","):
        part = part.strip()
        if part:
            try:
                values.append(float(part))
            except ValueError:
                pass
    if values:
        return values
    return list(fallback or [])


def parse_point_rows(text, width, fallback_rows):
    rows = []
    for row in str(text or "").split(";"):
        row = row.strip()
        if not row:
            continue
        vals = parse_float_list(row)
        if len(vals) >= width:
            rows.append(vals[:width])
    return rows if rows else [list(row[:width]) for row in fallback_rows]


def loop_or_trim_audio(audio, frames):
    frames = int(max(1, frames))
    if audio.shape[0] == frames:
        return audio.astype(np.float32, copy=False)
    if audio.shape[0] <= 0:
        return np.zeros((frames, audio.shape[1]), dtype=np.float32)
    if audio.shape[0] > frames:
        return audio[:frames].astype(np.float32, copy=False)
    reps = int(math.ceil(frames / max(1, audio.shape[0])))
    tiled = np.tile(audio, (reps, 1))
    return tiled[:frames].astype(np.float32, copy=False)


def seamless_loop_or_trim_audio(audio, frames, sample_rate, crossfade_ms=80.0):
    frames = int(max(1, frames))
    audio = audio.astype(np.float32, copy=False)
    if audio.shape[0] <= 0:
        return np.zeros((frames, audio.shape[1]), dtype=np.float32)
    if audio.shape[0] >= frames:
        return audio[:frames].astype(np.float32, copy=False)
    source_frames = int(audio.shape[0])
    fade = int(round(float(crossfade_ms) * sample_rate / 1000.0))
    fade = max(0, min(fade, source_frames // 3, frames // 3))
    if fade < 4:
        reps = int(math.ceil(frames / max(1, source_frames)))
        return np.tile(audio, (reps, 1))[:frames].astype(np.float32, copy=False)

    body_len = max(1, source_frames - fade)
    out = np.zeros((frames, audio.shape[1]), dtype=np.float32)
    norm = np.zeros(frames, dtype=np.float32)
    win = np.ones(source_frames, dtype=np.float32)
    ramp = np.linspace(0.0, 1.0, fade, endpoint=False, dtype=np.float32)
    win[:fade] = ramp
    win[-fade:] = ramp[::-1]

    pos = -fade
    while pos < frames:
        src_start = 0
        dst_start = pos
        dst_end = pos + source_frames
        if dst_start < 0:
            src_start = -dst_start
            dst_start = 0
        if dst_end > frames:
            dst_end = frames
        count = dst_end - dst_start
        if count > 0:
            segment = audio[src_start:src_start + count]
            weights = win[src_start:src_start + count]
            out[dst_start:dst_end] += segment * weights[:, None]
            norm[dst_start:dst_end] += weights
        pos += body_len
    out /= np.maximum(norm[:, None], 1e-8)
    return out.astype(np.float32, copy=False)


def interp_path_rows(rows, t):
    if not rows:
        return [0.0] * 7
    if len(rows) == 1:
        return rows[0]
    t = float(np.clip(t, 0.0, 1.0))
    ordered = sorted(rows, key=lambda row: float(row[6]) if len(row) > 6 else 0.0)
    if t <= float(ordered[0][6]):
        return ordered[0]
    for idx in range(len(ordered) - 1):
        a = ordered[idx]
        b = ordered[idx + 1]
        at = float(a[6]) if len(a) > 6 else idx / max(1, len(ordered) - 1)
        bt = float(b[6]) if len(b) > 6 else (idx + 1) / max(1, len(ordered) - 1)
        if t <= bt:
            span = max(1e-9, bt - at)
            frac = float(np.clip((t - at) / span, 0.0, 1.0))
            out = []
            for col in range(min(len(a), len(b))):
                if col in (3, 4, 5):
                    diff = ((b[col] - a[col] + 180.0) % 360.0) - 180.0
                    out.append(a[col] + diff * frac)
                elif col == 6:
                    out.append(t)
                else:
                    out.append(a[col] * (1.0 - frac) + b[col] * frac)
            return out
    return ordered[-1]


def path_facing_orientation(rows, t):
    before = interp_path_rows(rows, max(0.0, float(t) - 0.006))
    after = interp_path_rows(rows, min(1.0, float(t) + 0.006))
    dx = after[0] - before[0]
    dy = after[1] - before[1]
    dz = after[2] - before[2]
    horiz = math.sqrt(dx * dx + dy * dy)
    if horiz < 1e-8 and abs(dz) < 1e-8:
        return 0.0, 0.0, 0.0
    yaw = -math.degrees(math.atan2(dx, dy))
    pitch = math.degrees(math.atan2(dz, max(1e-8, horiz)))
    return yaw, max(-90.0, min(90.0, pitch)), 0.0


def aed_from_unit(vec):
    x, y, z = float(vec[0]), float(vec[1]), float(vec[2])
    hyp = max(1e-12, math.sqrt(x * x + y * y))
    return math.degrees(math.atan2(y, x)), math.degrees(math.atan2(z, hyp))


def rotate_direction_aed(az_deg, el_deg, yaw_deg, pitch_deg, roll_deg):
    vec = unit_from_aed(az_deg, el_deg)
    yaw = math.radians(float(yaw_deg))
    pitch = math.radians(float(pitch_deg))
    roll = math.radians(float(roll_deg))
    cy, sy = math.cos(yaw), math.sin(yaw)
    cp, sp = math.cos(pitch), math.sin(pitch)
    cr, sr = math.cos(roll), math.sin(roll)
    rz = np.array([[cy, -sy, 0.0], [sy, cy, 0.0], [0.0, 0.0, 1.0]], dtype=np.float64)
    ry = np.array([[cp, 0.0, sp], [0.0, 1.0, 0.0], [-sp, 0.0, cp]], dtype=np.float64)
    rx = np.array([[1.0, 0.0, 0.0], [0.0, cr, -sr], [0.0, sr, cr]], dtype=np.float64)
    return aed_from_unit(rz @ ry @ rx @ vec)


def orientation_remap_matrix(layout, yaw_deg, pitch_deg, roll_deg, spread_deg):
    width = max(1.0, float(spread_deg))
    count = len(layout)
    matrix = np.zeros((count, count), dtype=np.float64)
    for dst, (az, el) in enumerate(layout):
        target = rotate_direction_aed(az, el, yaw_deg, pitch_deg, roll_deg)
        for src in range(count):
            dist = angular_distance_deg(layout[src], target)
            matrix[dst, src] = math.exp(-0.5 * (dist / width) ** 2)
        norm = math.sqrt(float(np.sum(matrix[dst] * matrix[dst]))) + 1e-12
        matrix[dst] /= norm
    return matrix.astype(np.float32)


def render_foafx_scene_navigator(cfg):
    output_order = max(1, min(3, int(cfg.get("output_order", 3))))
    source_order = max(1, min(3, int(cfg.get("source_order", 3))))
    source_channels = (source_order + 1) * (source_order + 1)
    out_channels = (output_order + 1) * (output_order + 1)
    layout = foafx_layout(output_order)
    basis_out = np.array([ambisonic_basis(output_order, az, el) for az, el in layout], dtype=np.float64)
    encode = np.linalg.pinv(basis_out).T
    basis_src = np.array([ambisonic_basis(source_order, az, el) for az, el in layout], dtype=np.float64)

    paths = [line.strip() for line in str(cfg.get("source_paths", "")).splitlines() if line.strip()]
    starts = parse_float_list(cfg.get("source_starts", ""), [0.0] * len(paths))
    durations = parse_float_list(cfg.get("source_durations", ""), [0.0] * len(paths))
    if not paths:
        raise RuntimeError("No source paths were provided.")

    sample_rate = int(cfg.get("sample_rate", 48000))
    duration = max(0.05, float(cfg.get("duration", 10.0)))
    frames = max(1, int(round(duration * sample_rate)))
    node_rows = parse_point_rows(cfg.get("node_positions", ""), 4, [])
    if not node_rows:
        legacy_nodes = parse_point_rows(cfg.get("node_positions", ""), 3, [])
        node_rows = [list(row[:3]) + [1.0] for row in legacy_nodes]
    if len(node_rows) < len(paths):
        for idx in range(len(node_rows), len(paths)):
            angle = 2.0 * math.pi * idx / max(1, len(paths))
            node_rows.append([math.cos(angle), math.sin(angle), 0.0, 1.0])
    path_rows = parse_point_rows(cfg.get("path_points", ""), 7, [
        [-0.85, -0.55, 0.0, 0.0, 0.0, 0.0, 0.0],
        [-0.25, 0.35, 0.15, 35.0, 0.0, 0.0, 0.33],
        [0.35, -0.15, -0.10, -35.0, 0.0, 0.0, 0.66],
        [0.85, 0.55, 0.0, 0.0, 0.0, 0.0, 1.0],
    ])

    influence = max(0.05, float(cfg.get("influence_radius", 1.25)))
    falloff = max(0.2, float(cfg.get("distance_falloff", 1.4)))
    sharpness = max(0.1, float(cfg.get("blend_sharpness", 1.2)))
    perspective = float(np.clip(cfg.get("perspective_rotation", 0.80), 0.0, 1.0))
    near_blur = float(np.clip(cfg.get("near_field_blur", 0.25), 0.0, 1.0))
    motion_smoothing = float(np.clip(cfg.get("motion_smoothing", 0.35), 0.0, 0.98))
    height_sensitivity = float(np.clip(cfg.get("height_sensitivity", 0.65), 0.0, 2.0))
    loop_crossfade_ms = float(np.clip(cfg.get("loop_crossfade_ms", 80.0), 0.0, 2000.0))
    output_gain = 10.0 ** (float(cfg.get("output_gain_db", 0.0)) / 20.0)
    mode = str(cfg.get("navigation_mode", "blend")).lower()
    orientation_mode = str(cfg.get("orientation_mode", "path")).lower()
    block = int(max(128, min(8192, cfg.get("block_size", 1024))))

    sources = []
    labels = []
    for idx, path in enumerate(paths):
        data, source_rate = read_wav(path)
        start = starts[idx] if idx < len(starts) else 0.0
        src_dur = durations[idx] if idx < len(durations) and durations[idx] > 0.0 else data.shape[0] / max(1, source_rate)
        audio = segment(data, source_rate, start, src_dur, sample_rate)
        if audio.shape[1] < source_channels:
            raise RuntimeError(f"Source {idx + 1} has {audio.shape[1]} channels, but {source_order}OA needs {source_channels}.")
        audio = seamless_loop_or_trim_audio(audio[:, :source_channels], frames, sample_rate, loop_crossfade_ms)
        virtual = (audio.astype(np.float64) @ basis_src.T).astype(np.float32)
        sources.append(virtual)
        labels.append(os.path.basename(path))
    if not sources:
        raise RuntimeError("No usable source files were found.")

    out_virtual = np.zeros((frames, len(layout)), dtype=np.float32)
    previous_weights = None
    previous_matrix = None
    max_active = 0
    min_distance_seen = 1e9

    for start in range(0, frames, block):
        end = min(frames, start + block)
        t = (start + end) * 0.5 / max(1, frames)
        row = interp_path_rows(path_rows, t)
        lx, ly, lz = row[0], row[1], row[2]
        if orientation_mode == "manual":
            yaw, pitch, roll = row[3], row[4], row[5]
        else:
            yaw, pitch, roll = path_facing_orientation(path_rows, t)
        distances = []
        raw = []
        effective_radii = []
        for node in node_rows[:len(sources)]:
            dx = node[0] - lx
            dy = node[1] - ly
            dz = (node[2] - lz) * height_sensitivity
            distance = math.sqrt(dx * dx + dy * dy + dz * dz)
            min_distance_seen = min(min_distance_seen, distance)
            distances.append(distance)
            local_influence = max(0.02, influence * (node[3] if len(node) > 3 else 1.0))
            effective_radii.append(local_influence)
            if mode == "nearest":
                raw.append(0.0)
            else:
                raw.append(math.exp(-((distance / local_influence) ** falloff) * sharpness))
        if mode == "nearest":
            nearest = int(np.argmin(np.array(distances)))
            raw = [1.0 if i == nearest else 0.0 for i in range(len(sources))]
        weights = np.array(raw, dtype=np.float64)
        if np.sum(weights) <= 1e-12:
            nearest = int(np.argmin(np.array(distances)))
            weights[nearest] = 1.0
        weights /= math.sqrt(float(np.sum(weights * weights))) + 1e-12
        if previous_weights is not None and motion_smoothing > 0.0:
            weights = previous_weights * motion_smoothing + weights * (1.0 - motion_smoothing)
            weights /= math.sqrt(float(np.sum(weights * weights))) + 1e-12
        previous_weights = weights
        max_active = max(max_active, int(np.sum(weights > 0.05)))

        nearest_margin = max(0.0, min([r - d for r, d in zip(effective_radii, distances)] or [0.0]))
        spread = 7.0 + near_blur * 58.0 + min(40.0, nearest_margin * 8.0)
        matrix = orientation_remap_matrix(layout, yaw * perspective, pitch * perspective, roll * perspective, spread)
        if previous_matrix is not None and motion_smoothing > 0.0:
            matrix = previous_matrix * motion_smoothing + matrix * (1.0 - motion_smoothing)
        previous_matrix = matrix

        mixed = np.zeros((end - start, len(layout)), dtype=np.float32)
        for idx, src in enumerate(sources):
            if weights[idx] > 1e-5:
                mixed += src[start:end] * float(weights[idx])
        out_virtual[start:end] = mixed @ matrix.T

    out = (out_virtual.astype(np.float64) @ encode).astype(np.float32) * output_gain
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
    write_pcm24_wav(cfg["output_path"], out[:, :out_channels], sample_rate)
    print("Process: 3OAFX Scene Navigator")
    print(f"Sources: {len(sources)}")
    print(f"Source order: {source_order}OA")
    print(f"Output: {output_order}OA ACN/SN3D")
    print(f"Duration: {duration:.2f} sec")
    print(f"Navigation mode: {mode}")
    print(f"Head orientation: {orientation_mode}")
    print(f"Source loop crossfade: {loop_crossfade_ms:.1f} ms")
    print(f"Path points: {len(path_rows)}")
    print(f"Global node radius: {influence:.3f}")
    print(f"Node radius multipliers: {', '.join([f'{(row[3] if len(row) > 3 else 1.0):.2f}' for row in node_rows[:len(sources)]])}")
    print(f"Max active nodes: {max_active}")
    print(f"Closest listener-node distance: {min_distance_seen:.3f}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")
    print(f"Output: {cfg['output_path']}")


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
    dry_level = env_array(cfg, "dry_level", frames, float(cfg.get("dry_level", 0.65)))
    dry_atten = env_array(cfg, "dry_attenuation", frames, float(cfg.get("dry_attenuation", 0.18)))
    az_env = env_array(cfg, "azimuth", frames, float(cfg.get("azimuth", 0.0)))
    el_env = env_array(cfg, "elevation", frames, float(cfg.get("elevation", 0.0)))
    amp_env = env_array(cfg, "amplitude", frames, float(cfg.get("amplitude", 1.0)))
    move_wet_on_array = bool(cfg.get("move_wet_on_array", True))

    directions = np.array([unit_from_aed(az, el) for az, el in layout], dtype=np.float64)
    rendered = np.empty((frames, ambi_channels), dtype=np.float32)
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
        dry_trim = np.clip(dry_level[start:end, None], 0.0, 1.5).astype(np.float32)
        dry = np.clip(dry_atten[start:end, None], 0.0, 1.0).astype(np.float32)
        amp = amp_env[start:end, None].astype(np.float32)
        dry_gain = 1.0 - mask * (1.0 - dry)
        dry_virtual = virtual[start:end] * dry_gain * dry_trim
        if move_wet_on_array:
            wet_feed = np.sum(processed[start:end], axis=1, keepdims=True) / math.sqrt(len(layout))
            moved_wet_virtual = wet_feed * mask * wet
            rendered_virtual = (dry_virtual + moved_wet_virtual) * amp
            rendered[start:end] = (rendered_virtual.astype(np.float64) @ encode).astype(np.float32)
        else:
            wet_virtual = processed[start:end] * mask * wet
            rendered_virtual = (dry_virtual + wet_virtual) * amp
            rendered[start:end] = (rendered_virtual.astype(np.float64) @ encode).astype(np.float32)

    out = rendered
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
    print(f"Dry level: {float(cfg.get('dry_level', 0.65)):.3f}")
    print(f"Dry remaining at focus: {float(cfg.get('dry_attenuation', 0.18)):.3f}")
    print(f"Focus width: {float(cfg.get('focus_width', 38.0)):.2f} deg")
    print(f"Focus sharpness: {float(cfg.get('focus_sharpness', 0.65)):.3f}")
    print(f"Wet amount: {float(cfg.get('wet', 1.0)):.3f}")
    print(f"Move wet across virtual speaker array: {'on' if move_wet_on_array else 'off'}")
    print(f"Output channels: {ambi_channels}")
    print(f"Sample rate: {sample_rate} Hz")
    print(f"Pre-normalize peak: {pre_peak:.6f}")


def fft_convolve_1d(source, impulse):
    if source.size == 0 or impulse.size == 0:
        return np.zeros(1, dtype=np.float32)
    source = np.nan_to_num(source.astype(np.float32), nan=0.0, posinf=0.0, neginf=0.0)
    impulse = np.nan_to_num(impulse.astype(np.float32), nan=0.0, posinf=0.0, neginf=0.0)
    source = source - np.mean(source, dtype=np.float64)
    impulse = impulse - np.mean(impulse, dtype=np.float64)
    out_len = int(source.size + impulse.size - 1)
    fft_len = 1 << (out_len - 1).bit_length()
    spec = np.fft.rfft(source, fft_len) * np.fft.rfft(impulse, fft_len)
    out = np.fft.irfft(spec, fft_len)[:out_len]
    return out.astype(np.float32)


def split_manifest_list(value):
    text = str(value or "")
    if text == "":
        return []
    return [part for part in text.split("||") if part != ""]


def tetrahedral_layout():
    # Bruce Wiggins, Sounds in Space 2017, describes a first-order B-format
    # convolution workflow that transforms the source to a four-direction
    # P-format/tetrahedral intermediate, convolves each directional feed with
    # the corresponding ambisonic IR, then sums the ambisonic results.
    return [
        (45.0, 35.26438968),
        (-45.0, -35.26438968),
        (135.0, -35.26438968),
        (-135.0, 35.26438968),
    ]


def ambisonic_convolve_layout(order, layout_key):
    if str(layout_key) == "tetra":
        return tetrahedral_layout()
    if int(order) >= 2:
        # Practical higher-order recording/design bank: eight encoded ambisonic
        # IRs. For 2OA this gives 8 x 9 = 72 stacked channels; for 3OA it gives
        # 8 x 16 = 128 stacked channels, matching REAPER's maximum track width.
        # This reflects a feasible measurement plan better than dense virtual
        # effect layers.
        return [
            (45.0, 35.26438968),
            (-45.0, 35.26438968),
            (135.0, 35.26438968),
            (-135.0, 35.26438968),
            (45.0, -35.26438968),
            (-45.0, -35.26438968),
            (135.0, -35.26438968),
            (-135.0, -35.26438968),
        ]
    return foafx_layout(order)


def write_direction_map(path, layout, order, ambi_channels, output_mode, written_paths):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("index,azimuth_deg,elevation_deg,ambi_order,ambi_channels,stacked_channel_start,stacked_channel_end,file\n")
        for index, (az, el) in enumerate(layout, start=1):
            ch_start = (index - 1) * ambi_channels + 1
            ch_end = index * ambi_channels
            file_path = written_paths[0] if output_mode == "stacked" and written_paths else (
                written_paths[index - 1] if index - 1 < len(written_paths) else ""
            )
            handle.write(
                f"{index},{az:.6f},{el:.6f},{order},{ambi_channels},{ch_start},{ch_end},{file_path}\n"
            )


def render_ambisonic_convolve(cfg):
    source, source_rate = read_wav(cfg["source_path"])
    sample_rate = int(cfg.get("sample_rate", source_rate))
    audio = segment(source, source_rate, cfg.get("source_start", 0.0), cfg.get("source_duration", 1.0), sample_rate)
    order = int(cfg.get("order", 1))
    order = max(1, min(3, order))
    ambi_channels = (order + 1) * (order + 1)
    if audio.shape[1] < ambi_channels:
        raise RuntimeError(f"Selected source has {audio.shape[1]} channels, but {order}OA needs {ambi_channels}.")
    audio = audio[:, :ambi_channels].astype(np.float32, copy=False)

    ir_paths = split_manifest_list(cfg.get("ir_paths", ""))
    ir_starts = [float(x) for x in split_manifest_list(cfg.get("ir_starts", ""))]
    ir_durations = [float(x) for x in split_manifest_list(cfg.get("ir_durations", ""))]
    if not ir_paths:
        raise RuntimeError("At least one ambisonic IR WAV is required.")

    convolve_mode = str(cfg.get("convolve_mode", "bank"))
    layout = ambisonic_convolve_layout(order, cfg.get("direction_layout", "virtual"))
    wet_gain = 10.0 ** (float(cfg.get("wet_gain_db", 0.0)) / 20.0)
    wet_level = float(cfg.get("wet_level", 1.0))
    dry_level = float(cfg.get("dry_level", 0.0))
    trim_to_source = bool(cfg.get("trim_to_source", False))
    ir_normalize = bool(cfg.get("ir_normalize", True))
    adapt_lower_order_ir = bool(cfg.get("adapt_lower_order_ir", False))
    dc_protect = bool(cfg.get("dc_protect", True))

    if convolve_mode == "direct":
        if len(ir_paths) != 1:
            raise RuntimeError("Same-order direct convolution needs exactly one ambisonic IR WAV.")
        ir_audio, ir_rate = read_wav(ir_paths[0])
        start = ir_starts[0] if ir_starts else 0.0
        dur = ir_durations[0] if ir_durations else (ir_audio.shape[0] / max(1, ir_rate))
        ir_audio = segment(ir_audio, ir_rate, start, dur, sample_rate)
        if ir_audio.shape[1] < ambi_channels:
            raise RuntimeError(f"IR {ir_paths[0]} has {ir_audio.shape[1]} channels, but {order}OA needs {ambi_channels}.")
        ir_audio = ir_audio[:, :ambi_channels].astype(np.float32, copy=False)
        if dc_protect:
            ir_audio = ir_audio - np.mean(ir_audio, axis=0, keepdims=True)
        if ir_normalize:
            peak = float(np.max(np.abs(ir_audio))) if ir_audio.size else 0.0
            if peak > 1e-12:
                ir_audio = ir_audio / peak
        output_len = audio.shape[0] if trim_to_source else audio.shape[0] + ir_audio.shape[0] - 1
        wet = np.zeros((output_len, ambi_channels), dtype=np.float32)
        for channel in range(ambi_channels):
            convolved = fft_convolve_1d(audio[:, channel], ir_audio[:, channel])
            if trim_to_source:
                convolved = convolved[:audio.shape[0]]
            wet[:convolved.size, channel] = convolved * wet_gain
        wet *= wet_level
        if dc_protect:
            wet -= np.mean(wet, axis=0, keepdims=True)
        if dry_level > 0.0:
            dry = np.zeros_like(wet)
            dry[:audio.shape[0], :] = audio * dry_level
            out = dry + wet
        else:
            out = wet
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
        print("Inspired by: Bruce Wiggins, Sounds in Space 2017, ambisonic measured reverb workflow")
        print("Convolution mode: same-order direct")
        print(f"Ambisonic order: {order}OA")
        print(f"Ambisonic channels: {ambi_channels}")
        print(f"IR files: {len(ir_paths)}")
        print("IR assignment: one same-order ambisonic IR")
        print(f"Dry level: {dry_level:.3f}")
        print(f"Wet level: {wet_level:.3f}")
        print(f"Pre-normalize peak: {pre_peak:.6f}")
        print(f"Output channels: {ambi_channels}")
        print(f"Sample rate: {sample_rate} Hz")
        return

    basis = np.array([ambisonic_basis(order, az, el) for az, el in layout], dtype=np.float64)
    decode = basis.T
    virtual = (audio.astype(np.float64) @ decode).astype(np.float32)

    stacked_input = len(ir_paths) == 1
    stacked_block_channels = ambi_channels
    stacked_source_order = order
    adapted_ir_orders = set()
    if stacked_input:
        stacked_audio, _stacked_rate = read_wav(ir_paths[0])
        if stacked_audio.shape[1] >= ambi_channels * len(layout):
            stacked_block_channels = ambi_channels
            stacked_source_order = order
        elif adapt_lower_order_ir:
            possible_block_channels = stacked_audio.shape[1] // len(layout)
            possible_order = ambisonic_order_from_channels(possible_block_channels)
            if possible_order > 0 and possible_order < order and stacked_audio.shape[1] >= ((possible_order + 1) * (possible_order + 1)) * len(layout):
                stacked_source_order = possible_order
                stacked_block_channels = (possible_order + 1) * (possible_order + 1)
                adapted_ir_orders.add(possible_order)
            else:
                raise RuntimeError(
                    f"Directional bank needs one stacked {ambi_channels * len(layout)}-channel IR bank, "
                    f"or an adaptable lower-order stacked bank with {len(layout)} direction blocks."
                )
        else:
            raise RuntimeError(
                f"Directional bank needs one stacked {ambi_channels * len(layout)}-channel IR bank, "
                f"or {len(layout)} separate {ambi_channels}-channel IRs."
            )
    elif len(ir_paths) != len(layout):
        raise RuntimeError(
            f"Directional bank needs {len(layout)} IR files, one per virtual direction. "
            "Reusing or wrapping IRs is disabled for direction accuracy."
        )

    ir_cache = {}

    def load_ir(index):
        path = ir_paths[0] if stacked_input else ir_paths[index]
        cache_key = path
        if stacked_input:
            cache_key = f"{path}#{index}"
        if cache_key not in ir_cache:
            ir_audio, ir_rate = read_wav(path)
            start = ir_starts[0 if stacked_input else index] if ir_starts else 0.0
            dur = ir_durations[0 if stacked_input else index] if ir_durations else (ir_audio.shape[0] / max(1, ir_rate))
            ir_audio = segment(ir_audio, ir_rate, start, dur, sample_rate)
            if stacked_input:
                channel_start = index * stacked_block_channels
                ir_audio = ir_audio[:, channel_start:channel_start + stacked_block_channels]
            elif ir_audio.shape[1] < ambi_channels:
                source_order = ambisonic_order_from_channels(ir_audio.shape[1])
                if not adapt_lower_order_ir or source_order <= 0 or source_order >= order:
                    raise RuntimeError(f"IR {path} has {ir_audio.shape[1]} channels, but {order}OA needs {ambi_channels}.")
                source_channels = (source_order + 1) * (source_order + 1)
                ir_audio = ir_audio[:, :source_channels]
                adapted_ir_orders.add(source_order)
            else:
                ir_audio = ir_audio[:, :ambi_channels]
            ir_audio = ir_audio.astype(np.float32, copy=False)
            if dc_protect:
                ir_audio = ir_audio - np.mean(ir_audio, axis=0, keepdims=True)
            if ir_normalize:
                peak = float(np.max(np.abs(ir_audio))) if ir_audio.size else 0.0
                if peak > 1e-12:
                    ir_audio = ir_audio / peak
            source_order = stacked_source_order if stacked_input else ambisonic_order_from_channels(ir_audio.shape[1])
            if source_order > 0 and source_order < order:
                ir_audio = adapt_ambisonic_ir_order(ir_audio, source_order, order)
                if dc_protect:
                    ir_audio = ir_audio - np.mean(ir_audio, axis=0, keepdims=True)
            ir_cache[cache_key] = ir_audio
        return ir_cache[cache_key], path

    output_len = audio.shape[0] if trim_to_source else audio.shape[0] + max(
        1,
        max((load_ir(i)[0].shape[0] for i in range(len(layout))), default=1),
    ) - 1
    wet = np.zeros((output_len, ambi_channels), dtype=np.float32)

    direction_peak = []
    for direction_index in range(len(layout)):
        feed = virtual[:, direction_index]
        ir_audio, ir_path = load_ir(direction_index)
        feed_peak = float(np.max(np.abs(feed))) if feed.size else 0.0
        direction_peak.append(feed_peak)
        if feed_peak <= 1e-12:
            continue
        for channel in range(ambi_channels):
            convolved = fft_convolve_1d(feed, ir_audio[:, channel])
            if trim_to_source:
                convolved = convolved[:audio.shape[0]]
            wet[:convolved.size, channel] += convolved * wet_gain

    wet *= wet_level / max(1.0, math.sqrt(len(layout)))
    if dc_protect:
        wet -= np.mean(wet, axis=0, keepdims=True)

    if dry_level > 0.0:
        dry = np.zeros_like(wet)
        dry[:audio.shape[0], :] = audio * dry_level
        out = dry + wet
    else:
        out = wet

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
    print("Inspired by: Bruce Wiggins, Sounds in Space 2017, ambisonic measured reverb workflow")
    print("Convolution mode: directional IR bank")
    print(f"Ambisonic order: {order}OA")
    print(f"Ambisonic channels: {ambi_channels}")
    print(f"Virtual directions: {len(layout)}")
    print(f"Direction layout: {cfg.get('direction_layout', 'virtual')}")
    print(f"IR files: {len(ir_paths)}")
    stacked_bank = False
    if stacked_input:
        ir_audio, _ir_rate = read_wav(ir_paths[0])
        if ir_audio.shape[1] >= ambi_channels * len(layout):
            stacked_bank = True
            print(f"IR bank mode: stacked multichannel ({ir_audio.shape[1]} channels)")
    if stacked_bank:
        print("IR assignment: stacked channel blocks per virtual direction")
    elif stacked_input:
        print("IR assignment: adapted lower-order stacked channel blocks per virtual direction")
    else:
        print("IR assignment: matched one IR per virtual direction")
    if adapted_ir_orders:
        orders = ", ".join(f"{value}OA" for value in sorted(adapted_ir_orders))
        print(f"IR adaptation: lower-order IRs adapted to {order}OA from {orders}")
        print("Adaptation note: preserves lower-order direction/energy but does not create measured higher-order detail.")
    print("Direction map:")
    for index, (az, el) in enumerate(layout, start=1):
        print(f"  {index:02d}: az {az:.2f} deg, el {el:.2f} deg")
    print(f"Dry level: {dry_level:.3f}")
    print(f"Wet level: {wet_level:.3f}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")
    print(f"Output channels: {ambi_channels}")
    print(f"Sample rate: {sample_rate} Hz")


def apply_kernel_fade(audio, sample_rate, fade_ms):
    fade_frames = int(round(max(0.0, float(fade_ms)) * sample_rate / 1000.0))
    if fade_frames <= 0 or audio.shape[0] <= 1:
        return audio
    fade_frames = min(fade_frames, max(1, audio.shape[0] // 2))
    window = np.ones(audio.shape[0], dtype=np.float32)
    ramp = np.linspace(0.0, 1.0, fade_frames, endpoint=True, dtype=np.float32)
    window[:fade_frames] *= ramp
    window[-fade_frames:] *= ramp[::-1]
    return (audio * window[:, None]).astype(np.float32)


def angular_distance_deg(a, b):
    va = unit_from_aed(a[0], a[1])
    vb = unit_from_aed(b[0], b[1])
    return math.degrees(math.acos(float(np.clip(np.dot(va, vb), -1.0, 1.0))))


def kernel_position_layout(count, layer_layout):
    count = max(1, int(count))
    if count == len(layer_layout):
        return list(layer_layout)
    if count == 1:
        return [(0.0, 0.0)]
    if count == 4:
        return tetrahedral_layout()
    if count == 8:
        return ambisonic_convolve_layout(2, "virtual")
    return foafx_layout(3)[:count] if count <= 24 else [
        (float((index * 137.507764) % 360.0 - 180.0), float(math.degrees(math.asin(1.0 - 2.0 * (index + 0.5) / count))))
        for index in range(count)
    ]


def render_ambisonic_kernel_collage(cfg):
    source, source_rate = read_wav(cfg["source_path"])
    sample_rate = int(cfg.get("sample_rate", source_rate))
    audio = segment(source, source_rate, cfg.get("source_start", 0.0), cfg.get("source_duration", 1.0), sample_rate)
    order = int(cfg.get("order", 3))
    order = max(1, min(3, order))
    ambi_channels = (order + 1) * (order + 1)
    if audio.shape[1] < ambi_channels:
        raise RuntimeError(f"Selected source has {audio.shape[1]} channels, but {order}OA needs {ambi_channels}.")
    audio = audio[:, :ambi_channels].astype(np.float32, copy=False)

    kernel_paths = split_manifest_list(cfg.get("kernel_paths", ""))
    kernel_starts = [float(x) for x in split_manifest_list(cfg.get("kernel_starts", ""))]
    kernel_durations = [float(x) for x in split_manifest_list(cfg.get("kernel_durations", ""))]
    if not kernel_paths:
        raise RuntimeError("Select at least one ambisonic recording to use as a convolution kernel.")

    max_kernel_seconds = max(0.01, float(cfg.get("max_kernel_seconds", 4.0)))
    kernel_fade_ms = max(0.0, float(cfg.get("kernel_fade_ms", 25.0)))
    kernel_normalize = bool(cfg.get("kernel_normalize", True))
    adapt_mixed_order_kernels = bool(cfg.get("adapt_mixed_order_kernels", True))
    dc_protect = bool(cfg.get("dc_protect", True))
    assignment_mode = str(cfg.get("assignment_mode", "cycle"))
    direction_layer = str(cfg.get("direction_layer", "auto"))
    seed = int(cfg.get("seed", 1))

    if direction_layer == "tetra":
        layout = ambisonic_convolve_layout(order, "tetra")
    elif direction_layer == "virtual":
        layout = ambisonic_convolve_layout(order, "virtual")
    else:
        layout = ambisonic_convolve_layout(order, "tetra" if order == 1 else "virtual")
    basis = np.array([ambisonic_basis(order, az, el) for az, el in layout], dtype=np.float64)
    virtual = (audio.astype(np.float64) @ basis.T).astype(np.float32)

    kernels = []
    kernel_orders = []
    for index, path in enumerate(kernel_paths):
        kernel_audio, kernel_rate = read_wav(path)
        kernel_order = ambisonic_order_from_channels(kernel_audio.shape[1])
        if kernel_order <= 0:
            raise RuntimeError(f"Kernel {path} has {kernel_audio.shape[1]} channels, but ambisonic kernels need at least 1OA / 4ch.")
        if not adapt_mixed_order_kernels and kernel_audio.shape[1] < ambi_channels:
            raise RuntimeError(f"Kernel {path} has {kernel_audio.shape[1]} channels, but {order}OA needs {ambi_channels}.")
        start = kernel_starts[index] if index < len(kernel_starts) else 0.0
        duration = kernel_durations[index] if index < len(kernel_durations) else (kernel_audio.shape[0] / max(1, kernel_rate))
        duration = min(float(duration), max_kernel_seconds)
        kernel_audio = segment(kernel_audio, kernel_rate, start, duration, sample_rate)
        if adapt_mixed_order_kernels and kernel_order != order:
            kernel_audio = adapt_ambisonic_ir_order(kernel_audio, kernel_order, order)
        elif kernel_audio.shape[1] >= ambi_channels:
            kernel_audio = kernel_audio[:, :ambi_channels].astype(np.float32, copy=False)
        else:
            raise RuntimeError(f"Kernel {path} has {kernel_audio.shape[1]} channels, but {order}OA needs {ambi_channels}.")
        if dc_protect:
            kernel_audio = kernel_audio - np.mean(kernel_audio, axis=0, keepdims=True)
        kernel_audio = apply_kernel_fade(kernel_audio, sample_rate, kernel_fade_ms)
        if kernel_normalize:
            peak = float(np.max(np.abs(kernel_audio))) if kernel_audio.size else 0.0
            if peak > 1e-12:
                kernel_audio = kernel_audio / peak
        kernels.append(kernel_audio)
        kernel_orders.append(kernel_order)

    rng = np.random.default_rng(seed)
    assignments = []
    kernel_positions = kernel_position_layout(len(kernels), layout)
    for direction_index in range(len(layout)):
        if assignment_mode == "all":
            assignments.append([(index, 1.0 / max(1.0, math.sqrt(len(kernels)))) for index in range(len(kernels))])
        elif assignment_mode == "random":
            assignments.append([(int(rng.integers(0, len(kernels))), 1.0)])
        elif assignment_mode == "indexed":
            assignments.append([(direction_index, 1.0)] if direction_index < len(kernels) else [])
        elif assignment_mode == "region":
            distances = np.array([angular_distance_deg(layout[direction_index], pos) for pos in kernel_positions], dtype=np.float64)
            width = max(12.0, float(cfg.get("region_width_deg", 70.0)))
            weights = np.exp(-0.5 * (distances / width) ** 2)
            if np.max(weights) > 1e-12:
                weights = weights / math.sqrt(float(np.sum(weights * weights)))
            assignments.append([(index, float(weight)) for index, weight in enumerate(weights) if weight > 1e-4])
        else:
            assignments.append([(direction_index % len(kernels), 1.0)])

    tail_mode = str(cfg.get("tail_mode", "max_tail"))
    max_kernel_len = max(kernel.shape[0] for kernel in kernels)
    if tail_mode == "source":
        output_len = audio.shape[0]
    elif tail_mode == "full":
        output_len = audio.shape[0] + max_kernel_len - 1
    else:
        max_tail_seconds = max(0.0, float(cfg.get("max_tail_seconds", 12.0)))
        output_len = audio.shape[0] + int(round(max_tail_seconds * sample_rate))
        output_len = min(output_len, audio.shape[0] + max_kernel_len - 1)
    output_len = max(1, output_len)

    wet_gain = 10.0 ** (float(cfg.get("wet_gain_db", -18.0)) / 20.0)
    wet_level = float(cfg.get("wet_level", 1.0))
    dry_level = float(cfg.get("dry_level", 0.0))
    wet = np.zeros((output_len, ambi_channels), dtype=np.float32)
    work_count = sum(len(entry) for entry in assignments)
    scale = wet_gain * wet_level / max(1.0, math.sqrt(work_count))

    for direction_index, kernel_indices in enumerate(assignments):
        feed = virtual[:, direction_index]
        if feed.size == 0 or float(np.max(np.abs(feed))) <= 1e-12:
            continue
        for kernel_index, assignment_gain in kernel_indices:
            kernel = kernels[kernel_index]
            for channel in range(ambi_channels):
                convolved = fft_convolve_1d(feed, kernel[:, channel])
                convolved = convolved[:output_len]
                wet[:convolved.size, channel] += convolved * scale * assignment_gain

    if dc_protect:
        wet -= np.mean(wet, axis=0, keepdims=True)
    if dry_level > 0.0:
        out = wet.copy()
        dry_len = min(audio.shape[0], out.shape[0])
        out[:dry_len] += audio[:dry_len] * dry_level
    else:
        out = wet

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
    print("Process: 3OAFX Ambisonic Kernel Collage")
    print("Kernel interpretation: selected ambisonic recordings used as convolution kernels")
    print(f"Ambisonic order: {order}OA")
    print(f"Ambisonic channels: {ambi_channels}")
    print(f"Direction layer: {direction_layer}")
    print(f"Virtual directions: {len(layout)}")
    print(f"Kernels: {len(kernels)}")
    print(f"Mixed-order kernel adaptation: {'on' if adapt_mixed_order_kernels else 'off'}")
    for index, kernel_order in enumerate(kernel_orders, start=1):
        relation = "native" if kernel_order == order else ("adapted up" if kernel_order < order else "reduced")
        print(f"  kernel {index:02d} order: {kernel_order}OA -> {order}OA ({relation})")
    print(f"Assignment mode: {assignment_mode}")
    for direction_index, kernel_indices in enumerate(assignments, start=1):
        labels = ", ".join(f"{k + 1}:{g:.2f}" for k, g in kernel_indices) if kernel_indices else "silent"
        print(f"  direction {direction_index:02d}: kernel {labels}")
    print(f"Max kernel window: {max_kernel_seconds:.3f} sec")
    print(f"Kernel fade: {kernel_fade_ms:.2f} ms")
    print(f"Wet pre-gain: {float(cfg.get('wet_gain_db', -18.0)):.2f} dB")
    print(f"Wet level: {wet_level:.3f}")
    print(f"Dry level: {dry_level:.3f}")
    print(f"Tail mode: {tail_mode}")
    print(f"Pre-normalize peak: {pre_peak:.6f}")
    print(f"Output channels: {ambi_channels}")
    print(f"Sample rate: {sample_rate} Hz")


def render_synthetic_ambisonic_ir_bank(cfg):
    order = int(cfg.get("order", 1))
    order = max(1, min(3, order))
    sample_rate = int(cfg.get("sample_rate", 48000))
    ambi_channels = (order + 1) * (order + 1)
    layout_key = cfg.get("direction_layout", "tetra")
    layout = ambisonic_convolve_layout(order, layout_key)
    output_dir = str(cfg.get("output_dir", ""))
    prefix = str(cfg.get("prefix", "s3g_synthetic_ambi_ir"))
    if output_dir == "":
        raise RuntimeError("Synthetic IR bank needs an output directory.")
    os.makedirs(output_dir, exist_ok=True)

    room_x = max(1.0, float(cfg.get("room_x", 12.0)))
    room_y = max(1.0, float(cfg.get("room_y", 9.0)))
    room_z = max(1.0, float(cfg.get("room_z", 5.0)))
    volume = room_x * room_y * room_z
    surface = 2.0 * (room_x * room_y + room_x * room_z + room_y * room_z)
    absorption = float(np.clip(cfg.get("absorption", 0.32), 0.03, 0.95))
    scattering = float(np.clip(cfg.get("scattering", 0.45), 0.0, 1.0))
    air_damping = float(np.clip(cfg.get("air_damping", 0.35), 0.0, 1.0))
    source_distance = max(0.25, float(cfg.get("source_distance", min(room_x, room_y) * 0.25)))
    pre_delay_ms = max(0.0, float(cfg.get("pre_delay_ms", 0.0)))
    direct_gain = float(cfg.get("direct_gain", 1.0))
    early_count = max(0, int(cfg.get("early_reflections", 18)))
    diffuse_count = max(0, int(cfg.get("diffuse_taps", 160)))
    decay = max(0.05, float(cfg.get("decay", 0.85)))
    if bool(cfg.get("auto_decay", True)):
        area_absorption = max(0.01, surface * absorption)
        decay = float(np.clip(0.161 * volume / area_absorption, 0.08, 8.0))
    duration = max(0.05, float(cfg.get("duration", max(0.35, decay * 1.6))))
    frames = max(1, int(round(duration * sample_rate)))
    spread_deg = max(0.0, float(cfg.get("spread_deg", 38.0)))
    lowpass = float(np.clip(cfg.get("tail_soften", 0.35), 0.0, 1.0))
    normalize_db = float(cfg.get("normalize_db", -6.0))
    output_mode = str(cfg.get("output_mode", "separate"))
    seed = int(cfg.get("seed", 1))
    rng = np.random.default_rng(seed)
    speed_of_sound = 343.0
    listener = np.array([room_x * 0.5, room_y * 0.5, room_z * 0.5], dtype=np.float64)

    def perturbed_direction(az, el, amount_deg):
        return (
            float(wrap_degrees(np.array([az + rng.normal(0.0, amount_deg)], dtype=np.float64))[0]),
            float(np.clip(el + rng.normal(0.0, amount_deg * 0.55), -89.0, 89.0)),
        )

    def aed_from_vector(vec):
        x, y, z = float(vec[0]), float(vec[1]), float(vec[2])
        radius = math.sqrt(x * x + y * y + z * z) + 1e-12
        az = math.degrees(math.atan2(y, x))
        el = math.degrees(math.asin(np.clip(z / radius, -1.0, 1.0)))
        return az, el

    def unit_from_layout(az, el):
        return unit_from_aed(az, el)

    def add_encoded_tap(ir, time_sec, az, el, amp):
        if time_sec < 0.0 or time_sec >= duration:
            return
        frame = min(frames - 1, max(0, int(round(time_sec * sample_rate))))
        basis = np.array(ambisonic_basis(order, az, el), dtype=np.float32)
        ir[frame] += basis * float(amp)

    def reflection_points(source_pos):
        sx, sy, sz = source_pos
        images = [
            np.array([-sx, sy, sz], dtype=np.float64),
            np.array([2.0 * room_x - sx, sy, sz], dtype=np.float64),
            np.array([sx, -sy, sz], dtype=np.float64),
            np.array([sx, 2.0 * room_y - sy, sz], dtype=np.float64),
            np.array([sx, sy, -sz], dtype=np.float64),
            np.array([sx, sy, 2.0 * room_z - sz], dtype=np.float64),
        ]
        return images

    written = []
    generated_irs = []
    for direction_index, (base_az, base_el) in enumerate(layout, start=1):
        ir = np.zeros((frames, ambi_channels), dtype=np.float32)
        direct_basis = np.array(ambisonic_basis(order, base_az, base_el), dtype=np.float32)
        source_vec = unit_from_layout(base_az, base_el)
        source_pos = listener + source_vec * min(source_distance, min(room_x, room_y, room_z) * 0.48)
        source_pos = np.clip(source_pos, np.array([0.05, 0.05, 0.05]), np.array([room_x - 0.05, room_y - 0.05, room_z - 0.05]))
        direct_time = pre_delay_ms / 1000.0 + source_distance / speed_of_sound
        direct_amp = direct_gain / max(1.0, source_distance)
        if direct_time < duration:
            direct_frame = min(frames - 1, max(0, int(round(direct_time * sample_rate))))
            ir[direct_frame] += direct_basis * direct_amp

        # Synthetic test IRs are encoded ambisonic responses for each virtual
        # source direction. They are not P-format files; the P-format or virtual
        # direction layer exists inside the convolution process.
        reflectivity = math.sqrt(max(0.0, 1.0 - absorption))
        images = reflection_points(source_pos)
        for image in images:
            vec = image - listener
            distance = float(np.linalg.norm(vec))
            if distance <= 1e-9:
                continue
            t = pre_delay_ms / 1000.0 + distance / speed_of_sound
            az, el = aed_from_vector(vec)
            az, el = perturbed_direction(az, el, scattering * spread_deg * 0.35)
            amp = direct_gain * reflectivity * math.exp(-t / max(0.05, decay)) / max(1.0, distance)
            add_encoded_tap(ir, t, az, el, amp)

        for _ in range(max(0, early_count - len(images))):
            room_cross = math.sqrt(room_x * room_x + room_y * room_y + room_z * room_z)
            t = pre_delay_ms / 1000.0 + float(rng.uniform(0.006, min(duration * 0.35, room_cross / speed_of_sound)))
            if rng.random() < 0.55 + scattering * 0.35:
                az, el = perturbed_direction(base_az, base_el, spread_deg * (0.5 + scattering))
            else:
                az = float(rng.uniform(-180.0, 180.0))
                el = float(np.degrees(np.arcsin(rng.uniform(-1.0, 1.0))))
            amp = (0.22 + 0.55 * rng.random()) * reflectivity * math.exp(-t / max(0.05, decay))
            amp *= rng.choice([-1.0, 1.0])
            add_encoded_tap(ir, t, az, el, amp)

        for _ in range(diffuse_count):
            u = rng.random()
            late_start = min(duration * 0.92, pre_delay_ms / 1000.0 + 0.035 + (1.0 - scattering) * 0.080)
            t = late_start + max(0.0, duration - late_start) * (u ** (1.35 + scattering * 0.9))
            if rng.random() < 0.35 + scattering * 0.45:
                az, el = perturbed_direction(base_az, base_el, spread_deg * (1.4 + scattering * 2.0))
            else:
                az = float(rng.uniform(-180.0, 180.0))
                el = float(np.degrees(np.arcsin(rng.uniform(-1.0, 1.0))))
            amp = (0.018 + 0.12 * rng.random()) * reflectivity * math.exp(-t / max(0.05, decay))
            amp *= 0.65 + scattering * 0.85
            amp *= rng.choice([-1.0, 1.0])
            add_encoded_tap(ir, t, az, el, amp)

        if lowpass > 0.001:
            cutoff = sample_rate * (0.05 + 0.36 * (1.0 - max(lowpass, air_damping * 0.75)))
            ir = one_pole_lowpass(ir, sample_rate, cutoff)
            if direct_time < duration:
                direct_frame = min(frames - 1, max(0, int(round(direct_time * sample_rate))))
                ir[direct_frame] += direct_basis * direct_amp * 0.85
        ir, pre_peak = normalize_peak(ir, normalize_db)
        generated_irs.append(ir)
        if output_mode != "stacked":
            name = f"{prefix}_{direction_index:02d}_{order}oa.wav"
            path = output_dir.rstrip("/\\") + "/" + name
            write_pcm24_wav(path, ir, sample_rate)
            written.append(path)

    if output_mode == "stacked":
        stacked = np.concatenate(generated_irs, axis=1) if generated_irs else np.zeros((frames, ambi_channels), dtype=np.float32)
        path = str(cfg.get("output_path", "")) or (output_dir.rstrip("/\\") + "/" + f"{prefix}_stacked_{order}oa_bank.wav")
        write_pcm24_wav(path, stacked, sample_rate)
        written.append(path)

    # Touch the first generated file path as the required output_path contract
    # used by the shared Lua NumPy runner.
    if output_mode != "stacked" and written and cfg.get("output_path") and str(cfg.get("output_path")) != written[0]:
        write_pcm24_wav(str(cfg["output_path"]), read_wav(written[0])[0], sample_rate)
    map_path = output_dir.rstrip("/\\") + "/" + f"{prefix}_direction_map.csv"
    write_direction_map(map_path, layout, order, ambi_channels, output_mode, written)
    print(f"Ambisonic order: {order}OA")
    print(f"Ambisonic channels per IR: {ambi_channels}")
    print(f"Direction layout: {layout_key}")
    print(f"Output mode: {output_mode}")
    print(f"IR files written: {len(written)}")
    if output_mode == "stacked":
        print(f"Stacked bank channels: {ambi_channels * len(layout)}")
    print(f"Room: {room_x:.2f} x {room_y:.2f} x {room_z:.2f} m")
    print(f"Absorption: {absorption:.3f}")
    print(f"Scattering: {scattering:.3f}")
    print(f"Duration: {duration:.3f} sec")
    print(f"Estimated / manual decay: {decay:.3f} sec")
    print(f"Source distance: {source_distance:.3f} m")
    print(f"Pre-delay: {pre_delay_ms:.2f} ms")
    print(f"Early reflections per IR: {early_count}")
    print(f"Diffuse taps per IR: {diffuse_count}")
    print(f"Direction map CSV: {map_path}")
    print("Files:")
    for path in written:
        print(path)


def render_midi_terrain_form(cfg):
    output_path = str(cfg["output_path"])
    seed = int(cfg.get("seed", 1))
    rng = np.random.default_rng(seed)
    duration_beats = max(4.0, float(cfg.get("duration_beats", 256.0)))
    sections = max(1, min(32, int(cfg.get("sections", 8))))
    lanes = max(1, min(16, int(cfg.get("lanes", 8))))
    density = max(0.0, min(1.0, float(cfg.get("density", 0.55))))
    form = str(cfg.get("form", "arc")).lower()
    terrain = str(cfg.get("terrain", "ridge")).lower()
    root = int(cfg.get("root", 0)) % 12
    scale_name = str(cfg.get("scale", "Dorian"))
    octave = int(cfg.get("octave", 3))
    register_span = max(1, int(cfg.get("register_span", 4)))
    pitch_span = max(4, int(cfg.get("pitch_span", 28)))
    min_note = max(0.03125, float(cfg.get("min_note_beats", 0.25)))
    max_note = max(min_note, float(cfg.get("max_note_beats", 2.0)))
    recurrence = max(0.0, min(1.0, float(cfg.get("recurrence", 0.35))))
    contrast = max(0.0, min(1.0, float(cfg.get("contrast", 0.55))))
    channel_motion = max(0.0, min(1.0, float(cfg.get("channel_motion", 0.65))))
    velocity_base = max(1, min(127, int(cfg.get("velocity", 78))))
    velocity_range = max(0, min(80, int(cfg.get("velocity_range", 34))))

    scales = {
        "Chromatic": list(range(12)),
        "Major": [0, 2, 4, 5, 7, 9, 11],
        "Natural minor": [0, 2, 3, 5, 7, 8, 10],
        "Harmonic minor": [0, 2, 3, 5, 7, 8, 11],
        "Melodic minor": [0, 2, 3, 5, 7, 9, 11],
        "Dorian": [0, 2, 3, 5, 7, 9, 10],
        "Phrygian": [0, 1, 3, 5, 7, 8, 10],
        "Lydian": [0, 2, 4, 6, 7, 9, 11],
        "Mixolydian": [0, 2, 4, 5, 7, 9, 10],
        "Locrian": [0, 1, 3, 5, 6, 8, 10],
        "Major pentatonic": [0, 2, 4, 7, 9],
        "Minor pentatonic": [0, 3, 5, 7, 10],
        "Suspended pentatonic": [0, 2, 5, 7, 10],
        "Egyptian pentatonic": [0, 2, 5, 7, 10],
        "Hirajoshi": [0, 2, 3, 7, 8],
        "In-sen": [0, 1, 5, 7, 10],
        "Iwato": [0, 1, 5, 6, 10],
        "Kumoi": [0, 2, 3, 7, 9],
        "Blues minor": [0, 3, 5, 6, 7, 10],
        "Blues major": [0, 2, 3, 4, 7, 9],
        "Whole tone": [0, 2, 4, 6, 8, 10],
        "Augmented": [0, 3, 4, 7, 8, 11],
        "Tritone": [0, 1, 4, 6, 7, 10],
        "Diminished WH": [0, 2, 3, 5, 6, 8, 9, 11],
        "Diminished HW": [0, 1, 3, 4, 6, 7, 9, 10],
        "Prometheus": [0, 2, 4, 6, 9, 10],
        "Mystic": [0, 2, 4, 6, 9, 10],
        "Acoustic": [0, 2, 4, 6, 7, 9, 10],
        "Lydian dominant": [0, 2, 4, 6, 7, 9, 10],
        "Phrygian dominant": [0, 1, 4, 5, 7, 8, 10],
        "Double harmonic": [0, 1, 4, 5, 7, 8, 11],
        "Hungarian minor": [0, 2, 3, 6, 7, 8, 11],
        "Neapolitan minor": [0, 1, 3, 5, 7, 8, 11],
        "Neapolitan major": [0, 1, 3, 5, 7, 9, 11],
        "Persian": [0, 1, 4, 5, 6, 8, 11],
        "Enigmatic": [0, 1, 4, 6, 8, 10, 11],
        "Bebop dominant": [0, 2, 4, 5, 7, 9, 10, 11],
        "Bebop major": [0, 2, 4, 5, 7, 8, 9, 11],
        "Hexatonic major": [0, 2, 4, 7, 9, 11],
        "Hexatonic minor": [0, 2, 3, 5, 7, 10],
        "Quartal": [0, 2, 5, 7, 10],
        "Fifths": [0, 2, 4, 7, 9],
    }
    scale = scales.get(scale_name, scales["Dorian"])

    raw = rng.uniform(0.55, 1.45, sections)
    if form == "blocks":
        raw = np.ones(sections)
    elif form == "cascade":
        raw = np.linspace(0.72, 1.38, sections)
    boundaries = np.concatenate(([0.0], np.cumsum(raw / np.sum(raw) * duration_beats)))
    boundaries[-1] = duration_beats
    centers = (boundaries[:-1] + boundaries[1:]) * 0.5 / duration_beats

    if form == "arc":
        section_energy = np.sin(np.pi * centers) ** (0.65 + contrast)
    elif form == "episodes":
        section_energy = rng.uniform(0.18, 1.0, sections)
    elif form == "return":
        base = np.sin(np.pi * centers) ** 0.7
        section_energy = 0.35 + 0.55 * base
        section_energy[::3] = 0.72 + 0.22 * recurrence
    elif form == "drift":
        section_energy = np.linspace(0.22, 0.92, sections)
    elif form == "blocks":
        section_energy = rng.choice([0.22, 0.48, 0.78, 0.94], sections)
    elif form == "ritual":
        section_energy = 0.42 + 0.32 * np.sin(np.arange(sections) * 0.85) ** 2
    elif form == "cascade":
        section_energy = np.linspace(0.12, 1.0, sections)
    elif form == "constellation":
        section_energy = np.linspace(0.18, 0.86, sections)
        section_energy = np.where(np.arange(sections) % 2 == 0, section_energy, section_energy * 0.55)
    else:
        section_energy = 0.35 + 0.55 * np.sin(np.pi * centers) ** 0.8
    section_energy = np.clip(section_energy, 0.04, 1.0)

    motif_count = max(3, min(16, int(round(4 + recurrence * 10))))
    motif_degrees = rng.integers(-pitch_span // 3, pitch_span, motif_count)
    motif_lanes = rng.integers(0, lanes, motif_count)
    motif_lengths = rng.uniform(min_note, max_note, motif_count)

    events = []
    grid = 0.25
    total_steps = max(1, int(math.ceil(duration_beats / grid)))
    lane_bias = rng.uniform(0.0, 1.0, lanes)
    for step in range(total_steps):
        t = step * grid
        pos = t / duration_beats
        sec = int(np.searchsorted(boundaries, t, side="right") - 1)
        sec = max(0, min(sections - 1, sec))
        local = (t - boundaries[sec]) / max(0.0001, boundaries[sec + 1] - boundaries[sec])
        if terrain == "ridge":
            terrain_value = math.exp(-((local - 0.5) ** 2) / (0.045 + 0.10 * (1.0 - contrast)))
        elif terrain == "basin":
            terrain_value = 1.0 - math.exp(-((local - 0.5) ** 2) / (0.060 + 0.12 * (1.0 - contrast)))
        elif terrain == "spiral":
            terrain_value = 0.5 + 0.5 * math.sin(2.0 * math.pi * (pos * (2.0 + contrast * 5.0) + local))
        elif terrain == "fault":
            terrain_value = 0.25 + 0.75 * (local > (0.35 + 0.20 * math.sin(sec)) )
        elif terrain == "cellular":
            cell = int(local * 8)
            terrain_value = 0.35 + 0.65 * (math.sin(seed * 12.9898 + sec * 78.233 + cell * 37.719) * 43758.5453 % 1.0)
        elif terrain == "attractor":
            attract = (sec % max(1, sections // 3 + 1)) / max(1, sections // 3)
            terrain_value = math.exp(-((local - attract) ** 2) / 0.09)
        else:
            terrain_value = 0.5 + 0.5 * math.sin(2.0 * math.pi * (pos + local * 0.5))
        probability = density * (0.08 + 0.92 * section_energy[sec]) * (0.25 + 0.75 * terrain_value)
        if form == "constellation" and rng.random() < 0.65:
            probability *= 0.45
        if rng.random() > probability:
            continue

        repeats = 1
        if rng.random() < section_energy[sec] * density * 0.18:
            repeats += int(rng.integers(1, 4))
        for rep in range(repeats):
            motif_idx = int(rng.integers(0, motif_count))
            use_motif = rng.random() < recurrence
            degree_center = motif_degrees[motif_idx] if use_motif else int((terrain_value - 0.35) * pitch_span)
            degree = int(round(degree_center + rng.normal(0, 1.5 + contrast * 4.0) + (sec - sections / 2) * 0.35))
            scale_degree = degree % len(scale)
            octave_offset = degree // len(scale)
            folded_octave = octave + (octave_offset % register_span)
            pitch = int(np.clip((folded_octave + 1) * 12 + root + scale[scale_degree], 0, 127))
            lane_float = (pos * channel_motion + terrain_value * (1 - channel_motion) + lane_bias[motif_lanes[motif_idx]] * 0.35) % 1.0
            lane = int(np.clip(round(lane_float * max(0, lanes - 1)), 0, lanes - 1))
            if use_motif and rng.random() < recurrence:
                lane = int(motif_lanes[motif_idx])
            dur = float(np.clip((motif_lengths[motif_idx] if use_motif else rng.uniform(min_note, max_note)) *
                                (0.55 + terrain_value * 0.9), min_note, max_note * 1.6))
            start = t + rep * min_note * 0.55 + float(rng.normal(0, grid * 0.10 * contrast))
            if start < 0 or start >= duration_beats:
                continue
            vel = int(np.clip(velocity_base + (terrain_value - 0.5) * velocity_range + rng.normal(0, 7), 1, 127))
            events.append((start, min(dur, duration_beats - start), pitch, vel, lane, sec))

    events.sort(key=lambda e: (e[0], e[4], e[2]))
    with open(output_path, "w", encoding="utf-8") as handle:
        handle.write("type,index,start,duration,pitch,velocity,channel,section,label\n")
        labels = ["A", "B", "C", "D", "E", "F", "G", "H"]
        for sec in range(sections):
            label = labels[sec % len(labels)]
            if form == "return" and sec % 3 == 0:
                label = "A"
            handle.write(f"section,{sec+1},{boundaries[sec]:.6f},{(boundaries[sec+1]-boundaries[sec]):.6f},0,0,0,{sec+1},{label}{sec+1}\n")
        for idx, (start, dur, pitch, vel, lane, sec) in enumerate(events, 1):
            handle.write(f"event,{idx},{start:.6f},{dur:.6f},{pitch},{vel},{lane},{sec+1},E{idx}\n")
    print("Process: Terrain Form")
    print(f"Duration beats: {duration_beats:.2f}")
    print(f"Sections: {sections}")
    print(f"Events: {len(events)}")
    print(f"Form: {form}")
    print(f"Terrain: {terrain}")
    print(f"Output: {output_path}")


def read_midi_note_csv(path):
    notes = []
    with open(path, "r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            try:
                notes.append({
                    "start": float(row.get("start", 0.0)),
                    "duration": max(0.03125, float(row.get("duration", 0.25))),
                    "pitch": int(float(row.get("pitch", 60))),
                    "velocity": int(float(row.get("velocity", 80))),
                    "channel": int(float(row.get("channel", 0))),
                })
            except ValueError:
                continue
    notes.sort(key=lambda n: (n["start"], n["channel"], n["pitch"]))
    return notes


def render_midi_form_learner(cfg):
    output_path = str(cfg["output_path"])
    source_path = str(cfg["source_path"])
    notes = read_midi_note_csv(source_path)
    if not notes:
        raise RuntimeError("No MIDI notes were available for learning.")

    seed = int(cfg.get("seed", 1))
    rng = np.random.default_rng(seed)
    duration_beats = max(4.0, float(cfg.get("duration_beats", 384.0)))
    sections = max(1, min(32, int(cfg.get("sections", 9))))
    lanes = max(1, min(16, int(cfg.get("lanes", 8))))
    bar_beats = max(0.25, float(cfg.get("bar_beats", 4.0)))
    density_scale = max(0.05, min(2.5, float(cfg.get("density_scale", 1.0))))
    source_influence = max(0.0, min(1.0, float(cfg.get("source_influence", 0.72))))
    variation = max(0.0, min(1.0, float(cfg.get("variation", 0.35))))
    recurrence = max(0.0, min(1.0, float(cfg.get("recurrence", 0.55))))
    transpose_range = max(0, min(36, int(cfg.get("transpose_range", 12))))
    time_warp = max(0.0, min(1.0, float(cfg.get("time_warp", 0.22))))
    strategy = str(cfg.get("strategy", "expanded_return")).lower()

    starts = np.array([n["start"] for n in notes], dtype=np.float64)
    durations = np.array([n["duration"] for n in notes], dtype=np.float64)
    pitches = np.array([n["pitch"] for n in notes], dtype=np.int32)
    velocities = np.array([n["velocity"] for n in notes], dtype=np.int32)
    channels = np.array([n["channel"] for n in notes], dtype=np.int32)
    source_span = max(bar_beats, float(np.max(starts + durations)))
    bar_count = max(1, int(math.ceil(source_span / bar_beats)))
    bars = [[] for _ in range(bar_count)]
    for idx, start in enumerate(starts):
        bars[min(bar_count - 1, max(0, int(start // bar_beats)))].append(idx)
    nonempty_bars = [idx for idx, members in enumerate(bars) if members]
    if not nonempty_bars:
        nonempty_bars = [0]
        bars[0] = list(range(len(notes)))

    density_by_bar = np.array([len(members) for members in bars], dtype=np.float64)
    if float(np.max(density_by_bar)) > 0:
        density_by_bar = density_by_bar / float(np.max(density_by_bar))
    pitch_center = float(np.median(pitches))
    pitch_spread = max(1.0, float(np.std(pitches)))
    vel_center = float(np.median(velocities))

    if strategy == "blocks":
        raw = np.ones(sections)
    elif strategy == "source_echo":
        raw = np.full(sections, 1.0)
    else:
        raw = rng.uniform(0.75, 1.30, sections)
    boundaries = np.concatenate(([0.0], np.cumsum(raw / np.sum(raw) * duration_beats)))
    boundaries[-1] = duration_beats
    centers = (boundaries[:-1] + boundaries[1:]) * 0.5 / duration_beats

    if strategy == "fragmented_blocks":
        section_energy = np.where(np.arange(sections) % 2 == 0, 0.82, 0.34)
    elif strategy == "drift_variation":
        section_energy = np.linspace(0.30, 0.95, sections)
    elif strategy == "channel_canon":
        section_energy = 0.55 + 0.35 * np.sin(np.arange(sections) * 0.73) ** 2
    elif strategy == "source_echo":
        section_energy = np.interp(centers, np.linspace(0.0, 1.0, bar_count), density_by_bar)
        section_energy = 0.34 + 0.62 * section_energy
    elif strategy == "terrain_hybrid":
        section_energy = 0.20 + 0.75 * np.sin(np.pi * centers) ** 0.55
    else:
        section_energy = 0.38 + 0.54 * np.sin(np.pi * centers) ** 0.75
        section_energy[::3] = np.maximum(section_energy[::3], 0.72 + 0.20 * recurrence)
    section_energy = np.clip(section_energy, 0.08, 1.0)

    target_bars = max(1, int(math.ceil(duration_beats / bar_beats)))
    events = []
    labels = ["A", "B", "C", "D", "E", "F", "G", "H"]

    def choose_source_bar(target_bar, sec):
        if strategy == "source_echo":
            return nonempty_bars[target_bar % len(nonempty_bars)]
        if strategy == "expanded_return" and sec % 3 == 0:
            return nonempty_bars[target_bar % len(nonempty_bars)]
        if strategy == "drift_variation":
            return nonempty_bars[int(round((len(nonempty_bars) - 1) * target_bar / max(1, target_bars - 1)))]
        if strategy == "fragmented_blocks":
            return nonempty_bars[(target_bar * 3 + sec) % len(nonempty_bars)]
        if strategy == "channel_canon":
            return nonempty_bars[(target_bar + sec) % len(nonempty_bars)]
        if strategy == "terrain_hybrid":
            ridge = abs(math.sin((target_bar + seed * 0.017) * 0.51))
            return nonempty_bars[int(np.clip(round(ridge * (len(nonempty_bars) - 1)), 0, len(nonempty_bars) - 1))]
        if rng.random() < recurrence:
            return nonempty_bars[target_bar % len(nonempty_bars)]
        return int(rng.choice(nonempty_bars))

    for target_bar in range(target_bars):
        bar_start = target_bar * bar_beats
        if bar_start >= duration_beats:
            break
        sec = int(np.searchsorted(boundaries, bar_start, side="right") - 1)
        sec = max(0, min(sections - 1, sec))
        src_bar = choose_source_bar(target_bar, sec)
        members = bars[src_bar] if bars[src_bar] else [int(rng.integers(0, len(notes)))]
        local_density = density_scale * section_energy[sec] * (0.45 + 0.55 * density_by_bar[src_bar])
        local_density *= 0.65 + 0.35 * source_influence
        if strategy == "fragmented_blocks" and sec % 2 == 1:
            local_density *= 0.45
        if strategy == "terrain_hybrid":
            local_density *= 0.60 + 0.65 * abs(math.sin(target_bar * 0.37 + sec))

        section_transpose = 0
        if transpose_range > 0:
            drift = ((sec / max(1, sections - 1)) * 2.0 - 1.0) * transpose_range
            random_part = float(rng.integers(-transpose_range, transpose_range + 1))
            section_transpose = int(round(drift * (1.0 - source_influence) * 0.65 + random_part * variation * 0.35))

        copies = 1 + (1 if rng.random() < max(0.0, local_density - 1.0) * 0.45 else 0)
        for copy_idx in range(copies):
            for note_idx in members:
                if rng.random() > min(1.0, local_density):
                    continue
                src = notes[note_idx]
                rel = src["start"] - src_bar * bar_beats
                rel = max(0.0, min(bar_beats - 0.03125, rel))
                warp = 1.0 + rng.normal(0.0, time_warp * 0.16)
                jitter = rng.normal(0.0, bar_beats * 0.015 * variation)
                if copy_idx > 0:
                    jitter += rng.uniform(0.0625, min(0.75, bar_beats * 0.25))
                start = bar_start + rel * warp + jitter
                if start < 0 or start >= duration_beats:
                    continue
                dur = src["duration"] * float(np.clip(rng.normal(1.0, 0.22 * variation + 0.03), 0.25, 2.8))
                dur = max(0.03125, min(dur, duration_beats - start))
                pitch_rand = rng.normal(0.0, (1.0 - source_influence) * pitch_spread * 0.40 + variation * 1.5)
                pitch = int(np.clip(src["pitch"] + section_transpose + round(pitch_rand), 0, 127))
                if source_influence < 0.45 and rng.random() < (0.45 - source_influence):
                    pitch = int(np.clip(round(pitch_center + rng.normal(0.0, pitch_spread * (0.8 + variation))), 0, 127))
                vel = int(np.clip(src["velocity"] + rng.normal((section_energy[sec] - 0.5) * 18.0, 5.0 + variation * 16.0), 1, 127))
                if source_influence < 0.35:
                    vel = int(np.clip(vel_center + rng.normal(0.0, 18.0), 1, 127))
                if strategy == "channel_canon":
                    lane = (src["channel"] + sec + copy_idx + target_bar) % lanes
                else:
                    learned_lane = src["channel"] % lanes
                    random_lane = int(rng.integers(0, lanes))
                    lane = learned_lane if rng.random() < source_influence else random_lane
                    if variation > 0.55 and rng.random() < variation * 0.25:
                        lane = (lane + int(rng.integers(-2, 3))) % lanes
                events.append((start, dur, pitch, vel, lane, sec))

    events.sort(key=lambda e: (e[0], e[4], e[2]))
    with open(output_path, "w", encoding="utf-8") as handle:
        handle.write("type,index,start,duration,pitch,velocity,channel,section,label\n")
        for sec in range(sections):
            label = labels[sec % len(labels)]
            if strategy == "expanded_return" and sec % 3 == 0:
                label = "A"
            handle.write(f"section,{sec+1},{boundaries[sec]:.6f},{(boundaries[sec+1]-boundaries[sec]):.6f},0,0,0,{sec+1},{label}{sec+1}\n")
        for idx, (start, dur, pitch, vel, lane, sec) in enumerate(events, 1):
            handle.write(f"event,{idx},{start:.6f},{dur:.6f},{pitch},{vel},{lane},{sec+1},E{idx}\n")

    print("Process: Form Learner")
    print(f"Source notes: {len(notes)}")
    print(f"Source span beats: {source_span:.2f}")
    print(f"Duration beats: {duration_beats:.2f}")
    print(f"Sections: {sections}")
    print(f"Events: {len(events)}")
    print(f"Strategy: {strategy}")
    print(f"Output: {output_path}")


def main():
    if len(sys.argv) != 3:
        raise SystemExit("Usage: s3g_numpy_render.py <dense_grain|loop_drift_bed|loop_rift|ir_toolkit|mass_partial|resonant_terrain|partial_trace_resynth|fata_morgana|stereo_expand_ambisonic_bed|foafx_offline|foafx_object_space|foafx_spatial_occupation_montage|foafx_scene_navigator|foafx_object_field_split|foafx_profile_subtract|foafx_spectral_profile_tool|multichannel_spectral_profile_tool|foafx_spatial_grains|foafx_pulsar_field|foafx_particle_cloud|karplus_field|subharmonic_bank|chaotic_resonant_eq|ambisonic_convolve|ambisonic_kernel_collage|synthetic_ambisonic_ir_bank|midi_terrain_form|midi_form_learner> <manifest.json>")
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
    elif mode == "stereo_expand_ambisonic_bed":
        render_stereo_expand_ambisonic_bed(cfg)
    elif mode == "foafx_offline":
        render_foafx_offline(cfg)
    elif mode == "foafx_object_space":
        render_foafx_object_space(cfg)
    elif mode == "foafx_spatial_occupation_montage":
        render_foafx_spatial_occupation_montage(cfg)
    elif mode == "foafx_scene_navigator":
        render_foafx_scene_navigator(cfg)
    elif mode == "foafx_object_field_split":
        render_foafx_object_field_split(cfg)
    elif mode == "foafx_profile_subtract":
        render_foafx_profile_subtract(cfg)
    elif mode == "foafx_spectral_profile_tool":
        render_foafx_spectral_profile_tool(cfg)
    elif mode == "multichannel_spectral_profile_tool":
        render_multichannel_spectral_profile_tool(cfg)
    elif mode == "foafx_spatial_grains":
        render_foafx_spatial_granulator(cfg)
    elif mode == "foafx_pulsar_field":
        render_foafx_pulsar_field(cfg)
    elif mode == "foafx_particle_cloud":
        render_foafx_particle_cloud(cfg)
    elif mode == "karplus_field":
        render_karplus_field(cfg)
    elif mode == "subharmonic_bank":
        render_subharmonic_bank(cfg)
    elif mode == "chaotic_resonant_eq":
        render_chaotic_resonant_eq(cfg)
    elif mode == "ambisonic_convolve":
        render_ambisonic_convolve(cfg)
    elif mode == "ambisonic_kernel_collage":
        render_ambisonic_kernel_collage(cfg)
    elif mode == "synthetic_ambisonic_ir_bank":
        render_synthetic_ambisonic_ir_bank(cfg)
    elif mode == "midi_terrain_form":
        render_midi_terrain_form(cfg)
    elif mode == "midi_form_learner":
        render_midi_form_learner(cfg)
    else:
        raise RuntimeError(f"Unknown render mode: {mode}")


if __name__ == "__main__":
    main()
