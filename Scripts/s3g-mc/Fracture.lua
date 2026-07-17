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
do
  local _s3g_theme_path = ({ reaper.get_action_context() })[2]
  if not _s3g_theme_path or _s3g_theme_path == "" then
    _s3g_theme_path = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
  end
  local _s3g_theme_dir = _s3g_theme_path:match("^(.*[/\\])") or ""
  package.path = _s3g_theme_dir .. "?.lua;" .. package.path
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme and _s3g_theme.install then _s3g_theme.install(ImGui) end
end
local theme = require("s3g-mc ImGui Theme")
local THEME = theme.palette(ImGui)


local PATHS = {
  [1] = "Clockwise",
  [2] = "Ping-pong",
  [3] = "Random",
}

local ROW_H = 25
local LABEL_W = 86
local CONTROL_GAP = 8
local VALUE_W = 76

local LABEL_ABBR = {
  ["OUTPUT CHANNELS"] = "OUT CH",
  ["SOURCE CHANNEL"] = "SRC CH",
  ["SPREAD VOICES"] = "VOICES",
  ["TIMING JITTER"] = "JITTER",
  ["DROP PROBABILITY"] = "DROP",
  ["FADE SECONDS"] = "FADE",
}

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function row_label_text(label)
  local upper = tostring(label or ""):upper()
  return LABEL_ABBR[upper] or upper
end

local function row_layout(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local avail = ImGui.GetContentRegionAvail(ctx)
  if type(avail) ~= "number" then avail = 360 end
  local control_x = x + LABEL_W
  local control_w = math.max(120, avail - LABEL_W - CONTROL_GAP)
  return x, y, control_x, control_w
end

local function row_label(ctx, x, y, label)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 4, THEME.label, row_label_text(label))
end

local function finish_row(ctx, x, y)
  ImGui.SetCursorScreenPos(ctx, x, y + ROW_H)
end

local function draw_custom_slider(ctx, label, value, lo, hi, fmt, integer)
  local x, y, control_x, control_w = row_layout(ctx)
  local slider_w = math.max(80, control_w - VALUE_W - CONTROL_GAP)
  local value_x = control_x + slider_w + CONTROL_GAP
  local track_y = y + 8
  local track_h = 8
  local norm = hi ~= lo and clamp((value - lo) / (hi - lo), 0, 1) or 0

  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.InvisibleButton(ctx, "##" .. label, slider_w, ROW_H)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local changed = false
  if (hovered or active) and ImGui.IsMouseDown(ctx, 0) then
    local mx = ImGui.GetMousePos(ctx)
    local next_norm = clamp((mx - control_x) / slider_w, 0, 1)
    local next_value = lo + (hi - lo) * next_norm
    if integer then next_value = math.floor(next_value + 0.5) end
    if math.abs(next_value - value) > (integer and 0 or 0.0000001) then
      value = next_value
      norm = next_norm
      changed = true
    end
  end

  local draw = ImGui.GetWindowDrawList(ctx)
  local frame = active and THEME.frame_active or (hovered and THEME.frame_hover or THEME.frame)
  local fill = active and THEME.active or THEME.fill
  local handle = active and THEME.active_hover or THEME.active
  ImGui.DrawList_AddRectFilled(draw, control_x, track_y, control_x + slider_w, track_y + track_h, frame)
  ImGui.DrawList_AddRectFilled(draw, control_x + 1, track_y + 1, control_x + math.max(2, slider_w * norm), track_y + track_h - 1, fill)
  local hx = clamp(control_x + slider_w * norm - 1.5, control_x + 1, control_x + slider_w - 4)
  ImGui.DrawList_AddRectFilled(draw, hx, track_y - 2, hx + 3, track_y + track_h + 2, handle)
  ImGui.DrawList_AddText(draw, value_x, y + 4, THEME.value, integer and tostring(math.floor(value + 0.5)) or string.format(fmt or "%.3f", value))
  finish_row(ctx, x, y)
  return changed, value
end

local function draw_combo(ctx, label, value)
  local x, y, control_x, control_w = row_layout(ctx)
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, control_w)
  if ImGui.BeginCombo(ctx, "##" .. label, PATHS[value]) then
    for index = 1, #PATHS do
      local selected = value == index
      if ImGui.Selectable(ctx, PATHS[index], selected) then value = index end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  finish_row(ctx, x, y)
  return value
end

local function section(ctx, label, height)
  local stack = theme.push_soft_panel(ImGui, ctx)
  local draw = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + height, THEME.panel_soft)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + 2, THEME.active)
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 10)
  theme.text(ImGui, ctx, label:upper())
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 36)
  return x, y, height, stack
end

local function finish_section(ctx, x, y, height, stack)
  theme.pop_soft_panel(ImGui, ctx, stack)
  ImGui.SetCursorScreenPos(ctx, x, y + height + 10)
  ImGui.Dummy(ctx, 1, 1)
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
    ImGui.SetNextWindowSize(ctx, 450, 520, ImGui.Cond_Appearing)
    local visible
    visible, open = ImGui.Begin(ctx, "Fracture", open)
    if visible then
      theme.muted(ImGui, ctx, "Source: " .. mc.item_label(item) .. "  (" .. tostring(source_channels) .. " ch)")
      ImGui.Spacing(ctx)
      local changed
      local sx, sy, sh, stack = section(ctx, "Settings", 250)
      changed, slice_count = draw_custom_slider(ctx, "Slices", slice_count, 2, 256, nil, true)
      changed, output_channels = draw_custom_slider(ctx, "Output channels", output_channels, 2, mc.MAX_REAPER_TRACK_CHANNELS, nil, true)
      changed, source_channel = draw_custom_slider(ctx, "Source channel", source_channel, 1, source_channels, nil, true)
      path = draw_combo(ctx, "Path", path)
      changed, spread_voices = draw_custom_slider(ctx, "Spread voices", spread_voices, 1, math.min(output_channels, 8), nil, true)
      changed, jitter = draw_custom_slider(ctx, "Timing jitter", jitter, 0, 1, "%.2f", false)
      changed, drop = draw_custom_slider(ctx, "Drop probability", drop, 0, 0.85, "%.2f", false)
      changed, fade = draw_custom_slider(ctx, "Fade seconds", fade, 0, 0.1, "%.4f", false)
      finish_section(ctx, sx, sy, sh, stack)
      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      theme.muted(ImGui, ctx, "Random path uses spread voices so random placement stays audible.")
      ImGui.Spacing(ctx)
      if ImGui.Button(ctx, "RENDER", 92, 26) then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "CANCEL", 92, 26) then open = false end
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
