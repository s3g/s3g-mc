autowatch = 1;
inlets = 1;
outlets = 7;

var score = null;
var duration = 1;
var position = 0;
var playing = false;
var lastMs = 0;
var loop = true;
var palindrome = false;
var direction = 1;
var speedValue = 1;
var heatResolution = 10;
var lastSceneIndex = -1;
var heatTextureWidth = 96;
var heatTextureHeight = 48;
var heatTick = 0;
var heatSkip = 4;
var heatDirty = true;
var heatPixelBlock = 1;
var geometryMode = "sphere";

var activeMatrix = null;
var sourceMatrix = null;
var lineMatrix = null;
var heatTextureMatrix = null;

function read(path) {
  var resolved = normalizePath(path);
  if (!resolved) {
    status("no JSON path");
    return;
  }
  try {
    loadjson(readTextFile(resolved), resolved);
  } catch (error) {
    status("read failed: " + error.message);
  }
}

function loadjson(text, label) {
  try {
    var data = JSON.parse(String(text || ""));
    if (!data || data.format !== "s3g-mc-displacement-score") {
      throw new Error("not a Displacement Score JSON file");
    }
    score = normalizeScore(data);
    duration = Math.max(0.001, Number(score.duration || 1));
    speedValue = 1;
    loop = true;
    palindrome = false;
    position = 0;
    direction = 1;
    lastSceneIndex = -1;
    lastMs = nowMs();
    allocateMatrices();
    status("loaded " + (label || "Displacement Score JSON") + " | " + score.frames.length + " frames | " + duration.toFixed(3) + "s | browser default 1x loop");
    outputFrame();
  } catch (error) {
    status("JSON parse failed: " + error.message);
  }
}

function browserdefault() {
  speedValue = 1;
  loop = true;
  palindrome = false;
  position = 0;
  direction = 1;
  lastSceneIndex = -1;
  lastMs = nowMs();
  status("browser default 1x loop");
  outputFrame();
}

function play() {
  playing = true;
  lastMs = nowMs();
  status("play");
}

function stop() {
  playing = false;
  status("stop");
}

function reset() {
  position = 0;
  direction = 1;
  lastSceneIndex = -1;
  lastMs = nowMs();
  outputFrame();
}

function tick() {
  if (!score) return;
  var t = nowMs();
  if (playing) advance(Math.max(0, t - lastMs) / 1000);
  lastMs = t;
  outputFrame();
}

function seconds(v) {
  setCyclePosition(safeNumber(v, 0));
  outputFrame();
}

function setnorm(v) {
  setCyclePosition(clamp(safeNumber(v, 0), 0, 1) * playbackDuration());
  outputFrame();
}

function speed(v) {
  speedValue = clamp(safeNumber(v, 1), 0, 64);
  status("speed " + speedValue.toFixed(3));
}

function playbackmode(name) {
  var mode = String(name || "loop").toLowerCase();
  if (mode === "pal" || mode === "palindrome" || mode === "backforth") {
    loop = true;
    palindrome = true;
  } else if (mode === "once" || mode === "one" || mode === "oneshot") {
    loop = false;
    palindrome = false;
  } else {
    loop = true;
    palindrome = false;
  }
  status("playback " + (loop ? (palindrome ? "palindrome" : "loop") : "once"));
}

function heatres(v) {
  heatResolution = Math.round(clamp(safeNumber(v, heatResolution), 4, 16));
  heatDirty = true;
  allocateMatrices();
  outputFrame();
}

function heatrate(v) {
  heatSkip = Math.round(clamp(safeNumber(v, heatSkip), 1, 24));
  status("heat update every " + heatSkip + " ticks");
}

function heatpixel(v) {
  heatPixelBlock = Math.round(clamp(safeNumber(v, heatPixelBlock), 1, 12));
  heatDirty = true;
  status("heat pixel block " + heatPixelBlock);
  outputFrame();
}

