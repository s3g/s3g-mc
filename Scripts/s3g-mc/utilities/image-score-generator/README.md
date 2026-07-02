# s3g-mc Image Score

Standalone browser tool for composing `512 x 256` PNG image scores for
`3OAFX Image Sonogram Field`.

Open `index.html` in a browser. No build step or local server is required.

## Mapping

- X axis: time
- Y axis: frequency
- Color hue/lightness/chroma: AED position for the renderer
- Alpha or exported mask PNG: amplitude

## Exports

- `Export Color PNG`: color layer only.
- `Export Alpha PNG`: grayscale alpha/mask layer.
- `Export Mask PNG`: the selected amplitude preview algorithm as a PNG.
- `Export RGBA Score`: color layer with the alpha layer in the PNG alpha
  channel. Use this when `3OAFX Image Sonogram Field` is set to `Alpha`.

## First Use

1. Draw directly, or choose a generator rule and press `Generate`.
2. Check the amplitude preview.
3. Export an RGBA score, or export a color PNG plus a separate mask PNG.
4. Load the exported PNG in `3OAFX Image Sonogram Field`.
