-- @description Breakpoint Envelope Library
-- @browser hidden

local M = {}

local function color(ImGui, r, g, b, a)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1)
end

function M.clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

function M.lerp(a, b, t)
  return a + (b - a) * t
end

function M.norm(def, value)
  if def.max == def.min then return 0 end
  return M.clamp(((value or def.min) - def.min) / (def.max - def.min), 0, 1)
end

function M.value(def, y)
  return M.lerp(def.min, def.max, M.clamp(y or 0, 0, 1))
end

function M.sort(points)
  if not points or #points == 0 then return end
  table.sort(points, function(a, b) return a.x < b.x end)
  points[1].x = 0
  points[#points].x = 1
  for index, point in ipairs(points) do
    point.y = M.clamp(point.y or 0, 0, 1)
    if index > 1 and index < #points then
      point.x = M.clamp(point.x or 0.5, points[index - 1].x + 0.01, points[index + 1].x - 0.01)
    end
  end
end

function M.set_points(points, values)
  for index = #points, 1, -1 do points[index] = nil end
  for index, pair in ipairs(values) do
    points[index] = { x = pair[1], y = pair[2] }
  end
  M.sort(points)
end

function M.set_shape(points, shape, base)
  base = M.clamp(base or 0.5, 0, 1)
  if shape == "rise" then
    M.set_points(points, { { 0, math.max(0, base * 0.20) }, { 1, math.min(1, base + 0.25) } })
  elseif shape == "fall" then
    M.set_points(points, { { 0, math.min(1, base + 0.25) }, { 1, math.max(0, base * 0.20) } })
  elseif shape == "ridge" then
    M.set_points(points, { { 0, math.max(0, base * 0.25) }, { 0.5, math.min(1, base + 0.35) }, { 1, math.max(0, base * 0.25) } })
  elseif shape == "valley" then
    M.set_points(points, { { 0, math.min(1, base + 0.25) }, { 0.5, math.max(0, base * 0.18) }, { 1, math.min(1, base + 0.25) } })
  elseif shape == "pulse" then
    M.set_points(points, { { 0, base }, { 0.18, base }, { 0.19, math.min(1, base + 0.35) }, { 0.58, math.min(1, base + 0.35) }, { 0.59, math.max(0, base * 0.25) }, { 1, math.max(0, base * 0.25) } })
  elseif shape == "terrace" then
    M.set_points(points, { { 0, base }, { 0.22, base }, { 0.23, math.min(1, base + 0.24) }, { 0.56, math.min(1, base + 0.24) }, { 0.57, math.max(0, base - 0.18) }, { 1, math.max(0, base - 0.18) } })
  elseif shape == "switchback" then
    M.set_points(points, { { 0, base }, { 0.18, math.max(0, base - 0.32) }, { 0.40, math.min(1, base + 0.32) }, { 0.64, math.max(0, base - 0.22) }, { 0.84, math.min(1, base + 0.24) }, { 1, base } })
  else
    M.set_points(points, { { 0, base }, { 1, base } })
  end
end

function M.randomize(points, base, amount, count, smooth, dispersion, seed)
  math.randomseed(seed or os.time())
  count = math.max(2, math.min(32, math.floor(count or 8)))
  amount = M.clamp(amount or 0.35, 0, 1)
  dispersion = M.clamp(dispersion or 0, 0, 1)
  for index = #points, 1, -1 do points[index] = nil end
  local xs = {}
  for index = 1, count do xs[index] = (index - 1) / math.max(1, count - 1) end
  for index = 2, count - 1 do
    local base_x = xs[index]
    local step = 1 / math.max(1, count - 1)
    xs[index] = M.clamp(base_x + (math.random() * 2 - 1) * step * dispersion * 1.6, 0.01, 0.99)
  end
  table.sort(xs)
  xs[1] = 0
  xs[#xs] = 1
  for index = 1, count do
    local wobble = (math.random() * 2 - 1) * amount
    points[index] = { x = xs[index], y = M.clamp((base or 0.5) + wobble, 0, 1) }
  end
  if smooth then
    for _ = 1, 2 do
      local ys = {}
      for index, point in ipairs(points) do ys[index] = point.y end
      for index = 2, #points - 1 do
        points[index].y = (ys[index - 1] + ys[index] * 2 + ys[index + 1]) / 4
      end
    end
  end
  M.sort(points)
end

function M.randomize_set(defs, points, enabled, current_values, scope, selected, opts)
  opts = opts or {}
  for index, def in ipairs(defs) do
    if scope == "all" or index == selected then
      local base = M.norm(def, current_values[def.key] or def.default or def.min)
      M.randomize(points[index], base, opts.random_amount, opts.random_count, opts.random_smooth, opts.random_dispersion, os.time() + index * 97)
      enabled[index] = true
    end
  end
end

function M.serialize(points)
  local parts = {}
  M.sort(points)
  for _, point in ipairs(points or {}) do
    parts[#parts + 1] = string.format("%.4f:%.4f", M.clamp(point.x or 0, 0, 1), M.clamp(point.y or 0, 0, 1))
  end
  return table.concat(parts, ";")
end

function M.parse(text)
  local points = {}
  for x, y in tostring(text or ""):gmatch("([%d%.%-]+):([%d%.%-]+)") do
    points[#points + 1] = { x = M.clamp(tonumber(x) or 0, 0, 1), y = M.clamp(tonumber(y) or 0, 0, 1) }
  end
  if #points < 2 then return nil end
  M.sort(points)
  return points
end

function M.init(defs, current_values)
  local points = {}
  local enabled = {}
  for index, def in ipairs(defs) do
    points[index] = {}
    enabled[index] = false
    M.set_shape(points[index], "flat", M.norm(def, current_values[def.key] or def.default or def.min))
  end
  return points, enabled
end

function M.load_extstate(section, defs, points, enabled)
  for index, def in ipairs(defs) do
    enabled[index] = reaper.GetExtState(section, "env_enabled_" .. def.key) == "1"
    local parsed = M.parse(reaper.GetExtState(section, "env_" .. def.key))
    if parsed then points[index] = parsed end
  end
end

function M.save_extstate(section, defs, points, enabled)
  for index, def in ipairs(defs) do
    reaper.SetExtState(section, "env_enabled_" .. def.key, enabled[index] and "1" or "0", true)
    reaper.SetExtState(section, "env_" .. def.key, M.serialize(points[index]), true)
  end
end

function M.add_to_manifest(manifest, defs, points, enabled)
  for index, def in ipairs(defs) do
    if enabled[index] then
      local parts = {}
      M.sort(points[index])
      for _, point in ipairs(points[index] or {}) do
        parts[#parts + 1] = string.format("%.4f:%.6f",
          M.clamp(point.x or 0, 0, 1),
          M.value(def, point.y))
      end
      manifest["env_" .. def.key] = table.concat(parts, ";")
    end
  end
end

local ROW_H = 25
local LABEL_W = 86
local CONTROL_GAP = 8
local VALUE_W = 76

local LABEL_ABBR = {
  ["ACTIVE ENVELOPE"] = "ACTIVE",
  ["ENVELOPE"] = "ENV",
  ["RANDOM POINTS"] = "POINTS",
  ["RANDOM AMOUNT"] = "AMOUNT",
  ["RANDOM DISPERSION"] = "DISP",
  ["SMOOTH RANDOM"] = "SMOOTH",
}

local function theme_module()
  local cached = package.loaded["s3g-mc ImGui Theme"]
  if cached then return cached end
  local ok, theme = pcall(require, "s3g-mc ImGui Theme")
  if ok then return theme end
  return nil
end

local function palette(ImGui)
  local theme = theme_module()
  if theme and theme.palette then return theme.palette(ImGui) end
  return {
    panel_soft = color(ImGui, 0.145, 0.145, 0.145, 1.0),
    frame = color(ImGui, 0.074, 0.074, 0.074, 1.0),
    frame_hover = color(ImGui, 0.074, 0.074, 0.074, 1.0),
    frame_active = color(ImGui, 0.195, 0.195, 0.195, 1.0),
    active = color(ImGui, 0.720, 0.720, 0.720, 1.0),
    active_hover = color(ImGui, 0.790, 0.790, 0.790, 1.0),
    fill = color(ImGui, 0.498, 0.498, 0.498, 1.0),
    label = color(ImGui, 0.659, 0.659, 0.659, 1.0),
    text = color(ImGui, 0.788, 0.788, 0.788, 1.0),
    value = color(ImGui, 0.572, 0.572, 0.572, 1.0),
    muted = color(ImGui, 0.560, 0.560, 0.560, 1.0),
  }
end

local function clean_label(label)
  return tostring(label or ""):gsub("##.*$", ""):upper():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function row_label(label)
  label = clean_label(label)
  return LABEL_ABBR[label] or label
end

local function row_layout(ImGui, ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local avail = math.max(220, ImGui.GetContentRegionAvail(ctx))
  local control_x = x + LABEL_W
  local control_w = math.max(52, avail - LABEL_W - VALUE_W - CONTROL_GAP)
  local value_x = control_x + control_w + CONTROL_GAP
  return x, y, avail, control_x, control_w, value_x
end

local function finish_row(ImGui, ctx, x, y, avail)
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.Dummy(ctx, avail, ROW_H)
  ImGui.SetCursorScreenPos(ctx, x, y + ROW_H)
end

local function text_width(ImGui, ctx, text)
  text = tostring(text or "")
  if ImGui.CalcTextSize then
    local ok, width = pcall(ImGui.CalcTextSize, ctx, text)
    if ok and type(width) == "number" then return width end
  end
  return #text * 7
end

local function combo_width(ImGui, ctx, names, current, max_width)
  local width = text_width(ImGui, ctx, names[current or 1] or "") + 38
  for _, name in ipairs(names or {}) do
    width = math.max(width, text_width(ImGui, ctx, name) + 38)
  end
  return math.max(80, math.min(max_width or width, width))
end

local function draw_row_label(ImGui, ctx, x, y, label)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 2, palette(ImGui).label, row_label(label))
end

local function draw_combo(ImGui, ctx, label, current, names)
  local x, y, avail, control_x, control_w = row_layout(ImGui, ctx)
  draw_row_label(ImGui, ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, combo_width(ImGui, ctx, names, current, control_w))
  if ImGui.BeginCombo(ctx, "##" .. tostring(label or ""), names[current] or "") then
    for index, name in ipairs(names) do
      local selected = index == current
      if ImGui.Selectable(ctx, name, selected) then current = index end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  finish_row(ImGui, ctx, x, y, avail)
  return current
end

local function draw_checkbox(ImGui, ctx, label, value)
  local x, y, avail, control_x = row_layout(ImGui, ctx)
  draw_row_label(ImGui, ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  local changed, next_value = ImGui.Checkbox(ctx, "##" .. tostring(label or ""), value)
  finish_row(ImGui, ctx, x, y, avail)
  return changed, next_value
end

local function format_value(value, fmt, integer)
  if integer then return tostring(math.floor(value + 0.5)) end
  return string.format(fmt or "%.3f", value)
end

local function draw_slider(ImGui, ctx, label, value, min_value, max_value, fmt, integer)
  local x, y, avail, control_x, control_w, value_x = row_layout(ImGui, ctx)
  local p = palette(ImGui)
  local norm = 0
  if max_value ~= min_value then norm = M.clamp((value - min_value) / (max_value - min_value), 0, 1) end
  local id = string.format("##breakpoint_slider_%s_%d_%d", tostring(label or ""), math.floor(x + 0.5), math.floor(y + 0.5))
  ImGui.InvisibleButton(ctx, id, avail, ROW_H)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local changed = false
  if (hovered or active) and ImGui.IsMouseDown(ctx, 0) then
    local mx = ImGui.GetMousePos(ctx)
    local next_norm = M.clamp((mx - control_x) / math.max(1, control_w), 0, 1)
    local next_value = min_value + (max_value - min_value) * next_norm
    if integer then next_value = math.floor(next_value + 0.5) end
    if math.abs(next_value - value) > (integer and 0 or 0.0000001) then
      value = next_value
      norm = next_norm
      changed = true
    end
  end

  local dl = ImGui.GetWindowDrawList(ctx)
  local track_y = y + 6
  local track_h = 8
  ImGui.DrawList_AddText(dl, x, y + 2, p.label, row_label(label))
  ImGui.DrawList_AddRectFilled(dl, control_x, track_y, control_x + control_w, track_y + track_h,
    active and p.frame_active or (hovered and p.frame_hover or p.frame))
  ImGui.DrawList_AddRectFilled(dl, control_x + 1, track_y + 1, control_x + math.max(2, control_w * norm), track_y + track_h - 1, p.fill)
  local handle_x = M.clamp(control_x + control_w * norm - 1.5, control_x + 1, control_x + control_w - 4)
  ImGui.DrawList_AddRectFilled(dl, handle_x, track_y - 2, handle_x + 3, track_y + track_h + 2,
    active and p.active_hover or p.active)
  ImGui.DrawList_AddText(dl, value_x, y + 2, p.value, format_value(value, fmt, integer))
  finish_row(ImGui, ctx, x, y, avail)
  return changed, value
end

local function begin_section(ImGui, ctx, label, height)
  local theme = theme_module()
  local stack = theme and theme.push_soft_panel and theme.push_soft_panel(ImGui, ctx) or nil
  local p = palette(ImGui)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + height, p.panel_soft)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + 2, p.active)
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 10)
  if theme and theme.text then
    theme.text(ImGui, ctx, clean_label(label))
  else
    ImGui.TextColored(ctx, p.label, clean_label(label))
  end
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 36)
  return x, y, height, stack
end

local function finish_section(ImGui, ctx, x, y, height, stack)
  local theme = theme_module()
  if theme and theme.pop_soft_panel then theme.pop_soft_panel(ImGui, ctx, stack) end
  ImGui.SetCursorScreenPos(ctx, x, y + height)
  ImGui.Dummy(ctx, 1, 10)
end

local function draw_square_handle(ImGui, dl, cx, cy, size, fill, edge, thickness)
  local half = size * 0.5
  ImGui.DrawList_AddRectFilled(dl, cx - half, cy - half, cx + half, cy + half, fill)
  ImGui.DrawList_AddRect(dl, cx - half, cy - half, cx + half, cy + half, edge, 0, 0, thickness or 1)
end

local function draw_overview(ImGui, ctx, defs, points, enabled, selected, selected_point, current_values, opts)
  local width = math.max(320, ImGui.GetContentRegionAvail(ctx) - 2)
  local lane_h = opts.overview_lane_h or 54
  local gap = 6
  local columns = opts.overview_columns or (#defs > 5 and 2 or 1)
  columns = math.max(1, math.min(columns, #defs))
  local rows = math.ceil(#defs / columns)
  local lane_w = math.max(150, (width - gap * (columns - 1)) / columns)
  local height = rows * lane_h + math.max(0, rows - 1) * gap
  ImGui.InvisibleButton(ctx, "##breakpoint_overview", width, height)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, _y1 = ImGui.GetItemRectMax(ctx)
  local hovered = ImGui.IsItemHovered(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local mx, my = ImGui.GetMousePos(ctx)
  local c_bg = color(ImGui, 0.040, 0.043, 0.046, 1)
  local c_bg_active = color(ImGui, 0.060, 0.064, 0.068, 1)
  local c_grid = color(ImGui, 0.56, 0.59, 0.60, 0.10)
  local c_edge = color(ImGui, 0.32, 0.34, 0.36, 0.62)
  local c_selected = color(ImGui, 0.82, 0.86, 0.88, 1.0)
  local c_active = color(ImGui, 0.62, 0.67, 0.69, 0.96)
  local c_inactive = color(ImGui, 0.42, 0.45, 0.46, 0.52)
  local c_handle_edge = color(ImGui, 0.08, 0.09, 0.10, 1)
  local c_text = color(ImGui, 0.70, 0.74, 0.75, 1)
  local drag_env = opts.overview_drag_env
  local drag_point = opts.overview_drag_point

  local function lane_rect(index)
    local col = (index - 1) % columns
    local row = math.floor((index - 1) / columns)
    local lx0 = x0 + col * (lane_w + gap)
    local ly0 = y0 + row * (lane_h + gap)
    return lx0, ly0, lx0 + lane_w, ly0 + lane_h
  end

  local function move_point(index, point_index, lane_x0, lane_y0, lane_x1, lane_y1)
    local p = points[index]
    local point = p and p[point_index]
    if not point then return selected, selected_point end
    local plot_x0 = lane_x0 + 118
    local plot_x1 = lane_x1 - 10
    if point_index > 1 and point_index < #p then
      point.x = M.clamp((mx - plot_x0) / math.max(1, plot_x1 - plot_x0), 0, 1)
    end
    point.y = M.clamp((lane_y1 - 8 - my) / math.max(1, (lane_y1 - 8) - (lane_y0 + 8)), 0, 1)
    M.sort(p)
    return index, point_index
  end

  for index, def in ipairs(defs) do
    local lx0, ly0, lx1, ly1 = lane_rect(index)
    local plot_x0 = lx0 + 118
    local plot_x1 = lx1 - 10
    local active = enabled[index]
    local is_selected = index == selected
    ImGui.DrawList_AddRectFilled(dl, lx0, ly0, lx1, ly1, active and c_bg_active or c_bg)
    ImGui.DrawList_AddRect(dl, lx0, ly0, lx1, ly1, is_selected and c_selected or c_edge, 0, 0, is_selected and 2 or 1)
    for grid = 1, 3 do
      local gx = M.lerp(plot_x0, plot_x1, grid / 4)
      ImGui.DrawList_AddLine(dl, gx, ly0 + 5, gx, ly1 - 5, c_grid, 1)
    end
    ImGui.DrawList_AddText(dl, lx0 + 8, ly0 + 8, c_text, def.label)

    local p = points[index]
    if not active then
      local base = M.norm(def, current_values[def.key] or def.default or def.min)
      p = { { x = 0, y = base }, { x = 1, y = base } }
    else
      M.sort(p)
    end
    local last_x, last_y
    for _, point in ipairs(p or {}) do
      local px = M.lerp(plot_x0, plot_x1, point.x)
      local py = M.lerp(ly1 - 8, ly0 + 8, point.y)
      if last_x then
        ImGui.DrawList_AddLine(dl, last_x, last_y, px, py, active and c_active or c_inactive, 2.0)
      end
      last_x, last_y = px, py
    end
    if active then
      for point_index, point in ipairs(p or {}) do
        local px = M.lerp(plot_x0, plot_x1, point.x)
        local py = M.lerp(ly1 - 8, ly0 + 8, point.y)
        local selected_here = is_selected and point_index == selected_point
        draw_square_handle(ImGui, dl, px, py, selected_here and 10.5 or (is_selected and 8.5 or 7.0),
          selected_here and c_selected or (is_selected and c_selected or c_active), c_handle_edge, selected_here and 1.5 or 1.0)
      end
    end

    if hovered and mx >= lx0 and mx <= lx1 and my >= ly0 and my <= ly1 and ImGui.IsMouseClicked(ctx, 0) then
      selected = index
      selected_point = nil
      enabled[index] = true
      local best_d = 999999
      for point_index, point in ipairs(points[index] or {}) do
        local px = M.lerp(plot_x0, plot_x1, point.x)
        local py = M.lerp(ly1 - 8, ly0 + 8, point.y)
        local d = (mx - px) * (mx - px) + (my - py) * (my - py)
        if d < best_d then
          best_d = d
          selected_point = point_index
        end
      end
      if (not selected_point or best_d > 256) and #points[index] < 32 then
        points[index][#points[index] + 1] = {
          x = M.clamp((mx - plot_x0) / math.max(1, plot_x1 - plot_x0), 0, 1),
          y = M.clamp((ly1 - 8 - my) / math.max(1, (ly1 - 8) - (ly0 + 8)), 0, 1),
        }
        M.sort(points[index])
        selected_point = nil
        local target_x = M.clamp((mx - plot_x0) / math.max(1, plot_x1 - plot_x0), 0, 1)
        local best = 999999
        for point_index, point in ipairs(points[index]) do
          local d = math.abs(point.x - target_x)
          if d < best then best = d selected_point = point_index end
        end
      end
      opts.overview_drag_env = selected
      opts.overview_drag_point = selected_point
      drag_env = selected
      drag_point = selected_point
      if selected_point then
        selected, selected_point = move_point(selected, selected_point, lx0, ly0, lx1, ly1)
      end
    end
  end

  if drag_env and drag_point and ImGui.IsMouseDown(ctx, 0) then
    local index = drag_env
    local lx0, ly0, lx1, ly1 = lane_rect(index)
    selected, selected_point = move_point(index, drag_point, lx0, ly0, lx1, ly1)
  elseif not ImGui.IsMouseDown(ctx, 0) then
    opts.overview_drag_env = nil
    opts.overview_drag_point = nil
  end

  return selected, selected_point
end

function M.draw(ImGui, ctx, defs, points, enabled, selected, selected_point, current_values, opts)
  opts = opts or {}
  opts.random_count = opts.random_count or 10
  opts.random_amount = opts.random_amount or 0.35
  opts.random_dispersion = opts.random_dispersion or 0.25
  opts.random_smooth = opts.random_smooth or false
  selected = math.max(1, math.min(#defs, selected or 1))
  selected, selected_point = draw_overview(ImGui, ctx, defs, points, enabled, selected, selected_point, current_values, opts)

  local editor_open = true
  if opts.collapse_editor ~= false then
    local was_open = opts._editor_was_open
    editor_open = ImGui.CollapsingHeader(ctx, clean_label(opts.editor_label or "Detailed Breakpoint Editor"))
    if was_open ~= nil and was_open ~= editor_open then
      local target_h = editor_open and opts.expanded_window_h or opts.compact_window_h
      local ok_get, get_window_size = pcall(function() return ImGui.GetWindowSize end)
      local ok_set, set_window_size = pcall(function() return ImGui.SetWindowSize end)
      if target_h and ok_get and ok_set and type(get_window_size) == "function" and type(set_window_size) == "function" then
        local window_w = select(1, get_window_size(ctx))
        set_window_size(ctx, window_w, target_h, ImGui.Cond_Always or 0)
      end
    end
    opts._editor_was_open = editor_open
  end
  if not editor_open then
    return selected, selected_point
  end

  local names = {}
  for index, def in ipairs(defs) do names[index] = def.label end

  local sx, sy, sh, stack = begin_section(ImGui, ctx, "Editor", 98)
  selected = draw_combo(ImGui, ctx, "Envelope", selected, names)
  local def = defs[selected]
  local p = points[selected]
  enabled[selected] = select(2, draw_checkbox(ImGui, ctx, "Active envelope", enabled[selected]))
  finish_section(ImGui, ctx, sx, sy, sh, stack)

  local base = M.norm(def, current_values[def.key] or def.default or def.min)
  sx, sy, sh, stack = begin_section(ImGui, ctx, "Shape", 95)
  if ImGui.Button(ctx, "FLAT") then M.set_shape(p, "flat", base) selected_point = nil end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "RISE") then M.set_shape(p, "rise", base) enabled[selected] = true selected_point = nil end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "FALL") then M.set_shape(p, "fall", base) enabled[selected] = true selected_point = nil end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "RIDGE") then M.set_shape(p, "ridge", base) enabled[selected] = true selected_point = nil end
  if ImGui.Button(ctx, "VALLEY") then M.set_shape(p, "valley", base) enabled[selected] = true selected_point = nil end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "TERRACE") then M.set_shape(p, "terrace", base) enabled[selected] = true selected_point = nil end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "SWITCHBACK") then M.set_shape(p, "switchback", base) enabled[selected] = true selected_point = nil end
  finish_section(ImGui, ctx, sx, sy, sh, stack)

  sx, sy, sh, stack = begin_section(ImGui, ctx, "Randomize", 173)
  opts.random_count = select(2, draw_slider(ImGui, ctx, "Random points", math.floor(opts.random_count), 4, 32, nil, true))
  opts.random_amount = select(2, draw_slider(ImGui, ctx, "Random amount", opts.random_amount, 0.0, 1.0, "%.2f", false))
  opts.random_dispersion = select(2, draw_slider(ImGui, ctx, "Random dispersion", opts.random_dispersion, 0.0, 1.0, "%.2f", false))
  opts.random_smooth = select(2, draw_checkbox(ImGui, ctx, "Smooth random", opts.random_smooth))
  if ImGui.Button(ctx, "RANDOM SELECTED") then
    M.randomize_set(defs, points, enabled, current_values, "selected", selected, opts)
    selected_point = nil
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "RANDOM ALL") then
    M.randomize_set(defs, points, enabled, current_values, "all", selected, opts)
    selected_point = nil
  end
  finish_section(ImGui, ctx, sx, sy, sh, stack)

  local width = math.max(320, ImGui.GetContentRegionAvail(ctx) - 2)
  local height = opts.height or 150
  ImGui.InvisibleButton(ctx, "##breakpoint_editor", width, height)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = ImGui.GetItemRectMax(ctx)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local c_bg = color(ImGui, 0.040, 0.043, 0.046, 1)
  local c_grid = color(ImGui, 0.56, 0.59, 0.60, 0.13)
  local c_line = color(ImGui, 0.66, 0.70, 0.72, enabled[selected] and 1 or 0.46)
  local c_fill = color(ImGui, 0.66, 0.70, 0.72, enabled[selected] and 0.13 or 0.05)
  local c_point = color(ImGui, 0.70, 0.74, 0.76, 1)
  local c_selected = color(ImGui, 0.90, 0.93, 0.94, 1)
  local c_handle_edge = color(ImGui, 0.08, 0.09, 0.10, 1)
  local c_edge = color(ImGui, 0.32, 0.34, 0.36, 0.68)
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x1, y1, c_bg)
  ImGui.DrawList_AddRect(dl, x0, y0, x1, y1, c_edge)
  for i = 1, 7 do
    local gx = M.lerp(x0, x1, i / 8)
    ImGui.DrawList_AddLine(dl, gx, y0, gx, y1, c_grid, 1)
  end
  for i = 1, 3 do
    local gy = M.lerp(y0, y1, i / 4)
    ImGui.DrawList_AddLine(dl, x0, gy, x1, gy, c_grid, 1)
  end

  M.sort(p)
  local last_x, last_y
  for _, point in ipairs(p) do
    local px = M.lerp(x0, x1, point.x)
    local py = M.lerp(y1, y0, point.y)
    if last_x then
      ImGui.DrawList_AddLine(dl, last_x, last_y, px, py, c_line, 2)
      ImGui.DrawList_AddTriangleFilled(dl, last_x, y1, px, y1, px, py, c_fill)
      ImGui.DrawList_AddTriangleFilled(dl, last_x, y1, last_x, last_y, px, py, c_fill)
    end
    last_x, last_y = px, py
  end
  for index, point in ipairs(p) do
    local px = M.lerp(x0, x1, point.x)
    local py = M.lerp(y1, y0, point.y)
    draw_square_handle(ImGui, dl, px, py, index == selected_point and 12.0 or 9.0,
      index == selected_point and c_selected or c_point, c_handle_edge, index == selected_point and 1.5 or 1.0)
  end

  local mx, my = ImGui.GetMousePos(ctx)
  if hovered and ImGui.IsMouseClicked(ctx, 0) then
    enabled[selected] = true
    selected_point = nil
    for index, point in ipairs(p) do
      local px = M.lerp(x0, x1, point.x)
      local py = M.lerp(y1, y0, point.y)
      if (mx - px) * (mx - px) + (my - py) * (my - py) < 100 then
        selected_point = index
        break
      end
    end
    if not selected_point and #p < 32 then
      p[#p + 1] = { x = M.clamp((mx - x0) / math.max(1, x1 - x0), 0, 1), y = M.clamp((y1 - my) / math.max(1, y1 - y0), 0, 1) }
      M.sort(p)
      for index, point in ipairs(p) do
        if math.abs(point.x - p[#p].x) < 0.0001 and math.abs(point.y - p[#p].y) < 0.0001 then selected_point = index break end
      end
    end
  end
  if selected_point and active and ImGui.IsMouseDown(ctx, 0) then
    local point = p[selected_point]
    if point then
      if selected_point > 1 and selected_point < #p then
        point.x = M.clamp((mx - x0) / math.max(1, x1 - x0), 0, 1)
      end
      point.y = M.clamp((y1 - my) / math.max(1, y1 - y0), 0, 1)
      M.sort(p)
    end
  end

  sx, sy, sh, stack = begin_section(ImGui, ctx, "Point", 86)
  if ImGui.Button(ctx, "ADD POINT") and #p < 32 then
    p[#p + 1] = { x = 0.5, y = base }
    selected_point = #p
    enabled[selected] = true
    M.sort(p)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "DELETE POINT") and selected_point and selected_point > 1 and selected_point < #p then
    table.remove(p, selected_point)
    selected_point = nil
    M.sort(p)
  end

  if selected_point and p[selected_point] then
    ImGui.SameLine(ctx)
    local point = p[selected_point]
    ImGui.TextColored(ctx, palette(ImGui).muted, string.format("T %.2f / " .. (def.fmt or "%.3f"), point.x, M.value(def, point.y)))
  end
  finish_section(ImGui, ctx, sx, sy, sh, stack)

  return selected, selected_point
end

return M
