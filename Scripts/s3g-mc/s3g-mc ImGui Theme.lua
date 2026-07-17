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
  local p = {
    bg = color(ImGui, 0.047, 0.047, 0.047, 1.0),       -- #0c0c0c
    bg_alt = color(ImGui, 0.074, 0.074, 0.074, 1.0),   -- #131313
    panel = color(ImGui, 0.113, 0.113, 0.113, 1.0),    -- #1d1d1d
    panel_soft = color(ImGui, 0.145, 0.145, 0.145, 1.0),
    frame = color(ImGui, 0.074, 0.074, 0.074, 1.0),
    frame_hover = color(ImGui, 0.074, 0.074, 0.074, 1.0),
    frame_active = color(ImGui, 0.195, 0.195, 0.195, 1.0),
    title = color(ImGui, 0.047, 0.047, 0.047, 1.0),
    title_active = color(ImGui, 0.074, 0.074, 0.074, 1.0),
    title_collapsed = color(ImGui, 0.047, 0.047, 0.047, 1.0),
    edge = color(ImGui, 0.337, 0.337, 0.337, 1.0),     -- #565656
    edge_soft = color(ImGui, 0.230, 0.230, 0.230, 1.0),
    text = color(ImGui, 0.788, 0.788, 0.788, 1.0),     -- #c9c9c9
    label = color(ImGui, 0.659, 0.659, 0.659, 1.0),    -- #a8a8a8
    value = color(ImGui, 0.572, 0.572, 0.572, 1.0),    -- #929292
    muted = color(ImGui, 0.560, 0.560, 0.560, 1.0),    -- #8f8f8f
    disabled = color(ImGui, 0.360, 0.360, 0.360, 1.0),
    active = color(ImGui, 0.720, 0.720, 0.720, 1.0),   -- #b8b8b8
    active_hover = color(ImGui, 0.790, 0.790, 0.790, 1.0),
    fill = color(ImGui, 0.498, 0.498, 0.498, 1.0),     -- #7f7f7f
    ok = color(ImGui, 0.340, 0.710, 0.520, 1.0),
    warn = color(ImGui, 0.940, 0.500, 0.340, 1.0),
    amber = color(ImGui, 0.880, 0.700, 0.360, 1.0),
    clear = color(ImGui, 0.0, 0.0, 0.0, 0.0),
  }

  -- Compatibility aliases used by older s3g-mc scripts. New scripts should
  -- prefer the semantic names above, but these keep local canvases on the same
  -- grayscale base without requiring a risky repo-wide rewrite.
  p.strip = p.bg_alt
  p.cellBg = p.panel
  p.grid = p.edge
  p.dim = p.muted
  p.button = color(ImGui, 0.045, 0.045, 0.045, 1.0)
  p.button_hover = color(ImGui, 0.064, 0.064, 0.064, 1.0)
  p.button_active = color(ImGui, 0.102, 0.102, 0.102, 1.0)
  p.selected = p.active
  p.selection = color(ImGui, 0.720, 0.720, 0.720, 0.22)
  p.send = color(ImGui, 0.620, 0.690, 0.720, 0.70)
  p.receive = color(ImGui, 0.580, 0.620, 0.660, 0.55)
  p.folder = color(ImGui, 0.880, 0.700, 0.360, 0.82)
  p.master = color(ImGui, 0.500, 0.640, 0.560, 0.72)
  return p
end

local function push_style_color(ImGui, ctx, name, value)
  local ok, key = pcall(function() return ImGui["Col_" .. name] end)
  if not ok then return 0 end
  if key then
    local pushed = pcall(ImGui.PushStyleColor, ctx, key, value)
    return pushed and 1 or 0
  end
  return 0
end

local function push_style_var(ImGui, ctx, name, ...)
  local ok, key = pcall(function() return ImGui["StyleVar_" .. name] end)
  if not ok then return 0 end
  if key then
    local pushed = pcall(ImGui.PushStyleVar, ctx, key, ...)
    return pushed and 1 or 0
  end
  return 0
end


function M.text(ImGui, ctx, value)
  ImGui.TextColored(ctx, M.palette(ImGui).label, value)
end

function M.muted(ImGui, ctx, value)
  ImGui.TextColored(ctx, M.palette(ImGui).muted, value)
end

function M.value(ImGui, ctx, value)
  ImGui.TextColored(ctx, M.palette(ImGui).value, value)
end

function M.status(ImGui, ctx, value, color_name)
  local p = M.palette(ImGui)
  ImGui.TextColored(ctx, p[color_name or "value"] or p.value, value)
end

