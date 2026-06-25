# s3g-mc

s3g-mc is a collection of REAPER tools for multichannel composition, spatial
audio, offline sound transformation, and procedural synthesis.

It includes Lua actions, ReaImGui controllers, and JSFX for channel editing,
automation, fold-down monitoring, dome panning, 3OA send/return routing, and
render-based multichannel processes.

Documentation and workflow notes: <a href="https://s3g.github.io/s3g-mc/" target="_blank" rel="noopener noreferrer">s3g-mc docs site</a>.

The code is released under 0BSD. Many of these tools are inspired by or extend  existing computer music practices, with references mentioned in the documentation where they are useful.

## Tools

### Channel Mixing / Automation

- `128ch Automation Mixer`: faders, mute/solo, channel groups, meters, and
  plugin pin remapping for high-channel-count tracks.
- `MC to Stereo Autogain`: multichannel fold-down with layout modes, width,
  rotation, weighting, autogain, and output trim.

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

### Spatial / HOA

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
- `3OA Send/Return FX Controller`: places a 24-channel insert lane inside an
  ambisonic decode/encode chain.

The shared 25ch dome layout is based on the speaker array layout of RISD SRST
Spatial Audio Studio.

See the 3OA / SPARTA setup section for the ambisonic send/return workflow.

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
- <a href="https://sws-extension.org/" target="_blank" rel="noopener noreferrer">SWS Extension</a> is recommended for render-based
  workflows. Source is available at
  <a href="https://github.com/reaper-oss/sws" target="_blank" rel="noopener noreferrer">reaper-oss/sws</a>.
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

## 3OA / SPARTA Setup

The 3OA workflow uses a 72-channel REAPER track:

- `1-24`: wet/effect lane
- `25-48`: protected dry copy
- `49-72`: return mask lane

Use this plugin order:

1. SPARTA AmbiDEC
2. `JS: s3g 3OA Send`
3. one 24-channel insert effect
4. `JS: s3g 3OA Return Mask`
5. `JS: s3g 3OA Mixer`
6. SPARTA AmbiENC

Recommended SPARTA settings:

- Ambisonic order: `3rd order`
- Channel ordering: `ACN`
- Normalization: `SN3D`
- AmbiDEC decoder mode: `MMD` / multi-mode decoder
- Number of virtual speaker/source points: `24`

Load the included JSON layouts:

- In SPARTA AmbiDEC, load
  `Scripts/s3g-mc/sparta_json/s3g_3oa_24_virtual_speakers_ambidec_loudspeaker_layout.json`
  as the 24-point loudspeaker layout.
- In SPARTA AmbiENC, load
  `Scripts/s3g-mc/sparta_json/s3g_3oa_24_virtual_speakers_ambienc_source_layout.json`
  as the matching 24-point source layout.

`MMD` is recommended for AmbiDEC here because the workflow decodes to a custom
irregular 24-point virtual speaker cloud before re-encoding.

After adding or moving the 24-channel insert, use the controller's `Pin inserts
1-24` button so the effect only touches the wet/effect lane.

More detail is in `Scripts/s3g-mc/s3g_3oa_fx_workflow.md`.

## License

Zero-Clause BSD. See
<a href="https://github.com/s3g/s3g-mc?tab=License-1-ov-file" target="_blank" rel="noopener noreferrer">LICENSE</a>.

Development assistance: OpenAI Codex.
