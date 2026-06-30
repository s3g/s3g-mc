---
layout: default
title: 3OAFX Guides
guide_nav: true
prev_page:
  title: Spatial Panners Guides
  url: /process-guides-spatial-panners.html
next_page:
  title: Spectral / Convolution Guides
  url: /process-guides-spectral.html
toc:
  - title: Source Format Convention
    href: "#source-format-convention"
  - title: 3OAFX Send Return Controller
    href: "#3oafx-send-return-controller"
  - title: 3OAFX Object Space
    href: "#3oafx-object-space"
  - title: 3OAFX Object / Field Split
    href: "#3oafx-object--field-split"
  - title: 3OAFX Particle Cloud
    href: "#3oafx-particle-cloud"
  - title: 3OAFX Pulsar Field
    href: "#3oafx-pulsar-field"
  - title: 3OAFX Scene Navigator
    href: "#3oafx-scene-navigator"
  - title: 3OAFX Spatial Occupation Montage
    href: "#3oafx-spatial-occupation-montage"
  - title: Stereo Expand to Ambisonic Bed
    href: "#stereo-expand-to-ambisonic-bed"
  - title: 3OAFX Ambisonic Kernel Collage
    href: "#3oafx-ambisonic-kernel-collage"
  - title: 3OAFX Offline Ambisonic Convolve
    href: "#3oafx-offline-ambisonic-convolve"
  - title: 3OAFX Synthetic Ambisonic IR Bank
    href: "#3oafx-synthetic-ambisonic-ir-bank"
  - title: 3OAFX Offline Renderer
    href: "#3oafx-offline-renderer"
  - title: 3OAFX Spectral Profile Subtract
    href: "#3oafx-spectral-profile-subtract"
  - title: 3OAFX Spectral Profile Tools
    href: "#3oafx-spectral-profile-tools"
  - title: 3OAFX Spatial Grains
    href: "#3oafx-spatial-grains"
---

# 3OAFX Guides

These guides match the Package Browser's 3OAFX group. They cover ambisonic offline rendering, ambisonic convolution, spatial grains, and ambisonic spectral profile tools.

## Source Format Convention

3OAFX processes use `ACN/SN3D` for ambisonic media and rendered ambisonic output. When a process accepts both ambisonic and non-ambisonic material, `Auto by channel count` reads `4ch` as 1OA, `10ch` as 2OA using the first 9 channels, and `16ch` as 3OA. A true `9ch` WAV may also be accepted as 2OA. Other channel counts are treated as non-ambisonic source objects. Each input channel is placed onto the selected 3OAFX directional layer, then encoded into the selected `ACN/SN3D` output order. This is a directional-layer interpretation rather than a decode of a standard speaker format such as 5.1 or hexagonal ring. Use the source-format override when the selected item needs to be interpreted differently.

References and related writings are listed separately in the documentation. The guide pages focus on how to use each process.

## 3OAFX Send Return Controller

Use this controller for the live 3OAFX send/return workflow on a 72-channel track. The track holds a decoded 24-channel virtual speaker lane between an ambisonic decoder and encoder. The controller changes the included JSFX masks and mixer so an inserted 24-channel effect can be focused on a region of the virtual speaker layer.

Track layout:

1. Ambisonic decoder before the 3OAFX send stage.
2. `JS: s3g 3OA Send`.
3. One 24-channel effect insert.
4. `JS: s3g 3OA Return Mask`.
5. `JS: s3g 3OA Mixer`.
6. Ambisonic encoder after the mixer.

Recommended external plugins for this live workflow are SPARTA `AmbiDEC` before `s3g 3OA Send` and SPARTA `AmbiENC` after `s3g 3OA Mixer`. Set `AmbiDEC` to `MMD` and load the included 24-point coordinate JSON files for both the decoder and encoder. The JSON files are included in the package's `sparta_json` folder.

SPARTA settings for this chain:

- Ambisonic order: `3rd order`
- Channel ordering: `ACN`
- Normalization: `SN3D`
- AmbiDEC decoder mode: `MMD` / multi-mode decoder
- Number of virtual speaker/source points: `24`

The 72-channel bus is divided into three 24-channel lanes:

- `1-24`: wet/effect lane
- `25-48`: clean dry copy
- `49-72`: return mask for mixer ducking and monitoring

