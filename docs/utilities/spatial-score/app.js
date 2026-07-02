const canvas = document.getElementById("view");
const ctx = canvas.getContext("2d");

const el = (id) => document.getElementById(id);
const ui = {
  play: el("play"),
  stop: el("stop"),
  app: document.querySelector(".app"),
  importJson: el("importJson"),
  exportJson: el("exportJson"),
  recordClip: el("recordClip"),
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
  randomMorphTime: el("randomMorphTime"),
  morphScene: el("morphScene"),
  autoNext: el("autoNext"),
  sceneLoop: el("sceneLoop"),
  bankMode: el("bankMode"),
  sceneMode: el("sceneMode"),
  duration: el("duration"),
  durationValue: el("durationValue"),
  pointRate: el("pointRate"),
  pointRateValue: el("pointRateValue"),
  pointCountValue: el("pointCountValue"),
  motion: el("motion"),
  width: el("width"),
  disorder: el("disorder"),
  gravity: el("gravity"),
  development: el("development"),
  topoWarp: el("topoWarp"),
  physAttract: el("physAttract"),
  physRepel: el("physRepel"),
  physBounce: el("physBounce"),
  physCollision: el("physCollision"),
  physDamping: el("physDamping"),
  physTurbulence: el("physTurbulence"),
  arcSluiceOn: el("arcSluiceOn"),
  arcSluiceMode: el("arcSluiceMode"),
  arcWallCount: el("arcWallCount"),
  arcSluiceHoles: el("arcSluiceHoles"),
  arcSluiceSize: el("arcSluiceSize"),
  arcSluiceAzimuth: el("arcSluiceAzimuth"),
  arcWallSpread: el("arcWallSpread"),
  arcWallWidth: el("arcWallWidth"),
  arcSluicePull: el("arcSluicePull"),
  arcSluiceSpit: el("arcSluiceSpit"),
  sourceSelect: el("sourceSelect"),
  sourceGain: el("sourceGain"),
  sourceAzimuth: el("sourceAzimuth"),
  sourceAzimuthValue: el("sourceAzimuthValue"),
  sourceElevation: el("sourceElevation"),
  sourceElevationValue: el("sourceElevationValue"),
  sourceDistance: el("sourceDistance"),
  sourceDistanceValue: el("sourceDistanceValue"),
  toggleSource: el("toggleSource"),
  resetSources: el("resetSources"),
  cameraAz: el("cameraAz"),
  cameraEl: el("cameraEl"),
  zoom: el("zoom"),
  spatialConstraint: el("spatialConstraint"),
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
  "manual",
  "orbit", "weave", "lattice", "frame", "trace", "pulse", "suspend", "leap",
  "field", "molec", "fluid", "forsy", "flock", "eco", "contact", "march",
  "procession", "xenak", "cardew", "path", "scatter", "physics",
];
const VARIANTS = [
  "primary", "alternate", "wide", "fold", "canon", "suspend", "burst", "drift",
  "ribbon", "gate", "mirror", "surge", "tether", "vortex", "yield", "still",
];
const VARIANT_LABELS = {
  manual: ["Placed points", "Placed points", "Placed points", "Placed points", "Placed points", "Placed points", "Placed points", "Placed points", "Placed points", "Placed points", "Placed points", "Placed points", "Placed points", "Placed points", "Placed points", "Placed points"],
  orbit: ["Single orbit", "Counter orbit", "Wide ellipse", "Folded orbit", "Phase canon", "High suspend", "Comet burst", "Slow drift", "Ribbon orbit", "Window gate", "Mirror pair", "Solar surge", "Gravity tether", "Vortex ring", "Yielding orbit", "Held orbit"],
  weave: ["Plain weave", "Cross weave", "Wide bands", "Folded braid", "Stagger canon", "Lifted weave", "Thread burst", "Loose drift", "Ribbon braid", "Gate loom", "Mirror braid", "Surge weave", "Tether weave", "Twist vortex", "Yielding cloth", "Held weave"],
  lattice: ["Cell lattice", "Rotated lattice", "Wide grid", "Folded grid", "Delayed cells", "Floating lattice", "Cell burst", "Drift grid", "Ribbon grid", "Gate cells", "Mirror lattice", "Surge grid", "Tether grid", "Spin lattice", "Soft collapse", "Held lattice"],
  frame: ["Frame trace", "Alt frame", "Wide frame", "Folded edge", "Edge canon", "High frame", "Frame burst", "Drift frame", "Ribbon edge", "Gate frame", "Mirror frame", "Surge frame", "Pinned edge", "Rotating frame", "Yielding frame", "Held frame"],
  trace: ["Follow trace", "Branch trace", "Wide trace", "Folded line", "Echo canon", "Suspended trace", "Trace burst", "Wander trace", "Ribbon trace", "Gate trace", "Mirror trace", "Surge trace", "Tether trace", "Spiral trace", "Yield trace", "Held trace"],
  pulse: ["Pulse field", "Alt pulse", "Wide pulse", "Folded pulse", "Pulse canon", "High pulse", "Impulse burst", "Pulse drift", "Ribbon pulse", "Gate pulse", "Mirror pulse", "Surge pulse", "Tether pulse", "Vortex pulse", "Yield pulse", "Held pulse"],
  suspend: ["Suspended cloud", "Alt suspend", "Wide halo", "Folded halo", "Hanging canon", "High float", "Lift burst", "Slow hover", "Ribbon halo", "Gate hover", "Mirror hover", "Lift surge", "Anchor tether", "Halo vortex", "Yield hover", "Still cloud"],
  leap: ["Soft leaps", "Alt leaps", "Wide jumps", "Folded jumps", "Jump canon", "High jumps", "Hard burst", "Drift jumps", "Ribbon jumps", "Gate jumps", "Mirror jumps", "Surge jumps", "Tether jumps", "Vortex jumps", "Yield jumps", "Held jumps"],
  field: ["Charge field", "Alt field", "Wide field", "Folded field", "Field canon", "Suspended field", "Field burst", "Flux drift", "Ribbon field", "Gate field", "Mirror poles", "Surge field", "Tether field", "Vortex field", "Yield field", "Held field"],
  molec: ["Bond pairs", "Alt bonds", "Wide molecule", "Folded molecule", "Bond canon", "Suspended molecule", "Bond burst", "Molecular drift", "Chain ribbon", "Gate bonds", "Mirror bonds", "Bond surge", "Tether bonds", "Helix vortex", "Yield bonds", "Locked bonds"],
  fluid: ["Laminar flow", "Eddy flow", "Wide current", "Folded current", "Flow canon", "Suspended flow", "Jet burst", "Drift current", "Ribbon stream", "Gate current", "Mirror flow", "Surge current", "Tether current", "Vortex eddy", "Yielding flow", "Still pool"],
  forsy: ["Point figure", "Line figure", "Wide plane", "Folded figure", "Figure canon", "Suspended figure", "Figure burst", "Drift figure", "Ribbon figure", "Gate figure", "Mirror figure", "Surge figure", "Tether figure", "Axis vortex", "Yield figure", "Held figure"],
  flock: ["Cohesive flock", "Split flock", "Wide flock", "Folded flock", "Flock canon", "High flock", "Panic burst", "Roost drift", "Ribbon flock", "Gate flock", "Mirror flock", "Surge flock", "Tether flock", "Vortex flock", "Yield flock", "Roost hold"],
  eco: ["Migration", "Grazing", "Wide range", "Folded range", "Herd canon", "High migration", "Scatter burst", "Forage drift", "Ribbon herd", "Gate herd", "Mirror herd", "Surge herd", "Tether herd", "Vortex herd", "Yield herd", "Nest hold"],
  contact: ["Weighted contact", "Rolling contact", "Wide lean", "Folded lean", "Contact canon", "Lifted contact", "Impact burst", "Contact drift", "Ribbon contact", "Gate contact", "Mirror contact", "Surge contact", "Tether contact", "Vortex contact", "Yield contact", "Held contact"],
  march: ["Block march", "Line march", "Wide wedge", "Folded ranks", "Rank canon", "High march", "Step burst", "Drift march", "Ribbon march", "Gate march", "Mirror march", "Surge march", "Tether march", "Pinwheel march", "Yield march", "Held ranks"],
  procession: ["Station walk", "Relay walk", "Wide circle", "Folded path", "Process canon", "High procession", "Process burst", "Return drift", "Ribbon process", "Gate process", "Mirror process", "Surge process", "Tether process", "Circle vortex", "Yield process", "Vigil hold"],
  xenak: ["Ruled score", "Graphic score", "Wide score", "Folded score", "Score canon", "High score", "Score burst", "Drift score", "Ribbon score", "Gate score", "Mirror score", "Surge score", "Tether score", "Helix score", "Yield score", "Held score"],
  cardew: ["Open line", "Symbol field", "Wide page", "Folded page", "Page canon", "High symbols", "Symbol burst", "Free drift", "Ribbon symbols", "Gate symbols", "Mirror page", "Surge page", "Tether page", "Spiral symbols", "Yield page", "Still page"],
  path: ["Path follow", "Reverse path", "Wide path", "Folded path", "Path canon", "High path", "Path burst", "Path drift", "Ribbon path", "Gate path", "Mirror path", "Surge path", "Tether path", "Vortex path", "Yield path", "Held path"],
  scatter: ["Dust cloud", "Spark cloud", "Wide scatter", "Folded scatter", "Scatter canon", "High scatter", "Burst scatter", "Brownian drift", "Ribbon scatter", "Gate scatter", "Mirror scatter", "Surge scatter", "Tether scatter", "Vortex scatter", "Yield scatter", "Settled scatter"],
  physics: ["Soft bodies", "Magnetic well", "Elastic chamber", "Brownian cloud", "Pinball shell", "Tethered masses", "Pressure release", "Viscous drift", "Ribbon bodies", "Impact gate", "Mirror masses", "Shock surge", "Spring tethers", "Vortex well", "Yielding field", "Frozen bodies"],
};
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
  physics: ["CALM", "SWARM", "BOUNCE", "ORBIT", "TETHER", "DRIFT", "VORTX", "WELL"],
};
const ARC_SLUICE_PARAM_KEYS = new Set([
  "arcSluiceOn",
  "arcSluiceMode",
  "arcWallCount",
  "arcSluiceHoles",
  "arcSluiceSize",
  "arcSluiceAzimuth",
  "arcWallSpread",
  "arcWallWidth",
  "arcSluicePull",
  "arcSluiceSpit",
]);
const MAX_BANKS = 8;
const TWO_PI = Math.PI * 2;
const DOME_RADIUS = 2.0;

