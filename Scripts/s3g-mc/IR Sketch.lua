-- @description IR Sketch (Deprecated)
-- @author s3g
-- @version 0.2
-- @category Utils
-- @browser hidden
-- @method Compatibility launcher for projects and actions created before IR Sketch became Imprint Sketch.

local script_name = "IR Sketch (Deprecated)"

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local repo_root = script_dir:gsub("[/\\]Scripts[/\\]s3g%-mc[/\\]?$", "")

local function file_exists(path)
  local file = io.open(path, "rb")
  if file then file:close() return true end
  return false
end

local utility_dir
for _, path in ipairs({
  script_dir .. "/utilities/imprint-sketch-designer",
  repo_root .. "/docs/utilities/imprint-sketch-designer",
}) do
  if file_exists(path .. "/index.html") then utility_dir = path break end
end

if not utility_dir then
  reaper.MB("Could not find Imprint Sketch. Reinstall or update the s3g-mc package.", script_name, 0)
  return
end

reaper.MB("IR Sketch has moved to Imprint Sketch. This compatibility action will now open the replacement utility.", script_name, 0)

local function shell_quote(text)
  text = tostring(text or "")
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

local index_path = utility_dir .. "/index.html"
if package.config:sub(1, 1) == "\\" then
  os.execute('start "" "' .. index_path .. '"')
else
  os.execute("open " .. shell_quote(index_path) .. " >/dev/null 2>&1 &")
end
