const W = 512;
const H = 256;

const scoreCanvas = document.getElementById("scoreCanvas");
const overlayCanvas = document.getElementById("overlayCanvas");
const actualCanvas = document.getElementById("actualCanvas");
const aedSphereCanvas = document.getElementById("aedSphereCanvas");
const aedLargeCanvas = document.getElementById("aedLargeCanvas");
const maskCanvas = document.getElementById("maskCanvas");
const colorColumnCanvas = document.getElementById("colorColumnCanvas");
const maskColumnCanvas = document.getElementById("maskColumnCanvas");
const scoreCtx = scoreCanvas.getContext("2d", { willReadFrequently: true });
const overlayCtx = overlayCanvas.getContext("2d");
const actualCtx = actualCanvas.getContext("2d");
const aedSphereCtx = aedSphereCanvas.getContext("2d", { willReadFrequently: true });
const aedLargeCtx = aedLargeCanvas.getContext("2d", { willReadFrequently: true });
const maskCtx = maskCanvas.getContext("2d", { willReadFrequently: true });
const colorColumnCtx = colorColumnCanvas.getContext("2d", { willReadFrequently: true });
const maskColumnCtx = maskColumnCanvas.getContext("2d", { willReadFrequently: true });

const colorCanvas = document.createElement("canvas");
const alphaCanvas = document.createElement("canvas");
colorCanvas.width = alphaCanvas.width = W;
colorCanvas.height = alphaCanvas.height = H;
const colorCtx = colorCanvas.getContext("2d", { willReadFrequently: true });
const alphaCtx = alphaCanvas.getContext("2d", { willReadFrequently: true });

const state = {
  tool: "brush",
  layer: "both",
  drawing: false,
  start: null,
  last: null,
  mask: null,
  aedCamera: "front",
  aedYaw: 0,
  aedPitch: 0,
  aedDragging: false,
  playing: false,
  playhead: 0,
  lastFrameTime: 0,
  raf: 0
};

const $ = (id) => document.getElementById(id);
const controls = {
  brushSize: $("brushSize"),
  brushOpacity: $("brushOpacity"),
  brushSoftness: $("brushSoftness"),
  alphaPaint: $("alphaPaint"),
  azimuth: $("azimuth"),
  elevation: $("elevation"),
  distance: $("distance"),
  colorModel: $("colorModel"),
  rule: $("rule"),
  palette: $("palette"),
  density: $("density"),
  freqSpread: $("freqSpread"),
  gestureDrift: $("gestureDrift"),
  seed: $("seed"),
  maskMode: $("maskMode"),
  threshold: $("threshold"),
  curve: $("curve"),
  readout: $("readout"),
  aedColorSwatch: $("aedColorSwatch"),
  aedColorText: $("aedColorText"),
  colorModelText: $("colorModelText"),
  playToggle: $("playToggle"),
  playhead: $("playhead"),
  playSpeed: $("playSpeed"),
  playReadout: $("playReadout")
};

function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, v));
}

function mulberry32(seed) {
  let t = seed >>> 0;
  return function rand() {
    t += 0x6d2b79f5;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r ^= r + Math.imul(r ^ (r >>> 7), 61 | r);
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

function currentHsl() {
  const az = Number(controls.azimuth.value);
  const el = Number(controls.elevation.value);
  const dist = Number(controls.distance.value) / 100;
  return {
    hue: ((az + 180) / 360) * 360,
    sat: 22 + dist * 72,
    light: 12 + ((el + 90) / 180) * 76
  };
}

function hslToRgb(h, s, l) {
  const hue = ((h % 360) + 360) % 360 / 360;
  const sat = clamp(s / 100, 0, 1);
  const light = clamp(l / 100, 0, 1);
  if (sat === 0) {
    const v = Math.round(light * 255);
    return { r: v, g: v, b: v };
  }
  const q = light < 0.5 ? light * (1 + sat) : light + sat - light * sat;
  const p = 2 * light - q;
  const hue2rgb = (t) => {
    let tt = t;
    if (tt < 0) tt += 1;
    if (tt > 1) tt -= 1;
    if (tt < 1 / 6) return p + (q - p) * 6 * tt;
    if (tt < 1 / 2) return q;
    if (tt < 2 / 3) return p + (q - p) * (2 / 3 - tt) * 6;
    return p;
  };
  return {
    r: Math.round(hue2rgb(hue + 1 / 3) * 255),
    g: Math.round(hue2rgb(hue) * 255),
    b: Math.round(hue2rgb(hue - 1 / 3) * 255)
  };
}

function hsvToRgb(h, s, v) {
  const hue = ((h % 360) + 360) % 360 / 60;
  const sat = clamp(s / 100, 0, 1);
  const val = clamp(v / 100, 0, 1);
  const c = val * sat;
  const x = c * (1 - Math.abs((hue % 2) - 1));
  const m = val - c;
  let rr = 0;
  let gg = 0;
  let bb = 0;
  if (hue < 1) [rr, gg, bb] = [c, x, 0];
  else if (hue < 2) [rr, gg, bb] = [x, c, 0];
  else if (hue < 3) [rr, gg, bb] = [0, c, x];
  else if (hue < 4) [rr, gg, bb] = [0, x, c];
  else if (hue < 5) [rr, gg, bb] = [x, 0, c];
  else [rr, gg, bb] = [c, 0, x];
  return {
    r: Math.round((rr + m) * 255),
    g: Math.round((gg + m) * 255),
    b: Math.round((bb + m) * 255)
  };
}

function srgbToLinear(v) {
  const x = clamp(v, 0, 1);
  return x <= 0.04045 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4);
}

function linearToSrgb(v) {
  const x = clamp(v, 0, 1);
  return x <= 0.0031308 ? x * 12.92 : 1.055 * Math.pow(x, 1 / 2.4) - 0.055;
}

function oklchToRgb(hue, chroma, light) {
  const L = clamp(light, 0, 1);
  const C = clamp(chroma, 0, 1) * 0.37;
  const a = Math.cos(hue * Math.PI * 2) * C;
  const b = Math.sin(hue * Math.PI * 2) * C;
  const l3 = L + 0.3963377774 * a + 0.2158037573 * b;
  const m3 = L - 0.1055613458 * a - 0.0638541728 * b;
  const s3 = L - 0.0894841775 * a - 1.2914855480 * b;
  const l = l3 * l3 * l3;
  const m = m3 * m3 * m3;
  const s = s3 * s3 * s3;
  const r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
  const g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
  const bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;
  return {
    r: Math.round(linearToSrgb(r) * 255),
    g: Math.round(linearToSrgb(g) * 255),
    b: Math.round(linearToSrgb(bb) * 255)
  };
}

function rgbToOklch(r, g, b) {
  const rr = srgbToLinear(r / 255);
  const gg = srgbToLinear(g / 255);
  const bb = srgbToLinear(b / 255);
  const l = 0.4122214708 * rr + 0.5363325363 * gg + 0.0514459929 * bb;
  const m = 0.2119034982 * rr + 0.6806995451 * gg + 0.1073969566 * bb;
  const s = 0.0883024619 * rr + 0.2817188370 * gg + 0.6299787005 * bb;
  const l3 = Math.cbrt(Math.max(0, l));
  const m3 = Math.cbrt(Math.max(0, m));
  const s3 = Math.cbrt(Math.max(0, s));
  const L = 0.2104542553 * l3 + 0.7936177850 * m3 - 0.0040720468 * s3;
  const a = 1.9779984951 * l3 - 2.4285922050 * m3 + 0.4505937099 * s3;
  const ob = 0.0259040371 * l3 + 0.7827717662 * m3 - 0.8086757660 * s3;
  return {
    h: ((Math.atan2(ob, a) / (Math.PI * 2)) % 1 + 1) % 1,
    c: clamp(Math.sqrt(a * a + ob * ob) / 0.37, 0, 1),
    l: clamp(L, 0, 1)
  };
}

function ycbcrToRgb(hue, chroma, luma) {
  const angle = (hue - 0.25) * Math.PI * 2;
  const c = clamp(chroma, 0, 1) / 2.2;
  const cb = Math.sin(angle) * c;
  const cr = Math.cos(angle) * c;
  const y = clamp(luma, 0, 1);
  return {
    r: Math.round(clamp(y + cr / 0.713, 0, 1) * 255),
    g: Math.round(clamp((y - 0.114 * (y + cb / 0.564) - 0.299 * (y + cr / 0.713)) / 0.587, 0, 1) * 255),
    b: Math.round(clamp(y + cb / 0.564, 0, 1) * 255)
  };
}

function rgbToYcbcr(r, g, b) {
  const rr = r / 255;
  const gg = g / 255;
  const bb = b / 255;
  const y = 0.299 * rr + 0.587 * gg + 0.114 * bb;
  const cb = (bb - y) * 0.564;
  const cr = (rr - y) * 0.713;
  return {
    h: ((Math.atan2(cb, cr) / (Math.PI * 2) + 0.25) % 1 + 1) % 1,
    c: clamp(Math.sqrt(cb * cb + cr * cr) * 2.2, 0, 1),
    l: clamp(y, 0, 1)
  };
}

function rgbToHsl(r, g, b) {
  const rr = r / 255;
  const gg = g / 255;
  const bb = b / 255;
  const max = Math.max(rr, gg, bb);
  const min = Math.min(rr, gg, bb);
  let h = 0;
  let s = 0;
  const l = (max + min) / 2;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    if (max === rr) h = (gg - bb) / d + (gg < bb ? 6 : 0);
    else if (max === gg) h = (bb - rr) / d + 2;
    else h = (rr - gg) / d + 4;
    h /= 6;
  }
  return { h: h * 360, s: s * 100, l: l * 100 };
}

