# Automation Score Max Bridge

This optional Max bridge reads exported Automation Score JSON files and plays the
stored breakpoint lanes back at control rate. It is intended as a general
translation layer for Max patches, OSC systems, MIDI control, hardware control,
or other non-REAPER targets.

Open `Automation Score Player.maxpat`, drop an Automation Score JSON export onto
the patch, then start playback. The V8 script outputs one message per enabled
lane on each tick. The default mode is OSC-style token output:

```text
/automation/lane lane-index normalized-value
```

Outlet map:

```text
1 lane/value data
2 playback clock
3 metadata, duration, section count, score JSON, view clock
4 marker hits only
5 status text
```

Output modes:

```text
mode osc
/automation/lane lane-index normalized-value

mode value
value lane-index normalized-value

mode cc
cc lane-index 0-to-127

mode generic
lane lane-index name lane-name value normalized-value enabled 1
```

`mode osc` is useful when the player feeds an OSC-style routing system or when
each automation lane should be parsed by address while playback is running.
The address is a single Max symbol followed by payload atoms, so it can be
routed with plain `route` objects.

`mode value` is a compact Max-native output for patching by lane number. It
omits the lane name and enabled state.

`mode cc` scales each normalized lane value to an integer `0..127`, which is
useful when the score is driving MIDI-style controller data.

`mode generic` is the most descriptive Max-native output. It includes the lane
number, lane name, normalized value, and enabled state in one message.

The patch also reports playback position, duration metadata, and section marker
changes. In the default OSC-style mode, marker hits use this shape when the
cursor enters a marker section:

```text
/automation/marker marker-index marker-name time-seconds bang
```

In the other output modes, marker hits use this shape:

```text
section section-index section-name time-seconds
```

The patch includes a passive `v8ui` monitor that displays the loaded score. Use
`view lanes` for stacked lane rows or `view overlap` for a shared overlay view.
The white cursor follows playback, and amber vertical lines show score section
markers.

Loop modes:

- `playbackmode loop`: wrap from the end back to the beginning.
- `playbackmode palindrome`: play forward, then backward, reversing at each end.
- `playbackmode once`: play to the end and stop.

In palindrome mode the reported playback duration is doubled: a 24 second
Automation Score export becomes a 48 second forward/backward cycle.

The bridge reads the exported `lanes` and `sections` arrays from Automation
Score JSON. It does not regenerate or reinterpret the score; it plays the stored
breakpoint data with the same linear, smooth, or step interpolation settings
used by the browser utility.
