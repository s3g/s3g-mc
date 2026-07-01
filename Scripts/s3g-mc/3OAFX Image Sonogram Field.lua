-- @description 3OAFX Image Sonogram Field
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category 3OAFX
-- @render Yes; renders a multichannel or 3OA image-driven synthesis field.
-- @method Offline PNG-to-sound process where X is time, Y is frequency, and color data determines AED positioning. Amplitude comes from alpha, edge contrast, or a separate image.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

local TITLE = "3OAFX Image Sonogram Field"
if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", TITLE, 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
local EXT = "s3g_mc_image_aed_sonogram_v1"
local SELECTED_SOURCES = nr.selected_entries()
local SELECTED_SOURCE = SELECTED_SOURCES[1]

local SYNTH_MODES = { "Hybrid", "Additive partials", "Spectral additive", "Spectral noise", "Granular" }
local AMP_SOURCES = { "Edge contrast", "Alpha", "Separate image" }
local COLOR_MODELS = { "OKLCH", "HSL", "HSV", "YCbCr" }
local OUTPUT_MODES = { "3OA ACN/SN3D", "Multichannel ring" }
local ELEVATION_MODES = { "Sphere", "Hemisphere" }
local FREQ_MODES = { "Log", "Linear" }
local GRAIN_SOURCE_MODES = { "Image time", "Image frequency", "Image color", "Random", "Cycle" }
local GRAIN_SCAN_MODES = { "Image time", "Image frequency", "Diagonal", "Random", "Fixed" }
local GRAIN_CHANNEL_MODES = { "Image row", "Image color", "Random", "Cycle", "Mixdown" }

local function get(k, d)
  local v = reaper.GetExtState(EXT, k)
  if v == "" then return d end
  return v
end

local function getn(k, d)
  return tonumber(get(k, d)) or d
end

local function getb(k, d)
  local v = reaper.GetExtState(EXT, k)
  if v == "" then return d end
  return v ~= "0"
end

local function set(k, v)
  reaper.SetExtState(EXT, k, type(v) == "boolean" and (v and "1" or "0") or tostring(v), true)
end

local settings = {
  image_path = get("image_path", ""),
  amp_image_path = get("amp_image_path", ""),
  synth_mode = getn("synth_mode", 1),
  amp_source = getn("amp_source", 1),
  color_model = getn("color_model", 1),
  output_mode = getn("output_mode", 1),
  elevation_mode = getn("elevation_mode", 1),
  freq_mode = getn("freq_mode", 1),
  transpose_read = getb("transpose_read", false),
  duration = getn("duration", 8),
  channels = getn("channels", 8),
  order = getn("order", 3),
  columns = getn("columns", 192),
  rows = getn("rows", 96),
  max_bins = getn("max_bins", 18),
  min_freq = getn("min_freq", 80),
  max_freq = getn("max_freq", 6000),
  threshold = getn("threshold", 0.08),
  amp_gamma = getn("amp_gamma", 0.75),
  noise_blend = getn("noise_blend", 0.45),
  additive_smoothing = getn("additive_smoothing", 0.85),
  additive_sustain = getn("additive_sustain", 0.85),
  additive_attack = getn("additive_attack", 0.12),
  spectral_blur = getn("spectral_blur", 0.55),
  spectral_band_width = getn("spectral_band_width", 0.18),
  spectral_inertia = getn("spectral_inertia", 0.8),
  grain_ms = getn("grain_ms", 45),
  grain_density = getn("grain_density", 0.55),
  grain_pitch_spread = getn("grain_pitch_spread", 0.12),
  grain_source_mode = getn("grain_source_mode", 1),
  grain_scan_mode = getn("grain_scan_mode", 1),
  grain_channel_mode = getn("grain_channel_mode", 1),
  grain_source_position = getn("grain_source_position", 0),
  grain_source_jitter = getn("grain_source_jitter", 0.12),
  grain_rate_depth = getn("grain_rate_depth", 1),
  grain_reverse = getn("grain_reverse", 0),
  grain_taper = getn("grain_taper", 0.45),
  overlap = getn("overlap", 0.25),
  spatial_width = getn("spatial_width", 0.65),
  min_distance = getn("min_distance", 0),
  max_distance = getn("max_distance", 1),
  invert_distance = getb("invert_distance", false),
  azimuth_offset = getn("azimuth_offset", 0),
  drive = getn("drive", 0.9),
  normalize = getb("normalize", true),
  normalize_db = getn("normalize_db", -6),
  seed = getn("seed", 1),
}

