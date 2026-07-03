# s3g-mc Displacement Score

Displacement Score designs a 24-point geometry transform for the 3OAFX virtual
speaker layer. The exported JSON is intended for offline 3OAFX processes that
decode to the 24-point direction layer, displace that layer, and then re-encode
to ACN/SN3D ambisonics.

The score stores the original 24 virtual speaker directions, named
displacement scenes, the polygon mesh that connects the directions, scale
controls, and basic metadata. Each scene is a whole-layout displacement state.
Scene methods can be combined with AED-style transforms such as azimuth
rotation, elevation shift, height-based twist, collapse toward the equator,
distance scaling, and distance flare. `AED transform` keeps the original
24-point layout and applies only those AED and distance controls. The mesh is
drawn through the active geometry, so the polygon surface follows the displaced
speaker field rather than staying fixed.

The time layer interpolates between displacement scenes across a normalized
0..1 timeline. A renderer can scale those frames to the selected media item or
offline render duration, making the displacement move through the process
rather than remain static. The first timeline position is pinned to the
original 24-point layout.

Use `Globe` for the camera-based 3D view or `Map` for a flattened
Peters-style equal-area projection. Shift-drag the globe view to rotate the
camera. Use the mouse wheel to zoom the globe view.

The heatmap colors the projected sphere as a virtual-speaker radiation field.
Each current point is hot at its center and falls away through warm and cool
regions. Cool areas show parts of the sphere with less nearby point influence.
Several color scales are available, including thermal, classic cold-hot,
inferno, viridis, magma, and greyscale. Turn off `Show points` to read the
heatmap or polygon without point markers and channel labels.
