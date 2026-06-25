-- @description NumPy Render Library
-- @browser hidden

local M = {}
local mc = dofile((debug.getinfo(1, "S").source:match("^@(.+[/\\])") or "") .. "Multichannel Library.lua")

function M.shell_quote(path)
  return "'" .. tostring(path):gsub("'", "'\\''") .. "'"
end

function M.trim(text)
  return (text or ""):match("^%s*(.-)%s*$")
end

function M.dirname(path)
  return tostring(path or ""):match("^(.*)[/\\][^/\\]+$") or ""
end

function M.file_exists(path)
  local file = io.open(path, "rb")
  if file then file:close() return true end
  return false
end

function M.read_file(path)
  local file = io.open(path, "rb")
  if not file then return "" end
  local text = file:read("*a") or ""
  file:close()
  return text
end

function M.run_command(command, log_path)
  if log_path then command = command .. " > " .. M.shell_quote(log_path) .. " 2>&1" end
  local result = os.execute(command)
  return result == true or result == 0
end

function M.find_python(script_dir)
  local configured_path = script_dir .. "python3_path.txt"
  if M.file_exists(configured_path) then
    local file = io.open(configured_path, "rb")
    local configured = file and M.trim(file:read("*a") or "") or ""
    if file then file:close() end
    if configured ~= "" and M.file_exists(configured) then return configured end
  end
  local home = os.getenv("HOME") or ""
  local candidates = { "/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3" }
  if home ~= "" then
    table.insert(candidates, 1, home .. "/miniconda3/bin/python3")
    table.insert(candidates, 2, home .. "/miniforge3/bin/python3")
    table.insert(candidates, 3, home .. "/anaconda3/bin/python3")
  end
  for _, path in ipairs(candidates) do
    if M.file_exists(path) then return path end
  end
  local handle = io.popen("command -v python3 2>/dev/null")
  if handle then
    local path = M.trim(handle:read("*a"))
    handle:close()
    if path ~= "" and M.file_exists(path) then return path end
  end
  return nil
end

function M.media_source_filename(source)
  if not source then return "" end
  local ok, a, b = pcall(reaper.GetMediaSourceFileName, source, "", 4096)
  if ok then
    if type(b) == "string" and b ~= "" then return b end
    if type(a) == "string" and a ~= "" then return a end
  end
  ok, a, b = pcall(reaper.GetMediaSourceFileName, source, "")
  if ok then
    if type(b) == "string" and b ~= "" then return b end
    if type(a) == "string" and a ~= "" then return a end
  end
  local parent = reaper.GetMediaSourceParent and reaper.GetMediaSourceParent(source)
  if parent and parent ~= source then return M.media_source_filename(parent) end
  return ""
end

function M.selected_entries()
  local entries = {}
  for index = 0, reaper.CountSelectedMediaItems(mc.PROJECT) - 1 do
    local item = reaper.GetSelectedMediaItem(mc.PROJECT, index)
    local take = item and reaper.GetActiveTake(item)
    local source = take and reaper.GetMediaItemTake_Source(take)
    local channels = take and mc.get_take_source_channels(take)
    if item and take and source and channels and channels > 0 then
      entries[#entries + 1] = {
        item = item,
        take = take,
        source = source,
        filename = M.media_source_filename(source),
        channels = channels,
        position = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
        length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
        start_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS"),
        playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE"),
        name = mc.item_label(item),
      }
    end
  end
  table.sort(entries, function(a, b) return a.position < b.position end)
  return entries
end

function M.source_sample_rate(entry)
  if not entry or not entry.source then return 48000 end
  local sr = reaper.GetMediaSourceSampleRate(entry.source)
  if not sr or sr <= 0 then return 48000 end
  return math.floor(sr + 0.5)
end

function M.json_string(value)
  local text = tostring(value or "")
  text = text:gsub("\\", "\\\\")
  text = text:gsub("\"", "\\\"")
  text = text:gsub("\n", "\\n")
  text = text:gsub("\r", "\\r")
  text = text:gsub("\t", "\\t")
  return "\"" .. text .. "\""
end