local function persist()
  for k, v in pairs(settings) do set(k, v) end
end

local function combo(label, value, items)
  local current = items[value] or items[1]
  if ImGui.BeginCombo(ctx, label, current) then
    for i, item in ipairs(items) do
      local selected = value == i
      if ImGui.Selectable(ctx, item, selected) then value = i end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return value
end

local function choose_png(title, current)
  local ok, path = reaper.GetUserFileNameForRead(current or "", title, "png")
  if ok and path and path ~= "" then return path end
  return current
end

local function output_channels()
  if settings.output_mode == 1 then
    local order = math.max(1, math.min(3, math.floor(settings.order + 0.5)))
    return (order + 1) * (order + 1)
  end
  local channels = math.max(1, math.min(mc.MAX_REAPER_TRACK_CHANNELS, math.floor(settings.channels + 0.5)))
  if channels > 1 and channels % 2 == 1 then channels = channels + 1 end
  return math.min(mc.MAX_REAPER_TRACK_CHANNELS, channels)
end

local function value_key(items, index)
  return (items[index] or items[1]):lower():gsub("%s+", "_"):gsub("/", "_"):gsub("acn_sn3d", "3oa")
end

local function render()
  if settings.image_path == "" then
    mc.show_error("Choose a PNG image first.")
    return
  end
  if settings.synth_mode == 5 and #SELECTED_SOURCES < 1 then
    mc.show_error("Granular mode needs one or more selected WAV-backed media items to use as grain sources.")
    return
  end
  if settings.amp_source == 3 and settings.amp_image_path == "" then
    mc.show_error("Separate image amplitude mode needs an amplitude PNG.")
    return
  end
  local channels = output_channels()
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local out_dir = nr.output_dir("s3g_image_aed_sonogram_renders", settings.image_path, script_dir)
  local output_path = out_dir .. "/s3g_image_aed_sonogram_" .. stamp .. "_" .. tostring(channels) .. "ch.wav"
  local manifest = {
    output_path = output_path,
    image_path = settings.image_path,
    amp_image_path = settings.amp_image_path,
    sample_rate = SELECTED_SOURCE and nr.source_sample_rate(SELECTED_SOURCE) or 48000,
    source_count = settings.synth_mode == 5 and #SELECTED_SOURCES or 0,
    duration = settings.duration,
    synth_mode = value_key(SYNTH_MODES, settings.synth_mode):gsub("additive_partials", "additive"):gsub("spectral_noise", "noise"),
    amp_source = settings.amp_source == 1 and "edge" or (settings.amp_source == 2 and "alpha" or "separate"),
    color_model = value_key(COLOR_MODELS, settings.color_model),
    output_mode = settings.output_mode == 1 and "3oa" or "ring",
    channels = channels,
    order = math.max(1, math.min(3, math.floor(settings.order + 0.5))),
    elevation_mode = value_key(ELEVATION_MODES, settings.elevation_mode),
    freq_mode = value_key(FREQ_MODES, settings.freq_mode),
    transpose_read = settings.transpose_read,
    columns = math.floor(settings.columns + 0.5),
    rows = math.floor(settings.rows + 0.5),
    max_bins_per_column = math.floor(settings.max_bins + 0.5),
    min_freq = settings.min_freq,
    max_freq = settings.max_freq,
    threshold = settings.threshold,
    amp_gamma = settings.amp_gamma,
    noise_blend = settings.noise_blend,
    additive_smoothing = settings.additive_smoothing,
    additive_sustain = settings.additive_sustain,
    additive_attack = settings.additive_attack,
    spectral_blur = settings.spectral_blur,
    spectral_band_width = settings.spectral_band_width,
    spectral_inertia = settings.spectral_inertia,
    grain_ms = settings.grain_ms,
    grain_density = settings.grain_density,
    grain_pitch_spread = settings.grain_pitch_spread,
    grain_source_mode = value_key(GRAIN_SOURCE_MODES, settings.grain_source_mode),
    grain_scan_mode = value_key(GRAIN_SCAN_MODES, settings.grain_scan_mode),
    grain_channel_mode = value_key(GRAIN_CHANNEL_MODES, settings.grain_channel_mode),
    grain_source_position = settings.grain_source_position,
    grain_source_jitter = settings.grain_source_jitter,
    grain_rate_depth = settings.grain_rate_depth,
    grain_reverse = settings.grain_reverse,
    grain_taper = settings.grain_taper,
    overlap = settings.overlap,
    spatial_width = settings.spatial_width,
    min_distance = settings.min_distance,
    max_distance = settings.max_distance,
    invert_distance = settings.invert_distance,
    azimuth_offset = settings.azimuth_offset,
    drive = settings.drive,
    normalize = settings.normalize,
    normalize_db = settings.normalize_db,
    seed = math.floor(settings.seed + 0.5),
  }
  if settings.synth_mode == 5 then
    for i, source in ipairs(SELECTED_SOURCES) do
      manifest["source_path_" .. tostring(i)] = source.filename
      manifest["source_start_" .. tostring(i)] = source.start_offset
      manifest["source_duration_" .. tostring(i)] = source.length * math.max(0.000001, source.playrate)
    end
  end
  local log, elapsed = nr.run_backend(script_dir, "image_aed_sonogram", manifest, TITLE)
  if not log then return end
  reaper.Undo_BeginBlock()
  local item, err = nr.insert_output_item(output_path, "3OAFX Image Sonogram Field (" .. tostring(channels) .. "ch)", reaper.GetCursorPosition(), channels, { master_send = false, track_gain = 0.5 })
  reaper.Undo_EndBlock(TITLE, -1)
  if not item then mc.show_error(err or "Could not insert render.") return end
  local source_line = #SELECTED_SOURCES > 0 and ("Grain sources: " .. tostring(#SELECTED_SOURCES) .. " selected item(s)") or "Source: generated image synth"
  mc.print_plan(TITLE, { source_line, "Output: " .. output_path, string.format("NumPy time: %.2f sec", elapsed), log })
