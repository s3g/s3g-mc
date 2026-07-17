# s3g-mc UI Consistency Audit

This audit is a working checklist for bringing the ReImGui tools closer to the current s3g visual language. It is intentionally practical: each item should point to something visible, clickable, or confusing for users.

Run the automated pass with:

```sh
tools/audit-reimgui-style.sh
```

The audit output is a warning list, not a failure list. Some color helpers and semantic canvas colors are expected to remain.

## 1. Shared Theme Adoption

Target: every ReImGui tool should install `s3g-mc ImGui Theme.lua`, then use `theme.palette(ImGui)` or helper calls for neutral UI colors.

Look for:
- Scripts that install the theme but still keep a separate neutral `COLORS` / `COLOR_*` palette.
- Direct `ImGui.TextColored` calls for ordinary labels, status, or explanatory text.
- Direct `ImGui.PushStyleColor` outside the theme module.

Allowed exceptions:
- Canvas point colors, meters, routing flows, warning/error states, and track/source identity colors.
- Small local `color()` / `rgba()` helpers used only for semantic canvas drawing.
- Shared theme style scopes such as `theme.push_soft_panel()` / `theme.pop_soft_panel()` are allowed; duplicated local style stacks are not.
- `s3g-mc Package Browser` keeps its own package-index visual language and is excluded from the broad ReImGui warning audit.

## 2. Neutral Base / Semantic Color

Target: the overall UI should be grayscale, with color reserved for meaning.

Look for:
- Bright cyan, green, or blue used as generic selected/active state.
- Saturated colors used for ordinary text or panel borders.
- Multiple scripts using different meanings for the same color.

Current rule:
- Selected/armed states should use muted gray or amber unless the color carries domain meaning.
- Speaker/source points can use semantic color, but the surrounding UI should stay neutral.

## 3. Text Hierarchy

Target: text should match the softened s3g-dsp GUI tone.

Look for:
- Bright white labels in dense panels.
- Bold/attention-like text for ordinary labels.
- Help or explanatory text competing visually with controls.
- Inconsistent labels for equivalent concepts, such as `Output gain`, `Inserted track gain`, `Wet mix`, `Normalize dB`.

Preferred helpers:
- `theme.text()` for primary labels.
- `theme.muted()` for help, counts, and secondary status.
- `theme.status()` for warning/error/ok status.

Control-label rule:
- Fixed controls should use compact CAPS labels: buttons, section labels, slider labels, checkbox labels, and menu labels.
- Dynamic/status text should stay readable in normal sentence case.
- Abbreviate only where context is clear, such as `PTRN`, `PSET`, `PROB`, `VELO`, `ACNT`, `NLEN`, and `MIDI`.
- Menu option text can remain readable/title-case; the menu label is the part that follows the CAPS rule.

## 4. Control Grammar

Target: the same kind of choice should use the same kind of control across scripts.

Look for:
- Named modes implemented as rows of buttons where a combo would be clearer.
- Binary state implemented as a text button where a checkbox/toggle would be clearer.
- Sliders used for discrete named choices.
- Numeric entry fields that visually fight sliders.

Rules:
- Combo menu: named modes, algorithm families, output layouts, order, routing mode.
- Checkbox: true/false state.
- Slider: continuous values and bounded numeric values.
- Button: commands that do something now, such as render, write automation, repair, reset, show lanes.
- MIDI Composition strict rule: visible combo/input rows must use the shared left-label hidden-ID helper and render without the default outlined ImGui frame. Raw visible `ImGui.Combo/Input*` calls are audit failures.

## 5. Camera / Spatial View Grammar

Target: spatial tools should feel related to the s3g-dsp encoder/decoder GUIs.

Look for:
- Inconsistent labels: `top` vs `Top`, `front` vs `Front`, `3/4 view` vs `3/4`.
- Mixed-case diagram titles in the upper-left of canvas/field views.
- Zoom controls separated from view buttons.
- Missing camera memory where a view is part of a repeated workflow.
- Top-view azimuth conventions that do not follow `0` up, `-90` right, `+90` left.