function M.write_manifest(path, data)
  local file = io.open(path, "w")
  if not file then return false end
  local function write_value(value)
    if type(value) == "boolean" then return value and "true" or "false" end
    if type(value) == "number" then return tostring(value) end
    return M.json_string(value)
  end
  file:write("{\n")
  local keys = {}
  for key in pairs(data) do keys[#keys + 1] = key end
  table.sort(keys)
  for index, key in ipairs(keys) do
    file:write("  " .. M.json_string(key) .. ": " .. write_value(data[key]))
    if index < #keys then file:write(",") end
    file:write("\n")
  end
  file:write("}\n")
  file:close()
  return true
end

function M.output_dir(folder_name, source_path, script_dir)
  local project_path = ({ reaper.EnumProjects(-1, "") })[2] or ""
  project_path = project_path ~= "" and M.dirname(project_path) or ""
  local source_dir = source_path and source_path ~= "" and M.dirname(source_path) or ""
  local fallback = reaper.GetResourcePath and reaper.GetResourcePath() or (os.getenv("TMPDIR") or "/tmp")
  local dir = project_path ~= "" and (project_path .. "/" .. folder_name) or
    ((source_dir ~= "" and source_dir or (script_dir or fallback)) .. "/" .. folder_name)
  reaper.RecursiveCreateDirectory(dir, 0)
  return dir
end

function M.insert_output_item(path, label, position, channel_count, options)
  options = options or {}
  local source = reaper.PCM_Source_CreateFromFile(path)
  if not source then return nil, "REAPER could not create a PCM source from output file." end
  local source_length = ({ reaper.GetMediaSourceLength(source) })[1] or 0
  reaper.InsertTrackAtIndex(reaper.CountTracks(mc.PROJECT), true)
  local track = reaper.GetTrack(mc.PROJECT, reaper.CountTracks(mc.PROJECT) - 1)
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", label, true)
  reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", mc.reaper_track_channel_count(channel_count))
  if options.track_gain then
    reaper.SetMediaTrackInfo_Value(track, "D_VOL", options.track_gain)
  end
  local item = reaper.AddMediaItemToTrack(track)
  local take = reaper.AddTakeToMediaItem(item)
  reaper.SetMediaItemTake_Source(take, source)
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", position or 0)
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", source_length)
  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", label, true)
  mc.select_only_track(track)
  mc.select_only_item(item)
  if reaper.UpdateItemInProject then reaper.UpdateItemInProject(item) end
  reaper.Main_OnCommand(40245, 0)
  reaper.UpdateArrange()
  return item, nil
end

function M.run_backend(script_dir, mode, manifest, title)
  local python = M.find_python(script_dir)
  if not python then mc.show_error("python3 was not found.") return nil end
  local numpy_log = (os.getenv("TMPDIR") or "/tmp") .. "/s3g-mc_numpy_check.log"
  if not M.run_command(M.shell_quote(python) .. " -c " .. M.shell_quote("import numpy"), numpy_log) then
    mc.show_error("Python was found, but NumPy could not be imported.\n\n" .. M.read_file(numpy_log))
    return nil
  end
  local stamp = tostring(math.floor(reaper.time_precise() * 1000))
  local temp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/s3g-mc_numpy_render_" .. stamp
  reaper.RecursiveCreateDirectory(temp_dir, 0)
  local manifest_path = temp_dir .. "/manifest.json"
  local log_path = temp_dir .. "/render.log"
  if not M.write_manifest(manifest_path, manifest) then
    mc.show_error("Could not write temporary NumPy manifest.")
    return nil
  end
  local backend = script_dir .. "s3g_numpy_render.py"
  local command = M.shell_quote(python) .. " " .. M.shell_quote(backend) .. " " ..
    M.shell_quote(mode) .. " " .. M.shell_quote(manifest_path)
  local start = reaper.time_precise()
  local ok = M.run_command(command, log_path)
  local elapsed = reaper.time_precise() - start
  local log = M.trim(M.read_file(log_path))
  os.remove(manifest_path)
  os.remove(log_path)
  os.remove(temp_dir)
  if not ok or not M.file_exists(manifest.output_path) then
    reaper.MB("NumPy render failed.\n\n" .. log .. "\n\nCommand:\n" .. command, title or "NumPy render", 0)
    return nil
  end
  return log, elapsed
end

return M
