const $ = (id) => document.getElementById(id);

const canvas = $("roomCanvas");
const ctx = canvas.getContext("2d");
const ROOM_CANVAS_W = 900;
const ROOM_CANVAS_H = 560;
const roomSvg = $("roomSvg");
const timelineCanvas = $("timelineCanvas");
const timelineCtx = timelineCanvas.getContext("2d");
const gltfCanvas = $("gltfCanvas");
const gltfCtx = gltfCanvas.getContext("2d");

const controls = {
  roomX: $("roomX"),
  roomY: $("roomY"),
  roomZ: $("roomZ"),
  materialPreset: $("materialPreset"),
  absorption: $("absorption"),
  scattering: $("scattering"),
  tailSoften: $("tailSoften"),
  spaceShape: $("spaceShape"),
  roomShape: $("roomShape"),
  topologyBias: $("topologyBias"),
  chamberShape: $("chamberShape"),
  chamberSide: $("chamberSide"),
  chamberMaterial: $("chamberMaterial"),
  chamberMaterialMode: $("chamberMaterialMode"),
  chamberWidth: $("chamberWidth"),
  chamberDepth: $("chamberDepth"),
  chamberCount: $("chamberCount"),
  chamberPosition: $("chamberPosition"),
  nestedChambers: $("nestedChambers"),
  openingWidth: $("openingWidth"),
  chamberCoupling: $("chamberCoupling"),
  chamberMaterialMix: $("chamberMaterialMix"),
  outsideOpening: $("outsideOpening"),
  outsideOpeningSide: $("outsideOpeningSide"),
  outsideOpeningCount: $("outsideOpeningCount"),
  outsideOpeningPosition: $("outsideOpeningPosition"),
  outsideOpeningSpread: $("outsideOpeningSpread"),
  outsideOpeningWidth: $("outsideOpeningWidth"),
  outsideLeak: $("outsideLeak"),
  fieldX: $("fieldX"),
  fieldY: $("fieldY"),
  sourceAz: $("sourceAz"),
  sourceEl: $("sourceEl"),
  sourceDistance: $("sourceDistance"),
  spreadDeg: $("spreadDeg"),
  groupVariation: $("groupVariation"),
  surfaceContrast: $("surfaceContrast"),
  distanceVariation: $("distanceVariation"),
  order: $("order"),
  directionSet: $("directionSet"),
  duration: $("duration"),
  preDelay: $("preDelay"),
  earlyReflections: $("earlyReflections"),
  cameraAz: $("cameraAz"),
  cameraEl: $("cameraEl"),
  cameraZoom: $("cameraZoom"),
  showDirect: $("showDirect"),
  showEarly: $("showEarly"),
  showDiffuse: $("showDiffuse")
};

const readouts = {
  rt60: $("rt60Readout"),
  volume: $("volumeReadout"),
  channels: $("channelReadout"),
  late: $("lateReadout"),
  group: $("groupReadout"),
  groupStrip: $("groupStrip"),
  json: $("jsonPreview")
};

const state = {
  view: "top",
  selectedDirection: 0,
  directionHitPoints: [],
  roomHitPoints: [],
  matrixHitRows: [],
  roomProjection: null,
  bankProjection: null,
  groupMapPositions: {},
  drag: null,
  gltfDrag: null,
  gltfCamera: { azimuth: -38, elevation: 32, zoom: 1 }
};

const materials = {
  concrete: { absorption: 0.12, scattering: 0.32, tailSoften: 0.16 },
  brick: { absorption: 0.16, scattering: 0.62, tailSoften: 0.20 },
  stone: { absorption: 0.18, scattering: 0.48, tailSoften: 0.22 },
  wood: { absorption: 0.30, scattering: 0.55, tailSoften: 0.36 },
  metal: { absorption: 0.08, scattering: 0.18, tailSoften: 0.08 },
  studio: { absorption: 0.42, scattering: 0.42, tailSoften: 0.48 },
  damped: { absorption: 0.68, scattering: 0.38, tailSoften: 0.72 },
  glass: { absorption: 0.20, scattering: 0.22, tailSoften: 0.12 },
  fabric: { absorption: 0.74, scattering: 0.58, tailSoften: 0.82 },
  water: { absorption: 0.10, scattering: 0.70, tailSoften: 0.10 }
};

function configureRoomCanvas() {
  const dpr = Math.max(1, Math.min(3, window.devicePixelRatio || 1));
  const pixelW = Math.round(ROOM_CANVAS_W * dpr);
  const pixelH = Math.round(ROOM_CANVAS_H * dpr);
  if (canvas.width !== pixelW || canvas.height !== pixelH) {
    canvas.width = pixelW;
    canvas.height = pixelH;
  }
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.imageSmoothingEnabled = false;
}

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

function choice(items) {
  return items[Math.floor(Math.random() * items.length)];
}

function chooseByBias(low, mid, high, bias) {
  if (bias < 0.28) return choice(low);
  if (bias < 0.68) return choice(mid);
  return choice(high);
}

