-- @description Karplus Field
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Offline Synthesis / IR
-- @render Yes; renders a multichannel Karplus-Strong plucked resonator field.
-- @method Offline NumPy synthesis for plucked string/body events distributed across a multichannel bed, with damping, brightness, dispersion, and spatial width.

local script_path = ({ reaper.get_action_context() })[2]
local script_dir = script_path:match("^(.*[/\\])") or ""
local mc = dofile(script_dir .. "Multichannel Library.lua")
local nr = dofile(script_dir .. "NumPy Render Library.lua")

if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.", "Karplus Field", 0) return end
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")
do
  local _s3g_theme_path = ({ reaper.get_action_context() })[2]
  if not _s3g_theme_path or _s3g_theme_path == "" then
    _s3g_theme_path = (debug.getinfo(1, "S").source or ""):gsub("^@", "")
  end
  local _s3g_theme_dir = _s3g_theme_path:match("^(.*[/\\])") or ""
  package.path = _s3g_theme_dir .. "?.lua;" .. package.path
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme and _s3g_theme.install then _s3g_theme.install(ImGui) end
end
local theme = require("s3g-mc ImGui Theme")
local THEME = theme.palette(ImGui)

local EXT = "s3g_mc_karplus_field_v1"
local function getn(k,d) return tonumber(reaper.GetExtState(EXT,k)) or d end
local function getb(k,d) local v=reaper.GetExtState(EXT,k); if v=="" then return d end; return v~="0" end
local function set(k,v) reaper.SetExtState(EXT,k,type(v)=="boolean" and (v and "1" or "0") or tostring(v),true) end

local s={duration=getn("duration",8),channels=getn("channels",8),events=getn("events",90),base_freq=getn("base_freq",82),spread_oct=getn("spread_oct",3),decay=getn("decay",0.985),damping=getn("damping",0.45),brightness=getn("brightness",0.7),dispersion=getn("dispersion",0.08),spatial_width=getn("spatial_width",1.4),normalize=getb("normalize",true),normalize_db=getn("normalize_db",-12),seed=getn("seed",1)}
local ctx=ImGui.CreateContext("Karplus Field"); local open=true; local go=false
local function persist() for k,v in pairs(s) do set(k,v) end end
local function clamp(value, lo, hi) if value < lo then return lo elseif value > hi then return hi end return value end

local ROW_H = 25
local LABEL_W = 86
local CONTROL_GAP = 8
local VALUE_W = 76
local LABEL_ABBR = {
  ["DURATION SEC"] = "DUR",
  ["PLUCK EVENTS"] = "EVENTS",
  ["BASE FREQUENCY"] = "BASE",
  ["SPREAD OCTAVES"] = "SPREAD",
  ["STRING DECAY"] = "DECAY",
  ["SPATIAL WIDTH"] = "WIDTH",
  ["NORMALIZE DB"] = "NORM DB",
}

local function row_label_text(label)
  local upper = tostring(label or ""):upper()
  return LABEL_ABBR[upper] or upper
end

local function row_layout()
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local avail = ImGui.GetContentRegionAvail(ctx)
  if type(avail) ~= "number" then avail = 380 end
  local control_x = x + LABEL_W
  local control_w = math.max(120, avail - LABEL_W - CONTROL_GAP)
  return x, y, control_x, control_w
end

local function row_label(x, y, label)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 4, THEME.label, row_label_text(label))
end

local function finish_row(x, y)
  ImGui.SetCursorScreenPos(ctx, x, y + ROW_H)
end

local function draw_custom_slider(label, value, lo, hi, fmt, integer)
  local x, y, control_x, control_w = row_layout()
  local slider_w = math.max(80, control_w - VALUE_W - CONTROL_GAP)
  local value_x = control_x + slider_w + CONTROL_GAP
  local track_y = y + 8
  local track_h = 8
  local norm = hi ~= lo and clamp((value - lo) / (hi - lo), 0, 1) or 0
  row_label(x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.InvisibleButton(ctx, "##" .. label, slider_w, ROW_H)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local changed = false
  if (hovered or active) and ImGui.IsMouseDown(ctx, 0) then
    local mx = ImGui.GetMousePos(ctx)
    local next_norm = clamp((mx - control_x) / slider_w, 0, 1)
    local next_value = lo + (hi - lo) * next_norm
    if integer then next_value = math.floor(next_value + 0.5) end
    if math.abs(next_value - value) > (integer and 0 or 0.0000001) then
      value = next_value
      norm = next_norm
      changed = true
    end
  end
  local draw = ImGui.GetWindowDrawList(ctx)
  local frame = active and THEME.frame_active or (hovered and THEME.frame_hover or THEME.frame)
  local fill = active and THEME.active or THEME.fill
  local handle = active and THEME.active_hover or THEME.active
  ImGui.DrawList_AddRectFilled(draw, control_x, track_y, control_x + slider_w, track_y + track_h, frame)
  ImGui.DrawList_AddRectFilled(draw, control_x + 1, track_y + 1, control_x + math.max(2, slider_w * norm), track_y + track_h - 1, fill)
  local hx = clamp(control_x + slider_w * norm - 1.5, control_x + 1, control_x + slider_w - 4)
  ImGui.DrawList_AddRectFilled(draw, hx, track_y - 2, hx + 3, track_y + track_h + 2, handle)
  ImGui.DrawList_AddText(draw, value_x, y + 4, THEME.value, integer and tostring(math.floor(value + 0.5)) or string.format(fmt or "%.3f", value))
  finish_row(x, y)
  return changed, value
end

local function draw_int_input(label, value)
  local x, y, control_x, control_w = row_layout()
  row_label(x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y)
  ImGui.SetNextItemWidth(ctx, math.min(control_w, 104))
  local changed, next_value = ImGui.InputInt(ctx, "##" .. label, math.floor(value))
  finish_row(x, y)
  return changed, next_value
end

local function draw_checkbox(label, value)
  local x, y, control_x = row_layout()
  row_label(x, y, label)
  ImGui.SetCursorScreenPos(ctx, control_x, y + 2)
  local changed, next_value = ImGui.Checkbox(ctx, "##" .. label, value)
  finish_row(x, y)
  return changed, next_value
end

local function section(label, height)
  local stack = theme.push_soft_panel(ImGui, ctx)
  local draw = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + height, THEME.panel_soft)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + 2, THEME.active)
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 10)
  theme.text(ImGui, ctx, label:upper())
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 36)
  return x, y, height, stack
