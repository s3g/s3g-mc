const VIRTUAL_24 = [
  [1, 0.000000, 73.402158], [2, 137.507764, 61.044976], [3, -84.984472, 52.341538],
  [4, 52.523292, 45.099472], [5, -169.968944, 38.682187], [6, -32.461180, 32.797168],
  [7, 105.046584, 27.279613], [8, -117.445652, 22.024313], [9, 20.062112, 16.957763],
  [10, 157.569876, 12.024699], [11, -64.922360, 7.180756], [12, 72.585405, 2.388015],
  [13, -149.906831, -2.388015], [14, -12.399067, -7.180756], [15, 125.108697, -12.024699],
  [16, -97.383539, -16.957763], [17, 40.124225, -22.024313], [18, 177.631989, -27.279613],
  [19, -44.860247, -32.797168], [20, 92.647517, -38.682187], [21, -129.844719, -45.099472],
  [22, 7.663045, -52.341538], [23, 145.170809, -61.044976], [24, -77.321427, -73.402158],
];

const MESH_EDGES = makeMeshEdges(VIRTUAL_24.map(([channel, azimuth, elevation]) => ({ channel, azimuth, elevation, radius: 1 })), 4);

const state = {
  name: "Displacement Score",
  amount: 0.65,
  azScale: 1,
  elScale: 1,
  rScale: 1,
  strength: 0.55,
  seed: 7,
  rotateAz: 0,
  shiftEl: 0,
  twist: 0,
  collapse: 0,
  distanceScale: 1,
  distanceFlare: 0,
  method: "target",
  normalizeRadius: true,
  showPoints: true,
  showPolygon: true,
  showHeatmap: false,
  heatmapPalette: "thermal",
  polygonMode: "resolved",
  timePosition: 0,
  frameCount: 32,
  selected: 0,
  viewMode: "globe",
  cameraAz: 38,
  cameraEl: 24,
  zoom: 1,
  base: VIRTUAL_24.map(([channel, azimuth, elevation]) => ({ channel, azimuth, elevation, radius: 1 })),
  target: VIRTUAL_24.map(([channel, azimuth, elevation]) => ({ channel, azimuth, elevation, radius: 1 })),
  dragging: false,
  viewDragging: false,
  viewDrag: null,
  projected: [],
};

const $ = (id) => document.getElementById(id);
const canvas = $("field");
const ctx = canvas.getContext("2d");
const playbar = $("playbar");
const barCtx = playbar.getContext("2d");
const STORAGE_KEY = "s3g-mc-displacement-score-autosave-v1";
let lastAutosaveJson = "";

function clonePoints(points) {
  return points.map((p) => ({ channel: p.channel, azimuth: p.azimuth, elevation: p.elevation, radius: p.radius ?? 1 }));
}

function makeScene(name, t, target) {
  return { name, t: clamp(t, 0, 1), target: clonePoints(target) };
}

state.duration = 16;
state.playing = false;
state.playStart = 0;
state.playT = 0;
state.selectedScene = 0;
state.scenes = [
  makeScene("A", 0, state.base),
  makeScene("B", 1, state.target.map((p) => ({
    ...p,
    azimuth: wrapDeg(p.azimuth + p.elevation * 0.65),
    elevation: clamp(p.elevation * 0.72, -90, 90),
  }))),
];
state.target = clonePoints(state.scenes[0].target);

