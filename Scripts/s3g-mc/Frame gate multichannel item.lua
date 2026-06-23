-- @description Frame gate multichannel item
-- @author s3g
-- @version 0.1
-- @requires Multichannel Texture Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; bounds to source item length.
-- @method Slices a multichannel item and prints rotating active channel groups as a spatial gate pattern.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tex = dofile(script_dir .. "Multichannel Texture Library.lua")
local mc = tex.mc

local function main()
  local item, take, source_channels = mc.require_selected_multichannel_item()
  if not item then return end

  local ok, input = reaper.GetUserInputs("Frame gate multichannel item", 4,
    "Slices,Active group size,Step channels,Fade sec",
    "32,2,1,0.005")
  if not ok then return end

  local slices_text, group_text, step_text, fade_text =
    input:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
  if not slices_text then mc.show_error("Enter four comma-separated values.") return end

  local slice_count, err = mc.validate_channel_count(slices_text, "Slices", 2, 512)
  if not slice_count then mc.show_error(err) return end
  local group_size
  group_size, err = mc.validate_channel_count(group_text, "Active group size", 1, source_channels)
  if not group_size then mc.show_error(err) return end
  local step = tonumber(step_text) or 1
  local fade = tonumber(fade_text) or 0
  if fade < 0 then mc.show_error("Fade is invalid.") return end

  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local slices = tex.equal_slices(slice_count, length)
  local events = {}
  for index, slice in ipairs(slices) do
    local start_channel = ((index - 1) * step % source_channels) + 1
    for voice = 0, group_size - 1 do
      local channel = ((start_channel - 1 + voice) % source_channels) + 1
      events[#events + 1] = {
        input_channel = channel,
        output_channel = channel,
        source_start = slice.source_start,
        output_start = slice.output_start,
        length = slice.length,
        fade = fade,
      }
    end
  end

  tex.render_events(item, source_channels, events, "Frame gate", { mute_source_item = true })
end

main()
