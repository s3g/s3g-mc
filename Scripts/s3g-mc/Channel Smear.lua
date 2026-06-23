-- @description Channel Smear
-- @author s3g
-- @version 0.1
-- @requires Multichannel Texture Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; bounds to source item length.
-- @method Slices one source channel and duplicates each slice to neighboring output channels with gain compensation.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tex = dofile(script_dir .. "Multichannel Texture Library.lua")
local mc = tex.mc

local function main()
  local item, take, source_channels = mc.require_selected_audio_item()
  if not item then return end

  local ok, input = reaper.GetUserInputs("Channel Smear", 6,
    "Slices,Output channels,Source channel,Spread width,Path 1=cw 2=pingpong 3=random,Fade sec",
    "32,8,1,3,2,0.005")
  if not ok then return end

  local slices_text, out_text, source_text, spread_text, path_text, fade_text =
    input:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
  if not slices_text then mc.show_error("Enter six comma-separated values.") return end

  local slice_count, err = mc.validate_channel_count(slices_text, "Slices", 2, 512)
  if not slice_count then mc.show_error(err) return end
  local output_channels
  output_channels, err = mc.validate_channel_count(out_text, "Output channels", 2, mc.MAX_REAPER_TRACK_CHANNELS)
  if not output_channels then mc.show_error(err) return end
  local source_channel
  source_channel, err = mc.validate_channel_count(source_text, "Source channel", 1, source_channels)
  if not source_channel then mc.show_error(err) return end
  local spread
  spread, err = mc.validate_channel_count(spread_text, "Spread width", 1, output_channels)
  if not spread then mc.show_error(err) return end
  local path = tonumber(path_text) or 2
  local fade = tonumber(fade_text) or 0
  if fade < 0 then mc.show_error("Fade is invalid.") return end

  math.randomseed(os.time())
  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local slices = tex.equal_slices(slice_count, length)
  local events = {}
  local gain = 1 / math.sqrt(spread)
  for index, slice in ipairs(slices) do
    local center = tex.channel_walk(index, output_channels, path)
    local left = math.floor((spread - 1) / 2)
    for voice = 0, spread - 1 do
      local channel = ((center - 1 - left + voice) % output_channels) + 1
      events[#events + 1] = {
        input_channel = source_channel,
        output_channel = channel,
        source_start = slice.source_start,
        output_start = slice.output_start,
        length = slice.length,
        fade = fade,
        gain = gain,
      }
    end
  end

  tex.render_events(item, output_channels, events, "Channel smear", { mute_source_item = true })
end

main()