function M.wrapped_text(ImGui, ctx, value, color_value, width)
  value = tostring(value or "")
  if value == "" then return end
  ImGui.PushStyleColor(ctx, ImGui.Col_Text, color_value or M.palette(ImGui).label)
  ImGui.PushTextWrapPos(ctx, ImGui.GetCursorScreenPos(ctx) + (width or 260))
  ImGui.TextWrapped(ctx, value)
  ImGui.PopTextWrapPos(ctx)
  ImGui.PopStyleColor(ctx)
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local SLIDER_ABBR = {
  ["TIMELINE PREVIEW"] = "TIME",
  ["PREVIEW SPEED"] = "SPEED",
  ["LOOP SECONDS"] = "LOOP",
  ["MIDI LANES"] = "MIDI",
  ["EVENT RATE"] = "RATE",
  ["FLOOR DB"] = "FLOOR",
  ["MIN HZ"] = "MIN",
  ["MAX HZ"] = "MAX",
  ["MIN BEATS"] = "MIN",
  ["MAX BEATS"] = "MAX",
  ["BAR BEATS"] = "BAR",
  ["PITCH SPAN"] = "PITCH",
  ["CH MOTION"] = "CH",
  ["NLEN VAR"] = "NVAR",
  ["SELECTED SOURCE"] = "SRC",
  ["LAYOUT FOCUS"] = "FOCUS",
  ["DISTANCE ROLLOFF"] = "ROLLOFF",
  ["DISTANCE DIFFUSION"] = "DIFF",
  ["MOTION SMOOTHING"] = "SMOOTH",
  ["GLOBAL AZIMUTH"] = "G AZ",
  ["GLOBAL ELEVATION"] = "G EL",
  ["GLOBAL DISTANCE OFFSET"] = "G DIST",
  ["OUTPUT GAIN"] = "OUT",
  ["SPHERE FOCUS"] = "FOCUS",
  ["COSINE FOCUS"] = "FOCUS",
  ["DBAP FOCUS"] = "FOCUS",
  ["FOCUS AMOUNT"] = "FOCUS",
  ["VECTOR SHARPNESS"] = "SHARP",
  ["LBAP SHARPNESS"] = "SHARP",
  ["VBAP SHARPNESS"] = "SHARP",
  ["REGION SHARPNESS"] = "SHARP",
  ["LBAP WIDTH"] = "WIDTH",
  ["DBAP ROLLOFF"] = "ROLLOFF",
  ["REGION BLEND"] = "BLEND",
  ["REGION WIDTH"] = "WIDTH",
  ["SNAPSHOT MORPH"] = "MORPH",
  ["XYZ SPREAD RADIUS"] = "SPREAD",
  ["GLOBAL X OFFSET"] = "G X",
  ["GLOBAL Y OFFSET"] = "G Y",
  ["GLOBAL Z OFFSET"] = "G Z",
  ["PATH METHOD"] = "METHOD",
  ["SOURCE RELATIONSHIP"] = "RELATE",
  ["POINT RATE"] = "RATE",
  ["SOURCE PHASE SPREAD"] = "PHASE",
  ["CANON DELAY"] = "DELAY",
  ["DURATION"] = "DUR",
  ["CONTINUITY"] = "CONT",
  ["CYCLES"] = "CYC",
  ["GRAPH NODES"] = "NODES",
  ["GRAPH MEMORY"] = "MEM",
  ["PATH CORNERS"] = "CORNERS",
  ["HOLE RADIUS"] = "HOLE",
  ["HOLE REPULSION"] = "REPEL",
  ["BOUNDARY FORCE"] = "FORCE",
  ["XYZ RADIUS"] = "RADIUS",
  ["AZIMUTH CENTER"] = "AZ CTR",
  ["AZIMUTH RANGE"] = "AZ RNG",
  ["ELEVATION CENTER"] = "EL CTR",
  ["ELEVATION RANGE"] = "EL RNG",
  ["DISTANCE CENTER"] = "D CTR",
  ["DISTANCE RANGE"] = "D RNG",
  ["TEAR / JUMP CHANCE"] = "TEAR",
  ["VISIBLE CHANNELS"] = "VISIBLE",
  ["INPUT CHANNELS"] = "INPUT",
  ["SOURCE CHANNELS"] = "SRC CH",
  ["OUTPUT CHANNELS"] = "OUT CH",
  ["MATRIX FIRST CHANNEL"] = "MATRIX",
  ["INPUT START CHANNEL"] = "IN CH",
  ["SOURCE START"] = "SRC ST",
  ["SOURCE COUNT"] = "SRC CT",
  ["DEST START"] = "DST ST",
  ["DEST COUNT"] = "DST CT",
  ["CHANNEL ROTATE"] = "ROTATE",
  ["NODE COUNT"] = "NODES",
  ["CURSOR INFLUENCE"] = "INFL",
  ["STACK POSITION"] = "STACK",
  ["CURSOR RADIUS"] = "RADIUS",
  ["GLOBAL RADIUS"] = "RADIUS",
  ["CURSOR FOCUS"] = "FOCUS",
  ["GLOBAL FOCUS"] = "FOCUS",
  ["CURSOR GATE"] = "GATE",
  ["SPREAD / WIDTH"] = "WIDTH",
  ["LAYOUT WEIGHTING"] = "WEIGHT",
  ["3D ATTENUATION"] = "3D ATT",
  ["AMBISONIC ORDER"] = "ORDER",
  ["BASS MONO BELOW HZ"] = "BASS",
  ["EVENT DENSITY"] = "DENS",
  ["EVENTS"] = "EVENTS",
  ["FREEZE/TRACE AMOUNT"] = "AMOUNT",
  ["GHOST SMOOTHING BINS"] = "GHOST",
  ["HIGHER-ORDER WEIGHT"] = "HOA",
  ["MAX SEGMENT MS"] = "MAX",
  ["MIN SEGMENT MS"] = "MIN",
  ["MODE"] = "MODE",
  ["OUTPUT DURATION SEC"] = "DUR",
  ["OVERLAP BUILD"] = "OVERLAP",
  ["SOURCE FORMAT"] = "FORMAT",
  ["SOURCE OBJECT SPREAD"] = "SPREAD",
  ["SPATIAL OCCUPATION"] = "OCCUPY",
  ["STEREO SUM/DIFFERENCE EXPANSION"] = "STEREO",
  ["SOFT LIMIT BEFORE NORMALIZE"] = "LIMIT",
  ["TRACE WIDTH"] = "TRACE",
  ["W WEIGHT"] = "W",
  ["YAW END DEG"] = "YAW E",
  ["YAW START DEG"] = "YAW S",
  ["CENTER AMOUNT"] = "CENTER",
  ["DC PROTECT"] = "DC",
  ["DIRECTIONAL COHERENCE"] = "COHER",
  ["EXPANSION MODE"] = "MODE",
  ["FIELD SMOOTHING"] = "FIELD",
  ["FFT OVERLAP"] = "OVERLAP",
  ["FREQUENCY SMOOTHING BINS"] = "FREQ",
  ["FRONT WEIGHT"] = "FRONT",
  ["HEIGHT AMOUNT"] = "HEIGHT",
  ["OBJECT / FIELD CROSSFADE"] = "XFADE",
  ["OBJECT BIAS"] = "OBJECT",
  ["OUTPUT ORDER"] = "ORDER",
  ["OUTPUT"] = "OUTPUT",
  ["REAR AMOUNT"] = "REAR",
  ["SOURCE SPREAD"] = "SPREAD",
  ["SPECTRAL CONTRAST"] = "CONTRAST",
  ["STEREO WIDTH"] = "WIDTH",
  ["SIDE AMOUNT"] = "SIDE",
  ["TEMPORAL SMOOTHING"] = "TEMP",
  ["TRANSIENT WEIGHT"] = "TRANS",
  ["AED TRAJECTORY"] = "AED",
  ["SOURCE CHANNEL MODE"] = "SRC",
  ["TRIGGER DENSITY"] = "DENS",
  ["TRIGGER CHANCE"] = "CHANCE",
  ["VOICE ROTATION"] = "VOICE",
  ["GRAIN DURATION MS"] = "GRAIN",
  ["MINIMUM GRAIN MS"] = "MIN",
  ["DURATION VARIATION"] = "VAR",
  ["SOURCE SPRAY MS"] = "SPRAY",
  ["SOURCE POSITION"] = "SRC POS",
  ["POSITION QUANTIZE"] = "QUANT",
  ["TRANSPOSE SEMITONES"] = "TRANS",
  ["PITCH SPREAD SEMITONES"] = "PITCH",
  ["REVERSE CHANCE"] = "REV",
  ["WINDOW MORPH"] = "WINDOW",
  ["RATE DRIFT"] = "DRIFT",
  ["AZIMUTH WIDTH"] = "AZ W",
  ["ELEVATION WIDTH"] = "EL W",
  ["DISTANCE MOTION"] = "D MOT",
  ["TRIM"] = "TRIM",
  ["PRE-GAIN DB"] = "GAIN",
  ["PEAK NORMALIZE"] = "PK NORM",
  ["NORMALIZE DB"] = "NORM",
  ["SEED"] = "SEED",
  ["PULSAR STREAMS"] = "STREAMS",
  ["TRAIN CURVE"] = "CURVE",
  ["PULSE MASK"] = "MASK",
  ["FUNDAMENTAL START HZ"] = "FUND S",
  ["FUNDAMENTAL END HZ"] = "FUND E",
  ["FORMANT START HZ"] = "FORM S",
  ["FORMANT END HZ"] = "FORM E",
  ["FORMANT SCATTER"] = "SCATTER",
  ["TRAIN DRIFT"] = "DRIFT",
  ["PULSARET"] = "PULSE",
  ["PULSARET ENVELOPE"] = "ENV",
  ["EDGE / CUTOFF SOFTNESS"] = "EDGE",
  ["STOCHASTIC PROBABILITY"] = "PROB",
  ["BURST ON"] = "ON",
  ["BURST OFF"] = "OFF",
  ["AZIMUTH START DEG"] = "AZ S",
  ["AZIMUTH END DEG"] = "AZ E",
  ["ELEVATION DEG"] = "EL",
  ["STREAM SPATIAL SPREAD"] = "SPREAD",
  ["PER-PULSE CHANNEL MASK"] = "MASK",
  ["SOURCE POOL"] = "POOL",
  ["NON-AMBISONIC SOURCE SPREAD"] = "SPREAD",
  ["GRAIN RATE"] = "RATE",
  ["STREAMS"] = "STREAMS",
  ["ASYNCHRONICITY"] = "ASYNC",
  ["INTERMITTENCY"] = "INTER",
  ["DURATION JITTER"] = "JITTER",
  ["ENVELOPE SHAPE"] = "ENV",
  ["PLAYBACK RATE"] = "RATE",
  ["PLAYBACK JITTER OCT"] = "JITTER",
  ["SCAN BEGIN"] = "SCAN S",
  ["SCAN RANGE"] = "RANGE",
  ["SCAN SPEED"] = "SPEED",
  ["PER-GRAIN YAW SCATTER"] = "SCATTER",
  ["HIGHER-ORDER BLUR"] = "BLUR",
  ["PROFILE STATISTIC"] = "PROFILE",
  ["REDUCTION AMOUNT"] = "AMOUNT",
  ["CARVE AMOUNT"] = "CARVE",
  ["MATCH AMOUNT"] = "MATCH",
  ["EXTRACTION AMOUNT"] = "EXTRACT",
  ["SPECTRAL FLOOR"] = "FLOOR",
  ["HOLE FLOOR"] = "FLOOR",
  ["SOURCE FLOOR"] = "FLOOR",
  ["LOW-BIN PROTECTION"] = "PROTECT",
  ["PROFILE SENSITIVITY"] = "SENSE",
  ["CARVE SENSITIVITY"] = "SENSE",
  ["REFERENCE SENSITIVITY"] = "SENSE",
  ["AMBIANCE SENSITIVITY"] = "SENSE",
  ["FREQUENCY SMOOTHING BINS"] = "FREQ",
  ["FFT SIZE"] = "FFT",
  ["OVERLAP"] = "OVERLAP",
  ["PEAK NORMALIZE OUTPUT"] = "PK NORM",
  ["NORMALIZE PEAK DB"] = "NORM",
  ["ADAPT MIXED-ORDER KERNELS"] = "ADAPT",
  ["MAX KERNEL WINDOW SEC"] = "WINDOW",
  ["KERNEL FADE MS"] = "FADE",
  ["NORMALIZE EACH KERNEL WINDOW"] = "K NORM",
  ["WET PRE-GAIN DB"] = "GAIN",
  ["WET LEVEL"] = "WET",
  ["DRY LEVEL"] = "DRY",
  ["MAX TAIL SEC"] = "TAIL",
  ["RANDOM SEED"] = "SEED",
  ["EFFECT REGION"] = "REGION",
  ["EFFECT AMOUNT / GAIN"] = "AMOUNT",
  ["DAMPING / SMOOTHING"] = "DAMP",
  ["WET AMOUNT"] = "WET",
  ["OUTPUT AMP"] = "OUT",
  ["MOVE WET ACROSS VIRTUAL SPEAKER ARRAY"] = "MOVE",
  ["DRY REMAINING AT FOCUS"] = "DRY FOC",
  ["SOURCE OBJECT SPREAD"] = "SRC OBJ",
  ["OBJECT CLARITY"] = "CLARITY",
  ["DRY OBJECT LEVEL"] = "DRY",
  ["SPACE AMOUNT"] = "SPACE",
  ["SPATIAL SPREAD DEG"] = "SPREAD",
  ["SPATIAL MOTION"] = "MOTION",
  ["RESONANCE HZ"] = "RES",
  ["RESONANT FEEDBACK"] = "FDBK",
  ["SPECTRAL SMEAR"] = "SMEAR",
  ["INPUT MODE"] = "INPUT",
  ["OUTPUT FORMAT"] = "FORMAT",
  ["MATERIAL PRESET"] = "MAT",
  ["ROOM LENGTH M"] = "ROOM X",
  ["ROOM WIDTH M"] = "ROOM Y",
  ["ROOM HEIGHT M"] = "ROOM Z",
  ["SOURCE DISTANCE M"] = "SRC D",
  ["PRE-DELAY MS"] = "PRE",
  ["SURFACE ABSORPTION"] = "ABSORB",
  ["WALL SCATTERING"] = "SCATTER",
  ["ESTIMATE DECAY FROM ROOM/MATERIAL"] = "AUTO RT",
  ["MANUAL DECAY SEC"] = "DECAY",
  ["IR DURATION SEC"] = "IR DUR",
  ["DIRECTIONAL SPREAD DEG"] = "SPREAD",
  ["DIRECT GAIN"] = "DIRECT",
  ["EARLY REFLECTIONS PER IR"] = "EARLY",
  ["LATE DIFFUSE TAPS PER IR"] = "DIFFUSE",
  ["AIR / TAIL DAMPING"] = "DAMP",
  ["NORMALIZE EACH IR DB"] = "NORM",
  ["INSERT GENERATED IR ITEMS"] = "INSERT",
  ["COLOR MODEL"] = "COLOR",
  ["ELEVATION SOURCE"] = "EL SRC",
  ["UNIFORM ELEVATION"] = "EL",
  ["ELEVATION SPREAD"] = "EL RNG",
  ["FREQUENCY SCALE"] = "FREQ",
  ["TIME COLUMNS"] = "COLS",
  ["FREQUENCY ROWS"] = "ROWS",
  ["MAX ACTIVE ROWS PER COLUMN"] = "MAX ROW",
  ["MIN FREQUENCY"] = "MIN F",
  ["MAX FREQUENCY"] = "MAX F",
  ["AMPLITUDE THRESHOLD"] = "THRESH",
  ["AMPLITUDE CURVE"] = "CURVE",
  ["COLUMN OVERLAP"] = "OVERLAP",
  ["HYBRID NOISE BLEND"] = "NOISE",
  ["ADDITIVE SMOOTHING"] = "SMOOTH",
  ["ADDITIVE SUSTAIN"] = "SUSTAIN",
  ["ADDITIVE ATTACK"] = "ATTACK",
  ["SPECTRAL BLUR"] = "BLUR",
  ["SPECTRAL BAND WIDTH"] = "BAND W",
  ["SPECTRAL INERTIA"] = "INERTIA",
  ["PARTIAL ATTACK"] = "ATTACK",
  ["GRAIN DURATION"] = "GRAIN",
  ["GRAIN DENSITY"] = "DENS",
  ["GRAIN PITCH SPREAD"] = "PITCH",
  ["IMAGE PITCH DEPTH"] = "IMG P",
  ["SOURCE ITEM"] = "SRC",
  ["SOURCE SCAN"] = "SCAN",
  ["SOURCE JITTER"] = "JITTER",
  ["SOURCE CHANNEL"] = "SRC CH",
  ["GRAIN TAPER"] = "TAPER",
  ["AZIMUTH OFFSET"] = "AZ OFF",
  ["MIN DISTANCE"] = "MIN D",
  ["MAX DISTANCE"] = "MAX D",
  ["INVERT DISTANCE"] = "INV D",
  ["RING SPATIAL WIDTH"] = "WIDTH",
  ["SOFT DRIVE"] = "DRIVE",
  ["ADAPT LOWER-ORDER IRS TO OUTPUT ORDER"] = "ADAPT",
  ["ALLOW SPARSE 4-DIRECTION FOA BANK"] = "SPARSE",
  ["NORMALIZE EACH IR BEFORE CONVOLUTION"] = "IR NORM",
  ["SOURCE ORDER"] = "SRC ORD",
  ["KERNEL ORDER"] = "KER ORD",
  ["KERNEL LAYOUT"] = "LAYOUT",
  ["KERNEL MODE"] = "KERNEL",
  ["CONVOLUTION MODE"] = "CONV",
  ["LOCK SEND AND RETURN AZ/EL"] = "LOCK AZ",
  ["LOCK MASK SHAPE"] = "LOCK",
  ["LINKED AZIMUTH (+L / -R)"] = "AZ",
  ["LINKED ELEVATION"] = "EL",
  ["MASK WIDTH"] = "WIDTH",
  ["MASK SHARPNESS"] = "SHARP",
  ["MASK GAIN"] = "GAIN",
  ["SEND GAIN"] = "SEND",
  ["RETURN GAIN"] = "RETURN",
  ["DRY SEND"] = "DRY",
  ["WET RETURN"] = "WET",
  ["SEND AZIMUTH"] = "S AZ",
  ["SEND ELEVATION"] = "S EL",
  ["RETURN AZIMUTH"] = "R AZ",
  ["RETURN ELEVATION"] = "R EL",
  ["YAW"] = "YAW",
  ["PITCH"] = "PITCH",
  ["NAVIGATION MODE"] = "NAV",
  ["DENSITY GRAINS/SEC"] = "DENS",
  ["GRAIN SIZE MS"] = "GRAIN",
  ["SCAN MOTION"] = "SCAN",
  ["AZIMUTH MOTION"] = "AZ MOT",
  ["ELEVATION MOTION"] = "EL MOT",
  ["SPATIAL BLUR"] = "BLUR",
  ["FREEZE POSITION"] = "FREEZE",
  ["FREEZE/TRACE AMOUNT"] = "AMOUNT",
  ["WET MIX"] = "WET",
  ["SPECTRAL SMOOTHING BINS"] = "SMOOTH",
  ["ENVELOPE FLOOR"] = "FLOOR",
  ["REGION WIDTH DEG"] = "WIDTH",
  ["DIRECTION LAYER"] = "LAYER",
  ["KERNEL ASSIGNMENT"] = "ASSIGN",
  ["OUTPUT LENGTH"] = "LENGTH",
  ["CONVOLUTION METHOD"] = "METHOD",
  ["PEAK NORMALIZE OUTPUT"] = "PK NORM",
  ["SOFT LIMIT BEFORE NORMALIZE"] = "LIMIT",
  ["PEAK NORMALIZE"] = "PK NORM",
  ["NORMALIZE PEAK DB"] = "NORM",
  ["ADAPT MIXED-ORDER KERNELS"] = "ADAPT",
  ["NORMALIZE EACH KERNEL WINDOW"] = "K NORM",
  ["SOURCE FORMAT"] = "FORMAT",
  ["OUTPUT ORDER"] = "ORDER",
  ["SPATIAL OCCUPATION"] = "OCCUPY",
  ["SOURCE POOL"] = "POOL",
  ["STEREO SUM/DIFFERENCE EXPANSION"] = "STEREO",
  ["HEAD ORIENTATION"] = "HEAD",
  ["LISTENER X"] = "L X",
  ["LISTENER Y"] = "L Y",
  ["LISTENER Z"] = "L Z",
  ["ROLL DEG"] = "ROLL",
  ["PITCH DEG"] = "PITCH",
  ["YAW DEG"] = "YAW",
  ["TIME"] = "TIME",
  ["SOFT LIMIT"] = "LIMIT",
  ["AMPLITUDE SOURCE"] = "AMP SRC",
  ["SYNTHESIS"] = "SYNTH",
  ["ELEVATION"] = "EL",
  ["DURATION SEC"] = "DUR",
  ["CAMERA AZIM"] = "CAM AZ",
  ["CAMERA ELEV"] = "CAM EL",
  ["PREVIEW TIME"] = "TIME",
  ["GLOBAL NODE RADIUS"] = "RADIUS",
  ["DISTANCE FALLOFF"] = "FALLOFF",
  ["BLEND SHARPNESS"] = "BLEND",
  ["PERSPECTIVE ROTATION"] = "ROTATE",
  ["NEAR-FIELD BLUR"] = "N BLUR",
  ["HEIGHT SENSITIVITY"] = "HEIGHT",
  ["SOURCE LOOP CROSSFADE MS"] = "XFADE",
  ["OUTPUT GAIN DB"] = "OUT",
  ["NODE X"] = "NODE X",
  ["NODE Y"] = "NODE Y",
  ["NODE Z"] = "NODE Z",
  ["NODE RADIUS"] = "RADIUS",
}

