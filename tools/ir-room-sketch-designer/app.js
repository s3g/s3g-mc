const $ = (id) => document.getElementById(id);

const canvas = $("roomCanvas");
const ctx = canvas.getContext("2d");
const timelineCanvas = $("timelineCanvas");
const timelineCtx = timelineCanvas.getContext("2d");

const controls = {
  roomX: $("roomX"),
  roomY: $("roomY"),
  roomZ: $("roomZ"),
  materialPreset: $("materialPreset"),
  absorption: $("absorption"),
  scattering: $("scattering"),
  tailSoften: $("tailSoften"),
  sourceAz: $("sourceAz"),
  sourceEl: $("sourceEl"),
  sourceDistance: $("sourceDistance"),
  spreadDeg: $("spreadDeg"),
  order: $("order"),
  directionSet: $("directionSet"),
  duration: $("duration"),
  preDelay: $("preDelay"),
  earlyReflections: $("earlyReflections")
};

const readouts = {
  rt60: $("rt60Readout"),
  volume: $("volumeReadout"),
  channels: $("channelReadout"),
  late: $("lateReadout"),
  group: $("groupReadout"),
  json: $("jsonPreview")
};

const state = {
  view: "top",
  selectedDirection: 0,
  directionHitPoints: []
};

const materials = {
  concrete: { absorption: 0.12, scattering: 0.32, tailSoften: 0.16 },
  stone: { absorption: 0.18, scattering: 0.48, tailSoften: 0.22 },
  wood: { absorption: 0.30, scattering: 0.55, tailSoften: 0.36 },
  studio: { absorption: 0.42, scattering: 0.42, tailSoften: 0.48 },
  damped: { absorption: 0.68, scattering: 0.38, tailSoften: 0.72 },
  glass: { absorption: 0.20, scattering: 0.22, tailSoften: 0.12 }
};

function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, v));
}

function updateRangeFill(input) {
  const min = Number(input.min || 0);
  const max = Number(input.max || 100);
  const value = Number(input.value || 0);
  const fill = max === min ? 0 : clamp((value - min) / (max - min), 0, 1) * 100;
  input.style.setProperty("--fill", `${fill.toFixed(2)}%`);
}

function updateAllRangeFills() {
  document.querySelectorAll('input[type="range"]').forEach(updateRangeFill);
}

function settings() {
  const roomX = Number(controls.roomX.value);
  const roomY = Number(controls.roomY.value);
  const roomZ = Number(controls.roomZ.value);
  const absorption = Number(controls.absorption.value);
  const scattering = Number(controls.scattering.value);
  const duration = Number(controls.duration.value);
  const preDelay = Number(controls.preDelay.value);
  const volume = roomX * roomY * roomZ;
  const surface = 2 * (roomX * roomY + roomX * roomZ + roomY * roomZ);
  const rt60 = clamp(0.161 * volume / Math.max(0.01, surface * absorption), 0.08, 8.0);
  const lateStart = Math.min(duration * 0.92, preDelay / 1000 + 0.035 + (1 - scattering) * 0.080);
  const order = Number(controls.order.value);
  const directionSet = controls.directionSet.value;
  const directionCount = activeDirections(directionSet).length;
  return {
    room_x: roomX,
    room_y: roomY,
    room_z: roomZ,
    material_preset: controls.materialPreset.value,
    absorption,
    scattering,
    tail_soften: Number(controls.tailSoften.value),
    source_azimuth: Number(controls.sourceAz.value),
    source_elevation: Number(controls.sourceEl.value),
    source_distance: Number(controls.sourceDistance.value),
    direction_spread_deg: Number(controls.spreadDeg.value),
    order,
    channels_per_ir: (order + 1) * (order + 1),
    direction_set: directionSet,
    direction_count: directionCount,
    stacked_channels: directionCount * (order + 1) * (order + 1),
    duration,
    pre_delay_ms: preDelay,
    early_reflections: Number(controls.earlyReflections.value),
    estimated_rt60: rt60,
    late_start_seconds: lateStart
  };
}