function rgbToHsv(r, g, b) {
  const rr = r / 255;
  const gg = g / 255;
  const bb = b / 255;
  const max = Math.max(rr, gg, bb);
  const min = Math.min(rr, gg, bb);
  const d = max - min;
  let h = 0;
  if (d !== 0) {
    if (max === rr) h = ((gg - bb) / d) % 6;
    else if (max === gg) h = (bb - rr) / d + 2;
    else h = (rr - gg) / d + 4;
    h *= 60;
  }
  if (h < 0) h += 360;
  return { h, s: max === 0 ? 0 : d / max * 100, v: max * 100 };
}

function aedToVector(azDeg, elDeg, dist) {
  const az = azDeg * Math.PI / 180;
  const el = elDeg * Math.PI / 180;
  return {
    x: Math.sin(az) * Math.cos(el) * dist,
    y: Math.sin(el) * dist,
    z: Math.cos(az) * Math.cos(el) * dist
  };
}

function vectorToAed(x, y, z) {
  const dist = clamp(Math.sqrt(x * x + y * y + z * z), 0, 1);
  if (dist < 1e-6) return { az: 0, el: 0, dist: 0 };
  return {
    az: Math.atan2(x, z) * 180 / Math.PI,
    el: Math.asin(clamp(y / dist, -1, 1)) * 180 / Math.PI,
    dist
  };
}

function currentRgb() {
  return encodeAedColor(
    Number(controls.azimuth.value),
    Number(controls.elevation.value),
    Number(controls.distance.value) / 100,
    controls.colorModel.value
  );
}

function currentColor() {
  const rgb = currentRgb();
  return `rgb(${rgb.r} ${rgb.g} ${rgb.b})`;
}

function colorFromAed(az, el, dist) {
  const rgb = encodeAedColor(az, el, dist, controls.colorModel.value);
  return `rgb(${rgb.r} ${rgb.g} ${rgb.b})`;
}

function encodeAedColor(az, el, dist, model = "hsl") {
  const hue01 = (((az + 180) / 360) % 1 + 1) % 1;
  const hue = hue01 * 360;
  const dd = clamp(dist, 0, 1);
  const ee = clamp(el, -90, 90);
  const light = (ee + 90) / 180;
  if (model === "oklch") {
    return oklchToRgb(hue01, dd, light);
  }
  if (model === "hsv") {
    return hsvToRgb(hue, dd * 100, light * 100);
  }
  if (model === "ycbcr") {
    return ycbcrToRgb(hue01, dd, light);
  }
  return hslToRgb(hue, dd * 100, light * 100);
}

function decodeAedColor(r, g, b, model = "hsl") {
  if (model === "oklch") {
    const oklch = rgbToOklch(r, g, b);
    return {
      az: oklch.h * 360 - 180,
      el: oklch.l * 180 - 90,
      dist: clamp(oklch.c, 0.05, 1)
    };
  }
  if (model === "hsv") {
    const hsv = rgbToHsv(r, g, b);
    return {
      az: hsv.h / 360 * 360 - 180,
      el: clamp((hsv.v / 100) * 180 - 90, -90, 90),
      dist: clamp(hsv.s / 100, 0.05, 1)
    };
  }
  if (model === "ycbcr") {
    const ycbcr = rgbToYcbcr(r, g, b);
    return {
      az: ycbcr.h * 360 - 180,
      el: ycbcr.l * 180 - 90,
      dist: clamp(ycbcr.c, 0.05, 1)
    };
  }
  const hsl = rgbToHsl(r, g, b);
  return {
    az: hsl.h / 360 * 360 - 180,
    el: clamp((hsl.l / 100) * 180 - 90, -90, 90),
    dist: clamp(hsl.s / 100, 0.05, 1)
  };
}

const palettes = {
  aed_full: [
    [-180, -55, 0.7],
    [-90, 0, 0.95],
    [0, 70, 0.8],
    [90, 0, 0.95],
    [180, -45, 0.7]
  ],
  front_focus: [
    [-60, -12, 0.55],
    [-25, 8, 0.78],
    [0, 42, 0.85],
    [25, 8, 0.78],
    [60, -12, 0.55]
  ],
  over_under: [
    [-135, -75, 0.82],
    [-45, -12, 0.68],
    [0, 78, 0.95],
    [45, -12, 0.68],
    [135, -75, 0.82]
  ],
  dusk: [
    [-160, -25, 0.42],
    [-85, 18, 0.55],
    [10, 52, 0.68],
    [95, 12, 0.48],
    [165, -38, 0.36]
  ],
  ember_ice: [
    [-150, -35, 0.4],
    [-35, -12, 0.82],
    [15, 18, 0.72],
    [115, 40, 0.68],
    [180, -28, 0.44]
  ],
  terrain: [
    [-135, -70, 0.62],
    [-65, -22, 0.54],
    [0, 8, 0.48],
    [68, 36, 0.58],
    [135, 76, 0.72]
  ],
  signal: [
    [-180, -5, 0.88],
    [-110, 45, 0.95],
    [0, 0, 0.7],
    [110, 45, 0.95],
    [180, -5, 0.88]
  ],
  mono_blue: [
    [72, -68, 0.42],
    [80, -20, 0.52],
    [88, 20, 0.68],
    [98, 62, 0.82]
  ],
  mono_amber: [
    [-150, -62, 0.38],
    [-142, -18, 0.54],
    [-132, 28, 0.72],
    [-120, 72, 0.88]
  ]
};

