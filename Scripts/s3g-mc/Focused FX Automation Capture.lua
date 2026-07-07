-- @description Focused FX Automation Capture
-- @author s3g
-- @version 0.1
-- @requires ReaImGui
-- @category Channel Mixing / Automation
-- @method ReaImGui utility for the currently focused track FX. Lists parameters, filters/selects them, captures timeline snapshots, and writes interpolated automation lanes.
-- @about
--   Captures the current settings of the focused track FX into visible, armed
--   automation lanes. Use the filter and checkboxes to snapshot all parameters
--   or a selected subset, then write editable automation between snapshots.

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", "Focused FX Automation Capture", 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TITLE = "Focused FX Automation Capture"
local ctx = ImGui.CreateContext(TITLE)
local open = true

local params = {}
local selected = {}
local filter_text = ""
local skip_empty = true
local arm_lanes = true
local show_lanes = true
local lane_height = 72
local write_mode = 1 -- 1 point at edit cursor, 2 constant over time selection, 3 lanes only
local interp_mode = 2
local curve_points = 16
local replace_between_snapshots = true
local last_key = ""
local status = "Focus an FX window, then refresh."
local snapshots = {}

local COLORS = {
  muted = ImGui.ColorConvertDouble4ToU32(0.55, 0.59, 0.60, 1),
  warn = ImGui.ColorConvertDouble4ToU32(0.95, 0.45, 0.34, 1),
  ok = ImGui.ColorConvertDouble4ToU32(0.45, 0.86, 0.58, 1),
}

local INTERP = {
  "Hold then jump",
  "Linear",
  "Smooth ease",
  "Ease in",
  "Ease out",
  "Stepped",
}

local function lower(s)
  return string.lower(s or "")
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

  local track
  if track_number == 0 then
    track = reaper.GetMasterTrack(0)
  elseif track_number and track_number > 0 then
    track = reaper.GetTrack(0, track_number - 1)
  end
  if not track or not fx_number or fx_number < 0 then return nil, -1, "Focused FX is not a track FX." end
  return track, fx_number, nil
end

