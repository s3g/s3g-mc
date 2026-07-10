-- @description Spatial Score Browser Link
-- @author s3g
-- @version 0.2
-- @category Deprecated
-- @browser hidden
-- @method Retired compatibility action. Runs Load Spatial Score JSON, which now supports direct AED automation for any focused/touched FX with Azimuth, Elevation, and Distance parameters.

local SCRIPT_NAME = "Spatial Score Browser Link"

local script_path = ({ reaper.get_action_context() })[2] or ""
local script_dir = script_path:match("^(.*[/\\])") or ""
local loader_path = script_dir .. "Load Spatial Score JSON.lua"

local file = io.open(loader_path, "rb")
if file then
  file:close()
  dofile(loader_path)
else
  reaper.MB("Spatial Score Browser Link has been retired.\n\nRun Load Spatial Score JSON instead.", SCRIPT_NAME, 0)
end
