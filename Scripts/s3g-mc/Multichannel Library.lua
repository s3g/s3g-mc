-- @description Multichannel Library
-- @browser hidden

local M = {}
local unpack_values = table.unpack or unpack

M.PROJECT = 0
M.MAX_REAPER_TRACK_CHANNELS = 128
M.RENDER_MULTICHANNEL_POST_FADER_STEM_NAME =
  "Track: Render selected area of tracks to multichannel post-fader stem tracks (and mute originals)"
M.RENDER_MULTICHANNEL_POST_FADER_STEM_FALLBACK_COMMAND = 40900
M.RENDER_MONO_STEM_COMMAND = 40789
M.SEND_MODE_POST_FX = 3

function M.show_error(message)
  reaper.MB(message, "Multichannel Tools", 0)
end

function M.find_main_action_by_exact_name(name)
  if not reaper.kbd_getTextFromCmd then return nil end
  for command_id = 40000, 50000 do
    local text = reaper.kbd_getTextFromCmd(command_id, 0)
    if text == name then return command_id end
  end
  return nil
end

function M.render_multichannel_post_fader_stem_command()
  return M.find_main_action_by_exact_name(M.RENDER_MULTICHANNEL_POST_FADER_STEM_NAME) or
    M.RENDER_MULTICHANNEL_POST_FADER_STEM_FALLBACK_COMMAND
end

function M.get_script_dir()
  local source = debug.getinfo(2, "S").source
  local path = source:match("^@(.+)$") or ""
  return path:match("^(.*[/\\])") or ""
end

function M.get_track_name(track)
  local ok, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  if ok and name ~= "" then return name end
  local index = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
  return "Track " .. tostring(index)
end

function M.get_take_source_channels(take)
  if not take or reaper.TakeIsMIDI(take) then return nil end
  local source = reaper.GetMediaItemTake_Source(take)
  if not source then return nil end
  return reaper.GetMediaSourceNumChannels(source)
end

function M.get_take_playback_channel_count(take)
  local source_channels = M.get_take_source_channels(take)
  if not source_channels then return nil end

  -- I_CHANMODE >= 2 means the take is playing as mono: downmix or one source channel.
  local channel_mode = math.floor(reaper.GetMediaItemTakeInfo_Value(take, "I_CHANMODE") or 0)
  if channel_mode >= 2 then return 1 end

  return source_channels
end

function M.get_track_media_channel_count(track)
  local max_channels = 0
  local item_count = reaper.CountTrackMediaItems(track)

  for item_index = 0, item_count - 1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    local take = reaper.GetActiveTake(item)
    local channels = M.get_take_playback_channel_count(take)
    if channels and channels > max_channels then
      max_channels = channels
    end
  end

  if max_channels > 0 then return max_channels end
  return math.max(1, math.floor(reaper.GetMediaTrackInfo_Value(track, "I_NCHAN")))
end

function M.get_selected_audio_item()
  local item = reaper.GetSelectedMediaItem(M.PROJECT, 0)
  if not item then
    M.show_error("Select one audio item first.")
    return nil
  end

  local take = reaper.GetActiveTake(item)
  local channels = M.get_take_source_channels(take)
  if not channels or channels < 1 then
    M.show_error("The selected item needs an active non-MIDI take.")
    return nil
  end

  return item, take, channels
end

function M.select_only_track(track)
  reaper.Main_OnCommand(40297, 0) -- Track: Unselect all tracks
  reaper.SetTrackSelected(track, true)
end

function M.select_only_item(item)
  reaper.Main_OnCommand(40289, 0) -- Item: Unselect all items
  reaper.SetMediaItemSelected(item, true)
end

