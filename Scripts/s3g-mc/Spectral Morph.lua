-- @description Spectral Morph
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spectral / Convolution
-- @render Yes; writes a new spectrally morphed media item.
-- @method CDP/SoundThread-inspired offline spectral morph. Select two WAV-backed media items: carrier first, modulator second. Morph live spectral frames or two frozen spectral frames while preserving carrier phase/timing.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local sol = dofile(script_dir .. "Spectral Offline Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "Spectral Morph", 0) return end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local FFT_NAMES = { [1] = "1024", [2] = "2048", [3] = "4096", [4] = "8192" }
local FFT_VALUES = { [1] = 1024, [2] = 2048, [3] = 4096, [4] = 8192 }
local MODE_NAMES = { [1] = "Live morph", [2] = "Freeze morph" }
local MODE_VALUES = { [1] = "live", [2] = "freeze" }

local entries = sol.selected_entries()
if #entries < 2 then reaper.MB("Select two WAV-backed media items: carrier first, modulator second.", "Spectral Morph", 0) return end

local ctx = ImGui.CreateContext("Spectral Morph")
local open = true
local fft_index = 2
local mode_index = 1
local morph = 0.5
local mix = 1.0
local smooth_bins = 5
local carrier_pos = 0.25
local modulator_pos = 0.75
local expand = 1.0
local normalize = true
local normalize_db = -6.0
local swap = false
local should_render = false

local function loop()
  ImGui.SetNextWindowSize(ctx, 560, 430, ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, "Spectral Morph", open)
  if visible then
    local carrier = swap and entries[2] or entries[1]
    local modulator = swap and entries[1] or entries[2]
    ImGui.Text(ctx, "Carrier: " .. carrier.name .. " (" .. tostring(carrier.channels) .. " ch)")
    ImGui.Text(ctx, "Modulator: " .. modulator.name .. " (" .. tostring(modulator.channels) .. " ch)")
    if ImGui.Button(ctx, "Swap carrier / modulator") then swap = not swap end
    ImGui.Spacing(ctx)
    local changed
    changed, mode_index = sol.draw_combo(ImGui, ctx, "Morph mode", mode_index, MODE_NAMES, 1, 2)
    changed, fft_index = sol.draw_combo(ImGui, ctx, "FFT size", fft_index, FFT_NAMES, 1, 4)
    changed, morph = ImGui.SliderDouble(ctx, "Morph position", morph, 0, 1, "%.3f")
    if mode_index == 2 then
      changed, carrier_pos = ImGui.SliderDouble(ctx, "Carrier freeze position", carrier_pos, 0, 1, "%.3f")
      changed, modulator_pos = ImGui.SliderDouble(ctx, "Modulator freeze position", modulator_pos, 0, 1, "%.3f")
    end
    changed, smooth_bins = ImGui.SliderInt(ctx, "Spectral smoothing bins", smooth_bins, 1, 96)
    changed, expand = ImGui.SliderDouble(ctx, "Expansion", expand, 1.0, 8.0, "%.2fx")
    changed, mix = ImGui.SliderDouble(ctx, "Wet mix", mix, 0, 1, "%.3f")
    changed, normalize = ImGui.Checkbox(ctx, "Peak normalize", normalize)
    if normalize then changed, normalize_db = ImGui.SliderDouble(ctx, "Normalize peak dB", normalize_db, -24, 0, "%.1f") end
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Interpolates spectral magnitude while keeping carrier timing/phase.")
    if ImGui.Button(ctx, "Render", 92, 26) then should_render = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 92, 26) then open = false end
    ImGui.End(ctx)
  end
  if should_render then
    open = false
    local carrier = swap and entries[2] or entries[1]
    local modulator = swap and entries[1] or entries[2]
    sol.render(script_dir, "Spectral Morph", carrier, {
      mode = "morph",
      source_path = carrier.filename,
      source_start_offset = carrier.start_offset,
      source_duration = carrier.length * math.max(0.000001, carrier.playrate),
      modulator_path = modulator.filename,
      modulator_start_offset = modulator.start_offset,
      modulator_duration = modulator.length * math.max(0.000001, modulator.playrate),
      sample_rate = sol.source_sample_rate(carrier),
      fft_size = FFT_VALUES[fft_index] or 2048,
      overlap = 4,
      morph_variant = MODE_VALUES[mode_index] or "live",
      morph = morph,
      smooth_bins = smooth_bins,
      carrier_freeze_pos = carrier_pos,
      modulator_freeze_pos = modulator_pos,
      expand = expand,
      mix = mix,
      normalize = normalize,
      normalize_db = normalize_db,
    }, "s3g_spectral_morph", {
      "Carrier: " .. carrier.name .. " (" .. tostring(carrier.channels) .. "ch)",
      "Modulator: " .. modulator.name .. " (" .. tostring(modulator.channels) .. "ch)",
      "Backend: Python WAV reader + NumPy STFT",
      "Mode: " .. (MODE_NAMES[mode_index] or "Live morph"),
      "FFT: " .. tostring(FFT_VALUES[fft_index] or 2048),
      "Morph position: " .. string.format("%.3f", morph),
      "Expansion: " .. string.format("%.2fx", expand),
    })
    return
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
