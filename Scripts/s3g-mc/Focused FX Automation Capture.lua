-- @description Focused FX Automation Capture
-- @author s3g
-- @version 0.1
-- @requires ReaImGui
-- @category Channel Mixing / Automation
-- @method ReaImGui utility for the currently focused or touched track FX. Filters/selects parameters and writes the current FX state as editable automation points at the edit cursor.
-- @about
--   Captures the current settings of the focused/touched track FX into visible,
--   armed automation lanes. Use the filter and bucket controls to choose a
--   parameter set, then save the current plugin state at the edit cursor.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Focused FX Automation Capture", 0)
  return
end

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

local TITLE = "Focused FX Automation Capture"
local EXT = "s3g-mc Focused FX Automation Capture"
local ctx = ImGui.CreateContext(TITLE)
local open = true

local params = {}
local selected = {}
local buckets = {}
local bucket_name = "Bucket 1"
local active_bucket = 1
local filter_text = ""
local skip_empty = true
local arm_lanes = true
local show_lanes = true
local lane_height = 72
local show_params = false
local last_key = ""
local status = "Focus or touch an FX parameter, then lock the FX."
local target_track = nil
local target_fx = -1
local target_key = ""
local make_key
local fx_name
local param_label

local STYLE = {
  muted = THEME.value,
  warn = THEME.warn,
  ok = THEME.ok,
}

local function lower(s)
  return string.lower(s or "")
end

local function enc(s)
  s = tostring(s or "")
  s = s:gsub("%%", "%%25")
  s = s:gsub("\t", "%%09")
  s = s:gsub("\n", "%%0A")
  s = s:gsub("\r", "%%0D")
  return s
end

local function dec(s)
  s = tostring(s or "")
  s = s:gsub("%%0D", "\r")
  s = s:gsub("%%0A", "\n")
  s = s:gsub("%%09", "\t")
  s = s:gsub("%%25", "%%")
  return s
end

local function ext_key_for_fx(track, fx)
  local name = fx_name(track, fx)
  return "buckets:" .. enc(name)
end

