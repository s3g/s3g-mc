-- @description s3g-mc Package Browser
-- @author s3g
-- @version 0.1
-- @requires ReaImGui
-- @category Utils
-- @about
--   Browser and launcher for the s3g-mc REAPER script collection. Scans this
--   folder for Lua scripts, groups them by practical workflow category, and
--   can register package scripts in REAPER's Action List.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "s3g-mc Package Browser", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local ctx = ImGui.CreateContext("s3g-mc Package Browser")
local open = true
local script_path = ({reaper.get_action_context()})[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local script_name = script_path:match("[^/\\]+$") or "s3g-mc Package Browser.lua"
local search = ""
local active_category = "All"
local status = ""
local detail_level = 2
local scripts = {}
local command_cache = {}

local COLORS = {
  panel = ImGui.ColorConvertDouble4ToU32(0.055, 0.060, 0.065, 1),
  edge = ImGui.ColorConvertDouble4ToU32(0.29, 0.31, 0.33, 1),
  text = ImGui.ColorConvertDouble4ToU32(0.78, 0.82, 0.84, 1),
  dim = ImGui.ColorConvertDouble4ToU32(0.48, 0.52, 0.54, 1),
}

local CATEGORY_ORDER = {
  "All",
  "Channel Mixing / Automation",
  "MIDI Composition",
  "Procedural Synthesis",
  "Offline Synthesis / IR",
  "Spatial Panners",
  "3OAFX",
  "Spectral / Convolution",
  "Multichannel Texture / Montage",
  "Item Channel Transforms",
  "Track Building / Routing",
  "Utils",
}

local CATEGORY_LABELS = {
  ["All"] = "All",
  ["Channel Mixing / Automation"] = "Channel Mixing",
  ["MIDI Composition"] = "MIDI",
  ["Procedural Synthesis"] = "Procedural Synth",
  ["Offline Synthesis / IR"] = "Offline Synth / IR",
  ["Spatial Panners"] = "Spatial Panners",
  ["3OAFX"] = "3OAFX",
  ["Spectral / Convolution"] = "Spectral",
  ["Multichannel Texture / Montage"] = "Texture",
  ["Item Channel Transforms"] = "Items",
  ["Track Building / Routing"] = "Routing",
  ["Utils"] = "Utils",
}

local function path_join(left, right)
  if left:match("[/\\]$") then return left .. right end
  return left .. "/" .. right
end

local function trim(text)
  return (text or ""):match("^%s*(.-)%s*$")
end

local function read_metadata(path)
  local meta = {
    description = nil,
    version = "",
    requires = "",
    method = "",
    render = "",
    category = "",
    browser = "",
    about = "",
  }
  local file = io.open(path, "r")
  if not file then return meta end

  local in_about = false
  for line in file:lines() do
    local description = line:match("^%-%- @description%s+(.+)$")
    local version = line:match("^%-%- @version%s+(.+)$")
    local requires = line:match("^%-%- @requires%s+(.+)$")
    local method = line:match("^%-%- @method%s+(.+)$")
    local render = line:match("^%-%- @render%s+(.+)$")
    local category = line:match("^%-%- @category%s+(.+)$")
    local browser = line:match("^%-%- @browser%s+(.+)$")
    if description then
      meta.description = trim(description)
      in_about = false
    elseif version then
      meta.version = trim(version)
      in_about = false
    elseif requires then
      requires = trim(requires)
      if requires ~= "" then
        meta.requires = meta.requires == "" and requires or (meta.requires .. "; " .. requires)
      end
      in_about = false
    elseif method then
      method = trim(method)
      if method ~= "" then
        meta.method = meta.method == "" and method or (meta.method .. "; " .. method)
      end
      in_about = false
    elseif render then
      render = trim(render)
      if render ~= "" then
        meta.render = meta.render == "" and render or (meta.render .. "; " .. render)
      end
      in_about = false
    elseif category then
      meta.category = trim(category)
      in_about = false
    elseif browser then
      meta.browser = trim(browser):lower()
      in_about = false
    elseif line:match("^%-%- @about") then
      in_about = true
    elseif in_about then
      local about_line = line:match("^%-%-%s?(.*)$")
      if about_line then
        about_line = trim(about_line)
        if about_line ~= "" then
          meta.about = meta.about == "" and about_line or (meta.about .. " " .. about_line)
        end
      else
        in_about = false
      end
    elseif not line:match("^%-%-") and line ~= "" then
      break
    end
  end

  file:close()
  return meta
end

local function classify(name, description)
  local hay = (name .. " " .. (description or "")):lower()
  if hay:find("cdp") or hay:find("reacoma") then return "Personal / Advanced" end
  if hay:find("midi") or hay:find("euclidean") or hay:find("polymetric") then return "MIDI Composition" end
  if hay:find("carto synth") or hay:find("procedural synth") then return "Procedural Synthesis" end
  if hay:find("shred") or hay:find("fracture") or hay:find("zigzag") or hay:find("cascade") or hay:find("crumble") or hay:find("spatial repeater") then return "Multichannel Texture / Montage" end
  if hay:find("3oafx") then return "3OAFX" end
  if hay:find("lbap") or hay:find("panner") or hay:find("dome") or hay:find("spatial automation") then return "Spatial Panners" end
  if hay:find("automation") or hay:find("mixer") or hay:find("fader") then return "Channel Mixing / Automation" end
  if hay:find("selected item") or hay:find("multichannel item") or hay:find("item channel") or hay:find("shred") then return "Item Channel Transforms" end
  if hay:find("selected tracks") or hay:find("selected mono tracks") or hay:find("track from") or hay:find("routing") then return "Track Building / Routing" end
  return "Utils"
end

local function scan_scripts()
  local found = {}
  command_cache = {}
  local index = 0
  while true do
    local filename = reaper.EnumerateFiles(script_dir, index)
    if not filename then break end
    index = index + 1

    if filename:match("%.lua$") then
      local path = path_join(script_dir, filename)
      local meta = read_metadata(path)
      if meta.browser ~= "hidden" then
        local description = meta.description or filename:gsub("%.lua$", "")
        found[#found + 1] = {
          filename = filename,
          path = path,
          description = description,
          version = meta.version,
          requires = meta.requires,
          method = meta.method,
          render = meta.render,
          about = meta.about,
          category = meta.category ~= "" and meta.category or classify(filename, description),
        }
      end
    end
  end

  table.sort(found, function(a, b)
    if a.category == b.category then return a.description:lower() < b.description:lower() end
    return a.category < b.category
  end)
  scripts = found
  status = string.format("Found %d package scripts", #scripts)
end

local function ensure_action(entry)
  if command_cache[entry.path] then return command_cache[entry.path] end
  local command_id = reaper.AddRemoveReaScript(true, 0, entry.path, true)
  if command_id and command_id ~= 0 and reaper.ReverseNamedCommandLookup then
    local named = reaper.ReverseNamedCommandLookup(command_id)
    if named and named ~= "" then
      local resolved = reaper.NamedCommandLookup(named)
      if resolved and resolved ~= 0 then
        command_cache[entry.path] = resolved
        return resolved
      end
    end
  end
  return nil
end

local function matches_filter(entry)
  if active_category ~= "All" and entry.category ~= active_category then return false end
  local q = trim(search):lower()
  if q == "" then return true end
  local hay = table.concat({entry.filename, entry.description, entry.category, entry.requires, entry.render, entry.method, entry.about}, " "):lower()
  return hay:find(q, 1, true) ~= nil
end

local function launch_script(entry)
  local command_id = ensure_action(entry)
  if command_id then
    status = "Running " .. entry.description
    reaper.Main_OnCommand(command_id, 0)
    return
  end

  status = "Running directly: " .. entry.description
  local ok, err = pcall(dofile, entry.path)
  if not ok then
    status = "Launch failed: " .. tostring(err)
    reaper.MB(tostring(err), "s3g-mc Package Browser", 0)
  end
end

local function register_actions()
  local count = 0
  for _, entry in ipairs(scripts) do
    if entry.filename ~= script_name then
      local command_id = reaper.AddRemoveReaScript(true, 0, entry.path, true)
      if command_id and command_id ~= 0 then count = count + 1 end
    end
  end
  status = string.format("Registered/refreshed %d scripts in the Action List", count)
end

local function category_button(label)
  local display = CATEGORY_LABELS[label] or label
  local shown = active_category == label and ("*" .. display) or display
  if ImGui.Button(ctx, shown) then active_category = label end
end

local function draw_category_buttons()
  local rows = {
    { "All", "Channel Mixing / Automation", "MIDI Composition", "Procedural Synthesis", "Offline Synthesis / IR" },
    { "Spatial Panners", "3OAFX", "Spectral / Convolution", "Multichannel Texture / Montage" },
    { "Item Channel Transforms", "Track Building / Routing", "Utils" },
  }
  for _, row in ipairs(rows) do
    for index, category in ipairs(row) do
      if index > 1 then ImGui.SameLine(ctx) end
      category_button(category)
    end
  end
end

local function wrapped_line_count(text, width)
  text = tostring(text or "")
  if text == "" then return 0 end
  width = math.max(80, width or 80)
  local avg_char_width = 8
  local space_width = avg_char_width
  local lines = 1
  local line_width = 0

  for word in text:gmatch("%S+") do
    local word_width = #word * avg_char_width
    local needed = line_width > 0 and (space_width + word_width) or word_width
    if line_width > 0 and line_width + needed > width then
      lines = lines + 1
      line_width = word_width
    else
      line_width = line_width + needed
    end

    while line_width > width do
      lines = lines + 1
      line_width = line_width - width
    end
  end

  return lines
end

local function metadata_line_height(text, width)
  if text == "" then return 0 end
  return wrapped_line_count(text, width) * 21
end

local function draw_wrapped_text(text, color_value, width)
  if text == "" then return end
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, color_value)
  ImGui.PushTextWrapPos(ctx, ImGui.GetCursorScreenPos(ctx) + width)
  ImGui.TextWrapped(ctx, text)
  ImGui.PopTextWrapPos(ctx)
  ImGui.PopStyleColor(ctx)
end

local function draw_wrapped_metadata(label, value, width)
  if value == "" then return end
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, COLORS.dim)
  ImGui.PushTextWrapPos(ctx, ImGui.GetCursorScreenPos(ctx) + width)
  ImGui.TextWrapped(ctx, label .. value)
  ImGui.PopTextWrapPos(ctx)
  ImGui.PopStyleColor(ctx)
  if ImGui.IsItemHovered(ctx) and #value > 90 then
    ImGui.SetTooltip(ctx, value)
  end
