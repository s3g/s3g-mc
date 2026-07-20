---
layout: default
title: Imprint Sketch
utility_nav: true
prev_page:
  title: Image Score
  url: /utilities-image-score-generator.html
next_page:
  title: Spatial Score
  url: /utilities-spatial-score.html
toc:
  - title: Open Tool
    href: "#open-tool"
  - title: Spaces
    href: "#spaces"
  - title: Connected Volumes
    href: "#connected-volumes"
  - title: Generate And Mutate
    href: "#generate-and-mutate"
  - title: Directional Responses
    href: "#directional-responses"
  - title: Echo Paths
    href: "#echo-paths"
  - title: Export
    href: "#export"
---

# Imprint Sketch

## Open Tool

[Open Imprint Sketch](utilities/imprint-sketch-designer/){:target="_blank" rel="noopener noreferrer" .utility-link}

Imprint Sketch designs procedural directional responses for `s3g Ambi Imprint
64` and ambisonic impulse-response banks rendered by `3OAFX Synthetic
Ambisonic IR Bank`. It replaces IR Sketch and imports projects created by the
retired utility.

The tool is an acoustic-response sketcher rather than a measurement or
architectural simulator. It supports plausible spaces, exaggerated natural
spaces, and intentionally impossible structures while keeping directional
arrivals and decay behavior repeatable.

## Spaces

The `Space` menu selects Room, Cave, Cavern, Tunnel, Canyon, Clearing, or
Abstract geometry. Each family has its own procedural boundary construction,
scale ranges, vertical variation, openness, reflection distribution, and
material tendencies.

Room preserves the architectural shapes and connected chambers from IR
Sketch. Caves and caverns use irregular closed boundaries, rough surfaces,
variable ceilings, and coupled branches. Tunnels and canyons use bent passage
topologies with axial returns. Clearings emphasize ground, boundary, and
distant scatter responses instead of a dense enclosed tail. Abstract spaces
permit deeply folded outlines, contrasting regions, unstable proportions, and
extreme combinations of enclosure and openness.

`Branch family` controls the identity of connected regions independently from
their material. `Inherit primary` keeps every branch in the primary space
family. An explicit family can connect unlike spaces, such as an architectural
room opening into a cave or a cavern feeding a tunnel. `Mixed deterministic`
chooses a repeatable family for each branch from the project seed and
Strangeness value. Family selection changes branch outline, height, path
distribution, directional spread, coupling, and energy loss; `Branch
material` remains a separate surface choice.

The Top, Side, and 3D views show the generated boundary and response
positions. Bank Map edits directional response positions: drag a response in
the plan for X/Y, then use the `ELEVATION` rail for its Z position. Colored
segments on the rail show the primary and connected vertical regions available
at that response's current plan position. Bank Matrix and Reflection Layers
compare timing and energy between response groups.

`Field X offset`, `Field Y offset`, and `Field Z offset` position the pickup
inside the connected acoustic volumes. Z ranges from the lowest beneath region
to the highest overhead region while keeping zero at the primary-space center.
The pickup is constrained to a real region rather than empty space between
volumes. Drag in Top view to edit X/Y, or drag in Side view to edit X/Z and
enter vertically connected chambers.

## Connected Volumes

Connected regions can attach to the front, back, left, or right wall, sit
overhead, or continue beneath the primary space. Pair placements such as
`Left + overhead` make it possible to compose arrivals from different planes
around the pickup. Nested overhead and beneath regions stack vertically rather
than being flattened into the floor plan.

`Opening shape` selects rectangular, arched, circular, elliptical, slot, or
irregular portals. Portal width, height, vertical position, area, and shape
affect coupling, loss, and directional spread as well as drawing. `Branch
heading` and `Cross-position` place ceiling and floor regions in plan, while
`Wall elevation` raises wall-attached regions within the available vertical
span.

The internal model is a graph of three-dimensional regions joined by portals.
Top view distinguishes wall, overhead, and beneath regions; Side and 3D show
their actual vertical positions and opening outlines. The graph is saved in
project and imprint metadata while its acoustic result is resolved into the
ordinary timed AED events consumed by Ambi Imprint.

`Open boundary` uses the same aperture language as a connected corridor: a
dark opening inside a light frame. Its mint frame distinguishes energy escape
to the exterior from the pale-blue portals between modeled regions. The
opening is shown consistently in Top, Side, 3D, and glTF views.

## Generate And Mutate

`Generate` creates a new space in the selected family. Choose `Any family` to
let the generator select one. `Strangeness` controls how strongly generation
favors irregular boundaries, connected regions, material contrast, vertical
variation, field displacement, and unusual reflection timing.

Every generated space has a visible seed. The seed keeps its procedural
geometry repeatable and is saved in project and runtime exports. `Mutate`
preserves the current family and overall identity while perturbing geometry,
materials, branches, response positions, and timing. Repeated mutations are a
quick way to develop related families of spaces.

## Directional Responses

First-order boundary events are calculated from the generated polygon rather
than from an invisible rectangular room. Floor and ceiling returns respond to
surface roughness, vertical variation, and openness. Additional scatter,
passage, folded, and connected-region events are generated according to the
space family.

Material curves, RT60 values, and natural-space controls are creative
estimates. Open spaces intentionally produce sparse returns and reduced late
energy rather than behaving like oversized rooms.

## Echo Paths

`Echo Paths` adds deterministic higher-order return structures without turning
the imprint into a live feedback processor. `Axial return` follows the longest
primary-room axis, `Flutter pair` alternates across the shortest opposing
surfaces, `Coupled chambers` derives independent and cross-region portal loops, and
`Circulating perimeter` advances around the primary polygon. `Automatic
geometry` selects among those models from the current topology and space
family.

Path interval comes from geometric distance at 343 metres per second.
`Prominence` controls event count and initial level, `Persistence` controls
loss across successive returns, and `Regularity` moves from perturbed natural
timing toward a strict periodic sequence. Dimensions, materials, portal width,
region coupling, duration, and the existing reflection count continue to shape
the result. Muted violet paths appear in Top and 3D views, while the response
timeline and Reflection Layers show their resolved events.

The default is `Off`, preserving projects created before the echo model. An
export stores optional path geometry and provenance, but audio is still
resolved into ordinary directional early-reflection entries understood by
`s3g Ambi Imprint 64`.

## Export

`Export Project` writes a versioned `s3g-imprint-sketch` JSON file that can be
re-imported for editing. Legacy `s3g-ir-room-sketch` JSON remains readable.
Version 2 adds `space.regions` and `space.portals`; version 1 projects remain
readable with wall-attached rectangular portal defaults. The project retains
the room-compatible fields required by `3OAFX Synthetic Ambisonic IR Bank`
while adding the generalized space model.

`Export Imprint` writes `.s3gimprint` for realtime use in `s3g Ambi Imprint
64`. The file contains directional direct arrivals, boundary, scatter, and
structured echo events, eight-band absorption and decay data, connected-region
information, and procedural-space provenance. `Export glTF` writes a visual
model with the generated boundary, ceiling variation, branches, openings,
listener, and response positions. Shaped chamber apertures and frames are
preserved, exterior openings retain their dark aperture and mint frame, and
wall, overhead, and beneath regions use the same green, blue, and muted-brown
identity as the Top, Side, and 3D views.
