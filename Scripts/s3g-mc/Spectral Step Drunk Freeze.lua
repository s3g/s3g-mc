-- @description Spectral Step Drunk Freeze
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spectral / Convolution
-- @render Yes; writes a new stepped or drunk-frozen spectral media item.
-- @method Stepped freeze and random-walk freeze. Select one WAV-backed media item; spectral frames are held at regular intervals or by random walk while preserving carrier phase/timing.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local sol = dofile(script_dir .. "Spectral Offline Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "Spectral Step Drunk Freeze", 0) return end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local FFT_NAMES = { [1] = "1024", [2] = "2048", [3] = "4096", [4] = "8192" }
local FFT_VALUES = { [1] = 1024, [2] = 2048, [3] = 4096, [4] = 8192 }
local MODE_NAMES = { [1] = "Stepped freeze", [2] = "Drunk freeze" }
local MODE_VALUES = { [1] = "step", [2] = "drunk" }

local entries = sol.selected_entries()
local entry = entries[1]
if not entry then reaper.MB("Select one WAV-backed audio media item.", "Spectral Step Drunk Freeze", 0) return end

local ctx = ImGui.CreateContext("Spectral Step Drunk Freeze")
local open = true
local fft_index = 2
local mode_index = 1
local step_frames = 12
local jump_frames = 4
local smooth_bins = 5
local amount = 0.8
local mix = 1.0
local expand = 1.0
local seed = 1
local normalize = true
local normalize_db = -6.0
local should_render = false

local function loop()
  ImGui.SetNextWindowSize(ctx, 540, 420, ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, "Spectral Step Drunk Freeze", open)
  if visible then
    ImGui.Text(ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
    local changed
    changed, mode_index = sol.draw_combo(ImGui, ctx, "Freeze mode", mode_index, MODE_NAMES, 1, 2)
    changed, fft_index = sol.draw_combo(ImGui, ctx, "FFT size", fft_index, FFT_NAMES, 1, 4)
    changed, step_frames = ImGui.SliderInt(ctx, "Hold clock frames", step_frames, 1, 96)
    if mode_index == 2 then
      changed, jump_frames = ImGui.SliderInt(ctx, "Random walk jump", jump_frames, 1, 96)
      changed, seed = ImGui.SliderInt(ctx, "Random seed", seed, 1, 9999)
    end
    changed, smooth_bins = ImGui.SliderInt(ctx, "Spectral smoothing bins", smooth_bins, 1, 96)
    changed, amount = ImGui.SliderDouble(ctx, "Freeze amount", amount, 0, 1, "%.3f")
    changed, expand = ImGui.SliderDouble(ctx, "Expansion", expand, 1.0, 8.0, "%.2fx")
    changed, mix = ImGui.SliderDouble(ctx, "Wet mix", mix, 0, 1, "%.3f")
    changed, normalize = ImGui.Checkbox(ctx, "Peak normalize", normalize)
    if normalize then changed, normalize_db = ImGui.SliderDouble(ctx, "Normalize peak dB", normalize_db, -24, 0, "%.1f") end
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Holds spectral frames by clock or random walk.")
    if ImGui.Button(ctx, "Render", 92, 26) then should_render = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 92, 26) then open = false end
    ImGui.End(ctx)
  end
  if should_render then
    open = false
    sol.render(script_dir, "Spectral Step Drunk Freeze", entry, {
      mode = "step_drunk",
      source_path = entry.filename,
      source_start_offset = entry.start_offset,
      source_duration = entry.length * math.max(0.000001, entry.playrate),
      sample_rate = sol.source_sample_rate(entry),
      fft_size = FFT_VALUES[fft_index] or 2048,
      overlap = 4,
      freeze_variant = MODE_VALUES[mode_index] or "step",
      step_frames = step_frames,
      jump_frames = jump_frames,
      smooth_bins = smooth_bins,
      amount = amount,
      expand = expand,
      mix = mix,
      seed = seed,
      normalize = normalize,
      normalize_db = normalize_db,
    }, "s3g_spectral_step_drunk_freeze", {
      "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. "ch)",
      "Backend: Python WAV reader + NumPy STFT",
      "Mode: " .. (MODE_NAMES[mode_index] or "Stepped freeze"),
      "FFT: " .. tostring(FFT_VALUES[fft_index] or 2048),
      "Hold clock frames: " .. tostring(step_frames),
      "Expansion: " .. string.format("%.2fx", expand),
    })
    return
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
