-- @description Mirror item channel order
-- @author s3g
-- @version 0.1
-- @requires Multichannel Library.lua; REAPER multichannel stem render action
-- @category Item Channel Transforms
-- @render Yes; bounds to source item length.
-- @method Reverses source-channel order.
-- @about
--   Renders a copy of the selected multichannel item with channel order
--   reversed, e.g. 1 2 3 4 -> 4 3 2 1.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local MUTE_SOURCE_ITEM_AFTER_RENDER = true

local function main()
  local item, take, channel_count = mc.get_selected_audio_item()
  if not item then return end

  if channel_count < 2 then
    mc.show_error("The selected item is mono; there is nothing to mirror.")
    return
  end

  local channel_map = mc.mirror_map(channel_count)

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local did_render = mc.build_multichannel_render_from_item(item, channel_count,
    channel_map, "Mirrored channels", { mute_source_item = MUTE_SOURCE_ITEM_AFTER_RENDER })

  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Mirror channels of selected multichannel item", -1)

  reaper.ShowConsoleMsg("")
  if did_render then
    reaper.ShowConsoleMsg("Rendered mirrored channel map: " .. table.concat(channel_map, " ") .. "\n")
    if MUTE_SOURCE_ITEM_AFTER_RENDER then
      reaper.ShowConsoleMsg("Muted the original source item so the rendered result is audible by itself.\n")
    end
  else
    reaper.ShowConsoleMsg("Built routing, but REAPER did not report a new rendered stem track.\n")
  end
end

main()
