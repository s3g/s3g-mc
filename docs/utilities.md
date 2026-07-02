---
layout: default
title: Utilities
utility_nav: true
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
  - title: Mover
    href: "#mover"
---

# Utilities

Browser-based companion tools for preparing scores, motion data, and impulse
response sketches used by the REAPER package. These run outside REAPER, then
export material that package scripts can load or render.

## Image Score Generator

[Open Image Score Generator](tools/image-score-generator/){:target="_blank" rel="noopener noreferrer" .utility-link}

[Read Image Score Generator notes](utilities-image-score-generator.md)

Composes `512 x 256` PNG scores for `3OAFX Image Sonogram Field`. Color can
drive AED placement, alpha or mask data can drive amplitude, and the tool
includes drawing, generator, preview, and export controls.

## IR Room Sketch Designer

[Open IR Room Sketch Designer](tools/ir-room-sketch-designer/){:target="_blank" rel="noopener noreferrer" .utility-link}

[Read IR Room Sketch Designer notes](utilities-ir-room-sketch-designer.md)

Sketches synthetic ambisonic impulse-response banks for `3OAFX Synthetic
Ambisonic IR Bank`, including room geometry, chambers, exterior leak openings,
direction groups, reflection timing, material variation, JSON export, and glTF
room export. Load the exported JSON with `Load Room Sketch JSON` inside
`3OAFX Synthetic Ambisonic IR Bank`; the generated IRs can then be used with
`3OAFX Offline Ambisonic Convolve`.

## Mover

[Open Mover](tools/mover/){:target="_blank" rel="noopener noreferrer" .utility-link}

[Read Mover notes](utilities-mover.md)

Designs banked third-order ambisonic source motion in the browser. Exported
JSON can be loaded in REAPER with `Load Mover JSON`, which creates encoder
tracks and writes automation for `s3g 8ch 3OA Object Encoder`. An optional Max
bridge in `tools/mover-max-bridge` can read the same JSON for ICST
AmbiMonitor-style playback and monitoring patches.
