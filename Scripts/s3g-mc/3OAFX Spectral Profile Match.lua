-- @description 3OAFX Spectral Profile Match
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline ambisonic spectral profile render.
-- @method Select two WAV-backed ACN/SN3D ambisonic media items. The earliest selected item is the source; the next selected item is the spectral reference. Both are decoded to the same 3OAFX directional layer, the source spectrum is steered toward the reference profile per direction, and the result is re-encoded.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tool = dofile(script_dir .. "3OAFX Spectral Profile Tool Library.lua")

tool.run({
  title = "3OAFX Spectral Profile Match",
  short_title = "directional spectral profile match",
  ext = "s3g_mc_foafx_profile_match_v1",
  process_kind = "match",
  output_folder = "s3g_foafx_profile_match_renders",
  output_prefix = "s3g_foafx_profile_match",
  track_label = "3OAFX profile match",
  profile_label = "Reference",
  profile_log_label = "Reference",
  profile_box = "reference HOA",
  profile_detail = "target spectral shape",
  model_detail = "directional contour",
  process_box = "match profile",
  process_detail = "preserve source phase",
  output_box = "matched source",
  amount_label = "Match amount",
  floor_label = "Low-bin protection",
  sensitivity_label = "Reference sensitivity",
  flow_note = "The reference shapes the source spectrum per direction; it is not mixed into the output.",
  selection_error = "Select a source ambisonic WAV item, then a reference ambisonic WAV item.",
  defaults = {
    reduction_amount = 0.55,
    spectral_floor = 0.10,
    profile_sensitivity = 1.00,
    frequency_smoothing_bins = 8,
    temporal_smoothing = 0.45,
  },
})
