# s3g-mc

s3g-mc is a collection of REAPER tools for multichannel composition, spatial
audio, offline sound transformation, and procedural synthesis.

It includes Lua actions, ReaImGui controllers, and JSFX for channel editing,
automation, fold-down monitoring, dome panning, 3OA send/return routing, and
render-based multichannel processes.

Documentation and workflow notes: <a href="https://s3g.github.io/s3g-mc/" target="_blank" rel="noopener noreferrer">s3g-mc docs site</a>.

Many of these tools are inspired by or extend existing computer music
practices, with references mentioned in the documentation where they are
useful.

## Tools

### Channel Mixing / Automation

- `128ch Automation Mixer`: faders, mute/solo, channel groups, meters, and
  plugin pin remapping for high-channel-count tracks.
- `MC to Stereo Autogain`: multichannel fold-down with layout modes, width,
  rotation, weighting, 3D projection attenuation, autogain, and output trim.

### Procedural Synthesis

These render actions drive included JSFX synth engines offline.

- `Render MC Carto Synth`: renders multichannel dust, pulse-packet,
  logic/fractal-drone, byte-mask, and spline-drift materials.
- `Render MC Spectra Synth`: renders slower spectral-mass and resonant
  materials: partial clouds, comb strata, formant bands, impulse resonators,
  and noise spectra.

Both use breakpoint curves for parameter motion and channel behavior, then
write a new multichannel media item.

### Offline Synthesis / IR

These NumPy-backed renderers handle processes that are easier to do offline
with Python than in Lua or JSFX. Breakpoint envelopes shape the render over
time. Density means event or peak admission before synthesis, not gain
modulation afterward.

- `Dense Grain Cloud`: source-item grains scattered into a multichannel field.
- `Fata Morgana Resynth`: hybrid oscillator resynthesis from 2-16 selected
  source items, recombining timing, pitch, amplitude, and spatial traits.
- `IR Toolkit`: reshapes a selected impulse response item with silence trim,
  tail fade, normalization, early reflections, and channel decorrelation.
- `Mass Partial Field`: additive partial events with drift and channel motion.
- `Partial Trace Resynth`: STFT peak tracing rendered as a multichannel
  oscillator field, with linked, point, smear, and frozen trace modes.
- `Resonant Terrain`: struck resonator banks for metallic, synthetic-IR, and
  resonant-dust materials.

### Spatial Panners

- `12ch Dodeca Panner`: AED-native panning for up to 8 mono sources across a
  12-channel dodecahedron loudspeaker layout, with a dodecahedron controller
  view.
- `17ch Cube XYZ Panner`: 3D DBAP-style Cartesian amplitude panning for up to
  8 mono sources across a 17-speaker cube layout, with native XYZ controls and
  a mirrored AED editing view. Small spread values can isolate a source to one
  speaker.
- `Layout Panner`: a general-purpose panner for quad, octophonic ring, 8ch
  cube, 12ch ring, 16ch ring, 16ch double ring, 20ch double ring, and 24ch dome
  without overhead. Speaker numbering starts near the stereo-right position and
  proceeds clockwise.
- `25ch Cosine Dome Panner`: soft angular-focus panning for up to 8 mono
  sources across the 25-speaker dome.
- `25ch DBAP Dome Panner`: distance-weighted amplitude panning for up to 8 mono
  sources across the 25-speaker dome.
- `25ch LBAP Dome Panner`: layer-based amplitude panning for up to 8 mono
  sources across the 25-speaker dome.
- `25ch Region Dome Panner`: region-locked panning that constrains up to 8 mono
  sources to speaker-defined rings, arcs, ribs, triangles, and caps.
- `25ch Vector Morph Dome Panner`: four-scene spatial snapshot morphing for up
  to 8 mono sources, driven by two automatable controls.
- `25ch VBAP Dome Panner`: nearest-region vector-style panning for up to 8 mono
  sources across the 25-speaker dome.
- `Spatial Automation Composer`: previews algorithmic AED or XYZ motion, then
  writes editable automation lanes for supported 8-source s3g panners.

The included panners are intended for use with loudspeaker arrays available in
the RISD Studio for Research in Sound & Technology (SRST). They include a
12-channel dodecahedron layout, a 17-channel cube layout, and the shared
25-channel dome layout. The 25ch dome panners offer several approaches to the
same array, giving composers room to compare and work with different spatial
behaviors.

See the <a href="https://s3g.github.io/s3g-mc/workflows.html#3oafx" target="_blank" rel="noopener noreferrer">3OAFX workflow docs</a>
for the ambisonic send/return workflow.

### 3OAFX

- `3OAFX Ambiance Extractor`: extracts room tone, noise bed, or other
  profile-like material from an ambisonic source while preserving the directional
  decode/re-encode workflow.
