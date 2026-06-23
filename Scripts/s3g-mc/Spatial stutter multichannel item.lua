-- @description Spatial stutter multichannel item
-- @author s3g
-- @version 0.1
-- @requires Multichannel Texture Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; bounds to source item length.
-- @method Repeats each source slice as a short spatial stutter that advances through a channel path.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tex = dofile(script_dir .. "Multichannel Texture Library.lua")
local mc = tex.mc

local function main()
  local item, take, source_channels = mc.require_selected_audio_item()
  if not item then return end

  local ok, input = reaper.GetUserInputs("Spatial stutter multichannel item", 7,
    "Slices,Repeats,Output channels,Source channel,Stutter gap sec,Decay 0-1,Path 1=cw 2=pingpong 3=random",
    "16,4,8,1,0.035,0.8,2")
  if not ok then return end

  local slices_text, reps_text, out_text, source_text, gap_text, decay_text, path_text =
    input:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
  if not slices_text then mc.show_error("Enter seven comma-separated values.") return end

  local slice_count, err = mc.validate_channel_count(slices_text, "Slices", 2, 512)
  if not slice_count then mc.show_error(err) return end
  local repeats
  repeats, err = mc.validate_channel_count(reps_text, "Repeats", 1, 64)
  if not repeats then mc.show_error(err) return end
  local output_channels
  output_channels, err = mc.validate_channel_count(out_text, "Output channels", 2, mc.MAX_REAPER_TRACK_CHANNELS)
  if not output_channels then mc.show_error(err) return end
  local source_channel
  source_channel, err = mc.validate_channel_count(source_text, "Source channel", 1, source_channels)
  if not source_channel then mc.show_error(err) return end

  local gap = tonumber(gap_text)
  local decay = tex.clamp(tonumber(decay_text) or 1, 0, 1)
  local path = tonumber(path_text) or 2
  if not gap or gap < 0 then mc.show_error("Stutter gap is invalid.") return end

  math.randomseed(os.time())
  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local slices = tex.equal_slices(slice_count, length)
  local events = {}
  for slice_index, slice in ipairs(slices) do
    local stutter_len = math.max(0.001, math.min(slice.length, gap > 0 and gap or slice.length))
    for repeat_index = 1, repeats do
      local out_start = slice.output_start + (repeat_index - 1) * gap
      if out_start + stutter_len <= length then
        events[#events + 1] = {
          input_channel = source_channel,
          output_channel = tex.channel_walk(slice_index + repeat_index - 1, output_channels, path),
          source_start = slice.source_start,
          output_start = out_start,
          length = stutter_len,
          fade = math.min(0.003, stutter_len / 3),
          gain = decay ^ (repeat_index - 1),
        }
      end
    end
  end

  tex.render_events(item, output_channels, events, "Spatial stutter", { mute_source_item = true })
end

main()
