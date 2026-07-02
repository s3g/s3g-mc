autowatch = 1;
inlets = 1;
outlets = 5;

var automationScore = null;
var duration = 1;
var position = 0;
var playing = false;
var lastMs = 0;
var loop = true;
var palindromeEnabled = false;
var direction = 1;
var selectedLane = "all";
var outputMode = "osc";
var lastSectionIndex = -1;

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
    if (!data || (data.format !== "s3g-mc-automation-score" && data.format !== "s3g-mc-automation-field")) {
      throw new Error("not an Automation Score JSON file");
    }
    automationScore = normalizeScore(data);
    duration = Math.max(0.001, Number(automationScore.duration || 1));
    position = 0;
    direction = 1;
    lastSectionIndex = -1;
    lastMs = nowMs();
    status("loaded " + (label || "Automation Score JSON") + " | " + laneCount() + " lanes | " + duration.toFixed(3) + "s");
    emitScore();
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
  lastSectionIndex = -1;
  lastMs = nowMs();
  outputFrame();
}

function tick() {
  if (!automationScore) return;
  var t = nowMs();
  if (playing) advance(Math.max(0, t - lastMs) / 1000);
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
  if (automationScore) automationScore.duration = duration;
  status("duration " + duration.toFixed(3));
  meta();
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

function lane(v) {
  if (String(v) === "all") selectedLane = "all";
  else selectedLane = Math.max(1, Math.round(Number(v || 1)));
  status("lane " + selectedLane);
  outputFrame();
}

function mode(name) {
  outputMode = String(name || "generic").toLowerCase();
  status("mode " + outputMode);
}

function meta() {
  if (!automationScore) return;
  outlet(2, ["duration", Number(playbackDuration().toFixed(6))]);
  outlet(2, ["source_duration", Number(duration.toFixed(6))]);
  outlet(2, ["point_rate", Number(automationScore.point_rate || 0)]);
  outlet(2, ["lanes", laneCount()]);
  outlet(2, ["sections", (automationScore.sections || []).length]);
}

function emitScore() {
  if (!automationScore) return;
  outlet(2, ["scorejson", JSON.stringify(automationScore)]);
}

function outputFrame() {
  if (!automationScore) return;
  var sourceT = duration > 0 ? clamp(position / duration, 0, 1) : 0;
  var cycle = playbackDuration();
  var cpos = cyclePosition();
  var cnorm = cycle > 0 ? clamp(cpos / cycle, 0, 1) : 0;
  outputSection(sourceT);
  var lanes = automationScore.lanes || [];
  for (var i = 0; i < lanes.length; i += 1) {
    var laneData = lanes[i];
    var laneIndex = Number(laneData.index || i + 1);
    if (selectedLane !== "all" && selectedLane !== laneIndex) continue;
    outputLane(laneIndex, laneData, sourceT);
  }
  outlet(1, [
    "position", Number(cpos.toFixed(6)),
    "norm", Number(cnorm.toFixed(6)),
    "source", Number(position.toFixed(6)),
    "source_norm", Number(sourceT.toFixed(6)),
    "direction", direction
  ]);
  outlet(2, [
    "viewclock",
    Number(cpos.toFixed(6)),
    Number(cnorm.toFixed(6)),
    Number(position.toFixed(6)),
    Number(sourceT.toFixed(6))
  ]);
}

function outputLane(index, laneData, t) {
  var enabled = laneData.enabled !== false;
  var value = enabled ? laneValue(laneData, t) : 0;
  var name = laneData.name || ("Lane " + index);
  if (outputMode === "osc") {
    outlet(0, ["/automation/lane", index, Number(value.toFixed(6))]);
  } else if (outputMode === "cc") {
    outlet(0, ["cc", index, Math.round(clamp(value, 0, 1) * 127)]);
  } else if (outputMode === "value") {
    outlet(0, ["value", index, Number(value.toFixed(6))]);
  } else {
    outlet(0, ["lane", index, "name", name, "value", Number(value.toFixed(6)), "enabled", enabled ? 1 : 0]);
  }
}

function outputSection(t) {
  var sections = automationScore.sections || [];
  if (!sections.length) return;
  var current = -1;
  for (var i = 0; i < sections.length; i += 1) {
    if (t + 0.000001 >= Number(sections[i].t || 0)) current = i;
  }
  if (current < 0) current = 0;
  if (current !== lastSectionIndex) {
    lastSectionIndex = current;
    var section = sections[current];
    var index = Number(section.index || current + 1);
    var name = section.name || ("Section " + (current + 1));
    var time = Number((section.time || section.t * duration || 0).toFixed(6));
    if (outputMode === "osc") {
      outlet(3, ["/automation/marker", index, name, time, "bang"]);
    } else {
      outlet(3, ["section", index, name, time]);
    }
  }
}

function laneValue(laneData, t) {
  var points = laneData.points || [];
  if (!points.length) return 0;
  if (points.length === 1 || t <= Number(points[0].t || 0)) return clamp(Number(points[0].v || 0), 0, 1);
  var last = points[points.length - 1];
  if (t >= Number(last.t || 1)) return clamp(Number(last.v || 0), 0, 1);
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
  var curve = String(laneData.curve || "linear").toLowerCase();
  if (curve === "step") u = 0;
  else if (curve === "smooth") u = u * u * (3 - 2 * u);
  return clamp(lerp(Number(a.v || 0), Number(b.v || 0), u), 0, 1);
}

function normalizeScore(data) {
  var score = {
    duration: Number(data.duration) || 1,
    point_rate: Number(data.point_rate || 0),
    sections: [],
    lanes: []
  };
  var durationSafe = Math.max(0.001, score.duration);
  var rawSections = data.sections || data.markers || [];
  for (var si = 0; si < rawSections.length; si += 1) {
    var section = rawSections[si] || {};
    var t = section.t !== undefined ? Number(section.t) : Number(section.time || 0) / durationSafe;
    score.sections.push({
      index: Number(section.index || si + 1),
      name: String(section.name || ("Section " + (si + 1))),
      t: clamp(t, 0, 1),
      time: clamp(t, 0, 1) * score.duration
    });
  }
  score.sections.sort(function(a, b) { return a.t - b.t; });
  var rawLanes = data.lanes || [];
  for (var li = 0; li < rawLanes.length; li += 1) {
    var laneData = rawLanes[li] || {};
    var lanePoints = laneData.points || [{ t: 0, v: 0 }];
    var points = [];
    for (var pi = 0; pi < lanePoints.length; pi += 1) {
      points.push({
        t: clamp(Number(lanePoints[pi].t || 0), 0, 1),
        v: clamp(Number(lanePoints[pi].v || 0), 0, 1)
      });
    }
    points.sort(function(a, b) { return a.t - b.t; });
    score.lanes.push({
      index: Number(laneData.index || li + 1),
      name: String(laneData.name || ("Lane " + (li + 1))),
      enabled: laneData.enabled !== false,
      curve: String(laneData.curve || "linear"),
      points: points
    });
  }
  return score;
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

function laneCount() {
  return automationScore && automationScore.lanes ? automationScore.lanes.length : 0;
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
  if (lo === undefined) lo = 0;
  if (hi === undefined) hi = 1;
  return Math.max(lo, Math.min(hi, v));
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

function status(message) {
  outlet(4, String(message));
}
