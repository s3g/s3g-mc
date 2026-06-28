-- @description Spectral Profile Subtract
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spectral / Convolution
-- @render Yes; NumPy-backed offline multichannel spectral profile render.
-- @method Select two WAV-backed media items. The earliest selected item is the source; the next selected item is the profile to remove. The renderer applies profile subtraction directly per channel, preserving the source channel count without ambisonic decoding.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tool = dofile(script_dir .. "Multichannel Spectral Profile Tool Library.lua")

tool.run({
  title = "Spectral Profile Subtract",
  short_title = "multichannel spectral profile subtract",
  ext = "s3g_mc_spectral_profile_subtract_v1",
  process_kind = "subtract",
  output_folder = "s3g_spectral_profile_subtract_renders",
  output_prefix = "s3g_spectral_profile_subtract",
  track_label = "Spectral profile subtract",
  profile_label = "Profile",
  profile_log_label = "Profile",
  profile_box = "profile",
  process_box = "subtract profile",
  output_box = "cleaned output",
  amount_label = "Reduction amount",
  floor_label = "Spectral floor",
  sensitivity_label = "Profile sensitivity",
  flow_note = "The source channel count is preserved; no ambisonic decode/re-encode is used.",
  selection_error = "Select a source WAV item, then a profile WAV item to subtract.",
  defaults = {
    channel_index = 1,
    reduction_amount = 0.72,
    spectral_floor = 0.18,
    profile_sensitivity = 1.15,
    frequency_smoothing_bins = 3,
    temporal_smoothing = 0.35,
  },
})
