-- @description s3g-mc ImGui Theme
-- @browser hidden

local M = {}
local installed = setmetatable({}, { __mode = "k" })
local DEFAULT_FONT_SIZE = 11

local function color(ImGui, r, g, b, a)
  if ImGui and ImGui.ColorConvertDouble4ToU32 then
    return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1.0)
  end
  return 0xffffffff
end

function M.palette(ImGui)
  return {
    bg = color(ImGui, 0.030, 0.032, 0.034, 1.0),
    bg_alt = color(ImGui, 0.042, 0.045, 0.048, 1.0),
    panel = color(ImGui, 0.060, 0.064, 0.068, 1.0),
    panel_soft = color(ImGui, 0.078, 0.083, 0.088, 1.0),
    frame = color(ImGui, 0.090, 0.096, 0.102, 1.0),
    frame_hover = color(ImGui, 0.135, 0.144, 0.152, 1.0),
    frame_active = color(ImGui, 0.178, 0.190, 0.200, 1.0),
    title = color(ImGui, 0.018, 0.020, 0.022, 1.0),
    title_active = color(ImGui, 0.145, 0.155, 0.165, 1.0),
    title_collapsed = color(ImGui, 0.045, 0.048, 0.052, 1.0),
    edge = color(ImGui, 0.310, 0.325, 0.340, 1.0),
    edge_soft = color(ImGui, 0.220, 0.232, 0.244, 1.0),
    text = color(ImGui, 0.830, 0.850, 0.860, 1.0),
    muted = color(ImGui, 0.560, 0.590, 0.600, 1.0),
    disabled = color(ImGui, 0.360, 0.380, 0.390, 1.0),
    active = color(ImGui, 0.620, 0.690, 0.720, 1.0),
    active_hover = color(ImGui, 0.710, 0.770, 0.790, 1.0),
    ok = color(ImGui, 0.340, 0.710, 0.520, 1.0),
    warn = color(ImGui, 0.940, 0.500, 0.340, 1.0),
    amber = color(ImGui, 0.880, 0.700, 0.360, 1.0),
    clear = color(ImGui, 0.0, 0.0, 0.0, 0.0),
  }
end

local function push_style_color(ImGui, ctx, name, value)
  local ok, key = pcall(function() return ImGui["Col_" .. name] end)
  if not ok then return 0 end
  if key then
    ImGui.PushStyleColor(ctx, key, value)
    return 1
  end
  return 0
end

local function push_style_var(ImGui, ctx, name, ...)
  local ok, key = pcall(function() return ImGui["StyleVar_" .. name] end)
  if not ok then return 0 end
  if key then
    ImGui.PushStyleVar(ctx, key, ...)
    return 1
  end
  return 0
end

function M.attach_font(ImGui, ctx, size)
  if not (ImGui and ImGui.CreateFont and ImGui.Attach) then return nil end
  size = size or DEFAULT_FONT_SIZE
  local candidates = { "Menlo", "Monaco", "Arial" }
  for _, name in ipairs(candidates) do
    local ok, font = pcall(ImGui.CreateFont, name, size)
    if ok and font then
      pcall(ImGui.Attach, ctx, font)
      return { font = font, size = size }
    end
  end
  return nil
end

function M.push_font(ImGui, ctx, font)
  if font and ImGui and ImGui.PushFont then
    local handle = type(font) == "table" and font.font or font
    local size = type(font) == "table" and font.size or DEFAULT_FONT_SIZE
    local ok = pcall(ImGui.PushFont, ctx, handle, size)
    if ok then return true end
  end
  return false
end

function M.pop_font(ImGui, ctx, pushed)
  if pushed and ImGui and ImGui.PopFont then
    ImGui.PopFont(ctx)
  end
end

