#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme_file="$ROOT/Scripts/s3g-mc/s3g-mc ImGui Theme.lua"

files=(
  "$ROOT/Scripts/s3g-mc/Carto Synth MIDI Controller.lua"
  "$ROOT/Scripts/s3g-mc/Carto Synth Render.lua"
  "$ROOT/Scripts/s3g-mc/Lattice Synth MIDI Controller.lua"
  "$ROOT/Scripts/s3g-mc/Lattice Synth Render.lua"
  "$ROOT/Scripts/s3g-mc/Spectra Synth MIDI Controller.lua"
  "$ROOT/Scripts/s3g-mc/Spectra Synth Render.lua"
)

fail=0

if grep -nE 'return ImGui\.Slider(Int|Double|Float)\(' "$theme_file"; then
  echo "FAIL Scripts/s3g-mc/s3g-mc ImGui Theme.lua: slider_row must not fall back to raw ImGui sliders"
  fail=1
fi

for file in "${files[@]}"; do
  rel="${file#$ROOT/}"
  if [[ ! -f "$file" ]]; then
    echo "FAIL $rel: missing file"
    fail=1
    continue
  fi

  if ! grep -q 's3g-mc ImGui Theme' "$file"; then
    echo "FAIL $rel: missing shared ImGui theme import"
    fail=1
  fi

  if ! grep -q 'push_soft_panel' "$file"; then
    echo "FAIL $rel: missing soft gray tool/control panel"
    fail=1
  fi

  if grep -nE 'ImGui\.Slider(Int|Double|Float)\(' "$file"; then
    echo "FAIL $rel: visible sliders must use theme.slider_* helpers"
    fail=1
  fi

  if grep -nE 'ImGui\.BeginCombo\(' "$file"; then
    echo "FAIL $rel: visible menus must use theme.combo_row helpers"
    fail=1
  fi

  if grep -nE 'ImGui\.Input(Double|Int|Text)\(ctx, "[^#]' "$file"; then
    echo "FAIL $rel: visible inputs must use theme.input_*_row helpers"
    fail=1
  fi

  if grep -nB1 -E 'theme\.(slider|combo|input)_' "$file" | grep -q 'SameLine'; then
    echo "FAIL $rel: shared row helpers should not be placed after SameLine"
    fail=1
  fi

  if grep -nE 'theme\.(combo_row|slider_(int|double)|input_(int|double|text)_row).*,[[:space:]]*width[[:space:]]*\)' "$file"; then
    echo "FAIL $rel: procedural row controls should use full shared row width, not per-call width overrides"
    fail=1
  fi

  if grep -nE 'ImGui\.(SmallButton|Button)\(ctx, "[^"#]*[a-z][^"#]*(##|")' "$file"; then
    echo "FAIL $rel: visible button literals must be all caps before ##id"
    fail=1
  fi

  if grep -nE 'ImGui\.Checkbox\(ctx, "[^"#]*[a-z][^"#]*(##|")' "$file"; then
    echo "FAIL $rel: visible checkbox labels must be all caps before ##id"
    fail=1
  fi

  if grep -nE 'ChildFlags_Borders|BeginChild\([^\n]*(true|child_flags)' "$file"; then
    echo "FAIL $rel: tool/control children should be borderless"
    fail=1
  fi
done

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "procedural synthesis GUI style audit passed"