function settings() {
  const roomX = Number(controls.roomX.value);
  const roomY = Number(controls.roomY.value);
  const roomZ = Number(controls.roomZ.value);
  const baseAbsorption = Number(controls.absorption.value);
  const scattering = Number(controls.scattering.value);
  const duration = Number(controls.duration.value);
  const preDelay = Number(controls.preDelay.value);
  const volume = roomX * roomY * roomZ;
  const surface = 2 * (roomX * roomY + roomX * roomZ + roomY * roomZ);
  const outsideOpening = controls.outsideOpening.checked;
  const outsideOpeningCount = Math.max(1, Math.round(Number(controls.outsideOpeningCount.value)));
  const outsideOpeningWidth = Number(controls.outsideOpeningWidth.value);
  const outsideLeak = Number(controls.outsideLeak.value);
  const leakFactor = outsideOpening ? clamp(outsideOpeningWidth * outsideLeak * outsideOpeningCount, 0, 1) : 0;
  const absorption = clamp(baseAbsorption + leakFactor * 0.32, 0.03, 0.95);
  const rt60 = clamp(0.161 * volume / Math.max(0.01, surface * absorption), 0.08, 8.0);
  const lateStart = clamp(Math.min(duration * 0.92, preDelay / 1000 + 0.035 + (1 - scattering) * 0.080 - leakFactor * 0.030), 0.008, duration * 0.92);
  const order = Number(controls.order.value);
  const directionSet = controls.directionSet.value;
  const effectiveDirectionLayout = directionSet === "auto" ? (order === 1 ? "tetra" : "practical_8") : directionSet;
  const directionCount = activeDirections({ direction_set: directionSet, order }).length;
  return {
    room_x: roomX,
    room_y: roomY,
    room_z: roomZ,
    material_preset: controls.materialPreset.value,
    absorption,
    scattering,
    tail_soften: Number(controls.tailSoften.value),
    space_shape: controls.spaceShape.value,
    room_shape: controls.roomShape.value,
    topology_bias: Number(controls.topologyBias.value),
    chamber_shape: controls.chamberShape.value,
    chamber_side: controls.chamberSide.value,
    chamber_material: controls.chamberMaterial.value,
    chamber_material_mode: controls.chamberMaterialMode.value,
    chamber_width: Number(controls.chamberWidth.value),
    chamber_depth: Number(controls.chamberDepth.value),
    chamber_count: Number(controls.chamberCount.value),
    chamber_position: Number(controls.chamberPosition.value),
    nested_chambers: Number(controls.nestedChambers.value),
    opening_width: Number(controls.openingWidth.value),
    chamber_coupling: Number(controls.chamberCoupling.value),
    chamber_material_mix: Number(controls.chamberMaterialMix.value),
    outside_opening: outsideOpening,
    outside_opening_side: controls.outsideOpeningSide.value,
    outside_opening_count: outsideOpeningCount,
    outside_opening_position: Number(controls.outsideOpeningPosition.value),
    outside_opening_spread: Number(controls.outsideOpeningSpread.value),
    outside_opening_width: outsideOpeningWidth,
    outside_leak: outsideLeak,
    outside_leak_factor: leakFactor,
    field_x: Number(controls.fieldX.value),
    field_y: Number(controls.fieldY.value),
    source_azimuth: Number(controls.sourceAz.value),
    source_elevation: Number(controls.sourceEl.value),
    source_distance: Number(controls.sourceDistance.value),
    direction_spread_deg: Number(controls.spreadDeg.value),
    group_variation: Number(controls.groupVariation.value),
    surface_contrast: Number(controls.surfaceContrast.value),
    distance_variation: Number(controls.distanceVariation.value),
    order,
    channels_per_ir: (order + 1) * (order + 1),
    direction_set: directionSet,
    effective_direction_layout: effectiveDirectionLayout,
    direction_count: directionCount,
    stacked_channels: directionCount * (order + 1) * (order + 1),
    duration,
    pre_delay_ms: preDelay,
    early_reflections: Number(controls.earlyReflections.value),
    camera_azimuth: Number(controls.cameraAz.value),
    camera_elevation: Number(controls.cameraEl.value),
    camera_zoom: Number(controls.cameraZoom.value),
    show_direct: controls.showDirect.checked,
    show_early: controls.showEarly.checked,
    show_diffuse: controls.showDiffuse.checked,
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

function wrapDegrees(v) {
  let out = v % 360;
  if (out > 180) out -= 360;
  if (out < -180) out += 360;
  return out;
}

function seededNoise(seed) {
  const value = Math.sin(seed * 12.9898 + 78.233) * 43758.5453;
  return value - Math.floor(value);
}

function directionSetDirections(name) {
  if (name === "tetra") return [[45, 35.264], [-45, -35.264], [135, -35.264], [-135, 35.264]];
  return [
    [45, 35.264], [-45, 35.264], [135, 35.264], [-135, 35.264],
    [45, -35.264], [-45, -35.264], [135, -35.264], [-135, -35.264]
  ];
}

function activeDirections(directionSetOrSettings = settings()) {
  const directionSet = typeof directionSetOrSettings === "string" ? directionSetOrSettings : directionSetOrSettings.direction_set;
  const order = typeof directionSetOrSettings === "string" ? Number(controls.order.value) : Number(directionSetOrSettings.order || controls.order.value);
  if (directionSet === "auto") return directionSetDirections(order === 1 ? "tetra" : "cube");
  return directionSetDirections(directionSet);
}

function localRt60(s, absorption) {
  const volume = s.room_x * s.room_y * s.room_z;
  const surface = 2 * (s.room_x * s.room_y + s.room_x * s.room_z + s.room_y * s.room_z);
  const leakAbsorption = (s.outside_opening ? s.outside_leak_factor || 0 : 0) * 0.20;
  return clamp(0.161 * volume / Math.max(0.01, surface * clamp(absorption + leakAbsorption, 0.03, 0.95)), 0.08, 8.0);
}

function roomMaterialProfile(s) {
  return {
    absorption: s.absorption,
    scattering: s.scattering,
    tail_soften: s.tail_soften
  };
}

function chamberMaterialProfile(s, chamber) {
  const base = roomMaterialProfile(s);
  const palette = ["concrete", "brick", "stone", "wood", "metal", "glass", "fabric", "water"];
  let materialKey = s.chamber_material;
  if (s.chamber_material_mode === "alternating" && chamber.index % 2 === 1) materialKey = "inherit";
  if (s.chamber_material_mode === "nested" && chamber.level > 0) materialKey = palette[(palette.indexOf(s.chamber_material) + chamber.level + 2 + palette.length) % palette.length];
  if (s.chamber_material_mode === "palette") materialKey = palette[Math.floor(seededNoise((chamber.index + 1) * 61) * palette.length) % palette.length];
  const target = materialKey === "inherit" ? base : (materials[materialKey] || base);
  const mix = clamp(s.chamber_material_mix, 0, 1);
  const seed = (chamber.index + 1) * 137 + chamber.level * 19;
  const variation = 0.08 + s.group_variation * 0.14;
  const targetTail = target.tailSoften === undefined ? target.tail_soften : target.tailSoften;
  return {
    material_key: materialKey,
    absorption: clamp(base.absorption * (1 - mix) + target.absorption * mix + (seededNoise(seed) - 0.5) * variation, 0.03, 0.95),
    scattering: clamp(base.scattering * (1 - mix) + target.scattering * mix + (seededNoise(seed + 7) - 0.5) * variation, 0, 1),
    tail_soften: clamp(base.tail_soften * (1 - mix) + targetTail * mix + (seededNoise(seed + 13) - 0.5) * variation, 0, 1)
  };
}

function groupProfile(s, index) {
  const variation = s.group_variation;
  const contrast = s.surface_contrast;
  const distanceVariation = s.distance_variation;
  const n1 = seededNoise((index + 1) * 17);
  const n2 = seededNoise((index + 1) * 29);
  const n3 = seededNoise((index + 1) * 41);
  const n4 = seededNoise((index + 1) * 53);
  const absorption = clamp(s.absorption + (n1 - 0.5) * contrast * variation * 0.72, 0.03, 0.95);
  const scattering = clamp(s.scattering + (n2 - 0.5) * contrast * variation * 0.9, 0, 1);
  const tailSoften = clamp(s.tail_soften + (n3 - 0.5) * contrast * variation * 0.75, 0, 1);
  const distance = clamp(s.source_distance * (1 + (n4 - 0.5) * distanceVariation * 1.4 * variation), 0.25, Number(controls.sourceDistance.max || 20));
  const spread = clamp(s.direction_spread_deg * (1 + (n2 - 0.5) * variation * 0.8), 0, 120);
  const preDelay = Math.max(0, s.pre_delay_ms + (n3 - 0.5) * variation * 22);
  return {
    absorption,
    scattering,
    tail_soften: tailSoften,
    source_distance: distance,
    direction_spread_deg: spread,
    pre_delay_ms: preDelay,
    rt60: localRt60(s, absorption)
  };
}

function chamberGeometries(s) {
  if (s.space_shape !== "side_chamber") return null;
  const requestedSides = s.chamber_side === "all" ? ["front", "back", "left", "right"] : [s.chamber_side || "back"];
  const count = Math.max(1, Math.round(s.chamber_count));
  const nested = Math.max(0, Math.round(s.nested_chambers));
  const roomPoly = roomPolygon(s);
  const chambers = [];
  requestedSides.forEach((side) => {
    const edge = edgeForSide(roomPoly, side);
    const wallLength = edge.length;
    const alongWidth = Math.min(s.chamber_width, wallLength * 0.9);
    const outwardDepth = Math.min(s.chamber_depth, (side === "left" || side === "right" ? s.room_x : s.room_y) * 0.8);
    const centerSpan = Math.max(0, wallLength - alongWidth);
    const baseCenter = alongWidth * 0.5 + centerSpan * clamp(s.chamber_position, 0, 1);
    const spacing = count > 1 ? Math.min(alongWidth * 1.15, Math.max(alongWidth * 0.55, wallLength / count)) : 0;
    const opening = clamp(s.opening_width, 0.05, 1) * alongWidth;
    for (let index = 0; index < count; index += 1) {
      const offset = (index - (count - 1) * 0.5) * spacing;
      const alongStart = clamp(baseCenter + offset - alongWidth * 0.5, 0, Math.max(0, wallLength - alongWidth));
      let chamber = makeEdgeChamber(s, side, edge, alongStart, alongWidth, outwardDepth, opening, 0, -1, chambers.length);
      chambers.push(chamber);
      let parent = chamber;
      for (let level = 1; level <= nested; level += 1) {
        const childAlong = alongWidth * Math.pow(0.72, level);
        const childOutward = outwardDepth * Math.pow(0.78, level);
        const childOpening = Math.min(opening * Math.pow(0.82, level), childAlong * 0.9);
        const nestedEdge = nestedEdgeFromChamber(parent);
        const childAlongStart = clamp(nestedEdge.length * 0.5 - childAlong * 0.5, 0, Math.max(0, nestedEdge.length - childAlong));
        const child = makeEdgeChamber(s, side, nestedEdge, childAlongStart, childAlong, childOutward, childOpening, level, parent.index, chambers.length);
        chambers.push(child);
        parent = child;
      }
    }
  });
  return chambers;
}

function polygonForBox(x, y, w, d, shape) {
  const skew = Math.min(w * 0.18, d * 0.28);
  if (shape === "trapezoid") {
    return [
      { x: x + skew, y },
      { x: x + w - skew * 0.55, y },
      { x: x + w, y: y + d },
      { x, y: y + d }
    ];
  }
  if (shape === "wedge") {
    return [
      { x, y },
      { x: x + w, y: y + d * 0.18 },
      { x: x + w * 0.62, y: y + d },
      { x: x + w * 0.05, y: y + d * 0.82 }
    ];
  }
  if (shape === "skew") {
    return [
      { x: x + skew * 0.5, y },
      { x: x + w, y: y + skew * 0.35 },
      { x: x + w - skew * 0.65, y: y + d },
      { x: x - skew * 0.45, y: y + d - skew * 0.4 }
    ];
  }
  if (shape === "diamond") {
    return [
      { x: x + w * 0.5, y },
      { x: x + w, y: y + d * 0.48 },
      { x: x + w * 0.54, y: y + d },
      { x, y: y + d * 0.54 }
    ];
  }
  if (shape === "impossible") {
    return [
      { x: x + w * 0.08, y },
      { x: x + w, y: y + d * 0.08 },
      { x: x + w * 0.78, y: y + d * 0.42 },
      { x: x + w * 1.04, y: y + d },
      { x: x + w * 0.36, y: y + d * 0.78 },
      { x: x - w * 0.10, y: y + d * 0.38 }
    ];
  }
  return [
    { x, y },
    { x: x + w, y },
    { x: x + w, y: y + d },
    { x, y: y + d }
  ];
}

function roomPolygon(s) {
  return polygonForBox(0, 0, s.room_x, s.room_y, s.room_shape);
}

function polygonCentroid(poly) {
  if (!poly.length) return { x: 0, y: 0 };
  return poly.reduce((sum, point) => ({ x: sum.x + point.x / poly.length, y: sum.y + point.y / poly.length }), { x: 0, y: 0 });
}

function edgeForSide(poly, side) {
  const centroid = polygonCentroid(poly);
  let best = null;
  for (let i = 0; i < poly.length; i += 1) {
    const a = poly[i];
    const b = poly[(i + 1) % poly.length];
    const mid = { x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5 };
    const score = side === "front" ? -mid.y : side === "back" ? mid.y : side === "left" ? -mid.x : mid.x;
    if (!best || score > best.score) best = { a, b, mid, score };
  }
  const dx = best.b.x - best.a.x;
  const dy = best.b.y - best.a.y;
  const length = Math.max(0.001, Math.sqrt(dx * dx + dy * dy));
  const tangent = { x: dx / length, y: dy / length };
  let normal = { x: -tangent.y, y: tangent.x };
  const away = { x: best.mid.x - centroid.x, y: best.mid.y - centroid.y };
  if (normal.x * away.x + normal.y * away.y < 0) normal = { x: -normal.x, y: -normal.y };
  return { ...best, length, tangent, outward: normal };
}

function mapLocal(edge, along, outward) {
  return {
    x: edge.a.x + edge.tangent.x * along + edge.outward.x * outward,
    y: edge.a.y + edge.tangent.y * along + edge.outward.y * outward
  };
}

function chamberLocalPolygon(alongStart, alongWidth, outwardDepth, shape) {
  const x = alongStart;
  const w = alongWidth;
  const d = outwardDepth;
  const skew = Math.min(w * 0.18, d * 0.28);
  if (shape === "trapezoid") {
    return [
      { x, y: 0 },
      { x: x + w, y: 0 },
      { x: x + w, y: d },
      { x: x + skew, y: d },
      { x, y: d },
      { x, y: d * 0.84 }
    ];
  }
  if (shape === "wedge") {
    return [
      { x, y: 0 },
      { x: x + w, y: 0 },
      { x: x + w, y: d * 0.26 },
      { x: x + w * 0.64, y: d },
      { x: x + w, y: d },
      { x, y: d }
    ];
  }
  if (shape === "skew") {
    return [
      { x, y: 0 },
      { x: x + w, y: 0 },
      { x: x + w + skew * 0.35, y: d * 0.46 },
      { x: x + w, y: d },
      { x, y: d },
      { x: x - skew * 0.25, y: d * 0.44 }
    ];
  }
  if (shape === "diamond") {
    return [
      { x, y: 0 },
      { x: x + w, y: 0 },
      { x: x + w, y: d * 0.54 },
      { x: x + w * 0.54, y: d },
      { x: x + w, y: d },
      { x, y: d },
      { x, y: d * 0.54 }
    ];
  }
  if (shape === "impossible") {
    return [
      { x, y: 0 },
      { x: x + w, y: 0 },
      { x: x + w * 1.04, y: d * 0.22 },
      { x: x + w * 0.82, y: d * 0.46 },
      { x: x + w * 1.02, y: d },
      { x: x + w, y: d },
      { x, y: d },
      { x: x - w * 0.08, y: d * 0.38 }
    ];
  }
  return polygonForBox(x, 0, w, d, "rect");
}

function transformLocalPolygon(edge, alongStart, alongWidth, outwardDepth, shape) {
  return chamberLocalPolygon(alongStart, alongWidth, outwardDepth, shape).map((point) => mapLocal(edge, point.x, point.y));
}

function boundsFromPoly(poly) {
  return polygonBounds(poly);
}

function makeEdgeChamber(s, side, edge, alongStart, alongWidth, outwardDepth, opening, level, parent, index) {
  const poly = transformLocalPolygon(edge, alongStart, alongWidth, outwardDepth, s.chamber_shape);
  const bounds = boundsFromPoly(poly);
  const openingStart = alongStart + alongWidth * 0.5 - opening * 0.5;
  const openA = mapLocal(edge, openingStart, 0);
  const openB = mapLocal(edge, openingStart + opening, 0);
  const outerA = mapLocal(edge, alongStart, outwardDepth);
  const outerB = mapLocal(edge, alongStart + alongWidth, outwardDepth);
  return {
    x: bounds.minX,
    y: bounds.minY,
    width: bounds.maxX - bounds.minX,
    depth: bounds.maxY - bounds.minY,
    opening,
    openingX: openA.x,
    openingY: openA.y,
    openA,
    openB,
    outerA,
    outerB,
    edgeOutward: edge.outward,
    poly,
    side,
    level,
    parent,
    index,
    shape: s.chamber_shape
  };
}

function nestedEdgeFromChamber(chamber) {
  const dx = chamber.outerB.x - chamber.outerA.x;
  const dy = chamber.outerB.y - chamber.outerA.y;
  const length = Math.max(0.001, Math.sqrt(dx * dx + dy * dy));
  const tangent = { x: dx / length, y: dy / length };
  const outward = chamber.edgeOutward || { x: -tangent.y, y: tangent.x };
  const outLen = Math.max(0.001, Math.sqrt(outward.x * outward.x + outward.y * outward.y));
  return {
    a: chamber.outerA,
    b: chamber.outerB,
    length,
    tangent,
    outward: { x: outward.x / outLen, y: outward.y / outLen }
  };
}

function makeChamber(s, side, alongStart, alongWidth, outwardDepth, opening, level, parent, index) {
  if (side === "front") {
    return { x: alongStart, y: -outwardDepth, width: alongWidth, depth: outwardDepth, opening, openingX: alongStart + alongWidth * 0.5 - opening * 0.5, openingY: 0, side, level, parent, index, shape: s.chamber_shape };
  }
  if (side === "left") {
    return { x: -outwardDepth, y: alongStart, width: outwardDepth, depth: alongWidth, opening, openingX: 0, openingY: alongStart + alongWidth * 0.5 - opening * 0.5, side, level, parent, index, shape: s.chamber_shape };
  }
  if (side === "right") {
    return { x: s.room_x, y: alongStart, width: outwardDepth, depth: alongWidth, opening, openingX: s.room_x, openingY: alongStart + alongWidth * 0.5 - opening * 0.5, side, level, parent, index, shape: s.chamber_shape };
  }
  return { x: alongStart, y: s.room_y, width: alongWidth, depth: outwardDepth, opening, openingX: alongStart + alongWidth * 0.5 - opening * 0.5, openingY: s.room_y, side: "back", level, parent, index, shape: s.chamber_shape };
}

function makeNestedChamber(s, parent, side, alongStart, alongWidth, outwardDepth, opening, level, parentIndex, index) {
  if (side === "front") {
    const y = parent.y - outwardDepth;
    return { x: alongStart, y, width: alongWidth, depth: outwardDepth, opening, openingX: alongStart + alongWidth * 0.5 - opening * 0.5, openingY: parent.y, side, level, parent: parentIndex, index, shape: s.chamber_shape };
  }
  if (side === "left") {
    const x = parent.x - outwardDepth;
    return { x, y: alongStart, width: outwardDepth, depth: alongWidth, opening, openingX: parent.x, openingY: alongStart + alongWidth * 0.5 - opening * 0.5, side, level, parent: parentIndex, index, shape: s.chamber_shape };
  }
  if (side === "right") {
    const x = parent.x + parent.width;
    return { x, y: alongStart, width: outwardDepth, depth: alongWidth, opening, openingX: x, openingY: alongStart + alongWidth * 0.5 - opening * 0.5, side, level, parent: parentIndex, index, shape: s.chamber_shape };
  }
  const y = parent.y + parent.depth;
  return { x: alongStart, y, width: alongWidth, depth: outwardDepth, opening, openingX: alongStart + alongWidth * 0.5 - opening * 0.5, openingY: y, side: "back", level, parent: parentIndex, index, shape: s.chamber_shape };
}

function chamberAlongCenter(chamber) {
  if (chamber.side === "left" || chamber.side === "right") return chamber.y + chamber.depth * 0.5;
  return chamber.x + chamber.width * 0.5;
}

function chamberOpeningSegment(chamber) {
  if (chamber.openA && chamber.openB) {
    return {
      x1: chamber.openA.x,
      y1: chamber.openA.y,
      x2: chamber.openB.x,
      y2: chamber.openB.y
    };
  }
  if (chamber.side === "left" || chamber.side === "right") {
    return {
      x1: chamber.openingX,
      y1: chamber.openingY,
      x2: chamber.openingX,
      y2: chamber.openingY + chamber.opening
    };
  }
  return {
    x1: chamber.openingX,
    y1: chamber.openingY,
    x2: chamber.openingX + chamber.opening,
    y2: chamber.openingY
  };
}

function roomOpeningSegment(s) {
  return roomOpeningSegments(s)[0] || null;
}

function roomOpeningSegments(s) {
  if (!s.outside_opening) return [];
  const roomPoly = roomPolygon(s);
  const count = Math.max(1, Math.round(s.outside_opening_count || 1));
  const requestedSides = s.outside_opening_side === "all"
    ? ["front", "right", "back", "left"]
    : [s.outside_opening_side || "back"];
  const segments = [];
  for (let index = 0; index < count; index += 1) {
    const side = requestedSides[index % requestedSides.length];
    const edge = edgeForSide(roomPoly, side);
    const opening = clamp(s.outside_opening_width, 0.03, 1) * edge.length;
    const spreadOffset = count <= 1 ? 0 : (index - (count - 1) * 0.5) * clamp(s.outside_opening_spread || 0, 0, 1) / Math.max(1, count - 1);
    const center = clamp((s.outside_opening_position || 0.5) + spreadOffset, 0, 1);
    const start = clamp(edge.length * center - opening * 0.5, 0, Math.max(0, edge.length - opening));
    const openA = mapLocal(edge, start, 0);
    const openB = mapLocal(edge, start + opening, 0);
    segments.push({
      x1: openA.x,
      y1: openA.y,
      x2: openB.x,
      y2: openB.y,
      opening,
      index,
      side,
      outward: edge.outward,
      center: mapLocal(edge, start + opening * 0.5, 0)
    });
  }
  return segments;
}

function chamberOutwardVector(side) {
  if (side === "front") return { x: 0, y: -1, az: 0 };
  if (side === "left") return { x: -1, y: 0, az: 90 };
  if (side === "right") return { x: 1, y: 0, az: -90 };
  return { x: 0, y: 1, az: 180 };
}

function pointOnOpening(chamber, amount) {
  const segment = chamberOpeningSegment(chamber);
  return {
    x: segment.x1 + (segment.x2 - segment.x1) * amount,
    y: segment.y1 + (segment.y2 - segment.y1) * amount
  };
}

function chamberPolygon(chamber) {
  if (chamber.poly) return chamber.poly;
  return polygonForBox(chamber.x, chamber.y, chamber.width, chamber.depth, chamber.shape);
}

function chamberBounds(chamber) {
  const points = chamberPolygon(chamber);
  return polygonBounds(points);
}

function polygonBounds(points) {
  return {
    minY: Math.min(...points.map((p) => p.y)),
    maxY: Math.max(...points.map((p) => p.y)),
    maxX: Math.max(...points.map((p) => p.x)),
    minX: Math.min(...points.map((p) => p.x))
  };
}

function chamberGeometry(s) {
  const chambers = chamberGeometries(s);
  return chambers && chambers.length ? chambers[0] : null;
}

function floorplanHeight(s) {
  const chambers = chamberGeometries(s);
  const roomBounds = polygonBounds(roomPolygon(s));
  if (!chambers || !chambers.length) return roomBounds.maxY - roomBounds.minY;
  const minY = Math.min(roomBounds.minY, ...chambers.map((chamber) => chamberBounds(chamber).minY));
  const maxY = Math.max(roomBounds.maxY, ...chambers.map((chamber) => chamberBounds(chamber).maxY));
  return maxY - minY;
}

function floorplanBounds(s) {
  const chambers = chamberGeometries(s) || [];
  const roomBounds = polygonBounds(roomPolygon(s));
  const minY = Math.min(roomBounds.minY, ...chambers.map((chamber) => chamberBounds(chamber).minY));
  const maxY = Math.max(roomBounds.maxY, ...chambers.map((chamber) => chamberBounds(chamber).maxY));
  return {
    minX: Math.min(roomBounds.minX, ...chambers.map((chamber) => chamberBounds(chamber).minX)),
    maxX: Math.max(roomBounds.maxX, ...chambers.map((chamber) => chamberBounds(chamber).maxX)),
    minY,
    maxY,
    height: maxY - minY
  };
}

function floorplanPolygons(s) {
  return [roomPolygon(s), ...(chamberGeometries(s) || []).map(chamberPolygon)];
}

function pointInPolygon(point, polygon) {
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i, i += 1) {
    const xi = polygon[i].x;
    const yi = polygon[i].y;
    const xj = polygon[j].x;
    const yj = polygon[j].y;
    const intersects = ((yi > point.y) !== (yj > point.y)) &&
      (point.x < (xj - xi) * (point.y - yi) / ((yj - yi) || 1e-9) + xi);
    if (intersects) inside = !inside;
  }
  return inside;
}

function pointInFloorplan(point, s) {
  return floorplanPolygons(s).some((polygon) => pointInPolygon(point, polygon));
}

function closestPointOnSegment(point, a, b) {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const lenSq = dx * dx + dy * dy;
  if (lenSq <= 1e-9) return { x: a.x, y: a.y };
  const t = clamp(((point.x - a.x) * dx + (point.y - a.y) * dy) / lenSq, 0, 1);
  return { x: a.x + dx * t, y: a.y + dy * t };
}

function closestPointInFloorplan(point, s) {
  if (pointInFloorplan(point, s)) return { ...point };
  let best = null;
  floorplanPolygons(s).forEach((polygon) => {
    for (let i = 0; i < polygon.length; i += 1) {
      const a = polygon[i];
      const b = polygon[(i + 1) % polygon.length];
      const candidate = closestPointOnSegment(point, a, b);
      const dx = point.x - candidate.x;
      const dy = point.y - candidate.y;
      const distSq = dx * dx + dy * dy;
      if (!best || distSq < best.distSq) best = { ...candidate, distSq };
    }
  });
  return best ? { x: best.x, y: best.y, z: point.z } : floorplanCenter(s);
}

function floorplanCenter(s) {
  const bounds = floorplanBounds(s);
  return {
    x: (bounds.minX + bounds.maxX) * 0.5,
    y: (bounds.minY + bounds.maxY) * 0.5,
    z: s.room_z * 0.5
  };
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

function groupPositionKey(index) {
  return `g${index}`;
}

function defaultGroupMapPosition(s, dir, profile) {
  const points = roomPoints(s, dir, profile);
  const candidate = { x: points.source.x, y: points.source.y, z: points.source.z };
  if (pointInFloorplan(candidate, s)) return candidate;
  const listener = points.listener;
  if (pointInFloorplan(listener, s)) return { ...listener };
  return floorplanCenter(s);
}

function groupMapPosition(s, info, profile = groupProfile(s, info.index || 0)) {
  const stored = state.groupMapPositions[groupPositionKey(info.index)];
  if (stored && pointInFloorplan(stored, s)) return { x: stored.x, y: stored.y, z: stored.z || s.room_z * 0.5 };
  return defaultGroupMapPosition(s, info, profile);
}

function roomPoints(s, dir = selectedDirection(s), profile = groupProfile(s, dir.index || 0)) {
  const bounds = floorplanBounds(s);
  const margin = 0.25;
  const fieldWidth = Math.max(0.5, bounds.maxX - bounds.minX);
  const fieldHeight = Math.max(0.5, bounds.maxY - bounds.minY);
  const listenerCandidate = {
    x: clamp(bounds.minX + fieldWidth * (0.5 + s.field_x * 0.5), bounds.minX + margin, bounds.maxX - margin),
    y: clamp(bounds.minY + fieldHeight * (0.5 + s.field_y * 0.5), bounds.minY + margin, bounds.maxY - margin),
    z: s.room_z * 0.5
  };
  const listener = closestPointInFloorplan(listenerCandidate, s);
  const unit = unitFromAed(dir.azimuth, dir.elevation);
  const maxDist = Math.min(profile.source_distance, Math.min(fieldWidth, fieldHeight, s.room_z) * 0.48);
  const sourceCandidate = {
    x: clamp(listener.x + unit.x * maxDist, bounds.minX + 0.05, bounds.maxX - 0.05),
    y: clamp(listener.y + unit.z * maxDist, bounds.minY + 0.05, bounds.maxY - 0.05),
    z: clamp(listener.z + unit.y * maxDist, 0.05, s.room_z - 0.05)
  };
  const source = closestPointInFloorplan(sourceCandidate, s);
  return { listener, source };
}

function groupMetrics(s, index) {
  const dirs = activeDirections(s);
  const dir = dirs[index] || dirs[0] || [0, 0];
  const info = {
    index,
    count: dirs.length,
    azimuth: dir[0],
    elevation: dir[1],
    channels_start: index * s.channels_per_ir + 1,
    channels_end: (index + 1) * s.channels_per_ir
  };
  const profile = groupProfile(s, index);
  const points = roomPoints(s, info, profile);
  const mapPosition = groupMapPosition(s, info, profile);
  const events = reflectionEvents(s, info);
  const directTime = profile.pre_delay_ms / 1000 + profile.source_distance / 343;
  const directAmp = 1 / Math.max(1, profile.source_distance);
  const firstReflection = events[0] || { time: 0, amp: 0, wall: "-" };
  const earlyEnergy = events.reduce((sum, event) => sum + event.amp * event.amp, 0);
  const chamberEnergy = events.filter((event) => event.type === "chamber").reduce((sum, event) => sum + event.amp * event.amp, 0);
  return {
    ...info,
    source: points.source,
    map_position: mapPosition,
    profile,
    direct_time: directTime,
    direct_amp: directAmp,
    first_reflection_time: firstReflection.time,
    first_reflection_wall: firstReflection.wall,
    early_energy: earlyEnergy,
    chamber_energy: chamberEnergy
  };
}

function reflectionEvents(s, dir = selectedDirection(s)) {
  const profile = groupProfile(s, dir.index || 0);
  const { listener } = roomPoints(s, dir, profile);
  const source = groupMapPosition(s, dir, profile);
  const images = [
    { pos: { x: -source.x, y: source.y, z: source.z }, wall: "L" },
    { pos: { x: 2 * s.room_x - source.x, y: source.y, z: source.z }, wall: "R" },
    { pos: { x: source.x, y: -source.y, z: source.z }, wall: "F" },
    { pos: { x: source.x, y: 2 * s.room_y - source.y, z: source.z }, wall: "B" },
    { pos: { x: source.x, y: source.y, z: -source.z }, wall: "D" },
    { pos: { x: source.x, y: source.y, z: 2 * s.room_z - source.z }, wall: "U" }
  ];
  const reflectivity = Math.sqrt(Math.max(0, 1 - profile.absorption));
  const baseEvents = images.map((image, index) => {
    const dx = image.pos.x - listener.x;
    const dy = image.pos.y - listener.y;
    const dz = image.pos.z - listener.z;
    const distance = Math.sqrt(dx * dx + dy * dy + dz * dz);
    const spread = profile.direction_spread_deg * profile.scattering * 0.12;
    const jitterA = (seededNoise((dir.index + 1) * 31 + index * 7) - 0.5) * spread;
    const jitterE = (seededNoise((dir.index + 1) * 43 + index * 11) - 0.5) * spread * 0.55;
    return {
      wall: image.wall,
      time: profile.pre_delay_ms / 1000 + distance / 343,
      amp: Math.pow(reflectivity, 1 + index * 0.15) / Math.max(1, distance),
      az: wrapDegrees(Math.atan2(dx, dy) * 180 / Math.PI + jitterA),
      el: clamp(Math.asin(clamp(dz / Math.max(0.001, distance), -1, 1)) * 180 / Math.PI + jitterE, -89, 89),
      type: "image"
    };
  });
  const roomCross = Math.sqrt(s.room_x * s.room_x + s.room_y * s.room_y + s.room_z * s.room_z);
  const maxExtra = Math.max(0, Math.floor(s.early_reflections) - baseEvents.length);
  const extraEvents = Array.from({ length: maxExtra }, (_, index) => {
    const seed = (dir.index + 1) * 101 + index * 17;
    const u = seededNoise(seed);
    const cluster = seededNoise(seed + 3);
    const randomField = seededNoise(seed + 9);
    const baseTime = Math.min(s.duration * 0.35, roomCross / 343);
    const t = profile.pre_delay_ms / 1000 + 0.006 + u * Math.max(0.004, baseTime);
    const aroundGroup = randomField < 0.55 + profile.scattering * 0.35;
    const az = aroundGroup
      ? wrapDegrees(dir.azimuth + (cluster - 0.5) * profile.direction_spread_deg * (1 + profile.scattering))
      : wrapDegrees(-180 + cluster * 360);
    const elSeed = seededNoise(seed + 13);
    const el = aroundGroup
      ? clamp(dir.elevation + (elSeed - 0.5) * profile.direction_spread_deg * 0.7, -89, 89)
      : Math.asin(-1 + 2 * elSeed) * 180 / Math.PI;
    const amp = (0.04 + 0.16 * seededNoise(seed + 19)) * reflectivity * Math.exp(-t / Math.max(0.05, profile.rt60));
    return {
      wall: "E",
      time: t,
      amp,
      az,
      el,
      type: "extra"
    };
  });
  const chambers = chamberGeometries(s);
  const chamberEvents = [];
  if (chambers && chambers.length && s.chamber_coupling > 0.001) {
    const dirUnit = unitFromAed(dir.azimuth, dir.elevation);
    const count = Math.max(1, Math.round(2 + s.chamber_coupling * 8 + chambers.length * 0.6));
    for (let index = 0; index < count; index += 1) {
      const seed = (dir.index + 1) * 211 + index * 23;
      const chamber = chambers[Math.floor(seededNoise(seed + 2) * chambers.length) % chambers.length];
      const outward = chamberOutwardVector(chamber.side);
      const sourceTowardChamber = Math.max(0, dirUnit.x * outward.x + dirUnit.z * outward.y);
      const coupling = s.chamber_coupling * (0.35 + sourceTowardChamber * 0.65);
      const chamberProfile = chamberMaterialProfile(s, chamber);
      const chamberReflectivity = Math.sqrt(Math.max(0, 1 - chamberProfile.absorption));
      const chamberPath = chamber.depth * 2 + chamber.width * 0.65 + chamber.level * (s.chamber_depth * 1.4);
      const t = profile.pre_delay_ms / 1000 + (profile.source_distance + chamberPath * (0.52 + index * (0.12 + chamberProfile.scattering * 0.12))) / 343;
      const az = wrapDegrees(outward.az + (seededNoise(seed) - 0.5) * (45 + chamberProfile.scattering * 70));
      const el = clamp(dir.elevation * 0.35 + (seededNoise(seed + 5) - 0.5) * (24 + chamberProfile.scattering * 38), -70, 70);
      const amp = (0.035 + 0.10 * seededNoise(seed + 9)) * chamberReflectivity * coupling * Math.exp(-t / Math.max(0.05, profile.rt60 * (0.9 + chamberProfile.tail_soften * 0.8)));
      chamberEvents.push({
        wall: "C",
        chamber_index: chamber.index,
        material: s.chamber_material,
        time: t,
        amp,
        az,
        el,
        type: "chamber"
      });
    }
  }
  return [...baseEvents, ...extraEvents, ...chamberEvents].sort((a, b) => a.time - b.time);
}

function drawRoom() {
  configureRoomCanvas();
  const s = settings();
  ctx.clearRect(0, 0, ROOM_CANVAS_W, ROOM_CANVAS_H);
  ctx.fillStyle = "#050607";
  ctx.fillRect(0, 0, ROOM_CANVAS_W, ROOM_CANVAS_H);
  if (state.view === "sphere") drawDirections(s);
  else if (state.view === "matrix") drawBankMatrix(s);
  else if (state.view === "layers") drawReflectionLayers(s);
  else drawRoomView(s);
  renderVectorRoom(s);
  drawTimeline(s);
  updateGroupStrip(s);
  updateReadouts(s);
}

function svgEscape(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;"
  })[char]);
}

