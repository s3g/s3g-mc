---
layout: default
title: Spatial Panners Guides
guide_nav: true
prev_page:
  title: Offline Synthesis / IR Guides
  url: /process-guides-offline-synthesis-ir.html
next_page:
  title: 3OAFX Guides
  url: /process-guides-3oafx.html
toc:
  - title: Panners
    href: "#panners"
  - title: Spatial Score
    href: "#spatial-score"
  - title: Spatial Automation Composer
    href: "#spatial-automation-composer"
---

# Spatial Panners Guides

These guides match the Package Browser's Spatial Panners group. The browser lists the individual panner controllers; this page summarizes shared panner workflow patterns.

## Panners

The panner controllers are companion interfaces for JSFX. Insert or load the JSFX on a track, then use the matching controller from the package browser or Action List for a larger spatial interface.

General workflow:

1. Put mono sources on an 8-channel track or bus where the panner expects up to 8 input sources.
2. Load the matching `s3g` panner JSFX.
3. Open the controller.
4. Use the visual panel, source controls, and automation controls from the controller rather than the raw JSFX fader list.

The `Layout Panner` is the general option for quad, rings, cube, double-ring, and 24-channel dome layouts. Use it when you want a common speaker arrangement without committing to one SRST-specific array.

`Layout Panner` and `25ch LBAP Dome Panner` include distance-aware controls.
`Distance rolloff` controls level as a source moves beyond the array edge.
`Distance diffusion` broadens the panning focus as distance increases, so an
outside-the-array gesture can become both quieter and less point-like. Leave
`Energy preserve` enabled in the LBAP panner when you want the earlier
equal-power behavior.

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

## Spatial Score

Spatial Score is a browser-based motion designer for banked 8-source 3OA encoder
groups. Use the browser tool to build and preview motion scenes, export JSON,
then run `Load Spatial Score JSON` in REAPER. The loader creates a 3OA encoder bus with
child tracks and writes source automation for `s3g 8ch 3OA Object Encoder`.

After loading a JSON file, `Spatial Score Browser Link` can reopen the same browser
score and follow REAPER transport. This gives a larger visual monitor for
automation that has already been written to the timeline.

## Spatial Automation Composer

`Spatial Automation Composer` writes motion as editable automation rather than
recording controller movement in realtime. Select a track with a supported s3g
AED or XYZ panner, choose a time range, preview the motion, then write the
automation lanes.

- `Path method` chooses the movement model, including orbit, arc, spiral,
  Lissajous, Brownian, graph walk, hole field, attractor, boundary trace, and
  scatter holds.
- `Source relationship` controls how up to 8 source paths relate: selected
  source, unison, phase offset, canon, counter-rotation, or scatter.
- `Continuity`, `Tear / jump chance`, graph controls, and hole/boundary
  controls shape how smooth, broken, constrained, or repelled the path becomes.
- The preview panel has camera controls, a timeline slider, play/stop preview,
  and a highlighted moving point. Nothing is written until `Write automation`.