function rad(v) { return v * Math.PI / 180; }
function deg(v) { return v * 180 / Math.PI; }
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
function lerp(a, b, t) { return a + (b - a) * t; }
function wrapDeg(v) {
  let x = ((v + 180) % 360 + 360) % 360 - 180;
  return x === -180 ? 180 : x;
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

function refreshCustomSelects(root = document) {
  root.querySelectorAll("select").forEach((select) => {
    if (!select._customButton) return;
    select._customButton.textContent = select.selectedOptions[0]?.textContent || "Select";
    select._customButton.disabled = select.disabled;
  });
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

function initCollapsiblePanels() {
  document.querySelectorAll(".panel section > h2").forEach((heading) => {
    if (heading.dataset.collapsible === "1") return;
    heading.dataset.collapsible = "1";
    heading.setAttribute("tabindex", "0");
    heading.setAttribute("role", "button");
    heading.setAttribute("aria-expanded", "true");
    const toggle = () => {
      const section = heading.parentElement;
      const isCollapsed = section.classList.toggle("collapsed");
      heading.setAttribute("aria-expanded", isCollapsed ? "false" : "true");
    };
    heading.addEventListener("click", toggle);
    heading.addEventListener("keydown", (event) => {
      if (!["Enter", " "].includes(event.key)) return;
      event.preventDefault();
      toggle();
    });
  });
}

function sphToXyz(p) {
  const az = rad(p.azimuth);
  const el = rad(p.elevation);
  const r = p.radius ?? 1;
  const ce = Math.cos(el);
  return {
    x: Math.sin(az) * ce * r,
    y: Math.cos(az) * ce * r,
    z: Math.sin(el) * r,
  };
}

function xyzToSph(v) {
  const r = Math.max(0.0001, Math.hypot(v.x, v.y, v.z));
  return {
    azimuth: wrapDeg(deg(Math.atan2(v.x, v.y))),
    elevation: clamp(deg(Math.asin(v.z / r)), -90, 90),
    radius: r,
  };
}

function sortScenes() {
  state.scenes.sort((a, b) => a.t - b.t);
  for (let i = 1; i < state.scenes.length; i += 1) {
    if (state.scenes[i].t <= 0.000001) state.scenes[i].t = Math.min(1, 0.001 + i * 0.001);
  }
  state.scenes.sort((a, b) => a.t - b.t);
  if (state.scenes.length) {
    state.scenes[0].t = 0;
    state.scenes[0].target = clonePoints(state.base);
    state.scenes[0].name = state.scenes[0].name || "A";
  }
  state.selectedScene = clamp(state.selectedScene, 0, Math.max(0, state.scenes.length - 1));
}

function currentScene() {
  if (!state.scenes.length) state.scenes.push(makeScene("A", 0, state.base));
  return state.scenes[state.selectedScene] || state.scenes[0];
}

function syncTargetFromScene() {
  state.target = clonePoints(currentScene().target);
}

function captureCurrentScene() {
  ensureEditableScene();
  currentScene().target = clonePoints(state.target);
}

function ensureEditableScene() {
  sortScenes();
  if (!currentScene() || currentScene().t > 0.000001) return;
  let next = state.scenes.findIndex((scene) => scene.t > 0.000001);
  if (next < 0) {
    state.scenes.push(makeScene("B", 1, state.target));
    next = state.scenes.length - 1;
  }
  state.selectedScene = next;
  syncTargetFromScene();
}

function scenePairAt(t) {
  sortScenes();
  const x = clamp(t, 0, 1);
  if (x <= state.scenes[0].t) return { a: state.scenes[0], b: state.scenes[0], u: 0 };
  const last = state.scenes[state.scenes.length - 1];
  if (x >= last.t) return { a: last, b: last, u: 0 };
  for (let i = 0; i < state.scenes.length - 1; i += 1) {
    const a = state.scenes[i];
    const b = state.scenes[i + 1];
    if (x <= b.t) {
      const span = Math.max(0.000001, b.t - a.t);
      return { a, b, u: (x - a.t) / span };
    }
  }
  return { a: last, b: last, u: 0 };
}

function targetAt(t = state.playT) {
  if (t <= 0.000001) return clonePoints(state.base);
  const { a, b, u } = scenePairAt(t);
  const v = u * u * (3 - 2 * u);
  return state.base.map((_, i) => {
    const p = a.target[i] || state.base[i];
    const q = b.target[i] || p;
    return {
      channel: p.channel,
      azimuth: wrapDeg(p.azimuth + wrapDeg(q.azimuth - p.azimuth) * v),
      elevation: clamp(lerp(p.elevation, q.elevation, v), -90, 90),
      radius: clamp(lerp(p.radius ?? 1, q.radius ?? 1, v), 0.1, 2),
    };
  });
}

function effectiveAmount() {
  return state.amount;
}

function displacedPoint(i, t = state.playT) {
  const a = state.base[i];
  const b = targetAt(t)[i];
  let da = wrapDeg(b.azimuth - a.azimuth) * state.azScale;
  let de = (b.elevation - a.elevation) * state.elScale;
  let dr = ((b.radius ?? 1) - (a.radius ?? 1)) * state.rScale;
  const amount = effectiveAmount();
  return {
    channel: a.channel,
    azimuth: wrapDeg(a.azimuth + da * amount),
    elevation: clamp(a.elevation + de * amount, -90, 90),
    radius: state.normalizeRadius ? 1 : clamp((a.radius ?? 1) + dr * amount, 0.05, 3),
  };
}

function project(p) {
  if (state.viewMode === "map") return projectMap(p);
  const v = sphToXyz(p);
  const az = rad(state.cameraAz);
  const el = rad(state.cameraEl);
  const ca = Math.cos(az), sa = Math.sin(az);
  const ce = Math.cos(el), se = Math.sin(el);
  const x1 = v.x * ca - v.y * sa;
  const y1 = v.x * sa + v.y * ca;
  const z1 = v.z;
  const y2 = y1 * ce - z1 * se;
  const z2 = y1 * se + z1 * ce;
  const size = Math.min(canvas.width, canvas.height) * 0.34 * state.zoom;
  return {
    x: canvas.width * 0.5 + x1 * size,
    y: canvas.height * 0.52 - z2 * size,
    depth: y2,
  };
}

function mapRect() {
  const marginX = state.showHeatmap ? 78 : 54;
  const marginY = 44;
  const aspect = Math.PI;
  const availW = Math.max(120, canvas.width - marginX * 2);
  const availH = Math.max(80, canvas.height - marginY * 2);
  let w = availW;
  let h = w / aspect;
  if (h > availH) {
    h = availH;
    w = h * aspect;
  }
  return {
    x: (canvas.width - w) * 0.5,
    y: (canvas.height - h) * 0.5,
    w,
    h,
  };
}

function projectMap(p) {
  const r = mapRect();
  return {
    x: r.x + ((wrapDeg(p.azimuth) + 180) / 360) * r.w,
    y: r.y + (0.5 - Math.sin(rad(p.elevation)) * 0.5) * r.h,
    depth: 0,
  };
}

function draw() {
  resizeCanvas();
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = "#070909";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  drawGeometry();
  drawPlaybar();
  updateReadouts();
}

function drawStageFrame() {
  ctx.strokeStyle = "rgba(120,135,135,0.20)";
  ctx.lineWidth = 1;
  if (state.viewMode === "map") {
    drawMapFrame();
  } else {
    ctx.strokeRect(18, 18, canvas.width - 36, canvas.height - 36);
  }
}

function drawMapFrame() {
  const r = mapRect();
  ctx.strokeStyle = "rgba(120,135,135,0.22)";
  ctx.lineWidth = 1;
  ctx.strokeRect(r.x, r.y, r.w, r.h);
  ctx.strokeStyle = "rgba(120,135,135,0.12)";
  for (let i = 1; i < 12; i += 1) {
    const x = r.x + (i / 12) * r.w;
    ctx.beginPath();
    ctx.moveTo(x, r.y);
    ctx.lineTo(x, r.y + r.h);
    ctx.stroke();
  }
  for (let i = 1; i < 6; i += 1) {
    const y = r.y + (i / 6) * r.h;
    ctx.beginPath();
    ctx.moveTo(r.x, y);
    ctx.lineTo(r.x + r.w, y);
    ctx.stroke();
  }
  ctx.fillStyle = "rgba(216,221,221,0.55)";
  ctx.font = "10px Menlo, monospace";
  ctx.textAlign = "left";
  ctx.fillText("-180", r.x, r.y + r.h + 18);
  ctx.textAlign = "center";
  ctx.fillText("0", r.x + r.w * 0.5, r.y + r.h + 18);
  ctx.textAlign = "right";
  ctx.fillText("+180", r.x + r.w, r.y + r.h + 18);
}

function drawGeometry() {
  state.projected = [];
  drawStageFrame();
  const resolvedTarget = targetAt(state.playT);
  const heat = radiationFieldAt(state.playT);
  if (state.showHeatmap) drawHeatmapField(heat);
  if (state.showPolygon) drawMesh();
  for (let i = 0; i < state.base.length; i += 1) {
    const base = project(state.base[i]);
    const target = project(resolvedTarget[i]);
    const out = project(displacedPoint(i, state.playT));
    state.projected.push({ x: out.x, y: out.y, index: i });
    if (state.showPoints) {
      ctx.strokeStyle = state.showHeatmap ? heatColor(0.72, 0.42) : "rgba(217,168,77,0.18)";
      ctx.lineWidth = state.showHeatmap ? 1.4 : 1;
      ctx.beginPath();
      ctx.moveTo(base.x, base.y);
      ctx.lineTo(target.x, target.y);
      ctx.stroke();
      drawPoint(base, 3, "rgba(120,135,135,0.60)");
      drawPoint(target, 4, state.showHeatmap ? heatColor(0.95, 0.86) : "rgba(223,115,72,0.80)");
      drawPoint(out, state.showHeatmap ? 7 : 5, state.showHeatmap ? heatColor(1, 1) : "#5eb9cf");
      drawLabel(out, String(i + 1), false);
    }
  }
  if (state.showHeatmap) drawHeatLegend(heat.max);
}

function drawMesh() {
  if (state.polygonMode === "source" || state.polygonMode === "all") {
    drawMeshForPoints(state.base, "rgba(120,135,135,0.30)", "rgba(120,135,135,0.035)");
  }
  if (state.polygonMode === "target" || state.polygonMode === "all") {
    drawMeshForPoints(targetAt(state.playT), "rgba(223,115,72,0.34)", "rgba(223,115,72,0.045)");
  }
  if (state.polygonMode === "resolved" || state.polygonMode === "all") {
    drawMeshForPoints(state.base.map((_, i) => displacedPoint(i, state.playT)), "rgba(94,185,207,0.48)", "rgba(94,185,207,0.060)");
  }
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
  const pad = 20;
  const y = 16;
  const graphW = Math.max(100, w - pad * 2);
  const graphH = h - 32;
  barCtx.strokeStyle = "#242a2a";
  barCtx.lineWidth = 1;
  barCtx.strokeRect(pad, y, graphW, graphH);
  barCtx.strokeStyle = "rgba(94,185,207,0.55)";
  barCtx.beginPath();
  for (let i = 0; i <= 160; i += 1) {
    const t = i / 160;
    const v = displacementEnergyAt(t);
    const x = pad + t * graphW;
    const yy = y + graphH - v * graphH;
    if (i === 0) barCtx.moveTo(x, yy);
    else barCtx.lineTo(x, yy);
  }
  barCtx.stroke();
  sortScenes();
  state.scenes.forEach((scene, index) => {
    const x = pad + scene.t * graphW;
    const active = index === state.selectedScene;
    barCtx.strokeStyle = active ? "#f1d47a" : "rgba(217,168,77,0.68)";
    barCtx.lineWidth = active ? 2 : 1;
    barCtx.beginPath();
    barCtx.moveTo(x, y);
    barCtx.lineTo(x, y + graphH);
    barCtx.stroke();
    barCtx.fillStyle = active ? "#f1d47a" : "#b98c46";
    barCtx.font = "10px Menlo, Monaco, monospace";
    barCtx.fillText(scene.name || `S${index + 1}`, Math.min(w - 48, x + 5), y + 13);
  });
  const px = pad + state.playT * graphW;
  barCtx.strokeStyle = "#f0c067";
  barCtx.lineWidth = 2;
  barCtx.beginPath();
  barCtx.moveTo(px, 6);
  barCtx.lineTo(px, h - 6);
  barCtx.stroke();
  barCtx.fillStyle = "#d0d0d0";
  barCtx.font = "11px Menlo, Monaco, monospace";
  barCtx.fillText(`${(state.playT * state.duration).toFixed(2)}s`, Math.min(w - 76, px + 6), h - 9);
}

function displacementEnergyAt(t) {
  let sum = 0;
  const targets = targetAt(t);
  for (let i = 0; i < state.base.length; i += 1) {
    const a = state.base[i];
    const b = targets[i];
    sum += Math.abs(wrapDeg(b.azimuth - a.azimuth)) / 180;
    sum += Math.abs(b.elevation - a.elevation) / 90;
    sum += Math.abs((b.radius ?? 1) - (a.radius ?? 1));
  }
  return clamp(sum / (state.base.length * 2.2), 0, 1);
}

function drawMeshForPoints(points, stroke, fill) {
  const projected = points.map(project);
  ctx.fillStyle = fill;
  ctx.strokeStyle = stroke;
  ctx.lineWidth = 1;
  for (const [a, b] of MESH_EDGES) {
    const p1 = projected[a];
    const p2 = projected[b];
    ctx.beginPath();
    ctx.moveTo(p1.x, p1.y);
    ctx.lineTo(p2.x, p2.y);
    ctx.stroke();
  }
  for (let i = 0; i < points.length; i += 1) {
    const neighbors = MESH_EDGES.filter(([a, b]) => a === i || b === i).slice(0, 2);
    if (neighbors.length < 2) continue;
    const p0 = projected[i];
    const p1 = projected[neighbors[0][0] === i ? neighbors[0][1] : neighbors[0][0]];
    const p2 = projected[neighbors[1][0] === i ? neighbors[1][1] : neighbors[1][0]];
    ctx.beginPath();
    ctx.moveTo(p0.x, p0.y);
    ctx.lineTo(p1.x, p1.y);
    ctx.lineTo(p2.x, p2.y);
    ctx.closePath();
    ctx.fill();
  }
}

function radiationFieldAt(t) {
  const resolved = state.base.map((_, i) => displacedPoint(i, t));
  const projected = resolved.map(project);
  const radius = Math.min(canvas.width, canvas.height) * 0.34 * state.zoom;
  const rect = state.viewMode === "map" ? mapRect() : null;
  return {
    points: projected,
    cx: canvas.width * 0.5,
    cy: canvas.height * 0.52,
    radius,
    rect,
    sigma: state.viewMode === "map" ? Math.max(24, (rect?.w || canvas.width) * 0.055) : Math.max(28, radius * 0.18),
  };
}

function heatColor(v, alpha = 1) {
  const palettes = {
    thermal: [
      [0.00, [32, 55, 116]],
      [0.25, [43, 148, 186]],
      [0.50, [240, 219, 85]],
      [0.73, [229, 93, 47]],
      [1.00, [210, 24, 24]],
    ],
    classic: [
      [0.00, [42, 70, 115]],
      [0.22, [73, 144, 171]],
      [0.48, [213, 168, 77]],
      [0.72, [224, 108, 72]],
      [1.00, [248, 224, 126]],
    ],
    inferno: [
      [0.00, [0, 0, 4]],
      [0.24, [87, 15, 109]],
      [0.48, [187, 55, 84]],
      [0.73, [249, 142, 8]],
      [1.00, [252, 255, 164]],
    ],
    viridis: [
      [0.00, [68, 1, 84]],
      [0.25, [59, 82, 139]],
      [0.50, [33, 145, 140]],
      [0.75, [94, 201, 98]],
      [1.00, [253, 231, 37]],
    ],
    magma: [
      [0.00, [0, 0, 4]],
      [0.25, [80, 18, 123]],
      [0.50, [183, 55, 121]],
      [0.75, [251, 136, 97]],
      [1.00, [252, 253, 191]],
    ],
    greyscale: [
      [0.00, [18, 22, 25]],
      [0.30, [76, 82, 86]],
      [0.60, [155, 160, 160]],
      [1.00, [245, 245, 235]],
    ],
  };
  const stops = palettes[state.heatmapPalette] || palettes.thermal;
  const x = clamp(v, 0, 1);
  let lo = stops[0];
  let hi = stops[stops.length - 1];
  for (let i = 0; i < stops.length - 1; i += 1) {
    if (x >= stops[i][0] && x <= stops[i + 1][0]) {
      lo = stops[i];
      hi = stops[i + 1];
      break;
    }
  }
  const u = (x - lo[0]) / Math.max(0.000001, hi[0] - lo[0]);
  const r = Math.round(lerp(lo[1][0], hi[1][0], u));
  const g = Math.round(lerp(lo[1][1], hi[1][1], u));
  const b = Math.round(lerp(lo[1][2], hi[1][2], u));
  return `rgba(${r},${g},${b},${alpha})`;
}

function drawHeatmapField(heat) {
  const step = Math.max(7, Math.round(Math.min(canvas.width, canvas.height) / 96));
  const sigma2 = heat.sigma * heat.sigma * 2;
  ctx.save();
  ctx.globalAlpha = 0.78;
  const bounds = heat.rect || { x: heat.cx - heat.radius, y: heat.cy - heat.radius, w: heat.radius * 2, h: heat.radius * 2 };
  const r2 = heat.radius * heat.radius;
  for (let y = bounds.y; y <= bounds.y + bounds.h; y += step) {
    for (let x = bounds.x; x <= bounds.x + bounds.w; x += step) {
      if (!heat.rect) {
        const dx = x - heat.cx;
        const dy = y - heat.cy;
        if (dx * dx + dy * dy > r2) continue;
      }
      let energy = 0.02;
      for (const p of heat.points) {
        let dx = x - p.x;
        if (heat.rect) {
          const wrapW = heat.rect.w;
          if (Math.abs(dx) > wrapW * 0.5) dx -= Math.sign(dx) * wrapW;
        }
        const d2 = dx * dx + (y - p.y) * (y - p.y);
        energy += Math.exp(-d2 / sigma2);
      }
      energy = clamp(energy / 1.28, 0, 1);
      ctx.fillStyle = heatColor(energy, 1);
      ctx.fillRect(x - step * 0.55, y - step * 0.55, step * 1.12, step * 1.12);
    }
  }
  ctx.globalAlpha = 1;
  ctx.strokeStyle = "rgba(216,221,221,0.28)";
  ctx.lineWidth = 1;
  if (heat.rect) ctx.strokeRect(heat.rect.x, heat.rect.y, heat.rect.w, heat.rect.h);
  else {
    ctx.beginPath();
    ctx.arc(heat.cx, heat.cy, heat.radius, 0, Math.PI * 2);
    ctx.stroke();
  }
  ctx.restore();
}

function drawHeatLegend() {
  const w = 12;
  const h = Math.min(190, canvas.height * 0.42);
  const x = canvas.width - 34;
  const y = Math.max(54, canvas.height * 0.5 - h * 0.5);
  const gradient = ctx.createLinearGradient(x, y + h, x, y);
  for (let i = 0; i <= 20; i += 1) {
    const t = i / 20;
    gradient.addColorStop(t, heatColor(t, 1));
  }
  ctx.fillStyle = gradient;
  ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = "rgba(216,221,221,0.38)";
  ctx.strokeRect(x, y, w, h);
}

function drawPoint(p, radius, color) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.arc(p.x, p.y, radius, 0, Math.PI * 2);
  ctx.fill();
}

function drawLabel(p, text, selected) {
  ctx.fillStyle = selected ? "#ffffff" : "rgba(216,221,221,0.78)";
  ctx.font = selected ? "bold 11px Menlo, monospace" : "10px Menlo, monospace";
  ctx.textAlign = "center";
  ctx.fillText(text, p.x, p.y - 10);
}

function resizeCanvas() {
  const rect = canvas.getBoundingClientRect();
  const w = Math.max(600, Math.floor(rect.width));
  const h = Math.max(420, Math.floor(rect.height));
  if (canvas.width !== w || canvas.height !== h) {
    canvas.width = w;
    canvas.height = h;
  }
}

function setView(az, el, zoom = state.zoom) {
  state.cameraAz = az;
  state.cameraEl = el;
  state.zoom = zoom;
  syncControls();
  draw();
}

function applyPreset() {
  ensureEditableScene();
  const type = $("preset").value;
  const s = state.strength;
  const rand = seeded(state.seed);
  state.target = state.base.map((p, i) => {
    let az = p.azimuth;
    let el = p.elevation;
    let r = 1;
    if (type === "aed") {
      // Keep the original 24-point layout and apply only the AED/distance transform controls.
    } else if (type === "shear") az += p.elevation * s * 1.25;
    else if (type === "fold") el = p.elevation > 0 ? p.elevation * (1 - s) : p.elevation - 42 * s;
    else if (type === "vortex") az += (90 - Math.abs(p.elevation)) * s * 1.4;
    else if (type === "pinch") { el *= 1 - s * 0.75; r = 1 - 0.35 * s + Math.abs(p.elevation) / 90 * 0.25 * s; }
    else if (type === "rupture") az += (i % 3 - 1) * 70 * s;
    else if (type === "scatter") { az += (rand() * 2 - 1) * 140 * s; el += (rand() * 2 - 1) * 70 * s; r = 1 + (rand() * 2 - 1) * 0.6 * s; }
    else if (type === "mirror") az = -az + (p.elevation > 0 ? 35 : -35) * s;
    else if (type === "wave") el += Math.sin(rad(p.azimuth * 2)) * 55 * s;
    return transformPoint({ channel: p.channel, azimuth: wrapDeg(az), elevation: clamp(el, -90, 90), radius: clamp(r, 0.1, 2) }, p);
  });
  captureCurrentScene();
  syncControls();
  draw();
}

function transformPoint(p, base) {
  const height = (base?.elevation ?? p.elevation) / 90;
  const collapsedEl = lerp(p.elevation, 0, state.collapse);
  const radiusByHeight = (p.radius ?? 1) * state.distanceScale + Math.abs(height) * state.distanceFlare;
  return {
    channel: p.channel,
    azimuth: wrapDeg(p.azimuth + state.rotateAz + state.twist * height * 90),
    elevation: clamp(collapsedEl + state.shiftEl, -90, 90),
    radius: clamp(radiusByHeight, 0.05, 3),
  };
}

function seeded(seed) {
  let x = Math.max(1, Math.floor(Number(seed) || 1)) % 2147483647;
  return () => {
    x = x * 16807 % 2147483647;
    return (x - 1) / 2147483646;
  };
}

function makeMeshEdges(points, count) {
  const xyz = points.map(sphToXyz);
  const edges = new Set();
  xyz.forEach((p, i) => {
    const nearest = xyz
      .map((q, j) => ({ j, d: i === j ? Infinity : Math.hypot(p.x - q.x, p.y - q.y, p.z - q.z) }))
      .sort((a, b) => a.d - b.d)
      .slice(0, count);
    nearest.forEach(({ j }) => {
      const a = Math.min(i, j);
      const b = Math.max(i, j);
      edges.add(`${a}:${b}`);
    });
  });
  return Array.from(edges).map((key) => key.split(":").map(Number));
}

function resetTargets() {
  ensureEditableScene();
  state.target = state.base.map((p) => ({ ...p }));
  captureCurrentScene();
  syncControls();
  draw();
}

function eventPoint(event) {
  const rect = canvas.getBoundingClientRect();
  const sx = canvas.width / rect.width;
  const sy = canvas.height / rect.height;
  return { x: (event.clientX - rect.left) * sx, y: (event.clientY - rect.top) * sy };
}

function exportJson() {
  const timeline = timelineData();
  const data = {
    format: "s3g-mc-displacement-score",
    version: 1,
    tool: "s3g-mc Displacement Score",
    name: state.name,
    intended_use: "3OAFX 24-point virtual speaker displacement before re-encoding",
    geometry: "s3g 3OA 24 virtual speakers",
    method: state.method,
    normalize_radius_for_encode: state.normalizeRadius,
    amount: state.amount,
    scales: { azimuth: state.azScale, elevation: state.elScale, radius: state.rScale },
    transform: methodTransformData(),
    visualization: { points: state.showPoints, heatmap: state.showHeatmap, heatmap_palette: state.heatmapPalette, view_mode: state.viewMode },
    polygon: { enabled: state.showPolygon, mode: state.polygonMode, edges: MESH_EDGES },
    timeline,
    source: state.base,
    target: state.target,
    scenes: state.scenes,
    resolved: state.base.map((_, i) => displacedPoint(i, state.playT)),
    frames: timeline.frames,
  };
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = safeName(state.name) + ".json";
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 500);
}

