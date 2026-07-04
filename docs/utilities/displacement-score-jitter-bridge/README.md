# Displacement Score Jitter Bridge

This optional Max bridge reads exported Displacement Score JSON files and
streams the current geometry frame into Jitter/OpenGL meshes.

Open `Displacement Score Jitter Player.maxpat`, drop a Displacement Score JSON
export onto the patch, enable the `jit.world` toggle, then start the qmetro and
send `play`. The bridge draws:

- the original 24-point virtual speaker layout as muted cyan points
- the displaced geometry as amber points
- the current displaced polygon as amber line segments
- a separate blue-to-red thermal heatmap matrix in `jit.pwindow`

Use the scrub slider to jump through the exported score timeline. The slider
sends normalized `setnorm` values to the v8 player, so the OpenGL geometry and
heatmap matrix update together.

The heatmap matrix uses the same projected-map energy model as the browser
utility. It follows the Peters-style azimuth/elevation projection used by
`geommode map`, so the flattened point view and heatmap share the same layout.

Useful messages:

```text
read /path/to/displacement-score.json
browserdefault
play
stop
reset
seconds 4.5
setnorm 0.25
speed 0.5
speed 2
playbackmode loop
playbackmode palindrome
playbackmode once
heatres 10
heatrate 4
heatpixel 1
geommode sphere
geommode map
```

When a score is loaded, the player resets to browser-default timing: `speed 1`,
loop playback, and the exported score duration. At that setting, one Max loop
matches one browser preview loop. `qmetro 16` only controls display refresh
cadence; the timeline itself is advanced from elapsed clock time.

`heatres` controls texture detail. `heatrate` controls how many qmetro ticks
pass between heatmap recalculations. Higher `heatrate` values reduce CPU load.
`heatpixel` controls the block size of the flat heatmap raster; higher values
make the matrix more visibly pixelated.

`geommode sphere` draws the OpenGL points on the 3D layout. `geommode map`
flattens the OpenGL point and shell geometry into the same Peters-style
azimuth/elevation layout used by the heatmap matrix. Choosing `geommode map`
also sends a front camera position with a wider zoom so the full map is visible.

Outlet map from `displacement_score_jitter_player_v8.js`:

```text
1 active displaced point matrix
2 source point matrix
3 displaced polygon line matrix
4 heatmap display matrix
5 camera/view messages
6 reserved
7 status, clock, and scene messages
```

The bridge does not regenerate the displacement score. It reads the exported
`timeline.frames` geometry and interpolates between frames for display.