local function track_name(track)
  if track == reaper.GetMasterTrack(0) then return "Master" end
  local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  if name and name ~= "" then return name end
  local number = math.floor((reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") or 0) + 0.5)
  return number > 0 and ("Track " .. tostring(number)) or "(unnamed track)"
end

local function fx_name(track, fx)
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

local function make_key(track, fx)
  if not track or fx < 0 then return "" end
  return tostring(reaper.GetTrackGUID(track) or track) .. ":" .. tostring(fx)
end

local function refresh_params(preserve_selection)
  local track, fx, err = focused_track_fx()
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
  status = string.format("%s / %s / %d params", track_name(track), fx_name(track, fx), #params)
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

local function param_label(param)
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

local function current_write_range()
  local start_pos, end_pos = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if end_pos and start_pos and end_pos > start_pos then return start_pos, end_pos, true end
  local pos = reaper.GetCursorPosition()
  return pos, pos, false
end

local function write_selected()
  local track, fx, err = focused_track_fx()
  if err then status = err return end
  local start_pos, end_pos, has_range = current_write_range()
  local wrote, lanes = 0, 0

  reaper.Undo_BeginBlock()
  for _, p in ipairs(params) do
    if selected[p.index] then
      local env = ensure_envelope(track, fx, p.index)
      if env then
        lanes = lanes + 1
        local value = reaper.TrackFX_GetParamNormalized(track, fx, p.index)
        if write_mode == 1 then
          reaper.InsertEnvelopePoint(env, start_pos, value, 0, 0, false, true)
          wrote = wrote + 1
        elseif write_mode == 2 and has_range then
          reaper.DeleteEnvelopePointRange(env, start_pos - 0.000001, end_pos + 0.000001)
          reaper.InsertEnvelopePoint(env, start_pos, value, 0, 0, false, true)
          reaper.InsertEnvelopePoint(env, end_pos, value, 0, 0, false, true)
          wrote = wrote + 2
        end
        reaper.Envelope_SortPoints(env)
      end
    end
  end
  reaper.Undo_EndBlock("Focused FX Automation Capture", -1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()

  if write_mode == 3 then
    status = string.format("Created/showed %d automation lanes.", lanes)
  elseif write_mode == 2 and not has_range then
    status = "No time selection; use Point at edit cursor or make a time selection."
  else
    status = string.format("Wrote %d envelope points across %d lanes.", wrote, lanes)
  end
end

local function capture_snapshot()
  local track, fx, err = focused_track_fx()
  if err then status = err return end
  local picks = selected_params()
  if #picks == 0 then
    status = "Select at least one parameter to capture."
    return
  end

  local t = reaper.GetCursorPosition()
  local snap = {
    time = t,
    interp_from_prev = interp_mode,
    fx_key = make_key(track, fx),
    fx_name = fx_name(track, fx),
    track_name = track_name(track),
    values = {},
    displays = {},
  }
  for _, param in ipairs(picks) do
    snap.values[param] = reaper.TrackFX_GetParamNormalized(track, fx, param)
    snap.displays[param] = param_display(track, fx, param)
  end

  local replaced = false
  for i, existing in ipairs(snapshots) do
    if math.abs(existing.time - t) < 0.0005 and existing.fx_key == snap.fx_key then
      snapshots[i] = snap
      replaced = true
      break
    end
  end
  if not replaced then snapshots[#snapshots + 1] = snap end
  table.sort(snapshots, function(a, b) return a.time < b.time end)
  status = string.format("%s snapshot at %.3fs with %d params.", replaced and "Replaced" or "Captured", t, #picks)
end

local function clear_snapshots()
  snapshots = {}
  status = "Cleared snapshots."
end

local function union_snapshot_params()
  local seen, out = {}, {}
  for _, snap in ipairs(snapshots) do
    for param in pairs(snap.values) do
      if not seen[param] then
        seen[param] = true
        out[#out + 1] = param
      end
    end
  end
  table.sort(out)
  return out
end

local function eased(u, mode)
  if mode == 3 then
    return u * u * (3 - 2 * u)
  elseif mode == 4 then
    return u * u
  elseif mode == 5 then
    return 1 - ((1 - u) * (1 - u))
  end
  return u
end

local function write_snapshot_segment(env, a, b, param)
  local va, vb = a.values[param], b.values[param]
  if va == nil or vb == nil then return 0 end
  local mode = b.interp_from_prev or 2
  local t1, t2 = a.time, b.time
  if t2 <= t1 then return 0 end

  if mode == 1 then
    reaper.InsertEnvelopePoint(env, t1, va, 0, 0, false, true)
    reaper.InsertEnvelopePoint(env, math.max(t1, t2 - 0.000001), va, 0, 0, false, true)
    reaper.InsertEnvelopePoint(env, t2, vb, 0, 0, false, true)
    return 3
  elseif mode == 6 then
    local steps = math.max(2, math.min(32, curve_points))
    local wrote = 0
    for i = 0, steps do
      local u = i / steps
      local stepped = math.floor(u * steps) / steps
      local value = va + (vb - va) * stepped
      reaper.InsertEnvelopePoint(env, t1 + (t2 - t1) * u, value, 0, 0, false, true)
      wrote = wrote + 1
    end
    return wrote
  elseif mode == 2 then
    reaper.InsertEnvelopePoint(env, t1, va, 0, 0, false, true)
    reaper.InsertEnvelopePoint(env, t2, vb, 0, 0, false, true)
    return 2
  end

  local points = math.max(4, math.min(64, curve_points))
  local wrote = 0
  for i = 0, points do
    local u = i / points
    local value = va + (vb - va) * eased(u, mode)
    reaper.InsertEnvelopePoint(env, t1 + (t2 - t1) * u, value, 0, 0, false, true)
    wrote = wrote + 1
  end
  return wrote
end

local function write_snapshots()
  local track, fx, err = focused_track_fx()
  if err then status = err return end
  if #snapshots == 0 then status = "Capture at least one snapshot first." return end

  local current_key = make_key(track, fx)
  for _, snap in ipairs(snapshots) do
    if snap.fx_key ~= current_key then
      status = "Snapshots belong to a different focused FX. Refocus that FX or clear snapshots."
      return
    end
  end

  table.sort(snapshots, function(a, b) return a.time < b.time end)
  local snapshot_params = union_snapshot_params()
  local wrote, lanes = 0, 0

  reaper.Undo_BeginBlock()
  for _, param in ipairs(snapshot_params) do
    local env = ensure_envelope(track, fx, param)
    if env then
      lanes = lanes + 1
      if replace_between_snapshots then
        local t1 = snapshots[1].time
        local t2 = snapshots[#snapshots].time
        reaper.DeleteEnvelopePointRange(env, t1 - 0.000001, t2 + 0.000001)
      end
      if #snapshots == 1 then
        local value = snapshots[1].values[param]
        if value ~= nil then
          reaper.InsertEnvelopePoint(env, snapshots[1].time, value, 0, 0, false, true)
          wrote = wrote + 1
        end
      else
        for i = 2, #snapshots do
          wrote = wrote + write_snapshot_segment(env, snapshots[i - 1], snapshots[i], param)
        end
      end
      reaper.Envelope_SortPoints(env)
    end
  end
  reaper.Undo_EndBlock("Focused FX Snapshot Automation", -1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  status = string.format("Wrote %d envelope points across %d lanes from %d snapshots.", wrote, lanes, #snapshots)
end

local function draw_mode_buttons()
  local labels = { "Point at cursor", "Constant in time selection", "Show/arm lanes only" }
  for i, label in ipairs(labels) do
    if i > 1 then ImGui.SameLine(ctx) end
    if write_mode == i then ImGui.PushStyleColor(ctx, ImGui.Col_Button, ImGui.ColorConvertDouble4ToU32(0.18, 0.46, 0.52, 1)) end
    if ImGui.Button(ctx, label) then write_mode = i end
    if write_mode == i then ImGui.PopStyleColor(ctx) end
  end
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 900, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    local track, fx, err = focused_track_fx()
    if err then
      ImGui.TextColored(ctx, COLORS.warn, err)
    else
      ImGui.Text(ctx, track_name(track))
      ImGui.SameLine(ctx)
      ImGui.TextColored(ctx, COLORS.muted, " / " .. fx_name(track, fx))
    end

    if ImGui.Button(ctx, "Refresh") then refresh_params(true) end
    ImGui.SameLine(ctx)
    local changed
    changed, filter_text = ImGui.InputText(ctx, "Filter", filter_text)
    ImGui.SameLine(ctx)
    changed, skip_empty = ImGui.Checkbox(ctx, "Skip empty", skip_empty)

    draw_mode_buttons()
    changed, show_lanes = ImGui.Checkbox(ctx, "Show lanes", show_lanes)
    ImGui.SameLine(ctx)
    changed, arm_lanes = ImGui.Checkbox(ctx, "Arm lanes", arm_lanes)
    ImGui.SameLine(ctx)
    changed, lane_height = ImGui.SliderInt(ctx, "Lane height", lane_height, 32, 140)

    if ImGui.Button(ctx, "Select visible") then select_visible(true) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "None") then select_visible(false) end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Invert") then invert_visible() end
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, COLORS.muted, tostring(selected_count()) .. " selected")

    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Snapshots")
    ImGui.SameLine(ctx)
    if ImGui.BeginCombo(ctx, "Interpolation from previous", INTERP[interp_mode]) then
      for i, label in ipairs(INTERP) do
        local chosen = i == interp_mode
        if ImGui.Selectable(ctx, label, chosen) then interp_mode = i end
        if chosen then ImGui.SetItemDefaultFocus(ctx) end
      end
      ImGui.EndCombo(ctx)
    end
    changed, curve_points = ImGui.SliderInt(ctx, "Curve points", curve_points, 4, 64)
    ImGui.SameLine(ctx)
    changed, replace_between_snapshots = ImGui.Checkbox(ctx, "Replace range", replace_between_snapshots)

    if ImGui.Button(ctx, "Capture Snapshot", 150, 28) then capture_snapshot() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Write Snapshots", 140, 28) then write_snapshots() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Clear Snapshots", 130, 28) then clear_snapshots() end
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, COLORS.muted, tostring(#snapshots) .. " captured")

    if #snapshots > 0 then
      for i, snap in ipairs(snapshots) do
        local label = string.format("%02d  %.3fs  %s", i, snap.time, i == 1 and "start" or INTERP[snap.interp_from_prev or 2])
        ImGui.TextColored(ctx, COLORS.muted, label)
        ImGui.SameLine(ctx)
        local names = {}
        for param in pairs(snap.values) do names[#names + 1] = param_label(param) end
        table.sort(names)
        local text = table.concat(names, ", ")
        if #text > 80 then text = text:sub(1, 77) .. "..." end
        ImGui.Text(ctx, text)
      end
    end

    ImGui.Separator(ctx)
    local footer_height = 76
    local child_flags = ImGui.ChildFlags_Borders and ImGui.ChildFlags_Borders() or ImGui.ChildFlags_Border and ImGui.ChildFlags_Border() or 0
    if ImGui.BeginChild(ctx, "##focused_fx_params", 0, -footer_height, child_flags) then
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
          ImGui.TextColored(ctx, COLORS.muted, p.display)
        end
      end
    end
    ImGui.EndChild(ctx)

    if status ~= "" then
      local ok_status = status:find("Wrote", 1, true) or status:find("Created", 1, true) or status:find("Captured", 1, true) or status:find("Replaced", 1, true)
      local col = ok_status and COLORS.ok or COLORS.muted
      ImGui.TextColored(ctx, col, status)
    end
    if ImGui.Button(ctx, "Write Current", 130, 30) then write_selected() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Write Snapshots", 140, 30) then write_snapshots() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Close", 90, 30) then open = false end
    ImGui.End(ctx)
  end

  if open then reaper.defer(loop) end
end

refresh_params(false)
loop()
