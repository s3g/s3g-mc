# Automation Score Max Bridge

This optional Max bridge reads exported Automation Score JSON files and plays the
stored breakpoint lanes back at control rate. It is intended as a general
translation layer for Max patches, OSC systems, MIDI control, hardware control,
or other non-REAPER targets.

Open `Automation Score Player.maxpat`, drop an Automation Score JSON export onto
the patch, then start playback. The V8 script outputs one message per enabled
lane on each tick:

```text
lane lane-index name lane-name value normalized-value enabled 1
```

Other output modes:

```text
mode value
value lane-index normalized-value

mode cc
cc lane-index 0-to-127
```

The patch also reports playback position, duration metadata, and section marker
changes. Section messages use this shape:

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
