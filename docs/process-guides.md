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
  - title: 3OAFX Ambisonic Kernel Collage
    href: "#3oafx-ambisonic-kernel-collage"
  - title: 3OAFX Offline Ambisonic Convolve
    href: "#3oafx-offline-ambisonic-convolve"
  - title: 3OAFX Offline Renderer
    href: "#3oafx-offline-renderer"
  - title: Ambisonic Stereo Decoder
    href: "#ambisonic-stereo-decoder"
  - title: 6ch Ambisonic Decoder Router
    href: "#6ch-ambisonic-decoder-router"
  - title: 3OAFX Spectral Profile Subtract
    href: "#3oafx-spectral-profile-subtract"
  - title: 3OAFX Spectral Profile Tools
    href: "#3oafx-spectral-profile-tools"
  - title: 3OAFX Spatial Grains
    href: "#3oafx-spatial-grains"
  - title: Multichannel Spectral Profile Tools
    href: "#multichannel-spectral-profile-tools"
  - title: Panners
    href: "#panners"
  - title: MC Channel Automation Mixer
    href: "#mc-channel-automation-mixer"
  - title: MC to Stereo Autogain
    href: "#mc-to-stereo-autogain"
  - title: Transaural Crosstalk Canceller
    href: "#transaural-crosstalk-canceller"
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
- Use many points for animated materials, but start with a readable shape when learning a process.
- `Random selected` changes one chosen lane; `Random all` changes every active lane.
- If an envelope is not active, the current slider value is used instead.

## Convolve Selected Items

Use this when you want one selected item to be convolved with another item used as an impulse response.

Selection:

1. Select the source item first.
2. Select the impulse item second.
3. Run `Convolve selected items`.

Start with `Matched / wrap impulse` for mono, stereo, or same-channel experiments. Use matrix-sum behavior when you want multichannel source and impulse material to combine into one summed channel layout rather than creating every source/impulse channel pair.

Starting settings:

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

Starting settings:

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

## 3OAFX Ambisonic Kernel Collage

Use this when the second set of files are not impulse responses, but ambisonic recordings you want to impose on another ambisonic source. The earliest selected WAV is the source. Every later selected WAV becomes a kernel recording. Any number of kernels can be selected. Files should use `ACN/SN3D`; kernels may be 1OA, 2OA, or 3OA when mixed-order adaptation is enabled.

The process decodes the source to a small virtual direction layer, convolves those source feeds with the kernel recordings, and sums the result back to an encoded ambisonic WAV. It is closer to spatial cross-convolution than room simulation: transients in the source can excite the spectral and spatial body of the kernel recordings, while sustained sources can become smeared or clouded by them.

Start conservatively:

1. Select a 1OA, 2OA, or 3OA source item first on the timeline.
2. Select one or more same-order ambisonic recordings to use as kernels.
3. Run `3OAFX Ambisonic Kernel Collage`.
4. Start with `Cycle kernels across directions`, `Max kernel window sec` around 2-4 seconds, and `Wet pre-gain dB` around `-18`.

`Direction layer` chooses the virtual directional structure. `Auto by order` uses four tetrahedral directions for 1OA and eight practical directions for 2OA/3OA. `Sparse 4-direction tetrahedral` can also be used with higher-order sources when you want a simpler four-region behavior. `Practical 8-direction` keeps the eight-region layout regardless of order.

`Kernel assignment` controls how the kernel recordings are distributed across those directions. `Cycle` is predictable and can use any number of kernels. `Random one per direction` changes the mapping with the seed. `Kernel index equals direction` treats the selected kernels as explicit direction slots, leaving missing slots silent and ignoring extra kernels. `Region smear` gives every selected kernel an implied position and blends nearby kernels into each virtual direction. `Dense all kernels per direction` can produce large, saturated spatial masses because every direction is convolved with every kernel.

`Adapt mixed-order kernels` lets 1OA, 2OA, and 3OA kernel recordings be used together. The selected output order is set by the source/order menu. Higher-order kernels are reduced to that order. Lower-order kernels keep their available channels, and missing higher-order channels are inferred from the lower-order directional energy. This is useful for collage work, but it is not the same as having native measured material at every order.

