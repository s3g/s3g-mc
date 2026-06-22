-- @description Build multichannel stem from selected tracks
-- @author s3g
-- @version 0.2
-- @requires REAPER multichannel stem render action
-- @category Track Building / Routing
-- @render Prompts before rendering; bounds to selected-track media range.
-- @method Creates routing from selected tracks into consecutive multichannel outputs.
-- @about
--   Counts media-source channels on selected tracks, inserts a new destination
--   track, and routes each selected track into consecutive destination channels.
--   Optionally renders that destination to a multichannel stem item.
--
--   Example: 8 selected mono media tracks -> one 8-channel destination track,
--   with source tracks routed to destination channels 1..8, then rendered.

local PROJECT = 0
local SEND_MODE_POST_FX = 3
local MAX_REAPER_TRACK_CHANNELS = 128
local RENDER_AFTER_ROUTING = true
local ASK_BEFORE_RENDER = true
local DELETE_ROUTING_BUS_AFTER_RENDER = true

local RENDER_SELECTED_AREA_MULTICHANNEL_POST_FADER_STEM_NAME =
  "Track: Render selected area of tracks to multichannel post-fader stem tracks (and mute originals)"
local RENDER_SELECTED_AREA_MULTICHANNEL_POST_FADER_STEM_FALLBACK_COMMAND = 40900

local function show_error(message)
  reaper.MB(message, "Create multichannel track", 0)
end

local function get_track_name(track)
  local ok, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  if ok and name ~= "" then return name end
  local index = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
  return "Track " .. tostring(index)
end

local function get_track_media_channel_count(track)
  local max_channels = 0
  local item_count = reaper.CountTrackMediaItems(track)

  for item_index = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    local take = reaper.GetActiveTake(item)
    if take and not reaper.TakeIsMIDI(take) then
      local source = reaper.GetMediaItemTake_Source(take)
      if source then
        local channels = reaper.GetMediaSourceNumChannels(source)
        local channel_mode = math.floor(reaper.GetMediaItemTakeInfo_Value(take, "I_CHANMODE") or 0)
        if channel_mode >= 2 then channels = 1 end
        if channels and channels > max_channels then
          max_channels = channels
        end
      end
    end
  end

  if max_channels > 0 then
    return max_channels, false
  end

  return math.max(1, math.floor(reaper.GetMediaTrackInfo_Value(track, "I_NCHAN"))), true
end

local function get_selected_tracks()
  local tracks = {}
  local selected_count = reaper.CountSelectedTracks(PROJECT)

  for selected_index = 0, selected_count - 1 do
    local track = reaper.GetSelectedTrack(PROJECT, selected_index)
    local media_channels, used_track_channel_fallback = get_track_media_channel_count(track)
    tracks[#tracks + 1] = {
      track = track,
      name = get_track_name(track),
      media_channels = media_channels,
      routing_channels = media_channels == 1 and 1 or media_channels + (media_channels % 2),
      used_track_channel_fallback = used_track_channel_fallback
    }
  end

  return tracks
end

local function get_insert_index_after_selection(tracks)
  local insert_index = 0
  for _, entry in ipairs(tracks) do
    local track_number = math.floor(reaper.GetMediaTrackInfo_Value(entry.track, "IP_TRACKNUMBER"))
    if track_number > insert_index then insert_index = track_number end
  end
  return insert_index
end

local function select_only_track(track)
  reaper.Main_OnCommand(40297, 0) -- Track: Unselect all tracks
  reaper.SetTrackSelected(track, true)
end

local function track_is_excluded(track, excluded_tracks)
  for _, excluded in ipairs(excluded_tracks or {}) do
    if track == excluded then return true end
  end
  return false
end

local function get_selected_track_excluding(excluded_tracks)
  for index = 0, reaper.CountSelectedTracks(PROJECT) - 1 do
    local track = reaper.GetSelectedTrack(PROJECT, index)
    if not track_is_excluded(track, excluded_tracks) then return track end
  end
  return nil
end

local function snapshot_track_guids()
  local guids = {}
  for index = 0, reaper.CountTracks(PROJECT) - 1 do
    local track = reaper.GetTrack(PROJECT, index)
    guids[reaper.GetTrackGUID(track)] = true
  end
  return guids
end

local function find_new_track(before_guids)
  for index = 0, reaper.CountTracks(PROJECT) - 1 do
    local track = reaper.GetTrack(PROJECT, index)
    if not before_guids[reaper.GetTrackGUID(track)] then return track end
  end
  return nil
end

