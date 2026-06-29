---
layout: default
title: Spatial and Channel Guides
prev_page:
  title: 3OAFX Guides
  url: /process-guides-3oafx.html
next_page:
  title: Gallery
  url: /gallery.html
toc:
  - title: Ambisonic Stereo Decoder
    href: "#ambisonic-stereo-decoder"
  - title: 6ch Ambisonic Decoder Router
    href: "#6ch-ambisonic-decoder-router"
  - title: Panners
    href: "#panners"
  - title: MC Channel Automation Mixer
    href: "#mc-channel-automation-mixer"
  - title: MC to Stereo Autogain
    href: "#mc-to-stereo-autogain"
  - title: Transaural Crosstalk Canceller
    href: "#transaural-crosstalk-canceller"
  - title: Track and Item Helpers
    href: "#track-and-item-helpers"
---

# Spatial and Channel Guides

These guides cover spatial monitoring, panners, channel control, fold-down, transaural playback, and project-structure helpers.

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


## Panners

The panner controllers are companion interfaces for JSFX. Insert or load the JSFX on a track, then use the matching controller from the package browser or Action List for a larger spatial interface.

General workflow:

1. Put mono sources on an 8-channel track or bus where the panner expects up to 8 input sources.
2. Load the matching `s3g` panner JSFX.
3. Open the controller.
4. Use the visual panel, source controls, and automation controls from the controller rather than the raw JSFX fader list.

The `Layout Panner` is the general option for quad, rings, cube, double-ring, and 24-channel dome layouts. Use it when you want a common speaker arrangement without committing to one SRST-specific array.

The 25-channel dome panners share the RISD SRST dome layout but use different panning ideas:

- `LBAP` is a practical default for smooth dome movement.
- `VBAP` emphasizes nearest-region vector behavior.
- `DBAP` emphasizes distance-weighted motion.
- `Cosine` gives softer angular focus.
- `Region` constrains sources to named arcs, rings, triangles, and custom constellations.
- `Vector Morph` stores scenes and interpolates between them.

The `17ch Cube XYZ Panner` is an XYZ-native panner. Use smaller spread values when you want a source to focus near a single speaker, and larger distance or offset gestures when you want a source to feel beyond the cube.

The `12ch Dodeca Panner` uses an AED-native spherical layout drawn as a dodecahedron. It supports discrete spherical motion with a smaller speaker count.

For automation, use the controller's automation controls to show, hide, arm, and write relevant lanes. In `Trim/Read`, the GUI can audition control changes without writing automation. Use write modes when you intentionally want controller motion recorded.


## MC Channel Automation Mixer

Use this as a track-level multichannel mixer when REAPER's normal JSFX fader view becomes too long to manage.

Workflow:

1. Select a multichannel track.
2. Run `128ch Automation Mixer`.
3. Set the track channel count in REAPER as needed.
4. Use the controller for faders, mute, solo, channel groups, meters, and pin routing.

The visible mixer adapts to the track channel count, up to REAPER's 128-channel limit. Faders use a dB-style response, double-click returns to unity, and direct dB entry can make relative changes across selected faders.

Use shift-click to select or release channels. Quick channel groups highlight related faders and let a group move together. The pin matrix is for channel remapping and should be treated as routing, not gain.


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

- `Cancellation mode`: `Matrix inverse` is the more reference-aligned
  transaural approximation. `Feedforward` keeps the earlier gentler subtraction
  behavior and can be useful in reflective rooms or less exact speaker setups.
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


## Track and Item Helpers

These are utility actions for building and reorganizing multichannel projects. They usually do one structural task, so duplicated test items are a useful way to confirm the result before working on source material.

Useful starting points:

- `Route Selected Tracks to Multichannel Bus` gathers selected mono or lower-channel tracks into a new multichannel folder/bus and assigns channel routing in order.
- `Build multichannel stem from selected tracks` creates a rendered multichannel stem from selected tracks.
- `Explode multichannel item to mono tracks` separates a multichannel media item into one mono track per channel.
- `Resize item channel count` repeats or downmixes channels to reach a target count.
- `Reorder`, `Rotate`, `Mirror`, `Interleave`, and `Deinterleave` change channel order without changing the musical content.

For routing actions, select only the tracks you want included. If the requested result would exceed REAPER's 128-channel limit, the action should stop rather than build an invalid bus. For render-based helpers, expect a new media item or track and keep the source material until you have checked the result.
