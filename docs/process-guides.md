---
layout: default
title: Process Guides
guide_nav: true
prev_page:
  title: Workflows
  url: /workflows.html
next_page:
  title: Channel Mixing / Automation Guides
  url: /process-guides-channel-mixing.html
toc:
  - title: General Pattern
    href: "#general-pattern"
  - title: Breakpoint Envelopes
    href: "#breakpoint-envelopes"
  - title: Category Guides
    href: "#category-guides"
---

# Process Guides

These pages provide practical notes for selected processes. The guide categories follow the Package Browser and [Processes](tools.md) page.

Many processes use custom ImGui interfaces with diagrams, tables, breakpoint
lanes, or spatial views. These visuals are meant to show how the process is
mapping time, channels, pitch, space, or source material, so they can be read as
part of the control surface while setting up a render.

## General Pattern

Most render actions follow the same workflow:

1. Select one or more media items or tracks.
2. Run the action from the `s3g-mc Package Browser` or REAPER Action List.
3. Choose render settings in the ImGui window.
4. Click `Render`.
5. Listen to the newly created item or track before deleting the source.

Render actions generally create a new media item rather than destructively editing the source. Actions that render from selected media try to limit the render to the selected item, selected-track media range, or requested duration.

For NumPy-backed processes, use WAV-backed media. Convert compressed formats to WAV first; the offline analysis and render scripts expect WAV sources.

## Breakpoint Envelopes

Several offline processes include compact breakpoint lanes plus a `Detailed Breakpoint Editor`. The compact lanes show the active time-shape for each mapped parameter. The detailed editor lets you choose a lane, activate it, add or delete points, apply preset shapes, and randomize points.

Useful habits:

- Draw `Amplitude` or `Density` first, then adjust timbre or spatial controls.
- Use many points for animated materials, but start with a readable shape when learning a process.
- `Random selected` changes one chosen lane; `Random all` changes every active lane.
- If an envelope is not active, the current slider value is used instead.

## Category Guides

- [Channel Mixing / Automation](process-guides-channel-mixing.md)
- [MIDI Composition](process-guides-midi.md)
- [Procedural Synthesis](process-guides-procedural-synthesis.md)
- [Offline Synthesis / IR](process-guides-offline-synthesis-ir.md)
- [Spatial Panners](process-guides-spatial-panners.md)
- [3OAFX](process-guides-3oafx.md)
- [Spectral / Convolution](process-guides-spectral.md)
- [Multichannel Texture / Montage](process-guides-texture-montage.md)
- [Item Channel Transforms](process-guides-item-transforms.md)
- [Track Building / Routing](process-guides-track-routing.md)
