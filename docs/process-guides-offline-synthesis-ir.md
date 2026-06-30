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
  - title: Fata Morgana Resynth
    href: "#fata-morgana-resynth"
  - title: IR Toolkit
    href: "#ir-toolkit"
  - title: Karplus Field
    href: "#karplus-field"
  - title: Mass Partial Field
    href: "#mass-partial-field"
  - title: Partial Trace Resynth
    href: "#partial-trace-resynth"
  - title: Resonant Terrain
    href: "#resonant-terrain"
  - title: Subharmonic Bank
    href: "#subharmonic-bank"
---

# Offline Synthesis / IR Guides

These guides match the Package Browser's Offline Synthesis / IR group. They cover selected offline synthesis, resynthesis, grain-cloud, and impulse-oriented tools.

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

Use lower grain counts while setting the event shape and spatial spread, then raise the count for denser renders. Use the amplitude envelope for fades instead of relying only on post-render gain.



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

If the output becomes whistle-like, reduce pitch emphasis with fewer traces, lower pitch scale extremes, or stronger texture bias.



## IR Toolkit

Use this to reshape a selected impulse response item before using it in a convolution process. Select one WAV-backed impulse item, then choose the edits to apply to the rendered copy.

Available operations:

- `Trim silence` removes leading or trailing low-level material.
- `Tail fade` applies an end fade over the selected fade length.
- `Normalize` sets the peak level of the processed impulse.
- `Early reflections` adds a sparse reflection pattern before the tail.
- `Decorrelate channels` gives multichannel IR channels slightly different timing and tone.

The output is a new media item, leaving the selected impulse item in place. Use this when an impulse needs a shorter tail, a defined peak level, or channel variation before convolution.



## Karplus Field

Use this to render a multichannel field of plucked resonator events. The process does not require an input item. It creates short excitation impulses, feeds them through Karplus-Strong-style resonators, and distributes the resulting events across the selected channel count.

Main controls:

- `Duration` and `Channels` set the rendered item.
- `Events` and `Density` decide how many plucks are admitted.
- `Pitch`, `Pitch spread`, and `Dispersion` shape the resonator tuning.
- `Damping` and `Brightness` control decay and tone.
- `Spatial width` and motion controls distribute events across the channel bed.

Breakpoint envelopes can change density, pitch region, damping, and amplitude over the render. Use the amplitude envelope to make the field enter, thin out, or fade without changing the post-render item gain.



## Mass Partial Field

Use this for additive fields made from many generated partial events rather than from a single analyzed source. Render time increases with duration, partial count, event count, and channel count.

Initial settings:

- Use a short duration while setting up a sound.
- Keep partial or event counts moderate.
- Leave normalize on.
- Shape amplitude and density with breakpoints before adding wide pitch drift.

This process is organized around mass behavior: many small related events that change density, register, and spatial focus over time. Render time increases with duration, partial count, event count, and channel count. The detailed breakpoint editor can be collapsed while setting other controls.



## Partial Trace Resynth

Use this when you want an input file analyzed into sinusoidal traces and re-rendered as a multichannel oscillator field.

Selection:

- Select one WAV-backed media item.
- Run `Partial Trace Resynth`.

The process tracks peaks in the source spectrum, then resynthesizes selected traces with controllable density, trace behavior, pitch spread, and spatial motion. It is based on sine-wave resynthesis, so clear harmonic or resonant sources tend to reveal the method more directly than noisy sources.

Main controls:

- `Trace mode` changes whether partials remain linked, smear, point, or freeze.
- `Density` admits fewer or more traces before synthesis.
- `Trace count` or equivalent detail controls set how many peaks are followed.
- `Pitch spread` and `jitter` push the result away from literal resynthesis.
- `Protection` or clarity controls reduce buildup in dense renders.

If the output contains static-like edges, reduce density and pitch spread first. If it stays close to the source, increase trace motion or spatial spread.



## Resonant Terrain

Use this for struck resonator banks, metallic fields, synthetic impulse responses, and sustained resonant dust. It sits between an offline synth and an impulse-design process.

Initial settings:

- Use moderate excitation.
- Use fewer resonators while learning the controls.
- Use amplitude and damping envelopes to shape the tail.
- Normalize to avoid unexpectedly quiet first renders.

Spread, detune, and channel motion determine how far the resonator bank moves away from a centered response. Excitation brightness and damping shape the upper-frequency edge before final gain is applied.



## Subharmonic Bank

Use this to render a multichannel bank of divided oscillator voices. The process starts from one or more root tones, creates subharmonic divisions, and shapes them with masks, drift, fold, and pulse/sine balance.

Main controls:

- `Duration` and `Channels` set the rendered item.
- `Root` and `Division range` define the subharmonic material.
- `Mask` controls decide when divided voices are allowed through.
- `Instability` and `Drift` vary tuning and articulation over time.
- `Pulse / sine blend` changes the edge of the oscillator bank.
- `Spatial spread` distributes voices across the channel bed.

Breakpoint envelopes can change activity, amplitude, register, and spatial behavior over the render. Sparse mask settings create separated articulations; dense mask settings create more continuous divided-tone layers.
