---
layout: default
title: Spectral / Convolution Guides
guide_nav: true
prev_page:
  title: 3OAFX Guides
  url: /process-guides-3oafx.html
next_page:
  title: Multichannel Texture / Montage Guides
  url: /process-guides-texture-montage.html
toc:
  - title: Convolve Selected Items
    href: "#convolve-selected-items"
  - title: Render MC Impulse Field
    href: "#render-mc-impulse-field"
  - title: Spectral Shaper
    href: "#spectral-shaper"
  - title: Multichannel Spectral Profile Tools
    href: "#multichannel-spectral-profile-tools"
  - title: Spectral Transform Tools
    href: "#spectral-transform-tools"
---

# Spectral / Convolution Guides

These guides match the Package Browser's Spectral / Convolution group for non-ambisonic spectral and convolution tools. For ambisonic variants, use the 3OAFX guide page.

## Convolve Selected Items

Use this when you want one selected item to be convolved with another item used as an impulse response.

Selection:

1. Select the source item first.
2. Select the impulse item second.
3. Run `Convolve selected items`.

`Matched / wrap impulse` is for mono, stereo, or same-channel source/impulse pairs. Matrix-sum behavior combines multichannel source and impulse material into one summed channel layout rather than creating every source/impulse channel pair.

Initial settings:

- Tail: `Full convolution tail`
- Normalize: on
- Normalize peak: around `-6 dB`

If the result is silent or unexpectedly long, check that both selected items are readable audio files and that the impulse has audible content. If the waveform takes a moment to appear, REAPER may still be building peaks for the rendered file.

## Render MC Impulse Field

Use this to generate multichannel impulse material for convolution, reverb
design, or spatial excitation. It does not need an input item.

Core decisions:

- Duration sets the impulse-response length.
- Channel count sets the output bed.
- Distribution controls decide where impulses happen in time and channels.
- Minimum spacing keeps impulses from collapsing into dense clicks.
- Profile controls change impulse shape, decay, and brightness.

For convolution use, short durations produce a compact spatial response.
Longer durations emphasize tail behavior, echo fields, or unstable room-like
motion.



## Spectral Shaper

Use this for two-file spectral envelope transfer. The first selected item keeps timing and phase; the second item supplies the spectral envelope or formant shape.

Selection:

1. Select the carrier item first. This is the rhythm, phrase, or tune source.
2. Select the shaper item second. This supplies the spectral color.
3. Run `Spectral Shaper`.

In use, one sound keeps the contour of its performance while another sound changes what that performance seems to be made from.

The standard spectral envelope mode transfers the shaper's spectrum frame by frame. The formant-vocode algorithm gives broader vocal-like or resonant contour transfer instead of dense frame-by-frame spectral matching.

Initial settings:

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



## Spectral Transform Tools

These tools render new media items from one or two selected WAV-backed sources. They work directly on the selected channel layout and do not decode to an ambisonic direction layer.

Single-source transforms:

- `Chaotic Resonant EQ`: passes the selected item through a multichannel resonant filter field with feedback, detuning, drive, wet/dry mix, and peak normalization.
- `Spectral Accumulate`: sustains spectral bands until stronger energy appears, with decay, floor, and expansion controls.
- `Spectral Blur`: smooths spectral magnitudes across time while retaining the source timing.
- `Spectral Freeze`: imposes one spectral frame over the item while retaining the source timing.
- `Spectral Spatializer`: distributes frequency bins across even output channel counts from `2` to `64`.
- `Spectral Step Drunk Freeze`: holds frames at regular steps or follows a random-walk frame path.
- `Spectral Trace`: keeps, suppresses, thresholds, or thins detected spectral material.

Two-source transforms:

- `Cross Synthesis`: keeps the phase and timing of the first selected item while blending its spectral magnitudes toward the second selected item.
- `Spectral Morph`: moves between the spectra of the first and second selected items, either frame-by-frame or through frozen frames.

Main controls across the group:

- Window and hop settings change the time/frequency detail of the analysis.
- Amount, mix, or depth controls set how strongly the transform is applied.
- Floor or protection controls leave a minimum amount of source material in place.
- Expansion or duration controls can render a longer item when the process includes time stretching.

For `Spectral Spatializer`, choose the output channel count before rendering. Lower channel counts create broader frequency regions per channel. Higher channel counts divide the spectrum into more locations.
