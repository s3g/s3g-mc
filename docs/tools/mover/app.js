const canvas = document.getElementById("view");
const ctx = canvas.getContext("2d");

const el = (id) => document.getElementById(id);
const ui = {
  play: el("play"),
  stop: el("stop"),
  app: document.querySelector(".app"),
  importJson: el("importJson"),
  exportJson: el("exportJson"),
  fullscreenView: el("fullscreenView"),
  closeFullscreen: el("closeFullscreen"),
  jsonFile: el("jsonFile"),
  timeReadout: el("timeReadout"),
  analysisReadout: el("analysisReadout"),
  motionSceneTitle: el("motionSceneTitle"),
  addBank: el("addBank"),
  deleteBank: el("deleteBank"),
  bankList: el("bankList"),
  sceneGrid: el("sceneGrid"),
  sceneName: el("sceneName"),
  morphTarget: el("morphTarget"),
  morphDuration: el("morphDuration"),
  morphDurationValue: el("morphDurationValue"),
  sceneHold: el("sceneHold"),
  sceneHoldValue: el("sceneHoldValue"),
  storeScene: el("storeScene"),
  randomScene: el("randomScene"),
  generateScenes: el("generateScenes"),
  varySceneBanks: el("varySceneBanks"),
  morphScene: el("morphScene"),
  autoNext: el("autoNext"),
  sceneLoop: el("sceneLoop"),
  bankMode: el("bankMode"),
  sceneMode: el("sceneMode"),
  duration: el("duration"),
  pointRate: el("pointRate"),
  motion: el("motion"),
  width: el("width"),
  disorder: el("disorder"),
  gravity: el("gravity"),
  development: el("development"),
  topoWarp: el("topoWarp"),
  sourceSelect: el("sourceSelect"),
  sourceGain: el("sourceGain"),
  sourceDistance: el("sourceDistance"),
  toggleSource: el("toggleSource"),
  resetSources: el("resetSources"),
  cameraAz: el("cameraAz"),
  cameraEl: el("cameraEl"),
  zoom: el("zoom"),
  analysisScope: el("analysisScope"),
  neighborLinks: el("neighborLinks"),
  analysisInfluence: el("analysisInfluence"),
  centroidPull: el("centroidPull"),
  spreadTarget: el("spreadTarget"),
  activityDamping: el("activityDamping"),
  showAnalysis: el("showAnalysis"),
  showCentroid: el("showCentroid"),
  showTrails: el("showTrails"),
  showLabels: el("showLabels"),
};

const COLORS = ["#6ee7f2", "#f2c56e", "#ff7f6e", "#9de67f", "#b998ff", "#f06eca", "#86a7ff", "#ffffff"];
const SCENE_COLORS = ["#5aa8c7", "#d8a24a", "#cf695f", "#7ea65a", "#9b83d8", "#cf6bb0", "#7f9bd8", "#d7d7d7"];
const SCENES = ["a", "b", "c", "d", "e", "f", "g", "h"];
const MOTION_BANKS = [
  "orbit", "weave", "lattice", "frame", "trace", "pulse", "suspend", "leap",
  "field", "molec", "fluid", "forsy", "flock", "eco", "contact", "march",
  "procession", "xenak", "cardew", "path", "scatter",
];
const VARIANTS = [
  "primary", "alternate", "wide", "fold", "canon", "suspend", "burst", "drift",
  "ribbon", "gate", "mirror", "surge", "tether", "vortex", "yield", "still",
];
const SCENE_NAME_A = ["RUST", "VOLT", "FROST", "GHOST", "DUSK", "CIRCUIT", "PULSE", "CINDER", "ECHO", "GLASS", "IRON", "STATIC", "NOVA", "BLOOM", "SILT", "VECTOR"];
const SCENE_NAME_B = ["DRIFT", "LOCK", "TRACE", "WAVE", "SPIN", "FIELD", "FOLD", "GATE", "ORBIT", "VAULT", "MIRROR", "SWARM", "BEND", "RIFT", "PHASE", "GRID"];
const SCENE_NAMES_BY_BANK = {
  weave: ["RIBBON", "LANES", "BANDS", "WAVES", "TWIST", "BRAID", "CROSS", "NET"],
  lattice: ["FAN", "ROTATE", "SECTOR", "TRAIL", "GRID", "RING", "STEP", "SPIN"],
  frame: ["HORIZ", "VERT", "BOX", "CURVE", "DOOR", "EDGE", "TILT", "WINDOW"],
  trace: ["CHASE", "BRANCH", "FIGURE", "FOLD", "ECHO", "TRACE", "SPLIT", "LOOP"],
  pulse: ["STEPS", "GATES", "SCAT", "ROTATE", "BURST", "STROBE", "WAVE", "POP"],
  suspend: ["HOLD", "ALIGN", "CENTER", "HALO", "FLOAT", "ANCHOR", "STILL", "CLOUD"],
  leap: ["RANDOM", "OPPOS", "GRID", "INVERT", "SKIP", "JUMP", "FLIP", "SHAKE"],
  field: ["CHARGE", "WELL", "DIPOLE", "GRAD", "FLUX", "DRIFT", "SHELL", "TURB"],
  molec: ["BOND", "CHAIN", "FOLD", "PAIR", "DIFF", "MEMBR", "LOCK", "HELIX"],
  fluid: ["LAMIN", "EDDY", "VORTX", "SINK", "SOURCE", "SHEAR", "WAVE", "JET"],
  orbit: ["MOON", "BINARY", "LAGR", "ELLIP", "RESON", "COMET", "RING", "TILT"],
  forsy: ["POINT", "LINE", "PLANE", "TRACE", "FOLD", "EXTND", "INSCR", "AXIS"],
  flock: ["MURMR", "SCHOOL", "VFORM", "ROOST", "SPLIT", "MERGE", "PRED", "ESCAP"],
  eco: ["FLOCK", "MIGR", "GRAZE", "PRED", "PREY", "NEST", "EDGE", "FLOW"],
  contact: ["WEIGHT", "ROLL", "LEAN", "YIELD", "LIFT", "CNTR", "FALL", "RCOVR"],
  march: ["BLOCK", "LINE", "ARC", "WEDGE", "SPIRL", "PASS", "GATE", "PINWH"],
  procession: ["STATN", "RELAY", "OFFER", "CIRCL", "GATE", "RTRN", "CHANT", "VIGIL"],
  xenak: ["DRAW", "SCORE", "UPIC", "RULED", "CONE", "CYL", "HELIC", "HYPAR"],
  cardew: ["LINE", "SYMBL", "PAGE", "STAFF", "RULE", "FREE", "CHOICE", "GROUP"],
  path: ["FOLLOW", "RIBBON", "ORBIT", "PULSE", "REV", "BRAID", "GATE", "SCAT"],
  scatter: ["CLOUD", "DUST", "SPARK", "DRIFT", "BURST", "GRAIN", "SWARM", "FIELD"],
};
const MAX_BANKS = 8;
const TWO_PI = Math.PI * 2;

let state = {
  playing: false,
  playStart: performance.now(),
  playT: 0,
  activeBank: 0,
  activeScene: "a",
  selectedSource: 0,
  banks: [makeBank(0, "Group 1")],
  dragging: null,
  viewDrag: null,
  nextSceneAt: 0,
  generateSeed: 0,
};

let reaperLink = {
  enabled: false,
  loaded: false,
  nextPoll: 0,
  lastUpdated: 0,
  playing: false,
  basePosition: 0,
  baseT: 0,
  displayT: 0,
  duration: 16,
  receivedAt: performance.now(),
};

function makeSource(index) {
  const a = (index / 8) * TWO_PI;
  return {
    id: index + 1,
    azimuth: radToDeg(a),
    elevation: (index % 2 === 0 ? 1 : -1) * 8,
    distance: 1,
    gain: 1,
    enabled: true,
  };
}

function makeBank(index, name) {
  return {
    id: index + 1,
    name,
    motionOffset: makeGroupOffset(index),
    mode: index % 2 ? "weave" : "orbit",
    scene: "a",
    variant: "primary",
    scenes: {},
    morph: null,
    sources: Array.from({ length: 8 }, (_, i) => makeSource(i)),
    params: {
      motion: 0.42,
      width: 0.58,
      disorder: 0.18,
      gravity: 0.46,
      development: 0.35,
      topoWarp: 0.18,
    },
  };
}

function makeGroupOffset(index, seed = 0) {
  const n = index + 1 + seed * 0.017;
  return {
    phase: fract(index * 0.137 + seed * 0.0009),
    azimuth: wrapDeg(index * 47 + hashNoise(n * 17, seed, 1) * 34 - 17),
    elevation: (hashNoise(n * 23, seed, 2) * 2 - 1) * Math.min(42, 8 + index * 5),
    distance: 0.82 + hashNoise(n * 31, seed, 3) * 0.72,
  };
}

function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, v));
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
  updateTimeReadouts();
}

