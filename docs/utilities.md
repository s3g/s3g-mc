---
layout: default
title: Utilities
prev_page:
  title: Gallery
  url: /gallery.html
next_page:
  title: References
  url: /references.html
toc:
  - title: Image Score Generator
    href: "#image-score-generator"
  - title: IR Room Sketch Designer
    href: "#ir-room-sketch-designer"
---

# Utilities

Small companion tools for preparing material used by the REAPER package.

## Image Score Generator

[Open Image Score Generator](tools/image-score-generator/){:target="_blank" rel="noopener noreferrer" .utility-link}

The Image Score Generator is a browser-based editor for composing `512 x 256`
PNG scores for `3OAFX Image Sonogram Field`. It provides drawing tools,
procedural score generators, color-to-AED controls, alpha/mask editing,
amplitude-mask previews, and PNG exports.

Use the exported RGBA score with the `Alpha` amplitude source, or export a
color PNG plus a separate mask PNG when using `Separate image` as the amplitude
source.

## IR Room Sketch Designer

[Open IR Room Sketch Designer](tools/ir-room-sketch-designer/){:target="_blank" rel="noopener noreferrer" .utility-link}

The IR Room Sketch Designer is a browser-based sketch tool for planning
synthetic ambisonic impulse-response banks. It previews room dimensions,
source/listener geometry, early-reflection timing, direction groups, estimated
decay, and the stacked channel ranges used by `3OAFX Synthetic Ambisonic IR
Bank`. Use the bank controls to step through each IR group and check its AED
position, source position, and channel block before rendering. The `Bank
Matrix` view summarizes direct arrival, first reflection, and relative early
energy for each group, while the path-layer toggles let the room views separate
direct sound, early reflections, and late-field behavior. The `Reflection
Layers` view expands that timing sketch into the main canvas and shows all IR
groups at once. In the Top and Side views, click a group source to select it
and drag the selected source to edit the shared source distance used by the
generated bank. Field offset controls move the source/listener field through
the floorplan, and the 3D view provides camera azimuth, elevation, and zoom
controls for inspecting the room sketch. Group variation controls add
deterministic differences in local absorption, scattering, source distance,
spread, and tail behavior, so the bank can sketch a less uniform acoustic
space. The room-shape controls can sketch the main room as a rectangle,
trapezoid, wedge, skewed polygon, diamond/lens, or folded shape. They can also
add multiple movable chambers on the front, back, left, right, or all sides of
the room, with optional nested chamber chains. Chambers can use different
material profiles and polygonal or folded shapes, creating later chamber-return
reflections that appear as a separate layer in the plan and reflection views.
When the main room is not rectangular, chamber openings snap to the selected
polygon edge so the chamber shares an actual boundary with the room. The
`Strangeness / topology bias` slider steers generated sketches from simpler
rooms toward folded shapes, all-side chambers, nested chambers, stronger field
offsets, and more varied chamber coupling.
In the Top view, dragging empty map space moves the source/listener field
through the full floorplan, including chamber areas. The `Bank Map` view places
each IR group directly in the same floorplan; drag group points inside the room
or chamber geometry to define where each impulse response is gathered.

Exported JSON is intended as a portable sketch of the room and direction-bank
settings for later use in the REAPER workflow. The glTF export writes a simple
3D model of the main room, chambers, field center, and IR group positions for
viewing or archiving the room shape alongside rendered impulse responses.