local MAX_SLIDER_LABEL_CHARS = 8

local function clamp_slider_label(value)
  value = tostring(value or ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if #value <= MAX_SLIDER_LABEL_CHARS then return value end
  local compact = value:gsub("[AEIOU]", "")
  if #compact <= MAX_SLIDER_LABEL_CHARS then return compact end
  return compact:sub(1, MAX_SLIDER_LABEL_CHARS)
end

local function slider_label(label)
  local visible = tostring(label or ""):gsub("##.*$", "")
  visible = visible:gsub("%s*%b()", "")
  local upper = visible:upper()
  upper = upper:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  local source_label = upper:match("^S%d+%s+(.+)$")
  if source_label then
    if source_label:match("^LIVE AZIMUTH") then return clamp_slider_label("AZ") end
    if source_label:match("^LIVE ELEVATION") then return clamp_slider_label("EL") end
    if source_label:match("^LIVE DISTANCE") then return clamp_slider_label("DIST") end
    if source_label:match("^AZIMUTH") then return clamp_slider_label("AZ") end
    if source_label:match("^ELEVATION") then return clamp_slider_label("EL") end
    if source_label:match("^DISTANCE") then return clamp_slider_label("DIST") end
    if source_label:match("^GAIN") then return clamp_slider_label("GAIN") end
    if source_label:match("^TRIANGLE PATH") then return clamp_slider_label("PATH") end
    if source_label:match("^POSITION") then return clamp_slider_label("POS") end
    if source_label:match("^CENTER BLEND") then return clamp_slider_label("BLEND") end
    if source_label:match("^VERTEX WIDTH") then return clamp_slider_label("WIDTH") end
    if source_label:match("^WIDTH") then return clamp_slider_label("WIDTH") end
    if source_label == "X" or source_label == "Y" or source_label == "Z" then return clamp_slider_label(source_label) end
  end
  return clamp_slider_label(SLIDER_ABBR[upper] or upper)
end

local function display_slider_value(value, format, integer)
  if integer then return tostring(math.floor(value + 0.5)) end
  if format and format ~= "" then return string.format(format, value) end
  return string.format("%.3f", value)
end

local function text_width(ImGui, ctx, text)
  text = tostring(text or "")
  if ImGui.CalcTextSize then
    local ok, width = pcall(ImGui.CalcTextSize, ctx, text)
    if ok and type(width) == "number" then return width end
  end
  return #text * 7
end

local function visible_text(text)
  return tostring(text or ""):gsub("##.*$", "")
end

local function combo_width(ImGui, ctx, labels, current, max_width)
  local width = text_width(ImGui, ctx, labels[current or 1] or "") + 38
  for _, label in ipairs(labels or {}) do
    width = math.max(width, text_width(ImGui, ctx, label) + 38)
  end
  return math.max(80, math.min(max_width or width, width))
end

local function input_int_width(ImGui, ctx, label, max_width)
  local text = tostring(label or ""):lower()
  if text:find("seed", 1, true) then
    return math.min(max_width or 112, math.max(92, text_width(ImGui, ctx, "0000000000") + 28))
  end
  return max_width
end

local function row_metrics(ImGui, ctx, width)
  local outer_x, y = ImGui.GetCursorScreenPos(ctx)
  local avail = width or ImGui.GetContentRegionAvail(ctx)
  if type(avail) ~= "number" then avail = 220 end
  avail = math.max(220, avail)
  local left_pad = 12
  local x = outer_x + left_pad
  local content_avail = math.max(180, avail - left_pad)
  local label_w = 96
  local value_w = 76
  local control_x = x + label_w
  local control_w = math.max(52, content_avail - label_w - value_w - 8)
  local value_x = control_x + control_w + 8
  return {
    outer_x = outer_x,
    x = x,
    y = y,
    avail = avail,
    content_avail = content_avail,
    label_w = label_w,
    value_w = value_w,
    control_x = control_x,
    control_w = control_w,
    value_x = value_x,
    h = 22,
  }
end

local function push_borderless_frame(ImGui, ctx)
  local vars = 0
  if ImGui.StyleVar_FrameBorderSize then
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 0.0)
    vars = vars + 1
  end
  return vars