- `3OAFX Ambisonic Kernel Collage`: creative ambisonic cross-convolution that
  treats selected ambisonic recordings as spatial/spectral kernels for another
  ambisonic source, with mixed-order kernel adaptation.
- `3OAFX Offline Renderer`: NumPy-backed ambisonic decode/process/re-encode
  action for 1OA, 2OA, and 3OA media, with moving AED focus and dry attenuation.
- `3OAFX Offline Ambisonic Convolve`: NumPy-backed ambisonic convolution. It
  can convolve one ambisonic source with one same-order ambisonic IR, or use
  direction-accurate IR banks for P-format first order and 8-direction 2OA/3OA,
  with optional lower-order and sparse FOA IR adaptation.
- `3OAFX Send Return Controller`: places a 24-channel insert lane inside an
  ambisonic decode/encode chain.
- `3OAFX Spectral Hole Maker`: carves profile-shaped spectral space from an
  ambisonic source per direction.
- `3OAFX Spectral Profile Match`: steers the source spectrum toward a reference
  profile per direction without mixing the reference into the output.
- `3OAFX Spectral Profile Subtract`: ambisonic noise/material-profile
  subtraction. Select a source and a profile item; both are decoded to the same
  directional layer before cleaned or residue output is re-encoded.
- `3OAFX Spectral Residue Extractor`: renders the removed spectral material as
  its own ambisonic item for creative or diagnostic use.
- `3OAFX Synthetic Ambisonic IR Bank`: designs encoded ambisonic IR banks for
  `3OAFX Offline Ambisonic Convolve`, with room size, material absorption,
  scattering, early reflections, late-field controls, and separate or stacked
  output formats. Higher-order banks use 8 directions: stacked 2OA is 72
  channels and stacked 3OA is 128 channels.

### Spectral / Convolution

These offline processes are informed by spectral tool families such as
<a href="https://www.composersdesktop.com/" target="_blank" rel="noopener noreferrer">CDP</a>,
<a href="https://www.soundhack.com/freeware/the-boneyard/" target="_blank" rel="noopener noreferrer">SoundHack</a>,
<a href="https://github.com/ericlyon/FFTease3.0-MaxMSP" target="_blank" rel="noopener noreferrer">FFTease</a>, and
<a href="https://www.michaelnorris.info/software/soundmagic-spectral" target="_blank" rel="noopener noreferrer">SoundMagic Spectral</a>,
and run from the package's Python/NumPy backend.

- `Convolve selected items`: convolution of two selected media items, including
  mono, stereo, multichannel pairing, and summed matrix modes.
- `Cross Synthesis`: offline STFT cross-synthesis for two WAV-backed media
  items. The first selected item keeps phase and timing while its spectral
  magnitudes are blended toward the second item's magnitudes.
- `Render MC Impulse Field`: procedural multichannel impulse fields for
  convolution.
- `Spectral Accumulate`: spectral sustain where each frequency band holds until
  stronger energy replaces it.
- `Spectral Blur`: offline magnitude blur across neighboring STFT frames, with
  safe envelope mode and optional time expansion.
- `Spectral Freeze`: imposes one selected spectral frame across the item while
  preserving phase/timing motion, with safe envelope mode, envelope floor, and
  optional time expansion.
- `Spectral Morph`: live or frozen spectral morph between two WAV-backed media
  items.
- `Spectral Shaper`: offline spectral envelope transfer for two WAV-backed
  media items, with an alternate formant-vocode algorithm. The first selected
  item is the carrier/tune/timing source; the second supplies the spectral
  envelope or broad formant contour.
- `Spectral Spatializer`: distributes frequency bins across even output channel
  counts from 2 to 64.
- `Spectral Step Drunk Freeze`: stepped freeze or random-walk freeze through
  spectral frames.
- `Spectral Trace`: partial tracing with modes to keep loudest partials,
  suppress loudest partials, threshold, or thin randomly.

### Item Channel Transforms

- `Explode multichannel item to mono tracks`
- `Extract item channel to mono track`
- `Mirror item channel order`
- `Rotate item channels`
- `Reorder item channels`
- `Resize item channel count`
- `Odd-even item channel order`
- `Interleave item channel pairs`
- `Deinterleave item channel pairs`
- `Swap item channel halves`

### Multichannel Texture / Montage

Native REAPER variations inspired by
<a href="https://www.composersdesktop.com/docs/html/cgromc.htm" target="_blank" rel="noopener noreferrer">CDP multichannel processes</a>.
These scripts do not require CDP.

- `Brownian Walk`: short fragments follow a bounded random walk through source
  time and output channels.