end

ctx = ImGui.CreateContext(TITLE)
local open = true
local run = false
local image_cache = {}
local edge_preview_cache = { signature = "", path = "", reason = "" }
local alpha_preview_cache = { signature = "", path = "", reason = "" }

local COLORS = {
  text = ImGui.ColorConvertDouble4ToU32(0.82, 0.88, 0.9, 1),
  muted = ImGui.ColorConvertDouble4ToU32(0.50, 0.58, 0.62, 1),
  edge = ImGui.ColorConvertDouble4ToU32(0.30, 0.34, 0.36, 1),
  graph = ImGui.ColorConvertDouble4ToU32(0.92, 0.96, 0.90, 0.62),
  graph_dim = ImGui.ColorConvertDouble4ToU32(0.92, 0.96, 0.90, 0.20),
  bg = ImGui.ColorConvertDouble4ToU32(0.045, 0.050, 0.055, 1),
  hot = ImGui.ColorConvertDouble4ToU32(0.94, 0.62, 0.28, 1),
  cyan = ImGui.ColorConvertDouble4ToU32(0.20, 0.72, 0.86, 1),
}

local function hash_text(text)
  local hash = 2166136261
  for i = 1, #text do
    hash = ((hash ~ text:byte(i)) * 16777619) % 4294967296
  end
  return string.format("%08x", hash)
end

local function amplitude_preview_signature(kind)
  return table.concat({
    kind or "edge",
    settings.image_path or "",
    tostring(math.floor(settings.columns + 0.5)),
    tostring(math.floor(settings.rows + 0.5)),
    settings.transpose_read and "1" or "0",
    string.format("%.5f", settings.threshold or 0),
    string.format("%.5f", settings.amp_gamma or 1),
  }, "|")
end

