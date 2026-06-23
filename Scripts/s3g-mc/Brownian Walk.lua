-- @description Brownian Walk
-- @author s3g
-- @version 0.2
-- @requires Multichannel Texture Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; bounds to source item length.
-- @method Generates short fragments from one source channel using a bounded random walk through source time and output channels.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tex = dofile(script_dir .. "Multichannel Texture Library.lua")
local mc = tex.mc

local function reflect(value, lo, hi)
  if hi <= lo then return lo end
  while value < lo or value > hi do
    if value < lo then
      value = lo + (lo - value)
    elseif value > hi then
      value = hi - (value - hi)
    end
  end
  return value
end

local function main()
  local item, take, source_channels = mc.require_selected_audio_item()
  if not item then return end

  local ok, input = reaper.GetUserInputs("Brownian Walk", 7,
    "Events,Output channels,Source channel,Event length sec,Tick sec,Channel step,Source step 0-1",
    "96,8,1,0.08,0.06,1,0.08")
  if not ok then return end

  local events_text, out_text, source_text, len_text, tick_text, chan_step_text, src_step_text =
    input:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
  if not events_text then mc.show_error("Enter seven comma-separated values.") return end

  local event_count, err = mc.validate_channel_count(events_text, "Events", 1, 4000)
  if not event_count then mc.show_error(err) return end
  local output_channels
  output_channels, err = mc.validate_channel_count(out_text, "Output channels", 2, mc.MAX_REAPER_TRACK_CHANNELS)
  if not output_channels then mc.show_error(err) return end
  local source_channel
  source_channel, err = mc.validate_channel_count(source_text, "Source channel", 1, source_channels)
  if not source_channel then mc.show_error(err) return end

  local event_len = tonumber(len_text)
  local tick = tonumber(tick_text)
  local channel_step
  channel_step, err = mc.validate_channel_count(chan_step_text, "Channel step", 1, output_channels)
  if not channel_step then mc.show_error(err) return end
  local source_step = tex.clamp(tonumber(src_step_text) or 0.08, 0, 1)
  if not event_len or event_len <= 0 or not tick or tick <= 0 then mc.show_error("Event length and tick must be positive.") return end

  math.randomseed(os.time())
  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local event_length = math.min(event_len, length)
  local max_start = math.max(0, length - event_length)
  local output_tick = tick
  if event_count > 1 and output_tick * (event_count - 1) < max_start then
    output_tick = max_start / (event_count - 1)
  end

  local channel = math.ceil(output_channels / 2)
  local source_pos = 0
  local events = {}
  for index = 1, event_count do
    events[#events + 1] = {
      input_channel = source_channel,
      output_channel = channel,
      source_start = source_pos,
      output_start = tex.clamp((index - 1) * output_tick, 0, max_start),
      length = event_length,
      fade = math.min(0.005, event_length / 3),
    }
    channel = tex.clamp(channel + math.random(-channel_step, channel_step), 1, output_channels)
    source_pos = reflect(source_pos + ((math.random() * 2 - 1) * source_step * length), 0, max_start)
  end

  tex.render_events(item, output_channels, events, "Brownian Walk", { mute_source_item = true })
end

main()
