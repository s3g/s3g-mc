#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
scripts="$ROOT/Scripts/s3g-mc"

fail=0

compact_files=(
  "$scripts/Karplus Field.lua"
  "$scripts/IR Toolkit.lua"
  "$scripts/Subharmonic Bank.lua"
)

category_files=(
  "$scripts/Karplus Field.lua"
  "$scripts/Resonant Terrain.lua"
  "$scripts/Dense Grain Cloud.lua"
  "$scripts/EVP Field.lua"
  "$scripts/IR Toolkit.lua"
  "$scripts/Modal Terrain.lua"
  "$scripts/Partial Trace Resynth.lua"
  "$scripts/Subharmonic Bank.lua"
  "$scripts/Fata Morgana Resynth.lua"
  "$scripts/Mass Partial Field.lua"
)

local_seed_files=(
  "$scripts/Karplus Field.lua"
  "$scripts/Resonant Terrain.lua"
  "$scripts/Dense Grain Cloud.lua"
  "$scripts/EVP Field.lua"
  "$scripts/IR Toolkit.lua"
  "$scripts/Modal Terrain.lua"
  "$scripts/Partial Trace Resynth.lua"
  "$scripts/Subharmonic Bank.lua"
  "$scripts/Fata Morgana Resynth.lua"
  "$scripts/Mass Partial Field.lua"
)

local_combo_files=(
  "$scripts/EVP Field.lua"
  "$scripts/Modal Terrain.lua"
  "$scripts/Partial Trace Resynth.lua"
  "$scripts/Fata Morgana Resynth.lua"
)

for file in "${compact_files[@]}"; do
  rel="${file#$ROOT/}"
  if [[ ! -f "$file" ]]; then
    echo "FAIL $rel: missing file"
    fail=1
    continue
  fi
  if grep -nE 'section\((ctx, )?"Output"|"Output"' "$file"; then
    echo "FAIL $rel: compact Offline Synthesis / IR GUIs should fold output/normalize controls into the main toolbox"
    fail=1
  fi
  if grep -n 'ImGui\.Button(ctx, "RENDER"' "$file"; then
    echo "FAIL $rel: render/cancel controls should use the shared footer helper"
    fail=1
  fi
  if ! grep -q '\.footer_buttons' "$file"; then
    echo "FAIL $rel: missing shared footer helper"
    fail=1
  fi
  if ! grep -q 'section_h' "$file"; then
    echo "FAIL $rel: compact window height should be derived from section height"
    fail=1
  fi
done

for file in "${category_files[@]}"; do
  rel="${file#$ROOT/}"
  if [[ ! -f "$file" ]]; then
    echo "FAIL $rel: missing file"
    fail=1
    continue
  fi
  if grep -n 'ImGui\.Button(ctx, "RENDER"' "$file"; then
    echo "FAIL $rel: render/cancel controls should use the shared footer helper"
    fail=1
  fi
  if grep -nE 'section\((ctx, )?"Output"' "$file"; then
    echo "FAIL $rel: standalone Output sections are redundant; use Render, Render Safety, or fold controls into the relevant toolbox"
    fail=1
  fi
done

if ! grep -q 'input_int_width' "$scripts/s3g-mc ImGui Theme.lua"; then
  echo "FAIL shared theme: seed InputInt rows should use compact 10-digit width logic"
  fail=1
fi

if grep -nE '\["PEAK NORMALIZE( OUTPUT)?"\] = "PEAK"' "$scripts/s3g-mc ImGui Theme.lua" "$scripts/Spectral Offline Library.lua" "${local_seed_files[@]}"; then
  echo "FAIL peak normalize labels: use PK NORM, not PEAK, to avoid checkbox overlap"
  fail=1
fi

if ! grep -q 'combo_width(ImGui, ctx, labels' "$scripts/s3g-mc ImGui Theme.lua"; then
  echo "FAIL shared theme: combo rows should size to contained menu text"
  fail=1
fi

if ! grep -q 'input_int_width' "$scripts/Spectral Offline Library.lua"; then
  echo "FAIL spectral offline library: seed InputInt rows should use compact 10-digit width logic"
  fail=1
fi

if ! grep -q 'combo_width(ImGui, ctx, names' "$scripts/Spectral Offline Library.lua"; then
  echo "FAIL spectral offline library: combo rows should size to contained menu text"
  fail=1
fi

for file in "${local_seed_files[@]}"; do
  rel="${file#$ROOT/}"
  if ! grep -qE 'SetNextItemWidth\(ctx, ?math\.min\(control_w, ?104\)\)' "$file"; then
    echo "FAIL $rel: local seed InputInt helper should cap width to roughly 10 digits"
    fail=1
  fi
done

for file in "${local_combo_files[@]}"; do
  rel="${file#$ROOT/}"
  if ! grep -q 'combo_width' "$file"; then
    echo "FAIL $rel: local combo helper should size dropdowns to contained text"
    fail=1
  fi
done

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "offline synthesis / IR GUI style audit passed"
