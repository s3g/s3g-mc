#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPTS="$ROOT/Scripts/s3g-mc"

if [[ ! -d "$SCRIPTS" ]]; then
  printf 'missing Scripts/s3g-mc directory: %s\n' "$SCRIPTS" >&2
  exit 2
fi

FILES_TMP="$(mktemp)"
rg -l '^-- @category MIDI Composition' "$SCRIPTS" --glob '*.lua' | sort > "$FILES_TMP"
FILE_COUNT="$(wc -l < "$FILES_TMP" | tr -d ' ')"

failures=0

check() {
  local label="$1"
  local pattern="$2"
  shift 2
  local tmp
  tmp="$(mktemp)"
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    rg --pcre2 -n "$pattern" "$file" "$@" >> "$tmp" || true
  done < "$FILES_TMP"
  if [[ -s "$tmp" ]]; then
    printf '\nFAIL: %s\n' "$label"
    cat "$tmp"
    failures=$((failures + 1))
  fi
  rm -f "$tmp"
}

printf 's3g-mc strict MIDI GUI audit\n'
printf 'root: %s\n' "$ROOT"
printf 'files: %s\n' "$FILE_COUNT"

check \
  'visible raw combo/input widgets; use shared left-label hidden-ID row helpers' \
  'ImGui\.(Combo|InputInt|InputDouble|InputText)\(ctx, "(?!##)'

check \
  'visible raw sliders; use shared custom slider rows' \
  'ImGui\.Slider(Int|Double|Float)\(ctx, "(?!##)'

check \
  'separator outlines; use section labels or spacing instead' \
  'ImGui\.Separator\(ctx\)'

check \
  'local style color pushes; use shared theme helpers or draw-list semantic color' \
  'PushStyleColor'

check \
  'ordinary TextColored calls; use theme text/muted/status helpers' \
  'TextColored'

check \
  'mixed-case collapsing headers; fixed section labels must be CAPS' \
  'CollapsingHeader\(ctx, "[A-Z][a-z]'

check \
  'fixed buttons should use all-CAPS visible labels' \
  'ImGui\.(SmallButton|Button)\(ctx, "[^"#]*[a-z][^"#]*(##|")'

check \
  'old visible labels on combo/input fallbacks; fallback widgets must also use hidden IDs' \
  'ImGui\.(Combo|InputInt|InputDouble|InputText)\(ctx, label'

if (( failures > 0 )); then
  rm -f "$FILES_TMP"
  printf '\nStrict MIDI GUI audit failed: %d rule group(s).\n' "$failures" >&2
  exit 1
fi

rm -f "$FILES_TMP"
printf '\nStrict MIDI GUI audit passed.\n'
