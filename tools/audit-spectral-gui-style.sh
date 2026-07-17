#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
scripts="$ROOT/Scripts/s3g-mc"

fail=0

check_render_footer() {
  local file="$1"
  local child_id="$2"
  local rel="${file#$ROOT/}"
  if [[ ! -f "$file" ]]; then
    echo "FAIL $rel: missing file"
    fail=1
    return
  fi
  if ! grep -q "BeginChild(ctx, \"$child_id\"" "$file"; then
    echo "FAIL $rel: tall spectral render windows should keep controls in a scrollable child"
    fail=1
  fi
  if ! grep -q '\.footer_buttons' "$file"; then
    echo "FAIL $rel: render/cancel controls should use the fixed shared footer helper"
    fail=1
  fi
}

check_render_footer "$scripts/Multichannel Spectral Profile Tool Library.lua" "##spectral_profile_controls"
check_render_footer "$scripts/Render MC Impulse Field.lua" "##impulse_field_controls"
check_render_footer "$scripts/Spectral Shaper.lua" "##spectral_shaper_controls"
check_render_footer "$scripts/Spectral Morph.lua" "##spectral_morph_controls"
check_render_footer "$scripts/Convolve selected items.lua" "##convolve_controls"
check_render_footer "$scripts/Chaotic Resonant EQ.lua" "##chaotic_resonant_eq_controls"

compact_files=(
  "$scripts/Spectral Freeze.lua"
  "$scripts/Spectral Accumulate.lua"
  "$scripts/Spectral Blur.lua"
  "$scripts/Spectral Step Drunk Freeze.lua"
  "$scripts/Spectral Trace.lua"
  "$scripts/Spectral Spatializer.lua"
  "$scripts/Cross Synthesis.lua"
)

for file in "${compact_files[@]}"; do
  rel="${file#$ROOT/}"
  if [[ ! -f "$file" ]]; then
    echo "FAIL $rel: missing file"
    fail=1
    continue
  fi
  if grep -n 'begin_section(ImGui, ctx, "Output"' "$file"; then
    echo "FAIL $rel: compact spectral GUIs should fold output/normalize controls into the main toolbox"
    fail=1
  fi
  if ! grep -q '\.footer_buttons' "$file"; then
    echo "FAIL $rel: compact spectral render/cancel controls should use the shared footer helper"
    fail=1
  fi
  if ! grep -q 'section_h' "$file"; then
    echo "FAIL $rel: compact spectral window height should be derived from section height"
    fail=1
  fi
done

if grep -nE 'body_h = math\.min\(body_target_h, math\.max\((320|360),' \
  "$scripts/Multichannel Spectral Profile Tool Library.lua" \
  "$scripts/Render MC Impulse Field.lua" \
  "$scripts/Spectral Shaper.lua" \
  "$scripts/Spectral Morph.lua" \
  "$scripts/Convolve selected items.lua" \
  "$scripts/Chaotic Resonant EQ.lua"; then
  echo "FAIL spectral footer windows: content-bounded bodies should not use generic 320/360px minimum heights"
  fail=1
fi

if grep -nE '"(OFFLINE NUMPY RENDER|RENDERS OFFLINE|NUMPY-BACKED OFFLINE|WRITES A NEW|SELECT .*WAV-BACKED)' "$scripts/Multichannel Spectral Profile Tool Library.lua" "$scripts/3OAFX Spectral Profile Tool Library.lua"; then
  echo "FAIL spectral profile GUI libraries: do not repeat Package Browser description text inside the GUI"
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "spectral/convolution GUI style audit passed"
