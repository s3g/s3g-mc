-- @description 3OAFX Synthetic Ambisonic IR Bank
-- @author s3g
-- @version 0.2
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed synthetic ambisonic IR bank generator.
-- @method Designs encoded ACN/SN3D ambisonic impulse-response WAVs for the direction layer used by 3OAFX Offline Ambisonic Convolve. Dimensions, material absorption, scattering, source distance, early reflections, late diffuse taps, and optional Imprint Sketch JSON files shape the synthetic space.
-- @about
--   Creates either one encoded ambisonic IR file per virtual direction or one
--   stacked multichannel bank with one ambisonic channel block per direction.
--   Both formats can be selected for 3OAFX Offline Ambisonic Convolve.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

local TITLE = "3OAFX Synthetic Ambisonic IR Bank"

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", TITLE, 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local ui_theme = nil
do
  local _s3g_theme_path = ({ reaper.get_action_context() })[2]
  if not _s3g_theme_path or _s3g_theme_path == "" then
    _s3g_theme_path = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
  end
  local _s3g_theme_dir = _s3g_theme_path:match("^(.*[/\\])") or ""
  package.path = _s3g_theme_dir .. "?.lua;" .. package.path
  package.loaded["s3g-mc ImGui Theme"] = nil
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme and _s3g_theme.install then _s3g_theme.install(ImGui); ui_theme = _s3g_theme end
end

local WINDOW_OPEN_COND = ImGui.Cond_Appearing
local EXT = "s3g_mc_synthetic_ambi_ir_bank_v1"
local CANVAS = {
  bg = ImGui.ColorConvertDouble4ToU32(0.035, 0.039, 0.042, 1.0),
  edge = ImGui.ColorConvertDouble4ToU32(0.34, 0.38, 0.38, 1.0),
  grid = ImGui.ColorConvertDouble4ToU32(0.60, 0.66, 0.66, 0.16),
  text = ImGui.ColorConvertDouble4ToU32(0.78, 0.83, 0.82, 1.0),
  muted = ImGui.ColorConvertDouble4ToU32(0.48, 0.54, 0.54, 1.0),
  direct = ImGui.ColorConvertDouble4ToU32(0.96, 0.68, 0.24, 0.95),
  early = ImGui.ColorConvertDouble4ToU32(0.28, 0.70, 0.95, 0.82),
  late = ImGui.ColorConvertDouble4ToU32(0.72, 0.58, 0.98, 0.74),
  fill = ImGui.ColorConvertDouble4ToU32(0.28, 0.70, 0.95, 0.16),
}

local ORDER_NAMES = { "1OA / 4ch", "2OA / 9ch", "3OA / 16ch" }
local ORDER_VALUES = { 1, 2, 3 }
local OUTPUT_MODE_NAMES = { "Separate ambisonic WAVs", "One stacked multichannel bank" }
local OUTPUT_MODE_KEYS = { "separate", "stacked" }
local MATERIAL_NAMES = {
  "Custom",
  "Concrete stairwell",
  "Stone hall",
  "Wood room",
  "Plaster studio",
  "Curtained / damped",
  "Glass / bright",
}
local MATERIALS = {
  nil,
  { absorption = 0.12, scattering = 0.32, tail_soften = 0.16, label = "hard concrete, long bright tail" },
  { absorption = 0.18, scattering = 0.48, tail_soften = 0.22, label = "reflective stone, broad reflections" },
  { absorption = 0.30, scattering = 0.55, tail_soften = 0.36, label = "wood diffusion, rounded tail" },
  { absorption = 0.42, scattering = 0.42, tail_soften = 0.48, label = "moderate absorption" },
  { absorption = 0.68, scattering = 0.38, tail_soften = 0.72, label = "shorter, darker response" },
  { absorption = 0.20, scattering = 0.22, tail_soften = 0.12, label = "bright specular response" },
}

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function get_number(key, default)
  local value = tonumber(reaper.GetExtState(EXT, key))
  return value or default