The kernel window, fade, wet pre-gain, soft limit, and peak normalize controls are there because a whole recording used as a convolution kernel can build level quickly. Shorter kernel windows usually keep the source identity clearer; longer windows push toward suspended, imprint-like fields.

## 3OAFX Offline Ambisonic Convolve

Use this for offline convolution of ambisonic source material with ambisonic impulse responses. It belongs with the 3OAFX offline family because it can either convolve one same-order ambisonic file with one same-order ambisonic IR, or use an intermediate directional layer before returning to ambisonic format. The banked method is inspired by the measured-reverb workflow Bruce Wiggins described in *Sounds in Space 2017*: decode or transform the ambisonic source to directional feeds, convolve those feeds with corresponding ambisonic IRs, then sum the wet result back into ambisonic format.

Selection:

1. Select the ambisonic source WAV as the earliest selected item on the timeline.
2. Select either one same-order ambisonic IR WAV, or a direction-accurate IR bank.
3. Run `3OAFX Offline Ambisonic Convolve`.

The source and IR items should use the same ambisonic convention: `ACN/SN3D`. Choose the source order to match the item: `1OA / 4ch`, `2OA / 9ch`, or `3OA / 16ch`.

Convolution methods:

- `Same-order direct convolution` uses one ambisonic source and one ambisonic IR at the same order: 1OA to 1OA, 2OA to 2OA, or 3OA to 3OA. The channels are convolved channel-for-channel.
- `Directional IR bank` uses a measured or designed ambisonic IR for each required direction. First order uses the four-direction P-format / tetrahedral method. 2OA and 3OA use an eight-direction cube-corner bank: `8 x 9 = 72` channels for a stacked 2OA bank, or `8 x 16 = 128` channels for a stacked 3OA bank.

In directional-bank mode, the IRs are encoded ambisonic WAVs, not P-format files. The source is transformed into the intermediate direction layer, then each directional feed is convolved with an encoded ambisonic IR. The summed output is a new encoded ambisonic WAV in the selected order.

Directional-bank mode does not reuse or wrap IRs. Select either one correctly stacked bank or the exact number of separate IR files required by the method: 4 files for first order, 8 files for 2OA or 3OA. A first-order four-direction bank is not an accurate substitute for an eight-direction 3OA bank. Render time increases with source duration, IR length, ambisonic order, and number of virtual directions.

`Adapt lower-order IRs to output order` allows a lower-order directional bank to be used in a higher-order render, for example eight 1OA IRs or one 32-channel stacked 1OA bank in a 3OA render. The adaptation estimates direction and signed energy from the lower-order IR, then re-encodes that response to the selected output order. This preserves the lower-order directional information, but it should be understood as an inferred higher-order response rather than a measured 3OA IR.

`Allow sparse 4-direction FOA bank` lets four 1OA directional IRs, or one 16-channel stacked FOA bank, drive a 2OA or 3OA render. This uses the P-format / tetrahedral directions as the source-feed layer. It is useful when only four measured directions are available, but it is intentionally sparse: the additional 8-direction higher-order measurement positions are not filled or guessed.

Use `Dry level` when the IRs were captured with little direct sound and you want to add the original source back separately. Use `Wet pre-gain dB` to lower the convolution bank before normalization if the wet result builds up.

For testing and designed spaces, run `3OAFX Synthetic Ambisonic IR Bank` to create encoded ambisonic IRs for the same direction layer. It uses room dimensions, material absorption, scattering, source distance, early reflections, and late diffuse taps to sketch a synthetic acoustic response.

The designer can write separate ambisonic WAVs, one per virtual direction, or one stacked multichannel bank where each direction occupies a block of ambisonic channels. The convolver detects either format. The practical 2OA and 3OA stacked banks are designed to fit REAPER's 128-channel track limit. The designer writes a direction-map CSV next to the generated IRs, and the convolver prints the same azimuth/elevation map in the console so measured banks can be checked against the expected order.

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

## 3OAFX Spectral Profile Subtract

Use this when you want to reduce or extract spectral material from an ambisonic
recording without treating each HOA channel as an unrelated signal.

Selection:

