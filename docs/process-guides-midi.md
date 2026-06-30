---
layout: default
title: MIDI Composition Guides
guide_nav: true
prev_page:
  title: Channel Mixing / Automation Guides
  url: /process-guides-channel-mixing.html
next_page:
  title: Procedural Synthesis Guides
  url: /process-guides-procedural-synthesis.html
toc:
  - title: Lattice Drums
    href: "#lattice-drums"
  - title: Lattice Tables
    href: "#lattice-tables"
  - title: Musical Space
    href: "#musical-space"
  - title: Form Learner
    href: "#form-learner"
  - title: Terrain Form
    href: "#terrain-form"
  - title: Polymetric Drum States
    href: "#polymetric-drum-states"
  - title: Polymetric Pitch Lanes
    href: "#polymetric-pitch-lanes"
---

# MIDI Composition Guides

These guides match the Package Browser's MIDI Composition group. The scripts create ordinary editable REAPER MIDI items for procedural synths and algorithmic composition.

The shared scale menu includes chromatic, modal, pentatonic, blues,
whole-tone, diminished, augmented, synthetic, bebop, and several regional or
historical pitch collections. The generated notes remain ordinary MIDI, so
scales can be treated as starting materials rather than fixed harmonic rules.

## Polymetric Drum States

Use this to create an editable drum MIDI item from changing polymeter states. Each state stores Euclidean lane settings for drum tokens such as `KIK`, `SNR`, `CHH`, and `OHH`; the script can jump between states or glide between them before writing MIDI notes.

Starting approach:

- Choose `Superior-style` or `GM` as the drum note map.
- Set `Lanes` to the number of drum voices you want to generate.
- Use `Timeline preview` or `Play Preview` to move through the state sequence.
- Use `Project BPM` and `Preview speed` to check the visual rhythm against the REAPER tempo or slow it down for inspection.
- Choose `Jump` for hard changes between polymeter configurations, or `Glide` for interpolated transitions.
- Use `Add State` and `Delete State` to change the number of configurations.
- Leave `Snap beat sliders` on when you want state lengths, trigger lengths, and spacing guards to land on a beat division. Choose the division with `Grid`.
- Leave `Integer state lengths` on for whole-beat state blocks, or turn it off when you want fractional state lengths.
- Set `Selected state length beats`, or type directly into `Beats`, to place each state over the generated item's timeline.
- Select a state, then edit each lane's `Steps`, `Pulses`, `Rotate`, `Pattern`, `Hit probability`, `Velocity`, and `Accent`.
- Use `Pattern` for live-coded non-Euclidean shorthand, where `x` marks a hit and `-` marks a rest.
- Keep `Note duration mode` on `Trigger` for Superior Drummer or other drum instruments. Use `Step fraction` only when driving instruments that respond musically to sustained MIDI note lengths.
- Open `Advanced generation limits` for `Global probability trim`, spacing guards, swing, velocity jitter, seed, and the maximum note cap.
- Keep `MIDI channel` at 10 for conventional drum instruments, or change it when driving another instrument.

The grid is shared across lanes. Each lane advances on that grid, then wraps
according to its own `Steps` value. A 16-step lane and a 15-step lane therefore
phase against each other without needing a separate per-lane step-duration
control.

`Hit probability` is density in the probabilistic sense. The visible Euclidean
pattern defines possible hits, and probability decides whether each possible
hit is admitted when the MIDI item is written. `Global probability trim`
multiplies the per-lane value.

The result is normal REAPER MIDI. If a time selection exists, generation starts
at the time selection start; otherwise it starts at the edit cursor. The item
length is the sum of the state lengths. The script is especially useful with
drum instruments because each lane keeps a fixed drum token while the rhythmic
state, probability, and velocity shift over time.

If a drum plugin glitches or REAPER DSP becomes unstable, lower `Global probability trim`, increase the spacing values, or reduce `Max generated notes` before generating another item.

## Lattice Tables

Use this to create a MIDI item from a visible table-scanning path. The script is inspired by Jerry Hunt's use of layered tables, ingress/egress locations, and event progressions, but it writes ordinary REAPER MIDI for procedural synths or other instruments.