local function bucket_preview(bucket)
  if not bucket or not bucket.params then return "" end
  local labels = {}
  for _, param in ipairs(bucket.params) do
    labels[#labels + 1] = param_label(param)
    if #labels >= 4 then break end
  end
  local suffix = #bucket.params > 4 and ", ..." or ""
  return table.concat(labels, ", ") .. suffix
end

local function load_buckets(track, fx)
  buckets = {}
  active_bucket = 1
  if not track or fx < 0 then return end
  local text = reaper.GetExtState(EXT, ext_key_for_fx(track, fx))
  for line in (text or ""):gmatch("[^\n]+") do
    local name, indices = line:match("^(.-)\t(.*)$")
    if name and name ~= "" then
      local bucket = { name = dec(name), params = {} }
      for token in tostring(indices or ""):gmatch("[^,]+") do
        local param = tonumber(token)
        if param then bucket.params[#bucket.params + 1] = math.floor(param) end
      end
      if #bucket.params > 0 then buckets[#buckets + 1] = bucket end
    end
  end
end

local function save_buckets(track, fx)
  if not track or fx < 0 then return end
  local lines = {}
  for _, bucket in ipairs(buckets) do
    local indices = {}
    for _, param in ipairs(bucket.params or {}) do indices[#indices + 1] = tostring(param) end
    lines[#lines + 1] = enc(bucket.name) .. "\t" .. table.concat(indices, ",")
  end
  reaper.SetExtState(EXT, ext_key_for_fx(track, fx), table.concat(lines, "\n"), true)
end

local function track_from_number(track_number)
  if track_number == 0 then return reaper.GetMasterTrack(0) end
  if track_number and track_number > 0 then return reaper.GetTrack(0, track_number - 1) end
  return nil
end

local function focused_track_fx()
  local retval, track_number, item_number, fx_number
  if reaper.GetFocusedFX2 then
    retval, track_number, item_number, fx_number = reaper.GetFocusedFX2()
  else
    retval, track_number, item_number, fx_number = reaper.GetFocusedFX()
  end
  if not retval or retval == 0 then return nil, -1, "No focused FX window." end
  if item_number and item_number >= 0 then
    return nil, -1, "Focused take FX are not supported in this first version."
  end

  local track = track_from_number(track_number)
  if not track or not fx_number or fx_number < 0 then return nil, -1, "Focused FX is not a track FX." end
  return track, fx_number, nil
end

local function touched_track_fx()
  if not reaper.GetLastTouchedFX then return nil, -1, "No focused or touched FX." end
  local ok, track_number, fx_number = reaper.GetLastTouchedFX()
  if not ok or ok == 0 then return nil, -1, "No focused or touched FX." end
  local track = track_from_number(track_number)
  if not track or not fx_number or fx_number < 0 then return nil, -1, "Last touched FX is not a track FX." end
  return track, fx_number, nil
end

local function discover_track_fx()
  local track, fx, err = focused_track_fx()
  if not err then return track, fx, nil, "focused" end
  track, fx, err = touched_track_fx()
  if not err then return track, fx, nil, "touched" end
  return nil, -1, err or "No focused or touched track FX.", nil
end

local function lock_target(track, fx)
  target_track = track
  target_fx = fx or -1
  target_key = make_key(track, target_fx)
end

local function target_track_fx()
  if target_track and target_fx and target_fx >= 0 then
    return target_track, target_fx, nil
  end
  local track, fx, err = discover_track_fx()
  if not err then lock_target(track, fx) end
  return track, fx, err
end

local function track_name(track)
  if track == reaper.GetMasterTrack(0) then return "Master" end
  local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  if name and name ~= "" then return name end
  local number = math.floor((reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") or 0) + 0.5)
  return number > 0 and ("Track " .. tostring(number)) or "(unnamed track)"
end

function fx_name(track, fx)
  local ok, name = reaper.TrackFX_GetFXName(track, fx, "")
  if ok and name and name ~= "" then return name end
  return "(focused FX)"
end

local function param_name(track, fx, param)
  local ok, name = reaper.TrackFX_GetParamName(track, fx, param, "")
  if ok and name and name ~= "" then return name end
  return "Param " .. tostring(param + 1)
end

local function param_display(track, fx, param)
  local ok, value = reaper.TrackFX_GetFormattedParamValue(track, fx, param, "")
  if ok and value and value ~= "" then return value end
  local actual = reaper.TrackFX_GetParam(track, fx, param)
  return string.format("%.4f", actual or 0)
end

function make_key(track, fx)
  if not track or fx < 0 then return "" end
  return tostring(reaper.GetTrackGUID(track) or track) .. ":" .. tostring(fx)
end

local function refresh_params(preserve_selection)
  local track, fx, err, source = discover_track_fx()
  if err then
    params = {}
    selected = {}
    last_key = ""
    status = err
    return nil, -1
  end

  local key = make_key(track, fx)
  local old = selected
  selected = {}
  params = {}
  local count = reaper.TrackFX_GetNumParams(track, fx)
  for param = 0, count - 1 do
    local name = param_name(track, fx, param)
    if not (skip_empty and name == "") then
      params[#params + 1] = {
        index = param,
        name = name,
        norm = reaper.TrackFX_GetParamNormalized(track, fx, param),
        display = param_display(track, fx, param),
      }
      selected[param] = preserve_selection and key == last_key and old[param] or false
    end
  end
  last_key = key
  lock_target(track, fx)
  load_buckets(track, fx)
  status = string.format("Locked %s FX: %s / %s / %d params", source or "target", track_name(track), fx_name(track, fx), #params)
  return track, fx
end

local function visible_param(p)
  local f = lower(filter_text)
  if f == "" then return true end
  return lower(p.name):find(f, 1, true) or tostring(p.index + 1):find(f, 1, true)
end

local function select_visible(value)
  for _, p in ipairs(params) do
    if visible_param(p) then selected[p.index] = value end
  end
end

local function invert_visible()
  for _, p in ipairs(params) do
    if visible_param(p) then selected[p.index] = not selected[p.index] end
  end
end

local function selected_count()
  local count = 0
  for _, p in ipairs(params) do
    if selected[p.index] then count = count + 1 end
  end
  return count
end

local function selected_params()
  local out = {}
  for _, p in ipairs(params) do
    if selected[p.index] then out[#out + 1] = p.index end
  end
  return out
end

local function visible_params()
  local out = {}
  for _, p in ipairs(params) do
    if visible_param(p) then out[#out + 1] = p.index end
  end
  return out
end

local function set_selected_params(indices, merge)
  if not merge then selected = {} end
  for _, param in ipairs(indices or {}) do selected[param] = true end
end

local function save_bucket_from(indices)
  local track, fx, err = target_track_fx()
  if err then status = err return end
  if not indices or #indices == 0 then
    status = "No parameters to store in bucket."
    return
  end
  local name = bucket_name
  if not name or name == "" then name = "Bucket " .. tostring(#buckets + 1) end

  local unique, clean = {}, {}
  for _, param in ipairs(indices) do
    if not unique[param] then
      unique[param] = true
      clean[#clean + 1] = param
    end
  end
  table.sort(clean)

  local replaced = false
  for i, bucket in ipairs(buckets) do
    if lower(bucket.name) == lower(name) then
      buckets[i] = { name = name, params = clean }
      active_bucket = i
      replaced = true
      break
    end
  end
  if not replaced then
    buckets[#buckets + 1] = { name = name, params = clean }
    active_bucket = #buckets
  end
  save_buckets(track, fx)
  status = string.format("%s bucket '%s' with %d params.", replaced and "Updated" or "Saved", name, #clean)
end

local function recall_bucket(merge)
  local bucket = buckets[active_bucket]
  if not bucket then status = "No bucket selected." return end
  set_selected_params(bucket.params, merge)
  bucket_name = bucket.name
  status = string.format("%s %d params from bucket '%s'.", merge and "Added" or "Selected", #(bucket.params or {}), bucket.name)
end

local function delete_bucket()
  local track, fx, err = target_track_fx()
  if err then status = err return end
  local bucket = buckets[active_bucket]
  if not bucket then status = "No bucket selected." return end
  local name = bucket.name
  table.remove(buckets, active_bucket)
  active_bucket = math.max(1, math.min(active_bucket, #buckets))
  save_buckets(track, fx)
  status = "Deleted bucket '" .. name .. "'."
end

function param_label(param)
  for _, p in ipairs(params) do
    if p.index == param then return p.name end
  end
  return "Param " .. tostring(param + 1)
end

local function ensure_envelope(track, fx, param)
  local env = reaper.GetFXEnvelope(track, fx, param, true)
  if not env then return nil end
  if reaper.SetEnvelopeInfo_Value then
    pcall(reaper.SetEnvelopeInfo_Value, env, "B_VISIBLE", show_lanes and 1 or 0)
    pcall(reaper.SetEnvelopeInfo_Value, env, "B_ACTIVE", 1)
    pcall(reaper.SetEnvelopeInfo_Value, env, "B_ARM", arm_lanes and 1 or 0)
    pcall(reaper.SetEnvelopeInfo_Value, env, "I_TCPH", show_lanes and lane_height or 0)
  end
  return env
end

local function current_envelope_value(env, track, fx, param)
  local value = reaper.TrackFX_GetParam(track, fx, param)
  if value == nil then value = reaper.TrackFX_GetParamNormalized(track, fx, param) end
  if reaper.GetEnvelopeScalingMode and reaper.ScaleToEnvelopeMode then
    local mode = reaper.GetEnvelopeScalingMode(env)
    if mode and mode ~= 0 then value = reaper.ScaleToEnvelopeMode(mode, value) end
  end
  return value or 0
end

local function write_selected()
  local track, fx, err = target_track_fx()
  if err then status = err return end
  local cursor_pos = reaper.GetCursorPosition()
  local wrote, lanes = 0, 0

  reaper.Undo_BeginBlock()
  for _, p in ipairs(params) do
    if selected[p.index] then
      local env = ensure_envelope(track, fx, p.index)
      if env then
        lanes = lanes + 1
        local value = current_envelope_value(env, track, fx, p.index)
        reaper.InsertEnvelopePoint(env, cursor_pos, value, 0, 0, false, true)
        wrote = wrote + 1
        reaper.Envelope_SortPoints(env)
      end
    end
  end
  reaper.Undo_EndBlock("Focused FX Automation Capture", -1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()

  status = string.format("Wrote %d envelope points across %d lanes.", wrote, lanes)
end

local function save_point_at_cursor()
  write_selected()
end

local function show_selected_lanes()
  local track, fx, err = target_track_fx()
  if err then status = err return end
  local lanes = 0
  reaper.Undo_BeginBlock()
  for _, p in ipairs(params) do
    if selected[p.index] then
      local env = ensure_envelope(track, fx, p.index)
      if env then lanes = lanes + 1 end
    end
  end
  reaper.Undo_EndBlock("Focused FX Automation Capture Show Lanes", -1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  status = string.format("Created/showed %d automation lanes.", lanes)
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 900, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local focused_track, focused_fx, focused_err = focused_track_fx()
    local track, fx, err = target_track_fx()
    if err then
      ImGui.TextColored(ctx, STYLE.warn, err)
    else
      ImGui.Text(ctx, "Locked: " .. track_name(track))
      ImGui.SameLine(ctx)
      ImGui.TextColored(ctx, STYLE.muted, " / " .. fx_name(track, fx))
    end

    local changed
    if ImGui.Button(ctx, "Lock FX", 78, 24) then refresh_params(true) end
    if focused_err then
      ImGui.SameLine(ctx)
      ImGui.TextColored(ctx, STYLE.muted, "Focus or touch a plugin parameter, then lock.")
    elseif focused_track and focused_fx >= 0 then
      ImGui.SameLine(ctx)
      ImGui.TextColored(ctx, STYLE.muted, "Focused: " .. track_name(focused_track) .. " / " .. fx_name(focused_track, focused_fx))
    end
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 330)
    changed, filter_text = ImGui.InputText(ctx, "Filter", filter_text)
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, STYLE.muted, tostring(selected_count()) .. " selected")
    ImGui.SameLine(ctx)
    changed, show_params = ImGui.Checkbox(ctx, "Show list", show_params)

    if ImGui.Button(ctx, "Select visible", 104, 24) then select_visible(true) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "None", 58, 24) then select_visible(false) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Invert", 64, 24) then invert_visible() end
    ImGui.SameLine(ctx)
    changed, skip_empty = ImGui.Checkbox(ctx, "Skip empty names", skip_empty)

    ImGui.Separator(ctx)
    local preview = buckets[active_bucket] and buckets[active_bucket].name or "(none)"
    ImGui.SetNextItemWidth(ctx, 220)
    if ImGui.BeginCombo(ctx, "Stored", preview) then
      for i, bucket in ipairs(buckets) do
        local chosen = i == active_bucket
        local label = bucket.name .. " (" .. tostring(#(bucket.params or {})) .. ")"
        if ImGui.Selectable(ctx, label, chosen) then
          active_bucket = i
          bucket_name = bucket.name
        end
        if chosen then ImGui.SetItemDefaultFocus(ctx) end
      end
      ImGui.EndCombo(ctx)
    end
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 160)
    changed, bucket_name = ImGui.InputText(ctx, "Bucket name", bucket_name)
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Save visible", 96, 24) then save_bucket_from(visible_params()) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Save selected", 104, 24) then save_bucket_from(selected_params()) end
    if ImGui.Button(ctx, "Recall", 72, 24) then recall_bucket(false) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Add", 54, 24) then recall_bucket(true) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Delete", 64, 24) then delete_bucket() end
    ImGui.SameLine(ctx)
    if buckets[active_bucket] then
      ImGui.TextColored(ctx, STYLE.muted, bucket_preview(buckets[active_bucket]))
    else
      ImGui.TextColored(ctx, STYLE.muted, "No stored bucket for this FX.")
    end

    ImGui.Separator(ctx)
    if ImGui.Button(ctx, "Save Point at Cursor", 168, 30) then save_point_at_cursor() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Show Selected Lanes", 154, 30) then show_selected_lanes() end
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, STYLE.muted, "Move cursor, adjust plugin GUI, save again. REAPER handles envelope interpolation.")

    if show_params then
      ImGui.Separator(ctx)
      ImGui.TextColored(ctx, STYLE.muted, "Parameters")
      if #params == 0 and track and fx >= 0 then refresh_params(false) end
      for _, p in ipairs(params) do
        if visible_param(p) then
          local label = string.format("%03d  %s", p.index + 1, p.name)
          local is_selected = selected[p.index] or false
          local changed_sel
          changed_sel, is_selected = ImGui.Checkbox(ctx, "##sel_" .. tostring(p.index), is_selected)
          if changed_sel then selected[p.index] = is_selected end
          ImGui.SameLine(ctx)
          ImGui.Text(ctx, label)
          ImGui.SameLine(ctx)
          ImGui.TextColored(ctx, STYLE.muted, p.display)
        end
      end
    end

    if status ~= "" then
      local ok_status = status:find("Wrote", 1, true) or status:find("Created", 1, true) or status:find("Saved", 1, true) or status:find("Updated", 1, true) or status:find("Selected", 1, true)
      local col = ok_status and STYLE.ok or STYLE.muted
      ImGui.TextColored(ctx, col, status)
    end
    if ImGui.Button(ctx, "Close", 90, 28) then open = false end
    ImGui.End(ctx)
  end

  if open then reaper.defer(loop) end
end

refresh_params(false)
loop()
