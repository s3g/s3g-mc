-- @description Stereo Spin
-- @author s3g
-- @version 0.1
-- @requires Multichannel Texture Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; bounds to source item length.
-- @method Slices a stereo source and rotates the left/right image around a multichannel output field.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tex = dofile(script_dir .. "Multichannel Texture Library.lua")
local mc = tex.mc
local input_dialog = dofile(script_dir .. "s3g-mc ImGui Input Dialog.lua")

local function main()
  local item, take, source_channels = mc.require_selected_audio_item(2)
  if not item then return end

  input_dialog.prompt_csv("Stereo Spin",
    "Slices,Output channels,Width channels,Step per slice,Fade sec",
    "64,8,2,1,0.005", function(input)

  local slices_text, out_text, width_text, step_text, fade_text =
    input:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
  if not slices_text then mc.show_error("Enter five comma-separated values.") return end

  local slice_count, err = mc.validate_channel_count(slices_text, "Slices", 2, 1024)
  if not slice_count then mc.show_error(err) return end
  local output_channels
  output_channels, err = mc.validate_channel_count(out_text, "Output channels", 2, mc.MAX_REAPER_TRACK_CHANNELS)
  if not output_channels then mc.show_error(err) return end
  local width
  width, err = mc.validate_channel_count(width_text, "Width channels", 1, output_channels - 1)
  if not width then mc.show_error(err) return end
  local step
  step, err = mc.validate_channel_count(step_text, "Step per slice", 0, output_channels)
  if not step then mc.show_error(err) return end
  local fade = tonumber(fade_text) or 0
  if fade < 0 then mc.show_error("Fade is invalid.") return end

  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local slices = tex.equal_slices(slice_count, length)
  local events = {}
  for index, slice in ipairs(slices) do
    local left = ((index - 1) * step % output_channels) + 1
    local right = ((left - 1 + width) % output_channels) + 1
    events[#events + 1] = {
      input_channel = 1,
      output_channel = left,
      source_start = slice.source_start,
      output_start = slice.output_start,
      length = slice.length,
      fade = fade,
    }
    events[#events + 1] = {
      input_channel = 2,
      output_channel = right,
      source_start = slice.source_start,
      output_start = slice.output_start,
      length = slice.length,
      fade = fade,
    }
  end

  tex.render_events(item, output_channels, events, "Stereo Spin", { mute_source_item = true })
  end)
end

main()
