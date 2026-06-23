-- @description Explode multichannel item to mono tracks
-- @author s3g
-- @version 0.1
-- @requires Multichannel Library.lua
-- @category Item Channel Transforms
-- @method Duplicates the selected multichannel item to one new mono track per source channel, preserving item length and setting each take to its matching channel.
-- @about
--   Duplicates the selected multichannel audio item to one new track per
--   source channel and sets each take to play one mono source channel.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")

local function main()
  local item, take, channel_count = mc.require_selected_multichannel_item()
  if not item then return end

  local source_track = reaper.GetMediaItemTrack(item)
  local insert_index = mc.get_insert_index_after_track(source_track)
  local source_name = mc.get_track_name(source_track)
  local created_tracks = {}

  reaper.Undo_BeginBlock()
  mc.with_ui_refresh_block(function()
    for channel = 1, channel_count do
      local track, clone = mc.create_mono_channel_track_from_item(item, channel,
        insert_index + channel - 1, source_name .. " ch " .. tostring(channel))
      if clone then created_tracks[#created_tracks + 1] = track end
    end

    reaper.Main_OnCommand(40297, 0) -- Track: Unselect all tracks
    for _, track in ipairs(created_tracks) do
      reaper.SetTrackSelected(track, true)
    end
  end)
  reaper.Undo_EndBlock("Explode selected multichannel item to mono tracks", -1)

  mc.print_plan("Exploded multichannel item", {
    "Item: " .. mc.item_label(item),
    "Source channels: " .. tostring(channel_count),
    "Created tracks: " .. tostring(#created_tracks),
  })
end

main()