end

local function draw_script_card(entry)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  local button_w = 76
  local button_h = 24
  local pad = 10
  local narrow = w < 430
  local text_w = narrow and math.max(80, w - pad * 2) or math.max(120, w - button_w - pad * 5)
  local h = 12
  h = h + metadata_line_height(entry.description, text_w)
  h = h + metadata_line_height(entry.category .. (entry.version ~= "" and ("  v" .. entry.version) or "") .. "  -  " .. entry.filename, text_w)
  if entry.requires ~= "" then h = h + metadata_line_height("Requires: " .. entry.requires, text_w) end
  if entry.render ~= "" then h = h + metadata_line_height("Render: " .. entry.render, text_w) end
  if detail_level >= 2 and entry.method ~= "" then h = h + metadata_line_height("Method: " .. entry.method, text_w) end
  if detail_level >= 3 and entry.about ~= "" then h = h + metadata_line_height(entry.about, text_w) end
  if narrow then h = h + button_h + pad end
  h = math.max(h + 18, narrow and 96 or 70)
  local mx, my = ImGui.GetMousePos(ctx)
  local hovered = mx >= x and mx <= x + w and my >= y and my <= y + h

  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + w, y + h, COLORS.panel)
  ImGui.DrawList_AddRect(draw_list, x, y, x + w, y + h, hovered and COLORS.text or COLORS.edge)
  ImGui.SetCursorScreenPos(ctx, x + pad, y + 8)
  draw_wrapped_text(entry.description, COLORS.text, text_w)
  draw_wrapped_text(entry.category .. (entry.version ~= "" and ("  v" .. entry.version) or "") .. "  -  " .. entry.filename, COLORS.dim, text_w)
  if entry.requires ~= "" then
    draw_wrapped_metadata("Requires: ", entry.requires, text_w)
  end
  if entry.render ~= "" then
    draw_wrapped_metadata("Render: ", entry.render, text_w)
  end
  if detail_level >= 2 and entry.method ~= "" then
    draw_wrapped_metadata("Method: ", entry.method, text_w)
  end
  if detail_level >= 3 and entry.about ~= "" then
    draw_wrapped_metadata("", entry.about, text_w)
  end

  local button_x = narrow and (x + w - button_w - pad) or (x + w - button_w - pad)
  local button_y = narrow and (y + h - button_h - pad) or (y + 8)
  ImGui.SetCursorScreenPos(ctx, button_x, button_y)
  if entry.filename == script_name then
    ImGui.TextColored(ctx, COLORS.dim, "Open")
  elseif ImGui.Button(ctx, "Run##" .. entry.filename, button_w, button_h) then
    launch_script(entry)
  end
  ImGui.SetCursorScreenPos(ctx, x, y + h + 6)
  ImGui.Dummy(ctx, w, 1)
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 820, 720, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, "s3g-mc Package Browser", open)

  if visible then
    ImGui.Text(ctx, "s3g-mc")
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Rescan") then scan_scripts() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Install/refresh actions") then register_actions() end

    local changed
    changed, search = ImGui.InputText(ctx, "Search", search)
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 120)
    changed, detail_level = ImGui.SliderInt(ctx, "Detail", detail_level, 1, 3)

    draw_category_buttons()

    ImGui.Separator(ctx)
    ImGui.Text(ctx, status)

    ImGui.BeginChild(ctx, "##script_list", 0, 0)
      for _, entry in ipairs(scripts) do
        if matches_filter(entry) then draw_script_card(entry) end
      end
    ImGui.EndChild(ctx)

    ImGui.End(ctx)
  end

  if open then reaper.defer(loop) end
end

scan_scripts()
reaper.defer(loop)
