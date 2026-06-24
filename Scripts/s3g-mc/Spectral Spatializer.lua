-- @description Spectral Spatializer
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spectral / Convolution
-- @render Yes; writes a new multichannel spectrally spatialized media item.
-- @method Offline STFT bin spatializer. Select one WAV-backed media item; frequency bins are distributed across even output channel counts from 2 to 64.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local sol = dofile(script_dir .. "Spectral Offline Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "Spectral Spatializer", 0) return end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local FFT_NAMES = { [1] = "1024", [2] = "2048", [3] = "4096", [4] = "8192" }
local FFT_VALUES = { [1] = 1024, [2] = 2048, [3] = 4096, [4] = 8192 }
local CH_NAMES, CH_VALUES = {}, {}
for channels = 2, 64, 2 do
  CH_VALUES[#CH_VALUES + 1] = channels
  CH_NAMES[#CH_NAMES + 1] = tostring(channels)
end

local entries = sol.selected_entries()
local entry = entries[1]
if not entry then reaper.MB("Select one WAV-backed audio media item.", "Spectral Spatializer", 0) return end

local ctx = ImGui.CreateContext("Spectral Spatializer")
local open = true
local fft_index = 2
local ch_index = 4
local spread = 1.25
local normalize = true
local normalize_db = -6.0
local should_render = false

local function loop()
  ImGui.SetNextWindowSize(ctx, 500, 300, ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, "Spectral Spatializer", open)
  if visible then
    ImGui.Text(ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
    local changed
    changed, fft_index = sol.draw_combo(ImGui, ctx, "FFT size", fft_index, FFT_NAMES, 1, 4)
    changed, ch_index = sol.draw_combo(ImGui, ctx, "Output channels", ch_index, CH_NAMES, 1, #CH_VALUES)
    changed, spread = ImGui.SliderDouble(ctx, "Bin spread", spread, 0.25, 6.0, "%.2f")
    changed, normalize = ImGui.Checkbox(ctx, "Peak normalize", normalize)
    if normalize then changed, normalize_db = ImGui.SliderDouble(ctx, "Normalize peak dB", normalize_db, -24, 0, "%.1f") end
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Low-to-high frequency bins are distributed across output channels.")
    if ImGui.Button(ctx, "Render", 92, 26) then should_render = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 92, 26) then open = false end
    ImGui.End(ctx)
  end
  if should_render then
    open = false
    local out_ch = CH_VALUES[ch_index] or 8
    sol.render(script_dir, "Spectral Spatializer", entry, {
      mode = "spatialize",
      source_path = entry.filename,
      source_start_offset = entry.start_offset,
      source_duration = entry.length * math.max(0.000001, entry.playrate),
      sample_rate = sol.source_sample_rate(entry),
      fft_size = FFT_VALUES[fft_index] or 2048,
      overlap = 4,
      output_channels = out_ch,
      spread = spread,
      normalize = normalize,
      normalize_db = normalize_db,
    }, "s3g_spectral_spatializer", {
      "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. "ch)",
      "Backend: Python WAV reader + NumPy STFT",
      "FFT: " .. tostring(FFT_VALUES[fft_index] or 2048),
      "Output channels: " .. tostring(out_ch),
      "Bin spread: " .. string.format("%.2f", spread),
    })
    return
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
