-- @description 3OAFX Spectral Profile Subtract
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed offline ambisonic spectral profile render.
-- @method Select two WAV-backed ACN/SN3D ambisonic media items. The earliest selected item is the source; the next selected item is the spectral profile to remove. The renderer decodes both to the same 3OAFX directional layer, applies profile subtraction per direction, and re-encodes a new ambisonic item.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tool = dofile(script_dir .. "3OAFX Spectral Profile Tool Library.lua")

tool.run({
  title = "3OAFX Spectral Profile Subtract",
  short_title = "directional spectral profile subtraction",
  ext = "s3g_mc_foafx_profile_subtract_v1",
  process_kind = "subtract",
  output_folder = "s3g_foafx_profile_subtract_renders",
  output_prefix = "s3g_foafx_profile_subtract",
  track_label = "3OAFX profile subtract",
  profile_label = "Profile",
  profile_log_label = "Profile",
  profile_box = "profile HOA",
  profile_detail = "material to remove",
  model_detail = "per-direction mask",
  process_box = "subtract / gate",
  process_detail = "same direction bins",
  output_box = "cleaned source",
  amount_label = "Reduction amount",
  floor_label = "Spectral floor",
  sensitivity_label = "Profile sensitivity",
  flow_note = "Profile audio is analyzed into a spectral mask; it is not mixed into the source path.",
  selection_error = "Select two WAV-backed ambisonic media items. The earliest selected item is the source; the next selected item is the profile to remove.",
  defaults = {
    reduction_amount = 0.72,
    spectral_floor = 0.18,
    profile_sensitivity = 1.15,
    frequency_smoothing_bins = 3,
    temporal_smoothing = 0.35,
  },
})
