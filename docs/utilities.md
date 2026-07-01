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
source/listener geometry, early-reflection timing, direction sets, estimated
decay, and the stacked channel count used by `3OAFX Synthetic Ambisonic IR
Bank`.

Exported JSON is intended as a portable sketch of the room and direction-bank
settings for later use in the REAPER workflow.
