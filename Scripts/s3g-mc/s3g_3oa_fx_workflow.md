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

1. `JS: s3g 3OA Send`
2. One 24-channel effect insert
3. `JS: s3g 3OA Return Mask`
4. `JS: s3g 3OA Mixer`

The track must be set to 72 channels.

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

If new JSFX names do not appear, open the FX browser and run a rescan, or restart
REAPER. JSFX pin-count and name changes can remain cached while an old instance
is loaded.

If `s3g 3OA Return Mask` does not show as 72 in / 72 out, remove any old return-mask
instance and add `JS: s3g 3OA Return Mask` again after rescanning.

If the map says `Predicted mask peak` instead of `Live mask peak`, remove and
re-add `JS: s3g 3OA Return Mask` after rescanning. Existing loaded instances can
cache older JSFX code before the live meter was added.

If old generated 3OA/HOA test effects appear in `REAPER/Effects/s3g`, they are
stale local files and should not be treated as part of this public package.

If an insert effect processes the dry path, click `Pin inserts 1-24`. REAPER may
auto-wire a newly inserted FX too broadly on a 72-channel track.

## Development Notes

Do not keep active JSFX copies in the Scripts folder. Edit and test JSFX from
the package `Effects/s3g` folder or the installed `REAPER/Effects/s3g` folder,
depending on whether you are working from a repo symlink or a copied install.

For new 3OA inserts, prefer small, stable JSFX that use smoothing and avoid
abrupt buffer-size or delay-tap changes. Delay/reverb/diffusion effects need
careful design before they are safe for this workflow.
