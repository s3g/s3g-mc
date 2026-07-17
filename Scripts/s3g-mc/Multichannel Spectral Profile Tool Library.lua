-- @description Multichannel Spectral Profile Tool Library
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
local ui_theme = nil
do
  local _s3g_theme_path = ({ reaper.get_action_context() })[2]
  if not _s3g_theme_path or _s3g_theme_path == "" then
    _s3g_theme_path = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
  end
  local _s3g_theme_dir = _s3g_theme_path:match("^(.*[/\\])") or ""
  package.path = _s3g_theme_dir .. "?.lua;" .. package.path
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme and _s3g_theme.install then _s3g_theme.install(ImGui); ui_theme = _s3g_theme end
end

  local WINDOW_OPEN_COND = ImGui.Cond_Appearing
  local EXT = config.ext

  local FLOW = {
    bg = ImGui.ColorConvertDouble4ToU32(0.035, 0.039, 0.042, 1.0),
    panel = ImGui.ColorConvertDouble4ToU32(0.060, 0.066, 0.070, 1.0),
    edge = ImGui.ColorConvertDouble4ToU32(0.34, 0.38, 0.38, 1.0),
    text = ImGui.ColorConvertDouble4ToU32(0.78, 0.83, 0.82, 1.0),
    muted = ImGui.ColorConvertDouble4ToU32(0.48, 0.54, 0.54, 1.0),
    flow = ImGui.ColorConvertDouble4ToU32(0.95, 0.68, 0.25, 0.95),
    profile = ImGui.ColorConvertDouble4ToU32(0.25, 0.68, 0.90, 0.92),
    output = ImGui.ColorConvertDouble4ToU32(0.30, 0.74, 0.54, 0.95),
    error = ImGui.ColorConvertDouble4ToU32(1.0, 0.35, 0.22, 1.0),
  }

  local PROFILE_NAMES = { "Median profile", "Mean profile" }
  local PROFILE_KEYS = { "median", "mean" }
  local CHANNEL_NAMES = { "Matched channels", "Wrap profile channels", "Summed profile to all" }
  local CHANNEL_KEYS = { "matched", "wrap", "summed" }
  local FFT_NAMES = { "1024", "2048", "4096", "8192" }
  local FFT_VALUES = { 1024, 2048, 4096, 8192 }

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
    local changed, next_index = ui_theme.combo_row(ImGui, ctx, label, names, index)
    return changed and next_index or index
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
    if source.channels > 128 then return "The source item exceeds REAPER's 128-channel track limit." end
    if settings.channel_index == 1 and profile.channels < source.channels then
      return "Matched channel mode needs at least as many profile channels as source channels. Use Wrap or Summed mode for smaller profile items."
    end
    return nil
  end

  local function draw_box(draw_list, x0, y0, x1, y1, title, detail, color)
    ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, FLOW.panel)
    ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, color or FLOW.edge)
    ImGui.DrawList_AddText(draw_list, x0 + 9, y0 + 9, FLOW.text, title)
    ImGui.DrawList_AddText(draw_list, x0 + 9, y0 + 30, FLOW.muted, detail)
  end

  local function draw_arrow(draw_list, x0, y0, x1, y1, color)
    ImGui.DrawList_AddLine(draw_list, x0, y0, x1, y1, color, 2.0)
    ImGui.DrawList_AddTriangleFilled(draw_list, x1, y1, x1 - 7, y1 - 4, x1 - 7, y1 + 4, color)
  end

  local function draw_flow(ctx, source, profile, settings)
    local width = math.max(560, ImGui.GetContentRegionAvail(ctx) - 2)
    local height = 190
    ImGui.InvisibleButton(ctx, "##mc_spectral_profile_flow", width, height)
    local x0, y0 = ImGui.GetItemRectMin(ctx)
    local x1, y1 = x0 + width, y0 + height
    local draw_list = ImGui.GetWindowDrawList(ctx)
    ImGui.DrawList_AddRectFilled(draw_list, x0, y0, x1, y1, FLOW.bg)
    ImGui.DrawList_AddRect(draw_list, x0, y0, x1, y1, FLOW.edge)
    ImGui.DrawList_AddText(draw_list, x0 + 14, y0 + 12, FLOW.text, string.lower(config.short_title or TITLE))

    local margin = 14
    local gap = 16
    local box_h = 58
    local box_w = (width - margin * 2 - gap * 3) / 4
    local bx = x0 + margin
    local by = y0 + 58
    draw_box(draw_list, bx, by, bx + box_w, by + box_h, "source", tostring(source.channels) .. " channels", FLOW.edge)
    draw_box(draw_list, bx + (box_w + gap), by, bx + (box_w + gap) + box_w, by + box_h, config.profile_box or "profile", tostring(profile.channels) .. " channels", FLOW.profile)
    draw_box(draw_list, bx + (box_w + gap) * 2, by, bx + (box_w + gap) * 2 + box_w, by + box_h, config.process_box or "profile process", CHANNEL_NAMES[settings.channel_index], FLOW.flow)
    draw_box(draw_list, bx + (box_w + gap) * 3, by, bx + (box_w + gap) * 3 + box_w, by + box_h, config.output_box or "output", "source channel count", FLOW.output)
    draw_arrow(draw_list, bx + box_w + 3, by + box_h * 0.5, bx + box_w + gap - 5, by + box_h * 0.5, FLOW.profile)
    draw_arrow(draw_list, bx + (box_w + gap) * 2 + box_w + 3, by + box_h * 0.5, bx + (box_w + gap) * 3 - 5, by + box_h * 0.5, FLOW.output)
    ImGui.DrawList_AddText(draw_list, bx + 4, y1 - 24, FLOW.muted, config.flow_note or "No ambisonic decode is used; source channel layout is preserved.")
  end

  local function run_render(source, profile, settings)
    local err = validate(source, profile, settings)
    if err then mc.show_error(err) return end

    local stamp = tostring(math.floor(reaper.time_precise() * 1000))
    local output_dir = nr.output_dir(config.output_folder, source.filename, script_dir)
    local output_path = output_dir .. "/" .. config.output_prefix .. "_" .. stamp .. "_" .. tostring(source.channels) .. "ch.wav"
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
      process_kind = config.process_kind,
      process_name = TITLE,
      output_mode = config.output_mode or "cleaned",
      channel_mode = CHANNEL_KEYS[settings.channel_index] or "matched",
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
    local log, elapsed = nr.run_backend(script_dir, "multichannel_spectral_profile_tool", manifest, TITLE)
    if not log then return end

    reaper.Undo_BeginBlock()
    local item, insert_err = nr.insert_output_item(output_path, config.track_label .. " (" .. tostring(source.channels) .. "ch)", source.position, source.channels, {
      master_send = false,
      track_gain = 0.5,
    })
    reaper.Undo_EndBlock(TITLE, -1)
    if not item then mc.show_error(insert_err or "Could not insert output item.") return end

    local lines = {
      "Source: " .. source.name .. " (" .. tostring(source.channels) .. "ch)",
      (config.profile_log_label or "Profile") .. ": " .. profile.name .. " (" .. tostring(profile.channels) .. "ch)",
      "Channel mode: " .. (CHANNEL_NAMES[settings.channel_index] or "?"),
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
    mc.show_error(config.selection_error or "Select two WAV-backed media items. The earliest selected item is the source; the next selected item is the profile/reference.")
    return
  end
  local source = entries[1]
  local profile = entries[2]

  local ctx = ImGui.CreateContext(TITLE)
  local open = true
  local should_render = false
  local defaults = config.defaults or {}
  local settings = {
    channel_index = clamp(math.floor(get_number("channel_index", defaults.channel_index or 1)), 1, #CHANNEL_NAMES),
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
    ImGui.SetNextWindowSize(ctx, 720, config.window_height or 690, WINDOW_OPEN_COND)
    local visible
    visible, open = ImGui.Begin(ctx, TITLE, open)
    if visible then
      local validation = validate(source, profile, settings)
      ui_theme.muted(ImGui, ctx, "SOURCE: " .. source.name .. "  (" .. tostring(source.channels) .. " CH)")
      ui_theme.muted(ImGui, ctx, (config.profile_label or "Profile"):upper() .. ": " .. profile.name .. "  (" .. tostring(profile.channels) .. " CH)")
      ImGui.Spacing(ctx)
      draw_flow(ctx, source, profile, settings)
      ImGui.Spacing(ctx)

      local panel = ui_theme.push_soft_panel(ImGui, ctx)
      settings.channel_index = combo(ctx, "Channel mode", settings.channel_index, CHANNEL_NAMES)
      settings.profile_index = combo(ctx, "Profile statistic", settings.profile_index, PROFILE_NAMES)
      local changed
      changed, settings.reduction_amount = ui_theme.slider_double(ImGui, ctx, config.amount_label or "Amount", settings.reduction_amount, 0.0, 1.0, "%.2f")
      changed, settings.spectral_floor = ui_theme.slider_double(ImGui, ctx, config.floor_label or "Spectral floor", settings.spectral_floor, 0.0, 0.75, "%.2f")
      changed, settings.profile_sensitivity = ui_theme.slider_double(ImGui, ctx, config.sensitivity_label or "Profile sensitivity", settings.profile_sensitivity, 0.25, 4.0, "%.2f")
      changed, settings.frequency_smoothing_bins = ui_theme.slider_int(ImGui, ctx, "Frequency smoothing bins", math.floor(settings.frequency_smoothing_bins), 0, 24)
      changed, settings.temporal_smoothing = ui_theme.slider_double(ImGui, ctx, "Temporal smoothing", settings.temporal_smoothing, 0.0, 0.95, "%.2f")
      settings.fft_index = combo(ctx, "FFT size", settings.fft_index, FFT_NAMES)
      changed, settings.overlap = ui_theme.slider_int(ImGui, ctx, "Overlap", math.floor(settings.overlap), 2, 8)
      settings.overlap = clamp(math.floor(settings.overlap), 2, 8)
      changed, settings.dc_protect = ui_theme.checkbox_row(ImGui, ctx, "DC protect", settings.dc_protect)
      changed, settings.soft_limit = ui_theme.checkbox_row(ImGui, ctx, "Soft limit before normalize", settings.soft_limit)
      changed, settings.normalize = ui_theme.checkbox_row(ImGui, ctx, "Peak normalize output", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = ui_theme.slider_double(ImGui, ctx, "Normalize peak dB", settings.normalize_db, -24.0, 0.0, "%.1f")
      end
      ui_theme.pop_soft_panel(ImGui, ctx, panel)

      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ui_theme.muted(ImGui, ctx, "OUTPUT CHANNELS: " .. tostring(source.channels))
      ui_theme.muted(ImGui, ctx, "SOURCE FILE: " .. basename(source.filename))
      ui_theme.muted(ImGui, ctx, (config.profile_label or "Profile"):upper() .. " FILE: " .. basename(profile.filename))
      if validation then
        ui_theme.status(ImGui, ctx, validation, "warn")
      else
        ui_theme.muted(ImGui, ctx, "RENDERS OFFLINE FROM WAV MEDIA WITH NUMPY.")
      end
      ImGui.Spacing(ctx)
      if ImGui.Button(ctx, "RENDER", 104, 28) and not validation then should_render = true end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "CANCEL", 104, 28) then open = false end
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
