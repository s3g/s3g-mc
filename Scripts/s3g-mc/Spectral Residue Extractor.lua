-- @description Spectral Residue Extractor
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spectral / Convolution
-- @render Yes; NumPy-backed offline multichannel spectral profile render.
-- @method Select two WAV-backed media items. The earliest selected item is the source; the next selected item is the profile to remove. The renderer outputs the removed spectral residue directly per channel, preserving the source channel count.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tool = dofile(script_dir .. "Multichannel Spectral Profile Tool Library.lua")

tool.run({
  title = "Spectral Residue Extractor",
  short_title = "multichannel spectral residue extractor",
  ext = "s3g_mc_spectral_residue_extractor_v1",
  process_kind = "residue",
  output_mode = "residue",
  output_folder = "s3g_spectral_residue_renders",
  output_prefix = "s3g_spectral_residue",
  track_label = "Spectral residue",
  profile_label = "Profile",
  profile_log_label = "Profile",
  profile_box = "profile",
  process_box = "extract residue",
  output_box = "residue output",
  amount_label = "Extraction amount",
  floor_label = "Source floor",
  sensitivity_label = "Profile sensitivity",
  flow_note = "The output contains the spectral material removed from the source by the profile.",
  selection_error = "Select a source WAV item, then a profile WAV item to extract as residue.",
  defaults = {
    channel_index = 1,
    reduction_amount = 0.78,
    spectral_floor = 0.14,
    profile_sensitivity = 1.20,
    frequency_smoothing_bins = 3,
    temporal_smoothing = 0.35,
  },
})
