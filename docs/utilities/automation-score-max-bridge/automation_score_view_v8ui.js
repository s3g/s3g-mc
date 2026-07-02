autowatch = 1;
inlets = 1;
outlets = 1;

mgraphics.init();
mgraphics.relative_coords = 0;
mgraphics.autofill = 0;

var score = null;
var playNorm = 0;
var playSeconds = 0;
var sourceNorm = 0;
var mode = "lanes";
var showMarkers = true;

var C = {
  bg: [0.055, 0.055, 0.055, 1],
  panel: [0.09, 0.09, 0.09, 1],
  field: [0.025, 0.03, 0.03, 1],
  line: [0.25, 0.25, 0.25, 1],
  soft: [0.15, 0.15, 0.15, 1],
  text: [0.82, 0.82, 0.82, 1],
  muted: [0.56, 0.56, 0.56, 1],
  cyan: [0.35, 0.66, 0.78, 1],
  amber: [0.85, 0.64, 0.29, 1],
  play: [0.95, 0.95, 0.95, 0.92]
};

function paint() {
  var w = box.rect[2] - box.rect[0];
  var h = box.rect[3] - box.rect[1];
  clear(w, h);
  drawFrame(w, h);
  if (!score) {
    drawEmpty(w, h);
    return;
  }
  if (mode === "overlap") drawOverlap(w, h);
  else drawLanes(w, h);
  drawMarkers(w, h);
  drawCursor(w, h);
  drawStatus(w, h);
}

function clear(w, h) {
  rgba(C.bg);
  mgraphics.rectangle(0, 0, w, h);
  mgraphics.fill();
}

function drawFrame(w, h) {
  rgba(C.panel);
  mgraphics.rectangle(0.5, 0.5, w - 1, h - 1);
  mgraphics.fill();
  rgba(C.line);
  mgraphics.set_line_width(1);
  mgraphics.rectangle(0.5, 0.5, w - 1, h - 1);
  mgraphics.stroke();
  setFont(10);
  rgba(C.text);
  mgraphics.move_to(10, 17);
  mgraphics.show_text("AUTOMATION SCORE");
  rgba(C.muted);
  mgraphics.move_to(w - 112, 17);
  mgraphics.show_text(mode.toUpperCase());
}

function drawEmpty(w, h) {
  rgba(C.field);
  mgraphics.rectangle(10.5, 29.5, w - 21, h - 50);
  mgraphics.fill();
  rgba(C.line);
  mgraphics.rectangle(10.5, 29.5, w - 21, h - 50);
  mgraphics.stroke();
  setFont(11);
  rgba(C.muted);
  mgraphics.move_to(22, Math.max(54, h * 0.5));
  mgraphics.show_text("Drop Automation Score JSON onto the patch.");
}

function drawLanes(w, h) {
  var lanes = score.lanes || [];
  var area = graphArea(w, h);
  rgba(C.field);
  mgraphics.rectangle(area.x, area.y, area.w, area.h);
  mgraphics.fill();
  rgba(C.line);
  mgraphics.rectangle(area.x + 0.5, area.y + 0.5, area.w - 1, area.h - 1);
  mgraphics.stroke();

  var labelW = Math.min(84, Math.max(52, area.w * 0.18));
  var plotX = area.x + labelW;
  var plotW = area.w - labelW;
  var gap = 4;
  var laneH = (area.h - gap * Math.max(0, lanes.length - 1)) / Math.max(1, lanes.length);

  for (var i = 0; i < lanes.length; i += 1) {
    var y = area.y + i * (laneH + gap);
    var lane = lanes[i];
    var col = parseColor(lane.color, i);
    rgba(i % 2 ? [0.075, 0.075, 0.075, 1] : [0.065, 0.065, 0.065, 1]);
    mgraphics.rectangle(area.x, y, area.w, laneH);
    mgraphics.fill();
    rgba([col[0], col[1], col[2], lane.enabled === false ? 0.18 : 0.78]);
    mgraphics.rectangle(area.x + 6, y + 6, 5, Math.max(4, laneH - 12));
    mgraphics.fill();
    setFont(9);
    rgba(lane.enabled === false ? C.muted : C.text);
    mgraphics.move_to(area.x + 15, y + Math.min(16, laneH - 4));
    mgraphics.show_text(shortName(lane.name || ("Lane " + (i + 1)), 12));
    drawLaneCurve(lane, plotX + 4, y + 4, plotW - 8, Math.max(6, laneH - 8), col, lane.enabled !== false);
  }
}