function updateTimeReadouts() {
  ui.morphDurationValue.textContent = `${Number(ui.morphDuration.value).toFixed(1)}s`;
  ui.sceneHoldValue.textContent = `${Number(ui.sceneHold.value).toFixed(1)}s`;
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

function degToRad(v) {
  return (v * Math.PI) / 180;
}

function radToDeg(v) {
  return (v * 180) / Math.PI;
}

function wrapDeg(v) {
  let x = ((v + 180) % 360 + 360) % 360 - 180;
  return x === -180 ? 180 : x;
}

function fract(v) {
  return v - Math.floor(v);
}

function activeBank() {
  return state.banks[state.activeBank];
}

function nextSceneKey(key, loop = true) {
  const index = SCENES.indexOf(key);
  if (index < 0) return SCENES[0];
  if (index + 1 >= SCENES.length) return loop ? SCENES[0] : null;
  return SCENES[index + 1];
}

function propagateMotionFrom(sourceBank) {
  state.banks.forEach((bank) => {
    if (bank === sourceBank) return;
    bank.mode = sourceBank.mode;
    bank.scene = sourceBank.scene;
    bank.variant = sourceBank.variant;
    bank.params = { ...sourceBank.params };
    bank.morph = null;
  });
}

function cloneSource(source) {
  return { ...source };
}

function snapshotBank(bank) {
  return {
    name: bank.name,
    motionOffset: { ...(bank.motionOffset || makeGroupOffset(0)) },
    mode: bank.mode,
    scene: bank.scene,
    variant: bank.variant || "primary",
    params: { ...bank.params },
    sources: bank.sources.map(cloneSource),
  };
}

function snapshotFromScene(scene, key) {
  return {
    name: scene.name || key.toUpperCase(),
    mode: scene.mode,
    scene: key,
    variant: scene.variant || "primary",
    params: { ...scene.params },
    hold: Number(scene.hold ?? ui.sceneHold.value ?? 1),
    morph: Number(scene.morph ?? ui.morphDuration.value ?? 4),
  };
}

function serializeScenes(scenes) {
  const out = {};
  Object.keys(scenes || {}).forEach((key) => {
    const scene = scenes[key];
    out[key] = {
      name: scene.name || key.toUpperCase(),
      mode: scene.mode || "orbit",
      variant: scene.variant || "primary",
      params: { ...(scene.params || {}) },
      hold: Number(scene.hold ?? 1),
      morph: Number(scene.morph ?? 4),
    };
  });
  return out;
}

function normalizeParams(params = {}) {
  return {
    motion: Number(params.motion ?? 0.42),
    width: Number(params.width ?? 0.58),
    disorder: Number(params.disorder ?? 0.18),
    gravity: Number(params.gravity ?? 0.46),
    development: Number(params.development ?? 0.35),
    topoWarp: Number(params.topoWarp ?? 0.18),
  };
}

function normalizeSource(source, index) {
  const fallback = makeSource(index);
  return {
    id: index + 1,
    azimuth: Number(source?.azimuth ?? fallback.azimuth),
    elevation: Number(source?.elevation ?? fallback.elevation),
    distance: Number(source?.distance ?? fallback.distance),
    gain: Number(source?.gain ?? fallback.gain),
    enabled: source?.enabled !== false,
  };
}

function normalizeGroupOffset(offset, index) {
  const fallback = makeGroupOffset(index);
  return {
    phase: clamp(Number(offset?.phase ?? fallback.phase), 0, 1),
    azimuth: wrapDeg(Number(offset?.azimuth ?? fallback.azimuth)),
    elevation: clamp(Number(offset?.elevation ?? fallback.elevation), -85, 85),
    distance: clamp(Number(offset?.distance ?? fallback.distance), 0.45, 2.4),
  };
}

function angularLerp(a, b, t) {
  return wrapDeg(a + wrapDeg(b - a) * t);
}

function blendSource(a, b, t) {
  return {
    id: a.id,
    azimuth: angularLerp(Number(a.azimuth || 0), Number(b.azimuth || 0), t),
    elevation: lerp(Number(a.elevation || 0), Number(b.elevation || 0), t),
    distance: lerp(Number(a.distance || 1), Number(b.distance || 1), t),
    gain: lerp(Number(a.gain || 0), Number(b.gain || 0), t),
    enabled: t < 0.5 ? a.enabled !== false : b.enabled !== false,
  };
}

function blendSnapshots(from, to, t) {
  const eased = smooth(clamp(t, 0, 1));
  const params = {};
  Object.keys(from.params).forEach((key) => {
    params[key] = lerp(Number(from.params[key] || 0), Number(to.params[key] || 0), eased);
  });
  return {
    name: from.name,
    mode: eased < 0.5 ? from.mode : to.mode,
    scene: to.scene || from.scene,
    variant: eased < 0.5 ? from.variant : to.variant,
    params,
    sources: from.sources.map(cloneSource),
  };
}

function effectiveBank(bank) {
  if (!bank.morph) return bank;
  return { ...bank, ...blendSnapshots(bank.morph.from, bank.morph.to, bank.morph.progress), morph: bank.morph };
}

function commitMorph(bank) {
  if (!bank.morph) return;
  const target = bank.morph.to;
  bank.mode = target.mode;
  bank.variant = target.variant || "primary";
  bank.params = { ...target.params };
  bank.sources = target.sources.map(cloneSource);
  bank.scene = bank.morph.targetKey;
  bank.morph = null;
  syncPanelFromBank();
}

function resizeCanvas() {
  const rect = canvas.getBoundingClientRect();
  const dpr = window.devicePixelRatio || 1;
  const w = Math.max(640, Math.round(rect.width * dpr));
  const h = Math.max(420, Math.round(rect.height * dpr));
  if (canvas.width !== w || canvas.height !== h) {
    canvas.width = w;
    canvas.height = h;
  }
}

function sourcePosition(bank, source, t) {
  if (bank.morph) return morphSourcePosition(bank, source, t);
  const raw = rawSourcePosition(bank, source, t);
  return applyAnalysisInfluence(bank, source, raw, t);
}

function morphSourcePosition(bank, source, t) {
  const eased = smooth(clamp(bank.morph.progress, 0, 1));
  const fromBank = {
    ...bank,
    mode: bank.morph.from.mode,
    variant: bank.morph.from.variant || "primary",
    params: { ...bank.morph.from.params },
    morph: null,
  };
  const toBank = {
    ...bank,
    mode: bank.morph.to.mode,
    variant: bank.morph.to.variant || "primary",
    params: { ...bank.morph.to.params },
    morph: null,
  };
  const a = rawSourcePosition(fromBank, source, t);
  const b = rawSourcePosition(toBank, source, t);
  const x = lerp(a.x, b.x, eased);
  const y = lerp(a.y, b.y, eased);
  const z = lerp(a.z, b.z, eased);
  const azimuth = wrapDeg(radToDeg(Math.atan2(x, y)));
  const elevation = clamp(radToDeg(Math.atan2(z, Math.hypot(x, y))), -89, 89);
  const distance = clamp(Math.hypot(x, y, z), 0.1, 3);
  const raw = { x, y, z, azimuth, elevation, distance, gain: lerp(a.gain, b.gain, eased) };
  const analysisBank = effectiveBank(bank);
  return applyAnalysisInfluence(analysisBank, source, raw, t);
}

function rawSourcePosition(bank, source, t) {
  const p = bank.params;
  const offset = bank.motionOffset || makeGroupOffset(Math.max(0, Number(bank.id || 1) - 1));
  const phase = fract(source.id / 8 + Number(offset.phase || 0));
  const motion = p.motion;
  const width = 0.22 + p.width * 1.8;
  const disorder = p.disorder;
  const dev = p.development;
  const topo = p.topoWarp;
  const variantIndex = Math.max(0, VARIANTS.indexOf(bank.variant || "primary"));
  const variantOffset = variantIndex * 0.061;
  const variantAmt = variantIndex / Math.max(1, VARIANTS.length - 1);
  const baseAz = degToRad(wrapDeg(source.azimuth + Number(offset.azimuth || 0)));
  const baseEl = degToRad(clamp(source.elevation + Number(offset.elevation || 0), -85, 85));
  const base = {
    x: Math.sin(baseAz) * Math.cos(baseEl),
    y: Math.cos(baseAz) * Math.cos(baseEl),
    z: Math.sin(baseEl),
  };
  let x = 0;
  let y = 0;
  let z = 0;

  if (bank.mode === "orbit") {
    const cycles = 1 + Math.round(motion * 3);
    const a = TWO_PI * (phase + t * cycles + variantOffset);
    x = Math.sin(a) * width;
    y = Math.cos(a) * width;
    z = Math.sin(TWO_PI * (t * cycles + phase)) * (p.gravity - 0.5) * 1.5;
  } else if (bank.mode === "weave") {
    const cycles = 1 + Math.round(motion * 3);
    const a = TWO_PI * (t * cycles + phase + variantOffset);
    x = Math.sin(a) * width;
    y = Math.sin(TWO_PI * (t * (cycles + 1) - phase * 0.5 + variantOffset)) * width;
    z = Math.cos(TWO_PI * (t * cycles + phase * 0.25)) * (0.2 + p.gravity);
  } else if (bank.mode === "lattice") {
    const cycles = 1 + Math.round(motion * 4);
    x = Math.sin(TWO_PI * (t * cycles + phase)) * width;
    y = Math.sin(TWO_PI * (t * (cycles + 1) + phase * 0.5)) * width;
    z = Math.sin(TWO_PI * (t * Math.max(1, cycles - 1) - phase * 0.75)) * (0.15 + p.gravity);
    x = Math.sign(x) * Math.pow(Math.abs(x), 0.45);
    y = Math.sign(y) * Math.pow(Math.abs(y), 0.45);
    z = Math.sign(z) * Math.pow(Math.abs(z), 0.6);
  } else if (bank.mode === "frame") {
    const side = Math.floor(fract(phase * 4 + variantOffset) * 4);
    const q = pingpong01(t * (1 + Math.round(motion * 3)) + phase);
    const edge = q * 2 - 1;
    x = side < 2 ? edge * width : (side === 2 ? -width : width);
    y = side < 2 ? (side === 0 ? -width : width) : edge * width;
    z = (Math.round(fract(t * 2 + phase + variantOffset) * 2) - 0.5) * p.gravity;
  } else if (bank.mode === "trace") {
    const trail = smooth(pingpong01(t * (0.8 + motion * 4) + phase * 0.7));
    const a = TWO_PI * (trail + phase * 0.35 + variantOffset);
    const tail = smoothNoise(source.id * 23, t * 0.6, variantOffset);
    x = Math.sin(a) * width * (0.25 + trail);
    y = Math.cos(a * (1.0 + dev)) * width * (0.35 + tail);
    z = Math.sin(a + tail * TWO_PI) * p.gravity * 0.9;
  } else if (bank.mode === "pulse") {
    const steps = 3 + Math.round(motion * 9);
    const step = Math.floor(fract(t + phase + variantOffset) * steps) / steps;
    const gate = hashNoise(source.id * 19 + step * 101, t * steps, variantOffset) > 0.42 ? 1 : 0.25;
    const a = TWO_PI * (step + phase * (1 + Math.round(dev * 3)));
    x = Math.sin(a) * width * gate;
    y = Math.cos(a) * width * gate;
    z = (gate - 0.35) * p.gravity * Math.sin(TWO_PI * (step + phase));
  } else if (bank.mode === "suspend") {
    const a = TWO_PI * (phase + variantOffset + Math.sin(t * TWO_PI * (0.2 + motion)) * 0.025);
    const lift = 0.45 + p.gravity * 0.9;
    x = Math.sin(a) * width * (0.28 + dev * 0.26);
    y = Math.cos(a) * width * (0.28 + dev * 0.26);
    z = lift + Math.sin(TWO_PI * (t * (0.3 + motion) + phase)) * 0.12;
  } else if (bank.mode === "leap") {
    const jumps = 2 + Math.round(motion * 10);
    const cell = Math.floor(fract(t + phase * 0.21 + variantOffset) * jumps);
    const seed = source.id * 37 + cell * 17 + variantIndex * 13;
    x = (hashNoise(seed, cell, 1) * 2 - 1) * width;
    y = (hashNoise(seed, cell, 2) * 2 - 1) * width;
    z = (hashNoise(seed, cell, 3) * 2 - 1) * (0.2 + p.gravity);
  } else if (bank.mode === "field") {
    const a = TWO_PI * (phase + variantOffset);
    const pulse = Math.sin(TWO_PI * t * (0.5 + motion * 3) + source.id);
    x = Math.sin(a + pulse * 0.5) * width * (0.55 + dev);
    y = Math.cos(a * 1.5 + pulse) * width;
    z = Math.sin(a * 2 + t * TWO_PI) * p.gravity;
  } else if (bank.mode === "molec") {
    const pair = Math.floor((source.id - 1) / 2);
    const local = source.id % 2 ? -1 : 1;
    const c = TWO_PI * (pair / 4 + t * (0.15 + motion * 0.7) + variantOffset);
    const bond = 0.18 + dev * 0.42;
    x = Math.sin(c) * width * 0.62 + Math.cos(c * 2) * bond * local;
    y = Math.cos(c) * width * 0.62 + Math.sin(c * 2) * bond * local;
    z = Math.sin(c + local * Math.PI * 0.5) * p.gravity * 0.55;
  } else if (bank.mode === "fluid") {
    const flow = t * (0.4 + motion * 1.8);
    const a = TWO_PI * (phase + flow + variantOffset);
    const eddy = Math.sin(TWO_PI * (flow * 1.7 - phase * 0.9));
    x = Math.sin(a + eddy * 0.55) * width * (0.7 + dev * 0.3);
    y = Math.cos(a * 0.72 + eddy) * width * (0.55 + p.gravity * 0.35);
    z = Math.sin(TWO_PI * (flow + phase * 2)) * p.gravity * (0.35 + dev);
  } else if (bank.mode === "forsy") {
    const cycles = 1 + Math.round(motion * 2);
    const a = TWO_PI * (t * cycles + phase);
    const b = TWO_PI * (t * (cycles + 1 + Math.round(dev * 2)) - phase * 1.7);
    x = Math.sin(a) * width;
    y = Math.sin(b) * width * 0.72;
    z = Math.sin(a + b) * (0.1 + p.gravity);
  } else if (bank.mode === "flock") {
    const c = Math.sin(TWO_PI * t * (0.13 + motion * 0.24));
    const a = TWO_PI * phase + c;
    x = Math.sin(a) * width * (0.45 + dev);
    y = Math.cos(a) * width * (0.45 + dev);
    z = Math.sin(c + source.id) * p.gravity;
  } else if (bank.mode === "eco") {
    const herd = Math.sin(TWO_PI * t * (0.08 + motion * 0.18));
    const lane = Math.round((phase + herd * 0.1) * 5) / 5;
    const a = TWO_PI * (lane + variantOffset);
    const forage = smoothNoise(source.id * 11, t * (0.25 + motion), variantOffset);
    x = Math.sin(a) * width * (0.42 + forage * 0.48);
    y = Math.cos(a) * width * (0.42 + forage * 0.48);
    z = (forage - 0.35) * p.gravity * 0.8;
  } else if (bank.mode === "contact") {
    const partner = source.id % 2 ? 1 : -1;
    const q = Math.sin(TWO_PI * (t * (0.35 + motion) + Math.floor((source.id - 1) / 2) / 4));
    const a = TWO_PI * (phase + variantOffset + q * 0.08);
    x = Math.sin(a) * width * (0.5 + partner * q * 0.18);
    y = Math.cos(a) * width * (0.5 - partner * q * 0.18);
    z = (q * partner * 0.35 + 0.1) * p.gravity;
  } else if (bank.mode === "march") {
    const rank = Math.floor((source.id - 1) / 2);
    const file = (source.id - 1) % 2;
    const step = Math.floor(fract(t * (1 + motion * 4) + variantOffset) * 4) / 3;
    x = ((file ? 0.5 : -0.5) + (step - 0.5) * dev) * width;
    y = ((rank / 3) * 2 - 1) * width * (0.55 + p.gravity * 0.15);
    z = Math.sin(TWO_PI * (step + phase)) * p.gravity * 0.18;
  } else if (bank.mode === "procession") {
    const q = fract(t * (0.25 + motion) + phase + variantOffset);
    const spiral = q * TWO_PI * (1.0 + dev * 2.5);
    const r = width * (0.2 + q * 0.8);
    x = Math.sin(spiral) * r;
    y = Math.cos(spiral) * r;
    z = (q - 0.5) * p.gravity * 1.15;
  } else if (bank.mode === "xenak") {
    const u = fract(t * (0.25 + motion * 1.4) + phase + variantOffset);
    const ruled = (phase * 2 - 1) * width;
    const helix = TWO_PI * (u + phase * (1 + Math.round(dev * 4)));
    x = lerp(ruled, Math.sin(helix) * width, 0.45 + dev * 0.35);
    y = (u * 2 - 1) * width;
    z = Math.cos(helix) * p.gravity;
  } else if (bank.mode === "cardew") {
    const cell = Math.floor(fract(t * (2 + motion * 12) + phase + variantOffset) * 12);
    const sparse = hashNoise(source.id * 13 + cell, cell, variantIndex);
    const line = Math.round((phase + sparse * dev) * 5) / 5;
    x = (line * 2 - 1) * width;
    y = (hashNoise(cell * 23 + source.id, cell, 2) * 2 - 1) * width * (0.3 + sparse * 0.7);
    z = (sparse > 0.62 ? sparse - 0.5 : 0) * p.gravity * 1.4;
  } else if (bank.mode === "path") {
    const q = smooth(pingpong01(t * (1 + Math.round(motion * 3)) + phase * 0.5 + variantOffset));
    x = (q * 2 - 1) * width;
    y = Math.sin(q * TWO_PI * (1 + Math.round(dev * 4))) * width * 0.42;
    z = Math.cos(q * TWO_PI) * p.gravity;
  } else {
    const n1 = smoothNoise(source.id * 17, t, variantOffset);
    const n2 = smoothNoise(source.id * 31, t + 0.2, variantOffset);
    const n3 = smoothNoise(source.id * 47, t + 0.4, variantOffset);
    x = (n1 * 2 - 1) * width;
    y = (n2 * 2 - 1) * width;
    z = (n3 * 2 - 1) * (0.2 + p.gravity);
  }

  if (bank.variant === "wide") {
    x *= 1.28;
    y *= 1.28;
    z *= 1.08;
  } else if (bank.variant === "fold") {
    x = Math.abs(x) * (source.id % 2 ? -1 : 1);
  } else if (bank.variant === "canon") {
    const delay = (source.id - 1) * 0.017 * (1 + dev * 3);
    const q = rawSourcePosition({ ...bank, variant: "primary" }, source, fract(t - delay + 1));
    x = q.x / Math.max(0.1, source.distance);
    y = q.y / Math.max(0.1, source.distance);
    z = q.z / Math.max(0.1, source.distance);
  } else if (bank.variant === "ribbon") {
    const r = Math.hypot(x, y);
    const a = Math.atan2(x, y) + Math.sin(TWO_PI * (t + phase)) * 0.18;
    x = Math.sin(a) * r;
    y = Math.cos(a) * r * 0.62;
  } else if (bank.variant === "gate") {
    const gate = Math.floor(fract(t * (2 + motion * 8) + phase) * 2);
    const scale = gate ? 1 : 0.18;
    x *= scale;
    y *= scale;
    z *= scale;
  } else if (bank.variant === "mirror") {
    if (source.id % 2 === 0) x = -x;
  } else if (bank.variant === "surge") {
    const surge = 0.55 + smooth(Math.sin(TWO_PI * (t * (0.4 + motion) + phase)) * 0.5 + 0.5) * 0.75;
    x *= surge;
    y *= surge;
    z *= surge;
  } else if (bank.variant === "tether") {
    const pull = 0.18 + dev * 0.36;
    x = lerp(x, base.x * width, pull);
    y = lerp(y, base.y * width, pull);
    z = lerp(z, base.z * (0.25 + p.gravity), pull);
  } else if (bank.variant === "vortex") {
    const r = Math.hypot(x, y);
    const a = Math.atan2(x, y) + t * TWO_PI * (0.25 + motion) + z * 0.2;
    x = Math.sin(a) * r;
    y = Math.cos(a) * r;
  } else if (bank.variant === "yield") {
    const sink = smooth(Math.sin(TWO_PI * (t * (0.3 + motion) + phase)) * 0.5 + 0.5);
    x *= 0.65 + sink * 0.25;
    y *= 0.65 + sink * 0.25;
    z = lerp(z, -0.2 * p.gravity, sink * 0.45);
  } else if (bank.variant === "still") {
    x = lerp(x, base.x * width * 0.42, 0.78);
    y = lerp(y, base.y * width * 0.42, 0.78);
    z = lerp(z, base.z * (0.2 + p.gravity) * 0.32, 0.78);
  }

  const jitter = disorder * 0.28;
  x += (smoothNoise(source.id, t * 1.7, 1.1) * 2 - 1) * jitter;
  y += (smoothNoise(source.id, t * 1.3, 2.2) * 2 - 1) * jitter;
  z += (smoothNoise(source.id, t * 1.1, 3.3) * 2 - 1) * jitter;
  if (topo > 0) {
    const twist = Math.atan2(x, y) + topo * Math.sin(t * TWO_PI + z) * 1.4;
    const r = Math.hypot(x, y);
    x = Math.sin(twist) * r;
    y = Math.cos(twist) * r;
  }

  const baseBlend = clamp(0.2 + (1 - motion) * 0.45, 0.2, 0.65);
  x = lerp(x, base.x * width, baseBlend);
  y = lerp(y, base.y * width, baseBlend);
  z = lerp(z, base.z * (0.25 + p.gravity), baseBlend);

  const groupDistance = Number(offset.distance || 1);
  x *= source.distance * groupDistance;
  y *= source.distance * groupDistance;
  z *= source.distance * groupDistance;
  const azimuth = wrapDeg(radToDeg(Math.atan2(x, y)));
  const elevation = clamp(radToDeg(Math.atan2(z, Math.hypot(x, y))), -89, 89);
  const distance = clamp(Math.hypot(x, y, z), 0.1, 3);
  return { x, y, z, azimuth, elevation, distance, gain: source.enabled ? source.gain : 0 };
}

function bankAnalysis(bank, t, raw = true) {
  const positions = bank.sources
    .filter((s) => s.enabled)
    .map((s) => (raw ? rawSourcePosition(bank, s, t) : sourcePosition(bank, s, t)));
  if (!positions.length) {
    return { centroid: { x: 0, y: 0, z: 0 }, spread: 0, activity: 0, positions };
  }
  const centroid = positions.reduce((a, p) => ({ x: a.x + p.x, y: a.y + p.y, z: a.z + p.z }), { x: 0, y: 0, z: 0 });
  centroid.x /= positions.length;
  centroid.y /= positions.length;
  centroid.z /= positions.length;
  const spread = positions.reduce((a, p) => a + Math.hypot(p.x - centroid.x, p.y - centroid.y, p.z - centroid.z), 0) / positions.length;
  const t2 = (t + 0.01) % 1;
  const next = bank.sources
    .filter((s) => s.enabled)
    .map((s) => rawSourcePosition(bank, s, t2));
  const activity = positions.reduce((a, p, i) => a + Math.hypot(p.x - next[i].x, p.y - next[i].y, p.z - next[i].z), 0) / positions.length / 0.01;
  return { centroid, spread, activity, positions };
}

function analysisBanksForScope() {
  if (ui.analysisScope.value === "active") return [effectiveBank(activeBank())];
  return state.banks.map(effectiveBank);
}

function scopedAnalysis(t, raw = true) {
  const positions = [];
  const nextPositions = [];
  const t2 = (t + 0.01) % 1;
  analysisBanksForScope().forEach((bank) => {
    bank.sources.filter((s) => s.enabled).forEach((source) => {
      positions.push(raw ? rawSourcePosition(bank, source, t) : sourcePosition(bank, source, t));
      nextPositions.push(rawSourcePosition(bank, source, t2));
    });
  });
  if (!positions.length) {
    return { centroid: { x: 0, y: 0, z: 0 }, spread: 0, activity: 0, positions };
  }
  const centroid = positions.reduce((a, p) => ({ x: a.x + p.x, y: a.y + p.y, z: a.z + p.z }), { x: 0, y: 0, z: 0 });
  centroid.x /= positions.length;
  centroid.y /= positions.length;
  centroid.z /= positions.length;
  const spread = positions.reduce((a, p) => a + Math.hypot(p.x - centroid.x, p.y - centroid.y, p.z - centroid.z), 0) / positions.length;
  const activity = positions.reduce((a, p, i) => a + Math.hypot(p.x - nextPositions[i].x, p.y - nextPositions[i].y, p.z - nextPositions[i].z), 0) / positions.length / 0.01;
  return { centroid, spread, activity, positions };
}

function applyAnalysisInfluence(bank, source, pos, t) {
  const influence = Number(ui.analysisInfluence.value || 0);
  if (influence <= 0 || !source.enabled) return pos;
  const analysis = ui.analysisScope.value === "active" ? bankAnalysis(bank, t, true) : scopedAnalysis(t, true);
  const c = analysis.centroid;
  const pull = Number(ui.centroidPull.value || 0) * influence * 0.22;
  let x = pos.x + (c.x - pos.x) * pull;
  let y = pos.y + (c.y - pos.y) * pull;
  let z = pos.z + (c.z - pos.z) * pull;

  const target = Number(ui.spreadTarget.value || 1.05);
  const spread = Math.max(0.001, analysis.spread);
  const spreadScale = lerp(1, target / spread, influence * 0.28);
  x = c.x + (x - c.x) * spreadScale;
  y = c.y + (y - c.y) * spreadScale;
  z = c.z + (z - c.z) * spreadScale;

  const damping = Number(ui.activityDamping.value || 0) * influence;
  if (damping > 0) {
    const previous = rawSourcePosition(bank, source, (t - 0.016 + 1) % 1);
    x = lerp(x, previous.x, damping * 0.42);
    y = lerp(y, previous.y, damping * 0.42);
    z = lerp(z, previous.z, damping * 0.42);
  }

  const azimuth = wrapDeg(radToDeg(Math.atan2(x, y)));
  const elevation = clamp(radToDeg(Math.atan2(z, Math.hypot(x, y))), -89, 89);
  const distance = clamp(Math.hypot(x, y, z), 0.1, 3);
  return { x, y, z, azimuth, elevation, distance, gain: pos.gain };
}

function smooth(t) {
  return t * t * (3 - 2 * t);
}

function pingpong01(t) {
  const u = ((t % 2) + 2) % 2;
  return u <= 1 ? u : 2 - u;
}

function hashNoise(seed, t, salt) {
  const x = Math.sin(seed * 12.9898 + Math.floor(t * 32) * 78.233 + salt * 37.719) * 43758.5453;
  const y = Math.sin(seed * 4.898 + Math.floor(t * 32 + 1) * 27.233 + salt * 19.719) * 24634.6345;
  const f = (t * 32) % 1;
  return lerp(x - Math.floor(x), y - Math.floor(y), smooth(f));
}

function smoothNoise(seed, t, salt) {
  const a = TWO_PI * (t + seed * 0.071 + salt * 0.13);
  const b = TWO_PI * (t * 2 + seed * 0.037 - salt * 0.19);
  const c = TWO_PI * (t * 3 - seed * 0.019 + salt * 0.07);
  return clamp(0.5 + 0.26 * Math.sin(a) + 0.16 * Math.sin(b) + 0.08 * Math.cos(c), 0, 1);
}

function project(point) {
  const az = degToRad(Number(ui.cameraAz.value));
  const elv = degToRad(Number(ui.cameraEl.value));
  const zoom = Number(ui.zoom.value);
  const ca = Math.cos(az);
  const sa = Math.sin(az);
  const ce = Math.cos(elv);
  const se = Math.sin(elv);
  let x = point.x * ca - point.y * sa;
  let y = point.x * sa + point.y * ca;
  let z = point.z;
  let yy = y * ce - z * se;
  let zz = y * se + z * ce;
  const scale = Math.min(canvas.width, canvas.height) * 0.26 * zoom;
  return {
    x: canvas.width * 0.5 + x * scale,
    y: canvas.height * 0.52 - zz * scale,
    depth: yy,
  };
}

function draw() {
  resizeCanvas();
  const w = canvas.width;
  const h = canvas.height;
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = "#050707";
  ctx.fillRect(0, 0, w, h);
  drawGrid();
  drawAnalysis();
  drawBanks();
  requestAnimationFrame(tick);
}

function drawGrid() {
  ctx.save();
  ctx.lineWidth = 1;
  ctx.strokeStyle = "#172020";
  for (let r = 0.5; r <= 2; r += 0.5) {
    const pts = [];
    for (let i = 0; i <= 96; i++) {
      const a = (i / 96) * TWO_PI;
      pts.push(project({ x: Math.sin(a) * r, y: Math.cos(a) * r, z: 0 }));
    }
    pathPoints(pts);
    ctx.stroke();
  }
  ctx.strokeStyle = "#253030";
  axisLine({ x: -2.1, y: 0, z: 0 }, { x: 2.1, y: 0, z: 0 });
  axisLine({ x: 0, y: -2.1, z: 0 }, { x: 0, y: 2.1, z: 0 });
  axisLine({ x: 0, y: 0, z: -1.2 }, { x: 0, y: 0, z: 1.2 });
  ctx.restore();
}

function axisLine(a, b) {
  const p = project(a);
  const q = project(b);
  ctx.beginPath();
  ctx.moveTo(p.x, p.y);
  ctx.lineTo(q.x, q.y);
  ctx.stroke();
}

function pathPoints(pts) {
  ctx.beginPath();
  pts.forEach((p, i) => (i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)));
}

