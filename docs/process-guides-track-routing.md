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

- `Route Selected Tracks to Multichannel Bus` gathers selected mono or lower-channel tracks into a new multichannel folder/bus and assigns channel routing in order.
- `Build multichannel stem from selected tracks` creates a rendered multichannel stem from selected tracks.

For routing actions, select only the tracks you want included. If the requested result would exceed REAPER's 128-channel limit, the action should stop rather than build an invalid bus. For render-based helpers, expect a new media item or track and keep the source material until you have checked the result.