function M.push(ImGui, ctx)
  local p = M.palette(ImGui)
  local vars = 0
  local colors = 0

  vars = vars + push_style_var(ImGui, ctx, "WindowPadding", 8, 7)
  vars = vars + push_style_var(ImGui, ctx, "FramePadding", 6, 3)
  vars = vars + push_style_var(ImGui, ctx, "ItemSpacing", 7, 4)
  vars = vars + push_style_var(ImGui, ctx, "WindowRounding", 0)
  vars = vars + push_style_var(ImGui, ctx, "ChildRounding", 0)
  vars = vars + push_style_var(ImGui, ctx, "FrameRounding", 0)
  vars = vars + push_style_var(ImGui, ctx, "PopupRounding", 0)
  vars = vars + push_style_var(ImGui, ctx, "ScrollbarRounding", 0)
  vars = vars + push_style_var(ImGui, ctx, "GrabRounding", 0)
  vars = vars + push_style_var(ImGui, ctx, "TabRounding", 0)
  vars = vars + push_style_var(ImGui, ctx, "WindowBorderSize", 1)
  vars = vars + push_style_var(ImGui, ctx, "FrameBorderSize", 1)

  colors = colors + push_style_color(ImGui, ctx, "WindowBg", p.bg)
  colors = colors + push_style_color(ImGui, ctx, "TitleBg", p.title)
  colors = colors + push_style_color(ImGui, ctx, "TitleBgActive", p.title_active)
  colors = colors + push_style_color(ImGui, ctx, "TitleBgCollapsed", p.title_collapsed)
  colors = colors + push_style_color(ImGui, ctx, "ChildBg", p.bg_alt)
  colors = colors + push_style_color(ImGui, ctx, "PopupBg", p.panel)
  colors = colors + push_style_color(ImGui, ctx, "Border", p.edge)
  colors = colors + push_style_color(ImGui, ctx, "BorderShadow", p.clear)
  colors = colors + push_style_color(ImGui, ctx, "Text", p.text)
  colors = colors + push_style_color(ImGui, ctx, "TextDisabled", p.disabled)
  colors = colors + push_style_color(ImGui, ctx, "FrameBg", p.frame)
  colors = colors + push_style_color(ImGui, ctx, "FrameBgHovered", p.frame_hover)
  colors = colors + push_style_color(ImGui, ctx, "FrameBgActive", p.frame_active)
  colors = colors + push_style_color(ImGui, ctx, "Button", p.frame)
  colors = colors + push_style_color(ImGui, ctx, "ButtonHovered", p.frame_hover)
  colors = colors + push_style_color(ImGui, ctx, "ButtonActive", p.frame_active)
  colors = colors + push_style_color(ImGui, ctx, "Header", p.frame)
  colors = colors + push_style_color(ImGui, ctx, "HeaderHovered", p.frame_hover)
  colors = colors + push_style_color(ImGui, ctx, "HeaderActive", p.frame_active)
  colors = colors + push_style_color(ImGui, ctx, "CheckMark", p.active)
  colors = colors + push_style_color(ImGui, ctx, "SliderGrab", p.active)
  colors = colors + push_style_color(ImGui, ctx, "SliderGrabActive", p.active_hover)
  colors = colors + push_style_color(ImGui, ctx, "ScrollbarBg", p.bg)
  colors = colors + push_style_color(ImGui, ctx, "ScrollbarGrab", p.frame_active)
  colors = colors + push_style_color(ImGui, ctx, "ScrollbarGrabHovered", p.edge)
  colors = colors + push_style_color(ImGui, ctx, "ScrollbarGrabActive", p.active)
  colors = colors + push_style_color(ImGui, ctx, "Separator", p.edge_soft)
  colors = colors + push_style_color(ImGui, ctx, "SeparatorHovered", p.edge)
  colors = colors + push_style_color(ImGui, ctx, "SeparatorActive", p.active)
  colors = colors + push_style_color(ImGui, ctx, "Tab", p.frame)
  colors = colors + push_style_color(ImGui, ctx, "TabHovered", p.frame_hover)
  colors = colors + push_style_color(ImGui, ctx, "TabActive", p.panel_soft)

  return { vars = vars, colors = colors }
end

function M.pop(ImGui, ctx, stack)
  if not stack then return end
  if stack.colors and stack.colors > 0 then ImGui.PopStyleColor(ctx, stack.colors) end
  if stack.vars and stack.vars > 0 then ImGui.PopStyleVar(ctx, stack.vars) end
end

function M.install(ImGui)
  if not (ImGui and ImGui.Begin and ImGui.End) or installed[ImGui] then return false end

  local original_begin = ImGui.Begin
  local original_end = ImGui.End
  local original_set_next_window_size = ImGui.SetNextWindowSize
  local stacks_by_ctx = setmetatable({}, { __mode = "k" })
  local fonts_by_ctx = setmetatable({}, { __mode = "k" })
  local unpack_fn = table.unpack or unpack

  local function themed_begin(ctx, ...)
    local font = fonts_by_ctx[ctx]
    if font == nil then
      font = M.attach_font(ImGui, ctx, DEFAULT_FONT_SIZE) or false
      fonts_by_ctx[ctx] = font
    end
    local font_pushed = font and M.push_font(ImGui, ctx, font) or false
    local stack = M.push(ImGui, ctx)
    local results = { original_begin(ctx, ...) }
    if results[1] then
      local stacks = stacks_by_ctx[ctx]
      if not stacks then
        stacks = {}
        stacks_by_ctx[ctx] = stacks
      end
      stacks[#stacks + 1] = { style = stack, font_pushed = font_pushed }
    else
      M.pop(ImGui, ctx, stack)
      M.pop_font(ImGui, ctx, font_pushed)
    end
    return unpack_fn(results)
  end

  local function themed_end(ctx, ...)
    original_end(ctx, ...)
    local stacks = stacks_by_ctx[ctx]
    local frame_stack = stacks and table.remove(stacks)
    if frame_stack then
      M.pop_font(ImGui, ctx, frame_stack.font_pushed)
      M.pop(ImGui, ctx, frame_stack.style)
    end
  end

  local function themed_set_next_window_size(ctx, width, height, ...)
    if type(height) == "number" and height > 0 then height = height + 10 end
    return original_set_next_window_size(ctx, width, height, ...)
  end

  local ok = pcall(function()
    ImGui.Begin = themed_begin
    ImGui.End = themed_end
    if original_set_next_window_size then ImGui.SetNextWindowSize = themed_set_next_window_size end
  end)
  if ok then installed[ImGui] = true end
  return ok
end

return M
