---
layout: default
title: Item Channel Transforms Guides
guide_nav: true
prev_page:
  title: Multichannel Texture / Montage Guides
  url: /process-guides-texture-montage.html
next_page:
  title: Track Building / Routing Guides
  url: /process-guides-track-routing.html
toc:
  - title: Item Channel Utilities
    href: "#item-channel-utilities"
---

# Item Channel Transforms Guides

These guides match the Package Browser's Item Channel Transforms group. They
cover utilities that change the channel structure or channel order of selected
media items.

## Item Channel Utilities

Use these actions when the media item already contains the material you want,
but the channel layout needs to be extracted, resized, paired, rotated, or
reordered.

Useful starting points:

- `Deinterleave item channel pairs` separates interleaved channel pairs.
- `Explode multichannel item to mono tracks` creates one mono track per item
  channel.
- `Extract item channel to mono track` isolates one channel from a multichannel
  item.
- `Interleave item channel pairs` rebuilds paired channel ordering.
- `Mirror item channel order`, `Odd-even item channel order`, `Rotate item
  channels`, and `Swap item channel halves` change channel order without
  changing the underlying sound.
- `Reorder item channels` is the general-purpose channel-ordering tool.
- `Resize item channel count` repeats or downmixes channels to reach a target
  count.

These tools are structural. Duplicate important source items before trying a new
channel operation, then keep the transformed result only after the channel order
is confirmed.
