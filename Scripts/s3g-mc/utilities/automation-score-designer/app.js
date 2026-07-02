const canvas = document.getElementById("field");
const ctx = canvas.getContext("2d");
const playbar = document.getElementById("playbar");
const barCtx = playbar.getContext("2d");
const heatmap = document.getElementById("heatmap");
const heatCtx = heatmap.getContext("2d");
const spaceCanvas = document.getElementById("spaceView");
const spaceCtx = spaceCanvas.getContext("2d");

const palette = ["#5aa8c7", "#d8a24a", "#ff7f6e", "#8fcf7a", "#c18bd8", "#69b6a7", "#d66f9b", "#b6c05b", "#7aa4e8", "#e0a16f", "#8ecfbc", "#d0d0d0"];

const state = {
  duration: 16,
  pointRate: 16,
  lanes: [],
  sections: [],
  selectedLane: 0,
  selectedPoint: -1,
  selectedSection: 0,
  viewMode: "overlay",
  aggregateMode: "mean",
  projectionMode: "line",
  showSamples: false,
  playing: false,
  playStart: 0,
  playT: 0,
  spaceOpen: false,
  spaceDrag: null,
  cameraAz: -35,
  cameraEl: 32,
  cameraZoom: 1,
  drag: null,
};

const el = {
  play: document.getElementById("play"),
  stop: document.getElementById("stop"),
  openSpaceView: document.getElementById("openSpaceView"),
  closeSpaceView: document.getElementById("closeSpaceView"),
  spacePlay: document.getElementById("spacePlay"),
  spaceStop: document.getElementById("spaceStop"),
  spaceModal: document.getElementById("spaceModal"),
  importJson: document.getElementById("importJson"),
  exportJson: document.getElementById("exportJson"),
  jsonFile: document.getElementById("jsonFile"),
  addLane: document.getElementById("addLane"),
  deleteLane: document.getElementById("deleteLane"),
  laneList: document.getElementById("laneList"),
  addSection: document.getElementById("addSection"),
  deleteSection: document.getElementById("deleteSection"),
  sectionList: document.getElementById("sectionList"),
  sectionName: document.getElementById("sectionName"),
  sectionTime: document.getElementById("sectionTime"),
  sectionToPlayhead: document.getElementById("sectionToPlayhead"),
  laneName: document.getElementById("laneName"),
  laneEnabled: document.getElementById("laneEnabled"),
  laneColor: document.getElementById("laneColor"),
  laneCurve: document.getElementById("laneCurve"),
  addPoint: document.getElementById("addPoint"),
  clearLane: document.getElementById("clearLane"),
  shape: document.getElementById("shape"),
  amount: document.getElementById("amount"),
  amountValue: document.getElementById("amountValue"),
  pointCount: document.getElementById("pointCount"),
  pointValue: document.getElementById("pointValue"),
  seed: document.getElementById("seed"),
  generateLane: document.getElementById("generateLane"),
  generateAll: document.getElementById("generateAll"),
  relationshipTarget: document.getElementById("relationshipTarget"),
  relationshipStrength: document.getElementById("relationshipStrength"),
  relationshipStrengthValue: document.getElementById("relationshipStrengthValue"),
  relationshipMotion: document.getElementById("relationshipMotion"),
  relationshipMotionValue: document.getElementById("relationshipMotionValue"),
  relationshipCenter: document.getElementById("relationshipCenter"),
  relationshipCenterValue: document.getElementById("relationshipCenterValue"),
  generateRelationship: document.getElementById("generateRelationship"),
  deriveMethod: document.getElementById("deriveMethod"),
  deriveAmount: document.getElementById("deriveAmount"),
  deriveAmountValue: document.getElementById("deriveAmountValue"),
  deriveCenter: document.getElementById("deriveCenter"),
  deriveCenterValue: document.getElementById("deriveCenterValue"),
  deriveDestination: document.getElementById("deriveDestination"),
  deriveLane: document.getElementById("deriveLane"),
  duration: document.getElementById("duration"),
  durationValue: document.getElementById("durationValue"),
  pointRate: document.getElementById("pointRate"),
  rateValue: document.getElementById("rateValue"),
  viewMode: document.getElementById("viewMode"),
  aggregateMode: document.getElementById("aggregateMode"),
  projectionMode: document.getElementById("projectionMode"),
  showSamples: document.getElementById("showSamples"),
  cameraAz: document.getElementById("cameraAz"),
  cameraEl: document.getElementById("cameraEl"),
  cameraZoom: document.getElementById("cameraZoom"),
  cameraAzValue: document.getElementById("cameraAzValue"),
  cameraElValue: document.getElementById("cameraElValue"),
  cameraZoomValue: document.getElementById("cameraZoomValue"),
  reset: document.getElementById("reset"),
  timeReadout: document.getElementById("timeReadout"),
  laneReadout: document.getElementById("laneReadout"),
  valueReadout: document.getElementById("valueReadout"),
};

function clamp(v, lo = 0, hi = 1) {
  return Math.max(lo, Math.min(hi, v));
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

function smooth(t) {
  return t * t * (3 - 2 * t);
}

function updateRangeFill(input) {
  const min = Number(input.min || 0);
  const max = Number(input.max || 1);
  const value = Number(input.value || 0);
  const fill = max === min ? 0 : clamp((value - min) / (max - min), 0, 1) * 100;
  input.style.setProperty("--fill", `${fill.toFixed(2)}%`);
}

function updateAllRangeFills() {
  document.querySelectorAll('input[type="range"]').forEach(updateRangeFill);
}

function enhanceCustomSelects(root = document) {
  if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches) return;
  let open = null;
  const close = () => {
    if (!open) return;
    open.wrapper.classList.remove("open");
    open.menu.remove();
    open = null;
  };
  const refresh = (select) => {
    if (!select._customButton) return;
    select._customButton.textContent = select.selectedOptions[0]?.textContent || "Select";
    select._customButton.disabled = select.disabled;
  };
  const positionMenu = (button, menu) => {
    const rect = button.getBoundingClientRect();
    menu.style.left = `${Math.round(rect.left)}px`;
    menu.style.top = `${Math.round(rect.bottom + 2)}px`;
    menu.style.width = `${Math.round(rect.width)}px`;
  };
  root.querySelectorAll("select").forEach((select) => {
    if (select.dataset.customEnhanced === "1") return;
    select.dataset.customEnhanced = "1";
    const wrapper = document.createElement("span");
    wrapper.className = "custom-select";
    const button = document.createElement("button");
    button.type = "button";
    button.className = "custom-select-button";
    select.classList.add("native-select-hidden");
    select.parentNode.insertBefore(wrapper, select.nextSibling);
    wrapper.appendChild(button);
    select._customButton = button;
    const openMenu = () => {
      if (select.disabled) return;
      if (open?.select === select) {
        close();
        return;
      }
      close();
      const menu = document.createElement("div");
      menu.className = "custom-select-menu";
      Array.from(select.options).forEach((option) => {
        const item = document.createElement("div");
        item.className = `custom-select-option${option.selected ? " active" : ""}`;
        item.textContent = option.textContent;
        item.addEventListener("pointerdown", (event) => {
          event.preventDefault();
          select.value = option.value;
          refresh(select);
          select.dispatchEvent(new Event("input", { bubbles: true }));
          select.dispatchEvent(new Event("change", { bubbles: true }));
          close();
        });
        menu.appendChild(item);
      });
      document.body.appendChild(menu);
      positionMenu(button, menu);
      wrapper.classList.add("open");
      open = { select, wrapper, menu, button };
    };
    button.addEventListener("click", openMenu);
    button.addEventListener("keydown", (event) => {
      if (!["Enter", " ", "ArrowDown"].includes(event.key)) return;
      event.preventDefault();
      openMenu();
    });
    select.addEventListener("input", () => refresh(select));
    select.addEventListener("change", () => refresh(select));
    refresh(select);
  });
  document.addEventListener("pointerdown", (event) => {
    if (!open) return;
    if (open.wrapper.contains(event.target) || open.menu.contains(event.target)) return;
    close();
  });
  window.addEventListener("resize", close);
  setInterval(() => root.querySelectorAll("select").forEach(refresh), 350);
}

