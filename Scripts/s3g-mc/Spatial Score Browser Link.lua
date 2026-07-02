-- @description Spatial Score Browser Link
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3
-- @category Utils
-- @method Opens the browser-based s3g-mc Spatial Score with the last loaded Spatial Score JSON and writes a small playhead file so the browser can follow REAPER transport.

local SCRIPT_NAME = "Spatial Score Browser Link"
local EXT_SECTION = "s3g-mc Spatial Score Link"
local PORT = 7429
local WRITE_INTERVAL = 0.033

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is required for " .. SCRIPT_NAME .. ".", SCRIPT_NAME, 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local ctx = ImGui.CreateContext(SCRIPT_NAME)
local open = true
local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local repo_root = script_dir:gsub("[/\\]Scripts[/\\]s3g%-mc[/\\]?$", "")
local json_path = reaper.GetExtState(EXT_SECTION, "json_path")
local start_pos = tonumber(reaper.GetExtState(EXT_SECTION, "start_pos")) or 0
local duration = tonumber(reaper.GetExtState(EXT_SECTION, "duration")) or 16
local status = "Ready"
local last_write = 0
local server_started = false
local tried_auto_launch = false

local function file_exists(path)
  local file = io.open(path, "rb")
  if file then file:close() return true end
  return false
end

local function find_utility_dir(name)
  local candidates = {
    script_dir .. "/utilities/" .. name,
    repo_root .. "/docs/utilities/" .. name,
  }
  for _, path in ipairs(candidates) do
    if file_exists(path .. "/index.html") then return path end
  end
  return nil
end

local mover_dir = find_utility_dir("mover") or (script_dir .. "/utilities/mover")

local function read_file(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local text = file:read("*a")
  file:close()
  return text
end

local function write_file(path, text)
  local file = io.open(path, "wb")
  if not file then return false end
  file:write(text or "")
  file:close()
  return true
end

local function shell_quote(text)
  text = tostring(text or "")
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function url_quote(text)
  text = tostring(text or "")
  return text:gsub("([^%w%-%_%.%~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
end

local function open_url(url)
  local sep = package.config:sub(1, 1)
  if sep == "\\" then
    os.execute('start "" "' .. url .. '"')
  else
    os.execute("open " .. shell_quote(url) .. " >/dev/null 2>&1 &")
  end
end

local function start_server()
  if server_started then return true end
  if not file_exists(mover_dir .. "/index.html") then
    status = "Could not find utilities/mover/index.html."
    return false
  end
  local sep = package.config:sub(1, 1)
  if sep == "\\" then
    os.execute('start "" /min python -m http.server ' .. tostring(PORT) ..
      ' --bind 127.0.0.1 --directory "' .. mover_dir .. '"')
  else
    os.execute("python3 -m http.server " .. tostring(PORT) ..
      " --bind 127.0.0.1 --directory " .. shell_quote(mover_dir) ..
      " >/dev/null 2>&1 &")
  end
  server_started = true
  return true
end

local function choose_json()
  local ok, path = reaper.GetUserFileNameForRead("", "Choose s3g-mc Spatial Score JSON", ".json")
  if ok and path ~= "" then
    json_path = path
    reaper.SetExtState(EXT_SECTION, "json_path", json_path, true)
    status = "Selected JSON: " .. (json_path:match("[^/\\]+$") or json_path)
    return true
  end
  return false
end

local function publish_json(prompt_if_missing)
  if json_path == "" or not file_exists(json_path) then
    if not prompt_if_missing then
      status = "No Spatial Score JSON is selected. Use Choose JSON, or run Load Spatial Score JSON first."
      return false
    end
    if not choose_json() then
      status = "No Spatial Score JSON selected."
      return false
    end
  end
  local text = read_file(json_path)
  if not text then
    status = "Could not read JSON."
    return false
  end
  if not write_file(mover_dir .. "/reaper-link.json", text) then
    status = "Could not write reaper-link.json."
    return false
  end
  return true
end

local function playhead_json()
  local play_state = reaper.GetPlayState()
  local playing = (play_state & 1) == 1
  local position = playing and reaper.GetPlayPosition() or reaper.GetCursorPosition()
  local t = duration > 0 and ((position - start_pos) / duration) or 0
  if t < 0 then t = 0 end
  if t > 1 then t = 1 end
  return string.format(
    '{"tool":"s3g-mc Spatial Score Link","version":1,"playing":%s,"position":%.9f,"start":%.9f,"duration":%.9f,"t":%.9f,"updated":%.9f}',
    playing and "true" or "false",
    position,
    start_pos,
    duration,
    t,
    reaper.time_precise()
  )
end

local function publish_playhead(force)
  local now = reaper.time_precise()
  if not force and now - last_write < WRITE_INTERVAL then return end
  last_write = now
  write_file(mover_dir .. "/reaper-playhead.json", playhead_json())
end

local function launch_browser()
  if not publish_json(true) then return end
  publish_playhead(true)
  if not start_server() then return end
  local url = "http://127.0.0.1:" .. tostring(PORT) ..
    "/?reaper_link=1&cache=" .. url_quote(tostring(math.floor(reaper.time_precise() * 1000)))
  open_url(url)
  status = "Browser link active on port " .. tostring(PORT)
end

local function draw()
  ImGui.SetNextWindowSize(ctx, 430, 210, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, SCRIPT_NAME, open)
  if visible then
    ImGui.Text(ctx, "s3g-mc Spatial Score browser link")
    ImGui.Separator(ctx)
    ImGui.TextWrapped(ctx, "JSON: " .. (json_path ~= "" and json_path or "none"))
    ImGui.Text(ctx, string.format("Range: %.2f - %.2f sec", start_pos, start_pos + duration))
    if ImGui.Button(ctx, "Open / Refresh Browser") then launch_browser() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Choose JSON") then
      if choose_json() then publish_json() end
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Stop") then open = false end
    ImGui.Separator(ctx)
    ImGui.TextWrapped(ctx, status)
    ImGui.End(ctx)
  end
end

local function auto_launch_if_ready()
  if tried_auto_launch then return end
  tried_auto_launch = true
  if json_path ~= "" and file_exists(json_path) then
    if not publish_json(false) then return end
    publish_playhead(true)
    if not start_server() then return end
    local url = "http://127.0.0.1:" .. tostring(PORT) ..
      "/?reaper_link=1&cache=" .. url_quote(tostring(math.floor(reaper.time_precise() * 1000)))
    open_url(url)
    status = "Browser link active on port " .. tostring(PORT)
  else
    status = "Ready. Choose a Spatial Score JSON, or run Load Spatial Score JSON first."
  end
end

auto_launch_if_ready()

local function loop()
  publish_playhead(false)
  draw()
  if open then reaper.defer(loop) end
end

reaper.defer(loop)
