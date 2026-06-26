-- @description Frame Shift
-- @author s3g
-- @version 0.2
-- @requires ReaImGui; Multichannel Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; bounds to source item length.
-- @method ReaImGui controller for rendering channel-frame rotation, mirror, odd/even split, pair interleave, or half-swap maps.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Frame Shift", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local MODES = {
  [1] = "Rotate",
  [2] = "Mirror",
  [3] = "Odd/even split",
  [4] = "Pair interleave",
  [5] = "Swap halves",
}

local function map_for_mode(mode, channel_count, offset)
  if mode == 1 then return mc.rotate_map(channel_count, offset), "Frame rotate" end
  if mode == 2 then return mc.mirror_map(channel_count), "Frame mirror" end
  if mode == 3 then return mc.odd_even_map(channel_count), "Frame odd even" end
  if mode == 4 then return mc.interleave_pairs_map(channel_count), "Frame interleave" end
  return mc.swap_halves_map(channel_count), "Frame swap halves"
end

local function draw_combo(ctx, label, value)
  if ImGui.BeginCombo(ctx, label, MODES[value]) then
    for index = 1, #MODES do
      local selected = value == index
      if ImGui.Selectable(ctx, MODES[index], selected) then value = index end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return value
end

local function main()
  local item, take, channel_count = mc.require_selected_multichannel_item()
  if not item then return end

  local ctx = ImGui.CreateContext("Frame Shift")
  local open = true
  local mode = 1
  local offset = 1
  local should_render = false

  local function loop()
    ImGui.SetNextWindowSize(ctx, 420, 290, ImGui.Cond_FirstUseEver)
    local visible
    visible, open = ImGui.Begin(ctx, "Frame Shift", open)
    if visible then
      ImGui.Text(ctx, "Source: " .. mc.item_label(item) .. "  (" .. tostring(channel_count) .. " ch)")
      ImGui.Spacing(ctx)
      mode = draw_combo(ctx, "Mode", mode)
      if mode == 1 then
        local changed
        changed, offset = ImGui.SliderInt(ctx, "Rotate offset", offset, -channel_count + 1, channel_count - 1)
      else
        ImGui.Text(ctx, "Rotate offset: not used")
      end
      local map, label = map_for_mode(mode, channel_count, offset)
      ImGui.Text(ctx, "Map: " .. mc.describe_map(map))
      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Spacing(ctx)
      if ImGui.Button(ctx, "Render", 92, 26) then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 92, 26) then open = false end
      ImGui.End(ctx)
    end

    if should_render then
      local map, label = map_for_mode(mode, channel_count, offset)
      open = false
      reaper.Undo_BeginBlock()
      local did_render = mc.with_ui_refresh_block(function()
        return mc.build_multichannel_render_from_item(item, channel_count, map, label, { mute_source_item = true })
      end)
      reaper.Undo_EndBlock(label, -1)
      if did_render then mc.print_plan(label, mc.render_plan_for_item(item, channel_count, map, label)) end
      return
    end

    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