end

local function pop_borderless_frame(ImGui, ctx, vars)
  if vars and vars > 0 then ImGui.PopStyleVar(ctx, vars) end
end

local function finish_row(ImGui, ctx, row)
  ImGui.SetCursorScreenPos(ctx, row.outer_x or row.x, row.y)
  ImGui.Dummy(ctx, row.avail, row.h)
  ImGui.SetCursorScreenPos(ctx, row.outer_x or row.x, row.y + row.h)
end

function M.slider_row(ImGui, ctx, label, value, min_value, max_value, format, integer, width)
  local row = row_metrics(ImGui, ctx, width)
  local x, y = row.x, row.y
  local p = M.palette(ImGui)
  local h = row.h
  local track_x = row.control_x
  local track_w = row.control_w
  local value_x = row.value_x
  local track_y = y + 6
  local track_h = 8
  local norm = 0
  if max_value ~= min_value then norm = clamp((value - min_value) / (max_value - min_value), 0, 1) end

  local id = string.format("##s3g_slider_%s_%d_%d", tostring(label or ""), math.floor(x + 0.5), math.floor(y + 0.5))
  ImGui.InvisibleButton(ctx, id, row.avail, h)
  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local changed = false
  if (hovered or active) and ImGui.IsMouseDown(ctx, 0) then
    local mx = ImGui.GetMousePos(ctx)
    local new_norm = clamp((mx - track_x) / track_w, 0, 1)
    local new_value = min_value + (max_value - min_value) * new_norm
    if integer then new_value = math.floor(new_value + 0.5) end
    if math.abs(new_value - value) > (integer and 0 or 0.0000001) then
      value = new_value
      changed = true
      norm = new_norm
    end
  end

  local draw = ImGui.GetWindowDrawList(ctx)
  local track_col = active and p.frame_active or (hovered and p.frame_hover or p.frame)
  local fill_col = active and p.active or p.fill
  local handle_col = active and p.active_hover or p.active
  ImGui.DrawList_AddText(draw, x, y + 2, p.label, slider_label(label))
  ImGui.DrawList_AddRectFilled(draw, track_x, track_y, track_x + track_w, track_y + track_h, track_col)
  ImGui.DrawList_AddRectFilled(draw, track_x + 1, track_y + 1, track_x + math.max(2, track_w * norm), track_y + track_h - 1, fill_col)
  local hx = clamp(track_x + track_w * norm - 1.5, track_x + 1, track_x + track_w - 4)
  ImGui.DrawList_AddRectFilled(draw, hx, track_y - 2, hx + 3, track_y + track_h + 2, handle_col)
  ImGui.DrawList_AddText(draw, value_x, y + 2, p.value, display_slider_value(value, format, integer))
  ImGui.SetCursorScreenPos(ctx, row.outer_x or row.x, row.y + row.h)
  return changed, value
