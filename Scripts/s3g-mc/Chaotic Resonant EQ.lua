-- @description Chaotic Resonant EQ
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; Python 3 with NumPy
-- @category Spectral / Convolution
-- @render Yes; processes the selected media item through a multichannel resonant feedback EQ field.
-- @method Select one WAV-backed media item. The renderer applies a protected resonant filter bank with channel-to-channel feedback, chaotic detuning, drive, wet/dry mix, and peak normalization.

local script_path=({reaper.get_action_context()})[2]; local script_dir=script_path:match("^(.*[/\\])") or ""; local mc=dofile(script_dir.."Multichannel Library.lua"); local nr=dofile(script_dir.."NumPy Render Library.lua")
if not reaper.APIExists("ImGui_GetVersion") then reaper.MB("ReaImGui is not installed.","Chaotic Resonant EQ",0) return end
package.path=reaper.ImGui_GetBuiltinPath().."/?.lua"; local ImGui=require("imgui")("0.10")
do
  package.path = script_dir .. "?.lua;" .. package.path
  local _s3g_theme_ok, _s3g_theme = pcall(require, "s3g-mc ImGui Theme")
  if _s3g_theme_ok and _s3g_theme and _s3g_theme.install then _s3g_theme.install(ImGui) end
end
local theme=require("s3g-mc ImGui Theme"); local sol_ui=dofile(script_dir.."Spectral Offline Library.lua")
local EXT="s3g_mc_chaotic_resonant_eq_v1"
local entries=nr.selected_entries(); local entry=entries[1]; if not entry then mc.show_error("Select one WAV-backed media item.") return end
local function getn(k,d)return tonumber(reaper.GetExtState(EXT,k))or d end; local function getb(k,d)local v=reaper.GetExtState(EXT,k);if v==""then return d end;return v~="0"end; local function set(k,v)reaper.SetExtState(EXT,k,type(v)=="boolean"and(v and"1"or"0")or tostring(v),true)end
local s={bands=getn("bands",12),low_freq=getn("low_freq",90),high_freq=getn("high_freq",6000),q=getn("q",18),feedback=getn("feedback",0.18),chaos=getn("chaos",0.25),wet=getn("wet",0.55),drive=getn("drive",1.2),normalize=getb("normalize",true),normalize_db=getn("normalize_db",-9),seed=getn("seed",1)}
local ctx=ImGui.CreateContext("Chaotic Resonant EQ"); local open=true; local go=false
local function persist()for k,v in pairs(s)do set(k,v)end end
local function render()local stamp=tostring(math.floor(reaper.time_precise()*1000));local out_dir=nr.output_dir("s3g_chaotic_resonant_eq_renders",entry.filename,script_dir);local output_path=out_dir.."/s3g_chaotic_resonant_eq_"..stamp.."_"..entry.channels.."ch.wav";local manifest={source_path=entry.filename,source_start=entry.start_offset,source_duration=entry.length*math.max(0.000001,entry.playrate),sample_rate=nr.source_sample_rate(entry),output_path=output_path,bands=s.bands,low_freq=s.low_freq,high_freq=s.high_freq,q=s.q,feedback=s.feedback,chaos=s.chaos,wet=s.wet,drive=s.drive,normalize=s.normalize,normalize_db=s.normalize_db,seed=s.seed};local log,elapsed=nr.run_backend(script_dir,"chaotic_resonant_eq",manifest,"Chaotic Resonant EQ");if not log then return end;reaper.Undo_BeginBlock();local item,err=nr.insert_output_item(output_path,"Chaotic Resonant EQ ("..entry.channels.."ch)",entry.position,entry.channels,{track_gain=0.5});reaper.Undo_EndBlock("Chaotic Resonant EQ",-1);if not item then mc.show_error(err or"Could not insert render.")return end;mc.print_plan("Chaotic Resonant EQ",{"Source: "..entry.name,"Output: "..output_path,string.format("NumPy time: %.2f sec",elapsed),log})end
local function loop()
  local section_h = s.normalize and 323 or 298
  local body_target_h = section_h + 70
  ImGui.SetNextWindowSize(ctx, 520, body_target_h + 124, ImGui.Cond_Appearing)
  local vis
  vis, open = ImGui.Begin(ctx, "Chaotic Resonant EQ", open)
  if vis then
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    local footer_h = 48
    local body_h = math.min(body_target_h, math.max(1, (avail_h or body_target_h + footer_h) - footer_h))
    local body_visible = ImGui.BeginChild(ctx, "##chaotic_resonant_eq_controls", 0, body_h, 0)
    if body_visible then
      theme.muted(ImGui, ctx, "Source: " .. entry.name .. " (" .. entry.channels .. " ch)")
      local changed
      local sx, sy, sh, stack = sol_ui.begin_section(ImGui, ctx, "Resonators", section_h)
      changed, s.bands = sol_ui.draw_slider_int(ImGui, ctx, "Bands", math.floor(s.bands), 2, 48)
      changed, s.low_freq = sol_ui.draw_slider(ImGui, ctx, "Low frequency", s.low_freq, 20, 1000, "%.1f", false)
      changed, s.high_freq = sol_ui.draw_slider(ImGui, ctx, "High frequency", s.high_freq, 400, 18000, "%.1f", false)
      changed, s.q = sol_ui.draw_slider(ImGui, ctx, "Resonance Q", s.q, 1, 120, "%.1f", false)
      changed, s.feedback = sol_ui.draw_slider(ImGui, ctx, "Feedback", s.feedback, 0, 0.92, "%.2f", false)
      changed, s.chaos = sol_ui.draw_slider(ImGui, ctx, "Chaotic detune", s.chaos, 0, 1, "%.2f", false)
      changed, s.wet = sol_ui.draw_slider(ImGui, ctx, "Wet mix", s.wet, 0, 1, "%.2f", false)
      changed, s.drive = sol_ui.draw_slider(ImGui, ctx, "Drive", s.drive, 0.2, 8, "%.2f", false)
      changed, s.normalize = sol_ui.draw_checkbox(ImGui, ctx, "Peak normalize", s.normalize)
      if s.normalize then
        changed, s.normalize_db = sol_ui.draw_slider(ImGui, ctx, "Normalize dB", s.normalize_db, -36, 0, "%.1f", false)
      end
      changed, s.seed = sol_ui.draw_input_int(ImGui, ctx, "Seed", s.seed)
      sol_ui.finish_section(ImGui, ctx, sx, sy, sh, stack)
      theme.muted(ImGui, ctx, "Feedback is soft-limited in the offline backend.")
    end
    ImGui.EndChild(ctx)
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
