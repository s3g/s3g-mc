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

local function draw_combo(ImGui, ctx, label, current, names)
  if ImGui.BeginCombo(ctx, label, names[current] or "") then
    for index, name in ipairs(names) do
      local selected = index == current
      if ImGui.Selectable(ctx, name, selected) then current = index end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return current
end

local function draw_overview(ImGui, ctx, defs, points, enabled, selected, selected_point, current_values, opts)
  local width = math.max(320, ImGui.GetContentRegionAvail(ctx) - 2)
  local lane_h = opts.overview_lane_h or 54
  local gap = 6
  local height = #defs * lane_h + math.max(0, #defs - 1) * gap
  ImGui.InvisibleButton(ctx, "##breakpoint_overview", width, height)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, _y1 = ImGui.GetItemRectMax(ctx)
  local hovered = ImGui.IsItemHovered(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local mx, my = ImGui.GetMousePos(ctx)
  local c_bg = color(ImGui, 0.040, 0.044, 0.046, 1)
  local c_bg_active = color(ImGui, 0.070, 0.066, 0.052, 1)
  local c_grid = color(ImGui, 0.50, 0.56, 0.56, 0.09)
  local c_edge = color(ImGui, 0.55, 0.60, 0.58, 0.28)
  local c_selected = color(ImGui, 1.00, 0.88, 0.38, 0.95)
  local c_active = color(ImGui, 0.90, 0.72, 0.32, 0.95)
  local c_inactive = color(ImGui, 0.52, 0.56, 0.55, 0.45)
  local c_text = color(ImGui, 0.72, 0.76, 0.74, 1)
  local plot_x0 = x0 + 118
  local plot_x1 = x1 - 10
  local drag_env = opts.overview_drag_env
  local drag_point = opts.overview_drag_point

  local function move_point(index, point_index, lane_y0, lane_y1)
    local p = points[index]
    local point = p and p[point_index]
    if not point then return selected, selected_point end
    if point_index > 1 and point_index < #p then
      point.x = M.clamp((mx - plot_x0) / math.max(1, plot_x1 - plot_x0), 0, 1)
    end
    point.y = M.clamp((lane_y1 - 8 - my) / math.max(1, (lane_y1 - 8) - (lane_y0 + 8)), 0, 1)
    M.sort(p)
    return index, point_index
  end

  for index, def in ipairs(defs) do
    local ly0 = y0 + (index - 1) * (lane_h + gap)
    local ly1 = ly0 + lane_h
    local active = enabled[index]
    local is_selected = index == selected
    ImGui.DrawList_AddRectFilled(dl, x0, ly0, x1, ly1, active and c_bg_active or c_bg)
    ImGui.DrawList_AddRect(dl, x0, ly0, x1, ly1, is_selected and c_selected or c_edge, 0, 0, is_selected and 2 or 1)
    for grid = 1, 3 do
      local gx = M.lerp(plot_x0, plot_x1, grid / 4)
      ImGui.DrawList_AddLine(dl, gx, ly0 + 5, gx, ly1 - 5, c_grid, 1)
    end
    ImGui.DrawList_AddText(dl, x0 + 8, ly0 + 8, c_text, def.label)

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
        ImGui.DrawList_AddCircleFilled(dl, px, py, selected_here and 5.7 or (is_selected and 4.6 or 3.8),
          selected_here and c_selected or (is_selected and c_selected or c_active))
      end
    end

    if hovered and mx >= x0 and mx <= x1 and my >= ly0 and my <= ly1 and ImGui.IsMouseClicked(ctx, 0) then
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
        selected, selected_point = move_point(selected, selected_point, ly0, ly1)
      end
    end
  end

  if drag_env and drag_point and ImGui.IsMouseDown(ctx, 0) then
    local index = drag_env
    local ly0 = y0 + (index - 1) * (lane_h + gap)
    local ly1 = ly0 + lane_h
    selected, selected_point = move_point(index, drag_point, ly0, ly1)
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
  if opts.collapse_editor then
    local was_open = opts._editor_was_open
    editor_open = ImGui.CollapsingHeader(ctx, opts.editor_label or "Detailed Breakpoint Editor")
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
  selected = draw_combo(ImGui, ctx, "Envelope", selected, names)
  local def = defs[selected]
  local p = points[selected]
  enabled[selected] = select(2, ImGui.Checkbox(ctx, "Active envelope", enabled[selected]))

  local base = M.norm(def, current_values[def.key] or def.default or def.min)
  if ImGui.Button(ctx, "Flat") then M.set_shape(p, "flat", base) selected_point = nil end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Rise") then M.set_shape(p, "rise", base) enabled[selected] = true selected_point = nil end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Fall") then M.set_shape(p, "fall", base) enabled[selected] = true selected_point = nil end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Ridge") then M.set_shape(p, "ridge", base) enabled[selected] = true selected_point = nil end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Valley") then M.set_shape(p, "valley", base) enabled[selected] = true selected_point = nil end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Terrace") then M.set_shape(p, "terrace", base) enabled[selected] = true selected_point = nil end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Switchback") then M.set_shape(p, "switchback", base) enabled[selected] = true selected_point = nil end

  opts.random_count = select(2, ImGui.SliderInt(ctx, "Random points", math.floor(opts.random_count), 4, 32))
  opts.random_amount = select(2, ImGui.SliderDouble(ctx, "Random amount", opts.random_amount, 0.0, 1.0, "%.2f"))
  opts.random_dispersion = select(2, ImGui.SliderDouble(ctx, "Random dispersion", opts.random_dispersion, 0.0, 1.0, "%.2f"))
  opts.random_smooth = select(2, ImGui.Checkbox(ctx, "Smooth random", opts.random_smooth))
  if ImGui.Button(ctx, "Random selected") then
    M.randomize_set(defs, points, enabled, current_values, "selected", selected, opts)
    selected_point = nil
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Random all") then
    M.randomize_set(defs, points, enabled, current_values, "all", selected, opts)
    selected_point = nil
  end

  local width = math.max(320, ImGui.GetContentRegionAvail(ctx) - 2)
  local height = opts.height or 150
  ImGui.InvisibleButton(ctx, "##breakpoint_editor", width, height)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = ImGui.GetItemRectMax(ctx)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local c_bg = color(ImGui, 0.045, 0.050, 0.052, 1)
  local c_grid = color(ImGui, 0.50, 0.56, 0.56, 0.14)
  local c_line = color(ImGui, 0.90, 0.72, 0.32, enabled[selected] and 1 or 0.45)
  local c_fill = color(ImGui, 0.90, 0.72, 0.32, enabled[selected] and 0.15 or 0.06)
  local c_point = color(ImGui, 0.94, 0.88, 0.64, 1)
  local c_selected = color(ImGui, 1.00, 0.96, 0.42, 1)
  local c_edge = color(ImGui, 0.55, 0.60, 0.58, 0.35)
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
    ImGui.DrawList_AddCircleFilled(dl, px, py, index == selected_point and 6.5 or 4.8, index == selected_point and c_selected or c_point)
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
  if ImGui.Button(ctx, "Add point") and #p < 32 then
    p[#p + 1] = { x = 0.5, y = base }
    selected_point = #p
    enabled[selected] = true
    M.sort(p)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Delete point") and selected_point and selected_point > 1 and selected_point < #p then
    table.remove(p, selected_point)
    selected_point = nil
    M.sort(p)
  end

  if selected_point and p[selected_point] then
    ImGui.SameLine(ctx)
    local point = p[selected_point]
    ImGui.Text(ctx, string.format("t %.2f / " .. (def.fmt or "%.3f"), point.x, M.value(def, point.y)))
  end

  return selected, selected_point
end

return M
