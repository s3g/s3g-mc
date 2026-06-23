-- @description Odd-even item channel order
-- @author s3g
-- @version 0.1
-- @requires Multichannel Library.lua; REAPER multichannel stem render action
-- @category Item Channel Transforms
-- @render Yes; bounds to source item length.
-- @method Renders a copy of the selected multichannel item with odd channels first, then even channels.
-- @about
--   Reorders item channels from 1 2 3 4 5 6 to 1 3 5 2 4 6.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local MUTE_SOURCE_ITEM_AFTER_RENDER = true

local function main()
  local item, take, channel_count = mc.require_selected_multichannel_item()
  if not item then return end

  local channel_map = mc.odd_even_map(channel_count)

  reaper.Undo_BeginBlock()
  local did_render = mc.with_ui_refresh_block(function()
    return mc.build_multichannel_render_from_item(item, channel_count,
      channel_map, "Odd-even channels", { mute_source_item = MUTE_SOURCE_ITEM_AFTER_RENDER })
  end)
  reaper.Undo_EndBlock("Odd-even channel order of selected item", -1)

  if did_render then
    mc.print_plan("Odd-even item channel order", mc.render_plan_for_item(item, channel_count,
      channel_map, "Odd-even channels"))
    if MUTE_SOURCE_ITEM_AFTER_RENDER then
      reaper.ShowConsoleMsg("Muted the original source item so the rendered result is audible by itself.\n")
    end
  else
    reaper.ShowConsoleMsg("Built routing, but REAPER did not report a new rendered stem track.\n")
  end
end

main()
