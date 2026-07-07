---
layout: default
title: s3g-mc
next_page:
  title: Installation
  url: /installation.html
toc:
  - title: Start Here
    href: "#start-here"
  - title: Highlights
    href: "#highlights"
  - title: License
    href: "#license"
---

# s3g-mc

s3g-mc is a collection of REAPER tools for multichannel composition, spatial audio, offline sound transformation, and procedural synthesis.

It includes Lua actions, ReaImGui controllers, and JSFX for channel editing, automation, fold-down monitoring, dome panning, 3OA send/return routing, and render-based multichannel processes.

Current package snapshot: the browser exposes 120 user-facing tools/controllers, plus the Package Browser. Of those, 50 are Python/NumPy-backed offline processes, 25 load, control, or render included JSFX, and 45 are native Lua/ReaImGui REAPER actions. The repository also ships 23 underlying JSFX engine/effect files. The Lua folder includes helper libraries and support dialogs that are not shown as Package Browser entries.

The package also includes browser-based companion utilities for spatial motion,
automation lanes, image scores, IR room sketches, and 3OAFX displacement maps.
They live inside `Scripts/s3g-mc/utilities` and can be launched from the
Package Browser or opened from the docs. Automation Score, Displacement Score,
and Spatial Score also include Max bridge examples for playing exported JSON in
Max patches.

Many of these tools are inspired by or extend existing computer music practices, with references mentioned in the documentation where they are useful.

## Start Here

- [Installation](installation.md)
- [Dependencies](dependencies.md)
- [Processes](tools.md)
- [Workflows](workflows.md)
- [Process Guides](process-guides.md)
- [Gallery](gallery.md)
- [Utilities](utilities.md)
- [References](references.md)

## Highlights

- Common-layout panning plus 12ch, 17ch, and 25ch panners for RISD SRST arrays
- 3OAFX ambisonic send/return workflow for 24-channel effect inserts
- Track-level automation mixer for up to 128 channels, with plugin pin control
- Ambisonic stereo fold-down based on virtual speaker fields and stereo pickup models
- Stereo-to-ambisonic source expansion for building 3OAFX beds from mono or stereo material
- Multi-source ambisonic scene navigation with editable node maps and listener paths
- Node-based multichannel track mixing with routing overview, cursor automation, and tunable blend curves
- Browser-based utility scores for spatial motion, generic automation lanes, image-to-sound scoring, IR room sketches, and 3OAFX displacement maps, with Max bridge examples for selected JSON workflows
- Stereo loudspeaker transaural crosstalk cancellation with matrix-inverse approximation
- Multichannel workflow helpers for item transforms, track routing, and stems
- MIDI rule generators for drum states, musical-space paths, learned forms, and polymetric lanes
- Offline spectral, convolution, and resynthesis processes
- Multichannel texture and montage actions
- Procedural synth engines with offline render and MIDI-controller workflows

## License

Zero-Clause BSD. See the package
<a href="https://github.com/s3g/s3g-mc?tab=License-1-ov-file" target="_blank" rel="noopener noreferrer">LICENSE</a>.

Attribution is appreciated for software development, publications, research,
teaching materials, and projects that build on or adapt this package. See
<a href="https://github.com/s3g/s3g-mc/blob/main/CITATION.cff" target="_blank" rel="noopener noreferrer">CITATION.cff</a>.

Development assistance: OpenAI Codex.
