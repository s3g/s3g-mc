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
  - title: 3OAFX Object Space
    href: "#3oafx-object-space"
  - title: 3OAFX Object / Field Split
    href: "#3oafx-object--field-split"
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

3OAFX processes use `ACN/SN3D` for ambisonic media and rendered ambisonic output. When a process accepts both ambisonic and non-ambisonic material, it should infer the source type from the selected item channel count: `4ch` as 1OA, `10ch` as 2OA using the first 9 channels, and `16ch` as 3OA. A true `9ch` WAV may also be accepted as 2OA. Other channel counts are treated as non-ambisonic source material and encoded into the selected `ACN/SN3D` output order. Processes should also provide an explicit source-format override when ambiguity matters.

When a process follows a specific published idea closely, the relevant guide should say so. Other processes may use published work as historical or conceptual context while extending those ideas into package-specific workflows.

## 3OAFX Object Space

Use this when you want to transform a selected source into an ambisonic object/space relationship. The process accepts either `ACN/SN3D` ambisonic media or non-ambisonic media. In `Auto by channel count`, `4ch`, `10ch`, and `16ch` are interpreted as 1OA, 2OA, and 3OA respectively; true `9ch` WAVs are also accepted as 2OA. Other channel counts are treated as separate source objects and encoded into the selected ambisonic output order.

This process directly draws on Natasha Barrett's distinction between sound-object, sounding space, spatial illusion, spatial allusion, and object-to-resonance transformation. The modes are package-specific extensions of those ideas rather than recreations of a specific Barrett work. Bernhard Leitner's sound-space work is also useful context for hearing sound as architectural material, path, and spatial occupation.

Modes:

- `Resonance bloom` transforms localized object energy into a resonant diffuse field.
- `Spatial occupation` builds an occupied volume from smeared, distributed source energy.
- `Motion counterpoint` separates spectral regions into different spatial motion layers.
- `Spatial allusion` emphasizes partial spatial cues, resonance, and ambiguity rather than a plausible room model.

Start conservatively:

1. Select one WAV-backed media item.
2. Leave `Source format` on `Auto by channel count` unless the item is ambiguous.
3. Choose the target `Output order`.
4. Start with `Object clarity` around `0.5`, `Space amount` below `1.0`, and `Peak normalize` enabled.

For non-ambisonic sources, `Source object spread` controls how broadly each input channel is encoded into the virtual direction layer before the object-space process. For ambisonic sources, the selected order is decoded to the virtual direction layer, transformed, and re-encoded to `ACN/SN3D`.

## 3OAFX Object / Field Split

Use this when you want to separate an ambisonic recording into a foreground
object stream and a field-like spatial bed. Select one WAV-backed `ACN/SN3D`
ambisonic item. The renderer decodes it to the 3OAFX directional layer,
estimates object-like material from transient energy, directional concentration,
and local spectral contrast, then re-encodes the object and field outputs as new
ambisonic WAVs.

This first version is automatic. It does not need a reference file. A guided
variant using object or field reference profiles would be a separate workflow,
closer to the spectral profile tools.

Starting approach:

1. Select one ambisonic WAV-backed media item.
2. Choose the source order: `1OA / 4ch`, `2OA / 9ch`, or `3OA / 16ch`.
3. Leave `Output` on `Both object and field`.
4. Start with `Object bias` around `0.55`, `Transient weight` and
   `Directional coherence` around `0.45`, and `Peak normalize` enabled.

Raise `Transient weight` when attacks should be captured as object material.
Raise `Directional coherence` when focused directional energy should stay in the
object stream. Raise `Field smoothing` when the bed should be broader and less
edge-like. `Object / field crossfade` prevents the two outputs from becoming too
binary.

## 3OAFX Scene Navigator

Use this when you want several ambisonic recordings to behave like soundfield
nodes on a navigable scene surface. Select two or more WAV-backed `ACN/SN3D`
ambisonic media items. Each item becomes a draggable node in the map. Node size
is editable: larger nodes keep influence over a wider area, while smaller nodes
make tighter zones. The listener path is drawn through those nodes with editable
XYZ position and normalized time breakpoints. By default, the listener head
faces the direction of travel. A manual AED orientation mode is available when
yaw, pitch, and roll should be controlled independently from the trajectory. The
editor includes a visual preview transport so the trajectory and head direction
can be checked before rendering. The renderer writes a new ambisonic WAV
representing that traversal.

This is a scene-interpolation and perspective-traversal process. It should not
be read as literal physical six-degrees-of-freedom translation inside a single
ambisonic recording. Instead, it composes a path through multiple encoded
soundfields by decoding each selected file to the same 3OAFX direction layer,
weighting nearby nodes, rotating the virtual field from the listener
perspective, and re-encoding the result.

Starting approach:

1. Select two or more same-order ambisonic WAV-backed items.
2. Leave `Source order` and `Output order` at `3OA / 16ch` for third-order
   material.
3. Drag the blue node spheres to arrange the selected files on the scene map.
4. Drag the purple/red path points to define the listener trajectory. Leave
   `Head orientation` on `Face trajectory` unless independent head movement is
   needed.
