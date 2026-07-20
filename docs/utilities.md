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
  - title: Displacement Score
    href: "#displacement-score"
  - title: Image Score
    href: "#image-score"
  - title: Imprint Sketch
    href: "#imprint-sketch"
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

## Displacement Score

[Open Displacement Score](utilities/displacement-score/){:target="_blank" rel="noopener noreferrer" .utility-link}

[Read Displacement Score notes](utilities-displacement-score.md)

Designs 24-point virtual speaker displacement JSON for 3OAFX workflows. The
score is intended for offline renderers that decode to the 24-point direction
layer, apply the displacement, and re-encode to ACN/SN3D. An optional Jitter
bridge in `Scripts/s3g-mc/utilities/displacement-score-jitter-bridge` displays
the exported geometry in Max with OpenGL points, polygon lines, and a separate
heatmap matrix.

The same utility can be launched from REAPER with `Displacement Score`.

## Image Score

[Open Image Score](utilities/image-score-generator/){:target="_blank" rel="noopener noreferrer" .utility-link}

[Read Image Score notes](utilities-image-score-generator.md)

Composes `512 x 256` PNG scores for `3OAFX Image Sonogram Field`. Color can
drive AED placement, alpha or mask data can drive amplitude, and the tool
includes drawing, generator, preview, and export controls.

The same utility can be launched from REAPER with `Image Score`.

## Imprint Sketch

[Open Imprint Sketch](utilities/imprint-sketch-designer/){:target="_blank" rel="noopener noreferrer" .utility-link}

[Read Imprint Sketch notes](utilities-imprint-sketch.md)

Sketches seeded directional responses for rooms, caves, caverns, passages,
open fields, and impossible spaces. Generate and Mutate provide repeatable
variation across geometry, materials, connected regions, reflection timing,
and decay behavior. Project JSON can be re-imported for editing or loaded by
`3OAFX Synthetic Ambisonic IR Bank`. `Export Imprint` writes a `.s3gimprint`
file that loads directly in `s3g Ambi Imprint 64` from the sibling `s3g-dsp`
package.

The same utility can be launched from REAPER with `Imprint Sketch`. The retired
`IR Sketch` action remains as a hidden compatibility launcher.

## Spatial Score

[Open Spatial Score](utilities/spatial-score/){:target="_blank" rel="noopener noreferrer" .utility-link}

[Read Spatial Score notes](utilities-spatial-score.md)

Designs banked third-order ambisonic source motion in the browser. Exported
JSON can be loaded in REAPER with `Load Spatial Score JSON`, either targeting a
focused encoder/effect with AED or XYZ parameters or creating encoder tracks for
`s3g 8ch 3OA Object Encoder`. An optional Max bridge in
`Scripts/s3g-mc/utilities/spatial-score-max-bridge` can read the same JSON for
ICST AmbiMonitor-style playback and monitoring patches.