Starting approach:

- Set `Rows`, `Columns`, and `Layers` to define the table.
- Move `Ingress` and `Egress` to set the start and goal areas of the gesture.
- Choose a `Gesture template`: `Circulating` is the most direct, while `Spiral`, `Cross address`, and `Egress pull` create more explicit path behavior.
- Choose a `Layer translation` to decide how table values become pitch, velocity, duration, and MIDI channel.
- Use `Density` for event admission and `Gesture mutation` for controlled deviation from the visible path.
- Use `Note length scale` and `Note length variation` to shape sustained or
  pointillistic articulation from the table values.
- Use `Voicing` and `Voicing variation` to expand each accepted lattice event
  into dyads, triads, quartal shapes, or clusters.
- Use `MIDI channel mode` to keep table-derived channel/source-lane motion or
  force all generated notes onto one MIDI channel.
- Keep `MIDI channels / source lanes` at 8 when driving the procedural synth source-lane model.

The preview shows the table, the active ingress-to-egress path, and the translation layers. The same path shown in the graphic is used when the MIDI item is generated, so the diagram is a readable score rather than decoration. Small horizontal traces on events indicate their generated note lengths. Density removes events from their original scan positions rather than compressing the accepted events toward the start of the item.

The lattice scripts include scan, snake, diagonal, orbit, pendulum, jump,
attractor, random-walk, braid, layer-bounce, and corner/star gesture templates.

## Lattice Drums

Use this to create an editable drum MIDI item from the same layered table-scanning model as `Lattice Tables`. Each layer is assigned to a drum voice, while the table cells shape velocity, duration, and density.

Starting approach:

- Choose `Superior-style` or `GM` as the drum map.
- Leave `MIDI channel` at 10 for conventional drum instruments.
- Use `Linear preset` for a starting point, then edit the gesture, table, and layer assignments.
- Assign each layer to a drum token such as `KIK`, `SNR`, `CHH`, or `OHH`.
- Choose a `Gesture template` and `Layer translation` to decide how the table scan becomes drum events.
- Use `Density` for event admission and `Gesture mutation` for controlled deviation from the visible path.

`Lattice Drums` is useful for linear drumming: a pattern where no two drums hit
at the exact same time. The scan writes one accepted lattice event at a time,
and each event belongs to one layer/drum voice.

The included starting presets are `Tight Linear Groove`, `Broken Funk Line`,
`Tom Contour`, `Playable Erratic`, `Hat / Snare Braid`, `Sparse Kick Thread`,
and `Orbiting Kit`.

The preview shows the layered table and animated scan. Event dots follow the layer colors, while the active event readout shows the drum token and MIDI note number that will be written.

## Musical Space

Use this to create a new editable MIDI item from a path through a pitch or harmonic space. It is intended for the procedural synths, but the result is ordinary MIDI and can drive any instrument.

Starting approach:

- Select a track, or let the script use the first track.
- Use a time selection when you want the item to match an exact region.
- Choose a root, scale, and space.
- Choose a `Rhythm model`, then use `Steps`, `Pulses`, `Rotate`, and
  `Rhythm variation` to shape timing.
- Use `Density` and `Path surprise` to decide how continuous or disrupted the path feels.
- Use `Voicing` when you want dyads, triads, quartal voicings, or clusters
  instead of a single note at each event.
- Use `Note length variation` to loosen the articulation while keeping the
  generated notes inside the item duration.
- Use `Channel mode` to map notes across MIDI channels for procedural synth focus.

The preview shows time, degree, MIDI-channel focus, and pitch-class placement
in one readable score. The main field places events across the generated
duration, while vertical marks show the rhythmic event positions. The pitch
compass shows the selected scale and the pitch classes used by the current
path. Short horizontal traces from each event show the generated note lengths.

Rhythm models include `Euclidean grid`, `Swing grid`, `Aksak cycle`,
`Burst / rest`, `Brownian clock`, `Contour pulse`, `Clave cells`,
`Fibonacci gaps`, `Morse cells`, `Irrational drift`, and `Logistic clock`.
These models are useful when a pattern needs additive grouping, uneven clocks,
bursts, drifting pulse placement, or a less grid-bound contour.

