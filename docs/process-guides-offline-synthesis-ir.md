---
layout: default
title: Offline Synthesis / IR Guides
guide_nav: true
prev_page:
  title: Procedural Synthesis Guides
  url: /process-guides-procedural-synthesis.html
next_page:
  title: Spatial Panners Guides
  url: /process-guides-spatial-panners.html
toc:
  - title: Dense Grain Cloud
    href: "#dense-grain-cloud"
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

# Offline Synthesis / IR Guides

These guides match the Package Browser's Offline Synthesis / IR group. They cover NumPy-backed synthesis, resynthesis, grain-cloud, and impulse-oriented tools.

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