function rng(seed) {
  let s = Math.max(1, Math.floor(seed)) >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

function newLane(index) {
  const base = 0.2 + (index % 5) * 0.14;
  return {
    name: `Lane ${index + 1}`,
    enabled: true,
    color: palette[index % palette.length],
    curve: "linear",
    points: [
      { t: 0, v: clamp(base) },
      { t: 1, v: clamp(1 - base * 0.7) },
    ],
  };
}

function resetField() {
  state.lanes = [];
  for (let i = 0; i < 8; i++) state.lanes.push(newLane(i));
  state.sections = [
    { name: "A", t: 0 },
    { name: "B", t: 0.5 },
  ];
  state.selectedLane = 0;
  state.selectedPoint = -1;
  state.selectedSection = 0;
  syncControls();
}

function selectedLane() {
  return state.lanes[state.selectedLane] || state.lanes[0];
}

function sortPoints(lane) {
  lane.points.sort((a, b) => a.t - b.t);
  if (!lane.points.length) lane.points.push({ t: 0, v: 0.5 }, { t: 1, v: 0.5 });
  lane.points[0].t = 0;
  lane.points[lane.points.length - 1].t = 1;
}

function sortSections() {
  state.sections = state.sections
    .map((section, index) => ({
      name: section.name || `Section ${index + 1}`,
      t: clamp(Number(section.t) || 0),
    }))
    .sort((a, b) => a.t - b.t);
  state.selectedSection = Math.max(0, Math.min(state.selectedSection, Math.max(0, state.sections.length - 1)));
}

function selectedSection() {
  if (!state.sections.length) {
    state.sections.push({ name: "A", t: state.playT });
    state.selectedSection = 0;
  }
  return state.sections[state.selectedSection] || state.sections[0];
}

function drawSectionMarkers(g, x0, y0, width, height, options = {}) {
  if (!state.sections.length) return;
  g.save();
  g.font = "10px Menlo, Monaco, monospace";
  state.sections.forEach((section, index) => {
    const x = x0 + clamp(section.t) * width;
    const active = index === state.selectedSection;
    g.strokeStyle = active ? "rgba(240, 192, 103, 0.95)" : "rgba(216, 162, 74, 0.62)";
    g.lineWidth = active ? 1.8 : 1;
    g.beginPath();
    g.moveTo(x, y0);
    g.lineTo(x, y0 + height);
    g.stroke();
    if (!options.noLabel) {
      const label = section.name || `S${index + 1}`;
      g.fillStyle = active ? "#f0c067" : "#b98c46";
      g.fillText(label, Math.min(x + 4, x0 + width - 48), y0 + 12);
    }
  });
  g.restore();
}

function drawSectionRail() {
  const r = markerRailRect();
  ctx.save();
  ctx.fillStyle = "#10100d";
  ctx.strokeStyle = "#3d3320";
  ctx.lineWidth = 1;
  ctx.fillRect(r.x, r.y, r.w, r.h);
  ctx.strokeRect(r.x, r.y, r.w, r.h);
  ctx.fillStyle = "#8d7a50";
  ctx.font = "10px Menlo, Monaco, monospace";
  ctx.fillText("markers", r.x + 6, r.y + 14);
  state.sections.forEach((section, index) => {
    const x = r.x + clamp(section.t) * r.w;
    const active = index === state.selectedSection;
    ctx.fillStyle = active ? "#f0c067" : "#b98c46";
    ctx.strokeStyle = "#050505";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x, r.y + 3);
    ctx.lineTo(x + 5, r.y + 11);
    ctx.lineTo(x, r.y + 19);
    ctx.lineTo(x - 5, r.y + 11);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = active ? "#f0c067" : "#9f8046";
    ctx.fillText(section.name || `S${index + 1}`, Math.min(x + 7, r.x + r.w - 42), r.y + 14);
  });
  ctx.restore();
}

function laneValue(lane, t) {
  const pts = lane.points;
  if (!pts.length) return 0;
  if (t <= pts[0].t) return pts[0].v;
  for (let i = 0; i < pts.length - 1; i++) {
    const a = pts[i];
    const b = pts[i + 1];
    if (t <= b.t) {
      if (lane.curve === "step") return a.v;
      const span = Math.max(0.000001, b.t - a.t);
      const u = clamp((t - a.t) / span);
      return lerp(a.v, b.v, lane.curve === "smooth" ? smooth(u) : u);
    }
  }
  return pts[pts.length - 1].v;
}

function makeSamples(lane) {
  const count = Math.max(2, Math.round(state.duration * state.pointRate));
  const out = [];
  for (let i = 0; i <= count; i++) {
    const t = i / count;
    out.push({ t: +t.toFixed(6), v: +laneValue(lane, t).toFixed(6) });
  }
  return out;
}

function enabledLanes() {
  return state.lanes.filter(lane => lane.enabled);
}

function aggregateAt(t) {
  const lanes = enabledLanes();
  if (!lanes.length) return { mean: 0, median: 0, min: 0, max: 0, range: 0, sum: 0, density: 0, variance: 0, stddev: 0, delta: 0, pairwise: 0, synchrony: 1 };
  let sum = 0;
  let min = 1;
  let max = 0;
  let active = 0;
  const values = [];
  for (const lane of lanes) {
    const v = laneValue(lane, t);
    values.push(v);
    sum += v;
    min = Math.min(min, v);
    max = Math.max(max, v);
    if (v > 0.5) active += 1;
  }
  values.sort((a, b) => a - b);
  const mean = sum / lanes.length;
  const mid = Math.floor(values.length / 2);
  const median = values.length % 2 ? values[mid] : (values[mid - 1] + values[mid]) * 0.5;
  let variance = 0;
  for (const v of values) variance += Math.pow(v - mean, 2);
  variance /= lanes.length;
  const dt = 1 / Math.max(32, Math.round(state.duration * state.pointRate));
  let delta = 0;
  for (const lane of lanes) {
    delta += Math.abs(laneValue(lane, clamp(t + dt)) - laneValue(lane, clamp(t - dt)));
  }
  delta = clamp(delta / lanes.length / (dt * 2));
  let pairTotal = 0;
  let pairCount = 0;
  for (let i = 0; i < values.length; i++) {
    for (let j = i + 1; j < values.length; j++) {
      pairTotal += Math.abs(values[i] - values[j]);
      pairCount += 1;
    }
  }
  const pairwise = pairCount > 0 ? pairTotal / pairCount : 0;
  return {
    mean,
    median,
    min,
    max,
    range: max - min,
    sum: clamp(sum / lanes.length),
    density: active / lanes.length,
    variance: clamp(variance),
    stddev: clamp(Math.sqrt(variance)),
    delta,
    pairwise,
    synchrony: 1 - pairwise,
  };
}

function aggregateValueAt(t) {
  const a = aggregateAt(t);
  if (state.aggregateMode === "sum") return a.sum;
  if (state.aggregateMode === "density") return a.density;
  if (state.aggregateMode === "median") return a.median;
  if (state.aggregateMode === "range") return a.range;
  if (state.aggregateMode === "stddev") return a.stddev;
  if (state.aggregateMode === "variance") return a.variance;
  if (state.aggregateMode === "delta") return a.delta;
  if (state.aggregateMode === "pairwise") return a.pairwise;
  if (state.aggregateMode === "synchrony") return a.synchrony;
  return a.mean;
}

function aggregateLabel() {
  return {
    mean: "mean / spread",
    median: "median",
    range: "range max-min",
    stddev: "standard deviation",
    variance: "variance",
    sum: "normalized sum",
    density: "activity density",
    delta: "change rate",
    pairwise: "pairwise distance",
    synchrony: "synchrony",
  }[state.aggregateMode] || state.aggregateMode;
}

function fieldRect() {
  const w = canvas.clientWidth;
  const h = canvas.clientHeight;
  return { x: 52, y: 58, w: Math.max(120, w - 84), h: Math.max(120, h - 94) };
}

function markerRailRect() {
  const r = fieldRect();
  return { x: r.x, y: 28, w: r.w, h: 22 };
}

function timelineGeometry(width) {
  const r = fieldRect();
  const fieldWidth = canvas.clientWidth || width;
  const ratio = width / Math.max(1, fieldWidth);
  return {
    x: Math.round(r.x * ratio),
    w: Math.max(100, Math.round(r.w * ratio)),
  };
}

function laneRect(index) {
  const r = fieldRect();
  if (state.viewMode !== "stacked") return r;
  const gap = 8;
  const laneH = (r.h - gap * (state.lanes.length - 1)) / Math.max(1, state.lanes.length);
  return { x: r.x, y: r.y + index * (laneH + gap), w: r.w, h: Math.max(24, laneH) };
}

function pointToScreen(point, index) {
  const r = laneRect(index);
  return { x: r.x + point.t * r.w, y: r.y + (1 - point.v) * r.h };
}

function screenToPoint(x, y, index) {
  const r = laneRect(index);
  return { t: clamp((x - r.x) / r.w), v: clamp(1 - (y - r.y) / r.h) };
}