function drawBanks() {
  const t = currentT();
  state.banks.forEach((bank, bi) => {
    const drawBank = effectiveBank(bank);
    const alpha = bi === state.activeBank ? 1 : 0.32;
    if (ui.showTrails.checked) drawTrails(drawBank, alpha);
    drawBank.sources.forEach((source, si) => {
      const pos = sourcePosition(drawBank, source, t);
      const p = project(pos);
      const radius = (bi === state.activeBank && si === state.selectedSource ? 11 : 7) * (window.devicePixelRatio || 1);
      ctx.save();
      ctx.globalAlpha = alpha;
      ctx.fillStyle = source.enabled ? COLORS[si] : "#404848";
      ctx.strokeStyle = bi === state.activeBank ? "#f2c56e" : "#708080";
      ctx.lineWidth = 1.5 * (window.devicePixelRatio || 1);
      ctx.beginPath();
      ctx.arc(p.x, p.y, radius, 0, TWO_PI);
      ctx.fill();
      ctx.stroke();
      if (ui.showLabels.checked || (bi === state.activeBank && si === state.selectedSource)) {
        ctx.fillStyle = "#d7dddd";
        ctx.font = `${12 * (window.devicePixelRatio || 1)}px Menlo, monospace`;
        ctx.fillText(`${bank.id}.${source.id}`, p.x + radius + 4, p.y - radius);
      }
      ctx.restore();
    });
  });
}