local function ensure_amplitude_preview(kind)
  if settings.image_path == "" then return nil, "No PNG selected." end
  kind = kind or "edge"
  local cache = kind == "alpha" and alpha_preview_cache or edge_preview_cache
  local signature = amplitude_preview_signature(kind)
  if cache.signature == signature and cache.path ~= "" and nr.file_exists(cache.path) then
    return cache.path, nil
  end
  local temp_dir = (os.getenv("TMPDIR") or "/tmp")
  local output_path = temp_dir .. "/s3g_image_" .. kind .. "_preview_" .. hash_text(signature) .. ".png"
  local manifest_path = temp_dir .. "/s3g_image_" .. kind .. "_preview_" .. hash_text(signature) .. ".json"
  local log_path = temp_dir .. "/s3g_image_" .. kind .. "_preview_" .. hash_text(signature) .. ".log"
  local manifest = {
    output_path = output_path,
    image_path = settings.image_path,
    preview_type = kind,
    columns = math.floor(settings.columns + 0.5),
    rows = math.floor(settings.rows + 0.5),
    transpose_read = settings.transpose_read,
    threshold = settings.threshold,
    amp_gamma = settings.amp_gamma,
  }
  local python = nr.find_python(script_dir)
  if not python then return nil, "python3 was not found." end
  if not nr.write_manifest(manifest_path, manifest) then return nil, "Could not write amplitude preview manifest." end
  local command = nr.shell_quote(python) .. " " .. nr.shell_quote(script_dir .. "s3g_numpy_render.py") ..
    " " .. nr.shell_quote("image_edge_preview") .. " " .. nr.shell_quote(manifest_path)
  local ok = nr.run_command(command, log_path)
  os.remove(manifest_path)
  os.remove(log_path)
  if not ok or not nr.file_exists(output_path) then
    local failed = { signature = signature, path = "", reason = "Could not render " .. kind .. " preview." }
    if kind == "alpha" then alpha_preview_cache = failed else edge_preview_cache = failed end
    return nil, failed.reason
  end
  local updated = { signature = signature, path = output_path, reason = "" }
  if kind == "alpha" then alpha_preview_cache = updated else edge_preview_cache = updated end
  return output_path, nil
end

local function read_axis_text()
  if settings.transpose_read then
    return "horizontal frequency / vertical time"
  end
  return "horizontal time / vertical frequency"
end

local function draw_read_graph(dl, x1, y1, x2, y2)
  if x2 <= x1 or y2 <= y1 then return end
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, COLORS.graph, 0, 0, 1.2)
  for i = 1, 3 do
    local gx = x1 + (x2 - x1) * i / 4
    local gy = y1 + (y2 - y1) * i / 4
    ImGui.DrawList_AddLine(dl, gx, y1, gx, y2, COLORS.graph_dim, 1)
    ImGui.DrawList_AddLine(dl, x1, gy, x2, gy, COLORS.graph_dim, 1)
  end
  local h_label = settings.transpose_read and "freq" or "time"
  local v_label = settings.transpose_read and "time" or "freq"
  local ax0, ay0 = x1, y2 + 13
  local ax1, ay1 = x2, y2 + 13
  local fx0, fy0 = x1 - 18, y2
  local fx1, fy1 = x1 - 18, y1
  ImGui.DrawList_AddLine(dl, ax0, ay0, ax1, ay1, COLORS.graph, 1.6)
  ImGui.DrawList_AddTriangleFilled(dl, ax1, ay1, ax1 - 8, ay1 - 4, ax1 - 8, ay1 + 4, COLORS.graph)
  ImGui.DrawList_AddText(dl, x1 + 4, ay0 + 3, COLORS.graph, h_label)
  ImGui.DrawList_AddLine(dl, fx0, fy0, fx1, fy1, COLORS.graph, 1.6)
  ImGui.DrawList_AddTriangleFilled(dl, fx1, fy1, fx1 - 4, fy1 + 8, fx1 + 4, fy1 + 8, COLORS.graph)
  ImGui.DrawList_AddText(dl, fx1 - 20, fy1 - 18, COLORS.graph, v_label)
end

local function draw_diagram()
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(420, ImGui.GetContentRegionAvail(ctx))
  local h = 118
  ImGui.InvisibleButton(ctx, "##image_aed_diagram", w, h)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, COLORS.bg)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, COLORS.edge)
  ImGui.DrawList_AddText(dl, x + 12, y + 10, COLORS.text, "image score")
  ImGui.DrawList_AddText(dl, x + 12, y + 30, COLORS.muted, read_axis_text())
  draw_read_graph(dl, x + 166, y + 24, x + w - 26, y + h - 35)
  for i = 0, 8 do
    local px = x + 176 + i * (w - 216) / 8
    local py = y + 28 + ((i * 37) % 72)
    local col = (i % 3 == 0) and COLORS.hot or ((i % 3 == 1) and COLORS.cyan or COLORS.text)
    ImGui.DrawList_AddCircleFilled(dl, px, py, 3 + (i % 4), col, 16)
  end
  ImGui.DrawList_AddText(dl, x + 12, y + 62, COLORS.muted, "hue -> az")
  ImGui.DrawList_AddText(dl, x + 12, y + 78, COLORS.muted, "light -> el")
  ImGui.DrawList_AddText(dl, x + 12, y + 94, COLORS.muted, "chroma -> dist")