The inserted effect processes only `1-24`. After adding or moving an insert
effect, click `Pin inserts 1-24` in the controller so the dry copy and return
mask lanes remain reserved for the included 3OAFX JSFX.

Controller setup:

1. Select the 3OA FX track.
2. Run `3OAFX Send Return Controller`.
3. Click `Load/repair JSFX` to add or repair the core chain.
4. Add the desired 24-channel insert effect between `s3g 3OA Send` and
   `s3g 3OA Return Mask`.
5. Click `Pin inserts 1-24`.

Main controls:

- Focus azimuth and elevation set the center of the processed region.
- Focus width and sharpness shape how many virtual speakers are included.
- Return amount controls how much processed signal is returned.
- Dry and mix controls decide how the masked effect and unprocessed signal combine.
- The visual mask display shows which of the 24 virtual points are included in the focus area.

## 3OAFX Object Space

Use this when you want to transform a selected source into an ambisonic object/space relationship. The process accepts either `ACN/SN3D` ambisonic media or non-ambisonic media. In `Auto by channel count`, `4ch`, `10ch`, and `16ch` are interpreted as 1OA, 2OA, and 3OA respectively; true `9ch` WAVs are also accepted as 2OA. Other channel counts are treated as separate source objects placed onto the selected 3OAFX directional layer before ambisonic encoding.

Modes:

- `Resonance bloom` transforms localized object energy into a resonant diffuse field.
- `Spatial occupation` builds an occupied volume from smeared, distributed source energy.
- `Motion counterpoint` separates spectral regions into different spatial motion layers.
- `Spatial allusion` emphasizes partial spatial cues, resonance, and ambiguity rather than a plausible room model.

Initial setup:

1. Select one WAV-backed media item.
2. Leave `Source format` on `Auto by channel count` unless the item is ambiguous.
3. Choose the target `Output order`.
4. Use `Object clarity` around `0.5`, `Space amount` below `1.0`, and `Peak normalize` enabled while setting the relationship.

For non-ambisonic sources, `Source object spread` controls how broadly each input channel is encoded into the virtual direction layer before the object-space process. For ambisonic sources, the selected order is decoded to the virtual direction layer, transformed, and re-encoded to `ACN/SN3D`.

## 3OAFX Object / Field Split

Use this when you want to separate an ambisonic recording into a foreground
object stream and a field-like spatial bed. Select one WAV-backed `ACN/SN3D`
ambisonic item. The renderer decodes it to the 3OAFX directional layer,
estimates object-like material from transient energy, directional concentration,
and local spectral contrast, then re-encodes the object and field outputs as new
ambisonic WAVs.

This version is automatic and does not need a reference file. The process
estimates foreground and field behavior from the selected source itself.

Initial setup:

1. Select one ambisonic WAV-backed media item.
2. Choose the source order: `1OA / 4ch`, `2OA / 9ch`, or `3OA / 16ch`.
3. Leave `Output` on `Both object and field`.
4. Use `Object bias` around `0.55`, `Transient weight` and
   `Directional coherence` around `0.45`, and `Peak normalize` enabled.

Raise `Transient weight` to place attacks in the object output. Raise
`Directional coherence` to keep focused directional energy in the object stream.
Raise `Field smoothing` to broaden the bed and reduce edge-like separation.
`Object / field crossfade` blends the two outputs.

## 3OAFX Particle Cloud

Use this when you want an ambisonic source to be reassembled as a particle
cloud while keeping grain decisions coherent across all encoded component
channels. Select one WAV-backed `ACN/SN3D` ambisonic media item, choose the
source order, and render a new ambisonic item.

Method:

The renderer emits grains from the selected source. Each grain uses the same
source-time position, duration, envelope, playback rate, and yaw transform
across every encoded channel. This keeps the source moving as one ambisonic
field rather than treating HOA channels as unrelated mono files.

Main controls:

- `Grain rate`, `Streams`, `Asynchronicity`, and `Intermittency` define when
  particles are emitted.
- `Scan begin`, `Scan range`, and `Scan speed` define where grains read from
  the source.
- `Grain duration`, `Duration jitter`, and `Envelope shape` define the particle
  profile.
- `Playback rate` and `Playback jitter` alter grain reading speed.
- `Yaw` controls rotate the ambisonic field over the render; `Higher-order blur`
  softens upper-order spatial detail.

