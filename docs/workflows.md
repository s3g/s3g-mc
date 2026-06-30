---
layout: default
title: Workflows
prev_page:
  title: Tools
  url: /tools.html
next_page:
  title: Process Guides
  url: /process-guides.html
toc:
  - title: Package Browser
    href: "#package-browser"
  - title: Track-Level Channel Mixing
    href: "#track-level-channel-mixing"
  - title: MIDI Composition
    href: "#midi-composition"
  - title: Item and Stem Workflows
    href: "#item-and-stem-workflows"
  - title: Procedural Synthesis
    href: "#procedural-synthesis"
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

The package browser is the central entry point for running tools and installing
or refreshing the individual REAPER actions. It groups scripts by use: channel mixing,
MIDI composition, procedural synthesis, offline synthesis, spatial panners,
3OAFX, spectral/convolution, multichannel texture/montage, item transforms, and
track routing.

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

Use `128ch Node Track Mixer` when several source tracks remain intact as
multichannel objects and are mixed through a shared cursor. Selected tracks are
routed to a new multichannel bus, labeled as nodes, and mixed as spatial
objects or stacked channel-shapes. The controller provides a routing overview,
camera presets, cursor falloff/gate tuning, and automation helpers for writing
cursor or curve movement to REAPER lanes.

Use `Transaural Crosstalk Canceller` after a binaural decoder or binaural
stereo render when that signal needs to play over loudspeakers from a fixed
listening position. It is not a binaural headphone decoder; it is the
loudspeaker playback stage that tries to reduce speaker-to-opposite-ear
crosstalk. `Matrix inverse` uses the inverse-filter transaural model, while
`Feedforward` uses a direct delayed cancellation path.

These tools sit near large-format console, matrix mixer, and spatial control
workflows: channels can be treated as tracks, objects, speaker feeds, or
intermediate routing lanes rather than only as fixed left/right outputs.

## MIDI Composition

The MIDI composition tools write ordinary editable REAPER MIDI items. They use
geometry, tables, paths, Euclidean/polymetric rhythm, learned source traits, and
song-duration form maps as visible ways to compose note data before it is sent
to procedural synths or external instruments.

Some of the visual approaches sit near broader composition references,
including Jerry Hunt's layered table and gesture work, Godfried Toussaint's
rhythm geometry, and Julian Hook's writing on musical spaces. In the package,
those ideas are translated into REAPER MIDI items rather than preserved as
separate notation or performance systems.

## Item and Stem Workflows

The item and stem tools are for changing the channel structure of existing
material. They can explode multichannel items, rebuild stems from selected
tracks, cycle mono tracks into multichannel layouts, and prepare channel counts
for later spatial or spectral work.

These actions are intended to leave obvious new media items or tracks behind,
rather than silently changing the source. When a process renders audio, it is
bounded to the selected item, selected track material, or requested output
duration wherever possible.

## Procedural Synthesis

The procedural synth workflows combine included JSFX engines with render and
MIDI-controller actions. A synth can be printed offline as a new media item, or
loaded on a track and driven from generated MIDI items.

The workflow sits near table-driven synthesis, generative control systems,
chaotic circuits, and offline score/control rendering. In this package, those
ideas are exposed as editable REAPER media items, MIDI items, breakpoint
envelopes, and JSFX parameters.

## Offline Render Workflows

The spectral, convolution, resynthesis, and offline synth tools are
non-realtime processes. Select media items, choose the render settings, and the
action writes a new media item into the project.

This follows an offline computer music workflow: the process is composed,
rendered, auditioned, and edited as media, rather than treated only as a live
insert effect.

Use WAV-backed media for these actions. Convert compressed files to WAV before
rendering. Some included JSFX synth engines also have render actions
and MIDI controller actions, so the same synth can be printed offline or driven
from MIDI items on the timeline.

The spectral and convolution workflows sit alongside computer music tool
families such as
<a href="https://www.composersdesktop.com/" target="_blank" rel="noopener noreferrer">CDP</a>,
<a href="https://www.soundhack.com/freeware/the-boneyard/" target="_blank" rel="noopener noreferrer">SoundHack</a>,
<a href="https://github.com/ericlyon/FFTease3.0-MaxMSP" target="_blank" rel="noopener noreferrer">FFTease</a>, and
<a href="https://www.michaelnorris.info/software/soundmagic-spectral" target="_blank" rel="noopener noreferrer">SoundMagic Spectral</a>.

## Texture / Montage

The montage tools create multichannel structures from slices, impulses, grains,
and channel motion. They can turn mono, stereo, or multichannel source material
into new channel arrangements over time.