end

local function png_size(path)
  local file = io.open(path or "", "rb")
  if not file then return nil, nil end
  local header = file:read(24) or ""
  file:close()
  if #header < 24 or header:sub(1, 8) ~= "\137PNG\r\n\026\n" then return nil, nil end
  local function be32(offset)
    local a, b, c, d = header:byte(offset, offset + 3)
    if not a then return nil end
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return be32(17), be32(21)
end

local function load_preview_image(key, path)
  local cache = image_cache[key] or {}
  if cache.path == path then return cache end
  cache = { path = path, image = nil, ok = false, reason = "" }
  image_cache[key] = cache
  if not path or path == "" then
    cache.reason = "No PNG selected."
    return cache
  end
  cache.w, cache.h = png_size(path)
  if not cache.w or not cache.h then
    cache.reason = "Preview expects a PNG file."
    return cache
  end
  if not ImGui.CreateImage or not ImGui.Image then
    cache.reason = "Image preview requires a newer ReaImGui image API."
    return cache
  end
  local ok, image = pcall(ImGui.CreateImage, path)
  if not ok or not image then
    cache.reason = "Could not load PNG preview."
    return cache
  end
  cache.image = image
  if ImGui.Attach then pcall(ImGui.Attach, ctx, image) end
  cache.ok = true
  return cache
end