function paletteColor(name, t, rand, drift) {
  const palette = palettes[name] || palettes.aed_full;
  const scaled = clamp(t, 0, 1) * (palette.length - 1);
  const index = Math.floor(scaled);
  const frac = scaled - index;
  const a = palette[index];
  const b = palette[Math.min(index + 1, palette.length - 1)];
  const wobble = (rand() - 0.5) * drift;
  const az = a[0] + (b[0] - a[0]) * frac + wobble * 70;
  const el = a[1] + (b[1] - a[1]) * frac + wobble * 46;
  const dist = a[2] + (b[2] - a[2]) * frac + wobble * 0.2;
  return colorFromAed(az, el, dist);
}

function updateAedSwatch() {
  const az = Number(controls.azimuth.value);
  const el = Number(controls.elevation.value);
  const dist = Number(controls.distance.value) / 100;
  const color = currentColor();
  const rgb = currentRgb();
  controls.aedColorSwatch.style.background = color;
  controls.aedColorText.innerHTML = `<span>AED ${az.toFixed(0)} / ${el.toFixed(0)} / ${dist.toFixed(2)}</span><span>RGB ${rgb.r}, ${rgb.g}, ${rgb.b}</span>`;
  const modelText = {
    oklch: "OKLCH: hue azimuth, chroma distance, light elevation",
    hsl: "HSL: hue azimuth, saturation distance, light elevation",
    hsv: "HSV: hue azimuth, saturation distance, value elevation",
    ycbcr: "YCbCr: chroma angle azimuth, chroma distance, luma elevation"
  };
  controls.colorModelText.textContent = modelText[controls.colorModel.value] || modelText.oklch;
  updateRangeFill(controls.azimuth);
  updateRangeFill(controls.elevation);
  updateRangeFill(controls.distance);
}