function unitFromAed(azDeg, elDeg) {
  const az = azDeg * Math.PI / 180;
  const el = elDeg * Math.PI / 180;
  return {
    x: Math.sin(az) * Math.cos(el),
    y: Math.sin(el),
    z: Math.cos(az) * Math.cos(el)
  };
}

function directionSetDirections(name) {
  if (name === "single") return [[0, 0]];
  if (name === "tetra") return [[45, 35], [-45, -35], [135, -35], [-135, 35]];
  if (name === "ring8") return Array.from({ length: 8 }, (_, i) => [45 - i * 45, 0]);
  if (name === "virtual24") {
    const lower = Array.from({ length: 8 }, (_, i) => [45 - i * 45, -35]);
    const mid = Array.from({ length: 8 }, (_, i) => [45 - i * 45, 0]);
    const upper = Array.from({ length: 8 }, (_, i) => [45 - i * 45, 45]);
    return [...lower, ...mid, ...upper];
  }
  return [
    [45, 35], [-45, 35], [-135, 35], [135, 35],
    [45, -35], [-45, -35], [-135, -35], [135, -35]
  ];
}

function activeDirections(directionSetOrSettings = settings()) {
  const directionSet = typeof directionSetOrSettings === "string" ? directionSetOrSettings : directionSetOrSettings.direction_set;
  if (directionSet === "single") {
    const sourceAz = Number(controls.sourceAz.value);
    const sourceEl = Number(controls.sourceEl.value);
    return [[sourceAz, sourceEl]];
  }
  return directionSetDirections(directionSet);
}

function selectedDirection(s) {
  const dirs = activeDirections(s);
  const index = clamp(state.selectedDirection, 0, Math.max(0, dirs.length - 1));
  state.selectedDirection = index;
  const dir = dirs[index] || [0, 0];
  const channelsStart = index * s.channels_per_ir + 1;
  return {
    index,
    count: dirs.length,
    azimuth: dir[0],
    elevation: dir[1],
    channels_start: channelsStart,
    channels_end: channelsStart + s.channels_per_ir - 1
  };
}

function roomPoints(s, dir = selectedDirection(s)) {
  const listener = { x: s.room_x * 0.5, y: s.room_y * 0.5, z: s.room_z * 0.5 };
  const unit = unitFromAed(dir.azimuth, dir.elevation);
  const maxDist = Math.min(s.source_distance, Math.min(s.room_x, s.room_y, s.room_z) * 0.48);
  const source = {
    x: clamp(listener.x + unit.x * maxDist, 0.05, s.room_x - 0.05),
    y: clamp(listener.y + unit.z * maxDist, 0.05, s.room_y - 0.05),
    z: clamp(listener.z + unit.y * maxDist, 0.05, s.room_z - 0.05)
  };
  return { listener, source };
}

function reflectionEvents(s, dir = selectedDirection(s)) {
  const { listener, source } = roomPoints(s, dir);
  const images = [
    { pos: { x: -source.x, y: source.y, z: source.z }, wall: "L" },
    { pos: { x: 2 * s.room_x - source.x, y: source.y, z: source.z }, wall: "R" },
    { pos: { x: source.x, y: -source.y, z: source.z }, wall: "F" },
    { pos: { x: source.x, y: 2 * s.room_y - source.y, z: source.z }, wall: "B" },
    { pos: { x: source.x, y: source.y, z: -source.z }, wall: "D" },
    { pos: { x: source.x, y: source.y, z: 2 * s.room_z - source.z }, wall: "U" }
  ];
  const reflectivity = Math.sqrt(Math.max(0, 1 - s.absorption));
  return images.map((image, index) => {
    const dx = image.pos.x - listener.x;
    const dy = image.pos.y - listener.y;
    const dz = image.pos.z - listener.z;
    const distance = Math.sqrt(dx * dx + dy * dy + dz * dz);
    return {
      wall: image.wall,
      time: s.pre_delay_ms / 1000 + distance / 343,
      amp: Math.pow(reflectivity, 1 + index * 0.15) / Math.max(1, distance),
      az: Math.atan2(dx, dy) * 180 / Math.PI,
      el: Math.asin(clamp(dz / Math.max(0.001, distance), -1, 1)) * 180 / Math.PI
    };
  }).sort((a, b) => a.time - b.time);
}

