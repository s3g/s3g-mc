-- @description Spatial Repeater
-- @author s3g
-- @version 0.1
-- @requires Multichannel Texture Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; may extend beyond source item length.
-- @method Repeats one source channel around a multichannel path with spacing, decay, and channel walk modes.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tex = dofile(script_dir .. "Multichannel Texture Library.lua")
local mc = tex.mc

local function main()
  local item, take, source_channels = mc.require_selected_audio_item()
  if not item then return end
  local ok, input = reaper.GetUserInputs("Spatial Repeater", 6,
    "Repeats,Output channels,Source channel,Spacing sec,Decay 0-1,Path 1=cw 2=pingpong 3=random",
    "8,8,1,0.25,0.75,1")
  if not ok then return end
  local reps_text, out_text, source_text, spacing_text, decay_text, path_text =
    input:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
  if not reps_text then mc.show_error("Enter six comma-separated values.") return end
  local repeats, err = mc.validate_channel_count(reps_text, "Repeats", 1, 512)
  if not repeats then mc.show_error(err) return end
  local output_channels
  output_channels, err = mc.validate_channel_count(out_text, "Output channels", 2, mc.MAX_REAPER_TRACK_CHANNELS)
  if not output_channels then mc.show_error(err) return end
  local source_channel
  source_channel, err = mc.validate_channel_count(source_text, "Source channel", 1, source_channels)
  if not source_channel then mc.show_error(err) return end
  local spacing = tonumber(spacing_text)
  local decay = tonumber(decay_text)
  local path = tonumber(path_text) or 1
  if not spacing or spacing < 0 or not decay or decay < 0 or decay > 1 then mc.show_error("Spacing and decay are invalid.") return end

  math.randomseed(os.time())
  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local events = {}
  for index = 1, repeats do
    events[#events + 1] = {
      input_channel = source_channel,
      output_channel = tex.channel_walk(index, output_channels, path),
      source_start = 0,
      output_start = (index - 1) * spacing,
      length = length,
      fade = 0.005,
      gain = decay ^ (index - 1),
    }
  end
  local render_length = length + math.max(0, repeats - 1) * spacing
  tex.render_events(item, output_channels, events, "Spatial repeater", { mute_source_item = true, render_length = render_length })
end

main()