function timelineData() {
  sortScenes();
  const frameCount = Math.max(2, Math.round(state.frameCount));
  const points = state.scenes.map((scene) => ({ name: scene.name, t: Number(scene.t.toFixed(6)), time: Number((scene.t * state.duration).toFixed(6)) }));
  const frames = [];
  for (let i = 0; i < frameCount; i += 1) {
    const t = frameCount === 1 ? 0 : i / (frameCount - 1);
    frames.push({
      t,
      amount: Number(effectiveAmount(t).toFixed(6)),
      geometry: state.base.map((_, j) => displacedPoint(j, t)),
    });
  }
  return {
    enabled: true,
    duration_mode: "scale_to_offline_render_duration",
    shape: "scene_interpolation",
    duration_seconds: state.duration,
    preview_t: state.playT,
    points,
    frame_count: frameCount,
    frames,
  };
}

function methodTransformData() {
  return {
    rotate_azimuth: state.rotateAz,
    shift_elevation: state.shiftEl,
    twist_by_height: state.twist,
    collapse_to_equator: state.collapse,
    distance_scale: state.distanceScale,
    distance_flare: state.distanceFlare,
  };
}

function safeName(name) {
  return String(name || "displacement-score").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "displacement-score";
}

function loadJsonData(data) {
  if (data.format !== "s3g-mc-displacement-score") throw new Error("not a Displacement Score JSON file");
  state.name = data.name || state.name;
  state.method = data.method || state.method;
  state.normalizeRadius = data.normalize_radius_for_encode !== false;
  state.amount = Number(data.amount ?? state.amount);
  state.azScale = Number(data.scales?.azimuth ?? state.azScale);
  state.elScale = Number(data.scales?.elevation ?? state.elScale);
  state.rScale = Number(data.scales?.radius ?? state.rScale);
  state.rotateAz = Number(data.transform?.rotate_azimuth ?? state.rotateAz);
  state.shiftEl = Number(data.transform?.shift_elevation ?? state.shiftEl);
  state.twist = Number(data.transform?.twist_by_height ?? state.twist);
  state.collapse = Number(data.transform?.collapse_to_equator ?? state.collapse);
  state.distanceScale = Number(data.transform?.distance_scale ?? state.distanceScale);
  state.distanceFlare = Number(data.transform?.distance_flare ?? state.distanceFlare);
  state.showPoints = data.visualization?.points !== false;
  state.showHeatmap = data.visualization?.heatmap === true;
  state.heatmapPalette = data.visualization?.heatmap_palette || state.heatmapPalette;
  state.viewMode = data.visualization?.view_mode === "map" ? "map" : "globe";
  state.showPolygon = data.polygon?.enabled !== false;
  state.polygonMode = data.polygon?.mode || state.polygonMode;
  state.duration = Number(data.timeline?.duration_seconds || data.duration || state.duration);
  state.playT = Number(data.timeline?.preview_t ?? state.playT);
  state.frameCount = Number(data.timeline?.frame_count ?? state.frameCount);
  if (Array.isArray(data.scenes) && data.scenes.length) {
    state.scenes = data.scenes.map((scene, index) => makeScene(scene.name || String.fromCharCode(65 + index), Number(scene.t) || 0, Array.isArray(scene.target) ? scene.target.map(cleanPoint) : state.base));
    sortScenes();
    state.selectedScene = 0;
    syncTargetFromScene();
  } else if (Array.isArray(data.target) && data.target.length === 24) {
    state.target = data.target.map(cleanPoint);
  }
  syncControls();
  draw();
}