1. Select a WAV-backed ambisonic source item.
2. Select a WAV-backed ambisonic profile item that contains the material to
   reduce or extract.
3. Run `3OAFX Spectral Profile Subtract`.

The source and profile should use the same ambisonic order and channel format.
The renderer decodes both to the same 3OAFX directional layer, builds a spectral
profile per direction, applies subtraction, and re-encodes the result to
ACN/SN3D.

Settings:

- `Output`: `Cleaned source` writes the reduced source; `Residue only` writes
  the removed material.
- `Reduction amount`: how strongly the profile is subtracted.
- `Spectral floor`: the minimum gain left in a bin, useful for avoiding hollow
  or watery artifacts.
- `Profile sensitivity`: scales the profile before subtraction.
- `Frequency smoothing bins` and `Temporal smoothing`: soften narrow-bin and
  frame-to-frame changes.

## Ambisonic Stereo Decoder

This JSFX is a stereo fold-down decoder for ACN/SN3D ambisonic material. It is
intended for loudspeaker stereo monitoring or stereo renders, not headphone
binaural playback.

The decoder first projects the ambisonic input onto an internal virtual speaker
field, then derives the stereo output by placing a stereo pickup model inside
that field. This follows a practical studio approach: decode to a spatial field,
then choose how a stereo listening position hears that field.

Starting settings:

- `Ambisonic order`: match the source file, usually `1OA`, `2OA`, or `3OA`.
- `Virtual speaker field`: `24ch dome` is a good general starting point for
  3D material; `12ch dodeca` and `32ch sphere` are useful alternate projections.
  Virtual coordinates follow the package/IEM AED convention: `-90` is right,
  `+90` is left, and ring-like fields number speaker 1 at right-front and
  continue clockwise.
- `Stereo method`: start with `XY cardioid` for a stable image. Try `MS
  cardioid` for a center/side-like fold-down, `Blumlein` for a stronger
  figure-8 character, or `ORTF-style` when you want a wider speaker image.
- `Stereo width`: controls how strongly left/right differences are expressed;
  `0%` collapses the stereo pickup to mono.
- `A/B spacing`: adds a small time-difference component for `Spaced omni`, so
  that mode is not only amplitude panning.
- `Listening rotation`: rotates the stereo pickup position inside the virtual
  field. Positive values face left and negative values face right, following
  the package AED convention.
- `Rotation image`: scales how strongly `Listening rotation` is translated into
  the stereo image. `100%` is literal; higher values exaggerate the rotation.
- `Mic elevation`: tilts the stereo pickup upward or downward inside the
  virtual field.
- `Rear rejection`: reduces rear pickup as part of the stereo pickup model.
- `Front/rear balance`: a separate musical front/rear weighting stage. Positive
  values reshape rear material; negative values reduce the front instead.
- `Rear fold`: decides how positive `Front/rear balance` treats rear material:
  `Quieter`, `Narrower`, or `Wrap wide`.
- `Height fold`, `Height image`, and `Diffuse blend`: shape how overhead and
  diffuse material enter the stereo image.
- `Decode weighting`: choose the default projection, energy normalization,
  Max-rE-style taper, or `Custom` band weights for `W`, `1st`, `2nd`, and
  `3rd` order components. Custom weighting is edited with the order-weight
  sliders in the decode section; there is no separate weighting visual layer.
- `Bass mono below`: folds low frequencies toward the stereo center below the
  selected frequency for more controlled stereo renders.

The controller draws the virtual speaker field and the stereo pickup directions
so the fold-down can be adjusted visually. The package AED convention applies:
`-90` is right and `+90` is left.

Preset buttons provide quick starting points without changing the selected
ambisonic order: `Stable Stereo`, `Wide Field`, `Front Focus`, `Room Image`,
`MS Master`, `Blumlein`, and `A/B Soft`.

## 6ch Ambisonic Decoder Router

This JSFX is a package-native monitor decoder/router for a compact 6-speaker
setup. It accepts ACN/SN3D 1OA, 2OA, or 3OA input and writes speaker feeds to
channels 1-6. The default output layout is `45/0`, `-45/0`, `-135/0`,
`135/0`, `90/60`, and `-90/60` in azimuth/elevation degrees; each speaker has
editable azimuth and elevation sliders.