5. Start with `Blend field`, `Global node radius` around `1.25`,
   `Perspective rotation` around `0.8`, and `Peak normalize` enabled.

The scene viewer has `3/4`, `Top`, and `Side` camera presets plus camera
azimuth/elevation controls. `Top` is best for placing nodes and path points
across X/Y. `Side` is useful for height changes because dragging edits X/Z.
`3/4` gives the clearest overview of the node field and listener trajectory.

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

The source-format convention is the same as `3OAFX Object Space`: `4ch`, `10ch`, and `16ch` are treated as 1OA, 2OA, and 3OA in `Auto by channel count`, with true `9ch` WAVs also accepted as 2OA. Other channel counts are treated as non-ambisonic source objects.

The optional stereo expansion is informed by Michael Gerzon's writing on deriving surround information from two-channel stereo. In this process it is used as a practical source-expansion step: stereo material contributes left/right object cues plus mid/side-derived front, rear, and side occupation cues before ambisonic encoding. It is not intended as a strict decoder for a historical matrix format.

Starting approach:

1. Select one or more WAV-backed source items.
2. Leave `Source format` on `Auto by channel count` unless the items need an override.
3. Choose the target `Output order`.
4. Start with `Events` around `180`, `Spatial occupation` around `0.7`, and `Peak normalize` enabled.

`Event density` controls how many requested events are admitted. `Min segment ms` and `Max segment ms` set the fragment size range. `Spatial occupation` spreads each event through the virtual direction layer, while `Spatial motion` rotates or offsets event material over short blocks. Dense settings and long segments can build level quickly, so normalization is recommended while exploring.

## Stereo Expand to Ambisonic Bed

Use this when you want mono or stereo source material to become an ambisonic bed
for later 3OAFX processing. The renderer writes a new `ACN/SN3D` 1OA, 2OA, or
3OA WAV. Mono sources are treated as a center object. Stereo sources are split
into left/right plus mid/side cues, then distributed as front, side, rear, and
optional height material before ambisonic encoding.

This process is informed by Michael Gerzon's work on deriving surround
information from two-channel stereo, but it is a package-specific expansion
tool rather than a decoder for a named matrix format.

Starting approach:

1. Select one WAV-backed mono or stereo media item.
2. Choose the target `Output order`.
3. Start with `Balanced bed`, `Stereo width` near `1.0`, and `Peak normalize`
   enabled.
4. Raise `Rear amount`, `Side amount`, or `Height amount` to make a broader bed.

`Decorrelation` adds diffuse support to the derived field. `Source spread`
controls how tightly the derived components land on the virtual direction layer.
`Bass mono below Hz` centers low frequencies before expansion, useful when the
output will later be folded down or decoded to compact speaker layouts.

## 3OAFX Ambisonic Kernel Collage

Use this when the second set of files are not impulse responses, but ambisonic recordings you want to impose on another ambisonic source. The earliest selected WAV is the source. Every later selected WAV becomes a kernel recording. Any number of kernels can be selected. Files should use `ACN/SN3D`; kernels may be 1OA, 2OA, or 3OA when mixed-order adaptation is enabled.

The process decodes the source to a small virtual direction layer, convolves those source feeds with the kernel recordings, and sums the result back to an encoded ambisonic WAV. It is closer to spatial cross-convolution than room simulation: transients in the source can excite the spectral and spatial body of the kernel recordings, while sustained sources can become smeared or clouded by them.

Start conservatively:

1. Select a 1OA, 2OA, or 3OA source item first on the timeline.
2. Select one or more same-order ambisonic recordings to use as kernels.
3. Run `3OAFX Ambisonic Kernel Collage`.
4. Start with `Cycle kernels across directions`, `Max kernel window sec` around 2-4 seconds, and `Wet pre-gain dB` around `-18`.

`Direction layer` chooses the virtual directional structure. `Auto by order` uses four tetrahedral directions for 1OA and eight practical directions for 2OA/3OA. `Sparse 4-direction tetrahedral` can also be used with higher-order sources when you want a simpler four-region behavior. `Practical 8-direction` keeps the eight-region layout regardless of order.

`Kernel assignment` controls how the kernel recordings are distributed across those directions. `Cycle` is predictable and can use any number of kernels. `Random one per direction` changes the mapping with the seed. `Kernel index equals direction` treats the selected kernels as explicit direction slots, leaving missing slots silent and ignoring extra kernels. `Region smear` gives every selected kernel an implied position and blends nearby kernels into each virtual direction. `Dense all kernels per direction` can produce large, saturated spatial masses because every direction is convolved with every kernel.

`Adapt mixed-order kernels` lets 1OA, 2OA, and 3OA kernel recordings be used together. The selected output order is set by the source/order menu. Higher-order kernels are reduced to that order. Lower-order kernels keep their available channels, and missing higher-order channels are inferred from the lower-order directional energy. This is useful for collage work, but it is not the same as having native measured material at every order.

The kernel window, fade, wet pre-gain, soft limit, and peak normalize controls are there because a whole recording used as a convolution kernel can build level quickly. Shorter kernel windows usually keep the source identity clearer; longer windows push toward suspended, imprint-like fields.



