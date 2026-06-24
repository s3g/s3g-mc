# s3g-mc

s3g-mc is a REAPER package for multichannel composition, spatial audio
workflow, procedural synthesis, and offline sound transformation.

It includes Lua actions, ReaImGui controllers, and JSFX for channel editing,
128-channel automation, fold-down monitoring, dome panning, third-order
ambisonic send/return routing, procedural synthesis, and render-based
multichannel processes.

This package contains original scripts and JSFX implementations, released under
0BSD. Many tools are inspired by and extensions of existing computer music
practices; references are credited in the relevant documentation where
appropriate.

## Tools

### Channel Mixing / Automation

- `128ch Automation Mixer`: track-aware faders, mute/solo, channel
  groups, meters, and plugin pin remapping.
- `MC to Stereo Autogain`: multichannel-to-stereo fold-down with layout modes,
  width, rotation, layout weighting, autogain, and output gain.

### Procedural Synthesis

- `Render MC Carto Synth`: offline controller for a multichannel JSFX
  synthesis engine with CDP synth-inspired dust, pulse-packet,
  logic/fractal-drone, byte-mask, and spline-drift algorithms.
  Choose duration, channel count, algorithm, and map-route breakpoint curves;
  the action writes automation to a temporary generator track, renders a
  multichannel media item, normalizes if requested, and removes the temporary
  track.
- `Render MC Spectra Synth`: offline controller for a multichannel JSFX
  synthesis engine with partial-cloud, comb-strata, formant-band,
  impulse-resonator, and noise-spectra algorithms.
  Uses the same breakpoint routing interface for slower spectral-mass and
  resonance-based synthesis, with algorithm-specific channel-motion models.

### Offline Synthesis / IR

These NumPy-backed renderers are for offline processes that are too dense or
array-oriented to fit comfortably in Lua or JSFX. The synth renderers include
breakpoint envelopes for shaping key parameters over the rendered duration.
Density controls event or peak admission before synthesis, not post-render
amplitude, so drawn density shapes change texture occupancy without adding gain
modulation.

- `Dense Grain Cloud`: renders thousands of source-item grains into a new
  multichannel media item with pitch scatter, spatial spread, density shaping,
  breakpoint envelopes, and overlap-safe normalization.
- `IR Toolkit`: reshapes a selected impulse response item with silence trim,
  tail fade, peak normalization, optional early reflections, and channel
  decorrelation.
- `Mass Partial Field`: renders a high-density additive field with thousands of
  independent partial events, frequency drift, envelopes, and multichannel
  motion, with breakpoint control over amplitude, density, and event behavior.
- `Partial Trace Resynth`: analyzes prominent spectral peaks from one selected
  source item and renders them as a multichannel oscillator field with
  breakpoint control over amplitude, density, trace gain, drift, and spatial
  width.
- `Resonant Terrain`: renders sparse excitation events through inharmonic
  resonator banks, producing struck-metal, synthetic-IR, and multichannel
  resonant-dust materials with breakpoint control over amplitude, density,
  decay, and spatial width.

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

See the 3OA / SPARTA Setup section later in this document for the separate
third-order ambisonic send/return workflow.

### Spectral / Convolution

These offline processes are inspired by spectral tool families such as
<a href="https://www.composersdesktop.com/" target="_blank" rel="noopener noreferrer">CDP</a>,
<a href="https://www.soundhack.com/freeware/the-boneyard/" target="_blank" rel="noopener noreferrer">SoundHack</a>,
<a href="https://github.com/ericlyon/FFTease3.0-MaxMSP" target="_blank" rel="noopener noreferrer">FFTease</a>, and
<a href="https://www.michaelnorris.info/software/soundmagic-spectral" target="_blank" rel="noopener noreferrer">SoundMagic Spectral</a>,
but run from the package's Python/NumPy backend.

- `Convolve selected items`: offline convolution of two selected media items,
  with mono, stereo, multichannel pairing, and summed source-to-impulse matrix modes.
- `Cross Synthesis`: offline STFT cross-synthesis for two WAV-backed media
  items. The first selected item keeps phase and timing while its spectral
  magnitudes are blended toward the second item's magnitudes.
- `Render MC Impulse Field`: procedural multichannel impulse generator for
  convolution. Creates impulse fields with selectable distribution rules,
  spacing, channel counts, and impulse profiles.
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

Native REAPER variations inspired by the
<a href="https://www.composersdesktop.com/docs/html/cgromc.htm" target="_blank" rel="noopener noreferrer">CDP multichannel processes</a>.
These scripts do not require CDP.

