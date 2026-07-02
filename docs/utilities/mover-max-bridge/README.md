# Spatial Score Max Bridge

This optional Max bridge reads exported Spatial Score JSON files and plays the stored
automation points back at control rate. It is intended as a translation layer
for ICST AmbiMonitor or other Max-based ambisonic monitoring workflows.

Open `Mover AmbiMonitor Bridge.maxpat`, drop a Spatial Score JSON export onto the
patch, then start playback. The V8 script outputs one message per source:

```text
source global-index group group-index source source-index azimuth deg elevation deg distance value gain value
```

For ICST AmbiMonitor, send `mode icst` to output the point format:

```text
aed index azimuth elevation distance
```

Disabled or muted Spatial Score sources are skipped in ICST mode.

When a JSON file loads, the patch reports the file duration in the visible
`total seconds` number box. This value comes from the Spatial Score JSON `duration`
field. Current Spatial Score exports set that duration from the full A-H motion scene
cycle: each stored hold time plus each stored morph time through the scene set.

Loop modes:

- `playbackmode once`: play to the end and stop.
- `playbackmode loop`: wrap from the end back to the beginning.
- `playbackmode palindrome`: play forward, then backward, reversing at each end.

In palindrome mode the reported playback duration is doubled: a 24 second
Spatial Score export becomes a 48 second forward/backward cycle.

The bridge reads the exported `automation` arrays from Spatial Score JSON rather than
recomputing motion rules inside Max. That keeps playback consistent with the
browser preview and REAPER automation export, including spatial constraints and
scene morph smoothing.
