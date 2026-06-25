-- @description Shred / Slice
-- @author s3g
-- @version 0.3
-- @requires ReaImGui; Multichannel Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; bounds to source item length.
-- @method Slices the selected item by equal divisions, project markers, or active-take markers, then spreads mono slices or reorients multichannel slices across the output channels.
-- @about
--   Builds a new multichannel render from the selected item. Ordered mono
--   spread keeps slices in time order and cycles them evenly through the
--   output channels. Random mono scatter produces independent mono fragments
--   across the output field. Multichannel rotate modes keep the source frame
--   together but rotate the channel image per slice.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local MUTE_SOURCE_ITEM_AFTER_RENDER = true

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Shred / Slice", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local SLICE_EQUAL = 1
local SLICE_MARKERS = 2

local MODE_ORDERED_MONO = 1
local MODE_RANDOM_MONO = 2
local MODE_ORDERED_ROTATE = 3
local MODE_RANDOM_ROTATE = 4

local SLICE_MODE_NAMES = {
  [SLICE_EQUAL] = "Equal divisions",
  [SLICE_MARKERS] = "Markers",
}

local MOTION_MODE_NAMES = {
  [MODE_ORDERED_MONO] = "Ordered mono spread",
  [MODE_RANDOM_MONO] = "Random mono scatter",
  [MODE_ORDERED_ROTATE] = "Ordered multichannel rotation",
  [MODE_RANDOM_ROTATE] = "Random multichannel rotation",
}

local function shuffled_indices(count)
  local indices = {}
  for index = 1, count do indices[index] = index end
  for index = count, 2, -1 do
    local swap_index = math.random(index)
    indices[index], indices[swap_index] = indices[swap_index], indices[index]
  end
  return indices
end

local function clamp_fade(fade_seconds, length)
  return math.min(fade_seconds, math.max(0, length / 2))
end

local function slice_mode_label(mode)
  if mode == SLICE_MARKERS then return "markers" end
  return "equal divisions"
end

local function motion_mode_label(mode)
  if mode == MODE_RANDOM_MONO then return "random mono scatter" end
  if mode == MODE_ORDERED_ROTATE then return "ordered multichannel rotation" end
  if mode == MODE_RANDOM_ROTATE then return "random multichannel rotation" end
  return "ordered mono spread"
end

local function equal_slices(count, source_length)
  local slices = {}
  local slice_length = source_length / count
  for index = 1, count do
    slices[index] = {
      source_start = (index - 1) * slice_length,
      output_start = (index - 1) * slice_length,
      length = slice_length,
    }
  end
  return slices
end