end

function M.slider_int(ImGui, ctx, label, value, min_value, max_value, width)
  return M.slider_row(ImGui, ctx, label, value, min_value, max_value, nil, true, width)
end

function M.slider_double(ImGui, ctx, label, value, min_value, max_value, format, width)
  return M.slider_row(ImGui, ctx, label, value, min_value, max_value, format or "%.3f", false, width)
end

function M.combo_row(ImGui, ctx, label, labels, value, width)
  labels = labels or {}
  local row = row_metrics(ImGui, ctx, width)
  local x, y = row.x, row.y
  local p = M.palette(ImGui)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 2, p.label, slider_label(label))
  ImGui.SetCursorScreenPos(ctx, row.control_x, y)
  ImGui.SetNextItemWidth(ctx, combo_width(ImGui, ctx, labels, value, row.control_w))
  local border_vars = push_borderless_frame(ImGui, ctx)
  local changed, next_value = ImGui.Combo(ctx, "##combo_" .. tostring(label or ""), (value or 1) - 1, table.concat(labels, "\0") .. "\0")
  pop_borderless_frame(ImGui, ctx, border_vars)
  finish_row(ImGui, ctx, row)
  return changed, next_value + 1
end

function M.combo_action_row(ImGui, ctx, label, labels, value, width, button_label, button_width)
  labels = labels or {}
  button_width = button_width or 88
  local row = row_metrics(ImGui, ctx, width)
  local x, y = row.x, row.y
  local p = M.palette(ImGui)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 2, p.label, slider_label(label))
  ImGui.SetCursorScreenPos(ctx, row.control_x, y)
  ImGui.SetNextItemWidth(ctx, combo_width(ImGui, ctx, labels, value, math.max(52, row.control_w - button_width - 8)))
  local border_vars = push_borderless_frame(ImGui, ctx)
  local changed, next_value = ImGui.Combo(ctx, "##combo_" .. tostring(label or ""), (value or 1) - 1, table.concat(labels, "\0") .. "\0")
  pop_borderless_frame(ImGui, ctx, border_vars)
  ImGui.SameLine(ctx)
  local pressed = ImGui.Button(ctx, tostring(button_label or "APPLY"), button_width, 24)
  finish_row(ImGui, ctx, row)
  return changed, next_value + 1, pressed