function drawRoom() {
  const s = settings();
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = "#050607";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  if (state.view === "sphere") drawDirections(s);
  else drawRoomView(s);
  drawTimeline(s);
  updateReadouts(s);
}

function drawRoomView(s) {
  const pad = 48;
  const roomW = state.view === "side" ? s.room_x : s.room_x;
  const roomH = state.view === "side" ? s.room_z : s.room_y;
  const scale = Math.min((canvas.width - pad * 2) / roomW, (canvas.height - pad * 2) / roomH);
  const ox = (canvas.width - roomW * scale) / 2;
  const oy = (canvas.height - roomH * scale) / 2;
  const selected = selectedDirection(s);
  const { listener, source } = roomPoints(s, selected);
  const px = (p) => ox + p.x * scale;
  const py = (p) => oy + (state.view === "side" ? (roomH - p.z) : p.y) * scale;
  const listenerPoint = { x: listener.x, y: listener.y, z: listener.z };
  const sourcePoint = { x: source.x, y: source.y, z: source.z };

  ctx.strokeStyle = "#646464";
  ctx.lineWidth = 1;
  ctx.strokeRect(ox, oy, roomW * scale, roomH * scale);

  const grid = state.view === "side" ? s.room_z : s.room_y;
  ctx.strokeStyle = "rgba(255,255,255,0.09)";
  for (let i = 1; i < 8; i += 1) {
    const x = ox + roomW * scale * i / 8;
    ctx.beginPath();
    ctx.moveTo(x, oy);
    ctx.lineTo(x, oy + roomH * scale);
    ctx.stroke();
    const y = oy + grid * scale * i / 8;
    ctx.beginPath();
    ctx.moveTo(ox, y);
    ctx.lineTo(ox + roomW * scale, y);
    ctx.stroke();
  }

  activeDirections(s).forEach((dir, index) => {
    const info = {
      index,
      azimuth: dir[0],
      elevation: dir[1],
      channels_start: index * s.channels_per_ir + 1,
      channels_end: (index + 1) * s.channels_per_ir
    };
    const point = roomPoints(s, info).source;
    const active = index === selected.index;
    drawPoint(px(point), py(point), active ? 7 : 4, active ? "#5aa8c7" : "rgba(90,168,199,0.42)", String(index + 1), active);
  });

  const events = reflectionEvents(s, selected);
  ctx.strokeStyle = "rgba(216, 162, 74, 0.5)";
  events.slice(0, Math.min(events.length, s.early_reflections)).forEach((event) => {
    const dir = unitFromAed(event.az, event.el);
    const endpoint = {
      x: clamp(listener.x + dir.x * s.source_distance * 0.65, 0, s.room_x),
      y: clamp(listener.y + dir.z * s.source_distance * 0.65, 0, s.room_y),
      z: clamp(listener.z + dir.y * s.source_distance * 0.65, 0, s.room_z)
    };
    ctx.beginPath();
    ctx.moveTo(px(listenerPoint), py(listenerPoint));
    ctx.lineTo(px(endpoint), py(endpoint));
    ctx.stroke();
  });

  ctx.strokeStyle = "rgba(90, 190, 220, 0.9)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(px(listenerPoint), py(listenerPoint));
  ctx.lineTo(px(sourcePoint), py(sourcePoint));
  ctx.stroke();

  drawPoint(px(listenerPoint), py(listenerPoint), 7, "#d7d7d7", "L", true);
  drawPoint(px(sourcePoint), py(sourcePoint), 8, "#5aa8c7", String(selected.index + 1), true);
  ctx.fillStyle = "#9a9a9a";
  ctx.font = "11px Menlo, monospace";
  ctx.fillText(`${state.view.toUpperCase()} group ${selected.index + 1}/${selected.count}  ${selected.azimuth} az / ${selected.elevation} el`, 12, 20);
}

