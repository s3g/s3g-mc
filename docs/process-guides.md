---
layout: default
title: Process Guides
prev_page:
  title: Workflows
  url: /workflows.html
next_page:
  title: Gallery
  url: /gallery.html
toc:
  - title: General Pattern
    href: "#general-pattern"
  - title: Breakpoint Envelopes
    href: "#breakpoint-envelopes"
  - title: Convolve Selected Items
    href: "#convolve-selected-items"
  - title: Spectral Shaper
    href: "#spectral-shaper"
  - title: Scatter Slices
    href: "#scatter-slices"
  - title: Loop Drift
    href: "#loop-drift"
  - title: Loop Rift
    href: "#loop-rift"
  - title: Dense Grain Cloud
    href: "#dense-grain-cloud"
  - title: Render MC Carto Synth
    href: "#render-mc-carto-synth"
  - title: Render MC Spectra Synth
    href: "#render-mc-spectra-synth"
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
  - title: 3OAFX Offline Renderer
    href: "#3oafx-offline-renderer"
  - title: Panners
    href: "#panners"
  - title: MC Channel Automation Mixer
    href: "#mc-channel-automation-mixer"
  - title: MC to Stereo Autogain
    href: "#mc-to-stereo-autogain"
  - title: Track and Item Helpers
    href: "#track-and-item-helpers"
---

# Process Guides

These notes describe how to approach selected s3g-mc processes in practice. They are intentionally more direct than the tool list: what to select, what the action creates, and which settings are worth touching first.

## General Pattern

Most render actions follow the same workflow:

1. Select one or more media items or tracks.
2. Run the action from the `s3g-mc Package Browser` or REAPER Action List.
3. Choose render settings in the ImGui window.
4. Click `Render`.
5. Listen to the newly created item or track before deleting the source.

Render actions generally create a new media item rather than destructively editing the source. Actions that render from selected media try to limit the render to the selected item, selected-track media range, or requested duration.

For NumPy-backed processes, use WAV-backed media. Convert compressed formats to WAV first; the offline analysis and render scripts expect WAV sources.

## Breakpoint Envelopes

Several offline processes include compact breakpoint lanes plus a `Detailed Breakpoint Editor`. The compact lanes show the active time-shape for each mapped parameter. The detailed editor lets you choose a lane, activate it, add or delete points, apply preset shapes, and randomize points.

Useful habits:

- Draw `Amplitude` or `Density` first, then adjust timbre or spatial controls.
- Use many points for animated materials, but keep the shape simple when judging a new process.
- `Random selected` is safer than `Random all` when you already like part of a render.
- If an envelope is not active, the current slider value is used instead.

## Convolve Selected Items

Use this when you want one selected item to be convolved with another item used as an impulse response.

Selection:

1. Select the source item first.
2. Select the impulse item second.
3. Run `Convolve selected items`.

Start with `Matched / wrap impulse` for simple mono, stereo, or same-channel experiments. Use matrix-sum behavior when you want multichannel source and impulse material to combine into a richer shared result without exploding into every source/impulse channel pair.

Good first settings:

- Tail: `Full convolution tail`
- Normalize: on
- Normalize peak: around `-6 dB`

If the result is silent or unexpectedly long, check that both selected items are readable audio files and that the impulse has audible content. If the waveform takes a moment to appear, REAPER may still be building peaks for the rendered file.

## Spectral Shaper

Use this for two-file spectral envelope transfer. The first selected item keeps timing and phase; the second item supplies the spectral envelope or formant shape.

Selection:

1. Select the carrier item first. This is the rhythm, phrase, or tune source.
2. Select the shaper item second. This supplies the spectral color.
3. Run `Spectral Shaper`.

The classic way to think about it: one sound keeps the contour of its performance while another sound changes what that performance seems to be made from.

Try the standard spectral envelope mode first. Use the formant-vocode algorithm when you want broader vocal-like or resonant contour transfer instead of dense frame-by-frame spectral matching.

Good first settings:

- Amount: moderate rather than maximum
- Contrast: increase after the source relationship is working
- Normalize: on

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

Start with conservative rate spread and a generous crossfade. Increase drift once the loop feels seamless.

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

## Render MC Carto Synth

Use this when you want a rendered multichannel synthetic source rather than a processed input file. Carto is a JSFX synth driven offline by the Lua renderer, so it creates a new media item instead of requiring realtime playback.

Good first approach:

1. Choose duration and channel count.
2. Choose one algorithm.
3. Leave normalize on.
4. Shape amplitude and density with breakpoint envelopes.
5. Render a short test before making a long version.

Algorithms have different spatial behavior. Dust-like modes work well as stochastic clouds. Pulse and packet modes read more clearly with lower density and sharper envelopes. Byte-mask materials can become noise quickly, so sparse density and amplitude shaping are useful. Spline and drift-like materials benefit from slower breakpoint motion.

Use the detailed breakpoint editor when the render feels too static. A good starting set is amplitude, density, brightness, and one spatial control. Randomize one lane at a time until the behavior is legible.

## Render MC Spectra Synth

Use this for slower, polished synthetic material based on spectral masses, resonators, impulse responses, and partial-like behavior. It is also rendered offline through the included JSFX synth engine.

Good first approach:

- Keep peak normalize on.
- Start with moderate density and brightness.
- Use amplitude and spectral-shape breakpoint lanes before adding heavy spatial motion.
- Avoid judging the process from only the first second; some modes develop over the whole duration.

Impulse and resonator modes can become clicky if the event layer is too sharp. Increase event smoothing or use slower envelopes when that happens. Spectral-mass modes usually sound better when density changes over time rather than staying fixed.

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
- `Protection` or clarity controls help avoid muddy, overloaded renders.

