-- @description Load Automation Score JSON
-- @author s3g
-- @version 0.2
-- @requires ReaImGui
-- @category Channel Mixing / Automation
-- @method Loads Automation Score JSON and maps generic score lanes to selected track volume envelopes or FX parameter envelopes.

local script_name = "Load Automation Score JSON"

if not reaper.APIExists("ImGui_GetVersion") then
  reaper.MB("ReaImGui is required for " .. script_name .. ".", script_name, 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
local ImGui = require("imgui")("0.10")

local TARGET_TYPES = { "Track volume dB", "FX parameter", "Skip" }
local TARGET_VOLUME = 1
local TARGET_FX = 2
local TARGET_SKIP = 3

local function message(text)
  reaper.MB(text, script_name, 0)
end

local function clamp(value, lo, hi)
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

local Json = {}
Json.__index = Json

function Json.new(text)
  return setmetatable({ text = text, pos = 1, len = #text }, Json)
end

function Json:peek()
  return self.text:sub(self.pos, self.pos)
end

function Json:skip_ws()
  while self.pos <= self.len do
    local c = self:peek()
    if c ~= " " and c ~= "\n" and c ~= "\r" and c ~= "\t" then return end
    self.pos = self.pos + 1
  end
end

function Json:error(msg)
  error(string.format("JSON parse error at byte %d: %s", self.pos, msg), 0)
end

function Json:parse_string()
  if self:peek() ~= '"' then self:error("expected string") end
  self.pos = self.pos + 1
  local out = {}
  while self.pos <= self.len do
    local c = self:peek()
    self.pos = self.pos + 1
    if c == '"' then return table.concat(out) end
    if c == "\\" then
      local e = self:peek()
      self.pos = self.pos + 1
      if e == '"' or e == "\\" or e == "/" then out[#out + 1] = e
      elseif e == "b" then out[#out + 1] = "\b"
      elseif e == "f" then out[#out + 1] = "\f"
      elseif e == "n" then out[#out + 1] = "\n"
      elseif e == "r" then out[#out + 1] = "\r"
      elseif e == "t" then out[#out + 1] = "\t"
      elseif e == "u" then self.pos = self.pos + 4; out[#out + 1] = "?"
      else self:error("bad escape") end
    else
      out[#out + 1] = c
    end
  end
  self:error("unterminated string")
end

function Json:parse_number()
  local start = self.pos
  while self.pos <= self.len and self:peek():match("[%d%+%-%.eE]") do
    self.pos = self.pos + 1
  end
  local value = tonumber(self.text:sub(start, self.pos - 1))
  if value == nil then self:error("bad number") end
  return value
end

function Json:parse_array()
  self.pos = self.pos + 1
  local arr = {}
  self:skip_ws()
  if self:peek() == "]" then self.pos = self.pos + 1 return arr end
  while true do
    arr[#arr + 1] = self:parse_value()
    self:skip_ws()
    local c = self:peek()
    if c == "]" then self.pos = self.pos + 1 return arr end
    if c ~= "," then self:error("expected comma or ]") end
    self.pos = self.pos + 1
  end
end

function Json:parse_object()
  self.pos = self.pos + 1
  local obj = {}
  self:skip_ws()
  if self:peek() == "}" then self.pos = self.pos + 1 return obj end
  while true do
    self:skip_ws()
    local key = self:parse_string()
    self:skip_ws()
    if self:peek() ~= ":" then self:error("expected colon") end
    self.pos = self.pos + 1
    obj[key] = self:parse_value()
    self:skip_ws()
    local c = self:peek()
    if c == "}" then self.pos = self.pos + 1 return obj end
    if c ~= "," then self:error("expected comma or }") end
    self.pos = self.pos + 1
  end
end

function Json:parse_literal(lit, value)
  if self.text:sub(self.pos, self.pos + #lit - 1) ~= lit then self:error("bad literal") end
  self.pos = self.pos + #lit
  return value
end

function Json:parse_value()
  self:skip_ws()
  local c = self:peek()
  if c == "{" then return self:parse_object() end
  if c == "[" then return self:parse_array() end
  if c == '"' then return self:parse_string() end
  if c == "-" or c:match("%d") then return self:parse_number() end
  if c == "t" then return self:parse_literal("true", true) end
  if c == "f" then return self:parse_literal("false", false) end
  if c == "n" then return self:parse_literal("null", nil) end
  self:error("unexpected value")
end

local function decode_json(text)
  local parser = Json.new(text)
  local ok, value = pcall(function() return parser:parse_value() end)
  if not ok then return nil, value end
  return value
end

local function read_file(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local text = file:read("*a")
  file:close()
  return text
end

local function selected_tracks()
  local tracks = {}
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    local track = reaper.GetSelectedTrack(0, i)
    local _, name = reaper.GetTrackName(track)
    tracks[#tracks + 1] = { track = track, name = name ~= "" and name or ("Track " .. tostring(i + 1)) }
  end
  return tracks
end

local function ensure_track_volume_envelope(track)
  local env = reaper.GetTrackEnvelopeByName(track, "Volume")
  if env then return env end
  local selected = {}
  for i = 0, reaper.CountSelectedTracks(0) - 1 do
    selected[#selected + 1] = reaper.GetSelectedTrack(0, i)
  end
  reaper.Main_OnCommand(40297, 0)
  reaper.SetTrackSelected(track, true)
  reaper.Main_OnCommand(40406, 0)
  reaper.Main_OnCommand(40297, 0)
  for _, tr in ipairs(selected) do reaper.SetTrackSelected(tr, true) end
  return reaper.GetTrackEnvelopeByName(track, "Volume")
end

local function prepare_fx_envelope(track, fx_index, param_index)
  if not reaper.GetFXEnvelope then return nil end
  local env = reaper.GetFXEnvelope(track, fx_index, param_index, true)
  if not env then return nil end
  if reaper.SetEnvelopeInfo_Value then
    pcall(reaper.SetEnvelopeInfo_Value, env, "B_VISIBLE", 1)
    pcall(reaper.SetEnvelopeInfo_Value, env, "B_ACTIVE", 1)
    pcall(reaper.SetEnvelopeInfo_Value, env, "B_ARM", 1)
    pcall(reaper.SetEnvelopeInfo_Value, env, "I_TCPH", 72)
  end
  return env
end

local function db_to_amp(db)
  if db <= -150 then return 0 end
  return 10 ^ (db / 20)
end

local function volume_envelope_value(env, db)
  local amp = db_to_amp(db)
  if reaper.GetEnvelopeScalingMode and reaper.ScaleToEnvelopeMode then
    local mode = reaper.GetEnvelopeScalingMode(env)
    if mode and mode ~= 0 then
      return reaper.ScaleToEnvelopeMode(mode, amp)
    end
  end
  return amp
end

local function write_lane(env, lane, start_pos, duration, use_samples, transform)
  if not env then return 0 end
  reaper.DeleteEnvelopePointRange(env, start_pos - 0.0001, start_pos + duration + 0.0001)
  local points = use_samples and lane.samples or lane.points
  if not points or #points == 0 then points = lane.points end
  local inserted = 0
  for _, point in ipairs(points or {}) do
    local t = clamp(tonumber(point.t) or 0, 0, 1)
    local v = clamp(tonumber(point.v) or 0, 0, 1)
    local value = transform(v)
    if reaper.InsertEnvelopePoint(env, start_pos + t * duration, value, 0, 0, false, true) then
      inserted = inserted + 1
    end
  end
  reaper.Envelope_SortPoints(env)
  return inserted
end

local function combo(ctx, label, current, names)
  local preview = names[current] or names[1] or ""
  if ImGui.BeginCombo(ctx, label, preview) then
    for i, name in ipairs(names) do
      local selected = i == current
      if ImGui.Selectable(ctx, name, selected) then current = i end
      if selected then ImGui.SetItemDefaultFocus(ctx) end
    end
    ImGui.EndCombo(ctx)
  end
  return current
end

local function disabled_text(text)
  if ImGui.TextDisabled then
    ImGui.TextDisabled(ctx, text)
  else
    ImGui.TextColored(ctx, 0x777777FF, text)
  end
end

local function track_fx_names(track)
  local names = {}
  local count = reaper.TrackFX_GetCount(track) or 0
  for i = 0, count - 1 do
    local _, name = reaper.TrackFX_GetFXName(track, i, "")
    if name == "" then name = "FX " .. tostring(i + 1) end
    names[#names + 1] = tostring(i + 1) .. ": " .. name
  end
  if #names == 0 then names[1] = "No FX on track" end
  return names, count
end

local function fx_param_names(track, fx_index)
  local names = {}
  local count = 0
  if reaper.TrackFX_GetNumParams then
    count = reaper.TrackFX_GetNumParams(track, fx_index) or 0
  end
  for i = 0, count - 1 do
    local _, name = reaper.TrackFX_GetParamName(track, fx_index, i, "")
    if name == "" then name = "Param " .. tostring(i + 1) end
    names[#names + 1] = tostring(i + 1) .. ": " .. name
  end
  if #names == 0 then names[1] = "No automatable parameters" end
  return names, count
end

local ok, path = reaper.GetUserFileNameForRead("", "Load s3g-mc Automation Score JSON", ".json")
if not ok or path == "" then return end

local text = read_file(path)
if not text then message("Could not read JSON file.") return end

local data, err = decode_json(text)
if not data then message(err) return end
if data.format ~= "s3g-mc-automation-score" and data.format ~= "s3g-mc-automation-field" then
  message("This does not look like an Automation Score JSON file.")
  return
end

local lanes = {}
for _, lane in ipairs(data.lanes or {}) do
  if lane.enabled ~= false then lanes[#lanes + 1] = lane end
end
if #lanes == 0 then message("No enabled lanes found in the JSON file.") return end

local tracks = selected_tracks()
if #tracks == 0 then message("Select one or more target tracks before loading the JSON.") return end

local track_names = {}
for i, info in ipairs(tracks) do track_names[i] = tostring(i) .. ": " .. info.name end

local start_pos = reaper.GetCursorPosition()
local duration = tonumber(data.duration) or 16
local use_samples = true
local write_requested = false
local status = "Ready. Assign each score lane to a track volume envelope, FX parameter, or Skip."
local open = true
local ctx = ImGui.CreateContext(script_name)

local assignments = {}
for i, lane in ipairs(lanes) do
  assignments[i] = {
    target = TARGET_VOLUME,
    track_index = ((i - 1) % #tracks) + 1,
    fx_index = 1,
    param_index = i,
    min_db = -48.0,
    max_db = 0.0,
    min_value = 0.0,
    max_value = 1.0,
    lane_name = tostring(lane.name or ("Lane " .. tostring(i))),
  }
end

local function refresh_tracks()
  local next_tracks = selected_tracks()
  if #next_tracks == 0 then
    status = "No selected tracks. Select target tracks in REAPER, then Refresh Tracks."
    return
  end
  tracks = next_tracks
  track_names = {}
  for i, info in ipairs(tracks) do track_names[i] = tostring(i) .. ": " .. info.name end
  for _, a in ipairs(assignments) do
    a.track_index = clamp(a.track_index or 1, 1, #tracks)
  end
  status = "Refreshed selected tracks."
end

local function assign_volume_cycle()
  for i, a in ipairs(assignments) do
    a.target = TARGET_VOLUME
    a.track_index = ((i - 1) % #tracks) + 1
    a.min_db = -48.0
    a.max_db = 0.0
  end
end

local function assign_fx_sequential()
  for i, a in ipairs(assignments) do
    a.target = TARGET_FX
    a.track_index = 1
    a.fx_index = 1
    a.param_index = i
    a.min_value = 0.0
    a.max_value = 1.0
  end
end

local function write_automation()
  if #tracks == 0 then return false, "No selected target tracks." end
  local total = 0
  local skipped = 0
  reaper.Undo_BeginBlock()
  for i, lane in ipairs(lanes) do
    local a = assignments[i]
    if not a or a.target == TARGET_SKIP then
      skipped = skipped + 1
    else
      local track_info = tracks[clamp(a.track_index or 1, 1, #tracks)]
      if not track_info then
        skipped = skipped + 1
      elseif a.target == TARGET_VOLUME then
        local env = ensure_track_volume_envelope(track_info.track)
        local min_db = tonumber(a.min_db) or -48
        local max_db = tonumber(a.max_db) or 0
        total = total + write_lane(env, lane, start_pos, duration, use_samples, function(v)
          local db = min_db + v * (max_db - min_db)
          return volume_envelope_value(env, db)
        end)
      elseif a.target == TARGET_FX then
        local fx_names, fx_count = track_fx_names(track_info.track)
        local fx_index = math.max(0, math.min(fx_count - 1, (tonumber(a.fx_index) or 1) - 1))
        local _, param_count = fx_param_names(track_info.track, fx_index)
        if fx_count == 0 or param_count == 0 then
          skipped = skipped + 1
        else
          local param_index = math.max(0, math.min(param_count - 1, (tonumber(a.param_index) or 1) - 1))
          local env = prepare_fx_envelope(track_info.track, fx_index, param_index)
        local min_value = tonumber(a.min_value) or 0
        local max_value = tonumber(a.max_value) or 1
        total = total + write_lane(env, lane, start_pos, duration, use_samples, function(v)
          return min_value + v * (max_value - min_value)
        end)
        end
      end
    end
  end
  reaper.UpdateArrange()
  reaper.Undo_EndBlock(script_name, -1)
  return true, string.format("Wrote %d automation points from %.2f to %.2f seconds. Skipped %d lane(s).", total, start_pos, start_pos + duration, skipped)
end

local function draw_assignment_row(i, lane, a)
  ImGui.PushID(ctx, i)
  ImGui.TableNextRow(ctx)
  ImGui.TableSetColumnIndex(ctx, 0)
  ImGui.Text(ctx, tostring(i))
  ImGui.TableSetColumnIndex(ctx, 1)
  ImGui.Text(ctx, a.lane_name)
  ImGui.TableSetColumnIndex(ctx, 2)
  ImGui.SetNextItemWidth(ctx, 150)
  a.target = combo(ctx, "##target", a.target, TARGET_TYPES)
  ImGui.TableSetColumnIndex(ctx, 3)
  ImGui.SetNextItemWidth(ctx, 170)
  a.track_index = combo(ctx, "##track", clamp(a.track_index or 1, 1, #tracks), track_names)
  ImGui.TableSetColumnIndex(ctx, 4)
  if a.target == TARGET_FX then
    local track_info = tracks[clamp(a.track_index or 1, 1, #tracks)]
    local fx_names, fx_count = track_fx_names(track_info.track)
    a.fx_index = clamp(a.fx_index or 1, 1, math.max(1, fx_count))
    ImGui.SetNextItemWidth(ctx, 170)
    a.fx_index = combo(ctx, "##fx", a.fx_index, fx_names)
    if fx_count > 0 then
      local param_names, param_count = fx_param_names(track_info.track, a.fx_index - 1)
      a.param_index = clamp(a.param_index or 1, 1, math.max(1, param_count))
      ImGui.SetNextItemWidth(ctx, 170)
      a.param_index = combo(ctx, "##param", a.param_index, param_names)
    else
      disabled_text("Select a track with FX.")
    end
  else
    disabled_text("-")
  end
  ImGui.TableSetColumnIndex(ctx, 5)
  if a.target == TARGET_VOLUME then
    ImGui.SetNextItemWidth(ctx, 72)
    local changed, value = ImGui.InputDouble(ctx, "Min dB##mindb", a.min_db or -48, 1, 6, "%.1f")
    if changed then a.min_db = value end
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 72)
    changed, value = ImGui.InputDouble(ctx, "Max dB##maxdb", a.max_db or 0, 1, 6, "%.1f")
    if changed then a.max_db = value end
  elseif a.target == TARGET_FX then
    ImGui.SetNextItemWidth(ctx, 72)
    local changed, value = ImGui.InputDouble(ctx, "Min##minv", a.min_value or 0, 0.01, 0.1, "%.3f")
    if changed then a.min_value = value end
    ImGui.SameLine(ctx)
    ImGui.SetNextItemWidth(ctx, 72)
    changed, value = ImGui.InputDouble(ctx, "Max##maxv", a.max_value or 1, 0.01, 0.1, "%.3f")
    if changed then a.max_value = value end
  else
    disabled_text("-")
  end
  ImGui.PopID(ctx)
end

local function loop()
  ImGui.SetNextWindowSize(ctx, 1120, 760, ImGui.Cond_Appearing)
  local visible
  visible, open = ImGui.Begin(ctx, script_name, open)
  if visible then
    ImGui.Text(ctx, "JSON: " .. (path:match("[^/\\]+$") or path))
    ImGui.Text(ctx, string.format("Enabled lanes: %d | Duration: %.2f sec | Selected target tracks: %d", #lanes, duration, #tracks))
    ImGui.Separator(ctx)

    local changed
    changed, start_pos = ImGui.InputDouble(ctx, "Start time", start_pos, 0.1, 1.0, "%.3f")
    changed, duration = ImGui.InputDouble(ctx, "Duration", duration, 1.0, 10.0, "%.3f")
    duration = math.max(0.001, duration)
    changed, use_samples = ImGui.Checkbox(ctx, "Use sampled points from JSON", use_samples)

    if ImGui.Button(ctx, "Refresh Tracks", 118, 24) then refresh_tracks() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Auto Volume Across Tracks", 180, 24) then assign_volume_cycle() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Auto FX Sequential", 150, 24) then assign_fx_sequential() end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Skip All", 80, 24) then
      for _, a in ipairs(assignments) do a.target = TARGET_SKIP end
    end

    ImGui.Separator(ctx)
    local footer_height = 96
    local child_flags = ImGui.ChildFlags_Borders or 1
    if ImGui.BeginChild(ctx, "assignment_scroll", 0, -footer_height, child_flags) then
      if ImGui.BeginTable(ctx, "automation_score_assignments", 6, ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg | ImGui.TableFlags_SizingStretchProp) then
        ImGui.TableSetupColumn(ctx, "#", ImGui.TableColumnFlags_WidthFixed, 28)
        ImGui.TableSetupColumn(ctx, "Lane")
        ImGui.TableSetupColumn(ctx, "Target", ImGui.TableColumnFlags_WidthFixed, 160)
        ImGui.TableSetupColumn(ctx, "Track", ImGui.TableColumnFlags_WidthFixed, 190)
        ImGui.TableSetupColumn(ctx, "FX / Parameter", ImGui.TableColumnFlags_WidthFixed, 190)
        ImGui.TableSetupColumn(ctx, "Range", ImGui.TableColumnFlags_WidthFixed, 190)
        ImGui.TableHeadersRow(ctx)
        for i, lane in ipairs(lanes) do
          draw_assignment_row(i, lane, assignments[i])
        end
        ImGui.EndTable(ctx)
      end
    end
    ImGui.EndChild(ctx)

    ImGui.Separator(ctx)
    ImGui.TextWrapped(ctx, "Track volume lanes use dB scaling before writing REAPER envelope values. FX parameter lanes write normalized parameter values.")
    ImGui.TextColored(ctx, 0xBBBBBBFF, status)
    if ImGui.Button(ctx, "Write Automation", 150, 30) then write_requested = true end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Cancel", 100, 30) then open = false end
    ImGui.End(ctx)
  end

  if write_requested then
    write_requested = false
    local ok_write, write_status = write_automation()
    status = write_status
    if ok_write then
      message(write_status)
      open = false
      return
    end
  end

  if open then reaper.defer(loop) end
end

loop()
