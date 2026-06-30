---
layout: default
title: Channel Mixing / Automation Guides
guide_nav: true
prev_page:
  title: Process Guides
  url: /process-guides.html
next_page:
  title: MIDI Composition Guides
  url: /process-guides-midi.html
toc:
  - title: Ambisonic Stereo Decoder
    href: "#ambisonic-stereo-decoder"
  - title: 6ch Ambisonic Decoder Router
    href: "#6ch-ambisonic-decoder-router"
  - title: MC Channel Automation Mixer
    href: "#mc-channel-automation-mixer"
  - title: 128ch Node Track Mixer
    href: "#128ch-node-track-mixer"
  - title: MC to Stereo Autogain
    href: "#mc-to-stereo-autogain"
  - title: Transaural Crosstalk Canceller
    href: "#transaural-crosstalk-canceller"
---

# Channel Mixing / Automation Guides

These guides match the Package Browser's Channel Mixing / Automation group and related monitoring tools. They cover track-level channel control, fold-down, monitor decoding, and transaural playback.

## Ambisonic Stereo Decoder

This JSFX is a stereo fold-down decoder for ACN/SN3D ambisonic material. It is
intended for loudspeaker stereo monitoring or stereo renders, not headphone
binaural playback.

The decoder first projects the ambisonic input onto an internal virtual speaker
field, then derives the stereo output by placing a stereo pickup model inside
that field. This follows a practical studio approach: decode to a spatial field,
then choose how a stereo listening position hears that field.

Starting settings:

- `Ambisonic order`: match the source file, usually `1OA`, `2OA`, or `3OA`.
- `Virtual speaker field`: `24ch dome` is a good general starting point for
  3D material; `12ch dodeca` and `32ch sphere` are useful alternate projections.
  Virtual coordinates follow the package/IEM AED convention: `-90` is right,
  `+90` is left, and ring-like fields number speaker 1 at right-front and
  continue clockwise.
- `Stereo method`: start with `XY cardioid` for a stable image. Try `MS
  cardioid` for a center/side-like fold-down, `Blumlein` for a stronger
  figure-8 character, or `ORTF-style` when you want a wider speaker image.
- `Stereo width`: controls how strongly left/right differences are expressed;
  `0%` collapses the stereo pickup to mono.
- `A/B spacing`: adds a small time-difference component for `Spaced omni`, so
  that mode is not only amplitude panning.
- `Listening rotation`: rotates the stereo pickup position inside the virtual
  field. Positive values face left and negative values face right, following
  the package AED convention.
- `Rotation image`: scales how strongly `Listening rotation` is translated into
  the stereo image. `100%` is literal; higher values exaggerate the rotation.
- `Mic elevation`: tilts the stereo pickup upward or downward inside the
  virtual field.
- `Rear rejection`: reduces rear pickup as part of the stereo pickup model.
- `Front/rear balance`: a separate musical front/rear weighting stage. Positive
  values reshape rear material; negative values reduce the front instead.
- `Rear fold`: decides how positive `Front/rear balance` treats rear material:
  `Quieter`, `Narrower`, or `Wrap wide`.
- `Height fold`, `Height image`, and `Diffuse blend`: shape how overhead and
  diffuse material enter the stereo image.
- `Decode weighting`: choose the default projection, energy normalization,
  Max-rE-style taper, or `Custom` band weights for `W`, `1st`, `2nd`, and
  `3rd` order components. Custom weighting is edited with the order-weight
  sliders in the decode section; there is no separate weighting visual layer.
- `Bass mono below`: folds low frequencies toward the stereo center below the
  selected frequency for more controlled stereo renders.

The controller draws the virtual speaker field and the stereo pickup directions
so the fold-down can be adjusted visually. The package AED convention applies:
`-90` is right and `+90` is left.

Preset buttons provide quick starting points without changing the selected
ambisonic order: `Stable Stereo`, `Wide Field`, `Front Focus`, `Room Image`,
`MS Master`, `Blumlein`, and `A/B Soft`.



## 6ch Ambisonic Decoder Router

This JSFX is a package-native monitor decoder/router for a compact 6-speaker
setup. It accepts ACN/SN3D 1OA, 2OA, or 3OA input and writes speaker feeds to
channels 1-6. The default output layout is `45/0`, `-45/0`, `-135/0`,
`135/0`, `90/60`, and `-90/60` in azimuth/elevation degrees; each speaker has
editable azimuth and elevation sliders.

