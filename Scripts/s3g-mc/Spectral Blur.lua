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
  local section_h = 198 + (normalize and 50 or 25)
  ImGui.SetNextWindowSize(ctx, 520, section_h + 150, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, "Spectral Blur", open)
  if visible then
    theme.muted(ImGui, ctx, "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. " ch)")
    local changed
    local sx, sy, sh, stack = sol.begin_section(ImGui, ctx, "Blur", section_h)
    changed, fft_index = sol.draw_combo(ImGui, ctx, "FFT size", fft_index, FFT_NAMES, 1, 4)
    changed, amount = sol.draw_slider(ImGui, ctx, "Blur amount", amount, 0, 1, "%.3f", false)
    changed, mix = sol.draw_slider(ImGui, ctx, "Wet mix", mix, 0, 1, "%.3f", false)
    changed, radius = sol.draw_slider_int(ImGui, ctx, "Time blur frames", radius, 1, 96)
    changed, expand = sol.draw_slider(ImGui, ctx, "Expansion", expand, 1.0, 8.0, "%.2fx", false)
    changed, safe = sol.draw_checkbox(ImGui, ctx, "Safe envelope mode", safe)
    changed, normalize = sol.draw_checkbox(ImGui, ctx, "Peak normalize", normalize)
    if normalize then changed, normalize_db = sol.draw_slider(ImGui, ctx, "Normalize peak dB", normalize_db, -24, 0, "%.1f", false) end
    sol.finish_section(ImGui, ctx, sx, sy, sh, stack)
    theme.muted(ImGui, ctx, "Smears spectral magnitude over neighboring frames.")
    local render_pressed, cancel_pressed = theme.footer_buttons(ImGui, ctx, "RENDER", "CANCEL", 104, 104)
    if render_pressed then should_render = true end
    if cancel_pressed then open = false end
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
