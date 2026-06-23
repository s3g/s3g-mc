# s3g 3OA FX Workflow

This workflow processes a 24-channel third-order ambisonic speaker feed inside a
72-channel REAPER track. The extra channels carry a protected dry copy and a
return mask so one inserted effect can be moved, shaped, and mixed without
destroying the original signal.

## Required Files

JSFX install to:

`REAPER/Effects/s3g`

Core effects:

- `s3g 3OA Send`
- `s3g 3OA Return Mask`
- `s3g 3OA Mixer`

Controller:

- `3OA Send Return FX Controller.lua`

## Basic Chain

On one REAPER track, use this order:

1. SPARTA AmbiDEC
2. `JS: s3g 3OA Send`
3. One 24-channel effect insert
4. `JS: s3g 3OA Return Mask`
5. `JS: s3g 3OA Mixer`
6. SPARTA AmbiENC

The track must be set to 72 channels.

Recommended SPARTA settings:

- Ambisonic order: `3rd order`
- Channel ordering: `ACN`
- Normalization: `SN3D`
- AmbiDEC decoder mode: `MMD` / multi-mode decoder
- Number of virtual speaker/source points: `24`

Load the included JSON layouts from `sparta_json/`:

- AmbiDEC: `s3g_3oa_24_virtual_speakers_ambidec_loudspeaker_layout.json`
- AmbiENC: `s3g_3oa_24_virtual_speakers_ambienc_source_layout.json`

`MMD` is recommended for AmbiDEC because this workflow decodes to a custom
irregular 24-point virtual speaker cloud before re-encoding, rather than to a
standard symmetric speaker preset.

## Channel Layout

The 72-channel bus is divided into three 24-channel lanes:

- `1-24`: wet/effect lane
- `25-48`: clean dry copy
- `49-72`: return mask for mixer ducking and monitoring

`s3g 3OA Send` reads the original 24 channels, writes the effect send to `1-24`,
and writes a clean dry copy to `25-48`.

The inserted effect should process only `1-24`.

`s3g 3OA Return Mask` reads the effected audio from `1-24`, passes the dry copy
through `25-48`, and writes the return mask to `49-72`.

`s3g 3OA Mixer` reads wet from `1-24`, dry from `25-48`, and the return mask from
`49-72`.

`s3g 3OA Return Mask` has two return-routing modes:

- `Gate`: keeps each wet channel in its original channel and gates it with the
return mask. Send and return positions need overlap for this to be obvious.
- `Re-place`: sums the effected send and redistributes it through the return
mask. This is the mode to use when the send is on one source position and the
effect should appear at a different return position.

The ImGui map draws the return mask as green intensity around the speaker dots.
When `s3g 3OA Return Mask` is running, this is read live from the JSFX meter. If no
fresh meter data is available, the map falls back to a predicted mask calculated
from the Return/Mask direction, width, focus, floor, and rear-reject controls.

## Controller Workflow

1. Select the 3OA FX track.
2. Run `3OA Send Return FX Controller.lua`.
3. Click `Load/repair JSFX` to add or repair the core chain.
4. Add the desired 24-channel insert effect between `s3g 3OA Send` and `s3g 3OA Return Mask`.
5. Click `Pin inserts 1-24`.

`Pin inserts 1-24` is required after adding or moving insert effects. It forces
every effect between `s3g 3OA Send` and `s3g 3OA Return Mask` to use only channels
`1-24`, leaving the dry copy on `25-48` untouched.

`Load/repair JSFX` also runs the pin repair, but only for insert effects already
between Send and Return when the button is clicked.

`Lock send and return az/el` links the send and return positions.

`Lock mask shape` links send and return width, focus, and rear reject. Beam
floor, level, gamma, smoothing, and energy compensation remain independent so
the send/return shape can match while the return mask still has its own mixing
feel.

For a simple test, unlock send/return azimuth, put `Send` on a source, put
`Return` somewhere else, and enable `Re-place wet through return mask`. The
effect should be fed by the send position and heard from the return position.

## Mixing Behavior

In `s3g 3OA Mixer`:

- `Wet trim` controls the returned effect level.
- `Dry trim` controls the protected dry copy.
- In insert-duck mode, the return mask ducks the dry signal where the returned
effect is active.
- With `Wet trim` at `0`, the dry path should remain dry and unducked.

Recommended starting defaults:

- `Wet trim`: `1.00`
- `Dry trim`: `0.65`
- `Output trim`: `0.90`
- `Mask ceiling`: `0.92`
- `Duck curve`: `0.00`

If dry still sounds effected, click `Pin inserts 1-24` and verify the insert
effect is physically between `s3g 3OA Send` and `s3g 3OA Return Mask`.

## Insert Effects

This public package does not include a dedicated 3OA insert effect. Use a
third-party or custom effect that can process the 24-channel wet lane on
channels `1-24`. After adding or moving the insert, click `Pin inserts 1-24` in
the controller so the insert does not process the protected dry copy or return
mask lanes.

## Troubleshooting

If the `s3g` JSFX do not appear, confirm that this package's `Effects/s3g`
folder was copied or symlinked to `REAPER/Effects/s3g`, then rescan JSFX or
restart REAPER.

If the 3OA chain does not pass audio, confirm that the track is set to 72
channels and that the plugin order is AmbiDEC, Send, insert effect, Return Mask,
Mixer, AmbiENC.

If spatial positions seem wrong, confirm that AmbiDEC is set to MMD, that both
SPARTA plugins use ACN/SN3D 3rd-order ambisonics, and that both included
24-point JSON layouts are loaded.

If the controller map says `Predicted mask peak` instead of `Live mask peak`,
make sure `JS: s3g 3OA Return Mask` is present in the chain and enabled.

If an insert effect processes the dry path, click `Pin inserts 1-24`. REAPER may
auto-wire a newly inserted FX too broadly on a 72-channel track.
