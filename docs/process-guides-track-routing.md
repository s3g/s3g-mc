---
layout: default
title: Track Building / Routing Guides
guide_nav: true
prev_page:
  title: Item Channel Transforms Guides
  url: /process-guides-item-transforms.html
next_page:
  title: Gallery
  url: /gallery.html
toc:
  - title: Track Helpers
    href: "#track-helpers"
---

# Track Building / Routing Guides

These guides match the Package Browser's Track Building / Routing group. They cover project structure, routing, and stem-building actions.

## Track Helpers

These are utility actions for building and routing multichannel projects. They usually do one structural task, so duplicated test tracks are a useful way to confirm the result before working on source material.

Useful starting points:

- `Build multichannel stem from selected tracks` routes selected tracks to
  consecutive channels on a new destination and offers to render the bounded
  source range as a multichannel stem.
- `Cycle mono tracks into multichannel stem` renders selected mono tracks to a
  requested channel count, repeating sources or grouping them with compensated
  gain when the source and output counts differ.
- `Route selected tracks to multichannel folder bus` gathers selected tracks
  into a new parent folder and assigns each child track to a consecutive span
  of bus channels without rendering.

For routing actions, select only the tracks you want included. If the requested result would exceed REAPER's 128-channel limit, the action should stop rather than build an invalid bus. For render-based helpers, expect a new media item or track and keep the source material until you have checked the result.