function autosave() {
  try {
    const timeline = timelineData();
    const json = JSON.stringify({
      format: "s3g-mc-displacement-score",
      version: 1,
      tool: "s3g-mc Displacement Score",
      name: state.name,
      intended_use: "3OAFX 24-point virtual speaker displacement before re-encoding",
      geometry: "s3g 3OA 24 virtual speakers",
      method: state.method,
      normalize_radius_for_encode: state.normalizeRadius,
      amount: state.amount,
      scales: { azimuth: state.azScale, elevation: state.elScale, radius: state.rScale },
      transform: methodTransformData(),
      visualization: { points: state.showPoints, heatmap: state.showHeatmap, heatmap_palette: state.heatmapPalette, view_mode: state.viewMode },
      polygon: { enabled: state.showPolygon, mode: state.polygonMode, edges: MESH_EDGES },
      timeline,
      source: state.base,
      target: state.target,
      scenes: state.scenes,
      resolved: state.base.map((_, i) => displacedPoint(i, state.playT)),
      frames: timeline.frames,
    });
    if (json === lastAutosaveJson) return;
    localStorage.setItem(STORAGE_KEY, json);
    lastAutosaveJson = json;
  } catch (error) {
    // Autosave should not interrupt editing.
  }
}

function restoreAutosave() {
  try {
    const json = localStorage.getItem(STORAGE_KEY);
    if (!json) return false;
    loadJsonData(JSON.parse(json));
    lastAutosaveJson = json;
    return true;
  } catch (error) {
    localStorage.removeItem(STORAGE_KEY);
    return false;
  }
}