function drawTrails(bank, alpha) {
  const t = currentT();
  bank.sources.forEach((source, si) => {
    const pts = [];
    const horizon = 0.28;
    const steps = 72;
    for (let i = 0; i <= steps; i++) {
      const tt = t + (i / steps) * horizon;
      if (tt > 1) break;
      pts.push(project(sourcePosition(bank, source, tt)));
    }
    drawTrailSegment(pts, si, alpha);
  });
}

function drawTrailSegment(pts, sourceIndex, alpha) {
  if (pts.length < 2) return;
  ctx.save();
  ctx.globalAlpha = 0.16 * alpha;
  ctx.strokeStyle = COLORS[sourceIndex];
  ctx.lineWidth = 1 * (window.devicePixelRatio || 1);
  ctx.beginPath();
  for (let i = 0; i < pts.length; i++) {
    const p = pts[i];
    const prev = pts[i - 1];
    if (prev && Math.hypot(p.x - prev.x, p.y - prev.y) > Math.min(canvas.width, canvas.height) * 0.35) {
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(p.x, p.y);
    } else if (i === 0) {
      ctx.moveTo(p.x, p.y);
    } else {
      ctx.lineTo(p.x, p.y);
    }
  }
  ctx.stroke();
  ctx.restore();
}

function drawAnalysis() {
  if (!ui.showAnalysis.checked) return;
  const t = currentT();
  const analysis = scopedAnalysis(t, false);
  const positions = analysis.positions;
  if (!positions.length) return;
  const centroid = analysis.centroid;
  const spread = analysis.spread;
  const activity = analysis.activity;
  drawAnalysisConnections(positions);
  if (ui.showCentroid.checked) {
    const c = project(centroid);
    ctx.save();
    ctx.strokeStyle = "#f2c56e";
    ctx.fillStyle = "rgba(242, 197, 110, 0.09)";
    ctx.lineWidth = 1.5 * (window.devicePixelRatio || 1);
    ctx.beginPath();
    ctx.arc(c.x, c.y, Math.max(12, spread * Math.min(canvas.width, canvas.height) * 0.13), 0, TWO_PI);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = "#f2c56e";
    ctx.fillRect(c.x - 4, c.y - 4, 8, 8);
    ctx.restore();
  }
  const scope = ui.analysisScope.value === "active" ? "active" : `${state.banks.length} groups`;
  ui.analysisReadout.textContent = `${scope} | centroid ${centroid.x.toFixed(2)} / ${centroid.y.toFixed(2)} / ${centroid.z.toFixed(2)} | spread ${spread.toFixed(2)} | activity ${activity.toFixed(2)}`;
}