## 3OAFX Pulsar Field

Use this to synthesize a new `ACN/SN3D` ambisonic item from pulsar streams.
The process does not need a source item. It creates sound from short pulsarets
whose repetition rate can move between rhythm, flutter, and tone.

Method:

Each stream emits a train of pulsars. The fundamental curve controls the
emission period, the formant curve controls pulsaret width, and the pulse mask
decides which pulsars are heard or left silent. Each stream is encoded along an
AED trajectory before the result is written as 1OA, 2OA, or 3OA.

Main controls:

- `Fundamental start/end` controls the pulsar-train rate.
- `Formant start/end` controls the pulsaret duration and spectral region.
- `Pulse mask` selects stochastic omission, burst/rest patterns, channel
  dialogue, or no mask.
- `Pulsaret` and `Pulsaret envelope` shape each particle.
- `Azimuth`, `Elevation`, and `Stream spatial spread` place the streams in the
  ambisonic field.

## 3OAFX Scene Navigator

Use this when you want several ambisonic recordings to behave like soundfield
nodes on a navigable scene surface. Select two or more WAV-backed `ACN/SN3D`
ambisonic media items. Each item becomes a draggable node in the map. Node size
is editable: larger nodes keep influence over a wider area, while smaller nodes
make tighter zones. The listener path is drawn through those nodes with editable
XYZ position and normalized time breakpoints. By default, the listener head
faces the direction of travel. A manual AED orientation mode is available when
yaw, pitch, and roll are controlled independently from the trajectory. The
editor includes a visual preview transport so the trajectory and head direction
can be checked before rendering. The renderer writes a new ambisonic WAV
representing that traversal.

This is a scene-interpolation and perspective-traversal process. It is not
literal physical six-degrees-of-freedom translation inside a single
ambisonic recording. Instead, it composes a path through multiple encoded
soundfields by decoding each selected file to the same 3OAFX direction layer,
weighting nearby nodes, rotating the virtual field from the listener
perspective, and re-encoding the result.

Initial setup:

1. Select two or more same-order ambisonic WAV-backed items.
2. Leave `Source order` and `Output order` at `3OA / 16ch` for third-order
   material.
3. Drag the blue node spheres to arrange the selected files on the scene map.
4. Drag the purple/red path points to define the listener trajectory. Leave
   `Head orientation` on `Face trajectory` unless independent head movement is
   needed.
5. Use `Blend field`, `Global node radius` around `1.25`,
   `Perspective rotation` around `0.8`, and `Peak normalize` enabled.

The scene viewer has `3/4`, `Top`, and `Side` camera presets plus camera
azimuth/elevation controls. `Top` places nodes and path points across X/Y.
`Side` edits X/Z for height changes. `3/4` shows the node field and listener
trajectory together.

If the render duration is longer than one or more selected media items, those
sources are looped under the hood with `Source loop crossfade ms`. This keeps
the listener trajectory independent from file length: each selected soundfield
can remain available as a node and becomes audible when the path enters its
area.

`Global node radius`, the selected node's `Node radius`, `Distance falloff`, and
`Blend sharpness` determine how quickly the renderer moves from one soundfield
node to another. When the listener trajectory moves outside a node, that node
rolls off by distance rather than switching off abruptly. `Near-field blur`
softens transitions close to nodes. `Height sensitivity` controls how strongly
Z-distance affects node weighting. `Perspective rotation` controls how strongly
the listener's derived or manual head orientation rotates the decoded direction
layer.
The `Time` value on each listener breakpoint controls traversal pacing:
breakpoints placed close together in time move quickly, while wider spacing
slows that part of the path.

## 3OAFX Spatial Occupation Montage

Use this to create an ambisonic montage from one or more selected WAV-backed media items. The process fragments the selected sources into overlapping events, distributes those events through a virtual direction layer, and re-encodes the result as `ACN/SN3D` ambisonic output.

The source-format convention is the same as `3OAFX Object Space`: `4ch`, `10ch`, and `16ch` are treated as 1OA, 2OA, and 3OA in `Auto by channel count`, with true `9ch` WAVs also accepted as 2OA. Other channel counts are treated as non-ambisonic source objects placed onto the selected 3OAFX directional layer.