function geommode(name) {
  var mode = String(name || "sphere").toLowerCase();
  geometryMode = mode === "map" || mode === "peters" || mode === "flat" ? "map" : "sphere";
  status("geometry mode " + geometryMode);
  if (geometryMode === "map") {
    outlet(4, ["position", 0, 0, 6.2]);
    outlet(4, ["lookat", 0, 0, 0]);
  }
  outputFrame();
}

function advance(delta) {
  position += delta * speedValue * direction;
  if (loop && palindrome) {
    while (position > duration || position < 0) {
      if (position > duration) {
        position = duration - (position - duration);
        direction = -1;
      } else {
        position = -position;
        direction = 1;
      }
    }
  } else if (loop) {
    position = ((position % duration) + duration) % duration;
  } else if (position >= duration) {
    position = duration;
    playing = false;
    status("done");
  } else if (position <= 0) {
    position = 0;
    playing = false;
    status("done");
  }
}

function outputFrame() {
  if (!score) return;
  var t = duration > 0 ? clamp(position / duration, 0, 1) : 0;
  var cycle = playbackDuration();
  var cyclePos = cyclePosition();
  var cycleNorm = cycle > 0 ? clamp(cyclePos / cycle, 0, 1) : 0;
  var frame = frameAt(t);
  var active = frame.geometry || [];
  writePointMatrix(activeMatrix, active, 1.0);
  writePointMatrix(sourceMatrix, score.source || [], 1.0);
  writeLineMatrix(lineMatrix, active);
  heatTick += 1;
  if (heatDirty || heatTick >= heatSkip) {
    heatTick = 0;
    writeHeatTexture(active);
    heatDirty = false;
  }
  outputMatrices();
  outputSceneHit(t);
  outlet(6, [
    "clock",
    Number(cyclePos.toFixed(6)),
    Number(cycleNorm.toFixed(6)),
    Number(position.toFixed(6)),
    Number(t.toFixed(6)),
    direction
  ]);
}

function outputMatrices() {
  if (activeMatrix) outlet(0, "jit_matrix", activeMatrix.name);
  if (sourceMatrix) outlet(1, "jit_matrix", sourceMatrix.name);
  if (lineMatrix) outlet(2, "jit_matrix", lineMatrix.name);
  if (heatTextureMatrix) outlet(3, "jit_matrix", heatTextureMatrix.name);
}

function outputSceneHit(t) {
  var scenes = score.scenes || [];
  if (!scenes.length) return;
  var current = -1;
  for (var i = 0; i < scenes.length; i += 1) {
    if (t + 0.000001 >= Number(scenes[i].t || 0)) current = i;
  }
  if (current < 0) current = 0;
  if (current !== lastSceneIndex) {
    lastSceneIndex = current;
    var scene = scenes[current];
    var name = scene.name || String.fromCharCode(65 + current);
    var time = Number((Number(scene.t || 0) * duration).toFixed(6));
    outlet(6, ["/displacement/scene", current + 1, name, time, "bang"]);
  }
}

function allocateMatrices() {
  var pointCount = Math.max(1, score && score.source ? score.source.length : 24);
  var edgeCount = Math.max(1, score && score.edges ? score.edges.length : pointCount);
  activeMatrix = makeMatrix(3, "float32", pointCount);
  sourceMatrix = makeMatrix(3, "float32", pointCount);
  lineMatrix = makeMatrix(3, "float32", Math.max(2, edgeCount * 2));
  heatTextureWidth = Math.max(96, heatResolution * 32);
  heatTextureHeight = Math.max(32, heatResolution * 10);
  heatTextureMatrix = makeMatrix2d(4, "char", heatTextureWidth, heatTextureHeight);
  heatDirty = true;
}

function makeMatrix(planes, type, dim) {
  var matrix = new JitterMatrix(planes, type, dim);
  matrix.clear();
  return matrix;
}

function makeMatrix2d(planes, type, width, height) {
  var matrix = new JitterMatrix(planes, type, width, height);
  matrix.clear();
  return matrix;
}

function writePointMatrix(matrix, points, scale) {
  if (!matrix) return;
  matrix.clear();
  for (var i = 0; i < points.length; i += 1) {
    var xyz = displayXyz(points[i], scale);
    setCell(matrix, i, xyz[0], xyz[1], xyz[2]);
  }
}