Preferred row:
- `-` / `+` zoom next to `TOP`, `SIDE` or `FRONT`, `3/4` where applicable.
- View buttons should be compact and consistently ordered inside a family.
- Upper-left diagram titles should be CAPS.

## 6. Panel / Collapse Behavior

Target: visible disclosure affordances should be truthful.

Look for:
- `CollapsingHeader` used for sections that should always be visible.
- Static title bars containing `+` or `-` without actual collapse behavior.
- Too many default-open collapsing sections causing dense vertical scrolling.

Rule:
- If it looks collapsible, it should collapse.
- If it is always visible, use a static header or muted section label.

## 7. Layout Density And Spacing

Target: compact, readable, repeatable spacing.

Look for:
- Long chains of `SameLine()` that can overlap in narrower windows.
- Hard-coded item widths that differ wildly between related scripts.
- One-line UI blocks with many controls, which are hard to read and hard to audit.
- Footer buttons overlapping status text.

Suggested convention:
- Important command buttons: roughly 90-110 px wide unless label needs more.
- Dense sliders: use shared helper widths where possible.
- Custom slider row: visible numeric sliders should use the shared s3g-mc helper instead of raw `ImGui.Slider*` controls.
- Slider labels: rendered slider labels should be short CAPS, 8 characters or fewer. Add semantic abbreviations for recurring labels; rely on the helper's automatic compaction only as a safety net.
- MIDI Composition scripts have a strict audit: run `tools/audit-midi-gui-style.sh` and resolve failures before considering that family cleaned up.
- Split large tools into clear sections or child regions, not nested decorative panels.
- Repeated lane/channel controls should read like a table: consistent label width, slider width, and value position.
- For dense lane/channel editors, split content into compact rows instead of forcing horizontal scrolling.
- Use muted identity-color row washes only when the color maps to semantic content such as a lane, source, track, or geometry color.

## 8. Family Consistency

Target: related tools should share interaction patterns.

Families to audit together:
- Package/browser tools.
- Channel mixing and routing tools.
- Automation capture/composer tools.
- Procedural render tools.
- 3OAFX tools.
- Panner/controller tools.
- Ambisonic utility tools.
- Browser utilities in `Scripts/s3g-mc/utilities`.

Look for:
- Same concept named differently across a family.
- Same workflow placed in different parts of the window.
- Different camera controls in tools that draw the same spatial field.

## 9. Runtime Safety / Error UI

Target: failures should be visible but not visually alarming unless action is needed.

Look for:
- Raw error text in bright colors.
- Repair/rescan/install guidance hidden below fold.
- Status messages that do not persist long enough to read.

Rules:
- Use `theme.status(..., "warn")` for action-needed messages.
- Use `theme.status(..., "danger")` for blocked or destructive problems.
- Use muted text for contextual hints.

## 10. Documentation Sync

Target: when GUI rules change, update this checklist and `docs/reimgui-style-guide.md`.

Look for:
- New visual convention added in one family but not documented.
- Audit false positives that should become explicit exceptions.
- Repeated manual fixes that should become a helper in the shared theme module.

## 11. Browser Utilities

Target: browser-based score/design utilities should feel related to the ReImGui and s3g-dsp tools even though they use HTML/CSS/canvas.

Look for:
- Saturated legacy cyan/green/purple colors used as generic UI states.
- Different button, panel, and text hierarchy from the ReImGui tools.
- Camera/view labels that diverge from `TOP`, `SIDE`, `FRONT`, `3/4`, and zoom conventions.
- Canvas colors that should remain semantic versus CSS chrome that should become neutral.

Allowed exceptions:
- OKLCH/AED point color, image-derived color, waveform/score data, exported SVG/GLB content, and source/track identity colors.