function drawOverlap(w, h) {
  var lanes = score.lanes || [];
  var area = graphArea(w, h);
  rgba(C.field);
  mgraphics.rectangle(area.x, area.y, area.w, area.h);
  mgraphics.fill();
  drawGrid(area);
  for (var i = 0; i < lanes.length; i += 1) {
    var lane = lanes[i];
    var col = parseColor(lane.color, i);
    drawLaneCurve(lane, area.x + 8, area.y + 8, area.w - 16, area.h - 16, col, lane.enabled !== false);
  }
  rgba(C.line);
  mgraphics.rectangle(area.x + 0.5, area.y + 0.5, area.w - 1, area.h - 1);
  mgraphics.stroke();
}

function drawLaneCurve(lane, x, y, w, h, col, enabled) {
  var points = lane.points || [];
  if (!points.length) return;
  mgraphics.set_line_width(enabled ? 1.75 : 1);
  rgba([col[0], col[1], col[2], enabled ? 0.86 : 0.28]);
  for (var i = 0; i < points.length; i += 1) {
    var px = x + clamp(points[i].t, 0, 1) * w;
    var py = y + (1 - clamp(points[i].v, 0, 1)) * h;
    if (i === 0) mgraphics.move_to(px, py);
    else mgraphics.line_to(px, py);
  }
  mgraphics.stroke();
  for (var j = 0; j < points.length; j += 1) {
    var dx = x + clamp(points[j].t, 0, 1) * w;
    var dy = y + (1 - clamp(points[j].v, 0, 1)) * h;
    rgba([col[0], col[1], col[2], enabled ? 0.95 : 0.32]);
    mgraphics.rectangle(dx - 2, dy - 2, 4, 4);
    mgraphics.fill();
  }
}

function drawGrid(area) {
  rgba(C.soft);
  mgraphics.set_line_width(1);
  for (var i = 1; i < 4; i += 1) {
    var y = area.y + area.h * i / 4;
    mgraphics.move_to(area.x, y);
    mgraphics.line_to(area.x + area.w, y);
    mgraphics.stroke();
  }
}

function drawMarkers(w, h) {
  if (!showMarkers || !score) return;
  var sections = score.sections || [];
  var area = graphArea(w, h);
  setFont(8);
  for (var i = 0; i < sections.length; i += 1) {
    var x = area.x + clamp(sections[i].t, 0, 1) * area.w;
    rgba(C.amber);
    mgraphics.set_line_width(1);
    mgraphics.move_to(x, area.y);
    mgraphics.line_to(x, area.y + area.h);
    mgraphics.stroke();
    rgba([C.amber[0], C.amber[1], C.amber[2], 0.22]);
    mgraphics.rectangle(x - 2, area.y, 4, area.h);
    mgraphics.fill();
    rgba(C.amber);
    mgraphics.move_to(x + 4, area.y + 10);
    mgraphics.show_text(shortName(sections[i].name || ("S" + (i + 1)), 8));
  }
}

function drawCursor(w, h) {
  var area = graphArea(w, h);
  var x = area.x + clamp(sourceNorm, 0, 1) * area.w;
  rgba([C.play[0], C.play[1], C.play[2], 0.95]);
  mgraphics.set_line_width(2);
  mgraphics.move_to(x, area.y);
  mgraphics.line_to(x, area.y + area.h);
  mgraphics.stroke();
  rgba([C.cyan[0], C.cyan[1], C.cyan[2], 0.32]);
  mgraphics.rectangle(area.x, area.y + area.h + 7, clamp(playNorm, 0, 1) * area.w, 5);
  mgraphics.fill();
  rgba(C.line);
  mgraphics.rectangle(area.x, area.y + area.h + 7, area.w, 5);
  mgraphics.stroke();
}

function drawStatus(w, h) {
  var lanes = score ? (score.lanes || []).length : 0;
  var sections = score ? (score.sections || []).length : 0;
  setFont(9);
  rgba(C.muted);
  mgraphics.move_to(10, h - 12);
  mgraphics.show_text(playSeconds.toFixed(2) + "s / " + ((score && score.duration) ? score.duration.toFixed(2) : "0.00") + "s");
  mgraphics.move_to(w - 145, h - 12);
  mgraphics.show_text(lanes + " lanes  " + sections + " markers");
}