local function track_items_bounds(track_entries)
  local start_position = nil
  local end_position = nil
  for _, entry in ipairs(track_entries or {}) do
    local track = entry.track
    if track then
      for item_index = 0, reaper.CountTrackMediaItems(track) - 1 do
        local item = reaper.GetTrackMediaItem(track, item_index)
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        start_position = start_position and math.min(start_position, item_start) or item_start
        end_position = end_position and math.max(end_position, item_end) or item_end
      end
    end
  end
  return start_position or 0, end_position or 0
end

local function move_track_items_by(track, offset)
  if not track or offset == 0 then return end
  for item_index = 0, reaper.CountTrackMediaItems(track) - 1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", position + offset)
  end
end

local function set_track_items_length(track, length)
  if not track or not length or length <= 0 then return end
  for item_index = 0, reaper.CountTrackMediaItems(track) - 1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", length)
  end
end

local function save_time_selection()
  local start_pos, end_pos = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  return { start_pos = start_pos, end_pos = end_pos }
end

local function set_time_selection(start_pos, end_pos)
  reaper.GetSet_LoopTimeRange(true, false, start_pos, math.max(start_pos, end_pos), false)
end

local function restore_time_selection(saved)
  if not saved then return end
  reaper.GetSet_LoopTimeRange(true, false, saved.start_pos or 0, saved.end_pos or 0, false)
end

local function save_render_bounds()
  return {
    flag = reaper.GetSetProjectInfo(PROJECT, "RENDER_BOUNDSFLAG", 0, false),
    start_pos = reaper.GetSetProjectInfo(PROJECT, "RENDER_STARTPOS", 0, false),
    end_pos = reaper.GetSetProjectInfo(PROJECT, "RENDER_ENDPOS", 0, false),
  }
end

local function set_render_bounds_to_time_selection(start_pos, end_pos)
  reaper.GetSetProjectInfo(PROJECT, "RENDER_BOUNDSFLAG", 2, true)
  reaper.GetSetProjectInfo(PROJECT, "RENDER_STARTPOS", start_pos, true)
  reaper.GetSetProjectInfo(PROJECT, "RENDER_ENDPOS", math.max(start_pos, end_pos), true)
end

local function restore_render_bounds(saved)
  if not saved then return end
  reaper.GetSetProjectInfo(PROJECT, "RENDER_BOUNDSFLAG", saved.flag or 0, true)
  reaper.GetSetProjectInfo(PROJECT, "RENDER_STARTPOS", saved.start_pos or 0, true)
  reaper.GetSetProjectInfo(PROJECT, "RENDER_ENDPOS", saved.end_pos or 0, true)
end

local function source_channel_flag(channel_count)
  if channel_count == 1 then
    return 1024
  end

  return math.floor((channel_count + 1) / 2) * 1024
end

local function destination_channel_flag(channel_offset, channel_count)
  if channel_count == 1 then
    return channel_offset + 1024
  end

  return channel_offset
end

local function find_main_action_by_exact_name(name)
  if not reaper.kbd_getTextFromCmd then return nil end
  for command_id = 40000, 50000 do
    local text = reaper.kbd_getTextFromCmd(command_id, 0)
    if text == name then return command_id end
  end
  return nil
end

local function render_selected_area_multichannel_command()
  return find_main_action_by_exact_name(RENDER_SELECTED_AREA_MULTICHANNEL_POST_FADER_STEM_NAME) or
    RENDER_SELECTED_AREA_MULTICHANNEL_POST_FADER_STEM_FALLBACK_COMMAND
end

