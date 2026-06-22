-- @description Cycle mono tracks into multichannel stem
-- @author s3g
-- @version 0.1
-- @requires Multichannel Library.lua; REAPER multichannel stem render action
-- @category Track Building / Routing
-- @render Yes; bounds to selected-track media range.
-- @method Routes selected mono tracks across the requested output channels, repeating or grouped-downmixing as needed.
-- @about
--   Routes selected mono media tracks into an N-channel bus and renders the
--   bus as a multichannel stem item. If output channels exceed source tracks,
--   source order repeats. If output channels are fewer than source tracks,
--   adjacent sources are grouped and gain-compensated per output.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")

local function get_selected_tracks()
  local tracks = {}
  for index = 0, reaper.CountSelectedTracks(mc.PROJECT) - 1 do
    tracks[#tracks + 1] = reaper.GetSelectedTrack(mc.PROJECT, index)
  end
  return tracks
end

local function get_insert_index_after_tracks(tracks)
  local insert_index = 0
  for _, track in ipairs(tracks) do
    local track_number = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
    if track_number > insert_index then insert_index = track_number end
  end
  return insert_index
end

local function build_assignments(source_count, output_channels)
  local assignments = {}

  if output_channels >= source_count then
    for output_channel = 1, output_channels do
      assignments[#assignments + 1] = {
        source_index = ((output_channel - 1) % source_count) + 1,
        dest_channel = output_channel - 1,
        gain = 1.0,
      }
    end
    return assignments
  end

  local counts_by_dest = {}
  for source_index = 1, source_count do
    local dest_channel = math.floor((source_index - 1) * output_channels / source_count)
    counts_by_dest[dest_channel] = (counts_by_dest[dest_channel] or 0) + 1
  end

  for source_index = 1, source_count do
    local dest_channel = math.floor((source_index - 1) * output_channels / source_count)
    assignments[#assignments + 1] = {
      source_index = source_index,
      dest_channel = dest_channel,
      gain = 1.0 / math.max(1, counts_by_dest[dest_channel] or 1),
    }
  end

  return assignments
end

local function routing_mode_label(source_count, output_channels)
  if output_channels > source_count then return "repeated source order" end
  if output_channels < source_count then return "adjacent grouped downmix" end
  return "one-to-one"
end

local function main()
  local tracks = get_selected_tracks()
  if #tracks == 0 then
    mc.show_error("Select one or more mono media tracks first.")
    return
  end

  for _, track in ipairs(tracks) do
    local channels = mc.get_track_media_channel_count(track)
    if channels ~= 1 then
      mc.show_error("This script expects tracks whose active takes play as mono. " ..
        mc.get_track_name(track) .. " appears to play " .. tostring(channels) .. " channels.")
      return
    end
  end

  local ok, input = reaper.GetUserInputs("Cyclic multichannel distribute", 1,
    "Output channels", tostring(#tracks))
  if not ok then return end

  local output_channels = tonumber(input)
  if not output_channels or output_channels ~= math.floor(output_channels) or output_channels < 2 then
    mc.show_error("Output channels must be a whole number of 2 or more.")
    return
  end

  if output_channels > mc.MAX_REAPER_TRACK_CHANNELS then
    mc.show_error("REAPER tracks support up to " .. tostring(mc.MAX_REAPER_TRACK_CHANNELS) .. " channels.")
    return
  end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local insert_index = get_insert_index_after_tracks(tracks)
  local bounds_start, bounds_end = mc.track_items_bounds(tracks)
  local bounds_length = bounds_end - bounds_start
  local bus = mc.insert_track_at(insert_index,
    "Cyclic distribute (" .. tostring(output_channels) .. "ch)",
    mc.reaper_track_channel_count(output_channels))

  local assignments = build_assignments(#tracks, output_channels)
  for _, assignment in ipairs(assignments) do
    local track = tracks[assignment.source_index]
    local send_index = mc.create_postfx_send(track, bus, 1, assignment.dest_channel)
    reaper.SetTrackSendInfo_Value(track, 0, send_index, "D_VOL", assignment.gain)
  end

  mc.select_only_track(bus)
  local saved_time_selection = mc.save_time_selection()
  local saved_render_bounds = mc.save_render_bounds()
  if bounds_length > 0 then
    mc.set_time_selection(bounds_start, bounds_end)
    mc.set_render_bounds_to_time_selection(bounds_start, bounds_end)
  end
  local before_guids = mc.snapshot_track_guids()
  local track_count_before_render = reaper.CountTracks(mc.PROJECT)
  reaper.Main_OnCommand(mc.render_multichannel_post_fader_stem_command(), 0)
  mc.restore_render_bounds(saved_render_bounds)
  mc.restore_time_selection(saved_time_selection)
  local did_render = reaper.CountTracks(mc.PROJECT) > track_count_before_render
  local rendered_track = nil

  if did_render then
    local excluded_tracks = { bus }
    for _, track in ipairs(tracks) do excluded_tracks[#excluded_tracks + 1] = track end
    rendered_track = mc.find_new_track(before_guids) or mc.get_selected_track_excluding(excluded_tracks)
    if rendered_track then
      reaper.GetSetMediaTrackInfo_String(rendered_track, "P_NAME",
        "Cyclic distribute render (" .. tostring(output_channels) .. "ch)", true)
      reaper.SetMediaTrackInfo_Value(rendered_track, "I_NCHAN",
        mc.reaper_track_channel_count(output_channels))
      if bounds_length > 0 then
        mc.set_track_items_length(rendered_track, bounds_length)
        local rendered_start = mc.track_items_bounds({ rendered_track })
        mc.move_track_items_by(rendered_track, bounds_start - rendered_start)
      end
    end
  end

  if did_render and reaper.ValidatePtr2(mc.PROJECT, bus, "MediaTrack*") then
    reaper.DeleteTrack(bus)
  end

  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Distribute selected mono tracks cyclically to multichannel item", -1)

  reaper.ShowConsoleMsg("")
  if did_render then
    reaper.ShowConsoleMsg("Rendered " .. tostring(#tracks) .. " mono tracks cyclically into " ..
      tostring(output_channels) .. " channels (" ..
      routing_mode_label(#tracks, output_channels) .. ").\n")
  else
    reaper.ShowConsoleMsg("Built routing, but REAPER did not report a new rendered stem track.\n")
  end
end

main()
