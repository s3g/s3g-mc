---
layout: default
title: Ray Sketch
description: Design musical moving-source ray fields for s3g Ambi Ray Encoder.
utility_nav: true
prev_page:
  title: Imprint Sketch
  url: /utilities-imprint-sketch.html
next_page:
  title: Spatial Score
  url: /utilities-spatial-score.html
toc:
  - title: Open Tool
    href: "#ray-sketch"
  - title: Navigation
    href: "#navigation"
  - title: Analysis Views
    href: "#analysis-views"
  - title: Export
    href: "#export"
---

# Ray Sketch

[Open Ray Sketch](utilities/ray-sketch-designer/){:target="_blank" rel="noopener noreferrer" .utility-link}

Ray Sketch adapts the Imprint Sketch space engine for a positioned source. It retains architectural, cave, cavern, tunnel, canyon, clearing, abstract, connected-region, portal, material, echo-path, and glTF design tools.

## Navigation

The `NAV` view places top and side projections together. Drag the source in the top view for X/Y movement and in the side view for X/Z movement. Solid paths run from source through an amber wall, floor, ceiling, portal, or echo point to the listener. Dashed inward arrows remain listener-relative arrivals when a procedural event has no honest bounce point. The navigation grid samples valid positions in connected volumes and stores a compact set of stable reflection slots at every cell.

## Analysis Views

`FIELD MAP` plots every valid export cell over the room and highlights the same nearest-four inverse-distance blend used by Ambi Ray Encoder. Its elevation rail separates grid layers and keeps the current source and listener heights visible.

`CELL MATRIX` separates the source grid into one X/Y matrix per Z layer. Missing squares lie outside the connected room volume; numbered squares are the four cells currently feeding interpolation. Selecting a valid square moves the source to that exact export cell.

`RAY TIMELINE` is one response at the current source position, grouped by cause rather than by bounce order: direct sound, first-order boundaries, portals and chambers, structured echo paths, procedural scatter arrivals, and the late field. The three views are different readings of the same ray field, not independent response banks.

## Export

`Export Ray Field` writes [`.s3gray`](https://s3g.github.io/s3g-dsp/s3gray-format.html) for `s3g Ambi Ray Encoder`. The plugin follows direct sound continuously, morphs globally stable reflection slots between nearby cells, and drives a directional late field. The model is intended for repeatable musical space design rather than architectural prediction.

Ray Sketch also imports editable Imprint Sketch and legacy IR Sketch project JSON, so an existing designed space can become a Ray Field without rebuilding its geometry.
