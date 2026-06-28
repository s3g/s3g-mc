-- @description Spectral Hole Maker
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spectral / Convolution
-- @render Yes; NumPy-backed offline multichannel spectral profile render.
-- @method Select two WAV-backed media items. The earliest selected item is the source; the next selected item is the profile used to carve space. The renderer creates profile-shaped spectral holes directly per channel, preserving the source channel count.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tool = dofile(script_dir .. "Multichannel Spectral Profile Tool Library.lua")

tool.run({
  title = "Spectral Hole Maker",
  short_title = "multichannel spectral hole maker",
  ext = "s3g_mc_spectral_hole_maker_v1",
  process_kind = "hole",
  output_folder = "s3g_spectral_hole_renders",
  output_prefix = "s3g_spectral_hole",
  track_label = "Spectral hole",
  profile_label = "Carve profile",
  profile_log_label = "Carve profile",
  profile_box = "carve profile",
  process_box = "carve source",
  output_box = "carved output",
  amount_label = "Carve amount",
  floor_label = "Hole floor",
  sensitivity_label = "Carve sensitivity",
  flow_note = "Use this to make spectral space in a multichannel bed while preserving channel layout.",
  selection_error = "Select a source WAV item, then a profile WAV item whose spectrum should carve space.",
  defaults = {
    channel_index = 2,
    reduction_amount = 0.64,
    spectral_floor = 0.26,
    profile_sensitivity = 1.05,
    frequency_smoothing_bins = 5,
    temporal_smoothing = 0.42,
  },
})
