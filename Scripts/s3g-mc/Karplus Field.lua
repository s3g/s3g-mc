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
local EXT = "s3g_mc_karplus_field_v1"
local function getn(k,d) return tonumber(reaper.GetExtState(EXT,k)) or d end
local function getb(k,d) local v=reaper.GetExtState(EXT,k); if v=="" then return d end; return v~="0" end
local function set(k,v) reaper.SetExtState(EXT,k,type(v)=="boolean" and (v and "1" or "0") or tostring(v),true) end

local s={duration=getn("duration",8),channels=getn("channels",8),events=getn("events",90),base_freq=getn("base_freq",82),spread_oct=getn("spread_oct",3),decay=getn("decay",0.985),damping=getn("damping",0.45),brightness=getn("brightness",0.7),dispersion=getn("dispersion",0.08),spatial_width=getn("spatial_width",1.4),normalize=getb("normalize",true),normalize_db=getn("normalize_db",-12),seed=getn("seed",1)}
local ctx=ImGui.CreateContext("Karplus Field"); local open=true; local go=false
local function persist() for k,v in pairs(s) do set(k,v) end end
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
  ImGui.SetNextWindowSize(ctx,520,470,ImGui.Cond_Appearing); local vis; vis,open=ImGui.Begin(ctx,"Karplus Field",open)
  if vis then local changed; changed,s.duration=ImGui.SliderDouble(ctx,"Duration sec",s.duration,0.5,180,"%.2f"); changed,s.channels=ImGui.SliderInt(ctx,"Channels",math.floor(s.channels),1,mc.MAX_REAPER_TRACK_CHANNELS); changed,s.events=ImGui.SliderInt(ctx,"Pluck events",math.floor(s.events),1,800); changed,s.base_freq=ImGui.SliderDouble(ctx,"Base frequency",s.base_freq,20,440,"%.1f"); changed,s.spread_oct=ImGui.SliderDouble(ctx,"Spread octaves",s.spread_oct,0.1,7,"%.2f"); changed,s.decay=ImGui.SliderDouble(ctx,"String decay",s.decay,0.80,0.9995,"%.4f"); changed,s.damping=ImGui.SliderDouble(ctx,"Damping",s.damping,0,0.98,"%.2f"); changed,s.brightness=ImGui.SliderDouble(ctx,"Brightness",s.brightness,0,1,"%.2f"); changed,s.dispersion=ImGui.SliderDouble(ctx,"Dispersion",s.dispersion,0,0.5,"%.2f"); changed,s.spatial_width=ImGui.SliderDouble(ctx,"Spatial width",s.spatial_width,0.2,8,"%.2f"); changed,s.normalize=ImGui.Checkbox(ctx,"Peak normalize",s.normalize); if s.normalize then changed,s.normalize_db=ImGui.SliderDouble(ctx,"Normalize dB",s.normalize_db,-36,0,"%.1f") end; changed,s.seed=ImGui.InputInt(ctx,"Seed",math.floor(s.seed)); if ImGui.Button(ctx,"Render",96,28) then go=true end; ImGui.SameLine(ctx); if ImGui.Button(ctx,"Cancel",96,28) then open=false end; ImGui.End(ctx) end
  persist(); if go then open=false; render(); return end; if open then reaper.defer(loop) end
end
reaper.defer(loop)