function drawGrid(r, label) {
  ctx.strokeStyle = "#252525";
  ctx.lineWidth = 1;
  for (let i = 0; i <= 8; i++) {
    const x = r.x + (i / 8) * r.w;
    ctx.beginPath();
    ctx.moveTo(x, r.y);
    ctx.lineTo(x, r.y + r.h);
    ctx.stroke();
  }
  for (let i = 0; i <= 4; i++) {
    const y = r.y + (i / 4) * r.h;
    ctx.beginPath();
    ctx.moveTo(r.x, y);
    ctx.lineTo(r.x + r.w, y);
    ctx.stroke();
  }
  ctx.strokeStyle = "#444";
  ctx.strokeRect(r.x, r.y, r.w, r.h);
  ctx.fillStyle = "#8d8d8d";
  ctx.font = "11px Menlo, Monaco, monospace";
  if (label) ctx.fillText(label, r.x + 6, r.y + 14);
}

function drawLane(lane, index) {
  const r = laneRect(index);
  const alpha = lane.enabled ? 1 : 0.25;
  if (state.viewMode === "stacked" || index === 0) drawGrid(r, state.viewMode === "stacked" ? lane.name : "");
  ctx.strokeStyle = lane.color;
  ctx.globalAlpha = alpha;
  ctx.lineWidth = index === state.selectedLane ? 2.4 : 1.35;
  ctx.beginPath();
  const steps = Math.max(64, Math.floor(r.w / 5));
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const x = r.x + t * r.w;
    const y = r.y + (1 - laneValue(lane, t)) * r.h;
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }
  ctx.stroke();
  if (state.showSamples) {
    ctx.fillStyle = lane.color;
    for (const s of makeSamples(lane)) {
      const x = r.x + s.t * r.w;
      const y = r.y + (1 - s.v) * r.h;
      ctx.fillRect(x - 1, y - 1, 2, 2);
    }
  }
  lane.points.forEach((p, pi) => {
    const sp = pointToScreen(p, index);
    ctx.fillStyle = pi === state.selectedPoint && index === state.selectedLane ? "#fff" : lane.color;
    ctx.strokeStyle = "#050505";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.rect(sp.x - 4, sp.y - 4, 8, 8);
    ctx.fill();
    ctx.stroke();
  });
  ctx.globalAlpha = 1;
}

function draw() {
  const dpr = window.devicePixelRatio || 1;
  const w = canvas.clientWidth;
  const h = canvas.clientHeight;
  if (canvas.width !== Math.floor(w * dpr) || canvas.height !== Math.floor(h * dpr)) {
    canvas.width = Math.floor(w * dpr);
    canvas.height = Math.floor(h * dpr);
  }
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = "#050707";
  ctx.fillRect(0, 0, w, h);
  drawSectionRail();
  if (state.viewMode === "overlay") drawGrid(fieldRect(), "");
  state.lanes.forEach((lane, index) => drawLane(lane, index));
  const r = fieldRect();
  drawSectionMarkers(ctx, r.x, r.y, r.w, r.h, { noLabel: state.viewMode === "stacked" });
  const playX = r.x + state.playT * r.w;
  ctx.strokeStyle = "#d8a24a";
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(playX, r.y);
  ctx.lineTo(playX, r.y + r.h);
  ctx.stroke();
  ctx.fillStyle = "#9a9a9a";
  ctx.font = "11px Menlo, Monaco, monospace";
  ctx.fillText("time", r.x + r.w - 28, r.y + r.h + 22);
  ctx.save();
  ctx.translate(18, r.y + r.h * 0.5 + 16);
  ctx.rotate(-Math.PI / 2);
  ctx.fillText("value", 0, 0);
  ctx.restore();
}

function drawPlaybar() {
  const dpr = window.devicePixelRatio || 1;
  const w = playbar.clientWidth;
  const h = playbar.clientHeight;
  if (playbar.width !== Math.floor(w * dpr) || playbar.height !== Math.floor(h * dpr)) {
    playbar.width = Math.floor(w * dpr);
    playbar.height = Math.floor(h * dpr);
  }
  barCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
  barCtx.clearRect(0, 0, w, h);
  barCtx.fillStyle = "#070808";
  barCtx.fillRect(0, 0, w, h);

  const geo = timelineGeometry(w);
  const pad = geo.x;
  const top = 10;
  const graphH = 58;
  const graphW = Math.max(100, Math.min(geo.w, w - pad - 10));
  const steps = Math.max(96, Math.floor(graphW / 3));

  barCtx.strokeStyle = "#242424";
  barCtx.lineWidth = 1;
  for (let i = 0; i <= 8; i++) {
    const x = pad + (i / 8) * graphW;
    barCtx.beginPath();
    barCtx.moveTo(x, top);
    barCtx.lineTo(x, h - 12);
    barCtx.stroke();
  }

  if (state.projectionMode === "space") {
    drawCompactSpaceProjection(pad, top, graphW, h - 20);
  } else if (state.projectionMode === "ribbons") {
    drawRibbonProjection(pad, top, graphW, h - 20);
  } else {
    drawAggregateLine(pad, top, graphW, graphH, steps);
  }
  drawSectionMarkers(barCtx, pad, top, graphW, graphH, { noLabel: false });

  const playX = pad + state.playT * graphW;
  barCtx.strokeStyle = "#f0c067";
  barCtx.lineWidth = 2;
  barCtx.beginPath();
  barCtx.moveTo(playX, 6);
  barCtx.lineTo(playX, h - 7);
  barCtx.stroke();
  barCtx.fillStyle = "#d0d0d0";
  barCtx.font = "11px Menlo, Monaco, monospace";
  barCtx.fillText(`${(state.playT * state.duration).toFixed(2)}s`, Math.min(w - 76, playX + 6), 18);
  barCtx.fillStyle = "#888";
  const now = aggregateAt(state.playT);
  barCtx.fillText(`${state.projectionMode} | ${aggregateLabel()} ${aggregateValueAt(state.playT).toFixed(3)} | sd ${now.stddev.toFixed(3)} | pair ${now.pairwise.toFixed(3)}`, pad, h - 4);
}

function drawHeatmapWindow() {
  const dpr = window.devicePixelRatio || 1;
  const w = heatmap.clientWidth;
  const h = heatmap.clientHeight;
  if (heatmap.width !== Math.floor(w * dpr) || heatmap.height !== Math.floor(h * dpr)) {
    heatmap.width = Math.floor(w * dpr);
    heatmap.height = Math.floor(h * dpr);
  }
  heatCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
  heatCtx.clearRect(0, 0, w, h);
  heatCtx.fillStyle = "#070808";
  heatCtx.fillRect(0, 0, w, h);
  const geo = timelineGeometry(w);
  const pad = geo.x;
  const graphW = Math.max(100, Math.min(geo.w, w - pad - 10));
  const steps = Math.max(96, Math.floor(graphW / 3));
  drawLaneHeatmap(heatCtx, pad, 10, graphW, h - 22, steps, { compact: false, labelOutside: true });
  drawSectionMarkers(heatCtx, pad, 10, graphW, h - 22, { noLabel: true });
  heatCtx.fillStyle = "#888";
  heatCtx.font = "10px Menlo, Monaco, monospace";
  heatCtx.fillText("lane heatmap", pad, h - 5);
}

function drawAggregateLine(x0, y0, width, height, steps) {
  if (state.aggregateMode === "mean") {
    barCtx.fillStyle = "rgba(90, 168, 199, 0.28)";
    barCtx.beginPath();
    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      const a = aggregateAt(t);
      const x = x0 + t * width;
      const y = y0 + (1 - a.max) * height;
      if (i === 0) barCtx.moveTo(x, y);
      else barCtx.lineTo(x, y);
    }
    for (let i = steps; i >= 0; i--) {
      const t = i / steps;
      const a = aggregateAt(t);
      const x = x0 + t * width;
      const y = y0 + (1 - a.min) * height;
      barCtx.lineTo(x, y);
    }
    barCtx.closePath();
    barCtx.fill();
    barCtx.strokeStyle = "rgba(90, 168, 199, 0.55)";
    barCtx.lineWidth = 1;
    barCtx.stroke();
  }

  barCtx.strokeStyle = state.aggregateMode === "density" || state.aggregateMode === "delta" || state.aggregateMode === "pairwise" ? "#d8a24a" : "#5aa8c7";
  barCtx.lineWidth = 1.7;
  barCtx.beginPath();
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const value = aggregateValueAt(t);
    const x = x0 + t * width;
    const y = y0 + (1 - value) * height;
    if (i === 0) barCtx.moveTo(x, y);
    else barCtx.lineTo(x, y);
  }
  barCtx.stroke();

}