end

function M.input_int_row(ImGui, ctx, label, value, step, step_fast, width)
  local row = row_metrics(ImGui, ctx, width)
  local x, y = row.x, row.y
  local p = M.palette(ImGui)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 2, p.label, slider_label(label))
  ImGui.SetCursorScreenPos(ctx, row.control_x, y)
  ImGui.SetNextItemWidth(ctx, input_int_width(ImGui, ctx, label, row.control_w))
  local border_vars = push_borderless_frame(ImGui, ctx)
  local changed, next_value = ImGui.InputInt(ctx, "##input_" .. tostring(label or ""), value, step or 1, step_fast or 10)
  pop_borderless_frame(ImGui, ctx, border_vars)
  finish_row(ImGui, ctx, row)
  return changed, next_value
end

function M.input_double_row(ImGui, ctx, label, value, step, step_fast, format, width)
  local row = row_metrics(ImGui, ctx, width)
  local x, y = row.x, row.y
  local p = M.palette(ImGui)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 2, p.label, slider_label(label))
  ImGui.SetCursorScreenPos(ctx, row.control_x, y)
  ImGui.SetNextItemWidth(ctx, row.control_w)
  local border_vars = push_borderless_frame(ImGui, ctx)
  local changed, next_value = ImGui.InputDouble(ctx, "##input_" .. tostring(label or ""), value, step or 0.1, step_fast or 1.0, format or "%.3f")
  pop_borderless_frame(ImGui, ctx, border_vars)
  finish_row(ImGui, ctx, row)
  return changed, next_value
