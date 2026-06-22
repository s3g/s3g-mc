# s3g-mc

REAPER scripts and JSFX for multichannel editing, channel automation, fold-down
monitoring, and spatial workflows.

## Included Tools

### Channel Mixing / Automation

- `128ch Automation Mixer.lua` controls `s3g MC Channel Automation Mixer 128`
  with track-aware faders, mute/solo, groups, meters, and plugin pin remapping.
- `MC to Stereo Autogain.lua` controls `s3g MC to Stereo Autogain` for
  multichannel-to-stereo fold-down with layout modes, width, rotation, layout
  weighting, autogain, and output gain.

### Spatial / HOA

- `25ch LBAP Dome Panner.lua` controls `s3g 25ch LBAP Dome Panner`, panning up
  to 8 mono source channels across a fixed 25-channel dome.
- `3OA Send Return FX Controller.lua` controls the `s3g 3OA Send`, `s3g 3OA
  Return Mask`, and `s3g 3OA Mixer` JSFX chain for a 24-channel 3OA insert lane.

The 3OA workflow requires an ambisonic decoder before `s3g 3OA Send` and an
ambisonic encoder after `s3g 3OA Mixer`. Recommended plugins are SPARTA AmbiDEC
and SPARTA AmbiENC. Load the included 24-point JSON layouts from
`Scripts/s3g-mc/sparta_json/` into those plugins.

### Item Channel Transforms

- `Explode multichannel item to mono tracks.lua`
- `Mirror item channel order.lua`
- `Rotate item channels.lua`
- `Reorder item channels.lua`
- `Shred item across multichannel ring.lua`

### Track Building / Routing

- `Build multichannel stem from selected tracks.lua`
- `Cycle mono tracks into multichannel stem.lua`

## Dependencies

- REAPER
- ReaImGui for the package browser and controller scripts
- SWS Extension is recommended for render-based workflows
- SPARTA AmbiDEC and AmbiENC are recommended for the 3OA workflow

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

## Development Layout

This repository mirrors the REAPER resource folders:

```text
s3g-mc/
  Scripts/s3g-mc/
  Effects/s3g/
```

For active development, keep this repository as the source of truth and symlink
the REAPER resource folders back to it. That keeps REAPER and GitHub using the
same files.

Development assistance: OpenAI Codex.
