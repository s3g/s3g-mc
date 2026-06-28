-- @description 3OAFX Spectral Profile Tool Library
-- @browser hidden

local M = {}

function M.run(config)
  local script_path = ({ reaper.get_action_context() })[2]
  local script_dir = script_path:match("^(.*[/\\])") or ""
  local mc = dofile(script_dir .. "Multichannel Library.lua")
  local nr = dofile(script_dir .. "NumPy Render Library.lua")

  local TITLE = config.title
  if not reaper.APIExists("ImGui_GetVersion") then
    reaper.MB("ReaImGui is not installed or not loaded.", TITLE, 0)
    return
  end

  package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
  local ImGui = require("imgui")("0.10")
  local WINDOW_OPEN_COND = ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver
  local EXT = config.ext

  local COLOR_BG = ImGui.ColorConvertDouble4ToU32(0.035, 0.039, 0.042, 1.0)
  local COLOR_PANEL = ImGui.ColorConvertDouble4ToU32(0.060, 0.066, 0.070, 1.0)
  local COLOR_EDGE = ImGui.ColorConvertDouble4ToU32(0.34, 0.38, 0.38, 1.0)
  local COLOR_TEXT = ImGui.ColorConvertDouble4ToU32(0.78, 0.83, 0.82, 1.0)
  local COLOR_MUTED = ImGui.ColorConvertDouble4ToU32(0.48, 0.54, 0.54, 1.0)
  local COLOR_FLOW = ImGui.ColorConvertDouble4ToU32(0.95, 0.68, 0.25, 0.95)
  local COLOR_PROFILE = ImGui.ColorConvertDouble4ToU32(0.25, 0.68, 0.90, 0.92)
  local COLOR_OUTPUT = ImGui.ColorConvertDouble4ToU32(0.30, 0.74, 0.54, 0.95)
  local COLOR_ERROR = ImGui.ColorConvertDouble4ToU32(1.0, 0.35, 0.22, 1.0)

  local ORDER_NAMES = { "1OA / 4ch", "2OA / 9ch", "3OA / 16ch" }
  local ORDER_VALUES = { 1, 2, 3 }
  local PROFILE_NAMES = { "Median profile", "Mean profile" }
  local PROFILE_KEYS = { "median", "mean" }
  local FFT_NAMES = { "1024", "2048", "4096" }
  local FFT_VALUES = { 1024, 2048, 4096 }

  local function clamp(value, lo, hi)
    if value < lo then return lo end
    if value > hi then return hi end
    return value
  end

  local function get_number(key, default)
    return tonumber(reaper.GetExtState(EXT, key)) or default
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

  local function order_index_for_channels(channels)
    if channels >= 16 then return 3 end
    if channels >= 9 then return 2 end
    return 1
  end

  local function order_channels(order_index)
    local order = ORDER_VALUES[order_index] or 1
    return (order + 1) * (order + 1)
  end

  local function direction_count(order_index)
    local order = ORDER_VALUES[order_index] or 1
    if order <= 1 then return 6 end
    if order == 2 then return 12 end
    return 24
  end

  local function is_wav(path)
    return tostring(path or ""):lower():match("%.wav$") ~= nil
  end

  local function basename(path)
    return tostring(path or ""):match("[^/\\]+$") or tostring(path or "")
  end

  local function source_duration(entry)
    return entry.length * math.max(0.000001, entry.playrate or 1.0)
  end

  local function validate(source, profile, settings)
    if not source or not profile then return "Select a source item and a profile/reference item." end
    if source.filename == "" or not nr.file_exists(source.filename) or not is_wav(source.filename) then
      return "The source item must be backed by a readable WAV file."
    end
    if profile.filename == "" or not nr.file_exists(profile.filename) or not is_wav(profile.filename) then
      return "The profile/reference item must be backed by a readable WAV file."
    end
    local needed = order_channels(settings.order_index)
    if source.channels < needed then
      return "The source item has " .. tostring(source.channels) .. " channels, but this order needs " .. tostring(needed) .. "."
    end
    if profile.channels < needed then
      return "The profile/reference item has " .. tostring(profile.channels) .. " channels, but this order needs " .. tostring(needed) .. "."
    end
    return nil
  end

  local function draw_box(draw_list, x0, y0, x1, y1, title, detail, color)
    ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, COLOR_PANEL)
    ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, color or COLOR_EDGE)
    ImGui.DrawList_AddText(draw_list, x0 + 9, y0 + 9, COLOR_TEXT, title)
    ImGui.DrawList_AddText(draw_list, x0 + 9, y0 + 30, COLOR_MUTED, detail)
  end

  local function draw_arrow(draw_list, x0, y0, x1, y1, color)
    ImGui.DrawList_AddLine(draw_list, x0, y0, x1, y1, color, 2.0)
    ImGui.DrawList_AddTriangleFilled(draw_list, x1, y1, x1 - 7, y1 - 4, x1 - 7, y1 + 4, color)
  end

  local function draw_flow(ctx, settings)
    local width = math.max(560, ImGui.GetContentRegionAvail(ctx) - 2)
    local height = 214
    ImGui.InvisibleButton(ctx, "##spectral_profile_tool_flow", width, height)
    local x0, y0 = ImGui.GetItemRectMin(ctx)
    local x1, y1 = x0 + width, y0 + height
    local draw_list = ImGui.GetWindowDrawList(ctx)
    ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, COLOR_BG)
    ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, COLOR_EDGE)
    ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 12, COLOR_TEXT, string.lower(config.short_title or TITLE))

    local margin = 14
    local gap = 16
    local box_h = 58
    local left_w = math.max(130, (width - margin * 2 - gap * 3) * 0.23)
    local mid_w = math.max(145, (width - margin * 2 - gap * 3) * 0.25)
    local proc_w = math.max(145, (width - margin * 2 - gap * 3) * 0.25)
    local out_w = math.max(130, width - margin * 2 - gap * 3 - left_w - mid_w - proc_w)
    local source_y = y0 + 48
    local profile_y = y0 + 123
    local left_x = x0 + margin
    local mid_x = left_x + left_w + gap
    local proc_x = mid_x + mid_w + gap
    local out_x = proc_x + proc_w + gap

    draw_box(draw_list, left_x, source_y, left_x + left_w, source_y + box_h, "source HOA", ORDER_NAMES[settings.order_index], COLOR_EDGE)
    draw_box(draw_list, left_x, profile_y, left_x + left_w, profile_y + box_h, config.profile_box or "profile HOA", config.profile_detail or "reference material", COLOR_PROFILE)
    draw_box(draw_list, mid_x, source_y, mid_x + mid_w, source_y + box_h, "source directions", tostring(direction_count(settings.order_index)) .. " decoded feeds", COLOR_FLOW)
    draw_box(draw_list, mid_x, profile_y, mid_x + mid_w, profile_y + box_h, "profile model", config.model_detail or "per-direction spectrum", COLOR_PROFILE)
    draw_box(draw_list, proc_x, y0 + 83, proc_x + proc_w, y0 + 83 + box_h, config.process_box or "spectral process", config.process_detail or "same direction bins", COLOR_FLOW)
    draw_box(draw_list, out_x, y0 + 83, out_x + out_w, y0 + 83 + box_h, config.output_box or "output HOA", "re-encoded HOA", COLOR_OUTPUT)

    draw_arrow(draw_list, left_x + left_w + 3, source_y + box_h * 0.5, mid_x - 5, source_y + box_h * 0.5, COLOR_FLOW)
    draw_arrow(draw_list, left_x + left_w + 3, profile_y + box_h * 0.5, mid_x - 5, profile_y + box_h * 0.5, COLOR_PROFILE)
    draw_arrow(draw_list, mid_x + mid_w + 3, source_y + box_h * 0.5, proc_x - 5, y0 + 83 + box_h * 0.5, COLOR_FLOW)
    ImGui.DrawList_AddLine(draw_list, mid_x + mid_w + 3, profile_y + box_h * 0.5, proc_x - 5, y0 + 83 + box_h * 0.5 + 12, COLOR_PROFILE, 1.4)
    ImGui.DrawList_AddTriangleFilled(draw_list, proc_x - 5, y0 + 83 + box_h * 0.5 + 12, proc_x - 12, y0 + 83 + box_h * 0.5 + 8, proc_x - 12, y0 + 83 + box_h * 0.5 + 16, COLOR_PROFILE)
    draw_arrow(draw_list, proc_x + proc_w + 3, y0 + 83 + box_h * 0.5, out_x - 5, y0 + 83 + box_h * 0.5, COLOR_OUTPUT)

    ImGui.DrawList_AddText(draw_list, left_x + 4, y1 - 24, COLOR_MUTED, config.flow_note or "The profile item is analyzed; it is not mixed directly into the output.")
  end

  local function run_render(source, profile, settings)
    local err = validate(source, profile, settings)
    if err then mc.show_error(err) return end

    local stamp = tostring(math.floor(reaper.time_precise() * 1000))
    local order = ORDER_VALUES[settings.order_index] or 1
    local output_channels = order_channels(settings.order_index)
    local output_dir = nr.output_dir(config.output_folder, source.filename, script_dir)
    local output_path = output_dir .. "/" .. config.output_prefix .. "_" .. stamp .. "_" .. tostring(order) .. "oa.wav"
    local fft_size = FFT_VALUES[settings.fft_index] or 2048
    local hop_size = math.floor(fft_size / settings.overlap + 0.5)

    local manifest = {
      source_path = source.filename,
      source_start = source.start_offset or 0,
      source_duration = source_duration(source),
      profile_path = profile.filename,
      profile_start = profile.start_offset or 0,
      profile_duration = source_duration(profile),
      sample_rate = nr.source_sample_rate(source),
      output_path = output_path,
      order = order,
      process_kind = config.process_kind,
      process_name = TITLE,
      output_mode = config.output_mode or "cleaned",
      profile_stat = PROFILE_KEYS[settings.profile_index] or "median",
      reduction_amount = settings.reduction_amount,
      spectral_floor = settings.spectral_floor,
      profile_sensitivity = settings.profile_sensitivity,
      frequency_smoothing_bins = math.floor(settings.frequency_smoothing_bins + 0.5),
      temporal_smoothing = settings.temporal_smoothing,
      fft_size = fft_size,
      hop_size = hop_size,
      dc_protect = settings.dc_protect,
      soft_limit = settings.soft_limit,
      normalize = settings.normalize,
      normalize_db = settings.normalize_db,
    }

    local total_start = reaper.time_precise()
    local log, elapsed = nr.run_backend(script_dir, "foafx_spectral_profile_tool", manifest, TITLE)
    if not log then return end

    reaper.Undo_BeginBlock()
    local item, insert_err = nr.insert_output_item(output_path, config.track_label .. " (" .. tostring(order) .. "OA)", source.position, output_channels, {
      master_send = false,
      track_gain = 0.5,
    })
    reaper.Undo_EndBlock(TITLE, -1)
    if not item then mc.show_error(insert_err or "Could not insert output item.") return end

    local lines = {
      "Source: " .. source.name .. " (" .. tostring(source.channels) .. "ch)",
      (config.profile_log_label or "Profile") .. ": " .. profile.name .. " (" .. tostring(profile.channels) .. "ch)",
      "Order: " .. tostring(order) .. "OA",
      "Direction feeds: " .. tostring(direction_count(settings.order_index)),
      "Backend: Python WAV reader + NumPy",
    }
    if log ~= "" then lines[#lines + 1] = log end
    lines[#lines + 1] = "Inserted track gain: -6.0 dB"
    lines[#lines + 1] = "Master send: off"
    lines[#lines + 1] = string.format("NumPy time: %.2f sec", elapsed)
    lines[#lines + 1] = string.format("Total time: %.2f sec", reaper.time_precise() - total_start)
    lines[#lines + 1] = "Output: " .. output_path
    mc.print_plan(TITLE, lines)
  end

  local entries = nr.selected_entries()
  if #entries < 2 then
    mc.show_error(config.selection_error or "Select two WAV-backed ambisonic media items. The earliest selected item is the source; the next selected item is the profile/reference.")
    return
  end
  local source = entries[1]
  local profile = entries[2]

  local ctx = ImGui.CreateContext(TITLE)
  local open = true
  local should_render = false
  local defaults = config.defaults or {}
  local settings = {
    order_index = clamp(math.floor(get_number("order_index", order_index_for_channels(source.channels))), 1, 3),
    profile_index = clamp(math.floor(get_number("profile_index", defaults.profile_index or 1)), 1, #PROFILE_NAMES),
    reduction_amount = get_number("reduction_amount", defaults.reduction_amount or 0.72),
    spectral_floor = get_number("spectral_floor", defaults.spectral_floor or 0.18),
    profile_sensitivity = get_number("profile_sensitivity", defaults.profile_sensitivity or 1.15),
    frequency_smoothing_bins = get_number("frequency_smoothing_bins", defaults.frequency_smoothing_bins or 3),
    temporal_smoothing = get_number("temporal_smoothing", defaults.temporal_smoothing or 0.35),
    fft_index = clamp(math.floor(get_number("fft_index", defaults.fft_index or 2)), 1, #FFT_NAMES),
    overlap = clamp(math.floor(get_number("overlap", defaults.overlap or 4)), 2, 8),
    dc_protect = get_bool("dc_protect", true),
    soft_limit = get_bool("soft_limit", true),
    normalize = get_bool("normalize", true),
    normalize_db = get_number("normalize_db", -6.0),
  }

  local function persist()
    for key, value in pairs(settings) do set_value(key, value) end
  end

  local function loop()
    ImGui.SetNextWindowSize(ctx, 760, config.window_height or 735, WINDOW_OPEN_COND)
    local visible
    visible, open = ImGui.Begin(ctx, TITLE, open)
    if visible then
      local validation = validate(source, profile, settings)
      ImGui.Text(ctx, "Source: " .. source.name .. "  (" .. tostring(source.channels) .. " ch)")
      ImGui.Text(ctx, (config.profile_label or "Profile") .. ": " .. profile.name .. "  (" .. tostring(profile.channels) .. " ch)")
      ImGui.Spacing(ctx)
      draw_flow(ctx, settings)
      ImGui.Spacing(ctx)

      settings.order_index = combo(ctx, "Ambisonic order", settings.order_index, ORDER_NAMES)
      settings.profile_index = combo(ctx, "Profile statistic", settings.profile_index, PROFILE_NAMES)
      local changed
      changed, settings.reduction_amount = ImGui.SliderDouble(ctx, config.amount_label or "Amount", settings.reduction_amount, 0.0, 1.0, "%.2f")
      changed, settings.spectral_floor = ImGui.SliderDouble(ctx, config.floor_label or "Spectral floor", settings.spectral_floor, 0.0, 0.75, "%.2f")
      changed, settings.profile_sensitivity = ImGui.SliderDouble(ctx, config.sensitivity_label or "Profile sensitivity", settings.profile_sensitivity, 0.25, 4.0, "%.2f")
      changed, settings.frequency_smoothing_bins = ImGui.SliderInt(ctx, "Frequency smoothing bins", math.floor(settings.frequency_smoothing_bins), 0, 24)
      changed, settings.temporal_smoothing = ImGui.SliderDouble(ctx, "Temporal smoothing", settings.temporal_smoothing, 0.0, 0.95, "%.2f")
      settings.fft_index = combo(ctx, "FFT size", settings.fft_index, FFT_NAMES)
      changed, settings.overlap = ImGui.SliderInt(ctx, "Overlap", math.floor(settings.overlap), 2, 8)
      settings.overlap = clamp(math.floor(settings.overlap), 2, 8)
      changed, settings.dc_protect = ImGui.Checkbox(ctx, "DC protect", settings.dc_protect)
      changed, settings.soft_limit = ImGui.Checkbox(ctx, "Soft limit before normalize", settings.soft_limit)
      changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize output", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize peak dB", settings.normalize_db, -24.0, 0.0, "%.1f")
      end

      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Text(ctx, "Required channels per ambisonic item: " .. tostring(order_channels(settings.order_index)))
      ImGui.Text(ctx, "Directional feeds: " .. tostring(direction_count(settings.order_index)))
      ImGui.Text(ctx, "Source file: " .. basename(source.filename))
      ImGui.Text(ctx, (config.profile_label or "Profile") .. " file: " .. basename(profile.filename))
      if validation then
        ImGui.TextColored(ctx, COLOR_ERROR, validation)
      else
        ImGui.Text(ctx, "Renders offline from WAV media with NumPy.")
      end
      ImGui.Spacing(ctx)
      if ImGui.Button(ctx, "Render", 104, 28) and not validation then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 104, 28) then open = false end
      ImGui.End(ctx)
    end

    persist()
    if should_render then
      open = false
      run_render(source, profile, settings)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

return M
