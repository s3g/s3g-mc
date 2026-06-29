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
