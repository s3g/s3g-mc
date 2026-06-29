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
  - title: Carto Synth Render
    href: "#carto-synth-render"
  - title: Carto Synth MIDI Controller
    href: "#carto-synth-midi-controller"
  - title: Spectra Synth Render
    href: "#spectra-synth-render"
  - title: Spectra Synth MIDI Controller
    href: "#spectra-synth-midi-controller"
---

# Procedural Synthesis Guides

These guides match the Package Browser's Procedural Synthesis group. They cover the included JSFX synth engines as offline render tools and MIDI-controlled realtime instruments.

## Carto Synth Render

Use this when you want a rendered multichannel synthetic source rather than a processed input file. Carto is a JSFX synth driven offline by the Lua renderer, so it creates a new media item instead of requiring realtime playback.

Starting approach:

1. Choose duration and channel count.
2. Choose one algorithm.
3. Leave normalize on.
4. Shape amplitude and density with breakpoint envelopes.
5. Render a short test before making a long version.

Algorithms have different spatial behavior. Dust-like modes behave as stochastic clouds. Pulse and packet modes show their event structure with lower density and sharper envelopes. Byte-mask materials change quickly as density increases, so sparse density and amplitude shaping give more separation. Spline and drift-like materials respond well to slower breakpoint motion.

Use the detailed breakpoint editor when the render feels too static. A good starting set is amplitude, density, brightness, and one spatial control. Randomize one lane at a time until the behavior is legible.



## Carto Synth MIDI Controller

Use this when you want to drive Carto from MIDI items on the timeline. The controller loads the JSFX engine on the selected track and exposes the MIDI response layer: pitch mode, velocity-to-density, velocity-to-rate, velocity-to-gain, note gate depth, and MIDI-channel focus.

Starting approach:

- Put the controller on the selected track, or let it load the JSFX engine.
- Create a MIDI item on the same track.
- Enable `MIDI control`.
- Use `Pitch sets frequency` for note-like behavior, or `Gate only` when the synth should keep its base frequency.
- Use MIDI channels when `Focus by MIDI channel` is active.

The offline render action remains separate. Use `Carto Synth Render` when you want breakpoint-controlled file output instead of realtime playback.



## Spectra Synth Render

Use this for synthetic material based on spectral masses, resonators, impulse responses, and partial-like behavior. It is also rendered offline through the included JSFX synth engine.

Starting approach:

- Keep peak normalize on.
- Start with moderate density and brightness.
- Use amplitude and spectral-shape breakpoint lanes before adding wide spatial motion.
- Some modes develop over the whole duration, so check more than the opening moment of a render.

Impulse and resonator modes can become clicky if the event layer is too sharp. Increase event smoothing or use slower envelopes when that happens. Spectral-mass modes often reveal more internal motion when density changes over time rather than staying fixed.



## Spectra Synth MIDI Controller

Use this when you want the Spectra engine to behave as a realtime multichannel instrument. The controller loads the JSFX engine on the selected track and exposes the same MIDI response layer as Carto.

Starting approach:

- Enable `MIDI control`.
- Use lower density and moderate decay for note-driven articulation.
- Use velocity-to-gain first, then add velocity-to-density or velocity-to-rate.
- Use MIDI-channel focus when different MIDI channels should pull energy toward different output-channel regions.

The MIDI controller is for realtime/timeline use. Use `Spectra Synth Render` for offline breakpoint composition and rendered media items.

