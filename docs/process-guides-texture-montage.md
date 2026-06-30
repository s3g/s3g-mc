---
layout: default
title: Multichannel Texture / Montage Guides
guide_nav: true
prev_page:
  title: Spectral / Convolution Guides
  url: /process-guides-spectral.html
next_page:
  title: Item Channel Transforms Guides
  url: /process-guides-item-transforms.html
toc:
  - title: Scatter Slices
    href: "#scatter-slices"
  - title: Loop Drift
    href: "#loop-drift"
  - title: Loop Rift
    href: "#loop-rift"
  - title: Texture / Montage Utilities
    href: "#texture--montage-utilities"
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

For denser renders, use more slices and moderate gain. For more open renders, reduce density and increase minimum spacing or use a thinner density envelope. If the source has defined attacks, marker or transient-like manual slicing preserves those boundaries more directly than very small even slices.



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

Use moderate rate spread and a longer crossfade while setting the loop behavior. Increase drift after the loop seam is smooth.



## Loop Rift

Use this when you want Loop Drift behavior with openings, dropouts, and partial loop sections rather than continuous beds.

It preserves source identity more than a glitch process: sections appear as parts of the loop entering and leaving, rather than tiny click-like fragments.

Important controls:

- `Section density` decides how many loop openings are admitted.
- `Section length ms` controls how much of the loop appears at once.
- `Minimum section ms` protects against tiny click-like fragments.
- `Fade / duck ms` smooths section edges.
- `Gap fill` changes how silence and openings behave.

If the result feels too choppy, increase minimum section length and fade time, then reduce rate instability.



## Texture / Montage Utilities

These actions create multichannel arrangements from selected items without opening a large editor. Most of them write a new media item and leave the source item in place. Use WAV-backed media when possible, especially when the action renders a new file.

Slice and fragment tools:

- `Fracture`: cuts the selected material into fragments and distributes them across the target channel layout.
- `Frame Gate`: admits short time frames according to a gate pattern.
- `Frame Shift`: offsets frames between channels to create staggered time relationships.
- `Marker spatial montage`: uses project markers or take markers as montage boundaries.
- `Shred / Slice`: slices the source and rearranges slices across channels and time.

Repeat, echo, and motion tools:

- `Cascade spatial echo`: sends repeated material through a channel cascade.
- `Channel orbit delay`: delays repeated material around the channel layout.
- `Spatial Repeater`: repeats selected material with channel movement and spacing controls.
- `Spatial Stutter`: repeats short segments across channel positions.
- `Stereo Spin`: rotates stereo material through a multichannel bed.
- `Zigzag channel walker`: moves events back and forth across the channel order.

Channel-density and grouping tools:

- `Brownian Walk`: moves short fragments through channels using a bounded random walk.
- `Channel Smear`: spreads source material across neighboring channels.
- `Crumble spatial groups`: breaks material into grouped channel events.
- `Flutter Gate`: switches active channel groups over time.
- `Mono Fill`: spreads a mono source into the selected channel count.
- `Texture Clouds`: creates overlapping channel events from selected material.

Common settings:

- `Output channels` sets the rendered channel count.
- Segment or frame length controls determine the size of each event.
- Density, probability, or gate controls decide how many events are admitted.
- Fade controls shape event edges.
- Gain or normalize controls set the rendered level.

When a process uses markers, project markers and active-take markers can be used as boundaries where supported. Take markers travel with the media item; project markers stay fixed on the project timeline.