function drawRibbonProjection(x0, y0, width, height) {
  const lanes = state.lanes;
  const enabled = lanes.filter(lane => lane.enabled);
  const n = Math.max(1, lanes.length);
  const depthX = Math.min(72, width * 0.13);
  const depthY = Math.min(24, height * 0.28);
  const baseY = y0 + height - 18;
  const valueH = Math.max(24, height - depthY - 24);
  const steps = Math.max(40, Math.floor(width / 12));

  barCtx.strokeStyle = "#323232";
  barCtx.lineWidth = 1;
  barCtx.beginPath();
  barCtx.moveTo(x0, baseY);
  barCtx.lineTo(x0 + width - depthX, baseY);
  barCtx.lineTo(x0 + width, baseY - depthY);
  barCtx.moveTo(x0, baseY);
  barCtx.lineTo(x0, baseY - valueH);
  barCtx.moveTo(x0, baseY);
  barCtx.lineTo(x0 + depthX, baseY - depthY);
  barCtx.stroke();

  for (let li = lanes.length - 1; li >= 0; li--) {
    const lane = lanes[li];
    const depth = n <= 1 ? 0 : li / (n - 1);
    const dx = depth * depthX;
    const dy = depth * depthY;
    barCtx.globalAlpha = lane.enabled ? 0.9 : 0.18;
    barCtx.strokeStyle = lane.color;
    barCtx.lineWidth = li === state.selectedLane ? 2.2 : 1.25;
    barCtx.beginPath();
    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      const v = laneValue(lane, t);
      const x = x0 + dx + t * (width - depthX);
      const y = baseY - dy - v * valueH;
      if (i === 0) barCtx.moveTo(x, y);
      else barCtx.lineTo(x, y);
    }
    barCtx.stroke();
  }
  barCtx.globalAlpha = 1;

  const active = enabled.length ? enabled.map(lane => laneValue(lane, state.playT)) : [0];
  const min = Math.min(...active);
  const max = Math.max(...active);
  barCtx.fillStyle = "rgba(90,168,199,0.08)";
  const playX = x0 + state.playT * (width - depthX);
  barCtx.fillRect(playX - 1, baseY - depthY - max * valueH, 3, Math.max(2, (max - min) * valueH));
}

function projectCompact3(x, y, z, originX, originY, scaleX, scaleY, depthX, depthY) {
  return {
    x: originX + x * scaleX + z * depthX,
    y: originY - y * scaleY - z * depthY,
  };
}

function drawCompactSpaceProjection(x0, y0, width, height) {
  const lanes = state.lanes;
  const originX = x0 + 18;
  const originY = y0 + height - 16;
  const scaleX = width - 108;
  const scaleY = Math.max(34, height - 42);
  const depthX = 76;
  const depthY = 28;
  const steps = 40;

  barCtx.strokeStyle = "#343434";
  barCtx.lineWidth = 1;
  const p000 = projectCompact3(0, 0, 0, originX, originY, scaleX, scaleY, depthX, depthY);
  const p100 = projectCompact3(1, 0, 0, originX, originY, scaleX, scaleY, depthX, depthY);
  const p010 = projectCompact3(0, 1, 0, originX, originY, scaleX, scaleY, depthX, depthY);
  const p001 = projectCompact3(0, 0, 1, originX, originY, scaleX, scaleY, depthX, depthY);
  const p101 = projectCompact3(1, 0, 1, originX, originY, scaleX, scaleY, depthX, depthY);
  const p011 = projectCompact3(0, 1, 1, originX, originY, scaleX, scaleY, depthX, depthY);
  const p110 = projectCompact3(1, 1, 0, originX, originY, scaleX, scaleY, depthX, depthY);
  const p111 = projectCompact3(1, 1, 1, originX, originY, scaleX, scaleY, depthX, depthY);
  barCtx.beginPath();
  [[p000, p100], [p000, p010], [p000, p001], [p100, p110], [p100, p101], [p010, p110], [p010, p011], [p001, p101], [p001, p011], [p111, p101], [p111, p110], [p111, p011]].forEach(([a, b]) => {
    barCtx.moveTo(a.x, a.y);
    barCtx.lineTo(b.x, b.y);
  });
  barCtx.stroke();

  for (let li = lanes.length - 1; li >= 0; li--) {
    const lane = lanes[li];
    const z = lanes.length <= 1 ? 0 : li / (lanes.length - 1);
    barCtx.globalAlpha = lane.enabled ? 0.88 : 0.18;
    barCtx.strokeStyle = lane.color;
    barCtx.lineWidth = li === state.selectedLane ? 2.1 : 1.15;
    barCtx.beginPath();
    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      const p = projectCompact3(t, laneValue(lane, t), z, originX, originY, scaleX, scaleY, depthX, depthY);
      if (i === 0) barCtx.moveTo(p.x, p.y);
      else barCtx.lineTo(p.x, p.y);
    }
    barCtx.stroke();
    const now = projectCompact3(state.playT, laneValue(lane, state.playT), z, originX, originY, scaleX, scaleY, depthX, depthY);
    barCtx.fillStyle = lane.color;
    barCtx.fillRect(now.x - 3, now.y - 3, 6, 6);
  }
  barCtx.globalAlpha = 1;
}

function project3(x, y, z, originX, originY, scale, camera) {
  const az = (camera.az ?? state.cameraAz) * Math.PI / 180;
  const elv = (camera.el ?? state.cameraEl) * Math.PI / 180;
  const zoom = camera.zoom ?? state.cameraZoom;
  const px = (x - 0.5) * 2;
  const py = (y - 0.5) * 2;
  const pz = (z - 0.5) * 2;
  const ca = Math.cos(az);
  const sa = Math.sin(az);
  const ce = Math.cos(elv);
  const se = Math.sin(elv);
  const x1 = px * ca - pz * sa;
  const z1 = px * sa + pz * ca;
  const y1 = py;
  const y2 = y1 * ce - z1 * se;
  const z2 = y1 * se + z1 * ce;
  return {
    x: originX + x1 * scale * zoom,
    y: originY - y2 * scale * zoom,
    depth: z2,
  };
}

function drawSpaceProjection(g, x0, y0, width, height, options = {}) {
  const lanes = state.lanes;
  const originX = x0 + width * 0.5;
  const originY = y0 + height * 0.54;
  const scale = Math.min(width, height) * (options.compact ? 0.29 : 0.34);
  const steps = options.compact ? 40 : 96;
  const camera = { az: state.cameraAz, el: state.cameraEl, zoom: state.cameraZoom };

  g.strokeStyle = "#343434";
  g.lineWidth = 1;
  const p000 = project3(0, 0, 0, originX, originY, scale, camera);
  const p100 = project3(1, 0, 0, originX, originY, scale, camera);
  const p010 = project3(0, 1, 0, originX, originY, scale, camera);
  const p001 = project3(0, 0, 1, originX, originY, scale, camera);
  const p101 = project3(1, 0, 1, originX, originY, scale, camera);
  const p011 = project3(0, 1, 1, originX, originY, scale, camera);
  const p110 = project3(1, 1, 0, originX, originY, scale, camera);
  const p111 = project3(1, 1, 1, originX, originY, scale, camera);
  g.beginPath();
  [[p000, p100], [p000, p010], [p000, p001], [p100, p110], [p100, p101], [p010, p110], [p010, p011], [p001, p101], [p001, p011], [p111, p101], [p111, p110], [p111, p011]].forEach(([a, b]) => {
    g.moveTo(a.x, a.y);
    g.lineTo(b.x, b.y);
  });
  g.stroke();

  if (options.labels !== false) {
    g.fillStyle = "#9a9a9a";
    g.font = "11px Menlo, Monaco, monospace";
    g.fillText("time", p100.x - 22, p100.y + 15);
    g.fillText("value", p010.x - 8, p010.y - 7);
    g.fillText("lanes", p001.x + 6, p001.y);
  }

  for (let li = lanes.length - 1; li >= 0; li--) {
    const lane = lanes[li];
    const z = lanes.length <= 1 ? 0 : li / (lanes.length - 1);
    g.globalAlpha = lane.enabled ? 0.88 : 0.18;
    g.strokeStyle = lane.color;
    g.lineWidth = li === state.selectedLane ? (options.compact ? 2.1 : 3) : (options.compact ? 1.15 : 1.7);
    g.beginPath();
    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      const p = project3(t, laneValue(lane, t), z, originX, originY, scale, camera);
      if (i === 0) g.moveTo(p.x, p.y);
      else g.lineTo(p.x, p.y);
    }
    g.stroke();
    const now = project3(state.playT, laneValue(lane, state.playT), z, originX, originY, scale, camera);
    g.fillStyle = lane.color;
    const s = options.compact ? 6 : 9;
    g.fillRect(now.x - s * 0.5, now.y - s * 0.5, s, s);
  }
  g.globalAlpha = 1;
}