The layout follows the package AED convention: `-90` is right and `+90` is
left. Speakers 1-4 form the horizontal bed; speakers 5 and 6 are the elevated
left and right side speakers. If these defaults do not appear after updating,
rescan JSFX in REAPER and click `Reset 6ch layout` in the controller.

The decoder is an energy-normalized projection decoder with optional
max-rE-style order weighting. It is useful for realtime listening and sketching
inside REAPER. For formal calibrated ambisonic decoding, use a measured decoder
such as IEM `AllRADecoder` when available.

`Direct 6ch` mode bypasses ambisonic decoding and routes input channels 1-6 to
the same speaker outputs. `Ambisonic + Direct` mixes that direct layer with the
decoded ambisonic layer, which is useful when combining non-ambisonic materials
with the same monitor rig.



## MC Channel Automation Mixer

Use this as a track-level multichannel mixer when REAPER's normal JSFX fader view becomes too long to manage.

Workflow:

1. Select a multichannel track.
2. Run `128ch Automation Mixer`.
3. Set the track channel count in REAPER as needed.
4. Use the controller for faders, mute, solo, channel groups, meters, and pin routing.

The visible mixer adapts to the track channel count, up to REAPER's 128-channel limit. Faders use a dB-style response, double-click returns to unity, and direct dB entry can make relative changes across selected faders.

Use shift-click to select or release channels. Quick channel groups highlight related faders and let a group move together. The pin matrix is for channel remapping and should be treated as routing, not gain.


## 128ch Node Track Mixer

Use this when selected source tracks should become spatial mix nodes on a new
multichannel bus. The action creates a bus, routes each selected source track
as a true multichannel send block, loads `s3g 128ch Node Track Mixer`, and
opens a node controller.

The JSFX does not decode or encode ambisonics. It treats the bus outputs as a
layout-aware speaker or channel field. Each node can have its own source shape
and source channel count, so an 8-channel track can be treated as an 8-channel
ring by default, or changed to a cube, dome, or other supported shape. Four
8-channel cube tracks, for example, are packed into 32 input channels on the
bus, then mixed down by the JSFX into the selected 8-channel mix bed.

When source and mix-bed channel counts differ, assignment is based on shape
coordinates rather than channel-number matching. Each source channel has a
position inside its node shape, and the JSFX weights that channel into the
nearest channels of the selected mix bed.

`Mix mode` changes the meaning of the nodes. `Spatial objects` treats each node
as a separate channel shape placed in the field, so two quad nodes beside each
other behave like two neighboring quad arrays. `Stacked shapes` aligns the node
shapes to the same mix bed, so channel 1 of each quad belongs to the same
corner family, channel 2 belongs to the next, and so on. In stacked mode,
`Channel rotate` shifts a node's channel order before it is aligned, which is
useful for rotating quad corners, ring positions, cube corners, or other
multichannel source layouts against the shared bed.

The `Mix Cursor` is the main automation target. In `Spatial objects`, automate
`Cursor X`, `Cursor Y`, and `Cursor Z` to move through the node field. In
`Stacked shapes`, automate `Stack position` to move through aligned node
layers. `Cursor influence` blends the cursor behavior in or out, while `Cursor
radius`, `Cursor focus`, and `Cursor gate` control how many nearby nodes
contribute. Use the falloff curve display to tune the curve: radius sets reach,
focus changes the slope, and gate cuts low node weights to zero. Set
`Cursor influence` to `1.0` when distant nodes should disappear completely.

The controller opens in a top camera view. `3/4`, `Top`, and `Side` camera
presets are available for checking node placement, shape overlap, and Z
position. Source track names are stored on the node bus and shown in the node
labels, selected-node panel, routing overview, and matrix rows.

The matrix mask limits which output channels a node can reach. Leave the matrix
fully enabled for layout interpolation, or disable cells to restrict a node to
a ring, cube layer, speaker group, or custom region.

The `Routing overview` gives a compact source-to-output summary for each node:
track name, input channel range, source shape, active output count, and a small
output strip. Use the detailed matrix below it when exact output masks are
needed.