function svgPoints(points) {
  return points.map((point) => `${round(point.x, 2)},${round(point.y, 2)}`).join(" ");
}

function svgOpeningMarker(projection, segment, color) {
  const p1 = projection.point({ x: segment.x1, y: segment.y1 });
  const p2 = projection.point({ x: segment.x2, y: segment.y2 });
  const dx = p2.x - p1.x;
  const dy = p2.y - p1.y;
  const len = Math.max(0.001, Math.hypot(dx, dy));
  const nx = -dy / len;
  const ny = dx / len;
  const tick = 7;
  return `
    <line x1="${round(p1.x, 2)}" y1="${round(p1.y, 2)}" x2="${round(p2.x, 2)}" y2="${round(p2.y, 2)}" stroke="#050607" stroke-width="5.8" vector-effect="non-scaling-stroke" />
    <line x1="${round(p1.x, 2)}" y1="${round(p1.y, 2)}" x2="${round(p2.x, 2)}" y2="${round(p2.y, 2)}" stroke="${color}" stroke-width="1.8" stroke-dasharray="4 3" vector-effect="non-scaling-stroke" />
    <line x1="${round(p1.x - nx * tick, 2)}" y1="${round(p1.y - ny * tick, 2)}" x2="${round(p1.x + nx * tick, 2)}" y2="${round(p1.y + ny * tick, 2)}" stroke="${color}" stroke-width="1.4" vector-effect="non-scaling-stroke" />
    <line x1="${round(p2.x - nx * tick, 2)}" y1="${round(p2.y - ny * tick, 2)}" x2="${round(p2.x + nx * tick, 2)}" y2="${round(p2.y + ny * tick, 2)}" stroke="${color}" stroke-width="1.4" vector-effect="non-scaling-stroke" />
  `;
}

function renderVectorRoom(s) {
  const vectorView = state.view === "top" || state.view === "sphere";
  roomSvg.parentElement.classList.toggle("svg-active", vectorView);
  if (!vectorView) {
    roomSvg.innerHTML = "";
    return;
  }
  if (state.view === "sphere") renderVectorBankMap(s);
  else renderVectorTopView(s);
}

function vectorProjection(s) {
  const pad = 48;
  const bounds = floorplanBounds(s);
  const roomW = bounds.maxX - bounds.minX;
  const roomH = bounds.height;
  const scale = Math.min((ROOM_CANVAS_W - pad * 2) / roomW, (ROOM_CANVAS_H - pad * 2) / roomH);
  const ox = (ROOM_CANVAS_W - roomW * scale) / 2;
  const oy = (ROOM_CANVAS_H - roomH * scale) / 2;
  return {
    bounds,
    scale,
    px: (p) => ox + (p.x - bounds.minX) * scale,
    py: (p) => oy + (p.y - bounds.minY) * scale,
    point: (p) => ({ x: ox + (p.x - bounds.minX) * scale, y: oy + (p.y - bounds.minY) * scale })
  };
}

function renderVectorFloorplan(s, projection) {
  const room = roomPolygon(s).map(projection.point);
  const chambers = chamberGeometries(s) || [];
  const outsideSvg = roomOpeningSegments(s).map((outside) => {
    const label = projection.point(outside.center);
    return `
      ${svgOpeningMarker(projection, outside, "rgba(200,245,235,0.82)")}
      <text x="${round(label.x + 8, 2)}" y="${round(label.y - 8, 2)}" class="svg-tiny svg-outside">${svgEscape(`outside ${outside.index + 1}`)}</text>
    `;
  }).join("");
  const chamberSvg = chambers.map((chamber) => {
    const material = chamberMaterialProfile(s, chamber);
    const alpha = Math.max(0.04, 0.06 + s.chamber_coupling * 0.08 + (1 - material.absorption) * 0.03 - chamber.level * 0.01);
    const poly = chamberPolygon(chamber).map(projection.point);
    const opening = chamberOpeningSegment(chamber);
    const label = chamber.level === 0 ? `chamber ${chamber.index + 1}` : `nested ${chamber.level}`;
    const text = projection.point({ x: chamber.x, y: chamber.y });
    return `
      <polygon points="${svgPoints(poly)}" fill="rgba(120,190,150,${alpha.toFixed(3)})" stroke="rgba(120,190,150,${chamber.level === 0 ? 0.78 : 0.5})" stroke-width="1.3" vector-effect="non-scaling-stroke" />
      ${svgOpeningMarker(projection, opening, chamber.level === 0 ? "rgba(184,255,202,0.88)" : "rgba(184,255,202,0.64)")}
      <text x="${round(text.x + 8, 2)}" y="${round(text.y + 16, 2)}" class="svg-small svg-chamber">${svgEscape(label)}</text>
      <text x="${round(text.x + 8, 2)}" y="${round(text.y + 29, 2)}" class="svg-tiny svg-muted">${svgEscape(material.material_key)} a${round(material.absorption, 2)} s${round(material.scattering, 2)}</text>
    `;
  }).join("");
  const grid = Array.from({ length: 7 }, (_, i) => {
    const n = i + 1;
    const x = projection.px({ x: s.room_x * n / 8, y: 0 });
    const y = projection.py({ x: 0, y: s.room_y * n / 8 });
    const left = projection.px({ x: 0, y: 0 });
    const right = projection.px({ x: s.room_x, y: 0 });
    const top = projection.py({ x: 0, y: 0 });
    const bottom = projection.py({ x: 0, y: s.room_y });
    return `
      <line x1="${round(x, 2)}" y1="${round(top, 2)}" x2="${round(x, 2)}" y2="${round(bottom, 2)}" class="svg-grid" />
      <line x1="${round(left, 2)}" y1="${round(y, 2)}" x2="${round(right, 2)}" y2="${round(y, 2)}" class="svg-grid" />
    `;
  }).join("");
  return `
    <defs>
      <style>
        text { font-family: Menlo, Monaco, "Courier New", monospace; }
        .svg-label { fill: #d7d7d7; font-size: 10px; dominant-baseline: middle; text-anchor: middle; }
        .svg-small { fill: #d7d7d7; font-size: 10px; }
        .svg-tiny { font-size: 9px; }
        .svg-muted { fill: #8f9aa0; }
        .svg-chamber { fill: #78be96; }
        .svg-outside { fill: #c8f5eb; }
        .svg-grid { stroke: rgba(255,255,255,0.09); stroke-width: 1; vector-effect: non-scaling-stroke; }
      </style>
    </defs>
    <rect x="0" y="0" width="${ROOM_CANVAS_W}" height="${ROOM_CANVAS_H}" fill="#050607" />
    ${grid}
    <polygon points="${svgPoints(room)}" fill="rgba(90,168,199,0.045)" stroke="rgba(90,168,199,0.78)" stroke-width="1.4" vector-effect="non-scaling-stroke" />
    ${outsideSvg}
    ${chamberSvg}
  `;
}

function renderVectorTopView(s) {
  const projection = vectorProjection(s);
  const selected = selectedDirection(s);
  const { listener } = roomPoints(s, selected);
  const selectedProfile = groupProfile(s, selected.index);
  const sourcePoint = groupMapPosition(s, selected, selectedProfile);
  const listenerPoint = { x: listener.x, y: listener.y, z: listener.z };
  const events = reflectionEvents(s, selected).slice(0, Math.min(s.early_reflections, 26));
  const points = activeDirections(s).map((dir, index) => {
    const profile = groupProfile(s, index);
    const info = {
      index,
      azimuth: dir[0],
      elevation: dir[1],
      channels_start: index * s.channels_per_ir + 1,
      channels_end: (index + 1) * s.channels_per_ir
    };
    return { index, active: index === selected.index, p: projection.point(groupMapPosition(s, info, profile)) };
  });
  const pathLines = points.slice(1).map((point, i) => {
    const prev = points[i].p;
    return `<line x1="${round(prev.x, 2)}" y1="${round(prev.y, 2)}" x2="${round(point.p.x, 2)}" y2="${round(point.p.y, 2)}" stroke="rgba(90,168,199,0.22)" stroke-width="1.5" vector-effect="non-scaling-stroke" />`;
  }).join("");
  const lp = projection.point(listenerPoint);
  const sp = projection.point(sourcePoint);
  const diffuseRadius = Math.min(projection.bounds.maxX - projection.bounds.minX, projection.bounds.height) * projection.scale * (0.12 + selectedProfile.scattering * 0.22);
  const eventLines = s.show_early ? events.map((event) => {
    const dir = unitFromAed(event.az, event.el);
    const endpoint = {
      x: clamp(listener.x + dir.x * selectedProfile.source_distance * 0.65, 0, s.room_x),
      y: clamp(listener.y + dir.z * selectedProfile.source_distance * 0.65, 0, s.room_y)
    };
    const ep = projection.point(endpoint);
    const color = event.type === "chamber" ? "120,190,150" : "216,162,74";
    return `<line x1="${round(lp.x, 2)}" y1="${round(lp.y, 2)}" x2="${round(ep.x, 2)}" y2="${round(ep.y, 2)}" stroke="rgba(${color},${clamp(event.amp * 3.6, 0.18, 0.72).toFixed(3)})" stroke-width="${round(clamp(event.amp * 12, 1.8, 4.8), 2)}" vector-effect="non-scaling-stroke" />`;
  }).join("") : "";
  const pointSvg = points.map((point) => `
    <g>
      <circle cx="${round(point.p.x, 2)}" cy="${round(point.p.y, 2)}" r="${point.active ? 7 : 4}" fill="${point.active ? "#5aa8c7" : "rgba(90,168,199,0.48)"}" />
      <text x="${round(point.p.x, 2)}" y="${round(point.p.y + 0.5, 2)}" class="svg-label" fill="${point.active ? "#050607" : "#d7d7d7"}">${point.index + 1}</text>
    </g>
  `).join("");
  roomSvg.innerHTML = `
    ${renderVectorFloorplan(s, projection)}
    ${pathLines}
    ${s.show_diffuse ? `<circle cx="${round(lp.x, 2)}" cy="${round(lp.y, 2)}" r="${round(diffuseRadius, 2)}" fill="rgba(90,168,199,${(0.06 + (1 - selectedProfile.absorption) * 0.08).toFixed(3)})" />` : ""}
    ${eventLines}
    ${s.show_direct ? `<line x1="${round(lp.x, 2)}" y1="${round(lp.y, 2)}" x2="${round(sp.x, 2)}" y2="${round(sp.y, 2)}" stroke="rgba(90,190,220,0.92)" stroke-width="3" vector-effect="non-scaling-stroke" />` : ""}
    ${pointSvg}
    <circle cx="${round(lp.x, 2)}" cy="${round(lp.y, 2)}" r="7" fill="#d7d7d7" />
    <text x="${round(lp.x, 2)}" y="${round(lp.y + 0.5, 2)}" class="svg-label" fill="#050607">L</text>
    <circle cx="${round(sp.x, 2)}" cy="${round(sp.y, 2)}" r="8" fill="#5aa8c7" />
    <text x="${round(sp.x, 2)}" y="${round(sp.y + 0.5, 2)}" class="svg-label" fill="#050607">${selected.index + 1}</text>
    <text x="12" y="20" class="svg-small svg-muted">TOP group ${selected.index + 1}/${selected.count}  ${selected.azimuth} az / ${selected.elevation} el</text>
    <text x="12" y="${ROOM_CANVAS_H - 16}" class="svg-small svg-muted">drag in Top view to move the field; use Bank Map to move mic positions</text>
  `;
}

function renderVectorBankMap(s) {
  const projection = vectorProjection(s);
  const dirs = activeDirections(s);
  const selected = selectedDirection(s);
  const listener = roomPoints(s, selected).listener;
  const lp = projection.point(listener);
  const groupSvg = dirs.map((dir, index) => {
    const metrics = groupMetrics(s, index);
    const position = groupMapPosition(s, metrics, metrics.profile);
    const p = projection.point(position);
    const active = index === selected.index;
    const radius = active ? 11 : clamp(5 + Math.sqrt(metrics.early_energy) * 14, 5, 15);
    const dirUnit = unitFromAed(dir[0], dir[1]);
    const lobeX = p.x + dirUnit.x * 46;
    const lobeY = p.y + dirUnit.z * 46;
    return `
      ${active ? `<path d="M ${round(p.x, 2)} ${round(p.y, 2)} Q ${round(p.x + dirUnit.x * 26 - dirUnit.z * 14, 2)} ${round(p.y + dirUnit.z * 26 + dirUnit.x * 14, 2)} ${round(lobeX, 2)} ${round(lobeY, 2)} Q ${round(p.x + dirUnit.x * 26 + dirUnit.z * 14, 2)} ${round(p.y + dirUnit.z * 26 - dirUnit.x * 14, 2)} ${round(p.x, 2)} ${round(p.y, 2)} Z" fill="rgba(216,162,74,0.12)" />
      <line x1="${round(p.x, 2)}" y1="${round(p.y, 2)}" x2="${round(lobeX, 2)}" y2="${round(lobeY, 2)}" stroke="rgba(216,162,74,0.72)" stroke-width="1.2" vector-effect="non-scaling-stroke" />` : ""}
      <circle cx="${round(p.x, 2)}" cy="${round(p.y, 2)}" r="${round(radius, 2)}" fill="${active ? "#d8a24a" : "rgba(90,168,199,0.72)"}" />
      <text x="${round(p.x + 11, 2)}" y="${round(p.y + 3, 2)}" class="svg-small">${svgEscape(`G${index + 1}`)}</text>
    `;
  }).join("");
  roomSvg.innerHTML = `
    ${renderVectorFloorplan(s, projection)}
    <circle cx="${round(lp.x, 2)}" cy="${round(lp.y, 2)}" r="7" fill="#d7d7d7" />
    <text x="${round(lp.x, 2)}" y="${round(lp.y + 0.5, 2)}" class="svg-label" fill="#050607">L</text>
    ${groupSvg}
    <text x="12" y="20" class="svg-small svg-muted">Bank Map: ${dirs.length} IR groups placed in floorplan / ${s.channels_per_ir}ch per group / ${s.stacked_channels}ch stacked</text>
    <text x="12" y="38" class="svg-small svg-muted">selected G${selected.index + 1}: ${selected.channels_start}-${selected.channels_end}</text>
    <text x="12" y="${ROOM_CANVAS_H - 16}" class="svg-small svg-muted">drag IR group points inside the room/chamber geometry</text>
  `;
}

