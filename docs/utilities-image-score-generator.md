---
layout: default
title: Image Score Generator
utility_nav: true
prev_page:
  title: Utilities
  url: /utilities.html
next_page:
  title: IR Room Sketch Designer
  url: /utilities-ir-room-sketch-designer.html
toc:
  - title: Open Tool
    href: "#open-tool"
  - title: Purpose
    href: "#purpose"
  - title: Score Format
    href: "#score-format"
  - title: Image Reading
    href: "#image-reading"
  - title: Export
    href: "#export"
---

# Image Score Generator

## Open Tool

[Open Image Score Generator](tools/image-score-generator/){:target="_blank" rel="noopener noreferrer" .utility-link}

## Purpose

The Image Score Generator prepares PNG scores for `3OAFX Image Sonogram Field`.
It is useful when the image is part of the composition rather than only a file
chosen at render time.

The tool provides drawing controls, procedural generators, layer previews,
color-to-AED controls, alpha and mask editing, and a playhead preview that shows
how columns are read over time.

## Score Format

`3OAFX Image Sonogram Field` expects a maximum working image size of `512 x
256`. Wider or taller images are resampled by the REAPER render process. When
composing image scores directly, use `512 x 256` so the score resolution is
predictable.

X is time. Y is frequency. Color can determine AED placement, while amplitude
can come from alpha, edge contrast, local contrast, ridge/blob detection,
center emphasis, temporal activity, or a separate image.

## Image Reading

The canvas overlay shows the time/frequency scan direction. The transpose
control swaps horizontal and vertical reading, and the preview updates to match
the selected orientation.

The AED view shows how the current playhead column maps into ambisonic space.
Use the color model menu to match the color interpretation used in the REAPER
render process.

## Export

Use `Export RGBA score PNG` for the most direct workflow. In REAPER, load that
image and choose `Alpha` as the amplitude source when the alpha channel should
control level.

Use a separate mask image when the score's color layer should be independent
from amplitude. In that case, load the color score as the main image and choose
`Separate image` as the amplitude source in `3OAFX Image Sonogram Field`.