let state = {
  playing: false,
  playStart: performance.now(),
  playT: 0,
  activeBank: 0,
  groupFocus: true,
  activeScene: "a",
  selectedSource: 0,
  banks: [makeBank(0, "Group 1")],
  arcSluice: defaultArcSluiceParams(),
  dragging: null,
  viewDrag: null,
  nextSceneAt: 0,
  generateSeed: 0,
  simCache: new Map(),
  recorder: null,
  recordingStart: 0,
  recordingDuration: 0,
  recordingSceneCycle: false,
  recordingScale: 1,
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

function defaultArcSluiceParams() {
  return {
    arcSluiceOn: 0,
    arcSluiceMode: "quarter",
    arcWallCount: 1,
    arcSluiceHoles: 1,
    arcSluiceSize: 0.55,
    arcSluiceAzimuth: 0,
    arcWallSpread: 0.36,
    arcWallWidth: 0.42,
    arcSluicePull: 0.45,
    arcSluiceSpit: 0.34,
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
      physAttract: 0.32,
      physRepel: 0.42,
      physBounce: 0.52,
      physCollision: 0.34,
      physDamping: 0.38,
      physTurbulence: 0.28,
      ...defaultArcSluiceParams(),
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
  const duration = Number(ui.duration.value || 0);
  const pointRate = Number(ui.pointRate.value || 0);
  const exportDuration = Math.max(1, sceneCycleDuration(activeBank()));
  const pointCount = Math.max(2, Math.round(exportDuration * pointRate));
  ui.durationValue.textContent = `${duration.toFixed(duration % 1 ? 2 : 0)}s`;
  ui.pointRateValue.textContent = `${Math.round(pointRate)}/s`;
  ui.pointCountValue.textContent = `A-H export ${exportDuration.toFixed(1)}s | ${pointCount.toLocaleString()} points per source`;
}

function updateSourcePositionReadouts() {
  ui.sourceAzimuthValue.textContent = `${Number(ui.sourceAzimuth.value).toFixed(0)} deg`;
  ui.sourceElevationValue.textContent = `${Number(ui.sourceElevation.value).toFixed(0)} deg`;
  ui.sourceDistanceValue.textContent = `${Number(ui.sourceDistance.value).toFixed(2)} m`;
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

function signedAngleRad(a, b) {
  return Math.atan2(Math.sin(a - b), Math.cos(a - b));
}

function internalAzimuthRad(azimuthDeg) {
  return degToRad(-wrapDeg(azimuthDeg));
}

function azimuthFromVector(x, y) {
  return wrapDeg(-radToDeg(Math.atan2(x, y)));
}

function vectorFromAed(azimuthDeg, elevationDeg, distance = 1) {
  const az = internalAzimuthRad(azimuthDeg);
  const el = degToRad(clamp(elevationDeg, -89, 89));
  return {
    x: Math.sin(az) * Math.cos(el) * distance,
    y: Math.cos(az) * Math.cos(el) * distance,
    z: Math.sin(el) * distance,
  };
}

function fract(v) {
  return v - Math.floor(v);
}

function activeBank() {
  return state.banks[state.activeBank];
}

function preserveArcSluiceParams(targetParams = {}, sourceParams = {}) {
  ARC_SLUICE_PARAM_KEYS.forEach((key) => {
    if (Object.prototype.hasOwnProperty.call(sourceParams, key)) {
      targetParams[key] = sourceParams[key];
    }
  });
  return targetParams;
}

function syncGlobalArcSluiceFromParams(params = {}) {
  ARC_SLUICE_PARAM_KEYS.forEach((key) => {
    if (Object.prototype.hasOwnProperty.call(params, key)) {
      state.arcSluice[key] = params[key];
    }
  });
}

function globalArcSluiceBank() {
  return {
    id: 1,
    motionOffset: { phase: 0, azimuth: 0, elevation: 0, distance: 1 },
    params: state.arcSluice,
  };
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
    bank.params = preserveArcSluiceParams({ ...sourceBank.params }, bank.params);
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
    sources: (scene.sources || []).map(cloneSource),
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
      sources: (scene.sources || []).map(cloneSource),
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
    physAttract: Number(params.physAttract ?? 0.32),
    physRepel: Number(params.physRepel ?? 0.42),
    physBounce: Number(params.physBounce ?? 0.52),
    physCollision: Number(params.physCollision ?? 0.34),
    physDamping: Number(params.physDamping ?? 0.38),
    physTurbulence: Number(params.physTurbulence ?? 0.28),
    arcSluiceOn: Number(params.arcSluiceOn ?? 0),
    arcSluiceMode: ["quarter", "vertical", "diameter", "full"].includes(params.arcSluiceMode) ? params.arcSluiceMode : "quarter",
    arcWallCount: Number(params.arcWallCount ?? 1),
    arcSluiceHoles: Number(params.arcSluiceHoles ?? 1),
    arcSluiceSize: Number(params.arcSluiceSize ?? 0.55),
    arcSluiceAzimuth: Number(params.arcSluiceAzimuth ?? 0),
    arcWallSpread: Number(params.arcWallSpread ?? 0.36),
    arcWallWidth: Number(params.arcWallWidth ?? 0.42),
    arcSluicePull: Number(params.arcSluicePull ?? 0.45),
    arcSluiceSpit: Number(params.arcSluiceSpit ?? 0.34),
  };
}

function normalizeArcSluiceParams(params = {}) {
  const normalized = normalizeParams({ ...defaultArcSluiceParams(), ...params });
  const arc = {};
  ARC_SLUICE_PARAM_KEYS.forEach((key) => {
    arc[key] = normalized[key];
  });
  return arc;
}

function setParamControlValue(key, value) {
  const control = ui[key];
  if (!control) return;
  if (control.type === "checkbox") control.checked = Number(value) > 0;
  else control.value = value;
  if (control._customButton) {
    control._customButton.textContent = control.selectedOptions[0]?.textContent || String(control.value);
  }
}

function readParamControlValue(key) {
  const control = ui[key];
  if (!control) return 0;
  if (control.tagName === "SELECT") return control.value;
  return control.type === "checkbox" ? (control.checked ? 1 : 0) : Number(control.value);
}

function variantLabelsForBank(mode) {
  return VARIANT_LABELS[mode] || VARIANTS.map((key) => key.replace(/\b\w/g, (c) => c.toUpperCase()));
}

function updateVariantMenu(mode, selected = ui.sceneMode.value || "primary") {
  const labels = variantLabelsForBank(mode);
  ui.sceneMode.innerHTML = "";
  VARIANTS.forEach((key, index) => {
    const option = document.createElement("option");
    option.value = key;
    option.textContent = labels[index] || key;
    ui.sceneMode.appendChild(option);
  });
  ui.sceneMode.value = VARIANTS.includes(selected) ? selected : "primary";
  if (ui.sceneMode._customButton) {
    ui.sceneMode._customButton.textContent = ui.sceneMode.selectedOptions[0]?.textContent || "Select";
  }
}

function updatePhysicsControlState(mode = ui.bankMode.value) {
  const active = mode === "physics";
  const arcActive = !!ui.arcSluiceOn.checked;
  document.querySelectorAll(".physics-only").forEach((label) => {
    label.classList.toggle("inactive", !active);
    const input = label.querySelector("input");
    if (input) input.disabled = !active;
  });
  document.querySelectorAll(".arc-sluice-only").forEach((label) => {
    label.classList.toggle("inactive", !arcActive);
    const input = label.querySelector("input");
    if (input) input.disabled = !arcActive;
  });
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
  const blended = { ...bank, ...blendSnapshots(bank.morph.from, bank.morph.to, bank.morph.progress), morph: bank.morph };
  blended.params = preserveArcSluiceParams({ ...blended.params }, bank.params);
  return blended;
}

function commitMorph(bank) {
  if (!bank.morph) return;
  const target = bank.morph.to;
  bank.mode = target.mode;
  bank.variant = target.variant || "primary";
  bank.params = preserveArcSluiceParams({ ...target.params }, bank.params);
  bank.sources = target.sources.map(cloneSource);
  bank.scene = bank.morph.targetKey;
  bank.morph = null;
  syncPanelFromBank();
}

function resizeCanvas() {
  const rect = canvas.getBoundingClientRect();
  const dpr = (window.devicePixelRatio || 1) * (state.recordingScale || 1);
  const w = Math.max(640, Math.round(rect.width * dpr));
  const h = Math.max(420, Math.round(rect.height * dpr));
  if (canvas.width !== w || canvas.height !== h) {
    canvas.width = w;
    canvas.height = h;
  }
}

function renderPixelScale() {
  return (window.devicePixelRatio || 1) * (state.recordingScale || 1);
}

function sourcePosition(bank, source, t) {
  if (bank.morph) return morphSourcePosition(bank, source, t);
  if (bank.mode === "manual") return constrainPosition(rawSourcePosition(bank, source, t));
  if (usesVelocitySimulation(bank)) {
    return simulatedSourcePosition(bank, source, t);
  }
  const raw = rawSourcePosition(bank, source, t);
  return constrainPosition(applyAnalysisInfluence(bank, source, raw, t));
}

function usesVelocitySimulation(bank) {
  return bank.mode === "physics" || Number(state.arcSluice?.arcSluiceOn || 0);
}

function constrainPosition(pos) {
  if (ui.spatialConstraint.value !== "hemisphere" || pos.z >= 0) return pos;
  const x = pos.x;
  const y = pos.y;
  const z = 0;
  return { ...pos, ...outputFromVector({ x, y, z }, { enabled: true, gain: pos.gain ?? 0 }) };
}

function motionVariantProfile(mode, variant) {
  const index = Math.max(0, VARIANTS.indexOf(variant || "primary"));
  const base = { motion: 1, width: 1, disorder: 1, development: 1, topo: 1, gravity: 1 };
  const generic = [
    {},
    { motion: 1.12, disorder: 1.12 },
    { width: 1.28 },
    { width: 0.82, topo: 1.15 },
    { motion: 0.88, development: 1.35 },
    { gravity: 1.32, width: 0.82 },
    { motion: 1.42, disorder: 1.28 },
    { motion: 0.72, disorder: 1.25 },
    { width: 1.1, topo: 1.55 },
    { motion: 1.18, width: 0.72 },
    { width: 0.92, topo: 1.18 },
    { motion: 1.34, width: 1.08 },
    { development: 1.55, width: 0.82 },
    { motion: 1.18, topo: 1.72 },
    { motion: 0.74, gravity: 0.72 },
    { motion: 0.45, width: 0.62, disorder: 0.32 },
  ][index] || {};
  const byBank = {
    physics: [
      { attract: 1.10, damping: 1.30, repel: 0.72, turbulence: 0.65, bounce: 0.55 },
      { attract: 1.75, damping: 0.78, repel: 0.52, turbulence: 0.72, bounce: 0.60 },
      { attract: 0.92, repel: 1.10, bounce: 1.15, collision: 1.35, damping: 0.72 },
      { attract: 0.52, repel: 1.45, turbulence: 1.85, damping: 0.55, width: 1.18 },
      { attract: 0.45, repel: 1.05, bounce: 1.90, collision: 1.65, damping: 0.38, motion: 1.35 },
      { attract: 1.30, repel: 0.82, damping: 1.22, development: 1.45, bounce: 0.72 },
      { attract: 0.62, repel: 1.70, bounce: 1.35, collision: 1.18, turbulence: 1.20, motion: 1.22 },
      { attract: 0.95, repel: 0.70, damping: 1.72, turbulence: 0.55, motion: 0.62 },
      { attract: 0.68, repel: 1.25, bounce: 1.45, collision: 1.20, turbulence: 1.10, topo: 1.35 },
      { attract: 0.58, repel: 1.05, bounce: 1.65, collision: 1.42, damping: 0.52 },
      { repel: 1.20, collision: 1.15, width: 0.9 },
      { attract: 0.55, repel: 1.35, bounce: 1.55, turbulence: 1.40, motion: 1.32 },
      { attract: 1.45, repel: 0.74, damping: 1.12, development: 1.65 },
      { attract: 1.28, repel: 0.92, turbulence: 1.35, topo: 1.80, motion: 1.12 },
      { attract: 0.78, repel: 1.08, damping: 0.88, bounce: 1.02 },
      { attract: 1.10, damping: 2.00, repel: 0.45, turbulence: 0.25, motion: 0.38 },
    ],
    fluid: [{}, {}, { width: 1.35 }, {}, {}, {}, { motion: 1.55 }, { motion: 0.62, disorder: 1.25 }, { topo: 1.75 }, { width: 0.65 }, {}, { motion: 1.35 }, {}, { topo: 2.0 }, { damping: 1.2 }, { motion: 0.45 }],
    flock: [{ attract: 1.25 }, { repel: 1.25 }, { width: 1.28 }, {}, { development: 1.3 }, { gravity: 1.25 }, { disorder: 1.65, motion: 1.35 }, { motion: 0.6 }, {}, {}, {}, { motion: 1.3 }, { attract: 1.4 }, { topo: 1.6 }, { damping: 1.2 }, { motion: 0.4, disorder: 0.25 }],
    scatter: [{ disorder: 1.2 }, { disorder: 1.45, motion: 1.25 }, { width: 1.35 }, {}, {}, { gravity: 1.2 }, { motion: 1.55, disorder: 1.5 }, { motion: 0.7, disorder: 1.45 }, {}, { width: 0.7 }, {}, { motion: 1.35 }, {}, { topo: 1.7 }, {}, { motion: 0.42, disorder: 0.42 }],
  };
  return { ...base, ...generic, ...((byBank[mode] || [])[index] || {}) };
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
  const frozen = bank.morph.frozen?.[source.id];
  const fromSource = bank.morph.from.sources.find((item) => item.id === source.id) || source;
  const toSource = bank.morph.to.sources.find((item) => item.id === source.id) || source;
  const a = frozen || sourcePosition(fromBank, fromSource, t);
  const b = sourcePosition(toBank, toSource, t);
  const x = lerp(a.x, b.x, eased);
  const y = lerp(a.y, b.y, eased);
  const z = lerp(a.z, b.z, eased);
  return constrainPosition(outputFromVector({ x, y, z }, { enabled: true, gain: lerp(a.gain, b.gain, eased) }));
}

function rawSourcePosition(bank, source, t) {
  const p = bank.params;
  const offset = bank.motionOffset || makeGroupOffset(Math.max(0, Number(bank.id || 1) - 1));
  const phase = fract(source.id / 8 + Number(offset.phase || 0));
  const variantIndex = Math.max(0, VARIANTS.indexOf(bank.variant || "primary"));
  const variantOffset = variantIndex * 0.061;
  const variantAmt = variantIndex / Math.max(1, VARIANTS.length - 1);
  const variantProfile = motionVariantProfile(bank.mode, bank.variant || "primary");
  const motion = clamp(p.motion * variantProfile.motion, 0, 1.8);
  const width = 0.22 + clamp(p.width * variantProfile.width, 0, 1.75) * 1.8;
  const disorder = clamp(p.disorder * variantProfile.disorder, 0, 1.8);
  const dev = clamp(p.development * variantProfile.development, 0, 1.8);
  const topo = clamp(p.topoWarp * variantProfile.topo, 0, 1.8);
  const base = vectorFromAed(
    source.azimuth + Number(offset.azimuth || 0),
    (source.elevation + Number(offset.elevation || 0)) * variantProfile.gravity,
    1
  );
  if (bank.mode === "manual") {
    return outputFromVector(vectorFromAed(source.azimuth, source.elevation, source.distance), source);
  }
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
    z = Math.sin(TWO_PI * (t * 0.75 + phase + variantOffset)) * p.gravity * 0.5;
  } else if (bank.mode === "trace") {
    const trail = smooth(pingpong01(t * (0.8 + motion * 4) + phase * 0.7));
    const a = TWO_PI * (trail + phase * 0.35 + variantOffset);
    const tail = smoothNoise(source.id * 23, t * 0.6, variantOffset);
    x = Math.sin(a) * width * (0.25 + trail);
    y = Math.cos(a * (1.0 + dev)) * width * (0.35 + tail);
    z = Math.sin(a + tail * TWO_PI) * p.gravity * 0.9;
  } else if (bank.mode === "pulse") {
    const rate = 1 + motion * 4.5;
    const q = fract(t * rate + phase + variantOffset);
    const pulse = smooth(Math.max(0, 1 - Math.abs(q - 0.5) * 2));
    const gate = 0.25 + pulse * 0.75;
    const a = TWO_PI * (q + phase * (1 + dev * 3));
    x = Math.sin(a) * width * gate;
    y = Math.cos(a) * width * gate;
    z = (gate - 0.35) * p.gravity * Math.sin(TWO_PI * (q + phase));
  } else if (bank.mode === "suspend") {
    const a = TWO_PI * (phase + variantOffset + Math.sin(t * TWO_PI * (0.2 + motion)) * 0.025);
    const lift = 0.45 + p.gravity * 0.9;
    x = Math.sin(a) * width * (0.28 + dev * 0.26);
    y = Math.cos(a) * width * (0.28 + dev * 0.26);
    z = lift + Math.sin(TWO_PI * (t * (0.3 + motion) + phase)) * 0.12;
  } else if (bank.mode === "leap") {
    const jumpRate = 0.35 + motion * 2.6;
    const bend = smoothNoise(source.id * 37 + variantIndex * 13, t * jumpRate + phase * 0.21, variantOffset);
    const bend2 = smoothNoise(source.id * 53 + variantIndex * 17, t * (jumpRate * 0.83) + phase * 0.37, variantOffset + 0.2);
    const bend3 = smoothNoise(source.id * 71 + variantIndex * 19, t * (jumpRate * 1.17) + phase * 0.53, variantOffset + 0.4);
    x = (bend * 2 - 1) * width;
    y = (bend2 * 2 - 1) * width;
    z = (bend3 * 2 - 1) * (0.2 + p.gravity);
  } else if (bank.mode === "field") {
    const a = TWO_PI * (phase + variantOffset);
    const pulse = Math.sin(TWO_PI * t * (0.5 + motion * 3) + source.id);
    x = Math.sin(a + pulse * 0.5) * width * (0.55 + dev);
    y = Math.cos(a * 1.5 + pulse) * width;
    z = Math.sin(a * 2 + t * TWO_PI) * p.gravity;
  } else if (bank.mode === "physics") {
    const sceneIndex = Math.max(0, SCENES.indexOf(bank.scene || "a"));
    const energy = motion;
    const space = p.width;
    const chaos = disorder;
    const ret = dev;
    const dir = (p.gravity - 0.5) * 2;
    const attractAmt = clamp(Number(p.physAttract ?? 0.32) * (variantProfile.attract || 1), 0, 1.8);
    const repelAmt = clamp(Number(p.physRepel ?? 0.42) * (variantProfile.repel || 1), 0, 1.8);
    const bounceAmt = clamp(Number(p.physBounce ?? 0.52) * (variantProfile.bounce || 1), 0, 1.8);
    const collisionAmt = clamp(Number(p.physCollision ?? 0.34) * (variantProfile.collision || 1), 0, 1.8);
    const dampingAmt = clamp(Number(p.physDamping ?? 0.38) * (variantProfile.damping || 1), 0, 1.8);
    const turbulenceAmt = clamp(Number(p.physTurbulence ?? 0.28) * (variantProfile.turbulence || 1), 0, 1.8);
    const variantPush = 0.55 + variantAmt * 0.95;
    const a0 = TWO_PI * (phase + variantOffset * 1.7);
    const rate = 0.18 + energy * 2.6 + variantAmt * 0.55;
    const tt = t * rate + phase * 0.37 + variantOffset;
    const swirl = TWO_PI * (tt + dir * 0.18);
    const rest = {
      x: base.x * width * (0.28 + ret * 0.62),
      y: base.y * width * (0.28 + ret * 0.62),
      z: base.z * (0.18 + p.gravity * 1.1),
    };
    const noiseX = smoothNoise(source.id * 19 + sceneIndex * 7, tt * (0.75 + chaos), variantOffset) * 2 - 1;
    const noiseY = smoothNoise(source.id * 29 + sceneIndex * 11, tt * (0.7 + chaos), variantOffset + 0.23) * 2 - 1;
    const noiseZ = smoothNoise(source.id * 41 + sceneIndex * 13, tt * (0.65 + chaos), variantOffset + 0.47) * 2 - 1;
    const pulse = smooth(Math.sin(TWO_PI * (t * (0.55 + energy * 2.2) + phase + variantOffset)) * 0.5 + 0.5);
    const shock = Math.pow(Math.max(0, Math.sin(TWO_PI * (t * (0.32 + energy * 1.7) + phase * 0.31 + variantOffset))), 5);
    const repel = 0.18 + space * 1.18;
    const spring = 0.22 + ret * 0.68;
    const brown = chaos * (0.18 + energy * 0.62) * variantPush;
    const ringX = Math.sin(a0 + swirl) * width * repel;
    const ringY = Math.cos(a0 + swirl) * width * repel;
    const ringZ = Math.sin(swirl * 0.73 + a0 * 0.5) * (0.14 + p.gravity * 1.35);

    if (sceneIndex === 0) {
      x = lerp(ringX * 0.18, rest.x, 0.58 + spring * 0.26) + noiseX * brown * 0.16;
      y = lerp(ringY * 0.18, rest.y, 0.58 + spring * 0.26) + noiseY * brown * 0.16;
      z = lerp(ringZ * 0.14, rest.z, 0.62 + spring * 0.20) + noiseZ * brown * 0.10;
    } else if (sceneIndex === 1) {
      const cloud = 0.72 + space * 1.05;
      x = ringX * cloud + noiseX * brown * 1.55;
      y = ringY * cloud + noiseY * brown * 1.55;
      z = ringZ * (0.65 + space * 0.55) + noiseZ * brown * 1.2;
      x = lerp(x, rest.x, ret * 0.10);
      y = lerp(y, rest.y, ret * 0.10);
      z = lerp(z, rest.z, ret * 0.08);
    } else if (sceneIndex === 2) {
      const q = smooth(pingpong01(t * (0.8 + energy * 2.6) + phase + variantOffset));
      const hit = Math.pow(Math.sin(q * Math.PI), 0.42);
      const wall = q < 0.5 ? -1 : 1;
      x = ringX * (0.24 + hit * 1.05) + wall * dir * energy * 0.32;
      y = ringY * (0.24 + hit * 1.05) + noiseY * brown * 0.42;
      z = (q * 2 - 1) * (0.48 + p.gravity * 1.35) + noiseZ * chaos * 0.38;
    } else if (sceneIndex === 3) {
      const orbitR = width * (0.35 + space * 1.25);
      x = Math.sin(swirl) * orbitR + rest.x * ret * 0.24;
      y = Math.cos(swirl) * orbitR + rest.y * ret * 0.24;
      z = Math.sin(swirl * (0.45 + variantAmt * 0.4) + a0) * (0.18 + p.gravity * 1.35);
    } else if (sceneIndex === 4) {
      const elastic = Math.sin(TWO_PI * (tt * 1.6 + source.id * 0.071)) * (0.18 + energy * 0.58);
      const snap = Math.sin(TWO_PI * (tt * 0.73 + phase)) * chaos * 0.35;
      x = lerp(ringX + noiseX * brown * 0.55, rest.x, 0.28 + spring * 0.44) + base.x * (elastic + snap);
      y = lerp(ringY + noiseY * brown * 0.55, rest.y, 0.28 + spring * 0.44) + base.y * (elastic - snap);
      z = lerp(ringZ + noiseZ * brown * 0.45, rest.z, 0.30 + spring * 0.38) + base.z * elastic * 0.82;
    } else if (sceneIndex === 5) {
      x = lerp(rest.x, noiseX * width * (0.8 + space * 1.2), 0.35 + energy * 0.48);
      y = lerp(rest.y, noiseY * width * (0.8 + space * 1.2), 0.35 + energy * 0.48);
      z = lerp(rest.z, noiseZ * (0.35 + p.gravity * 1.15), 0.28 + energy * 0.42);
    } else if (sceneIndex === 6) {
      const r = width * (0.18 + space * 1.35);
      const sink = 1 - 0.38 * pulse;
      x = Math.sin(swirl * 1.65 + noiseX * chaos) * r * sink + noiseX * brown * 0.45;
      y = Math.cos(swirl * 1.65 + noiseY * chaos) * r * sink + noiseY * brown * 0.45;
      z = Math.sin(swirl * 0.94 + phase * TWO_PI) * (0.28 + p.gravity * 1.25) * sink;
    } else {
      const pull = 0.30 + ret * 0.62;
      const well = Math.max(0.08, 1 - shock * (0.45 + energy * 0.45));
      x = (ringX * 0.42 + noiseX * brown * 0.32) * well + rest.x * (1 - pull * 0.34);
      y = (ringY * 0.42 + noiseY * brown * 0.32) * well + rest.y * (1 - pull * 0.34);
      z = (ringZ * 0.30 + noiseZ * brown * 0.24) * well + rest.z * (1 - pull * 0.24);
    }

    const centerPull = attractAmt * (sceneIndex === 7 ? 0.52 : 0.18);
    const restPull = attractAmt * (sceneIndex === 0 || sceneIndex === 4 ? 0.34 : 0.12);
    x = lerp(x, 0, centerPull);
    y = lerp(y, 0, centerPull);
    z = lerp(z, 0, centerPull * 0.75);
    x = lerp(x, rest.x, restPull);
    y = lerp(y, rest.y, restPull);
    z = lerp(z, rest.z, restPull * 0.82);

    const collisionRadius = 0.18 + collisionAmt * 0.92 + space * 0.22;
    const repelStrength = repelAmt * (0.12 + space * 0.42) * (sceneIndex === 1 || sceneIndex === 5 ? 1.55 : 1);
    bank.sources.filter((other) => other.enabled && other.id !== source.id).forEach((other) => {
      const otherPhase = fract(other.id / 8 + Number(offset.phase || 0));
      const otherA = TWO_PI * (otherPhase + variantOffset * 1.7);
      const otherT = t * rate + otherPhase * 0.37 + variantOffset;
      const otherSwirl = TWO_PI * (otherT + dir * 0.18);
      const ox = Math.sin(otherA + otherSwirl) * width * repel;
      const oy = Math.cos(otherA + otherSwirl) * width * repel;
      const oz = Math.sin(otherSwirl * 0.73 + otherA * 0.5) * (0.14 + p.gravity * 1.35);
      let dx = x - ox;
      let dy = y - oy;
      let dz = z - oz;
      const d = Math.max(0.001, Math.hypot(dx, dy, dz));
      if (d < collisionRadius) {
        const hit = Math.pow((collisionRadius - d) / collisionRadius, 1.35);
        const push = hit * repelStrength;
        dx /= d;
        dy /= d;
        dz /= d;
        x += dx * push;
        y += dy * push;
        z += dz * push * 0.86;
      }
    });

    const boundary = 1.15 + space * 1.45;
    const dist = Math.max(0.001, Math.hypot(x, y, z));
    if (dist > boundary) {
      const nx = x / dist;
      const ny = y / dist;
      const nz = z / dist;
      const over = dist - boundary;
      const rebound = over * (0.45 + bounceAmt * 1.65);
      x -= nx * rebound;
      y -= ny * rebound;
      z -= nz * rebound;
      const tangent = Math.sin(TWO_PI * (t * (0.8 + energy * 1.4) + phase + variantOffset));
      x += -ny * tangent * bounceAmt * 0.18;
      y += nx * tangent * bounceAmt * 0.18;
      z += nz * Math.abs(tangent) * bounceAmt * 0.08;
    }

    if (ui.spatialConstraint.value === "hemisphere" && z < 0) {
      z = Math.abs(z) * (0.22 + bounceAmt * 0.58);
      x += noiseX * bounceAmt * 0.08;
      y += noiseY * bounceAmt * 0.08;
    }

    const turbulence = turbulenceAmt * (0.08 + energy * 0.32 + chaos * 0.28);
    x += noiseX * turbulence;
    y += noiseY * turbulence;
    z += noiseZ * turbulence * 0.88;
    x = lerp(x, rest.x, dampingAmt * 0.18);
    y = lerp(y, rest.y, dampingAmt * 0.18);
    z = lerp(z, rest.z, dampingAmt * 0.14);
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
    const lane = phase + herd * 0.1;
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
    const step = smooth(pingpong01(t * (0.45 + motion * 1.8) + variantOffset));
    x = ((file ? 0.5 : -0.5) + (step - 0.5) * dev) * width;
    y = ((rank / 3) * 2 - 1) * width * (0.55 + p.gravity * 0.15);
    z = Math.sin(TWO_PI * (step + phase)) * p.gravity * 0.18;
  } else if (bank.mode === "procession") {
    const q = smooth(pingpong01(t * (0.25 + motion) + phase + variantOffset));
    const spiral = q * TWO_PI * (1.0 + dev * 2.5);
    const r = width * (0.2 + q * 0.8);
    x = Math.sin(spiral) * r;
    y = Math.cos(spiral) * r;
    z = (q - 0.5) * p.gravity * 1.15;
  } else if (bank.mode === "xenak") {
    const u = smooth(pingpong01(t * (0.25 + motion * 1.4) + phase + variantOffset));
    const ruled = (phase * 2 - 1) * width;
    const helix = TWO_PI * (u + phase * (1 + Math.round(dev * 4)));
    x = lerp(ruled, Math.sin(helix) * width, 0.45 + dev * 0.35);
    y = (u * 2 - 1) * width;
    z = Math.cos(helix) * p.gravity;
  } else if (bank.mode === "cardew") {
    const sparse = smoothNoise(source.id * 13 + variantIndex, t * (0.8 + motion * 2.2) + phase, variantOffset);
    const line = phase + (sparse - 0.5) * dev;
    x = (line * 2 - 1) * width;
    y = (smoothNoise(source.id * 23 + variantIndex, t * (0.65 + motion * 1.8), 2) * 2 - 1) * width * (0.3 + sparse * 0.7);
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
  } else if (bank.variant === "ribbon" && bank.mode !== "physics") {
    const r = Math.hypot(x, y);
    const a = Math.atan2(x, y) + Math.sin(TWO_PI * (t + phase)) * 0.18;
    x = Math.sin(a) * r;
    y = Math.cos(a) * r * 0.62;
  } else if (bank.variant === "gate") {
    const gate = smooth(Math.sin(TWO_PI * (t * (0.8 + motion * 3.2) + phase)) * 0.5 + 0.5);
    const scale = 0.18 + gate * 0.82;
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

  const physicsMode = bank.mode === "physics";
  const jitter = disorder * (physicsMode ? 0.48 : 0.28);
  x += (smoothNoise(source.id, t * 1.7, 1.1) * 2 - 1) * jitter;
  y += (smoothNoise(source.id, t * 1.3, 2.2) * 2 - 1) * jitter;
  z += (smoothNoise(source.id, t * 1.1, 3.3) * 2 - 1) * jitter;
  if (topo > 0) {
    const twist = Math.atan2(x, y) + topo * Math.sin(t * TWO_PI + z) * 1.4;
    const r = Math.hypot(x, y);
    x = Math.sin(twist) * r;
    y = Math.cos(twist) * r;
  }

  const baseBlend = physicsMode
    ? clamp(0.04 + (1 - motion) * 0.18 + dev * 0.08, 0.04, 0.30)
    : clamp(0.2 + (1 - motion) * 0.45, 0.2, 0.65);
  x = lerp(x, base.x * width, baseBlend);
  y = lerp(y, base.y * width, baseBlend);
  z = lerp(z, base.z * (0.25 + p.gravity), baseBlend);

  const groupDistance = Number(offset.distance || 1);
  x *= source.distance * groupDistance;
  y *= source.distance * groupDistance;
  z *= source.distance * groupDistance;
  return outputFromVector({ x, y, z }, source);
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

  return outputFromVector({ x, y, z }, { enabled: true, gain: pos.gain });
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

function drawFrame() {
  resizeCanvas();
  const w = canvas.width;
  const h = canvas.height;
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = "#050707";
  ctx.fillRect(0, 0, w, h);
  drawGrid();
  drawAnalysis();
  drawMotionBoundaries();
  drawBanks();
}

function draw() {
  drawFrame();
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

function pathPointsWithContext(targetCtx, pts) {
  targetCtx.beginPath();
  pts.forEach((p, i) => (i ? targetCtx.lineTo(p.x, p.y) : targetCtx.moveTo(p.x, p.y)));
}

function arcSluiceWalls(bank, t, profile = null) {
  const p = bank.params || {};
  const arcWidth = clamp(Number(p.arcWallWidth ?? 0.42), 0, 1);
  const dispersion = clamp(Number(p.arcWallSpread ?? 0.36), 0, 1);
  const wallCount = Math.max(1, Math.min(6, Math.round(Number(p.arcWallCount ?? 1))));
  const holeCount = Math.max(0, Math.min(4, Math.round(Number(p.arcSluiceHoles ?? 1))));
  const holeSize = clamp(Number(p.arcSluiceSize ?? 0.55), 0, 1);
  const pull = clamp(Number(p.arcSluicePull ?? 0.45), 0, 1);
  const spit = clamp(Number(p.arcSluiceSpit ?? 0.34), 0, 1);
  const mode = ["quarter", "vertical", "diameter", "full"].includes(p.arcSluiceMode) ? p.arcSluiceMode : "quarter";
  const offset = bank.motionOffset || makeGroupOffset(Math.max(0, Number(bank.id || 1) - 1));
  const placementAz = Number(p.arcSluiceAzimuth ?? 0);
  const azBase = internalAzimuthRad(Number(offset.azimuth || 0) + placementAz);
  const elMin = mode === "vertical" || mode === "full" ? -Math.PI * 0.5 : 0;
  const elMax = Math.PI * 0.5;
  const spreadRad = degToRad(12 + dispersion * 300);
  const base = azBase;
  const walls = [];
  const addWall = (az, holes, laneIndex) => {
    walls.push({
      az,
      halfSpan: degToRad(2.5 + arcWidth * 22),
      elMin,
      elMax,
      radius: DOME_RADIUS,
      holes: holes.map((hole) => ({ ...hole })),
      pull,
      spit,
      mode,
      laneIndex,
    });
  };
  for (let i = 0; i < wallCount; i += 1) {
    const lane = wallCount === 1 ? 0 : i / (wallCount - 1) - 0.5;
    const holes = [];
    for (let h = 0; h < holeCount; h += 1) {
      const seed = Number(offset.phase || 0) * 97 + i * 23 + h * 37;
      const pos = holeCount === 1 ? 0.5 : (h + 0.5) / holeCount;
      holes.push({
        pos: clamp(pos + (hashNoise(seed, 0.13, 1) - 0.5) * 0.30, 0.14, 0.86),
        dist: clamp(0.24 + (h + 0.5) / holeCount * 0.58 + (hashNoise(seed, 0.37, 2) - 0.5) * 0.18, 0.18, 0.92),
        radius: clamp(0.045 + holeSize * 0.275 + hashNoise(seed, 0.71, 3) * 0.018, 0.035, 0.38),
      });
    }
    const az = base + lane * spreadRad;
    addWall(az, holes, i);
    if (mode === "diameter" || mode === "full") addWall(az + Math.PI, holes, i + wallCount);
  }
  return walls;
}

function simulationKey(bank) {
  return JSON.stringify({
    id: bank.id,
    mode: bank.mode,
    scene: bank.scene,
    variant: bank.variant || "primary",
    params: bank.params,
    arcSluice: state.arcSluice,
    sources: bank.sources.map((s) => ({
      id: s.id,
      enabled: s.enabled,
      azimuth: s.azimuth,
      elevation: s.elevation,
      distance: s.distance,
      gain: s.gain,
    })),
    offset: bank.motionOffset || {},
    duration: Number(ui.duration.value || 16),
    pointRate: Number(ui.pointRate.value || 32),
    spatialConstraint: ui.spatialConstraint.value,
    analysis: {
      influence: Number(ui.analysisInfluence.value || 0),
      scope: ui.analysisScope.value,
      neighborLinks: Number(ui.neighborLinks.value || 0),
      centroid: Number(ui.centroidPull.value || 0),
      spread: Number(ui.spreadTarget.value || 1.05),
      damping: Number(ui.activityDamping.value || 0),
    },
  });
}

function targetMotionPosition(bank, source, t) {
  const raw = rawSourcePosition(bank, source, t);
  return constrainPosition(applyAnalysisInfluence(bank, source, raw, t));
}

function outputFromVector(point, source) {
  const x = point.x;
  const y = point.y;
  const z = point.z;
  return {
    x,
    y,
    z,
    azimuth: azimuthFromVector(x, y),
    elevation: clamp(radToDeg(Math.atan2(z, Math.hypot(x, y))), -89, 89),
    distance: clamp(Math.hypot(x, y, z), 0.1, 3),
    gain: source.enabled ? source.gain : 0,
  };
}

function simulatedSourcePosition(bank, source, t) {
  const sim = velocitySimulation(bank);
  const frames = sim.sources[source.id];
  if (!frames || !frames.length) return targetMotionPosition(bank, source, t);
  const ft = clamp(t, 0, 1) * (frames.length - 1);
  const i0 = Math.floor(ft);
  const i1 = Math.min(frames.length - 1, i0 + 1);
  const f = ft - i0;
  const a = frames[i0];
  const b = frames[i1];
  const point = {
    x: lerp(a.x, b.x, f),
    y: lerp(a.y, b.y, f),
    z: lerp(a.z, b.z, f),
  };
  return outputFromVector(point, source);
}

function velocitySimulation(bank) {
  const key = simulationKey(bank);
  const cached = state.simCache.get(key);
  if (cached) return cached;
  if (state.simCache.size > 12) state.simCache.clear();
  const duration = Math.max(0.1, Number(ui.duration.value || 16));
  const pointRate = Math.max(4, Number(ui.pointRate.value || 32));
  const steps = Math.min(4096, Math.max(160, Math.round(duration * pointRate)));
  const sources = {};
  const current = {};
  const velocities = {};
  bank.sources.forEach((source) => {
    const p0 = targetMotionPosition(bank, source, 0);
    const p1 = targetMotionPosition(bank, source, Math.min(1, 1 / steps));
    current[source.id] = { x: p0.x, y: p0.y, z: p0.z };
    velocities[source.id] = {
      x: (p1.x - p0.x) * 0.72,
      y: (p1.y - p0.y) * 0.72,
      z: (p1.z - p0.z) * 0.72,
    };
    sources[source.id] = [{ ...current[source.id] }];
  });
  for (let i = 1; i <= steps; i += 1) {
    const t = i / steps;
    const predictedById = {};
    const velocityById = {};
    bank.sources.forEach((source) => {
      const desired = targetMotionPosition(bank, source, t);
      const pos = current[source.id];
      const vel = velocities[source.id];
      const follow = bank.mode === "physics" ? 0.075 : 0.145;
      const retain = bank.mode === "physics" ? 0.91 : 0.86;
      vel.x = vel.x * retain + (desired.x - pos.x) * follow;
      vel.y = vel.y * retain + (desired.y - pos.y) * follow;
      vel.z = vel.z * retain + (desired.z - pos.z) * follow;
      predictedById[source.id] = {
        x: pos.x + vel.x,
        y: pos.y + vel.y,
        z: pos.z + vel.z,
      };
      velocityById[source.id] = { ...vel };
    });
    bank.sources.forEach((source) => {
      const resolved = resolveVelocityFrame(
        bank,
        t,
        predictedById[source.id],
        velocityById[source.id],
        source,
        predictedById,
        current[source.id]
      );
      current[source.id] = resolved.point;
      velocities[source.id] = resolved.velocity;
      sources[source.id].push({ ...resolved.point });
    });
  }
  const sim = { key, steps, sources };
  state.simCache.set(key, sim);
  return sim;
}

function resolveVelocityFrame(bank, t, point, velocity, source, predictedById, previousPoint = null) {
  let resolved = { point, velocity };
  if (bank.mode === "physics") {
    resolved = resolvePhysicsVelocity(bank, t, resolved.point, resolved.velocity, source, predictedById);
  }
  if (Number(state.arcSluice?.arcSluiceOn || 0)) {
    resolved = resolveArcSluiceVelocity(bank, t, resolved.point, resolved.velocity, source, previousPoint);
  }
  return resolved;
}

function resolvePhysicsVelocity(bank, t, point, velocity, source, predictedById) {
  const p = bank.params || {};
  const variantProfile = motionVariantProfile(bank.mode, bank.variant || "primary");
  const attractAmt = clamp(Number(p.physAttract ?? 0.32) * (variantProfile.attract || 1), 0, 1.8);
  const repelAmt = clamp(Number(p.physRepel ?? 0.42) * (variantProfile.repel || 1), 0, 1.8);
  const bounceAmt = clamp(Number(p.physBounce ?? 0.52) * (variantProfile.bounce || 1), 0, 1.8);
  const collisionAmt = clamp(Number(p.physCollision ?? 0.34) * (variantProfile.collision || 1), 0, 1.8);
  const dampingAmt = clamp(Number(p.physDamping ?? 0.38) * (variantProfile.damping || 1), 0, 1.8);
  const turbulenceAmt = clamp(Number(p.physTurbulence ?? 0.28) * (variantProfile.turbulence || 1), 0, 1.8);
  const width = clamp(Number(p.width ?? 0.5), 0, 1);
  const motion = clamp(Number(p.motion ?? 0.42) * (variantProfile.motion || 1), 0, 1.8);
  const disorder = clamp(Number(p.disorder ?? 0.35) * (variantProfile.disorder || 1), 0, 1.8);
  const sceneIndex = Math.max(0, SCENES.indexOf(bank.scene || "a"));
  let x = point.x;
  let y = point.y;
  let z = point.z;
  let vx = velocity.x;
  let vy = velocity.y;
  let vz = velocity.z;

  const activeSources = bank.sources.filter((item) => item.enabled);
  const centroid = activeSources.reduce((acc, item) => {
    const other = predictedById[item.id];
    if (!other) return acc;
    acc.x += other.x;
    acc.y += other.y;
    acc.z += other.z;
    acc.count += 1;
    return acc;
  }, { x: 0, y: 0, z: 0, count: 0 });
  if (centroid.count) {
    centroid.x /= centroid.count;
    centroid.y /= centroid.count;
    centroid.z /= centroid.count;
  }

  const rest = targetMotionPosition({ ...bank, mode: "orbit", morph: null }, source, t);
  const centerPull = attractAmt * (sceneIndex === 7 ? 0.0065 : 0.0032);
  const restPull = attractAmt * (sceneIndex === 0 || sceneIndex === 4 ? 0.010 : 0.004);
  vx += (centroid.x - x) * centerPull;
  vy += (centroid.y - y) * centerPull;
  vz += (centroid.z - z) * centerPull * 0.82;
  vx += (rest.x - x) * restPull;
  vy += (rest.y - y) * restPull;
  vz += (rest.z - z) * restPull * 0.82;

  const collisionRadius = 0.16 + collisionAmt * 0.72 + width * 0.24;
  const repelStrength = repelAmt * (0.010 + width * 0.018) * (sceneIndex === 1 || sceneIndex === 5 ? 1.55 : 1);
  activeSources.forEach((otherSource) => {
    if (otherSource.id === source.id) return;
    const other = predictedById[otherSource.id];
    if (!other) return;
    let dx = x - other.x;
    let dy = y - other.y;
    let dz = z - other.z;
    const d = Math.max(0.001, Math.hypot(dx, dy, dz));
    if (d < collisionRadius) {
      const hit = smooth(clamp((collisionRadius - d) / collisionRadius, 0, 1));
      dx /= d;
      dy /= d;
      dz /= d;
      const push = hit * repelStrength;
      vx += dx * push;
      vy += dy * push;
      vz += dz * push * 0.86;
      x += dx * push * 0.42;
      y += dy * push * 0.42;
      z += dz * push * 0.32;
    }
  });

  const noiseRate = 0.8 + motion * 2.4 + disorder * 1.2;
  const nx = smoothNoise(source.id * 101 + sceneIndex * 31, t * noiseRate, 0.11) * 2 - 1;
  const ny = smoothNoise(source.id * 131 + sceneIndex * 37, t * noiseRate * 0.91, 0.33) * 2 - 1;
  const nz = smoothNoise(source.id * 173 + sceneIndex * 41, t * noiseRate * 1.07, 0.57) * 2 - 1;
  const turbulence = turbulenceAmt * (0.003 + motion * 0.008 + disorder * 0.006);
  vx += nx * turbulence;
  vy += ny * turbulence;
  vz += nz * turbulence * 0.86;

  const boundary = 1.08 + width * 1.72;
  const dist = Math.max(0.001, Math.hypot(x, y, z));
  if (dist > boundary) {
    const nx = x / dist;
    const ny = y / dist;
    const nz = z / dist;
    const over = dist - boundary;
    x -= nx * over * (0.82 + collisionAmt * 0.22);
    y -= ny * over * (0.82 + collisionAmt * 0.22);
    z -= nz * over * (0.82 + collisionAmt * 0.22);
    const vn = vx * nx + vy * ny + vz * nz;
    if (vn > 0) {
      const impulse = -(1 + bounceAmt * 0.68) * vn;
      vx += impulse * nx;
      vy += impulse * ny;
      vz += impulse * nz;
    }
  }

  if (ui.spatialConstraint.value === "hemisphere" && z < 0) {
    z = Math.abs(z) * (0.24 + bounceAmt * 0.28);
    if (vz < 0) vz = -vz * (0.32 + bounceAmt * 0.42);
  }

  const drag = clamp(0.992 - dampingAmt * 0.075, 0.82, 0.994);
  vx *= drag;
  vy *= drag;
  vz *= drag;
  const speed = Math.hypot(vx, vy, vz);
  const maxSpeed = 0.055 + motion * 0.135 + bounceAmt * 0.035;
  if (speed > maxSpeed) {
    const scale = maxSpeed / speed;
    vx *= scale;
    vy *= scale;
    vz *= scale;
  }

  return {
    point: constrainPosition({ x, y, z, azimuth: 0, elevation: 0, distance: 1, gain: source.enabled ? source.gain : 0 }),
    velocity: { x: vx, y: vy, z: vz },
  };
}

function resolveArcSluiceVelocity(bank, t, point, velocity, source, previousPoint = null) {
  const p = { ...(bank.params || {}), ...(state.arcSluice || {}) };
  const variantProfile = motionVariantProfile(bank.mode, bank.variant || "primary");
  const collisionAmt = clamp(Number(p.physCollision ?? 0.34) * (variantProfile.collision || 1), 0, 1.8);
  const bounceAmt = clamp(Number(p.physBounce ?? 0.52) * (variantProfile.bounce || 1), 0, 1.8);
  const attractAmt = clamp(Number(p.physAttract ?? 0.32) * (variantProfile.attract || 1), 0, 1.8);
  const dampingAmt = clamp(Number(p.physDamping ?? 0.38), 0, 1);
  let x = point.x;
  let y = point.y;
  let z = point.z;
  let vx = velocity.x;
  let vy = velocity.y;
  let vz = velocity.z;
  const reboundFromWall = (nx, ny, nz, overlap = 0.02, extraSpring = 0) => {
    const vn = vx * nx + vy * ny + vz * nz;
    const tx = vx - nx * vn;
    const ty = vy - ny * vn;
    const tz = vz - nz * vn;
    const spring = overlap * (0.78 + collisionAmt * 0.34 + bounceAmt * 0.20) + extraSpring;
    const restitution = clamp(0.34 + bounceAmt * 0.35 - dampingAmt * 0.10, 0.22, 0.88);
    const normalOut = vn < 0
      ? (-vn * restitution + spring)
      : (Math.max(0, vn) * 0.42 + spring * 0.65);
    const tangentLoss = clamp(0.90 - dampingAmt * 0.22 - Math.min(0.28, overlap * 1.8), 0.48, 0.94);
    const normalLoss = clamp(0.98 - dampingAmt * 0.08 - Math.min(0.16, overlap * 0.55), 0.76, 0.98);
    vx = nx * normalOut * normalLoss + tx * tangentLoss;
    vy = ny * normalOut * normalLoss + ty * tangentLoss;
    vz = nz * normalOut * normalLoss + tz * tangentLoss;
  };
  arcSluiceWalls(globalArcSluiceBank(), t, variantProfile).forEach((wall) => {
    const radial = Math.max(0.001, Math.hypot(x, y));
    const pointAz = Math.atan2(x, y);
    const pointEl = Math.atan2(z, radial);
    const distNorm = Math.hypot(x, y, z) / Math.max(0.001, wall.radius);
    const azDelta = signedAngleRad(pointAz, wall.az);
    const absDelta = Math.abs(azDelta);
    const wallNxPos = Math.cos(wall.az);
    const wallNyPos = -Math.sin(wall.az);
    const signedWallDistance = x * wallNxPos + y * wallNyPos;
    const wallThickness = Math.max(0.075 + Number(p.arcWallWidth ?? 0.42) * 0.16, wall.halfSpan * Math.max(0.18, radial));
    const centerStopRadius = 0.18 + Number(p.arcWallWidth ?? 0.42) * 0.26;
    const elNorm = clamp((pointEl - wall.elMin) / Math.max(0.001, wall.elMax - wall.elMin), 0, 1);
    if (pointEl < wall.elMin || pointEl > wall.elMax) return;
    let nearestHole = null;
    let nearestDistance = Infinity;
    (wall.holes || []).forEach((hole) => {
      const dx = (distNorm - hole.dist) / Math.max(0.001, hole.radius);
      const dy = (elNorm - hole.pos) / Math.max(0.001, hole.radius);
      const dz = azDelta / Math.max(0.001, wall.halfSpan);
      const d = Math.hypot(dx, dy, dz);
      if (d < nearestDistance) {
        nearestDistance = d;
        nearestHole = hole;
      }
    });
    const insideSluicePlane = (testDist, testEl) => {
      return (wall.holes || []).some((hole) => {
        const dx = (testDist - hole.dist) / Math.max(0.001, hole.radius);
        const dy = (testEl - hole.pos) / Math.max(0.001, hole.radius);
        return dx * dx + dy * dy <= 1;
      });
    };
    if (previousPoint) {
      const prevRadial = Math.max(0.001, Math.hypot(previousPoint.x, previousPoint.y));
      const prevAz = Math.atan2(previousPoint.x, previousPoint.y);
      const prevEl = Math.atan2(previousPoint.z, prevRadial);
      const prevDelta = signedAngleRad(prevAz, wall.az);
      const prevWallDistance = previousPoint.x * wallNxPos + previousPoint.y * wallNyPos;
      const crossedPlane = prevWallDistance !== 0 && signedWallDistance !== 0 && Math.sign(prevWallDistance) !== Math.sign(signedWallDistance);
      const prevInElev = prevEl >= wall.elMin && prevEl <= wall.elMax;
      const prevDistNorm = Math.hypot(previousPoint.x, previousPoint.y, previousPoint.z) / Math.max(0.001, wall.radius);
      const crossingDist = clamp((prevDistNorm + distNorm) * 0.5, 0, 1.25);
      const crossingEl = clamp((((prevEl - wall.elMin) / Math.max(0.001, wall.elMax - wall.elMin)) + elNorm) * 0.5, 0, 1);
      if (crossedPlane && prevInElev && !insideSluicePlane(crossingDist, crossingEl)) {
        const side = prevWallDistance >= 0 ? 1 : -1;
        const targetDistance = side * wallThickness;
        const correctionDistance = targetDistance - signedWallDistance;
        x += wallNxPos * correctionDistance;
        y += wallNyPos * correctionDistance;
        const nx = wallNxPos * side;
        const ny = wallNyPos * side;
        reboundFromWall(nx, ny, 0, Math.max(0.018, Math.abs(correctionDistance) * 0.18), 0.012 + collisionAmt * 0.010);
        return;
      }
    }
    const feather = 0.42;
    const wallFeather = nearestDistance <= 1 ? 0 : nearestDistance >= 1 + feather
      ? 1
      : smooth(clamp((nearestDistance - 1) / feather, 0, 1));
    if (nearestHole && nearestDistance <= 1.85) {
      const reach = smooth(1 - clamp((nearestDistance - 1) / 0.85, 0, 1));
      const targetEl = lerp(wall.elMin, wall.elMax, nearestHole.pos);
      const sx = Math.sin(wall.az) * Math.cos(targetEl);
      const sy = Math.cos(wall.az) * Math.cos(targetEl);
      const sz = Math.sin(targetEl);
      const hx = sx * nearestHole.dist * wall.radius;
      const hy = sy * nearestHole.dist * wall.radius;
      const hz = sz * nearestHole.dist * wall.radius;
      const suction = reach * (wall.pull * 0.075 + attractAmt * 0.018);
      vx += (hx - x) * suction;
      vy += (hy - y) * suction;
      vz += (hz - z) * suction;
    }
    if (nearestHole && nearestDistance <= 1) {
      const gate = smooth(1 - clamp(nearestDistance, 0, 1));
      const targetEl = lerp(wall.elMin, wall.elMax, nearestHole.pos);
      const sx = Math.sin(wall.az) * Math.cos(targetEl);
      const sy = Math.cos(wall.az) * Math.cos(targetEl);
      const sz = Math.sin(targetEl);
      const hx = sx * nearestHole.dist * wall.radius;
      const hy = sy * nearestHole.dist * wall.radius;
      const hz = sz * nearestHole.dist * wall.radius;
      const pull = gate * (wall.pull * 0.12 + attractAmt * 0.022);
      vx += (hx - x) * pull;
      vy += (hy - y) * pull;
      vz += (hz - z) * pull;
      const entrySide = previousPoint
        ? Math.sign(previousPoint.x * wallNxPos + previousPoint.y * wallNyPos)
        : Math.sign(signedWallDistance);
      const exitSide = -(entrySide || Math.sign(signedWallDistance) || 1);
      const throughX = wallNxPos * exitSide;
      const throughY = wallNyPos * exitSide;
      const incomingNormal = vx * wallNxPos + vy * wallNyPos;
      const reverseInertia = Math.abs(incomingNormal) * (0.38 + wall.spit * 0.85);
      const spit = gate * (wall.spit * (0.060 + bounceAmt * 0.040) + reverseInertia);
      vx = vx * 0.68 + throughX * spit;
      vy = vy * 0.68 + throughY * spit;
      vz = vz * 0.82 + sz * spit * 0.22;
      return;
    }
    if (distNorm < centerStopRadius / Math.max(0.001, wall.radius) && !insideSluicePlane(distNorm, elNorm)) {
      const prevSide = previousPoint
        ? Math.sign(previousPoint.x * wallNxPos + previousPoint.y * wallNyPos)
        : 0;
      const side = prevSide || Math.sign(signedWallDistance) || 1;
      const targetDistance = side * wallThickness;
      const correctionDistance = targetDistance - signedWallDistance;
      x += wallNxPos * correctionDistance;
      y += wallNyPos * correctionDistance;
      const nx = wallNxPos * side;
      const ny = wallNyPos * side;
      reboundFromWall(nx, ny, 0, Math.max(0.026, Math.abs(correctionDistance) * 0.22), 0.018 + collisionAmt * 0.014);
      vx *= 0.92;
      vy *= 0.92;
      vz *= 0.96;
      return;
    }
    const hardMargin = degToRad(2.0);
    const hardWidth = wall.halfSpan + hardMargin;
    if ((absDelta > hardWidth && Math.abs(signedWallDistance) > wallThickness) || wallFeather <= 0) return;
    const sign = signedWallDistance >= 0 ? 1 : -1;
    const nx = wallNxPos * sign;
    const ny = wallNyPos * sign;
    const nz = 0;
    const physicalPenetration = Math.max(0, wallThickness - Math.abs(signedWallDistance));
    const angularPenetration = Math.max(0, hardWidth - Math.min(absDelta, hardWidth)) * Math.max(0.18, radial);
    const overlap = Math.max(0.006, Math.max(physicalPenetration, angularPenetration) * wallFeather);
    const correction = 1.18 + collisionAmt * 0.20;
    x += nx * overlap * correction;
    y += ny * overlap * correction;
    reboundFromWall(nx, ny, nz, overlap, overlap * (0.10 + bounceAmt * 0.05));
  });
  const speed = Math.hypot(vx, vy, vz);
  const maxSpeed = 0.11 + Number(p.motion ?? 0.42) * 0.11 + bounceAmt * 0.035;
  if (speed > maxSpeed) {
    const scale = maxSpeed / speed;
    vx *= scale;
    vy *= scale;
    vz *= scale;
  }
  return {
    point: { x, y, z },
    velocity: { x: vx, y: vy, z: vz },
  };
}

function drawMotionBoundaries() {
  const t = currentT();
  if (!Number(state.arcSluice?.arcSluiceOn || 0)) return;
  drawArcSluice(globalArcSluiceBank(), t, 1);
}

function drawArcSluice(bank, t, alpha = 1) {
  const walls = arcSluiceWalls(bank, t);
  const dpr = renderPixelScale();
  const elSteps = 44;

  const wallPoint = (az, el, dist = 1) => ({
    x: Math.sin(az) * Math.cos(el) * dist,
    y: Math.cos(az) * Math.cos(el) * dist,
    z: Math.sin(el) * dist,
  });

  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.lineCap = "butt";

  walls.forEach((wall, wi) => {
    const wallAlpha = 1 - Math.min(0.46, wi * 0.07);

    const drawProjectedLine = (points, strokeStyle, lineWidth, close = false) => {
      if (!points.length) return;
      ctx.strokeStyle = strokeStyle;
      ctx.lineWidth = lineWidth;
      ctx.beginPath();
      points.forEach((pt, pi) => (pi ? ctx.lineTo(pt.x, pt.y) : ctx.moveTo(pt.x, pt.y)));
      if (close) ctx.closePath();
      ctx.stroke();
    };
    const edgeColor = `rgba(255, 201, 124, ${0.82 * wallAlpha})`;
    const shadeColor = `rgba(6, 8, 10, ${0.74 * wallAlpha})`;
    const sideA = [];
    const sideB = [];
    for (let ei = 0; ei <= elSteps; ei += 1) {
      const elNorm = ei / elSteps;
      const el = lerp(wall.elMin, wall.elMax, elNorm);
      sideA.push(project(wallPoint(wall.az - wall.halfSpan, el, wall.radius)));
      sideB.push(project(wallPoint(wall.az + wall.halfSpan, el, wall.radius)));
    }
    const topEdge = [
      project(wallPoint(wall.az - wall.halfSpan, wall.elMax, 0.12 * wall.radius)),
      project(wallPoint(wall.az + wall.halfSpan, wall.elMax, 0.12 * wall.radius)),
      project(wallPoint(wall.az + wall.halfSpan, wall.elMax, wall.radius)),
      project(wallPoint(wall.az - wall.halfSpan, wall.elMax, wall.radius)),
    ];
    const bottomEdge = [
      project(wallPoint(wall.az - wall.halfSpan, wall.elMin, 0.12 * wall.radius)),
      project(wallPoint(wall.az + wall.halfSpan, wall.elMin, 0.12 * wall.radius)),
      project(wallPoint(wall.az + wall.halfSpan, wall.elMin, wall.radius)),
      project(wallPoint(wall.az - wall.halfSpan, wall.elMin, wall.radius)),
    ];
    [sideA, sideB, topEdge, bottomEdge].forEach((points) => drawProjectedLine(points, shadeColor, 4.4 * dpr, Array.isArray(points) && points.length === 4));
    [sideA, sideB].forEach((points) => drawProjectedLine(points, edgeColor, 1.55 * dpr));
    drawProjectedLine(topEdge, edgeColor, 1.4 * dpr, true);
    drawProjectedLine(bottomEdge, `rgba(255, 183, 94, ${0.50 * wallAlpha})`, 1.1 * dpr, true);

    const holes = wall.holes || [];
    const isInsideOtherHole = (hole, dist, elNorm) => {
      return holes.some((other) => {
        if (other === hole) return false;
        const dx = (dist - other.dist) / Math.max(0.001, other.radius);
        const dy = (elNorm - other.pos) / Math.max(0.001, other.radius);
        return dx * dx + dy * dy < 0.98;
      });
    };
    const drawVisibleHoleRims = (strokeStyle, lineWidth) => {
      ctx.strokeStyle = strokeStyle;
      ctx.lineWidth = lineWidth;
      holes.forEach((hole) => {
        const rimSteps = 96;
        let drawing = false;
        ctx.beginPath();
        for (let i = 0; i <= rimSteps; i += 1) {
          const a = TWO_PI * (i / rimSteps);
          const nextA = TWO_PI * (Math.min(i + 1, rimSteps) / rimSteps);
          const midA = (a + nextA) * 0.5;
          const dist = clamp(hole.dist + Math.cos(a) * hole.radius, 0.02, 1);
          const elNorm = clamp(hole.pos + Math.sin(a) * hole.radius, 0, 1);
          const midDist = clamp(hole.dist + Math.cos(midA) * hole.radius, 0.02, 1);
          const midEl = clamp(hole.pos + Math.sin(midA) * hole.radius, 0, 1);
          const visible = !isInsideOtherHole(hole, midDist, midEl);
          const pt = project(wallPoint(wall.az, lerp(wall.elMin, wall.elMax, elNorm), dist * wall.radius));
          if (visible && !drawing) {
            ctx.moveTo(pt.x, pt.y);
            drawing = true;
          } else if (visible) {
            ctx.lineTo(pt.x, pt.y);
          } else {
            drawing = false;
          }
        }
        ctx.stroke();
      });
    };
    drawVisibleHoleRims(`rgba(5, 7, 8, ${0.70 * wallAlpha})`, 5 * dpr);
    drawVisibleHoleRims(`rgba(255, 190, 112, ${0.92 * wallAlpha})`, 2 * dpr);

  });
  ctx.restore();
}

function drawBanks() {
  const t = currentT();
  state.banks.forEach((bank, bi) => {
    const drawBank = effectiveBank(bank);
    const focused = state.groupFocus && bi === state.activeBank;
    const alpha = state.groupFocus ? (focused ? 1 : 0.32) : 1;
    if (ui.showTrails.checked) drawTrails(drawBank, alpha);
    drawBank.sources.forEach((source, si) => {
      const pos = sourcePosition(drawBank, source, t);
      const p = project(pos);
      const dpr = renderPixelScale();
      const radius = (focused && si === state.selectedSource ? 11 : 7) * dpr;
      ctx.save();
      ctx.globalAlpha = alpha;
      ctx.fillStyle = source.enabled ? COLORS[si] : "#404848";
      ctx.strokeStyle = focused ? "#f2c56e" : "#708080";
      ctx.lineWidth = 1.5 * dpr;
      ctx.beginPath();
      ctx.arc(p.x, p.y, radius, 0, TWO_PI);
      ctx.fill();
      ctx.stroke();
      if (ui.showLabels.checked || (focused && si === state.selectedSource)) {
        ctx.fillStyle = "#d7dddd";
        ctx.font = `${12 * dpr}px Menlo, monospace`;
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
  ctx.lineWidth = 1 * renderPixelScale();
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
    ctx.lineWidth = 1.5 * renderPixelScale();
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
  const dpr = renderPixelScale();
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
    if (state.recorder) {
      const recordDuration = Math.max(0.001, Number(state.recordingDuration || dur));
      state.playT = clamp((now - state.recordingStart) / 1000 / recordDuration, 0, 1);
      if (state.recordingSceneCycle && !activeBank().morph && now >= state.nextSceneAt) {
        const nextKey = nextSceneKey(activeBank().scene, false);
        if (nextKey) startSceneMorph(nextKey);
        else if (state.recorder.state !== "inactive") state.recorder.stop();
      }
      if (state.playT >= 1 && state.recorder.state !== "inactive") state.recorder.stop();
    } else {
      state.playT = pingpong01((now - state.playStart) / 1000 / dur);
    }
    if (!state.recorder && ui.autoNext.checked && !activeBank().morph && now >= state.nextSceneAt) {
      startSceneMorph();
    }
  }
  const displayDuration = state.recorder
    ? Number(state.recordingDuration || ui.duration.value)
    : Number(ui.duration.value);
  if (!reaperLink.enabled) ui.timeReadout.textContent = `${(state.playT * displayDuration).toFixed(2)}s`;
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
  updateVariantMenu(shownBank.mode, shownBank.variant || "primary");
  ui.sceneMode.value = shownBank.variant || "primary";
  if (ui.sceneMode._customButton) {
    ui.sceneMode._customButton.textContent = ui.sceneMode.selectedOptions[0]?.textContent || "Select";
  }
  ui.morphTarget.value = nextSceneKey(bank.scene);
  ui.sceneName.value = bank.scenes[bank.scene]?.name || bank.scene.toUpperCase();
  if (bank.scenes[bank.scene]) {
    ui.sceneHold.value = Number(bank.scenes[bank.scene].hold ?? ui.sceneHold.value);
    ui.morphDuration.value = Number(bank.scenes[bank.scene].morph ?? ui.morphDuration.value);
  }
  for (const key of Object.keys(shownBank.params)) {
    if (!ARC_SLUICE_PARAM_KEYS.has(key)) setParamControlValue(key, shownBank.params[key]);
  }
  ARC_SLUICE_PARAM_KEYS.forEach((key) => setParamControlValue(key, state.arcSluice[key]));
  updatePhysicsControlState(shownBank.mode);
  const source = shownBank.sources[state.selectedSource];
  ui.sourceSelect.value = String(state.selectedSource);
  ui.sourceGain.value = source.gain;
  ui.sourceAzimuth.value = wrapDeg(source.azimuth);
  ui.sourceElevation.value = clamp(source.elevation, -85, 85);
  ui.sourceDistance.value = source.distance;
  updateSourcePositionReadouts();
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
    sources: bank.sources.map(cloneSource),
    hold: Number(ui.sceneHold.value || 0),
    morph: Number(ui.morphDuration.value || 4),
  };
  if (!silent) ui.analysisReadout.textContent = `captured motion scene ${bank.scene.toUpperCase()}`;
}

function syncBankFromPanel() {
  const bank = activeBank();
  if (bank.morph) bank.morph = null;
  const previousMode = bank.mode;
  bank.mode = ui.bankMode.value;
  if (previousMode !== bank.mode) {
    updateVariantMenu(bank.mode, bank.variant || ui.sceneMode.value);
    updatePhysicsControlState(bank.mode);
  }
  bank.variant = ui.sceneMode.value;
  updatePhysicsControlState(bank.mode);
  for (const key of Object.keys(bank.params)) {
    if (ARC_SLUICE_PARAM_KEYS.has(key)) state.arcSluice[key] = readParamControlValue(key);
    else bank.params[key] = readParamControlValue(key);
  }
  propagateMotionFrom(bank);
  captureScene(bank);
  updateAllRangeFills();
}

function syncSourceFromPanel() {
  const bank = activeBank();
  const source = bank.sources[state.selectedSource];
  source.gain = Number(ui.sourceGain.value);
  source.azimuth = wrapDeg(Number(ui.sourceAzimuth.value));
  source.elevation = clamp(Number(ui.sourceElevation.value), -85, 85);
  source.distance = Number(ui.sourceDistance.value);
  updateAllRangeFills();
  captureScene(bank);
  renderBanks();
}

function syncSourcePositionControls(source) {
  ui.sourceAzimuth.value = Number(wrapDeg(source.azimuth).toFixed(1));
  ui.sourceElevation.value = Number(clamp(source.elevation, -85, 85).toFixed(1));
  ui.sourceDistance.value = Number(source.distance.toFixed(3));
  updateRangeFill(ui.sourceAzimuth);
  updateRangeFill(ui.sourceElevation);
  updateRangeFill(ui.sourceDistance);
  updateSourcePositionReadouts();
}

function renderBanks() {
  ui.bankList.innerHTML = "";
  state.banks.forEach((bank, i) => {
    const b = document.createElement("button");
    b.className = `bank-button${state.groupFocus && i === state.activeBank ? " active" : ""}`;
    b.type = "button";
    b.textContent = bank.name || `Group ${bank.id}`;
    b.addEventListener("click", () => {
      if (state.groupFocus && state.activeBank === i) {
        state.groupFocus = false;
      } else {
        state.activeBank = i;
        state.groupFocus = true;
      }
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
  if (scene.sources && scene.sources.length) {
    bank.sources = Array.from({ length: 8 }, (_, index) => normalizeSource(scene.sources[index], index));
  }
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
  if (!state.recordingSceneCycle) captureScene(bank);
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
    current.sources = bank.sources.map(cloneSource);
    current.hold = Number(ui.sceneHold.value || 0);
    current.morph = Number(ui.morphDuration.value || 4);
    bank.scenes[targetKey] = current;
  }
  const scene = bank.scenes[targetKey];
  const currentScene = bank.scenes[bank.scene] || {};
  const duration = Math.max(0.1, Number(currentScene.morph ?? ui.morphDuration.value ?? 4));
  const targetHold = Math.max(0, Number(scene.hold ?? ui.sceneHold.value ?? 0));
  const started = performance.now();
  const freezeT = currentT();
  state.banks.forEach((group, index) => {
    const from = snapshotBank(effectiveBank(group));
    const frozen = {};
    from.sources.forEach((source) => {
      frozen[source.id] = sourcePosition({ ...from, morph: null }, source, freezeT);
    });
    const target = snapshotBank(effectiveBank(group));
    target.mode = scene.mode;
    target.scene = targetKey;
    target.variant = scene.variant || "primary";
    target.params = { ...scene.params };
    target.sources = Array.from({ length: 8 }, (_, sourceIndex) => normalizeSource((scene.sources || group.sources || [])[sourceIndex], sourceIndex));
    target.hold = Number(scene.hold ?? targetHold);
    target.morph = Number(scene.morph ?? duration);
    group.morph = {
      targetKey,
      from,
      to: target,
      frozen,
      progress: 0,
      duration,
      started,
    };
  });
  state.nextSceneAt = performance.now() + (duration + targetHold) * 1000;
  updateSceneDisplays();
}

function sceneCycleDuration(bank = activeBank()) {
  return SCENES.reduce((total, key, index) => {
    const scene = bank.scenes[key] || {};
    const hold = Math.max(0, Number(scene.hold ?? ui.sceneHold.value ?? 0));
    const morph = index < SCENES.length - 1
      ? Math.max(0.1, Number(scene.morph ?? ui.morphDuration.value ?? 4))
      : 0;
    return total + hold + morph;
  }, 0);
}

function sceneMotionSnapshot(bank, key) {
  const scene = bank.scenes[key] || activeBank().scenes[key] || {};
  return {
    ...snapshotBank(bank),
    mode: scene.mode || bank.mode,
    scene: key,
    variant: scene.variant || bank.variant || "primary",
    params: normalizeParams(scene.params || bank.params),
    sources: Array.from({ length: 8 }, (_, index) => normalizeSource((scene.sources || bank.sources || [])[index], index)),
    morph: null,
  };
}

function sceneCycleBankAt(bank, seconds, totalDuration) {
  let cursor = 0;
  for (let index = 0; index < SCENES.length; index += 1) {
    const key = SCENES[index];
    const scene = bank.scenes[key] || activeBank().scenes[key] || {};
    const current = sceneMotionSnapshot(bank, key);
    const hold = Math.max(0, Number(scene.hold ?? ui.sceneHold.value ?? 0));
    if (seconds <= cursor + hold || index === SCENES.length - 1) return current;
    cursor += hold;
    const nextKey = SCENES[index + 1];
    const morph = Math.max(0.1, Number(scene.morph ?? ui.morphDuration.value ?? 4));
    if (seconds <= cursor + morph) {
      const next = sceneMotionSnapshot(bank, nextKey);
      const progress = clamp((seconds - cursor) / morph, 0, 1);
      return {
        ...current,
        ...blendSnapshots(current, next, progress),
        sources: current.sources.map((source, index) => blendSource(source, next.sources[index] || source, smooth(clamp(progress, 0, 1)))),
        morph: null,
      };
    }
    cursor += morph;
  }
  const finalKey = SCENES[SCENES.length - 1];
  return sceneMotionSnapshot(bank, finalKey);
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
    const generatedBanks = MOTION_BANKS.filter((mode) => mode !== "manual");
    bank.mode = generatedBanks[Math.abs(seed) % generatedBanks.length];
  }
  bank.variant = VARIANTS[seed % VARIANTS.length];
  Object.keys(bank.params).forEach((key, i) => {
    if (ARC_SLUICE_PARAM_KEYS.has(key)) return;
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
  const globalMorph = Number(ui.morphDuration.value || 4);
  state.banks.forEach((group, index) => {
    group.motionOffset = makeGroupOffset(index, baseSeed + index * 53);
  });
  SCENES.forEach((key, index) => {
    const sceneSeed = baseSeed + index * 37;
    const timing = generatedTiming(sceneSeed, index);
    bank.scene = key;
    ui.sceneHold.value = timing.hold;
    ui.morphDuration.value = ui.randomMorphTime.checked ? timing.morph : globalMorph;
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
  const duration = Math.max(1, sceneCycleDuration(activeBank()));
  const pointRate = Number(ui.pointRate.value);
  const pointCount = Math.max(2, Math.round(duration * pointRate));
  return {
    tool: "s3g-mc Spatial Score",
    format: "s3g_mc_mover_v1",
    version: 1,
    target: "s3g 8ch 3OA Object Encoder",
    order: 3,
    duration,
    point_rate: pointRate,
    arc_sluice: { ...state.arcSluice },
    browser_state: {
      active_group: state.activeBank + 1,
      group_focus: state.groupFocus,
      selected_source: state.selectedSource + 1,
      morph_duration: Number(ui.morphDuration.value),
      hold_duration: Number(ui.sceneHold.value),
      loop_scenes: ui.sceneLoop.checked,
      vary_scene_banks: ui.varySceneBanks.checked,
      random_morph_time: ui.randomMorphTime.checked,
      camera_azimuth: Number(ui.cameraAz.value),
      camera_elevation: Number(ui.cameraEl.value),
      zoom: Number(ui.zoom.value),
      spatial_constraint: ui.spatialConstraint.value,
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
      const exportBank = sceneCycleBankAt(bank, 0, duration);
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
          const seconds = t * duration;
          const timelineBank = sceneCycleBankAt(bank, seconds, duration);
          const timelineSource = timelineBank.sources.find((item) => item.id === source.id) || source;
          const p = sourcePosition(timelineBank, timelineSource, t);
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
  a.download = `s3g-mc-spatial-score-${Date.now()}.json`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

function recorderMimeType() {
  const candidates = [
    "video/webm;codecs=vp9",
    "video/webm;codecs=vp8",
    "video/webm",
  ];
  return candidates.find((type) => window.MediaRecorder?.isTypeSupported(type)) || "";
}

function recordCanvasClip() {
  if (state.recorder) {
    state.recorder.stop();
    return;
  }
  if (!canvas.captureStream || !window.MediaRecorder) {
    ui.analysisReadout.textContent = "canvas recording is not supported in this browser";
    return;
  }
  const bank = activeBank();
  if (!bank.scenes.a) captureScene(bank);
  bank.scene = "a";
  applyScene(bank.scenes.a || snapshotBank(bank));
  const duration = Math.max(1, sceneCycleDuration(bank));
  const rect = canvas.getBoundingClientRect();
  const baseDpr = window.devicePixelRatio || 1;
  const baseLongEdge = Math.max(rect.width, rect.height) * baseDpr;
  const targetLongEdge = 2560;
  const recordingScale = clamp(targetLongEdge / Math.max(1, baseLongEdge), 1, 3);
  state.recordingScale = recordingScale;
  resizeCanvas();
  drawFrame();
  const stream = canvas.captureStream(30);
  const mimeType = recorderMimeType();
  const chunks = [];
  const recorderOptions = {
    videoBitsPerSecond: 16_000_000,
    ...(mimeType ? { mimeType } : {}),
  };
  const recorder = new MediaRecorder(stream, recorderOptions);
  const wasPlaying = state.playing;
  const previousT = state.playT;
  recorder.ondataavailable = (event) => {
    if (event.data && event.data.size) chunks.push(event.data);
  };
  recorder.onstop = () => {
    stream.getTracks().forEach((track) => track.stop());
    state.recorder = null;
    state.recordingStart = 0;
    state.recordingDuration = 0;
    state.recordingSceneCycle = false;
    state.recordingScale = 1;
    resizeCanvas();
    ui.recordClip.textContent = "Record";
    ui.recordClip.classList.remove("active");
    const type = recorder.mimeType || "video/webm";
    if (chunks.length) {
      downloadBlob(new Blob(chunks, { type }), `s3g-mc-spatial-score-${Date.now()}.webm`);
      ui.analysisReadout.textContent = `recorded ${duration.toFixed(1)}s A-H scene-cycle HD clip`;
    }
    state.playing = wasPlaying;
    state.playT = wasPlaying ? state.playT : previousT;
    state.playStart = performance.now() - state.playT * duration * 1000;
  };
  state.recorder = recorder;
  state.recordingDuration = duration;
  state.recordingSceneCycle = true;
  state.recordingStart = performance.now();
  state.playT = 0;
  state.playing = true;
  state.playStart = state.recordingStart;
  state.nextSceneAt = state.recordingStart + Math.max(0, Number(bank.scenes.a?.hold ?? ui.sceneHold.value ?? 0)) * 1000;
  ui.recordClip.textContent = "Stop Rec";
  ui.recordClip.classList.add("active");
  ui.analysisReadout.textContent = `recording ${duration.toFixed(1)}s A-H scene-cycle HD clip at ${canvas.width} x ${canvas.height}`;
  recorder.start();
  window.setTimeout(() => {
    if (state.recorder === recorder && recorder.state !== "inactive") recorder.stop();
  }, duration * 1000 + 250);
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
    throw new Error("not a s3g-mc Spatial Score JSON file");
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
        sources: Array.from({ length: 8 }, (_, si) => normalizeSource((scene.sources || bank.sources || [])[si], si)),
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
        sources: bank.sources.map(cloneSource),
        hold: Number(data.browser_state?.hold_duration ?? 1),
        morph: Number(data.browser_state?.morph_duration ?? 4),
      };
    }
    return bank;
  });
  if (!state.banks.length) state.banks = [makeBank(0, "Group 1")];
  const firstArcSource = state.banks.find((bank) => Number(bank.params?.arcSluiceOn || 0))?.params
    || state.banks[0]?.params
    || defaultArcSluiceParams();
  state.arcSluice = normalizeArcSluiceParams(data.arc_sluice || firstArcSource);

  const bs = data.browser_state || {};
  ui.duration.value = Number(data.duration || 16);
  ui.pointRate.value = Number(data.point_rate || 32);
  ui.morphDuration.value = Number(bs.morph_duration ?? ui.morphDuration.value);
  ui.sceneHold.value = Number(bs.hold_duration ?? ui.sceneHold.value);
  ui.sceneLoop.checked = bs.loop_scenes !== false;
  ui.varySceneBanks.checked = bs.vary_scene_banks === true;
  ui.randomMorphTime.checked = bs.random_morph_time !== false;
  ui.cameraAz.value = Number(bs.camera_azimuth ?? ui.cameraAz.value);
  ui.cameraEl.value = Number(bs.camera_elevation ?? ui.cameraEl.value);
  ui.zoom.value = Number(bs.zoom ?? ui.zoom.value);
  ui.spatialConstraint.value = bs.spatial_constraint === "hemisphere" ? "hemisphere" : "sphere";
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
  state.groupFocus = bs.group_focus !== false;
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

function placeSelectedSourceFromPointer(event) {
  const mouse = pointerPoint(event);
  const scale = Math.min(canvas.width, canvas.height) * 0.26 * Number(ui.zoom.value);
  const dx = (mouse.x - canvas.width * 0.5) / scale;
  const dy = -(mouse.y - canvas.height * 0.52) / scale;
  const source = activeBank().sources[state.selectedSource];
  source.azimuth = azimuthFromVector(dx, Math.max(0.001, dy));
  source.elevation = clamp(dy * 45, -80, 80);
  source.distance = clamp(Math.hypot(dx, dy), 0.1, 3);
  source.enabled = true;
  source.gain = Math.max(Number(source.gain || 0), 0.001);
  syncSourcePositionControls(source);
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
    state.groupFocus = true;
    state.selectedSource = hit.source;
    const bank = activeBank();
    if (bank.mode !== "manual") {
      bank.mode = "manual";
      bank.variant = "primary";
      propagateMotionFrom(bank);
    }
    state.dragging = hit;
    canvas.setPointerCapture(event.pointerId);
    syncPanelFromBank();
  } else {
    const bank = activeBank();
    if (bank.mode === "manual") {
      state.groupFocus = true;
      state.dragging = { bank: state.activeBank, source: state.selectedSource };
      placeSelectedSourceFromPointer(event);
      canvas.setPointerCapture(event.pointerId);
      syncPanelFromBank();
    } else {
      state.groupFocus = false;
      renderBanks();
    }
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
  placeSelectedSourceFromPointer(event);
});

canvas.addEventListener("pointerup", (event) => {
  if (state.dragging && activeBank().mode === "manual") {
    captureScene(activeBank());
    propagateMotionFrom(activeBank());
    syncPanelFromBank();
  }
  state.dragging = null;
  state.viewDrag = null;
  try {
    canvas.releasePointerCapture(event.pointerId);
  } catch (_) {}
});

canvas.addEventListener("wheel", (event) => {
  event.preventDefault();
  const current = Number(ui.zoom.value || 1);
  const min = Number(ui.zoom.min || 0.45);
  const max = Number(ui.zoom.max || 2.8);
  const direction = event.deltaY < 0 ? 1 : -1;
  const amount = event.altKey ? 0.035 : event.shiftKey ? 0.16 : 0.08;
  const next = clamp(current * (1 + direction * amount), min, max);
  ui.zoom.value = next.toFixed(2);
  updateRangeFill(ui.zoom);
}, { passive: false });

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
ui.recordClip.addEventListener("click", recordCanvasClip);
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
  next.params = preserveArcSluiceParams({ ...current.params }, next.params);
  state.banks.push(next);
  state.activeBank = state.banks.length - 1;
  state.groupFocus = true;
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
  state.groupFocus = true;
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
    const sourceControls = ["sourceGain", "sourceAzimuth", "sourceElevation", "sourceDistance"];
    const interfaceControls = [
      "morphTarget", "autoNext", "sceneLoop", "varySceneBanks", "randomMorphTime",
      "cameraAz", "cameraEl", "zoom", "spatialConstraint", "analysisScope", "neighborLinks", "showAnalysis", "showCentroid", "showTrails", "showLabels",
    ];
    if (sourceControls.includes(input.id)) {
      if (input.type === "range") updateRangeFill(input);
      syncSourceFromPanel();
      updateSourcePositionReadouts();
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
