-- @description Spectral Blur
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spectral / Convolution
-- @render Yes; writes a new spectrally blurred media item.
-- @method Offline STFT magnitude blur. Select one WAV-backed media item; the action smooths spectral magnitudes across time while preserving phase, with safe envelope mode and optional time expansion.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local sol = dofile(script_dir .. "Spectral Offline Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "Spectral Blur", 0) return end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local FFT_NAMES = { [1] = "1024", [2] = "2048", [3] = "4096", [4] = "8192" }
local FFT_VALUES = { [1] = 1024, [2] = 2048, [3] = 4096, [4] = 8192 }

local entries = sol.selected_entries()
local entry = entries[1]
if not entry then reaper.MB("Select one WAV-backed audio media item.", "Spectral Blur", 0) return end

local ctx = ImGui.CreateContext("Spectral Blur")
local open = true
local fft_index = 2
local amount = 0.55
local mix = 0.85
local radius = 5
local expand = 1.0
local safe = true
local normalize = true
local normalize_db = -6.0
local should_render = false

local function loop()
  ImGui.SetNextWindowSize(ctx, 520, 350, ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, "Spectral Blur", open)
  if visible then
    ImGui.Text(ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
    local changed
    changed, fft_index = sol.draw_combo(ImGui, ctx, "FFT size", fft_index, FFT_NAMES, 1, 4)
    changed, amount = ImGui.SliderDouble(ctx, "Blur amount", amount, 0, 1, "%.3f")
    changed, mix = ImGui.SliderDouble(ctx, "Wet mix", mix, 0, 1, "%.3f")
    changed, radius = ImGui.SliderInt(ctx, "Time blur frames", radius, 1, 96)
    changed, expand = ImGui.SliderDouble(ctx, "Expansion", expand, 1.0, 8.0, "%.2fx")
    changed, safe = ImGui.Checkbox(ctx, "Safe envelope mode", safe)
    changed, normalize = ImGui.Checkbox(ctx, "Peak normalize", normalize)
    if normalize then changed, normalize_db = ImGui.SliderDouble(ctx, "Normalize peak dB", normalize_db, -24, 0, "%.1f") end
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Smears spectral magnitude over neighboring frames.")
    if ImGui.Button(ctx, "Render", 92, 26) then should_render = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 92, 26) then open = false end
    ImGui.End(ctx)
  end
  if should_render then
    open = false
    sol.render(script_dir, "Spectral Blur", entry, {
      mode = "blur",
      source_path = entry.filename,
      source_start_offset = entry.start_offset,
      source_duration = entry.length * math.max(0.000001, entry.playrate),
      sample_rate = sol.source_sample_rate(entry),
      fft_size = FFT_VALUES[fft_index] or 2048,
      overlap = 4,
      amount = amount,
      mix = mix,
      time_radius = radius,
      expand = expand,
      safe = safe,
      normalize = normalize,
      normalize_db = normalize_db,
    }, "s3g_spectral_blur", {
      "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. "ch)",
      "Backend: Python WAV reader + NumPy STFT",
      "FFT: " .. tostring(FFT_VALUES[fft_index] or 2048),
      "Blur amount: " .. string.format("%.3f", amount),
      "Time blur frames: " .. tostring(radius),
      "Expansion: " .. string.format("%.2fx", expand),
      "Safe envelope mode: " .. (safe and "on" or "off"),
    })
    return
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