function drawPoint(x, y, r, color, label, labelInside = false) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.fill();
  if (!labelInside) {
    ctx.fillStyle = "#d7d7d7";
    ctx.font = "10px Menlo, monospace";
    ctx.fillText(label, x + r + 4, y + 3);
    return;
  }
  ctx.fillStyle = "#050607";
  ctx.font = "10px Menlo, monospace";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(label, x, y + 0.5);
  ctx.textAlign = "start";
  ctx.textBaseline = "alphabetic";
}

function drawDirections(s) {
  const dirs = activeDirections(s);
  const selected = selectedDirection(s);
  const cx = canvas.width / 2;
  const cy = canvas.height / 2;
  const r = Math.min(canvas.width, canvas.height) * 0.36;
  ctx.strokeStyle = "rgba(210,210,210,0.42)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.arc(cx, cy, r, 0, Math.PI * 2);
  ctx.stroke();
  ctx.strokeStyle = "rgba(120,120,120,0.34)";
  ctx.beginPath();
  ctx.ellipse(cx, cy, r, r * 0.28, 0, 0, Math.PI * 2);
  ctx.stroke();
  ctx.beginPath();
  ctx.ellipse(cx, cy, r * 0.28, r, 0, 0, Math.PI * 2);
  ctx.stroke();
  state.directionHitPoints = [];

  dirs.forEach((dir, index) => {
    const unit = unitFromAed(dir[0], dir[1]);
    const x = cx - unit.x * r * 0.9;
    const y = cy - unit.y * r * 0.9;
    const z = unit.z;
    const active = index === selected.index;
    const radius = active ? 9 : 5 + Math.max(0, z) * 2;
    state.directionHitPoints.push({ x, y, r: radius + 8, index });
    ctx.globalAlpha = active ? 1 : 0.42 + Math.max(0, z) * 0.36;
    ctx.fillStyle = active ? "#d8a24a" : "#5aa8c7";
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#d7d7d7";
    ctx.font = "10px Menlo, monospace";
    ctx.fillText(`G${index + 1}`, x + 11, y + 3);
    if (active) {
      ctx.strokeStyle = "rgba(216, 162, 74, 0.72)";
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(x, y);
      ctx.stroke();
    }
  });
  ctx.globalAlpha = 1;
  ctx.fillStyle = "#9a9a9a";
  ctx.fillText(`${dirs.length} IR groups / ${s.channels_per_ir}ch per group / ${s.stacked_channels}ch stacked`, 12, 20);
  ctx.fillText(`selected G${selected.index + 1}: ${selected.channels_start}-${selected.channels_end}`, 12, 38);
}

