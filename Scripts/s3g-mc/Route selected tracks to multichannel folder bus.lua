-- @description Route selected tracks to multichannel folder bus
-- @author s3g
-- @version 0.1
-- @requires Multichannel Library.lua; REAPER 5.90 or newer
-- @category Track Building / Routing
-- @render No
-- @method Creates a new multichannel folder bus above the selected tracks, moves the selected tracks into it, and assigns each child track's parent send to consecutive bus channels.
-- @about
--   Counts the active audio channel width of each selected track, creates a
--   parent folder bus large enough to contain those channels, then routes each
--   gathered child track's parent send into its own channel span on the bus. If
--   the required bus width exceeds REAPER's 128-channel track limit, the action
--   stops before changing the project.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")

local PROJECT = mc.PROJECT
local TITLE = "Route selected tracks to multichannel folder bus"

local function selected_track_entries()
  local entries = {}
  for index = 0, reaper.CountSelectedTracks(PROJECT) - 1 do
    local track = reaper.GetSelectedTrack(PROJECT, index)
    local media_channels = mc.get_track_media_channel_count(track)
    local routing_channels = media_channels == 1 and 1 or mc.reaper_track_channel_count(media_channels)
    local track_number = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
    entries[#entries + 1] = {
      track = track,
      name = mc.get_track_name(track),
      media_channels = media_channels,
      routing_channels = routing_channels,
      original_number = track_number,
    }
  end

  table.sort(entries, function(a, b) return a.original_number < b.original_number end)
  return entries
end

local function first_selected_track_index(entries)
  local first_number = entries[1].original_number
  for _, entry in ipairs(entries) do
    first_number = math.min(first_number, entry.original_number)
  end
  return first_number - 1
end

local function total_routing_channels(entries)
  local total_media = 0
  local total_routing = 0
  for _, entry in ipairs(entries) do
    total_media = total_media + entry.media_channels
    total_routing = total_routing + entry.routing_channels
  end
  return total_media, total_routing
end

local function child_range_text(start_channel, media_channels, routing_channels)
  local media_end = start_channel + media_channels - 1
  if routing_channels == media_channels then
    return tostring(start_channel) .. "-" .. tostring(media_end)
  end
  return tostring(start_channel) .. "-" .. tostring(media_end) ..
    " (routing reserves through " .. tostring(start_channel + routing_channels - 1) .. ")"
end

local function main()
  if not reaper.APIExists("ReorderSelectedTracks") then
    mc.show_error("This action requires REAPER 5.90 or newer for ReorderSelectedTracks().")
    return
  end

  local entries = selected_track_entries()
  if #entries == 0 then
    mc.show_error("Select one or more tracks first.")
    return
  end

  local total_media, total_routing = total_routing_channels(entries)
  local bus_channels = mc.reaper_track_channel_count(total_routing)
  if bus_channels > mc.MAX_REAPER_TRACK_CHANNELS then
    mc.show_error("The selected tracks need " .. tostring(total_routing) ..
      " routed channels (" .. tostring(bus_channels) ..
      " REAPER track channels). REAPER tracks support up to " ..
      tostring(mc.MAX_REAPER_TRACK_CHANNELS) .. " channels.")
    return
  end

  local insert_index = first_selected_track_index(entries)
  local insert_id = insert_index + 1
  local summary = {}

  reaper.Undo_BeginBlock()
  mc.with_ui_refresh_block(function()
    reaper.InsertTrackAtIndex(insert_index, true)
    local bus = reaper.GetTrack(PROJECT, insert_index)
    reaper.GetSetMediaTrackInfo_String(bus, "P_NAME",
      "Multichannel folder bus (" .. tostring(total_media) .. "ch)", true)
    reaper.SetMediaTrackInfo_Value(bus, "I_NCHAN", bus_channels)
    reaper.SetMediaTrackInfo_Value(bus, "B_MAINSEND", 1)

    reaper.Main_OnCommand(40297, 0) -- Track: Unselect all tracks.
    for _, entry in ipairs(entries) do
      if reaper.ValidatePtr2(PROJECT, entry.track, "MediaTrack*") then
        reaper.SetTrackSelected(entry.track, true)
      end
    end
    reaper.ReorderSelectedTracks(insert_id, 1)

    local channel_offset = 0
    for _, entry in ipairs(entries) do
      if reaper.ValidatePtr2(PROJECT, entry.track, "MediaTrack*") then
        reaper.SetMediaTrackInfo_Value(entry.track, "B_MAINSEND", 1)
        reaper.SetMediaTrackInfo_Value(entry.track, "C_MAINSEND_OFFS", channel_offset)
        reaper.SetMediaTrackInfo_Value(entry.track, "C_MAINSEND_NCH", entry.routing_channels)

        summary[#summary + 1] = entry.name .. " -> bus ch " ..
          child_range_text(channel_offset + 1, entry.media_channels, entry.routing_channels)
        channel_offset = channel_offset + entry.routing_channels
      end
    end

    mc.select_only_track(bus)
  end)
  reaper.Undo_EndBlock(TITLE, -1)

  local lines = {
    "Created folder bus: " .. tostring(bus_channels) .. " REAPER track channels",
    "Selected tracks gathered: " .. tostring(#entries),
    "Media channels counted: " .. tostring(total_media),
    "Routed channel span: " .. tostring(total_routing),
    "",
    table.concat(summary, "\n"),
  }
  mc.print_plan("Route selected tracks to multichannel folder bus", lines)
end

main()
