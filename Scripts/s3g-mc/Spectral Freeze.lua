-- @description Spectral Freeze
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spectral / Convolution
-- @render Yes; writes a new spectrally frozen media item.
-- @method Offline STFT spectral freeze. Select one WAV-backed media item; one spectral frame is imposed over the item while carrier phase/timing remains, with safe envelope mode, envelope floor, and optional time expansion.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local sol = dofile(script_dir .. "Spectral Offline Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "Spectral Freeze", 0) return end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local FFT_NAMES = { [1] = "1024", [2] = "2048", [3] = "4096", [4] = "8192" }
local FFT_VALUES = { [1] = 1024, [2] = 2048, [3] = 4096, [4] = 8192 }

local entries = sol.selected_entries()
local entry = entries[1]
if not entry then reaper.MB("Select one WAV-backed audio media item.", "Spectral Freeze", 0) return end

local ctx = ImGui.CreateContext("Spectral Freeze")
local open = true
local fft_index = 2
local amount = 0.65
local mix = 0.9
local pos = 0.5
local smooth_bins = 9
local expand = 1.0
local safe = true
local floor = 0.05
local normalize = true
local normalize_db = -6.0
local should_render = false

local function loop()
  ImGui.SetNextWindowSize(ctx, 520, 460, ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, "Spectral Freeze", open)
  if visible then
    ImGui.Text(ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
    local changed
    changed, fft_index = sol.draw_combo(ImGui, ctx, "FFT size", fft_index, FFT_NAMES, 1, 4)
    changed, pos = ImGui.SliderDouble(ctx, "Freeze position", pos, 0, 1, "%.3f")
    changed, amount = ImGui.SliderDouble(ctx, "Freeze amount", amount, 0, 1, "%.3f")
    changed, mix = ImGui.SliderDouble(ctx, "Wet mix", mix, 0, 1, "%.3f")
    changed, smooth_bins = ImGui.SliderInt(ctx, "Spectral smoothing bins", smooth_bins, 1, 96)
    changed, expand = ImGui.SliderDouble(ctx, "Expansion", expand, 1.0, 8.0, "%.2fx")
    changed, floor = ImGui.SliderDouble(ctx, "Envelope floor", floor, 0.001, 0.5, "%.3f")
    changed, safe = ImGui.Checkbox(ctx, "Safe envelope mode", safe)
    changed, normalize = ImGui.Checkbox(ctx, "Peak normalize", normalize)
    if normalize then changed, normalize_db = ImGui.SliderDouble(ctx, "Normalize peak dB", normalize_db, -24, 0, "%.1f") end
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Freezes one spectral magnitude frame across the selected item.")
    if ImGui.Button(ctx, "Render", 92, 26) then should_render = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 92, 26) then open = false end
    ImGui.End(ctx)
  end
  if should_render then
    open = false
    sol.render(script_dir, "Spectral Freeze", entry, {
      mode = "freeze",
      source_path = entry.filename,
      source_start_offset = entry.start_offset,
      source_duration = entry.length * math.max(0.000001, entry.playrate),
      sample_rate = sol.source_sample_rate(entry),
      fft_size = FFT_VALUES[fft_index] or 2048,
      overlap = 4,
      freeze_pos = pos,
      amount = amount,
      mix = mix,
      smooth_bins = smooth_bins,
      expand = expand,
      floor = floor,
      safe = safe,
      normalize = normalize,
      normalize_db = normalize_db,
    }, "s3g_spectral_freeze", {
      "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. "ch)",
      "Backend: Python WAV reader + NumPy STFT",
      "FFT: " .. tostring(FFT_VALUES[fft_index] or 2048),
      "Freeze position: " .. string.format("%.3f", pos),
      "Freeze amount: " .. string.format("%.3f", amount),
      "Expansion: " .. string.format("%.2fx", expand),
      "Safe envelope mode: " .. (safe and "on" or "off"),
    })
    return
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