end

local function finish_section(x, y, height, stack)
  theme.pop_soft_panel(ImGui, ctx, stack)
  ImGui.SetCursorScreenPos(ctx, x, y + height + 10)
  ImGui.Dummy(ctx, 1, 1)
end

local function render()
  s.channels=math.max(1,math.min(mc.MAX_REAPER_TRACK_CHANNELS,math.floor(s.channels)))
  local stamp=tostring(math.floor(reaper.time_precise()*1000)); local out_dir=nr.output_dir("s3g_karplus_field_renders",nil,script_dir)
  local output_path=out_dir.."/s3g_karplus_field_"..stamp.."_"..s.channels.."ch.wav"
  local manifest={output_path=output_path,sample_rate=48000,duration=s.duration,channels=s.channels,events=s.events,base_freq=s.base_freq,spread_oct=s.spread_oct,decay=s.decay,damping=s.damping,brightness=s.brightness,dispersion=s.dispersion,spatial_width=s.spatial_width,normalize=s.normalize,normalize_db=s.normalize_db,seed=s.seed}
  local log,elapsed=nr.run_backend(script_dir,"karplus_field",manifest,"Karplus Field"); if not log then return end
  reaper.Undo_BeginBlock(); local item,err=nr.insert_output_item(output_path,"Karplus Field ("..s.channels.."ch)",reaper.GetCursorPosition(),s.channels,{track_gain=0.35}); reaper.Undo_EndBlock("Karplus Field",-1)
  if not item then mc.show_error(err or "Could not insert render.") return end
  mc.print_plan("Karplus Field",{"Output: "..output_path,string.format("NumPy time: %.2f sec",elapsed),log})
end
local function loop()
  local section_h = s.normalize and 426 or 401
  ImGui.SetNextWindowSize(ctx, 520, section_h + 130, ImGui.Cond_Appearing)
  local vis
  vis, open = ImGui.Begin(ctx, "Karplus Field", open)
  if vis then
    local changed
    local sx, sy, sh, stack = section("Field", section_h)
    changed, s.duration = draw_custom_slider("Duration sec", s.duration, 0.5, 180, "%.2f", false)
    changed, s.channels = draw_custom_slider("Channels", math.floor(s.channels), 1, mc.MAX_REAPER_TRACK_CHANNELS, nil, true)
    changed, s.events = draw_custom_slider("Pluck events", math.floor(s.events), 1, 800, nil, true)
    changed, s.base_freq = draw_custom_slider("Base frequency", s.base_freq, 20, 440, "%.1f", false)
    changed, s.spread_oct = draw_custom_slider("Spread octaves", s.spread_oct, 0.1, 7, "%.2f", false)
    changed, s.decay = draw_custom_slider("String decay", s.decay, 0.80, 0.9995, "%.4f", false)
    changed, s.damping = draw_custom_slider("Damping", s.damping, 0, 0.98, "%.2f", false)
    changed, s.brightness = draw_custom_slider("Brightness", s.brightness, 0, 1, "%.2f", false)
    changed, s.dispersion = draw_custom_slider("Dispersion", s.dispersion, 0, 0.5, "%.2f", false)
    changed, s.spatial_width = draw_custom_slider("Spatial width", s.spatial_width, 0.2, 8, "%.2f", false)
    changed, s.normalize = draw_checkbox("Peak normalize", s.normalize)
    if s.normalize then
      changed, s.normalize_db = draw_custom_slider("Normalize dB", s.normalize_db, -36, 0, "%.1f", false)
    end
    changed, s.seed = draw_int_input("Seed", s.seed)
    finish_section(sx, sy, sh, stack)
    local render_pressed, cancel_pressed = theme.footer_buttons(ImGui, ctx, "RENDER", "CANCEL", 104, 104)
    if render_pressed then go = true end
    if cancel_pressed then open = false end
    ImGui.End(ctx)
  end
  persist()
  if go then
    open = false
    render()
    return
  end
  if open then reaper.defer(loop) end
end
reaper.defer(loop)
