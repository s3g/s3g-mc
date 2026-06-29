---
layout: default
title: Process Guides
prev_page:
  title: Workflows
  url: /workflows.html
next_page:
  title: MIDI Guides
  url: /process-guides-midi.html
toc:
  - title: General Pattern
    href: "#general-pattern"
  - title: Breakpoint Envelopes
    href: "#breakpoint-envelopes"
  - title: Guide Pages
    href: "#guide-pages"
---

# Process Guides

These notes describe how to approach selected s3g-mc processes in practice. They are intentionally more direct than the tool list: what to select, what the action creates, and which settings are worth touching first.

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



## Guide Pages

- [MIDI Guides](process-guides-midi.md): MIDI rule generation, musical-space paths, and polymetric lanes.
- [Synthesis Guides](process-guides-synthesis.md): procedural synths, resynthesis, grain clouds, loop tools, and impulse fields.
- [Spectral and Convolution Guides](process-guides-spectral.md): convolution, spectral shaping, and multichannel spectral profile tools.
- [3OAFX Guides](process-guides-3oafx.md): ambisonic offline rendering, ambisonic convolution, spatial grains, and 3OAFX spectral tools.
- [Spatial and Channel Guides](process-guides-spatial-channel.md): panners, fold-down, transaural playback, automation mixer, and track/item helpers.
