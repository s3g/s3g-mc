-- @description IR Toolkit
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Offline Synthesis / IR
-- @render Yes; reshapes the selected impulse response item into a new media item.
-- @method Offline NumPy impulse-response utility. Select one WAV-backed impulse item, then trim silence, fade the tail, normalize, add sparse early reflections, and decorrelate channels.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "IR Toolkit", 0)
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


local EXT = "s3g_mc_ir_toolkit"

local function get_number(key, default)
  local value = tonumber(reaper.GetExtState(EXT, key))
  return value or default
end

local function get_bool(key, default)
  local value = reaper.GetExtState(EXT, key)
  if value == "" then return default end
  return value ~= "0"
end

local function store(settings)
  for key, value in pairs(settings) do
    reaper.SetExtState(EXT, key, type(value) == "boolean" and (value and "1" or "0") or tostring(value), true)
  end
end

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local ROW_H = 25
local LABEL_W = 86
local CONTROL_GAP = 8
local VALUE_W = 76
local LABEL_ABBR = {
  ["TRIM SILENCE"] = "TRIM",
  ["TRIM THRESHOLD DB"] = "THRESH",
  ["TRIM PAD MS"] = "PAD",
  ["TAIL FADE MS"] = "TAIL",
  ["DECOR DELAY MS"] = "DELAY",
  ["ADD EARLY REFLECTIONS"] = "EARLY",
  ["REFLECTION COUNT"] = "COUNT",
  ["REFLECTION WINDOW MS"] = "WINDOW",
  ["PEAK NORMALIZE"] = "PEAK",
  ["NORMALIZE DB"] = "NORM DB",
}

local function row_label_text(label)
  local upper = tostring(label or ""):upper()
  return LABEL_ABBR[upper] or upper
end

local function row_layout(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local avail = ImGui.GetContentRegionAvail(ctx)
  if type(avail) ~= "number" then avail = 380 end
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

local function draw_int_input(ctx, label, value)
  local x, y, control_x, control_w = row_layout(ctx)
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, control_w)
  local changed, next_value = ImGui.InputInt(ctx, "##" .. label, math.floor(value))
  finish_row(ctx, x, y)
  return changed, next_value
end

local function draw_checkbox(ctx, label, value)
  local x, y, control_x = row_layout(ctx)
  row_label(ctx, x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y + 2)
  local changed, next_value = ImGui.Checkbox(ctx, "##" .. label, value)
  finish_row(ctx, x, y)
  return changed, next_value
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
end

local function render(entry, settings)
  if entry.filename == "" or not nr.file_exists(entry.filename) then
    mc.show_error("The selected impulse item must be backed by a readable WAV file.")
    return
  end
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_ir_toolkit_renders", entry.filename, script_dir)
  local output_path = out_dir .. "/s3g_ir_toolkit_" .. stamp .. "_" .. tostring(entry.channels) .. "ch.wav"
  local manifest = {
    source_path = entry.filename,
    source_start = entry.start_offset,
    source_duration = entry.length * math.max(0.000001, entry.playrate),
    output_path = output_path,
    sample_rate = nr.source_sample_rate(entry),
    trim = settings.trim,
    trim_db = settings.trim_db,
    pad_ms = settings.pad_ms,
    tail_fade_ms = settings.tail_fade_ms,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    decorrelate = settings.decorrelate,
    decor_ms = settings.decor_ms,
    early_reflections = settings.early_reflections,
    reflection_count = settings.reflection_count,
    reflection_ms = settings.reflection_ms,
    seed = settings.seed,
  }
  local log, elapsed = nr.run_backend(script_dir, "ir_toolkit", manifest, "IR Toolkit")
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path, "IR toolkit (" .. tostring(entry.channels) .. "ch)", entry.position, entry.channels)
  reaper.Undo_EndBlock("IR Toolkit", -1)
  if not item then mc.show_error(err or "Could not insert processed IR.") return end
  mc.print_plan("IR Toolkit", {
    "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. "ch)",
    "Output: " .. output_path,
    "NumPy time: " .. string.format("%.2f sec", elapsed),
    log,
  })
end

local function main()
  local entries = nr.selected_entries()
  if #entries < 1 then
    mc.show_error("Select one WAV-backed impulse response media item first.")
    return
  end
  local entry = entries[1]
  local settings = {
    trim = get_bool("trim", true),
    trim_db = get_number("trim_db", -70.0),
    pad_ms = get_number("pad_ms", 5.0),
    tail_fade_ms = get_number("tail_fade_ms", 25.0),
    normalize = get_bool("normalize", true),
    normalize_db = get_number("normalize_db", -6.0),
    decorrelate = get_number("decorrelate", 0.15),
    decor_ms = get_number("decor_ms", 18.0),
    early_reflections = get_bool("early_reflections", false),
    reflection_count = get_number("reflection_count", 12),
    reflection_ms = get_number("reflection_ms", 120.0),
    seed = get_number("seed", 1),
  }
  local ctx = ImGui.CreateContext("IR Toolkit")
  local open = true
  local should_render = false

  local function loop()
    ImGui.SetNextWindowSize(ctx, 500, 470, ImGui.Cond_Appearing)
    local visible
    visible, open = ImGui.Begin(ctx, "IR Toolkit", open)
    if visible then
      theme.muted(ImGui, ctx, "Source: " .. entry.name .. "  (" .. tostring(entry.channels) .. " ch)")
      local changed
      ImGui.Spacing(ctx)
      local sx, sy, sh, stack = section(ctx, "Trim / Tail", settings.trim and 148 or 96)
      changed, settings.trim = draw_checkbox(ctx, "Trim silence", settings.trim)
      if settings.trim then
        changed, settings.trim_db = draw_custom_slider(ctx, "Trim threshold dB", settings.trim_db, -100.0, -24.0, "%.1f", false)
        changed, settings.pad_ms = draw_custom_slider(ctx, "Trim pad ms", settings.pad_ms, 0.0, 100.0, "%.1f", false)
      end
      changed, settings.tail_fade_ms = draw_custom_slider(ctx, "Tail fade ms", settings.tail_fade_ms, 0.0, 500.0, "%.1f", false)
      finish_section(ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = section(ctx, "Space", settings.early_reflections and 174 or 122)
      changed, settings.decorrelate = draw_custom_slider(ctx, "Decorrelate", settings.decorrelate, 0.0, 1.0, "%.2f", false)
      changed, settings.decor_ms = draw_custom_slider(ctx, "Decor delay ms", settings.decor_ms, 1.0, 80.0, "%.1f", false)
      changed, settings.early_reflections = draw_checkbox(ctx, "Add early reflections", settings.early_reflections)
      if settings.early_reflections then
        changed, settings.reflection_count = draw_custom_slider(ctx, "Reflection count", math.floor(settings.reflection_count), 1, 96, nil, true)
        changed, settings.reflection_ms = draw_custom_slider(ctx, "Reflection window ms", settings.reflection_ms, 5.0, 500.0, "%.1f", false)
      end
      finish_section(ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = section(ctx, "Output", settings.normalize and 124 or 98)
      changed, settings.normalize = draw_checkbox(ctx, "Peak normalize", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = draw_custom_slider(ctx, "Normalize dB", settings.normalize_db, -24.0, 0.0, "%.1f", false)
      end
      changed, settings.seed = draw_int_input(ctx, "Seed", settings.seed)
      finish_section(ctx, sx, sy, sh, stack)
      if ImGui.Button(ctx, "RENDER", 96, 28) then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "CANCEL", 96, 28) then open = false end
      ImGui.End(ctx)
    end
    if should_render then
      open = false
      store(settings)
      render(entry, settings)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
