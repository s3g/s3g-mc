---
layout: default
title: Automation Score
utility_nav: true
prev_page:
  title: Utilities
  url: /utilities.html
next_page:
  title: Image Score
  url: /utilities-image-score-generator.html
toc:
  - title: Overview
    href: "#overview"
  - title: Export
    href: "#export"
  - title: Loading In REAPER
    href: "#loading-in-reaper"
---

# Automation Score

[Open Automation Score](utilities/automation-score-designer/){:target="_blank" rel="noopener noreferrer" .utility-link}

## Overview

Automation Score is a browser-based editor for generic breakpoint
lanes. It is useful when several automation curves need to be composed together
before being assigned to REAPER tracks or effect parameters.

The lane names are intentionally generic. The JSON stores normalized `0..1`
values, so the same field can later target track volume, an FX parameter range,
or another mapping added in a future loader.

## Export

Use the breakpoint canvas to add, move, and shape lanes. The generator panel can
fill one lane or all lanes with ramps, waves, gates, random walks, mirrored
pairs, and staggered shapes. Export writes a JSON file containing both the
editable breakpoints and sampled points at the chosen point rate.

## Loading In REAPER

Run `Load Automation Score JSON` with one or more destination tracks selected.
The loader opens an ImGui assignment window where each score lane can be mapped
to a selected track's volume envelope, to an FX parameter envelope, or skipped.

For track volume, lane values are mapped through a dB range before REAPER
envelope points are written. The default range is `-48 dB` to `0 dB`, which
usually gives a visible and audible envelope shape.

For FX parameters, lane values are mapped through a normalized parameter range.
The assignment table lists FX and parameter names from the selected track.

The loader includes automatic assignment buttons for volume across selected
tracks and sequential FX parameters, but the per-lane table can be edited before
writing.
