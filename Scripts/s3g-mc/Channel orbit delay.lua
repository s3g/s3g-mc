-- @description Channel orbit delay
-- @author s3g
-- @version 0.1
-- @requires Multichannel Texture Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; may extend beyond source item length.
-- @method Prints whole-item delay repeats that orbit through output channels by a fixed channel step.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tex = dofile(script_dir .. "Multichannel Texture Library.lua")
local mc = tex.mc

local function main()
  local item, take, source_channels = mc.require_selected_audio_item()
  if not item then return end

  local ok, input = reaper.GetUserInputs("Channel orbit delay", 6,
    "Repeats,Output channels,Source channel,Delay sec,Channel step,Decay 0-1",
    "8,8,1,0.22,1,0.7")
  if not ok then return end

  local reps_text, out_text, source_text, delay_text, step_text, decay_text =
    input:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
  if not reps_text then mc.show_error("Enter six comma-separated values.") return end

  local repeats, err = mc.validate_channel_count(reps_text, "Repeats", 1, 256)
  if not repeats then mc.show_error(err) return end
  local output_channels
  output_channels, err = mc.validate_channel_count(out_text, "Output channels", 2, mc.MAX_REAPER_TRACK_CHANNELS)
  if not output_channels then mc.show_error(err) return end
  local source_channel
  source_channel, err = mc.validate_channel_count(source_text, "Source channel", 1, source_channels)
  if not source_channel then mc.show_error(err) return end

  local delay = tonumber(delay_text)
  local step = tonumber(step_text) or 1
  local decay = tex.clamp(tonumber(decay_text) or 1, 0, 1)
  if not delay or delay < 0 then mc.show_error("Delay is invalid.") return end

  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local events = {}
  for index = 1, repeats do
    events[#events + 1] = {
      input_channel = source_channel,
      output_channel = ((index - 1) * step % output_channels) + 1,
      source_start = 0,
      output_start = (index - 1) * delay,
      length = length,
      fade = 0.005,
      gain = decay ^ (index - 1),
    }
  end

  tex.render_events(item, output_channels, events, "Channel orbit delay",
    { mute_source_item = true, render_length = length + (repeats - 1) * delay })
end

main()
