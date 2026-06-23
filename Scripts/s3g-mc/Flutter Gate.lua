-- @description Flutter Gate
-- @author s3g
-- @version 0.1
-- @requires Multichannel Texture Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; bounds to source item length.
-- @method Slices a multichannel source and prints a moving flutter/gate pattern across its channels.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tex = dofile(script_dir .. "Multichannel Texture Library.lua")
local mc = tex.mc

local function main()
  local item, take, source_channels = mc.require_selected_multichannel_item()
  if not item then return end

  local ok, input = reaper.GetUserInputs("Flutter Gate", 5,
    "Slices,Active channels,Duty 0-1,Step channels,Fade sec",
    "96,2,0.65,1,0.003")
  if not ok then return end

  local slices_text, active_text, duty_text, step_text, fade_text =
    input:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
  if not slices_text then mc.show_error("Enter five comma-separated values.") return end

  local slice_count, err = mc.validate_channel_count(slices_text, "Slices", 2, 2048)
  if not slice_count then mc.show_error(err) return end
  local active
  active, err = mc.validate_channel_count(active_text, "Active channels", 1, source_channels)
  if not active then mc.show_error(err) return end
  local duty = tex.clamp(tonumber(duty_text) or 0.65, 0.05, 1)
  local step
  step, err = mc.validate_channel_count(step_text, "Step channels", 0, source_channels)
  if not step then mc.show_error(err) return end
  local fade = tonumber(fade_text) or 0
  if fade < 0 then mc.show_error("Fade is invalid.") return end

  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local slices = tex.equal_slices(slice_count, length)
  local events = {}
  for index, slice in ipairs(slices) do
    if ((index - 1) % 100) / 100 < duty then
      local start_channel = ((index - 1) * step % source_channels) + 1
      for voice = 0, active - 1 do
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
  end

  tex.render_events(item, source_channels, events, "Flutter Gate", { mute_source_item = true })
end

main()