function writeLineMatrix(matrix, points) {
  if (!matrix) return;
  matrix.clear();
  if (!points.length) return;
  var edges = score && score.edges && score.edges.length ? score.edges : fallbackEdges(points);
  var idx = 0;
  for (var i = 0; i < edges.length; i += 1) {
    var edge = edges[i] || [];
    var ai = Number(edge[0] || 0);
    var bi = Number(edge[1] || 0);
    if (!points[ai] || !points[bi]) continue;
    var a = displayXyz(points[ai], 1.0);
    var b = displayXyz(points[bi], 1.0);
    setCell(matrix, idx, a[0], a[1], a[2]);
    idx += 1;
    setCell(matrix, idx, b[0], b[1], b[2]);
    idx += 1;
  }
}

function writeHeatTexture(points) {
  if (!heatTextureMatrix) return;
  heatTextureMatrix.clear();
  var projected = projectHeatPoints(points || []);
  var sigma = Math.max(4, heatTextureWidth * 0.055);
  var sigma2 = sigma * sigma * 2;
  for (var y = 0; y < heatTextureHeight; y += heatPixelBlock) {
    var sampleY = y + heatPixelBlock * 0.5;
    for (var x = 0; x < heatTextureWidth; x += heatPixelBlock) {
      var sampleX = x + heatPixelBlock * 0.5;
      var heatValue = heatAtMap(sampleX, sampleY, projected, sigma2);
      var rgba = thermalColor(heatValue);
      fillHeatBlock(x, y, rgba);
    }
  }
}

function projectHeatPoints(points) {
  var out = [];
  for (var i = 0; i < points.length; i += 1) {
    var p = points[i] || {};
    out.push({
      x: ((wrapDeg(Number(p.azimuth || 0)) + 180) / 360) * heatTextureWidth,
      y: (0.5 - Math.sin(degToRad(Number(p.elevation || 0))) * 0.5) * heatTextureHeight
    });
  }
  return out;
}

function heatAtMap(x, y, projected, sigma2) {
  var energy = 0.02;
  for (var i = 0; i < projected.length; i += 1) {
    var dx = x - projected[i].x;
    if (Math.abs(dx) > heatTextureWidth * 0.5) dx -= (dx < 0 ? -1 : 1) * heatTextureWidth;
    var dy = y - projected[i].y;
    var d2 = dx * dx + dy * dy;
    energy += Math.exp(-d2 / sigma2);
  }
  return clamp(energy / 1.28, 0, 1);
}

function frameAt(t) {
  var frames = score.frames || [];
  if (!frames.length) return { t: t, geometry: score.source || [] };
  if (frames.length === 1 || t <= Number(frames[0].t || 0)) return frames[0];
  var last = frames[frames.length - 1];
  if (t >= Number(last.t || 1)) return last;
  var lo = 0;
  var hi = frames.length - 1;
  while (hi - lo > 1) {
    var mid = Math.floor((lo + hi) / 2);
    if (Number(frames[mid].t || 0) <= t) lo = mid;
    else hi = mid;
  }
  return interpolateFrame(frames[lo], frames[hi], t);
}

function interpolateFrame(a, b, t) {
  var ta = Number(a.t || 0);
  var tb = Number(b.t || 1);
  var u = tb === ta ? 0 : clamp((t - ta) / (tb - ta), 0, 1);
  var ga = a.geometry || [];
  var gb = b.geometry || [];
  var n = Math.max(ga.length, gb.length);
  var geometry = [];
  for (var i = 0; i < n; i += 1) {
    var pa = ga[i] || gb[i] || {};
    var pb = gb[i] || ga[i] || {};
    geometry.push({
      channel: Number(pa.channel || pb.channel || i + 1),
      azimuth: angularLerp(Number(pa.azimuth || 0), Number(pb.azimuth || 0), u),
      elevation: lerp(Number(pa.elevation || 0), Number(pb.elevation || 0), u),
      radius: lerp(Number(pa.radius || 1), Number(pb.radius || 1), u)
    });
  }
  return { t: t, geometry: geometry };
}