The layout follows the package AED convention: `-90` is right and `+90` is
left. Speakers 1-4 form the horizontal bed; speakers 5 and 6 are the elevated
left and right side speakers. If these defaults do not appear after updating,
rescan JSFX in REAPER and click `Reset 6ch layout` in the controller.

The decoder is an energy-normalized projection decoder with optional
max-rE-style order weighting. It is useful for realtime listening and sketching
inside REAPER. For formal calibrated ambisonic decoding, use a measured decoder
such as IEM `AllRADecoder` when available.

`Direct 6ch` mode bypasses ambisonic decoding and routes input channels 1-6 to
the same speaker outputs. `Ambisonic + Direct` mixes that direct layer with the
decoded ambisonic layer, which is useful when combining non-ambisonic materials
with the same monitor rig.

## 3OAFX Spectral Profile Tools

These actions share the same source/profile workflow as `3OAFX Spectral Profile
Subtract`: select a WAV-backed ambisonic source item first, then select a
WAV-backed ambisonic profile or reference item. Both items are decoded to the
same directional layer before processing and re-encoding.

Use the variants for different intentions:

- `3OAFX Spectral Profile Match`: moves the source toward the spectral contour
  of a reference while keeping the source timing and phase.
- `3OAFX Spectral Residue Extractor`: writes the material that would be removed
  by a profile subtraction.
- `3OAFX Spectral Hole Maker`: carves profile-shaped space from the source.
- `3OAFX Ambiance Extractor`: extracts source material that resembles a room
  tone, noise bed, or ambiance profile.

Useful first controls:

- `Amount`: strength of the match, carve, or extraction.
- `Profile sensitivity`: how strongly the second item influences the process.
- `Spectral floor`: how much material is allowed to remain in reduced areas.
- `Frequency smoothing bins` and `Temporal smoothing`: increase these when the
  result feels too narrow, watery, or frame-like.

## 3OAFX Spatial Grains

`3OAFX Spatial Grains` follows the spatial-grain principle described by E.
Deleflie and Greg Schiemer: the same grain micro-control is applied to every
encoded component channel. In practice, grain position, duration, envelope,
playback rate, overlap, and navigation mode are shared across the 1OA, 2OA, or
3OA channels, so the renderer can work directly on the encoded ambisonic file.

Use `Navigation mode` to decide how source time is used as a spatial index:

- `Index scan`: reads through the source as a trajectory.
- `Cloud`: samples source-time positions statistically.
- `Dual state`: moves between two source-time regions.
- `Jump scan`: steps through source-time regions.
- `Freeze cloud`: builds a cloud around one source-time position.

`Room memory` increases minimum grain length and overlap to help retain
reverberant or time-based spatial cues. `Yaw` controls add optional HOA-domain
rotation; order weighting can soften or emphasize higher-order spatial detail.

## Multichannel Spectral Profile Tools

These are the non-ambisonic counterparts to the 3OAFX profile tools. Select a
WAV-backed source item first, then a WAV-backed profile item. The output keeps
the source channel count and does not decode or re-encode HOA.

Use the variants for different intentions:

- `Spectral Profile Subtract`: reduces material in the source that matches the
  profile.
- `Spectral Residue Extractor`: writes the removed material as a separate item.
- `Spectral Hole Maker`: carves profile-shaped spectral space in the source.
- `Spectral Ambiance Extractor`: extracts material that resembles room tone,
  noise bed, or ambiance profile.

The `Channel mode` setting controls how the profile channels are assigned:

- `Matched channels`: source channel 1 uses profile channel 1, and so on.
- `Wrap profile channels`: profile channels repeat across the source channels.
- `Summed profile to all`: the profile is analyzed as one composite spectrum and
  applied to every source channel.

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

The `17ch Cube XYZ Panner` is an XYZ-native panner. Use smaller spread values when you want a source to focus near a single speaker, and larger distance or offset gestures when you want a source to feel beyond the cube.

The `12ch Dodeca Panner` uses an AED-native spherical layout drawn as a dodecahedron. It supports discrete spherical motion with a smaller speaker count.

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