function importJson(file) {
  const reader = new FileReader();
  reader.onload = () => {
    loadJsonData(JSON.parse(String(reader.result || "{}")));
  };
  reader.readAsText(file);
}

function cleanPoint(p, i) {
  return {
    channel: Number(p.channel || i + 1),
    azimuth: wrapDeg(Number(p.azimuth || 0)),
    elevation: clamp(Number(p.elevation || 0), -90, 90),
    radius: clamp(Number(p.radius || 1), 0.1, 2),
  };
}

function syncControls() {
  $("scoreName").value = state.name;
  $("amount").value = state.amount;
  $("amountValue").textContent = state.amount.toFixed(2);
  $("azScale").value = state.azScale;
  $("azScaleValue").textContent = state.azScale.toFixed(2);
  $("elScale").value = state.elScale;
  $("elScaleValue").textContent = state.elScale.toFixed(2);
  $("rScale").value = state.rScale;
  $("rScaleValue").textContent = state.rScale.toFixed(2);
  $("strength").value = state.strength;
  $("strengthValue").textContent = state.strength.toFixed(2);
  $("seed").value = state.seed;
  $("rotateAz").value = state.rotateAz;
  $("rotateAzValue").textContent = `${Math.round(state.rotateAz)}`;
  $("shiftEl").value = state.shiftEl;
  $("shiftElValue").textContent = `${Math.round(state.shiftEl)}`;
  $("twist").value = state.twist;
  $("twistValue").textContent = state.twist.toFixed(2);
  $("collapse").value = state.collapse;
  $("collapseValue").textContent = state.collapse.toFixed(2);
  $("distanceScale").value = state.distanceScale;
  $("distanceScaleValue").textContent = state.distanceScale.toFixed(2);
  $("distanceFlare").value = state.distanceFlare;
  $("distanceFlareValue").textContent = state.distanceFlare.toFixed(2);
  $("method").value = state.method;
  $("normalizeRadius").checked = state.normalizeRadius;
  $("showPoints").checked = state.showPoints;
  $("showPolygon").checked = state.showPolygon;
  $("showHeatmap").checked = state.showHeatmap;
  $("heatmapPalette").value = state.heatmapPalette;
  $("polygonMode").value = state.polygonMode;
  $("duration").value = state.duration;
  $("durationValue").textContent = `${state.duration.toFixed(2)}s`;
  $("timePosition").value = state.playT;
  $("timeValue").textContent = `${state.playT.toFixed(3)} / ${(state.playT * state.duration).toFixed(2)}s`;
  $("frameCount").value = state.frameCount;
  $("frameCountValue").textContent = String(Math.round(state.frameCount));
  populateSceneSelect();
  $("sceneSelect").value = String(state.selectedScene);
  $("sceneName").value = currentScene().name || `Scene ${state.selectedScene + 1}`;
  $("sceneTime").value = (currentScene().t * state.duration).toFixed(3);
  $("cameraAz").value = state.cameraAz;
  $("cameraAzValue").textContent = Math.round(state.cameraAz);
  $("cameraEl").value = state.cameraEl;
  $("cameraElValue").textContent = Math.round(state.cameraEl);
  $("zoom").value = state.zoom;
  $("zoomValue").textContent = state.zoom.toFixed(2);
  $("viewGlobe").classList.toggle("active", state.viewMode === "globe");
  $("viewMap").classList.toggle("active", state.viewMode === "map");
  updateAllRangeFills();
  refreshCustomSelects();
}