function drawSpacePopup() {
  if (!state.spaceOpen) return;
  const dpr = window.devicePixelRatio || 1;
  const w = spaceCanvas.clientWidth;
  const h = spaceCanvas.clientHeight;
  if (spaceCanvas.width !== Math.floor(w * dpr) || spaceCanvas.height !== Math.floor(h * dpr)) {
    spaceCanvas.width = Math.floor(w * dpr);
    spaceCanvas.height = Math.floor(h * dpr);
  }
  spaceCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
  spaceCtx.clearRect(0, 0, w, h);
  spaceCtx.fillStyle = "#050707";
  spaceCtx.fillRect(0, 0, w, h);
  const matrixSize = Math.min(220, Math.max(120, Math.min(w * 0.22, h * 0.42)));
  const matrixGap = 24;
  const projectionW = Math.max(260, w - matrixSize - matrixGap - 68);
  drawSpaceProjection(spaceCtx, 34, 28, projectionW, h - 62, { labels: true, compact: false });
  drawRelationMatrix(spaceCtx, 34 + projectionW + matrixGap, Math.max(48, (h - matrixSize) * 0.5), matrixSize, { label: "lane relationship" });
  const now = aggregateAt(state.playT);
  spaceCtx.fillStyle = "#9a9a9a";
  spaceCtx.font = "12px Menlo, Monaco, monospace";
  spaceCtx.fillText(`${(state.playT * state.duration).toFixed(2)}s / ${state.duration.toFixed(2)}s | sd ${now.stddev.toFixed(3)} | pair ${now.pairwise.toFixed(3)}`, 18, h - 18);
}

function drawLaneHeatmap(g, x0, y0, width, height, steps, options = {}) {
  const lanes = state.lanes;
  const labelW = options.labelOutside ? 0 : options.compact ? 28 : 42;
  const mapX = x0 + labelW;
  const mapW = Math.max(40, width - labelW);
  const laneH = Math.max(5, height / Math.max(1, lanes.length));
  g.strokeStyle = "#262626";
  g.lineWidth = 1;
  g.strokeRect(mapX, y0, mapW, laneH * lanes.length);
  lanes.forEach((lane, index) => {
    const y = y0 + index * laneH;
    const laneAlpha = lane.enabled ? 1 : 0.22;
    for (let i = 0; i < steps; i++) {
      const t = i / (steps - 1);
      const v = laneValue(lane, t);
      const dark = 16 + Math.round(v * 22);
      g.fillStyle = `rgb(${dark}, ${dark}, ${dark})`;
      g.fillRect(mapX + (i / steps) * mapW, y, Math.ceil(mapW / steps) + 1, Math.max(2, laneH - 1));
      g.fillStyle = hexToRgba(lane.color, (0.12 + v * 0.82) * laneAlpha);
      g.fillRect(mapX + (i / steps) * mapW, y, Math.ceil(mapW / steps) + 1, Math.max(2, laneH - 1));
    }
    g.fillStyle = lane.enabled ? "#b8b8b8" : "#666";
    g.font = "10px Menlo, Monaco, monospace";
    const labelX = options.labelOutside ? Math.max(4, x0 - 28) : x0 + 4;
    g.fillText(options.compact ? String(index + 1) : String(index + 1).padStart(2, "0"), labelX, y + Math.min(laneH - 2, 11));
    g.strokeStyle = "#1e1e1e";
    g.beginPath();
    g.moveTo(mapX, y + laneH);
    g.lineTo(mapX + mapW, y + laneH);
    g.stroke();
  });
  const playX = mapX + state.playT * mapW;
  g.fillStyle = "rgba(240, 192, 103, 0.22)";
  g.fillRect(playX - 2, y0, 4, laneH * lanes.length);
  g.strokeStyle = "#f0c067";
  g.beginPath();
  g.moveTo(playX, y0);
  g.lineTo(playX, y0 + laneH * lanes.length);
  g.stroke();
}

function drawRelationMatrix(g, x, y, size, options = {}) {
  const lanes = state.lanes.filter(lane => lane.enabled);
  const n = Math.max(1, lanes.length);
  const labelPad = options.labels === false ? 0 : 20;
  const gridSize = size - labelPad;
  const cell = gridSize / n;
  g.save();
  g.fillStyle = "#050707";
  g.fillRect(x, y, size, size);
  const gx = x + labelPad;
  const gy = y + labelPad;
  for (let row = 0; row < n; row++) {
    const rv = laneValue(lanes[row], state.playT);
    for (let col = 0; col < n; col++) {
      const cv = laneValue(lanes[col], state.playT);
      const similarity = 1 - Math.abs(rv - cv);
      const hue = similarity > 0.66 ? "#5aa8c7" : similarity > 0.33 ? "#d8a24a" : "#ff7f6e";
      g.fillStyle = hexToRgba(hue, 0.18 + similarity * 0.72);
      g.fillRect(gx + col * cell, gy + row * cell, Math.ceil(cell), Math.ceil(cell));
    }
  }
  if (labelPad > 0) {
    g.fillStyle = "#b8b8b8";
    g.font = "10px Menlo, Monaco, monospace";
    g.textAlign = "center";
    g.textBaseline = "middle";
    lanes.forEach((lane, index) => {
      const label = String(state.lanes.indexOf(lane) + 1);
      g.fillText(label, gx + index * cell + cell * 0.5, y + labelPad * 0.48);
      g.fillText(label, x + labelPad * 0.48, gy + index * cell + cell * 0.5);
    });
    g.textAlign = "left";
    g.textBaseline = "alphabetic";
  }
  g.strokeStyle = "#3d3d3d";
  g.lineWidth = 1;
  g.strokeRect(gx, gy, gridSize, gridSize);
  g.fillStyle = "#8a8a8a";
  g.font = options.large ? "11px Menlo, Monaco, monospace" : "10px Menlo, Monaco, monospace";
  g.fillText(options.label || "all lanes", x, y - 6);
  g.restore();
}

function hexToRgba(hex, alpha) {
  const clean = String(hex || "#ffffff").replace("#", "");
  const value = parseInt(clean.length === 3 ? clean.split("").map(c => c + c).join("") : clean, 16);
  const r = (value >> 16) & 255;
  const g = (value >> 8) & 255;
  const b = value & 255;
  return `rgba(${r}, ${g}, ${b}, ${clamp(alpha, 0, 1)})`;
}

function updateReadouts() {
  const lane = selectedLane();
  const tSec = state.playT * state.duration;
  el.timeReadout.textContent = `${tSec.toFixed(2)}s / ${state.duration.toFixed(2)}s`;
  el.laneReadout.textContent = `${lane.name} | ${lane.points.length} points`;
  el.valueReadout.textContent = `value ${laneValue(lane, state.playT).toFixed(3)}`;
}

function renderLoop(now) {
  if (state.playing) {
    const elapsed = (now - state.playStart) / 1000;
    state.playT = (elapsed % state.duration) / state.duration;
  }
  draw();
  drawPlaybar();
  drawHeatmapWindow();
  drawSpacePopup();
  updateReadouts();
  requestAnimationFrame(renderLoop);
}

function renderLaneList() {
  el.laneList.innerHTML = "";
  state.lanes.forEach((lane, index) => {
    const b = document.createElement("button");
    b.type = "button";
    b.className = `lane-button${index === state.selectedLane ? " active" : ""}`;
    b.innerHTML = `<span class="lane-swatch" style="background:${lane.color}"></span><span>${lane.name}</span><span>${lane.enabled ? "on" : "off"}</span>`;
    b.addEventListener("click", () => {
      state.selectedLane = index;
      state.selectedPoint = -1;
      syncControls();
    });
    el.laneList.appendChild(b);
  });
}

function renderSectionList() {
  el.sectionList.innerHTML = "";
  state.sections.forEach((section, index) => {
    const b = document.createElement("button");
    b.type = "button";
    b.className = `section-button${index === state.selectedSection ? " active" : ""}`;
    b.innerHTML = `<span>${section.name || `S${index + 1}`}</span><span>${(section.t * state.duration).toFixed(2)}s</span>`;
    b.addEventListener("click", () => {
      state.selectedSection = index;
      state.playT = clamp(section.t);
      syncControls();
    });
    el.sectionList.appendChild(b);
  });
}

