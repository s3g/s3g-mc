local M = {}

local has_imgui = reaper.APIExists and reaper.APIExists("ImGui_CreateContext")

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
  package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
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

  local labels = type(labels_csv) == "table" and labels_csv or split_csv(labels_csv)
  local values = type(defaults_csv) == "table" and defaults_csv or split_csv(defaults_csv)
  for index = 1, #labels do
    values[index] = tostring(values[index] or "")
  end

  local ctx = ImGui.CreateContext(title or "s3g-mc Input")
  local open = true
  local submitted = false
  local window_height = math.min(720, math.max(180, 116 + #labels * 42))
  local window_width = opts.width or 460
  local button_label = opts.button_label or "Run"

  local function finish()
    ctx = nil
  end

  local function loop()
    if not open then
      finish()
      return
    end

    ImGui.SetNextWindowSize(ctx, window_width, window_height, ImGui.Cond_Appearing or ImGui.Cond_FirstUseEver)
    local visible
    visible, open = ImGui.Begin(ctx, title or "s3g-mc Input", open)
    if visible then
      local label_w = opts.label_width or 190
      local input_w = opts.input_width or math.max(160, window_width - label_w - 54)
      for index, label in ipairs(labels) do
        ImGui.AlignTextToFramePadding(ctx)
        ImGui.Text(ctx, tostring(label))
        ImGui.SameLine(ctx, label_w)
        ImGui.PushItemWidth(ctx, input_w)
        local changed, value = ImGui.InputText(ctx, "##field" .. tostring(index), values[index] or "")
        if changed then values[index] = value end
        ImGui.PopItemWidth(ctx)
      end

      ImGui.Spacing(ctx)
      if ImGui.Button(ctx, button_label, 96, 28) then
        submitted = true
        open = false
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 96, 28) then
        open = false
      end
      ImGui.End(ctx)
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
