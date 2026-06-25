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


def render_loop_drift_bed(cfg):
    sample_rate = int(cfg.get("sample_rate", 48000))
    source, source_rate = read_wav(cfg["source_path"])
    source = segment(source, source_rate, cfg.get("source_start", 0.0), cfg.get("source_duration", 1.0), sample_rate)
    if source.shape[0] < 16:
        raise RuntimeError("Selected source segment is too short for loop drifting.")
    source = source - np.mean(source, axis=0, keepdims=True)
    mono_source = np.mean(source, axis=1).astype(np.float32)
    source_channels = int(source.shape[1])
    channels = int(cfg["channels"])
    duration = float(cfg["duration"])
    frames = max(1, int(round(duration * sample_rate)))
    out = np.zeros((frames, channels), dtype=np.float32)
    base_rate = float(cfg.get("base_rate", 1.0))
    rate_amount = float(cfg.get("rate_amount", 0.08))
    rate_mode = str(cfg.get("rate_mode", "deviation"))
    distribution = str(cfg.get("distribution", "cycle"))
    phase_mode = str(cfg.get("phase_mode", "even"))
    drift_amount = float(cfg.get("drift_amount", 0.0))
    spread = float(cfg.get("spatial_spread", 0.0))
    gain = float(cfg.get("gain", 0.85))
    xfade_frames = int(round(float(cfg.get("xfade_ms", 80.0)) * sample_rate / 1000.0))
    xfade_frames = int(min(max(0, xfade_frames), max(0, (source.shape[0] - 2) // 2)))
    xfade_duck = float(cfg.get("xfade_duck", 0.12))
    loop_period = max(2, source.shape[0] - xfade_frames)
    rng = np.random.default_rng(int(cfg.get("seed", 1)))
    t = np.arange(frames, dtype=np.float64)

    channel_rates = []
    source_map = []
    for dst in range(channels):
        u = dst / max(1, channels - 1)
        if rate_mode == "spread":
            rate = base_rate * (1.0 + (u * 2.0 - 1.0) * rate_amount)
        elif rate_mode == "ascending":
            rate = base_rate * (1.0 + u * rate_amount)
        elif rate_mode == "descending":
            rate = base_rate * (1.0 + (1.0 - u) * rate_amount)
        elif rate_mode == "random_steps":
            choices = np.array([-1.0, -0.5, -0.25, 0.0, 0.25, 0.5, 1.0], dtype=np.float64)
            rate = base_rate * (1.0 + float(rng.choice(choices)) * rate_amount)
        else:
            rate = base_rate * (1.0 + rng.uniform(-rate_amount, rate_amount))
        channel_rates.append(max(0.05, float(rate)))

        if distribution == "mono_sum":
            source_index = -1
        elif distribution == "mirror":
            period = max(1, source_channels * 2 - 2)
            pos = dst % period
            source_index = pos if pos < source_channels else period - pos
        elif distribution == "random":
            source_index = int(rng.integers(0, source_channels))
        elif distribution == "paired":
            source_index = ((dst // 2) % source_channels)
        else:
            source_index = dst % source_channels
        source_map.append(int(source_index))

    for dst in range(channels):
        if phase_mode == "random":
            phase = rng.random() * loop_period
        elif phase_mode == "aligned":
            phase = 0.0
        else:
            phase = (dst / max(1, channels)) * loop_period
        rate = channel_rates[dst]
        if drift_amount > 0.0001:
            drift_freq = rng.uniform(0.015, 0.09)
            drift_phase = rng.uniform(0.0, 2.0 * math.pi)
            drift = 1.0 + drift_amount * np.sin(2.0 * math.pi * drift_freq * t / sample_rate + drift_phase)
            positions = phase + np.cumsum(rate * drift)
        else:
            positions = phase + t * rate
        source_channel = mono_source if source_map[dst] < 0 else source[:, source_map[dst]]
        loop = seamless_loop_read(source_channel, positions, xfade_frames, xfade_duck)
        local_gain = gain / math.sqrt(max(1.0, channels / 2.0))
        if spread > 0.001 and channels > 1:
            width = 0.08 + spread * max(1.0, channels * 0.08)
            weights = pan_weights(dst, channels, width)
            out += loop[:, None] * weights[None, :] * local_gain
        else:
            out[:, dst] += loop * local_gain

    out = apply_output_envelope(out, cfg, "amplitude")
    corr = mean_neighbor_correlation(out)
    if bool(cfg.get("normalize", True)):
        out, pre_peak = normalize_peak(out, float(cfg.get("normalize_db", -6.0)))
    else:
        pre_peak = float(np.max(np.abs(out))) if out.size else 0.0
    write_pcm24_wav(cfg["output_path"], out, sample_rate)
    print(f"Source channels: {source_channels}")
    print(f"Output channels: {channels}")
    print(f"Duration: {duration:.3f} sec")
    print(f"Rate mode: {rate_mode}")
    print(f"Base rate: {base_rate:.5f}")
    print(f"Rate amount: {rate_amount:.5f}")
    print(f"Distribution: {distribution}")
    print(f"Phase mode: {phase_mode}")
    print(f"Crossfade: {1000.0 * xfade_frames / sample_rate:.2f} ms")
    print(f"Crossfade duck: {xfade_duck:.3f}")
    print(f"Effective loop period: {loop_period / sample_rate:.6f} sec")
    print(f"Spatial spread: {spread:.3f}")
    print(f"Rate min/max: {min(channel_rates):.5f} / {max(channel_rates):.5f}")
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


def main():
    if len(sys.argv) != 3:
        raise SystemExit("Usage: s3g_numpy_render.py <dense_grain|loop_drift_bed|ir_toolkit|mass_partial|resonant_terrain|partial_trace_resynth|fata_morgana> <manifest.json>")
    mode = sys.argv[1]
    with open(sys.argv[2], "r", encoding="utf-8") as handle:
        cfg = json.load(handle)
    if mode == "dense_grain":
        render_dense_grain(cfg)
    elif mode == "loop_drift_bed":
        render_loop_drift_bed(cfg)
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
    else:
        raise RuntimeError(f"Unknown render mode: {mode}")


if __name__ == "__main__":
    main()
