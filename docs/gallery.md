---
layout: default
title: Gallery
prev_page:
  title: Process Guides
  url: /process-guides.html
next_page:
  title: References
  url: /references.html
toc:
  - title: Interface Screenshots
    href: "#interface-screenshots"
---

# Gallery

Screenshots of selected s3g-mc controllers, render tools, panners, and workflow helpers. Click any image to browse the gallery at larger size.

## Interface Screenshots

<div class="gallery-grid gallery-mosaic" data-gallery>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/PackageBrowser.png" aria-label="Open Package Browser screenshot"><img src="assets/images/gallery/PackageBrowser.png" alt="s3g-mc Package Browser"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/128chAutomationMixer.png" aria-label="Open 128ch Automation Mixer screenshot"><img src="assets/images/gallery/128chAutomationMixer.png" alt="128ch Automation Mixer"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/MCtoStereoAutogain.png" aria-label="Open MC to Stereo Autogain screenshot"><img src="assets/images/gallery/MCtoStereoAutogain.png" alt="MC to Stereo Autogain"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/LayoutPanner.png" aria-label="Open Layout Panner screenshot"><img src="assets/images/gallery/LayoutPanner.png" alt="Layout Panner"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/25chLBAPDomePanner.png" aria-label="Open 25ch LBAP Dome Panner screenshot"><img src="assets/images/gallery/25chLBAPDomePanner.png" alt="25ch LBAP Dome Panner"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/17chCubeXYZPanner.png" aria-label="Open 17ch Cube XYZ Panner screenshot"><img src="assets/images/gallery/17chCubeXYZPanner.png" alt="17ch Cube XYZ Panner"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/12chDodecaPanner.png" aria-label="Open 12ch Dodeca Panner screenshot"><img src="assets/images/gallery/12chDodecaPanner.png" alt="12ch Dodeca Panner"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/3OAFXSendReturnController.png" aria-label="Open 3OAFX Send Return Controller screenshot"><img src="assets/images/gallery/3OAFXSendReturnController.png" alt="3OAFX Send Return Controller"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/3OAFXOfflineRenderer.png" aria-label="Open 3OAFX Offline Renderer screenshot"><img src="assets/images/gallery/3OAFXOfflineRenderer.png" alt="3OAFX Offline Renderer"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/SpatialAutomationComposer.png" aria-label="Open Spatial Automation Composer screenshot"><img src="assets/images/gallery/SpatialAutomationComposer.png" alt="Spatial Automation Composer"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/ConvolveSelectedItems.png" aria-label="Open Convolve Selected Items screenshot"><img src="assets/images/gallery/ConvolveSelectedItems.png" alt="Convolve Selected Items"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/SpectralShaper.png" aria-label="Open Spectral Shaper screenshot"><img src="assets/images/gallery/SpectralShaper.png" alt="Spectral Shaper"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/DenseGrainCloud.png" aria-label="Open Dense Grain Cloud screenshot"><img src="assets/images/gallery/DenseGrainCloud.png" alt="Dense Grain Cloud"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/FataMorganaResynth.png" aria-label="Open Fata Morgana Resynth screenshot"><img src="assets/images/gallery/FataMorganaResynth.png" alt="Fata Morgana Resynth"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/LoopDrift.png" aria-label="Open Loop Drift screenshot"><img src="assets/images/gallery/LoopDrift.png" alt="Loop Drift"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/RenderMCCartoSynth.png" aria-label="Open Carto Synth Render screenshot"><img src="assets/images/gallery/RenderMCCartoSynth.png" alt="Carto Synth Render"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/MCCartoSynth.png" aria-label="Open Carto Synth screenshot"><img src="assets/images/gallery/MCCartoSynth.png" alt="Carto Synth"></button>
  <button class="gallery-tile" type="button" data-full="assets/images/gallery/ResonantTerrain.png" aria-label="Open Resonant Terrain screenshot"><img src="assets/images/gallery/ResonantTerrain.png" alt="Resonant Terrain"></button>
</div>

<div class="gallery-lightbox" data-gallery-lightbox aria-hidden="true">
  <button class="gallery-close" type="button" data-gallery-close aria-label="Close gallery">x</button>
  <button class="gallery-arrow prev" type="button" data-gallery-prev aria-label="Previous screenshot">‹</button>
  <img data-gallery-image src="" alt="">
  <button class="gallery-arrow next" type="button" data-gallery-next aria-label="Next screenshot">›</button>
</div>

<script>
(() => {
  const tiles = Array.from(document.querySelectorAll("[data-gallery] .gallery-tile"));
  const lightbox = document.querySelector("[data-gallery-lightbox]");
  const image = document.querySelector("[data-gallery-image]");
  const close = document.querySelector("[data-gallery-close]");
  const prev = document.querySelector("[data-gallery-prev]");
  const next = document.querySelector("[data-gallery-next]");
  let current = 0;

  function show(index) {
    if (!tiles.length) return;
    current = (index + tiles.length) % tiles.length;
    const tile = tiles[current];
    const img = tile.querySelector("img");
    image.src = tile.dataset.full;
    image.alt = img ? img.alt : "";
    lightbox.setAttribute("aria-hidden", "false");
    document.body.classList.add("gallery-open");
  }

  function hide() {
    lightbox.setAttribute("aria-hidden", "true");
    document.body.classList.remove("gallery-open");
    image.src = "";
  }

  tiles.forEach((tile, index) => {
    tile.addEventListener("click", () => show(index));
  });

  close.addEventListener("click", hide);
  prev.addEventListener("click", () => show(current - 1));
  next.addEventListener("click", () => show(current + 1));
  lightbox.addEventListener("click", event => {
    if (event.target === lightbox) hide();
  });
  document.addEventListener("keydown", event => {
    if (lightbox.getAttribute("aria-hidden") === "true") return;
    if (event.key === "Escape") hide();
    if (event.key === "ArrowLeft") show(current - 1);
    if (event.key === "ArrowRight") show(current + 1);
  });
})();
</script>
