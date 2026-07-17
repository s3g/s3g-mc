-- @description Dense Grain Cloud
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Offline Synthesis / IR
-- @render Yes; renders a dense multichannel grain cloud from the selected media item.
-- @method Offline NumPy grain renderer. Select one WAV-backed media item, choose duration, channel count, grain count, grain size, pitch scatter, and spatial spread; the action writes a new multichannel media item.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")
local be = dofile(script_dir .. "Breakpoint Envelope Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Dense Grain Cloud", 0)
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

local WINDOW_OPEN_COND = ImGui.Cond_Appearing

local EXT = "s3g_mc_dense_grain_cloud_v2"

local ENV_DEFS = {
  { key = "amplitude", label = "Amplitude", min = 0.0, max = 1.5, default = 1.0, fmt = "%.2f" },
  { key = "density", label = "Density", min = 0.0, max = 1.0, default = 1.0, fmt = "%.2f" },
  { key = "spread", label = "Spatial spread", min = 0.02, max = 6.0, fmt = "%.2f" },
  { key = "pitch_scatter", label = "Pitch scatter", min = 0.0, max = 2.0, fmt = "%.2f oct" },
}

local function get_number(key, default)
  local value = tonumber(reaper.GetExtState(EXT, key))
  return value or default
end

local function set_number(key, value)
  reaper.SetExtState(EXT, key, tostring(value), true)
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
  ["DURATION SEC"] = "DUR",
  ["OUTPUT CHANNELS"] = "OUT CH",
  ["GRAIN MS"] = "GRAIN",
  ["LENGTH VARIATION"] = "LEN VAR",
  ["PITCH SCATTER OCT"] = "PITCH",
  ["SPATIAL SPREAD"] = "SPREAD",
  ["CHANNEL CONTRAST"] = "CONTR",
  ["SOURCE BIAS BY CHANNEL"] = "BIAS",
  ["DENSITY SHAPE"] = "SHAPE",
  ["CLOUD GAIN"] = "GAIN",
  ["NORMALIZE DB"] = "NORM DB",
  ["INSERTED TRACK GAIN"] = "INSERT",
}

local function row_label_text(label)
  local upper = tostring(label or ""):upper()
  return LABEL_ABBR[upper] or upper
end

local function row_layout(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local avail = ImGui.GetContentRegionAvail(ctx)
  if type(avail) ~= "number" then avail = 560 end
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
  ImGui.SetNextItemWidth(ctx, math.min(control_w, 104))
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
  ImGui.Dummy(ctx, 1, 1)
end

local function render(entry, settings, env_points, env_enabled)
  if entry.filename == "" or not nr.file_exists(entry.filename) then
    mc.show_error("The selected source item must be backed by a readable WAV file.")
    return
  end
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_grain_cloud_renders", entry.filename, script_dir)
  local output_path = out_dir .. "/s3g_dense_grain_cloud_" .. stamp .. "_" .. tostring(settings.channels) .. "ch.wav"
  local manifest = {
    source_path = entry.filename,
    source_start = entry.start_offset,
    source_duration = entry.length * math.max(0.000001, entry.playrate),
    output_path = output_path,
    sample_rate = nr.source_sample_rate(entry),
    duration = settings.duration,
    channels = settings.channels,
    grains = settings.grains,
    grain_ms = settings.grain_ms,
    grain_jitter = settings.grain_jitter,
    density = settings.density,
    pitch_scatter = settings.pitch_scatter,
    spread = settings.spread,
    channel_contrast = settings.channel_contrast,
    source_bias = settings.source_bias,
    density_shape = settings.density_shape,
    gain = settings.gain,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    seed = settings.seed,
  }
  be.add_to_manifest(manifest, ENV_DEFS, env_points, env_enabled)

  local log, elapsed = nr.run_backend(script_dir, "dense_grain", manifest, "Dense Grain Cloud")
  if not log then return end

  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path,
    "Dense grain cloud (" .. tostring(settings.channels) .. "ch)", entry.position, settings.channels,
    { track_gain = settings.insert_gain })
  reaper.Undo_EndBlock("Dense Grain Cloud", -1)
  if not item then mc.show_error(err or "Could not insert rendered grain cloud.") return end

  mc.print_plan("Dense Grain Cloud", {
    "Source: " .. entry.name .. " (" .. tostring(entry.channels) .. "ch)",
    "Output: " .. output_path,
    "Duration: " .. tostring(settings.duration) .. " sec",
    "Channels: " .. tostring(settings.channels),
    "Inserted track gain: " .. string.format("%.1f dB", 20 * math.log(settings.insert_gain, 10)),
    "NumPy time: " .. string.format("%.2f sec", elapsed),
    log,
  })
end