end

local function get_bool(key, default)
  local value = reaper.GetExtState(EXT, key)
  if value == "" then return default end
  return value == "1"
end

local function set_value(key, value)
  if type(value) == "boolean" then
    reaper.SetExtState(EXT, key, value and "1" or "0", true)
  else
    reaper.SetExtState(EXT, key, tostring(value), true)
  end
end

local function combo(ctx, label, index, names)
  local _, next_index = ui_theme.combo_row(ImGui, ctx, label, names, index)
  return next_index
end

local function apply_material(settings)
  local material = MATERIALS[settings.material_index]
  if not material then return end
  settings.absorption = material.absorption
  settings.scattering = material.scattering
  settings.tail_soften = material.tail_soften
end

local function basename(path)
  return tostring(path or ""):match("([^/\\]+)$") or tostring(path or "")
end

local function json_number(text, key)
  local pattern = '"' .. key .. '"%s*:%s*([-+]?%d+%.?%d*)'
  local value = tostring(text or ""):match(pattern)
  return value and tonumber(value) or nil
end

local function json_string(text, key)
  local pattern = '"' .. key .. '"%s*:%s*"([^"]*)"'
  return tostring(text or ""):match(pattern)
end

local function apply_room_sketch(settings, path)
  local text = nr.read_file(path)
  if text == "" then return false, "Could not read JSON file." end
  if not text:find('"target_process"%s*:%s*"3OAFX Synthetic Ambisonic IR Bank"', 1) then
    return false, "This does not look like an Imprint Sketch or legacy IR Sketch export."
  end
  settings.sketch_path = path
  settings.room_x = json_number(text, "room_x") or settings.room_x
  settings.room_y = json_number(text, "room_y") or settings.room_y
  settings.room_z = json_number(text, "room_z") or settings.room_z
  settings.absorption = json_number(text, "absorption") or settings.absorption
  settings.scattering = json_number(text, "scattering") or settings.scattering
  settings.tail_soften = json_number(text, "tail_soften") or settings.tail_soften
  settings.source_distance = json_number(text, "source_distance") or settings.source_distance
  settings.spread_deg = json_number(text, "direction_spread_deg") or settings.spread_deg
  settings.duration = json_number(text, "duration") or settings.duration
  settings.pre_delay_ms = json_number(text, "pre_delay_ms") or settings.pre_delay_ms
  settings.early_reflections = json_number(text, "early_reflections") or settings.early_reflections
  local order = json_number(text, "order")
  if order then settings.order_index = clamp(math.floor(order + 0.5), 1, 3) end
  settings.material_index = 1
  return true, "Loaded " .. basename(path)
end

local function choose_room_sketch(settings)
  local ok, path = reaper.GetUserFileNameForRead(settings.sketch_path or "", "Load Imprint Sketch JSON", "json")
  if not ok or path == "" then return end
  local loaded, message = apply_room_sketch(settings, path)
  if not loaded then
    mc.show_error(message or "Could not load Imprint Sketch JSON.")
  else
    reaper.ShowConsoleMsg("[3OAFX Synthetic Ambisonic IR Bank]\n" .. message .. "\n")
  end
end

local function order_channels(order_index)
  local order = ORDER_VALUES[order_index] or 1
  return (order + 1) * (order + 1)
end

local function direction_count(order_index)
  local order = ORDER_VALUES[order_index] or 1
  if order == 1 then return 4 end
  return 8
end

local function estimated_rt60(settings)
  local x = math.max(1.0, settings.room_x)
  local y = math.max(1.0, settings.room_y)
  local z = math.max(1.0, settings.room_z)
  local volume = x * y * z
  local surface = 2.0 * (x * y + x * z + y * z)
  local absorption = math.max(0.03, math.min(0.95, settings.absorption))
  return math.max(0.08, math.min(8.0, 0.161 * volume / math.max(0.01, surface * absorption)))
