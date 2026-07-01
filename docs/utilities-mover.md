---
layout: default
title: Mover
utility_nav: true
prev_page:
  title: IR Room Sketch Designer
  url: /utilities-ir-room-sketch-designer.html
next_page:
  title: References
  url: /references.html
toc:
  - title: Open Tool
    href: "#open-tool"
  - title: Purpose
    href: "#purpose"
  - title: Groups And Scenes
    href: "#groups-and-scenes"
  - title: Motion Rules
    href: "#motion-rules"
  - title: Preview
    href: "#preview"
  - title: REAPER Export
    href: "#reaper-export"
  - title: Browser Link
    href: "#browser-link"
---

# Mover

## Open Tool

[Open Mover](tools/mover/){:target="_blank" rel="noopener noreferrer" .utility-link}

## Purpose

Mover is a browser-based spatial motion designer for banked 8-source
third-order ambisonic motion. It is meant for composing motion first, then
writing that motion into REAPER as editable automation.

## Groups And Scenes

Each group contains up to eight sources. Up to eight groups can be used, giving
a practical target of 64 source points. Groups share the selected motion bank
and scene structure but can be offset so their points do not simply overlap.

Motion scenes store the generated source state, hold time, morph time, and
scene name. `Auto Next` advances through the scenes in order during preview.
`Generate A-H` creates a full scene set and can vary hold/morph timing.

## Motion Rules

Motion banks provide families of movement such as orbit, weave, lattice, frame,
trace, pulse, suspend, leap, field, molec, fluid, forsy, flock, eco, contact,
march, procession, xenak, cardew, path, and scatter. Variants change the local
behavior within a bank.

`Generate Motion` creates a new seeded variant for the active scene. Captured
motion can then be held, morphed into the next scene, and exported as part of a
banked motion score.

## Preview

The main view previews point position, path preview, optional centroid display,
neighbor-link analysis, and camera views. Top, side, and 3/4 views are useful
for checking whether the spatial behavior is clear before exporting.

The analysis layer can operate across all groups or only the active group.
Neighbor links draw local constellations between nearby points rather than
connecting every point to every other point.

## REAPER Export

Exported JSON can be loaded in REAPER with `Load Mover JSON`. The loader
creates encoder tracks and writes source motion as automation for `s3g 8ch 3OA
Object Encoder`.

The browser utility is the design surface; REAPER remains the place where the
automation is placed, edited against media, and rendered.

## Browser Link

After loading a Mover JSON in REAPER, run `Mover Browser Link` to reopen the
same JSON in the browser and follow REAPER transport. The link starts a local
browser view, writes a small playhead file while the ReaScript window is open,
and lets the Mover visual act as a large monitor for the automation already
written into REAPER.