end

function M.input_text_row(ImGui, ctx, label, value, width)
  local row = row_metrics(ImGui, ctx, width)
  local x, y = row.x, row.y
  local p = M.palette(ImGui)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 2, p.label, slider_label(label))
  ImGui.SetCursorScreenPos(ctx, row.control_x, y)
  ImGui.SetNextItemWidth(ctx, row.control_w)
  local border_vars = push_borderless_frame(ImGui, ctx)
  local changed, next_value = ImGui.InputText(ctx, "##input_" .. tostring(label or ""), value or "")
  pop_borderless_frame(ImGui, ctx, border_vars)
  finish_row(ImGui, ctx, row)
  return changed, next_value
end

function M.checkbox_row(ImGui, ctx, label, value, width)
  local row = row_metrics(ImGui, ctx, width)
  local x, y = row.x, row.y
  local p = M.palette(ImGui)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y + 2, p.label, slider_label(label))
  ImGui.SetCursorScreenPos(ctx, row.control_x, y)
  local changed, next_value = ImGui.Checkbox(ctx, "##check_" .. tostring(label or ""), value)
  finish_row(ImGui, ctx, row)
  return changed, next_value
end

function M.note_row(ImGui, ctx, text, width)
  local row = row_metrics(ImGui, ctx, width)
  local p = M.palette(ImGui)
  local draw = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddText(draw, row.control_x, row.y + 2, p.muted, tostring(text or ""))
  finish_row(ImGui, ctx, row)
end

function M.status_row(ImGui, ctx, text, color_name, width)
  local row = row_metrics(ImGui, ctx, width)
  local p = M.palette(ImGui)
  local draw = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddText(draw, row.control_x, row.y + 2, p[color_name or "value"] or p.value, tostring(text or ""))
  finish_row(ImGui, ctx, row)
end

function M.footer_buttons(ImGui, ctx, primary_label, secondary_label, primary_w, secondary_w)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.SetCursorScreenPos(ctx, x + 12, y)
  local primary = ImGui.Button(ctx, tostring(primary_label or "OK"):upper(), primary_w or 96, 28)
  local secondary = false
  if secondary_label and secondary_label ~= "" then
    ImGui.SameLine(ctx)
    secondary = ImGui.Button(ctx, tostring(secondary_label):upper(), secondary_w or primary_w or 96, 28)
  end
  return primary, secondary
end

function M.action_button(ImGui, ctx, label, width, height)
  label = tostring(label or ""):upper()
  local avail = ImGui.GetContentRegionAvail(ctx)
  if type(avail) ~= "number" then avail = 220 end
  local button_w = width or math.max(96, math.min(avail, text_width(ImGui, ctx, visible_text(label)) + 28))
  return ImGui.Button(ctx, label, button_w, height or 26)
end

function M.action_row(ImGui, ctx, label, width, height)
  local row = row_metrics(ImGui, ctx)
  local button_label = tostring(label or ""):upper()
  local button_w = width or math.max(80, math.min(row.control_w, text_width(ImGui, ctx, visible_text(button_label)) + 28))
  ImGui.SetCursorScreenPos(ctx, row.control_x, row.y)
  local pressed = ImGui.Button(ctx, button_label, button_w, height or 24)
  finish_row(ImGui, ctx, row)
  return pressed
end

function M.button_row(ImGui, ctx, buttons, height)
  local row = row_metrics(ImGui, ctx)
  ImGui.SetCursorScreenPos(ctx, row.control_x, row.y)
  local pressed = nil
  for index, button in ipairs(buttons or {}) do
    local label = tostring(button.label or button[1] or ""):upper()
    local width = button.width or button[2] or math.max(64, text_width(ImGui, ctx, visible_text(label)) + 24)
    if index > 1 then ImGui.SameLine(ctx) end
    if ImGui.Button(ctx, label, width, height or 24) then pressed = index end
  end
  finish_row(ImGui, ctx, row)
  return pressed
end

function M.section_label(ImGui, ctx, label)
  ImGui.Dummy(ctx, 1, 4)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), x, y, M.palette(ImGui).muted, slider_label(label))
  ImGui.Dummy(ctx, 1, 16)
end

function M.toolbox_header(ImGui, ctx, title, flags)
  local open_state
  title = tostring(title or ""):upper()
  if flags then
    open_state = ImGui.CollapsingHeader(ctx, title, nil, flags)
  else
    open_state = ImGui.CollapsingHeader(ctx, title)
  end
  if ImGui.GetItemRectMin and ImGui.GetItemRectMax and ImGui.GetWindowDrawList then
    local x0, y0 = ImGui.GetItemRectMin(ctx)
    local x1 = ImGui.GetItemRectMax(ctx)
    ImGui.DrawList_AddLine(
      ImGui.GetWindowDrawList(ctx),
      x0 + 1,
      y0 + 1,
      x1 - 1,
      y0 + 1,
      ImGui.ColorConvertDouble4ToU32(0.88, 0.88, 0.86, 0.58),
      1.0)
  end
  ImGui.Dummy(ctx, 1, 3)
  return open_state
end

