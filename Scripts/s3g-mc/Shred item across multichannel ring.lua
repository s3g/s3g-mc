-- @description Shred item across multichannel ring
-- @author s3g
-- @version 0.1
-- @requires Multichannel Library.lua; REAPER multichannel stem render action
-- @category Item Channel Transforms
-- @render Yes; bounds to source item length.
-- @method Splits the item into fragments and scatters them across output channels.
-- @about
--   Splits the selected audio item into equal fragments, randomizes fragment
--   source order, scatters fragments across output channels, and renders a
--   multichannel stem item.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local MUTE_SOURCE_ITEM_AFTER_RENDER = true

local function shuffled_indices(count)
  local indices = {}
  for index = 1, count do indices[index] = index end
  for index = count, 2, -1 do
    local swap_index = math.random(index)
    indices[index], indices[swap_index] = indices[swap_index], indices[index]
  end
  return indices
end

local function main()
  local item, take, source_channels = mc.get_selected_audio_item()
  if not item then return end

  local defaults = "16,8,1,0.005"
  local ok, input = reaper.GetUserInputs("Shred item across ring", 4,
    "Fragments,Output channels,Source channel,Fade seconds", defaults)
  if not ok then return end

  local fragment_count_text, output_channels_text, source_channel_text, fade_text =
    input:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")

  local fragment_count = tonumber(fragment_count_text)
  local output_channels = tonumber(output_channels_text)
  local source_channel = tonumber(source_channel_text)
  local fade_seconds = tonumber(fade_text)

  if not fragment_count or fragment_count ~= math.floor(fragment_count) or fragment_count < 2 then
    mc.show_error("Fragments must be a whole number of 2 or more.")
    return
  end
  if not output_channels or output_channels ~= math.floor(output_channels) or output_channels < 2 then
    mc.show_error("Output channels must be a whole number of 2 or more.")
    return
  end
  if output_channels > mc.MAX_REAPER_TRACK_CHANNELS then
    mc.show_error("REAPER tracks support up to " .. tostring(mc.MAX_REAPER_TRACK_CHANNELS) .. " channels.")
    return
  end
  if not source_channel or source_channel ~= math.floor(source_channel) or
    source_channel < 1 or source_channel > source_channels then
    mc.show_error("Source channel must be between 1 and " .. tostring(source_channels) .. ".")
    return
  end
  if not fade_seconds or fade_seconds < 0 then
    mc.show_error("Fade seconds must be zero or greater.")
    return
  end

  math.randomseed(os.time())

  local source_track = reaper.GetMediaItemTrack(item)
  local insert_index = mc.get_insert_index_after_track(source_track)
  local temp_tracks = {}
  local source_position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local source_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local source_start_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  local source_playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  local fragment_length = source_length / fragment_count
  local order = shuffled_indices(fragment_count)

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  for channel = 1, output_channels do
    temp_tracks[channel] = mc.insert_track_at(insert_index + channel - 1,
      "tmp shred ch " .. tostring(channel), 2)
    reaper.SetMediaTrackInfo_Value(temp_tracks[channel], "B_MAINSEND", 0)
  end

  for output_index = 1, fragment_count do
    local source_index = order[output_index]
    local output_channel = math.random(output_channels)
    local clone = mc.clone_item_to_track(item, temp_tracks[output_channel])
    if clone then
      local clone_take = reaper.GetActiveTake(clone)
      mc.set_take_to_mono_source_channel(clone_take, source_channel)
      reaper.SetMediaItemInfo_Value(clone, "D_POSITION",
        (output_index - 1) * fragment_length)
      reaper.SetMediaItemInfo_Value(clone, "D_LENGTH", fragment_length)
      reaper.SetMediaItemInfo_Value(clone, "D_FADEINLEN", math.min(fade_seconds, fragment_length / 2))
      reaper.SetMediaItemInfo_Value(clone, "D_FADEOUTLEN", math.min(fade_seconds, fragment_length / 2))
      reaper.SetMediaItemTakeInfo_Value(clone_take, "D_STARTOFFS",
        source_start_offset + ((source_index - 1) * fragment_length * source_playrate))
    end
  end

  local bus = mc.insert_track_at(insert_index + output_channels,
    "Shredded ring (" .. tostring(output_channels) .. "ch)",
    mc.reaper_track_channel_count(output_channels))

  for channel, temp_track in ipairs(temp_tracks) do
    mc.create_postfx_send(temp_track, bus, 1, channel - 1)
  end

  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  mc.select_only_track(bus)
  local saved_time_selection = mc.save_time_selection()
  local saved_render_bounds = mc.save_render_bounds()
  mc.set_time_selection(0, source_length)
  mc.set_render_bounds_to_time_selection(0, source_length)
  local before_guids = mc.snapshot_track_guids()
  local track_count_before_render = reaper.CountTracks(mc.PROJECT)
  reaper.Main_OnCommand(mc.render_multichannel_post_fader_stem_command(), 0)
  mc.restore_render_bounds(saved_render_bounds)
  mc.restore_time_selection(saved_time_selection)
  local did_render = reaper.CountTracks(mc.PROJECT) > track_count_before_render
  local rendered_track = nil

  if did_render then
    local excluded_tracks = {}
    for _, temp_track in ipairs(temp_tracks) do
      excluded_tracks[#excluded_tracks + 1] = temp_track
    end
    excluded_tracks[#excluded_tracks + 1] = bus
    rendered_track = mc.find_new_track(before_guids) or mc.get_selected_track_excluding(excluded_tracks)
    if rendered_track then
      reaper.GetSetMediaTrackInfo_String(rendered_track, "P_NAME",
        "Shredded ring render (" .. tostring(output_channels) .. "ch)", true)
      reaper.SetMediaTrackInfo_Value(rendered_track, "I_NCHAN",
        mc.reaper_track_channel_count(output_channels))
      mc.set_track_items_length(rendered_track, source_length)
      local rendered_start = mc.track_items_bounds({ rendered_track })
      mc.move_track_items_by(rendered_track, source_position - rendered_start)
    end
    if MUTE_SOURCE_ITEM_AFTER_RENDER then
      reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
    end
    if reaper.ValidatePtr2(mc.PROJECT, bus, "MediaTrack*") then
      reaper.DeleteTrack(bus)
    end
    for index = #temp_tracks, 1, -1 do
      if reaper.ValidatePtr2(mc.PROJECT, temp_tracks[index], "MediaTrack*") then
        reaper.DeleteTrack(temp_tracks[index])
      end
    end
    if rendered_track and reaper.ValidatePtr2(mc.PROJECT, rendered_track, "MediaTrack*") then
      mc.select_only_track(rendered_track)
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Shred selected item across multichannel ring", -1)

  reaper.ShowConsoleMsg("")
  if did_render then
    reaper.ShowConsoleMsg("Rendered " .. tostring(fragment_count) .. " shuffled fragments across " ..
      tostring(output_channels) .. " channels.\n")
    if MUTE_SOURCE_ITEM_AFTER_RENDER then
      reaper.ShowConsoleMsg("Muted the original source item so the rendered result is audible by itself.\n")
    end
  else
    reaper.ShowConsoleMsg("Built shred routing, but REAPER did not report a new rendered stem track.\n")
  end
end

main()
