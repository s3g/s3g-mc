-- @description Reorder item channels
-- @author s3g
-- @version 0.1
-- @requires Multichannel Library.lua; REAPER multichannel stem render action
-- @category Item Channel Transforms
-- @render Yes; bounds to source item length.
-- @method Applies a user-entered output-to-input channel map.
-- @about
--   Creates a rendered multichannel stem from the selected item using a custom
--   output-to-input channel map, e.g. "3 4 1 2".

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local input_dialog = dofile(script_dir .. "s3g-mc ImGui Input Dialog.lua")
local MUTE_SOURCE_ITEM_AFTER_RENDER = true

local function main()
  local item, take, channel_count = mc.require_selected_multichannel_item()
  if not item then return end

  local default_map = table.concat(mc.identity_map(channel_count), " ")
  input_dialog.prompt_csv("Reorder item channels", "Output channels use input channels", default_map, function(input)

  local channel_map, err = mc.parse_channel_map(input, channel_count, true)
  if not channel_map then
    mc.show_error(err)
    return
  end

  reaper.Undo_BeginBlock()
  local did_render = mc.with_ui_refresh_block(function()
    return mc.build_multichannel_render_from_item(item, channel_count,
      channel_map, "Reordered channels", { mute_source_item = MUTE_SOURCE_ITEM_AFTER_RENDER })
  end)
  reaper.Undo_EndBlock("Reorder channels of selected multichannel item", -1)

  if did_render then
    mc.print_plan("Reordered item channels", mc.render_plan_for_item(item, channel_count,
      channel_map, "Reordered channels"))
    if MUTE_SOURCE_ITEM_AFTER_RENDER then
      reaper.ShowConsoleMsg("Muted the original source item so the rendered result is audible by itself.\n")
    end
  else
    reaper.ShowConsoleMsg("Built routing, but REAPER did not report a new rendered stem track.\n")
  end
  end)
end

main()
