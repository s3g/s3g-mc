#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
FILE="$ROOT/Scripts/s3g-mc/Spatial Automation Composer.lua"

if [[ ! -f "$FILE" ]]; then
  printf 'missing Spatial Automation Composer script: %s\n' "$FILE" >&2
  exit 2
fi

failures=0

check() {
  local label="$1"
  local pattern="$2"
  local tmp
  tmp="$(mktemp)"
  rg --pcre2 -n "$pattern" "$FILE" > "$tmp" || true
  if [[ -s "$tmp" ]]; then
    printf '\nFAIL: %s\n' "$label"
    cat "$tmp"
    failures=$((failures + 1))
  fi
  rm -f "$tmp"
}

check_has() {
  local label="$1"
  local pattern="$2"
  if ! rg -q "$pattern" "$FILE"; then
    printf '\nFAIL: %s\n%s\n' "$label" "$FILE"
    failures=$((failures + 1))
  fi
}

printf 's3g-mc Spatial Automation Composer GUI audit\n'
printf 'root: %s\n' "$ROOT"

check \
  'diagram title strings must be CAPS' \
  'DrawList_AddText\(draw_list, x \+ 14, y \+ 12, STYLE\.text, "[^"]*[a-z][^"]*"\)'

check \
  'old camera labels; use CAPS camera buttons' \
  '"top##motioncam"|"front##motioncam"|"up##motioncam"|"down##motioncam"|"left##motioncam"|"right##motioncam"'

check \
  'visible raw sliders; use shared slider row except fallback branches' \
  '^[[:space:]]*(changed, [^=]+ = )?ImGui\.Slider(Int|Double|Float)\(ctx, "'

check \
  'visible raw combo rows; use shared combo row except fallback branches' \
  '^[[:space:]]*if ImGui\.BeginCombo\(ctx, label,'

check \
  'mixed-case fixed buttons/checkboxes' \
  'ImGui\.(Button|Checkbox)\(ctx, "(Write automation|Close|Clear existing|Stop Preview|Play Preview|Reset Preview)'

check_has \
  'missing soft-panel control region' \
  'push_soft_panel'

check_has \
  'missing shared slider row path for capped labels' \
  'theme\.slider_row'

check_has \
  'missing shared combo row path' \
  'theme\.combo_row'

if (( failures > 0 )); then
  printf '\nSpatial Automation Composer GUI audit failed: %d rule group(s).\n' "$failures" >&2
  exit 1
fi

printf '\nSpatial Automation Composer GUI audit passed.\n'
