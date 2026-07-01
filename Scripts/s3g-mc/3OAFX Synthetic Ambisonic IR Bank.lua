-- @description 3OAFX Synthetic Ambisonic IR Bank
-- @author s3g
-- @version 0.2
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; NumPy-backed synthetic ambisonic IR bank generator.
-- @method Designs encoded ACN/SN3D ambisonic impulse-response WAVs for the direction layer used by 3OAFX Offline Ambisonic Convolve. Room size, material absorption, scattering, source distance, early reflections, late diffuse taps, and optional IR Room Sketch Designer JSON files shape the synthetic space.
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
local WINDOW_OPEN_COND = ImGui.Cond_Appearing
local EXT = "s3g_mc_synthetic_ambi_ir_bank_v1"
local COLOR_BG = ImGui.ColorConvertDouble4ToU32(0.035, 0.039, 0.042, 1.0)
local COLOR_EDGE = ImGui.ColorConvertDouble4ToU32(0.34, 0.38, 0.38, 1.0)
local COLOR_GRID = ImGui.ColorConvertDouble4ToU32(0.60, 0.66, 0.66, 0.16)
local COLOR_TEXT = ImGui.ColorConvertDouble4ToU32(0.78, 0.83, 0.82, 1.0)
local COLOR_MUTED = ImGui.ColorConvertDouble4ToU32(0.48, 0.54, 0.54, 1.0)
local COLOR_DIRECT = ImGui.ColorConvertDouble4ToU32(0.96, 0.68, 0.24, 0.95)
local COLOR_EARLY = ImGui.ColorConvertDouble4ToU32(0.28, 0.70, 0.95, 0.82)
local COLOR_LATE = ImGui.ColorConvertDouble4ToU32(0.72, 0.58, 0.98, 0.74)
local COLOR_FILL = ImGui.ColorConvertDouble4ToU32(0.28, 0.70, 0.95, 0.16)

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
  if ImGui.BeginCombo(ctx, label, names[index] or "") then
    for i, name in ipairs(names) do
      local selected = i == index
      if ImGui.Selectable(ctx, name, selected) then index = i end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return index
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
    return false, "This does not look like an IR Room Sketch Designer export."
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
  local ok, path = reaper.GetUserFileNameForRead(settings.sketch_path or "", "Load IR Room Sketch JSON", "json")
  if not ok or path == "" then return end
  local loaded, message = apply_room_sketch(settings, path)
  if not loaded then
    mc.show_error(message or "Could not load room sketch JSON.")
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
  ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, COLOR_BG)
  ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, COLOR_EDGE)

  local plot_x0, plot_y0 = x0 + 14, y0 + 34
  local plot_x1, plot_y1 = x1 - 14, y1 - 22
  local mid_y = (plot_y0 + plot_y1) * 0.5
  local duration = math.max(0.05, settings.duration)
  local decay = settings.auto_decay and estimated_rt60(settings) or math.max(0.05, settings.decay)
  local distance = math.max(0.25, settings.source_distance)
  local direct_t = settings.pre_delay_ms / 1000.0 + distance / 343.0
  local late_start = math.min(duration * 0.92, settings.pre_delay_ms / 1000.0 + 0.035 + (1.0 - settings.scattering) * 0.080)
  local reflectivity = math.sqrt(math.max(0.0, 1.0 - settings.absorption))

  ImGui.DrawList_AddText(draw_list, x0 + 12, y0 + 10, COLOR_TEXT, "representative IR shape")
  ImGui.DrawList_AddText(draw_list, x1 - 150, y0 + 10, COLOR_MUTED, string.format("%.2fs / RT %.2fs", duration, decay))
  for i = 0, 4 do
    local gx = plot_x0 + (plot_x1 - plot_x0) * i / 4
    ImGui.DrawList_AddLine(draw_list, gx, plot_y0, gx, plot_y1, COLOR_GRID, 1)
  end
  ImGui.DrawList_AddLine(draw_list, plot_x0, mid_y, plot_x1, mid_y, COLOR_GRID, 1)

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
      ImGui.DrawList_AddLine(draw_list, last_x, last_y, x, y, COLOR_LATE, 1.4)
      ImGui.DrawList_AddTriangleFilled(draw_list, last_x, mid_y, x, mid_y, x, y, COLOR_FILL)
      ImGui.DrawList_AddTriangleFilled(draw_list, last_x, mid_y, last_x, last_y, x, y, COLOR_FILL)
    end
    last_x, last_y = x, y
  end

  if direct_t < duration then
    local x = px(direct_t)
    local amp = clamp(settings.direct_gain / math.max(1.0, distance), 0.08, 1.0)
    ImGui.DrawList_AddLine(draw_list, x, mid_y, x, py(amp), COLOR_DIRECT, 2.4)
    ImGui.DrawList_AddText(draw_list, x + 4, plot_y0 + 2, COLOR_DIRECT, "direct")
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
      ImGui.DrawList_AddLine(draw_list, x, mid_y, x, py(amp * sign), COLOR_EARLY, 1.3)
    end
  end

  ImGui.DrawList_AddText(draw_list, plot_x0, plot_y1 + 6, COLOR_MUTED, "0")
  ImGui.DrawList_AddText(draw_list, plot_x1 - 42, plot_y1 + 6, COLOR_MUTED, string.format("%.2fs", duration))
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
    settings.sketch_path and settings.sketch_path ~= "" and ("Room sketch: " .. settings.sketch_path) or "Room sketch: none",
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
      local footer_h = 54
      local control_h = math.max(260, ImGui.GetWindowHeight(ctx) - footer_h)
      if ImGui.BeginChild(ctx, "##synthetic_ir_bank_controls", 0, control_h) then
      settings.order_index = combo(ctx, "Ambisonic order", settings.order_index, ORDER_NAMES)
      settings.output_mode_index = combo(ctx, "Output format", settings.output_mode_index, OUTPUT_MODE_NAMES)
      if settings.order_index == 1 then
        ImGui.Text(ctx, "First order uses the four-direction P-format / tetrahedral bank.")
      else
        ImGui.Text(ctx, "Higher-order bank uses 8 directions: 2OA stacked = 72ch, 3OA stacked = 128ch.")
      end
      ImGui.Spacing(ctx)
      draw_ir_preview(ctx, settings)
      ImGui.Spacing(ctx)
      if ImGui.Button(ctx, "Load Room Sketch JSON", 180, 26) then choose_room_sketch(settings) end
      ImGui.SameLine(ctx)
      if settings.sketch_path and settings.sketch_path ~= "" then
        ImGui.Text(ctx, basename(settings.sketch_path))
      else
        ImGui.TextColored(ctx, COLOR_MUTED, "optional browser sketch")
      end
      if settings.sketch_path and settings.sketch_path ~= "" then
        ImGui.TextColored(ctx, COLOR_MUTED, "Imported sketches can add polygon room metadata and chamber-return timing.")
      end
      ImGui.Spacing(ctx)
      local old_material = settings.material_index
      settings.material_index = combo(ctx, "Material preset", settings.material_index, MATERIAL_NAMES)
      if settings.material_index ~= old_material then apply_material(settings) end
      local material = MATERIALS[settings.material_index]
      if material then ImGui.Text(ctx, material.label) end
      ImGui.Spacing(ctx)
      local changed
      changed, settings.room_x = ImGui.SliderDouble(ctx, "Room length m", settings.room_x, 1.0, 80.0, "%.1f")
      changed, settings.room_y = ImGui.SliderDouble(ctx, "Room width m", settings.room_y, 1.0, 80.0, "%.1f")
      changed, settings.room_z = ImGui.SliderDouble(ctx, "Room height m", settings.room_z, 1.0, 30.0, "%.1f")
      changed, settings.source_distance = ImGui.SliderDouble(ctx, "Source distance m", settings.source_distance, 0.25, 30.0, "%.2f")
      changed, settings.pre_delay_ms = ImGui.SliderDouble(ctx, "Pre-delay ms", settings.pre_delay_ms, 0.0, 120.0, "%.1f")
      changed, settings.absorption = ImGui.SliderDouble(ctx, "Surface absorption", settings.absorption, 0.03, 0.95, "%.2f")
      changed, settings.scattering = ImGui.SliderDouble(ctx, "Wall scattering", settings.scattering, 0.0, 1.0, "%.2f")
      changed, settings.auto_decay = ImGui.Checkbox(ctx, "Estimate decay from room/material", settings.auto_decay)
      if settings.auto_decay then
        ImGui.Text(ctx, string.format("Estimated decay: %.2f sec", estimated_rt60(settings)))
      else
        changed, settings.decay = ImGui.SliderDouble(ctx, "Manual decay sec", settings.decay, 0.05, 8.0, "%.2f")
      end
      changed, settings.duration = ImGui.SliderDouble(ctx, "IR duration sec", settings.duration, 0.05, 8.0, "%.2f")
      changed, settings.spread_deg = ImGui.SliderDouble(ctx, "Directional spread deg", settings.spread_deg, 0.0, 120.0, "%.1f")
      changed, settings.direct_gain = ImGui.SliderDouble(ctx, "Direct gain", settings.direct_gain, 0.0, 2.0, "%.2f")
      changed, settings.early_reflections = ImGui.SliderDouble(ctx, "Early reflections per IR", settings.early_reflections, 0, 80, "%.0f")
      changed, settings.diffuse_taps = ImGui.SliderDouble(ctx, "Late diffuse taps per IR", settings.diffuse_taps, 0, 1200, "%.0f")
      changed, settings.tail_soften = ImGui.SliderDouble(ctx, "Air / tail damping", settings.tail_soften, 0.0, 1.0, "%.2f")
      changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize each IR dB", settings.normalize_db, -24.0, 0.0, "%.1f")
      changed, settings.seed = ImGui.SliderDouble(ctx, "Seed", settings.seed, 1, 9999, "%.0f")
      changed, settings.insert_items = ImGui.Checkbox(ctx, "Insert generated IR items", settings.insert_items)
      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Text(ctx, "IR files to create: " .. tostring(direction_count(settings.order_index)))
      ImGui.Text(ctx, "Channels per IR: " .. tostring(order_channels(settings.order_index)))
      if settings.output_mode_index == 2 then
        local stacked_channels = stacked_channel_count(settings)
        ImGui.Text(ctx, "Stacked bank channels: " .. tostring(stacked_channels))
        if stacked_channels > mc.MAX_REAPER_TRACK_CHANNELS then
          ImGui.Text(ctx, "Stacked bank exceeds REAPER's 128-channel track limit; use separate ambisonic WAVs.")
        end
      end
      ImGui.Text(ctx, "Use these as the IR selection for 3OAFX Offline Ambisonic Convolve.")
      ImGui.Spacing(ctx)
      ImGui.EndChild(ctx)
      end
      if ImGui.Button(ctx, "Render IR Bank", 128, 28) then
        if settings.output_mode_index == 2 and stacked_channel_count(settings) > mc.MAX_REAPER_TRACK_CHANNELS then
          mc.show_error("This stacked bank would need " .. tostring(stacked_channel_count(settings)) .. " channels. REAPER tracks are limited to 128 channels, so use separate ambisonic WAVs for this order/layout.")
        else
          should_render = true
        end
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 104, 28) then open = false end
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
