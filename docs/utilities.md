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
  - title: Automation Score
    href: "#automation-score"
  - title: Image Score
    href: "#image-score"
  - title: IR Sketch
    href: "#ir-sketch"
  - title: Spatial Score
    href: "#spatial-score"
---

# Utilities

Browser-based companion tools for preparing scores, motion data, and impulse
response sketches used by the REAPER package. These run outside REAPER, then
export material that package scripts can load or render.

When the package is installed with `Scripts/s3g-mc/utilities` in place, the Package Browser can launch these tools from REAPER.

## Automation Score

[Open Automation Score](utilities/automation-score-designer/){:target="_blank" rel="noopener noreferrer" .utility-link}

[Read Automation Score notes](utilities-automation-score-designer.md)

Composes generic breakpoint lanes and section markers for REAPER automation.
Export JSON from the browser, then run `Load Automation Score JSON` to write
those lanes to selected track volume envelopes or sequential FX parameter
envelopes, with optional project markers. An optional Max bridge in
`Scripts/s3g-mc/utilities/automation-score-max-bridge` can read the same JSON
for control-rate playback in Max.

## Image Score

[Open Image Score](utilities/image-score-generator/){:target="_blank" rel="noopener noreferrer" .utility-link}

[Read Image Score notes](utilities-image-score-generator.md)

Composes `512 x 256` PNG scores for `3OAFX Image Sonogram Field`. Color can
drive AED placement, alpha or mask data can drive amplitude, and the tool
includes drawing, generator, preview, and export controls.

The same utility can be launched from REAPER with `Image Score`.

## IR Sketch

[Open IR Sketch](utilities/ir-room-sketch-designer/){:target="_blank" rel="noopener noreferrer" .utility-link}

[Read IR Sketch notes](utilities-ir-room-sketch-designer.md)

Sketches synthetic ambisonic impulse-response banks for `3OAFX Synthetic
Ambisonic IR Bank`, including room geometry, chambers, exterior leak openings,
direction groups, reflection timing, material variation, JSON export, and glTF
room export. Load the exported JSON with `Load Room Sketch JSON` inside
`3OAFX Synthetic Ambisonic IR Bank`; the generated IRs can then be used with
`3OAFX Offline Ambisonic Convolve`.

The same utility can be launched from REAPER with `IR Sketch`.

## Spatial Score

[Open Spatial Score](utilities/spatial-score/){:target="_blank" rel="noopener noreferrer" .utility-link}

[Read Spatial Score notes](utilities-spatial-score.md)

Designs banked third-order ambisonic source motion in the browser. Exported
JSON can be loaded in REAPER with `Load Spatial Score JSON`, which creates encoder
tracks and writes automation for `s3g 8ch 3OA Object Encoder`. An optional Max
bridge in `Scripts/s3g-mc/utilities/spatial-score-max-bridge` can read the same JSON
for ICST AmbiMonitor-style playback and monitoring patches.