function updateReadouts() {
  $("timeReadout").textContent = `${(state.playT * state.duration).toFixed(2)}s / ${state.duration.toFixed(2)}s`;
  $("coordReadout").textContent = `${state.scenes.length} scenes / ${Math.round(state.frameCount)} frames / ${state.viewMode === "map" ? "Peters map" : "globe"}`;
  $("modeReadout").textContent = `${currentScene().name || `Scene ${state.selectedScene + 1}`} / blend ${effectiveAmount().toFixed(2)}`;
}

function populateSceneSelect() {
  const select = $("sceneSelect");
  const old = select.value;
  select.innerHTML = "";
  sortScenes();
  state.scenes.forEach((scene, i) => {
    const option = document.createElement("option");
    option.value = String(i);
    option.textContent = `${scene.name || `Scene ${i + 1}`} / ${(scene.t * state.duration).toFixed(2)}s`;
    select.appendChild(option);
  });
  if (old && Number(old) < state.scenes.length) select.value = old;
}

function addScene() {
  const name = String.fromCharCode(65 + Math.min(25, state.scenes.length));
  const t = state.playT <= 0.000001 ? 1 : state.playT;
  state.scenes.push(makeScene(name, t, targetAt(t)));
  sortScenes();
  state.selectedScene = state.scenes.findIndex((scene) => scene.name === name);
  syncTargetFromScene();
  syncControls();
  draw();
}