function drawAnalysisConnections(positions) {
  const dpr = window.devicePixelRatio || 1;
  const projected = positions.map(project);
  const neighborCount = Math.max(1, Math.round(Number(ui.neighborLinks.value || 2)));
  const edges = new Map();
  for (let i = 0; i < positions.length; i++) {
    const neighbors = [];
    for (let j = 0; j < positions.length; j++) {
      if (i === j) continue;
      const a = positions[i];
      const b = positions[j];
      const d = Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z);
      neighbors.push({ j, d });
    }
    neighbors
      .sort((a, b) => a.d - b.d)
      .slice(0, neighborCount)
      .forEach(({ j, d }) => {
        const a = Math.min(i, j);
        const b = Math.max(i, j);
        const key = `${a}:${b}`;
        if (!edges.has(key) || d < edges.get(key).d) edges.set(key, { a, b, d });
      });
  }
  ctx.save();
  ctx.lineWidth = 1 * dpr;
  edges.forEach((edge) => {
    const strength = clamp(1 - edge.d / 2.35, 0.08, 1);
    ctx.globalAlpha = 0.12 + strength * 0.44;
    ctx.strokeStyle = strength > 0.58 ? "#f2c56e" : "#7ed8f0";
    ctx.beginPath();
    ctx.moveTo(projected[edge.a].x, projected[edge.a].y);
    ctx.lineTo(projected[edge.b].x, projected[edge.b].y);
    ctx.stroke();
  });
  ctx.restore();
}

function currentT() {
  if (state.playing) return state.playT;
  return state.playT;
}

function tick(now = performance.now()) {
  state.banks.forEach((bank) => {
    if (!bank.morph) return;
    bank.morph.progress = clamp((now - bank.morph.started) / (bank.morph.duration * 1000), 0, 1);
    if (bank.morph.progress >= 1) commitMorph(bank);
  });
  if (reaperLink.enabled) {
    pollReaperPlayhead(now);
    applyReaperTransport(now);
  } else if (state.playing) {
    const dur = Number(ui.duration.value);
    state.playT = pingpong01((now - state.playStart) / 1000 / dur);
    if (ui.autoNext.checked && !activeBank().morph && now >= state.nextSceneAt) {
      startSceneMorph();
    }
  }
  if (!reaperLink.enabled) ui.timeReadout.textContent = `${(state.playT * Number(ui.duration.value)).toFixed(2)}s`;
  updateSceneDisplays();
  draw();
}

function applyReaperTransport(now = performance.now()) {
  const duration = Math.max(0.001, Number(reaperLink.duration || ui.duration.value || 1));
  let position = Number(reaperLink.basePosition || 0);
  if (reaperLink.playing) {
    position += (now - reaperLink.receivedAt) / 1000;
  }
  const targetT = clamp(Number(reaperLink.baseT || 0) + (position - Number(reaperLink.basePosition || 0)) / duration, 0, 1);
  const diff = targetT - reaperLink.displayT;
  if (!reaperLink.playing || Math.abs(diff) > 0.04) {
    reaperLink.displayT = targetT;
  } else {
    reaperLink.displayT += diff * 0.18;
  }
  state.playT = clamp(reaperLink.displayT, 0, 1);
  ui.timeReadout.textContent = `${position.toFixed(2)}s REAPER${reaperLink.playing ? "" : " paused"}`;
}

