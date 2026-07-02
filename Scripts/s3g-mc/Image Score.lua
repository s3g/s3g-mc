-- @description Image Score
-- @author s3g
-- @version 0.1
-- @category Package / Utilities
-- @method Opens the browser-based Image Score for composing PNG scores used by 3OAFX Image Sonogram Field.

local script_name = "Image Score"

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local repo_root = script_dir:gsub("[/\\]Scripts[/\\]s3g%-mc[/\\]?$", "")

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

local utility_dir = find_utility_dir("image-score-generator")
if not utility_dir then
  reaper.MB("Could not find image-score-generator/index.html in Scripts/s3g-mc/utilities or docs/utilities.", script_name, 0)
  return
end

local function shell_quote(text)
  text = tostring(text or "")
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

local index_path = utility_dir .. "/index.html"
local sep = package.config:sub(1, 1)
if sep == "\\" then
  os.execute('start "" "' .. index_path .. '"')
else
  os.execute("open " .. shell_quote(index_path) .. " >/dev/null 2>&1 &")
end
