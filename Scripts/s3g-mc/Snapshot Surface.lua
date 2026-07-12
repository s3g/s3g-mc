-- @description Snapshot Surface
-- @author s3g
-- @version 0.1
-- @requires ReaImGui; JSFX: s3g Snapshot Surface Cursor
-- @category Channel Mixing / Automation
-- @method Captures REAPER track and FX states as 2D surface snapshots, then interpolates the captured parameters by moving a cursor between snapshots.
-- @about
--   A project-state interpolation surface for REAPER. Capture selected tracks,
--   selected-track FX, the focused FX, or a bounded project scope as surface
--   nodes, then move the cursor to apply an interpolated state.

local TITLE = "Snapshot Surface"
local EXT = "s3g_mc_snapshot_surface_v1"
local PROJECT = 0
local CURSOR_FX_NAME = "s3g Snapshot Surface Cursor"
local CURSOR_TRACK_NAME = "Snapshot Surface Cursor"

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is not installed or not loaded.", TITLE, 0)
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

local ctx = ImGui.CreateContext(TITLE)
local open = true
local snapshots = {}
local cursor = { x = 0.5, y = 0.5 }
local selected_snapshot = nil
local status = "Capture a snapshot to begin."
local auto_apply = false
local follow_cursor_fx = false
local cursor_link_track_guid = ""
local cursor_link_fx = -1
local show_regions = true
local include_fx_enabled = true
local interpolation_power = 2.0
local scope_index = 1
local max_project_tracks = 64
local max_fx_per_track = 16
local max_params_per_fx = 256
local capture_name = ""
local last_auto_apply_x = nil
local last_auto_apply_y = nil
local dragging_snapshot = nil
local snapshot_drag_dx = 0
local snapshot_drag_dy = 0
local snapshot_position_dirty = false

local SCOPES = {
  "Selected tracks + FX",
  "Selected track FX only",
  "Focused FX only",
  "Entire project bounded",
  "Selected track controls only",
}

local TYPE_NUMBER = "number"
local TYPE_BOOL = "bool"

local COLORS = {
  bg = ImGui.ColorConvertDouble4ToU32(0.035, 0.038, 0.041, 1),
  grid = ImGui.ColorConvertDouble4ToU32(0.52, 0.56, 0.58, 0.16),
  edge = ImGui.ColorConvertDouble4ToU32(0.35, 0.38, 0.40, 1),
  region_edge = ImGui.ColorConvertDouble4ToU32(0.48, 0.51, 0.53, 0.78),
  triangle = ImGui.ColorConvertDouble4ToU32(0.86, 0.90, 0.92, 0.22),
  node = ImGui.ColorConvertDouble4ToU32(0.58, 0.64, 0.67, 1),
  node_sel = ImGui.ColorConvertDouble4ToU32(0.86, 0.90, 0.92, 1),
  cursor = ImGui.ColorConvertDouble4ToU32(0.78, 0.84, 0.86, 1),
  influence = ImGui.ColorConvertDouble4ToU32(0.78, 0.84, 0.86, 0.18),
  muted = ImGui.ColorConvertDouble4ToU32(0.55, 0.59, 0.60, 1),
  warn = ImGui.ColorConvertDouble4ToU32(0.95, 0.48, 0.34, 1),
}

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local function hsv_to_rgb(h, s, v)
  h = (h % 1) * 6
  local i = math.floor(h)
  local f = h - i
  local p = v * (1 - s)
  local q = v * (1 - f * s)
  local t = v * (1 - (1 - f) * s)
  if i == 0 then return v, t, p end
  if i == 1 then return q, v, p end
  if i == 2 then return p, v, t end
  if i == 3 then return p, q, v end
  if i == 4 then return t, p, v end
  return v, p, q
end