function drawTimeline(s) {
  const w = timelineCanvas.width;
  const h = timelineCanvas.height;
  timelineCtx.clearRect(0, 0, w, h);
  timelineCtx.fillStyle = "#050607";
  timelineCtx.fillRect(0, 0, w, h);
  timelineCtx.strokeStyle = "#4a5259";
  timelineCtx.strokeRect(0.5, 0.5, w - 1, h - 1);

  const events = reflectionEvents(s);
  const duration = Math.max(0.1, s.duration);
  timelineCtx.fillStyle = "rgba(90, 190, 220, 0.18)";
  const lateX = clamp(s.late_start_seconds / duration, 0, 1) * w;
  timelineCtx.fillRect(lateX, 0, w - lateX, h);

  events.forEach((event) => {
    const x = clamp(event.time / duration, 0, 1) * w;
    const height = clamp(event.amp * 220, 6, h - 20);
    timelineCtx.strokeStyle = "rgba(216, 162, 74, 0.85)";
    timelineCtx.beginPath();
    timelineCtx.moveTo(x + 0.5, h - 12);
    timelineCtx.lineTo(x + 0.5, h - 12 - height);
    timelineCtx.stroke();
  });

  timelineCtx.strokeStyle = "rgba(215,215,215,0.5)";
  timelineCtx.beginPath();
  for (let x = 0; x < w; x += 1) {
    const t = x / w * duration;
    const env = t < s.late_start_seconds ? 0 : Math.exp(-(t - s.late_start_seconds) / Math.max(0.04, s.estimated_rt60 * 0.42));
    const y = h - 12 - env * (h - 32) * (1 - s.tail_soften * 0.55);
    if (x === 0) timelineCtx.moveTo(x, y);
    else timelineCtx.lineTo(x, y);
  }
  timelineCtx.stroke();

  timelineCtx.fillStyle = "#9a9a9a";
  timelineCtx.font = "10px Menlo, monospace";
  timelineCtx.fillText("early reflections / late tail", 8, 14);
}

function updateReadouts(s) {
  const selected = selectedDirection(s);
  const points = roomPoints(s, selected);
  readouts.rt60.textContent = `${s.estimated_rt60.toFixed(2)} s`;
  readouts.volume.textContent = `${(s.room_x * s.room_y * s.room_z).toFixed(1)} m3`;
  readouts.channels.textContent = `${s.stacked_channels}`;
  readouts.late.textContent = `${Math.round(s.late_start_seconds * 1000)} ms`;
  readouts.group.innerHTML = `
    <div><span>Group</span><strong>${selected.index + 1} / ${selected.count}</strong></div>
    <div><span>AED</span><strong>${round(selected.azimuth)} deg / ${round(selected.elevation)} deg</strong></div>
    <div><span>Stacked channels</span><strong>${selected.channels_start}-${selected.channels_end}</strong></div>
    <div><span>Source XYZ m</span><strong>${round(points.source.x, 2)}, ${round(points.source.y, 2)}, ${round(points.source.z, 2)}</strong></div>
  `;
  readouts.json.textContent = JSON.stringify(exportObject(s), null, 2);
}

function exportObject(s = settings()) {
  const groups = activeDirections(s).map((d, i) => {
    const info = {
      index: i,
      azimuth: d[0],
      elevation: d[1],
      channels_start: i * s.channels_per_ir + 1,
      channels_end: (i + 1) * s.channels_per_ir
    };
    const points = roomPoints(s, info);
    return {
      group: i + 1,
      azimuth: d[0],
      elevation: d[1],
      channels: `${info.channels_start}-${info.channels_end}`,
      source_position_m: {
        x: round(points.source.x, 3),
        y: round(points.source.y, 3),
        z: round(points.source.z, 3)
      }
    };
  });
  return {
    tool: "s3g-mc IR Room Sketch Designer",
    target_process: "3OAFX Synthetic Ambisonic IR Bank",
    room_x: round(s.room_x),
    room_y: round(s.room_y),
    room_z: round(s.room_z),
    material_preset: s.material_preset,
    absorption: round(s.absorption, 3),
    scattering: round(s.scattering, 3),
    tail_soften: round(s.tail_soften, 3),
    source_azimuth: round(s.source_azimuth),
    source_elevation: round(s.source_elevation),
    source_distance: round(s.source_distance, 3),
    direction_spread_deg: round(s.direction_spread_deg),
    order: s.order,
    direction_set: s.direction_set,
    groups,
    duration: round(s.duration, 3),
    pre_delay_ms: round(s.pre_delay_ms),
    early_reflections: round(s.early_reflections),
    estimated_rt60: round(s.estimated_rt60, 3),
    late_start_seconds: round(s.late_start_seconds, 3)
  };
}

function round(v, places = 2) {
  const f = 10 ** places;
  return Math.round(v * f) / f;
}

