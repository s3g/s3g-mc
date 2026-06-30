-- @description Scatter Slices
-- @author s3g
-- @version 0.5
-- @requires ReaImGui; Multichannel Library.lua; REAPER multichannel stem render action
-- @category Multichannel Texture / Montage
-- @render Yes; bounds to target duration.
-- @method ReaImGui controller for slicing multiple selected media items, then arranging them across a target multichannel duration with shape modes, channel paths, and a breakpoint density envelope.
-- @about
--   Builds a new multichannel render from all selected audio items. If the
--   target duration is shorter than the combined source slices, slices overlap
--   with gain compensation. If it is longer, arrangement shapes and a custom
--   density envelope decide where the slices gather or open up.

local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Scatter Slices", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local SLICE_EQUAL = 1
local SLICE_MARKERS = 2
local SOURCE_ALL_CHANNELS = 1
local SOURCE_ONE_CHANNEL = 2
local ARRANGE_SCATTER = 1
local ARRANGE_ORDERED_WALK = 2
local ARRANGE_STUTTER = 3
local ARRANGE_REPEATER = 4
local PATH_CLOCKWISE = 1
local PATH_PINGPONG = 2
local PATH_RANDOM = 3
local SHAPE_FREE = 1
local SHAPE_BURSTS = 2
local SHAPE_SWARMS = 3
local SHAPE_WAVE = 4
local SHAPE_CALL_RESPONSE = 5
local SHAPE_REVERSE_PULL = 6

local SLICE_NAMES = {
  [SLICE_EQUAL] = "Equal divisions",
  [SLICE_MARKERS] = "Project or take markers",
}

local SOURCE_NAMES = {
  [SOURCE_ALL_CHANNELS] = "All source channels",
  [SOURCE_ONE_CHANNEL] = "One source channel",
}

local ARRANGE_NAMES = {
  [ARRANGE_SCATTER] = "Scatter",
  [ARRANGE_ORDERED_WALK] = "Ordered walk",
  [ARRANGE_STUTTER] = "Spatial stutter",
  [ARRANGE_REPEATER] = "Repeater trail",
}

local PATH_NAMES = {
  [PATH_CLOCKWISE] = "Clockwise",
  [PATH_PINGPONG] = "Ping-pong",
  [PATH_RANDOM] = "Random",
}

local SHAPE_NAMES = {
  [SHAPE_FREE] = "Free",
  [SHAPE_BURSTS] = "Burst clusters",
  [SHAPE_SWARMS] = "Swarm clouds",
  [SHAPE_WAVE] = "Wave sweep",
  [SHAPE_CALL_RESPONSE] = "Call / response",
  [SHAPE_REVERSE_PULL] = "Reverse pull",
}

local COLOR_BG = ImGui.ColorConvertDouble4ToU32(0.08, 0.085, 0.09, 1)
local COLOR_GRID = ImGui.ColorConvertDouble4ToU32(0.40, 0.43, 0.45, 0.22)
local COLOR_LINE = ImGui.ColorConvertDouble4ToU32(0.34, 0.78, 0.86, 1)
local COLOR_FILL = ImGui.ColorConvertDouble4ToU32(0.25, 0.58, 0.66, 0.22)
local COLOR_POINT = ImGui.ColorConvertDouble4ToU32(0.93, 0.86, 0.54, 1)
local COLOR_POINT_SELECTED = ImGui.ColorConvertDouble4ToU32(1.00, 0.54, 0.24, 1)
local COLOR_TEXT_DIM = ImGui.ColorConvertDouble4ToU32(0.78, 0.82, 0.84, 0.60)

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function channel_walk(index, output_channels, mode)
  if mode == PATH_PINGPONG then
    local period = math.max(1, (output_channels - 1) * 2)
    local phase = (index - 1) % period
    if phase < output_channels then return phase + 1 end
    return period - phase + 1
  elseif mode == PATH_RANDOM then
    return math.random(output_channels)
  end
  return ((index - 1) % output_channels) + 1
end

local function normalized_index(index, count)
  if count <= 1 then return 0 end
  return (index - 1) / (count - 1)
end

