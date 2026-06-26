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
local input_dialog = dofile(script_dir .. "s3g-mc ImGui Input Dialog.lua")

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
    local map = mc.repeat_sources_map(source_count, output_channels)
    for output_channel, source_index in ipairs(map) do
      assignments[#assignments + 1] = {
        source_index = source_index,
        dest_channel = output_channel - 1,
        gain = 1.0,
      }
    end
    return assignments
  end

  local plan = mc.grouped_downmix_plan(source_count, output_channels)
  for output_channel, group in ipairs(plan) do
    for _, source_index in ipairs(group.inputs) do
      assignments[#assignments + 1] = {
        source_index = source_index,
        dest_channel = output_channel - 1,
        gain = group.gain,
      }
    end
  end

  return assignments
end

local function routing_mode_label(source_count, output_channels)
  if output_channels > source_count then return "repeated source order" end
  if output_channels < source_count then return "adjacent grouped downmix" end
  return "one-to-one"
end

local function main()
  local tracks = mc.require_selected_mono_compatible_tracks()
  if not tracks then return end

  input_dialog.prompt_csv("Cycle mono tracks into multichannel stem", "Output channels", tostring(#tracks), function(input)

  local output_channels, err = mc.validate_channel_count(input, "Output channels", 2, mc.MAX_REAPER_TRACK_CHANNELS)
  if not output_channels then
    mc.show_error(err)
    return
  end

  reaper.Undo_BeginBlock()
  local did_render = false
  mc.with_ui_refresh_block(function()
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
    local function do_render()
      local before_guids = mc.snapshot_track_guids()
      local track_count_before_render = reaper.CountTracks(mc.PROJECT)
      reaper.Main_OnCommand(mc.render_multichannel_post_fader_stem_command(), 0)
      did_render = reaper.CountTracks(mc.PROJECT) > track_count_before_render

      if did_render then
        local excluded_tracks = { bus }
        for _, track in ipairs(tracks) do excluded_tracks[#excluded_tracks + 1] = track end
        local rendered_track = mc.find_new_track(before_guids) or mc.get_selected_track_excluding(excluded_tracks)
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
    end

    if bounds_length > 0 then
      mc.with_render_bounds_for_range(bounds_start, bounds_end, do_render)
    else
      do_render()
    end

    if did_render and reaper.ValidatePtr2(mc.PROJECT, bus, "MediaTrack*") then
      reaper.DeleteTrack(bus)
    end
  end)
  reaper.Undo_EndBlock("Distribute selected mono tracks cyclically to multichannel item", -1)

  if did_render then
    mc.print_plan("Cyclic multichannel stem", {
      "Source tracks: " .. tostring(#tracks),
      "Output channels: " .. tostring(output_channels),
      "Mode: " .. routing_mode_label(#tracks, output_channels),
    })
  else
    reaper.ShowConsoleMsg("Built routing, but REAPER did not report a new rendered stem track.\n")
  end
  end)
end

main()
