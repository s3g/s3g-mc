-- @description s3g-mc ImGui Input Dialog
-- @browser hidden

local M = {}

local has_imgui = reaper.APIExists and reaper.APIExists("ImGui_CreateContext")

local function module_dir()
  local source = debug.getinfo(1, "S").source or ""
  source = source:gsub("^@", "")
  return source:match("^(.*[/\\])") or ""
end

local function split_csv(text)
  local values = {}
  text = tostring(text or "")
  for value in text:gmatch("([^,]*)[,]?") do
    if value == "" and #values > 0 and text:sub(-1) ~= "," then
      break
    end
    values[#values + 1] = (value:gsub("^%s+", ""):gsub("%s+$", ""))
    if #values > 256 then break end
  end
  if #values == 0 then values[1] = "" end
  return values
end

local function join_csv(values)
  local parts = {}
  for index = 1, #values do
    parts[index] = tostring(values[index] or "")
  end
  return table.concat(parts, ",")
end

local function ensure_imgui(title)
  if not has_imgui then
    reaper.MB("ReaImGui is required for this dialog.", title or "s3g-mc", 0)
    return nil
  end
  package.path = module_dir() .. "?.lua;" .. reaper.ImGui_GetBuiltinPath() .. "/?.lua"
  local ok, imgui_loader = pcall(require, "imgui")
  if not ok or not imgui_loader then
    reaper.MB("Could not load ReaImGui.", title or "s3g-mc", 0)
    return nil
  end
  if type(imgui_loader) == "function" then
    return imgui_loader("0.10")
  end
  return imgui_loader
end

function M.prompt_csv(title, labels_csv, defaults_csv, on_submit, opts)
  opts = opts or {}
  local ImGui = ensure_imgui(title)
  if not ImGui then return false end
  local ok_theme, theme = pcall(require, "s3g-mc ImGui Theme")
  if not ok_theme then theme = nil end
  if theme and theme.install then theme.install(ImGui) end

  local labels = type(labels_csv) == "table" and labels_csv or split_csv(labels_csv)
  local values = type(defaults_csv) == "table" and defaults_csv or split_csv(defaults_csv)
  for index = 1, #labels do
    values[index] = tostring(values[index] or "")
  end

  local ctx = ImGui.CreateContext(title or "s3g-mc Input")
  local theme_font = theme and theme.attach_font(ImGui, ctx, 11) or nil
  local open = true
  local submitted = false
  local row_h = 25
  local section_h = 40 + #labels * row_h
  local window_height = math.min(730, math.max(210, 118 + section_h))
  local window_width = opts.width or 520
  local button_label = opts.button_label or "Run"

  local function finish()
    ctx = nil
  end

  local function loop()
    if not open then
      finish()
      return
    end

    ImGui.SetNextWindowSize(ctx, window_width, window_height, ImGui.Cond_Appearing)
    local theme_stack = theme and theme.push(ImGui, ctx) or nil
    local font_pushed = theme and theme.push_font(ImGui, ctx, theme_font) or false
    local visible
    visible, open = ImGui.Begin(ctx, title or "s3g-mc Input", open)
    if visible then
      if theme and theme.begin_section then
        local sx, sy, sh, stack = theme.begin_section(ImGui, ctx, "Parameters", section_h)
        for index, label in ipairs(labels) do
          local changed, value = theme.input_text_row(ImGui, ctx, label, values[index] or "")
          if changed then values[index] = value end
        end
        theme.finish_section(ImGui, ctx, sx, sy, sh, stack)
      else
        local label_w = opts.label_width or 190
        local input_w = opts.input_width or math.max(160, window_width - label_w - 54)
        for index, label in ipairs(labels) do
          ImGui.AlignTextToFramePadding(ctx)
          ImGui.Text(ctx, tostring(label):upper())
          ImGui.SameLine(ctx, label_w)
          ImGui.PushItemWidth(ctx, input_w)
          local changed, value = ImGui.InputText(ctx, "##field" .. tostring(index), values[index] or "")
          if changed then values[index] = value end
          ImGui.PopItemWidth(ctx)
        end
      end

      ImGui.Spacing(ctx)
      if ImGui.Button(ctx, tostring(button_label):upper(), 96, 28) then
        submitted = true
        open = false
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "CANCEL", 96, 28) then
        open = false
      end
      ImGui.End(ctx)
    end
    if theme then
      theme.pop_font(ImGui, ctx, font_pushed)
      theme.pop(ImGui, ctx, theme_stack)
    end

    if submitted then
      finish()
      on_submit(join_csv(values))
      return
    end

    reaper.defer(loop)
  end

  reaper.defer(loop)
  return true
end

return M