local function shape_time_u(index, count, base_u, shape_mode, scatter)
  if shape_mode == SHAPE_BURSTS then
    local centers = { 0.16, 0.42, 0.70, 0.88 }
    local center = centers[((index - 1) % #centers) + 1]
    return clamp(center + (math.random() * 2 - 1) * (0.035 + scatter * 0.09), 0, 1)
  elseif shape_mode == SHAPE_SWARMS then
    local centers = { 0.22, 0.50, 0.78 }
    local center = centers[math.random(#centers)]
    return clamp(center + (math.random() * 2 - 1) * (0.06 + scatter * 0.16), 0, 1)
  elseif shape_mode == SHAPE_WAVE then
    return clamp(normalized_index(index, count) + (math.random() * 2 - 1) * scatter * 0.035, 0, 1)
  elseif shape_mode == SHAPE_CALL_RESPONSE then
    local phrase = math.floor((index - 1) / 4)
    local local_step = ((index - 1) % 4) / 3
    local phrase_u = (phrase % 2 == 0) and (0.08 + local_step * 0.32) or (0.58 + local_step * 0.34)
    return clamp(phrase_u + (math.random() * 2 - 1) * scatter * 0.045, 0, 1)
  elseif shape_mode == SHAPE_REVERSE_PULL then
    return clamp(1 - normalized_index(index, count) + (math.random() * 2 - 1) * scatter * 0.04, 0, 1)
  end
  return clamp(base_u, 0, 1)
end

local function shape_channel(index, base_channel, output_channels, shape_mode)
  if shape_mode == SHAPE_CALL_RESPONSE and output_channels > 2 then
    local half = math.floor(output_channels / 2)
    local zone_start = ((index - 1) % 2 == 0) and 1 or (half + 1)
    local zone_width = ((index - 1) % 2 == 0) and half or (output_channels - half)
    return zone_start + ((base_channel - 1) % zone_width)
  elseif shape_mode == SHAPE_WAVE then
    return ((index - 1) % output_channels) + 1
  elseif shape_mode == SHAPE_REVERSE_PULL then
    return output_channels - (((index - 1) % output_channels))
  end
  return base_channel
end

local function motion_target_channel(event_index, base_channel, step, output_channels, path_mode, shape_mode)
  local target
  if path_mode == PATH_PINGPONG then
    target = channel_walk(event_index + step, output_channels, path_mode)
  elseif path_mode == PATH_RANDOM then
    local direction = math.random(0, 1) == 0 and -1 or 1
    target = ((base_channel - 1 + direction * step) % output_channels) + 1
  else
    target = ((base_channel - 1 + step) % output_channels) + 1
  end
  return shape_channel(event_index + step, target, output_channels, shape_mode)
end

local function shuffled_indices(count)
  local indices = {}
  for index = 1, count do indices[index] = index end
  for index = count, 2, -1 do
    local swap = math.random(index)
    indices[index], indices[swap] = indices[swap], indices[index]
  end
  return indices
end

local function draw_combo(ctx, label, value, names, first_index, last_index)
  local changed = false
  if ImGui.BeginCombo(ctx, label, names[value] or "") then
    for index = first_index, last_index do
      local selected = value == index
      if ImGui.Selectable(ctx, names[index], selected) then
        value = index
        changed = true
      end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return changed, value
end

local function sort_density_points(points)
  table.sort(points, function(a, b) return a.x < b.x end)
  points[1].x = 0
  points[#points].x = 1
  for index, point in ipairs(points) do
    point.y = clamp(point.y, 0.01, 1)
    if index > 1 and index < #points then
      local lo = points[index - 1].x + 0.01
      local hi = points[index + 1].x - 0.01
      point.x = clamp(point.x, lo, hi)
    end
  end
end

local function density_at(points, x)
  x = clamp(x, 0, 1)
  for index = 1, #points - 1 do
    local a = points[index]
    local b = points[index + 1]
    if x >= a.x and x <= b.x then
      local span = math.max(0.0001, b.x - a.x)
      local t = (x - a.x) / span
      return a.y + (b.y - a.y) * t
    end
  end
  return points[#points].y
end

local function map_u_by_density(u, points)
  u = clamp(u, 0, 1)
  local steps = 96
  local cumulative = { 0 }
  local total = 0
  local prev_y = density_at(points, 0)
  for step = 1, steps do
    local x = step / steps
    local y = density_at(points, x)
    total = total + (prev_y + y) * 0.5 / steps
    cumulative[step + 1] = total
    prev_y = y
  end
  if total <= 0.000001 then return u end

  local target = u * total
  for step = 1, steps do
    local a = cumulative[step]
    local b = cumulative[step + 1]
    if target <= b then
      local span = math.max(0.000001, b - a)
      local t = (target - a) / span
      return ((step - 1) + t) / steps
    end
  end
  return 1
end

local function density_keep_probability(points, x, contrast)
  contrast = math.max(0, contrast or 1)
  local density = clamp(density_at(points, x), 0.001, 1)
  if contrast <= 0 then return 1 end
  return clamp(density ^ contrast, 0, 1)
end

local function reset_density_points(points, mode)
  for index = #points, 1, -1 do points[index] = nil end
  if mode == "build" then
    points[1] = { x = 0, y = 0.15 }
    points[2] = { x = 0.45, y = 0.45 }
    points[3] = { x = 1, y = 1 }
  elseif mode == "thin" then
    points[1] = { x = 0, y = 1 }
    points[2] = { x = 0.55, y = 0.45 }
    points[3] = { x = 1, y = 0.15 }
  elseif mode == "arch" then
    points[1] = { x = 0, y = 0.10 }
    points[2] = { x = 0.5, y = 1 }
    points[3] = { x = 1, y = 0.10 }
  elseif mode == "gaps" then
    points[1] = { x = 0, y = 0.8 }
    points[2] = { x = 0.24, y = 0.05 }
    points[3] = { x = 0.50, y = 0.95 }
    points[4] = { x = 0.74, y = 0.05 }
    points[5] = { x = 1, y = 0.8 }
  else
    points[1] = { x = 0, y = 1 }
    points[2] = { x = 1, y = 1 }
  end
  sort_density_points(points)
end

local function draw_density_editor(ctx, points, selected_index)
  sort_density_points(points)
  local width = ImGui.GetContentRegionAvail(ctx)
  local height = 116
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local x1, y1 = x0 + width, y0 + height
  local pad = 10
  local plot_x0, plot_y0 = x0 + pad, y0 + pad
  local plot_x1, plot_y1 = x1 - pad, y1 - pad

  ImGui.InvisibleButton(ctx, "##density_envelope", width, height)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local mx, my = ImGui.GetMousePos(ctx)

  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, COLOR_BG)
  for grid = 1, 3 do
    local gx = plot_x0 + (plot_x1 - plot_x0) * grid / 4
    local gy = plot_y0 + (plot_y1 - plot_y0) * grid / 4
    ImGui.DrawList_AddLine(draw_list, gx, plot_y0, gx, plot_y1, COLOR_GRID, 1)
    ImGui.DrawList_AddLine(draw_list, plot_x0, gy, plot_x1, gy, COLOR_GRID, 1)
  end
  ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, COLOR_GRID)
  ImGui.DrawList_AddText(draw_list, x0 + 8, y0 + 6, COLOR_TEXT_DIM, "density envelope")

  local prev_x, prev_y = nil, nil
  for index, point in ipairs(points) do
    local px = plot_x0 + point.x * (plot_x1 - plot_x0)
    local py = plot_y1 - point.y * (plot_y1 - plot_y0)
    if prev_x then
      ImGui.DrawList_AddLine(draw_list, prev_x, prev_y, px, py, COLOR_LINE, 2)
      ImGui.DrawList_AddTriangleFilled(draw_list, prev_x, plot_y1, px, plot_y1, px, py, COLOR_FILL)
      ImGui.DrawList_AddTriangleFilled(draw_list, prev_x, plot_y1, prev_x, prev_y, px, py, COLOR_FILL)
    end
    prev_x, prev_y = px, py
  end

  local nearest = nil
  local nearest_dist = 999999
  for index, point in ipairs(points) do
    local px = plot_x0 + point.x * (plot_x1 - plot_x0)
    local py = plot_y1 - point.y * (plot_y1 - plot_y0)
    local dist = ((mx - px) ^ 2 + (my - py) ^ 2) ^ 0.5
    if dist < nearest_dist then
      nearest = index
      nearest_dist = dist
    end
    local color = index == selected_index and COLOR_POINT_SELECTED or COLOR_POINT
    ImGui.DrawList_AddCircleFilled(draw_list, px, py, 4.5, color, 16)
  end

  if hovered and ImGui.IsMouseClicked(ctx, 0) and nearest and nearest_dist < 12 then
    selected_index = nearest
  end
  if selected_index and active and ImGui.IsMouseDown(ctx, 0) then
    local point = points[selected_index]
    if point then
      if selected_index > 1 and selected_index < #points then
        point.x = clamp((mx - plot_x0) / math.max(1, plot_x1 - plot_x0), 0, 1)
      end
      point.y = clamp((plot_y1 - my) / math.max(1, plot_y1 - plot_y0), 0.01, 1)
      sort_density_points(points)
      for index, candidate in ipairs(points) do
        if candidate == point then selected_index = index break end
      end
    end
  end

  if ImGui.Button(ctx, "Flat") then reset_density_points(points, "flat") selected_index = nil end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Build") then reset_density_points(points, "build") selected_index = nil end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Thin") then reset_density_points(points, "thin") selected_index = nil end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Arch") then reset_density_points(points, "arch") selected_index = nil end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Gaps") then reset_density_points(points, "gaps") selected_index = nil end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Add") and #points < 12 then
    points[#points + 1] = { x = 0.5, y = 0.5 }
    selected_index = #points
    sort_density_points(points)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Delete") and selected_index and selected_index > 1 and selected_index < #points then
    table.remove(points, selected_index)
    selected_index = nil
    sort_density_points(points)
  end

  if selected_index then
    local point = points[selected_index]
    if point then
      ImGui.Text(ctx, string.format("Point %d: %.2f time / %.2f density", selected_index, point.x, point.y))
    end
  else
    ImGui.Text(ctx, "Drag points; endpoints keep time fixed.")
  end

  return selected_index
end

local function get_selected_audio_items()
  local items = {}
  for index = 0, reaper.CountSelectedMediaItems(mc.PROJECT) - 1 do
    local item = reaper.GetSelectedMediaItem(mc.PROJECT, index)
    local take = item and reaper.GetActiveTake(item)
    local channels = take and mc.get_take_source_channels(take)
    if take and channels and channels > 0 then
      items[#items + 1] = {
        item = item,
        take = take,
        channels = channels,
        position = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
        length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
      }
    end
  end
  table.sort(items, function(a, b) return a.position < b.position end)
  return items
end

local function add_take_marker_points(points, source)
  local marker_count = reaper.GetNumTakeMarkers(source.take) or 0
  if marker_count <= 0 then return end

  local start_offset = reaper.GetMediaItemTakeInfo_Value(source.take, "D_STARTOFFS")
  local playrate = reaper.GetMediaItemTakeInfo_Value(source.take, "D_PLAYRATE")
  if math.abs(playrate) < 0.000001 then playrate = 1 end

  for index = 0, marker_count - 1 do
    local source_position = reaper.GetTakeMarker(source.take, index, "", 0, 0)
    local item_relative = (source_position - start_offset) / playrate
    if item_relative > 0 and item_relative < source.length then
      points[#points + 1] = item_relative
    end
  end
end

local function marker_slices_for_source(source)
  local item_end = source.position + source.length
  local points = { 0 }
  local _, marker_count, region_count = reaper.CountProjectMarkers(0)
  for index = 0, marker_count + region_count - 1 do
    local ok, is_region, marker_position = reaper.EnumProjectMarkers3(0, index)
    if ok and not is_region and marker_position > source.position and marker_position < item_end then
      points[#points + 1] = marker_position - source.position
    end
  end
  add_take_marker_points(points, source)
  points[#points + 1] = source.length
  table.sort(points)

  local slices = {}
  for index = 1, #points - 1 do
    local length = points[index + 1] - points[index]
    if length > 0.0001 then
      slices[#slices + 1] = { source_start = points[index], length = length }
    end
  end
  return slices
end

local function equal_slices_for_source(source, count)
  local slices = {}
  local length = source.length / count
  for index = 1, count do
    slices[#slices + 1] = {
      source_start = (index - 1) * length,
      length = length,
    }
  end
  return slices
end

local function nearest_zero_crossing(accessor, project_time, channel_index, channel_count, sample_rate, window_seconds)
  if not accessor or window_seconds <= 0 then return project_time end
  local samples_each_side = math.max(1, math.floor(window_seconds * sample_rate))
  local sample_count = samples_each_side * 2 + 1
  local start_time = project_time - samples_each_side / sample_rate
  local buffer = reaper.new_array(sample_count * channel_count)
  local ok = reaper.GetAudioAccessorSamples(accessor, sample_rate, channel_count, start_time, sample_count, buffer)
  if not ok then return project_time end

  local center = samples_each_side + 1
  local best_sample = center
  local best_score = math.huge
  local previous = nil

  for sample_index = 1, sample_count do
    local value = buffer[(sample_index - 1) * channel_count + channel_index] or 0
    local distance = math.abs(sample_index - center)
    local score = math.abs(value) + distance * 0.0001
    if previous and ((previous <= 0 and value >= 0) or (previous >= 0 and value <= 0)) then
      score = distance * 0.0001
    end
    if score < best_score then
      best_score = score
      best_sample = sample_index
    end
    previous = value
  end

  return start_time + (best_sample - 1) / sample_rate
end

local function adjusted_bounds(source, source_channel, source_start, length, zero_window)
  if zero_window <= 0 then return source_start, length end

  local accessor = reaper.CreateTakeAudioAccessor(source.take)
  if not accessor then return source_start, length end

  local sample_rate = tonumber(({ reaper.GetAudioDeviceInfo("SRATE", "") })[2]) or 48000
  if sample_rate < 8000 then sample_rate = 48000 end
  local start_time = source.position + source_start
  local end_time = source.position + source_start + length
  local adjusted_start_time = nearest_zero_crossing(accessor, start_time,
    clamp(source_channel, 1, source.channels), source.channels, sample_rate, zero_window)
  local adjusted_end_time = nearest_zero_crossing(accessor, end_time,
    clamp(source_channel, 1, source.channels), source.channels, sample_rate, zero_window)

  reaper.DestroyAudioAccessor(accessor)

  local adjusted_start = clamp(adjusted_start_time - source.position, 0, source.length)
  local adjusted_end = clamp(adjusted_end_time - source.position, adjusted_start + 0.001, source.length)
  return adjusted_start, adjusted_end - adjusted_start
end

local function create_fragment(source, track, input_channel, source_start, output_start, length, fade, gain)
  local clone = mc.clone_item_to_track(source.item, track)
  if not clone then return nil end

  local clone_take = reaper.GetActiveTake(clone)
  local start_offset = reaper.GetMediaItemTakeInfo_Value(source.take, "D_STARTOFFS")
  local playrate = reaper.GetMediaItemTakeInfo_Value(source.take, "D_PLAYRATE")
  mc.set_take_to_mono_source_channel(clone_take, input_channel)
  reaper.SetMediaItemInfo_Value(clone, "D_POSITION", output_start)
  reaper.SetMediaItemInfo_Value(clone, "D_LENGTH", length)
  reaper.SetMediaItemInfo_Value(clone, "D_FADEINLEN", math.min(fade, length / 2))
  reaper.SetMediaItemInfo_Value(clone, "D_FADEOUTLEN", math.min(fade, length / 2))
  reaper.SetMediaItemInfo_Value(clone, "D_VOL", gain)
  reaper.SetMediaItemTakeInfo_Value(clone_take, "D_STARTOFFS", start_offset + source_start * playrate)
  return clone
end

local function collect_slices(sources, slice_mode, equal_count, source_mode, one_channel, zero_window)
  local slices = {}
  local total_duration = 0
  local scheduled_duration = 0

  for _, source in ipairs(sources) do
    local source_slices = slice_mode == SLICE_MARKERS and marker_slices_for_source(source) or
      equal_slices_for_source(source, equal_count)
    for _, slice in ipairs(source_slices) do
      total_duration = total_duration + slice.length
      local first_channel = source_mode == SOURCE_ONE_CHANNEL and clamp(one_channel, 1, source.channels) or 1
      local last_channel = source_mode == SOURCE_ONE_CHANNEL and first_channel or source.channels
      for channel = first_channel, last_channel do
        local adjusted_start, adjusted_length = adjusted_bounds(source, channel,
          slice.source_start, slice.length, zero_window)
        slices[#slices + 1] = {
          source = source,
          source_channel = channel,
          source_start = adjusted_start,
          length = adjusted_length,
        }
        scheduled_duration = scheduled_duration + adjusted_length
      end
    end
  end

  return slices, total_duration, scheduled_duration
end

local function add_spread_event(events, slice, output_channel, output_start, length, fade, gain, output_channels, spread_width)
  local width = math.max(1, math.min(spread_width, output_channels))
  local left = math.floor((width - 1) / 2)
  local spread_gain = gain / math.sqrt(width)
  for voice = 0, width - 1 do
    local channel = ((output_channel - 1 - left + voice) % output_channels) + 1
    events[#events + 1] = {
      source = slice.source,
      input_channel = slice.source_channel,
      output_channel = channel,
      source_start = slice.source_start,
      output_start = output_start,
      length = length,
      fade = fade,
      gain = spread_gain,
    }
  end
end

local function add_motion_event(events, slice, event_index, output_channel, output_start, length, fade, gain,
  output_channels, spread_width, path_mode, shape_mode, channel_motion)
  channel_motion = clamp(channel_motion or 0, 0, 1)
  if channel_motion <= 0 or length <= 0.004 then
    add_spread_event(events, slice, output_channel, output_start, length, fade, gain, output_channels, spread_width)
    return
  end

  local motion_steps = channel_motion > 0.55 and 2 or 1
  local gain_scale = 1 / math.sqrt(1 + channel_motion * (motion_steps == 2 and 1.45 or 0.85))
  add_spread_event(events, slice, output_channel, output_start, length, fade, gain * gain_scale,
    output_channels, spread_width)

  for step = 1, motion_steps do
    local offset = length * (step == 1 and 0.32 or 0.58) * channel_motion
    local shadow_start = output_start + offset
    local shadow_length = math.max(0.001, length - offset)
    local shadow_channel = motion_target_channel(event_index, output_channel, step, output_channels, path_mode, shape_mode)
    local shadow_gain = gain * gain_scale * channel_motion * (step == 1 and 0.78 or 0.48)
    add_spread_event(events, slice, shadow_channel, shadow_start, shadow_length,
      math.min(fade + offset * 0.4, shadow_length / 2), shadow_gain, output_channels, spread_width)
  end
end

local function order_for_mode(slice_count, arrange_mode)
  if arrange_mode == ARRANGE_ORDERED_WALK then
    local order = {}
    for index = 1, slice_count do order[index] = index end
    return order
  end
  return shuffled_indices(slice_count)
end

local function assign_events(slices, total_duration, target_duration, output_channels, fade, scatter, density_gain,
  arrange_mode, shape_mode, path_mode, spread_width, stutter_repeats, stutter_gap, repeater_repeats, repeater_spacing,
  decay, density_points, density_contrast, channel_motion)
  local order = order_for_mode(#slices, arrange_mode)
  local events = {}
  local gap_pool = math.max(0, target_duration - total_duration)
  local compressed = target_duration < total_duration
  local scale = compressed and (target_duration / math.max(total_duration, 0.001)) or 1
  local cursor = 0

  for index, order_index in ipairs(order) do
    local slice = slices[order_index]
    local output_start
    if compressed then
      local grid_start = cursor * scale
      local jitter = (math.random() * 2 - 1) * scatter * slice.length * 0.5
      output_start = clamp(grid_start + jitter, 0, math.max(0, target_duration - 0.001))
      cursor = cursor + slice.length
    elseif arrange_mode == ARRANGE_ORDERED_WALK then
      local remaining = #order - index + 1
      local gap = remaining > 1 and gap_pool / remaining or 0
      gap_pool = math.max(0, gap_pool - gap)
      cursor = math.min(target_duration, cursor + gap)
      local jitter = (math.random() * 2 - 1) * scatter * gap * 0.5
      output_start = clamp(cursor + jitter, 0, math.max(0, target_duration - 0.001))
      cursor = cursor + slice.length
    else
      local remaining = #order - index + 1
      local max_gap = remaining > 0 and gap_pool / remaining * 2 or 0
      local gap = math.random() * max_gap * scatter
      gap_pool = math.max(0, gap_pool - gap)
      cursor = math.min(target_duration, cursor + gap)
      output_start = clamp(cursor, 0, math.max(0, target_duration - 0.001))
      cursor = cursor + slice.length
    end

    local base_u = target_duration > 0 and (output_start / target_duration) or 0
    local shaped_u = shape_time_u(index, #order, base_u, shape_mode, scatter)
    local density_u = map_u_by_density(shaped_u, density_points)
    output_start = clamp(density_u * target_duration, 0, math.max(0, target_duration - 0.001))
    local keep_probability = density_keep_probability(density_points, density_u, density_contrast)
    if math.random() <= keep_probability then
      local channel = shape_channel(index, channel_walk(index, output_channels,
        arrange_mode == ARRANGE_SCATTER and PATH_RANDOM or path_mode), output_channels, shape_mode)
      local base_length = math.min(slice.length, math.max(0.001, target_duration - output_start))

      if arrange_mode == ARRANGE_STUTTER then
        local repeat_length = math.min(base_length, math.max(0.001, stutter_gap > 0 and stutter_gap or base_length))
        for repeat_index = 1, stutter_repeats do
          local repeat_start = output_start + (repeat_index - 1) * stutter_gap
          if repeat_start < target_duration then
            local repeat_channel = shape_channel(index + repeat_index - 1,
              channel_walk(index + repeat_index - 1, output_channels, path_mode), output_channels, shape_mode)
            add_motion_event(events, slice, index + repeat_index - 1, repeat_channel,
              repeat_start, math.min(repeat_length, target_duration - repeat_start),
              math.min(fade, repeat_length / 2), density_gain * (decay ^ (repeat_index - 1)),
              output_channels, spread_width, path_mode, shape_mode, channel_motion)
          end
        end
      elseif arrange_mode == ARRANGE_REPEATER then
        for repeat_index = 1, repeater_repeats do
          local repeat_start = output_start + (repeat_index - 1) * repeater_spacing
          if repeat_start < target_duration then
            local repeat_channel = shape_channel(index + repeat_index - 1,
              channel_walk(index + repeat_index - 1, output_channels, path_mode), output_channels, shape_mode)
            add_motion_event(events, slice, index + repeat_index - 1, repeat_channel,
              repeat_start, math.min(base_length, target_duration - repeat_start), fade,
              density_gain * (decay ^ (repeat_index - 1)), output_channels, spread_width, path_mode, shape_mode,
              channel_motion)
          end
        end
      else
        add_motion_event(events, slice, index, channel, output_start, base_length, fade, density_gain,
          output_channels, spread_width, path_mode, shape_mode, channel_motion)
      end
    end
  end

  return events
end

local function render_events(sources, output_channels, events, target_start, target_duration)
  if #events == 0 then
    mc.show_error("No events were generated.")
    return false
  end

  local source_track = reaper.GetMediaItemTrack(sources[1].item)
  local insert_index = mc.get_insert_index_after_track(source_track)
  local temp_tracks = {}
  local did_render = false

  reaper.Undo_BeginBlock()
  mc.with_ui_refresh_block(function()
    for channel = 1, output_channels do
      temp_tracks[channel] = mc.insert_track_at(insert_index + channel - 1,
        "tmp scatter slices ch " .. tostring(channel), 2)
      reaper.SetMediaTrackInfo_Value(temp_tracks[channel], "B_MAINSEND", 0)
    end

    for _, event in ipairs(events) do
      create_fragment(event.source, temp_tracks[event.output_channel], event.input_channel,
        event.source_start, target_start + event.output_start, event.length, event.fade, event.gain)
    end

    local bus = mc.insert_track_at(insert_index + output_channels,
      "Scatter slices bus (" .. tostring(output_channels) .. "ch)",
      mc.reaper_track_channel_count(output_channels))
    for channel, temp_track in ipairs(temp_tracks) do
      mc.create_postfx_send(temp_track, bus, 1, channel - 1)
    end

    mc.select_only_track(bus)
    mc.with_render_bounds_for_range(target_start, target_start + target_duration, function()
      local before_guids = mc.snapshot_track_guids()
      local before_count = reaper.CountTracks(mc.PROJECT)
      reaper.Main_OnCommand(mc.render_multichannel_post_fader_stem_command(), 0)
      did_render = reaper.CountTracks(mc.PROJECT) > before_count

      if did_render then
        local excluded_tracks = { bus }
        for _, temp_track in ipairs(temp_tracks) do excluded_tracks[#excluded_tracks + 1] = temp_track end
        local rendered_track = mc.find_new_track(before_guids) or mc.get_selected_track_excluding(excluded_tracks)
        if rendered_track then
          reaper.GetSetMediaTrackInfo_String(rendered_track, "P_NAME",
            "Scatter slices render (" .. tostring(output_channels) .. "ch)", true)
          reaper.SetMediaTrackInfo_Value(rendered_track, "I_NCHAN", mc.reaper_track_channel_count(output_channels))
          mc.set_track_items_length(rendered_track, target_duration)
          local rendered_start = mc.track_items_bounds({ rendered_track })
          mc.move_track_items_by(rendered_track, target_start - rendered_start)
          mc.select_only_track(rendered_track)
        end
      end
    end)

    if did_render then
      if reaper.ValidatePtr2(mc.PROJECT, bus, "MediaTrack*") then reaper.DeleteTrack(bus) end
      for index = #temp_tracks, 1, -1 do
        if reaper.ValidatePtr2(mc.PROJECT, temp_tracks[index], "MediaTrack*") then
          reaper.DeleteTrack(temp_tracks[index])
        end
      end
    end
  end)
  reaper.Undo_EndBlock("Scatter slices", -1)

  return did_render
end

local function run_process(sources, target_duration, output_channels, slice_mode, equal_count, source_mode, one_channel,
  arrange_mode, shape_mode, path_mode, spread_width, fade, zero_window, scatter, stutter_repeats, stutter_gap,
  repeater_repeats, repeater_spacing, decay, density_points, density_contrast, channel_motion, seed)
  if target_duration <= 0 then mc.show_error("Target duration must be greater than zero.") return end
  if #sources == 0 then mc.show_error("Select one or more audio media items.") return end
  math.randomseed(seed > 0 and seed or os.time())

  local slices, total_duration, scheduled_duration = collect_slices(sources, slice_mode, equal_count, source_mode, one_channel, zero_window)
  if #slices == 0 then
    mc.show_error("No slices were found. For marker slicing, add project markers or active-take markers inside selected items.")
    return
  end

  local density = math.max(1, scheduled_duration / target_duration)
  local repeat_density = arrange_mode == ARRANGE_STUTTER and stutter_repeats or
    (arrange_mode == ARRANGE_REPEATER and repeater_repeats or 1)
  local motion_density = channel_motion > 0.55 and 3 or (channel_motion > 0 and 2 or 1)
  local channel_density = math.max(1, (#slices * spread_width * repeat_density * motion_density) / math.max(1, output_channels * 8))
  local density_gain = 1 / math.sqrt(density * channel_density)
  local events = assign_events(slices, scheduled_duration, target_duration, output_channels, fade, scatter, density_gain,
    arrange_mode, shape_mode, path_mode, spread_width, stutter_repeats, stutter_gap, repeater_repeats,
    repeater_spacing, decay, density_points, density_contrast, channel_motion)
  if #events == 0 then
    mc.show_error("The density envelope rejected every event. Raise low envelope points or reduce density contrast.")
    return
  end
  local target_start = sources[1].position
  local did_render = render_events(sources, output_channels, events, target_start, target_duration)

  if did_render then
    mc.print_plan("Scatter Slices", {
      "Selected source items: " .. tostring(#sources),
      "Slice events: " .. tostring(#events),
      "Unique source duration: " .. string.format("%.3f sec", total_duration),
      "Scheduled slice duration: " .. string.format("%.3f sec", scheduled_duration),
      "Target duration: " .. string.format("%.3f sec", target_duration),
      "Output channels: " .. tostring(output_channels),
      "Arrangement: " .. (ARRANGE_NAMES[arrange_mode] or "?"),
      "Shape: " .. (SHAPE_NAMES[shape_mode] or "?"),
      "Path: " .. (PATH_NAMES[path_mode] or "?"),
      "Spread width: " .. tostring(spread_width),
      "Channel motion: " .. string.format("%.2f", channel_motion),
      "Fade: " .. string.format("%.4f sec", fade),
      "Zero-crossing search: " .. string.format("%.4f sec", zero_window),
      "Density contrast: " .. string.format("%.2f", density_contrast),
      "Gain compensation: " .. string.format("%.3f", density_gain),
    })
  else
    reaper.ShowConsoleMsg("Built scatter routing, but REAPER did not report a new rendered stem track.\n")
  end
end

local function main()
  local sources = get_selected_audio_items()
  if #sources == 0 then
    mc.show_error("Select one or more audio media items.")
    return
  end

  local total_length = 0
  local max_channels = 1
  for _, source in ipairs(sources) do
    total_length = total_length + source.length
    max_channels = math.max(max_channels, source.channels)
  end

  local ctx = ImGui.CreateContext("Scatter Slices")
  local open = true
  local should_render = false
  local target_duration = math.max(1, total_length)
  local output_channels = math.min(math.max(8, max_channels), mc.MAX_REAPER_TRACK_CHANNELS)
  local slice_mode = SLICE_EQUAL
  local equal_count = 12
  local source_mode = SOURCE_ALL_CHANNELS
  local one_channel = 1
  local arrange_mode = ARRANGE_SCATTER
  local shape_mode = SHAPE_FREE
  local path_mode = PATH_PINGPONG
  local spread_width = 1
  local channel_motion = 0.35
  local fade = 0.005
  local zero_window = 0.002
  local scatter = 0.75
  local stutter_repeats = 4
  local stutter_gap = 0.035
  local repeater_repeats = 3
  local repeater_spacing = 0.15
  local decay = 0.78
  local density_contrast = 2.2
  local density_points = {}
  local selected_density_point = nil
  local seed = 0
  reset_density_points(density_points, "flat")

  local function loop()
    ImGui.SetNextWindowSize(ctx, 640, 760, ImGui.Cond_Appearing)
    local visible
    visible, open = ImGui.Begin(ctx, "Scatter Slices", open)

    if visible then
      local footer_h = 54
      local control_h = math.max(260, ImGui.GetWindowHeight(ctx) - footer_h)
      if ImGui.BeginChild(ctx, "##scatter_slices_controls", 0, control_h) then
      ImGui.Text(ctx, "Sources: " .. tostring(#sources) .. " selected audio item(s)")
      ImGui.Text(ctx, "Combined source length: " .. string.format("%.3f sec", total_length))
      ImGui.Spacing(ctx)

      local changed
      if ImGui.CollapsingHeader(ctx, "Render Setup", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        changed, target_duration = ImGui.SliderDouble(ctx, "Target duration sec", target_duration, 0.1, math.max(0.1, total_length * 4), "%.3f")
        changed, output_channels = ImGui.SliderInt(ctx, "Output channels", output_channels, 2, mc.MAX_REAPER_TRACK_CHANNELS)
      end
      if ImGui.CollapsingHeader(ctx, "Slice Source", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        changed, slice_mode = draw_combo(ctx, "Slice source", slice_mode, SLICE_NAMES, SLICE_EQUAL, SLICE_MARKERS)
        if slice_mode == SLICE_EQUAL then
          changed, equal_count = ImGui.SliderInt(ctx, "Equal slices per item", equal_count, 2, 256)
        else
          ImGui.Text(ctx, "Uses project markers and active-take markers inside each item.")
        end
        changed, source_mode = draw_combo(ctx, "Source channels", source_mode, SOURCE_NAMES, SOURCE_ALL_CHANNELS, SOURCE_ONE_CHANNEL)
        if source_mode == SOURCE_ONE_CHANNEL then
          changed, one_channel = ImGui.SliderInt(ctx, "Source channel", one_channel, 1, max_channels)
        end
      end
      if ImGui.CollapsingHeader(ctx, "Arrangement", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        changed, arrange_mode = draw_combo(ctx, "Arrangement", arrange_mode, ARRANGE_NAMES, ARRANGE_SCATTER, ARRANGE_REPEATER)
        changed, shape_mode = draw_combo(ctx, "Arrangement shape", shape_mode, SHAPE_NAMES, SHAPE_FREE, SHAPE_REVERSE_PULL)
        if arrange_mode ~= ARRANGE_SCATTER or channel_motion > 0 then
          changed, path_mode = draw_combo(ctx, "Channel path", path_mode, PATH_NAMES, PATH_CLOCKWISE, PATH_RANDOM)
        end
        changed, spread_width = ImGui.SliderInt(ctx, "Smear width", spread_width, 1, math.min(output_channels, 32))
        changed, channel_motion = ImGui.SliderDouble(ctx, "Channel motion", channel_motion, 0, 1, "%.2f")
        if arrange_mode == ARRANGE_STUTTER then
          changed, stutter_repeats = ImGui.SliderInt(ctx, "Stutter repeats", stutter_repeats, 1, 32)
          changed, stutter_gap = ImGui.SliderDouble(ctx, "Stutter gap sec", stutter_gap, 0, 1, "%.3f")
          changed, decay = ImGui.SliderDouble(ctx, "Repeat decay", decay, 0, 1, "%.2f")
        elseif arrange_mode == ARRANGE_REPEATER then
          changed, repeater_repeats = ImGui.SliderInt(ctx, "Repeater copies", repeater_repeats, 1, 32)
          changed, repeater_spacing = ImGui.SliderDouble(ctx, "Repeater spacing sec", repeater_spacing, 0, 2, "%.3f")
          changed, decay = ImGui.SliderDouble(ctx, "Repeat decay", decay, 0, 1, "%.2f")
        end
        changed, scatter = ImGui.SliderDouble(ctx, "Scatter", scatter, 0, 1, "%.2f")
        changed, fade = ImGui.SliderDouble(ctx, "Fade seconds", fade, 0, 0.1, "%.4f")
        changed, zero_window = ImGui.SliderDouble(ctx, "Zero-cross search", zero_window, 0, 0.02, "%.4f")
        changed, seed = ImGui.InputInt(ctx, "Seed (0=random)", seed)
      end
      if ImGui.CollapsingHeader(ctx, "Density Envelope", nil, ImGui.TreeNodeFlags_DefaultOpen) then
        ImGui.Spacing(ctx)
        selected_density_point = draw_density_editor(ctx, density_points, selected_density_point)
        changed, density_contrast = ImGui.SliderDouble(ctx, "Density contrast", density_contrast, 0, 4, "%.2f")
      end

      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Spacing(ctx)
      if target_duration < total_length then
        ImGui.Text(ctx, "Short target: slices overlap with gain compensation.")
      elseif arrange_mode == ARRANGE_STUTTER then
        ImGui.Text(ctx, "Stutter: each slice prints short repeats along the channel path.")
      elseif arrange_mode == ARRANGE_REPEATER then
        ImGui.Text(ctx, "Repeater: each slice leaves delayed decaying copies along the channel path.")
      elseif shape_mode ~= SHAPE_FREE then
        ImGui.Text(ctx, "Shape: " .. (SHAPE_NAMES[shape_mode] or "") .. " guides timing and channel placement.")
      elseif channel_motion > 0 then
        ImGui.Text(ctx, "Motion: staggered shadows imply movement between output channels.")
      elseif spread_width > 1 then
        ImGui.Text(ctx, "Smear: each slice spreads to neighboring output channels.")
      else
        ImGui.Text(ctx, "Long target: slices receive scattered gaps across the duration.")
      end
      ImGui.EndChild(ctx)
      end

      if ImGui.Button(ctx, "Render", 92, 26) then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 92, 26) then open = false end
      ImGui.End(ctx)
    end

    if should_render then
      open = false
      run_process(sources, target_duration, output_channels, slice_mode, equal_count,
        source_mode, one_channel, arrange_mode, shape_mode, path_mode, spread_width, fade, zero_window, scatter,
        stutter_repeats, stutter_gap, repeater_repeats, repeater_spacing, decay, density_points, density_contrast,
        channel_motion, seed)
      return
    end

    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