function M.push_soft_panel(ImGui, ctx)
  local function rgba(r, g, b, a) return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1.0) end
  local colors = 0
  local vars = 0
  local body = rgba(0.125, 0.128, 0.130, 1.0)
  local title = rgba(0.058, 0.060, 0.062, 1.0)
  local title_hover = rgba(0.078, 0.080, 0.083, 1.0)
  local title_active = rgba(0.094, 0.096, 0.098, 1.0)
  local control = rgba(0.052, 0.054, 0.056, 1.0)
  local control_hover = control
  local control_active = rgba(0.088, 0.090, 0.092, 1.0)
  if ImGui.Col_ChildBg then ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, body); colors = colors + 1 end
  if ImGui.Col_Border then ImGui.PushStyleColor(ctx, ImGui.Col_Border, rgba(0.10, 0.11, 0.12, 0.16)); colors = colors + 1 end
  if ImGui.Col_Separator then ImGui.PushStyleColor(ctx, ImGui.Col_Separator, rgba(0.11, 0.12, 0.13, 0.30)); colors = colors + 1 end
  if ImGui.Col_Header then ImGui.PushStyleColor(ctx, ImGui.Col_Header, title); colors = colors + 1 end
  if ImGui.Col_HeaderHovered then ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, title_hover); colors = colors + 1 end
  if ImGui.Col_HeaderActive then ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive, title_active); colors = colors + 1 end
  if ImGui.Col_FrameBg then ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, control); colors = colors + 1 end
  if ImGui.Col_FrameBgHovered then ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, control_hover); colors = colors + 1 end
  if ImGui.Col_FrameBgActive then ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, control_active); colors = colors + 1 end
  if ImGui.Col_Button then ImGui.PushStyleColor(ctx, ImGui.Col_Button, rgba(0.045, 0.045, 0.045, 1.0)); colors = colors + 1 end
  if ImGui.Col_ButtonHovered then ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, rgba(0.064, 0.064, 0.064, 1.0)); colors = colors + 1 end
  if ImGui.Col_ButtonActive then ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, rgba(0.102, 0.102, 0.102, 1.0)); colors = colors + 1 end
  if ImGui.Col_CheckMark then ImGui.PushStyleColor(ctx, ImGui.Col_CheckMark, rgba(0.62, 0.64, 0.64, 1.0)); colors = colors + 1 end
  if ImGui.Col_SliderGrab then ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrab, rgba(0.42, 0.43, 0.43, 1.0)); colors = colors + 1 end
  if ImGui.Col_SliderGrabActive then ImGui.PushStyleColor(ctx, ImGui.Col_SliderGrabActive, rgba(0.64, 0.65, 0.64, 1.0)); colors = colors + 1 end
  if ImGui.StyleVar_ChildBorderSize then ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildBorderSize, 0.0); vars = vars + 1 end
  if ImGui.StyleVar_FrameBorderSize then ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 0.0); vars = vars + 1 end
  if ImGui.StyleVar_FramePadding then ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 5, 2); vars = vars + 1 end
  if ImGui.StyleVar_GrabMinSize then ImGui.PushStyleVar(ctx, ImGui.StyleVar_GrabMinSize, 6.0); vars = vars + 1 end
  return { colors = colors, vars = vars }
end

function M.pop_soft_panel(ImGui, ctx, stack)
  if not stack then return end
  if stack.colors and stack.colors > 0 then ImGui.PopStyleColor(ctx, stack.colors) end
  if stack.vars and stack.vars > 0 then ImGui.PopStyleVar(ctx, stack.vars) end
end

function M.begin_section(ImGui, ctx, title, height)
  local stack = M.push_soft_panel(ImGui, ctx)
  local p = M.palette(ImGui)
  local draw = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local w = ImGui.GetContentRegionAvail(ctx)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + height, p.panel_soft)
  ImGui.DrawList_AddRectFilled(draw, x, y, x + w, y + 2, p.active)
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 10)
  M.text(ImGui, ctx, tostring(title or ""):upper())
  ImGui.SetCursorScreenPos(ctx, x + 12, y + 36)
  return x, y, height, stack
end

function M.finish_section(ImGui, ctx, x, y, height, stack)
  M.pop_soft_panel(ImGui, ctx, stack)
  ImGui.SetCursorScreenPos(ctx, x, y + height)
  ImGui.Dummy(ctx, 1, 10)
end

function M.push_panel(ImGui, ctx)
  local p = M.palette(ImGui)
  local colors = 0
  colors = colors + push_style_color(ImGui, ctx, "ChildBg", p.panel)
  colors = colors + push_style_color(ImGui, ctx, "Border", p.edge)
  return { colors = colors, vars = 0 }
end

function M.static_header(ImGui, ctx, title)
  local p = M.palette(ImGui)
  ImGui.TextColored(ctx, p.label, title)
  if ImGui.Separator then ImGui.Separator(ctx) end
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
  colors = colors + push_style_color(ImGui, ctx, "Text", p.label)
  colors = colors + push_style_color(ImGui, ctx, "TextDisabled", p.disabled)
  colors = colors + push_style_color(ImGui, ctx, "FrameBg", p.frame)
  colors = colors + push_style_color(ImGui, ctx, "FrameBgHovered", p.frame_hover)
  colors = colors + push_style_color(ImGui, ctx, "FrameBgActive", p.frame_active)
  colors = colors + push_style_color(ImGui, ctx, "Button", p.button)
  colors = colors + push_style_color(ImGui, ctx, "ButtonHovered", p.button_hover)
  colors = colors + push_style_color(ImGui, ctx, "ButtonActive", p.button_active)
  colors = colors + push_style_color(ImGui, ctx, "Header", p.frame)
  colors = colors + push_style_color(ImGui, ctx, "HeaderHovered", p.frame_hover)
  colors = colors + push_style_color(ImGui, ctx, "HeaderActive", p.frame_active)
  colors = colors + push_style_color(ImGui, ctx, "CheckMark", p.active)
  colors = colors + push_style_color(ImGui, ctx, "SliderGrab", p.fill)
  colors = colors + push_style_color(ImGui, ctx, "SliderGrabActive", p.active)
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
    if results[1] ~= nil then
      local stacks = stacks_by_ctx[ctx]
      if not stacks then
        stacks = {}
        stacks_by_ctx[ctx] = stacks
      end
      stacks[#stacks + 1] = { style = stack, font_pushed = font_pushed }
    else
      M.pop_font(ImGui, ctx, font_pushed)
      M.pop(ImGui, ctx, stack)
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

  local ok = pcall(function()
    ImGui.Begin = themed_begin
    ImGui.End = themed_end
  end)
  if ok then installed[ImGui] = true end
  return ok
end

return M
