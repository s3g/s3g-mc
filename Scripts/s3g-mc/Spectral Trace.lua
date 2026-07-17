-- @description Spectral Trace
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spectral / Convolution
-- @render Yes; writes a new spectrally traced media item.
-- @method Offline spectral trace. Select one WAV-backed media item; retain, suppress, threshold, or randomly thin spectral partials while preserving phase/timing.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local sol = dofile(script_dir .. "Spectral Offline Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "Spectral Trace", 0) return end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
do
  local _s3g_theme_path = ({ reaper.get_action_context() })[2]
  if not _s3g_theme_path or _s3g_theme_path == "" then
    _s3g_theme_path = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
  end
  local _s3g_theme_dir = _s3g_theme_path:match("^(.*[/\\])") or ""
  package.path = _s3g_theme_dir .. "?.lua;" .. package.path
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme and _s3g_theme.install then _s3g_theme.install(ImGui) end
end
local theme = require("s3g-mc ImGui Theme")


local FFT_NAMES = { [1] = "1024", [2] = "2048", [3] = "4096", [4] = "8192" }
local FFT_VALUES = { [1] = 1024, [2] = 2048, [3] = 4096, [4] = 8192 }
local MODE_NAMES = { [1] = "Keep loudest partials", [2] = "Suppress loudest partials", [3] = "Threshold trace", [4] = "Thin randomly" }
local MODE_VALUES = { [1] = "keep", [2] = "suppress", [3] = "threshold", [4] = "thin" }

local entries = sol.selected_entries()
local entry = entries[1]
if not entry then reaper.MB("Select one WAV-backed audio media item.", "Spectral Trace", 0) return end

local ctx = ImGui.CreateContext("Spectral Trace")
local open = true
local fft_index = 2
local mode_index = 1
local keep_bins = 24
local threshold = 0.25
local amount = 1.0
local mix = 1.0
local seed = 1
local normalize = true
local normalize_db = -6.0
local should_render = false

local function loop()
  ImGui.SetNextWindowSize(ctx, 540, 520, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, "Spectral Trace", open)
  if visible then
    theme.muted(ImGui, ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
    local changed
    local sx, sy, sh, stack = sol.begin_section(ImGui, ctx, "Trace", mode_index == 4 and 198 or 173)
    changed, mode_index = sol.draw_combo(ImGui, ctx, "Trace mode", mode_index, MODE_NAMES, 1, 4)
    changed, fft_index = sol.draw_combo(ImGui, ctx, "FFT size", fft_index, FFT_NAMES, 1, 4)
    if mode_index <= 2 then
      changed, keep_bins = sol.draw_slider_int(ImGui, ctx, "Partial count", keep_bins, 1, 512)
    else
      changed, threshold = sol.draw_slider(ImGui, ctx, mode_index == 4 and "Keep probability" or "Threshold", threshold, 0.01, 1.0, "%.3f", false)
    end
    changed, amount = sol.draw_slider(ImGui, ctx, "Trace amount", amount, 0, 1, "%.3f", false)
    changed, mix = sol.draw_slider(ImGui, ctx, "Wet mix", mix, 0, 1, "%.3f", false)
    if mode_index == 4 then changed, seed = sol.draw_slider_int(ImGui, ctx, "Random seed", seed, 1, 9999) end
    sol.finish_section(ImGui, ctx, sx, sy, sh, stack)
    sx, sy, sh, stack = sol.begin_section(ImGui, ctx, "Output", normalize and 98 or 73)
    changed, normalize = sol.draw_checkbox(ImGui, ctx, "Peak normalize", normalize)
    if normalize then changed, normalize_db = sol.draw_slider(ImGui, ctx, "Normalize peak dB", normalize_db, -24, 0, "%.1f", false) end
    sol.finish_section(ImGui, ctx, sx, sy, sh, stack)
    theme.muted(ImGui, ctx, "Reduces or opens the spectrum by selecting partials per frame.")
    if ImGui.Button(ctx, "RENDER", 92, 26) then should_render = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "CANCEL", 92, 26) then open = false end
    ImGui.End(ctx)
  end
  if should_render then
    open = false
    sol.render(script_dir, "Spectral Trace", entry, {
      mode = "trace",
      source_path = entry.filename,
      source_start_offset = entry.start_offset,
      source_duration = entry.length * math.max(0.000001, entry.playrate),
      sample_rate = sol.source_sample_rate(entry),
      fft_size = FFT_VALUES[fft_index] or 2048,
      overlap = 4,
      trace_kind = MODE_VALUES[mode_index] or "keep",
      keep_bins = keep_bins,
      threshold = threshold,
      amount = amount,
      mix = mix,
      seed = seed,
      normalize = normalize,
      normalize_db = normalize_db,
    }, "s3g_spectral_trace", {
      "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. "ch)",
      "Backend: Python WAV reader + NumPy STFT",
      "Mode: " .. (MODE_NAMES[mode_index] or "Keep loudest partials"),
      "FFT: " .. tostring(FFT_VALUES[fft_index] or 2048),
      "Amount: " .. string.format("%.3f", amount),
    })
    return
  end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
