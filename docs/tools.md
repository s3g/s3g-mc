---
layout: default
title: Tools
toc:
  - title: Channel Mixing
    href: "#channel-mixing--automation"
  - title: Procedural Synthesis
    href: "#procedural-synthesis"
  - title: Offline Synthesis / IR
    href: "#offline-synthesis--ir"
  - title: Spatial / HOA
    href: "#spatial--hoa"
  - title: Spectral / Convolution
    href: "#spectral--convolution"
  - title: Item Transforms
    href: "#item-channel-transforms"
  - title: Texture / Montage
    href: "#multichannel-texture--montage"
  - title: Track Routing
    href: "#track-building--routing"
---

# Tools

## Channel Mixing / Automation

- `128ch Automation Mixer`: faders, mute/solo, channel groups, meters, and
  plugin pin remapping for high-channel-count tracks.
- `MC to Stereo Autogain`: multichannel fold-down with layout modes, width,
  rotation, weighting, autogain, and output trim.

## Procedural Synthesis

These render actions drive included JSFX synth engines offline.

- `Render MC Carto Synth`: renders multichannel dust, pulse-packet,
  logic/fractal-drone, byte-mask, and spline-drift materials.
- `Render MC Spectra Synth`: renders slower spectral-mass and resonant
  materials: partial clouds, comb strata, formant bands, impulse resonators,
  and noise spectra.

Both use breakpoint curves for parameter motion and channel behavior, then
write a new multichannel media item.

## Offline Synthesis / IR

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

## Spatial / HOA

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

## Spectral / Convolution

These offline processes are informed by spectral tool families such as
<a href="https://www.composersdesktop.com/" target="_blank" rel="noopener noreferrer">CDP</a>,
<a href="https://www.soundhack.com/freeware/the-boneyard/" target="_blank" rel="noopener noreferrer">SoundHack</a>,
<a href="https://github.com/ericlyon/FFTease3.0-MaxMSP" target="_blank" rel="noopener noreferrer">FFTease</a>, and
<a href="https://www.michaelnorris.info/software/soundmagic-spectral" target="_blank" rel="noopener noreferrer">SoundMagic Spectral</a>.

- `Convolve selected items`: convolution of two selected media items, including
  mono, stereo, multichannel pairing, and summed matrix modes.
- `Cross Synthesis`: offline STFT cross-synthesis for two WAV-backed media
  items.
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
  media items, with an alternate formant-vocode algorithm.
- `Spectral Spatializer`: distributes frequency bins across even output channel
  counts from 2 to 64.
- `Spectral Step Drunk Freeze`: stepped freeze or random-walk freeze through
  spectral frames.
- `Spectral Trace`: partial tracing with modes to keep loudest partials,
  suppress loudest partials, threshold, or thin randomly.

## Item Channel Transforms

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

## Multichannel Texture / Montage

Native REAPER variations inspired by
<a href="https://www.composersdesktop.com/docs/html/cgromc.htm" target="_blank" rel="noopener noreferrer">CDP multichannel processes</a>.
These scripts do not require CDP.

- `Brownian Walk`
- `Cascade Spatial Echo`
- `Channel Orbit Delay`
- `Channel Smear`
- `Crumble Spatial Groups`
- `Flutter Gate`
- `Fracture`
- `Frame Gate`
- `Frame Shift`
- `Marker Spatial Montage`
- `Mono Fill`
- `Scatter Slices`
- `Shred / Slice`
- `Spatial Repeater`
- `Spatial Stutter`
- `Stereo Spin`
- `Texture Clouds`
- `Zigzag Channel Walker`

## Track Building / Routing

- `Build multichannel stem from selected tracks`: routes selected tracks to
  consecutive channels on a new multichannel destination, then renders a
  bounded stem.
- `Cycle mono tracks into multichannel stem`: selected mono tracks become a
  multichannel stem, with repeat or grouped downmix behavior when the requested
  output count differs from the source count.
- `Route selected tracks to multichannel folder bus`: creates a new parent
  folder bus and assigns each child track to consecutive bus channels.
