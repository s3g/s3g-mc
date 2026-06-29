---
layout: default
title: Synthesis Guides
prev_page:
  title: MIDI Guides
  url: /process-guides-midi.html
next_page:
  title: Spectral and Convolution Guides
  url: /process-guides-spectral.html
toc:
  - title: Scatter Slices
    href: "#scatter-slices"
  - title: Loop Drift
    href: "#loop-drift"
  - title: Loop Rift
    href: "#loop-rift"
  - title: Dense Grain Cloud
    href: "#dense-grain-cloud"
  - title: Carto Synth Render
    href: "#carto-synth-render"
  - title: Carto Synth MIDI Controller
    href: "#carto-synth-midi-controller"
  - title: Spectra Synth Render
    href: "#spectra-synth-render"
  - title: Spectra Synth MIDI Controller
    href: "#spectra-synth-midi-controller"
  - title: Partial Trace Resynth
    href: "#partial-trace-resynth"
  - title: Fata Morgana Resynth
    href: "#fata-morgana-resynth"
  - title: Mass Partial Field
    href: "#mass-partial-field"
  - title: Resonant Terrain
    href: "#resonant-terrain"
  - title: Render MC Impulse Field
    href: "#render-mc-impulse-field"
---

# Synthesis Guides

These guides cover rendered synthesis, resynthesis, grains, loop-based processes, and the realtime MIDI controllers for the procedural JSFX engines.

## Scatter Slices

Use this when you want selected media items sliced and rearranged across a target multichannel duration.

Selection:

- Select one or more media items.
- The items can be on different tracks.
- Slice sources can be even divisions, project markers, or active-take markers.

Core decisions:

- Duration sets the target length of the new render.
- Output channels sets the multichannel bed.
- Slice mode decides where the source segments come from.
- Arrangement shape controls how events are distributed through time.
- Density envelope controls where events are admitted over the render.

For dense results, use more slices and moderate gain. For sparse results, reduce density and increase minimum spacing or use a thinner density envelope. If the source has obvious attacks, marker or transient-like manual slicing usually reads more clearly than very small even slices.


## Loop Drift

Use this for seamless loops distributed into a multichannel bed where each channel or group drifts away from the others through rate, phase, and source-pool variation.

Selection:

- Select one or more WAV-backed media items.
- A mono source can be spread to many output channels.
- Multiple selected items can be folded into the source pool.

Important controls:

- `Loop crossfade ms` controls overlap-add smoothing at loop seams.
- `Base rate` is the main playback speed.
- `Rate spread/deviation` separates channels or groups from each other.
- `Rate quantize` can make rate relationships more stable or more stepped.
- `Source mode` and `Source distribution` decide how multiple selected items are assigned.

Start with moderate rate spread and a generous crossfade. Increase drift after the loop seam feels stable.


## Loop Rift

Use this when you want Loop Drift behavior with openings, dropouts, and partial loop sections rather than continuous beds.

It is designed to preserve source identity more than a glitch process: sections should feel like parts of the loop appearing and disappearing, not accidental clicks.

Important controls:

- `Section density` decides how many loop openings are admitted.
- `Section length ms` controls how much of the loop appears at once.
- `Minimum section ms` protects against tiny click-like fragments.
- `Fade / duck ms` smooths section edges.
- `Gap fill` changes how silence and openings behave.

If the result feels too choppy, increase minimum section length and fade time, then reduce rate instability.


## Dense Grain Cloud

Use this for source-based grain clouds rendered directly to a multichannel item.

Selection:

- Select one WAV-backed media item.
- Run `Dense Grain Cloud`.

Important controls:

- `Grains` sets the event count.
- `Density` admits more or fewer grains.
- `Grain ms` controls average grain duration.
- `Length variation` makes the cloud less uniform.
- `Pitch scatter oct` moves grains away from the source pitch.
- `Spatial spread` and `Channel contrast` control how strongly grains separate across channels.

Start with fewer grains and moderate density, then raise grain count after the spatial behavior is clear. Use the amplitude envelope for fades instead of relying only on post-render gain.


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


## Partial Trace Resynth

Use this when you want an input file analyzed into sinusoidal traces and re-rendered as a multichannel oscillator field.

Selection:

- Select one WAV-backed media item.
- Run `Partial Trace Resynth`.

The process tracks peaks in the source spectrum, then resynthesizes selected traces with controllable density, trace behavior, pitch spread, and spatial motion. It is based on sine-wave resynthesis, so clear harmonic or resonant sources tend to reveal the method more directly than noisy sources.

Useful controls:

- `Trace mode` changes whether partials remain linked, smear, point, or freeze.
- `Density` admits fewer or more traces before synthesis.
- `Trace count` or equivalent detail controls set how many peaks are followed.
- `Pitch spread` and `jitter` push the result away from literal resynthesis.
- `Protection` or clarity controls reduce buildup in dense renders.

If the output sounds staticy, reduce density and pitch spread first. If it stays close to the source, increase trace motion or spatial spread.


## Fata Morgana Resynth

Use this for hybrid resynthesis from multiple input files. It analyzes selected items and recombines their timing, pitch, amplitude, and spatial traits into a new oscillator-field render.

Selection:

- Select 2-16 WAV-backed media items.
- Use sources with clearly different traits if you want the recombination to be obvious.

Important controls:

- `Hybrid mode` decides how sources are recombined.
- `Trace behavior` changes how partials are followed or redistributed.
- `Traces per frame` controls how much analysis detail is admitted.
- `Trait mutation` increases cross-source instability.
- `Texture bias` pushes the result toward denser or more textural behavior.
- `Clarity protect` helps avoid muddy low-frequency or overfull renders.

If the output becomes whistly, reduce pitch emphasis with fewer traces, lower pitch scale extremes, or stronger texture bias.


## Mass Partial Field

Use this for additive fields made from many generated partial events rather than from a single analyzed source. Render time increases with duration, partial count, event count, and channel count.

Starting settings:

- Use a short duration while setting up a sound.
- Keep partial or event counts moderate.
- Leave normalize on.
- Shape amplitude and density with breakpoints before adding wide pitch drift.

This process is designed around mass behavior: many small related events that change density, register, and spatial focus over time. If REAPER feels slow while the window is open, collapse the detailed breakpoint editor or render a shorter test.


## Resonant Terrain

Use this for struck resonator banks, metallic fields, synthetic impulse responses, and sustained resonant dust. It sits between an offline synth and an impulse-design process.

Starting settings:

- Start with moderate excitation.
- Use fewer resonators while learning the controls.
- Use amplitude and damping envelopes to shape the tail.
- Normalize to avoid unexpectedly quiet first renders.

Increase spread, detune, and channel motion after the basic resonant shape works. If the result becomes harsh, reduce excitation brightness or increase damping before lowering the overall gain.


## Render MC Impulse Field

Use this to generate multichannel impulse material for convolution, reverb design, or spatial excitation. It does not need an input item.

Core decisions:

- Duration sets the impulse-response length.
- Channel count sets the output bed.
- Distribution controls decide where impulses happen in time and channels.
- Minimum spacing keeps impulses from collapsing into dense clicks.
- Profile controls change impulse shape, decay, and brightness.

For convolution use, start shorter than you think. A sparse one- or two-second impulse field can already create a strong spatial response. Use longer durations when you want tail behavior, echo fields, or unstable room-like motion.

