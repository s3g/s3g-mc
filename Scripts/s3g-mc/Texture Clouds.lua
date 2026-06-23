-- @description Texture Clouds
-- @author s3g
-- @version 0.1
-- @requires Multichannel Texture Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; bounds to source item length.
-- @method Generates a dense cloud of short fragments from one source channel across a multichannel output field.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tex = dofile(script_dir .. "Multichannel Texture Library.lua")
local mc = tex.mc

local function main()
  local item, take, source_channels = mc.require_selected_audio_item()
  if not item then return end

  local ok, input = reaper.GetUserInputs("Texture Clouds", 7,
    "Events,Output channels,Source channel,Avg grain sec,Length rand 0-1,Timing scatter 0-1,Fade sec",
    "160,8,1,0.08,0.6,1,0.005")
  if not ok then return end

  local events_text, out_text, source_text, grain_text, rand_text, scatter_text, fade_text =
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

  local grain = tonumber(grain_text)
  local length_rand = tex.clamp(tonumber(rand_text) or 0, 0, 1)
  local scatter = tex.clamp(tonumber(scatter_text) or 0, 0, 1)
  local fade = tonumber(fade_text) or 0
  if not grain or grain <= 0 or fade < 0 then mc.show_error("Grain and fade values are invalid.") return end

  math.randomseed(os.time())
  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local events = {}
  for index = 1, event_count do
    local grain_scale = 1 - length_rand + math.random() * length_rand * 2
    local grain_len = tex.clamp(grain * grain_scale, 0.001, length)
    local grid_pos = (index - 1) * length / event_count
    local out_start = tex.clamp(grid_pos + (math.random() * 2 - 1) * scatter * grain * 4,
      0, math.max(0, length - grain_len))
    events[#events + 1] = {
      input_channel = source_channel,
      output_channel = math.random(output_channels),
      source_start = math.random() * math.max(0, length - grain_len),
      output_start = out_start,
      length = grain_len,
      fade = fade,
      gain = 1 / math.sqrt(math.max(1, event_count / 32)),
    }
  end

  local did_render = tex.render_events(item, output_channels, events, "Texture clouds", { mute_source_item = true })
  if did_render then
    mc.print_plan("Texture Clouds", {
      "Events: " .. tostring(event_count),
      "Output channels: " .. tostring(output_channels),
      "Average grain: " .. tostring(grain),
    })
  end
end

main()
