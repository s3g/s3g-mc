# s3g-mc ReImGui Style Guide

This is the ReImGui-side companion to the `s3g-dsp` GUI style guide. The goal is not pixel-perfect Cocoa rendering inside REAPER; it is the same interaction grammar.

## Shared Look

- Use the shared `s3g-mc ImGui Theme.lua` module for windows, text, panels, frames, sliders, tabs, and buttons.
- `s3g-mc Package Browser` is an intentional exception. It is a package-index and launcher surface with its own settled visual feel; do not force toolbox/panel cleanup rules onto it unless revisiting that browser specifically.
- Browser utilities should mirror the same neutral chrome in CSS: dark panels, gray borders, muted text, gray active states, and color reserved for score data, spatial identity, meters, or exported visual content.
- Keep the base UI grayscale: near-black background, dark panel fills, thin gray borders, muted gray labels, and regular-weight monospaced text.
- Use color only when it carries meaning: warning, status, track color, signal flow, meters, spatial identity, or selected/armed state.
- Prefer soft gray active controls. Avoid bright cyan/green as a generic selected state.

## Panels And Headers

- A visible `+` or `-` means the header is actually collapsible. Static sections should have a plain title or separator, not a fake disclosure marker.
- Keep toolbox sections compact and aligned. Do not add nested panel containers unless the content is a specific canvas, matrix, meter, or editor.
- When a MIDI tool needs the darker reference toolbox/panel look from Polymetric Drum States, use the shared theme `push_soft_panel` / `pop_soft_panel` helpers. Do not duplicate local `PushStyleColor` stacks.
- Use checkboxes/buttons for binary state, combo menus for named choices, and sliders for continuous values.
- Use CAPS for fixed controls: buttons, section labels, slider labels, checkbox labels, and menu labels. Leave dynamic/status text readable in normal sentence case.
- Use the shared custom slider row for visible numeric sliders. Avoid raw `ImGui.Slider*` widgets in styled toolboxes except as fallback code inside the helper itself.
- Slider row labels must fit the fixed label column. Use smart CAPS abbreviations and keep rendered labels to 8 characters or fewer; the shared helper enforces this as a last-resort guard.
- Use the shared menu/input rows for visible menus and numeric/text entry: left CAPS label, hidden ImGui ID, borderless neutral frame. A source-level wrapper is not enough if it renders the default outlined ImGui control.
- Avoid redundant section labels. If the toolbox title or row label already names the task, do not repeat it as a mini-header.
- Separate selection rows from action rows. For example, state selectors such as `A B C D` should sit apart from commands such as `ADD`, `RAND`, and `DELETE`.
- When a label/action relationship is obvious, keep it on one row: `BANK [menu] APPLY` is clearer than a separate `BANK` title plus another `BANK` row.
- In repeated rows, align controls like a small table: shared label widths, shared slider widths, and consistent value columns.
- Use two or three compact rows for dense repeated data instead of one horizontally scrolling row.
- For lane/channel rows, use muted identity color as a background wash across the whole logical block. Use brighter identity color only for small markers such as lane numbers.
- In dense ReaImGui row blocks, prefer manual draw-list backgrounds over nested child windows and local style stacks. After manual cursor positioning, submit a real item such as `Dummy()` so ImGui can measure the row.

## Spatial And Canvas Tools

- Match the s3g-dsp spatial convention where possible: `TOP`, `SIDE`, `3/4`, with `-` / `+` zoom immediately to the left when zoom is exposed.
- In top-view AED canvases, azimuth `0` degrees is up, `-90` is right, and `+90` is left.
- Diagram/canvas title text in the upper-left should be CAPS, matching the MIDI diagram convention and panner family.
- Speaker/source IDs should remain readable muted gray text. Spatial color can identify points, but it should not become the overall UI color.

## Audit Targets

Use `tools/audit-reimgui-style.sh` as a warning pass. It looks for local hardcoded color palettes, direct `PushStyleColor` / `TextColored` calls, bright generic active colors, camera-label drift, density risks, and old canvas scripts that should eventually move to the shared theme.

See `docs/s3g-mc-ui-audit.md` for the full checklist, review categories, and allowed exceptions.

For MIDI Composition scripts, run `tools/audit-midi-gui-style.sh` before calling a GUI cleanup complete. It is intentionally stricter than the repo-wide warning audit.
