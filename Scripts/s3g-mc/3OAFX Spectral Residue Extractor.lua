-- @description 3OAFX Spectral Residue Extractor
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline ambisonic spectral profile render.
-- @method Select two WAV-backed ACN/SN3D ambisonic media items. The earliest selected item is the source; the next selected item is the profile to subtract. The renderer outputs the removed spectral residue as a re-encoded ambisonic item.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tool = dofile(script_dir .. "3OAFX Spectral Profile Tool Library.lua")

tool.run({
  title = "3OAFX Spectral Residue Extractor",
  short_title = "directional spectral residue extraction",
  ext = "s3g_mc_foafx_spectral_residue_v1",
  process_kind = "residue",
  output_mode = "residue",
  output_folder = "s3g_foafx_spectral_residue_renders",
  output_prefix = "s3g_foafx_spectral_residue",
  track_label = "3OAFX spectral residue",
  profile_label = "Profile",
  profile_log_label = "Profile",
  profile_box = "profile HOA",
  profile_detail = "material to extract",
  model_detail = "removal profile",
  process_box = "extract residue",
  process_detail = "removed bins only",
  output_box = "residue HOA",
  amount_label = "Extraction amount",
  floor_label = "Source floor",
  sensitivity_label = "Profile sensitivity",
  flow_note = "The output is the spectral material removed from the source by the profile model.",
  selection_error = "Select a source ambisonic WAV item, then a profile ambisonic WAV item to extract as residue.",
  defaults = {
    reduction_amount = 0.78,
    spectral_floor = 0.14,
    profile_sensitivity = 1.20,
    frequency_smoothing_bins = 3,
    temporal_smoothing = 0.35,
  },
})
