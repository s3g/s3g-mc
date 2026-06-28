-- @description 3OAFX Ambiance Extractor
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline ambisonic spectral profile render.
-- @method Select two WAV-backed ACN/SN3D ambisonic media items. The earliest selected item is the source; the next selected item is an ambiance/noise-bed profile. Both are decoded to the same 3OAFX directional layer, source bins that resemble the profile are extracted per direction, and the result is re-encoded.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tool = dofile(script_dir .. "3OAFX Spectral Profile Tool Library.lua")

tool.run({
  title = "3OAFX Ambiance Extractor",
  short_title = "directional ambiance extraction",
  ext = "s3g_mc_foafx_ambiance_extractor_v1",
  process_kind = "ambience",
  output_folder = "s3g_foafx_ambiance_extractor_renders",
  output_prefix = "s3g_foafx_ambiance_extractor",
  track_label = "3OAFX ambiance extractor",
  profile_label = "Ambiance profile",
  profile_log_label = "Ambiance profile",
  profile_box = "ambiance HOA",
  profile_detail = "noise bed / room tone",
  model_detail = "matching mask",
  process_box = "extract match",
  process_detail = "profile-like bins",
  output_box = "ambiance HOA",
  amount_label = "Extraction amount",
  floor_label = "Residual floor",
  sensitivity_label = "Ambiance sensitivity",
  flow_note = "The profile identifies source material that resembles the room tone or ambiance sample.",
  selection_error = "Select a source ambisonic WAV item, then an ambisonic WAV item containing the ambiance profile to extract.",
  defaults = {
    reduction_amount = 0.85,
    spectral_floor = 0.03,
    profile_sensitivity = 1.45,
    frequency_smoothing_bins = 7,
    temporal_smoothing = 0.62,
  },
})