The optional stereo expansion is a practical source-expansion step: stereo material contributes left/right object cues plus mid/side-derived front, rear, and side occupation cues before ambisonic encoding. It is not intended as a strict decoder for a historical matrix format.

Initial setup:

1. Select one or more WAV-backed source items.
2. Leave `Source format` on `Auto by channel count` unless the items need an override.
3. Choose the target `Output order`.
4. Use `Events` around `180`, `Spatial occupation` around `0.7`, and `Peak normalize` enabled.

`Event density` controls how many requested events are admitted. `Min segment ms` and `Max segment ms` set the fragment size range. `Spatial occupation` spreads each event through the virtual direction layer, while `Spatial motion` rotates or offsets event material over short blocks. Dense settings and long segments can build level quickly, so normalization is recommended while exploring.

## Stereo Expand to Ambisonic Bed

Use this when you want mono or stereo source material to become an ambisonic bed
for later 3OAFX processing. The renderer writes a new `ACN/SN3D` 1OA, 2OA, or
3OA WAV. Mono sources are treated as a center object. Stereo sources are split
into left/right plus mid/side cues, then distributed as front, side, rear, and
optional height material before ambisonic encoding.

This is a package-specific expansion tool rather than a decoder for a named
matrix format.

Initial setup:

1. Select one WAV-backed mono or stereo media item.
2. Choose the target `Output order`.
3. Use `Balanced bed`, `Stereo width` near `1.0`, and `Peak normalize`
   enabled.
4. Raise `Rear amount`, `Side amount`, or `Height amount` to make a broader bed.

`Decorrelation` adds diffuse support to the derived field. `Source spread`
controls how tightly the derived components land on the virtual direction layer.
`Bass mono below Hz` centers low frequencies before expansion when the output
will later be folded down or decoded to compact speaker layouts.

## 3OAFX Ambisonic Kernel Collage

Use this when the second set of files are not impulse responses, but ambisonic recordings you want to impose on another ambisonic source. The earliest selected WAV is the source. Every later selected WAV becomes a kernel recording. Any number of kernels can be selected. Files use `ACN/SN3D`; kernels may be 1OA, 2OA, or 3OA when mixed-order adaptation is enabled.

The process decodes the source to a small virtual direction layer, convolves those source feeds with the kernel recordings, and sums the result back to an encoded ambisonic WAV. It is closer to spatial cross-convolution than room simulation: transients in the source can excite the spectral and spatial body of the kernel recordings, while sustained sources can become smeared or clouded by them.

Initial setup:

1. Select a 1OA, 2OA, or 3OA source item first on the timeline.
2. Select one or more same-order ambisonic recordings to use as kernels.
3. Run `3OAFX Ambisonic Kernel Collage`.
4. Use `Cycle kernels across directions`, `Max kernel window sec` around 2-4 seconds, and `Wet pre-gain dB` around `-18` for an initial render.

`Direction layer` chooses the virtual directional structure. `Auto by order` uses four tetrahedral directions for 1OA and eight practical directions for 2OA/3OA. `Sparse 4-direction tetrahedral` can also be used with higher-order sources when you want a simpler four-region behavior. `Practical 8-direction` keeps the eight-region layout regardless of order.

`Kernel assignment` controls how the kernel recordings are distributed across those directions. `Cycle` is predictable and can use any number of kernels. `Random one per direction` changes the mapping with the seed. `Kernel index equals direction` treats the selected kernels as explicit direction slots, leaving missing slots silent and ignoring extra kernels. `Region smear` gives every selected kernel an implied position and blends nearby kernels into each virtual direction. `Dense all kernels per direction` can produce large, saturated spatial masses because every direction is convolved with every kernel.

`Adapt mixed-order kernels` lets 1OA, 2OA, and 3OA kernel recordings be used together. The selected output order is set by the source/order menu. Higher-order kernels are reduced to that order. Lower-order kernels keep their available channels, and missing higher-order channels are inferred from the lower-order directional energy. This makes mixed-order collage possible, but it is not the same as having native measured material at every order.

The kernel window, fade, wet pre-gain, soft limit, and peak normalize controls shape level and duration when a whole recording is used as a convolution kernel. Shorter kernel windows keep more of the source articulation. Longer windows extend the kernel imprint over time.



## 3OAFX Offline Ambisonic Convolve

