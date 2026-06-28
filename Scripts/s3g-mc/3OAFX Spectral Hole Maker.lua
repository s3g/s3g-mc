-- @description 3OAFX Spectral Hole Maker
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline ambisonic spectral profile render.
-- @method Select two WAV-backed ACN/SN3D ambisonic media items. The earliest selected item is the source; the next selected item is the spectral profile used to carve space. Both are decoded to the same 3OAFX directional layer, the profile carves spectral holes per direction, and the result is re-encoded.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tool = dofile(script_dir .. "3OAFX Spectral Profile Tool Library.lua")

tool.run({
  title = "3OAFX Spectral Hole Maker",
  short_title = "directional spectral hole maker",
  ext = "s3g_mc_foafx_spectral_hole_v1",
  process_kind = "hole",
  output_folder = "s3g_foafx_spectral_hole_renders",
  output_prefix = "s3g_foafx_spectral_hole",
  track_label = "3OAFX spectral hole",
  profile_label = "Carve profile",
  profile_log_label = "Carve profile",
  profile_box = "carve HOA",
  profile_detail = "space-making profile",
  model_detail = "negative mask",
  process_box = "carve source",
  process_detail = "profile-shaped holes",
  output_box = "carved HOA",
  amount_label = "Carve amount",
  floor_label = "Hole floor",
  sensitivity_label = "Carve sensitivity",
  flow_note = "The profile opens space in the source spectrum while preserving the source direction layer.",
  selection_error = "Select a source ambisonic WAV item, then an ambisonic WAV item whose spectrum should carve space.",
  defaults = {
    reduction_amount = 0.64,
    spectral_floor = 0.26,
    profile_sensitivity = 1.05,
    frequency_smoothing_bins = 5,
    temporal_smoothing = 0.42,
  },
})