end

local function stacked_channel_count(settings)
  return order_channels(settings.order_index) * direction_count(settings.order_index)
end

local function frac_noise(seed, index)
  local value = math.sin((seed or 1) * 12.9898 + index * 78.233) * 43758.5453
  return value - math.floor(value)
end

local function draw_ir_preview(ctx, settings)
  local width = math.max(520, ImGui.GetContentRegionAvail(ctx) - 2)
  local height = 150
  ImGui.InvisibleButton(ctx, "##synthetic_ir_preview", width, height)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = x0 + width, y0 + height
  local draw_list = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, CANVAS.bg)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, CANVAS.edge)

  local plot_x0, plot_y0 = x0 + 14, y0 + 34
  local plot_x1, plot_y1 = x1 - 14, y1 - 22
  local mid_y = (plot_y0 + plot_y1) * 0.5
  local duration = math.max(0.05, settings.duration)
  local decay = settings.auto_decay and estimated_rt60(settings) or math.max(0.05, settings.decay)
  local distance = math.max(0.25, settings.source_distance)
  local direct_t = settings.pre_delay_ms / 1000.0 + distance / 343.0
  local late_start = math.min(duration * 0.92, settings.pre_delay_ms / 1000.0 + 0.035 + (1.0 - settings.scattering) * 0.080)
  local reflectivity = math.sqrt(math.max(0.0, 1.0 - settings.absorption))

  ImGui.DrawList_AddText(draw_list, x0 + 12, y0 + 10, CANVAS.text, "representative IR shape")
  ImGui.DrawList_AddText(draw_list, x1 - 150, y0 + 10, CANVAS.muted, string.format("%.2fs / RT %.2fs", duration, decay))
  for i = 0, 4 do
    local gx = plot_x0 + (plot_x1 - plot_x0) * i / 4
    ImGui.DrawList_AddLine(draw_list, gx, plot_y0, gx, plot_y1, CANVAS.grid, 1)
  end
  ImGui.DrawList_AddLine(draw_list, plot_x0, mid_y, plot_x1, mid_y, CANVAS.grid, 1)

  local function px(time)
    return plot_x0 + (plot_x1 - plot_x0) * clamp(time / duration, 0, 1)
  end
  local function py(value)
    local v = clamp(value, -1, 1)
    return mid_y - v * (plot_y1 - plot_y0) * 0.46
  end

  local last_x, last_y
  for i = 0, 120 do
    local u = i / 120
    local t = u * duration
    local env = 0.0
    if t >= late_start then
      env = 0.33 * reflectivity * math.exp(-(t - late_start) / math.max(0.04, decay * 0.42))
      env = env * (0.45 + 0.55 * frac_noise(settings.seed, i))
      env = env * (1.0 - settings.tail_soften * 0.45)
    end
    local x, y = px(t), py(env)
    if last_x then
      ImGui.DrawList_AddLine(draw_list, last_x, last_y, x, y, CANVAS.late, 1.4)
      ImGui.DrawList_AddTriangleFilled(draw_list, last_x, mid_y, x, mid_y, x, y, CANVAS.fill)
      ImGui.DrawList_AddTriangleFilled(draw_list, last_x, mid_y, last_x, last_y, x, y, CANVAS.fill)
    end
    last_x, last_y = x, y
  end

  if direct_t < duration then
    local x = px(direct_t)
    local amp = clamp(settings.direct_gain / math.max(1.0, distance), 0.08, 1.0)
    ImGui.DrawList_AddLine(draw_list, x, mid_y, x, py(amp), CANVAS.direct, 2.4)
    ImGui.DrawList_AddText(draw_list, x + 4, plot_y0 + 2, CANVAS.direct, "direct")
  end

  local early_count = math.min(40, math.max(0, math.floor(settings.early_reflections + 0.5)))
  local room_cross = math.sqrt(settings.room_x * settings.room_x + settings.room_y * settings.room_y + settings.room_z * settings.room_z)
  local early_hi = math.min(duration * 0.35, room_cross / 343.0 + settings.pre_delay_ms / 1000.0)
  for i = 1, early_count do
    local n = frac_noise(settings.seed + 17, i)
    local t = settings.pre_delay_ms / 1000.0 + 0.006 + n * math.max(0.001, early_hi - 0.006)
    if t < duration then
      local amp = (0.18 + 0.46 * frac_noise(settings.seed + 41, i)) * reflectivity * math.exp(-t / math.max(0.05, decay))
      local x = px(t)
      local sign = frac_noise(settings.seed + 83, i) > 0.5 and 1 or -1
      ImGui.DrawList_AddLine(draw_list, x, mid_y, x, py(amp * sign), CANVAS.early, 1.3)
    end
  end

  ImGui.DrawList_AddText(draw_list, plot_x0, plot_y1 + 6, CANVAS.muted, "0")
  ImGui.DrawList_AddText(draw_list, plot_x1 - 42, plot_y1 + 6, CANVAS.muted, string.format("%.2fs", duration))
