-- @description Fracture
-- @author s3g
-- @version 0.3
-- @requires ReaImGui; Multichannel Texture Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; bounds to source item length.
-- @method ReaImGui controller for time-ordered source slices dispersed across a controlled multichannel path with jitter, drop, and spread voices.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local tex = dofile(script_dir .. "Multichannel Texture Library.lua")
local mc = tex.mc

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Fracture", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local PATHS = {
  [1] = "Clockwise",
  [2] = "Ping-pong",
  [3] = "Random",
}

local function draw_combo(ctx, label, value)
  if ImGui.BeginCombo(ctx, label, PATHS[value]) then
    for index = 1, #PATHS do
      local selected = value == index
      if ImGui.Selectable(ctx, PATHS[index], selected) then value = index end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return value
end

local function channel_for_voice(slice_index, voice_index, output_channels, path)
  if path == 3 then return math.random(output_channels) end
  return tex.channel_walk(slice_index + voice_index - 1, output_channels, path)
end

local function render_fracture(item, source_channel, slice_count, output_channels, path, spread_voices, jitter, drop, fade)
  math.randomseed(os.time())
  drop = tex.clamp(drop, 0, 0.85)
  spread_voices = math.max(1, math.min(spread_voices, output_channels))

  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local slices = tex.equal_slices(slice_count, length)
  local events = {}
  local kept_slices = 0
  local voice_gain = 1 / math.sqrt(spread_voices)

  for index, slice in ipairs(slices) do
    if math.random() >= drop then
      kept_slices = kept_slices + 1
      local max_jitter = slice.length * jitter
      local out_start = tex.clamp(slice.output_start + (math.random() * 2 - 1) * max_jitter,
        0, math.max(0, length - slice.length))
      for voice = 1, spread_voices do
        events[#events + 1] = {
          input_channel = source_channel,
          output_channel = channel_for_voice(index, voice, output_channels, path),
          source_start = slice.source_start,
          output_start = out_start,
          length = slice.length,
          fade = fade,
          gain = voice_gain,
        }
      end
    end
  end

  if kept_slices == 0 then
    local slice = slices[1]
    events[#events + 1] = {
      input_channel = source_channel,
      output_channel = channel_for_voice(1, 1, output_channels, path),
      source_start = slice.source_start,
      output_start = slice.output_start,
      length = slice.length,
      fade = fade,
      gain = 1,
    }
  end

  local did_render = tex.render_events(item, output_channels, events, "Fracture texture", { mute_source_item = true })
  if did_render then
    mc.print_plan("Fracture", {
      "Slices: " .. tostring(slice_count),
      "Kept slices: " .. tostring(math.max(kept_slices, 1)),
      "Events rendered: " .. tostring(#events),
      "Output channels: " .. tostring(output_channels),
      "Path: " .. PATHS[path],
      "Spread voices: " .. tostring(spread_voices),
    })
  end
end

local function main()
  local item, take, source_channels = mc.require_selected_audio_item()
  if not item then return end

  local ctx = ImGui.CreateContext("Fracture")
  local open = true
  local slice_count = 32
  local output_channels = math.min(math.max(source_channels, 8), mc.MAX_REAPER_TRACK_CHANNELS)
  local source_channel = 1
  local path = 2
  local spread_voices = 2
  local jitter = 0.15
  local drop = 0.0
  local fade = 0.005
  local should_render = false

  local function loop()
    ImGui.SetNextWindowSize(ctx, 450, 410, ImGui.Cond_Appearing)
    local visible
    visible, open = ImGui.Begin(ctx, "Fracture", open)
    if visible then
      ImGui.Text(ctx, "Source: " .. mc.item_label(item) .. "  (" .. tostring(source_channels) .. " ch)")
      ImGui.Spacing(ctx)
      local changed
      changed, slice_count = ImGui.SliderInt(ctx, "Slices", slice_count, 2, 256)
      changed, output_channels = ImGui.SliderInt(ctx, "Output channels", output_channels, 2, mc.MAX_REAPER_TRACK_CHANNELS)
      changed, source_channel = ImGui.SliderInt(ctx, "Source channel", source_channel, 1, source_channels)
      path = draw_combo(ctx, "Path", path)
      changed, spread_voices = ImGui.SliderInt(ctx, "Spread voices", spread_voices, 1, math.min(output_channels, 8))
      changed, jitter = ImGui.SliderDouble(ctx, "Timing jitter", jitter, 0, 1, "%.2f")
      changed, drop = ImGui.SliderDouble(ctx, "Drop probability", drop, 0, 0.85, "%.2f")
      changed, fade = ImGui.SliderDouble(ctx, "Fade seconds", fade, 0, 0.1, "%.4f")
      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Text(ctx, "Random path uses spread voices so random placement stays audible.")
      ImGui.Spacing(ctx)
      if ImGui.Button(ctx, "Render", 92, 26) then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 92, 26) then open = false end
      ImGui.End(ctx)
    end

    if should_render then
      open = false
      render_fracture(item, source_channel, slice_count, output_channels, path, spread_voices, jitter, drop, fade)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
