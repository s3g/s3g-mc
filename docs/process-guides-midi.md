---
layout: default
title: MIDI Guides
prev_page:
  title: Process Guides
  url: /process-guides.html
next_page:
  title: Synthesis Guides
  url: /process-guides-synthesis.html
toc:
  - title: Generate Musical Space MIDI
    href: "#generate-musical-space-midi"
  - title: Generate Polymetric MIDI Lanes
    href: "#generate-polymetric-midi-lanes"
---

# MIDI Guides

These guides cover MIDI item generators that create ordinary editable REAPER MIDI for procedural synths and algorithmic composition.

## Generate Musical Space MIDI

Use this to create a new editable MIDI item from a path through a pitch or harmonic space. It is intended for the procedural synths, but the result is ordinary MIDI and can drive any instrument.

Starting approach:

- Select a track, or let the script use the first track.
- Use a time selection when you want the item to match an exact region.
- Choose a root, scale, and space.
- Use Euclidean `Steps`, `Pulses`, and `Rotate` to define timing.
- Use `Density` and `Path surprise` to decide how continuous or disrupted the path feels.
- Use `Channel mode` to map notes across MIDI channels for Carto/Spectra focus.

The preview shows pitch height over time and labels each generated event with its MIDI channel. `Scale walk` is the most direct mode. `Contour` favors melodic direction changes. `Triadic` makes larger harmonic moves. `Axis mirror` folds alternate moves around a center degree.


## Generate Polymetric MIDI Lanes

Use this to create several simultaneous Euclidean lanes in one MIDI item. Each lane can have its own step count, pulse count, rotation, pitch degree, and MIDI channel.

Starting approach:

- Set `Lanes / MIDI channels` to match the number of procedural synth source lanes you want to excite.
- Set a duration in beats, or use the current edit position as the starting point.
- Adjust each lane's `Steps`, `Pulses`, and `Rotate`.
- Use `Degree` to assign lane pitch within the selected scale.
- Keep lane count at 8 for the Carto/Spectra source-lane model, or raise it for denser MIDI-channel work.

This script is useful for polymetric activity because each lane repeats over the same item duration with a different internal grid. For the procedural synths, MIDI channel number becomes a compositional dimension: it can steer channel focus while note pitch, velocity, and length steer the synth response.