The `Automation` section mirrors the panner controllers. It can switch the bus
track between `Trim/Read` and `Write`, show or hide cursor lanes, show or hide
curve lanes, and show or hide the stacked-position lane.

Starting approach:

1. Select up to 16 source tracks.
2. Run `128ch Node Track Mixer`.
3. Choose a `Mix mode`, `Mix bed shape`, and channel count.
4. Check each node's `Node source shape`, `Source channels`, and `Input start
   channel`.
5. In `Spatial objects`, move nodes in the viewer and adjust `Shape scale` and
   `Focus`.
6. In `Stacked shapes`, use `Channel rotate`, node level, and `Focus` to align
   or offset each source against the shared bed.
7. Adjust `Cursor radius`, `Cursor focus`, and `Cursor gate` while watching the
   falloff curve.
8. Use `Show cursor lanes`, `Show curve lanes`, or `Show stack` when the mix
   movement should be written as REAPER automation.
9. Use the matrix only when a node should avoid or prefer a defined output
   region.

The script turns off the selected source tracks' master sends when it creates
the node bus, so the bus becomes the monitored/output path.



## MC to Stereo Autogain

Use this at the end of a multichannel sketch when you need a stereo monitor or print. It is not a substitute for an actual multichannel render; it is a controlled fold-down.

Important controls:

- Layout preset describes how channels are arranged conceptually.
- Width and rotation change stereo spread.
- Projection or weighting decides how channels contribute to left and right.
- 3D attenuation can reduce overhead, underhead, or distant speakers in sphere, hemisphere, and cube-style layouts.
- Autogain helps keep the fold-down from jumping in level as channel count changes.

Use ring projection for circular layouts, sphere or hemisphere projection for dome-like material, and cube-style projection for XYZ/cube work. Watch the graphic: smaller dots indicate channels receiving stronger 3D attenuation.



## Transaural Crosstalk Canceller

Use this on a stereo loudspeaker track when you want transaural crosstalk
cancellation for a fixed listening position. It is not a headphone binaural
processor; it will usually sound wrong on headphones and will change with
speaker angle, listener position, and room reflections.

The normal placement is after a binaural decoder or binaural stereo render. The
binaural stage creates the left-ear/right-ear stereo signal; the transaural
stage prepares that signal for loudspeaker playback by reducing how much each
speaker reaches the opposite ear.

The processor is a lightweight JSFX approximation of transaural
crosstalk-cancellation practice. `Feedforward` subtracts a delayed and filtered
opposite-channel path. `Matrix inverse` adds a conservative symmetric 2x2
inverse-style compensation stage, closer to the standard transaural framing of
speaker-to-ear transfer paths, but still without measured HRTFs or room-specific
inverse filters.

Background: transaural stereo is usually described as loudspeaker playback that
accounts for four transfer paths: each speaker to each ear. This tool uses that
idea as a practical controller-oriented approximation rather than as a measured
listener-specific inverse filter.

Starting settings:

- `Cancellation mode`: `Matrix inverse` uses inverse-style compensation.
  `Feedforward` uses delayed opposite-channel subtraction.
- `Cancellation amount`: start around `60-100%`; higher values are more
  dramatic and more position-dependent.
- `Speaker half-angle`: half of the angle between the left and right speakers
  from the listener position. A common stereo triangle is about `30 deg`.
- `Head width`: listener ear spacing estimate; `17-18 cm` is a practical
  default.
- `Delay trim`: fine-tunes the cancellation delay if the image feels smeared or
  hollow.
- `Cancel HF rolloff`: softens the cancellation path so it does not become
  brittle.
- `Low protect`: reduces cancellation in the low end, where room and speaker
  geometry make cancellation less reliable.
- `Stereo preserve`: blends back toward the original stereo signal if the
  cancellation image becomes too fragile.
- `Output gain`: keep headroom; cancellation can raise peaks.

The controller graphic shows the direct speaker-to-ear paths and the delayed
opposite-channel cancellation paths. Head width changes the ear spacing in the
graphic, while the side readouts summarize cancellation filtering, low
protection, stereo preservation, and output trim. Use it as a geometry check,
then tune by ear from the intended listening position.

Preset buttons provide starting points for common situations: `Gentle`,
`Standard`, `Narrow Setup`, `Wide Setup`, and `Careful / Roomy`.