function project3DFactory(s) {
  const bounds = floorplanBounds(s);
  const center = {
    x: (bounds.minX + bounds.maxX) * 0.5,
    y: (bounds.minY + bounds.maxY) * 0.5,
    z: s.room_z * 0.5
  };
  const az = s.camera_azimuth * Math.PI / 180;
  const el = s.camera_elevation * Math.PI / 180;
  const cosA = Math.cos(az);
  const sinA = Math.sin(az);
  const cosE = Math.cos(el);
  const sinE = Math.sin(el);
  const diagonal = Math.sqrt((bounds.maxX - bounds.minX) ** 2 + bounds.height ** 2 + s.room_z ** 2);
  const scale = Math.min(ROOM_CANVAS_W, ROOM_CANVAS_H) * 0.82 * s.camera_zoom / Math.max(1, diagonal);
  return (p) => {
    const x = p.x - center.x;
    const y = p.y - center.y;
    const z = p.z - center.z;
    const rx = x * cosA - y * sinA;
    const ry = x * sinA + y * cosA;
    const sy = ry * sinE - z * cosE;
    return {
      x: ROOM_CANVAS_W * 0.5 + rx * scale,
      y: ROOM_CANVAS_H * 0.54 + sy * scale,
      depth: ry * cosE + z * sinE
    };
  };
}

function drawPolyline3D(project, points, close = false) {
  if (!points.length) return;
  const first = project(points[0]);
  ctx.beginPath();
  ctx.moveTo(first.x, first.y);
  points.slice(1).forEach((point) => {
    const p = project(point);
    ctx.lineTo(p.x, p.y);
  });
  if (close) ctx.closePath();
  ctx.stroke();
}

function drawPlanPolygon(points, ox, oy, scale, bounds, fillStyle, strokeStyle, lineWidth = 1) {
  if (!points.length) return;
  const first = points[0];
  ctx.beginPath();
  ctx.moveTo(ox + (first.x - bounds.minX) * scale, oy + (first.y - bounds.minY) * scale);
  points.slice(1).forEach((point) => {
    ctx.lineTo(ox + (point.x - bounds.minX) * scale, oy + (point.y - bounds.minY) * scale);
  });
  ctx.closePath();
  if (fillStyle) {
    ctx.fillStyle = fillStyle;
    ctx.fill();
  }
  ctx.strokeStyle = strokeStyle;
  ctx.lineWidth = lineWidth;
  ctx.stroke();
}

function drawRoom3D(s) {
  const project = project3DFactory(s);
  const selected = selectedDirection(s);
  const { listener, source } = roomPoints(s, selected);
  const selectedProfile = groupProfile(s, selected.index);
  const mapSource = groupMapPosition(s, selected, selectedProfile);
  const listenerPoint = { x: listener.x, y: listener.y, z: listener.z };
  const sourcePoint = { x: mapSource.x, y: mapSource.y, z: mapSource.z || source.z };
  const roomFloor = roomPolygon(s).map((p) => ({ ...p, z: 0 }));
  const roomTop = roomPolygon(s).map((p) => ({ ...p, z: s.room_z }));
  state.roomHitPoints = [];
  state.roomProjection = null;

  ctx.strokeStyle = "rgba(90,168,199,0.72)";
  ctx.lineWidth = 1;
  drawPolyline3D(project, roomFloor, true);
  drawPolyline3D(project, roomTop, true);
  roomFloor.forEach((point, index) => drawPolyline3D(project, [point, roomTop[index]]));

  openingSegmentsForModel(s).forEach((opening) => {
    const height = opening.height || s.room_z * 0.82;
    const a = { x: opening.x1, y: opening.y1, z: 0.03 };
    const b = { x: opening.x2, y: opening.y2, z: 0.03 };
    const c = { x: opening.x2, y: opening.y2, z: height };
    const d = { x: opening.x1, y: opening.y1, z: height };
    const pa = project(a);
    const pb = project(b);
    const pc = project(c);
    const pd = project(d);
    ctx.fillStyle = "rgba(5,6,7,0.74)";
    ctx.strokeStyle = "rgba(200,245,235,0.88)";
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.moveTo(pa.x, pa.y);
    ctx.lineTo(pb.x, pb.y);
    ctx.lineTo(pc.x, pc.y);
    ctx.lineTo(pd.x, pd.y);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
  });

  const chambers = chamberGeometries(s) || [];
  chambers.forEach((chamber) => {
    const material = chamberMaterialProfile(s, chamber);
    const poly = chamberPolygon(chamber);
    const floor = poly.map((p) => ({ ...p, z: 0 }));
    const top = poly.map((p) => ({ ...p, z: s.room_z * (0.42 + chamber.level * 0.08) }));
    ctx.fillStyle = `rgba(120,190,150,${0.035 + (1 - material.absorption) * 0.06})`;
    const first = project(floor[0]);
    ctx.beginPath();
    ctx.moveTo(first.x, first.y);
    floor.slice(1).forEach((point) => {
      const p = project(point);
      ctx.lineTo(p.x, p.y);
    });
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = chamber.level === 0 ? "rgba(120,190,150,0.64)" : "rgba(120,190,150,0.42)";
    ctx.lineWidth = 1.4;
    drawPolyline3D(project, floor, true);
    drawPolyline3D(project, top, true);
    poly.forEach((point, index) => drawPolyline3D(project, [floor[index], top[index]]));
  });

  if (s.show_diffuse) {
    const p = project(listenerPoint);
    const profile = groupProfile(s, selected.index);
    ctx.fillStyle = `rgba(90,168,199,${0.045 + (1 - profile.absorption) * 0.09})`;
    ctx.beginPath();
    ctx.arc(p.x, p.y, 30 + profile.scattering * 70, 0, Math.PI * 2);
    ctx.fill();
  }

  if (s.show_early) {
    const selectedProfile = groupProfile(s, selected.index);
    reflectionEvents(s, selected).slice(0, Math.min(s.early_reflections, 28)).forEach((event) => {
      const dir = unitFromAed(event.az, event.el);
      const endpoint = {
        x: clamp(listener.x + dir.x * selectedProfile.source_distance * 0.9, 0, s.room_x),
        y: clamp(listener.y + dir.z * selectedProfile.source_distance * 0.9, 0, s.room_y),
        z: clamp(listener.z + dir.y * selectedProfile.source_distance * 0.9, 0, s.room_z)
      };
      const a = project(listenerPoint);
      const b = project(endpoint);
      ctx.strokeStyle = event.type === "chamber" ? "rgba(120,190,150,0.56)" : "rgba(216,162,74,0.46)";
      ctx.lineWidth = clamp(event.amp * 11, 1.4, 4.4);
      ctx.beginPath();
      ctx.moveTo(a.x, a.y);
      ctx.lineTo(b.x, b.y);
      ctx.stroke();
    });
  }

  activeDirections(s).forEach((dir, index) => {
    const info = {
      index,
      azimuth: dir[0],
      elevation: dir[1],
      channels_start: index * s.channels_per_ir + 1,
      channels_end: (index + 1) * s.channels_per_ir
    };
    const profile = groupProfile(s, index);
    const point = groupMapPosition(s, info, profile);
    const projected = project(point);
    const active = index === selected.index;
    drawPoint(projected.x, projected.y, active ? 7 : 4, active ? "#5aa8c7" : "rgba(90,168,199,0.46)", String(index + 1), active);
  });

  if (s.show_direct) {
    const a = project(listenerPoint);
    const b = project(sourcePoint);
    ctx.strokeStyle = "rgba(90,190,220,0.9)";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(a.x, a.y);
    ctx.lineTo(b.x, b.y);
    ctx.stroke();
  }
  const lp = project(listenerPoint);
  const sp = project(sourcePoint);
  drawPoint(lp.x, lp.y, 7, "#d7d7d7", "L", true);
  drawPoint(sp.x, sp.y, 8, "#5aa8c7", String(selected.index + 1), true);
  ctx.fillStyle = "#9a9a9a";
  ctx.font = "11px Menlo, monospace";
  ctx.fillText(`3D group ${selected.index + 1}/${selected.count}  camera ${s.camera_azimuth} az / ${s.camera_elevation} el / ${round(s.camera_zoom, 2)}x`, 12, 20);
  ctx.fillText("use camera controls for 3D; Bank Map edits mic positions, Top edits field offset", 12, ROOM_CANVAS_H - 16);
}

function drawRoomView(s) {
  if (state.view === "view3d") {
    drawRoom3D(s);
    return;
  }
  const pad = 48;
  const bounds = floorplanBounds(s);
  const viewMinX = bounds.minX;
  const viewMinY = state.view === "side" ? 0 : bounds.minY;
  const roomW = bounds.maxX - bounds.minX;
  const roomH = state.view === "side" ? s.room_z : bounds.height;
  const mainRoomH = state.view === "side" ? s.room_z : s.room_y;
  const scale = Math.min((ROOM_CANVAS_W - pad * 2) / roomW, (ROOM_CANVAS_H - pad * 2) / roomH);
  const ox = (ROOM_CANVAS_W - roomW * scale) / 2;
  const oy = (ROOM_CANVAS_H - roomH * scale) / 2;
  const selected = selectedDirection(s);
  const { listener, source } = roomPoints(s, selected);
  const selectedProfile = groupProfile(s, selected.index);
  const mapSource = groupMapPosition(s, selected, selectedProfile);
  const px = (p) => ox + (p.x - viewMinX) * scale;
  const py = (p) => oy + (state.view === "side" ? (roomH - p.z) : (p.y - viewMinY)) * scale;
  const listenerPoint = { x: listener.x, y: listener.y, z: listener.z };
  const sourcePoint = state.view === "top" ? { x: mapSource.x, y: mapSource.y, z: mapSource.z } : { x: source.x, y: source.y, z: source.z };
  state.roomHitPoints = [];
  state.roomProjection = { ox, oy, scale, roomW, roomH, minX: viewMinX, minY: viewMinY, view: state.view };

  ctx.strokeStyle = "#646464";
  ctx.lineWidth = 1;
  if (state.view === "top") {
    drawPlanPolygon(roomPolygon(s), ox, oy, scale, bounds, "rgba(90,168,199,0.045)", "rgba(90,168,199,0.72)", 1.2);
    drawChamberPlan(s, ox, oy, scale);
    drawOutsideOpeningPlan(s, ox, oy, scale);
  } else {
    ctx.strokeRect(ox + (0 - viewMinX) * scale, oy + (0 - viewMinY) * scale, s.room_x * scale, mainRoomH * scale);
    drawChamberSide(s, ox, oy, scale, bounds);
  }

  const grid = state.view === "side" ? s.room_z : s.room_y;
  ctx.strokeStyle = "rgba(255,255,255,0.09)";
  for (let i = 1; i < 8; i += 1) {
    const x = ox + roomW * scale * i / 8;
    ctx.beginPath();
    ctx.moveTo(x, oy);
    ctx.lineTo(x, oy + roomH * scale);
    ctx.stroke();
    const y = oy + (grid * i / 8 - viewMinY) * scale;
    ctx.beginPath();
    ctx.moveTo(ox, y);
    ctx.lineTo(ox + roomW * scale, y);
    ctx.stroke();
  }

  activeDirections(s).forEach((dir, index) => {
    const profile = groupProfile(s, index);
    const info = {
      index,
      azimuth: dir[0],
      elevation: dir[1],
      channels_start: index * s.channels_per_ir + 1,
      channels_end: (index + 1) * s.channels_per_ir
    };
    const point = state.view === "top" ? groupMapPosition(s, info, profile) : roomPoints(s, info, profile).source;
    const active = index === selected.index;
    if (index > 0) {
      const previousDir = activeDirections(s)[index - 1];
      const previousInfo = {
        index: index - 1,
        azimuth: previousDir[0],
        elevation: previousDir[1],
        channels_start: (index - 1) * s.channels_per_ir + 1,
        channels_end: index * s.channels_per_ir
      };
      const previousProfile = groupProfile(s, index - 1);
      const previousPoint = state.view === "top" ? groupMapPosition(s, previousInfo, previousProfile) : roomPoints(s, previousInfo, previousProfile).source;
      ctx.strokeStyle = "rgba(90,168,199,0.18)";
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(px(previousPoint), py(previousPoint));
      ctx.lineTo(px(point), py(point));
      ctx.stroke();
    }
    drawPoint(px(point), py(point), active ? 7 : 4, active ? "#5aa8c7" : "rgba(90,168,199,0.42)", String(index + 1), active);
    state.roomHitPoints.push({ x: px(point), y: py(point), r: active ? 18 : 12, index });
  });

  const events = reflectionEvents(s, selected);
  if (s.show_diffuse) {
    const diffuseRadius = Math.min(roomW, roomH) * scale * (0.12 + selectedProfile.scattering * 0.22);
    ctx.fillStyle = `rgba(90, 168, 199, ${0.06 + (1 - selectedProfile.absorption) * 0.08})`;
    ctx.beginPath();
    ctx.arc(px(listenerPoint), py(listenerPoint), diffuseRadius, 0, Math.PI * 2);
    ctx.fill();
  }

  if (s.show_early) {
    events.slice(0, Math.min(events.length, s.early_reflections)).forEach((event) => {
      const dir = unitFromAed(event.az, event.el);
      const endpoint = {
        x: clamp(listener.x + dir.x * selectedProfile.source_distance * 0.65, 0, s.room_x),
        y: clamp(listener.y + dir.z * selectedProfile.source_distance * 0.65, 0, s.room_y),
        z: clamp(listener.z + dir.y * selectedProfile.source_distance * 0.65, 0, s.room_z)
      };
      const eventColor = event.type === "chamber" ? "120, 190, 150" : "216, 162, 74";
      ctx.strokeStyle = `rgba(${eventColor}, ${clamp(event.amp * 3.6, 0.18, 0.72)})`;
      ctx.lineWidth = clamp(event.amp * 12, 2.2, 5.2);
      if (event.type === "chamber" && state.view === "top") {
        drawChamberRay(s, event, listenerPoint, px, py);
      } else {
        ctx.beginPath();
        ctx.moveTo(px(listenerPoint), py(listenerPoint));
        ctx.lineTo(px(endpoint), py(endpoint));
        ctx.stroke();
      }
      if (event.type === "image" || (event.type === "chamber" && state.view !== "top")) drawPoint(px(endpoint), py(endpoint), 3, event.type === "chamber" ? "rgba(120, 190, 150, 0.72)" : "rgba(216, 162, 74, 0.72)", event.wall, false);
      else {
        ctx.fillStyle = "rgba(216, 162, 74, 0.55)";
        ctx.fillRect(px(endpoint) - 1.5, py(endpoint) - 1.5, 3, 3);
      }
    });
  }

  if (s.show_direct) {
    ctx.strokeStyle = "rgba(90, 190, 220, 0.9)";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(px(listenerPoint), py(listenerPoint));
    ctx.lineTo(px(sourcePoint), py(sourcePoint));
    ctx.stroke();
  }

  drawPoint(px(listenerPoint), py(listenerPoint), 7, "#d7d7d7", "L", true);
  drawPoint(px(sourcePoint), py(sourcePoint), 8, "#5aa8c7", String(selected.index + 1), true);
  ctx.fillStyle = "#9a9a9a";
  ctx.font = "11px Menlo, monospace";
  ctx.fillText(`${state.view.toUpperCase()} group ${selected.index + 1}/${selected.count}  ${selected.azimuth} az / ${selected.elevation} el`, 12, 20);
  ctx.fillText("drag in Top view to move the field; use Bank Map to move mic positions", 12, ROOM_CANVAS_H - 16);
}

function drawChamberRay(s, event, listenerPoint, px, py) {
  const chambers = chamberGeometries(s);
  const chamber = chambers && chambers.length ? chambers[Math.min(chambers.length - 1, Math.max(0, event.chamber_index || 0))] : null;
  if (!chamber) return;
  const seed = Math.round(event.time * 10000 + event.amp * 100000);
  const openingPoint = pointOnOpening(chamber, 0.25 + seededNoise(seed + 1) * 0.5);
  const opening = {
    x: openingPoint.x,
    y: openingPoint.y,
    z: listenerPoint.z
  };
  const wallPick = seededNoise(seed + 3);
  let bounce;
  if (wallPick < 0.33) {
    bounce = {
      x: chamber.x + chamber.width * seededNoise(seed + 5),
      y: chamber.y + chamber.depth,
      z: listenerPoint.z
    };
  } else if (wallPick < 0.66) {
    bounce = {
      x: chamber.x,
      y: chamber.y + chamber.depth * seededNoise(seed + 7),
      z: listenerPoint.z
    };
  } else {
    bounce = {
      x: chamber.x + chamber.width,
      y: chamber.y + chamber.depth * seededNoise(seed + 9),
      z: listenerPoint.z
    };
  }
  const returnPoint = {
    ...pointOnOpening(chamber, 0.18 + seededNoise(seed + 11) * 0.64),
    z: listenerPoint.z
  };
  ctx.beginPath();
  ctx.moveTo(px(listenerPoint), py(listenerPoint));
  ctx.lineTo(px(opening), py(opening));
  ctx.lineTo(px(bounce), py(bounce));
  ctx.lineTo(px(returnPoint), py(returnPoint));
  ctx.stroke();
  ctx.fillStyle = "rgba(120, 190, 150, 0.85)";
  ctx.fillRect(px(bounce) - 3, py(bounce) - 3, 6, 6);
}

function drawChamberSide(s, ox, oy, scale, bounds) {
  const chambers = chamberGeometries(s);
  if (!chambers) return;
  chambers.forEach((chamber) => {
    const chamberBoundsLocal = chamberBounds(chamber);
    const material = chamberMaterialProfile(s, chamber);
    const x = ox + (chamberBoundsLocal.minX - bounds.minX) * scale;
    const yTop = oy + s.room_z * (1 - (0.72 + chamber.level * 0.06)) * scale;
    const w = Math.max(3, (chamberBoundsLocal.maxX - chamberBoundsLocal.minX) * scale);
    const h = s.room_z * (0.72 + chamber.level * 0.06) * scale;
    const alpha = Math.max(0.045, 0.07 + s.chamber_coupling * 0.08 + (1 - material.absorption) * 0.035 - chamber.level * 0.012);
    ctx.fillStyle = `rgba(120, 190, 150, ${alpha})`;
    ctx.fillRect(x, yTop, w, h);
    ctx.strokeStyle = chamber.level === 0 ? "rgba(120, 190, 150, 0.72)" : "rgba(120, 190, 150, 0.48)";
    ctx.lineWidth = 1.2;
    ctx.strokeRect(x, yTop, w, h);

    const opening = chamberOpeningSegment(chamber);
    const openCenterX = (opening.x1 + opening.x2) * 0.5;
    const openWidth = Math.max(Math.abs(opening.x2 - opening.x1), chamber.opening * 0.16);
    const openX = ox + (openCenterX - bounds.minX) * scale - openWidth * scale * 0.5;
    ctx.fillStyle = "rgba(5, 6, 7, 0.92)";
    ctx.fillRect(openX, oy + s.room_z * 0.24 * scale, Math.max(3, openWidth * scale), s.room_z * 0.56 * scale);

    ctx.fillStyle = "#78be96";
    ctx.font = "9px Menlo, monospace";
    ctx.fillText(chamber.level === 0 ? `chamber ${chamber.index + 1}` : `nested ${chamber.level}`, x + 6, yTop + 14);
  });
  ctx.lineWidth = 1;
}