function M.save_selected_tracks()
  local tracks = {}
  for index = 0, reaper.CountSelectedTracks(M.PROJECT) - 1 do
    tracks[#tracks + 1] = reaper.GetSelectedTrack(M.PROJECT, index)
  end
  return tracks
end

function M.restore_selected_tracks(tracks)
  reaper.Main_OnCommand(40297, 0) -- Track: Unselect all tracks
  for _, track in ipairs(tracks or {}) do
    if reaper.ValidatePtr2(M.PROJECT, track, "MediaTrack*") then
      reaper.SetTrackSelected(track, true)
    end
  end
end

function M.save_selected_items()
  local items = {}
  for index = 0, reaper.CountSelectedMediaItems(M.PROJECT) - 1 do
    items[#items + 1] = reaper.GetSelectedMediaItem(M.PROJECT, index)
  end
  return items
end

function M.restore_selected_items(items)
  reaper.Main_OnCommand(40289, 0) -- Item: Unselect all items
  for _, item in ipairs(items or {}) do
    if reaper.ValidatePtr2(M.PROJECT, item, "MediaItem*") then
      reaper.SetMediaItemSelected(item, true)
    end
  end
end

function M.move_track_items_by(track, offset)
  if not track or offset == 0 then return end
  for item_index = 0, reaper.CountTrackMediaItems(track) - 1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", position + offset)
  end
end

function M.set_track_items_length(track, length)
  if not track or not length or length <= 0 then return end
  for item_index = 0, reaper.CountTrackMediaItems(track) - 1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", length)
  end
end

function M.item_end_position(item)
  return reaper.GetMediaItemInfo_Value(item, "D_POSITION") +
    reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
end

function M.track_items_bounds(tracks)
  local start_position = nil
  local end_position = nil
  for _, track in ipairs(tracks or {}) do
    if track then
      for item_index = 0, reaper.CountTrackMediaItems(track) - 1 do
        local item = reaper.GetTrackMediaItem(track, item_index)
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = M.item_end_position(item)
        start_position = start_position and math.min(start_position, item_start) or item_start
        end_position = end_position and math.max(end_position, item_end) or item_end
      end
    end
  end
  return start_position or 0, end_position or 0
end

function M.save_time_selection()
  local start_pos, end_pos = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  return { start_pos = start_pos, end_pos = end_pos }
end

function M.set_time_selection(start_pos, end_pos)
  reaper.GetSet_LoopTimeRange(true, false, start_pos, math.max(start_pos, end_pos), false)
end

function M.restore_time_selection(saved)
  if not saved then return end
  reaper.GetSet_LoopTimeRange(true, false, saved.start_pos or 0, saved.end_pos or 0, false)
end

function M.save_render_bounds()
  return {
    flag = reaper.GetSetProjectInfo(M.PROJECT, "RENDER_BOUNDSFLAG", 0, false),
    start_pos = reaper.GetSetProjectInfo(M.PROJECT, "RENDER_STARTPOS", 0, false),
    end_pos = reaper.GetSetProjectInfo(M.PROJECT, "RENDER_ENDPOS", 0, false),
  }
end

function M.set_render_bounds_to_time_selection(start_pos, end_pos)
  reaper.GetSetProjectInfo(M.PROJECT, "RENDER_BOUNDSFLAG", 2, true)
  reaper.GetSetProjectInfo(M.PROJECT, "RENDER_STARTPOS", start_pos, true)
  reaper.GetSetProjectInfo(M.PROJECT, "RENDER_ENDPOS", math.max(start_pos, end_pos), true)
end

function M.restore_render_bounds(saved)
  if not saved then return end
  reaper.GetSetProjectInfo(M.PROJECT, "RENDER_BOUNDSFLAG", saved.flag or 0, true)
  reaper.GetSetProjectInfo(M.PROJECT, "RENDER_STARTPOS", saved.start_pos or 0, true)
  reaper.GetSetProjectInfo(M.PROJECT, "RENDER_ENDPOS", saved.end_pos or 0, true)
end

function M.with_ui_refresh_block(fn)
  reaper.PreventUIRefresh(1)
  local results = { pcall(fn) }
  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  if not results[1] then error(results[2]) end
  return unpack_values(results, 2)
end

function M.with_preserved_selection(fn)
  local tracks = M.save_selected_tracks()
  local items = M.save_selected_items()
  local results = { pcall(fn) }
  M.restore_selected_tracks(tracks)
  M.restore_selected_items(items)
  if not results[1] then error(results[2]) end
  return unpack_values(results, 2)
end

function M.with_render_bounds_for_range(start_pos, end_pos, fn)
  local saved_time_selection = M.save_time_selection()
  local saved_render_bounds = M.save_render_bounds()
  M.set_time_selection(start_pos, end_pos)
  M.set_render_bounds_to_time_selection(start_pos, end_pos)
  local results = { pcall(fn) }
  M.restore_render_bounds(saved_render_bounds)
  M.restore_time_selection(saved_time_selection)
  if not results[1] then error(results[2]) end
  return unpack_values(results, 2)
end

function M.with_render_bounds_for_item(item, fn)
  local start_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local end_pos = M.item_end_position(item)
  return M.with_render_bounds_for_range(start_pos, end_pos, fn)
end

function M.clone_item_to_track(item, track)
  local ok, chunk = reaper.GetItemStateChunk(item, "", false)
  if not ok then return nil end

  local clone = reaper.AddMediaItemToTrack(track)
  if not clone then return nil end

  reaper.SetItemStateChunk(clone, chunk, false)
  return clone
end

function M.set_take_to_mono_source_channel(take, channel)
  -- I_CHANMODE: 3 = mono source channel 1, 4 = mono source channel 2, etc.
  reaper.SetMediaItemTakeInfo_Value(take, "I_CHANMODE", channel + 2)
end

function M.duplicate_item_as_mono_channel(item, track, channel)
  local clone = M.clone_item_to_track(item, track)
  if not clone then return nil end
  local take = reaper.GetActiveTake(clone)
  M.set_take_to_mono_source_channel(take, channel)
  return clone
end

function M.create_mono_channel_track_from_item(item, channel, insert_index, name)
  local source_track = reaper.GetMediaItemTrack(item)
  insert_index = insert_index or M.get_insert_index_after_track(source_track)
  name = name or (M.get_track_name(source_track) .. " ch " .. tostring(channel))
  local track = M.insert_track_at(insert_index, name, 2)
  local clone = M.duplicate_item_as_mono_channel(item, track, channel)
  return track, clone
end

function M.insert_track_at(index, name, channel_count)
  reaper.InsertTrackAtIndex(index, true)
  local track = reaper.GetTrack(M.PROJECT, index)
  if name then
    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
  end
  if channel_count then
    reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", channel_count)
  end
  return track
end

function M.reaper_track_channel_count(channel_count)
  if channel_count <= 1 then return 2 end
  return channel_count + (channel_count % 2)
end

function M.get_insert_index_after_track(track)
  return math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
end

function M.source_channel_flag(channel_count)
  if channel_count == 1 then return 1024 end
  return math.floor((channel_count + 1) / 2) * 1024
end

function M.destination_channel_flag(channel_offset, channel_count)
  if channel_count == 1 then return channel_offset + 1024 end
  return channel_offset
end

function M.create_postfx_send(src_track, dest_track, src_channel_count, dest_channel_offset)
  local send_index = reaper.CreateTrackSend(src_track, dest_track)
  reaper.SetTrackSendInfo_Value(src_track, 0, send_index, "I_SENDMODE", M.SEND_MODE_POST_FX)
  reaper.SetTrackSendInfo_Value(src_track, 0, send_index, "D_VOL", 1.0)
  reaper.SetTrackSendInfo_Value(src_track, 0, send_index, "I_SRCCHAN", M.source_channel_flag(src_channel_count))
  reaper.SetTrackSendInfo_Value(src_track, 0, send_index, "I_DSTCHAN", M.destination_channel_flag(dest_channel_offset, src_channel_count))
  return send_index
end

function M.track_is_in_list(track, tracks)
  for _, list_track in ipairs(tracks) do
    if track == list_track then return true end
  end
  return false
end

function M.get_selected_track_excluding(excluded_tracks)
  for index = 0, reaper.CountSelectedTracks(M.PROJECT) - 1 do
    local track = reaper.GetSelectedTrack(M.PROJECT, index)
    if not M.track_is_in_list(track, excluded_tracks) then
      return track
    end
  end
  return nil
end

function M.snapshot_track_guids()
  local guids = {}
  for index = 0, reaper.CountTracks(M.PROJECT) - 1 do
    local track = reaper.GetTrack(M.PROJECT, index)
    guids[reaper.GetTrackGUID(track)] = true
  end
  return guids
end

function M.find_new_track(before_guids)
  for index = 0, reaper.CountTracks(M.PROJECT) - 1 do
    local track = reaper.GetTrack(M.PROJECT, index)
    if not before_guids[reaper.GetTrackGUID(track)] then return track end
  end
  return nil
end

function M.parse_channel_map(text, channel_count, require_unique)
  local map = {}
  local used = {}

  for token in text:gmatch("%S+") do
    local channel = tonumber(token)
    if not channel or channel ~= math.floor(channel) then
      return nil, "Channel map must contain only whole numbers."
    end
    if channel < 1 or channel > channel_count then
      return nil, "Channel " .. tostring(channel) .. " is outside 1-" .. tostring(channel_count) .. "."
    end
    if require_unique and used[channel] then
      return nil, "Channel " .. tostring(channel) .. " appears more than once."
    end
    used[channel] = true
    map[#map + 1] = channel
  end

  if #map ~= channel_count then
    return nil, "Expected " .. tostring(channel_count) .. " channels, got " .. tostring(#map) .. "."
  end

  return map
end

function M.validate_channel_count(channel_count, label, minimum, maximum)
  label = label or "Channel count"
  minimum = minimum or 1
  maximum = maximum or M.MAX_REAPER_TRACK_CHANNELS
  channel_count = tonumber(channel_count)
  if not channel_count or channel_count ~= math.floor(channel_count) then
    return nil, label .. " must be a whole number."
  end
  if channel_count < minimum or channel_count > maximum then
    return nil, label .. " must be in the range " .. tostring(minimum) .. "-" .. tostring(maximum) .. "."
  end
  return channel_count
end

function M.validate_even_reaper_channel_count(channel_count, label)
  local count, err = M.validate_channel_count(channel_count, label or "Track channel count", 2, M.MAX_REAPER_TRACK_CHANNELS)
  if not count then return nil, err end
  if count % 2 ~= 0 then
    return nil, (label or "Track channel count") .. " must be even for REAPER multichannel tracks."
  end
  return count
end

function M.require_selected_audio_item(min_channels)
  local item, take, channels = M.get_selected_audio_item()
  if not item then return nil end
  min_channels = min_channels or 1
  if channels < min_channels then
    M.show_error("The selected item needs at least " .. tostring(min_channels) .. " source channels.")
    return nil
  end
  return item, take, channels
end

function M.require_selected_multichannel_item()
  return M.require_selected_audio_item(2)
end

function M.require_selected_tracks()
  local tracks = {}
  for index = 0, reaper.CountSelectedTracks(M.PROJECT) - 1 do
    tracks[#tracks + 1] = reaper.GetSelectedTrack(M.PROJECT, index)
  end
  if #tracks == 0 then
    M.show_error("Select one or more tracks first.")
    return nil
  end
  return tracks
end

function M.require_selected_mono_compatible_tracks()
  local tracks = M.require_selected_tracks()
  if not tracks then return nil end
  for _, track in ipairs(tracks) do
    local channels = M.get_track_media_channel_count(track)
    if channels ~= 1 then
      M.show_error("Selected track '" .. M.get_track_name(track) .. "' is " .. tostring(channels) ..
        " channel; this operation expects mono-compatible tracks.")
      return nil
    end
  end
  return tracks
end

function M.identity_map(channel_count)
  local map = {}
  for channel = 1, channel_count do map[channel] = channel end
  return map
end

function M.rotate_map(channel_count, offset)
  local map = {}
  for output_channel = 1, channel_count do
    map[output_channel] = ((output_channel - 1 - offset) % channel_count) + 1
  end
  return map
end

function M.mirror_map(channel_count)
  local map = {}
  for output_channel = 1, channel_count do
    map[output_channel] = channel_count - output_channel + 1
  end
  return map
end

function M.odd_even_map(channel_count)
  local map = {}
  for channel = 1, channel_count, 2 do map[#map + 1] = channel end
  for channel = 2, channel_count, 2 do map[#map + 1] = channel end
  return map
end

function M.deinterleave_pairs_map(channel_count)
  return M.odd_even_map(channel_count)
end

function M.interleave_pairs_map(channel_count)
  local map = {}
  local left_count = math.ceil(channel_count / 2)
  for index = 1, left_count do
    map[#map + 1] = index
    local paired = index + left_count
    if paired <= channel_count then map[#map + 1] = paired end
  end
  return map
end

function M.swap_halves_map(channel_count)
  local map = {}
  local split = math.floor(channel_count / 2)
  for channel = split + 1, channel_count do map[#map + 1] = channel end
  for channel = 1, split do map[#map + 1] = channel end
  return map
end

function M.split_halves_map(channel_count)
  return M.swap_halves_map(channel_count)
end

function M.repeat_sources_map(source_count, output_count)
  local map = {}
  if source_count < 1 then return map end
  for output_channel = 1, output_count do
    map[output_channel] = ((output_channel - 1) % source_count) + 1
  end
  return map
end

function M.grouped_downmix_plan(source_count, output_count)
  local plan = {}
  if source_count < 1 or output_count < 1 then return plan end
  for output_channel = 1, output_count do
    plan[output_channel] = { inputs = {}, gain = 1 }
  end
  for source_channel = 1, source_count do
    local output_channel = math.floor((source_channel - 1) * output_count / source_count) + 1
    plan[output_channel].inputs[#plan[output_channel].inputs + 1] = source_channel
  end
  for _, group in ipairs(plan) do
    group.gain = #group.inputs > 0 and (1 / #group.inputs) or 1
  end
  return plan
end

function M.adjacent_pair_downmix_map(source_count, output_count)
  return M.grouped_downmix_plan(source_count, output_count)
end

function M.adjacent_pair_downmix_plan(source_count, output_count)
  return M.grouped_downmix_plan(source_count, output_count)
end

function M.format_channel_map(map)
  local parts = {}
  for output_channel, input_channel in ipairs(map or {}) do
    parts[#parts + 1] = tostring(output_channel) .. "<-" .. tostring(input_channel)
  end
  return table.concat(parts, " ")
end

function M.channel_range_label(start_channel, channel_count)
  if channel_count <= 1 then return tostring(start_channel) end
  return tostring(start_channel) .. "-" .. tostring(start_channel + channel_count - 1)
end

function M.describe_map(map)
  if not map or #map == 0 then return "empty map" end
  local identity = true
  local mirror = true
  for index, value in ipairs(map) do
    if value ~= index then identity = false end
    if value ~= (#map - index + 1) then mirror = false end
  end
  if identity then return "identity " .. tostring(#map) .. "ch" end
  if mirror then return "mirror " .. tostring(#map) .. "ch" end
  return "custom " .. tostring(#map) .. "ch: " .. M.format_channel_map(map)
end

function M.describe_downmix_plan(plan)
  local parts = {}
  for output_channel, group in ipairs(plan or {}) do
    parts[#parts + 1] = tostring(output_channel) .. "<-" .. table.concat(group.inputs or {}, "+") ..
      " @ " .. string.format("%.3f", group.gain or 1)
  end
  return table.concat(parts, " ")
end

function M.console_header(title)
  reaper.ShowConsoleMsg("\n[" .. tostring(title or "s3g-mc") .. "]\n")
end

function M.print_plan(title, lines)
  M.console_header(title)
  for _, line in ipairs(lines or {}) do
    reaper.ShowConsoleMsg(tostring(line) .. "\n")
  end
end

function M.item_label(item)
  local take = item and reaper.GetActiveTake(item)
  if take then
    local name = reaper.GetTakeName(take)
    if name and name ~= "" then return name end
  end
  return "(unnamed item)"
end

function M.render_plan_for_item(item, source_channel_count, channel_map, label)
  local start_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  return {
    "Item: " .. M.item_label(item),
    "Source channels: " .. tostring(source_channel_count),
    "Output channels: " .. tostring(#channel_map),
    "Map: " .. M.describe_map(channel_map),
    "Render bounds: " .. string.format("%.3f to %.3f sec", start_pos, start_pos + length),
    "Output label: " .. tostring(label or "multichannel render"),
  }
end

function M.build_multichannel_render_from_item(item, source_channel_count, channel_map, label, options)
  options = options or {}

  if source_channel_count > M.MAX_REAPER_TRACK_CHANNELS then
    M.show_error("REAPER tracks support up to " .. tostring(M.MAX_REAPER_TRACK_CHANNELS) .. " channels.")
    return false, nil
  end

  local source_track = reaper.GetMediaItemTrack(item)
  local insert_index = M.get_insert_index_after_track(source_track)
  local source_position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local source_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local temp_tracks = {}

  for output_channel = 1, #channel_map do
    local input_channel = channel_map[output_channel]
    local temp_track = M.insert_track_at(insert_index + output_channel - 1,
      "tmp " .. label .. " ch " .. tostring(output_channel) ..
      " <- " .. tostring(input_channel), 2)
    reaper.SetMediaTrackInfo_Value(temp_track, "B_MAINSEND", 0)
    local clone = M.clone_item_to_track(item, temp_track)
    if not clone then return false, nil end
    reaper.SetMediaItemInfo_Value(clone, "D_POSITION", 0)
    local clone_take = reaper.GetActiveTake(clone)
    M.set_take_to_mono_source_channel(clone_take, input_channel)
    temp_tracks[#temp_tracks + 1] = temp_track
  end

  local bus_index = insert_index + #temp_tracks
  local bus = M.insert_track_at(bus_index, label .. " (" .. tostring(#channel_map) .. "ch)",
    M.reaper_track_channel_count(#channel_map))

  for output_channel, temp_track in ipairs(temp_tracks) do
    M.create_postfx_send(temp_track, bus, 1, output_channel - 1)
  end

  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  M.select_only_track(bus)
  local saved_time_selection = M.save_time_selection()
  local saved_render_bounds = M.save_render_bounds()
  M.set_time_selection(0, source_length)
  M.set_render_bounds_to_time_selection(0, source_length)
  local before_guids = M.snapshot_track_guids()
  local track_count_before_render = reaper.CountTracks(M.PROJECT)
  local render_command = M.render_multichannel_post_fader_stem_command()
  reaper.Main_OnCommand(render_command, 0)
  M.restore_render_bounds(saved_render_bounds)
  M.restore_time_selection(saved_time_selection)
  local track_count_after_render = reaper.CountTracks(M.PROJECT)
  local did_render = track_count_after_render > track_count_before_render
  local rendered_track = nil

  if did_render then
    local excluded_tracks = {}
    for _, temp_track in ipairs(temp_tracks) do
      excluded_tracks[#excluded_tracks + 1] = temp_track
    end
    excluded_tracks[#excluded_tracks + 1] = bus
    rendered_track = M.find_new_track(before_guids) or M.get_selected_track_excluding(excluded_tracks)

    if rendered_track then
      reaper.GetSetMediaTrackInfo_String(rendered_track, "P_NAME",
        label .. " render (" .. tostring(#channel_map) .. "ch)", true)
      reaper.SetMediaTrackInfo_Value(rendered_track, "I_NCHAN",
        M.reaper_track_channel_count(#channel_map))
      M.set_track_items_length(rendered_track, source_length)
      local rendered_start = M.track_items_bounds({ rendered_track })
      M.move_track_items_by(rendered_track, source_position - rendered_start)
    end

    if options.mute_source_item then
      reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
    end

    if reaper.ValidatePtr2(M.PROJECT, bus, "MediaTrack*") then
      reaper.DeleteTrack(bus)
    end
    for index = #temp_tracks, 1, -1 do
      local track = temp_tracks[index]
      if reaper.ValidatePtr2(M.PROJECT, track, "MediaTrack*") then
        reaper.DeleteTrack(track)
      end
    end

    if rendered_track and reaper.ValidatePtr2(M.PROJECT, rendered_track, "MediaTrack*") then
      M.select_only_track(rendered_track)
    end
  end

  return did_render, rendered_track
end

function M.build_multichannel_mix_render_from_item(item, source_channel_count, output_mixes, label, options)
  options = options or {}

  if source_channel_count > M.MAX_REAPER_TRACK_CHANNELS or #output_mixes > M.MAX_REAPER_TRACK_CHANNELS then
    M.show_error("REAPER tracks support up to " .. tostring(M.MAX_REAPER_TRACK_CHANNELS) .. " channels.")
    return false, nil
  end

  local source_track = reaper.GetMediaItemTrack(item)
  local insert_index = M.get_insert_index_after_track(source_track)
  local source_position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local source_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local temp_tracks = {}

  for output_channel, mix in ipairs(output_mixes) do
    for _, input_channel in ipairs(mix.inputs or {}) do
      local temp_track = M.insert_track_at(insert_index + #temp_tracks,
        "tmp " .. label .. " out " .. tostring(output_channel) ..
        " <- " .. tostring(input_channel), 2)
      reaper.SetMediaTrackInfo_Value(temp_track, "B_MAINSEND", 0)
      local clone = M.clone_item_to_track(item, temp_track)
      if not clone then return false, nil end
      reaper.SetMediaItemInfo_Value(clone, "D_POSITION", 0)
      local clone_take = reaper.GetActiveTake(clone)
      M.set_take_to_mono_source_channel(clone_take, input_channel)
      temp_tracks[#temp_tracks + 1] = {
        track = temp_track,
        output_channel = output_channel,
        gain = mix.gain or 1,
      }
    end
  end

  local bus = M.insert_track_at(insert_index + #temp_tracks,
    label .. " (" .. tostring(#output_mixes) .. "ch)",
    M.reaper_track_channel_count(#output_mixes))

  for _, entry in ipairs(temp_tracks) do
    local send_index = M.create_postfx_send(entry.track, bus, 1, entry.output_channel - 1)
    reaper.SetTrackSendInfo_Value(entry.track, 0, send_index, "D_VOL", entry.gain)
  end

  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  M.select_only_track(bus)

  local before_guids
  local track_count_before_render
  M.with_render_bounds_for_range(0, source_length, function()
    before_guids = M.snapshot_track_guids()
    track_count_before_render = reaper.CountTracks(M.PROJECT)
    reaper.Main_OnCommand(M.render_multichannel_post_fader_stem_command(), 0)
  end)

  local did_render = reaper.CountTracks(M.PROJECT) > track_count_before_render
  local rendered_track = nil

  if did_render then
    local excluded_tracks = { bus }
    for _, entry in ipairs(temp_tracks) do excluded_tracks[#excluded_tracks + 1] = entry.track end
    rendered_track = M.find_new_track(before_guids) or M.get_selected_track_excluding(excluded_tracks)

    if rendered_track then
      reaper.GetSetMediaTrackInfo_String(rendered_track, "P_NAME",
        label .. " render (" .. tostring(#output_mixes) .. "ch)", true)
      reaper.SetMediaTrackInfo_Value(rendered_track, "I_NCHAN",
        M.reaper_track_channel_count(#output_mixes))
      M.set_track_items_length(rendered_track, source_length)
      local rendered_start = M.track_items_bounds({ rendered_track })
      M.move_track_items_by(rendered_track, source_position - rendered_start)
    end

    if options.mute_source_item then
      reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
    end

    if reaper.ValidatePtr2(M.PROJECT, bus, "MediaTrack*") then
      reaper.DeleteTrack(bus)
    end
    for index = #temp_tracks, 1, -1 do
      local track = temp_tracks[index].track
      if reaper.ValidatePtr2(M.PROJECT, track, "MediaTrack*") then
        reaper.DeleteTrack(track)
      end
    end

    if rendered_track and reaper.ValidatePtr2(M.PROJECT, rendered_track, "MediaTrack*") then
      M.select_only_track(rendered_track)
    end
  end

  return did_render, rendered_track
end

return M
