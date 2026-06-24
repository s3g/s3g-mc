-- @description Cross Synthesis
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spectral / Convolution
-- @render Yes; writes a new cross-synthesized media item.
-- @method Offline STFT cross-synthesis. Select two WAV-backed media items: carrier first, modulator second. Carrier phase/timing is shaped by the modulator spectrum.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local sol = dofile(script_dir .. "Spectral Offline Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "Cross Synthesis", 0) return end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local FFT_NAMES = { [1] = "1024", [2] = "2048", [3] = "4096", [4] = "8192" }
local FFT_VALUES = { [1] = 1024, [2] = 2048, [3] = 4096, [4] = 8192 }

local entries = sol.selected_entries()
if #entries < 2 then reaper.MB("Select two WAV-backed media items: carrier first, modulator second.", "Cross Synthesis", 0) return end

local ctx = ImGui.CreateContext("Cross Synthesis")
local open = true
local fft_index = 2
local amount = 0.85
local mix = 1.0
local smooth_bins = 7
local contrast = 1.0
local floor = 0.05
local normalize = true
local normalize_db = -6.0
local swap = false
local should_render = false

local function loop()
  ImGui.SetNextWindowSize(ctx, 540, 370, ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, "Cross Synthesis", open)
  if visible then
    local carrier = swap and entries[2] or entries[1]
    local modulator = swap and entries[1] or entries[2]
    ImGui.Text(ctx, "Carrier: " .. carrier.name .. " (" .. tostring(carrier.channels) .. " ch)")
    ImGui.Text(ctx, "Modulator: " .. modulator.name .. " (" .. tostring(modulator.channels) .. " ch)")
    if ImGui.Button(ctx, "Swap carrier / modulator") then swap = not swap end
    ImGui.Spacing(ctx)
    local changed
    changed, fft_index = sol.draw_combo(ImGui, ctx, "FFT size", fft_index, FFT_NAMES, 1, 4)
    changed, amount = ImGui.SliderDouble(ctx, "Modulator amount", amount, 0, 1, "%.3f")
    changed, mix = ImGui.SliderDouble(ctx, "Wet mix", mix, 0, 1, "%.3f")
    changed, smooth_bins = ImGui.SliderInt(ctx, "Envelope smoothing bins", smooth_bins, 1, 96)
    changed, contrast = ImGui.SliderDouble(ctx, "Envelope contrast", contrast, 0.1, 3.0, "%.2f")
    changed, floor = ImGui.SliderDouble(ctx, "Envelope floor", floor, 0.001, 0.5, "%.3f")
    changed, normalize = ImGui.Checkbox(ctx, "Peak normalize", normalize)
    if normalize then changed, normalize_db = ImGui.SliderDouble(ctx, "Normalize peak dB", normalize_db, -24, 0, "%.1f") end
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Carrier keeps phase/timing; modulator supplies spectral contour.")
    if ImGui.Button(ctx, "Render", 92, 26) then should_render = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 92, 26) then open = false end
    ImGui.End(ctx)
  end
  if should_render then
    open = false
    local carrier = swap and entries[2] or entries[1]
    local modulator = swap and entries[1] or entries[2]
    sol.render(script_dir, "Cross Synthesis", carrier, {
      mode = "cross",
      source_path = carrier.filename,
      source_start_offset = carrier.start_offset,
      source_duration = carrier.length * math.max(0.000001, carrier.playrate),
      modulator_path = modulator.filename,
      modulator_start_offset = modulator.start_offset,
      modulator_duration = modulator.length * math.max(0.000001, modulator.playrate),
      sample_rate = sol.source_sample_rate(carrier),
      fft_size = FFT_VALUES[fft_index] or 2048,
      overlap = 4,
      amount = amount,
      mix = mix,
      smooth_bins = smooth_bins,
      contrast = contrast,
      floor = floor,
      normalize = normalize,
      normalize_db = normalize_db,
    }, "s3g_cross_synthesis", {
      "Carrier: " .. carrier.name .. " (" .. tostring(carrier.channels) .. "ch)",
      "Modulator: " .. modulator.name .. " (" .. tostring(modulator.channels) .. "ch)",
      "Backend: Python WAV reader + NumPy STFT",
      "FFT: " .. tostring(FFT_VALUES[fft_index] or 2048),
      "Modulator amount: " .. string.format("%.3f", amount),
    })
    return
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
