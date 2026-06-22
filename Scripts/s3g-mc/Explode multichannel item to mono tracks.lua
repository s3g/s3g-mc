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
  local item, take, channel_count = mc.get_selected_audio_item()
  if not item then return end

  if channel_count < 2 then
    mc.show_error("The selected item is mono; there is nothing to explode.")
    return
  end

  local source_track = reaper.GetMediaItemTrack(item)
  local insert_index = mc.get_insert_index_after_track(source_track)
  local source_name = mc.get_track_name(source_track)
  local created_tracks = {}

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  for channel = 1, channel_count do
    local track = mc.insert_track_at(insert_index + channel - 1,
      source_name .. " ch " .. tostring(channel), 2)
    local clone = mc.clone_item_to_track(item, track)
    if clone then
      local clone_take = reaper.GetActiveTake(clone)
      mc.set_take_to_mono_source_channel(clone_take, channel)
      created_tracks[#created_tracks + 1] = track
    end
  end

  reaper.Main_OnCommand(40297, 0) -- Track: Unselect all tracks
  for _, track in ipairs(created_tracks) do
    reaper.SetTrackSelected(track, true)
  end

  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Explode selected multichannel item to mono tracks", -1)

  reaper.ShowConsoleMsg("")
  reaper.ShowConsoleMsg("Exploded selected item to " .. tostring(channel_count) .. " mono-channel tracks.\n")
end

main()
