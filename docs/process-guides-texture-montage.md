---
layout: default
title: Multichannel Texture / Montage Guides
guide_nav: true
prev_page:
  title: Spectral / Convolution Guides
  url: /process-guides-spectral.html
next_page:
  title: Track Building / Routing Guides
  url: /process-guides-track-routing.html
toc:
  - title: Scatter Slices
    href: "#scatter-slices"
  - title: Loop Drift
    href: "#loop-drift"
  - title: Loop Rift
    href: "#loop-rift"
---

# Multichannel Texture / Montage Guides

These guides match the Package Browser's Multichannel Texture / Montage group. They cover slice, loop, and montage-oriented processes that build multichannel structures over time.

## Scatter Slices

Use this when you want selected media items sliced and rearranged across a target multichannel duration.

Selection:

- Select one or more media items.
- The items can be on different tracks.
- Slice sources can be even divisions, project markers, or active-take markers.

Core decisions:

- Duration sets the target length of the new render.
- Output channels sets the multichannel bed.
- Slice mode decides where the source segments come from.
- Arrangement shape controls how events are distributed through time.
- Density envelope controls where events are admitted over the render.

For dense results, use more slices and moderate gain. For sparse results, reduce density and increase minimum spacing or use a thinner density envelope. If the source has obvious attacks, marker or transient-like manual slicing usually reads more clearly than very small even slices.



## Loop Drift

Use this for seamless loops distributed into a multichannel bed where each channel or group drifts away from the others through rate, phase, and source-pool variation.

Selection:

- Select one or more WAV-backed media items.
- A mono source can be spread to many output channels.
- Multiple selected items can be folded into the source pool.

Important controls:

- `Loop crossfade ms` controls overlap-add smoothing at loop seams.
- `Base rate` is the main playback speed.
- `Rate spread/deviation` separates channels or groups from each other.
- `Rate quantize` can make rate relationships more stable or more stepped.
- `Source mode` and `Source distribution` decide how multiple selected items are assigned.

Start with moderate rate spread and a generous crossfade. Increase drift after the loop seam feels stable.



## Loop Rift

Use this when you want Loop Drift behavior with openings, dropouts, and partial loop sections rather than continuous beds.

It is designed to preserve source identity more than a glitch process: sections should feel like parts of the loop appearing and disappearing, not accidental clicks.

Important controls:

- `Section density` decides how many loop openings are admitted.
- `Section length ms` controls how much of the loop appears at once.
- `Minimum section ms` protects against tiny click-like fragments.
- `Fade / duck ms` smooths section edges.
- `Gap fill` changes how silence and openings behave.

If the result feels too choppy, increase minimum section length and fade time, then reduce rate instability.