function syncControls() {
  const lane = selectedLane();
  const section = selectedSection();
  el.laneName.value = lane.name;
  el.laneEnabled.checked = lane.enabled;
  el.laneColor.value = lane.color;
  el.laneCurve.value = lane.curve;
  el.duration.value = state.duration;
  el.durationValue.textContent = `${state.duration.toFixed(2)}s`;
  el.pointRate.value = state.pointRate;
  el.rateValue.textContent = `${state.pointRate}/s`;
  el.viewMode.value = state.viewMode;
  el.aggregateMode.value = state.aggregateMode;
  el.projectionMode.value = state.projectionMode;
  el.showSamples.checked = state.showSamples;
  el.cameraAz.value = state.cameraAz;
  el.cameraEl.value = state.cameraEl;
  el.cameraZoom.value = state.cameraZoom;
  el.cameraAzValue.textContent = `${Math.round(state.cameraAz)}`;
  el.cameraElValue.textContent = `${Math.round(state.cameraEl)}`;
  el.cameraZoomValue.textContent = state.cameraZoom.toFixed(2);
  el.amountValue.textContent = Number(el.amount.value).toFixed(2);
  el.pointValue.textContent = el.pointCount.value;
  el.relationshipStrengthValue.textContent = Number(el.relationshipStrength.value).toFixed(2);
  el.relationshipMotionValue.textContent = Number(el.relationshipMotion.value).toFixed(2);
  el.relationshipCenterValue.textContent = Number(el.relationshipCenter.value).toFixed(2);
  el.deriveAmountValue.textContent = Number(el.deriveAmount.value).toFixed(2);
  el.deriveCenterValue.textContent = Number(el.deriveCenter.value).toFixed(2);
  el.sectionName.value = section.name || "";
  el.sectionTime.value = (clamp(section.t) * state.duration).toFixed(3);
  updateAllRangeFills();
  renderLaneList();
  renderSectionList();
}

function syncSectionFields() {
  const section = selectedSection();
  el.sectionName.value = section.name || "";
  el.sectionTime.value = (clamp(section.t) * state.duration).toFixed(3);
}

function generateShape(laneIndex) {
  const lane = state.lanes[laneIndex];
  const shape = el.shape.value;
  const amount = Number(el.amount.value);
  const count = Number(el.pointCount.value);
  const random = rng(Number(el.seed.value) + laneIndex * 997);
  const phase = random();
  const tilt = (random() - 0.5) * 0.28 * amount;
  const curve = lerp(0.55, 2.4, random());
  const jitter = shape === "gate" || shape === "randomWalk" ? 0 : amount * 0.08;
  const pts = [];
  for (let i = 0; i < count; i++) {
    const rawT = count === 1 ? 0 : i / (count - 1);
    const t = i === 0 || i === count - 1 ? rawT : clamp(rawT + (random() - 0.5) * jitter);
    const shifted = (t + phase) % 1;
    let v = 0.5;
    if (shape === "ramp") v = lerp(1 - amount, amount, t) + tilt;
    else if (shape === "fadeIn") v = Math.pow(t, curve) * lerp(0.72, 1, amount) + tilt;
    else if (shape === "fadeOut") v = 1 - Math.pow(t, curve) * lerp(0.72, 1, amount) + tilt;
    else if (shape === "triangle") v = 1 - Math.abs((((t + phase * 0.35) % 1) * 2) - 1);
    else if (shape === "pulse") v = (Math.sin((t + phase + laneIndex * 0.03) * Math.PI * 2 * Math.max(1, Math.round(1 + amount * 7))) > lerp(0.5, -0.2, random())) ? 0.92 : 0.08;
    else if (shape === "wave") v = 0.5 + Math.sin((t + phase + laneIndex * 0.07) * Math.PI * 2 * (1 + amount * 5)) * lerp(0.24, 0.48, random());
    else if (shape === "randomWalk") v = i === 0 ? 0.5 : clamp(pts[i - 1].v + (random() - 0.5) * amount * 0.75);
    else if (shape === "stagger") v = clamp((shifted + laneIndex / Math.max(1, state.lanes.length - 1)) % 1);
    else if (shape === "mirror") v = laneIndex % 2 === 0 ? shifted : 1 - shifted;
    else if (shape === "gate") v = random() < amount ? lerp(0.65, 1, random()) : lerp(0, 0.25, random());
    if (shape !== "gate" && shape !== "randomWalk") v += (random() - 0.5) * amount * 0.12;
    pts.push({ t: +t.toFixed(6), v: +clamp(v).toFixed(6) });
  }
  lane.points = pts;
  if (shape === "gate") lane.curve = "step";
  sortPoints(lane);
}

function advanceSeed() {
  const current = Number(el.seed.value) || 1;
  el.seed.value = String(current + 1);
}

function generateRelationshipScore() {
  advanceSeed();
  const target = el.relationshipTarget.value;
  const strength = Number(el.relationshipStrength.value);
  const motion = Number(el.relationshipMotion.value);
  const center = Number(el.relationshipCenter.value);
  const count = Number(el.pointCount.value);
  const random = rng(Number(el.seed.value) * 131 + 17);
  const laneCount = state.lanes.length;
  const phaseBase = random() * Math.PI * 2;
  const waves = 1 + Math.round(motion * 7);

  state.lanes.forEach((lane, laneIndex) => {
    const pts = [];
    const lanePhase = phaseBase + (laneIndex / Math.max(1, laneCount)) * Math.PI * 2;
    const polarity = laneIndex % 2 === 0 ? 1 : -1;
    const rank = laneCount <= 1 ? 0 : (laneIndex / (laneCount - 1)) * 2 - 1;
    for (let i = 0; i < count; i++) {
      const t = count === 1 ? 0 : i / (count - 1);
      const drift = Math.sin((t * waves + random() * 0.08) * Math.PI * 2 + lanePhase);
      const slow = Math.sin((t * (1 + motion * 2)) * Math.PI * 2 + phaseBase);
      let v = center;
      if (target === "stddev") {
        v = center + rank * strength * 0.42 * (0.35 + 0.65 * Math.abs(slow)) + drift * motion * 0.12;
      } else if (target === "spread") {
        v = center + rank * strength * 0.48 + drift * motion * 0.08;
      } else if (target === "synchrony") {
        v = center + slow * strength * 0.3 + drift * motion * 0.04;
      } else if (target === "density") {
        const threshold = 1 - strength;
        v = ((drift * 0.5 + 0.5) > threshold ? 0.85 : 0.15) + slow * motion * 0.08;
      } else if (target === "divergence") {
        const localSpread = Math.sin(t * Math.PI);
        v = center + polarity * localSpread * strength * 0.45 + drift * motion * 0.18;
      }
      v += (random() - 0.5) * 0.04 * motion;
      pts.push({ t: +t.toFixed(6), v: +clamp(v).toFixed(6) });
    }
    lane.points = pts;
    lane.curve = target === "density" ? "step" : "smooth";
    sortPoints(lane);
  });
  syncControls();
}

function destinationLaneForDerive() {
  if (el.deriveDestination.value === "append" || state.lanes.length < 2) {
    const source = selectedLane();
    state.lanes.push({
      name: `${source.name} derived`,
      enabled: true,
      color: palette[state.lanes.length % palette.length],
      curve: source.curve,
      points: [{ t: 0, v: 0.5 }, { t: 1, v: 0.5 }],
    });
    return state.lanes[state.lanes.length - 1];
  }
  const nextIndex = (state.selectedLane + 1) % state.lanes.length;
  return state.lanes[nextIndex];
}

