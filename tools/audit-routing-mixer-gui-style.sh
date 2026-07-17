#!/usr/bin/env bash
set -euo pipefail

repo="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
scripts="$repo/Scripts/s3g-mc"

files=(
  "$scripts/128ch Automation Mixer.lua"
  "$scripts/128ch Node Track Mixer.lua"
  "$scripts/128ch Ambisonic Node Track Mixer.lua"
  "$scripts/MC to Stereo Autogain.lua"
  "$scripts/Patch Routing View.lua"
)

fail=0

check_absent() {
  local pattern="$1"
  local message="$2"
  if rg -n "$pattern" "${files[@]}" >/tmp/s3g_mc_audit_routing_hits.txt; then
    echo "FAIL: $message"
    cat /tmp/s3g_mc_audit_routing_hits.txt
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

check_absent 'ImGui\.Slider(Int|Double|Float)\(' "visible numeric controls must use theme slider helpers"
check_absent 'ImGui\.BeginCombo\(' "visible option sets must use theme combo helpers"
check_absent 'ImGui\.TextColored\(' "visible status text must use shared theme text helpers"
check_absent 'ImGui\.(SmallButton|Button)\(ctx, "[^"#]*[a-z][^"#]*(##|")' "fixed buttons should use all-CAPS visible labels"
check_absent 'Checkbox\(ctx, "[A-Z][a-z][^"#]*"' "fixed checkboxes should use CAPS labels"
check_absent 'ChildFlags_Borders|BeginChild\([^)]*,[^)]*,[^)]*,[^)]*(child_flags|true)' "routing/mixer tool areas should use borderless child regions"

for file in "${files[@]}"; do
  check_present_file "$file" 'require\("s3g-mc ImGui Theme"\)' "missing shared theme import"
done

check_present_file "$scripts/128ch Node Track Mixer.lua" 'theme\.toolbox_header' "node mixer should use toolbox headers"
check_present_file "$scripts/128ch Ambisonic Node Track Mixer.lua" 'theme\.toolbox_header' "ambisonic node mixer should use toolbox headers"
check_present_file "$scripts/128ch Automation Mixer.lua" 'theme\.toolbox_header' "automation mixer should use toolbox headers"
check_present_file "$scripts/128ch Node Track Mixer.lua" '##node_mixer_tool_area' "node mixer should have a gray tool-area background"
check_present_file "$scripts/128ch Ambisonic Node Track Mixer.lua" '##ambi_node_mixer_tool_area' "ambisonic node mixer should have a gray tool-area background"
check_present_file "$scripts/128ch Automation Mixer.lua" '##automation_channel_tool_area' "automation mixer channel controls should have a gray tool-area background"
check_present_file "$scripts/128ch Automation Mixer.lua" '##automation_pin_tool_area' "automation mixer pin controls should have a gray tool-area background"
check_present_file "$scripts/MC to Stereo Autogain.lua" 'theme\.push_soft_panel' "autogain controls should use soft panel"
check_present_file "$scripts/Patch Routing View.lua" '##patch_toolbar_tool_area' "patch routing toolbar should have a gray tool-area background"
check_present_file "$scripts/Patch Routing View.lua" '##patch_inspector' "patch routing inspector should have a gray tool-area background"

if (( fail )); then
  exit 1
fi

echo "routing/mixer GUI style audit passed"