function drawChamberPlan(s, ox, oy, scale) {
  const chambers = chamberGeometries(s);
  if (!chambers) return;
  const bounds = floorplanBounds(s);
  chambers.forEach((chamber) => {
    const poly = chamberPolygon(chamber);
    const first = poly[0];
    const x = ox + (chamber.x - bounds.minX) * scale;
    const y = oy + (chamber.y - bounds.minY) * scale;
    const openingSegment = chamberOpeningSegment(chamber);
    const openX1 = ox + (openingSegment.x1 - bounds.minX) * scale;
    const openY1 = oy + (openingSegment.y1 - bounds.minY) * scale;
    const openX2 = ox + (openingSegment.x2 - bounds.minX) * scale;
    const openY2 = oy + (openingSegment.y2 - bounds.minY) * scale;
    const material = chamberMaterialProfile(s, chamber);
    const alpha = 0.05 + s.chamber_coupling * 0.08 - chamber.level * 0.01;
    ctx.fillStyle = `rgba(120, 190, 150, ${Math.max(0.035, alpha + (1 - material.absorption) * 0.03)})`;
    ctx.beginPath();
    ctx.moveTo(ox + (first.x - bounds.minX) * scale, oy + (first.y - bounds.minY) * scale);
    poly.slice(1).forEach((point) => ctx.lineTo(ox + (point.x - bounds.minX) * scale, oy + (point.y - bounds.minY) * scale));
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = chamber.level === 0 ? "rgba(120, 190, 150, 0.72)" : "rgba(120, 190, 150, 0.48)";
    ctx.stroke();
    ctx.strokeStyle = "rgba(5, 6, 7, 0.95)";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(openX1, openY1);
    ctx.lineTo(openX2, openY2);
    ctx.stroke();
    ctx.lineWidth = 1;
    ctx.fillStyle = "#78be96";
    ctx.font = "10px Menlo, monospace";
    ctx.fillText(chamber.level === 0 ? `chamber ${chamber.index + 1}` : `nested ${chamber.level}`, x + 8, y + 16);
    ctx.fillStyle = "#8f9a94";
    ctx.font = "9px Menlo, monospace";
    ctx.fillText(`${material.material_key} a${round(material.absorption, 2)} s${round(material.scattering, 2)}`, x + 8, y + 29);
  });
}

function drawOutsideOpeningPlan(s, ox, oy, scale) {
  const bounds = floorplanBounds(s);
  roomOpeningSegments(s).forEach((opening) => {
    const openX1 = ox + (opening.x1 - bounds.minX) * scale;
    const openY1 = oy + (opening.y1 - bounds.minY) * scale;
    const openX2 = ox + (opening.x2 - bounds.minX) * scale;
    const openY2 = oy + (opening.y2 - bounds.minY) * scale;
    const centerX = ox + (opening.center.x - bounds.minX) * scale;
    const centerY = oy + (opening.center.y - bounds.minY) * scale;
    const outward = opening.outward || chamberOutwardVector(opening.side);
    ctx.strokeStyle = "rgba(5, 6, 7, 0.98)";
    ctx.lineWidth = 4.8;
    ctx.beginPath();
    ctx.moveTo(openX1, openY1);
    ctx.lineTo(openX2, openY2);
    ctx.stroke();
    ctx.strokeStyle = "rgba(200, 245, 235, 0.88)";
    ctx.lineWidth = 1.5;
    ctx.setLineDash([5, 4]);
    ctx.beginPath();
    ctx.moveTo(openX1, openY1);
    ctx.lineTo(openX2, openY2);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = "rgba(200, 245, 235, 0.88)";
    ctx.font = "9px Menlo, monospace";
    ctx.fillText(`outside ${opening.index + 1}`, centerX + outward.x * 16 + 5, centerY + outward.y * 16 + 3);
  });
  ctx.lineWidth = 1;
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
  const pad = 48;
  const bounds = floorplanBounds(s);
  const roomW = Math.max(0.5, bounds.maxX - bounds.minX);
  const roomH = Math.max(0.5, bounds.maxY - bounds.minY);
  const scale = Math.min((ROOM_CANVAS_W - pad * 2) / roomW, (ROOM_CANVAS_H - pad * 2) / roomH);
  const ox = (ROOM_CANVAS_W - roomW * scale) / 2;
  const oy = (ROOM_CANVAS_H - roomH * scale) / 2;
  const px = (p) => ox + (p.x - bounds.minX) * scale;
  const py = (p) => oy + (p.y - bounds.minY) * scale;
  state.directionHitPoints = [];
  state.bankProjection = { ox, oy, scale, minX: bounds.minX, minY: bounds.minY, maxX: bounds.maxX, maxY: bounds.maxY };

  drawPlanPolygon(roomPolygon(s), ox, oy, scale, bounds, "rgba(90,168,199,0.045)", "rgba(90,168,199,0.72)", 1.2);
  drawChamberPlan(s, ox, oy, scale);

  ctx.strokeStyle = "rgba(255,255,255,0.08)";
  ctx.lineWidth = 1;
  for (let i = 1; i < 8; i += 1) {
    const x = ox + roomW * scale * i / 8;
    const y = oy + roomH * scale * i / 8;
    ctx.beginPath();
    ctx.moveTo(x, oy);
    ctx.lineTo(x, oy + roomH * scale);
    ctx.moveTo(ox, y);
    ctx.lineTo(ox + roomW * scale, y);
    ctx.stroke();
  }

  const listener = roomPoints(s, selected).listener;
  if (pointInFloorplan(listener, s)) {
    drawPoint(px(listener), py(listener), 7, "#d7d7d7", "L", true);
  }

  if (s.show_diffuse) {
    const profile = groupProfile(s, selected.index);
    const position = groupMapPosition(s, selected, profile);
    ctx.fillStyle = `rgba(90, 168, 199, ${0.04 + (1 - profile.absorption) * 0.08})`;
    ctx.beginPath();
    ctx.arc(px(position), py(position), 22 + profile.scattering * 86, 0, Math.PI * 2);
    ctx.fill();
  }

  dirs.forEach((dir, index) => {
    const metrics = groupMetrics(s, index);
    const position = groupMapPosition(s, metrics, metrics.profile);
    const x = px(position);
    const y = py(position);
    const active = index === selected.index;
    const energyRadius = clamp(5 + Math.sqrt(metrics.early_energy) * 18, 5, 18);
    const radius = active ? Math.max(10, energyRadius) : energyRadius * 0.82;
    state.directionHitPoints.push({ x, y, r: radius + 10, index });
    ctx.globalAlpha = active ? 1 : 0.58;
    ctx.fillStyle = active ? "#d8a24a" : "#5aa8c7";
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#d7d7d7";
    ctx.font = "10px Menlo, monospace";
    ctx.fillText(`G${index + 1}`, x + 11, y + 3);
    if (active) {
      const dirUnit = unitFromAed(dir[0], dir[1]);
      const lobeX = x + dirUnit.x * 46;
      const lobeY = y + dirUnit.z * 46;
      drawDirectivityLobe(x, y, lobeX, lobeY, 76, metrics.profile.direction_spread_deg);
      ctx.strokeStyle = "rgba(216, 162, 74, 0.72)";
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(lobeX, lobeY);
      ctx.stroke();
      ctx.fillStyle = "rgba(216, 162, 74, 0.10)";
      ctx.beginPath();
      ctx.arc(x, y, 34, 0, Math.PI * 2);
      ctx.fill();
    }
  });
  ctx.globalAlpha = 1;
  ctx.fillStyle = "#9a9a9a";
  ctx.font = "11px Menlo, monospace";
  ctx.fillText(`Bank Map: ${dirs.length} IR groups placed in floorplan / ${s.channels_per_ir}ch per group / ${s.stacked_channels}ch stacked`, 12, 20);
  ctx.fillText(`selected G${selected.index + 1}: ${selected.channels_start}-${selected.channels_end}`, 12, 38);
  ctx.fillText("drag IR group points inside the room/chamber geometry", 12, ROOM_CANVAS_H - 16);
}

function drawDirectivityLobe(cx, cy, x, y, radius, spreadDeg) {
  const dx = x - cx;
  const dy = y - cy;
  const len = Math.sqrt(dx * dx + dy * dy) || 1;
  const ux = dx / len;
  const uy = dy / len;
  const width = clamp(spreadDeg / 120, 0, 1);
  ctx.fillStyle = "rgba(216, 162, 74, 0.12)";
  ctx.beginPath();
  ctx.moveTo(cx, cy);
  ctx.quadraticCurveTo(cx + ux * radius * 0.35 - uy * radius * width * 0.22, cy + uy * radius * 0.35 + ux * radius * width * 0.22, x, y);
  ctx.quadraticCurveTo(cx + ux * radius * 0.35 + uy * radius * width * 0.22, cy + uy * radius * 0.35 - ux * radius * width * 0.22, cx, cy);
  ctx.fill();
}

function drawBankMatrix(s) {
  const dirs = activeDirections(s);
  const selected = selectedDirection(s);
  const metrics = dirs.map((_, index) => groupMetrics(s, index));
  const maxEnergy = Math.max(...metrics.map((item) => item.early_energy), 0.0001);
  const maxTime = Math.max(s.duration, ...metrics.map((item) => item.first_reflection_time), 0.1);
  const pad = 34;
  const rowH = Math.min(48, (ROOM_CANVAS_H - pad * 2 - 42) / Math.max(1, dirs.length));
  const x0 = pad;
  const y0 = pad + 36;
  const columns = {
    group: x0,
    aed: x0 + 76,
    channels: x0 + 188,
    direct: x0 + 318,
    first: x0 + 446,
    energy: x0 + 602
  };
  state.matrixHitRows = [];

  ctx.fillStyle = "#9a9a9a";
  ctx.font = "11px Menlo, monospace";
  ctx.fillText("Bank Matrix: each row is one encoded ambisonic IR group", x0, 22);
  ctx.fillStyle = "#d7d7d7";
  ctx.fillText("Group", columns.group, y0 - 10);
  ctx.fillText("AED", columns.aed, y0 - 10);
  ctx.fillText("Stack", columns.channels, y0 - 10);
  ctx.fillText("Direct", columns.direct, y0 - 10);
  ctx.fillText("First reflection", columns.first, y0 - 10);
  ctx.fillText("Early energy", columns.energy, y0 - 10);

  metrics.forEach((item, row) => {
    const y = y0 + row * rowH;
    const active = row === selected.index;
    ctx.fillStyle = active ? "rgba(216, 162, 74, 0.12)" : row % 2 === 0 ? "rgba(255,255,255,0.035)" : "rgba(255,255,255,0.015)";
    ctx.fillRect(x0 - 10, y - 18, ROOM_CANVAS_W - pad * 2 + 20, rowH - 5);
    state.matrixHitRows.push({
      index: row,
      x: x0 - 10,
      y: y - 18,
      w: ROOM_CANVAS_W - pad * 2 + 20,
      h: rowH - 5
    });
    ctx.strokeStyle = active ? "rgba(216, 162, 74, 0.82)" : "rgba(255,255,255,0.08)";
    ctx.strokeRect(x0 - 10.5, y - 18.5, ROOM_CANVAS_W - pad * 2 + 20, rowH - 5);

    ctx.fillStyle = active ? "#f0d39a" : "#d7d7d7";
    ctx.fillText(`G${row + 1}`, columns.group, y);
    ctx.fillText(`${round(item.azimuth)}/${round(item.elevation)}`, columns.aed, y);
    ctx.fillText(`${item.channels_start}-${item.channels_end}`, columns.channels, y);

    const directW = clamp(item.direct_time / maxTime, 0, 1) * 90;
    const firstW = clamp(item.first_reflection_time / maxTime, 0, 1) * 110;
    drawMetricBar(columns.direct, y + 8, 94, directW, "#5aa8c7", `${Math.round(item.direct_time * 1000)} ms`);
    drawMetricBar(columns.first, y + 8, 116, firstW, "#d8a24a", `${item.first_reflection_wall} ${Math.round(item.first_reflection_time * 1000)} ms`);
    drawMetricBar(columns.energy, y + 8, 170, clamp(item.early_energy / maxEnergy, 0, 1) * 170, item.chamber_energy > 0.00001 ? "#78be96" : "#b8d8e8", `${round(item.early_energy, 3)} c${round(item.chamber_energy, 3)}`);
  });
  ctx.fillStyle = "#9a9a9a";
  ctx.font = "10px Menlo, monospace";
  ctx.fillText("click a row to select the IR group", x0, ROOM_CANVAS_H - 16);
}

function drawReflectionLayers(s) {
  const dirs = activeDirections(s);
  const selected = selectedDirection(s);
  const pad = 36;
  const top = 66;
  const bottom = ROOM_CANVAS_H - 50;
  const left = 116;
  const right = ROOM_CANVAS_W - 34;
  const width = right - left;
  const rowH = Math.min(64, (bottom - top) / Math.max(1, dirs.length));
  const duration = Math.max(0.1, s.duration);
  const focusEnd = clamp(Math.max(0.18, s.late_start_seconds * 2.2), 0.12, Math.min(duration, 0.65));
  const focusWidth = duration <= focusEnd ? 1 : 0.78;
  const frontCurve = 14;
  const tailCurve = 8;
  const timeToX = (time) => {
    const boundedTime = clamp(time, 0, duration);
    if (boundedTime <= focusEnd || duration <= focusEnd) {
      const normalized = clamp(boundedTime / focusEnd, 0, 1);
      const curved = Math.log1p(normalized * frontCurve) / Math.log1p(frontCurve);
      return left + curved * width * focusWidth;
    }
    const tailNorm = clamp((boundedTime - focusEnd) / Math.max(0.001, duration - focusEnd), 0, 1);
    const curvedTail = Math.log1p(tailNorm * tailCurve) / Math.log1p(tailCurve);
    return left + width * focusWidth + curvedTail * width * (1 - focusWidth);
  };
  const xToTime = (x) => {
    const normalized = clamp((x - left) / width, 0, 1);
    if (normalized <= focusWidth || duration <= focusEnd) {
      const frontNorm = normalized / focusWidth;
      return focusEnd * (Math.expm1(frontNorm * Math.log1p(frontCurve)) / frontCurve);
    }
    const tailNorm = (normalized - focusWidth) / Math.max(0.001, 1 - focusWidth);
    return focusEnd + (duration - focusEnd) * (Math.expm1(tailNorm * Math.log1p(tailCurve)) / tailCurve);
  };
  const timeLabel = (time) => time < 1 ? `${Math.round(time * 1000)}ms` : `${round(time, 1)}s`;
  const lateX = timeToX(s.late_start_seconds);
  state.matrixHitRows = [];

  ctx.fillStyle = "#9a9a9a";
  ctx.font = "11px Menlo, monospace";
  ctx.fillText("Reflection Layers: all IR groups across time", pad, 22);
  ctx.fillText("front-weighted log time view: early impulse expanded, late tail compressed", pad, 40);

  ctx.strokeStyle = "rgba(255,255,255,0.10)";
  ctx.beginPath();
  const tickTimes = [0, 0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.15, 0.2, 0.35, 0.5, 1, 2, 4, 8, duration]
    .filter((time, index, items) => time <= duration && items.indexOf(time) === index);
  let lastLabelX = -Infinity;
  tickTimes.forEach((time) => {
    const x = timeToX(time);
    ctx.moveTo(x, top - 18);
    ctx.lineTo(x, bottom + 8);
    if (x - lastLabelX > 42 || time === duration) {
      ctx.fillStyle = "#777";
      ctx.fillText(timeLabel(time), x - 10, bottom + 26);
      lastLabelX = x;
    }
  });
  ctx.stroke();

  dirs.forEach((dir, index) => {
    const y = top + index * rowH;
    const active = index === selected.index;
    const info = {
      index,
      count: dirs.length,
      azimuth: dir[0],
      elevation: dir[1],
      channels_start: index * s.channels_per_ir + 1,
      channels_end: (index + 1) * s.channels_per_ir
    };
    const events = reflectionEvents(s, info);
    const profile = groupProfile(s, index);
    const directT = profile.pre_delay_ms / 1000 + profile.source_distance / 343;
    const directX = timeToX(directT);
    const rowTop = y - 16;
    const rowMid = y + rowH * 0.36;
    const imageBase = rowTop + rowH * 0.34;
    const chamberBase = rowTop + rowH * 0.74;
    const rowBottom = y + rowH - 10;
    const hue = (index * 47 + 194) % 360;
    const groupColor = `hsl(${hue}, 58%, ${active ? 66 : 48}%)`;

    ctx.fillStyle = active ? "rgba(216, 162, 74, 0.10)" : index % 2 === 0 ? "rgba(255,255,255,0.028)" : "rgba(255,255,255,0.014)";
    ctx.fillRect(pad, rowTop, ROOM_CANVAS_W - pad * 2, rowH - 4);
    ctx.strokeStyle = active ? "rgba(216,162,74,0.76)" : "rgba(255,255,255,0.07)";
    ctx.strokeRect(pad + 0.5, rowTop + 0.5, ROOM_CANVAS_W - pad * 2, rowH - 4);
    ctx.fillStyle = groupColor;
    ctx.fillRect(pad + 1, rowTop + 1, 4, rowH - 6);
    state.matrixHitRows.push({ index, x: pad, y: rowTop, w: ROOM_CANVAS_W - pad * 2, h: rowH - 4 });

    ctx.fillStyle = active ? "#f0d39a" : groupColor;
    ctx.fillText(`G${index + 1}`, pad + 8, rowMid + 4);
    ctx.fillStyle = "#8f9aa0";
    ctx.fillText(`${round(dir[0])}/${round(dir[1])}`, pad + 42, rowMid + 4);

    ctx.strokeStyle = "rgba(255,255,255,0.08)";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(left, imageBase);
    ctx.lineTo(right, imageBase);
    ctx.moveTo(left, chamberBase);
    ctx.lineTo(right, chamberBase);
    ctx.stroke();

    if (s.show_diffuse) {
      const alpha = 0.08 + (1 - profile.absorption) * 0.10;
      ctx.fillStyle = `rgba(90,168,199,${alpha})`;
      ctx.fillRect(lateX, rowTop + 7, right - lateX, rowH - 18);
      ctx.strokeStyle = "rgba(215,215,215,0.35)";
      ctx.beginPath();
      for (let x = Math.ceil(lateX); x <= right; x += 3) {
        const t = xToTime(x);
        const env = Math.exp(-(t - s.late_start_seconds) / Math.max(0.04, profile.rt60 * 0.42));
        const yy = rowBottom - env * (rowH - 24) * (1 - profile.tail_soften * 0.55);
        if (x === Math.ceil(lateX)) ctx.moveTo(x, yy);
        else ctx.lineTo(x, yy);
      }
      ctx.stroke();
    }

    if (s.show_direct) {
      ctx.strokeStyle = active ? "rgba(112,220,244,0.98)" : "rgba(90,190,220,0.65)";
      ctx.lineWidth = active ? 2.6 : 1.6;
      ctx.beginPath();
      ctx.moveTo(directX, imageBase - 8);
      ctx.lineTo(directX, chamberBase + 8);
      ctx.stroke();
      ctx.fillStyle = "#70dcf4";
      ctx.beginPath();
      ctx.arc(directX, rowMid, active ? 4.6 : 3.4, 0, Math.PI * 2);
      ctx.fill();
    }

    if (s.show_early) {
      events.slice(0, Math.min(events.length, s.early_reflections)).forEach((event) => {
        const x = timeToX(event.time);
        const h = clamp(event.amp * 135, 4, rowH * 0.28);
        const isChamber = event.type === "chamber";
        const alpha = clamp(event.amp * 4.8, active ? 0.42 : 0.24, active ? 0.96 : 0.72);
        const color = isChamber ? `rgba(120,190,150,${alpha})` : `rgba(216,162,74,${alpha})`;
        ctx.strokeStyle = color;
        ctx.fillStyle = color;
        ctx.lineWidth = active ? 2.4 : 1.5;
        if (isChamber) {
          ctx.beginPath();
          ctx.moveTo(x, chamberBase);
          ctx.lineTo(x, chamberBase + h);
          ctx.stroke();
          ctx.fillRect(x - 2.5, chamberBase + h - 2.5, 5, 5);
        } else {
          ctx.beginPath();
          ctx.moveTo(x, imageBase);
          ctx.lineTo(x, imageBase - h);
          ctx.stroke();
          ctx.beginPath();
          ctx.moveTo(x, imageBase - h - 4);
          ctx.lineTo(x - 4, imageBase - h + 2);
          ctx.lineTo(x + 4, imageBase - h + 2);
          ctx.closePath();
          ctx.fill();
        }
        if (active && (event.type === "image" || event.type === "chamber")) {
          ctx.fillStyle = isChamber ? "#78be96" : "#d8a24a";
          ctx.font = "9px Menlo, monospace";
          ctx.fillText(event.wall, x + 4, isChamber ? chamberBase + h + 8 : imageBase - h - 7);
        }
      });
    }
  });
  ctx.lineWidth = 1;
  ctx.fillStyle = "#9a9a9a";
  ctx.font = "10px Menlo, monospace";
  ctx.fillText("click a row to select; upper/lower lanes separate image-source and chamber timing", pad, ROOM_CANVAS_H - 16);
}

