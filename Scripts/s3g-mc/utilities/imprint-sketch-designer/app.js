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
const STORAGE_KEY = "s3g-mc-imprint-sketch-autosave-v1";
const LEGACY_STORAGE_KEY = "s3g-mc-ir-sketch-autosave-v1";
const PROJECT_FORMAT = "s3g-imprint-sketch";
const PROJECT_VERSION = 1;
const LEGACY_PROJECT_FORMAT = "s3g-ir-room-sketch";
const LEGACY_PROJECT_VERSION = 2;
const IMPRINT_FORMAT = "s3g-ambi-imprint";
const IMPRINT_VERSION = 1;
const IMPRINT_BANDS_HZ = [125, 250, 500, 1000, 2000, 4000, 8000, 16000];
let lastAutosaveJson = "";

const controls = {
  spaceFamily: $("spaceFamily"),
  spaceSeed: $("spaceSeed"),
  roomX: $("roomX"),
  roomY: $("roomY"),
  roomZ: $("roomZ"),
  materialPreset: $("materialPreset"),
  absorption: $("absorption"),
  scattering: $("scattering"),
  tailSoften: $("tailSoften"),
  irregularity: $("irregularity"),
  surfaceRoughness: $("surfaceRoughness"),
  verticalVariation: $("verticalVariation"),
  openness: $("openness"),
  spaceShape: $("spaceShape"),
  roomShape: $("roomShape"),
  topologyBias: $("topologyBias"),
  branchFamily: $("branchFamily"),
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
  echoStructure: $("echoStructure"),
  echoProminence: $("echoProminence"),
  echoPersistence: $("echoPersistence"),
  echoRegularity: $("echoRegularity"),
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
  concrete: { absorption: 0.12, scattering: 0.32, tailSoften: 0.16, bands: [0.04, 0.05, 0.07, 0.09, 0.12, 0.17, 0.24, 0.32] },
  brick: { absorption: 0.16, scattering: 0.62, tailSoften: 0.20, bands: [0.05, 0.06, 0.08, 0.12, 0.17, 0.24, 0.33, 0.42] },
  stone: { absorption: 0.18, scattering: 0.48, tailSoften: 0.22, bands: [0.05, 0.06, 0.08, 0.11, 0.16, 0.23, 0.31, 0.40] },
  wood: { absorption: 0.30, scattering: 0.55, tailSoften: 0.36, bands: [0.22, 0.25, 0.28, 0.31, 0.35, 0.42, 0.50, 0.58] },
  metal: { absorption: 0.08, scattering: 0.18, tailSoften: 0.08, bands: [0.13, 0.10, 0.07, 0.05, 0.05, 0.07, 0.10, 0.15] },
  studio: { absorption: 0.42, scattering: 0.42, tailSoften: 0.48, bands: [0.24, 0.32, 0.42, 0.50, 0.58, 0.66, 0.73, 0.78] },
  damped: { absorption: 0.68, scattering: 0.38, tailSoften: 0.72, bands: [0.40, 0.54, 0.68, 0.78, 0.86, 0.91, 0.94, 0.96] },
  glass: { absorption: 0.20, scattering: 0.22, tailSoften: 0.12, bands: [0.26, 0.19, 0.14, 0.11, 0.10, 0.12, 0.17, 0.24] },
  fabric: { absorption: 0.74, scattering: 0.58, tailSoften: 0.82, bands: [0.24, 0.42, 0.62, 0.76, 0.86, 0.92, 0.95, 0.97] },
  water: { absorption: 0.10, scattering: 0.70, tailSoften: 0.10, bands: [0.04, 0.05, 0.06, 0.08, 0.11, 0.16, 0.24, 0.34] },
  earth: { absorption: 0.38, scattering: 0.76, tailSoften: 0.58, bands: [0.18, 0.24, 0.31, 0.39, 0.49, 0.60, 0.70, 0.78] },
  porous_rock: { absorption: 0.27, scattering: 0.84, tailSoften: 0.43, bands: [0.10, 0.14, 0.20, 0.27, 0.35, 0.45, 0.56, 0.66] },
  ice: { absorption: 0.09, scattering: 0.28, tailSoften: 0.12, bands: [0.08, 0.07, 0.06, 0.06, 0.08, 0.12, 0.19, 0.28] },
  vegetation: { absorption: 0.62, scattering: 0.88, tailSoften: 0.82, bands: [0.26, 0.39, 0.54, 0.66, 0.76, 0.85, 0.91, 0.95] }
};

const SPACE_FAMILIES = ["room", "cave", "cavern", "tunnel", "canyon", "clearing", "abstract"];

function normalizedSeed(value) {
  const seed = Math.abs(Math.trunc(Number(value) || 1)) % 10000000;
  return seed || 1;
}

