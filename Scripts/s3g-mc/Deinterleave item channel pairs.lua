-- @description Deinterleave item channel pairs
-- @author s3g
-- @version 0.1
-- @requires Multichannel Library.lua; REAPER multichannel stem render action
-- @category Item Channel Transforms
-- @render Yes; bounds to source item length.
-- @method Renders a copy of the selected item with odd/even interleaved pairs split into channel halves.
-- @about
--   Converts interleaved pair order such as L1 R1 L2 R2 into L1 L2 R1 R2.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local MUTE_SOURCE_ITEM_AFTER_RENDER = true

local function main()
  local item, take, channel_count = mc.require_selected_multichannel_item()
  if not item then return end

  local channel_map = mc.deinterleave_pairs_map(channel_count)

  reaper.Undo_BeginBlock()
  local did_render = mc.with_ui_refresh_block(function()
    return mc.build_multichannel_render_from_item(item, channel_count,
      channel_map, "Deinterleaved pairs", { mute_source_item = MUTE_SOURCE_ITEM_AFTER_RENDER })
  end)
  reaper.Undo_EndBlock("Deinterleave channel pairs of selected item", -1)

  if did_render then
    mc.print_plan("Deinterleaved item channel pairs", mc.render_plan_for_item(item, channel_count,
      channel_map, "Deinterleaved pairs"))
    if MUTE_SOURCE_ITEM_AFTER_RENDER then
      reaper.ShowConsoleMsg("Muted the original source item so the rendered result is audible by itself.\n")
    end
  else
    reaper.ShowConsoleMsg("Built routing, but REAPER did not report a new rendered stem track.\n")
  end
end

main()
