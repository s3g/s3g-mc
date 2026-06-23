-- @description Zigzag channel walker
-- @author s3g
-- @version 0.1
-- @requires Multichannel Texture Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; bounds to source item length.
-- @method Slices one source channel and walks successive slices back and forth across the output channels.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tex = dofile(script_dir .. "Multichannel Texture Library.lua")
local mc = tex.mc

local function main()
  local item, take, source_channels = mc.require_selected_audio_item()
  if not item then return end
  local ok, input = reaper.GetUserInputs("Zigzag channel walker", 5,
    "Slices,Output channels,Source channel,Read 1=forward 2=reverse order,Fade sec",
    "32,8,1,1,0.005")
  if not ok then return end
  local slices_text, out_text, source_text, read_text, fade_text =
    input:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
  if not slices_text then mc.show_error("Enter five comma-separated values.") return end
  local slice_count, err = mc.validate_channel_count(slices_text, "Slices", 2, 512)
  if not slice_count then mc.show_error(err) return end
  local output_channels
  output_channels, err = mc.validate_channel_count(out_text, "Output channels", 2, mc.MAX_REAPER_TRACK_CHANNELS)
  if not output_channels then mc.show_error(err) return end
  local source_channel
  source_channel, err = mc.validate_channel_count(source_text, "Source channel", 1, source_channels)
  if not source_channel then mc.show_error(err) return end
  local read_mode = tonumber(read_text) or 1
  local fade = tonumber(fade_text) or 0
  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local slices = tex.equal_slices(slice_count, length)
  local events = {}
  for index, slice in ipairs(slices) do
    local source_index = read_mode == 2 and (#slices - index + 1) or index
    events[#events + 1] = {
      input_channel = source_channel,
      output_channel = tex.channel_walk(index, output_channels, 2),
      source_start = slices[source_index].source_start,
      output_start = slice.output_start,
      length = slice.length,
      fade = fade,
    }
  end
  tex.render_events(item, output_channels, events, "Zigzag channel walker", { mute_source_item = true })
end

main()
