-- @description Subharmonic Bank
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Offline Synthesis / IR
-- @render Yes; renders a multichannel subharmonic oscillator bank.
-- @method Offline NumPy synthesis inspired by unstable subharmonic divider banks: root-driven divided voices, masks, drift, pulse/sine blend, fold, and multichannel spatial spread.

local script_path=({reaper.get_action_context()})[2]; local script_dir=script_path:match("^(.*[/\\])") or ""; local mc=dofile(script_dir.."Multichannel Library.lua"); local nr=dofile(script_dir.."NumPy Render Library.lua")
if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.","Subharmonic Bank",0) return end
package.path=reaper.ImGui_GetBuiltinPath().."/?.lua"; local ImGui=require("imgui")("0.10")
do
  package.path = script_dir .. "?.lua;" .. package.path
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme and _s3g_theme.install then _s3g_theme.install(ImGui) end
end
local theme = require("s3g-mc ImGui Theme")
local THEME = theme.palette(ImGui)
local EXT="s3g_mc_subharmonic_bank_v1"
local function getn(k,d)return tonumber(reaper.GetExtState(EXT,k))or d end; local function getb(k,d)local v=reaper.GetExtState(EXT,k);if v==""then return d end;return v~="0"end; local function set(k,v)reaper.SetExtState(EXT,k,type(v)=="boolean"and(v and"1"or"0")or tostring(v),true)end
local s={duration=getn("duration",12),channels=getn("channels",8),voices=getn("voices",24),root_freq=getn("root_freq",110),instability=getn("instability",0.12),pulse_blend=getn("pulse_blend",0.55),fold=getn("fold",0.2),event_mask=getn("event_mask",0.55),spatial_width=getn("spatial_width",1.8),normalize=getb("normalize",true),normalize_db=getn("normalize_db",-12),seed=getn("seed",1)}
local ctx=ImGui.CreateContext("Subharmonic Bank"); local open=true; local go=false
local function persist()for k,v in pairs(s)do set(k,v)end end
local function clamp(v,lo,hi)if v<lo then return lo elseif v>hi then return hi end return v end
local ROW_H,LABEL_W,CONTROL_GAP,VALUE_W=25,86,8,76
local LABEL_ABBR={["DURATION SEC"]="DUR",["ROOT FREQUENCY"]="ROOT",["PULSE BLEND"]="PULSE",["FOLD / DRIVE"]="FOLD",["MASK OPENINGS"]="MASK",["SPATIAL WIDTH"]="WIDTH",["PEAK NORMALIZE"]="PK NORM",["NORMALIZE DB"]="NORM DB"}
local function row_label_text(label)local upper=tostring(label or ""):upper();return LABEL_ABBR[upper]or upper end
local function row_layout()local x,y=ImGui.GetCursorScreenPos(ctx);local avail=ImGui.GetContentRegionAvail(ctx);if type(avail)~="number"then avail=380 end;local control_x=x+LABEL_W;local control_w=math.max(120,avail-LABEL_W-CONTROL_GAP);return x,y,control_x,control_w end
local function row_label(x,y,label)ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx),x,y+4,THEME.label,row_label_text(label))end
local function finish_row(x,y)ImGui.SetCursorScreenPos(ctx,x,y+ROW_H)end
local function draw_custom_slider(label,value,lo,hi,fmt,integer)local x,y,control_x,control_w=row_layout();local slider_w=math.max(80,control_w-VALUE_W-CONTROL_GAP);local value_x=control_x+slider_w+CONTROL_GAP;local track_y=y+8;local track_h=8;local norm=hi~=lo and clamp((value-lo)/(hi-lo),0,1)or 0;row_label(x,y,label);ImGui.SetCursorScreenPos(ctx,control_x,y);ImGui.InvisibleButton(ctx,"##"..label,slider_w,ROW_H);local hovered=ImGui.IsItemHovered(ctx);local active=ImGui.IsItemActive(ctx);local changed=false;if(hovered or active)and ImGui.IsMouseDown(ctx,0)then local mx=ImGui.GetMousePos(ctx);local next_norm=clamp((mx-control_x)/slider_w,0,1);local next_value=lo+(hi-lo)*next_norm;if integer then next_value=math.floor(next_value+0.5)end;if math.abs(next_value-value)>(integer and 0 or 0.0000001)then value=next_value;norm=next_norm;changed=true end end;local draw=ImGui.GetWindowDrawList(ctx);local frame=active and THEME.frame_active or(hovered and THEME.frame_hover or THEME.frame);local fill=active and THEME.active or THEME.fill;local handle=active and THEME.active_hover or THEME.active;ImGui.DrawList_AddRectFilled(draw,control_x,track_y,control_x+slider_w,track_y+track_h,frame);ImGui.DrawList_AddRectFilled(draw,control_x+1,track_y+1,control_x+math.max(2,slider_w*norm),track_y+track_h-1,fill);local hx=clamp(control_x+slider_w*norm-1.5,control_x+1,control_x+slider_w-4);ImGui.DrawList_AddRectFilled(draw,hx,track_y-2,hx+3,track_y+track_h+2,handle);ImGui.DrawList_AddText(draw,value_x,y+4,THEME.value,integer and tostring(math.floor(value+0.5))or string.format(fmt or"%.3f",value));finish_row(x,y);return changed,value end
local function draw_int_input(label,value)local x,y,control_x,control_w=row_layout();row_label(x,y,label);ImGui.SetCursorScreenPos(ctx,control_x,y);ImGui.SetNextItemWidth(ctx,math.min(control_w,104));local changed,next_value=ImGui.InputInt(ctx,"##"..label,math.floor(value));finish_row(x,y);return changed,next_value end
local function draw_checkbox(label,value)local x,y,control_x=row_layout();row_label(x,y,label);ImGui.SetCursorScreenPos(ctx,control_x,y+2);local changed,next_value=ImGui.Checkbox(ctx,"##"..label,value);finish_row(x,y);return changed,next_value end
local function section(label,height)local stack=theme.push_soft_panel(ImGui,ctx);local draw=ImGui.GetWindowDrawList(ctx);local x,y=ImGui.GetCursorScreenPos(ctx);local w=ImGui.GetContentRegionAvail(ctx);ImGui.DrawList_AddRectFilled(draw,x,y,x+w,y+height,THEME.panel_soft);ImGui.DrawList_AddRectFilled(draw,x,y,x+w,y+21,THEME.bg_alt);ImGui.DrawList_AddRect(draw,x,y,x+w,y+height,THEME.edge);ImGui.DrawList_AddRectFilled(draw,x,y,x+w,y+2,THEME.active);ImGui.SetCursorScreenPos(ctx,x+8,y+6);theme.text(ImGui,ctx,label:upper());ImGui.SetCursorScreenPos(ctx,x+12,y+36);return x,y,height,stack end
local function finish_section(x,y,height,stack)theme.pop_soft_panel(ImGui,ctx,stack);ImGui.SetCursorScreenPos(ctx,x,y+height+10);ImGui.Dummy(ctx,1,1)end
local function render()s.channels=math.max(1,math.min(mc.MAX_REAPER_TRACK_CHANNELS,math.floor(s.channels)));local stamp=tostring(math.floor(reaper.time_precise()*1000));local out_dir=nr.output_dir("s3g_subharmonic_bank_renders",nil,script_dir);local output_path=out_dir.."/s3g_subharmonic_bank_"..stamp.."_"..s.channels.."ch.wav";local manifest={output_path=output_path,sample_rate=48000,duration=s.duration,channels=s.channels,voices=s.voices,root_freq=s.root_freq,instability=s.instability,pulse_blend=s.pulse_blend,fold=s.fold,event_mask=s.event_mask,spatial_width=s.spatial_width,normalize=s.normalize,normalize_db=s.normalize_db,seed=s.seed};local log,elapsed=nr.run_backend(script_dir,"subharmonic_bank",manifest,"Subharmonic Bank");if not log then return end;reaper.Undo_BeginBlock();local item,err=nr.insert_output_item(output_path,"Subharmonic Bank ("..s.channels.."ch)",reaper.GetCursorPosition(),s.channels,{track_gain=0.35});reaper.Undo_EndBlock("Subharmonic Bank",-1);if not item then mc.show_error(err or"Could not insert render.")return end;mc.print_plan("Subharmonic Bank",{"Output: "..output_path,string.format("NumPy time: %.2f sec",elapsed),log})end
local function loop()
  local section_h = s.normalize and 346 or 321
  ImGui.SetNextWindowSize(ctx, 520, section_h + 130, ImGui.Cond_Appearing)
  local vis
  vis, open = ImGui.Begin(ctx, "Subharmonic Bank", open)
  if vis then
    local changed
    local sx, sy, sh, stack = section("Bank", section_h)
    changed, s.duration = draw_custom_slider("Duration sec", s.duration, 0.5, 180, "%.2f", false)
    changed, s.channels = draw_custom_slider("Channels", math.floor(s.channels), 1, mc.MAX_REAPER_TRACK_CHANNELS, nil, true)
    changed, s.voices = draw_custom_slider("Voices", math.floor(s.voices), 1, 96, nil, true)
    changed, s.root_freq = draw_custom_slider("Root frequency", s.root_freq, 20, 880, "%.1f", false)
    changed, s.instability = draw_custom_slider("Instability", s.instability, 0, 1, "%.2f", false)
    changed, s.pulse_blend = draw_custom_slider("Pulse blend", s.pulse_blend, 0, 1, "%.2f", false)
    changed, s.fold = draw_custom_slider("Fold / drive", s.fold, 0, 1, "%.2f", false)
    changed, s.event_mask = draw_custom_slider("Mask openings", s.event_mask, 0, 1, "%.2f", false)
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
