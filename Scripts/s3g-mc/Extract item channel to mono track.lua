-- @description Extract item channel to mono track
-- @author s3g
-- @version 0.1
-- @requires Multichannel Library.lua
-- @category Item Channel Transforms
-- @method Duplicates the selected item to a new mono track and sets the take to one chosen source channel.
-- @about
--   Non-rendering utility for auditioning or editing one channel from a
--   multichannel item as a mono take.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")

local function main()
  local item, take, channel_count = mc.require_selected_audio_item()
  if not item then return end

  local ok, input = reaper.GetUserInputs("Extract item channel", 1,
    "Source channel", "1")
  if not ok then return end

  local channel, err = mc.validate_channel_count(input, "Source channel", 1, channel_count)
  if not channel then
    mc.show_error(err)
    return
  end

  local source_track = reaper.GetMediaItemTrack(item)
  local insert_index = mc.get_insert_index_after_track(source_track)
  local source_name = mc.get_track_name(source_track)

  reaper.Undo_BeginBlock()
  local track
  local clone
  mc.with_ui_refresh_block(function()
    track, clone = mc.create_mono_channel_track_from_item(item, channel, insert_index,
      source_name .. " ch " .. tostring(channel))
    if track then mc.select_only_track(track) end
    if clone then mc.select_only_item(clone) end
  end)
  reaper.Undo_EndBlock("Extract selected item channel to mono track", -1)

  if clone then
    mc.print_plan("Extracted item channel", {
      "Item: " .. mc.item_label(item),
      "Source channel: " .. tostring(channel),
      "Created track: " .. (track and mc.get_track_name(track) or "(none)"),
    })
  else
    mc.show_error("Could not duplicate the selected item.")
  end
end

main()
