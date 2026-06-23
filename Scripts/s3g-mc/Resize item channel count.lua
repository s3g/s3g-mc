-- @description Resize item channel count
-- @author s3g
-- @version 0.1
-- @requires Multichannel Library.lua; REAPER multichannel stem render action
-- @category Item Channel Transforms
-- @render Yes; bounds to source item length.
-- @method Renders the selected item to a chosen channel count, repeating source channels when expanding and adjacent gain-compensated groups when reducing.
-- @about
--   Creates a new multichannel render from the selected item. Higher output
--   counts repeat source-channel order. Lower output counts combine adjacent
--   source channels into gain-compensated output groups.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local MUTE_SOURCE_ITEM_AFTER_RENDER = true

local function mixes_from_repeat_map(source_count, output_count)
  local map = mc.repeat_sources_map(source_count, output_count)
  local mixes = {}
  for output_channel, input_channel in ipairs(map) do
    mixes[output_channel] = { inputs = { input_channel }, gain = 1 }
  end
  return mixes, "repeated source order: " .. mc.format_channel_map(map)
end

local function mixes_from_downmix_plan(source_count, output_count)
  local plan = mc.grouped_downmix_plan(source_count, output_count)
  local mixes = {}
  for output_channel, group in ipairs(plan) do
    mixes[output_channel] = { inputs = group.inputs, gain = group.gain }
  end
  return mixes, "adjacent grouped downmix: " .. mc.describe_downmix_plan(plan)
end

local function main()
  local item, take, source_channels = mc.require_selected_audio_item()
  if not item then return end

  local default_channels = tostring(mc.reaper_track_channel_count(source_channels))
  local ok, input = reaper.GetUserInputs("Resize item channel count", 1,
    "Output channels", default_channels)
  if not ok then return end

  local output_channels, err = mc.validate_channel_count(input, "Output channels", 2, mc.MAX_REAPER_TRACK_CHANNELS)
  if not output_channels then
    mc.show_error(err)
    return
  end

  local mixes, mode
  if output_channels >= source_channels then
    mixes, mode = mixes_from_repeat_map(source_channels, output_channels)
  else
    mixes, mode = mixes_from_downmix_plan(source_channels, output_channels)
  end

  reaper.Undo_BeginBlock()
  local did_render = mc.with_ui_refresh_block(function()
    return mc.build_multichannel_mix_render_from_item(item, source_channels,
      mixes, "Resize item channels", { mute_source_item = MUTE_SOURCE_ITEM_AFTER_RENDER })
  end)
  reaper.Undo_EndBlock("Resize selected item channel count", -1)

  if did_render then
    mc.print_plan("Resize item channel count", {
      "Item: " .. mc.item_label(item),
      "Source channels: " .. tostring(source_channels),
      "Output channels: " .. tostring(output_channels),
      "Mode: " .. mode,
    })
    if MUTE_SOURCE_ITEM_AFTER_RENDER then
      reaper.ShowConsoleMsg("Muted the original source item so the rendered result is audible by itself.\n")
    end
  else
    reaper.ShowConsoleMsg("Built resize routing, but REAPER did not report a new rendered stem track.\n")
  end
end

main()
