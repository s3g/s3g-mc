#!/usr/bin/env bash
set -euo pipefail

repo="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
scripts="$repo/Scripts/s3g-mc"

files=(
  "$scripts/Vertical Timeline Navigator.lua"
  "$scripts/Transaural Crosstalk Canceller.lua"
  "$scripts/Snapshot Surface.lua"
  "$scripts/Focused FX Automation Capture.lua"
)

shared_panel_files=(
  "$scripts/Vertical Timeline Navigator.lua"
  "$scripts/Transaural Crosstalk Canceller.lua"
  "$scripts/Snapshot Surface.lua"
)

fail=0

check_absent() {
  local pattern="$1"
  local message="$2"
  if rg -n "$pattern" "${files[@]}" >/tmp/s3g_mc_audit_automation_hits.txt; then
    echo "FAIL: $message"
    cat /tmp/s3g_mc_audit_automation_hits.txt
    fail=1
  fi
}

check_absent_in() {
  local pattern="$1"
  local message="$2"
  shift 2
  if rg -n "$pattern" "$@" >/tmp/s3g_mc_audit_automation_hits.txt; then
    echo "FAIL: $message"
    cat /tmp/s3g_mc_audit_automation_hits.txt
    fail=1
  fi
}

check_present_file() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -n "$pattern" "$file" >/dev/null; then
    echo "FAIL: $message: $file"
    fail=1
  fi
}

check_absent 'ImGui\.Slider(Int|Double|Float)\(' "visible numeric controls must use shared slider helpers"
check_absent 'ImGui\.BeginCombo\(' "visible option sets must use shared combo helpers"
check_absent_in 'ImGui\.TextColored\(' "ordinary UI text must use theme text helpers" "${shared_panel_files[@]}"
check_absent 'ChildFlags_Borders|BeginChild\([^)]*,[^)]*,[^)]*,[^)]*(child_flags|true)' "tool areas should use borderless child regions"
check_absent 'ImGui\.(SmallButton|Button)\(ctx, "[^"#]*[a-z][^"#]*(##|")' "fixed buttons should use all-CAPS visible labels"
check_absent 'play_label = .*"(Play|Pause|Stop)"' "dynamic transport button labels should be all caps"
check_absent 'Checkbox\(ctx, "[A-Z][a-z][^"#]*"' "fixed checkboxes should use CAPS labels"

for file in "${files[@]}"; do
  check_present_file "$file" 's3g-mc ImGui Theme' "missing shared theme import"
done

for file in "${shared_panel_files[@]}"; do
  check_present_file "$file" 'push_soft_panel' "missing gray tool-area background"
done

check_present_file "$scripts/Focused FX Automation Capture.lua" 'theme\.begin_section' "focused FX should use the shared gray section renderer"
check_present_file "$scripts/Vertical Timeline Navigator.lua" '##vertical_timeline_tool_area' "vertical timeline should wrap controls in a gray tool area"
check_present_file "$scripts/Transaural Crosstalk Canceller.lua" '##transaural_tool_area' "transaural controls should use a gray tool area"
check_present_file "$scripts/Snapshot Surface.lua" '##snapshot_surface_side' "snapshot side controls should use a gray tool area"
check_present_file "$scripts/Snapshot Surface.lua" '##snapshot_footer_tool_area' "snapshot footer controls should use a gray tool area"
check_present_file "$scripts/Focused FX Automation Capture.lua" '##focused_fx_tool_area' "focused FX controls should use a gray tool area"

if (( fail )); then
  exit 1
fi

echo "automation utilities GUI style audit passed"
