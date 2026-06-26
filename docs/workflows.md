---
layout: default
title: Workflows
prev_page:
  title: Tools
  url: /tools.html
toc:
  - title: Package Browser
    href: "#package-browser"
  - title: Track-Level Channel Mixing
    href: "#track-level-channel-mixing"
  - title: Item and Stem Workflows
    href: "#item-and-stem-workflows"
  - title: Offline Render Workflows
    href: "#offline-render-workflows"
  - title: Texture / Montage
    href: "#texture--montage"
  - title: 3OAFX
    href: "#3oafx"
  - title: Spatial Panners
    href: "#spatial-panners"
---

# Workflows

## Package Browser

The package browser is the easiest way to run the tools and install or refresh
the individual REAPER actions. It groups scripts by use: channel mixing,
spatial/HOA, spectral/convolution, offline synthesis, item transforms,
multichannel montage, and track routing.

## Track-Level Channel Mixing

Use the `128ch Automation Mixer` on high-channel tracks and buses when you need
track-style control over many channels at once. It gives you faders, mute/solo,
meters, quick groups, selection behavior, and a compact plugin pin connector
for tracks up to REAPER's 128-channel limit.

Use `MC to Stereo Autogain` when a multichannel track needs a practical stereo
fold-down for monitoring, previewing, or rendering. The controller exposes
layout, width, rotation, weighting, 3D projection attenuation, output trim, and
autogain controls so the fold-down can be shaped without losing the
multichannel source.

## Item and Stem Workflows

The item and stem tools are for changing the channel structure of existing
material. They can explode multichannel items, rebuild stems from selected
tracks, cycle mono tracks into multichannel layouts, and prepare channel counts
for later spatial or spectral work.

These actions are intended to leave obvious new media items or tracks behind,
rather than silently changing the source. When a process renders audio, it is
bounded to the selected item, selected track material, or requested output
duration wherever possible.

## Offline Render Workflows

The spectral, convolution, resynthesis, and offline synth tools are
non-realtime processes. Select media items, choose the render settings, and the
script writes a new media item into the project.

Python and NumPy are used where Lua or JSFX would be too slow or too limited:
FFT processing, convolution, spectral recombination, dense grain rendering, and
oscillator-bank resynthesis. The included JSFX synth engines are also rendered
offline when a process benefits from REAPER's audio engine and automation.

## Texture / Montage

The montage tools create multichannel structures from slices, impulses, grains,
and channel motion. They are useful for turning mono or stereo source material
into spatial material with controlled randomness.

Many of these actions can use even slicing, project markers, or take markers.
The result is usually a new multichannel item: slices can be scattered, repeated,
spread across channels, moved between channels, or constrained into denser and
thinner regions over time.

## 3OAFX

This workflow processes a 24-channel third-order ambisonic speaker feed inside
a 72-channel REAPER track. The extra channels carry a protected dry copy and a
return mask so one inserted effect can be moved, shaped, and mixed without
destroying the original signal.

The workflow inherits ideas from
<a href="https://github.com/risdsound/foafx" target="_blank" rel="noopener noreferrer">FOAFX</a>:
decode an ambisonic signal to a controlled virtual speaker layer, process a
spatially selected wet path, then recombine or re-encode the result. In
`s3g-mc`, that logic is adapted for third-order ambisonics, a 24-point virtual
speaker layout, and a REAPER workflow built around JSFX lanes, plugin pinning,
and an ImGui controller.

There is also a NumPy-backed offline renderer, `3OAFX Offline Renderer.lua`.
It works directly from a selected ACN/SN3D ambisonic media item, supports 1OA,
2OA, and 3OA, and writes a new ambisonic item with the selected focus movement,
dry attenuation, and regional effect baked into the render.

### Required Files

JSFX install to:

```text
REAPER/Effects/s3g
```

Core effects:

- `s3g 3OA Send`
- `s3g 3OA Return Mask`
- `s3g 3OA Mixer`

Controller:

- `3OAFX Send Return Controller.lua`

### Basic Chain

On one REAPER track, use this order:

1. SPARTA AmbiDEC
2. `JS: s3g 3OA Send`
3. one 24-channel insert effect
4. `JS: s3g 3OA Return Mask`
5. `JS: s3g 3OA Mixer`
6. SPARTA AmbiENC

The track must be set to 72 channels.

Recommended SPARTA settings:

- Ambisonic order: `3rd order`
- Channel ordering: `ACN`
- Normalization: `SN3D`
- AmbiDEC decoder mode: `MMD` / multi-mode decoder
- Number of virtual speaker/source points: `24`

Load the included JSON layouts from `sparta_json/`:

- AmbiDEC: `s3g_3oa_24_virtual_speakers_ambidec_loudspeaker_layout.json`
- AmbiENC: `s3g_3oa_24_virtual_speakers_ambienc_source_layout.json`

`MMD` is recommended for AmbiDEC because this workflow decodes to a custom
irregular 24-point virtual speaker cloud before re-encoding, rather than to a
standard symmetric speaker preset.

### Channel Layout

The 72-channel bus is divided into three 24-channel lanes:

- `1-24`: wet/effect lane
- `25-48`: clean dry copy
- `49-72`: return mask for mixer ducking and monitoring

`s3g 3OA Send` reads the original 24 channels, writes the effect send to `1-24`,
and writes a clean dry copy to `25-48`.

The inserted effect should process only `1-24`.

`s3g 3OA Return Mask` reads the effected audio from `1-24`, passes the dry copy
through `25-48`, and writes the return mask to `49-72`.

`s3g 3OA Mixer` reads wet from `1-24`, dry from `25-48`, and the return mask from
`49-72`.

`s3g 3OA Return Mask` has two return-routing modes:

