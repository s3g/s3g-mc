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

These pages provide practical notes for selected tools. The guide categories follow the Package Browser and [Tools](tools.md) page.

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

- [Channel Mixing / Automation](process-guides-channel-mixing.md): automation mixer, fold-down, transaural playback, and monitor decoders.
- [MIDI Composition](process-guides-midi.md): MIDI rule generation, musical-space paths, and polymetric lanes.
- [Procedural Synthesis](process-guides-procedural-synthesis.md): Carto, Lattice, and Spectra synth workflows.
- [Offline Synthesis / IR](process-guides-offline-synthesis-ir.md): offline synth, resynthesis, grain-cloud, and impulse tools.
- [Spatial Panners](process-guides-spatial-panners.md): panner workflows and spatial layout controls.
- [3OAFX](process-guides-3oafx.md): ambisonic offline rendering, ambisonic convolution, spatial grains, and 3OAFX spectral tools.
- [Spectral / Convolution](process-guides-spectral.md): non-ambisonic convolution, spectral shaping, and spectral profile tools.
- [Multichannel Texture / Montage](process-guides-texture-montage.md): slice, loop, and montage-oriented multichannel processes.
- [Track Building / Routing](process-guides-track-routing.md): project structure, routing, stems, and item helper actions.
