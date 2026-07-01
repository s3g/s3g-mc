---
layout: default
title: IR Room Sketch Designer
utility_nav: true
prev_page:
  title: Image Score Generator
  url: /utilities-image-score-generator.html
next_page:
  title: s3g-mc Mover
  url: /utilities-mover.html
toc:
  - title: Open Tool
    href: "#open-tool"
  - title: Purpose
    href: "#purpose"
  - title: Room Views
    href: "#room-views"
  - title: IR Groups
    href: "#ir-groups"
  - title: Room Variation
    href: "#room-variation"
  - title: REAPER Use
    href: "#reaper-use"
  - title: Export
    href: "#export"
---

# IR Room Sketch Designer

## Open Tool

[Open IR Room Sketch Designer](tools/ir-room-sketch-designer/){:target="_blank" rel="noopener noreferrer" .utility-link}

## Purpose

The IR Room Sketch Designer plans synthetic ambisonic impulse-response banks for
`3OAFX Synthetic Ambisonic IR Bank`. It sketches room dimensions,
source/listener geometry, direction groups, early-reflection timing, estimated
decay, material behavior, and the channel blocks used by the rendered bank.

It is a spatial IR sketcher, not a physically exact room simulator. The goal is
to design plausible, exaggerated, or impossible ambisonic reverb behavior that
can be rendered as encoded impulse-response banks.

## Room Views

The main display can show plan, side, bank-map, reflection-layer, matrix, and
3D views. Top and side views include chamber geometry. Drag the field position
to move the source/listener frame through the room and chamber geometry. In
Bank Map view, drag IR group points to place where each directional impulse
response is gathered.

The reflection-layer view shows all IR groups across time. Its timing display
is weighted toward the early part of the impulse, where direct sound and early
reflections are easiest to compare.

## IR Groups

Bank controls step through each IR group and show the group's AED position,
source position, and channel block. The Bank Matrix summarizes direct arrival,
first reflection, and relative early energy for each group.

For higher-order ambisonic workflows, the group layout defines which directional
IRs are produced and how they are arranged for the REAPER render script.

## Room Variation

The main room can be rectangular, trapezoid, wedge-shaped, skewed, diamond/lens,
or folded. Chambers can be added to any side of the room, including nested
chains. Chambers may use their own material profiles and polygonal or folded
shapes.

When the main room is not rectangular, chamber openings snap to the selected
polygon edge so chambers share a boundary with the room. `Strangeness /
topology bias` steers generated sketches toward folded shapes, all-side
chambers, nested chambers, stronger field offsets, and more varied chamber
coupling.

One or more exterior openings can be added to the main room. These are
interpreted as energy escape boundaries rather than chambers: they thin the
estimated late tail and mark where the room opens to the outside in JSON and
glTF exports. Overlapping chamber or exterior openings are merged in the glTF
view so the model reads as a single cutout.

## REAPER Use

The JSON export is intended for `3OAFX Synthetic Ambisonic IR Bank`, not
`3OAFX Offline Renderer`. In REAPER, open `3OAFX Synthetic Ambisonic IR Bank`
and use `Load Room Sketch JSON` to import the sketch. That renderer uses the
room polygon, chamber network, exterior openings, Bank Map group positions, and
material settings when creating encoded ambisonic IR banks.

Those generated IR banks can then be used with `3OAFX Offline Ambisonic
Convolve` for ambisonic convolution.

## Export

Export JSON to save the room, chamber, material, exterior-leak, and
direction-bank settings for the REAPER workflow. The glTF export writes a
simple 3D model of the main room, chambers, openings, field center, and IR
group positions for viewing or archiving the sketched room alongside rendered
impulse responses.
