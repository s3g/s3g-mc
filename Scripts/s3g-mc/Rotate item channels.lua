-- @description Rotate item channels
-- @author s3g
-- @version 0.1
-- @requires Multichannel Library.lua; REAPER multichannel stem render action
-- @category Item Channel Transforms
-- @render Yes; bounds to source item length.
-- @method Rotates source-channel order by a user-entered offset.
-- @about
--   Renders a copy of the selected multichannel item with channels rotated by
--   an offset. Positive offset moves source material to higher channel numbers.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local input_dialog = dofile(script_dir .. "s3g-mc ImGui Input Dialog.lua")
local MUTE_SOURCE_ITEM_AFTER_RENDER = true

local function main()
  local item, take, channel_count = mc.require_selected_multichannel_item()
  if not item then return end

  input_dialog.prompt_csv("Rotate item channels", "Channel offset", "1", function(input)

  local offset = tonumber(input)
  if not offset or offset ~= math.floor(offset) then
    mc.show_error("Channel offset must be a whole number.")
    return
  end

  local channel_map = mc.rotate_map(channel_count, offset)

  reaper.Undo_BeginBlock()
  local did_render = mc.with_ui_refresh_block(function()
    return mc.build_multichannel_render_from_item(item, channel_count,
      channel_map, "Rotated channels " .. tostring(offset),
      { mute_source_item = MUTE_SOURCE_ITEM_AFTER_RENDER })
  end)
  reaper.Undo_EndBlock("Rotate channels of selected multichannel item", -1)

  if did_render then
    mc.print_plan("Rotated item channels", mc.render_plan_for_item(item, channel_count,
      channel_map, "Rotated channels " .. tostring(offset)))
    if MUTE_SOURCE_ITEM_AFTER_RENDER then
      reaper.ShowConsoleMsg("Muted the original source item so the rendered result is audible by itself.\n")
    end
  else
    reaper.ShowConsoleMsg("Built routing, but REAPER did not report a new rendered stem track.\n")
  end
  end)
end

main()