Many of these actions can use even slicing, project markers, or take markers.
The result is usually a new multichannel item: slices can be scattered, repeated,
spread across channels, moved between channels, or constrained into denser and
thinner regions over time.

Several texture and montage actions are native REAPER variations related to
<a href="https://www.composersdesktop.com/docs/html/cgromc.htm" target="_blank" rel="noopener noreferrer">CDP multichannel processes</a>.
They do not require CDP.

## 3OAFX

3OAFX tools work with ambisonic material through a virtual speaker layer. The
group includes offline render actions, ambisonic convolution and spectral
profile tools, stereo and compact-speaker decoders, and live send/return
routing.

The workflow inherits ideas from
<a href="https://github.com/risdsound/foafx" target="_blank" rel="noopener noreferrer">FOAFX</a>:
decode an ambisonic signal to a controlled virtual speaker layer, process a
spatially selected wet path, then recombine or re-encode the result. In
`s3g-mc`, that logic extends across live send/return routing, offline
ambisonic rendering, convolution, spectral processing, and monitoring tools.

Other 3OAFX workflows sit near spatial-audio references including Natasha
Barrett's object/space terminology, Michael Gerzon's stereo-to-surround
thinking, Bruce Wiggins's ambisonic convolution workflow, and Deleflie and
Schiemer's spatial-grain model. The process guides describe the package tools
in operational terms.

`3OAFX Send Return Controller` uses one 72-channel REAPER track so a
24-channel effect lane can be focused, masked, mixed with dry signal, and
returned to ambisonic format.

`3OAFX Offline Renderer` works directly from a selected ACN/SN3D ambisonic
media item, supports 1OA, 2OA, and 3OA, and writes a new ambisonic item with
focus movement, dry control, and regional effect behavior baked into the render.

`Ambisonic Stereo Decoder` is a package-native JSFX option for stereo
loudspeaker monitoring or rendering. It is not a binaural headphone decoder.
Instead, it decodes the ambisonic signal to a virtual speaker field, then places
a stereo pickup model inside that field using methods such as XY, MS, Blumlein,
ORTF-style, and spaced omni.

For smaller monitoring setups, `6ch Ambisonic Decoder Router` provides a
package-native JSFX decoder/router for ACN/SN3D 1OA, 2OA, or 3OA into a compact
4-speaker bed plus 2 elevated side speakers. It can also bypass decoding and
route direct 6-channel material to the same outputs.

See the [3OAFX process guides](process-guides-3oafx.md) for controller setup,
offline render actions, convolution tools, spectral profile tools, and synthetic
IR generation.

## Spatial Panners

The included panners are intended for use with loudspeaker arrays available in
the RISD Studio for Research in Sound & Technology (SRST). The package includes
controllers for a 12-channel dodecahedron layout, a 17-channel cube layout, and
the shared 25-channel dome layout. The 25ch dome panners provide several
panning methods for the same speaker arrangement.

The panner group sits near common spatial-audio approaches such as vector-base,
distance-base, layer/region-based, cosine-focus, and Cartesian panning. The
controllers keep a shared 8-source interaction model while changing the
underlying panning behavior.

The `12ch Dodeca Panner` is AED-native and draws a dodecahedron controller view
for the 12-channel array. The `17ch Cube XYZ Panner` uses 3D DBAP-style
Cartesian amplitude panning, so straight-line XYZ automation is also the audio
model. Its controller exposes native XYZ source controls and a mirrored AED
editing view.

The `Layout Panner` covers quad, octophonic ring, 8ch cube, 12ch ring, 16ch
ring, 16ch double ring, 20ch double ring, and 24ch dome without overhead. LFE
formats are intentionally left out. Speaker
numbering starts near the stereo-right position and proceeds clockwise,
matching the orientation used in the SRST dome tools.

In REAPER, the primary use is on an 8-channel track or bus before the master
send. Each panner can take up to 8 mono source channels and distribute them
across its target loudspeaker layout. Route source material into channels `1-8`,
place or automate the sources with the controller, then send the resulting
multichannel output onward to the session's monitoring or routing path.

Each panner has an associated JSFX engine, and the companion controller script
is the intended way to load and control it. The JSFX parameters remain
automatable in REAPER, but the controller gives direct access to the spatial
map, source positions, and panner-specific controls.

Use `Spatial Automation Composer` to compose spatial movement offline as
editable REAPER automation. It detects supported 8-source AED and XYZ s3g
panners on the selected track, previews the intended motion, and writes
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

For controller controls, automation behavior, and panner-specific notes, see the
[Spatial Panners process guide](process-guides-spatial-panners.md).
