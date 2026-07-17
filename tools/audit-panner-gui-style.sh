#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPTS="$ROOT/Scripts/s3g-mc"

if [[ ! -d "$SCRIPTS" ]]; then
  printf 'missing Scripts/s3g-mc directory: %s\n' "$SCRIPTS" >&2
  exit 2
fi

FILES_TMP="$(mktemp)"
rg --files "$SCRIPTS" --glob '*Panner*.lua' | sort -u > "$FILES_TMP"
FILE_COUNT="$(wc -l < "$FILES_TMP" | tr -d ' ')"

failures=0

check() {
  local label="$1"
  local pattern="$2"
  local tmp
  tmp="$(mktemp)"
  while IFS= read -r file; do
    [[ -n "$file" && -f "$file" ]] || continue
    rg --pcre2 -n "$pattern" "$file" >> "$tmp" || true
  done < "$FILES_TMP"
  if [[ -s "$tmp" ]]; then
    printf '\nFAIL: %s\n' "$label"
    cat "$tmp"
    failures=$((failures + 1))
  fi
  rm -f "$tmp"
}

check_file_has() {
  local label="$1"
  local pattern="$2"
  local tmp
  tmp="$(mktemp)"
  while IFS= read -r file; do
    [[ -n "$file" && -f "$file" ]] || continue
    if ! rg -q "$pattern" "$file"; then
      printf '%s\n' "$file" >> "$tmp"
    fi
  done < "$FILES_TMP"
  if [[ -s "$tmp" ]]; then
    printf '\nFAIL: %s\n' "$label"
    cat "$tmp"
    failures=$((failures + 1))
  fi
  rm -f "$tmp"
}

printf 's3g-mc panner GUI audit\n'
printf 'root: %s\n' "$ROOT"
printf 'files: %s\n' "$FILE_COUNT"

check \
  'legacy neutral COLORS palette; use CANVAS for semantic drawing and theme helpers for UI chrome' \
  'local COLORS =|COLORS\.'

check \
  'ordinary TextColored calls; use muted_text/theme helpers unless text is semantic canvas drawing' \
  'TextColored'

check \
  'mixed-case collapsing headers; use shared toolbox_header CAPS titles' \
  'CollapsingHeader\(ctx, "[A-Z][a-z]'

check \
  'old camera labels; use 3/4, TOP, FRONT in panner controls' \
  '"3/4 view"|"Top"|"Front"|"top##cam"|"front##cam"'

check \
  'fixed buttons should use all-CAPS visible labels' \
  'ImGui\.(SmallButton|Button)\(ctx, "[^"#]*[a-z][^"#]*(##|")'

check \
  'diagram title strings must be CAPS in the upper-left canvas title position' \
  'DrawList_AddText\(draw_list, x0 \+ 14, y0 \+ 14, CANVAS\.text, "[^"]*[a-z][^"]*"\)'

check_file_has \
  'missing shared toolbox helper' \
  'toolbox_header'

check_file_has \
  'missing real soft-panel toolbox child region' \
  '##panner_toolbox_area'

check_file_has \
  'missing shared slider row path for capped panner labels' \
  'ui_theme\.slider_row'

if (( failures > 0 )); then
  rm -f "$FILES_TMP"
  printf '\nPanner GUI audit failed: %d rule group(s).\n' "$failures" >&2
  exit 1
fi

rm -f "$FILES_TMP"
printf '\nPanner GUI audit passed.\n'
