#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

run_warn() {
  local label="$1"
  shift
  printf '\n== %s ==\n' "$label"
  "$@" || true
}

run_strict() {
  local label="$1"
  shift
  printf '\n== %s ==\n' "$label"
  "$@"
}

printf 's3g-mc GUI weak-point audit suite\n'
printf 'root: %s\n' "$ROOT"
printf 'mode: report current drift; do not rewrite GUI code\n'

run_warn "repo-wide ReaImGui warning pass" bash "$ROOT/tools/audit-reimgui-style.sh" "$ROOT"
run_strict "MIDI composition strict pass" bash "$ROOT/tools/audit-midi-gui-style.sh" "$ROOT"
run_strict "routing and mixer strict pass" bash "$ROOT/tools/audit-routing-mixer-gui-style.sh" "$ROOT"
run_strict "automation utilities strict pass" bash "$ROOT/tools/audit-automation-utilities-gui-style.sh" "$ROOT"
run_strict "procedural synthesis strict pass" bash "$ROOT/tools/audit-procedural-synthesis-gui-style.sh"
run_strict "spectral/convolution strict pass" bash "$ROOT/tools/audit-spectral-gui-style.sh" "$ROOT"
run_strict "offline synthesis / IR strict pass" bash "$ROOT/tools/audit-offline-synthesis-ir-gui-style.sh" "$ROOT"
run_strict "panner strict pass" bash "$ROOT/tools/audit-panner-gui-style.sh" "$ROOT"

printf '\nGUI weak-point audit suite complete.\n'