local function render_destination_track(destination, source_entries, destination_track_channels)
  if not RENDER_AFTER_ROUTING then return false end

  if ASK_BEFORE_RENDER then
    local answer = reaper.MB("Render the new routing track to a multichannel stem item now?",
      "Create multichannel track", 4)
    if answer ~= 6 then return false end
  end

  local bounds_start, bounds_end = track_items_bounds(source_entries)
  local bounds_length = bounds_end - bounds_start
  local saved_time_selection = save_time_selection()
  local saved_render_bounds = save_render_bounds()
  if bounds_length > 0 then
    set_time_selection(bounds_start, bounds_end)
    set_render_bounds_to_time_selection(bounds_start, bounds_end)
  end
  local before_guids = snapshot_track_guids()
  local track_count_before_render = reaper.CountTracks(PROJECT)
  select_only_track(destination)
  local render_command = render_selected_area_multichannel_command()
  reaper.Main_OnCommand(render_command, 0)
  restore_render_bounds(saved_render_bounds)
  restore_time_selection(saved_time_selection)
  local track_count_after_render = reaper.CountTracks(PROJECT)
  local did_render = track_count_after_render > track_count_before_render

  if did_render then
    local excluded_tracks = { destination }
    for _, entry in ipairs(source_entries or {}) do excluded_tracks[#excluded_tracks + 1] = entry.track end
    local rendered_track = find_new_track(before_guids) or get_selected_track_excluding(excluded_tracks)
    if rendered_track then
      reaper.SetMediaTrackInfo_Value(rendered_track, "I_NCHAN", destination_track_channels)
      if bounds_length > 0 then
        set_track_items_length(rendered_track, bounds_length)
        local rendered_start = track_items_bounds({ { track = rendered_track } })
        move_track_items_by(rendered_track, bounds_start - rendered_start)
      end
    end
  end

  if DELETE_ROUTING_BUS_AFTER_RENDER and did_render then
    if reaper.ValidatePtr2(PROJECT, destination, "MediaTrack*") then
      reaper.DeleteTrack(destination)
    end
  end

  return did_render, render_command
end

local function main()
  local tracks = get_selected_tracks()
  if #tracks == 0 then
    show_error("Select one or more tracks first.")
    return
  end

  local total_media_channels = 0
  local total_routing_channels = 0
  local fallback_count = 0

  for _, entry in ipairs(tracks) do
    total_media_channels = total_media_channels + entry.media_channels
    total_routing_channels = total_routing_channels + entry.routing_channels
    if entry.used_track_channel_fallback then fallback_count = fallback_count + 1 end
  end

  if total_routing_channels > MAX_REAPER_TRACK_CHANNELS then
    show_error("The selected tracks need " .. tostring(total_routing_channels) ..
      " routed channels. REAPER tracks support up to " ..
      tostring(MAX_REAPER_TRACK_CHANNELS) .. " channels.")
    return
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local insert_index = get_insert_index_after_selection(tracks)
  reaper.InsertTrackAtIndex(insert_index, true)
  local destination = reaper.GetTrack(PROJECT, insert_index)
  local destination_track_channels = total_routing_channels + (total_routing_channels % 2)

  reaper.GetSetMediaTrackInfo_String(destination, "P_NAME",
    "Multichannel from " .. tostring(#tracks) .. " tracks (" ..
    tostring(total_media_channels) .. "ch)", true)
  reaper.SetMediaTrackInfo_Value(destination, "I_NCHAN", destination_track_channels)

  local channel_offset = 0
  local summary = {}

  for _, entry in ipairs(tracks) do
    local send_index = reaper.CreateTrackSend(entry.track, destination)
    reaper.SetTrackSendInfo_Value(entry.track, 0, send_index, "I_SENDMODE", SEND_MODE_POST_FX)
    reaper.SetTrackSendInfo_Value(entry.track, 0, send_index, "D_VOL", 1.0)
    reaper.SetTrackSendInfo_Value(entry.track, 0, send_index, "I_SRCCHAN", source_channel_flag(entry.routing_channels))
    reaper.SetTrackSendInfo_Value(entry.track, 0, send_index, "I_DSTCHAN", destination_channel_flag(channel_offset, entry.routing_channels))

    summary[#summary + 1] = entry.name .. " -> ch " ..
      tostring(channel_offset + 1) .. "-" .. tostring(channel_offset + entry.media_channels)

    channel_offset = channel_offset + entry.routing_channels
  end

  select_only_track(destination)

  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Create multichannel routing track from selected tracks", -1)

  local did_render, render_command = render_destination_track(destination, tracks, destination_track_channels)

  local message = "Created destination track with " .. tostring(total_media_channels) ..
    " media channels"

  if destination_track_channels ~= total_media_channels then
    message = message .. " (" .. tostring(destination_track_channels) ..
      " REAPER track channels for routing)"
  end

  message = message .. ".\n\n" .. table.concat(summary, "\n")

  if fallback_count > 0 then
    message = message .. "\n\nNote: " .. tostring(fallback_count) ..
      " selected track(s) had no non-MIDI media, so their REAPER track channel count was used."
  end

  if RENDER_AFTER_ROUTING then
    if did_render then
      message = message .. "\n\nRendered using REAPER action " ..
        tostring(render_command or "?") ..
        " and selected the resulting stem track."
      if DELETE_ROUTING_BUS_AFTER_RENDER then
        message = message .. "\nTemporary routing bus was removed."
      end
    else
      message = message .. "\n\nRouting was created but not rendered."
      reaper.MB("Created the routing track, but REAPER did not create a rendered multichannel stem.\n\nThe script looked for this action:\n" .. RENDER_SELECTED_AREA_MULTICHANNEL_POST_FADER_STEM_NAME .. "\n\nCommand tried: " .. tostring(render_command or "?") .. "\n\nCheck that the selected tracks contain audio in the selected media range.", "Create multichannel track", 0)
    end
  end

  reaper.ShowConsoleMsg("")
  reaper.ShowConsoleMsg(message .. "\n")
end

main()