local function serialize(value, indent)
  indent = indent or ""
  local value_type = type(value)
  if value_type == "number" or value_type == "boolean" then return tostring(value) end
  if value_type == "string" then return string.format("%q", value) end
  if value_type ~= "table" then return "nil" end
  local next_indent = indent .. "  "
  local parts = { "{\n" }
  for key, item in pairs(value) do
    local key_text
    if type(key) == "number" then
      key_text = "[" .. tostring(key) .. "]"
    else
      key_text = "[" .. string.format("%q", tostring(key)) .. "]"
    end
    parts[#parts + 1] = next_indent .. key_text .. " = " .. serialize(item, next_indent) .. ",\n"
  end
  parts[#parts + 1] = indent .. "}"
  return table.concat(parts)
end

local function save_state()
  local state = {
    snapshots = snapshots,
    cursor = cursor,
    settings = {
      scope_index = scope_index,
      interpolation_power = interpolation_power,
      follow_cursor_fx = follow_cursor_fx,
      cursor_link_track_guid = cursor_link_track_guid,
      cursor_link_fx = cursor_link_fx,
      show_regions = show_regions,
      include_fx_enabled = include_fx_enabled,
      max_project_tracks = max_project_tracks,
      max_fx_per_track = max_fx_per_track,
      max_params_per_fx = max_params_per_fx,
    }
  }
  reaper.SetProjExtState(PROJECT, EXT, "state", serialize(state))
end

local function load_state()
  local _, text = reaper.GetProjExtState(PROJECT, EXT, "state")
  if not text or text == "" then return end
  local chunk = load("return " .. text, "snapshot_surface_state", "t", {})
  if not chunk then return end
  local ok, state = pcall(chunk)
  if not ok or type(state) ~= "table" then return end
  snapshots = type(state.snapshots) == "table" and state.snapshots or {}
  cursor = type(state.cursor) == "table" and state.cursor or cursor
  cursor.x = clamp(tonumber(cursor.x) or 0.5, 0, 1)
  cursor.y = clamp(tonumber(cursor.y) or 0.5, 0, 1)
  local settings = type(state.settings) == "table" and state.settings or {}
  scope_index = clamp(math.floor(tonumber(settings.scope_index) or scope_index), 1, #SCOPES)
  interpolation_power = clamp(tonumber(settings.interpolation_power) or interpolation_power, 0.25, 8)
  follow_cursor_fx = settings.follow_cursor_fx == true
  cursor_link_track_guid = tostring(settings.cursor_link_track_guid or "")
  cursor_link_fx = math.floor(tonumber(settings.cursor_link_fx) or -1)
  show_regions = settings.show_regions ~= false
  include_fx_enabled = settings.include_fx_enabled ~= false
  max_project_tracks = clamp(math.floor(tonumber(settings.max_project_tracks) or max_project_tracks), 1, 256)
  max_fx_per_track = clamp(math.floor(tonumber(settings.max_fx_per_track) or max_fx_per_track), 0, 64)
  max_params_per_fx = clamp(math.floor(tonumber(settings.max_params_per_fx) or max_params_per_fx), 1, 2048)
  status = string.format("Loaded %d snapshot(s) from project.", #snapshots)
end

local function track_guid(track)
  if not track then return "" end
  return reaper.GetTrackGUID(track) or ""
end

local function track_by_guid(guid)
  if guid == "MASTER" then return reaper.GetMasterTrack(PROJECT) end
  for index = 0, reaper.CountTracks(PROJECT) - 1 do
    local track = reaper.GetTrack(PROJECT, index)
    if track_guid(track) == guid then return track end
  end
  return nil
end

local function track_name(track)
  local ok, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  if ok and name ~= "" then return name end
  local number = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") or 0)
  if number > 0 then return "Track " .. tostring(number) end
  return "Master"
end

local function fx_name_matches(name)
  return name and name:find(CURSOR_FX_NAME, 1, true) ~= nil
end

local function linked_cursor_fx()
  local track = track_by_guid(cursor_link_track_guid)
  if not track or cursor_link_fx < 0 then return nil, -1 end
  local ok, name = reaper.TrackFX_GetFXName(track, cursor_link_fx, "")
  if ok and fx_name_matches(name) then return track, cursor_link_fx end
  return nil, -1
end

local function find_cursor_fx()
  for track_index = 0, reaper.CountTracks(PROJECT) - 1 do
    local track = reaper.GetTrack(PROJECT, track_index)
    local fx_count = reaper.TrackFX_GetCount(track) or 0
    for fx = 0, fx_count - 1 do
      local ok, name = reaper.TrackFX_GetFXName(track, fx, "")
      if ok and fx_name_matches(name) then return track, fx end
    end
  end
  return nil, -1
end

local function add_cursor_fx(track)
  local fx = reaper.TrackFX_AddByName(track, "JS: " .. CURSOR_FX_NAME, false, -1)
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, CURSOR_FX_NAME, false, -1) end
  if fx < 0 then fx = reaper.TrackFX_AddByName(track, "JS: s3g/" .. CURSOR_FX_NAME, false, -1) end
  return fx
end

local function create_or_link_cursor_fx()
  local track, fx = linked_cursor_fx()
  if not track then track, fx = find_cursor_fx() end
  if not track then
    local index = reaper.CountTracks(PROJECT)
    reaper.InsertTrackAtIndex(index, true)
    track = reaper.GetTrack(PROJECT, index)
    if not track then
      status = "Could not create cursor control track."
      return
    end
    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", CURSOR_TRACK_NAME, true)
    fx = add_cursor_fx(track)
  end
  if track and fx and fx >= 0 then
    cursor_link_track_guid = track_guid(track)
    cursor_link_fx = fx
    follow_cursor_fx = true
    reaper.TrackFX_SetParamNormalized(track, fx, 0, cursor.x)
    reaper.TrackFX_SetParamNormalized(track, fx, 1, cursor.y)
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()
    status = "Linked Snapshot Surface cursor FX."
    save_state()
  else
    status = "Could not load JS: " .. CURSOR_FX_NAME .. ". Rescan JSFX if it was just installed."
  end
end

local function show_arm_cursor_envelopes()
  local track, fx = linked_cursor_fx()
  if not track then
    status = "Create or link the cursor FX first."
    return
  end
  local shown = 0
  if reaper.GetFXEnvelope then
    for param = 0, 1 do
      local env = reaper.GetFXEnvelope(track, fx, param, true)
      if env then
        shown = shown + 1
      end
    end
    reaper.SetOnlyTrackSelected(track)
    reaper.TrackFX_Show(track, fx, 3)
  else
    reaper.TrackFX_Show(track, fx, 3)
  end
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  if shown > 0 then
    status = "Created Cursor X/Y envelopes and opened the cursor FX."
  else
    status = "Opened cursor FX. This REAPER build did not expose FX envelope creation to the script."
  end
end

local function linked_cursor_label()
  local track, fx = linked_cursor_fx()
  if not track then return "Cursor FX: not linked" end
  local ok, fx_name = reaper.TrackFX_GetFXName(track, fx, "")
  return string.format("Cursor FX: %s / %s", track_name(track), ok and fx_name or CURSOR_FX_NAME)
end

local function add_target(snapshot, target)
  snapshot.targets[target.id] = target
  snapshot.order[#snapshot.order + 1] = target.id
end

local function capture_track_controls(snapshot, track)
  local guid = track_guid(track)
  local name = track_name(track)
  add_target(snapshot, {
    id = "track:" .. guid .. ":vol",
    kind = "track_vol",
    value_type = TYPE_NUMBER,
    track_guid = guid,
    value = reaper.GetMediaTrackInfo_Value(track, "D_VOL") or 1,
    label = name .. " / volume",
  })
  add_target(snapshot, {
    id = "track:" .. guid .. ":pan",
    kind = "track_pan",
    value_type = TYPE_NUMBER,
    track_guid = guid,
    value = reaper.GetMediaTrackInfo_Value(track, "D_PAN") or 0,
    label = name .. " / pan",
  })
  add_target(snapshot, {
    id = "track:" .. guid .. ":mute",
    kind = "track_mute",
    value_type = TYPE_BOOL,
    track_guid = guid,
    value = (reaper.GetMediaTrackInfo_Value(track, "B_MUTE") or 0) >= 0.5 and 1 or 0,
    label = name .. " / mute",
  })
  add_target(snapshot, {
    id = "track:" .. guid .. ":solo",
    kind = "track_solo",
    value_type = TYPE_BOOL,
    track_guid = guid,
    value = (reaper.GetMediaTrackInfo_Value(track, "I_SOLO") or 0) > 0 and 1 or 0,
    label = name .. " / solo",
  })
end

local function capture_fx(snapshot, track, fx)
  local guid = track_guid(track)
  local ok, fx_name = reaper.TrackFX_GetFXName(track, fx, "")
  fx_name = ok and fx_name or ("FX " .. tostring(fx + 1))
  local prefix = track_name(track) .. " / " .. fx_name
  if include_fx_enabled and reaper.TrackFX_GetEnabled then
    add_target(snapshot, {
      id = "fx:" .. guid .. ":" .. tostring(fx) .. ":enabled",
      kind = "fx_enabled",
      value_type = TYPE_BOOL,
      track_guid = guid,
      fx = fx,
      value = reaper.TrackFX_GetEnabled(track, fx) and 1 or 0,
      label = prefix .. " / enabled",
    })
  end
  local param_count = math.min(reaper.TrackFX_GetNumParams(track, fx) or 0, max_params_per_fx)
  for param = 0, param_count - 1 do
    local _, param_name = reaper.TrackFX_GetParamName(track, fx, param, "")
    param_name = (param_name and param_name ~= "") and param_name or ("Param " .. tostring(param + 1))
    add_target(snapshot, {
      id = "fx:" .. guid .. ":" .. tostring(fx) .. ":param:" .. tostring(param),
      kind = "fx_param",
      value_type = TYPE_NUMBER,
      track_guid = guid,
      fx = fx,
      param = param,
      value = reaper.TrackFX_GetParamNormalized(track, fx, param) or 0,
      label = prefix .. " / " .. param_name,
    })
  end
end

local function read_target_current_value(template)
  if not template then return nil end
  local track = track_by_guid(template.track_guid or "")
  if not track then return nil end
  if template.kind == "track_vol" then
    return reaper.GetMediaTrackInfo_Value(track, "D_VOL") or 1
  elseif template.kind == "track_pan" then
    return reaper.GetMediaTrackInfo_Value(track, "D_PAN") or 0
  elseif template.kind == "track_mute" then
    return (reaper.GetMediaTrackInfo_Value(track, "B_MUTE") or 0) >= 0.5 and 1 or 0
  elseif template.kind == "track_solo" then
    return (reaper.GetMediaTrackInfo_Value(track, "I_SOLO") or 0) > 0 and 1 or 0
  elseif template.kind == "fx_enabled" and reaper.TrackFX_GetEnabled then
    return reaper.TrackFX_GetEnabled(track, template.fx) and 1 or 0
  elseif template.kind == "fx_param" then
    local fx_count = reaper.TrackFX_GetCount(track) or 0
    if not template.fx or template.fx < 0 or template.fx >= fx_count then return nil end
    return reaper.TrackFX_GetParamNormalized(track, template.fx, template.param) or 0
  end
  return nil
end

local function target_templates()
  local seen = {}
  local templates = {}
  for _, snapshot in ipairs(snapshots) do
    for _, id in ipairs(snapshot.order or {}) do
      local target = snapshot.targets and snapshot.targets[id]
      if target and not seen[id] then
        seen[id] = true
        templates[#templates + 1] = target
      end
    end
  end
  return templates
end

local function count_target_set()
  return #target_templates()
end

local function selected_tracks()
  local tracks = {}
  for index = 0, reaper.CountSelectedTracks(PROJECT) - 1 do
    tracks[#tracks + 1] = reaper.GetSelectedTrack(PROJECT, index)
  end
  return tracks
end

local function focused_fx_track()
  if not reaper.GetFocusedFX then return nil, -1 end
  local retval, track_number, _, fx_number = reaper.GetFocusedFX()
  if retval ~= 1 or not fx_number or fx_number < 0 then return nil, -1 end
  local track = track_number == 0 and reaper.GetMasterTrack(PROJECT) or reaper.GetTrack(PROJECT, track_number - 1)
  return track, fx_number
end

local function capture_snapshot()
  local snapshot = {
    name = capture_name ~= "" and capture_name or ("Snapshot " .. tostring(#snapshots + 1)),
    x = cursor.x,
    y = cursor.y,
    scope = SCOPES[scope_index],
    targets = {},
    order = {},
    created = os.date("%Y-%m-%d %H:%M:%S"),
  }
  local track_count = 0
  local fx_count = 0
  local target_count = 0

  if scope_index == 1 or scope_index == 2 or scope_index == 5 then
    local tracks = selected_tracks()
    if #tracks == 0 then
      status = "Select one or more tracks first."
      return
    end
    for _, track in ipairs(tracks) do
      track_count = track_count + 1
      if scope_index == 1 or scope_index == 5 then capture_track_controls(snapshot, track) end
      if scope_index ~= 5 then
        local count = math.min(reaper.TrackFX_GetCount(track) or 0, max_fx_per_track)
        for fx = 0, count - 1 do
          fx_count = fx_count + 1
          capture_fx(snapshot, track, fx)
        end
      end
    end
  elseif scope_index == 3 then
    local track, fx = focused_fx_track()
    if not track or fx < 0 then
      status = "Focus a track FX window or touch an FX parameter first."
      return
    end
    track_count = 1
    fx_count = 1
    capture_fx(snapshot, track, fx)
  else
    local count = math.min(reaper.CountTracks(PROJECT), max_project_tracks)
    for index = 0, count - 1 do
      local track = reaper.GetTrack(PROJECT, index)
      track_count = track_count + 1
      capture_track_controls(snapshot, track)
      local fx_total = math.min(reaper.TrackFX_GetCount(track) or 0, max_fx_per_track)
      for fx = 0, fx_total - 1 do
        fx_count = fx_count + 1
        capture_fx(snapshot, track, fx)
      end
    end
  end

  for _ in pairs(snapshot.targets) do target_count = target_count + 1 end
  if target_count == 0 then
    status = "No parameters captured for this scope."
    return
  end
  snapshots[#snapshots + 1] = snapshot
  selected_snapshot = #snapshots
  capture_name = ""
  status = string.format("Captured %s: %d track(s), %d FX, %d target(s).", snapshot.name, track_count, fx_count, target_count)
  save_state()
end

local function capture_from_target_set()
  local templates = target_templates()
  if #templates == 0 then
    status = "Capture one scoped snapshot first to define the target set."
    return
  end
  local snapshot = {
    name = capture_name ~= "" and capture_name or ("Snapshot " .. tostring(#snapshots + 1)),
    x = cursor.x,
    y = cursor.y,
    scope = "Existing target set",
    targets = {},
    order = {},
    created = os.date("%Y-%m-%d %H:%M:%S"),
  }
  local skipped = 0
  for _, template in ipairs(templates) do
    local value = read_target_current_value(template)
    if value == nil then
      skipped = skipped + 1
    else
      local target = {}
      for key, item in pairs(template) do target[key] = item end
      target.value = value
      add_target(snapshot, target)
    end
  end
  if #snapshot.order == 0 then
    status = "No current values could be read from the stored target set."
    return
  end
  snapshots[#snapshots + 1] = snapshot
  selected_snapshot = #snapshots
  capture_name = ""
  if skipped > 0 then
    status = string.format("Captured %s from target set: %d target(s), %d skipped.", snapshot.name, #snapshot.order, skipped)
  else
    status = string.format("Captured %s from target set: %d target(s).", snapshot.name, #snapshot.order)
  end
  save_state()
end

local function nearest_snapshot_for(target_id)
  local best, best_d = nil, math.huge
  for _, snapshot in ipairs(snapshots) do
    if snapshot.targets and snapshot.targets[target_id] then
      local dx = cursor.x - (snapshot.x or 0.5)
      local dy = cursor.y - (snapshot.y or 0.5)
      local d = dx * dx + dy * dy
      if d < best_d then
        best = snapshot.targets[target_id]
        best_d = d
      end
    end
  end
  return best
end

local function interpolated_target(target_id)
  local sum = 0
  local weight_sum = 0
  local template = nil
  for _, snapshot in ipairs(snapshots) do
    local target = snapshot.targets and snapshot.targets[target_id]
    if target then
      template = template or target
      if target.value_type == TYPE_BOOL then return nearest_snapshot_for(target_id) end
      local dx = cursor.x - (snapshot.x or 0.5)
      local dy = cursor.y - (snapshot.y or 0.5)
      local distance = math.sqrt(dx * dx + dy * dy)
      if distance < 0.00001 then return target end
      local weight = 1 / (distance ^ interpolation_power)
      sum = sum + (tonumber(target.value) or 0) * weight
      weight_sum = weight_sum + weight
    end
  end
  if not template or weight_sum <= 0 then return nil end
  local result = {}
  for key, value in pairs(template) do result[key] = value end
  result.value = sum / weight_sum
  return result
end

local function all_target_ids()
  local seen = {}
  local ids = {}
  for _, snapshot in ipairs(snapshots) do
    for _, id in ipairs(snapshot.order or {}) do
      if not seen[id] then
        seen[id] = true
        ids[#ids + 1] = id
      end
    end
  end
  return ids
end

local function apply_target(target)
  if not target then return false end
  local track = track_by_guid(target.track_guid or "")
  if not track then return false end
  local value = tonumber(target.value) or 0
  if target.kind == "track_vol" then
    reaper.SetMediaTrackInfo_Value(track, "D_VOL", clamp(value, 0, 16))
  elseif target.kind == "track_pan" then
    reaper.SetMediaTrackInfo_Value(track, "D_PAN", clamp(value, -1, 1))
  elseif target.kind == "track_mute" then
    reaper.SetMediaTrackInfo_Value(track, "B_MUTE", value >= 0.5 and 1 or 0)
  elseif target.kind == "track_solo" then
    reaper.SetMediaTrackInfo_Value(track, "I_SOLO", value >= 0.5 and 1 or 0)
  elseif target.kind == "fx_enabled" and reaper.TrackFX_SetEnabled then
    reaper.TrackFX_SetEnabled(track, target.fx, value >= 0.5)
  elseif target.kind == "fx_param" then
    reaper.TrackFX_SetParamNormalized(track, target.fx, target.param, clamp(value, 0, 1))
  else
    return false
  end
  return true
end

local function apply_surface(make_undo)
  if #snapshots == 0 then
    status = "No snapshots to apply."
    return
  end
  local applied = 0
  if make_undo ~= false then reaper.Undo_BeginBlock() end
  reaper.PreventUIRefresh(1)
  for _, id in ipairs(all_target_ids()) do
    if apply_target(interpolated_target(id)) then applied = applied + 1 end
  end
  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  if make_undo ~= false then reaper.Undo_EndBlock("Apply Snapshot Surface", -1) end
  status = string.format("Applied %d interpolated target(s).", applied)
end

local function auto_apply_surface()
  local moved = not last_auto_apply_x
    or math.abs(cursor.x - last_auto_apply_x) > 0.002
    or math.abs(cursor.y - last_auto_apply_y) > 0.002
  if not moved then return end
  last_auto_apply_x, last_auto_apply_y = cursor.x, cursor.y
  apply_surface(false)
end

local function follow_linked_cursor_fx()
  if not follow_cursor_fx then return end
  local track, fx = linked_cursor_fx()
  if not track then return end
  local enabled = (reaper.TrackFX_GetParamNormalized(track, fx, 2) or 0) >= 0.5
  if not enabled then return end
  local x = clamp(reaper.TrackFX_GetParamNormalized(track, fx, 0) or cursor.x, 0, 1)
  local y = clamp(reaper.TrackFX_GetParamNormalized(track, fx, 1) or cursor.y, 0, 1)
  local focus_value = reaper.TrackFX_GetParam(track, fx, 3)
  if focus_value then interpolation_power = clamp(focus_value, 0.25, 8) end
  local moved = math.abs(x - cursor.x) > 0.0005 or math.abs(y - cursor.y) > 0.0005
  cursor.x, cursor.y = x, y
  if moved and auto_apply then auto_apply_surface() end
end

local function push_cursor_to_linked_fx()
  local track, fx = linked_cursor_fx()
  if not track then return end
  reaper.TrackFX_SetParamNormalized(track, fx, 0, cursor.x)
  reaper.TrackFX_SetParamNormalized(track, fx, 1, cursor.y)
  reaper.TrackFX_SetParam(track, fx, 3, interpolation_power)
end

local function delete_snapshot(index)
  if not index or not snapshots[index] then return end
  table.remove(snapshots, index)
  selected_snapshot = nil
  save_state()
end

local function clear_snapshots()
  snapshots = {}
  selected_snapshot = nil
  status = "Cleared snapshots."
  save_state()
end

local function draw_combo(label, current, names)
  if ImGui.BeginCombo(ctx, label, names[current] or "") then
    for index, name in ipairs(names) do
      local selected = index == current
      if ImGui.Selectable(ctx, name, selected) then current = index end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return current
end

local function cell_color(index, alpha_scale)
  local hue = ((index - 1) * 0.137) % 1
  local r, g, b = hsv_to_rgb(hue, 0.58, 0.42)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, alpha_scale or 0.34)
end

local function clip_polygon_to_halfplane(poly, px, py, qx, qy)
  if #poly == 0 then return poly end
  local a = 2 * (qx - px)
  local b = 2 * (qy - py)
  local c = qx * qx + qy * qy - px * px - py * py
  local function inside(point)
    return a * point.x + b * point.y <= c + 0.0001
  end
  local function intersect(p1, p2)
    local denom = a * (p2.x - p1.x) + b * (p2.y - p1.y)
    if math.abs(denom) < 0.000001 then return { x = p1.x, y = p1.y } end
    local t = (c - a * p1.x - b * p1.y) / denom
    t = clamp(t, 0, 1)
    return {
      x = p1.x + (p2.x - p1.x) * t,
      y = p1.y + (p2.y - p1.y) * t,
    }
  end
  local out = {}
  local prev = poly[#poly]
  local prev_inside = inside(prev)
  for _, current in ipairs(poly) do
    local current_inside = inside(current)
    if current_inside then
      if not prev_inside then out[#out + 1] = intersect(prev, current) end
      out[#out + 1] = current
    elseif prev_inside then
      out[#out + 1] = intersect(prev, current)
    end
    prev = current
    prev_inside = current_inside
  end
  return out
end

local function draw_polygon_fill(dl, poly, color)
  if #poly < 3 then return end
  local p0 = poly[1]
  for i = 2, #poly - 1 do
    ImGui.DrawList_AddTriangleFilled(dl, p0.x, p0.y, poly[i].x, poly[i].y, poly[i + 1].x, poly[i + 1].y, color)
  end
end

local function draw_polygon_outline(dl, poly, color, thickness)
  if #poly < 2 then return end
  for i = 1, #poly do
    local a = poly[i]
    local b = poly[i == #poly and 1 or i + 1]
    ImGui.DrawList_AddLine(dl, a.x, a.y, b.x, b.y, color, thickness or 1)
  end
end

local function draw_voronoi_cells(dl, x0, y0, x1, y1)
  if not show_regions or #snapshots == 0 then return end
  local w = math.max(1, x1 - x0)
  local h = math.max(1, y1 - y0)
  local points = {}
  for index, snapshot in ipairs(snapshots) do
    points[index] = {
      x = x0 + w * (snapshot.x or 0.5),
      y = y0 + h * (snapshot.y or 0.5),
    }
  end
  for index, site in ipairs(points) do
    local poly = {
      { x = x0, y = y0 },
      { x = x1, y = y0 },
      { x = x1, y = y1 },
      { x = x0, y = y1 },
    }
    for other, other_site in ipairs(points) do
      if other ~= index then
        poly = clip_polygon_to_halfplane(poly, site.x, site.y, other_site.x, other_site.y)
        if #poly == 0 then break end
      end
    end
    if #poly >= 3 then
      draw_polygon_fill(dl, poly, cell_color(index, 0.36))
    end
  end
  for index, site in ipairs(points) do
    local poly = {
      { x = x0, y = y0 },
      { x = x1, y = y0 },
      { x = x1, y = y1 },
      { x = x0, y = y1 },
    }
    for other, other_site in ipairs(points) do
      if other ~= index then
        poly = clip_polygon_to_halfplane(poly, site.x, site.y, other_site.x, other_site.y)
        if #poly == 0 then break end
      end
    end
    if #poly >= 3 then
      draw_polygon_outline(dl, poly, COLORS.region_edge, 1.5)
    end
  end
end

local function draw_surface(width, height)
  ImGui.InvisibleButton(ctx, "##snapshot_surface", width, height)
  local x0, y0 = ImGui.GetItemRectMin(ctx)
  local x1, y1 = ImGui.GetItemRectMax(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(dl, x0, y0, x1, y1, COLORS.bg)
  draw_voronoi_cells(dl, x0, y0, x1, y1)
  ImGui.DrawList_AddRect(dl, x0, y0, x1, y1, COLORS.edge, 0, 0, 1.4)
  for i = 1, 7 do
    local gx = x0 + (x1 - x0) * i / 8
    local gy = y0 + (y1 - y0) * i / 8
    ImGui.DrawList_AddLine(dl, gx, y0, gx, y1, COLORS.grid, 1)
    ImGui.DrawList_AddLine(dl, x0, gy, x1, gy, COLORS.grid, 1)
  end

  local mx, my = ImGui.GetMousePos(ctx)
  local surface_hovered = ImGui.IsItemHovered(ctx)
  local surface_w = math.max(1, x1 - x0)
  local surface_h = math.max(1, y1 - y0)

  if surface_hovered and ImGui.IsMouseClicked(ctx, 0) then
    local best, best_d = nil, 999999
    for index, snapshot in ipairs(snapshots) do
      local sx = x0 + surface_w * (snapshot.x or 0.5)
      local sy = y0 + surface_h * (snapshot.y or 0.5)
      local d = (mx - sx) * (mx - sx) + (my - sy) * (my - sy)
      if d < best_d then best, best_d = index, d end
    end
    if best and best_d < 625 then
      dragging_snapshot = best
      selected_snapshot = best
      snapshot_drag_dx = (snapshots[best].x or 0.5) - clamp((mx - x0) / surface_w, 0, 1)
      snapshot_drag_dy = (snapshots[best].y or 0.5) - clamp((my - y0) / surface_h, 0, 1)
      snapshot_position_dirty = true
    else
      dragging_snapshot = nil
    end
  end

  if dragging_snapshot and snapshots[dragging_snapshot] and ImGui.IsMouseDown(ctx, 0) then
    local snapshot = snapshots[dragging_snapshot]
    snapshot.x = clamp((mx - x0) / surface_w + snapshot_drag_dx, 0, 1)
    snapshot.y = clamp((my - y0) / surface_h + snapshot_drag_dy, 0, 1)
    snapshot_position_dirty = true
  elseif surface_hovered and ImGui.IsMouseDown(ctx, 0) then
    cursor.x = clamp((mx - x0) / surface_w, 0, 1)
    cursor.y = clamp((my - y0) / surface_h, 0, 1)
    push_cursor_to_linked_fx()
    if auto_apply then auto_apply_surface() end
  end

  if ImGui.IsMouseReleased(ctx, 0) then
    if snapshot_position_dirty then
      save_state()
      status = "Moved snapshot region."
    end
    dragging_snapshot = nil
    snapshot_position_dirty = false
  end

  for index, snapshot in ipairs(snapshots) do
    local sx = x0 + surface_w * (snapshot.x or 0.5)
    local sy = y0 + surface_h * (snapshot.y or 0.5)
    local dx = sx - (x0 + surface_w * cursor.x)
    local dy = sy - (y0 + surface_h * cursor.y)
    local distance = math.sqrt(dx * dx + dy * dy)
    local radius = clamp(42 / math.max(0.25, distance / 42 + 0.25), 8, 42)
    ImGui.DrawList_AddCircleFilled(dl, sx, sy, radius * 1.9, cell_color(index, 0.16), 32)
    ImGui.DrawList_AddCircleFilled(dl, sx, sy, radius, cell_color(index, 0.30), 32)
    local size = index == selected_snapshot and 12 or 9
    ImGui.DrawList_AddCircleFilled(dl, sx, sy, size, cell_color(index, 0.95), 24)
    ImGui.DrawList_AddCircle(dl, sx, sy, size, index == selected_snapshot and COLORS.node_sel or COLORS.edge, 24, index == selected_snapshot and 2 or 1)
    ImGui.DrawList_AddText(dl, sx + size + 5, sy - 7, COLORS.node_sel, snapshot.name or tostring(index))
  end

  local cx = x0 + surface_w * cursor.x
  local cy = y0 + surface_h * cursor.y
  ImGui.DrawList_AddLine(dl, cx - 13, cy, cx + 13, cy, COLORS.cursor, 2)
  ImGui.DrawList_AddLine(dl, cx, cy - 13, cx, cy + 13, COLORS.cursor, 2)
  ImGui.DrawList_AddRect(dl, cx - 5, cy - 5, cx + 5, cy + 5, COLORS.cursor, 0, 0, 1.5)

  if surface_hovered and ImGui.IsMouseClicked(ctx, 1) then
    local best, best_d = nil, 999999
    for index, snapshot in ipairs(snapshots) do
      local sx = x0 + surface_w * (snapshot.x or 0.5)
      local sy = y0 + surface_h * (snapshot.y or 0.5)
      local d = (mx - sx) * (mx - sx) + (my - sy) * (my - sy)
      if d < best_d then best, best_d = index, d end
    end
    if best and best_d < 625 then
      selected_snapshot = best
      cursor.x = snapshots[best].x or cursor.x
      cursor.y = snapshots[best].y or cursor.y
      push_cursor_to_linked_fx()
      if auto_apply then auto_apply_surface() end
    end
  end
end

local function draw_snapshot_list()
  local list_visible = ImGui.BeginChild(ctx, "##snapshot_list", 0, 0)
  if list_visible then
    for index, snapshot in ipairs(snapshots) do
      local label = string.format("%02d  %s  (%d targets)", index, snapshot.name or "Snapshot", #(snapshot.order or {}))
      if ImGui.Selectable(ctx, label, selected_snapshot == index) then
        selected_snapshot = index
        cursor.x = snapshot.x or cursor.x
        cursor.y = snapshot.y or cursor.y
        push_cursor_to_linked_fx()
      end
    end
  end
  ImGui.EndChild(ctx)
end

local function draw_toolbox(height)
  local side_visible = ImGui.BeginChild(ctx, "##snapshot_surface_side", 330, height)
  if side_visible then
    scope_index = draw_combo("Capture scope", scope_index, SCOPES)
    _, capture_name = ImGui.InputText(ctx, "Name", capture_name)
    if ImGui.Button(ctx, "Capture From Scope", 160, 28) then capture_snapshot() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Apply", 70, 28) then apply_surface() end
    if ImGui.Button(ctx, "Capture From Target Set", 230, 28) then capture_from_target_set() end
    _, auto_apply = ImGui.Checkbox(ctx, "Apply while dragging cursor", auto_apply)
    _, show_regions = ImGui.Checkbox(ctx, "Show surface regions", show_regions)
    _, include_fx_enabled = ImGui.Checkbox(ctx, "Capture FX enabled state", include_fx_enabled)
    local focus_changed
    focus_changed, interpolation_power = ImGui.SliderDouble(ctx, "Interpolation focus", interpolation_power, 0.25, 8.0, "%.2f")
    if focus_changed then push_cursor_to_linked_fx() end
    if ImGui.CollapsingHeader(ctx, "Cursor Automation", ImGui.TreeNodeFlags_DefaultOpen) then
      _, follow_cursor_fx = ImGui.Checkbox(ctx, "Follow cursor FX", follow_cursor_fx)
      if ImGui.Button(ctx, "Create / Link Cursor FX", 180, 26) then create_or_link_cursor_fx() end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Show / Arm X Y", 130, 26) then show_arm_cursor_envelopes() end
      ImGui.TextColored(ctx, COLORS.muted, linked_cursor_label())
    end
    ImGui.Separator(ctx)
    ImGui.Text(ctx, string.format("Cursor %.3f / %.3f", cursor.x, cursor.y))
    ImGui.TextColored(ctx, COLORS.muted, "Left-drag empty surface: move cursor")
    ImGui.TextColored(ctx, COLORS.muted, "Left-drag snapshot: move region")
    ImGui.TextColored(ctx, COLORS.muted, "Right-click snapshot: select + audition")
    ImGui.Text(ctx, string.format("Stored targets: %d", count_target_set()))
    ImGui.TextColored(ctx, COLORS.muted, "VCA and parameter-linked controls can")
    ImGui.TextColored(ctx, COLORS.muted, "be captured as normal REAPER targets.")
    ImGui.Separator(ctx)
    if ImGui.CollapsingHeader(ctx, "Project Scope Limits") then
      _, max_project_tracks = ImGui.SliderInt(ctx, "Max tracks", max_project_tracks, 1, 256)
      _, max_fx_per_track = ImGui.SliderInt(ctx, "Max FX / track", max_fx_per_track, 0, 64)
      _, max_params_per_fx = ImGui.SliderInt(ctx, "Max params / FX", max_params_per_fx, 1, 2048)
    end
    if selected_snapshot and snapshots[selected_snapshot] then
      local s = snapshots[selected_snapshot]
      ImGui.Separator(ctx)
      ImGui.Text(ctx, "Selected Snapshot")
      local renamed
      renamed, s.name = ImGui.InputText(ctx, "Snapshot name", s.name or "")
      if renamed then save_state() end
      ImGui.TextColored(ctx, COLORS.muted, s.scope or "")
      if ImGui.Button(ctx, "Move Node To Cursor", 150, 26) then
        s.x, s.y = cursor.x, cursor.y
        save_state()
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Delete", 70, 26) then delete_snapshot(selected_snapshot) end
    end
  end
  ImGui.EndChild(ctx)
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 1120, 780, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, TITLE, open)
  if visible then
    follow_linked_cursor_fx()
    local _, avail_h = ImGui.GetContentRegionAvail(ctx)
    local footer_h = 46
    local body_visible = ImGui.BeginChild(ctx, "##snapshot_surface_body", 0, math.max(500, avail_h - footer_h))
    if body_visible then
      local side_w = 330
      local body_w, body_h = ImGui.GetContentRegionAvail(ctx)
      local left_w = math.max(520, body_w - side_w - 20)
      local left_visible = ImGui.BeginChild(ctx, "##snapshot_surface_left", left_w, body_h)
      if left_visible then
        local _, left_h = ImGui.GetContentRegionAvail(ctx)
        local surface_h = math.min(460, math.max(300, left_h * 0.72))
        draw_surface(left_w, surface_h)
        ImGui.Separator(ctx)
        local _, after_surface_h = ImGui.GetContentRegionAvail(ctx)
        ImGui.BeginChild(ctx, "##snapshot_list_area", 0, math.max(80, after_surface_h - 24))
        draw_snapshot_list()
        ImGui.EndChild(ctx)
        ImGui.TextColored(ctx, COLORS.muted, status)
      end
      ImGui.EndChild(ctx)
      ImGui.SameLine(ctx)
      draw_toolbox(body_h)
    end
    ImGui.EndChild(ctx)
    if ImGui.Button(ctx, "Save", 92, 28) then save_state(); status = "Saved snapshots to project." end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Reload", 92, 28) then load_state() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Clear", 92, 28) then clear_snapshots() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Close", 92, 28) then open = false end
    ImGui.Dummy(ctx, 1, 10)
  end
  ImGui.End(ctx)
  if open then reaper.defer(loop) end
end

load_state()
reaper.defer(loop)