function normalizeScore(data) {
  var timeline = data.timeline || {};
  var frames = Array.isArray(timeline.frames) ? timeline.frames : (Array.isArray(data.frames) ? data.frames : []);
  var durationSafe = Math.max(0.001, Number(timeline.duration_seconds || data.duration || 1));
  return {
    name: String(data.name || "Displacement Score"),
    duration: durationSafe,
    source: normalizePoints(data.source || []),
    scenes: normalizeScenes(data.scenes || [], durationSafe),
    frames: normalizeFrames(frames),
    edges: normalizeEdges(data.polygon && data.polygon.edges ? data.polygon.edges : [])
  };
}

function normalizePoints(points) {
  var out = [];
  for (var i = 0; i < points.length; i += 1) {
    var p = points[i] || {};
    out.push({
      channel: Number(p.channel || i + 1),
      azimuth: wrapDeg(Number(p.azimuth || 0)),
      elevation: clamp(Number(p.elevation || 0), -90, 90),
      radius: clamp(Number(p.radius || 1), 0.001, 8)
    });
  }
  return out;
}

function normalizeFrames(frames) {
  var out = [];
  for (var i = 0; i < frames.length; i += 1) {
    out.push({
      t: clamp(Number(frames[i].t || 0), 0, 1),
      geometry: normalizePoints(frames[i].geometry || [])
    });
  }
  out.sort(function(a, b) { return a.t - b.t; });
  return out;
}

function normalizeScenes(scenes, durationSafe) {
  var out = [];
  for (var i = 0; i < scenes.length; i += 1) {
    var scene = scenes[i] || {};
    var t = scene.t !== undefined ? Number(scene.t) : Number(scene.time || 0) / durationSafe;
    out.push({
      name: String(scene.name || String.fromCharCode(65 + i)),
      t: clamp(t, 0, 1)
    });
  }
  out.sort(function(a, b) { return a.t - b.t; });
  return out;
}

function normalizeEdges(edges) {
  var out = [];
  if (!Array.isArray(edges)) return out;
  for (var i = 0; i < edges.length; i += 1) {
    var edge = edges[i];
    if (!Array.isArray(edge) || edge.length < 2) continue;
    var a = Math.round(Number(edge[0]));
    var b = Math.round(Number(edge[1]));
    if (isNaN(a) || isNaN(b) || a === b) continue;
    out.push([a, b]);
  }
  return out;
}

function fallbackEdges(points) {
  var edges = [];
  for (var i = 0; i < points.length; i += 1) {
    edges.push([i, (i + 1) % points.length]);
  }
  return edges;
}

function aedToXyz(point, scale) {
  var radius = Number(point.radius || 1) * (scale || 1);
  var az = degToRad(Number(point.azimuth || 0));
  var el = degToRad(Number(point.elevation || 0));
  var ce = Math.cos(el);
  var x = -Math.sin(az) * ce * radius;
  var y = Math.sin(el) * radius;
  var z = -Math.cos(az) * ce * radius;
  return [x, y, z];
}

function displayXyz(point, scale) {
  if (geometryMode === "map") return petersMapXyz(point, scale);
  return aedToXyz(point, scale);
}

function petersMapXyz(point, scale) {
  var az = wrapDeg(Number(point.azimuth || 0));
  var el = clamp(Number(point.elevation || 0), -90, 90);
  var height = 1.72 * (scale || 1);
  var aspect = heatTextureHeight > 0 ? heatTextureWidth / heatTextureHeight : 3.2;
  var width = height * aspect;
  var x = ((az + 180) / 360 - 0.5) * width;
  var y = Math.sin(degToRad(el)) * height * 0.5;
  return [x, y, 0];
}

function setCell(matrix, index, x, y, z) {
  try {
    matrix.setcell(index, "val", Number(x || 0), Number(y || 0), Number(z || 0));
  } catch (error) {
    try {
      matrix.setcell1d(index, [Number(x || 0), Number(y || 0), Number(z || 0)]);
    } catch (ignored) {
      // Jitter JS APIs have differed across Max generations; keep the player alive.
    }
  }
}

