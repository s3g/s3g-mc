-- @description Generate Polymetric MIDI Lanes
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; MIDI Rule Library.lua
-- @category MIDI Composition
-- @render No
-- @method Creates a new MIDI item with multiple polymetric Euclidean lanes. Each lane can use a different step count and pulse count, and lanes are mapped to MIDI channels for Carto/Spectra source focus or general multichannel synth control.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local midi = dofile(script_dir .. "MIDI Rule Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Generate Polymetric MIDI Lanes", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "Generate Polymetric MIDI Lanes"
local ctx = ImGui.CreateContext(TITLE)
local open = true
local status = ""

local lane_count = 8
local duration_beats = 32
local root_index = 1
local scale_index = 2
local base_octave = 3
local lane_spread = 2
local seed = 1
local density = 0.95
local note_len = 0.55
local velocity = 82
local velocity_slope = 4

local lanes = {}
for i = 1, 16 do
  lanes[i] = {
    steps = 8 + i,
    pulses = 2 + (i % 5),
    rotate = i - 1,
    degree = (i - 1) * 2,
    muted = i > 8,
  }
end

local function color(r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

local COLORS = {
  panel = color(0.055, 0.060, 0.064, 1),
  edge = color(0.30, 0.32, 0.33, 1),
  grid = color(0.50, 0.55, 0.54, 0.20),
  dim = color(0.50, 0.55, 0.54, 1),
  lane = color(0.26, 0.74, 0.70, 1),
  hit = color(0.95, 0.74, 0.28, 1),
  muted = color(0.22, 0.24, 0.25, 1),
}

local RING_COLORS = {
  color(1.00, 0.78, 0.18, 1),
  color(0.08, 0.78, 0.92, 1),
  color(0.96, 0.22, 0.34, 1),
  color(0.26, 0.86, 0.36, 1),
  color(0.70, 0.42, 1.00, 1),
  color(1.00, 0.45, 0.08, 1),
  color(0.24, 0.48, 1.00, 1),
  color(0.90, 0.92, 0.22, 1),
}

local function ring_color(index)
  return RING_COLORS[((index - 1) % #RING_COLORS) + 1]
end

local function point_on_circle(cx, cy, radius, step, steps)
  local angle = -math.pi * 0.5 + (math.pi * 2 * step / math.max(1, steps))
  return cx + math.cos(angle) * radius, cy + math.sin(angle) * radius
end

local function draw_lane_preview()
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  local h = 320
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, COLORS.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, COLORS.edge)

  local legend_w = 150
  local cx = x + (w - legend_w) * 0.5
  local cy = y + h * 0.54
  local max_r = math.max(34, math.min(w - legend_w, h - 38) * 0.5 - 12)
  local spacing = math.max(7, math.min(20, (max_r - 14) / math.max(1, lane_count)))

  ImGui.DrawList_AddText(draw_list, x + 12, y + 10, COLORS.dim, "POLYMETRIC RINGS")
  for i = 1, lane_count do
    local lane = lanes[i]
    local radius = max_r - (i - 1) * spacing
    if radius < 14 then break end
    local col = lane.muted and COLORS.dim or ring_color(i)
    ImGui.DrawList_AddCircle(draw_list, cx, cy, radius, lane.muted and COLORS.muted or COLORS.grid, 96, 1)
    if not lane.muted then
      local pattern = midi.euclidean_pattern(lane.pulses, lane.steps, lane.rotate)
      local hit_points = {}
      for step = 1, lane.steps do
        local p1x, p1y = point_on_circle(cx, cy, radius - 3, step - 1, lane.steps)
        local p2x, p2y = point_on_circle(cx, cy, radius + 3, step - 1, lane.steps)
        ImGui.DrawList_AddLine(draw_list, p1x, p1y, p2x, p2y, pattern[step] and col or COLORS.grid, 1)
        if pattern[step] then
          local hx, hy = point_on_circle(cx, cy, radius - spacing * 0.42, step - 1, lane.steps)
          hit_points[#hit_points + 1] = { x = hx, y = hy }
          ImGui.DrawList_AddCircleFilled(draw_list, hx, hy, 3.4, col)
        end
      end
      for p = 1, #hit_points do
        local a = hit_points[p]
        local b = hit_points[(p % #hit_points) + 1]
        if b then ImGui.DrawList_AddLine(draw_list, a.x, a.y, b.x, b.y, col, 1.1) end
      end
    end
    local label_y = y + 34 + (i - 1) * 16
    if label_y < y + h - 8 then
      ImGui.DrawList_AddRectFilled(draw_list, x + w - legend_w + 14, label_y - 8, x + w - legend_w + 23, label_y + 1, col)
      ImGui.DrawList_AddText(draw_list, x + w - legend_w + 30, label_y - 10, lane.muted and COLORS.dim or col,
        "ch " .. tostring(i) .. "  " .. tostring(lane.pulses) .. "/" .. tostring(lane.steps))
    end
  end
  ImGui.SetCursorScreenPos(ctx, x, y + h + 12)
end

local function write_midi()
  midi.seed(seed)
  local track = midi.ensure_track()
  if not track then midi.show_error("Could not find or create a track.", TITLE) return end
  local start_qn, _ = midi.time_selection_or_cursor_qn(duration_beats)
  local end_qn = start_qn + duration_beats
  local item, take = midi.create_midi_item(track, start_qn, end_qn, "Polymetric MIDI Lanes")
  if not take then midi.show_error("Could not create MIDI item.", TITLE) return end

  local root = midi.ROOT_NAMES[root_index]
  local scale = midi.SCALE_NAMES[scale_index]
  local event_count = 0
  for i = 1, lane_count do
    local lane = lanes[i]
    if not lane.muted then
      local pattern = midi.euclidean_pattern(lane.pulses, lane.steps, lane.rotate)
      local step_beats = duration_beats / math.max(1, lane.steps)
      local pitch = midi.scale_pitch(root, scale, lane.degree, base_octave, lane_spread)
      local hit_index = 0
      for step = 1, lane.steps do
        if pattern[step] and midi.chance(density) then
          hit_index = hit_index + 1
          local note_start = start_qn + (step - 1) * step_beats
          local note_end = note_start + step_beats * note_len
          local vel = midi.velocity(velocity + (i - 1) * velocity_slope, 18, hit_index, 4, 6)
          midi.insert_note_qn(take, note_start, note_end, i - 1, pitch, vel)
          event_count = event_count + 1
        end
      end
    end
  end
  reaper.MIDI_Sort(take)
  reaper.UpdateArrange()
  status = "Wrote " .. tostring(event_count) .. " notes across " .. tostring(lane_count) .. " lanes."
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 860, 760, ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    draw_lane_preview()
    local changed
    changed, lane_count = ImGui.SliderInt(ctx, "Lanes / MIDI channels", lane_count, 1, 16)
    changed, duration_beats = ImGui.SliderDouble(ctx, "Duration beats", duration_beats, 1, 256, "%.1f")
    ImGui.SetNextItemWidth(ctx, 90)
    changed, root_index = ImGui.Combo(ctx, "Root", root_index, table.concat(midi.ROOT_NAMES, "\0") .. "\0")
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 170)
    changed, scale_index = ImGui.Combo(ctx, "Scale", scale_index, table.concat(midi.SCALE_NAMES, "\0") .. "\0")
    changed, base_octave = ImGui.SliderInt(ctx, "Base octave", base_octave, 0, 8)
    changed, lane_spread = ImGui.SliderInt(ctx, "Lane register span", lane_spread, 1, 6)
    changed, density = ImGui.SliderDouble(ctx, "Density", density, 0, 1, "%.3f")
    changed, note_len = ImGui.SliderDouble(ctx, "Note length", note_len, 0.05, 1.5, "%.2f steps")
    changed, velocity = ImGui.SliderInt(ctx, "Base velocity", velocity, 1, 127)
    changed, velocity_slope = ImGui.SliderInt(ctx, "Lane velocity slope", velocity_slope, -10, 10)
    changed, seed = ImGui.InputInt(ctx, "Seed", seed)

    ImGui.Separator(ctx)
    if ImGui.BeginChild(ctx, "##lanes", 0, 260) then
      for i = 1, lane_count do
        local lane = lanes[i]
        ImGui.PushID(ctx, i)
        changed, lane.muted = ImGui.Checkbox(ctx, "Mute", lane.muted)
        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, 90)
        changed, lane.steps = ImGui.SliderInt(ctx, "Steps", lane.steps, 1, 64)
        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, 90)
        lane.pulses = math.min(lane.pulses, lane.steps)
        changed, lane.pulses = ImGui.SliderInt(ctx, "Pulses", lane.pulses, 0, lane.steps)
        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, 90)
        changed, lane.rotate = ImGui.SliderInt(ctx, "Rotate", lane.rotate, -lane.steps, lane.steps)
        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, 90)
        changed, lane.degree = ImGui.SliderInt(ctx, "Degree", lane.degree, -24, 48)
        ImGui.PopID(ctx)
      end
      ImGui.EndChild(ctx)
    end

    if ImGui.Button(ctx, "Generate MIDI Item", 160, 30) then write_midi() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Reset Lanes", 110, 30) then
      for i = 1, 16 do
        lanes[i].steps = 8 + i
        lanes[i].pulses = 2 + (i % 5)
        lanes[i].rotate = i - 1
        lanes[i].degree = (i - 1) * 2
        lanes[i].muted = i > lane_count
      end
    end
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, COLORS.dim, status)
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