function deleteScene() {
  if (state.scenes.length <= 1) return;
  state.scenes.splice(state.selectedScene, 1);
  state.selectedScene = clamp(state.selectedScene, 0, state.scenes.length - 1);
  syncTargetFromScene();
  syncControls();
  draw();
}

function setSceneTimeSeconds(seconds) {
  const minT = state.selectedScene === 0 ? 0 : 0.001;
  currentScene().t = clamp(Number(seconds) / Math.max(0.001, state.duration), minT, 1);
  sortScenes();
  syncControls();
  draw();
}

function setSceneName(name) {
  const scene = currentScene();
  scene.name = String(name || "").trim() || `Scene ${state.selectedScene + 1}`;
  populateSceneSelect();
  $("sceneSelect").value = String(state.selectedScene);
  refreshCustomSelects();
  updateReadouts();
  draw();
}

function startPlayback() {
  state.playing = true;
  state.playStart = performance.now() - state.playT * state.duration * 1000;
}

function stopPlayback() {
  state.playing = false;
  state.playT = 0;
  syncControls();
  draw();
}

function renderLoop() {
  if (state.playing) {
    const elapsed = (performance.now() - state.playStart) / 1000;
    state.playT = (elapsed % state.duration) / state.duration;
    syncControls();
    draw();
  }
  requestAnimationFrame(renderLoop);
}

function playbarPointer(event) {
  const rect = playbar.getBoundingClientRect();
  const x = event.clientX - rect.left;
  state.playT = clamp((x - 20) / Math.max(1, rect.width - 40), 0, 1);
  if (state.playing) state.playStart = performance.now() - state.playT * state.duration * 1000;
  syncControls();
  draw();
}

