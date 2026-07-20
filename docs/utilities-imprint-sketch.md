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
  - title: Generate And Mutate
    href: "#generate-and-mutate"
  - title: Directional Responses
    href: "#directional-responses"
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
positions. Bank Map edits directional response positions. Bank Matrix and
Reflection Layers compare timing and energy between response groups.

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

## Export

`Export Project` writes a versioned `s3g-imprint-sketch` JSON file that can be
re-imported for editing. Legacy `s3g-ir-room-sketch` JSON remains readable.
The project retains the room-compatible fields required by `3OAFX Synthetic
Ambisonic IR Bank` while adding the generalized space model.

`Export Imprint` writes `.s3gimprint` for realtime use in `s3g Ambi Imprint
64`. The file contains directional direct arrivals, boundary and scatter
events, eight-band absorption and decay data, connected-region information,
and procedural-space provenance. `Export glTF` writes a visual model with the
generated boundary, ceiling variation, branches, openings, listener, and
response positions.