function drawMetricBar(x, y, width, fillWidth, color, label) {
  ctx.fillStyle = "rgba(255,255,255,0.08)";
  ctx.fillRect(x, y - 10, width, 9);
  ctx.fillStyle = color;
  ctx.fillRect(x, y - 10, fillWidth, 9);
  ctx.fillStyle = "#9a9a9a";
  ctx.font = "10px Menlo, monospace";
  ctx.fillText(label, x, y + 12);
}

function updateGroupStrip(s) {
  const selected = selectedDirection(s);
  const groups = activeDirections(s).map((dir, index) => {
    const start = index * s.channels_per_ir + 1;
    const end = (index + 1) * s.channels_per_ir;
    const active = index === selected.index ? " active" : "";
    return `<button type="button" class="group-chip${active}" data-group="${index}">
      <span>G${index + 1}</span><small>${round(dir[0])}/${round(dir[1])}</small><small>${start}-${end}</small>
    </button>`;
  }).join("");
  readouts.groupStrip.innerHTML = groups;
  readouts.groupStrip.querySelectorAll("[data-group]").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedDirection = Number(button.dataset.group);
      drawRoom();
    });
  });
}

function stepGroup(delta) {
  const s = settings();
  const count = activeDirections(s).length;
  state.selectedDirection = (state.selectedDirection + delta + count) % count;
  drawRoom();
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
  const lateX = clamp(s.late_start_seconds / duration, 0, 1) * w;
  if (s.show_diffuse) {
    timelineCtx.fillStyle = "rgba(90, 190, 220, 0.18)";
    timelineCtx.fillRect(lateX, 0, w - lateX, h);
  }

  if (s.show_direct) {
    const directX = clamp((s.pre_delay_ms / 1000 + s.source_distance / 343) / duration, 0, 1) * w;
    timelineCtx.strokeStyle = "rgba(90, 190, 220, 0.95)";
    timelineCtx.lineWidth = 2.4;
    timelineCtx.beginPath();
    timelineCtx.moveTo(directX + 0.5, h - 12);
    timelineCtx.lineTo(directX + 0.5, 20);
    timelineCtx.stroke();
  }

  if (s.show_early) events.forEach((event) => {
    const x = clamp(event.time / duration, 0, 1) * w;
    const height = clamp(event.amp * 220, 6, h - 20);
    timelineCtx.strokeStyle = "rgba(216, 162, 74, 0.85)";
    timelineCtx.lineWidth = clamp(event.amp * 10, 2, 4.5);
    timelineCtx.beginPath();
    timelineCtx.moveTo(x + 0.5, h - 12);
    timelineCtx.lineTo(x + 0.5, h - 12 - height);
    timelineCtx.stroke();
  });

  if (s.show_diffuse) {
    timelineCtx.strokeStyle = "rgba(215,215,215,0.5)";
    timelineCtx.lineWidth = 1.6;
    timelineCtx.beginPath();
    for (let x = 0; x < w; x += 1) {
      const t = x / w * duration;
      const env = t < s.late_start_seconds ? 0 : Math.exp(-(t - s.late_start_seconds) / Math.max(0.04, s.estimated_rt60 * 0.42));
      const y = h - 12 - env * (h - 32) * (1 - s.tail_soften * 0.55);
      if (x === 0) timelineCtx.moveTo(x, y);
      else timelineCtx.lineTo(x, y);
    }
    timelineCtx.stroke();
  }

  timelineCtx.fillStyle = "#9a9a9a";
  timelineCtx.lineWidth = 1;
  timelineCtx.font = "10px Menlo, monospace";
  timelineCtx.fillText("direct / early reflections / late tail", 8, 14);
}

function updateReadouts(s) {
  const selected = selectedDirection(s);
  const profile = groupProfile(s, selected.index);
  const points = roomPoints(s, selected, profile);
  const metrics = groupMetrics(s, selected.index);
  readouts.rt60.textContent = `${s.estimated_rt60.toFixed(2)} s`;
  readouts.volume.textContent = `${(s.room_x * s.room_y * s.room_z).toFixed(1)} m3`;
  readouts.channels.textContent = `${s.stacked_channels}`;
  readouts.late.textContent = `${Math.round(s.late_start_seconds * 1000)} ms`;
  readouts.group.innerHTML = `
    <div><span>Group</span><strong>${selected.index + 1} / ${selected.count}</strong></div>
    <div><span>AED</span><strong>${round(selected.azimuth)} deg / ${round(selected.elevation)} deg</strong></div>
    <div><span>Stacked channels</span><strong>${selected.channels_start}-${selected.channels_end}</strong></div>
    <div><span>Source XYZ m</span><strong>${round(metrics.map_position.x, 2)}, ${round(metrics.map_position.y, 2)}, ${round(metrics.map_position.z, 2)}</strong></div>
    <div><span>Direct arrival</span><strong>${Math.round(metrics.direct_time * 1000)} ms</strong></div>
    <div><span>First reflection</span><strong>${metrics.first_reflection_wall} / ${Math.round(metrics.first_reflection_time * 1000)} ms</strong></div>
    <div><span>Early energy</span><strong>${round(metrics.early_energy, 3)}</strong></div>
    <div><span>Chamber energy</span><strong>${round(metrics.chamber_energy, 3)}</strong></div>
    <div><span>Exterior leak</span><strong>${s.outside_opening ? round(s.outside_leak_factor, 3) : "off"}</strong></div>
    <div><span>Local material</span><strong>a ${round(profile.absorption, 2)} / s ${round(profile.scattering, 2)} / tail ${round(profile.tail_soften, 2)}</strong></div>
    <div><span>Local distance</span><strong>${round(profile.source_distance, 2)} m</strong></div>
  `;
  readouts.json.textContent = JSON.stringify(exportObject(s), null, 2);
}

