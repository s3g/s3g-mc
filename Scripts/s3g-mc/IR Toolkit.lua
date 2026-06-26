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
    ImGui.SetNextWindowSize(ctx, 500, 470, ImGui.Cond_FirstUseEver)
    local visible
    visible, open = ImGui.Begin(ctx, "IR Toolkit", open)
    if visible then
      ImGui.Text(ctx, "Source: " .. entry.name .. "  (" .. tostring(entry.channels) .. " ch)")
      local changed
      changed, settings.trim = ImGui.Checkbox(ctx, "Trim silence", settings.trim)
      if settings.trim then
        changed, settings.trim_db = ImGui.SliderDouble(ctx, "Trim threshold dB", settings.trim_db, -100.0, -24.0, "%.1f")
        changed, settings.pad_ms = ImGui.SliderDouble(ctx, "Trim pad ms", settings.pad_ms, 0.0, 100.0, "%.1f")
      end
      changed, settings.tail_fade_ms = ImGui.SliderDouble(ctx, "Tail fade ms", settings.tail_fade_ms, 0.0, 500.0, "%.1f")
      changed, settings.decorrelate = ImGui.SliderDouble(ctx, "Decorrelate", settings.decorrelate, 0.0, 1.0, "%.2f")
      changed, settings.decor_ms = ImGui.SliderDouble(ctx, "Decor delay ms", settings.decor_ms, 1.0, 80.0, "%.1f")
      changed, settings.early_reflections = ImGui.Checkbox(ctx, "Add early reflections", settings.early_reflections)
      if settings.early_reflections then
        changed, settings.reflection_count = ImGui.SliderInt(ctx, "Reflection count", math.floor(settings.reflection_count), 1, 96)
        changed, settings.reflection_ms = ImGui.SliderDouble(ctx, "Reflection window ms", settings.reflection_ms, 5.0, 500.0, "%.1f")
      end
      changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -24.0, 0.0, "%.1f")
      end
      changed, settings.seed = ImGui.InputInt(ctx, "Seed", math.floor(settings.seed))
      if ImGui.Button(ctx, "Render", 96, 28) then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 96, 28) then open = false end
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