function syncPanelFromBank() {
  const bank = activeBank();
  const shownBank = effectiveBank(bank);
  ui.bankMode.value = shownBank.mode;
  ui.sceneMode.value = shownBank.variant || "primary";
  ui.morphTarget.value = nextSceneKey(bank.scene);
  ui.sceneName.value = bank.scenes[bank.scene]?.name || bank.scene.toUpperCase();
  if (bank.scenes[bank.scene]) {
    ui.sceneHold.value = Number(bank.scenes[bank.scene].hold ?? ui.sceneHold.value);
    ui.morphDuration.value = Number(bank.scenes[bank.scene].morph ?? ui.morphDuration.value);
  }
  for (const key of Object.keys(shownBank.params)) ui[key].value = shownBank.params[key];
  const source = shownBank.sources[state.selectedSource];
  ui.sourceSelect.value = String(state.selectedSource);
  ui.sourceGain.value = source.gain;
  ui.sourceDistance.value = source.distance;
  ui.toggleSource.textContent = source.enabled ? "Mute Source" : "Unmute Source";
  renderBanks();
  renderScenes();
  updateAllRangeFills();
}

function captureScene(bank, silent = true) {
  if (bank.morph) commitMorph(bank);
  bank.scenes[bank.scene] = {
    name: ui.sceneName.value || bank.scene.toUpperCase(),
    mode: bank.mode,
    variant: bank.variant || "primary",
    params: { ...bank.params },
    hold: Number(ui.sceneHold.value || 0),
    morph: Number(ui.morphDuration.value || 4),
  };
  if (!silent) ui.analysisReadout.textContent = `captured motion scene ${bank.scene.toUpperCase()}`;
}

function syncBankFromPanel() {
  const bank = activeBank();
  if (bank.morph) bank.morph = null;
  bank.mode = ui.bankMode.value;
  bank.variant = ui.sceneMode.value;
  for (const key of Object.keys(bank.params)) bank.params[key] = Number(ui[key].value);
  propagateMotionFrom(bank);
  captureScene(bank);
  updateAllRangeFills();
}

function syncSourceFromPanel() {
  const bank = activeBank();
  const source = bank.sources[state.selectedSource];
  source.gain = Number(ui.sourceGain.value);
  source.distance = Number(ui.sourceDistance.value);
  updateAllRangeFills();
}

function renderBanks() {
  ui.bankList.innerHTML = "";
  state.banks.forEach((bank, i) => {
    const b = document.createElement("button");
    b.className = `bank-button${i === state.activeBank ? " active" : ""}`;
    b.type = "button";
    b.textContent = bank.name || `Group ${bank.id}`;
    b.addEventListener("click", () => {
      state.activeBank = i;
      syncPanelFromBank();
    });
    ui.bankList.appendChild(b);
  });
  ui.addBank.disabled = state.banks.length >= MAX_BANKS;
  ui.addBank.textContent = state.banks.length >= MAX_BANKS ? "8 Groups Max" : "Add Group";
}

function renderScenes() {
  const bank = activeBank();
  ui.sceneGrid.innerHTML = "";
  SCENES.forEach((key) => {
    const b = document.createElement("button");
    b.type = "button";
    b.dataset.scene = key;
    b.style.setProperty("--scene-color", SCENE_COLORS[SCENES.indexOf(key)] || "#5aa8c7");
    b.innerHTML = `<span>${key.toUpperCase()}</span>`;
    b.addEventListener("click", () => {
      captureScene(activeBank());
      if (activeBank().morph) activeBank().morph = null;
      if (activeBank().scenes[key]) {
        activeBank().scene = key;
        applyScene(activeBank().scenes[key]);
      } else {
        activeBank().scene = key;
        captureScene(activeBank());
        propagateMotionFrom(activeBank());
      }
      syncPanelFromBank();
    });
    ui.sceneGrid.appendChild(b);
  });
  updateSceneDisplays();
}

function sceneVisualState(key) {
  const bank = activeBank();
  const targetKey = bank.morph ? bank.morph.targetKey : ui.morphTarget.value || nextSceneKey(bank.scene);
  const stored = !!bank.scenes[key];
  const active = key === bank.scene && !bank.morph;
  const target = key === targetKey && key !== bank.scene;
  const morphing = !!(bank.morph && (key === bank.scene || key === targetKey));
  const progress = bank.morph && key === targetKey ? `${(bank.morph.progress * 100).toFixed(1)}%` : "0%";
  return { stored, active, target, morphing, progress, targetKey };
}

function applySceneVisual(element, key, baseClass) {
  const state = sceneVisualState(key);
  element.className = [
    baseClass,
    state.stored ? "stored" : "",
    state.active ? "active" : "",
    state.target ? "target" : "",
    state.morphing ? "morphing" : "",
  ].filter(Boolean).join(" ");
  element.style.setProperty("--progress", state.progress);
  const label = element.querySelector("span");
  if (label) label.textContent = `${key.toUpperCase()}${state.stored ? "" : " -"}`;
}

function updateSceneDisplays() {
  const bank = activeBank();
  const targetKey = bank.morph ? bank.morph.targetKey : ui.morphTarget.value || nextSceneKey(bank.scene);
  ui.motionSceneTitle.textContent = bank.morph
    ? `Motion Scene ${bank.scene.toUpperCase()} -> ${targetKey.toUpperCase()}`
    : `Motion Scene ${bank.scene.toUpperCase()}`;
  ui.sceneGrid.querySelectorAll("[data-scene]").forEach((button) => {
    applySceneVisual(button, button.dataset.scene, "scene-button");
  });
}

function applyScene(scene) {
  const bank = activeBank();
  bank.morph = null;
  bank.mode = scene.mode;
  bank.variant = scene.variant || "primary";
  bank.params = { ...scene.params };
  ui.sceneHold.value = Number(scene.hold ?? ui.sceneHold.value);
  ui.morphDuration.value = Number(scene.morph ?? ui.morphDuration.value);
  propagateMotionFrom(bank);
}

function storeScene() {
  const bank = activeBank();
  captureScene(bank, false);
  propagateMotionFrom(bank);
  syncPanelFromBank();
}

function startSceneMorph(targetKey = null) {
  const bank = activeBank();
  captureScene(bank);
  targetKey = targetKey || nextSceneKey(bank.scene, ui.sceneLoop.checked);
  if (!targetKey) {
    ui.autoNext.checked = false;
    ui.analysisReadout.textContent = "auto next stopped at scene H";
    return;
  }
  ui.morphTarget.value = targetKey;
  if (!bank.scenes[targetKey]) {
    const current = snapshotBank(effectiveBank(bank));
    current.name = targetKey.toUpperCase();
    current.scene = targetKey;
    current.hold = Number(ui.sceneHold.value || 0);
    current.morph = Number(ui.morphDuration.value || 4);
    bank.scenes[targetKey] = current;
  }
  const scene = bank.scenes[targetKey];
  const currentScene = bank.scenes[bank.scene] || {};
  const duration = Math.max(0.1, Number(currentScene.morph ?? ui.morphDuration.value ?? 4));
  const targetHold = Math.max(0, Number(scene.hold ?? ui.sceneHold.value ?? 0));
  const started = performance.now();
  state.banks.forEach((group, index) => {
    const target = snapshotBank(effectiveBank(group));
    target.mode = scene.mode;
    target.scene = targetKey;
    target.variant = scene.variant || "primary";
    target.params = { ...scene.params };
    target.hold = Number(scene.hold ?? targetHold);
    target.morph = Number(scene.morph ?? duration);
    group.morph = {
      targetKey,
      from: snapshotBank(effectiveBank(group)),
      to: target,
      progress: 0,
      duration,
      started,
    };
  });
  state.nextSceneAt = performance.now() + (duration + targetHold) * 1000;
  updateSceneDisplays();
}

function randomizeScene() {
  const bank = activeBank();
  state.generateSeed += 1;
  const seed = state.generateSeed * 37 + Math.max(0, VARIANTS.indexOf(bank.variant || "primary")) * 11 + bank.id * 17;
  applyGeneratedMotion(bank, seed, ui.varySceneBanks.checked);
  ui.sceneName.value = generatedSceneName(seed, bank.mode, SCENES.indexOf(bank.scene));
  storeScene();
  syncPanelFromBank();
}

function generatedSceneName(seed, mode = "", index = -1) {
  const bankNames = SCENE_NAMES_BY_BANK[mode];
  if (bankNames && index >= 0) return `${mode.toUpperCase()} ${bankNames[index % bankNames.length]}`;
  const a = SCENE_NAME_A[Math.abs(seed) % SCENE_NAME_A.length];
  const b = SCENE_NAME_B[Math.abs(Math.floor(seed / SCENE_NAME_A.length) + 7) % SCENE_NAME_B.length];
  return `${a} ${b}`;
}

function applyGeneratedMotion(bank, seed, allowBankChange = false) {
  if (allowBankChange) {
    bank.mode = MOTION_BANKS[Math.abs(seed) % MOTION_BANKS.length];
  }
  bank.variant = VARIANTS[seed % VARIANTS.length];
  Object.keys(bank.params).forEach((key, i) => {
    const base = hashNoise(seed + i * 13, state.playT + i * 0.071, i);
    const accent = hashNoise(seed + i * 29, state.playT * 0.37 + i * 0.113, i + 9);
    bank.params[key] = clamp(0.07 + base * 0.68 + accent * 0.22, 0, 1);
  });
}

