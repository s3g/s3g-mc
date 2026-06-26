-- @description Mono Fill
-- @author s3g
-- @version 0.1
-- @requires Multichannel Texture Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; bounds to source item length.
-- @method Duplicates one source channel into every output channel with optional gain compensation and rotation by slices.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tex = dofile(script_dir .. "Multichannel Texture Library.lua")
local mc = tex.mc
local input_dialog = dofile(script_dir .. "s3g-mc ImGui Input Dialog.lua")

local function main()
  local item, take, source_channels = mc.require_selected_audio_item()
  if not item then return end

  input_dialog.prompt_csv("Mono Fill",
    "Output channels,Source channel,Slices,Rotate 0/1,Gain compensate 0/1",
    "8,1,1,0,1", function(input)

  local out_text, source_text, slices_text, rotate_text, gain_text =
    input:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
  if not out_text then mc.show_error("Enter five comma-separated values.") return end

  local output_channels, err = mc.validate_channel_count(out_text, "Output channels", 2, mc.MAX_REAPER_TRACK_CHANNELS)
  if not output_channels then mc.show_error(err) return end
  local source_channel
  source_channel, err = mc.validate_channel_count(source_text, "Source channel", 1, source_channels)
  if not source_channel then mc.show_error(err) return end
  local slice_count
  slice_count, err = mc.validate_channel_count(slices_text, "Slices", 1, 512)
  if not slice_count then mc.show_error(err) return end
  local rotate = tonumber(rotate_text) == 1
  local gain = tonumber(gain_text) == 1 and (1 / math.sqrt(output_channels)) or 1

  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local slices = tex.equal_slices(slice_count, length)
  local events = {}
  for index, slice in ipairs(slices) do
    local offset = rotate and (index - 1) or 0
    for channel = 1, output_channels do
      events[#events + 1] = {
        input_channel = source_channel,
        output_channel = ((channel - 1 + offset) % output_channels) + 1,
        source_start = slice.source_start,
        output_start = slice.output_start,
        length = slice.length,
        fade = 0.003,
        gain = gain,
      }
    end
  end

  tex.render_events(item, output_channels, events, "Mono Fill", { mute_source_item = true })
  end)
end

main()
