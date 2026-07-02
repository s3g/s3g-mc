-- @description Automation Score
-- @author s3g
-- @version 0.1
-- @category Utils
-- @method Opens the browser-based Automation Score for composing generic breakpoint automation JSON.

local script_name = "Automation Score"

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local repo_root = script_dir:gsub("[/\\]Scripts[/\\]s3g%-mc[/\\]?$", "")

local function file_exists(path)
  local file = io.open(path, "rb")
  if file then file:close() return true end
  return false
end

local function utility_dir(name)
  local candidates = {
    script_dir .. "/utilities/" .. name,
    repo_root .. "/docs/utilities/" .. name,
  }
  for _, path in ipairs(candidates) do
    if file_exists(path .. "/index.html") then return path end
  end
  return nil
end

local tool_dir = utility_dir("automation-score-designer")
if not tool_dir then
  reaper.MB("Could not find automation-score-designer/index.html in Scripts/s3g-mc/utilities or docs/utilities.", script_name, 0)
  return
end

local function shell_quote(text)
  text = tostring(text or "")
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

local index_path = tool_dir .. "/index.html"
local sep = package.config:sub(1, 1)
if sep == "\\" then
  os.execute('start "" "' .. index_path .. '"')
else
  os.execute("open " .. shell_quote(index_path) .. " >/dev/null 2>&1 &")
end