If the output sounds staticy, reduce density and pitch spread first. If it sounds too much like a simple filtered copy, increase trace motion or spatial spread.

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

Use this for additive fields made from many generated partial events rather than from a single analyzed source. It can become computationally heavy, so it is best approached with conservative tests.

Good first settings:

- Use a short duration while designing.
- Keep partial or event counts moderate.
- Leave normalize on.
- Shape amplitude and density with breakpoints before adding wide pitch drift.

This process is strongest when it behaves like a mass: many small related events that change density, register, and spatial focus over time. If REAPER feels slow while the window is open, collapse the detailed breakpoint editor and render shorter tests.

## Resonant Terrain

Use this for struck resonator banks, metallic fields, synthetic impulse responses, and sustained resonant dust. It sits between an offline synth and an impulse-design process.

Good first settings:

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

## 3OAFX Offline Renderer

Use this when you want the 3OAFX idea rendered offline directly from an ambisonic media item.

Selection:

- Select one ambisonic media item.
- Use ACN/SN3D channel convention.
- Choose 1OA, 2OA, or 3OA to match the source channel count.

Method:

The process decodes the ambisonic item to a virtual speaker layer, applies an effect over a moving AED focus region, mixes dry and wet behavior using the focus mask, then re-encodes to a new ambisonic item.

Important controls:

- `Effect region` chooses the processing type.
- `Azimuth` and `Elevation` set the focus direction.
- `Focus width` and `Focus sharpness` shape the region.
- `Effect amount / gain` controls how strongly the effect is heard.
- `Wet amount`, `Dry level`, and `Dry remaining at focus` define how dry and processed signal coexist.
- Breakpoint envelopes can animate focus and mix parameters over the item.

For a clear moving-spotlight test, use a strong effect amount, low dry remaining at focus, and an azimuth breakpoint moving from `-180` to `180`.

## Panners

The panner controllers are companion interfaces for JSFX. Insert or load the JSFX on a track, then use the matching controller from the package browser or Action List for a larger spatial interface.

General workflow:

1. Put mono sources on an 8-channel track or bus where the panner expects up to 8 input sources.
2. Load the matching `s3g` panner JSFX.
3. Open the controller.
4. Use the visual panel, source controls, and automation controls from the controller rather than the raw JSFX fader list.

The `Layout Panner` is the general option for quad, rings, cube, double-ring, and 24-channel dome layouts. Use it when you want a common speaker arrangement without committing to one SRST-specific array.

The 25-channel dome panners share the RISD SRST dome layout but use different panning ideas:

- `LBAP` is a practical default for smooth dome movement.
- `VBAP` emphasizes nearest-region vector behavior.
- `DBAP` emphasizes distance-weighted motion.
- `Cosine` gives softer angular focus.
- `Region` constrains sources to named arcs, rings, triangles, and custom constellations.
- `Vector Morph` stores scenes and interpolates between them.

The `17ch Cube XYZ Panner` is best treated as an XYZ-native panner. Use smaller spread values when you want a source to focus near a single speaker, and larger distance or offset gestures when you want a source to feel beyond the cube.

The `12ch Dodeca Panner` uses an AED-native spherical layout drawn as a dodecahedron. It is useful for discrete spherical motion with a smaller speaker count.

For automation, use the controller's automation controls to show, hide, arm, and write relevant lanes. In `Trim/Read`, the GUI can audition control changes without writing automation. Use write modes when you intentionally want controller motion recorded.

## MC Channel Automation Mixer

Use this as a track-level multichannel mixer when REAPER's normal JSFX fader view becomes too long to manage.

Workflow:

1. Select a multichannel track.
2. Run `128ch Automation Mixer`.
3. Set the track channel count in REAPER as needed.
4. Use the controller for faders, mute, solo, channel groups, meters, and pin routing.

The visible mixer adapts to the track channel count, up to REAPER's 128-channel limit. Faders use a dB-style response, double-click returns to unity, and direct dB entry can make relative changes across selected faders.

Use shift-click to select or release channels. Quick channel groups highlight related faders and let a group move together. The pin matrix is for channel remapping and should be treated as routing, not gain.

## MC to Stereo Autogain

Use this at the end of a multichannel sketch when you need a useful stereo monitor or print. It is not a substitute for an actual multichannel render; it is a controlled fold-down.

Important controls:

- Layout preset describes how channels are arranged conceptually.
- Width and rotation change stereo spread.
- Projection or weighting decides how channels contribute to left and right.
- 3D attenuation can reduce overhead, underhead, or distant speakers in sphere, hemisphere, and cube-style layouts.
- Autogain helps keep the fold-down from jumping in level as channel count changes.

Use ring projection for circular layouts, sphere or hemisphere projection for dome-like material, and cube-style projection for XYZ/cube work. Watch the graphic: smaller dots indicate channels receiving stronger 3D attenuation.

## Track and Item Helpers

These are utility actions for building and reorganizing multichannel projects. They usually do one structural task and are easiest to learn by duplicating a few test items first.

Useful starting points:

- `Route Selected Tracks to Multichannel Bus` gathers selected mono or lower-channel tracks into a new multichannel folder/bus and assigns channel routing in order.
- `Build multichannel stem from selected tracks` creates a rendered multichannel stem from selected tracks.
- `Explode multichannel item to mono tracks` separates a multichannel media item into one mono track per channel.
- `Resize item channel count` repeats or downmixes channels to reach a target count.
- `Reorder`, `Rotate`, `Mirror`, `Interleave`, and `Deinterleave` change channel order without changing the musical content.

For routing actions, select only the tracks you want included. If the requested result would exceed REAPER's 128-channel limit, the action should stop rather than build an invalid bus. For render-based helpers, expect a new media item or track and keep the source material until you have checked the result.