function generatedTiming(seed, index) {
  const holdNoise = hashNoise(seed + 401, index * 0.137 + state.playT, 3);
  const morphNoise = hashNoise(seed + 809, index * 0.191 + state.playT, 7);
  return {
    hold: Number((0.4 + holdNoise * 5.6).toFixed(1)),
    morph: Number((1.2 + morphNoise * 10.8).toFixed(1)),
  };
}

function generateAllScenes() {
  const bank = activeBank();
  state.generateSeed += 1;
  const baseSeed = state.generateSeed * 101 + bank.id * 19;
  const previousScene = bank.scene;
  state.banks.forEach((group, index) => {
    group.motionOffset = makeGroupOffset(index, baseSeed + index * 53);
  });
  SCENES.forEach((key, index) => {
    const sceneSeed = baseSeed + index * 37;
    const timing = generatedTiming(sceneSeed, index);
    bank.scene = key;
    ui.sceneHold.value = timing.hold;
    ui.morphDuration.value = timing.morph;
    applyGeneratedMotion(bank, sceneSeed, ui.varySceneBanks.checked);
    ui.sceneName.value = generatedSceneName(sceneSeed, bank.mode, index);
    captureScene(bank);
  });
  bank.scene = previousScene;
  applyScene(bank.scenes[bank.scene]);
  ui.analysisReadout.textContent = `generated motion scenes A-H${ui.varySceneBanks.checked ? " with varied banks" : ` in ${bank.mode}`}`;
  syncPanelFromBank();
}

function makeExport() {
  if (!activeBank().morph) syncBankFromPanel();
  const duration = Number(ui.duration.value);
  const pointRate = Number(ui.pointRate.value);
  const pointCount = Math.max(2, Math.round(duration * pointRate));
  return {
    tool: "s3g-mc Mover",
    format: "s3g_mc_mover_v1",
    version: 1,
    target: "s3g 8ch 3OA Object Encoder",
    order: 3,
    duration,
    point_rate: pointRate,
    browser_state: {
      active_group: state.activeBank + 1,
      selected_source: state.selectedSource + 1,
      morph_duration: Number(ui.morphDuration.value),
      hold_duration: Number(ui.sceneHold.value),
      loop_scenes: ui.sceneLoop.checked,
      vary_scene_banks: ui.varySceneBanks.checked,
      camera_azimuth: Number(ui.cameraAz.value),
      camera_elevation: Number(ui.cameraEl.value),
      zoom: Number(ui.zoom.value),
      analysis_scope: ui.analysisScope.value,
      neighbor_links: Number(ui.neighborLinks.value),
      analysis_influence: Number(ui.analysisInfluence.value),
      centroid_pull: Number(ui.centroidPull.value),
      spread_target: Number(ui.spreadTarget.value),
      activity_damping: Number(ui.activityDamping.value),
      show_analysis: ui.showAnalysis.checked,
      show_centroid: ui.showCentroid.checked,
      show_path_preview: ui.showTrails.checked,
      show_labels: ui.showLabels.checked,
    },
    banks: state.banks.map((bank) => {
      const exportBank = effectiveBank(bank);
      return {
      bank: bank.id,
      name: bank.name,
      motion_offset: { ...(exportBank.motionOffset || makeGroupOffset(bank.id - 1)) },
      mode: exportBank.mode,
      scene: exportBank.scene,
      variant: exportBank.variant || "primary",
      params: exportBank.params,
      scenes: serializeScenes(bank.scenes),
      analysis: {
        influence: Number(ui.analysisInfluence.value),
        centroid_pull: Number(ui.centroidPull.value),
        spread_target: Number(ui.spreadTarget.value),
        activity_damping: Number(ui.activityDamping.value),
      },
      sources: exportBank.sources.map((source) => ({ ...source })),
      automation: exportBank.sources.map((source) => ({
        source: source.id,
        enabled: source.enabled,
        points: Array.from({ length: pointCount }, (_, i) => {
          const t = pointCount <= 1 ? 0 : i / (pointCount - 1);
          const p = sourcePosition(exportBank, source, t);
          return {
            t,
            azimuth: Number(p.azimuth.toFixed(4)),
            elevation: Number(p.elevation.toFixed(4)),
            distance: Number(p.distance.toFixed(4)),
            gain: Number(p.gain.toFixed(4)),
          };
        }),
      })),
      };
    }),
  };
}