function deriveSelectedLane() {
  const source = selectedLane();
  if (!source) return;
  advanceSeed();
  const method = el.deriveMethod.value;
  const amount = Number(el.deriveAmount.value);
  const center = Number(el.deriveCenter.value);
  const count = Math.max(2, Number(el.pointCount.value));
  const random = rng(Number(el.seed.value) * 193 + state.selectedLane * 29);
  const lag = amount * 0.35;
  const dest = destinationLaneForDerive();
  const pts = [];
  for (let i = 0; i < count; i++) {
    const t = i / (count - 1);
    let sampleT = t;
    let v = laneValue(source, t);
    if (method === "complement") {
      v = 1 - v;
    } else if (method === "inverse") {
      v = center - (v - center) * (0.4 + amount * 1.6);
    } else if (method === "echo") {
      const delayed = laneValue(source, clamp(t - lag));
      v = lerp(v, delayed, 0.35 + amount * 0.6);
    } else if (method === "offset") {
      sampleT = clamp(t - amount * 0.5);
      v = laneValue(source, sampleT);
    } else if (method === "phase") {
      sampleT = (t + amount) % 1;
      v = laneValue(source, sampleT);
    } else if (method === "gate") {
      v = v > center ? lerp(center, 1, 0.45 + amount * 0.55) : lerp(0, center, 0.55 - amount * 0.45);
    } else if (method === "smooth") {
      const radius = 0.025 + amount * 0.11;
      v = (laneValue(source, clamp(t - radius)) + v * 2 + laneValue(source, clamp(t + radius))) * 0.25;
    } else if (method === "variation") {
      const wobble = Math.sin((t * (1 + amount * 8) + random()) * Math.PI * 2) * amount * 0.12;
      v = v + wobble + (random() - 0.5) * amount * 0.14;
    }
    pts.push({ t: +t.toFixed(6), v: +clamp(v).toFixed(6) });
  }
  dest.points = pts;
  dest.curve = method === "gate" ? "step" : source.curve === "step" ? "linear" : source.curve;
  if (!dest.name || dest.name.match(/^Lane \d+$/)) dest.name = `${source.name} ${method}`;
  sortPoints(dest);
  state.selectedLane = state.lanes.indexOf(dest);
  state.selectedPoint = -1;
  syncControls();
}

function exportData() {
  const lanes = state.lanes.map((lane, index) => ({
    index: index + 1,
    name: lane.name,
    enabled: lane.enabled,
    color: lane.color,
    curve: lane.curve,
    points: lane.points.map(p => ({ t: +p.t.toFixed(6), v: +p.v.toFixed(6) })),
    samples: makeSamples(lane),
  }));
  return {
    tool: "s3g-mc Automation Score",
    format: "s3g-mc-automation-score",
    version: 1,
    duration: state.duration,
    point_rate: state.pointRate,
    sections: state.sections.map((section, index) => ({
      index: index + 1,
      name: section.name || `Section ${index + 1}`,
      t: +clamp(section.t).toFixed(6),
      time: +(clamp(section.t) * state.duration).toFixed(6),
    })),
    lanes,
  };
}

function downloadJson() {
  const data = JSON.stringify(exportData(), null, 2);
  const blob = new Blob([data], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `s3g-mc-automation-score-${Date.now()}.json`;
  a.click();
  URL.revokeObjectURL(a.href);
}

function loadData(data) {
  const validFormat = data && (data.format === "s3g-mc-automation-score" || data.format === "s3g-mc-automation-field");
  if (!validFormat) throw new Error("not an Automation Score JSON file");
  state.duration = Number(data.duration) || 16;
  state.pointRate = Number(data.point_rate) || 16;
  state.sections = (data.sections || data.markers || []).map((section, index) => {
    const hasT = section.t !== undefined;
    const t = hasT ? Number(section.t) : (Number(section.time) || 0) / Math.max(0.001, state.duration);
    return { name: section.name || `Section ${index + 1}`, t: clamp(t) };
  });
  if (!state.sections.length) state.sections = [{ name: "A", t: 0 }, { name: "B", t: 0.5 }];
  sortSections();
  state.lanes = (data.lanes || []).map((lane, index) => ({
    name: lane.name || `Lane ${index + 1}`,
    enabled: lane.enabled !== false,
    color: lane.color || palette[index % palette.length],
    curve: lane.curve || "linear",
    points: (lane.points || [{ t: 0, v: 0.5 }, { t: 1, v: 0.5 }]).map(p => ({ t: clamp(Number(p.t) || 0), v: clamp(Number(p.v) || 0) })),
  }));
  if (!state.lanes.length) resetField();
  state.lanes.forEach(sortPoints);
  state.selectedLane = 0;
  state.selectedPoint = -1;
  state.selectedSection = 0;
  syncControls();
}

function pointerPos(event) {
  const rect = canvas.getBoundingClientRect();
  return { x: event.clientX - rect.left, y: event.clientY - rect.top };
}

function hitTest(x, y) {
  let best = null;
  state.lanes.forEach((lane, li) => {
    if (state.viewMode === "overlay" && li !== state.selectedLane) return;
    lane.points.forEach((p, pi) => {
      const sp = pointToScreen(p, li);
      const d = Math.hypot(x - sp.x, y - sp.y);
      if (d < 10 && (!best || d < best.d)) best = { lane: li, point: pi, d };
    });
  });
  return best;
}

function hitTestSection(x, y, allowFullHeight) {
  const r = fieldRect();
  const rail = markerRailRect();
  const inRail = y >= rail.y - 4 && y <= rail.y + rail.h + 4;
  if (!inRail && (!allowFullHeight || y < r.y - 8 || y > r.y + r.h + 8)) return null;
  let best = null;
  const width = inRail ? rail.w : r.w;
  const x0 = inRail ? rail.x : r.x;
  state.sections.forEach((section, index) => {
    const sx = x0 + clamp(section.t) * width;
    const d = Math.abs(x - sx);
    const threshold = inRail ? 16 : 9;
    if (d < threshold && (!best || d < best.d)) best = { section: index, d };
  });
  return best;
}

canvas.addEventListener("pointerdown", event => {
  const { x, y } = pointerPos(event);
  const sectionHit = hitTestSection(x, y, event.shiftKey);
  if (sectionHit) {
    state.selectedSection = sectionHit.section;
    state.selectedPoint = -1;
    const rail = markerRailRect();
    const inRail = y >= rail.y - 4 && y <= rail.y + rail.h + 4;
    state.drag = { type: "section", sectionRef: state.sections[sectionHit.section], rail: inRail };
    canvas.setPointerCapture(event.pointerId);
    syncControls();
    return;
  }

  const hit = hitTest(x, y);
  if (hit) {
    state.selectedLane = hit.lane;
    state.selectedPoint = hit.point;
    state.drag = { type: "point", lane: hit.lane, point: hit.point };
  } else {
    const laneIndex = state.viewMode === "stacked"
      ? Math.max(0, Math.min(state.lanes.length - 1, state.lanes.findIndex((_, i) => {
        const r = laneRect(i);
        return y >= r.y && y <= r.y + r.h;
      })))
      : state.selectedLane;
    const p = screenToPoint(x, y, laneIndex);
    state.selectedLane = laneIndex < 0 ? state.selectedLane : laneIndex;
    selectedLane().points.push(p);
    sortPoints(selectedLane());
    state.selectedPoint = selectedLane().points.findIndex(q => q === p);
    state.drag = { type: "point", lane: state.selectedLane, point: state.selectedPoint };
  }
  canvas.setPointerCapture(event.pointerId);
  syncControls();
});

canvas.addEventListener("pointermove", event => {
  if (!state.drag) return;
  const { x, y } = pointerPos(event);
  if (state.drag.type === "section") {
    const r = state.drag.rail ? markerRailRect() : fieldRect();
    const section = state.drag.sectionRef;
    section.t = clamp((x - r.x) / Math.max(1, r.w));
    state.selectedSection = state.sections.findIndex(item => item === section);
    if (state.selectedSection < 0) state.selectedSection = 0;
    syncSectionFields();
    return;
  }
  const lane = state.lanes[state.drag.lane];
  const p = screenToPoint(x, y, state.drag.lane);
  const idx = state.drag.point;
  lane.points[idx].t = idx === 0 ? 0 : idx === lane.points.length - 1 ? 1 : p.t;
  lane.points[idx].v = p.v;
  sortPoints(lane);
});

canvas.addEventListener("pointerup", event => {
  if (state.drag && state.drag.type === "section") {
    const section = state.drag.sectionRef;
    sortSections();
    state.selectedSection = state.sections.findIndex(item => item === section);
    if (state.selectedSection < 0) state.selectedSection = 0;
    syncControls();
  }
  state.drag = null;
  canvas.releasePointerCapture(event.pointerId);
});

function startPlayback() {
  state.playing = true;
  state.playStart = performance.now() - state.playT * state.duration * 1000;
}

function stopPlayback() {
  state.playing = false;
  state.playT = 0;
}

el.play.addEventListener("click", startPlayback);
el.spacePlay.addEventListener("click", startPlayback);
el.stop.addEventListener("click", stopPlayback);
el.spaceStop.addEventListener("click", stopPlayback);
el.importJson.addEventListener("click", () => el.jsonFile.click());
el.exportJson.addEventListener("click", downloadJson);
el.jsonFile.addEventListener("change", () => {
  const file = el.jsonFile.files && el.jsonFile.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    try { loadData(JSON.parse(String(reader.result || ""))); }
    catch (err) { alert(err.message || String(err)); }
  };
  reader.readAsText(file);
});
el.addLane.addEventListener("click", () => {
  state.lanes.push(newLane(state.lanes.length));
  state.selectedLane = state.lanes.length - 1;
  syncControls();
});
el.deleteLane.addEventListener("click", () => {
  if (state.lanes.length <= 1) return;
  state.lanes.splice(state.selectedLane, 1);
  state.selectedLane = Math.max(0, state.selectedLane - 1);
  syncControls();
});
el.addSection.addEventListener("click", () => {
  state.sections.push({ name: `Section ${state.sections.length + 1}`, t: state.playT });
  sortSections();
  state.selectedSection = state.sections.findIndex(section => Math.abs(section.t - state.playT) < 0.000001);
  if (state.selectedSection < 0) state.selectedSection = state.sections.length - 1;
  syncControls();
});
el.deleteSection.addEventListener("click", () => {
  if (!state.sections.length) return;
  state.sections.splice(state.selectedSection, 1);
  state.selectedSection = Math.max(0, state.selectedSection - 1);
  syncControls();
});
el.sectionName.addEventListener("input", () => {
  selectedSection().name = el.sectionName.value;
  renderSectionList();
});
el.sectionTime.addEventListener("input", () => {
  selectedSection().t = clamp((Number(el.sectionTime.value) || 0) / Math.max(0.001, state.duration));
  sortSections();
  syncControls();
});
el.sectionToPlayhead.addEventListener("click", () => {
  selectedSection().t = state.playT;
  sortSections();
  syncControls();
});
el.laneName.addEventListener("input", () => { selectedLane().name = el.laneName.value; renderLaneList(); });
el.laneEnabled.addEventListener("change", () => { selectedLane().enabled = el.laneEnabled.checked; renderLaneList(); });
el.laneColor.addEventListener("input", () => { selectedLane().color = el.laneColor.value; renderLaneList(); });
el.laneCurve.addEventListener("change", () => { selectedLane().curve = el.laneCurve.value; });
el.addPoint.addEventListener("click", () => {
  const lane = selectedLane();
  lane.points.push({ t: state.playT, v: laneValue(lane, state.playT) });
  sortPoints(lane);
  syncControls();
});
el.clearLane.addEventListener("click", () => {
  selectedLane().points = [{ t: 0, v: 0.5 }, { t: 1, v: 0.5 }];
  syncControls();
});
el.generateLane.addEventListener("click", () => {
  advanceSeed();
  generateShape(state.selectedLane);
  syncControls();
});
el.generateAll.addEventListener("click", () => {
  advanceSeed();
  state.lanes.forEach((_, index) => generateShape(index));
  syncControls();
});
el.generateRelationship.addEventListener("click", generateRelationshipScore);
el.deriveLane.addEventListener("click", deriveSelectedLane);
el.amount.addEventListener("input", syncControls);
el.pointCount.addEventListener("input", syncControls);
el.relationshipStrength.addEventListener("input", syncControls);
el.relationshipMotion.addEventListener("input", syncControls);
el.relationshipCenter.addEventListener("input", syncControls);
el.deriveAmount.addEventListener("input", syncControls);
el.deriveCenter.addEventListener("input", syncControls);
el.duration.addEventListener("input", () => { state.duration = Number(el.duration.value); syncControls(); });
el.pointRate.addEventListener("input", () => { state.pointRate = Number(el.pointRate.value); syncControls(); });
el.viewMode.addEventListener("change", () => { state.viewMode = el.viewMode.value; syncControls(); });
el.aggregateMode.addEventListener("change", () => { state.aggregateMode = el.aggregateMode.value; syncControls(); });
el.projectionMode.addEventListener("change", () => { state.projectionMode = el.projectionMode.value; syncControls(); });
el.showSamples.addEventListener("change", () => { state.showSamples = el.showSamples.checked; syncControls(); });
el.reset.addEventListener("click", resetField);
el.openSpaceView.addEventListener("click", () => {
  state.spaceOpen = true;
  el.spaceModal.classList.add("open");
  el.spaceModal.setAttribute("aria-hidden", "false");
});
el.closeSpaceView.addEventListener("click", () => {
  state.spaceOpen = false;
  el.spaceModal.classList.remove("open");
  el.spaceModal.setAttribute("aria-hidden", "true");
});
el.cameraAz.addEventListener("input", () => {
  state.cameraAz = Number(el.cameraAz.value);
  syncControls();
});
el.cameraEl.addEventListener("input", () => {
  state.cameraEl = Number(el.cameraEl.value);
  syncControls();
});
el.cameraZoom.addEventListener("input", () => {
  state.cameraZoom = Number(el.cameraZoom.value);
  syncControls();
});

