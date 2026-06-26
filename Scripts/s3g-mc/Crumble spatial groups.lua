-- @description Crumble spatial groups
-- @author s3g
-- @version 0.1
-- @requires Multichannel Texture Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; bounds to source item length.
-- @method Slices one source channel and projects successive slices through progressively smaller channel groups.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tex = dofile(script_dir .. "Multichannel Texture Library.lua")
local mc = tex.mc
local input_dialog = dofile(script_dir .. "s3g-mc ImGui Input Dialog.lua")

local function main()
  local item, take, source_channels = mc.require_selected_audio_item()
  if not item then return end
  input_dialog.prompt_csv("Crumble spatial groups",
    "Slices,Output channels,Source channel,Minimum group,Fade sec",
    "32,8,1,1,0.005", function(input)
  local slices_text, out_text, source_text, min_text, fade_text =
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
  local min_group
  min_group, err = mc.validate_channel_count(min_text, "Minimum group", 1, output_channels)
  if not min_group then mc.show_error(err) return end
  local fade = tonumber(fade_text) or 0
  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local slices = tex.equal_slices(slice_count, length)
  local events = {}
  for index, slice in ipairs(slices) do
    local progress = (index - 1) / math.max(1, #slices - 1)
    local group_size = math.max(min_group, math.floor(output_channels - progress * (output_channels - min_group) + 0.5))
    local start_channel = math.floor((output_channels - group_size) * progress) + 1
    local output_channel = start_channel + ((index - 1) % group_size)
    events[#events + 1] = {
      input_channel = source_channel,
      output_channel = output_channel,
      source_start = slice.source_start,
      output_start = slice.output_start,
      length = slice.length,
      fade = fade,
    }
  end
  tex.render_events(item, output_channels, events, "Crumble spatial groups", { mute_source_item = true })
  end)
end

main()