function graphArea(w, h) {
  return { x: 10.5, y: 29.5, w: w - 21, h: Math.max(40, h - 58) };
}

function scorejson() {
  var text = arrayfromargs(arguments).join(" ");
  try {
    score = JSON.parse(text);
    if (!score.duration) score.duration = 1;
    playNorm = 0;
    sourceNorm = 0;
    playSeconds = 0;
    mgraphics.redraw();
  } catch (error) {
    post("Automation Score view JSON failed: " + error.message + "\n");
  }
}

function position(pos) {
  var args = [];
  for (var i = 0; i < arguments.length; i += 1) args.push(arguments[i]);
  playSeconds = safeNumber(pos, playSeconds);
  for (var j = 1; j < args.length - 1; j += 2) {
    var key = String(args[j]);
    var value = args[j + 1];
    if (key === "norm") playNorm = safeNumber(value, playNorm);
    else if (key === "source") playSeconds = safeNumber(value, playSeconds);
    else if (key === "source_norm") sourceNorm = safeNumber(value, sourceNorm);
  }
  if (args.length < 3) {
    playNorm = score && score.duration > 0 ? clamp(playSeconds / score.duration, 0, 1) : 0;
    sourceNorm = playNorm;
  }
  mgraphics.redraw();
}

function viewclock(cycleSeconds, cycleNorm, sourceSeconds, sourceNormValue) {
  playSeconds = safeNumber(sourceSeconds, safeNumber(cycleSeconds, playSeconds));
  playNorm = safeNumber(cycleNorm, playNorm);
  sourceNorm = safeNumber(sourceNormValue, sourceNorm);
  mgraphics.redraw();
}

function duration(v) {
  if (score) score.duration = Math.max(0.001, safeNumber(v, score.duration || 1));
  mgraphics.redraw();
}

function source_duration(v) {
  duration(v);
}

function point_rate() {}
function lanes() {}
function sections() {}

function section() {
  mgraphics.redraw();
}

function view(name) {
  mode = String(name || "lanes").toLowerCase() === "overlap" ? "overlap" : "lanes";
  mgraphics.redraw();
}

function markers(v) {
  showMarkers = Number(v) !== 0;
  mgraphics.redraw();
}

function bang() {
  mgraphics.redraw();
}

function onclick(x, y) {
  var w = box.rect[2] - box.rect[0];
  if (y < 25 && x > w - 124) {
    mode = mode === "lanes" ? "overlap" : "lanes";
    mgraphics.redraw();
  }
}

function setFont(size) {
  mgraphics.select_font_face("Arial");
  mgraphics.set_font_size(size);
}

function rgba(c) {
  mgraphics.set_source_rgba(c[0], c[1], c[2], c.length > 3 ? c[3] : 1);
}

function parseColor(hex, index) {
  var fallback = [
    [0.35, 0.66, 0.78],
    [0.85, 0.64, 0.29],
    [0.49, 0.65, 0.35],
    [0.78, 0.41, 0.37],
    [0.62, 0.50, 0.78],
    [0.62, 0.70, 0.72]
  ][index % 6];
  if (!hex || String(hex).charAt(0) !== "#") return fallback;
  var s = String(hex).replace("#", "");
  if (s.length !== 6) return fallback;
  var r = parseInt(s.slice(0, 2), 16);
  var g = parseInt(s.slice(2, 4), 16);
  var b = parseInt(s.slice(4, 6), 16);
  if (isNaN(r) || isNaN(g) || isNaN(b)) return fallback;
  return [r / 255, g / 255, b / 255];
}

function shortName(text, maxLen) {
  text = String(text || "");
  return text.length <= maxLen ? text : text.slice(0, Math.max(1, maxLen - 1)) + ".";
}

function clamp(v, lo, hi) {
  v = Number(v);
  if (isNaN(v)) v = 0;
  return Math.max(lo, Math.min(hi, v));
}

function safeNumber(v, fallback) {
  var n = Number(v);
  return isNaN(n) ? fallback : n;
}