function downloadJson() {
  const blob = new Blob([JSON.stringify(exportObject(), null, 2)], { type: "application/json" });
  const link = document.createElement("a");
  link.download = "s3g_ir_room_sketch.json";
  link.href = URL.createObjectURL(blob);
  link.click();
  URL.revokeObjectURL(link.href);
}

function applyMaterial() {
  const material = materials[controls.materialPreset.value];
  if (!material) return;
  controls.absorption.value = material.absorption;
  controls.scattering.value = material.scattering;
  controls.tailSoften.value = material.tailSoften;
  updateAllRangeFills();
  drawRoom();
}

function resetDefaults() {
  controls.roomX.value = 12;
  controls.roomY.value = 9;
  controls.roomZ.value = 5;
  controls.materialPreset.value = "concrete";
  controls.sourceAz.value = 35;
  controls.sourceEl.value = 10;
  controls.sourceDistance.value = 3.2;
  controls.spreadDeg.value = 45;
  controls.order.value = 3;
  controls.directionSet.value = "cube";
  controls.duration.value = 3;
  controls.preDelay.value = 12;
  controls.earlyReflections.value = 18;
  state.selectedDirection = 0;
  applyMaterial();
}

function randomize() {
  const presets = Object.keys(materials);
  controls.materialPreset.value = presets[Math.floor(Math.random() * presets.length)];
  controls.roomX.value = round(6 + Math.random() * 26, 1);
  controls.roomY.value = round(4 + Math.random() * 18, 1);
  controls.roomZ.value = round(2.8 + Math.random() * 8, 1);
  controls.sourceAz.value = Math.round(-160 + Math.random() * 320);
  controls.sourceEl.value = Math.round(-25 + Math.random() * 70);
  controls.sourceDistance.value = round(1 + Math.random() * 8, 2);
  controls.spreadDeg.value = Math.round(20 + Math.random() * 80);
  controls.duration.value = round(1.5 + Math.random() * 5.5, 2);
  controls.preDelay.value = Math.round(Math.random() * 45);
  controls.earlyReflections.value = Math.round(8 + Math.random() * 34);
  state.selectedDirection = 0;
  applyMaterial();
}

Object.values(controls).forEach((control) => {
  control.addEventListener("input", () => {
    if (control.type === "range") updateRangeFill(control);
    drawRoom();
  });
  control.addEventListener("change", drawRoom);
});

controls.materialPreset.addEventListener("change", applyMaterial);

document.querySelectorAll(".section-toggle").forEach((button) => {
  button.addEventListener("click", () => {
    const section = button.closest(".collapsible");
    const collapsed = section.classList.toggle("collapsed");
    button.textContent = collapsed ? "+" : "-";
    button.setAttribute("aria-expanded", collapsed ? "false" : "true");
  });
});

document.querySelectorAll("[data-view]").forEach((button) => {
  button.addEventListener("click", () => {
    state.view = button.dataset.view;
    document.querySelectorAll("[data-view]").forEach((viewButton) => {
      viewButton.classList.toggle("active", viewButton === button);
    });
    drawRoom();
  });
});

canvas.addEventListener("pointerdown", (event) => {
  if (state.view !== "sphere") return;
  const rect = canvas.getBoundingClientRect();
  const scaleX = canvas.width / rect.width;
  const scaleY = canvas.height / rect.height;
  const x = (event.clientX - rect.left) * scaleX;
  const y = (event.clientY - rect.top) * scaleY;
  const hit = state.directionHitPoints.find((point) => {
    const dx = x - point.x;
    const dy = y - point.y;
    return Math.sqrt(dx * dx + dy * dy) <= point.r;
  });
  if (hit) {
    state.selectedDirection = hit.index;
    drawRoom();
  }
});

$("reset").addEventListener("click", resetDefaults);
$("randomize").addEventListener("click", randomize);
$("exportJson").addEventListener("click", downloadJson);

updateAllRangeFills();
applyMaterial();
