autowatch = 1;
inlets = 1;
outlets = 4;

var spatialScore = null;
var duration = 1;
var position = 0;
var playing = false;
var lastMs = 0;
var loop = true;
var palindromeEnabled = false;
var direction = 1;
var selectedGroup = "all";
var outputMode = "icst";

function read(path) {
  var resolved = normalizePath(path);
  if (!resolved) {
    status("no JSON path");
    return;
  }
  try {
    var text = readTextFile(resolved);
    loadjson(text, resolved);
  } catch (error) {
    status("read failed: " + error.message);
  }
}

function loadjson(text, label) {
  try {
    var data = JSON.parse(String(text || ""));
    if (!data || data.format !== "s3g_mc_mover_v1") {
      throw new Error("not a Spatial Score JSON file");
    }
    spatialScore = data;
    duration = Math.max(0.001, Number(data.duration || 1));
    position = 0;
    direction = 1;
    lastMs = nowMs();
    status("loaded " + (label || "Spatial Score JSON") + " | " + sourceCount() + " sources | " + duration.toFixed(3) + "s");
    meta();
    outputFrame();
  } catch (error) {
    status("JSON parse failed: " + error.message);
  }
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
  lastMs = nowMs();
  outputFrame();
}

function tick() {
  if (!spatialScore) return;
  var t = nowMs();
  if (playing) {
    advance(Math.max(0, t - lastMs) / 1000);
  }
  lastMs = t;
  outputFrame();
}

function advance(delta) {
  if (duration <= 0) {
    position = 0;
    return;
  }
  position += delta * direction;
  if (loop && palindromeEnabled) {
    while (position > duration || position < 0) {
      if (position > duration) {
        position = duration - (position - duration);
        direction = -1;
      } else if (position < 0) {
        position = -position;
        direction = 1;
      }
    }
  } else if (loop) {
    position = ((position % duration) + duration) % duration;
  } else {
    if (position >= duration) {
      position = duration;
      playing = false;
      status("done");
    } else if (position <= 0) {
      position = 0;
      playing = false;
      status("done");
    }
  }
}

function seconds(v) {
  setCyclePosition(Number(v || 0));
  lastMs = nowMs();
  outputFrame();
}

function norm(v) {
  setCyclePosition(clamp(Number(v || 0), 0, 1) * playbackDuration());
  lastMs = nowMs();
  outputFrame();
}

function setduration(v) {
  duration = Math.max(0.001, Number(v || duration || 1));
  if (spatialScore) spatialScore.duration = duration;
  status("duration " + duration.toFixed(3));
}

function setloop(v) {
  loop = Number(v) !== 0;
  if (!loop) palindromeEnabled = false;
  status("loop " + (loop ? "on" : "off") + (loop && palindromeEnabled ? " palindrome" : ""));
  meta();
}

function setpalindrome(v) {
  palindromeEnabled = Number(v) !== 0;
  if (palindromeEnabled) loop = true;
  status("palindrome " + (palindromeEnabled ? "on" : "off"));
  meta();
}

function palindrome(v) {
  setpalindrome(v);
}

function playbackmode(name) {
  var mode = String(name || "loop").toLowerCase();
  if (mode === "pal" || mode === "palindrome" || mode === "backforth") {
    loop = true;
    palindromeEnabled = true;
  } else if (mode === "once" || mode === "one" || mode === "oneshot") {
    loop = false;
    palindromeEnabled = false;
    if (position >= duration) {
      position = 0;
      direction = 1;
    }
  } else {
    loop = true;
    palindromeEnabled = false;
  }
  if (position <= 0) direction = 1;
  else if (position >= duration) direction = palindromeEnabled ? -1 : 1;
  status("playback " + (loop ? (palindromeEnabled ? "palindrome" : "loop") : "once"));
  meta();
}

function playbackDuration() {
  return loop && palindromeEnabled ? duration * 2 : duration;
}

function cyclePosition() {
  if (!(loop && palindromeEnabled)) return position;
  return direction < 0 ? duration + (duration - position) : position;
}