Use this for offline convolution of ambisonic source material with ambisonic impulse responses. It belongs with the 3OAFX offline family because it can either convolve one same-order ambisonic file with one same-order ambisonic IR, or use an intermediate directional layer before returning to ambisonic format. In directional-bank mode, the source is decoded or transformed to directional feeds, those feeds are convolved with corresponding ambisonic IRs, and the wet result is summed back into ambisonic format.

Selection:

1. Select the ambisonic source WAV as the earliest selected item on the timeline.
2. Select either one same-order ambisonic IR WAV, or a direction-accurate IR bank.
3. Run `3OAFX Offline Ambisonic Convolve`.

The source and IR items use the same ambisonic convention: `ACN/SN3D`. Choose the source order to match the item: `1OA / 4ch`, `2OA / 9ch`, or `3OA / 16ch`.

Convolution methods:

- `Same-order direct convolution` uses one ambisonic source and one ambisonic IR at the same order: 1OA to 1OA, 2OA to 2OA, or 3OA to 3OA. The channels are convolved channel-for-channel.
- `Directional IR bank` uses a measured or designed ambisonic IR for each required direction. First order uses the four-direction P-format / tetrahedral method. 2OA and 3OA use an eight-direction cube-corner bank: `8 x 9 = 72` channels for a stacked 2OA bank, or `8 x 16 = 128` channels for a stacked 3OA bank.

In directional-bank mode, the IRs are encoded ambisonic WAVs, not P-format files. The source is transformed into the intermediate direction layer, then each directional feed is convolved with an encoded ambisonic IR. The summed output is a new encoded ambisonic WAV in the selected order.

Directional-bank mode does not reuse or wrap IRs. Select either one correctly stacked bank or the exact number of separate IR files required by the method: 4 files for first order, 8 files for 2OA or 3OA. A first-order four-direction bank is not an accurate substitute for an eight-direction 3OA bank. Render time increases with source duration, IR length, ambisonic order, and number of virtual directions.

`Adapt lower-order IRs to output order` allows a lower-order directional bank to be used in a higher-order render, for example eight 1OA IRs or one 32-channel stacked 1OA bank in a 3OA render. The adaptation estimates direction and signed energy from the lower-order IR, then re-encodes that response to the selected output order. This preserves the lower-order directional information as an inferred higher-order response rather than a measured 3OA IR.

`Allow sparse 4-direction FOA bank` lets four 1OA directional IRs, or one 16-channel stacked FOA bank, drive a 2OA or 3OA render. This uses the P-format / tetrahedral directions as the source-feed layer. The additional 8-direction higher-order measurement positions are not filled or guessed.

Use `Dry level` when the IRs were captured with little direct sound and you want to add the original source back separately. Use `Wet pre-gain dB` to lower the convolution bank before normalization if the wet result builds up.

For designed impulse responses, run `3OAFX Synthetic Ambisonic IR Bank` to create encoded ambisonic IRs for the same direction layer. It uses room dimensions, material absorption, scattering, source distance, early reflections, and late diffuse taps to define a synthetic acoustic response.

The designer can write separate ambisonic WAVs, one per virtual direction, or one stacked multichannel bank where each direction occupies a block of ambisonic channels. The convolver detects either format. The practical 2OA and 3OA stacked banks are designed to fit REAPER's 128-channel track limit. The designer writes a direction-map CSV next to the generated IRs, and the convolver prints the same azimuth/elevation map in the console so measured banks can be checked against the expected order.



## 3OAFX Synthetic Ambisonic IR Bank

Use this to create encoded ambisonic impulse-response banks for `3OAFX Offline Ambisonic Convolve`. The generated files use `ACN/SN3D` and match the direction layers expected by the convolver.

Output formats:

- `Separate files` writes one ambisonic IR WAV per virtual direction.
- `Stacked bank` writes one multichannel WAV with one ambisonic channel block per direction.

Direction formats:

- 1OA uses a four-direction tetrahedral / P-format-style layout.
- 2OA uses eight directions, with each direction stored as a 9-channel ambisonic block.
- 3OA uses eight directions, with each direction stored as a 16-channel ambisonic block.

The stacked 2OA bank is `72ch`. The stacked 3OA bank is `128ch`, which fits REAPER's maximum track channel count. The script also writes a direction-map CSV next to the generated IRs so the direction order can be checked later.