function exportObject(s = settings()) {
  const outsideOpenings = roomOpeningSegments(s);
  const groups = activeDirections(s).map((d, i) => {
    const info = {
      index: i,
      azimuth: d[0],
      elevation: d[1],
      channels_start: i * s.channels_per_ir + 1,
      channels_end: (i + 1) * s.channels_per_ir
    };
    const metrics = groupMetrics(s, i);
    const points = roomPoints(s, info, metrics.profile);
    return {
      group: i + 1,
      azimuth: d[0],
      elevation: d[1],
      channels: `${info.channels_start}-${info.channels_end}`,
      direct_time_ms: Math.round(metrics.direct_time * 1000),
      first_reflection: {
        wall: metrics.first_reflection_wall,
        time_ms: Math.round(metrics.first_reflection_time * 1000)
      },
      early_energy: round(metrics.early_energy, 5),
      chamber_energy: round(metrics.chamber_energy, 5),
      local_profile: {
        absorption: round(metrics.profile.absorption, 3),
        scattering: round(metrics.profile.scattering, 3),
        tail_soften: round(metrics.profile.tail_soften, 3),
        source_distance: round(metrics.profile.source_distance, 3),
        direction_spread_deg: round(metrics.profile.direction_spread_deg, 2),
        pre_delay_ms: round(metrics.profile.pre_delay_ms, 2),
        rt60: round(metrics.profile.rt60, 3)
      },
      source_position_m: {
        x: round(metrics.map_position.x, 3),
        y: round(metrics.map_position.y, 3),
        z: round(metrics.map_position.z, 3)
      }
    };
  });
  return {
    tool: "s3g-mc IR Sketch",
    target_process: "3OAFX Synthetic Ambisonic IR Bank",
    room_x: round(s.room_x),
    room_y: round(s.room_y),
    room_z: round(s.room_z),
    material_preset: s.material_preset,
    absorption: round(s.absorption, 3),
    scattering: round(s.scattering, 3),
    tail_soften: round(s.tail_soften, 3),
    space_shape: s.space_shape,
    room_shape: s.room_shape,
    topology_bias: round(s.topology_bias, 3),
    room_polygon: roomPolygon(s).map((point) => ({
      x: round(point.x, 3),
      y: round(point.y, 3)
    })),
    chamber_shape: s.chamber_shape,
    chamber_side: s.chamber_side,
    exterior_opening: outsideOpenings.length ? {
      enabled: true,
      side: s.outside_opening_side,
      count: outsideOpenings.length,
      position: round(s.outside_opening_position, 3),
      spread: round(s.outside_opening_spread, 3),
      width: round(s.outside_opening_width, 3),
      opening_m: round(outsideOpenings.reduce((sum, item) => sum + item.opening, 0), 3),
      leak: round(s.outside_leak, 3),
      leak_factor: round(s.outside_leak_factor, 3),
      interpretation: "energy escape boundary for late-tail thinning and reduced reflection density",
      openings: outsideOpenings.map((opening) => ({
        index: opening.index + 1,
        side: opening.side,
        opening_m: round(opening.opening, 3),
        opening_segment: {
          x1: round(opening.x1, 3),
          y1: round(opening.y1, 3),
          x2: round(opening.x2, 3),
          y2: round(opening.y2, 3)
        }
      })),
      opening_segment: {
        x1: round(outsideOpenings[0].x1, 3),
        y1: round(outsideOpenings[0].y1, 3),
        x2: round(outsideOpenings[0].x2, 3),
        y2: round(outsideOpenings[0].y2, 3)
      }
    } : {
      enabled: false,
      leak: 0
    },
    chamber: s.space_shape === "side_chamber" ? {
      material: s.chamber_material,
      material_mode: s.chamber_material_mode,
      material_mix: round(s.chamber_material_mix, 3),
      width: round(s.chamber_width, 3),
      depth: round(s.chamber_depth, 3),
      count: round(s.chamber_count, 0),
      position: round(s.chamber_position, 3),
      nested_chambers: round(s.nested_chambers, 0),
      opening_width: round(s.opening_width, 3),
      coupling: round(s.chamber_coupling, 3),
      chambers: (chamberGeometries(s) || []).map((chamber) => ({
        ...(function () {
          const material = chamberMaterialProfile(s, chamber);
          return {
            material_profile: {
              material: material.material_key,
              absorption: round(material.absorption, 3),
              scattering: round(material.scattering, 3),
              tail_soften: round(material.tail_soften, 3)
            }
          };
        }()),
        index: chamber.index + 1,
        level: chamber.level,
        x: round(chamber.x, 3),
        y: round(chamber.y, 3),
        width: round(chamber.width, 3),
        depth: round(chamber.depth, 3),
        opening_x: round(chamber.openingX, 3),
        opening_y: round(chamber.openingY, 3),
        opening: round(chamber.opening, 3),
        polygon: chamberPolygon(chamber).map((point) => ({ x: round(point.x, 3), y: round(point.y, 3) })),
        opening_segment: (function () {
          const segment = chamberOpeningSegment(chamber);
          return {
            x1: round(segment.x1, 3),
            y1: round(segment.y1, 3),
            x2: round(segment.x2, 3),
            y2: round(segment.y2, 3)
          };
        }()),
        side: chamber.side,
        shape: chamber.shape
      }))
    } : null,
    field_offset: {
      x: round(s.field_x, 3),
      y: round(s.field_y, 3)
    },
    source_distance: round(s.source_distance, 3),
    direction_spread_deg: round(s.direction_spread_deg),
    group_variation: round(s.group_variation, 3),
    surface_contrast: round(s.surface_contrast, 3),
    distance_variation: round(s.distance_variation, 3),
    order: s.order,
    direction_set: s.direction_set,
    effective_direction_layout: s.effective_direction_layout,
    groups,
    duration: round(s.duration, 3),
    pre_delay_ms: round(s.pre_delay_ms),
    early_reflections: round(s.early_reflections),
    camera: {
      azimuth: round(s.camera_azimuth, 1),
      elevation: round(s.camera_elevation, 1),
      zoom: round(s.camera_zoom, 3)
    },
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

function polygonArea(poly) {
  let area = 0;
  for (let i = 0; i < poly.length; i += 1) {
    const a = poly[i];
    const b = poly[(i + 1) % poly.length];
    area += a.x * b.y - b.x * a.y;
  }
  return area * 0.5;
}

function pushVec3(list, x, y, z) {
  list.push(round(x, 4), round(y, 4), round(z, 4));
}

function addExtrudedPolygonMesh(meshes, name, poly, height, materialIndex) {
  if (!poly || poly.length < 3) return;
  const positions = [];
  const indices = [];
  const clockwise = polygonArea(poly) < 0;
  poly.forEach((point) => pushVec3(positions, point.x, 0, -point.y));
  poly.forEach((point) => pushVec3(positions, point.x, height, -point.y));
  for (let i = 1; i < poly.length - 1; i += 1) {
    if (clockwise) {
      indices.push(0, i + 1, i);
      indices.push(poly.length, poly.length + i, poly.length + i + 1);
    } else {
      indices.push(0, i, i + 1);
      indices.push(poly.length, poly.length + i + 1, poly.length + i);
    }
  }
  for (let i = 0; i < poly.length; i += 1) {
    const next = (i + 1) % poly.length;
    const a = i;
    const b = next;
    const c = next + poly.length;
    const d = i + poly.length;
    if (clockwise) indices.push(a, c, b, a, d, c);
    else indices.push(a, b, c, a, c, d);
  }
  meshes.push({ name, positions, indices, materialIndex });
}

function addPointMarkerMesh(meshes, name, point, radius, height, materialIndex) {
  const sides = 12;
  const poly = Array.from({ length: sides }, (_, index) => {
    const angle = index / sides * Math.PI * 2;
    return {
      x: point.x + Math.cos(angle) * radius,
      y: point.y + Math.sin(angle) * radius
    };
  });
  addExtrudedPolygonMesh(meshes, name, poly, height, materialIndex);
}

function addOpeningPortalMesh(meshes, name, chamber, height, materialIndex) {
  const segment = chamberOpeningSegment(chamber);
  const outward = chamber.edgeOutward || chamberOutwardVector(chamber.side);
  addSegmentPortalMesh(meshes, name, segment, outward, height, materialIndex);
}

function addRoomOpeningPortalMesh(meshes, name, s, height, materialIndex) {
  mergedOpeningSegments(roomOpeningSegments(s)).forEach((segment) => {
    addSegmentPortalMesh(meshes, `${name} ${segment.index + 1}`, segment, segment.outward, height, materialIndex);
  });
}

function mergedOpeningSegments(segments) {
  const groups = new Map();
  segments.forEach((segment) => {
    const dx = segment.x2 - segment.x1;
    const dy = segment.y2 - segment.y1;
    const length = Math.max(0.001, Math.sqrt(dx * dx + dy * dy));
    const tx = dx / length;
    const ty = dy / length;
    const normal = segment.x1 * -(ty) + segment.y1 * tx;
    const key = [
      segment.side || "wall",
      Math.round(Math.abs(tx) * 1000),
      Math.round(Math.abs(ty) * 1000),
      Math.round(normal * 1000),
      Math.round((segment.outward?.x || 0) * 1000),
      Math.round((segment.outward?.y || 0) * 1000)
    ].join(":");
    const start = segment.x1 * tx + segment.y1 * ty;
    const end = segment.x2 * tx + segment.y2 * ty;
    if (!groups.has(key)) groups.set(key, { tx, ty, normal, side: segment.side, outward: segment.outward, items: [] });
    groups.get(key).items.push({
      start: Math.min(start, end),
      end: Math.max(start, end),
      height: segment.height || 0,
      kind: segment.kind || "opening",
      level: Number(segment.level || 0),
      original: segment
    });
  });
  const merged = [];
  groups.forEach((group) => {
    group.items.sort((a, b) => a.start - b.start);
    const spans = [];
    group.items.forEach((item) => {
      const last = spans[spans.length - 1];
      if (last && item.start <= last.end + 0.04) {
        last.end = Math.max(last.end, item.end);
        last.height = Math.max(last.height || 0, item.height || 0);
        last.level = Math.max(Number(last.level || 0), Number(item.level || 0));
        if (item.kind === "chamber") last.kind = "chamber";
        else if (item.kind === "outside" && last.kind !== "chamber") last.kind = "outside";
      } else {
        spans.push({ start: item.start, end: item.end, height: item.height || 0, kind: item.kind, level: Number(item.level || 0) });
      }
    });
    spans.forEach((span) => {
      const nx = -group.ty;
      const ny = group.tx;
      const x1 = group.tx * span.start + nx * group.normal;
      const y1 = group.ty * span.start + ny * group.normal;
      const x2 = group.tx * span.end + nx * group.normal;
      const y2 = group.ty * span.end + ny * group.normal;
      merged.push({
        x1,
        y1,
        x2,
        y2,
        opening: Math.max(0.001, span.end - span.start),
        side: group.side,
        outward: group.outward,
        index: merged.length,
        height: span.height || 0,
        kind: span.kind || "opening",
        level: Number(span.level || 0),
        center: { x: (x1 + x2) * 0.5, y: (y1 + y2) * 0.5 }
      });
    });
  });
  return merged;
}

function openingSegmentsForModel(s) {
  const openings = roomOpeningSegments(s).map((segment) => ({
    ...segment,
    kind: "outside",
    height: s.room_z * 0.86
  }));
  (chamberGeometries(s) || []).forEach((chamber) => {
    const chamberHeight = s.room_z * (0.72 + chamber.level * 0.06);
    openings.push({
      ...chamberOpeningSegment(chamber),
      index: openings.length,
      kind: "chamber",
      level: chamber.level,
      side: chamber.side,
      outward: chamber.edgeOutward || chamberOutwardVector(chamber.side),
      height: Math.min(s.room_z, chamberHeight) * 0.92
    });
  });
  return mergedOpeningSegments(openings);
}

function addSegmentPortalMesh(meshes, name, segment, outward, height, materialIndex) {
  if (!segment) return;
  outward = outward || { x: 0, y: 1 };
  const offset = 0.035;
  const dx = segment.x2 - segment.x1;
  const dy = segment.y2 - segment.y1;
  const length = Math.max(0.001, Math.sqrt(dx * dx + dy * dy));
  const tx = dx / length;
  const ty = dy / length;
  const frame = clamp(length * 0.034, 0.055, 0.14);
  const ox = (outward.x || 0) * offset;
  const oy = (outward.y || 0) * offset;
  const positions = [];
  const indices = [];
  const pushPortalQuad = (ax, ay, bx, by, bottom, top) => {
    const base = positions.length / 3;
    pushVec3(positions, ax + ox, bottom, -(ay + oy));
    pushVec3(positions, bx + ox, bottom, -(by + oy));
    pushVec3(positions, bx + ox, top, -(by + oy));
    pushVec3(positions, ax + ox, top, -(ay + oy));
    indices.push(base, base + 1, base + 2, base, base + 2, base + 3);
  };
  pushPortalQuad(
    segment.x1 - tx * frame,
    segment.y1 - ty * frame,
    segment.x1 + tx * frame,
    segment.y1 + ty * frame,
    0.01,
    height
  );
  pushPortalQuad(
    segment.x2 - tx * frame,
    segment.y2 - ty * frame,
    segment.x2 + tx * frame,
    segment.y2 + ty * frame,
    0.01,
    height
  );
  pushPortalQuad(
    segment.x1,
    segment.y1,
    segment.x2,
    segment.y2,
    Math.max(0.01, height - frame * 2.4),
    height
  );
  meshes.push({ name, positions, indices, materialIndex, portalFrame: true, portalSegment: { ...segment, height } });
}

function buildGltfMeshes(s = settings()) {
  const meshes = [];
  addExtrudedPolygonMesh(meshes, "Main room", roomPolygon(s), s.room_z, 0);
  (chamberGeometries(s) || []).forEach((chamber) => {
    const chamberHeight = s.room_z * (0.72 + chamber.level * 0.06);
    addExtrudedPolygonMesh(meshes, `Chamber ${chamber.index + 1}`, chamberPolygon(chamber), chamberHeight, 1);
  });
  openingSegmentsForModel(s).forEach((segment) => {
    addSegmentPortalMesh(meshes, `Opening ${segment.index + 1}`, segment, segment.outward, segment.height || s.room_z * 0.72, 4);
  });
  const listener = roomPoints(s).listener;
  addPointMarkerMesh(meshes, "Field center", listener, Math.max(0.12, Math.min(s.room_x, s.room_y) * 0.018), s.room_z * 0.08, 2);
  activeDirections(s).forEach((dir, index) => {
    const info = {
      index,
      azimuth: dir[0],
      elevation: dir[1],
      channels_start: index * s.channels_per_ir + 1,
      channels_end: (index + 1) * s.channels_per_ir
    };
    const position = groupMapPosition(s, info, groupProfile(s, index));
    addPointMarkerMesh(meshes, `IR group ${index + 1}`, position, Math.max(0.09, Math.min(s.room_x, s.room_y) * 0.014), s.room_z * 0.06, 3);
  });
  return meshes;
}

function buildGltf(s = settings()) {
  const meshes = buildGltfMeshes(s);
  const nodes = [];
  const gltfMeshes = [];
  let bufferOffset = 0;
  const buffers = [];
  const bufferViews = [];
  const accessors = [];

  function addAccessor(values, componentType, type) {
    const index = accessors.length;
    const count = type === "SCALAR" ? values.length : values.length / 3;
    const min = [];
    const max = [];
    if (type === "VEC3") {
      for (let axis = 0; axis < 3; axis += 1) {
        const axisValues = [];
        for (let i = axis; i < values.length; i += 3) axisValues.push(values[i]);
        min.push(Math.min(...axisValues));
        max.push(Math.max(...axisValues));
      }
    } else {
      min.push(Math.min(...values));
      max.push(Math.max(...values));
    }
    const typed = componentType === 5125 ? new Uint32Array(values) : new Float32Array(values);
    const bytes = new Uint8Array(typed.buffer);
    while (bufferOffset % 4 !== 0) {
      buffers.push(0);
      bufferOffset += 1;
    }
    const byteOffset = bufferOffset;
    bytes.forEach((byte) => buffers.push(byte));
    bufferOffset += bytes.byteLength;
    bufferViews.push({ buffer: 0, byteOffset, byteLength: bytes.byteLength });
    accessors.push({ bufferView: bufferViews.length - 1, componentType, count, type, min, max });
    return index;
  }

  meshes.forEach((mesh) => {
    const positionAccessor = addAccessor(mesh.positions, 5126, "VEC3");
    const indexAccessor = addAccessor(mesh.indices, 5125, "SCALAR");
    gltfMeshes.push({
      name: mesh.name,
      primitives: [{
        attributes: { POSITION: positionAccessor },
        indices: indexAccessor,
        material: mesh.materialIndex
      }]
    });
    nodes.push({ name: mesh.name, mesh: gltfMeshes.length - 1 });
  });

  const binary = new Uint8Array(buffers);
  let binaryText = "";
  binary.forEach((byte) => { binaryText += String.fromCharCode(byte); });
  return {
    asset: {
      version: "2.0",
      generator: "s3g-mc IR Sketch"
    },
    scene: 0,
    scenes: [{ nodes: nodes.map((_, index) => index) }],
    nodes,
    meshes: gltfMeshes,
    materials: [
      { name: "Main room cyan", pbrMetallicRoughness: { baseColorFactor: [0.2, 0.75, 0.85, 0.42], metallicFactor: 0, roughnessFactor: 0.92 }, alphaMode: "BLEND", doubleSided: true },
      { name: "Chambers green", pbrMetallicRoughness: { baseColorFactor: [0.32, 0.78, 0.52, 0.48], metallicFactor: 0, roughnessFactor: 0.86 }, alphaMode: "BLEND", doubleSided: true },
      { name: "Field center", pbrMetallicRoughness: { baseColorFactor: [0.9, 0.9, 0.9, 1], metallicFactor: 0, roughnessFactor: 0.5 } },
      { name: "IR groups", pbrMetallicRoughness: { baseColorFactor: [0.93, 0.62, 0.22, 1], metallicFactor: 0, roughnessFactor: 0.5 } },
      { name: "Opening frames", pbrMetallicRoughness: { baseColorFactor: [0.78, 0.96, 0.92, 0.28], metallicFactor: 0, roughnessFactor: 0.96 }, alphaMode: "BLEND", doubleSided: true }
    ],
    accessors,
    bufferViews,
    buffers: [{
      uri: `data:application/octet-stream;base64,${btoa(binaryText)}`,
      byteLength: binary.byteLength
    }],
    extras: {
      target_process: "3OAFX Synthetic Ambisonic IR Bank",
      room_sketch: exportObject(s)
    }
  };
}

function downloadGltf() {
  const blob = new Blob([JSON.stringify(buildGltf(), null, 2)], { type: "model/gltf+json" });
  const link = document.createElement("a");
  link.download = "s3g_ir_room_sketch.gltf";
  link.href = URL.createObjectURL(blob);
  link.click();
  URL.revokeObjectURL(link.href);
}

function drawGltfPreview() {
  const s = settings();
  const dpr = window.devicePixelRatio || 1;
  const rect = gltfCanvas.getBoundingClientRect();
  gltfCanvas.width = Math.max(640, Math.round(rect.width * dpr));
  gltfCanvas.height = Math.max(420, Math.round(rect.height * dpr));
  gltfCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
  const w = gltfCanvas.width / dpr;
  const h = gltfCanvas.height / dpr;
  gltfCtx.fillStyle = "#050607";
  gltfCtx.fillRect(0, 0, w, h);

  const meshes = buildGltfMeshes(s);
  const allPoints = [];
  meshes.forEach((mesh) => {
    for (let i = 0; i < mesh.positions.length; i += 3) {
      allPoints.push({ x: mesh.positions[i], y: mesh.positions[i + 1], z: mesh.positions[i + 2] });
    }
  });
  if (!allPoints.length) return;
  const min = {
    x: Math.min(...allPoints.map((p) => p.x)),
    y: Math.min(...allPoints.map((p) => p.y)),
    z: Math.min(...allPoints.map((p) => p.z))
  };
  const max = {
    x: Math.max(...allPoints.map((p) => p.x)),
    y: Math.max(...allPoints.map((p) => p.y)),
    z: Math.max(...allPoints.map((p) => p.z))
  };
  const center = {
    x: (min.x + max.x) * 0.5,
    y: (min.y + max.y) * 0.5,
    z: (min.z + max.z) * 0.5,
    planY: -(min.z + max.z) * 0.5
  };
  const az = state.gltfCamera.azimuth * Math.PI / 180;
  const el = state.gltfCamera.elevation * Math.PI / 180;
  const cosA = Math.cos(az);
  const sinA = Math.sin(az);
  const cosE = Math.cos(el);
  const sinE = Math.sin(el);
  const diag = Math.sqrt((max.x - min.x) ** 2 + (max.y - min.y) ** 2 + (max.z - min.z) ** 2);
  const scale = Math.min(w, h) * 0.72 * state.gltfCamera.zoom / Math.max(1, diag);
  const project = (point) => {
    const x = point.x - center.x;
    const y = -point.z - center.planY;
    const z = point.y - center.y;
    const rx = x * cosA - y * sinA;
    const ry = x * sinA + y * cosA;
    const sy = ry * sinE - z * cosE;
    return {
      x: w * 0.5 + rx * scale,
      y: h * 0.54 + sy * scale,
      depth: ry * cosE + z * sinE
    };
  };
  const fills = [
    "rgba(90,168,199,0.20)",
    "rgba(120,190,150,0.24)",
    "rgba(230,230,230,0.88)",
    "rgba(216,162,74,0.92)",
    "rgba(200,245,235,0.70)"
  ];
  const strokes = [
    "rgba(90,168,199,0)",
    "rgba(120,190,150,0)",
    "rgba(245,245,245,0.95)",
    "rgba(216,162,74,0.95)",
    "rgba(200,245,235,0.92)"
  ];
  const triangles = [];
  meshes.forEach((mesh) => {
    for (let i = 0; i < mesh.indices.length; i += 3) {
      const pts = [0, 1, 2].map((offset) => {
        const idx = mesh.indices[i + offset] * 3;
        return project({
          x: mesh.positions[idx],
          y: mesh.positions[idx + 1],
          z: mesh.positions[idx + 2]
        });
      });
      triangles.push({
        pts,
        materialIndex: mesh.materialIndex,
        depth: (pts[0].depth + pts[1].depth + pts[2].depth) / 3
      });
    }
  });
  triangles.sort((a, b) => a.depth - b.depth);
  triangles.forEach((tri) => {
    if (tri.materialIndex === 4) return;
    gltfCtx.beginPath();
    gltfCtx.moveTo(tri.pts[0].x, tri.pts[0].y);
    gltfCtx.lineTo(tri.pts[1].x, tri.pts[1].y);
    gltfCtx.lineTo(tri.pts[2].x, tri.pts[2].y);
    gltfCtx.closePath();
    gltfCtx.fillStyle = fills[tri.materialIndex] || fills[0];
    gltfCtx.strokeStyle = strokes[tri.materialIndex] || strokes[0];
    gltfCtx.lineWidth = tri.materialIndex === 2 || tri.materialIndex === 3 ? 1.4 : 0;
    gltfCtx.fill();
    if (tri.materialIndex === 2 || tri.materialIndex === 3) gltfCtx.stroke();
  });
  const outlineStyles = [
    { stroke: "rgba(90,168,199,0.92)", width: 1.45 },
    { stroke: "rgba(120,190,150,0.78)", width: 1.2 },
    null,
    null,
    null
  ];
  meshes.forEach((mesh) => {
    const style = outlineStyles[mesh.materialIndex];
    if (!style) return;
    if (mesh.positions.length < 18) return;
    const vertexCount = mesh.positions.length / 3;
    const half = vertexCount / 2;
    if (Math.floor(half) !== half || half < 3) return;
    const bottom = [];
    const top = [];
    for (let i = 0; i < half; i += 1) {
      const bi = i * 3;
      const ti = (i + half) * 3;
      bottom.push(project({ x: mesh.positions[bi], y: mesh.positions[bi + 1], z: mesh.positions[bi + 2] }));
      top.push(project({ x: mesh.positions[ti], y: mesh.positions[ti + 1], z: mesh.positions[ti + 2] }));
    }
    gltfCtx.strokeStyle = style.stroke;
    gltfCtx.lineWidth = style.width;
    gltfCtx.beginPath();
    top.forEach((p, index) => index === 0 ? gltfCtx.moveTo(p.x, p.y) : gltfCtx.lineTo(p.x, p.y));
    gltfCtx.closePath();
    bottom.forEach((p, index) => index === 0 ? gltfCtx.moveTo(p.x, p.y) : gltfCtx.lineTo(p.x, p.y));
    gltfCtx.closePath();
    for (let i = 0; i < half; i += 1) {
      gltfCtx.moveTo(bottom[i].x, bottom[i].y);
      gltfCtx.lineTo(top[i].x, top[i].y);
    }
    gltfCtx.stroke();
  });
  meshes.filter((mesh) => mesh.portalFrame && mesh.portalSegment).forEach((mesh) => {
    const segment = mesh.portalSegment;
    const chamberPortal = segment.kind === "chamber";
    const nestedPortal = chamberPortal && Number(segment.level || 0) > 0;
    const p1b = project({ x: segment.x1, y: 0.02, z: -segment.y1 });
    const p2b = project({ x: segment.x2, y: 0.02, z: -segment.y2 });
    const p1t = project({ x: segment.x1, y: segment.height, z: -segment.y1 });
    const p2t = project({ x: segment.x2, y: segment.height, z: -segment.y2 });
    gltfCtx.save();
    gltfCtx.globalCompositeOperation = "source-over";
    gltfCtx.strokeStyle = "rgba(3,5,6,0.82)";
    gltfCtx.lineWidth = 5.2;
    gltfCtx.beginPath();
    gltfCtx.moveTo(p1b.x, p1b.y);
    gltfCtx.lineTo(p1t.x, p1t.y);
    gltfCtx.moveTo(p2b.x, p2b.y);
    gltfCtx.lineTo(p2t.x, p2t.y);
    gltfCtx.moveTo(p1t.x, p1t.y);
    gltfCtx.lineTo(p2t.x, p2t.y);
    gltfCtx.stroke();
    gltfCtx.strokeStyle = nestedPortal
      ? "rgba(255,202,126,0.98)"
      : chamberPortal
        ? "rgba(184,255,202,0.98)"
        : "rgba(220,255,248,0.98)";
    gltfCtx.lineWidth = nestedPortal ? 3.0 : chamberPortal ? 2.6 : 2.2;
    gltfCtx.beginPath();
    gltfCtx.moveTo(p1b.x, p1b.y);
    gltfCtx.lineTo(p1t.x, p1t.y);
    gltfCtx.moveTo(p2b.x, p2b.y);
    gltfCtx.lineTo(p2t.x, p2t.y);
    gltfCtx.moveTo(p1t.x, p1t.y);
    gltfCtx.lineTo(p2t.x, p2t.y);
    gltfCtx.stroke();
    if (chamberPortal) {
      gltfCtx.setLineDash(nestedPortal ? [3, 3] : [5, 4]);
      gltfCtx.strokeStyle = nestedPortal ? "rgba(255,202,126,0.95)" : "rgba(120,190,150,0.95)";
      gltfCtx.lineWidth = nestedPortal ? 1.9 : 1.5;
      gltfCtx.beginPath();
      gltfCtx.moveTo(p1b.x, p1b.y);
      gltfCtx.lineTo(p2b.x, p2b.y);
      if (nestedPortal) {
        gltfCtx.moveTo(p1t.x, p1t.y);
        gltfCtx.lineTo(p2t.x, p2t.y);
      }
      gltfCtx.stroke();
      gltfCtx.setLineDash([]);
    }
    gltfCtx.restore();
  });
  gltfCtx.fillStyle = "#aeb7bd";
  gltfCtx.font = "11px Menlo, monospace";
  gltfCtx.fillText(`glTF preview  ${round(s.room_x, 1)} x ${round(s.room_y, 1)} x ${round(s.room_z, 1)} m  camera ${round(state.gltfCamera.azimuth)}/${round(state.gltfCamera.elevation)}  zoom ${round(state.gltfCamera.zoom, 2)}x`, 14, 22);
}

function syncGltfCameraControls() {
  $("gltfCameraAz").value = round(state.gltfCamera.azimuth, 1);
  $("gltfCameraEl").value = round(state.gltfCamera.elevation, 1);
  $("gltfCameraZoom").value = round(state.gltfCamera.zoom, 2);
  updateRangeFill($("gltfCameraAz"));
  updateRangeFill($("gltfCameraEl"));
  updateRangeFill($("gltfCameraZoom"));
}

function setGltfCamera(azimuth, elevation, zoom) {
  state.gltfCamera.azimuth = wrapDegrees(azimuth);
  state.gltfCamera.elevation = clamp(elevation, -80, 80);
  state.gltfCamera.zoom = clamp(zoom, 0.45, 3.2);
  syncGltfCameraControls();
  drawGltfPreview();
}

function openGltfModal() {
  state.gltfCamera = {
    azimuth: Number(controls.cameraAz.value),
    elevation: Number(controls.cameraEl.value),
    zoom: Number(controls.cameraZoom.value)
  };
  syncGltfCameraControls();
  $("gltfModal").classList.add("open");
  $("gltfModal").setAttribute("aria-hidden", "false");
  drawGltfPreview();
}

function closeGltfModal() {
  $("gltfModal").classList.remove("open");
  $("gltfModal").setAttribute("aria-hidden", "true");
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
  controls.spaceShape.value = "side_chamber";
  controls.roomShape.value = "rect";
  controls.topologyBias.value = 0.35;
  controls.chamberShape.value = "rect";
  controls.chamberSide.value = "back";
  controls.chamberMaterial.value = "stone";
  controls.chamberMaterialMode.value = "nested";
  controls.chamberWidth.value = 4.5;
  controls.chamberDepth.value = 3.8;
  controls.chamberCount.value = 2;
  controls.chamberPosition.value = 0.5;
  controls.nestedChambers.value = 1;
  controls.openingWidth.value = 0.42;
  controls.chamberCoupling.value = 0.48;
  controls.chamberMaterialMix.value = 0.65;
  controls.outsideOpening.checked = true;
  controls.outsideOpeningSide.value = "back";
  controls.outsideOpeningCount.value = 2;
  controls.outsideOpeningPosition.value = 0.76;
  controls.outsideOpeningSpread.value = 0.42;
  controls.outsideOpeningWidth.value = 0.22;
  controls.outsideLeak.value = 0.28;
  controls.fieldX.value = 0;
  controls.fieldY.value = 0;
  controls.sourceAz.value = 0;
  controls.sourceEl.value = 0;
  controls.sourceDistance.value = 3.2;
  controls.spreadDeg.value = 45;
  controls.groupVariation.value = 0.35;
  controls.surfaceContrast.value = 0.45;
  controls.distanceVariation.value = 0.18;
  controls.order.value = 3;
  controls.directionSet.value = "auto";
  controls.duration.value = 3;
  controls.preDelay.value = 12;
  controls.earlyReflections.value = 18;
  controls.cameraAz.value = -38;
  controls.cameraEl.value = 32;
  controls.cameraZoom.value = 1;
  state.selectedDirection = 0;
  applyMaterial();
}

function randomize() {
  const presets = Object.keys(materials);
  const bias = clamp(Number(controls.topologyBias.value || 0.35), 0, 1);
  const skew = Math.pow(bias, 1.35);
  const range = (min, max) => min + Math.random() * (max - min);
  const rangeBiased = (min, max) => min + (Math.random() * 0.55 + skew * 0.45) * (max - min);

  controls.materialPreset.value = choice(presets);
  controls.roomX.value = round(6 + Math.random() * 26, 1);
  controls.roomY.value = round(4 + Math.random() * 18, 1);
  controls.roomZ.value = round(2.8 + Math.random() * 8, 1);
  controls.spaceShape.value = Math.random() < 0.35 + bias * 0.62 ? "side_chamber" : "shoebox";
  controls.roomShape.value = chooseByBias(
    ["rect", "rect", "trapezoid"],
    ["rect", "trapezoid", "wedge", "skew"],
    ["wedge", "skew", "diamond", "impossible", "impossible"],
    bias
  );
  controls.chamberShape.value = chooseByBias(
    ["rect", "rect", "trapezoid"],
    ["rect", "trapezoid", "wedge", "skew"],
    ["wedge", "skew", "impossible", "impossible"],
    bias
  );
  controls.chamberSide.value = chooseByBias(
    ["back", "left", "right"],
    ["front", "back", "left", "right"],
    ["front", "back", "left", "right", "all", "all"],
    bias
  );
  controls.chamberMaterial.value = choice(presets);
  controls.chamberMaterialMode.value = chooseByBias(
    ["uniform", "uniform", "alternating"],
    ["uniform", "alternating", "nested"],
    ["alternating", "nested", "palette", "palette"],
    bias
  );
  controls.chamberWidth.value = round(2 + Math.random() * Math.min(10, Number(controls.roomX.value) * 0.75), 1);
  controls.chamberDepth.value = round(1.5 + Math.random() * Math.min(8, Number(controls.roomY.value) * 0.65), 1);
  controls.chamberCount.value = Math.round(clamp(1 + Math.random() * (1.2 + bias * 2.8), 1, 4));
  controls.chamberPosition.value = round(Math.random(), 2);
  controls.nestedChambers.value = Math.round(clamp(Math.random() * (0.4 + bias * 2.4), 0, 2));
  controls.openingWidth.value = round(range(0.48 - bias * 0.32, 0.86 - bias * 0.22), 2);
  controls.chamberCoupling.value = round(rangeBiased(0.12, 0.92), 2);
  controls.chamberMaterialMix.value = round(rangeBiased(0.18, 0.98), 2);
  controls.outsideOpening.checked = Math.random() < 0.35 + bias * 0.45;
  controls.outsideOpeningSide.value = chooseByBias(
    ["front", "back", "left", "right"],
    ["front", "back", "left", "right", "all"],
    ["front", "back", "left", "right", "all", "all"],
    bias
  );
  controls.outsideOpeningCount.value = Math.round(clamp(1 + Math.random() * (1.4 + bias * 4.2), 1, 6));
  controls.outsideOpeningPosition.value = round(Math.random(), 2);
  controls.outsideOpeningSpread.value = round(range(0.12, 0.35 + bias * 0.65), 2);
  controls.outsideOpeningWidth.value = round(range(0.10, 0.24 + bias * 0.42), 2);
  controls.outsideLeak.value = round(rangeBiased(0.12, 0.88), 2);
  controls.fieldX.value = round(range(-0.22 - bias * 0.62, 0.22 + bias * 0.62), 2);
  controls.fieldY.value = round(range(-0.22 - bias * 0.62, 0.22 + bias * 0.62), 2);
  controls.sourceAz.value = 0;
  controls.sourceEl.value = 0;
  controls.sourceDistance.value = round(range(1 + bias * 0.5, 6 + bias * 7), 2);
  controls.spreadDeg.value = Math.round(range(16 + bias * 8, 52 + bias * 68));
  controls.groupVariation.value = round(rangeBiased(0.08, 0.9), 2);
  controls.surfaceContrast.value = round(rangeBiased(0.12, 0.96), 2);
  controls.distanceVariation.value = round(rangeBiased(0.03, 0.72), 2);
  controls.duration.value = round(1.5 + Math.random() * 5.5, 2);
  controls.preDelay.value = Math.round(range(2, 24 + bias * 48));
  controls.earlyReflections.value = Math.round(range(8 + bias * 4, 28 + bias * 48));
  controls.cameraAz.value = Math.round(-80 + Math.random() * 160);
  controls.cameraEl.value = Math.round(18 + Math.random() * 34);
  controls.cameraZoom.value = round(0.78 + Math.random() * 0.58, 2);
  state.selectedDirection = 0;
  state.groupMapPositions = {};
  applyMaterial();
}

Object.values(controls).forEach((control) => {
  control.addEventListener("input", () => {
    if (control.type === "range") updateRangeFill(control);
    drawRoom();
    if ($("gltfModal").classList.contains("open")) drawGltfPreview();
  });
  control.addEventListener("change", () => {
    drawRoom();
    if ($("gltfModal").classList.contains("open")) drawGltfPreview();
  });
});

controls.materialPreset.addEventListener("change", applyMaterial);

document.querySelectorAll(".collapsible > h2").forEach((heading) => {
  const section = heading.parentElement;
  heading.tabIndex = 0;
  heading.setAttribute("role", "button");
  heading.setAttribute("aria-expanded", "true");
  const toggle = () => {
    section.classList.toggle("collapsed");
    heading.setAttribute("aria-expanded", section.classList.contains("collapsed") ? "false" : "true");
  };
  heading.addEventListener("pointerdown", (event) => {
    event.preventDefault();
    toggle();
  });
  heading.addEventListener("keydown", (event) => {
    if (event.key !== "Enter" && event.key !== " ") return;
    event.preventDefault();
    toggle();
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

document.querySelectorAll("[data-camera]").forEach((button) => {
  button.addEventListener("click", () => {
    const preset = button.dataset.camera;
    if (preset === "top") {
      controls.cameraAz.value = 0;
      controls.cameraEl.value = 80;
      controls.cameraZoom.value = 1.05;
    } else if (preset === "side") {
      controls.cameraAz.value = -90;
      controls.cameraEl.value = 8;
      controls.cameraZoom.value = 1.08;
    } else if (preset === "wide") {
      controls.cameraAz.value = -38;
      controls.cameraEl.value = 28;
      controls.cameraZoom.value = 0.68;
    } else {
      controls.cameraAz.value = -38;
      controls.cameraEl.value = 32;
      controls.cameraZoom.value = 1;
    }
    updateAllRangeFills();
    state.view = "view3d";
    document.querySelectorAll("[data-view]").forEach((viewButton) => {
      viewButton.classList.toggle("active", viewButton.dataset.view === "view3d");
    });
    drawRoom();
  });
});

$("prevGroup").addEventListener("click", () => stepGroup(-1));
$("nextGroup").addEventListener("click", () => stepGroup(1));

function canvasPoint(event) {
  const rect = canvas.getBoundingClientRect();
  const scaleX = ROOM_CANVAS_W / rect.width;
  const scaleY = ROOM_CANVAS_H / rect.height;
  return {
    x: (event.clientX - rect.left) * scaleX,
    y: (event.clientY - rect.top) * scaleY
  };
}

function updateDistanceFromCanvas(point) {
  const s = settings();
  const projection = state.roomProjection;
  if (!projection) return;
  const selected = selectedDirection(s);
  const unit = unitFromAed(selected.azimuth, selected.elevation);
  const listener = roomPoints(s, selected).listener;
  const bounds = floorplanBounds(s);
  const roomX = projection.view === "side"
    ? clamp((point.x - projection.ox) / projection.scale + (projection.minX || 0), 0, s.room_x)
    : clamp((point.x - projection.ox) / projection.scale + (projection.minX || 0), bounds.minX, bounds.maxX);
  const axisY = clamp((point.y - projection.oy) / projection.scale, 0, projection.roomH);
  let distance = Number(controls.sourceDistance.value);
  if (projection.view === "side") {
    const roomZ = clamp(projection.roomH - axisY, 0, s.room_z);
    const vx = roomX - listener.x;
    const vz = roomZ - listener.z;
    const denom = unit.x * unit.x + unit.y * unit.y;
    if (denom > 0.0001) distance = (vx * unit.x + vz * unit.y) / denom;
  } else {
    const roomY = clamp(axisY + (projection.minY || 0), bounds.minY, bounds.maxY);
    const vx = roomX - listener.x;
    const vy = roomY - listener.y;
    const denom = unit.x * unit.x + unit.z * unit.z;
    if (denom > 0.0001) distance = (vx * unit.x + vy * unit.z) / denom;
  }
  const maxDistance = Number(controls.sourceDistance.max || 20);
  controls.sourceDistance.value = round(clamp(distance, Number(controls.sourceDistance.min || 0.25), maxDistance), 2);
  updateRangeFill(controls.sourceDistance);
  drawRoom();
}

function updateFieldFromCanvas(point) {
  const s = settings();
  const projection = state.roomProjection;
  if (!projection || projection.view !== "top") return;
  const bounds = floorplanBounds(s);
  const fieldWidth = Math.max(0.5, bounds.maxX - bounds.minX);
  const fieldHeight = Math.max(0.5, bounds.maxY - bounds.minY);
  const planX = clamp((point.x - projection.ox) / projection.scale + projection.minX, bounds.minX, bounds.maxX);
  const planY = clamp((point.y - projection.oy) / projection.scale + projection.minY, bounds.minY, bounds.maxY);
  const boundedPoint = closestPointInFloorplan({ x: planX, y: planY, z: s.room_z * 0.5 }, s);
  controls.fieldX.value = round(clamp((boundedPoint.x - bounds.minX) / fieldWidth - 0.5, -0.5, 0.5) * 2, 3);
  controls.fieldY.value = round(clamp((boundedPoint.y - bounds.minY) / fieldHeight - 0.5, -0.5, 0.5) * 2, 3);
  updateRangeFill(controls.fieldX);
  updateRangeFill(controls.fieldY);
  drawRoom();
}

function updateGroupMapFromCanvas(index, point) {
  const s = settings();
  const projection = state.bankProjection;
  if (!projection) return;
  const candidate = {
    x: clamp((point.x - projection.ox) / projection.scale + projection.minX, projection.minX, projection.maxX),
    y: clamp((point.y - projection.oy) / projection.scale + projection.minY, projection.minY, projection.maxY),
    z: s.room_z * 0.5
  };
  if (!pointInFloorplan(candidate, s)) return;
  state.groupMapPositions[groupPositionKey(index)] = candidate;
  drawRoom();
}

canvas.addEventListener("pointerdown", (event) => {
  const { x, y } = canvasPoint(event);
  if (state.view === "sphere") {
    const hit = state.directionHitPoints.find((point) => {
      const dx = x - point.x;
      const dy = y - point.y;
      return Math.sqrt(dx * dx + dy * dy) <= point.r;
    });
    if (hit) {
      state.selectedDirection = hit.index;
      state.drag = { mode: "group_map", index: hit.index };
      canvas.setPointerCapture(event.pointerId);
      updateGroupMapFromCanvas(hit.index, { x, y });
      drawRoom();
    }
    return;
  }
  if (state.view === "matrix") {
    const hit = state.matrixHitRows.find((row) => x >= row.x && x <= row.x + row.w && y >= row.y && y <= row.y + row.h);
    if (hit) {
      state.selectedDirection = hit.index;
      drawRoom();
    }
    return;
  }
  const roomHit = state.roomHitPoints.find((point) => {
    const dx = x - point.x;
    const dy = y - point.y;
    return Math.sqrt(dx * dx + dy * dy) <= point.r;
  });
  if (roomHit) {
    state.selectedDirection = roomHit.index;
  }
  if (state.view === "top" && state.roomProjection) {
    state.drag = { mode: "field" };
    canvas.setPointerCapture(event.pointerId);
    updateFieldFromCanvas({ x, y });
    return;
  }
  if (roomHit) {
    drawRoom();
  }
});

canvas.addEventListener("pointermove", (event) => {
  if (!state.drag) return;
  if (state.drag.mode === "distance") updateDistanceFromCanvas(canvasPoint(event));
  if (state.drag.mode === "field") updateFieldFromCanvas(canvasPoint(event));
  if (state.drag.mode === "group_map") updateGroupMapFromCanvas(state.drag.index, canvasPoint(event));
});

canvas.addEventListener("pointerup", (event) => {
  state.drag = null;
  if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
});

canvas.addEventListener("pointercancel", (event) => {
  state.drag = null;
  if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
});

window.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && $("gltfModal").classList.contains("open")) {
    closeGltfModal();
    event.preventDefault();
    return;
  }
  if (event.target && ["INPUT", "SELECT", "TEXTAREA"].includes(event.target.tagName)) return;
  if (event.key === "ArrowLeft") {
    stepGroup(-1);
    event.preventDefault();
  } else if (event.key === "ArrowRight") {
    stepGroup(1);
    event.preventDefault();
  }
});

$("reset").addEventListener("click", resetDefaults);
$("randomize").addEventListener("click", randomize);
$("exportJson").addEventListener("click", downloadJson);
$("viewGltf").addEventListener("click", openGltfModal);
$("exportGltf").addEventListener("click", downloadGltf);
$("modalExportGltf").addEventListener("click", downloadGltf);
$("closeGltf").addEventListener("click", closeGltfModal);
$("gltfCameraAz").addEventListener("input", () => setGltfCamera(Number($("gltfCameraAz").value), state.gltfCamera.elevation, state.gltfCamera.zoom));
$("gltfCameraEl").addEventListener("input", () => setGltfCamera(state.gltfCamera.azimuth, Number($("gltfCameraEl").value), state.gltfCamera.zoom));
$("gltfCameraZoom").addEventListener("input", () => setGltfCamera(state.gltfCamera.azimuth, state.gltfCamera.elevation, Number($("gltfCameraZoom").value)));
document.querySelectorAll("[data-gltf-camera]").forEach((button) => {
  button.addEventListener("click", () => {
    const preset = button.dataset.gltfCamera;
    if (preset === "top") setGltfCamera(0, 80, 1.05);
    else if (preset === "side") setGltfCamera(-90, 8, 1.08);
    else if (preset === "wide") setGltfCamera(-38, 28, 0.68);
    else setGltfCamera(-38, 32, 1);
  });
});
$("gltfModal").addEventListener("click", (event) => {
  if (event.target.id === "gltfModal") closeGltfModal();
});
gltfCanvas.addEventListener("pointerdown", (event) => {
  state.gltfDrag = {
    x: event.clientX,
    y: event.clientY,
    azimuth: state.gltfCamera.azimuth,
    elevation: state.gltfCamera.elevation
  };
  gltfCanvas.setPointerCapture(event.pointerId);
});
gltfCanvas.addEventListener("pointermove", (event) => {
  if (!state.gltfDrag) return;
  const dx = event.clientX - state.gltfDrag.x;
  const dy = event.clientY - state.gltfDrag.y;
  setGltfCamera(state.gltfDrag.azimuth + dx * 0.45, state.gltfDrag.elevation - dy * 0.35, state.gltfCamera.zoom);
});
gltfCanvas.addEventListener("pointerup", (event) => {
  state.gltfDrag = null;
  if (gltfCanvas.hasPointerCapture(event.pointerId)) gltfCanvas.releasePointerCapture(event.pointerId);
});
gltfCanvas.addEventListener("pointercancel", (event) => {
  state.gltfDrag = null;
  if (gltfCanvas.hasPointerCapture(event.pointerId)) gltfCanvas.releasePointerCapture(event.pointerId);
});
gltfCanvas.addEventListener("wheel", (event) => {
  event.preventDefault();
  const factor = event.deltaY < 0 ? 1.08 : 0.92;
  setGltfCamera(state.gltfCamera.azimuth, state.gltfCamera.elevation, state.gltfCamera.zoom * factor);
}, { passive: false });
window.addEventListener("resize", () => {
  if ($("gltfModal").classList.contains("open")) drawGltfPreview();
});

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

updateAllRangeFills();
enhanceCustomSelects();
applyMaterial();
