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
  - title: Generate Lattice MIDI
    href: "#generate-lattice-midi"
  - title: Generate Musical Space MIDI
    href: "#generate-musical-space-midi"
  - title: MIDI Form Learner
    href: "#midi-form-learner"
  - title: MIDI Terrain Form
    href: "#midi-terrain-form"
  - title: Polymetric Drum States
    href: "#polymetric-drum-states"
  - title: Generate Polymetric MIDI Lanes
    href: "#generate-polymetric-midi-lanes"
---

# MIDI Composition Guides

These guides match the Package Browser's MIDI Composition group. The scripts create ordinary editable REAPER MIDI items for procedural synths and algorithmic composition.

## Polymetric Drum States

Use this to create an editable drum MIDI item from changing polymeter states. Each state stores Euclidean lane settings for drum tokens such as `KIK`, `SNR`, `CHH`, and `OHH`; the script can jump between states or glide between them before writing MIDI notes.

Starting approach:

- Choose `Superior-style` or `GM` as the drum note map.
- Set `Lanes` to the number of drum voices you want to generate.
- Use `Timeline preview` or `Play Preview` to move through the state sequence.
- Choose `Jump` for hard changes between polymeter configurations, or `Glide` for interpolated transitions.
- Use `Add State` and `Delete State` to change the number of configurations.
- Leave `Snap beat sliders` on when you want state lengths, trigger lengths, and spacing guards to land on a beat division. Choose the division with `Grid`.
- Leave `Integer state lengths` on for whole-beat state blocks, or turn it off when you want fractional state lengths.
- Set `Selected state length beats`, or type directly into `Beats`, to place each state over the generated item's timeline.
- Select a state, then edit each lane's `Steps`, `Pulses`, `Rotate`, `Hit probability`, `Velocity`, and `Accent`.
- Keep `Note duration mode` on `Trigger` for Superior Drummer or other drum instruments. Use `Step fraction` only when driving instruments that respond musically to sustained MIDI note lengths.
- Open `Advanced generation limits` for `Global probability trim`, spacing guards, swing, velocity jitter, seed, and the maximum note cap.
- Keep `MIDI channel` at 10 for conventional drum instruments, or change it when driving another instrument.

Each lane pattern runs over an internal 4-beat phrase. Different `Steps`,
`Pulses`, and `Rotate` values create the polymetric feel without adding a
separate per-lane cycle-length control.

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

## Generate Lattice MIDI

Use this to create a MIDI item from a visible table-scanning path. The script is inspired by Jerry Hunt's use of layered tables, ingress/egress locations, and event progressions, but it writes ordinary REAPER MIDI for procedural synths or other instruments.

Starting approach:

- Set `Rows`, `Columns`, and `Layers` to define the table.
- Move `Ingress` and `Egress` to set the start and goal areas of the gesture.
- Choose a `Gesture template`: `Circulating` is the most direct, while `Spiral`, `Cross address`, and `Egress pull` create more explicit path behavior.
- Choose a `Layer translation` to decide how table values become pitch, velocity, duration, and MIDI channel.
- Use `Density` for event admission and `Gesture mutation` for controlled deviation from the visible path.
- Keep `MIDI channels / source lanes` at 8 when driving the procedural synth source-lane model.

The preview shows the table, the active ingress-to-egress path, and the translation layers. The same path shown in the graphic is used when the MIDI item is generated, so the diagram is a readable score rather than decoration.

## Generate Musical Space MIDI

Use this to create a new editable MIDI item from a path through a pitch or harmonic space. It is intended for the procedural synths, but the result is ordinary MIDI and can drive any instrument.

Starting approach:

- Select a track, or let the script use the first track.
- Use a time selection when you want the item to match an exact region.
- Choose a root, scale, and space.
- Use Euclidean `Steps`, `Pulses`, and `Rotate` to define timing.
- Use `Density` and `Path surprise` to decide how continuous or disrupted the path feels.
- Use `Channel mode` to map notes across MIDI channels for procedural synth focus.

The preview uses two geometric diagrams. The pitch-space wheel shows the selected scale and the path through pitch classes. The rhythm/channel ring shows Euclidean timing, with event radius and labels indicating MIDI-channel focus. `Scale walk` is the most direct mode. `Contour` favors melodic direction changes. `Triadic` makes larger harmonic moves. `Axis mirror` folds alternate moves around a center degree.

## MIDI Form Learner

Use this to generate a longer MIDI item from one or more selected MIDI items. The script analyzes the selected notes as source material, then uses NumPy to compose a new editable form from their timing, pitch, duration, velocity, channel, and recurrence behavior.

Starting approach:

- Select one or more MIDI items with notes.
- Set `Duration beats` and `Sections` for the target form.
- Choose a `Learning strategy`: `Expanded return` keeps source material recognizable, `Channel canon` emphasizes MIDI-channel motion, and `Fragmented blocks` creates stronger contrast between dense and open sections.
- Use `Source influence` to decide how closely the result follows the selected material.
- Use `Variation`, `Timing warp`, and `Transpose range` to move away from the source.
- Keep `MIDI channels / lanes` at 8 when driving the procedural synth source-lane model.

The preview shows selected source-note density and register above a generated section map. The generated MIDI remains ordinary REAPER MIDI, so it can be edited, routed to the included procedural synths, or used with external instruments.

## MIDI Terrain Form

Use this for song-duration MIDI generation. The process calls a NumPy backend to compute a section map, terrain-shaped event density, register motion, channel/lane motion, and recurring motifs, then writes the result as an ordinary editable REAPER MIDI item.

Starting approach:

- Set `Duration beats` to the target form length.
- Choose a `Form`: `Arc`, `Return`, `Ritual`, and `Cascade` are useful starting points for longer spans.
- Choose a `Terrain`: `Ridge` concentrates activity, `Basin` opens space, `Fault` makes sharper changes, and `Attractor` pulls events toward moving centers.
- Use `Sections` to define the large-scale division of the item.
- Use `Motif recurrence` to decide how much material returns across the form.
- Keep `MIDI channels / lanes` at 8 for the procedural synth source-lane model.

The generated item is not tied to a specific synth. It can drive Carto, Lattice, Spectra, or external instruments. When `Add project markers for sections` is enabled, the script also writes section markers at the generated boundaries.



## Generate Polymetric MIDI Lanes

Use this to create several simultaneous Euclidean lanes in one MIDI item. Each lane can have its own step count, pulse count, rotation, pitch degree, and MIDI channel.

Starting approach:

- Set `Lanes / MIDI channels` to match the number of procedural synth source lanes you want to excite.
- Set a duration in beats, or use the current edit position as the starting point.
- Adjust each lane's `Steps`, `Pulses`, and `Rotate`.
- Use `Degree` to assign lane pitch within the selected scale.
- Keep lane count at 8 for the procedural synth source-lane model, or raise it for denser MIDI-channel work.

The preview uses concentric Euclidean rings: each MIDI lane is a ring, each step is a tick, and each active hit becomes a node. The hit polygon makes each lane's rhythmic shape visible. This script is useful for polymetric activity because each lane repeats over the same item duration with a different internal grid. For the procedural synths, MIDI channel number becomes a compositional dimension: it can steer channel focus while note pitch, velocity, and length steer the synth response.