local function add_take_marker_points(points, item, source_length)
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
    if item_relative > 0 and item_relative < source_length then
      points[#points + 1] = item_relative
    end
  end
end

local function marker_slices(item, item_position, source_length)
  local item_end = item_position + source_length
  local points = { 0 }
  local _, marker_count, region_count = reaper.CountProjectMarkers(0)
  local total = marker_count + region_count

  for index = 0, total - 1 do
    local ok, is_region, marker_position = reaper.EnumProjectMarkers3(0, index)
    if ok and not is_region and marker_position > item_position and marker_position < item_end then
      points[#points + 1] = marker_position - item_position
    end
  end

  add_take_marker_points(points, item, source_length)
  points[#points + 1] = source_length
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

local function source_channel_for_rotation(output_channel, source_channels, rotation)
  return ((output_channel - 1 - rotation) % source_channels) + 1
end

local function create_fragment(item, track, source_channel, source_start, output_start, length, fade_seconds, source_start_offset, source_playrate)
  local clone = mc.clone_item_to_track(item, track)
  if not clone then return nil end

  local clone_take = reaper.GetActiveTake(clone)
  mc.set_take_to_mono_source_channel(clone_take, source_channel)
  reaper.SetMediaItemInfo_Value(clone, "D_POSITION", output_start)
  reaper.SetMediaItemInfo_Value(clone, "D_LENGTH", length)
  reaper.SetMediaItemInfo_Value(clone, "D_FADEINLEN", clamp_fade(fade_seconds, length))
  reaper.SetMediaItemInfo_Value(clone, "D_FADEOUTLEN", clamp_fade(fade_seconds, length))
  reaper.SetMediaItemTakeInfo_Value(clone_take, "D_STARTOFFS",
    source_start_offset + (source_start * source_playrate))
  return clone
end

local function is_mono_motion(mode)
  return mode == MODE_ORDERED_MONO or mode == MODE_RANDOM_MONO
end

local function clamp_value(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function run_process(item, take, source_channels, slice_mode, motion_mode, slice_count, output_channels, source_channel, fade_seconds)
  if motion_mode == MODE_ORDERED_ROTATE or motion_mode == MODE_RANDOM_ROTATE then
    if source_channels < 2 then
      mc.show_error("Multichannel rotate modes require a multichannel source item.")
      return
    end
    output_channels = source_channels
  end

  math.randomseed(os.time())

  local source_track = reaper.GetMediaItemTrack(item)
  local insert_index = mc.get_insert_index_after_track(source_track)
  local source_position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local source_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local source_start_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  local source_playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  local slices = slice_mode == SLICE_MARKERS and marker_slices(item, source_position, source_length) or
    equal_slices(slice_count, source_length)

  if #slices < 2 then
    mc.show_error("Need at least two slices. Add project markers or active-take markers inside the item, or use equal slicing.")
    return
  end

  local order = motion_mode == MODE_RANDOM_MONO and shuffled_indices(#slices) or nil
  local temp_tracks = {}
  local did_render = false

  reaper.Undo_BeginBlock()
  mc.with_ui_refresh_block(function()
    for channel = 1, output_channels do
      temp_tracks[channel] = mc.insert_track_at(insert_index + channel - 1,
        "tmp shred slice ch " .. tostring(channel), 2)
      reaper.SetMediaTrackInfo_Value(temp_tracks[channel], "B_MAINSEND", 0)
    end

    local random_output_start = 0
    for output_index, output_slice in ipairs(slices) do
      local source_slice = output_slice
      if order then source_slice = slices[order[output_index]] end

      if motion_mode == MODE_ORDERED_MONO or motion_mode == MODE_RANDOM_MONO then
        local output_channel = motion_mode == MODE_ORDERED_MONO and
          (((output_index - 1) % output_channels) + 1) or math.random(output_channels)
        local fragment_start = output_slice.output_start
        local fragment_length = output_slice.length
        if motion_mode == MODE_RANDOM_MONO then
          fragment_start = random_output_start
          fragment_length = source_slice.length
          random_output_start = random_output_start + fragment_length
        end
        create_fragment(item, temp_tracks[output_channel], source_channel,
          source_slice.source_start, fragment_start, fragment_length,
          fade_seconds, source_start_offset, source_playrate)
      else
        local rotation = motion_mode == MODE_ORDERED_ROTATE and ((output_index - 1) % source_channels) or
          math.random(0, source_channels - 1)
        for output_channel = 1, output_channels do
          local input_channel = source_channel_for_rotation(output_channel, source_channels, rotation)
          create_fragment(item, temp_tracks[output_channel], input_channel,
            output_slice.source_start, output_slice.output_start, output_slice.length,
            fade_seconds, source_start_offset, source_playrate)
        end
      end
    end

    local bus = mc.insert_track_at(insert_index + output_channels,
      "Shred slice bus (" .. tostring(output_channels) .. "ch)",
      mc.reaper_track_channel_count(output_channels))

    for channel, temp_track in ipairs(temp_tracks) do
      mc.create_postfx_send(temp_track, bus, 1, channel - 1)
    end

    mc.select_only_track(bus)
    mc.with_render_bounds_for_range(0, source_length, function()
      local before_guids = mc.snapshot_track_guids()
      local track_count_before_render = reaper.CountTracks(mc.PROJECT)
      reaper.Main_OnCommand(mc.render_multichannel_post_fader_stem_command(), 0)
      did_render = reaper.CountTracks(mc.PROJECT) > track_count_before_render

      if did_render then
        local excluded_tracks = {}
        for _, temp_track in ipairs(temp_tracks) do
          excluded_tracks[#excluded_tracks + 1] = temp_track
        end
        excluded_tracks[#excluded_tracks + 1] = bus
        local rendered_track = mc.find_new_track(before_guids) or mc.get_selected_track_excluding(excluded_tracks)
        if rendered_track then
          reaper.GetSetMediaTrackInfo_String(rendered_track, "P_NAME",
            "Shred slice render (" .. tostring(output_channels) .. "ch)", true)
          reaper.SetMediaTrackInfo_Value(rendered_track, "I_NCHAN",
            mc.reaper_track_channel_count(output_channels))
          mc.set_track_items_length(rendered_track, source_length)
          local rendered_start = mc.track_items_bounds({ rendered_track })
          mc.move_track_items_by(rendered_track, source_position - rendered_start)
          mc.select_only_track(rendered_track)
        end
      end
    end)

    if did_render then
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
    end
  end)
  reaper.Undo_EndBlock("Shred / slice selected multichannel item", -1)

  if did_render then
    local lines = {
      "Item: " .. mc.item_label(item),
      "Slice mode: " .. slice_mode_label(slice_mode),
      "Motion: " .. motion_mode_label(motion_mode),
      "Slices: " .. tostring(#slices),
      "Source channels: " .. tostring(source_channels),
      "Output channels: " .. tostring(output_channels),
      "Fade: " .. tostring(fade_seconds) .. " sec",
    }
    if is_mono_motion(motion_mode) then
      lines[#lines + 1] = "Mono source channel: " .. tostring(source_channel)
    end
    mc.print_plan("Shred / Slice", lines)
    if MUTE_SOURCE_ITEM_AFTER_RENDER then
      reaper.ShowConsoleMsg("Muted the original source item so the rendered result is audible by itself.\n")
    end
  else
    reaper.ShowConsoleMsg("Built shred routing, but REAPER did not report a new rendered stem track.\n")
  end
end

local function draw_combo(ctx, label, value, names, first_index, last_index)
  local changed = false
  if ImGui.BeginCombo(ctx, label, names[value] or "") then
    for index = first_index, last_index do
      local selected = value == index
      if ImGui.Selectable(ctx, names[index], selected) then
        value = index
        changed = true
      end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return changed, value
end

local function main()
  local item, take, source_channels = mc.require_selected_audio_item()
  if not item then return end

  local ctx = ImGui.CreateContext("Shred / Slice")
  local open = true
  local slice_mode = SLICE_EQUAL
  local motion_mode = MODE_ORDERED_MONO
  local slice_count = 16
  local output_channels = math.min(math.max(source_channels, 8), mc.MAX_REAPER_TRACK_CHANNELS)
  local source_channel = 1
  local fade_seconds = 0.005
  local should_render = false
  local status = ""

  local function loop()
    ImGui.SetNextWindowSize(ctx, 440, 270, ImGui.Cond_FirstUseEver)
    local visible
    visible, open = ImGui.Begin(ctx, "Shred / Slice", open)

    if visible then
      ImGui.Text(ctx, "Source: " .. mc.item_label(item) .. "  (" .. tostring(source_channels) .. " ch)")
      ImGui.Spacing(ctx)
      local changed
      changed, slice_mode = draw_combo(ctx, "Slice", slice_mode, SLICE_MODE_NAMES, SLICE_EQUAL, SLICE_MARKERS)
      changed, motion_mode = draw_combo(ctx, "Motion", motion_mode, MOTION_MODE_NAMES, MODE_ORDERED_MONO, MODE_RANDOM_ROTATE)

      local mono_motion = is_mono_motion(motion_mode)
      source_channel = clamp_value(source_channel, 1, source_channels)
      if slice_mode == SLICE_EQUAL then
        changed, slice_count = ImGui.SliderInt(ctx, "Slices", slice_count, 2, 256)
      else
        ImGui.Text(ctx, "Slices: project or active-take markers inside item")
      end

      if mono_motion then
        changed, output_channels = ImGui.SliderInt(ctx, "Output channels", output_channels, 2, mc.MAX_REAPER_TRACK_CHANNELS)
        changed, source_channel = ImGui.SliderInt(ctx, "Source channel", source_channel, 1, source_channels)
      else
        output_channels = source_channels
        ImGui.Text(ctx, "Output channels: " .. tostring(output_channels) .. " (matches source)")
        ImGui.Text(ctx, "Source: all channels")
      end

      changed, fade_seconds = ImGui.SliderDouble(ctx, "Fade seconds", fade_seconds, 0, 0.1, "%.4f")
      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Spacing(ctx)

      local can_render = mono_motion or source_channels >= 2
      if not can_render then
        ImGui.Text(ctx, "Multichannel motion needs a multichannel source item.")
      elseif status ~= "" then
        ImGui.Text(ctx, status)
      elseif slice_mode == SLICE_MARKERS then
        ImGui.Text(ctx, "Uses markers inside the selected item as slice boundaries.")
      else
        ImGui.Text(ctx, "Uses " .. tostring(slice_count) .. " equal slices.")
      end

      if ImGui.Button(ctx, "Render", 92, 26) then
        if can_render then
          should_render = true
        else
          status = "Choose a mono motion mode, or select a multichannel item."
        end
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 92, 26) then
        open = false
      end
      ImGui.End(ctx)
    end

    if should_render then
      open = false
      run_process(item, take, source_channels, slice_mode, motion_mode,
        slice_count, output_channels, source_channel, fade_seconds)
      return
    end

    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
