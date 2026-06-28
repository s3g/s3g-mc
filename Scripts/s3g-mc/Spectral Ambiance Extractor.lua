-- @description Spectral Ambiance Extractor
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spectral / Convolution
-- @render Yes; NumPy-backed offline multichannel spectral profile render.
-- @method Select two WAV-backed media items. The earliest selected item is the source; the next selected item is an ambiance/noise-bed profile. The renderer extracts source bins that resemble the profile directly per channel, preserving the source channel count.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tool = dofile(script_dir .. "Multichannel Spectral Profile Tool Library.lua")

tool.run({
  title = "Spectral Ambiance Extractor",
  short_title = "multichannel spectral ambiance extractor",
  ext = "s3g_mc_spectral_ambiance_extractor_v1",
  process_kind = "ambience",
  output_folder = "s3g_spectral_ambiance_renders",
  output_prefix = "s3g_spectral_ambiance",
  track_label = "Spectral ambiance",
  profile_label = "Ambiance profile",
  profile_log_label = "Ambiance profile",
  profile_box = "ambiance profile",
  process_box = "extract match",
  output_box = "ambiance output",
  amount_label = "Extraction amount",
  floor_label = "Residual floor",
  sensitivity_label = "Ambiance sensitivity",
  flow_note = "The profile identifies source material that resembles room tone or ambience.",
  selection_error = "Select a source WAV item, then a WAV item containing the ambiance profile to extract.",
  defaults = {
    channel_index = 3,
    reduction_amount = 0.85,
    spectral_floor = 0.03,
    profile_sensitivity = 1.45,
    frequency_smoothing_bins = 7,
    temporal_smoothing = 0.62,
  },
})