function setCell2d(matrix, x, y, r, g, b, a) {
  try {
    matrix.setcell(x, y, "val", Math.round(a), Math.round(r), Math.round(g), Math.round(b));
  } catch (error) {
    try {
      matrix.setcell2d(x, y, [Math.round(a), Math.round(r), Math.round(g), Math.round(b)]);
    } catch (ignored) {
      // Keep playback running if a Max/Jitter version names this setter differently.
    }
  }
}

function fillHeatBlock(x, y, rgba) {
  var xmax = Math.min(heatTextureWidth, x + heatPixelBlock);
  var ymax = Math.min(heatTextureHeight, y + heatPixelBlock);
  for (var yy = y; yy < ymax; yy += 1) {
    for (var xx = x; xx < xmax; xx += 1) {
      setCell2d(heatTextureMatrix, xx, yy, rgba[0], rgba[1], rgba[2], rgba[3]);
    }
  }
}

function thermalColor(v) {
  v = clamp(v, 0, 1);
  var stops = [
    [0.00, 32, 55, 116],
    [0.25, 43, 148, 186],
    [0.50, 240, 219, 85],
    [0.73, 229, 93, 47],
    [1.00, 210, 24, 24]
  ];
  for (var i = 0; i < stops.length - 1; i += 1) {
    var a = stops[i];
    var b = stops[i + 1];
    if (v >= a[0] && v <= b[0]) {
      var u = (v - a[0]) / Math.max(0.000001, b[0] - a[0]);
      return [
        lerp(a[1], b[1], u),
        lerp(a[2], b[2], u),
        lerp(a[3], b[3], u),
        255
      ];
    }
  }
  return [210, 24, 24, 255];
}

function playbackDuration() {
  return loop && palindrome ? duration * 2 : duration;
}

function cyclePosition() {
  if (!(loop && palindrome)) return position;
  return direction < 0 ? duration + (duration - position) : position;
}

function setCyclePosition(v) {
  if (loop && palindrome) {
    var cycle = playbackDuration();
    var c = clamp(Number(v || 0), 0, cycle);
    if (c <= duration) {
      position = c;
      direction = 1;
    } else {
      position = cycle - c;
      direction = -1;
    }
  } else {
    position = clamp(Number(v || 0), 0, duration);
    if (position <= 0) direction = 1;
    else if (position >= duration) direction = -1;
  }
}

function readTextFile(path) {
  var file = new File(path, "read");
  if (!file || !file.isopen) throw new Error("could not open file");
  var chunks = [];
  while (file.position < file.eof) {
    var chunk = file.readstring(8192);
    if (!chunk) break;
    chunks.push(chunk);
  }
  file.close();
  return chunks.join("");
}

function normalizePath(path) {
  if (path && path.join) path = path.join(" ");
  path = String(path || "").replace(/^\"|\"$/g, "");
  if (path.indexOf("file://") === 0) path = decodeURI(path.slice(7));
  return path;
}

function nowMs() {
  return Date.now ? Date.now() : new Date().getTime();
}

function safeNumber(v, fallback) {
  var n = Number(v);
  return isNaN(n) ? fallback : n;
}

function clamp(v, lo, hi) {
  if (lo === undefined) lo = 0;
  if (hi === undefined) hi = 1;
  v = Number(v);
  if (isNaN(v)) v = 0;
  return Math.max(lo, Math.min(hi, v));
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

function angularLerp(a, b, t) {
  var delta = ((b - a + 180) % 360 + 360) % 360 - 180;
  return wrapDeg(a + delta * t);
}

function wrapDeg(v) {
  var x = ((v + 180) % 360 + 360) % 360 - 180;
  return x === -180 ? 180 : x;
}

function degToRad(v) {
  return Number(v || 0) * Math.PI / 180;
}

function status(message) {
  outlet(6, "jitter_status", String(message));
}
