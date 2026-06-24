-- @description Multichannel Texture Library
-- @browser hidden

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")

local T = { mc = mc }

function T.clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

function T.equal_slices(count, duration)
  local slices = {}
  local length = duration / count
  for index = 1, count do
    slices[index] = {
      source_start = (index - 1) * length,
      output_start = (index - 1) * length,
      length = length,
    }
  end
  return slices
end

local function add_take_marker_points(points, item, duration)
  if not item then return end
  local take = reaper.GetActiveTake(item)
  if not take then return end
  local marker_count = reaper.GetNumTakeMarkers(take) or 0
  if marker_count <= 0 then return end
  local start_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  if math.abs(playrate) < 0.000001 then playrate = 1 end

  for index = 0, marker_count - 1 do
    local source_position = reaper.GetTakeMarker(take, index, "", 0, 0)
    local item_relative = (source_position - start_offset) / playrate
    if item_relative > 0 and item_relative < duration then
      points[#points + 1] = item_relative
    end
  end
end

function T.marker_slices(item_position, duration, item)
  local item_end = item_position + duration
  local points = { 0 }
  local _, marker_count, region_count = reaper.CountProjectMarkers(0)
  for index = 0, marker_count + region_count - 1 do
    local ok, is_region, marker_position = reaper.EnumProjectMarkers3(0, index)
    if ok and not is_region and marker_position > item_position and marker_position < item_end then
      points[#points + 1] = marker_position - item_position
    end
  end
  add_take_marker_points(points, item, duration)
  points[#points + 1] = duration
  table.sort(points)

  local slices = {}
  local output_start = 0
  for index = 1, #points - 1 do
    local length = points[index + 1] - points[index]
    if length > 0 then
      slices[#slices + 1] = {
        source_start = points[index],
        output_start = output_start,
        length = length,
      }
      output_start = output_start + length
    end
  end
  return slices
end

function T.channel_walk(index, output_channels, mode)
  if mode == 2 then
    local period = math.max(1, (output_channels - 1) * 2)
    local phase = (index - 1) % period
    if phase < output_channels then return phase + 1 end
    return period - phase + 1
  elseif mode == 3 then
    return math.random(output_channels)
  end
  return ((index - 1) % output_channels) + 1
end

function T.create_fragment(item, track, input_channel, source_start, output_start, length, fade, gain)
  local clone = mc.clone_item_to_track(item, track)
  if not clone then return nil end
  local take = reaper.GetActiveTake(clone)
  local source_take = reaper.GetActiveTake(item)
  local start_offset = reaper.GetMediaItemTakeInfo_Value(source_take, "D_STARTOFFS")
  local playrate = reaper.GetMediaItemTakeInfo_Value(source_take, "D_PLAYRATE")
  mc.set_take_to_mono_source_channel(take, input_channel)
  reaper.SetMediaItemInfo_Value(clone, "D_POSITION", output_start)
  reaper.SetMediaItemInfo_Value(clone, "D_LENGTH", length)
  reaper.SetMediaItemInfo_Value(clone, "D_FADEINLEN", math.min(fade or 0, length / 2))
  reaper.SetMediaItemInfo_Value(clone, "D_FADEOUTLEN", math.min(fade or 0, length / 2))
  reaper.SetMediaItemInfo_Value(clone, "D_VOL", gain or 1)
  reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", start_offset + source_start * playrate)
  return clone
end

function T.render_events(item, output_channels, events, label, options)
  options = options or {}
  if not events or #events == 0 then
    mc.show_error("No events were generated.")
    return false, nil
  end

  local source_track = reaper.GetMediaItemTrack(item)
  local insert_index = mc.get_insert_index_after_track(source_track)
  local source_position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local source_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local render_length = options.render_length or source_length
  local temp_tracks = {}
  local did_render = false

  reaper.Undo_BeginBlock()
  mc.with_ui_refresh_block(function()
    for channel = 1, output_channels do
      temp_tracks[channel] = mc.insert_track_at(insert_index + channel - 1,
        "tmp " .. label .. " ch " .. tostring(channel), 2)
      reaper.SetMediaTrackInfo_Value(temp_tracks[channel], "B_MAINSEND", 0)
    end

    for _, event in ipairs(events) do
      T.create_fragment(item, temp_tracks[event.output_channel], event.input_channel,
        event.source_start, event.output_start, event.length, event.fade, event.gain)
    end

    local bus = mc.insert_track_at(insert_index + output_channels,
      label .. " bus (" .. tostring(output_channels) .. "ch)",
      mc.reaper_track_channel_count(output_channels))
    for channel, temp_track in ipairs(temp_tracks) do
      mc.create_postfx_send(temp_track, bus, 1, channel - 1)
    end

    mc.select_only_track(bus)
    mc.with_render_bounds_for_range(0, render_length, function()
      local before_guids = mc.snapshot_track_guids()
      local before_count = reaper.CountTracks(mc.PROJECT)
      reaper.Main_OnCommand(mc.render_multichannel_post_fader_stem_command(), 0)
      did_render = reaper.CountTracks(mc.PROJECT) > before_count
      if did_render then
        local excluded_tracks = { bus }
        for _, temp_track in ipairs(temp_tracks) do excluded_tracks[#excluded_tracks + 1] = temp_track end
        local rendered_track = mc.find_new_track(before_guids) or mc.get_selected_track_excluding(excluded_tracks)
        if rendered_track then
          reaper.GetSetMediaTrackInfo_String(rendered_track, "P_NAME",
            label .. " render (" .. tostring(output_channels) .. "ch)", true)
          reaper.SetMediaTrackInfo_Value(rendered_track, "I_NCHAN", mc.reaper_track_channel_count(output_channels))
          mc.set_track_items_length(rendered_track, render_length)
          local rendered_start = mc.track_items_bounds({ rendered_track })
          mc.move_track_items_by(rendered_track, source_position - rendered_start)
          mc.select_only_track(rendered_track)
        end
      end
    end)

    if did_render then
      if options.mute_source_item then reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1) end
      if reaper.ValidatePtr2(mc.PROJECT, bus, "MediaTrack*") then reaper.DeleteTrack(bus) end
      for index = #temp_tracks, 1, -1 do
        if reaper.ValidatePtr2(mc.PROJECT, temp_tracks[index], "MediaTrack*") then
          reaper.DeleteTrack(temp_tracks[index])
        end
      end
    end
  end)
  reaper.Undo_EndBlock(label, -1)
  return did_render
end

return T