Pitch-space models include direct scale walks, contour paths, triadic fields,
axis mirrors, pendulums, orbits, spirals, constellations, attractor nodes, and
register gates. The generated item is ordinary REAPER MIDI, so the result can
be edited after generation.

## Form Learner

Use this to generate a longer MIDI item from one or more selected MIDI items. The script analyzes the selected notes as source material, then uses NumPy to compose a new editable form from their timing, pitch, duration, velocity, channel, and recurrence behavior.

Starting approach:

- Select one or more MIDI items with notes.
- Set `Duration beats` and `Sections` for the target form.
- Choose a `Learning strategy`: `Expanded return` keeps source material recognizable, `Channel canon` emphasizes MIDI-channel motion, and `Fragmented blocks` creates stronger contrast between dense and open sections.
- Use `Source influence` to decide how closely the result follows the selected material.
- Use `Variation`, `Timing warp`, and `Transpose range` to move away from the source.
- Keep `MIDI channels / lanes` at 8 when driving the procedural synth source-lane model.

The preview shows selected source-note density and register above a generated section map. The generated MIDI remains ordinary REAPER MIDI, so it can be edited, routed to the included procedural synths, or used with external instruments.

## Terrain Form

Use this for song-duration MIDI generation. The process calls a NumPy backend to compute a section map, terrain-shaped event density, register motion, channel/lane motion, and recurring motifs, then writes the result as an ordinary editable REAPER MIDI item.

Starting approach:

- Set `Duration beats` to the target form length.
- Choose a `Form`: `Arc`, `Return`, `Ritual`, and `Cascade` are useful starting points for longer spans.
- Choose a `Terrain`: `Ridge` concentrates activity, `Basin` opens space, `Fault` makes sharper changes, and `Attractor` pulls events toward moving centers.
- Use `Sections` to define the large-scale division of the item.
- Use `Motif recurrence` to decide how much material returns across the form.
- Keep `MIDI channels / lanes` at 8 for the procedural synth source-lane model.

The generated item is not tied to a specific synth. It can drive Carto, Lattice, Spectra, or external instruments. When `Add project markers for sections` is enabled, the script also writes section markers at the generated boundaries.



## Polymetric Pitch Lanes

Use this to create several simultaneous Euclidean lanes in one MIDI item. Each lane can have its own step count, pulse count, rotation, pitch degree, and MIDI channel.

Starting approach:

- Set `Lanes / MIDI channels` to match the number of procedural synth source lanes you want to excite.
- Set a duration in beats, or use the current edit position as the starting point.
- Choose a `Preset bank` when you want a whole pitch/rhythm field to start from.
- Choose the shared `Grid` value that all lanes will advance on.
- Adjust each lane's `Steps`, `Pulses`, and `Rotate`.
- Use `Pattern` for live-coded non-Euclidean shorthand such as `x-x--x-x---x--x-x`.
- Use `Degree` to assign lane pitch within the selected scale.
- Use `Note length` and `Note length variation` to move between even trigger
  behavior and more uneven phrase articulation.
- Use `Project BPM` and `Preview speed` to inspect the lane phasing before writing the item.
- Keep lane count at 8 for the procedural synth source-lane model, or raise it for denser MIDI-channel work.

The preview uses concentric rhythm rings: each MIDI lane is a ring, each step is a tick, and each active hit becomes a node. The hit polygon makes each lane's rhythmic shape visible. This script is useful for polymetric activity because each lane advances on the same grid while wrapping at its own step count. For the procedural synths, MIDI channel number becomes a compositional dimension: it can steer channel focus while note pitch, velocity, and length steer the synth response.

Preset banks include harmonic fields, bell-like lane stacks, aksak ladders,
sparse constellations, hockets, quartal meshes, octave phasing, mirror canons,
low/high register splits, chromatic drifts, whole-tone tilts, tritone gates,
clusters, wide-register spreads, and minimal pulse fields. Applying a bank sets
the active lane count and mutes unused lanes.
