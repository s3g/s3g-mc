-- @description Load Mover JSON
-- @author s3g
-- @version 0.1
-- @requires JSFX: s3g 8ch 3OA Object Encoder
-- @category Spatial Panners
-- @method Loads a s3g-mc Mover JSON file, creates bank encoder tracks and a 16-channel 3OA bus, and writes source motion automation from the exported browser composition.

local script_name = "Load Mover JSON"
local ENCODER_NAME = "JS: s3g 8ch 3OA Object Encoder"
local CHANNELS = 16
local MAX_BANKS = 8
local EXT_SECTION = "s3g-mc Mover Link"

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
      elseif e == "u" then
        local hex = self.text:sub(self.pos, self.pos + 3)
        self.pos = self.pos + 4
        out[#out + 1] = "?"
      else
        self:error("bad escape")
      end
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

local function source_param_base(source_index)
  return 2 + (source_index - 1) * 5
end

local function set_fx_param(track, fx, param, value)
  reaper.TrackFX_SetParam(track, fx, param, value)
end

local set_envelope_chunk_visibility

set_envelope_chunk_visibility = function(env, visible)
  if not env or not reaper.GetEnvelopeStateChunk or not reaper.SetEnvelopeStateChunk then return false end
  local ok, chunk = reaper.GetEnvelopeStateChunk(env, "", false)
  if not ok or chunk == "" then return false end
  local vis = visible and "1" or "0"
  local changed = false
  chunk = chunk:gsub("(\nVIS%s+)%d", function(prefix)
    changed = true
    return prefix .. vis
  end, 1)
  if not changed then
    chunk = chunk:gsub("^(VIS%s+)%d", function(prefix)
      changed = true
      return prefix .. vis
    end, 1)
  end
  if not changed then return false end
  return reaper.SetEnvelopeStateChunk(env, chunk, false)
end

local function prepare_envelope(track, fx, param, visible)
  visible = visible ~= false
  local env = reaper.GetFXEnvelope(track, fx, param, true)
  if not env then return nil end
  if reaper.SetEnvelopeInfo_Value then
    pcall(reaper.SetEnvelopeInfo_Value, env, "B_VISIBLE", visible and 1 or 0)
    pcall(reaper.SetEnvelopeInfo_Value, env, "B_ACTIVE", 1)
    pcall(reaper.SetEnvelopeInfo_Value, env, "B_ARM", visible and 1 or 0)
    pcall(reaper.SetEnvelopeInfo_Value, env, "I_TCPH", visible and 72 or 0)
  end
  set_envelope_chunk_visibility(env, visible)
  return env
end

local function write_param_points(track, fx, param, start_pos, duration, points, field, transform, visible)
  local env = prepare_envelope(track, fx, param, visible)
  if not env then return 0 end
  reaper.DeleteEnvelopePointRange(env, start_pos - 0.0001, start_pos + duration + 0.0001)
  local before_count = reaper.CountEnvelopePoints and reaper.CountEnvelopePoints(env) or 0
  local inserted = 0
  for _, point in ipairs(points or {}) do
    local t = tonumber(point.t) or 0
    local v = point[field]
    if v ~= nil then
      v = transform and transform(v) or tonumber(v)
      if v then
        local ok = reaper.InsertEnvelopePoint(env, start_pos + t * duration, v, 0, 0, false, true)
        if ok then inserted = inserted + 1 end
      end
    end
  end
  reaper.Envelope_SortPoints(env)
  if reaper.CountEnvelopePoints then
    local after_count = reaper.CountEnvelopePoints(env) or 0
    return math.max(inserted, after_count - before_count)
  end
  return inserted
end

local function create_track(name, channels, index)
  index = index or reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(index, true)
  local track = reaper.GetTrack(0, index)
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
  reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", channels)
  return track
end

local function add_encoder(track)
  local fx = reaper.TrackFX_AddByName(track, ENCODER_NAME, false, -1)
  if fx < 0 then
    fx = reaper.TrackFX_AddByName(track, "s3g 8ch 3OA Object Encoder", false, -1)
  end
  return fx
end

local function connect_to_bus(source, bus)
  local send = reaper.CreateTrackSend(source, bus)
  reaper.SetTrackSendInfo_Value(source, 0, send, "I_SRCCHAN", 0 | (CHANNELS << 10))
  reaper.SetTrackSendInfo_Value(source, 0, send, "I_DSTCHAN", 0 | (CHANNELS << 10))
  reaper.SetTrackSendInfo_Value(source, 0, send, "D_VOL", 1)
end

local function selected_time_range(default_duration)
  local start_pos, end_pos = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if end_pos > start_pos then
    local response = reaper.MB(
      "A REAPER time selection is active.\n\nUse it as the Mover automation range?\n\nYes: write inside the time selection.\nNo: ignore it and write the full Mover JSON duration from the edit cursor.\nCancel: stop.",
      script_name,
      3
    )
    if response == 6 then return start_pos, end_pos - start_pos end
    if response == 2 then return nil, nil end
  end
  return reaper.GetCursorPosition(), default_duration
end

local function write_bank(track, fx, bank, start_pos, duration)
  reaper.TrackFX_SetParam(track, fx, 0, tonumber(bank.bank) or 1)
  reaper.TrackFX_SetParam(track, fx, 1, 0)
  local written = 0
  for _, source_auto in ipairs(bank.automation or {}) do
    local source_index = tonumber(source_auto.source) or 1
    if source_index >= 1 and source_index <= 8 then
      local base = source_param_base(source_index)
      local points = source_auto.points or {}
      local enabled = source_auto.enabled ~= false and 1 or 0
      set_fx_param(track, fx, base, enabled)
      written = written + write_param_points(track, fx, base, start_pos, duration, {
        { t = 0, enabled = enabled },
        { t = 1, enabled = enabled },
      }, "enabled", nil, false)
      written = written + write_param_points(track, fx, base + 1, start_pos, duration, points, "azimuth", nil, true)
      written = written + write_param_points(track, fx, base + 2, start_pos, duration, points, "elevation", nil, true)
      written = written + write_param_points(track, fx, base + 3, start_pos, duration, points, "distance", nil, true)
      written = written + write_param_points(track, fx, base + 4, start_pos, duration, points, "gain", function(v)
        local gain = tonumber(v) or 0
        if gain <= 0 then return -60 end
        return 20 * math.log(gain, 10)
      end, false)
    end
  end
  return written
end

local function main()
  local ok, path = reaper.GetUserFileNameForRead("", "Load s3g-mc Mover JSON", ".json")
  if not ok or path == "" then return end
  local text = read_file(path)
  if not text then message("Could not read JSON file.") return end
  local data, err = decode_json(text)
  if not data then message(tostring(err)) return end
  if data.format ~= "s3g_mc_mover_v1" then
    message("This does not look like a s3g-mc Mover JSON file.")
    return
  end
  if type(data.banks) ~= "table" or #data.banks == 0 then
    message("Mover JSON does not contain any banks.")
    return
  end

  local duration = math.max(0.1, tonumber(data.duration) or 16)
  local start_pos
  start_pos, duration = selected_time_range(duration)
  if not start_pos or not duration then return end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local bank_count = math.min(#data.banks, MAX_BANKS)
  local insert_index = reaper.CountTracks(0)
  local bus = create_track("s3g-mc Mover 3OA Bus", CHANNELS, insert_index)
  reaper.SetMediaTrackInfo_Value(bus, "B_MAINSEND", 0)
  reaper.SetMediaTrackInfo_Value(bus, "I_FOLDERDEPTH", 1)

  local created = 0
  local point_count = 0
  for index = 1, bank_count do
    local bank = data.banks[index]
    local bank_id = tonumber(bank.bank) or index
    local name = bank.name or ("Bank " .. tostring(bank_id))
    local track = create_track("Mover " .. name, CHANNELS, insert_index + index)
    reaper.SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)
    local fx = add_encoder(track)
    if fx < 0 then
      reaper.PreventUIRefresh(-1)
      reaper.Undo_EndBlock(script_name, -1)
      message("Could not insert JSFX: s3g 8ch 3OA Object Encoder. Rescan JSFX or check that the effect is installed.")
      return
    end
    connect_to_bus(track, bus)
    point_count = point_count + write_bank(track, fx, bank, start_pos, duration)
    created = created + 1
  end
  if created > 0 then
    local last_child = reaper.GetTrack(0, insert_index + created)
    if last_child then reaper.SetMediaTrackInfo_Value(last_child, "I_FOLDERDEPTH", -1) end
  else
    reaper.SetMediaTrackInfo_Value(bus, "I_FOLDERDEPTH", 0)
  end
  reaper.Main_OnCommand(40297, 0) -- Track: Unselect all tracks.
  reaper.SetTrackSelected(bus, true)
  reaper.GetSet_ArrangeView2(0, true, 0, 0, start_pos, start_pos + duration)
  reaper.SetEditCurPos(start_pos, false, false)
  reaper.SetExtState(EXT_SECTION, "json_path", path, true)
  reaper.SetExtState(EXT_SECTION, "start_pos", tostring(start_pos), true)
  reaper.SetExtState(EXT_SECTION, "duration", tostring(duration), true)

  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock(script_name, -1)
  local extra = point_count == 0 and "\n\nNo automation points were found. Re-export the JSON from the current Mover browser tool." or ""
  message(string.format("Loaded %d Mover bank(s) under the 3OA bus and wrote %d automation points from %.2f to %.2f seconds. Route source audio into the Mover bank tracks, then decode the 16-channel 3OA bus.%s", created, point_count, start_pos, start_pos + duration, extra))
end

main()
