# s3g-mc

REAPER scripts and JSFX for multichannel editing, channel automation,
fold-down monitoring, and spatial workflows.

## Tools

### Channel Mixing / Automation

- `128ch Automation Mixer`: track-aware faders, mute/solo, channel
  groups, meters, and plugin pin remapping.
- `MC to Stereo Autogain`: multichannel-to-stereo fold-down with layout modes,
  width, rotation, layout weighting, autogain, and output gain.

### Spatial / HOA

- `25ch LBAP Dome Panner`: panning for up to 8 mono source channels across the
  25-speaker dome layout of the RISD SRST Spatial Audio Studio.
- `3OA Send/Return FX Controller`: places a 24-channel insert lane inside an
  ambisonic decode/encode chain.

### Item Channel Transforms

- `Explode multichannel item to mono tracks`
- `Extract item channel to mono track`
- `Mirror item channel order`
- `Rotate item channels`
- `Reorder item channels`
- `Resize item channel count`
- `Odd-even item channel order`
- `Interleave item channel pairs`
- `Deinterleave item channel pairs`
- `Swap item channel halves`

### Multichannel Texture / Montage

Native REAPER variations inspired by the
[CDP multichannel processes](https://www.composersdesktop.com/docs/html/cgromc.htm).
These scripts do not require CDP.

- `Frame shift multichannel item`: channel-frame rotation, mirror,
  odd/even split, pair interleave, or half-swap render.
- `Shred / slice multichannel item`: equal or project-marker slices with
  ordered mono spread, random mono scatter, and multichannel reorientation
  modes.
- `Fracture mono to multichannel space`: time-ordered slices from one source
  channel dispersed across a controlled channel path with jitter, drop, and
  spread voices.
- `Spatial repeater multichannel item`: repeated prints of one source channel
  around clockwise, ping-pong, or random channel paths.
- `Zigzag channel walker`: equal slices walk back and forth across output
  channels, with optional reverse source-slice order.
- `Cascade spatial echo`: equal source segments print decaying echoes that step
  through multichannel space.
- `Crumble spatial groups`: slices are projected through progressively smaller
  channel groups.
- `Texture clouds multichannel item`: dense short fragments from one source
  channel scattered across an output field.
- `Spatial stutter multichannel item`: repeated short slices advance through a
  spatial path.
- `Channel orbit delay`: whole-item delay repeats orbit through output channels.
- `Frame gate multichannel item`: rotating active channel groups print a
  multichannel gate pattern.
- `Marker spatial montage`: project markers inside the selected item define
  chunks for ordered or shuffled montage.
- `Channel smear multichannel item`: slices duplicate to neighboring channels
  with gain compensation.

### Track Building / Routing

- `Build multichannel stem from selected tracks`
- `Cycle mono tracks into multichannel stem`: selected mono tracks become a
  multichannel stem, with repeat or grouped
  downmix behavior when the requested output count differs from the source
  count.

## Dependencies

- [REAPER](https://www.reaper.fm/)
- [ReaImGui](https://codeberg.org/cfillion/reaimgui) for the package browser
  and controller scripts. ReaImGui is distributed through ReaPack's default
  ReaTeam Extensions repository.
- [SWS Extension](https://sws-extension.org/) is recommended for render-based
  workflows. Source is available at
  [reaper-oss/sws](https://github.com/reaper-oss/sws).
- [SPARTA plugins](https://leomccormack.github.io/sparta-site/), specifically
  AmbiDEC and AmbiENC, are recommended for the 3OA workflow. Source and
  releases are available at
  [leomccormack/SPARTA](https://github.com/leomccormack/SPARTA).

## Install

Copy or symlink the package folders into your REAPER resource path:

```text
Scripts/s3g-mc -> REAPER/Scripts/s3g-mc
Effects/s3g    -> REAPER/Effects/s3g
```

Then in REAPER:

1. Open `Actions > Show action list...`.
2. Click `New Action > Load ReaScript...`.
3. Choose `REAPER/Scripts/s3g-mc/s3g-mc Package Browser.lua`.
4. Run `s3g-mc Package Browser`.
5. Click `Install/refresh actions` in the browser to register the package
   scripts.

If new JSFX do not appear in the FX browser, rescan JSFX or restart REAPER.

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

`MMD` is recommended for AmbiDEC because this workflow decodes to a custom
irregular 24-point virtual speaker cloud before re-encoding, rather than to a
standard symmetric speaker preset.

After adding or moving the 24-channel insert effect, use the package controller's
`Pin inserts 1-24` button so the insert processes only the wet/effect lane and
does not touch the dry copy or return mask lanes.

More detail is in `Scripts/s3g-mc/s3g_3oa_fx_workflow.md`.

## License

MIT License. See `LICENSE`.

Development assistance: OpenAI Codex.