- `Gate`: keeps each wet channel in its original channel and gates it with the
  return mask. Send and return positions need overlap for this to be obvious.
- `Re-place`: sums the effected send and redistributes it through the return
  mask. Use this when the send is on one source position and the effect should
  appear at a different return position.

The ImGui map draws the return mask as green intensity around the speaker dots.
When `s3g 3OA Return Mask` is running, this is read live from the JSFX meter. If
no fresh meter data is available, the map falls back to a predicted mask
calculated from the Return/Mask direction, width, focus, floor, and rear-reject
controls.

### Controller Workflow

1. Select the 3OA FX track.
2. Run `3OAFX Send Return Controller.lua`.
3. Click `Load/repair JSFX` to add or repair the core chain.
4. Add the desired 24-channel insert effect between `s3g 3OA Send` and
   `s3g 3OA Return Mask`.
5. Click `Pin inserts 1-24`.

`Pin inserts 1-24` is required after adding or moving insert effects. It forces
every effect between `s3g 3OA Send` and `s3g 3OA Return Mask` to use only
channels `1-24`, leaving the dry copy on `25-48` untouched.

`Load/repair JSFX` also runs the pin repair, but only for insert effects already
between Send and Return when the button is clicked.

`Lock send and return az/el` links the send and return positions.

`Lock mask shape` links send and return width, focus, and rear reject. Beam
floor, level, gamma, smoothing, and energy compensation remain independent so
the send/return shape can match while the return mask still has its own mixing
feel.

For a simple test, unlock send/return azimuth, put `Send` on a source, put
`Return` somewhere else, and enable `Re-place wet through return mask`. The
effect should be fed by the send position and heard from the return position.

### Mixing Behavior

In `s3g 3OA Mixer`:

- `Wet trim` controls the returned effect level.
- `Dry trim` controls the protected dry copy.
- In insert-duck mode, the return mask ducks the dry signal where the returned
  effect is active.
- With `Wet trim` at `0`, the dry path should remain dry and unducked.

Recommended starting defaults:

- `Wet trim`: `1.00`
- `Dry trim`: `0.65`
- `Output trim`: `0.90`
- `Mask ceiling`: `0.92`
- `Duck curve`: `0.00`

If dry still sounds effected, click `Pin inserts 1-24` and verify the insert
effect is physically between `s3g 3OA Send` and `s3g 3OA Return Mask`.

### Insert Effects

This public package does not include a dedicated 3OA insert effect. Use a
third-party or custom effect that can process the 24-channel wet lane on
channels `1-24`. After adding or moving the insert, click `Pin inserts 1-24` in
the controller so the insert does not process the protected dry copy or return
mask lanes.

### Troubleshooting

If the JSFX do not appear, confirm that this package's `Effects/s3g`
folder was copied or symlinked to `REAPER/Effects/s3g`, then rescan JSFX or
restart REAPER.

If the 3OA chain does not pass audio, confirm that the track is set to 72
channels and that the plugin order is AmbiDEC, Send, insert effect, Return Mask,
Mixer, AmbiENC.

If spatial positions seem wrong, confirm that AmbiDEC is set to MMD, that both
SPARTA plugins use ACN/SN3D 3rd-order ambisonics, and that both included
24-point JSON layouts are loaded.

If the controller map says `Predicted mask peak` instead of `Live mask peak`,
make sure `JS: s3g 3OA Return Mask` is present in the chain and enabled.

If an insert effect processes the dry path, click `Pin inserts 1-24`. REAPER may
auto-wire a newly inserted FX too broadly on a 72-channel track.

## Spatial Panners

The included panners are intended for use with loudspeaker arrays available in
the RISD Studio for Research in Sound & Technology (SRST). The package includes
controllers for a 12-channel dodecahedron layout, a 17-channel cube layout, and
the shared 25-channel dome layout. The 25ch dome panners offer several
approaches to the same array, giving composers room to compare and work with
different spatial behaviors.

The `12ch Dodeca Panner` is AED-native and draws a dodecahedron controller view
for the 12-channel array. The `17ch Cube XYZ Panner` uses 3D DBAP-style
Cartesian amplitude panning, so straight-line XYZ automation is also the audio
model. Its controller exposes native XYZ source controls and a mirrored AED
editing view.

The `Layout Panner` is the more general option. It covers quad, octophonic
ring, 8ch cube, 12ch ring, 16ch ring, 16ch double ring, 20ch double ring, and
24ch dome without overhead. LFE formats are intentionally left out. Speaker
numbering starts near the stereo-right position and proceeds clockwise,
matching the orientation used in the SRST dome tools.

In REAPER, the primary use is on an 8-channel track or bus before the master
send. Each panner can take up to 8 mono source channels and distribute them
across its target loudspeaker layout. This makes the panners useful as spatial
buses: route source material into channels `1-8`, place or automate the sources
with the controller, then send the resulting multichannel output onward to the
session's monitoring or routing path.

Each panner has an associated JSFX engine, and the companion controller script
is the intended way to load and control it. The JSFX parameters remain
automatable in REAPER, but the controller gives direct access to the spatial
map, source positions, and panner-specific controls.

Use `Spatial Automation Composer` when a spatial movement should be composed
offline as editable REAPER automation. It detects supported 8-source AED and XYZ
s3g panners on the selected track, previews the intended motion, and writes
automation points across the time selection or selected item range.

The package includes these spatial panners:

- `12ch Dodeca Panner`
- `17ch Cube XYZ Panner`
- `Layout Panner`
- `25ch LBAP Dome Panner`
- `25ch VBAP Dome Panner`
- `25ch DBAP Dome Panner`
- `25ch Cosine Dome Panner`
- `25ch Region Dome Panner`
- `25ch Vector Morph Dome Panner`