local function draw_image_preview(key, title, path, max_h)
  local cache = load_preview_image(key, path)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = math.max(420, ImGui.GetContentRegionAvail(ctx))
  local h = max_h or 180
  ImGui.InvisibleButton(ctx, "##preview_box_" .. key, w, h)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, COLORS.bg)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, COLORS.edge)
  ImGui.DrawList_AddText(dl, x + 12, y + 10, COLORS.text, title)
  if cache.ok and cache.image then
    local iw, ih = cache.w or 1, cache.h or 1
    local axis_left = 48
    local axis_bottom = 28
    local draw_w = w - axis_left - 16
    local draw_h = h - 42 - axis_bottom
    local scale = math.min(draw_w / math.max(1, iw), draw_h / math.max(1, ih))
    draw_w = math.max(1, iw * scale)
    draw_h = math.max(1, ih * scale)
    local img_x = x + axis_left + (w - axis_left - 16 - draw_w) * 0.5
    local img_y = y + 30 + (h - 42 - axis_bottom - draw_h) * 0.5
    ImGui.SetCursorScreenPos(ctx, img_x, img_y)
    local ok = pcall(ImGui.Image, ctx, cache.image, draw_w, draw_h)
    if not ok then
      ImGui.SetCursorScreenPos(ctx, x + 12, y + 34)
      ImGui.TextColored(ctx, COLORS.muted, "Preview image could not be drawn.")
    else
      draw_read_graph(dl, img_x, img_y, img_x + draw_w, img_y + draw_h)
    end
  else
    ImGui.DrawList_AddText(dl, x + 12, y + 34, COLORS.muted, cache.reason or "Preview unavailable.")
  end
  ImGui.SetCursorScreenPos(ctx, x, y + h)
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 760, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local footer_h = 48
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    if ImGui.BeginChild(ctx, "##image_aed_body", 0, math.max(280, avail_h - footer_h)) then
      if settings.image_path ~= "" then
        draw_image_preview("color", "Color image preview", settings.image_path, 190)
      else
        draw_diagram()
      end
      if settings.amp_source == 1 and settings.image_path ~= "" then
        local edge_path, edge_err = ensure_amplitude_preview("edge")
        ImGui.Spacing(ctx)
        if edge_path then
          draw_image_preview("edge", "Edge contrast amplitude preview", edge_path, 150)
        else
          ImGui.TextColored(ctx, COLORS.muted, edge_err or "Edge preview unavailable.")
        end
      end
      if settings.amp_source == 2 and settings.image_path ~= "" then
        local alpha_path, alpha_err = ensure_amplitude_preview("alpha")
        ImGui.Spacing(ctx)
        if alpha_path then
          draw_image_preview("alpha", "Alpha amplitude preview", alpha_path, 150)
        else
          ImGui.TextColored(ctx, COLORS.muted, alpha_err or "Alpha preview unavailable.")
        end
      end
      if settings.amp_source == 3 and settings.amp_image_path ~= "" then
        ImGui.Spacing(ctx)
        draw_image_preview("amp", "Amplitude image preview", settings.amp_image_path, 150)
      end
      ImGui.Spacing(ctx)
      ImGui.Text(ctx, "Color image")
      ImGui.PushItemWidth(ctx, -120)
      local changed
      changed, settings.image_path = ImGui.InputText(ctx, "##image_path", settings.image_path)
      ImGui.PopItemWidth(ctx)
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Choose##image", 96, 24) then settings.image_path = choose_png("Choose color PNG", settings.image_path) end
      settings.amp_source = combo("Amplitude source", settings.amp_source, AMP_SOURCES)
      if settings.amp_source == 3 then
        ImGui.PushItemWidth(ctx, -120)
        changed, settings.amp_image_path = ImGui.InputText(ctx, "##amp_image_path", settings.amp_image_path)
        ImGui.PopItemWidth(ctx)
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Choose##amp", 96, 24) then settings.amp_image_path = choose_png("Choose amplitude PNG", settings.amp_image_path) end
      end

      settings.synth_mode = combo("Synthesis", settings.synth_mode, SYNTH_MODES)
      if settings.synth_mode == 5 then
        local source_text = #SELECTED_SOURCES > 0 and ("Grain sources: " .. tostring(#SELECTED_SOURCES) .. " selected item(s)") or "Grain sources: select one or more WAV-backed media items before rendering"
        ImGui.TextColored(ctx, #SELECTED_SOURCES > 0 and COLORS.text or COLORS.hot, source_text)
      end
      settings.output_mode = combo("Output", settings.output_mode, OUTPUT_MODES)
      if settings.output_mode == 1 then
        changed, settings.order = ImGui.SliderInt(ctx, "Ambisonic order", math.floor(settings.order), 1, 3)
      else
        changed, settings.channels = ImGui.SliderInt(ctx, "Output channels", math.floor(settings.channels), 2, 64)
      end
      settings.color_model = combo("Color model", settings.color_model, COLOR_MODELS)
      settings.elevation_mode = combo("Elevation", settings.elevation_mode, ELEVATION_MODES)
      settings.freq_mode = combo("Frequency scale", settings.freq_mode, FREQ_MODES)
      local read_label = settings.transpose_read and "Read: vertical time / horizontal frequency" or "Read: horizontal time / vertical frequency"
      if ImGui.Button(ctx, read_label, -1, 26) then
        settings.transpose_read = not settings.transpose_read
      end

      changed, settings.duration = ImGui.SliderDouble(ctx, "Duration", settings.duration, 0.5, 180, "%.2f sec")
      changed, settings.columns = ImGui.SliderInt(ctx, "Time columns", math.floor(settings.columns), 32, 512)
      changed, settings.rows = ImGui.SliderInt(ctx, "Frequency rows", math.floor(settings.rows), 16, 256)
      changed, settings.max_bins = ImGui.SliderInt(ctx, "Max active rows per column", math.floor(settings.max_bins), 1, 256)
      changed, settings.min_freq = ImGui.SliderDouble(ctx, "Min frequency", settings.min_freq, 20, 1000, "%.1f Hz")
      changed, settings.max_freq = ImGui.SliderDouble(ctx, "Max frequency", settings.max_freq, 500, 18000, "%.1f Hz")
      changed, settings.threshold = ImGui.SliderDouble(ctx, "Amplitude threshold", settings.threshold, 0, 0.95, "%.3f")
      changed, settings.amp_gamma = ImGui.SliderDouble(ctx, "Amplitude curve", settings.amp_gamma, 0.2, 3, "%.2f")
      if settings.synth_mode == 1 then
        changed, settings.noise_blend = ImGui.SliderDouble(ctx, "Hybrid noise blend", settings.noise_blend, 0, 1, "%.2f")
      end
      if settings.synth_mode == 2 then
        changed, settings.additive_smoothing = ImGui.SliderDouble(ctx, "Additive smoothing", settings.additive_smoothing, 0, 1, "%.2f")
        changed, settings.additive_sustain = ImGui.SliderDouble(ctx, "Additive sustain", settings.additive_sustain, 0, 1, "%.2f")
        changed, settings.additive_attack = ImGui.SliderDouble(ctx, "Additive attack", settings.additive_attack, 0, 1, "%.2f")
      end
      if settings.synth_mode == 3 then
        changed, settings.spectral_blur = ImGui.SliderDouble(ctx, "Spectral blur", settings.spectral_blur, 0, 1, "%.2f")
        changed, settings.spectral_band_width = ImGui.SliderDouble(ctx, "Spectral band width", settings.spectral_band_width, 0, 1, "%.2f")
        changed, settings.spectral_inertia = ImGui.SliderDouble(ctx, "Spectral inertia", settings.spectral_inertia, 0, 1, "%.2f")
        changed, settings.additive_attack = ImGui.SliderDouble(ctx, "Partial attack", settings.additive_attack, 0, 1, "%.2f")
      end
      if settings.synth_mode == 5 then
        changed, settings.grain_ms = ImGui.SliderDouble(ctx, "Grain duration", settings.grain_ms, 8, 240, "%.1f ms")
        changed, settings.grain_density = ImGui.SliderDouble(ctx, "Grain density", settings.grain_density, 0.05, 1, "%.2f")
        changed, settings.grain_pitch_spread = ImGui.SliderDouble(ctx, "Grain pitch spread", settings.grain_pitch_spread, 0, 1, "%.2f oct")
        changed, settings.grain_rate_depth = ImGui.SliderDouble(ctx, "Image pitch depth", settings.grain_rate_depth, 0, 2, "%.2f")
        settings.grain_source_mode = combo("Source item", settings.grain_source_mode, GRAIN_SOURCE_MODES)
        settings.grain_scan_mode = combo("Source scan", settings.grain_scan_mode, GRAIN_SCAN_MODES)
        if settings.grain_scan_mode == 5 then
          changed, settings.grain_source_position = ImGui.SliderDouble(ctx, "Source position", settings.grain_source_position, 0, 1, "%.2f")
        end
        changed, settings.grain_source_jitter = ImGui.SliderDouble(ctx, "Source jitter", settings.grain_source_jitter, 0, 1, "%.2f")
        settings.grain_channel_mode = combo("Source channel", settings.grain_channel_mode, GRAIN_CHANNEL_MODES)
        changed, settings.grain_reverse = ImGui.SliderDouble(ctx, "Reverse chance", settings.grain_reverse, 0, 1, "%.2f")
        changed, settings.grain_taper = ImGui.SliderDouble(ctx, "Grain taper", settings.grain_taper, 0, 1, "%.2f")
      end
      changed, settings.overlap = ImGui.SliderDouble(ctx, "Column overlap", settings.overlap, 0, 2, "%.2f")

      changed, settings.azimuth_offset = ImGui.SliderDouble(ctx, "Azimuth offset", settings.azimuth_offset, -180, 180, "%.0f deg")
      changed, settings.min_distance = ImGui.SliderDouble(ctx, "Min distance", settings.min_distance, 0, 2, "%.2f")
      changed, settings.max_distance = ImGui.SliderDouble(ctx, "Max distance", settings.max_distance, 0, 3, "%.2f")
      changed, settings.invert_distance = ImGui.Checkbox(ctx, "Invert distance", settings.invert_distance)
      changed, settings.spatial_width = ImGui.SliderDouble(ctx, "Ring spatial width", settings.spatial_width, 0.05, 2, "%.2f")
      changed, settings.drive = ImGui.SliderDouble(ctx, "Soft drive", settings.drive, 0.1, 3, "%.2f")
      changed, settings.normalize = ImGui.Checkbox(ctx, "Peak normalize", settings.normalize)
      if settings.normalize then
        changed, settings.normalize_db = ImGui.SliderDouble(ctx, "Normalize dB", settings.normalize_db, -36, 0, "%.1f")
      end
      changed, settings.seed = ImGui.InputInt(ctx, "Seed", math.floor(settings.seed))
      ImGui.TextColored(ctx, COLORS.muted, "PNG only in this first version. Alpha amplitude uses the image alpha channel; edge contrast uses local structure.")
      ImGui.EndChild(ctx)
    end
    if ImGui.Button(ctx, "Render", 110, 30) then run = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 100, 30) then open = false end
    ImGui.End(ctx)
  end
  persist()
  if run then open = false; render(); return end
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