local function main()
  local entries = nr.selected_entries()
  if #entries < 1 then
    mc.show_error("Select one WAV-backed audio media item first.")
    return
  end
  local entry = entries[1]
  local settings = {
    duration = get_number("duration", math.max(1.0, entry.length)),
    channels = get_number("channels", math.max(2, entry.channels)),
    grains = get_number("grains", 2400),
    grain_ms = get_number("grain_ms", 80),
    grain_jitter = get_number("grain_jitter", 0.55),
    density = get_number("density", 1.0),
    pitch_scatter = get_number("pitch_scatter", 0.35),
    spread = get_number("spread", 0.28),
    channel_contrast = get_number("channel_contrast", 0.75),
    source_bias = get_number("source_bias", 0.55),
    density_shape = get_number("density_shape", 0.0),
    gain = get_number("gain", 0.75),
    normalize = reaper.GetExtState(EXT, "normalize") ~= "0",
    normalize_db = get_number("normalize_db", -12.0),
    insert_gain = get_number("insert_gain", 0.25),
    seed = get_number("seed", 1),
  }
  local env_points, env_enabled = be.init(ENV_DEFS, settings)
  be.load_extstate(EXT, ENV_DEFS, env_points, env_enabled)

  local ctx = ImGui.CreateContext("Dense Grain Cloud")
  local open = true
  local should_render = false
  local selected_env = 1
  local selected_env_point = nil
  local env_opts = { height = 150, overview_lane_h = 56, random_amount = 0.35, random_count = 12, random_dispersion = 0.25, random_smooth = false, collapse_editor = true, compact_window_h = 760, expanded_window_h = 760 }

  local function loop()
    ImGui.SetNextWindowSize(ctx, 760, env_opts._editor_was_open and env_opts.expanded_window_h or env_opts.compact_window_h, ImGui.Cond_Always)
    local visible
    visible, open = ImGui.Begin(ctx, "Dense Grain Cloud", open)
    if visible then
      local _, avail_h = ImGui.GetContentRegionAvail(ctx)
      local footer_h = 48
      local control_h = math.max(260, (avail_h or env_opts.compact_window_h) - footer_h)
      if ImGui.BeginChild(ctx, "##dense_grain_controls", 0, control_h) then
      theme.muted(ImGui, ctx, "Source: " .. entry.name .. "  (" .. tostring(entry.channels) .. " ch)")
      local changed
      ImGui.Spacing(ctx)
      selected_env, selected_env_point = be.draw(ImGui, ctx, ENV_DEFS, env_points, env_enabled, selected_env,
        selected_env_point, settings, env_opts)
      ImGui.Separator(ctx)
      local sx, sy, sh, stack = section(ctx, "Render", 148)
      changed, settings.duration = draw_custom_slider(ctx, "Duration sec", settings.duration, 0.25, 300.0, "%.2f", false)
      changed, settings.channels = draw_custom_slider(ctx, "Output channels", math.floor(settings.channels), 1, mc.MAX_REAPER_TRACK_CHANNELS, nil, true)
      changed, settings.grains = draw_custom_slider(ctx, "Grains", math.floor(settings.grains), 64, 20000, nil, true)
      changed, settings.density = draw_custom_slider(ctx, "Density", settings.density, 0.0, 1.0, "%.2f", false)
      finish_section(ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = section(ctx, "Cloud", 252)
      changed, settings.grain_ms = draw_custom_slider(ctx, "Grain ms", settings.grain_ms, 4.0, 800.0, "%.1f", false)
      changed, settings.grain_jitter = draw_custom_slider(ctx, "Length variation", settings.grain_jitter, 0.0, 0.95, "%.2f", false)
      changed, settings.pitch_scatter = draw_custom_slider(ctx, "Pitch scatter oct", settings.pitch_scatter, 0.0, 2.0, "%.2f", false)
      changed, settings.spread = draw_custom_slider(ctx, "Spatial spread", settings.spread, 0.02, 6.0, "%.2f", false)
      changed, settings.channel_contrast = draw_custom_slider(ctx, "Channel contrast", settings.channel_contrast, 0.0, 1.0, "%.2f", false)
      changed, settings.source_bias = draw_custom_slider(ctx, "Source bias by channel", settings.source_bias, 0.0, 1.0, "%.2f", false)
      changed, settings.density_shape = draw_custom_slider(ctx, "Density shape", settings.density_shape, -1.0, 1.0, "%.2f", false)
      changed, settings.gain = draw_custom_slider(ctx, "Cloud gain", settings.gain, 0.05, 4.0, "%.2f", false)
      finish_section(ctx, sx, sy, sh, stack)
      sx, sy, sh, stack = section(ctx, "Render", settings.normalize and 148 or 122)
      changed, settings.normalize = draw_checkbox(ctx, "Peak normalize", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = draw_custom_slider(ctx, "Normalize dB", settings.normalize_db, -36.0, -3.0, "%.1f", false)
      end
      changed, settings.insert_gain = draw_custom_slider(ctx, "Inserted track gain", settings.insert_gain, 0.05, 1.0, "%.2f", false)
      changed, settings.seed = draw_int_input(ctx, "Seed", settings.seed)
      finish_section(ctx, sx, sy, sh, stack)
      settings.channels = clamp(math.floor(settings.channels), 1, mc.MAX_REAPER_TRACK_CHANNELS)
        ImGui.EndChild(ctx)
      end
      local render_pressed, cancel_pressed = theme.footer_buttons(ImGui, ctx, "RENDER", "CANCEL", 104, 104)
      if render_pressed then should_render = true end
      if cancel_pressed then open = false end
      ImGui.End(ctx)
    end

    if should_render then
      open = false
      for key, value in pairs(settings) do
        if type(value) == "boolean" then
          reaper.SetExtState(EXT, key, value and "1" or "0", true)
        else
          set_number(key, value)
        end
      end
      be.save_extstate(EXT, ENV_DEFS, env_points, env_enabled)
      render(entry, settings, env_points, env_enabled)
      return
    end
    if open then reaper.defer(loop) end
  end

  reaper.defer(loop)
end

main()