## 3OAFX Offline Ambisonic Convolve

Use this for offline convolution of ambisonic source material with ambisonic impulse responses. It belongs with the 3OAFX offline family because it can either convolve one same-order ambisonic file with one same-order ambisonic IR, or use an intermediate directional layer before returning to ambisonic format. The banked method is inspired by the measured-reverb workflow Bruce Wiggins described in *Sounds in Space 2017*: decode or transform the ambisonic source to directional feeds, convolve those feeds with corresponding ambisonic IRs, then sum the wet result back into ambisonic format.

Selection:

1. Select the ambisonic source WAV as the earliest selected item on the timeline.
2. Select either one same-order ambisonic IR WAV, or a direction-accurate IR bank.
3. Run `3OAFX Offline Ambisonic Convolve`.

The source and IR items should use the same ambisonic convention: `ACN/SN3D`. Choose the source order to match the item: `1OA / 4ch`, `2OA / 9ch`, or `3OA / 16ch`.

Convolution methods:

- `Same-order direct convolution` uses one ambisonic source and one ambisonic IR at the same order: 1OA to 1OA, 2OA to 2OA, or 3OA to 3OA. The channels are convolved channel-for-channel.
- `Directional IR bank` uses a measured or designed ambisonic IR for each required direction. First order uses the four-direction P-format / tetrahedral method. 2OA and 3OA use an eight-direction cube-corner bank: `8 x 9 = 72` channels for a stacked 2OA bank, or `8 x 16 = 128` channels for a stacked 3OA bank.

In directional-bank mode, the IRs are encoded ambisonic WAVs, not P-format files. The source is transformed into the intermediate direction layer, then each directional feed is convolved with an encoded ambisonic IR. The summed output is a new encoded ambisonic WAV in the selected order.

Directional-bank mode does not reuse or wrap IRs. Select either one correctly stacked bank or the exact number of separate IR files required by the method: 4 files for first order, 8 files for 2OA or 3OA. A first-order four-direction bank is not an accurate substitute for an eight-direction 3OA bank. Render time increases with source duration, IR length, ambisonic order, and number of virtual directions.

`Adapt lower-order IRs to output order` allows a lower-order directional bank to be used in a higher-order render, for example eight 1OA IRs or one 32-channel stacked 1OA bank in a 3OA render. The adaptation estimates direction and signed energy from the lower-order IR, then re-encodes that response to the selected output order. This preserves the lower-order directional information, but it should be understood as an inferred higher-order response rather than a measured 3OA IR.

`Allow sparse 4-direction FOA bank` lets four 1OA directional IRs, or one 16-channel stacked FOA bank, drive a 2OA or 3OA render. This uses the P-format / tetrahedral directions as the source-feed layer. It is useful when only four measured directions are available, but it is intentionally sparse: the additional 8-direction higher-order measurement positions are not filled or guessed.

Use `Dry level` when the IRs were captured with little direct sound and you want to add the original source back separately. Use `Wet pre-gain dB` to lower the convolution bank before normalization if the wet result builds up.

For testing and designed spaces, run `3OAFX Synthetic Ambisonic IR Bank` to create encoded ambisonic IRs for the same direction layer. It uses room dimensions, material absorption, scattering, source distance, early reflections, and late diffuse taps to sketch a synthetic acoustic response.

The designer can write separate ambisonic WAVs, one per virtual direction, or one stacked multichannel bank where each direction occupies a block of ambisonic channels. The convolver detects either format. The practical 2OA and 3OA stacked banks are designed to fit REAPER's 128-channel track limit. The designer writes a direction-map CSV next to the generated IRs, and the convolver prints the same azimuth/elevation map in the console so measured banks can be checked against the expected order.



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

The source and profile should use the same ambisonic order and channel format.
The renderer decodes both to the same 3OAFX directional layer, builds a spectral
profile per direction, applies subtraction, and re-encodes the result to
ACN/SN3D.

Settings:

- `Output`: `Cleaned source` writes the reduced source; `Residue only` writes
  the removed material.
- `Reduction amount`: how strongly the profile is subtracted.
- `Spectral floor`: the minimum gain left in a bin, useful for avoiding hollow
  or watery artifacts.
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

`3OAFX Spatial Grains` follows the spatial-grain principle described by E.
Deleflie and Greg Schiemer: the same grain micro-control is applied to every
encoded component channel. In practice, grain position, duration, envelope,
playback rate, overlap, and navigation mode are shared across the 1OA, 2OA, or
3OA channels, so the renderer can work directly on the encoded ambisonic file.

Use `Navigation mode` to decide how source time is used as a spatial index:

- `Index scan`: reads through the source as a trajectory.
- `Cloud`: samples source-time positions statistically.
- `Dual state`: moves between two source-time regions.
- `Jump scan`: steps through source-time regions.
- `Freeze cloud`: builds a cloud around one source-time position.

`Room memory` increases minimum grain length and overlap to help retain
reverberant or time-based spatial cues. `Yaw` controls add optional HOA-domain
rotation; order weighting can soften or emphasize higher-order spatial detail.