Use this at the end of a multichannel sketch when you need a stereo monitor or print. It is not a substitute for an actual multichannel render; it is a controlled fold-down.

Important controls:

- Layout preset describes how channels are arranged conceptually.
- Width and rotation change stereo spread.
- Projection or weighting decides how channels contribute to left and right.
- 3D attenuation can reduce overhead, underhead, or distant speakers in sphere, hemisphere, and cube-style layouts.
- Autogain helps keep the fold-down from jumping in level as channel count changes.

Use ring projection for circular layouts, sphere or hemisphere projection for dome-like material, and cube-style projection for XYZ/cube work. Watch the graphic: smaller dots indicate channels receiving stronger 3D attenuation.

## Transaural Crosstalk Canceller

Use this on a stereo loudspeaker track when you want transaural crosstalk
cancellation for a fixed listening position. It is not a headphone binaural
processor; it will usually sound wrong on headphones and will change with
speaker angle, listener position, and room reflections.

The normal placement is after a binaural decoder or binaural stereo render. The
binaural stage creates the left-ear/right-ear stereo signal; the transaural
stage prepares that signal for loudspeaker playback by reducing how much each
speaker reaches the opposite ear.

The processor is a lightweight JSFX approximation of transaural
crosstalk-cancellation practice. `Feedforward` subtracts a delayed and filtered
opposite-channel path. `Matrix inverse` adds a conservative symmetric 2x2
inverse-style compensation stage, closer to the standard transaural framing of
speaker-to-ear transfer paths, but still without measured HRTFs or room-specific
inverse filters.

Background: transaural stereo is usually described as loudspeaker playback that
accounts for four transfer paths: each speaker to each ear. This tool uses that
idea as a practical controller-oriented approximation rather than as a measured
listener-specific inverse filter.

Starting settings:

- `Cancellation mode`: `Matrix inverse` is the more reference-aligned
  transaural approximation. `Feedforward` keeps the earlier gentler subtraction
  behavior and can be useful in reflective rooms or less exact speaker setups.
- `Cancellation amount`: start around `60-100%`; higher values are more
  dramatic and more position-dependent.
- `Speaker half-angle`: half of the angle between the left and right speakers
  from the listener position. A common stereo triangle is about `30 deg`.
- `Head width`: listener ear spacing estimate; `17-18 cm` is a practical
  default.
- `Delay trim`: fine-tunes the cancellation delay if the image feels smeared or
  hollow.
- `Cancel HF rolloff`: softens the cancellation path so it does not become
  brittle.
- `Low protect`: reduces cancellation in the low end, where room and speaker
  geometry make cancellation less reliable.
- `Stereo preserve`: blends back toward the original stereo signal if the
  cancellation image becomes too fragile.
- `Output gain`: keep headroom; cancellation can raise peaks.

The controller graphic shows the direct speaker-to-ear paths and the delayed
opposite-channel cancellation paths. Head width changes the ear spacing in the
graphic, while the side readouts summarize cancellation filtering, low
protection, stereo preservation, and output trim. Use it as a geometry check,
then tune by ear from the intended listening position.

Preset buttons provide starting points for common situations: `Gentle`,
`Standard`, `Narrow Setup`, `Wide Setup`, and `Careful / Roomy`.

## Track and Item Helpers

These are utility actions for building and reorganizing multichannel projects. They usually do one structural task, so duplicated test items are a useful way to confirm the result before working on source material.

Useful starting points:

- `Route Selected Tracks to Multichannel Bus` gathers selected mono or lower-channel tracks into a new multichannel folder/bus and assigns channel routing in order.
- `Build multichannel stem from selected tracks` creates a rendered multichannel stem from selected tracks.
- `Explode multichannel item to mono tracks` separates a multichannel media item into one mono track per channel.
- `Resize item channel count` repeats or downmixes channels to reach a target count.
- `Reorder`, `Rotate`, `Mirror`, `Interleave`, and `Deinterleave` change channel order without changing the musical content.

For routing actions, select only the tracks you want included. If the requested result would exceed REAPER's 128-channel limit, the action should stop rather than build an invalid bus. For render-based helpers, expect a new media item or track and keep the source material until you have checked the result.