document.querySelectorAll("[data-camera]").forEach(button => {
  button.addEventListener("click", () => {
    const view = button.dataset.camera;
    if (view === "top") {
      state.cameraAz = 0;
      state.cameraEl = 85;
      state.cameraZoom = 1;
    } else if (view === "front") {
      state.cameraAz = 0;
      state.cameraEl = 0;
      state.cameraZoom = 1;
    } else if (view === "side") {
      state.cameraAz = -90;
      state.cameraEl = 0;
      state.cameraZoom = 1;
    } else {
      state.cameraAz = -35;
      state.cameraEl = 32;
      state.cameraZoom = 1;
    }
    syncControls();
  });
});

document.querySelectorAll(".panel section > h2").forEach(header => {
  header.addEventListener("click", () => {
    header.parentElement.classList.toggle("collapsed");
  });
});

document.querySelectorAll('input[type="range"]').forEach(input => {
  input.addEventListener("input", () => updateRangeFill(input));
});

enhanceCustomSelects();

function playbarPointer(event) {
  const rect = event.currentTarget.getBoundingClientRect();
  const x = event.clientX - rect.left;
  const geo = timelineGeometry(rect.width);
  const pad = geo.x;
  const graphW = Math.max(100, Math.min(geo.w, rect.width - pad - 10));
  state.playT = clamp((x - pad) / Math.max(1, graphW));
  if (state.playing) state.playStart = performance.now() - state.playT * state.duration * 1000;
}

playbar.addEventListener("pointerdown", event => {
  state.drag = { playbar: true };
  playbarPointer(event);
  playbar.setPointerCapture(event.pointerId);
});
playbar.addEventListener("pointermove", event => {
  if (!state.drag || !state.drag.playbar) return;
  playbarPointer(event);
});
playbar.addEventListener("pointerup", event => {
  if (state.drag && state.drag.playbar) state.drag = null;
  playbar.releasePointerCapture(event.pointerId);
});

heatmap.addEventListener("pointerdown", event => {
  state.drag = { playbar: true };
  playbarPointer(event);
  heatmap.setPointerCapture(event.pointerId);
});
heatmap.addEventListener("pointermove", event => {
  if (!state.drag || !state.drag.playbar) return;
  playbarPointer(event);
});
heatmap.addEventListener("pointerup", event => {
  if (state.drag && state.drag.playbar) state.drag = null;
  heatmap.releasePointerCapture(event.pointerId);
});

function spacePointer(event) {
  const rect = spaceCanvas.getBoundingClientRect();
  return { x: event.clientX - rect.left, y: event.clientY - rect.top };
}

spaceCanvas.addEventListener("pointerdown", event => {
  const p = spacePointer(event);
  state.spaceDrag = { x: p.x, y: p.y, az: state.cameraAz, el: state.cameraEl };
  spaceCanvas.setPointerCapture(event.pointerId);
});

spaceCanvas.addEventListener("pointermove", event => {
  if (!state.spaceDrag) return;
  const p = spacePointer(event);
  state.cameraAz = ((state.spaceDrag.az + (p.x - state.spaceDrag.x) * 0.35 + 180) % 360) - 180;
  state.cameraEl = clamp(state.spaceDrag.el - (p.y - state.spaceDrag.y) * 0.28, -85, 85);
  syncControls();
});

spaceCanvas.addEventListener("pointerup", event => {
  state.spaceDrag = null;
  spaceCanvas.releasePointerCapture(event.pointerId);
});

spaceCanvas.addEventListener("wheel", event => {
  event.preventDefault();
  const factor = event.deltaY < 0 ? 1.06 : 0.94;
  state.cameraZoom = clamp(state.cameraZoom * factor, 0.45, 2.2);
  syncControls();
}, { passive: false });

document.addEventListener("keydown", event => {
  if (event.key === "Escape" && state.spaceOpen) {
    state.spaceOpen = false;
    el.spaceModal.classList.remove("open");
    el.spaceModal.setAttribute("aria-hidden", "true");
  }
});

resetField();
requestAnimationFrame(renderLoop);
