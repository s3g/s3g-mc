---
layout: default
title: Workflows
---

# Workflows

## 3OA / SPARTA Setup

The 3OA workflow uses a 72-channel REAPER track:

- `1-24`: wet/effect lane
- `25-48`: protected dry copy
- `49-72`: return mask lane

Use this plugin order:

1. SPARTA AmbiDEC
2. `JS: s3g 3OA Send`
3. one 24-channel insert effect
4. `JS: s3g 3OA Return Mask`
5. `JS: s3g 3OA Mixer`
6. SPARTA AmbiENC

Recommended SPARTA settings:

- Ambisonic order: `3rd order`
- Channel ordering: `ACN`
- Normalization: `SN3D`
- AmbiDEC decoder mode: `MMD` / multi-mode decoder
- Number of virtual speaker/source points: `24`

Load the included JSON layouts:

- In SPARTA AmbiDEC, load
  `Scripts/s3g-mc/sparta_json/s3g_3oa_24_virtual_speakers_ambidec_loudspeaker_layout.json`
  as the 24-point loudspeaker layout.
- In SPARTA AmbiENC, load
  `Scripts/s3g-mc/sparta_json/s3g_3oa_24_virtual_speakers_ambienc_source_layout.json`
  as the matching 24-point source layout.

`MMD` is recommended for AmbiDEC here because the workflow decodes to a custom
irregular 24-point virtual speaker cloud before re-encoding.

After adding or moving the 24-channel insert, use the controller's `Pin inserts
1-24` button so the effect only touches the wet/effect lane.

## Package Browser

The package browser is the easiest way to run the tools and install or refresh
the individual REAPER actions. It groups scripts by use: channel mixing,
spatial/HOA, spectral/convolution, offline synthesis, item transforms,
multichannel montage, and track routing.
