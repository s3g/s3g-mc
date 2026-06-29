---
layout: default
title: Spectral and Convolution Guides
prev_page:
  title: Synthesis Guides
  url: /process-guides-synthesis.html
next_page:
  title: 3OAFX Guides
  url: /process-guides-3oafx.html
toc:
  - title: Convolve Selected Items
    href: "#convolve-selected-items"
  - title: Spectral Shaper
    href: "#spectral-shaper"
  - title: Multichannel Spectral Profile Tools
    href: "#multichannel-spectral-profile-tools"
---

# Spectral and Convolution Guides

These guides cover non-ambisonic spectral and convolution tools. For ambisonic/3OAFX variants, use the 3OAFX guide page.

## Convolve Selected Items

Use this when you want one selected item to be convolved with another item used as an impulse response.

Selection:

1. Select the source item first.
2. Select the impulse item second.
3. Run `Convolve selected items`.

Start with `Matched / wrap impulse` for mono, stereo, or same-channel experiments. Use matrix-sum behavior when you want multichannel source and impulse material to combine into one summed channel layout rather than creating every source/impulse channel pair.

Starting settings:

- Tail: `Full convolution tail`
- Normalize: on
- Normalize peak: around `-6 dB`

If the result is silent or unexpectedly long, check that both selected items are readable audio files and that the impulse has audible content. If the waveform takes a moment to appear, REAPER may still be building peaks for the rendered file.


## Spectral Shaper

Use this for two-file spectral envelope transfer. The first selected item keeps timing and phase; the second item supplies the spectral envelope or formant shape.

Selection:

1. Select the carrier item first. This is the rhythm, phrase, or tune source.
2. Select the shaper item second. This supplies the spectral color.
3. Run `Spectral Shaper`.

The classic way to think about it: one sound keeps the contour of its performance while another sound changes what that performance seems to be made from.

Try the standard spectral envelope mode first. Use the formant-vocode algorithm when you want broader vocal-like or resonant contour transfer instead of dense frame-by-frame spectral matching.

Starting settings:

- Amount: moderate rather than maximum
- Contrast: increase after the source relationship is working
- Normalize: on


## Multichannel Spectral Profile Tools

These are the non-ambisonic counterparts to the 3OAFX profile tools. Select a
WAV-backed source item first, then a WAV-backed profile item. The output keeps
the source channel count and does not decode or re-encode HOA.

Use the variants for different intentions:

- `Spectral Profile Subtract`: reduces material in the source that matches the
  profile.
- `Spectral Residue Extractor`: writes the removed material as a separate item.
- `Spectral Hole Maker`: carves profile-shaped spectral space in the source.
- `Spectral Ambiance Extractor`: extracts material that resembles room tone,
  noise bed, or ambiance profile.

The `Channel mode` setting controls how the profile channels are assigned:

- `Matched channels`: source channel 1 uses profile channel 1, and so on.
- `Wrap profile channels`: profile channels repeat across the source channels.
- `Summed profile to all`: the profile is analyzed as one composite spectrum and
  applied to every source channel.