function setCyclePosition(v) {
  if (duration <= 0) {
    position = 0;
    direction = 1;
    return;
  }
  if (loop && palindromeEnabled) {
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

function group(v) {
  if (String(v) === "all") selectedGroup = "all";
  else selectedGroup = Math.max(1, Math.round(Number(v || 1)));
  status("group " + selectedGroup);
  outputFrame();
}

function mode(name) {
  outputMode = String(name || "generic").toLowerCase();
  status("mode " + outputMode);
}

function meta() {
  if (!spatialScore) return;
  outlet(2, ["duration", Number(playbackDuration().toFixed(6))]);
  outlet(2, ["source_duration", Number(duration.toFixed(6))]);
  outlet(2, ["point_rate", Number(spatialScore.point_rate || 0)]);
  outlet(2, ["groups", (spatialScore.banks || []).length]);
  outlet(2, ["sources", sourceCount()]);
  outlet(2, ["order", Number(spatialScore.order || 3)]);
}

function outputFrame() {
  if (!spatialScore) return;
  var t = duration > 0 ? clamp(position / duration, 0, 1) : 0;
  var cycle = playbackDuration();
  var cpos = cyclePosition();
  var cnorm = cycle > 0 ? clamp(cpos / cycle, 0, 1) : 0;
  var banks = spatialScore.banks || [];
  var globalIndex = 1;
  for (var bi = 0; bi < banks.length; bi += 1) {
    var bank = banks[bi];
    var bankId = Number(bank.bank || bi + 1);
    var includeBank = selectedGroup === "all" || selectedGroup === bankId;
    var automation = bank.automation || [];
    for (var si = 0; si < automation.length; si += 1) {
      var lane = automation[si];
      if (includeBank) outputSource(globalIndex, bankId, lane, t);
      globalIndex += 1;
    }
  }
  outlet(1, [
    "position", Number(cpos.toFixed(6)),
    "norm", Number(cnorm.toFixed(6)),
    "source", Number(position.toFixed(6)),
    "source_norm", Number(t.toFixed(6)),
    "direction", direction
  ]);
}

function outputSource(globalIndex, bankId, lane, t) {
  var point = sampleLane(lane, t);
  var sourceId = Number(lane.source || 1);
  var enabled = lane.enabled !== false && point.gain > 0;
  var az = Number(point.azimuth || 0);
  var el = Number(point.elevation || 0);
  var dist = Number(point.distance || 1);
  var gain = enabled ? Number(point.gain || 0) : 0;

  if (outputMode === "icst") {
    if (enabled) outlet(0, ["aed", globalIndex, az, el, dist]);
  } else {
    outlet(0, ["source", globalIndex, "group", bankId, "source", sourceId, "azimuth", az, "elevation", el, "distance", dist, "gain", gain]);
  }
}

function sampleLane(lane, t) {
  var points = lane.points || [];
  if (!points.length) {
    return { t: t, azimuth: 0, elevation: 0, distance: 1, gain: lane.enabled === false ? 0 : 1 };
  }
  if (points.length === 1 || t <= Number(points[0].t || 0)) return points[0];
  var last = points[points.length - 1];
  if (t >= Number(last.t || 1)) return last;
  var lo = 0;
  var hi = points.length - 1;
  while (hi - lo > 1) {
    var mid = Math.floor((lo + hi) / 2);
    if (Number(points[mid].t || 0) <= t) lo = mid;
    else hi = mid;
  }
  var a = points[lo];
  var b = points[hi];
  var ta = Number(a.t || 0);
  var tb = Number(b.t || 1);
  var u = tb === ta ? 0 : clamp((t - ta) / (tb - ta), 0, 1);
  return {
    t: t,
    azimuth: angularLerp(Number(a.azimuth || 0), Number(b.azimuth || 0), u),
    elevation: lerp(Number(a.elevation || 0), Number(b.elevation || 0), u),
    distance: lerp(Number(a.distance || 1), Number(b.distance || 1), u),
    gain: lerp(Number(a.gain || 0), Number(b.gain || 0), u)
  };
}

function sourceCount() {
  if (!spatialScore || !spatialScore.banks) return 0;
  var count = 0;
  for (var i = 0; i < spatialScore.banks.length; i += 1) {
    count += (spatialScore.banks[i].automation || []).length;
  }
  return count;
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

function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, v));
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

function wrapDeg(v) {
  var x = ((v + 180) % 360 + 360) % 360 - 180;
  return x === -180 ? 180 : x;
}

function angularLerp(a, b, t) {
  return wrapDeg(a + wrapDeg(b - a) * t);
}

function status(message) {
  outlet(3, String(message));
}