- `Brownian Walk`: short fragments follow a bounded random walk through source
  time and output channels.
- `Cascade Spatial Echo`: equal source segments print decaying echoes that step
  through multichannel space.
- `Channel Orbit Delay`: whole-item delay repeats orbit through output channels.
- `Channel Smear`: slices duplicate to neighboring channels
  with gain compensation.
- `Crumble Spatial Groups`: slices are projected through progressively smaller
  channel groups.
- `Flutter Gate`: moving active-channel groups create a multichannel flutter
  gate pattern.
- `Fracture`: time-ordered slices from one source
  channel dispersed across a controlled channel path with jitter, drop, and
  spread voices.
- `Frame Gate`: rotating active channel groups print a
  multichannel gate pattern.
- `Frame Shift`: channel-frame rotation, mirror,
  odd/even split, pair interleave, or half-swap render.
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
- `Spatial Repeater`: repeated prints of one source channel
  around clockwise, ping-pong, or random channel paths.
- `Spatial Stutter`: repeated short slices advance through a
  spatial path.
- `Stereo Spin`: sliced stereo images rotate around a multichannel output field.
- `Texture Clouds`: dense short fragments from one source
  channel scattered across an output field.
- `Zigzag Channel Walker`: equal slices walk back and forth across output
  channels, with optional reverse source-slice order.

### Track Building / Routing

- `Build multichannel stem from selected tracks`: routes selected tracks to
  consecutive channels on a new multichannel destination, then prompts to render
  a bounded stem.
- `Cycle mono tracks into multichannel stem`: selected mono tracks become a
  multichannel stem, with repeat or grouped
  downmix behavior when the requested output count differs from the source
  count.
- `Route selected tracks to multichannel folder bus`: creates a new parent
  folder bus above the selected tracks, moves the selected tracks into it, and
  assigns each child track's parent send to consecutive bus channels.

## Dependencies

- <a href="https://www.reaper.fm/" target="_blank" rel="noopener noreferrer">REAPER</a>
- <a href="https://codeberg.org/cfillion/reaimgui" target="_blank" rel="noopener noreferrer">ReaImGui</a> for the package browser
  and controller scripts. ReaImGui is distributed through ReaPack's default
  ReaTeam Extensions repository.
- <a href="https://sws-extension.org/" target="_blank" rel="noopener noreferrer">SWS Extension</a> is recommended for render-based
  workflows. Source is available at
  <a href="https://github.com/reaper-oss/sws" target="_blank" rel="noopener noreferrer">reaper-oss/sws</a>.
- <a href="https://www.python.org/downloads/" target="_blank" rel="noopener noreferrer">Python 3</a>
  with <a href="https://numpy.org/install/" target="_blank" rel="noopener noreferrer">NumPy</a>
  is required for offline spectral and convolution processes. If REAPER cannot
  find the intended Python, place a `python3_path.txt` file beside the scripts
  containing the full path to `python3`.
- <a href="https://leomccormack.github.io/sparta-site/" target="_blank" rel="noopener noreferrer">SPARTA plugins</a>, specifically
  AmbiDEC and AmbiENC, are recommended for the 3OA workflow. Source and
  releases are available at
  <a href="https://github.com/leomccormack/SPARTA" target="_blank" rel="noopener noreferrer">leomccormack/SPARTA</a>.

## Install

Copy or symlink the package folders into your REAPER resource path:

```text
Scripts/s3g-mc -> REAPER/Scripts/s3g-mc
Effects/s3g    -> REAPER/Effects/s3g
```

Then in REAPER:

1. Open `Actions > Show action list...`.
2. Click `New Action > Load ReaScript...`.
3. Choose `REAPER/Scripts/s3g-mc/s3g-mc Package Browser.lua`.
4. Run `s3g-mc Package Browser`.
5. Click `Install/refresh actions` in the browser to register the package
   scripts.

If new JSFX do not appear in the FX browser, rescan JSFX or restart REAPER.

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

`MMD` is recommended for AmbiDEC because this workflow decodes to a custom
irregular 24-point virtual speaker cloud before re-encoding, rather than to a
standard symmetric speaker preset.

After adding or moving the 24-channel insert effect, use the package controller's
`Pin inserts 1-24` button so the insert processes only the wet/effect lane and
does not touch the dry copy or return mask lanes.

More detail is in `Scripts/s3g-mc/s3g_3oa_fx_workflow.md`.

## License

Zero-Clause BSD. See `LICENSE`.

Development assistance: OpenAI Codex.