- `Cascade Spatial Echo`: equal segments print decaying echoes through space.
- `Channel Orbit Delay`: whole-item delay repeats orbit around output channels.
- `Channel Smear`: slices duplicate to neighboring channels with gain
  compensation.
- `Crumble Spatial Groups`: slices move through progressively smaller channel
  groups.
- `Flutter Gate`: moving active-channel groups create flutter patterns.
- `Fracture`: ordered slices from one source channel disperse across a channel
  path, with jitter, drop, and spread voices.
- `Frame Gate`: rotating active-channel groups print gate patterns.
- `Frame Shift`: channel-frame rotation, mirror, odd/even split, pair
  interleave, or half-swap render.
- `Loop Drift`: NumPy-backed seamless source loops distributed across a
  multichannel bed, with overlap-add seam crossfades and per-channel
  playback-rate spread, source-pool routing, quantization, direction, gain, and
  motion variation.
- `Loop Rift`: NumPy-backed loop sections with graceful dropouts,
  overlap-add fades, source-pool routing, grouped channel openings, and
  unstable playback rates.
- `Marker Spatial Montage`: project markers or active-take markers inside the
  selected item define chunks for ordered or shuffled montage.
- `Mono Fill`: one source channel fills every output channel with optional gain
  compensation and slice rotation.
- `Scatter Slices`: multiple selected items are sliced by equal divisions,
  project markers, or active-take markers, then randomly arranged across a
  target multichannel duration with scatter, ordered-walk, stutter, repeater,
  channel-smear, channel-motion, shape, and breakpoint-density variations.
- `Shred / Slice`: equal, project-marker, or active-take-marker slices with
  ordered mono spread, random mono scatter, and multichannel reorientation
  modes.
- `Spatial Repeater`: one source channel repeats around clockwise, ping-pong,
  or random channel paths.
- `Spatial Stutter`: repeated short slices advance through a spatial path.
- `Stereo Spin`: sliced stereo images rotate around a multichannel output field.
- `Texture Clouds`: dense short fragments from one source channel scattered
  across an output field.
- `Zigzag Channel Walker`: equal slices walk back and forth across output
  channels, with optional reverse source-slice order.

### Track Building / Routing

- `Build multichannel stem from selected tracks`: routes selected tracks to
  consecutive channels on a new multichannel destination, then renders a
  bounded stem.
- `Cycle mono tracks into multichannel stem`: selected mono tracks become a
  multichannel stem, with repeat or grouped downmix behavior when the requested
  output count differs from the source count.
- `Route selected tracks to multichannel folder bus`: creates a new parent
  folder bus and assigns each child track to consecutive bus channels.

## Dependencies

- <a href="https://www.reaper.fm/" target="_blank" rel="noopener noreferrer">REAPER</a>
- <a href="https://codeberg.org/cfillion/reaimgui" target="_blank" rel="noopener noreferrer">ReaImGui</a>
  for the browser and controller scripts. It is available through ReaPack's
  default ReaTeam Extensions repository.
- <a href="https://www.python.org/downloads/" target="_blank" rel="noopener noreferrer">Python 3</a>
  with <a href="https://numpy.org/install/" target="_blank" rel="noopener noreferrer">NumPy</a>
  is required for the NumPy-backed offline processes. If REAPER cannot find the
  intended Python, put a `python3_path.txt` file beside the scripts containing
  the full path to `python3`.
- <a href="https://leomccormack.github.io/sparta-site/" target="_blank" rel="noopener noreferrer">SPARTA plugins</a>, specifically
  AmbiDEC and AmbiENC, are recommended for the 3OA workflow. Source and releases:
  <a href="https://github.com/leomccormack/SPARTA" target="_blank" rel="noopener noreferrer">leomccormack/SPARTA</a>.

## Install

Copy or symlink the package folders into your REAPER resource path:

```text
Scripts/s3g-mc -> REAPER/Scripts/s3g-mc
Effects/s3g    -> REAPER/Effects/s3g
```

In REAPER:

1. Open `Actions > Show action list...`.
2. Click `New Action > Load ReaScript...`.
3. Choose `REAPER/Scripts/s3g-mc/s3g-mc Package Browser.lua`.
4. Run `s3g-mc Package Browser`.
5. Click `Install/refresh actions` in the browser.

If the JSFX do not appear, rescan JSFX or restart REAPER.

## License

Zero-Clause BSD. See
<a href="https://github.com/s3g/s3g-mc?tab=License-1-ov-file" target="_blank" rel="noopener noreferrer">LICENSE</a>.

Attribution is appreciated for software development, publications, research,
teaching materials, and projects that build on or adapt this package. See
<a href="https://github.com/s3g/s3g-mc/blob/main/CITATION.cff" target="_blank" rel="noopener noreferrer">CITATION.cff</a>.

Development assistance: OpenAI Codex.