function makeRng(seedValue) {
  let seed = normalizedSeed(seedValue) >>> 0;
  return () => {
    seed += 0x6d2b79f5;
    let value = seed;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

function freshSeed() {
  if (window.crypto && window.crypto.getRandomValues) {
    const values = new Uint32Array(1);
    window.crypto.getRandomValues(values);
    return values[0] % 9999999 + 1;
  }
  return Math.floor(Math.random() * 9999999) + 1;
}

function resolvedSpaceFamily(family, seed, bias = 0.35) {
  if (family !== "any") return SPACE_FAMILIES.includes(family) ? family : "room";
  const rng = makeRng(seed + Math.round(bias * 1009));
  const pool = bias < 0.28
    ? ["room", "room", "cave", "cavern", "tunnel", "clearing"]
    : bias < 0.68
      ? ["room", "cave", "cave", "cavern", "tunnel", "canyon", "clearing", "abstract"]
      : ["cave", "cavern", "tunnel", "canyon", "clearing", "abstract", "abstract", "abstract"];
  return pool[Math.floor(rng() * pool.length) % pool.length];
}

function resolvedBranchFamily(s, index, level = 0) {
  const requested = s.branch_family || "inherit";
  if (requested === "inherit") return s.space_family;
  if (SPACE_FAMILIES.includes(requested)) return requested;
  if (requested !== "mixed") return s.space_family;

  const related = {
    room: ["room", "cave", "tunnel", "clearing"],
    cave: ["cave", "cavern", "tunnel", "room"],
    cavern: ["cavern", "cave", "tunnel", "canyon"],
    tunnel: ["tunnel", "cave", "room", "canyon"],
    canyon: ["canyon", "cave", "clearing", "tunnel"],
    clearing: ["clearing", "room", "canyon", "cave"],
    abstract: SPACE_FAMILIES
  };
  const primary = SPACE_FAMILIES.includes(s.space_family) ? s.space_family : "room";
  const bias = clamp(Number(s.topology_bias || 0), 0, 1);
  const pool = bias < 0.28
    ? [primary, primary, ...(related[primary] || SPACE_FAMILIES)]
    : bias < 0.68
      ? [...(related[primary] || SPACE_FAMILIES), "abstract"]
      : [...SPACE_FAMILIES, "abstract", "abstract"];
  const rng = makeRng(s.space_seed + (index + 1) * 7919 + (level + 1) * 104729 + Math.round(bias * 1009));
  return pool[Math.floor(rng() * pool.length) % pool.length];
}

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

function choice(items, random = Math.random) {
  return items[Math.floor(random() * items.length)];
}

function chooseByBias(low, mid, high, bias, random = Math.random) {
  if (bias < 0.28) return choice(low, random);
  if (bias < 0.68) return choice(mid, random);
  return choice(high, random);
}

function settings() {
  const roomX = Number(controls.roomX.value);
  const roomY = Number(controls.roomY.value);
  const roomZ = Number(controls.roomZ.value);
  const spaceSeed = normalizedSeed(controls.spaceSeed.value);
  const topologyBias = Number(controls.topologyBias.value);
  const requestedFamily = controls.spaceFamily.value;
  const spaceFamily = resolvedSpaceFamily(requestedFamily, spaceSeed, topologyBias);
  const baseAbsorption = Number(controls.absorption.value);
  const scattering = Number(controls.scattering.value);
  const duration = Number(controls.duration.value);
  const preDelay = Number(controls.preDelay.value);
  const openness = Number(controls.openness.value);
  const outsideOpening = controls.outsideOpening.checked;
  const outsideOpeningCount = Math.max(1, Math.round(Number(controls.outsideOpeningCount.value)));
  const outsideOpeningWidth = Number(controls.outsideOpeningWidth.value);
  const outsideLeak = Number(controls.outsideLeak.value);
  const apertureLeak = outsideOpening ? outsideOpeningWidth * outsideLeak * outsideOpeningCount : 0;
  const leakFactor = clamp(apertureLeak * (1 - openness * 0.35) + openness * 0.82, 0, 1);
  const absorption = clamp(baseAbsorption + leakFactor * 0.32, 0.03, 0.95);
  const order = Number(controls.order.value);
  const directionSet = controls.directionSet.value;
  const effectiveDirectionLayout = directionSet === "auto" ? (order === 1 ? "tetra" : "practical_8") : directionSet;
  const directionCount = activeDirections({ direction_set: directionSet, order }).length;
  const result = {
    space_family: spaceFamily,
    space_family_requested: requestedFamily,
    space_seed: spaceSeed,
    room_x: roomX,
    room_y: roomY,
    room_z: roomZ,
    material_preset: controls.materialPreset.value,
    absorption,
    scattering,
    tail_soften: Number(controls.tailSoften.value),
    irregularity: Number(controls.irregularity.value),
    surface_roughness: Number(controls.surfaceRoughness.value),
    vertical_variation: Number(controls.verticalVariation.value),
    openness,
    space_shape: controls.spaceShape.value,
    room_shape: controls.roomShape.value,
    topology_bias: topologyBias,
    branch_family: controls.branchFamily.value,
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
    echo_structure: controls.echoStructure.value,
    echo_prominence: Number(controls.echoProminence.value),
    echo_persistence: Number(controls.echoPersistence.value),
    echo_regularity: Number(controls.echoRegularity.value),
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
    acoustic_volume: 0,
    acoustic_surface: 0,
    estimated_rt60: 0,
    late_start_seconds: 0
  };
  const geometry = acousticGeometry(result);
  result.acoustic_volume = geometry.volume;
  result.acoustic_surface = geometry.surface;
  result.estimated_rt60 = localRt60(result, absorption);
  result.late_start_seconds = clamp(
    Math.min(duration * 0.92, preDelay / 1000 + 0.035 + (1 - scattering) * 0.080 - leakFactor * 0.030),
    0.008,
    duration * 0.92
  );
  return result;
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

function polygonPerimeter(poly) {
  let perimeter = 0;
  for (let index = 0; index < poly.length; index += 1) {
    const a = poly[index];
    const b = poly[(index + 1) % poly.length];
    perimeter += Math.hypot(b.x - a.x, b.y - a.y);
  }
  return perimeter;
}

function spaceCeilingHeight(s, x, y) {
  if (s.vertical_variation <= 0.0001) return s.room_z;
  const nx = x / Math.max(0.1, s.room_x);
  const ny = y / Math.max(0.1, s.room_y);
  const phase = (s.space_seed % 997) * 0.0137;
  const broad = Math.sin(nx * Math.PI * 2.1 + phase) * 0.52
    + Math.cos(ny * Math.PI * 2.7 - phase * 0.61) * 0.31
    + Math.sin((nx + ny) * Math.PI * 3.4 + phase * 1.7) * 0.17;
  const familyDepth = s.space_family === "cave" || s.space_family === "cavern" ? 0.48
    : s.space_family === "tunnel" ? 0.32
      : s.space_family === "abstract" ? 0.62
        : 0.24;
  return clamp(s.room_z * (1 + broad * s.vertical_variation * familyDepth), s.room_z * 0.38, s.room_z * 1.62);
}

function ceilingProfile(s, count = 17) {
  const bounds = floorplanBounds(s);
  const centerY = (bounds.minY + bounds.maxY) * 0.5;
  return Array.from({ length: count }, (_, index) => {
    const amount = index / Math.max(1, count - 1);
    const x = bounds.minX + (bounds.maxX - bounds.minX) * amount;
    return { x, z: spaceCeilingHeight(s, x, centerY) };
  });
}

function acousticGeometry(s) {
  const polygons = floorplanPolygons(s);
  const area = Math.max(0.25, polygons.reduce((sum, polygon) => sum + Math.abs(polygonArea(polygon)), 0));
  const perimeter = Math.max(1, polygons.reduce((sum, polygon) => sum + polygonPerimeter(polygon), 0));
  const verticalScale = 1 - s.vertical_variation * (s.space_family === "abstract" ? 0.12 : 0.06);
  const meanHeight = Math.max(0.5, s.room_z * verticalScale);
  const roughnessArea = 1 + s.surface_roughness * (0.18 + s.irregularity * 0.42);
  const ceilingArea = area * (1 - s.openness * 0.92);
  const wallArea = perimeter * meanHeight * roughnessArea * (1 - s.openness * 0.28);
  return {
    area,
    perimeter,
    meanHeight,
    volume: area * meanHeight,
    surface: Math.max(0.5, area + ceilingArea + wallArea)
  };
}

function localRt60(s, absorption) {
  const geometry = s.acoustic_volume > 0 && s.acoustic_surface > 0
    ? { volume: s.acoustic_volume, surface: s.acoustic_surface }
    : acousticGeometry(s);
  const leakAbsorption = (s.outside_opening ? s.outside_leak_factor || 0 : 0) * 0.20 + s.openness * 0.48;
  const effectiveAbsorption = clamp(absorption + leakAbsorption, 0.03, 0.98);
  const familyScale = s.space_family === "cave" ? 1.08
    : s.space_family === "cavern" ? 1.22
      : s.space_family === "tunnel" ? 1.14
        : s.space_family === "canyon" ? 0.68
          : s.space_family === "clearing" ? 0.34
            : s.space_family === "abstract" ? 0.82 + s.topology_bias * 0.72
              : 1;
  return clamp(0.161 * geometry.volume / Math.max(0.01, geometry.surface * effectiveAbsorption) * familyScale, 0.08, 8.0);
}

function resolvedAbsorptionBands(profile, materialKey) {
  const material = materials[materialKey] || materials.concrete;
  const scalarOffset = profile.absorption - material.absorption;
  const tailOffset = profile.tail_soften - material.tailSoften;
  return material.bands.map((value, index) => {
    const highWeight = index / Math.max(1, material.bands.length - 1);
    return clamp(value + scalarOffset + tailOffset * highWeight * 0.22, 0.02, 0.98);
  });
}

function localRt60Bands(s, absorptionBands) {
  return absorptionBands.map((absorption) => localRt60(s, absorption));
}

function imprintSeed(s, groupIndex) {
  const spaceHash = Math.round(s.room_x * 101 + s.room_y * 211 + s.room_z * 307 + s.space_seed * 0.73);
  const materialHash = Array.from(s.material_preset || "space").reduce((sum, char) => sum + char.charCodeAt(0), 0);
  return (spaceHash * 131 + materialHash * 17 + (groupIndex + 1) * 7919) >>> 0;
}

function roomMaterialProfile(s) {
  return {
    absorption: s.absorption,
    scattering: s.scattering,
    tail_soften: s.tail_soften
  };
}

function branchFamilyResponse(s, chamber) {
  const profiles = {
    room: { absorption: 0, scattering: 0, tail: 0, path: 1, coupling: 1, energy: 1, azimuth: 1, elevation: 1 },
    cave: { absorption: -0.03, scattering: 0.14, tail: 0.08, path: 1.10, coupling: 0.95, energy: 1, azimuth: 1.18, elevation: 1.15 },
    cavern: { absorption: -0.05, scattering: 0.10, tail: 0.15, path: 1.35, coupling: 0.82, energy: 0.92, azimuth: 1.38, elevation: 1.42 },
    tunnel: { absorption: -0.03, scattering: -0.12, tail: 0.06, path: 1.55, coupling: 1.08, energy: 1.05, azimuth: 0.34, elevation: 0.58 },
    canyon: { absorption: 0.12, scattering: 0.06, tail: -0.10, path: 1.35, coupling: 0.62, energy: 0.63, azimuth: 0.48, elevation: 1.05 },
    clearing: { absorption: 0.22, scattering: 0.12, tail: -0.16, path: 1.18, coupling: 0.42, energy: 0.42, azimuth: 1.55, elevation: 1.18 }
  };
  if (chamber.family !== "abstract") return profiles[chamber.family] || profiles.room;
  const seed = s.space_seed + (chamber.index + 1) * 431 + chamber.level * 97;
  return {
    absorption: (seededNoise(seed) - 0.45) * 0.30,
    scattering: (seededNoise(seed + 11) - 0.35) * 0.44,
    tail: (seededNoise(seed + 23) - 0.5) * 0.40,
    path: 0.72 + seededNoise(seed + 31) * 1.18,
    coupling: 0.48 + seededNoise(seed + 43) * 0.82,
    energy: 0.52 + seededNoise(seed + 59) * 0.72,
    azimuth: 0.38 + seededNoise(seed + 67) * 1.62,
    elevation: 0.45 + seededNoise(seed + 79) * 1.50
  };
}

function branchHeightRatio(s, chamber) {
  const base = {
    room: 0.72,
    cave: 0.66,
    cavern: 1.02,
    tunnel: 0.52,
    canyon: 1.10,
    clearing: 0.34
  }[chamber.family];
  if (base !== undefined) return clamp(base + chamber.level * 0.05, 0.28, 1.16);
  const variation = seededNoise(s.space_seed + (chamber.index + 1) * 271 + chamber.level * 41);
  return clamp(0.42 + variation * 0.72 + chamber.level * 0.04, 0.30, 1.18);
}

function branchFamilyLabel(family) {
  return {
    room: "arch",
    clearing: "clear",
    abstract: "abstr"
  }[family] || family;
}

function chamberMaterialProfile(s, chamber) {
  const base = roomMaterialProfile(s);
  const palette = ["concrete", "brick", "stone", "wood", "metal", "glass", "fabric", "water", "earth", "porous_rock", "ice", "vegetation"];
  let materialKey = s.chamber_material;
  if (s.chamber_material_mode === "alternating" && chamber.index % 2 === 1) materialKey = "inherit";
  if (s.chamber_material_mode === "nested" && chamber.level > 0) materialKey = palette[(palette.indexOf(s.chamber_material) + chamber.level + 2 + palette.length) % palette.length];
  if (s.chamber_material_mode === "palette") materialKey = palette[Math.floor(seededNoise((chamber.index + 1) * 61) * palette.length) % palette.length];
  const target = materialKey === "inherit" ? base : (materials[materialKey] || base);
  const mix = clamp(s.chamber_material_mix, 0, 1);
  const seed = (chamber.index + 1) * 137 + chamber.level * 19;
  const variation = 0.08 + s.group_variation * 0.14;
  const targetTail = target.tailSoften === undefined ? target.tail_soften : target.tailSoften;
  const family = branchFamilyResponse(s, chamber);
  return {
    material_key: materialKey,
    family: chamber.family,
    absorption: clamp(base.absorption * (1 - mix) + target.absorption * mix + (seededNoise(seed) - 0.5) * variation + family.absorption, 0.03, 0.95),
    scattering: clamp(base.scattering * (1 - mix) + target.scattering * mix + (seededNoise(seed + 7) - 0.5) * variation + family.scattering, 0, 1),
    tail_soften: clamp(base.tail_soften * (1 - mix) + targetTail * mix + (seededNoise(seed + 13) - 0.5) * variation + family.tail, 0, 1)
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

function radialSpacePolygon(s, family) {
  const count = family === "abstract" ? 18
    : family === "cavern" ? 20
      : family === "clearing" ? 18
        : 16;
  const centerX = s.room_x * 0.5;
  const centerY = s.room_y * 0.5;
  const radiusX = s.room_x * 0.48;
  const radiusY = s.room_y * 0.48;
  const phase = seededNoise(s.space_seed * 0.73 + 19) * Math.PI * 2;
  const familyIrregularity = family === "abstract"
    ? clamp(0.48 + s.irregularity * 0.52 + s.topology_bias * 0.18, 0, 1)
    : family === "cavern"
      ? s.irregularity * 0.72
      : family === "clearing"
        ? s.irregularity * 0.58
        : s.irregularity;
  return Array.from({ length: count }, (_, index) => {
    const angle = -Math.PI * 0.5 + index / count * Math.PI * 2;
    const previous = seededNoise(s.space_seed + ((index + count - 1) % count) * 43 + 11);
    const current = seededNoise(s.space_seed + index * 43 + 11);
    const next = seededNoise(s.space_seed + ((index + 1) % count) * 43 + 11);
    const smoothNoise = previous * 0.22 + current * 0.56 + next * 0.22;
    const lobes = Math.sin(angle * (family === "abstract" ? 5 : 3) + phase) * 0.5
      + Math.sin(angle * 2 - phase * 0.37) * 0.22;
    const minimum = family === "abstract" ? 0.30 : 0.58;
    const radius = clamp(0.82 + (smoothNoise - 0.5) * familyIrregularity * 0.78 + lobes * familyIrregularity * 0.34, minimum, 1.04);
    return {
      x: clamp(centerX + Math.cos(angle) * radiusX * radius, 0, s.room_x),
      y: clamp(centerY + Math.sin(angle) * radiusY * radius, 0, s.room_y)
    };
  });
}

function passageSpacePolygon(s, family) {
  const segments = family === "canyon" ? 12 : 10;
  const left = [];
  const right = [];
  const phase = seededNoise(s.space_seed + 71) * Math.PI * 2;
  const baseWidth = s.room_x * (family === "canyon" ? 0.58 : 0.34);
  const bend = s.room_x * s.irregularity * (family === "canyon" ? 0.20 : 0.28);
  for (let index = 0; index < segments; index += 1) {
    const amount = index / Math.max(1, segments - 1);
    const y = s.room_y * amount;
    const noise = seededNoise(s.space_seed + index * 67 + 29) - 0.5;
    const center = s.room_x * 0.5
      + Math.sin(amount * Math.PI * (2.1 + s.topology_bias * 1.8) + phase) * bend
      + noise * bend * 0.46;
    const widthNoise = 0.72 + seededNoise(s.space_seed + index * 79 + 7) * 0.56;
    const width = baseWidth * widthNoise * (1 + s.irregularity * 0.32);
    left.push({ x: clamp(center - width * 0.5, 0, s.room_x), y });
    right.push({ x: clamp(center + width * 0.5, 0, s.room_x), y });
  }
  return [...left, ...right.reverse()];
}

function perturbedRoomPolygon(s) {
  const polygon = polygonForBox(0, 0, s.room_x, s.room_y, s.room_shape);
  if (s.irregularity <= 0.001) return polygon;
  const center = polygonCentroid(polygon);
  return polygon.map((point, index) => {
    const amount = (seededNoise(s.space_seed + index * 59 + 5) - 0.5) * s.irregularity * 0.20;
    return {
      x: clamp(point.x + (point.x - center.x) * amount, -s.room_x * 0.12, s.room_x * 1.12),
      y: clamp(point.y + (point.y - center.y) * amount, -s.room_y * 0.12, s.room_y * 1.12)
    };
  });
}

function roomPolygon(s) {
  if (s.space_family === "tunnel" || s.space_family === "canyon") return passageSpacePolygon(s, s.space_family);
  if (["cave", "cavern", "clearing", "abstract"].includes(s.space_family)) return radialSpacePolygon(s, s.space_family);
  return perturbedRoomPolygon(s);
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

function radialBranchLocalGeometry(s, alongStart, alongWidth, outwardDepth, family, index, level) {
  const segments = family === "cavern" ? 14 : family === "abstract" ? 12 : family === "clearing" ? 11 : 10;
  const widthScale = family === "cavern" ? 1.18 : family === "clearing" ? 1.10 : 1;
  const depthScale = family === "cavern" ? 1.10 : family === "clearing" ? 0.84 : 1;
  const roughness = family === "abstract"
    ? clamp(0.46 + s.irregularity * 0.48 + s.topology_bias * 0.20, 0, 1)
    : family === "clearing"
      ? s.irregularity * 0.46
      : family === "cavern"
        ? s.irregularity * 0.68
        : s.irregularity * 0.82;
  const center = alongStart + alongWidth * 0.5;
  const seed = s.space_seed + (index + 1) * 3571 + (level + 1) * 101;
  const phase = seededNoise(seed + 17) * Math.PI * 2;
  const radialPoint = (amount) => {
    const angle = amount * Math.PI;
    const sample = amount * segments;
    const sampleIndex = Math.round(sample);
    const previous = seededNoise(seed + (sampleIndex - 1) * 47 + 31);
    const current = seededNoise(seed + sampleIndex * 47 + 31);
    const next = seededNoise(seed + (sampleIndex + 1) * 47 + 31);
    const smoothNoise = previous * 0.22 + current * 0.56 + next * 0.22;
    const radial = clamp(0.92 + (smoothNoise - 0.5) * roughness * 0.54, 0.68, 1.16);
    const lateralFold = Math.sin(angle * 2 + phase) * alongWidth * roughness * (family === "abstract" ? 0.075 : 0.035);
    return {
      x: center + Math.cos(angle) * alongWidth * 0.5 * widthScale * radial + lateralFold * Math.sin(angle),
      y: Math.max(0, Math.sin(angle) * outwardDepth * depthScale * radial)
    };
  };
  const poly = [
    { x: alongStart, y: 0 },
    { x: alongStart + alongWidth, y: 0 }
  ];
  for (let pointIndex = 1; pointIndex < segments; pointIndex += 1) {
    poly.push(radialPoint(pointIndex / segments));
  }
  return {
    poly,
    outerA: radialPoint(0.58),
    outerB: radialPoint(0.42)
  };
}

function passageBranchLocalGeometry(s, alongStart, alongWidth, outwardDepth, family, index, level) {
  const segments = family === "canyon" ? 8 : 7;
  const left = [];
  const right = [];
  const seed = s.space_seed + (index + 1) * 6173 + (level + 1) * 149;
  const phase = seededNoise(seed + 13) * Math.PI * 2;
  const bend = (family === "canyon" ? 0.18 : 0.24) * (0.30 + s.irregularity * 0.70);
  for (let pointIndex = 0; pointIndex < segments; pointIndex += 1) {
    const amount = pointIndex / Math.max(1, segments - 1);
    const noise = seededNoise(seed + pointIndex * 71 + 23) - 0.5;
    const drift = pointIndex === 0 ? 0
      : (Math.sin(amount * Math.PI * (1.05 + s.topology_bias * 0.75) + phase) - Math.sin(phase)) * alongWidth * bend * amount;
    const center = alongStart + alongWidth * 0.5 + drift;
    const widthScale = pointIndex === 0 ? 1
      : family === "canyon"
        ? 0.92 + amount * 0.26 + noise * 0.22
        : 0.68 + (1 - amount) * 0.18 + noise * 0.16;
    const width = Math.max(alongWidth * 0.34, alongWidth * widthScale);
    const y = outwardDepth * amount;
    left.push({ x: center - width * 0.5, y });
    right.push({ x: center + width * 0.5, y });
  }
  return {
    poly: [...left, ...right.slice().reverse()],
    outerA: left[left.length - 1],
    outerB: right[right.length - 1]
  };
}

function branchLocalGeometry(s, alongStart, alongWidth, outwardDepth, family, index, level) {
  if (family === "tunnel" || family === "canyon") {
    return passageBranchLocalGeometry(s, alongStart, alongWidth, outwardDepth, family, index, level);
  }
  if (["cave", "cavern", "clearing", "abstract"].includes(family)) {
    return radialBranchLocalGeometry(s, alongStart, alongWidth, outwardDepth, family, index, level);
  }
  return {
    poly: chamberLocalPolygon(alongStart, alongWidth, outwardDepth, s.chamber_shape),
    outerA: { x: alongStart, y: outwardDepth },
    outerB: { x: alongStart + alongWidth, y: outwardDepth }
  };
}

function transformLocalGeometry(edge, geometry) {
  return {
    poly: geometry.poly.map((point) => mapLocal(edge, point.x, point.y)),
    outerA: mapLocal(edge, geometry.outerA.x, geometry.outerA.y),
    outerB: mapLocal(edge, geometry.outerB.x, geometry.outerB.y)
  };
}

function boundsFromPoly(poly) {
  return polygonBounds(poly);
}

function makeEdgeChamber(s, side, edge, alongStart, alongWidth, outwardDepth, opening, level, parent, index) {
  const family = resolvedBranchFamily(s, index, level);
  const geometry = transformLocalGeometry(
    edge,
    branchLocalGeometry(s, alongStart, alongWidth, outwardDepth, family, index, level)
  );
  const poly = geometry.poly;
  const bounds = boundsFromPoly(poly);
  const openingStart = alongStart + alongWidth * 0.5 - opening * 0.5;
  const openA = mapLocal(edge, openingStart, 0);
  const openB = mapLocal(edge, openingStart + opening, 0);
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
    outerA: geometry.outerA,
    outerB: geometry.outerB,
    edgeOutward: edge.outward,
    poly,
    side,
    level,
    parent,
    index,
    family,
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
  const x = (bounds.minX + bounds.maxX) * 0.5;
  const y = (bounds.minY + bounds.maxY) * 0.5;
  return {
    x,
    y,
    z: spaceCeilingHeight(s, x, y) * 0.5
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
  listenerCandidate.z = spaceCeilingHeight(s, listenerCandidate.x, listenerCandidate.y) * 0.5;
  const listener = closestPointInFloorplan(listenerCandidate, s);
  const unit = unitFromAed(dir.azimuth, dir.elevation);
  const maxDist = Math.min(profile.source_distance, Math.min(fieldWidth, fieldHeight, s.room_z) * 0.48);
  const sourceX = clamp(listener.x + unit.x * maxDist, bounds.minX + 0.05, bounds.maxX - 0.05);
  const sourceY = clamp(listener.y + unit.z * maxDist, bounds.minY + 0.05, bounds.maxY - 0.05);
  const sourceCeiling = spaceCeilingHeight(s, sourceX, sourceY);
  const sourceCandidate = {
    x: sourceX,
    y: sourceY,
    z: clamp(listener.z + unit.y * maxDist, 0.05, sourceCeiling - 0.05)
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
  const echoEnergy = events.filter((event) => event.type === "echo").reduce((sum, event) => sum + event.amp * event.amp, 0);
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
    chamber_energy: chamberEnergy,
    echo_energy: echoEnergy
  };
}

function reflectedPointAcrossEdge(point, a, b) {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const lengthSq = Math.max(1e-9, dx * dx + dy * dy);
  const amount = ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSq;
  const projection = { x: a.x + amount * dx, y: a.y + amount * dy };
  return {
    x: projection.x * 2 - point.x,
    y: projection.y * 2 - point.y,
    z: point.z
  };
}

function boundaryImageSources(s, source, listener) {
  const candidates = [];
  floorplanPolygons(s).forEach((polygon, polygonIndex) => {
    polygon.forEach((point, edgeIndex) => {
      const next = polygon[(edgeIndex + 1) % polygon.length];
      const image = reflectedPointAcrossEdge(source, point, next);
      const distance = Math.hypot(image.x - listener.x, image.y - listener.y, image.z - listener.z);
      candidates.push({
        pos: image,
        wall: polygonIndex === 0 ? `S${edgeIndex + 1}` : `B${polygonIndex}.${edgeIndex + 1}`,
        distance,
        surfaceGain: 1 - s.surface_roughness * 0.24
      });
    });
  });
  candidates.push({
    pos: { x: source.x, y: source.y, z: -source.z },
    wall: "D",
    distance: Math.hypot(source.x - listener.x, source.y - listener.y, -source.z - listener.z),
    surfaceGain: 1 - s.surface_roughness * 0.12
  });
  if (s.openness < 0.985) {
    const ceiling = spaceCeilingHeight(s, source.x, source.y);
    candidates.push({
      pos: { x: source.x, y: source.y, z: 2 * ceiling - source.z },
      wall: "U",
      distance: Math.hypot(source.x - listener.x, source.y - listener.y, 2 * ceiling - source.z - listener.z),
      surfaceGain: Math.pow(1 - s.openness, 0.72) * (1 - s.surface_roughness * 0.18)
    });
  }
  return candidates.sort((a, b) => a.distance - b.distance);
}

function pointDistance3(a, b) {
  return Math.hypot(a.x - b.x, a.y - b.y, (a.z || 0) - (b.z || 0));
}

function echoDirection(listener, point) {
  const dx = point.x - listener.x;
  const dy = point.y - listener.y;
  const dz = (point.z || 0) - (listener.z || 0);
  const distance = Math.max(0.001, Math.hypot(dx, dy, dz));
  return {
    az: wrapDegrees(Math.atan2(dx, dy) * 180 / Math.PI),
    el: clamp(Math.asin(clamp(dz / distance, -1, 1)) * 180 / Math.PI, -89, 89)
  };
}

function primaryAxisEchoPath(s, listener, source, structure) {
  const polygon = roomPolygon(s);
  const mids = polygon.map((point, index) => {
    const next = polygon[(index + 1) % polygon.length];
    return { x: (point.x + next.x) * 0.5, y: (point.y + next.y) * 0.5 };
  });
  const xs = polygon.map((point) => point.x);
  const ys = polygon.map((point) => point.y);
  const xSpan = Math.max(...xs) - Math.min(...xs);
  const ySpan = Math.max(...ys) - Math.min(...ys);
  const useX = structure === "flutter" ? xSpan <= ySpan : xSpan >= ySpan;
  const sorted = mids.slice().sort((a, b) => (useX ? a.x - b.x : a.y - b.y));
  const z = clamp(listener.z, 0.1, Math.max(0.1, s.room_z * 0.92));
  const first = { ...sorted[0], z };
  const second = { ...sorted[sorted.length - 1], z };
  const intervalDistance = Math.max(0.5, pointDistance3(first, second));
  return {
    id: 1,
    structure,
    points: [first, second],
    directionPoints: [first, second],
    closed: false,
    intervalDistance,
    baseDistance: pointDistance3(source, first) + pointDistance3(first, listener),
    material: s.material_preset,
    absorption: s.absorption,
    coupling: 1,
    strength: structure === "flutter" ? 1.08 : 0.92,
    chamberIndex: null,
    branchFamily: null
  };
}

function circulatingEchoPath(s, listener, source) {
  const polygon = roomPolygon(s);
  const anchorCount = Math.min(8, Math.max(4, Math.round(polygon.length / 2.5)));
  const z = clamp(listener.z, 0.1, Math.max(0.1, s.room_z * 0.86));
  const anchors = Array.from({ length: anchorCount }, (_, index) => {
    const point = polygon[Math.floor(index * polygon.length / anchorCount) % polygon.length];
    return { x: point.x, y: point.y, z };
  });
  const perimeter = anchors.reduce((sum, point, index) => sum + pointDistance3(point, anchors[(index + 1) % anchors.length]), 0);
  return {
    id: 1,
    structure: "circulating",
    points: anchors,
    directionPoints: anchors,
    closed: true,
    intervalDistance: Math.max(0.5, perimeter / anchors.length),
    baseDistance: pointDistance3(source, anchors[0]) + pointDistance3(anchors[0], listener),
    material: s.material_preset,
    absorption: s.absorption,
    coupling: 1,
    strength: 0.82,
    chamberIndex: null,
    branchFamily: null
  };
}

function coupledEchoPaths(s, dir, listener, source) {
  const chambers = chamberGeometries(s) || [];
  if (!chambers.length) return [];
  const direction = unitFromAed(dir.azimuth, dir.elevation);
  const ranked = chambers.map((chamber) => {
    const outward = chamberOutwardVector(chamber.side);
    const alignment = Math.max(0.12, direction.x * outward.x + direction.z * outward.y);
    return { chamber, alignment, score: alignment + chamber.level * 0.06 + seededNoise(s.space_seed + chamber.index * 41) * 0.08 };
  }).sort((a, b) => b.score - a.score);
  const pathCount = Math.min(ranked.length, Math.max(1, Math.round(1 + s.echo_prominence * 2)));
  return ranked.slice(0, pathCount).map(({ chamber, alignment }, index) => {
    const portal2 = pointOnOpening(chamber, 0.5);
    const height = s.room_z * branchHeightRatio(s, chamber);
    const z = clamp(listener.z * (0.82 + chamber.level * 0.05), 0.1, Math.max(0.1, height * 0.88));
    const portal = { x: portal2.x, y: portal2.y, z };
    const polygon = chamberPolygon(chamber);
    const far2 = polygon.reduce((best, point) => {
      const distance = Math.hypot(point.x - portal.x, point.y - portal.y);
      return !best || distance > best.distance ? { point, distance } : best;
    }, null).point;
    const far = { x: far2.x, y: far2.y, z: clamp(height * 0.54, 0.1, height * 0.9) };
    const family = branchFamilyResponse(s, chamber);
    const material = chamberMaterialProfile(s, chamber);
    const intervalDistance = Math.max(0.5, pointDistance3(portal, far) * 2 * family.path);
    const coupling = clamp(s.chamber_coupling * (0.35 + alignment * 0.65) * family.coupling, 0, 1.2);
    return {
      id: index + 1,
      structure: "coupled",
      points: [listener, portal, far, portal],
      directionPoints: [portal],
      closed: false,
      intervalDistance,
      baseDistance: pointDistance3(source, portal) + intervalDistance + pointDistance3(portal, listener),
      material: material.material_key,
      absorption: material.absorption,
      coupling,
      strength: family.energy,
      chamberIndex: chamber.index,
      branchFamily: chamber.family
    };
  });
}

function echoPathDefinitions(s, dir = selectedDirection(s)) {
  const requested = s.echo_structure || "off";
  if (requested === "off" || s.echo_prominence <= 0.0001) return { requested, resolved: "off", paths: [] };
  const profile = groupProfile(s, dir.index || 0);
  const listener = roomPoints(s, dir, profile).listener;
  const source = groupMapPosition(s, dir, profile);
  const chambers = chamberGeometries(s) || [];
  let resolved = requested;
  if (resolved === "geometry") {
    if (chambers.length) resolved = "coupled";
    else if (s.space_family === "room") resolved = "flutter";
    else if (s.space_family === "tunnel" || s.space_family === "canyon") resolved = "axial";
    else resolved = "circulating";
  }
  let paths = [];
  if (resolved === "coupled") paths = coupledEchoPaths(s, dir, listener, source);
  if (resolved === "coupled" && !paths.length) resolved = "axial";
  if (resolved === "axial" || resolved === "flutter") paths = [primaryAxisEchoPath(s, listener, source, resolved)];
  if (resolved === "circulating") paths = [circulatingEchoPath(s, listener, source)];
  return { requested, resolved, paths };
}

function echoPathEvents(s, dir = selectedDirection(s)) {
  const model = echoPathDefinitions(s, dir);
  if (!model.paths.length) return [];
  const listener = roomPoints(s, dir, groupProfile(s, dir.index || 0)).listener;
  const budget = Math.min(28, Math.max(model.paths.length, Math.round(4 + s.echo_prominence * 16 + s.echo_persistence * 8)));
  const eventsPerPath = Math.max(1, Math.ceil(budget / model.paths.length));
  const events = [];
  model.paths.forEach((path) => {
    const reflectivity = Math.sqrt(Math.max(0.001, 1 - path.absorption));
    const retention = clamp(s.echo_persistence * (0.82 + reflectivity * 0.18), 0.03, 0.97);
    const distanceLoss = 1 / Math.sqrt(Math.max(1, path.baseDistance * 0.35));
    const baseGain = (0.025 + s.echo_prominence * 0.17) * path.coupling * path.strength
      * reflectivity * distanceLoss / Math.sqrt(model.paths.length);
    const interval = Math.max(0.006, path.intervalDistance / 343);
    const baseTime = s.pre_delay_ms / 1000 + path.baseDistance / 343;
    let previousTime = -Infinity;
    for (let bounce = 0; bounce < eventsPerPath; bounce += 1) {
      const seed = s.space_seed + (dir.index + 1) * 1009 + path.id * 7919 + bounce * 131;
      const jitter = (seededNoise(seed) - 0.5) * 2 * interval * (1 - s.echo_regularity) * 0.34;
      const nominalTime = baseTime + bounce * interval;
      const time = Math.max(baseTime, previousTime + interval * 0.18, nominalTime + jitter);
      previousTime = time;
      if (time > s.duration) break;
      const point = path.directionPoints[bounce % path.directionPoints.length];
      const direction = echoDirection(listener, point);
      const gain = clamp(baseGain * Math.pow(retention, bounce), 0, 0.34);
      if (gain < 0.00001) continue;
      events.push({
        wall: `E${path.id}.${bounce + 1}`,
        time,
        amp: gain,
        az: direction.az,
        el: direction.el,
        type: "echo",
        material: path.material,
        chamber_index: path.chamberIndex,
        branch_family: path.branchFamily,
        echo_path_id: path.id,
        echo_bounce: bounce + 1,
        echo_structure: model.resolved,
        path_point: point
      });
    }
  });
  return events.sort((a, b) => a.time - b.time).slice(0, budget);
}

function echoPathSummary(s, dir = selectedDirection(s)) {
  const model = echoPathDefinitions(s, dir);
  const events = echoPathEvents(s, dir);
  return {
    enabled: model.paths.length > 0,
    requested_structure: model.requested,
    resolved_structure: model.resolved,
    prominence: round(s.echo_prominence, 4),
    persistence: round(s.echo_persistence, 4),
    regularity: round(s.echo_regularity, 4),
    geometry_driven: true,
    event_count: events.length,
    paths: model.paths.map((path) => ({
      id: path.id,
      structure: path.structure,
      interval_ms: round(path.intervalDistance / 343 * 1000, 3),
      repeat_path_m: round(path.intervalDistance, 4),
      material: path.material,
      chamber_index: path.chamberIndex === null ? null : path.chamberIndex + 1,
      branch_family: path.branchFamily,
      closed: path.closed,
      points_m: path.points.map((point) => ({ x: round(point.x, 4), y: round(point.y, 4), z: round(point.z || 0, 4) }))
    }))
  };
}

function reflectionEvents(s, dir = selectedDirection(s)) {
  const profile = groupProfile(s, dir.index || 0);
  const { listener } = roomPoints(s, dir, profile);
  const source = groupMapPosition(s, dir, profile);
  const desiredBoundaryCount = Math.min(
    Math.max(3, Math.floor(s.early_reflections)),
    Math.round(6 + s.surface_roughness * 10 + s.irregularity * 6 + (s.space_family === "abstract" ? 5 : 0))
  );
  const images = boundaryImageSources(s, source, listener).slice(0, desiredBoundaryCount);
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
      amp: Math.pow(reflectivity, 1 + index * 0.08) * image.surfaceGain / Math.max(1, distance),
      az: wrapDegrees(Math.atan2(dx, dy) * 180 / Math.PI + jitterA),
      el: clamp(Math.asin(clamp(dz / Math.max(0.001, distance), -1, 1)) * 180 / Math.PI + jitterE, -89, 89),
      type: "surface"
    };
  });
  const bounds = floorplanBounds(s);
  const roomCross = Math.sqrt((bounds.maxX - bounds.minX) ** 2 + (bounds.maxY - bounds.minY) ** 2 + s.room_z ** 2);
  const maxExtra = Math.max(0, Math.floor(s.early_reflections) - baseEvents.length);
  const extraEvents = Array.from({ length: maxExtra }, (_, index) => {
    const seed = (dir.index + 1) * 101 + index * 17;
    const u = seededNoise(seed);
    const cluster = seededNoise(seed + 3);
    const randomField = seededNoise(seed + 9);
    const baseTime = Math.min(s.duration * 0.35, roomCross / 343);
    const t = profile.pre_delay_ms / 1000 + 0.006 + u * Math.max(0.004, baseTime);
    const passage = s.space_family === "tunnel" || s.space_family === "canyon";
    const aroundGroup = randomField < 0.55 + profile.scattering * 0.35;
    const axialDirection = index % 2 === 0 ? 0 : 180;
    const az = passage
      ? wrapDegrees(axialDirection + (cluster - 0.5) * (18 + s.irregularity * 72))
      : aroundGroup
        ? wrapDegrees(dir.azimuth + (cluster - 0.5) * profile.direction_spread_deg * (1 + profile.scattering))
        : wrapDegrees(-180 + cluster * 360);
    const elSeed = seededNoise(seed + 13);
    const el = aroundGroup
      ? clamp(dir.elevation + (elSeed - 0.5) * profile.direction_spread_deg * 0.7, -89, 89)
      : Math.asin(-1 + 2 * elSeed) * 180 / Math.PI;
    const amp = (0.04 + 0.16 * seededNoise(seed + 19)) * reflectivity
      * (1 - s.openness * 0.76) * Math.exp(-t / Math.max(0.05, profile.rt60));
    return {
      wall: passage ? "AX" : s.space_family === "abstract" ? "FOLD" : "SC",
      time: t,
      amp,
      az,
      el,
      type: passage ? "axial" : s.space_family === "abstract" ? "fold" : "scatter"
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
      const familyResponse = branchFamilyResponse(s, chamber);
      const coupling = s.chamber_coupling * (0.35 + sourceTowardChamber * 0.65) * familyResponse.coupling;
      const chamberProfile = chamberMaterialProfile(s, chamber);
      const chamberReflectivity = Math.sqrt(Math.max(0, 1 - chamberProfile.absorption));
      const chamberPath = (chamber.depth * 2 + chamber.width * 0.65 + chamber.level * (s.chamber_depth * 1.4)) * familyResponse.path;
      const t = profile.pre_delay_ms / 1000 + (profile.source_distance + chamberPath * (0.52 + index * (0.12 + chamberProfile.scattering * 0.12))) / 343;
      const az = wrapDegrees(outward.az + (seededNoise(seed) - 0.5) * (45 + chamberProfile.scattering * 70) * familyResponse.azimuth);
      const el = clamp(dir.elevation * 0.35 + (seededNoise(seed + 5) - 0.5) * (24 + chamberProfile.scattering * 38) * familyResponse.elevation, -89, 89);
      const amp = (0.035 + 0.10 * seededNoise(seed + 9)) * chamberReflectivity * coupling * familyResponse.energy
        * Math.exp(-t / Math.max(0.05, profile.rt60 * (0.9 + chamberProfile.tail_soften * 0.8)));
      chamberEvents.push({
        wall: "C",
        chamber_index: chamber.index,
        branch_family: chamber.family,
        material: chamberProfile.material_key,
        time: t,
        amp,
        az,
        el,
        type: "chamber"
      });
    }
  }
  return [...baseEvents, ...extraEvents, ...chamberEvents, ...echoPathEvents(s, dir)]
    .sort((a, b) => a.time - b.time)
    .slice(0, 128);
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
    const label = chamber.level === 0 ? `branch ${chamber.index + 1}` : `depth ${chamber.level}`;
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
        .svg-chamber { fill: #8f9892; }
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
  const echoModel = echoPathDefinitions(s, selected);
  const echoPathSvg = s.show_early ? echoModel.paths.map((path) => {
    const points3 = path.closed ? [...path.points, path.points[0]] : path.points;
    const projected = points3.map(projection.point);
    const nodes = path.points.map((point) => {
      const p = projection.point(point);
      return `<rect x="${round(p.x - 2.5, 2)}" y="${round(p.y - 2.5, 2)}" width="5" height="5" fill="rgba(170,146,202,0.72)" />`;
    }).join("");
    return `<polyline points="${svgPoints(projected)}" fill="none" stroke="rgba(170,146,202,0.52)" stroke-width="1.5" stroke-dasharray="5 4" vector-effect="non-scaling-stroke" />${nodes}`;
  }).join("") : "";
  const eventLines = s.show_early ? events.map((event) => {
    const dir = unitFromAed(event.az, event.el);
    const endpoint = event.type === "echo" && event.path_point ? event.path_point : {
      x: clamp(listener.x + dir.x * selectedProfile.source_distance * 0.65, 0, s.room_x),
      y: clamp(listener.y + dir.z * selectedProfile.source_distance * 0.65, 0, s.room_y)
    };
    const ep = projection.point(endpoint);
    const color = event.type === "echo" ? "170,146,202" : event.type === "chamber" ? "120,190,150" : "216,162,74";
    return `<line x1="${round(lp.x, 2)}" y1="${round(lp.y, 2)}" x2="${round(ep.x, 2)}" y2="${round(ep.y, 2)}" stroke="rgba(${color},${clamp(event.amp * 3.6, 0.18, 0.72).toFixed(3)})" stroke-width="${round(clamp(event.amp * 12, 1.8, 4.8), 2)}" vector-effect="non-scaling-stroke" />`;
  }).join("") : "";
  const pointSvg = points.map((point) => `
    <g>
      <circle cx="${round(point.p.x, 2)}" cy="${round(point.p.y, 2)}" r="${point.active ? 7 : 4}" fill="${point.active ? "#8d8d8d" : "rgba(90,168,199,0.48)"}" />
      <text x="${round(point.p.x, 2)}" y="${round(point.p.y + 0.5, 2)}" class="svg-label" fill="${point.active ? "#050607" : "#d7d7d7"}">${point.index + 1}</text>
    </g>
  `).join("");
  roomSvg.innerHTML = `
    ${renderVectorFloorplan(s, projection)}
    ${pathLines}
    ${s.show_diffuse ? `<circle cx="${round(lp.x, 2)}" cy="${round(lp.y, 2)}" r="${round(diffuseRadius, 2)}" fill="rgba(90,168,199,${(0.06 + (1 - selectedProfile.absorption) * 0.08).toFixed(3)})" />` : ""}
    ${echoPathSvg}
    ${eventLines}
    ${s.show_direct ? `<line x1="${round(lp.x, 2)}" y1="${round(lp.y, 2)}" x2="${round(sp.x, 2)}" y2="${round(sp.y, 2)}" stroke="rgba(90,190,220,0.92)" stroke-width="3" vector-effect="non-scaling-stroke" />` : ""}
    ${pointSvg}
    <circle cx="${round(lp.x, 2)}" cy="${round(lp.y, 2)}" r="7" fill="#d7d7d7" />
    <text x="${round(lp.x, 2)}" y="${round(lp.y + 0.5, 2)}" class="svg-label" fill="#050607">L</text>
    <circle cx="${round(sp.x, 2)}" cy="${round(sp.y, 2)}" r="8" fill="#8d8d8d" />
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
      <circle cx="${round(p.x, 2)}" cy="${round(p.y, 2)}" r="${round(radius, 2)}" fill="${active ? "#a8a8a8" : "rgba(90,168,199,0.72)"}" />
      <text x="${round(p.x + 11, 2)}" y="${round(p.y + 3, 2)}" class="svg-small">${svgEscape(`G${index + 1}`)}</text>
    `;
  }).join("");
  roomSvg.innerHTML = `
    ${renderVectorFloorplan(s, projection)}
    <circle cx="${round(lp.x, 2)}" cy="${round(lp.y, 2)}" r="7" fill="#d7d7d7" />
    <text x="${round(lp.x, 2)}" y="${round(lp.y + 0.5, 2)}" class="svg-label" fill="#050607">L</text>
    ${groupSvg}
    <text x="12" y="20" class="svg-small svg-muted">Bank Map: ${dirs.length} responses placed in ${svgEscape(s.space_family)} topology / ${s.channels_per_ir}ch per group / ${s.stacked_channels}ch stacked</text>
    <text x="12" y="38" class="svg-small svg-muted">selected G${selected.index + 1}: ${selected.channels_start}-${selected.channels_end}</text>
    <text x="12" y="${ROOM_CANVAS_H - 16}" class="svg-small svg-muted">drag response points inside the primary and branch geometry</text>
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

function drawEchoPathGeometry(paths, project) {
  if (!paths.length) return;
  ctx.save();
  ctx.strokeStyle = "rgba(170,146,202,0.52)";
  ctx.fillStyle = "rgba(170,146,202,0.72)";
  ctx.lineWidth = 1.5;
  ctx.setLineDash([5, 4]);
  paths.forEach((path) => {
    const points = path.closed ? [...path.points, path.points[0]] : path.points;
    if (!points.length) return;
    const first = project(points[0]);
    ctx.beginPath();
    ctx.moveTo(first.x, first.y);
    points.slice(1).forEach((point) => {
      const projected = project(point);
      ctx.lineTo(projected.x, projected.y);
    });
    ctx.stroke();
    path.points.forEach((point) => {
      const projected = project(point);
      ctx.fillRect(projected.x - 2.5, projected.y - 2.5, 5, 5);
    });
  });
  ctx.restore();
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
  const roomTop = roomPolygon(s).map((p) => ({ ...p, z: spaceCeilingHeight(s, p.x, p.y) }));
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
    drawEchoPathGeometry(echoPathDefinitions(s, selected).paths, project);
    const selectedProfile = groupProfile(s, selected.index);
    reflectionEvents(s, selected).slice(0, Math.min(s.early_reflections, 28)).forEach((event) => {
      const dir = unitFromAed(event.az, event.el);
      const endpoint = event.type === "echo" && event.path_point ? event.path_point : {
        x: clamp(listener.x + dir.x * selectedProfile.source_distance * 0.9, 0, s.room_x),
        y: clamp(listener.y + dir.z * selectedProfile.source_distance * 0.9, 0, s.room_y),
        z: clamp(listener.z + dir.y * selectedProfile.source_distance * 0.9, 0, s.room_z)
      };
      const a = project(listenerPoint);
      const b = project(endpoint);
      ctx.strokeStyle = event.type === "echo" ? "rgba(170,146,202,0.56)" : event.type === "chamber" ? "rgba(120,190,150,0.56)" : "rgba(216,162,74,0.46)";
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
    drawPoint(projected.x, projected.y, active ? 7 : 4, active ? "#8d8d8d" : "rgba(90,168,199,0.46)", String(index + 1), active);
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
  drawPoint(sp.x, sp.y, 8, "#8d8d8d", String(selected.index + 1), true);
  ctx.fillStyle = "#9a9a9a";
  ctx.font = "11px Menlo, monospace";
  ctx.fillText(`3D ${s.space_family}  group ${selected.index + 1}/${selected.count}  camera ${s.camera_azimuth} az / ${s.camera_elevation} el / ${round(s.camera_zoom, 2)}x`, 12, 20);
  ctx.fillText("use camera controls for 3D; Bank Map edits response positions, Top edits field offset", 12, ROOM_CANVAS_H - 16);
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
  const sideHeight = Math.max(s.room_z, ...ceilingProfile(s).map((point) => point.z));
  const roomH = state.view === "side" ? sideHeight : bounds.height;
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
    const profile = ceilingProfile(s);
    ctx.beginPath();
    ctx.moveTo(ox + (bounds.minX - viewMinX) * scale, oy + roomH * scale);
    ctx.lineTo(ox + (bounds.maxX - viewMinX) * scale, oy + roomH * scale);
    profile.slice().reverse().forEach((point) => {
      ctx.lineTo(ox + (point.x - viewMinX) * scale, oy + (roomH - point.z) * scale);
    });
    ctx.closePath();
    ctx.fillStyle = "rgba(90,168,199,0.045)";
    ctx.fill();
    ctx.strokeStyle = "rgba(90,168,199,0.72)";
    ctx.stroke();
    drawChamberSide(s, ox, oy, scale, bounds);
  }

  const grid = state.view === "side" ? roomH : bounds.height;
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
    drawPoint(px(point), py(point), active ? 7 : 4, active ? "#8d8d8d" : "rgba(90,168,199,0.42)", String(index + 1), active);
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
    drawEchoPathGeometry(echoPathDefinitions(s, selected).paths, (point) => ({ x: px(point), y: py(point) }));
    events.slice(0, Math.min(events.length, s.early_reflections)).forEach((event) => {
      const dir = unitFromAed(event.az, event.el);
      const endpoint = event.type === "echo" && event.path_point ? event.path_point : {
        x: clamp(listener.x + dir.x * selectedProfile.source_distance * 0.65, bounds.minX, bounds.maxX),
        y: clamp(listener.y + dir.z * selectedProfile.source_distance * 0.65, bounds.minY, bounds.maxY),
        z: clamp(listener.z + dir.y * selectedProfile.source_distance * 0.65, 0, sideHeight)
      };
      const eventColor = event.type === "echo" ? "170, 146, 202" : event.type === "chamber" ? "120, 190, 150" : "216, 162, 74";
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
      if (event.type === "echo") {
        ctx.fillStyle = "rgba(170,146,202,0.78)";
        ctx.fillRect(px(endpoint) - 3, py(endpoint) - 3, 6, 6);
      } else if (event.type === "surface" || (event.type === "chamber" && state.view !== "top")) drawPoint(px(endpoint), py(endpoint), 3, event.type === "chamber" ? "rgba(120, 190, 150, 0.72)" : "rgba(216, 162, 74, 0.72)", event.wall, false);
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
  drawPoint(px(sourcePoint), py(sourcePoint), 8, "#8d8d8d", String(selected.index + 1), true);
  ctx.fillStyle = "#9a9a9a";
  ctx.font = "11px Menlo, monospace";
  ctx.fillText(`${state.view.toUpperCase()} ${s.space_family}  group ${selected.index + 1}/${selected.count}  ${selected.azimuth} az / ${selected.elevation} el`, 12, 20);
  ctx.fillText("drag in Top view to move the field; use Bank Map to move response positions", 12, ROOM_CANVAS_H - 16);
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
    const heightRatio = branchHeightRatio(s, chamber);
    const yTop = oy + s.room_z * (1 - heightRatio) * scale;
    const w = Math.max(3, (chamberBoundsLocal.maxX - chamberBoundsLocal.minX) * scale);
    const h = s.room_z * heightRatio * scale;
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

    ctx.fillStyle = "#8f9892";
    ctx.font = "9px Menlo, monospace";
    ctx.fillText(chamber.level === 0 ? `b${chamber.index + 1} ${branchFamilyLabel(chamber.family)}` : `d${chamber.level} ${branchFamilyLabel(chamber.family)}`, x + 6, yTop + 14);
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
    ctx.fillStyle = "#8f9892";
    ctx.font = "10px Menlo, monospace";
    ctx.fillText(chamber.level === 0 ? `b${chamber.index + 1} ${branchFamilyLabel(chamber.family)}` : `d${chamber.level} ${branchFamilyLabel(chamber.family)}`, x + 8, y + 16);
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
    ctx.fillStyle = active ? "#a8a8a8" : "#8d8d8d";
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
  ctx.fillText(`Bank Map: ${dirs.length} responses placed in ${s.space_family} topology / ${s.channels_per_ir}ch per group / ${s.stacked_channels}ch stacked`, 12, 20);
  ctx.fillText(`selected G${selected.index + 1}: ${selected.channels_start}-${selected.channels_end}`, 12, 38);
  ctx.fillText("drag response points inside the primary and branch geometry", 12, ROOM_CANVAS_H - 16);
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
  ctx.fillText("Bank Matrix: each row is one encoded directional response", x0, 22);
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
    drawMetricBar(columns.direct, y + 8, 94, directW, "#8d8d8d", `${Math.round(item.direct_time * 1000)} ms`);
    drawMetricBar(columns.first, y + 8, 116, firstW, "#a8a8a8", `${item.first_reflection_wall} ${Math.round(item.first_reflection_time * 1000)} ms`);
    drawMetricBar(columns.energy, y + 8, 170, clamp(item.early_energy / maxEnergy, 0, 1) * 170, item.echo_energy > 0.00001 ? "#aa92ca" : item.chamber_energy > 0.00001 ? "#8f9892" : "#b8d8e8", `${round(item.early_energy, 3)} c${round(item.chamber_energy, 3)} e${round(item.echo_energy, 3)}`);
  });
  ctx.fillStyle = "#9a9a9a";
  ctx.font = "10px Menlo, monospace";
  ctx.fillText("click a row to select the response", x0, ROOM_CANVAS_H - 16);
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
  ctx.fillText("Reflection Layers: all directional responses across time", pad, 22);
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
      ctx.fillStyle = "#95bcc2";
      ctx.beginPath();
      ctx.arc(directX, rowMid, active ? 4.6 : 3.4, 0, Math.PI * 2);
      ctx.fill();
    }

    if (s.show_early) {
      events.slice(0, Math.min(events.length, s.early_reflections)).forEach((event) => {
        const x = timeToX(event.time);
        const h = clamp(event.amp * 135, 4, rowH * 0.28);
        const isChamber = event.type === "chamber";
        const isEcho = event.type === "echo";
        const isLowerLane = isChamber || isEcho;
        const alpha = clamp(event.amp * 4.8, active ? 0.42 : 0.24, active ? 0.96 : 0.72);
        const color = isEcho ? `rgba(170,146,202,${alpha})` : isChamber ? `rgba(120,190,150,${alpha})` : `rgba(216,162,74,${alpha})`;
        ctx.strokeStyle = color;
        ctx.fillStyle = color;
        ctx.lineWidth = active ? 2.4 : 1.5;
        if (isLowerLane) {
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
        if (active && (event.type === "surface" || event.type === "chamber" || event.type === "echo")) {
          ctx.fillStyle = isEcho ? "#aa92ca" : isChamber ? "#8f9892" : "#a8a8a8";
          ctx.font = "9px Menlo, monospace";
          ctx.fillText(event.wall, x + 4, isLowerLane ? chamberBase + h + 8 : imageBase - h - 7);
        }
      });
    }
  });
  ctx.lineWidth = 1;
  ctx.fillStyle = "#9a9a9a";
  ctx.font = "10px Menlo, monospace";
  ctx.fillText("click a row to select; upper/lower lanes separate boundary and branch/echo timing", pad, ROOM_CANVAS_H - 16);
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
    timelineCtx.strokeStyle = event.type === "echo" ? "rgba(170,146,202,0.88)" : event.type === "chamber" ? "rgba(120,190,150,0.85)" : "rgba(216,162,74,0.85)";
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
  timelineCtx.fillText("direct / early reflections / echo paths / late tail", 8, 14);
}

function updateReadouts(s) {
  const selected = selectedDirection(s);
  const profile = groupProfile(s, selected.index);
  const points = roomPoints(s, selected, profile);
  const metrics = groupMetrics(s, selected.index);
  const echo = echoPathSummary(s, selected);
  const echoInterval = echo.paths.length ? `${round(echo.paths[0].interval_ms, 1)} ms` : "-";
  const branchFamilies = [...new Set((chamberGeometries(s) || []).map((chamber) => chamber.family))];
  readouts.rt60.textContent = `${s.estimated_rt60.toFixed(2)} s`;
  readouts.volume.textContent = `${s.acoustic_volume.toFixed(1)} m3`;
  readouts.channels.textContent = `${s.stacked_channels}`;
  readouts.late.textContent = `${Math.round(s.late_start_seconds * 1000)} ms`;
  readouts.group.innerHTML = `
    <div><span>Space</span><strong>${s.space_family} / seed ${s.space_seed}</strong></div>
    <div><span>Branches</span><strong>${s.branch_family}${branchFamilies.length ? ` / ${branchFamilies.join(", ")}` : " / none"}</strong></div>
    <div><span>Group</span><strong>${selected.index + 1} / ${selected.count}</strong></div>
    <div><span>AED</span><strong>${round(selected.azimuth)} deg / ${round(selected.elevation)} deg</strong></div>
    <div><span>Stacked channels</span><strong>${selected.channels_start}-${selected.channels_end}</strong></div>
    <div><span>Source XYZ m</span><strong>${round(metrics.map_position.x, 2)}, ${round(metrics.map_position.y, 2)}, ${round(metrics.map_position.z, 2)}</strong></div>
    <div><span>Direct arrival</span><strong>${Math.round(metrics.direct_time * 1000)} ms</strong></div>
    <div><span>First reflection</span><strong>${metrics.first_reflection_wall} / ${Math.round(metrics.first_reflection_time * 1000)} ms</strong></div>
    <div><span>Early energy</span><strong>${round(metrics.early_energy, 3)}</strong></div>
    <div><span>Branch energy</span><strong>${round(metrics.chamber_energy, 3)}</strong></div>
    <div><span>Echo paths</span><strong>${echo.resolved_structure} / ${echo.event_count} / ${echoInterval}</strong></div>
    <div><span>Echo energy</span><strong>${round(metrics.echo_energy, 3)}</strong></div>
    <div><span>Openness / escape</span><strong>${round(s.openness, 2)} / ${round(s.outside_leak_factor, 3)}</strong></div>
    <div><span>Local material</span><strong>a ${round(profile.absorption, 2)} / s ${round(profile.scattering, 2)} / tail ${round(profile.tail_soften, 2)}</strong></div>
    <div><span>Local distance</span><strong>${round(profile.source_distance, 2)} m</strong></div>
  `;
  readouts.json.textContent = JSON.stringify(exportObject(s), null, 2);
}

function exportObject(s = settings()) {
  const outsideOpenings = roomOpeningSegments(s);
  const directions = activeDirections(s);
  const firstDirection = directions[0] || [0, 0];
  const echoReference = {
    index: 0,
    count: directions.length,
    azimuth: firstDirection[0],
    elevation: firstDirection[1],
    channels_start: 1,
    channels_end: s.channels_per_ir
  };
  const groups = directions.map((d, i) => {
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
      branch_energy: round(metrics.chamber_energy, 5),
      echo_energy: round(metrics.echo_energy, 5),
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
    format: PROJECT_FORMAT,
    version: PROJECT_VERSION,
    tool: "s3g-mc Imprint Sketch",
    target_process: "3OAFX Synthetic Ambisonic IR Bank",
    interpretation: "directional acoustic sketch for architectural, natural, open, or imaginary spaces",
    space_family: s.space_family,
    space_seed: s.space_seed,
    room_x: round(s.room_x),
    room_y: round(s.room_y),
    room_z: round(s.room_z),
    material_preset: s.material_preset,
    absorption: round(s.absorption, 3),
    scattering: round(s.scattering, 3),
    tail_soften: round(s.tail_soften, 3),
    irregularity: round(s.irregularity, 3),
    surface_roughness: round(s.surface_roughness, 3),
    vertical_variation: round(s.vertical_variation, 3),
    openness: round(s.openness, 3),
    space_shape: s.space_shape,
    room_shape: s.room_shape,
    topology_bias: round(s.topology_bias, 3),
    branch_family: s.branch_family,
    room_polygon: roomPolygon(s).map((point) => ({
      x: round(point.x, 3),
      y: round(point.y, 3)
    })),
    space: {
      family: s.space_family,
      seed: s.space_seed,
      topology: s.space_shape === "side_chamber" ? "connected_regions" : "single_region",
      branch_family_mode: s.branch_family,
      primary_polygon_xy_m: roomPolygon(s).map((point) => ({ x: round(point.x, 3), y: round(point.y, 3) })),
      ceiling_profile_xz_m: ceilingProfile(s).map((point) => ({ x: round(point.x, 3), z: round(point.z, 3) })),
      irregularity: round(s.irregularity, 3),
      roughness: round(s.surface_roughness, 3),
      vertical_variation: round(s.vertical_variation, 3),
      openness: round(s.openness, 3),
      acoustic_volume_m3: round(s.acoustic_volume, 3),
      acoustic_surface_m2: round(s.acoustic_surface, 3)
    },
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
      family_mode: s.branch_family,
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
        family: chamber.family,
        height_m: round(s.room_z * branchHeightRatio(s, chamber), 3),
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
    echo_paths: echoPathSummary(s, echoReference),
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

function imprintObject(s = settings()) {
  const project = exportObject(s);
  const directions = activeDirections(s);
  const profiles = directions.map((direction, index) => {
    const info = {
      index,
      count: directions.length,
      azimuth: direction[0],
      elevation: direction[1],
      channels_start: index * s.channels_per_ir + 1,
      channels_end: (index + 1) * s.channels_per_ir
    };
    const metrics = groupMetrics(s, index);
    const absorptionBands = resolvedAbsorptionBands(metrics.profile, s.material_preset);
    const rt60Bands = localRt60Bands(s, absorptionBands);
    const reflections = reflectionEvents(s, info)
      .filter((event) => Number.isFinite(event.time) && Number.isFinite(event.amp) && event.time <= s.duration)
      .map((event) => {
        const reflection = {
          delay_ms: round(event.time * 1000, 3),
          gain: round(event.amp, 7),
          azimuth_deg: round(event.az, 3),
          elevation_deg: round(event.el, 3),
          kind: event.type,
          surface: event.wall,
          material: event.material || s.material_preset,
          branch_family: event.branch_family || null,
          chamber_index: event.chamber_index === undefined || event.chamber_index === null ? null : event.chamber_index + 1
        };
        if (event.echo_path_id) {
          reflection.echo_path_id = event.echo_path_id;
          reflection.echo_bounce = event.echo_bounce;
          reflection.echo_structure = event.echo_structure;
        }
        return reflection;
      });
    const tailLevel = clamp((Math.sqrt(Math.max(0, metrics.early_energy)) * 0.16
      + (1 - metrics.profile.absorption) * 0.10) * (1 - s.openness * 0.88), 0.003, 0.55);
    return {
      id: index + 1,
      input_direction: {
        azimuth_deg: round(direction[0], 3),
        elevation_deg: round(direction[1], 3)
      },
      source_position_m: {
        x: round(metrics.map_position.x, 4),
        y: round(metrics.map_position.y, 4),
        z: round(metrics.map_position.z, 4)
      },
      weight: round(1 / Math.max(1, directions.length), 7),
      direct: {
        delay_ms: round(metrics.direct_time * 1000, 3),
        gain: round(metrics.direct_amp, 7)
      },
      early_reflections: reflections,
      late: {
        start_ms: round(s.late_start_seconds * 1000, 3),
        duration_s: round(s.duration, 4),
        level: round(tailLevel, 7),
        diffusion: round(metrics.profile.scattering, 5),
        spread_deg: round(metrics.profile.direction_spread_deg, 3),
        high_frequency_damping: round(metrics.profile.tail_soften, 5),
        absorption_by_band: absorptionBands.map((value) => round(value, 6)),
        rt60_s_by_band: rt60Bands.map((value) => round(value, 6)),
        seed: imprintSeed(s, index)
      }
    };
  });

  return {
    format: IMPRINT_FORMAT,
    version: IMPRINT_VERSION,
    generator: {
      name: "s3g-mc Imprint Sketch",
      project_format: PROJECT_FORMAT,
      project_version: PROJECT_VERSION
    },
    interpretation: "procedural directional space sketch; spectral material curves are creative estimates, not measured coefficients",
    coordinate_system: {
      convention: "AED",
      azimuth_zero: "front",
      azimuth_positive: "counterclockwise",
      elevation_positive: "up",
      distance_unit: "metre",
      time_unit: "millisecond"
    },
    ambisonics: {
      channel_order: "ACN",
      normalization: "SN3D",
      reference_order: s.order,
      maximum_runtime_order: 7
    },
    spectral_bands_hz: IMPRINT_BANDS_HZ,
    space: project.space,
    echo_paths: project.echo_paths,
    room: {
      dimensions_m: {
        x: round(s.room_x, 4),
        y: round(s.room_y, 4),
        z: round(s.room_z, 4)
      },
      polygon_xy_m: project.room_polygon,
      shape: s.space_family === "room" ? s.room_shape : s.space_family,
      family: s.space_family,
      seed: s.space_seed,
      material: s.material_preset,
      absorption: round(s.absorption, 6),
      scattering: round(s.scattering, 6),
      tail_soften: round(s.tail_soften, 6),
      exterior_opening: project.exterior_opening,
      chamber: project.chamber
    },
    listener_position_m: {
      x: round(roomPoints(s, { index: 0, azimuth: directions[0][0], elevation: directions[0][1] }).listener.x, 4),
      y: round(roomPoints(s, { index: 0, azimuth: directions[0][0], elevation: directions[0][1] }).listener.y, 4),
      z: round(roomPoints(s, { index: 0, azimuth: directions[0][0], elevation: directions[0][1] }).listener.z, 4)
    },
    direction_layout: s.effective_direction_layout,
    direction_count: profiles.length,
    duration_s: round(s.duration, 4),
    profiles
  };
}

function round(v, places = 2) {
  const f = 10 ** places;
  return Math.round(v * f) / f;
}

function downloadObject(filename, object) {
  const blob = new Blob([JSON.stringify(object, null, 2)], { type: "application/json" });
  const link = document.createElement("a");
  link.download = filename;
  link.href = URL.createObjectURL(blob);
  link.click();
  URL.revokeObjectURL(link.href);
}

function downloadJson() {
  downloadObject("s3g_imprint_sketch.json", exportObject());
}

function downloadImprint() {
  const family = settings().space_family.replace(/[^a-z0-9_-]+/gi, "_");
  downloadObject(`s3g_${family}_imprint.s3gimprint`, imprintObject());
}

const RESTORE_KEYS = {
  space_family: "spaceFamily",
  space_seed: "spaceSeed",
  room_x: "roomX",
  room_y: "roomY",
  room_z: "roomZ",
  material_preset: "materialPreset",
  absorption: "absorption",
  scattering: "scattering",
  tail_soften: "tailSoften",
  irregularity: "irregularity",
  surface_roughness: "surfaceRoughness",
  vertical_variation: "verticalVariation",
  openness: "openness",
  space_shape: "spaceShape",
  room_shape: "roomShape",
  topology_bias: "topologyBias",
  branch_family: "branchFamily",
  chamber_shape: "chamberShape",
  chamber_side: "chamberSide",
  chamber_material: "chamberMaterial",
  chamber_material_mode: "chamberMaterialMode",
  chamber_width: "chamberWidth",
  chamber_depth: "chamberDepth",
  chamber_count: "chamberCount",
  chamber_position: "chamberPosition",
  nested_chambers: "nestedChambers",
  opening_width: "openingWidth",
  chamber_coupling: "chamberCoupling",
  chamber_material_mix: "chamberMaterialMix",
  echo_structure: "echoStructure",
  echo_prominence: "echoProminence",
  echo_persistence: "echoPersistence",
  echo_regularity: "echoRegularity",
  outside_opening_side: "outsideOpeningSide",
  outside_opening_count: "outsideOpeningCount",
  outside_opening_position: "outsideOpeningPosition",
  outside_opening_spread: "outsideOpeningSpread",
  outside_opening_width: "outsideOpeningWidth",
  outside_leak: "outsideLeak",
  field_x: "fieldX",
  field_y: "fieldY",
  source_azimuth: "sourceAz",
  source_elevation: "sourceEl",
  source_distance: "sourceDistance",
  direction_spread_deg: "spreadDeg",
  group_variation: "groupVariation",
  surface_contrast: "surfaceContrast",
  distance_variation: "distanceVariation",
  order: "order",
  direction_set: "directionSet",
  duration: "duration",
  pre_delay_ms: "preDelay",
  early_reflections: "earlyReflections",
};

function applyExportObject(data) {
  if (!data || typeof data !== "object") throw new Error("Imprint Sketch project must be a JSON object");
  const format = data.format || LEGACY_PROJECT_FORMAT;
  if (format !== PROJECT_FORMAT && format !== LEGACY_PROJECT_FORMAT) throw new Error(`Unsupported project format: ${format}`);
  const maximumVersion = format === LEGACY_PROJECT_FORMAT ? LEGACY_PROJECT_VERSION : PROJECT_VERSION;
  if (data.version && Number(data.version) > maximumVersion) throw new Error(`Project version ${data.version} is newer than this Imprint Sketch`);

  const chamber = data.chamber && typeof data.chamber === "object" ? data.chamber : {};
  const echoPaths = data.echo_paths && typeof data.echo_paths === "object" ? data.echo_paths : {};
  const exterior = data.exterior_opening && typeof data.exterior_opening === "object" ? data.exterior_opening : {};
  const space = data.space && typeof data.space === "object" ? data.space : {};
  const restored = {
    ...data,
    space_family: space.family ?? data.space_family ?? "room",
    space_seed: space.seed ?? data.space_seed ?? 314159,
    irregularity: space.irregularity ?? data.irregularity ?? (format === LEGACY_PROJECT_FORMAT ? 0 : undefined),
    surface_roughness: space.roughness ?? data.surface_roughness ?? (format === LEGACY_PROJECT_FORMAT ? 0.2 : undefined),
    vertical_variation: space.vertical_variation ?? data.vertical_variation ?? (format === LEGACY_PROJECT_FORMAT ? 0 : undefined),
    openness: space.openness ?? data.openness ?? (format === LEGACY_PROJECT_FORMAT ? 0 : undefined),
    direction_spread_deg: data.direction_spread_deg ?? data.spread_deg,
    branch_family: chamber.family_mode ?? chamber.family ?? space.branch_family_mode ?? data.branch_family ?? "inherit",
    chamber_material: chamber.material ?? data.chamber_material,
    chamber_material_mode: chamber.material_mode ?? data.chamber_material_mode,
    chamber_material_mix: chamber.material_mix ?? data.chamber_material_mix,
    chamber_width: chamber.width ?? data.chamber_width,
    chamber_depth: chamber.depth ?? data.chamber_depth,
    chamber_count: chamber.count ?? data.chamber_count,
    chamber_position: chamber.position ?? data.chamber_position,
    nested_chambers: chamber.nested_chambers ?? data.nested_chambers,
    opening_width: chamber.opening_width ?? data.opening_width,
    chamber_coupling: chamber.coupling ?? data.chamber_coupling,
    echo_structure: echoPaths.requested_structure ?? data.echo_structure ?? "off",
    echo_prominence: echoPaths.prominence ?? data.echo_prominence,
    echo_persistence: echoPaths.persistence ?? data.echo_persistence,
    echo_regularity: echoPaths.regularity ?? data.echo_regularity,
    outside_opening_side: exterior.side ?? data.outside_opening_side,
    outside_opening_count: exterior.count ?? data.outside_opening_count,
    outside_opening_position: exterior.position ?? data.outside_opening_position,
    outside_opening_spread: exterior.spread ?? data.outside_opening_spread,
    outside_opening_width: exterior.width ?? data.outside_opening_width,
    outside_leak: exterior.leak ?? data.outside_leak
  };
  Object.entries(RESTORE_KEYS).forEach(([key, controlId]) => {
    if (restored[key] === undefined || !controls[controlId]) return;
    controls[controlId].value = restored[key];
  });
  if (data.exterior_opening && controls.outsideOpening) controls.outsideOpening.checked = data.exterior_opening.enabled !== false;
  if (data.field_offset) {
    if (controls.fieldX && data.field_offset.x !== undefined) controls.fieldX.value = data.field_offset.x;
    if (controls.fieldY && data.field_offset.y !== undefined) controls.fieldY.value = data.field_offset.y;
  }
  if (data.camera) {
    if (controls.cameraAz && data.camera.azimuth !== undefined) controls.cameraAz.value = data.camera.azimuth;
    if (controls.cameraEl && data.camera.elevation !== undefined) controls.cameraEl.value = data.camera.elevation;
    if (controls.cameraZoom && data.camera.zoom !== undefined) controls.cameraZoom.value = data.camera.zoom;
  }
  state.groupMapPositions = {};
  if (Array.isArray(data.groups)) {
    data.groups.forEach((group, index) => {
      const position = group && group.source_position_m;
      if (!position || !Number.isFinite(Number(position.x)) || !Number.isFinite(Number(position.y))) return;
      state.groupMapPositions[groupPositionKey(index)] = {
        x: Number(position.x),
        y: Number(position.y),
        z: Number.isFinite(Number(position.z)) ? Number(position.z) : Number(controls.roomZ.value) * 0.5
      };
    });
  }
  if (data.view) state.view = data.view;
  document.querySelectorAll("[data-view]").forEach((button) => {
    button.classList.toggle("active", button.dataset.view === state.view);
  });
  updateAllRangeFills();
  drawRoom();
}

async function importProjectFile(file) {
  const text = await file.text();
  const data = JSON.parse(text);
  applyExportObject(data);
  lastAutosaveJson = "";
  autosave();
}

function autosave() {
  try {
    const json = JSON.stringify({ ...exportObject(), view: state.view });
    if (json === lastAutosaveJson) return;
    localStorage.setItem(STORAGE_KEY, json);
    lastAutosaveJson = json;
  } catch (error) {
    // Autosave is best-effort.
  }
}

function restoreAutosave() {
  try {
    const json = localStorage.getItem(STORAGE_KEY) || localStorage.getItem(LEGACY_STORAGE_KEY);
    if (!json) return false;
    applyExportObject(JSON.parse(json));
    lastAutosaveJson = json;
    if (!localStorage.getItem(STORAGE_KEY)) {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({ ...exportObject(), view: state.view }));
    }
    return true;
  } catch (error) {
    localStorage.removeItem(STORAGE_KEY);
    return false;
  }
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
  const topHeights = poly.map((point, index) => typeof height === "function" ? height(point, index) : height);
  poly.forEach((point) => pushVec3(positions, point.x, 0, -point.y));
  poly.forEach((point, index) => pushVec3(positions, point.x, topHeights[index], -point.y));
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
    const chamberHeight = s.room_z * branchHeightRatio(s, chamber);
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
  addExtrudedPolygonMesh(meshes, "Primary space", roomPolygon(s), (point) => spaceCeilingHeight(s, point.x, point.y), 0);
  (chamberGeometries(s) || []).forEach((chamber) => {
    const chamberHeight = s.room_z * branchHeightRatio(s, chamber);
    addExtrudedPolygonMesh(meshes, `Branch ${chamber.index + 1} ${chamber.family}`, chamberPolygon(chamber), chamberHeight, 1);
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
    addPointMarkerMesh(meshes, `Response ${index + 1}`, position, Math.max(0.09, Math.min(s.room_x, s.room_y) * 0.014), s.room_z * 0.06, 3);
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
      generator: "s3g-mc Imprint Sketch"
    },
    scene: 0,
    scenes: [{ nodes: nodes.map((_, index) => index) }],
    nodes,
    meshes: gltfMeshes,
    materials: [
      { name: "Primary space cyan", pbrMetallicRoughness: { baseColorFactor: [0.2, 0.75, 0.85, 0.42], metallicFactor: 0, roughnessFactor: 0.92 }, alphaMode: "BLEND", doubleSided: true },
      { name: "Branches green", pbrMetallicRoughness: { baseColorFactor: [0.32, 0.78, 0.52, 0.48], metallicFactor: 0, roughnessFactor: 0.86 }, alphaMode: "BLEND", doubleSided: true },
      { name: "Field center", pbrMetallicRoughness: { baseColorFactor: [0.9, 0.9, 0.9, 1], metallicFactor: 0, roughnessFactor: 0.5 } },
      { name: "Response groups", pbrMetallicRoughness: { baseColorFactor: [0.93, 0.62, 0.22, 1], metallicFactor: 0, roughnessFactor: 0.5 } },
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
      imprint_sketch: exportObject(s)
    }
  };
}

function downloadGltf() {
  const blob = new Blob([JSON.stringify(buildGltf(), null, 2)], { type: "model/gltf+json" });
  const link = document.createElement("a");
  link.download = "s3g_imprint_sketch.gltf";
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
  controls.spaceFamily.value = "room";
  controls.spaceSeed.value = 314159;
  controls.roomX.value = 12;
  controls.roomY.value = 9;
  controls.roomZ.value = 5;
  controls.materialPreset.value = "concrete";
  controls.irregularity.value = 0.18;
  controls.surfaceRoughness.value = 0.28;
  controls.verticalVariation.value = 0.12;
  controls.openness.value = 0.08;
  controls.spaceShape.value = "side_chamber";
  controls.roomShape.value = "rect";
  controls.topologyBias.value = 0.35;
  controls.branchFamily.value = "inherit";
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
  controls.echoStructure.value = "off";
  controls.echoProminence.value = 0.58;
  controls.echoPersistence.value = 0.68;
  controls.echoRegularity.value = 0.82;
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
  state.groupMapPositions = {};
  applyMaterial();
}

function randomize(seedOverride = null) {
  const bias = clamp(Number(controls.topologyBias.value || 0.35), 0, 1);
  const seed = Number.isFinite(Number(seedOverride)) ? normalizedSeed(seedOverride) : freshSeed();
  const rng = makeRng(seed);
  const range = (min, max) => min + rng() * (max - min);
  const rangeBiased = (min, max) => min + (rng() * 0.55 + Math.pow(bias, 1.35) * 0.45) * (max - min);
  const integer = (min, max) => Math.floor(range(min, max + 1));
  const pick = (items) => items[Math.floor(rng() * items.length) % items.length];
  let family = controls.spaceFamily.value;
  if (family === "any") family = resolvedSpaceFamily("any", seed, bias);
  controls.spaceFamily.value = family;
  controls.spaceSeed.value = seed;

  const familySettings = {
    room: {
      x: [6, 34], y: [4, 24], z: [2.8, 11], irregularity: [0.01, 0.16 + bias * 0.40],
      roughness: [0.08, 0.42 + bias * 0.28], vertical: [0, 0.12 + bias * 0.30], openness: [0, 0.12 + bias * 0.34],
      materials: ["concrete", "brick", "stone", "wood", "metal", "studio", "damped", "glass", "fabric"]
    },
    cave: {
      x: [8, 38], y: [7, 32], z: [3.5, 16], irregularity: [0.38, 0.72 + bias * 0.28],
      roughness: [0.58, 0.90 + bias * 0.10], vertical: [0.32, 0.72 + bias * 0.28], openness: [0.01, 0.18 + bias * 0.30],
      materials: ["stone", "stone", "porous_rock", "earth", "water", "ice"]
    },
    cavern: {
      x: [18, 72], y: [14, 62], z: [8, 30], irregularity: [0.24, 0.58 + bias * 0.28],
      roughness: [0.48, 0.86 + bias * 0.14], vertical: [0.44, 0.78 + bias * 0.22], openness: [0, 0.10 + bias * 0.24],
      materials: ["stone", "porous_rock", "earth", "water", "ice"]
    },
    tunnel: {
      x: [3, 13], y: [22, 80], z: [2.4, 11], irregularity: [0.10, 0.45 + bias * 0.38],
      roughness: [0.18, 0.64 + bias * 0.32], vertical: [0.08, 0.34 + bias * 0.42], openness: [0.06, 0.28 + bias * 0.34],
      materials: ["stone", "brick", "concrete", "metal", "earth", "porous_rock"]
    },
    canyon: {
      x: [9, 32], y: [32, 80], z: [10, 30], irregularity: [0.28, 0.68 + bias * 0.28],
      roughness: [0.56, 0.88 + bias * 0.12], vertical: [0.36, 0.70 + bias * 0.28], openness: [0.58, 0.84 + bias * 0.16],
      materials: ["stone", "porous_rock", "earth", "concrete"]
    },
    clearing: {
      x: [22, 80], y: [22, 80], z: [12, 30], irregularity: [0.14, 0.48 + bias * 0.30],
      roughness: [0.52, 0.84 + bias * 0.16], vertical: [0.08, 0.30 + bias * 0.30], openness: [0.78, 0.93 + bias * 0.07],
      materials: ["vegetation", "vegetation", "earth", "water", "porous_rock"]
    },
    abstract: {
      x: [4, 62], y: [4, 62], z: [3, 30], irregularity: [0.62, 1],
      roughness: [0.08, 1], vertical: [0.46, 1], openness: [0, 1],
      materials: Object.keys(materials)
    }
  };
  const preset = familySettings[family] || familySettings.room;
  controls.roomX.value = round(range(...preset.x), 1);
  controls.roomY.value = round(range(...preset.y), 1);
  controls.roomZ.value = round(range(...preset.z), 1);
  controls.irregularity.value = round(range(...preset.irregularity), 2);
  controls.surfaceRoughness.value = round(range(...preset.roughness), 2);
  controls.verticalVariation.value = round(range(...preset.vertical), 2);
  controls.openness.value = round(range(...preset.openness), 2);
  controls.materialPreset.value = pick(preset.materials);
  const material = materials[controls.materialPreset.value] || materials.concrete;
  controls.absorption.value = round(clamp(material.absorption + (rng() - 0.5) * bias * 0.16, 0.03, 0.95), 2);
  controls.scattering.value = round(clamp(material.scattering + (Number(controls.surfaceRoughness.value) - 0.5) * 0.26 + (rng() - 0.5) * 0.12, 0, 1), 2);
  controls.tailSoften.value = round(clamp(material.tailSoften + (rng() - 0.5) * (0.12 + bias * 0.20), 0, 1), 2);

  const connectedChance = family === "abstract" ? 0.92
    : family === "cave" || family === "cavern" ? 0.72 + bias * 0.22
      : family === "clearing" || family === "canyon" ? 0.18 + bias * 0.26
        : 0.28 + bias * 0.52;
  controls.spaceShape.value = rng() < connectedChance ? "side_chamber" : "shoebox";
  controls.roomShape.value = chooseByBias(
    ["rect", "rect", "trapezoid"],
    ["rect", "trapezoid", "wedge", "skew"],
    ["wedge", "skew", "diamond", "impossible", "impossible"],
    bias,
    rng
  );
  controls.chamberShape.value = chooseByBias(
    ["rect", "rect", "trapezoid"],
    ["rect", "trapezoid", "wedge", "skew"],
    ["wedge", "skew", "impossible", "impossible"],
    bias,
    rng
  );
  controls.chamberSide.value = chooseByBias(
    ["back", "left", "right"],
    ["front", "back", "left", "right"],
    ["front", "back", "left", "right", "all", "all"],
    bias,
    rng
  );
  controls.chamberMaterial.value = pick(preset.materials);
  controls.chamberMaterialMode.value = chooseByBias(
    ["uniform", "uniform", "alternating"],
    ["uniform", "alternating", "nested"],
    ["alternating", "nested", "palette", "palette"],
    bias,
    rng
  );
  controls.chamberWidth.value = round(range(1.2, Math.max(1.5, Math.min(14, Number(controls.roomX.value) * 0.72))), 1);
  controls.chamberDepth.value = round(range(1.2, Math.max(1.5, Math.min(16, Number(controls.roomY.value) * 0.62))), 1);
  controls.chamberCount.value = integer(1, Math.max(1, Math.round(1.6 + bias * 2.4)));
  controls.chamberPosition.value = round(rng(), 2);
  controls.nestedChambers.value = integer(0, Math.round(bias * 2));
  controls.openingWidth.value = round(range(0.48 - bias * 0.32, 0.86 - bias * 0.22), 2);
  controls.chamberCoupling.value = round(rangeBiased(0.12, 0.92), 2);
  controls.chamberMaterialMix.value = round(rangeBiased(0.18, 0.98), 2);
  controls.outsideOpening.checked = Number(controls.openness.value) > 0.42 || rng() < 0.28 + bias * 0.42;
  controls.outsideOpeningSide.value = chooseByBias(
    ["front", "back", "left", "right"],
    ["front", "back", "left", "right", "all"],
    ["front", "back", "left", "right", "all", "all"],
    bias,
    rng
  );
  controls.outsideOpeningCount.value = integer(1, Math.max(1, Math.round(2 + bias * 4)));
  controls.outsideOpeningPosition.value = round(rng(), 2);
  controls.outsideOpeningSpread.value = round(range(0.12, 0.35 + bias * 0.65), 2);
  controls.outsideOpeningWidth.value = round(range(0.10, 0.24 + bias * 0.42), 2);
  controls.outsideLeak.value = round(rangeBiased(0.12, 0.88), 2);
  controls.fieldX.value = round(range(-0.22 - bias * 0.62, 0.22 + bias * 0.62), 2);
  controls.fieldY.value = round(range(-0.22 - bias * 0.62, 0.22 + bias * 0.62), 2);
  controls.sourceAz.value = 0;
  controls.sourceEl.value = 0;
  controls.sourceDistance.value = round(clamp(range(0.8, Math.min(18, Math.max(2, Math.min(Number(controls.roomX.value), Number(controls.roomY.value)) * 0.72))), 0.25, 20), 2);
  controls.spreadDeg.value = Math.round(range(16 + bias * 8, 52 + bias * 68));
  controls.groupVariation.value = round(rangeBiased(0.08, 0.9), 2);
  controls.surfaceContrast.value = round(rangeBiased(0.12, 0.96), 2);
  controls.distanceVariation.value = round(rangeBiased(0.03, 0.72), 2);
  const durationRange = family === "clearing" ? [0.45, 2.4]
    : family === "canyon" ? [1.2, 5.5]
      : family === "cavern" ? [3, 9]
        : family === "abstract" ? [0.7, 10]
          : [1.2, 6.5];
  controls.duration.value = round(range(...durationRange), 2);
  controls.preDelay.value = Math.round(range(2, 24 + bias * 48));
  controls.earlyReflections.value = Math.round(range(8 + bias * 4, 28 + bias * 48));
  if (controls.echoStructure.value !== "off") {
    controls.echoProminence.value = round(rangeBiased(0.28, 0.94), 2);
    controls.echoPersistence.value = round(rangeBiased(0.38, 0.92), 2);
    controls.echoRegularity.value = round(range(0.24, 0.96 - bias * 0.12), 2);
  }
  controls.cameraAz.value = Math.round(range(-80, 80));
  controls.cameraEl.value = Math.round(range(18, 52));
  controls.cameraZoom.value = round(range(0.78, 1.36), 2);
  state.selectedDirection = 0;
  state.groupMapPositions = {};
  updateAllRangeFills();
  drawRoom();
}

function mutate() {
  const bias = clamp(Number(controls.topologyBias.value || 0.35), 0, 1);
  const seed = freshSeed();
  const rng = makeRng(seed);
  const amount = 0.06 + bias * 0.22;
  controls.spaceSeed.value = seed;
  if (controls.spaceFamily.value === "any") controls.spaceFamily.value = resolvedSpaceFamily("any", seed, bias);
  const mutateRange = (control, scale = 1) => {
    const min = Number(control.min);
    const max = Number(control.max);
    const value = Number(control.value);
    const next = clamp(value + (rng() - 0.5) * (max - min) * amount * scale, min, max);
    control.value = control.step && Number(control.step) >= 1 ? Math.round(next) : round(next, Number(control.step) < 0.01 ? 3 : 2);
  };
  [controls.roomX, controls.roomY, controls.roomZ, controls.irregularity, controls.surfaceRoughness,
    controls.verticalVariation, controls.openness, controls.chamberWidth, controls.chamberDepth,
    controls.chamberPosition, controls.openingWidth, controls.chamberCoupling, controls.chamberMaterialMix,
    controls.outsideOpeningPosition, controls.outsideOpeningSpread, controls.outsideOpeningWidth,
    controls.outsideLeak, controls.fieldX, controls.fieldY, controls.sourceDistance, controls.spreadDeg,
    controls.groupVariation, controls.surfaceContrast, controls.distanceVariation, controls.duration,
    controls.preDelay, controls.earlyReflections, controls.echoProminence, controls.echoPersistence,
    controls.echoRegularity].forEach((control) => mutateRange(control));
  if (rng() < 0.28 + bias * 0.30) controls.roomShape.value = choice(["rect", "trapezoid", "wedge", "skew", "diamond", "impossible"], rng);
  if (rng() < 0.24 + bias * 0.34) controls.chamberShape.value = choice(["rect", "trapezoid", "wedge", "skew", "impossible"], rng);
  if (rng() < 0.18 + bias * 0.30) controls.chamberSide.value = choice(["front", "back", "left", "right", "all"], rng);
  if (rng() < 0.14 + bias * 0.20) controls.spaceShape.value = controls.spaceShape.value === "shoebox" ? "side_chamber" : "shoebox";
  state.selectedDirection = 0;
  state.groupMapPositions = {};
  updateAllRangeFills();
  drawRoom();
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
  const button = heading.querySelector(".section-toggle");
  heading.tabIndex = 0;
  heading.setAttribute("role", "button");
  heading.setAttribute("aria-expanded", "true");
  const toggle = () => {
    const collapsed = section.classList.toggle("collapsed");
    heading.setAttribute("aria-expanded", collapsed ? "false" : "true");
    if (button) {
      button.textContent = collapsed ? "+" : "-";
      button.setAttribute("aria-expanded", collapsed ? "false" : "true");
    }
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
$("mutate").addEventListener("click", mutate);
$("importJson").addEventListener("click", () => $("projectFileInput").click());
$("projectFileInput").addEventListener("change", async (event) => {
  const file = event.target.files && event.target.files[0];
  if (!file) return;
  try {
    await importProjectFile(file);
  } catch (error) {
    window.alert(`Could not import Imprint Sketch project: ${error.message}`);
  } finally {
    event.target.value = "";
  }
});
$("exportJson").addEventListener("click", downloadJson);
$("exportImprint").addEventListener("click", downloadImprint);
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
if (!restoreAutosave()) applyMaterial();
setInterval(autosave, 2000);
window.addEventListener("beforeunload", autosave);