function readPanelState() {
  state.name = $("scoreName").value;
  state.method = $("method").value;
  state.amount = Number($("amount").value);
  state.azScale = Number($("azScale").value);
  state.elScale = Number($("elScale").value);
  state.rScale = Number($("rScale").value);
  state.strength = Number($("strength").value);
  state.seed = Number($("seed").value);
  state.rotateAz = Number($("rotateAz").value);
  state.shiftEl = Number($("shiftEl").value);
  state.twist = Number($("twist").value);
  state.collapse = Number($("collapse").value);
  state.distanceScale = Number($("distanceScale").value);
  state.distanceFlare = Number($("distanceFlare").value);
  state.normalizeRadius = $("normalizeRadius").checked;
  state.showPoints = $("showPoints").checked;
  state.showPolygon = $("showPolygon").checked;
  state.showHeatmap = $("showHeatmap").checked;
  state.heatmapPalette = $("heatmapPalette").value;
  state.polygonMode = $("polygonMode").value;
  state.duration = Number($("duration").value);
  state.playT = Number($("timePosition").value);
  state.frameCount = Number($("frameCount").value);
  state.cameraAz = Number($("cameraAz").value);
  state.cameraEl = Number($("cameraEl").value);
  state.zoom = Number($("zoom").value);
}

function viewPointer(event) {
  const dx = event.clientX - state.viewDrag.x;
  const dy = event.clientY - state.viewDrag.y;
  state.cameraAz = wrapDeg(state.viewDrag.az - dx * 0.35);
  state.cameraEl = clamp(state.viewDrag.el + dy * 0.28, -90, 90);
  syncControls();
  draw();
}

function init() {
  initCollapsiblePanels();
  enhanceCustomSelects();
  $("viewGlobe").addEventListener("click", () => { state.viewMode = "globe"; syncControls(); draw(); });
  $("viewMap").addEventListener("click", () => { state.viewMode = "map"; syncControls(); draw(); });
  $("viewTop").addEventListener("click", () => setView(0, 90, 1));
  $("viewFront").addEventListener("click", () => setView(0, 0, 1));
  $("viewSide").addEventListener("click", () => setView(90, 0, 1));
  $("viewIso").addEventListener("click", () => setView(38, 24, 1));
  $("play").addEventListener("click", startPlayback);
  $("stop").addEventListener("click", stopPlayback);
  $("applyPreset").addEventListener("click", applyPreset);
  $("resetTargets").addEventListener("click", resetTargets);
  $("addScene").addEventListener("click", addScene);
  $("deleteScene").addEventListener("click", deleteScene);
  $("captureScene").addEventListener("click", () => { captureCurrentScene(); draw(); });
  $("exportJson").addEventListener("click", exportJson);
  $("importJson").addEventListener("click", () => $("jsonFile").click());
  $("jsonFile").addEventListener("change", (event) => event.target.files[0] && importJson(event.target.files[0]));
  $("preset").addEventListener("change", applyPreset);
  const methodControlIds = new Set(["strength", "seed", "rotateAz", "shiftEl", "twist", "collapse", "distanceScale", "distanceFlare"]);
  ["scoreName", "method", "amount", "azScale", "elScale", "rScale", "strength", "seed", "rotateAz", "shiftEl", "twist", "collapse", "distanceScale", "distanceFlare", "normalizeRadius", "showPoints", "showPolygon", "showHeatmap", "heatmapPalette", "polygonMode", "duration", "timePosition", "frameCount", "cameraAz", "cameraEl", "zoom"].forEach((id) => {
    $(id).addEventListener("input", () => {
      readPanelState();
      if (methodControlIds.has(id)) {
        applyPreset();
        return;
      }
      syncControls();
      draw();
    });
  });
  $("sceneSelect").addEventListener("change", () => {
    state.selectedScene = Number($("sceneSelect").value);
    syncTargetFromScene();
    syncControls();
    draw();
  });
  $("sceneName").addEventListener("input", () => setSceneName($("sceneName").value));
  $("sceneTime").addEventListener("change", () => setSceneTimeSeconds($("sceneTime").value));
  playbar.addEventListener("pointerdown", (event) => {
    state.dragging = true;
    playbarPointer(event);
    playbar.setPointerCapture(event.pointerId);
  });
  playbar.addEventListener("pointermove", (event) => {
    if (state.dragging) playbarPointer(event);
  });
  playbar.addEventListener("pointerup", (event) => { state.dragging = false; playbar.releasePointerCapture(event.pointerId); });
  canvas.addEventListener("pointerdown", (event) => {
    if (state.viewMode !== "globe") return;
    if (!event.shiftKey) return;
    event.preventDefault();
    state.viewDragging = true;
    state.viewDrag = { x: event.clientX, y: event.clientY, az: state.cameraAz, el: state.cameraEl };
    canvas.setPointerCapture(event.pointerId);
  });
  canvas.addEventListener("pointermove", (event) => {
    if (!state.viewDragging) return;
    event.preventDefault();
    viewPointer(event);
  });
  canvas.addEventListener("pointerup", (event) => {
    if (!state.viewDragging) return;
    state.viewDragging = false;
    state.viewDrag = null;
    canvas.releasePointerCapture(event.pointerId);
  });
  canvas.addEventListener("wheel", (event) => {
    if (state.viewMode !== "globe") return;
    event.preventDefault();
    const factor = event.deltaY < 0 ? 1.06 : 0.94;
    state.zoom = clamp(state.zoom * factor, 0.55, 1.8);
    syncControls();
    draw();
  }, { passive: false });
  document.querySelectorAll('input[type="range"]').forEach((input) => {
    input.addEventListener("input", () => updateRangeFill(input));
  });
  window.addEventListener("resize", draw);
  if (!restoreAutosave()) {
    syncControls();
    draw();
  }
  updateAllRangeFills();
  refreshCustomSelects();
  setInterval(autosave, 2000);
  window.addEventListener("beforeunload", autosave);
  requestAnimationFrame(renderLoop);
}

init();