end

local function insert_ir_item(path, label, position, channel_count)
  local source = reaper.PCM_Source_CreateFromFile(path)
  if not source then return nil, "REAPER could not create a PCM source from " .. path end
  local source_length = ({ reaper.GetMediaSourceLength(source) })[1] or 0
  reaper.InsertTrackAtIndex(reaper.CountTracks(mc.PROJECT), true)
  local track = reaper.GetTrack(mc.PROJECT, reaper.CountTracks(mc.PROJECT) - 1)
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", label, true)
  reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", mc.reaper_track_channel_count(channel_count))
  reaper.SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)
  reaper.SetMediaTrackInfo_Value(track, "D_VOL", 0.5)
  local item = reaper.AddMediaItemToTrack(track)
  local take = reaper.AddTakeToMediaItem(item)
  reaper.SetMediaItemTake_Source(take, source)
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", position)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", source_length)
  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", label, true)
  return item, nil
end

local function run_render(settings)
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local order = ORDER_VALUES[settings.order_index] or 1
  local channels = order_channels(settings.order_index)
  local count = direction_count(settings.order_index)
  local output_dir = nr.output_dir("s3g_synthetic_ambisonic_irs", "", script_dir)
  local prefix = "s3g_synthetic_ambi_ir_" .. stamp
  local first_path
  if settings.output_mode_index == 2 then
    first_path = output_dir .. "/" .. prefix .. "_stacked_" .. tostring(order) .. "oa_bank.wav"
  else
    first_path = output_dir .. "/" .. prefix .. "_01_" .. tostring(order) .. "oa.wav"
  end
  local manifest = {
    output_path = first_path,
    output_dir = output_dir,
    prefix = prefix,
    sample_rate = settings.sample_rate,
    order = order,
    direction_layout = order == 1 and "tetra" or "virtual",
    output_mode = OUTPUT_MODE_KEYS[settings.output_mode_index] or "separate",
    duration = settings.duration,
    room_x = settings.room_x,
    room_y = settings.room_y,
    room_z = settings.room_z,
    absorption = settings.absorption,
    scattering = settings.scattering,
    source_distance = settings.source_distance,
    pre_delay_ms = settings.pre_delay_ms,
    auto_decay = settings.auto_decay,
    decay = settings.decay,
    spread_deg = settings.spread_deg,
    direct_gain = settings.direct_gain,
    early_reflections = math.floor(settings.early_reflections + 0.5),
    diffuse_taps = math.floor(settings.diffuse_taps + 0.5),
    tail_soften = settings.tail_soften,
    air_damping = settings.tail_soften,
    normalize_db = settings.normalize_db,
    seed = math.floor(settings.seed + 0.5),
    sketch_path = settings.sketch_path or "",
  }
  local log, elapsed = nr.run_backend(script_dir, "synthetic_ambisonic_ir_bank", manifest, TITLE)
  if not log then return end

  local paths = {}
  if settings.output_mode_index == 2 then
    paths[1] = first_path
  else
    for index = 1, count do
      paths[#paths + 1] = output_dir .. "/" .. prefix .. "_" .. string.format("%02d", index) .. "_" .. tostring(order) .. "oa.wav"
    end
  end

  if settings.insert_items then
    reaper.Undo_BeginBlock()
    local position = reaper.GetCursorPosition()
    reaper.Main_OnCommand(40289, 0) -- Item: Unselect all items
    local inserted = 0
    for index, path in ipairs(paths) do
      if nr.file_exists(path) then
        local item_channels = settings.output_mode_index == 2 and (channels * count) or channels
        local label = settings.output_mode_index == 2 and "3OAFX synthetic IR stacked bank" or ("3OAFX synthetic IR " .. tostring(index))
        local item = insert_ir_item(path, label, position + (index - 1) * 0.01, item_channels)
        if item then
          reaper.SetMediaItemSelected(item, true)
          inserted = inserted + 1
        end
      end
    end
    reaper.Undo_EndBlock(TITLE, -1)
    reaper.Main_OnCommand(40245, 0)
    reaper.UpdateArrange()
    log = log .. "\nInserted IR items: " .. tostring(inserted) .. " (master send off, track gain -6 dB)"
  end

  local lines = {
    "Order: " .. tostring(order) .. "OA",
    "Channels per IR: " .. tostring(channels),
    "Direction layout: " .. (order == 1 and "P-format / tetrahedral" or "Practical 8-direction bank"),
    "Output mode: " .. (OUTPUT_MODE_NAMES[settings.output_mode_index] or "?"),
    "IR files: " .. tostring(#paths),
    settings.sketch_path and settings.sketch_path ~= "" and ("Imprint sketch: " .. settings.sketch_path) or "Imprint sketch: none",
    string.format("NumPy time: %.2f sec", elapsed),
    "Output folder: " .. output_dir,
    "",
    log,
  }
  mc.print_plan(TITLE, lines)
end

local function main()
  local ctx = ImGui.CreateContext(TITLE)
  local open = true
  local should_render = false
  local settings = {
    order_index = clamp(math.floor(get_number("order_index", 1)), 1, 3),
    material_index = clamp(math.floor(get_number("material_index", 2)), 1, #MATERIAL_NAMES),
    output_mode_index = clamp(math.floor(get_number("output_mode_index", 1)), 1, #OUTPUT_MODE_NAMES),
    sample_rate = clamp(math.floor(get_number("sample_rate", 48000)), 8000, 192000),
    duration = get_number("duration", 2.0),
    room_x = get_number("room_x", 12.0),
    room_y = get_number("room_y", 9.0),
    room_z = get_number("room_z", 5.0),
    absorption = get_number("absorption", 0.12),
    scattering = get_number("scattering", 0.32),
    source_distance = get_number("source_distance", 3.0),
    pre_delay_ms = get_number("pre_delay_ms", 0.0),
    auto_decay = get_bool("auto_decay", true),
    decay = get_number("decay", 1.2),
    spread_deg = get_number("spread_deg", 38.0),
    direct_gain = get_number("direct_gain", 1.0),
    early_reflections = get_number("early_reflections", 18),
    diffuse_taps = get_number("diffuse_taps", 160),
    tail_soften = get_number("tail_soften", 0.35),
    normalize_db = get_number("normalize_db", -6.0),
    seed = get_number("seed", 1),
    insert_items = get_bool("insert_items", true),
    sketch_path = reaper.GetExtState(EXT, "sketch_path"),
  }

  local function persist()
    for key, value in pairs(settings) do set_value(key, value) end
  end

  local function loop()
    ImGui.SetNextWindowSize(ctx, 660, 760, WINDOW_OPEN_COND)
    local visible
    visible, open = ImGui.Begin(ctx, TITLE, open)
    if visible then
      local footer_h = 64
      local _, avail_h = ImGui.GetContentRegionAvail(ctx)
      local control_h = math.max(260, avail_h - footer_h)
      if ImGui.BeginChild(ctx, "##synthetic_ir_bank_controls", 0, control_h) then
      local sx, sy, sh, stack = ui_theme.begin_section(ImGui, ctx, "Routing", 98)
      settings.order_index = combo(ctx, "Ambisonic order", settings.order_index, ORDER_NAMES)
      settings.output_mode_index = combo(ctx, "Output format", settings.output_mode_index, OUTPUT_MODE_NAMES)
      ui_theme.finish_section(ImGui, ctx, sx, sy, sh, stack)
      if settings.order_index == 1 then
        ui_theme.muted(ImGui, ctx, "First order uses the four-direction P-format / tetrahedral bank.")
      else
        ui_theme.muted(ImGui, ctx, "Higher-order bank uses 8 directions: 2OA stacked = 72ch, 3OA stacked = 128ch.")
      end
      ImGui.Spacing(ctx)
      draw_ir_preview(ctx, settings)
      ImGui.Spacing(ctx)
      if ui_theme.action_button(ImGui, ctx, "LOAD IMPRINT SKETCH JSON") then choose_room_sketch(settings) end
      if settings.sketch_path and settings.sketch_path ~= "" then
        ui_theme.muted(ImGui, ctx, basename(settings.sketch_path))
      else
        ui_theme.muted(ImGui, ctx, "optional browser sketch")
      end
      if settings.sketch_path and settings.sketch_path ~= "" then
        ui_theme.muted(ImGui, ctx, "Imported sketches can add polygon room metadata, chamber timing, and exterior leak.")
      end
      ImGui.Spacing(ctx)
      local old_material = settings.material_index
      sx, sy, sh, stack = ui_theme.begin_section(ImGui, ctx, "Material", 98)
      settings.material_index = combo(ctx, "Material preset", settings.material_index, MATERIAL_NAMES)
      if settings.material_index ~= old_material then apply_material(settings) end
      local material = MATERIALS[settings.material_index]
      if material then ui_theme.muted(ImGui, ctx, material.label) end
      ui_theme.finish_section(ImGui, ctx, sx, sy, sh, stack)
      local changed
      sx, sy, sh, stack = ui_theme.begin_section(ImGui, ctx, "Room", 202)
      changed, settings.room_x = ui_theme.slider_double(ImGui, ctx, "Room length m", settings.room_x, 1.0, 80.0, "%.1f")
      changed, settings.room_y = ui_theme.slider_double(ImGui, ctx, "Room width m", settings.room_y, 1.0, 80.0, "%.1f")
      changed, settings.room_z = ui_theme.slider_double(ImGui, ctx, "Room height m", settings.room_z, 1.0, 30.0, "%.1f")
      changed, settings.source_distance = ui_theme.slider_double(ImGui, ctx, "Source distance m", settings.source_distance, 0.25, 30.0, "%.2f")
      changed, settings.pre_delay_ms = ui_theme.slider_double(ImGui, ctx, "Pre-delay ms", settings.pre_delay_ms, 0.0, 120.0, "%.1f")
      changed, settings.absorption = ui_theme.slider_double(ImGui, ctx, "Surface absorption", settings.absorption, 0.03, 0.95, "%.2f")
      changed, settings.scattering = ui_theme.slider_double(ImGui, ctx, "Wall scattering", settings.scattering, 0.0, 1.0, "%.2f")
      ui_theme.finish_section(ImGui, ctx, sx, sy, sh, stack)

      sx, sy, sh, stack = ui_theme.begin_section(ImGui, ctx, "Reverb", 230)
      changed, settings.auto_decay = ui_theme.checkbox_row(ImGui, ctx, "Estimate decay from room/material", settings.auto_decay)
      if settings.auto_decay then
        ui_theme.note_row(ImGui, ctx, string.format("Estimated decay: %.2f sec", estimated_rt60(settings)))
      else
        changed, settings.decay = ui_theme.slider_double(ImGui, ctx, "Manual decay sec", settings.decay, 0.05, 8.0, "%.2f")
      end
      changed, settings.duration = ui_theme.slider_double(ImGui, ctx, "IR duration sec", settings.duration, 0.05, 8.0, "%.2f")
      changed, settings.spread_deg = ui_theme.slider_double(ImGui, ctx, "Directional spread deg", settings.spread_deg, 0.0, 120.0, "%.1f")
      changed, settings.direct_gain = ui_theme.slider_double(ImGui, ctx, "Direct gain", settings.direct_gain, 0.0, 2.0, "%.2f")
      changed, settings.early_reflections = ui_theme.slider_double(ImGui, ctx, "Early reflections per IR", settings.early_reflections, 0, 80, "%.0f")
      changed, settings.diffuse_taps = ui_theme.slider_double(ImGui, ctx, "Late diffuse taps per IR", settings.diffuse_taps, 0, 1200, "%.0f")
      changed, settings.tail_soften = ui_theme.slider_double(ImGui, ctx, "Air / tail damping", settings.tail_soften, 0.0, 1.0, "%.2f")
      ui_theme.finish_section(ImGui, ctx, sx, sy, sh, stack)

      sx, sy, sh, stack = ui_theme.begin_section(ImGui, ctx, "Output", 114)
      changed, settings.normalize_db = ui_theme.slider_double(ImGui, ctx, "Normalize each IR dB", settings.normalize_db, -24.0, 0.0, "%.1f")
      changed, settings.seed = ui_theme.slider_double(ImGui, ctx, "Seed", settings.seed, 1, 9999, "%.0f")
      changed, settings.insert_items = ui_theme.checkbox_row(ImGui, ctx, "Insert generated IR items", settings.insert_items)
      ui_theme.finish_section(ImGui, ctx, sx, sy, sh, stack)
      ImGui.Spacing(ctx)
      ui_theme.muted(ImGui, ctx, "IR files to create: " .. tostring(direction_count(settings.order_index)))
      ui_theme.muted(ImGui, ctx, "Channels per IR: " .. tostring(order_channels(settings.order_index)))
      if settings.output_mode_index == 2 then
        local stacked_channels = stacked_channel_count(settings)
        ui_theme.muted(ImGui, ctx, "Stacked bank channels: " .. tostring(stacked_channels))
        if stacked_channels > mc.MAX_REAPER_TRACK_CHANNELS then
          ui_theme.status(ImGui, ctx, "Stacked bank exceeds REAPER's 128-channel track limit; use separate ambisonic WAVs.", "warn")
        end
      end
      ui_theme.muted(ImGui, ctx, "Use these as the IR selection for 3OAFX Offline Ambisonic Convolve.")
      ImGui.Spacing(ctx)
      ImGui.EndChild(ctx)
      end
      local render_pressed, cancel_pressed = ui_theme.footer_buttons(ImGui, ctx, "RENDER IR BANK", "CANCEL", 148, 104)
      if render_pressed then
        if settings.output_mode_index == 2 and stacked_channel_count(settings) > mc.MAX_REAPER_TRACK_CHANNELS then
          mc.show_error("This stacked bank would need " .. tostring(stacked_channel_count(settings)) .. " channels. REAPER tracks are limited to 128 channels, so use separate ambisonic WAVs for this order/layout.")
        else
          should_render = true
        end
      end
      if cancel_pressed then open = false end
      ImGui.Dummy(ctx, 1, 10)
      ImGui.End(ctx)
    end
    persist()
    if should_render then
      open = false
      run_render(settings)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