Main controls:

- Room dimensions set the broad size relationship.
- Material absorption changes how quickly energy decays.
- Scattering changes how separated or diffuse the reflections become.
- Source distance shapes the direct-to-reflected balance.
- Early reflection and late-field controls define the response over time.
- Output gain and peak normalize set the rendered level.



## 3OAFX Offline Renderer

Use this when you want the 3OAFX idea rendered offline directly from an ambisonic media item.

Selection:

- Select one ambisonic media item.
- Use ACN/SN3D channel convention.
- Choose 1OA, 2OA, or 3OA to match the source channel count.

Method:

The process decodes the ambisonic item to a virtual speaker layer, applies an effect over a moving AED focus region, mixes dry and wet behavior using the focus mask, then re-encodes to a new ambisonic item.

Important controls:

- `Effect region` chooses the processing type.
- `Azimuth` and `Elevation` set the focus direction.
- `Focus width` and `Focus sharpness` shape the region.
- `Effect amount / gain` controls how strongly the effect is heard.
- `Wet amount`, `Dry level`, and `Dry remaining at focus` define how dry and processed signal coexist.
- Breakpoint envelopes can animate focus and mix parameters over the item.

For a clear moving-spotlight test, use a strong effect amount, low dry remaining at focus, and an azimuth breakpoint moving from `-180` to `180`.



## 3OAFX Spectral Profile Subtract

Use this when you want to reduce or extract spectral material from an ambisonic
recording without treating each HOA channel as an unrelated signal.

Selection:

1. Select a WAV-backed ambisonic source item.
2. Select a WAV-backed ambisonic profile item that contains the material to
   reduce or extract.
3. Run `3OAFX Spectral Profile Subtract`.

The source and profile use the same ambisonic order and channel format.
The renderer decodes both to the same 3OAFX directional layer, builds a spectral
profile per direction, applies subtraction, and re-encodes the result to
ACN/SN3D.

Settings:

- `Output`: `Cleaned source` writes the reduced source; `Residue only` writes
  the removed material.
- `Reduction amount`: how strongly the profile is subtracted.
- `Spectral floor`: the minimum gain left in a bin.
- `Profile sensitivity`: scales the profile before subtraction.
- `Frequency smoothing bins` and `Temporal smoothing`: soften narrow-bin and
  frame-to-frame changes.



## 3OAFX Spectral Profile Tools

These actions share the same source/profile workflow as `3OAFX Spectral Profile
Subtract`: select a WAV-backed ambisonic source item first, then select a
WAV-backed ambisonic profile or reference item. Both items are decoded to the
same directional layer before processing and re-encoding.

Use the variants for different intentions:

- `3OAFX Spectral Profile Match`: moves the source toward the spectral contour
  of a reference while keeping the source timing and phase.
- `3OAFX Spectral Residue Extractor`: writes the material that would be removed
  by a profile subtraction.
- `3OAFX Spectral Hole Maker`: carves profile-shaped space from the source.
- `3OAFX Ambiance Extractor`: extracts source material that resembles a room
  tone, noise bed, or ambiance profile.

Useful first controls:

- `Amount`: strength of the match, carve, or extraction.
- `Profile sensitivity`: how strongly the second item influences the process.
- `Spectral floor`: how much material is allowed to remain in reduced areas.
- `Frequency smoothing bins` and `Temporal smoothing`: increase these when the
  result feels too narrow, watery, or frame-like.



## 3OAFX Spatial Grains

`3OAFX Spatial Grains` applies the same grain micro-control to every encoded
component channel. Grain position, duration, envelope, playback rate, overlap,
and navigation mode are shared across the 1OA, 2OA, or 3OA channels, so the
renderer can work directly on the encoded ambisonic file.

Use `Navigation mode` to decide how source time is used as a spatial index:

- `Index scan`: reads through the source as a trajectory.
- `Cloud`: samples source-time positions statistically.
- `Dual state`: moves between two source-time regions.
- `Jump scan`: steps through source-time regions.
- `Freeze cloud`: builds a cloud around one source-time position.

`Room memory` increases minimum grain length and overlap to help retain
reverberant or time-based spatial cues. `Yaw` controls add optional HOA-domain
rotation; order weighting can soften or emphasize higher-order spatial detail.
