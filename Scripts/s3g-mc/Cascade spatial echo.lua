-- @description Cascade spatial echo
-- @author s3g
-- @version 0.1
-- @requires Multichannel Texture Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; may extend beyond source item length.
-- @method Takes equal segments from one source channel and prints decaying echoes that step through multichannel space.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tex = dofile(script_dir .. "Multichannel Texture Library.lua")
local mc = tex.mc
local input_dialog = dofile(script_dir .. "s3g-mc ImGui Input Dialog.lua")

local function main()
  local item, take, source_channels = mc.require_selected_audio_item()
  if not item then return end
  input_dialog.prompt_csv("Cascade spatial echo",
    "Segments,Echoes,Output channels,Source channel,Delay sec,Decay 0-1,Fade sec",
    "8,4,8,1,0.18,0.65,0.005", function(input)
  local seg_text, echoes_text, out_text, source_text, delay_text, decay_text, fade_text =
    input:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
  if not seg_text then mc.show_error("Enter seven comma-separated values.") return end
  local segments, err = mc.validate_channel_count(seg_text, "Segments", 1, 256)
  if not segments then mc.show_error(err) return end
  local echoes
  echoes, err = mc.validate_channel_count(echoes_text, "Echoes", 1, 128)
  if not echoes then mc.show_error(err) return end
  local output_channels
  output_channels, err = mc.validate_channel_count(out_text, "Output channels", 2, mc.MAX_REAPER_TRACK_CHANNELS)
  if not output_channels then mc.show_error(err) return end
  local source_channel
  source_channel, err = mc.validate_channel_count(source_text, "Source channel", 1, source_channels)
  if not source_channel then mc.show_error(err) return end
  local delay = tonumber(delay_text)
  local decay = tonumber(decay_text)
  local fade = tonumber(fade_text)
  if not delay or delay < 0 or not decay or decay < 0 or decay > 1 or not fade or fade < 0 then mc.show_error("Delay, decay, or fade is invalid.") return end

  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local slices = tex.equal_slices(segments, length)
  local events = {}
  for seg_index, slice in ipairs(slices) do
    for echo = 1, echoes do
      events[#events + 1] = {
        input_channel = source_channel,
        output_channel = tex.channel_walk(seg_index + echo - 1, output_channels, 1),
        source_start = slice.source_start,
        output_start = slice.output_start + (echo - 1) * delay,
        length = slice.length,
        fade = fade,
        gain = decay ^ (echo - 1),
      }
    end
  end
  local render_length = length + math.max(0, echoes - 1) * delay
  tex.render_events(item, output_channels, events, "Cascade spatial echo", { mute_source_item = true, render_length = render_length })
  end)
end

main()
