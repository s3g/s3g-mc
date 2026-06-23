-- @description Marker spatial montage
-- @author s3g
-- @version 0.1
-- @requires Multichannel Texture Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; bounds to source item length.
-- @method Uses project markers inside the selected item as source chunks, then distributes them across a multichannel output.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tex = dofile(script_dir .. "Multichannel Texture Library.lua")
local mc = tex.mc

local function shuffled_indices(count)
  local t = {}
  for i = 1, count do t[i] = i end
  for i = count, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

local function main()
  local item, take, source_channels = mc.require_selected_audio_item()
  if not item then return end

  local ok, input = reaper.GetUserInputs("Marker spatial montage", 5,
    "Output channels,Source channel,Order 1=as-is 2=shuffle,Path 1=cw 2=pingpong 3=random,Fade sec",
    "8,1,1,2,0.005")
  if not ok then return end

  local out_text, source_text, order_text, path_text, fade_text =
    input:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
  if not out_text then mc.show_error("Enter five comma-separated values.") return end

  local output_channels, err = mc.validate_channel_count(out_text, "Output channels", 2, mc.MAX_REAPER_TRACK_CHANNELS)
  if not output_channels then mc.show_error(err) return end
  local source_channel
  source_channel, err = mc.validate_channel_count(source_text, "Source channel", 1, source_channels)
  if not source_channel then mc.show_error(err) return end
  local order_mode = tonumber(order_text) or 1
  local path = tonumber(path_text) or 2
  local fade = tonumber(fade_text) or 0
  if fade < 0 then mc.show_error("Fade is invalid.") return end

  math.randomseed(os.time())
  local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local chunks = tex.marker_slices(position, length)
  if #chunks < 2 then mc.show_error("Add at least one project marker inside the selected item.") return end
  local order = order_mode == 2 and shuffled_indices(#chunks) or nil
  local events = {}
  local output_start = 0
  for index = 1, #chunks do
    local chunk = order and chunks[order[index]] or chunks[index]
    events[#events + 1] = {
      input_channel = source_channel,
      output_channel = tex.channel_walk(index, output_channels, path),
      source_start = chunk.source_start,
      output_start = output_start,
      length = chunk.length,
      fade = fade,
    }
    output_start = output_start + chunk.length
  end

  tex.render_events(item, output_channels, events, "Marker spatial montage", { mute_source_item = true })
end

main()