function currentAlpha() {
  return Number(controls.alphaPaint.value) / 100;
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

function canvasPoint(event) {
  const rect = scoreCanvas.getBoundingClientRect();
  return {
    x: clamp((event.clientX - rect.left) / rect.width * W, 0, W - 1),
    y: clamp((event.clientY - rect.top) / rect.height * H, 0, H - 1)
  };
}

function drawOverlay() {
  overlayCtx.clearRect(0, 0, W, H);
  overlayCtx.strokeStyle = "rgba(255,255,255,0.18)";
  overlayCtx.lineWidth = 1;
  for (let x = 64; x < W; x += 64) {
    overlayCtx.beginPath();
    overlayCtx.moveTo(x + 0.5, 0);
    overlayCtx.lineTo(x + 0.5, H);
    overlayCtx.stroke();
  }
  for (let y = 32; y < H; y += 32) {
    overlayCtx.beginPath();
    overlayCtx.moveTo(0, y + 0.5);
    overlayCtx.lineTo(W, y + 0.5);
    overlayCtx.stroke();
  }
}

function drawPlayOverlay() {
  drawOverlay();
  const x = Math.round(state.playhead);
  const mask = state.mask?.data;
  overlayCtx.save();
  overlayCtx.strokeStyle = "rgba(90, 190, 220, 0.96)";
  overlayCtx.lineWidth = 1;
  overlayCtx.beginPath();
  overlayCtx.moveTo(x + 0.5, 0);
  overlayCtx.lineTo(x + 0.5, H);
  overlayCtx.stroke();

  if (mask) {
    overlayCtx.fillStyle = "rgba(104, 202, 232, 0.82)";
    overlayCtx.strokeStyle = "rgba(0, 0, 0, 0.55)";
    for (let y = 0; y < H; y += 1) {
      const value = mask[(y * W + x) * 4];
      if (value > 18) {
        const width = 3 + (value / 255) * 13;
        overlayCtx.fillRect(x - width * 0.5, y, width, 1);
      }
    }
  }
  overlayCtx.fillStyle = "rgba(90, 190, 220, 0.96)";
  overlayCtx.fillRect(Math.max(0, x - 2), 0, 5, 5);
  overlayCtx.fillRect(Math.max(0, x - 2), H - 5, 5, 5);
  overlayCtx.restore();
}

function drawColumnWindows() {
  const x = Math.round(state.playhead);
  const rgb = colorCtx.getImageData(x, 0, 1, H).data;
  const mask = state.mask?.data;
  const colorImage = colorColumnCtx.createImageData(colorColumnCanvas.width, H);
  const maskImage = maskColumnCtx.createImageData(maskColumnCanvas.width, H);

  for (let y = 0; y < H; y += 1) {
    const ri = y * 4;
    const mv = mask ? mask[(y * W + x) * 4] : 0;
    for (let sx = 0; sx < colorColumnCanvas.width; sx += 1) {
      const i = (y * colorColumnCanvas.width + sx) * 4;
      colorImage.data[i] = rgb[ri];
      colorImage.data[i + 1] = rgb[ri + 1];
      colorImage.data[i + 2] = rgb[ri + 2];
      colorImage.data[i + 3] = 255;
      maskImage.data[i] = mv;
      maskImage.data[i + 1] = mv;
      maskImage.data[i + 2] = mv;
      maskImage.data[i + 3] = 255;
    }
  }
  colorColumnCtx.putImageData(colorImage, 0, 0);
  maskColumnCtx.putImageData(maskImage, 0, 0);
  drawAedSphere(rgb, mask, x);
}

function projectAedPoint(azDeg, elDeg, dist, canvas) {
  const az = azDeg * Math.PI / 180;
  const el = elDeg * Math.PI / 180;
  let x = Math.sin(az) * Math.cos(el) * dist;
  let y = Math.sin(el) * dist;
  let z = Math.cos(az) * Math.cos(el) * dist;

  const yaw = state.aedYaw * Math.PI / 180;
  const pitch = state.aedPitch * Math.PI / 180;
  const cosYaw = Math.cos(yaw);
  const sinYaw = Math.sin(yaw);
  const cosPitch = Math.cos(pitch);
  const sinPitch = Math.sin(pitch);
  const x1 = x * cosYaw - z * sinYaw;
  const z1 = x * sinYaw + z * cosYaw;
  const y1 = y * cosPitch - z1 * sinPitch;
  const z2 = y * sinPitch + z1 * cosPitch;
  x = x1;
  y = y1;
  z = z2;

  const cx = canvas.width / 2;
  const cy = canvas.height / 2;
  const scale = Math.min(canvas.width, canvas.height) * 0.38;
  return {
    x: cx - x * scale,
    y: cy - y * scale,
    z,
    visible: z > -0.92
  };
}

function drawAedSphereTo(ctx, canvas, rgbColumn, mask, columnX) {
  const w = canvas.width;
  const h = canvas.height;
  const cx = w / 2;
  const cy = h / 2;
  const r = Math.min(w, h) * 0.38;
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = "#050607";
  ctx.fillRect(0, 0, w, h);

  ctx.save();
  ctx.strokeStyle = "rgba(210, 210, 210, 0.42)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.arc(cx, cy, r, 0, Math.PI * 2);
  ctx.stroke();
  ctx.strokeStyle = "rgba(120, 120, 120, 0.34)";
  ctx.beginPath();
  ctx.ellipse(cx, cy, r, r * 0.28, 0, 0, Math.PI * 2);
  ctx.stroke();
  ctx.beginPath();
  ctx.ellipse(cx, cy, r * 0.28, r, 0, 0, Math.PI * 2);
  ctx.stroke();
  ctx.fillStyle = "rgba(210, 210, 210, 0.72)";
  ctx.font = "10px Menlo, monospace";
  ctx.fillText(`${state.aedCamera.toUpperCase()} ${state.aedYaw.toFixed(0)} / ${state.aedPitch.toFixed(0)}`, 8, 15);

  const points = [];
  for (let y = 0; y < H; y += 2) {
    const ri = y * 4;
    const amp = mask ? mask[(y * W + columnX) * 4] / 255 : 0;
    if (amp < 0.08) continue;
    const decoded = decodeAedColor(rgbColumn[ri], rgbColumn[ri + 1], rgbColumn[ri + 2], controls.colorModel.value);
    const az = decoded.az;
    const el = decoded.el;
    const dist = decoded.dist;
    const p = projectAedPoint(az, el, dist, canvas);
    points.push({ ...p, amp, color: `rgb(${rgbColumn[ri]} ${rgbColumn[ri + 1]} ${rgbColumn[ri + 2]})` });
  }
  points.sort((a, b) => a.z - b.z);
  points.forEach((p) => {
    if (!p.visible) return;
    const size = 1.4 + p.amp * 5.8 + Math.max(0, p.z) * 1.2;
    ctx.globalAlpha = 0.28 + p.amp * 0.72;
    ctx.fillStyle = p.color;
    ctx.beginPath();
    ctx.arc(p.x, p.y, size, 0, Math.PI * 2);
    ctx.fill();
  });
  ctx.globalAlpha = 1;
  ctx.fillStyle = "rgba(90, 190, 220, 0.86)";
  ctx.beginPath();
  ctx.arc(cx, cy, 2.5, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function drawAedSphere(rgbColumn, mask, columnX) {
  drawAedSphereTo(aedSphereCtx, aedSphereCanvas, rgbColumn, mask, columnX);
  if (!$("aedLightbox").hidden) {
    drawAedSphereTo(aedLargeCtx, aedLargeCanvas, rgbColumn, mask, columnX);
  }
}

function setAedCamera(name, yaw, pitch) {
  state.aedCamera = name;
  state.aedYaw = yaw;
  state.aedPitch = clamp(pitch, -89, 89);
  document.querySelectorAll("[data-aed-camera]").forEach((button) => {
    button.classList.toggle("active", button.dataset.aedCamera === name);
  });
  drawColumnWindows();
}

function setAedCameraFromEvent(event, canvas = aedSphereCanvas) {
  const rect = canvas.getBoundingClientRect();
  const nx = clamp((event.clientX - rect.left) / rect.width, 0, 1);
  const ny = clamp((event.clientY - rect.top) / rect.height, 0, 1);
  state.aedCamera = "custom";
  state.aedYaw = (nx - 0.5) * 360;
  state.aedPitch = (0.5 - ny) * 160;
  document.querySelectorAll("[data-aed-camera]").forEach((button) => button.classList.remove("active"));
  drawColumnWindows();
}

function setPlayhead(value) {
  state.playhead = clamp(Number(value) || 0, 0, W - 1);
  controls.playhead.value = String(Math.round(state.playhead));
  updateRangeFill(controls.playhead);
  controls.playReadout.textContent = `col ${String(Math.round(state.playhead)).padStart(3, "0")}`;
  drawPlayOverlay();
  drawColumnWindows();
}

function animationFrame(time) {
  if (!state.playing) return;
  if (!state.lastFrameTime) state.lastFrameTime = time;
  const elapsed = Math.max(0, time - state.lastFrameTime) / 1000;
  state.lastFrameTime = time;
  const columnsPerSecond = Number(controls.playSpeed.value) || 100;
  let next = state.playhead + elapsed * columnsPerSecond;
  if (next >= W) next %= W;
  setPlayhead(next);
  state.raf = requestAnimationFrame(animationFrame);
}

function setPlaying(active) {
  state.playing = active;
  controls.playToggle.textContent = active ? "Stop" : "Play";
  controls.playToggle.classList.toggle("active", active);
  if (active) {
    state.lastFrameTime = 0;
    state.raf = requestAnimationFrame(animationFrame);
  } else if (state.raf) {
    cancelAnimationFrame(state.raf);
    state.raf = 0;
  }
}

function drawColorAlphaComposite(ctx) {
  const rgb = colorCtx.getImageData(0, 0, W, H);
  const alpha = alphaCtx.getImageData(0, 0, W, H);
  const view = ctx.createImageData(W, H);
  for (let i = 0; i < rgb.data.length; i += 4) {
    const a = alpha.data[i] / 255;
    view.data[i] = Math.round(rgb.data[i] * (0.18 + a * 0.82));
    view.data[i + 1] = Math.round(rgb.data[i + 1] * (0.18 + a * 0.82));
    view.data[i + 2] = Math.round(rgb.data[i + 2] * (0.18 + a * 0.82));
    view.data[i + 3] = 255;
  }
  ctx.putImageData(view, 0, 0);
}

function refresh() {
  scoreCtx.clearRect(0, 0, W, H);
  scoreCtx.fillStyle = "#050607";
  scoreCtx.fillRect(0, 0, W, H);
  scoreCtx.globalAlpha = 1;
  if (state.layer === "alpha") {
    scoreCtx.drawImage(alphaCanvas, 0, 0);
  } else if (state.layer === "both") {
    drawColorAlphaComposite(scoreCtx);
  } else {
    scoreCtx.drawImage(colorCanvas, 0, 0);
  }
  actualCtx.clearRect(0, 0, W, H);
  drawColorAlphaComposite(actualCtx);
  updateMaskPreview();
  drawPlayOverlay();
}

function strokeDot(ctx, x, y, radius, color, alpha, softness) {
  const gradient = ctx.createRadialGradient(x, y, 0, x, y, radius);
  gradient.addColorStop(0, color);
  gradient.addColorStop(clamp(softness, 0.02, 0.98), color);
  gradient.addColorStop(1, "rgba(0,0,0,0)");
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.globalCompositeOperation = color === "erase" ? "destination-out" : "source-over";
  ctx.fillStyle = color === "erase" ? "#000" : gradient;
  ctx.beginPath();
  ctx.arc(x, y, radius, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function paintAt(point) {
  const radius = Number(controls.brushSize.value);
  const opacity = Number(controls.brushOpacity.value) / 100;
  const softness = Number(controls.brushSoftness.value) / 100;
  const alpha = currentAlpha() * opacity;
  const color = currentColor();
  const active = state.layer;
  const erase = state.tool === "erase";

  if (active !== "alpha") {
    strokeDot(colorCtx, point.x, point.y, radius, erase ? "erase" : color, opacity, softness);
  }
  if (active !== "color") {
    const v = Math.round(alpha * 255);
    strokeDot(alphaCtx, point.x, point.y, radius, erase ? "erase" : `rgb(${v} ${v} ${v})`, 1, softness);
  }
}

function drawLine(a, b, width, color, alphaValue, erase = false) {
  const active = state.layer;
  if (active !== "alpha") {
    colorCtx.save();
    colorCtx.globalAlpha = Number(controls.brushOpacity.value) / 100;
    colorCtx.globalCompositeOperation = erase ? "destination-out" : "source-over";
    colorCtx.strokeStyle = color;
    colorCtx.lineCap = "round";
    colorCtx.lineJoin = "round";
    colorCtx.lineWidth = width;
    colorCtx.beginPath();
    colorCtx.moveTo(a.x, a.y);
    colorCtx.lineTo(b.x, b.y);
    colorCtx.stroke();
    colorCtx.restore();
  }
  if (active !== "color") {
    const v = Math.round(alphaValue * 255);
    alphaCtx.save();
    alphaCtx.globalCompositeOperation = erase ? "destination-out" : "source-over";
    alphaCtx.strokeStyle = `rgb(${v} ${v} ${v})`;
    alphaCtx.lineCap = "round";
    alphaCtx.lineJoin = "round";
    alphaCtx.lineWidth = width;
    alphaCtx.beginPath();
    alphaCtx.moveTo(a.x, a.y);
    alphaCtx.lineTo(b.x, b.y);
    alphaCtx.stroke();
    alphaCtx.restore();
  }
}

function drawBlob(point, radius, squish = 1) {
  const active = state.layer;
  const color = currentColor();
  const opacity = Number(controls.brushOpacity.value) / 100;
  const alpha = currentAlpha();
  if (active !== "alpha") {
    colorCtx.save();
    colorCtx.globalAlpha = opacity;
    colorCtx.fillStyle = color;
    colorCtx.beginPath();
    colorCtx.ellipse(point.x, point.y, radius * 1.35, radius * squish, 0, 0, Math.PI * 2);
    colorCtx.fill();
    colorCtx.restore();
  }
  if (active !== "color") {
    const v = Math.round(alpha * 255);
    alphaCtx.save();
    alphaCtx.fillStyle = `rgb(${v} ${v} ${v})`;
    alphaCtx.beginPath();
    alphaCtx.ellipse(point.x, point.y, radius * 1.35, radius * squish, 0, 0, Math.PI * 2);
    alphaCtx.fill();
    alphaCtx.restore();
  }
}

function drawRectBlock(x, y, w, h, color, alphaValue, opacity = 1) {
  const active = state.layer;
  if (active !== "alpha") {
    colorCtx.save();
    colorCtx.globalAlpha = opacity;
    colorCtx.fillStyle = color;
    colorCtx.fillRect(x, y, w, h);
    colorCtx.restore();
  }
  if (active !== "color") {
    const v = Math.round(alphaValue * 255);
    alphaCtx.save();
    alphaCtx.fillStyle = `rgb(${v} ${v} ${v})`;
    alphaCtx.fillRect(x, y, w, h);
    alphaCtx.restore();
  }
}

function drawArcStroke(cx, cy, radius, startAngle, endAngle, width, color, alphaValue) {
  const active = state.layer;
  const opacity = Number(controls.brushOpacity.value) / 100;
  if (active !== "alpha") {
    colorCtx.save();
    colorCtx.globalAlpha = opacity;
    colorCtx.strokeStyle = color;
    colorCtx.lineCap = "round";
    colorCtx.lineWidth = width;
    colorCtx.beginPath();
    colorCtx.arc(cx, cy, radius, startAngle, endAngle);
    colorCtx.stroke();
    colorCtx.restore();
  }
  if (active !== "color") {
    const v = Math.round(alphaValue * 255);
    alphaCtx.save();
    alphaCtx.strokeStyle = `rgb(${v} ${v} ${v})`;
    alphaCtx.lineCap = "round";
    alphaCtx.lineWidth = width;
    alphaCtx.beginPath();
    alphaCtx.arc(cx, cy, radius, startAngle, endAngle);
    alphaCtx.stroke();
    alphaCtx.restore();
  }
}

function drawFilledPolygon(points, color, alphaValue, opacity = 1) {
  if (points.length < 3) return;
  const active = state.layer;
  const paint = (ctx, fillStyle, alpha) => {
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.fillStyle = fillStyle;
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    for (let i = 1; i < points.length; i += 1) ctx.lineTo(points[i].x, points[i].y);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  };
  if (active !== "alpha") paint(colorCtx, color, opacity);
  if (active !== "color") {
    const v = Math.round(alphaValue * 255);
    paint(alphaCtx, `rgb(${v} ${v} ${v})`, 1);
  }
}

function fillAlphaGradient(gradient) {
  alphaCtx.save();
  alphaCtx.globalCompositeOperation = "source-over";
  alphaCtx.fillStyle = gradient;
  alphaCtx.fillRect(0, 0, W, H);
  alphaCtx.restore();
}

function drawGradientRule(rule, rand, density, spread, drift) {
  const palette = controls.palette.value;
  const stopCount = rule === "gradient_bands" ? 4 + Math.floor(density * 10) : 3 + Math.floor(density * 5);
  const angle = rand() * Math.PI * 2;
  const x0 = W * (0.5 - Math.cos(angle) * 0.65);
  const y0 = H * (0.5 - Math.sin(angle) * 0.65);
  const x1 = W * (0.5 + Math.cos(angle) * 0.65);
  const y1 = H * (0.5 + Math.sin(angle) * 0.65);
  const innerX = W * rand();
  const innerY = H * rand();
  const outerX = W * (0.25 + rand() * 0.5);
  const outerY = H * (0.25 + rand() * 0.5);
  const radius = H * (0.35 + spread * 1.2);
  const colorGradient = rule === "gradient_radial" || rule === "gradient_vortex"
    ? colorCtx.createRadialGradient(innerX, innerY, 0, outerX, outerY, radius)
    : colorCtx.createLinearGradient(x0, y0, x1, y1);
  const alphaGradient = rule === "gradient_radial" || rule === "gradient_vortex"
    ? alphaCtx.createRadialGradient(innerX, innerY, 0, outerX, outerY, radius)
    : alphaCtx.createLinearGradient(x0, y0, x1, y1);
  const stops = [];

  for (let i = 0; i < stopCount; i += 1) {
    const rawT = stopCount === 1 ? 0 : i / (stopCount - 1);
    const t = rule === "gradient_bands"
      ? clamp((Math.floor(rawT * stopCount) + rand() * 0.25) / stopCount, 0, 1)
      : clamp(rawT + (rand() - 0.5) * drift * 0.24, 0, 1);
    const amp = clamp(0.12 + rand() * 0.88, 0, 1);
    stops.push({ t, color: paletteColor(palette, rawT, rand, drift), amp });
  }
  stops.sort((a, b) => a.t - b.t);
  stops.forEach((stop) => {
    const v = Math.round(stop.amp * 255);
    colorGradient.addColorStop(stop.t, stop.color);
    alphaGradient.addColorStop(stop.t, `rgb(${v} ${v} ${v})`);
  });

  colorCtx.save();
  colorCtx.globalCompositeOperation = "source-over";
  colorCtx.fillStyle = colorGradient;
  colorCtx.fillRect(0, 0, W, H);
  colorCtx.restore();
  fillAlphaGradient(alphaGradient);

  if (rule === "gradient_bands") {
    const bands = 3 + Math.floor(density * 14);
    for (let i = 0; i < bands; i += 1) {
      const y = clamp(rand() * H, 0, H);
      const h = 2 + rand() * (4 + spread * 28);
      const color = paletteColor(palette, rand(), rand, drift);
      drawRectBlock(0, clamp(y - h / 2, 0, H - h), W, h, color, 0.2 + rand() * 0.8, 0.16 + rand() * 0.34);
    }
  } else if (rule === "gradient_vortex") {
    const rings = 6 + Math.floor(density * 18);
    const cx = W * (0.25 + rand() * 0.5);
    const cy = H * (0.25 + rand() * 0.5);
    for (let i = 0; i < rings; i += 1) {
      const radius = 12 + i * (5 + spread * 8);
      const start = angle + i * 0.35;
      const end = start + Math.PI * (0.35 + drift * 1.4);
      const color = paletteColor(palette, i / Math.max(1, rings - 1), rand, drift);
      drawArcStroke(cx, cy, radius, start, end, 2 + rand() * 12, color, 0.18 + rand() * 0.72);
    }
  }
}

function smudgeLayer(ctx, from, to, radius, opacity) {
  const size = Math.max(2, Math.round(radius * 2));
  const sx = Math.round(clamp(from.x - radius, 0, W - size));
  const sy = Math.round(clamp(from.y - radius, 0, H - size));
  const dx = Math.round(to.x - radius);
  const dy = Math.round(to.y - radius);
  ctx.save();
  ctx.globalAlpha = opacity;
  ctx.beginPath();
  ctx.arc(to.x, to.y, radius, 0, Math.PI * 2);
  ctx.clip();
  ctx.drawImage(ctx.canvas, sx, sy, size, size, dx, dy, size, size);
  ctx.restore();
}

function smudgeAt(from, to) {
  const radius = Math.max(2, Number(controls.brushSize.value));
  const opacity = clamp(Number(controls.brushOpacity.value) / 120, 0.05, 0.85);
  const active = state.layer;
  if (active !== "alpha") smudgeLayer(colorCtx, from, to, radius, opacity);
  if (active !== "color") smudgeLayer(alphaCtx, from, to, radius, opacity);
}

function setTool(tool) {
  state.tool = tool;
  document.querySelectorAll("#toolButtons button").forEach((button) => {
    button.classList.toggle("active", button.dataset.tool === tool);
  });
}

function setLayer(layer) {
  state.layer = layer;
  document.querySelectorAll("#layerButtons button").forEach((button) => {
    button.classList.toggle("active", button.dataset.layer === layer);
  });
  refresh();
}

function clearScore() {
  colorCtx.clearRect(0, 0, W, H);
  alphaCtx.clearRect(0, 0, W, H);
  refresh();
}

function fillAlpha(value = 255) {
  alphaCtx.save();
  alphaCtx.globalCompositeOperation = "source-over";
  alphaCtx.fillStyle = `rgb(${value} ${value} ${value})`;
  alphaCtx.fillRect(0, 0, W, H);
  alphaCtx.restore();
  refresh();
}

function generateScore() {
  const rand = mulberry32(Number(controls.seed.value) || 1);
  const density = Number(controls.density.value) / 100;
  const spread = Number(controls.freqSpread.value) / 100;
  const drift = Number(controls.gestureDrift.value) / 100;
  const rule = controls.rule.value;
  const count = Math.round(8 + density * 90);
  const oldTool = state.tool;
  const oldLayer = state.layer;
  setLayer("both");

  if (rule.startsWith("gradient_")) {
    drawGradientRule(rule, rand, density, spread, drift);
    controls.seed.value = String((Number(controls.seed.value) || 1) + 1);
    setTool(oldTool);
    setLayer(oldLayer);
    updateAedSwatch();
    updateAllRangeFills();
    refresh();
    return;
  }

  for (let i = 0; i < count; i += 1) {
    const baseY = H * (0.08 + rand() * 0.84);
    const yRange = 8 + spread * 96;
    const az = -180 + rand() * 360;
    const el = -80 + rand() * 160;
    controls.azimuth.value = String(Math.round(az));
    controls.elevation.value = String(Math.round(el));
    controls.distance.value = String(Math.round(35 + rand() * 65));
    controls.alphaPaint.value = String(Math.round(40 + rand() * 60));
    controls.brushOpacity.value = String(Math.round(35 + rand() * 60));

    if (rule === "arcs") {
      const cx = rand() * W;
      const cy = clamp(baseY + (rand() - 0.5) * yRange, -H * 0.4, H * 1.4);
      const radius = 24 + rand() * (60 + spread * 160);
      const a0 = rand() * Math.PI * 2;
      const sweep = (0.15 + rand() * (0.35 + drift)) * Math.PI;
      drawArcStroke(cx, cy, radius, a0, a0 + sweep, 1.5 + rand() * 5, currentColor(), currentAlpha());
    } else if (rule === "cloud") {
      controls.brushSize.value = String(Math.round(2 + rand() * 18));
      paintAt({ x: rand() * W, y: clamp(baseY + (rand() - 0.5) * yRange, 0, H) });
    } else if (rule === "bands") {
      const y = clamp(baseY + (rand() - 0.5) * yRange * 0.25, 0, H);
      controls.brushSize.value = String(Math.round(2 + rand() * 8));
      drawLine({ x: 0, y }, { x: W, y: y + (rand() - 0.5) * drift * 40 }, Number(controls.brushSize.value), currentColor(), currentAlpha());
    } else if (rule === "blocks") {
      const w = 10 + rand() * (24 + density * 90);
      const h = 4 + rand() * (10 + spread * 36);
      drawRectBlock(rand() * (W - w), clamp(baseY - h / 2, 0, H - h), w, h, currentColor(), currentAlpha(), 0.42 + rand() * 0.58);
    } else if (rule === "glissandi") {
      const points = 3 + Math.floor(rand() * 4);
      let prev = {
        x: rand() * 32,
        y: clamp(baseY + (rand() - 0.5) * yRange, 0, H)
      };
      const direction = rand() < 0.5 ? -1 : 1;
      for (let p = 1; p < points; p += 1) {
        const next = {
          x: (p / (points - 1)) * W,
          y: clamp(prev.y + direction * (8 + rand() * yRange * (0.2 + drift)), 0, H)
        };
        drawLine(prev, next, 1.5 + rand() * 4, currentColor(), currentAlpha());
        prev = next;
      }
    } else if (rule === "harmonics") {
      const fundamental = clamp(H * (0.55 + rand() * 0.36), 0, H);
      const partials = 3 + Math.floor(rand() * (4 + density * 8));
      const x0 = rand() * W * 0.25;
      const length = W * (0.18 + rand() * 0.72);
      for (let h = 1; h <= partials; h += 1) {
        const y = clamp(fundamental - Math.log2(h) * (12 + spread * 34), 0, H);
        const fade = Math.max(0.15, 1 / Math.sqrt(h));
        const xx = clamp(x0 + rand() * 34, 0, W - 4);
        drawLine({ x: xx, y }, { x: clamp(xx + length * (0.45 + fade), 0, W), y: y + (rand() - 0.5) * drift * 9 }, 1 + fade * 4, currentColor(), currentAlpha() * fade);
      }
    } else if (rule === "hatching") {
      const x = rand() * W;
      const len = 20 + rand() * (40 + spread * 120);
      const slope = (rand() < 0.5 ? -1 : 1) * (0.35 + drift * 1.5);
      drawLine({ x, y: clamp(baseY, 0, H) }, { x: clamp(x + len, 0, W), y: clamp(baseY + len * slope, 0, H) }, 1 + rand() * 3, currentColor(), currentAlpha());
    } else if (rule === "masks") {
      const x0 = rand() * W;
      const width = 28 + rand() * (40 + density * 150);
      const floor = clamp(baseY + (rand() - 0.5) * yRange, 0, H);
      const points = [
        { x: clamp(x0, 0, W), y: H },
        { x: clamp(x0, 0, W), y: floor },
        { x: clamp(x0 + width * 0.33, 0, W), y: clamp(floor + (rand() - 0.5) * yRange, 0, H) },
        { x: clamp(x0 + width * 0.66, 0, W), y: clamp(floor + (rand() - 0.5) * yRange, 0, H) },
        { x: clamp(x0 + width, 0, W), y: floor },
        { x: clamp(x0 + width, 0, W), y: H }
      ];
      drawFilledPolygon(points, currentColor(), currentAlpha(), 0.35 + rand() * 0.45);
    } else if (rule === "pulses") {
      const xStep = 8 + Math.round(rand() * (20 - density * 10));
      const pulseCount = 2 + Math.floor(rand() * (3 + density * 7));
      const h = 4 + rand() * (8 + spread * 30);
      for (let p = 0; p < pulseCount; p += 1) {
        const x = (rand() * W + p * xStep * (1 + rand() * 2)) % W;
        drawRectBlock(x, clamp(baseY - h / 2 + (rand() - 0.5) * yRange * 0.25, 0, H - h), 2 + rand() * 8, h, currentColor(), currentAlpha(), 0.55 + rand() * 0.45);
      }
    } else if (rule === "ridges") {
      const x0 = rand() * W;
      const x1 = clamp(x0 + 40 + rand() * 220, 0, W);
      const y0 = clamp(baseY, 0, H);
      const y1 = clamp(baseY + (rand() - 0.5) * yRange * drift, 0, H);
      drawLine({ x: x0, y: y0 }, { x: x1, y: y1 }, 1 + rand() * 3, currentColor(), currentAlpha());
    } else if (rule === "rain") {
      const x = rand() * W;
      const drop = 3 + rand() * (8 + spread * 28);
      drawLine({ x, y: clamp(baseY - drop, 0, H) }, { x: x + (rand() - 0.5) * drift * 10, y: clamp(baseY + drop, 0, H) }, 0.8 + rand() * 2.6, currentColor(), currentAlpha());
    } else if (rule === "constellation") {
      drawBlob({ x: rand() * W, y: clamp(baseY + (rand() - 0.5) * yRange, 0, H) }, 3 + rand() * 16, 0.45 + rand() * 1.1);
    } else if (rule === "temporal") {
      const x = rand() * W;
      const h = 16 + rand() * yRange;
      drawLine({ x, y: clamp(baseY - h / 2, 0, H) }, { x: x + (rand() - 0.5) * drift * 30, y: clamp(baseY + h / 2, 0, H) }, 2 + rand() * 8, currentColor(), currentAlpha());
    } else {
      const points = 3 + Math.floor(rand() * 5);
      let prev = { x: rand() * 40, y: clamp(baseY, 0, H) };
      for (let p = 1; p < points; p += 1) {
        const next = {
          x: (p / (points - 1)) * W,
          y: clamp(baseY + (rand() - 0.5) * yRange * drift, 0, H)
        };
        drawLine(prev, next, 1 + rand() * 5, currentColor(), currentAlpha());
        prev = next;
      }
    }
  }
  controls.seed.value = String((Number(controls.seed.value) || 1) + 1);
  setTool(oldTool);
  setLayer(oldLayer);
  updateAedSwatch();
  updateAllRangeFills();
  refresh();
}

function imageDataRgb() {
  return colorCtx.getImageData(0, 0, W, H);
}

function alphaData() {
  return alphaCtx.getImageData(0, 0, W, H);
}

function luminance(rgb, i) {
  return (0.2126 * rgb[i] + 0.7152 * rgb[i + 1] + 0.0722 * rgb[i + 2]) / 255;
}

function normalizeMask(mask) {
  let peak = 0;
  for (let i = 0; i < mask.length; i += 1) peak = Math.max(peak, mask[i]);
  if (peak > 1e-9) {
    for (let i = 0; i < mask.length; i += 1) mask[i] = clamp(mask[i] / peak, 0, 1);
  }
  return mask;
}

function blur(mask, radius = 3) {
  const temp = new Float32Array(mask.length);
  const out = new Float32Array(mask.length);
  for (let y = 0; y < H; y += 1) {
    for (let x = 0; x < W; x += 1) {
      let sum = 0;
      let count = 0;
      for (let k = -radius; k <= radius; k += 1) {
        const xx = clamp(x + k, 0, W - 1);
        sum += mask[y * W + xx];
        count += 1;
      }
      temp[y * W + x] = sum / count;
    }
  }
  for (let y = 0; y < H; y += 1) {
    for (let x = 0; x < W; x += 1) {
      let sum = 0;
      let count = 0;
      for (let k = -radius; k <= radius; k += 1) {
        const yy = clamp(y + k, 0, H - 1);
        sum += temp[yy * W + x];
        count += 1;
      }
      out[y * W + x] = sum / count;
    }
  }
  return out;
}

function computeMask(mode) {
  const rgb = imageDataRgb().data;
  const a = alphaData().data;
  const gray = new Float32Array(W * H);
  const mask = new Float32Array(W * H);
  for (let p = 0; p < W * H; p += 1) {
    gray[p] = luminance(rgb, p * 4);
  }

  if (mode === "alpha") {
    for (let p = 0; p < W * H; p += 1) mask[p] = a[p * 4] / 255;
  } else if (mode === "luminance") {
    mask.set(gray);
  } else if (mode === "inverse_luminance") {
    for (let p = 0; p < W * H; p += 1) mask[p] = 1 - gray[p];
  } else if (mode === "local_contrast") {
    const local = blur(gray, 6);
    for (let p = 0; p < W * H; p += 1) mask[p] = Math.abs(gray[p] - local[p]);
  } else if (mode === "ridge") {
    const soft = blur(gray, 2);
    for (let y = 1; y < H - 1; y += 1) {
      for (let x = 1; x < W - 1; x += 1) {
        const p = y * W + x;
        const lap = 4 * soft[p] - soft[p - 1] - soft[p + 1] - soft[p - W] - soft[p + W];
        mask[p] = Math.max(0, lap);
      }
    }
  } else if (mode === "blob") {
    const fill = blur(gray, 8);
    const edge = edgeMask(gray);
    for (let p = 0; p < W * H; p += 1) mask[p] = fill[p] * (1 - edge[p] * 0.55);
  } else if (mode === "center_emphasis") {
    const fill = blur(gray, 5);
    const edge = blur(edgeMask(gray), 3);
    for (let p = 0; p < W * H; p += 1) mask[p] = fill[p] * Math.pow(Math.max(0, 1 - edge[p]), 1.75);
  } else if (mode === "temporal_activity") {
    for (let y = 0; y < H; y += 1) {
      for (let x = 1; x < W; x += 1) {
        const p = y * W + x;
        mask[p] = Math.abs(gray[p] - gray[p - 1]);
      }
      mask[y * W] = mask[y * W + 1];
    }
  } else {
    mask.set(edgeMask(gray));
  }
  return normalizeMask(mask);
}

function edgeMask(gray) {
  const mask = new Float32Array(W * H);
  for (let y = 0; y < H; y += 1) {
    for (let x = 0; x < W; x += 1) {
      const xm = clamp(x - 1, 0, W - 1);
      const xp = clamp(x + 1, 0, W - 1);
      const ym = clamp(y - 1, 0, H - 1);
      const yp = clamp(y + 1, 0, H - 1);
      const gx = Math.abs(gray[y * W + xp] - gray[y * W + xm]) * 0.5;
      const gy = Math.abs(gray[yp * W + x] - gray[ym * W + x]) * 0.5;
      mask[y * W + x] = Math.sqrt(gx * gx + gy * gy);
    }
  }
  return normalizeMask(mask);
}

function updateMaskPreview() {
  const threshold = Number(controls.threshold.value) / 100;
  const curve = Number(controls.curve.value) / 100;
  const mask = computeMask(controls.maskMode.value);
  const image = maskCtx.createImageData(W, H);
  for (let p = 0; p < W * H; p += 1) {
    const shaped = Math.pow(clamp((mask[p] - threshold) / Math.max(0.000001, 1 - threshold), 0, 1), curve);
    const v = Math.round(shaped * 255);
    const i = p * 4;
    image.data[i] = v;
    image.data[i + 1] = v;
    image.data[i + 2] = v;
    image.data[i + 3] = 255;
  }
  state.mask = image;
  maskCtx.putImageData(image, 0, 0);
  drawPlayOverlay();
}

function downloadCanvas(canvas, filename) {
  const link = document.createElement("a");
  link.download = filename;
  link.href = canvas.toDataURL("image/png");
  link.click();
}

function exportColor() {
  const out = document.createElement("canvas");
  out.width = W;
  out.height = H;
  const ctx = out.getContext("2d");
  ctx.fillStyle = "#000";
  ctx.fillRect(0, 0, W, H);
  ctx.drawImage(colorCanvas, 0, 0);
  downloadCanvas(out, "s3g_image_score_color.png");
}

function exportAlpha() {
  downloadCanvas(alphaCanvas, "s3g_image_score_alpha.png");
}

function exportMask() {
  updateMaskPreview();
  downloadCanvas(maskCanvas, `s3g_image_score_${controls.maskMode.value}.png`);
}

function exportComposite() {
  const rgb = imageDataRgb();
  const alpha = alphaData();
  const out = document.createElement("canvas");
  out.width = W;
  out.height = H;
  const ctx = out.getContext("2d");
  const image = ctx.createImageData(W, H);
  for (let i = 0; i < rgb.data.length; i += 4) {
    image.data[i] = rgb.data[i];
    image.data[i + 1] = rgb.data[i + 1];
    image.data[i + 2] = rgb.data[i + 2];
    image.data[i + 3] = alpha.data[i];
  }
  ctx.putImageData(image, 0, 0);
  downloadCanvas(out, "s3g_image_score_rgba.png");
}

function importImage(file) {
  if (!file) return;
  const img = new Image();
  img.onload = () => {
    colorCtx.clearRect(0, 0, W, H);
    alphaCtx.clearRect(0, 0, W, H);
    colorCtx.drawImage(img, 0, 0, W, H);
    const data = colorCtx.getImageData(0, 0, W, H);
    const alphaImage = alphaCtx.createImageData(W, H);
    for (let i = 0; i < data.data.length; i += 4) {
      const a = data.data[i + 3];
      alphaImage.data[i] = a;
      alphaImage.data[i + 1] = a;
      alphaImage.data[i + 2] = a;
      alphaImage.data[i + 3] = 255;
      data.data[i + 3] = 255;
    }
    colorCtx.putImageData(data, 0, 0);
    alphaCtx.putImageData(alphaImage, 0, 0);
    URL.revokeObjectURL(img.src);
    refresh();
  };
  img.src = URL.createObjectURL(file);
}

scoreCanvas.addEventListener("pointerdown", (event) => {
  const point = canvasPoint(event);
  state.drawing = true;
  state.start = point;
  state.last = point;
  scoreCanvas.setPointerCapture(event.pointerId);
  if (state.tool === "brush" || state.tool === "erase") paintAt(point);
  if (state.tool === "blob") drawBlob(point, Number(controls.brushSize.value), 0.65 + Math.random() * 0.8);
  refresh();
});

scoreCanvas.addEventListener("pointermove", (event) => {
  const point = canvasPoint(event);
  controls.readout.textContent = `x ${(point.x / W).toFixed(3)} / y ${(1 - point.y / H).toFixed(3)}`;
  if (!state.drawing) return;
  if (state.tool === "brush" || state.tool === "erase") {
    drawLine(state.last, point, Number(controls.brushSize.value) * 1.2, currentColor(), currentAlpha(), state.tool === "erase");
    state.last = point;
    refresh();
  } else if (state.tool === "smudge") {
    smudgeAt(state.last, point);
    state.last = point;
    refresh();
  }
});

scoreCanvas.addEventListener("pointerup", (event) => {
  if (!state.drawing) return;
  const point = canvasPoint(event);
  if (state.tool === "line" || state.tool === "ridge") {
    drawLine(state.start, point, state.tool === "ridge" ? Math.max(1, Number(controls.brushSize.value) * 0.24) : Number(controls.brushSize.value), currentColor(), currentAlpha(), false);
  }
  state.drawing = false;
  state.start = null;
  state.last = null;
  refresh();
});

document.querySelectorAll("#toolButtons button").forEach((button) => {
  button.addEventListener("click", () => setTool(button.dataset.tool));
});

document.querySelectorAll("#layerButtons button").forEach((button) => {
  button.addEventListener("click", () => setLayer(button.dataset.layer));
});

document.querySelectorAll(".section-toggle").forEach((button) => {
  button.addEventListener("click", () => {
    const section = button.closest(".collapsible");
    const collapsed = section.classList.toggle("collapsed");
    button.textContent = collapsed ? "+" : "-";
    button.setAttribute("aria-expanded", collapsed ? "false" : "true");
  });
});

document.querySelectorAll("[data-aed-camera]").forEach((button) => {
  button.addEventListener("click", () => {
    const camera = button.dataset.aedCamera;
    if (camera === "top") setAedCamera("top", 0, -89);
    else if (camera === "right") setAedCamera("right", 90, 0);
    else setAedCamera("front", 0, 0);
  });
});

function bindAedCameraDrag(canvas) {
  canvas.addEventListener("pointerdown", (event) => {
    state.aedDragging = true;
    canvas.setPointerCapture(event.pointerId);
    setAedCameraFromEvent(event, canvas);
  });
  canvas.addEventListener("pointermove", (event) => {
    if (!state.aedDragging) return;
    setAedCameraFromEvent(event, canvas);
  });
  canvas.addEventListener("pointerup", () => {
    state.aedDragging = false;
  });
  canvas.addEventListener("pointercancel", () => {
    state.aedDragging = false;
  });
}

bindAedCameraDrag(aedSphereCanvas);
bindAedCameraDrag(aedLargeCanvas);

$("aedPopoutButton").addEventListener("click", () => {
  $("aedLightbox").hidden = false;
  drawColumnWindows();
});

$("aedLightboxClose").addEventListener("click", () => {
  $("aedLightbox").hidden = true;
});

$("aedLightbox").addEventListener("click", (event) => {
  if (event.target === $("aedLightbox")) $("aedLightbox").hidden = true;
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") $("aedLightbox").hidden = true;
});

document.querySelectorAll(".swatch").forEach((button) => {
  button.addEventListener("click", () => {
    controls.azimuth.value = button.dataset.az;
    controls.elevation.value = button.dataset.el;
    controls.distance.value = button.dataset.dist;
    updateAedSwatch();
    updateAllRangeFills();
  });
});

document.querySelectorAll('input[type="range"]').forEach((input) => {
  input.addEventListener("input", () => updateRangeFill(input));
});

["maskMode", "threshold", "curve"].forEach((id) => {
  controls[id].addEventListener("input", () => {
    updateMaskPreview();
    drawPlayOverlay();
  });
});

["azimuth", "elevation", "distance"].forEach((id) => {
  controls[id].addEventListener("input", updateAedSwatch);
});

controls.colorModel.addEventListener("change", () => {
  updateAedSwatch();
  drawColumnWindows();
});

$("newScore").addEventListener("click", clearScore);
$("randomize").addEventListener("click", generateScore);
$("clearAlpha").addEventListener("click", () => fillAlpha(0));
$("fillAlpha").addEventListener("click", () => fillAlpha(255));
$("exportScore").addEventListener("click", () => {
  const mode = $("exportMode").value;
  if (mode === "color") exportColor();
  else if (mode === "alpha") exportAlpha();
  else if (mode === "mask") exportMask();
  else exportComposite();
});
$("importImageButton").addEventListener("click", () => $("importImage").click());
$("importImage").addEventListener("change", (event) => importImage(event.target.files[0]));
controls.playToggle.addEventListener("click", () => setPlaying(!state.playing));
controls.playhead.addEventListener("input", () => setPlayhead(controls.playhead.value));
controls.playSpeed.addEventListener("input", () => drawPlayOverlay());

colorCtx.fillStyle = "hsl(210 18% 8%)";
colorCtx.fillRect(0, 0, W, H);
fillAlpha(0);
drawOverlay();
updateAedSwatch();
updateAllRangeFills();
document.querySelector('[data-aed-camera="front"]')?.classList.add("active");
generateScore();
setPlayhead(0);
