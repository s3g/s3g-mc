-- @description Spectral Accumulate
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spectral / Convolution
-- @render Yes; writes a new spectrally accumulated media item.
-- @method Offline spectral accumulation. Select one WAV-backed media item; each spectral band sustains until stronger energy arrives, with decay, floor, and optional expansion.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local sol = dofile(script_dir .. "Spectral Offline Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "Spectral Accumulate", 0) return end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local FFT_NAMES = { [1] = "1024", [2] = "2048", [3] = "4096", [4] = "8192" }
local FFT_VALUES = { [1] = 1024, [2] = 2048, [3] = 4096, [4] = 8192 }

local entries = sol.selected_entries()
local entry = entries[1]
if not entry then reaper.MB("Select one WAV-backed audio media item.", "Spectral Accumulate", 0) return end

local ctx = ImGui.CreateContext("Spectral Accumulate")
local open = true
local fft_index = 2
local amount = 0.85
local mix = 1.0
local decay = 0.985
local floor = 0.02
local expand = 1.0
local normalize = true
local normalize_db = -6.0
local should_render = false

local function loop()
  ImGui.SetNextWindowSize(ctx, 520, 450, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, "Spectral Accumulate", open)
  if visible then
    ImGui.Text(ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
    local changed
    changed, fft_index = sol.draw_combo(ImGui, ctx, "FFT size", fft_index, FFT_NAMES, 1, 4)
    changed, amount = ImGui.SliderDouble(ctx, "Accumulate amount", amount, 0, 1, "%.3f")
    changed, decay = ImGui.SliderDouble(ctx, "Memory decay", decay, 0.9, 1.0, "%.4f")
    changed, floor = ImGui.SliderDouble(ctx, "Spectral floor", floor, 0.001, 0.25, "%.3f")
    changed, expand = ImGui.SliderDouble(ctx, "Expansion", expand, 1.0, 8.0, "%.2fx")
    changed, mix = ImGui.SliderDouble(ctx, "Wet mix", mix, 0, 1, "%.3f")
    changed, normalize = ImGui.Checkbox(ctx, "Peak normalize", normalize)
    if normalize then changed, normalize_db = ImGui.SliderDouble(ctx, "Normalize peak dB", normalize_db, -24, 0, "%.1f") end
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Sustains each bin until stronger energy replaces it.")
    if ImGui.Button(ctx, "Render", 92, 26) then should_render = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 92, 26) then open = false end
    ImGui.End(ctx)
  end
  if should_render then
    open = false
    sol.render(script_dir, "Spectral Accumulate", entry, {
      mode = "accumulate",
      source_path = entry.filename,
      source_start_offset = entry.start_offset,
      source_duration = entry.length * math.max(0.000001, entry.playrate),
      sample_rate = sol.source_sample_rate(entry),
      fft_size = FFT_VALUES[fft_index] or 2048,
      overlap = 4,
      amount = amount,
      decay = decay,
      floor = floor,
      expand = expand,
      mix = mix,
      normalize = normalize,
      normalize_db = normalize_db,
    }, "s3g_spectral_accumulate", {
      "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. "ch)",
      "Backend: Python WAV reader + NumPy STFT",
      "FFT: " .. tostring(FFT_VALUES[fft_index] or 2048),
      "Accumulate amount: " .. string.format("%.3f", amount),
      "Memory decay: " .. string.format("%.4f", decay),
      "Expansion: " .. string.format("%.2fx", expand),
    })
    return
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