function exportJson() {
  const data = JSON.stringify(makeExport(), null, 2);
  const blob = new Blob([data], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `s3g-mc-mover-${Date.now()}.json`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

function importJsonFile(file) {
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    try {
      loadMoverJson(JSON.parse(String(reader.result || "")));
    } catch (error) {
      ui.analysisReadout.textContent = `could not import JSON: ${error.message}`;
    }
  };
  reader.readAsText(file);
}

function loadMoverJson(data) {
  if (!data || data.format !== "s3g_mc_mover_v1" || !Array.isArray(data.banks)) {
    throw new Error("not a s3g-mc Mover JSON file");
  }
  state.playing = false;
  state.playT = 0;
  state.generateSeed = 0;
  state.banks = data.banks.slice(0, MAX_BANKS).map((entry, i) => {
    const bank = makeBank(i, entry.name || `Group ${i + 1}`);
    bank.id = i + 1;
    bank.motionOffset = normalizeGroupOffset(entry.motion_offset || entry.motionOffset, i);
    bank.mode = MOTION_BANKS.includes(entry.mode) ? entry.mode : "orbit";
    bank.scene = SCENES.includes(entry.scene) ? entry.scene : "a";
    bank.variant = VARIANTS.includes(entry.variant) ? entry.variant : "primary";
    bank.params = normalizeParams(entry.params);
    bank.sources = Array.from({ length: 8 }, (_, si) => normalizeSource((entry.sources || [])[si], si));
    bank.scenes = {};
    Object.keys(entry.scenes || {}).forEach((key) => {
      if (!SCENES.includes(key)) return;
      const scene = entry.scenes[key];
      bank.scenes[key] = {
        name: scene.name || key.toUpperCase(),
        mode: scene.mode || bank.mode,
        variant: VARIANTS.includes(scene.variant) ? scene.variant : bank.variant,
        params: normalizeParams(scene.params || bank.params),
        hold: Number(scene.hold ?? data.browser_state?.hold_duration ?? 1),
        morph: Number(scene.morph ?? data.browser_state?.morph_duration ?? 4),
      };
    });
    if (!bank.scenes[bank.scene]) {
      bank.scenes[bank.scene] = {
        name: bank.scene.toUpperCase(),
        mode: bank.mode,
        variant: bank.variant,
        params: { ...bank.params },
        hold: Number(data.browser_state?.hold_duration ?? 1),
        morph: Number(data.browser_state?.morph_duration ?? 4),
      };
    }
    return bank;
  });
  if (!state.banks.length) state.banks = [makeBank(0, "Group 1")];

  const bs = data.browser_state || {};
  ui.duration.value = Number(data.duration || 16);
  ui.pointRate.value = Number(data.point_rate || 32);
  ui.morphDuration.value = Number(bs.morph_duration ?? ui.morphDuration.value);
  ui.sceneHold.value = Number(bs.hold_duration ?? ui.sceneHold.value);
  ui.sceneLoop.checked = bs.loop_scenes !== false;
  ui.varySceneBanks.checked = bs.vary_scene_banks === true;
  ui.cameraAz.value = Number(bs.camera_azimuth ?? ui.cameraAz.value);
  ui.cameraEl.value = Number(bs.camera_elevation ?? ui.cameraEl.value);
  ui.zoom.value = Number(bs.zoom ?? ui.zoom.value);
  ui.analysisScope.value = bs.analysis_scope === "active" ? "active" : "global";
  ui.neighborLinks.value = Number(bs.neighbor_links ?? ui.neighborLinks.value);
  ui.analysisInfluence.value = Number(bs.analysis_influence ?? ui.analysisInfluence.value);
  ui.centroidPull.value = Number(bs.centroid_pull ?? ui.centroidPull.value);
  ui.spreadTarget.value = Number(bs.spread_target ?? ui.spreadTarget.value);
  ui.activityDamping.value = Number(bs.activity_damping ?? ui.activityDamping.value);
  ui.showAnalysis.checked = bs.show_analysis !== false;
  ui.showCentroid.checked = bs.show_centroid === true;
  ui.showTrails.checked = bs.show_path_preview === true;
  ui.showLabels.checked = bs.show_labels === true;
  state.activeBank = clamp(Number(bs.active_group || 1) - 1, 0, state.banks.length - 1);
  state.selectedSource = clamp(Number(bs.selected_source || 1) - 1, 0, 7);
  syncPanelFromBank();
  updateAllRangeFills();
  ui.analysisReadout.textContent = `imported ${state.banks.length} group${state.banks.length === 1 ? "" : "s"} from JSON`;
}

async function loadReaperLinkJson() {
  try {
    const response = await fetch(`reaper-link.json?cache=${Date.now()}`, { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    loadMoverJson(data);
    reaperLink.loaded = true;
    state.playing = false;
    ui.analysisReadout.textContent = `REAPER link loaded ${state.banks.length} group${state.banks.length === 1 ? "" : "s"}`;
  } catch (error) {
    ui.analysisReadout.textContent = `REAPER link waiting for JSON: ${error.message}`;
  }
}

async function pollReaperPlayhead(now) {
  if (now < reaperLink.nextPoll) return;
  reaperLink.nextPoll = now + 45;
  try {
    const response = await fetch(`reaper-playhead.json?cache=${Date.now()}`, { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    const updated = Number(data.updated || 0);
    if (updated && updated === reaperLink.lastUpdated) return;
    const firstSample = reaperLink.lastUpdated === 0;
    reaperLink.lastUpdated = updated;
    const duration = Number(data.duration || ui.duration.value || 1);
    if (duration > 0) {
      ui.duration.value = duration;
      reaperLink.duration = duration;
      updateRangeFill(ui.duration);
    }
    state.playing = false;
    reaperLink.playing = data.playing === true;
    reaperLink.basePosition = Number(data.position || 0);
    reaperLink.baseT = clamp(Number(data.t || 0), 0, 1);
    reaperLink.receivedAt = now;
    if (!reaperLink.playing || firstSample) {
      reaperLink.displayT = reaperLink.baseT;
      state.playT = reaperLink.baseT;
    }
  } catch (_) {
    if (reaperLink.loaded) ui.analysisReadout.textContent = "REAPER link waiting for playhead";
  }
}

function initReaperLink() {
  const params = new URLSearchParams(window.location.search);
  reaperLink.enabled = params.get("reaper_link") === "1";
  if (!reaperLink.enabled) return;
  state.playing = false;
  ui.play.textContent = "R";
  ui.play.title = "Following REAPER transport";
  ui.stop.title = "REAPER link is controlled from REAPER";
  loadReaperLinkJson();
}

function pointerPoint(event) {
  const rect = canvas.getBoundingClientRect();
  const dpr = window.devicePixelRatio || 1;
  return { x: (event.clientX - rect.left) * dpr, y: (event.clientY - rect.top) * dpr };
}

function hitTest(event) {
  const mouse = pointerPoint(event);
  let best = null;
  let bestD = 24 * (window.devicePixelRatio || 1);
  state.banks.forEach((bank, bi) => {
    bank.sources.forEach((source, si) => {
      const p = project(sourcePosition(bank, source, currentT()));
      const d = Math.hypot(mouse.x - p.x, mouse.y - p.y);
      if (d < bestD) {
        bestD = d;
        best = { bank: bi, source: si };
      }
    });
  });
  return best;
}

canvas.addEventListener("pointerdown", (event) => {
  if (event.shiftKey) {
    const mouse = pointerPoint(event);
    state.viewDrag = {
      x: mouse.x,
      y: mouse.y,
      az: Number(ui.cameraAz.value),
      el: Number(ui.cameraEl.value),
    };
    canvas.setPointerCapture(event.pointerId);
    return;
  }
  const hit = hitTest(event);
  if (hit) {
    state.activeBank = hit.bank;
    state.selectedSource = hit.source;
    state.dragging = hit;
    canvas.setPointerCapture(event.pointerId);
    syncPanelFromBank();
  }
});

canvas.addEventListener("pointermove", (event) => {
  if (state.viewDrag) {
    const mouse = pointerPoint(event);
    const dpr = window.devicePixelRatio || 1;
    const dx = (mouse.x - state.viewDrag.x) / dpr;
    const dy = (mouse.y - state.viewDrag.y) / dpr;
    ui.cameraAz.value = wrapDeg(state.viewDrag.az + dx * 0.35);
    ui.cameraEl.value = clamp(state.viewDrag.el - dy * 0.28, -85, 85);
    updateRangeFill(ui.cameraAz);
    updateRangeFill(ui.cameraEl);
    return;
  }
  if (!state.dragging) return;
  const mouse = pointerPoint(event);
  const dx = (mouse.x - canvas.width * 0.5) / (Math.min(canvas.width, canvas.height) * 0.26 * Number(ui.zoom.value));
  const dy = -(mouse.y - canvas.height * 0.52) / (Math.min(canvas.width, canvas.height) * 0.26 * Number(ui.zoom.value));
  const source = activeBank().sources[state.selectedSource];
  source.azimuth = wrapDeg(radToDeg(Math.atan2(dx, Math.max(0.001, dy))));
  source.elevation = clamp(dy * 45, -80, 80);
  source.distance = clamp(Math.hypot(dx, dy), 0.1, 3);
  ui.sourceDistance.value = source.distance;
});

canvas.addEventListener("pointerup", (event) => {
  state.dragging = null;
  state.viewDrag = null;
  try {
    canvas.releasePointerCapture(event.pointerId);
  } catch (_) {}
});

ui.play.addEventListener("click", () => {
  state.playing = true;
  state.playStart = performance.now() - state.playT * Number(ui.duration.value) * 1000;
  state.nextSceneAt = performance.now() + Number(ui.sceneHold.value || 0) * 1000;
});
ui.stop.addEventListener("click", () => {
  state.playing = false;
  state.playT = 0;
});
ui.importJson.addEventListener("click", () => {
  ui.jsonFile.value = "";
  ui.jsonFile.click();
});
ui.jsonFile.addEventListener("change", () => {
  importJsonFile(ui.jsonFile.files && ui.jsonFile.files[0]);
});
ui.exportJson.addEventListener("click", exportJson);
ui.fullscreenView.addEventListener("click", () => {
  ui.app.classList.add("visual-fullscreen");
  resizeCanvas();
});
ui.closeFullscreen.addEventListener("click", () => {
  ui.app.classList.remove("visual-fullscreen");
  resizeCanvas();
});
ui.addBank.addEventListener("click", () => {
  if (state.banks.length >= MAX_BANKS) {
    ui.analysisReadout.textContent = "maximum 8 groups / 64 sources";
    return;
  }
  const current = activeBank();
  const next = makeBank(state.banks.length, `Group ${state.banks.length + 1}`);
  next.mode = current.mode;
  next.scene = current.scene;
  next.params = { ...current.params };
  state.banks.push(next);
  state.activeBank = state.banks.length - 1;
  syncPanelFromBank();
});
ui.deleteBank.addEventListener("click", () => {
  if (state.banks.length <= 1) return;
  state.banks.splice(state.activeBank, 1);
  state.banks.forEach((b, i) => {
    b.id = i + 1;
    b.name = b.name || `Group ${i + 1}`;
  });
  state.activeBank = clamp(state.activeBank, 0, state.banks.length - 1);
  syncPanelFromBank();
});
ui.storeScene.addEventListener("click", storeScene);
ui.randomScene.addEventListener("click", randomizeScene);
ui.generateScenes.addEventListener("click", generateAllScenes);
ui.morphScene.addEventListener("click", () => startSceneMorph());
ui.autoNext.addEventListener("change", () => {
  state.nextSceneAt = performance.now() + Number(ui.sceneHold.value || 0) * 1000;
});
for (let i = 0; i < 8; i++) {
  const option = document.createElement("option");
  option.value = String(i);
  option.textContent = `Source ${i + 1}`;
  ui.sourceSelect.appendChild(option);
}

ui.sourceSelect.addEventListener("change", () => {
  state.selectedSource = Number(ui.sourceSelect.value);
  syncPanelFromBank();
});
ui.toggleSource.addEventListener("click", () => {
  const source = activeBank().sources[state.selectedSource];
  source.enabled = !source.enabled;
  syncPanelFromBank();
});
ui.resetSources.addEventListener("click", () => {
  activeBank().sources = Array.from({ length: 8 }, (_, i) => makeSource(i));
  syncPanelFromBank();
});

document.querySelectorAll("input, select").forEach((input) => {
  input.addEventListener("input", () => {
    const sourceControls = ["sourceGain", "sourceDistance"];
    const interfaceControls = [
      "morphTarget", "autoNext", "sceneLoop", "varySceneBanks",
      "cameraAz", "cameraEl", "zoom", "analysisScope", "neighborLinks", "showAnalysis", "showCentroid", "showTrails", "showLabels",
    ];
    if (sourceControls.includes(input.id)) {
      if (input.type === "range") updateRangeFill(input);
      syncSourceFromPanel();
      return;
    }
    if (input.id === "morphDuration" || input.id === "sceneHold") {
      if (input.type === "range") updateRangeFill(input);
      updateTimeReadouts();
      captureScene(activeBank());
      return;
    }
    if (interfaceControls.includes(input.id)) {
      if (input.type === "range") updateRangeFill(input);
      updateTimeReadouts();
      return;
    }
    if (input.type === "range") updateRangeFill(input);
    syncBankFromPanel();
  });
});
document.querySelectorAll("[data-view]").forEach((button) => {
  button.addEventListener("click", () => {
    const view = button.dataset.view;
    if (view === "top") {
      ui.cameraAz.value = 0;
      ui.cameraEl.value = 89;
    } else if (view === "front") {
      ui.cameraAz.value = 0;
      ui.cameraEl.value = 0;
    } else if (view === "side") {
      ui.cameraAz.value = -90;
      ui.cameraEl.value = 0;
    } else {
      ui.cameraAz.value = -35;
      ui.cameraEl.value = 36;
    }
  });
});
document.querySelectorAll(".panel section > h2").forEach((heading) => {
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

function enhanceCustomSelects(root = document) {
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

window.addEventListener("resize", resizeCanvas);
window.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && ui.app.classList.contains("visual-fullscreen")) {
    ui.app.classList.remove("visual-fullscreen");
    resizeCanvas();
  }
});

captureScene(activeBank());
enhanceCustomSelects();
syncPanelFromBank();
updateAllRangeFills();
initReaperLink();
tick();
