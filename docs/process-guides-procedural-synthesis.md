---
layout: default
title: Procedural Synthesis Guides
guide_nav: true
prev_page:
  title: MIDI Composition Guides
  url: /process-guides-midi.html
next_page:
  title: Offline Synthesis / IR Guides
  url: /process-guides-offline-synthesis-ir.html
toc:
  - title: Carto Synth MIDI Controller
    href: "#carto-synth-midi-controller"
  - title: Carto Synth Render
    href: "#carto-synth-render"
  - title: Lattice Synth MIDI Controller
    href: "#lattice-synth-midi-controller"
  - title: Lattice Synth Render
    href: "#lattice-synth-render"
  - title: Spectra Synth MIDI Controller
    href: "#spectra-synth-midi-controller"
  - title: Spectra Synth Render
    href: "#spectra-synth-render"
  - title: s3g Fault CLAP
    href: "#s3g-fault-clap"
---

# Procedural Synthesis Guides

These guides match the Package Browser's Procedural Synthesis group. They
cover the included JSFX synth engines as offline render tools and
MIDI-controlled realtime instruments. The final section points to a related
realtime instrument from the sibling `s3g-dsp` CLAP collection.

## Carto Synth MIDI Controller

Use this when you want to drive Carto from MIDI items on the timeline. The
controller loads the JSFX engine on the selected track and exposes the MIDI
response layer: pitch mode, velocity-to-density, velocity-to-rate,
velocity-to-gain, note gate depth, and MIDI-channel focus.

Starting approach:

- Put the controller on the selected track, or let it load the JSFX engine.
- Create a MIDI item on the same track.
- Enable `MIDI control`.
- Use `Pitch sets frequency` for note-like behavior, or `Gate only` when the
  synth should keep its base frequency.
- Use MIDI channels when `Focus by MIDI channel` is active.

The offline render action remains separate. Use `Carto Synth Render` when you
want breakpoint-controlled file output instead of realtime playback.

## Carto Synth Render

Use this when you want a rendered multichannel synthetic source rather than a
processed input file. Carto is a JSFX synth driven offline by the Lua renderer,
so it creates a new media item instead of requiring realtime playback.

Starting approach:

1. Choose duration and channel count.
2. Choose one algorithm.
3. Leave normalize on.
4. Shape amplitude and density with breakpoint envelopes.
5. Render a short test before making a long version.

Algorithms have different spatial behavior. Dust-like modes behave as
stochastic clouds. Pulse and packet modes show their event structure with lower
density and sharper envelopes. Byte-mask materials change quickly as density
increases, so sparse density and amplitude shaping give more separation. Spline
and drift-like materials respond well to slower breakpoint motion.

Use the detailed breakpoint editor when the render feels too static. A good
starting set is amplitude, density, brightness, and one spatial control.
Randomize one lane at a time until the behavior is legible.

## Lattice Synth MIDI Controller

Use this with MIDI items that contain table, path, or channel-focused material.
The controller loads the Lattice Synth JSFX engine on the selected track and
exposes its table, gesture, resonator, and MIDI response controls.

Starting approach:

- Run `Lattice Tables` or another MIDI generator on the same track.
- Keep `MIDI control` on.
- Use `Pitch sets frequency` for note-like plucked behavior, or `Gate only`
  when the table and base frequency should define the pitch field.
- Set `Template`, `Ingress`, `Egress`, and `Gesture position` to shape the
  table scan.
- Use `Resonance`, `Damping`, and `Brightness` first; then add `Divider
  shadow` or `Feedback drive`.
- Use MIDI channels when `Focus by MIDI channel` is active.

The synth uses resonant delay lines rather than a sampled sound source. MIDI
notes excite the lattice; velocity changes excitation strength, and MIDI
channel can steer source focus across the multichannel output. The visible
table in the controller is a control map for the sound engine.

## Lattice Synth Render

Use this when the Lattice idea should produce a rendered multichannel media
item rather than a live MIDI-driven instrument. The script generates a
temporary MIDI score from the table, ingress/egress, and rhythm settings, feeds
that score into the Lattice Synth engine, then renders the result.

Starting approach:

- Choose duration and output channel count.
- Set `Gesture template`, `Ingress`, and `Egress` first.
- Use `Rhythm` to decide how the table path becomes note events.
- Use `Pitch sets frequency` for clear note response, or `Gate only` for a
  table-defined pitch field.
- Keep peak normalize on for first tests.

This renderer is closer to the MIDI composition scripts than to Carto/Spectra
render. The sound is produced by the JSFX resonator engine, but the offline
action first creates a score layer: pitch, velocity, duration, and MIDI-channel
focus are derived from the lattice path.

## Spectra Synth MIDI Controller

Use this when you want the Spectra engine to behave as a realtime multichannel
instrument. The controller loads the JSFX engine on the selected track and
exposes the same MIDI response layer as Carto.

Starting approach:

- Enable `MIDI control`.
- Use lower density and moderate decay for note-driven articulation.
- Use velocity-to-gain first, then add velocity-to-density or velocity-to-rate.
- Use MIDI-channel focus when different MIDI channels should pull energy toward
  different output-channel regions.

The MIDI controller is for realtime/timeline use. Use `Spectra Synth Render`
for offline breakpoint composition and rendered media items.

## Spectra Synth Render

Use this for synthetic material based on spectral masses, resonators, impulse
responses, and partial-like behavior. It is also rendered offline through the
included JSFX synth engine.

Starting approach:

- Keep peak normalize on.
- Start with moderate density and brightness.
- Use amplitude and spectral-shape breakpoint lanes before adding wide spatial
  motion.
- Some modes develop over the whole duration, so check more than the opening
  moment of a render.

Impulse and resonator modes can become clicky if the event layer is too sharp.
Increase event smoothing or use slower envelopes when that happens.
Spectral-mass modes often reveal more internal motion when density changes over
time rather than staying fixed.

## s3g Fault CLAP

[`s3g Fault`](https://s3g.github.io/s3g-dsp/fault.html) is a zero-input,
eight-output procedural instrument distributed with `s3g-dsp`. It generates a
structured byte field internally, reads any file from byte zero as unsigned
8-bit PCM, or decodes a PCM WAV's data chunk into eight requantized waveform
lanes. It turns sample points into stochastic curves, passes them through
reduced-rate PCM, delta, ADPCM, companding, or damaged codebook models, and
then applies resonant wavefolding. It is not installed by the `s3g-mc` ReaPack
package.

Starting approach:

- Set the REAPER track to eight channels before inserting the CLAP.
- Choose `SLOW FOLD`, `CODEC SCAR`, or `DELTA STAIRS` as a starting point.
- Use `OPEN ANY` with its WAVE option enabled for eight waveform-derived lanes,
  or disable the option to hear every source byte including the header.
- Begin with `WAVE TRACE` when source contour should remain apparent, or use
  `GEN FIELD` to return to internally generated material.
- Lower the displayed codec update rate and raise `FOLD` when the source should
  resolve into slower vector-like curves.
- Use `ROUTE` and `SPREAD` to separate the eight outputs before following the
  instrument with other multichannel processors.
- Use `MUTATE` for a nearby variation, `RANDOM PATCH` for a larger departure,
  and `UNDO` to compare the result with the preceding state.

Unlike Carto, Lattice, and Spectra, Fault runs continuously in the CLAP host
and does not create a rendered media item. REAPER automation can still capture
or sequence its named controls as part of an `s3g-mc` project workflow.
