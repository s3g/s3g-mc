#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIPTS="$ROOT/Scripts/s3g-mc"
UTILITIES="$SCRIPTS/utilities"
SAMPLE_LINES="${S3G_MC_AUDIT_SAMPLE_LINES:-16}"
warn() { printf 'WARN: %s\n' "$*"; }
info() { printf 'INFO: %s\n' "$*"; }

report_rg() {
  local level="$1"
  local label="$2"
  local pattern="$3"
  local exclude_pattern="${4:-}"
  local tmp
  tmp="$(mktemp)"
  if [[ -n "$exclude_pattern" ]]; then
    rg -n "$pattern" "$SCRIPTS" --glob '*.lua' --glob '!*s3g-mc Package Browser.lua' | rg -v "$exclude_pattern" > "$tmp" || true
  else
    rg -n "$pattern" "$SCRIPTS" --glob '*.lua' --glob '!*s3g-mc Package Browser.lua' > "$tmp" || true
  fi
  local count
  count=$(wc -l < "$tmp" | tr -d ' ')
  if [[ "$count" != "0" ]]; then
    if [[ "$level" == "WARN" ]]; then warn "$label ($count matches)"; else info "$label ($count matches)"; fi
    head -n "$SAMPLE_LINES" "$tmp"
    if (( count > SAMPLE_LINES )); then
      printf '... %d more\n' "$((count - SAMPLE_LINES))"
    fi
  fi
  rm -f "$tmp"
}

report_rg_path() {
  local level="$1"
  local label="$2"
  local pattern="$3"
  local path="$4"
  local glob_a="${5:-*}"
  local glob_b="${6:-}"
  local glob_c="${7:-}"
  local tmp
  tmp="$(mktemp)"
  if [[ -d "$path" ]]; then
    if [[ -n "$glob_c" ]]; then
      rg -n "$pattern" "$path" --glob "$glob_a" --glob "$glob_b" --glob "$glob_c" > "$tmp" || true
    elif [[ -n "$glob_b" ]]; then
      rg -n "$pattern" "$path" --glob "$glob_a" --glob "$glob_b" > "$tmp" || true
    else
      rg -n "$pattern" "$path" --glob "$glob_a" > "$tmp" || true
    fi
  fi
  local count
  count=$(wc -l < "$tmp" | tr -d ' ')
  if [[ "$count" != "0" ]]; then
    if [[ "$level" == "WARN" ]]; then warn "$label ($count matches)"; else info "$label ($count matches)"; fi
    head -n "$SAMPLE_LINES" "$tmp"
    if (( count > SAMPLE_LINES )); then printf '... %d more\n' "$((count - SAMPLE_LINES))"; fi
  fi
  rm -f "$tmp"
}

report_files_without() {
  local level="$1"
  local label="$2"
  local required_pattern="$3"
  local candidate_pattern="$4"
  local tmp
  tmp="$(mktemp)"
  while IFS= read -r file; do
    case "$file" in
      *" ImGui Theme.lua"|*" Library.lua") continue ;;
    esac
    if rg -q "$candidate_pattern" "$file" && ! rg -q "$required_pattern" "$file"; then
      printf '%s\n' "$file" >> "$tmp"
    fi
  done < <(rg --files "$SCRIPTS" --glob '*.lua' --glob '!*s3g-mc Package Browser.lua')
  local count
  count=$(wc -l < "$tmp" | tr -d ' ')
  if [[ "$count" != "0" ]]; then
    if [[ "$level" == "WARN" ]]; then warn "$label ($count files)"; else info "$label ($count files)"; fi
    head -n "$SAMPLE_LINES" "$tmp"
    if (( count > SAMPLE_LINES )); then printf '... %d more\n' "$((count - SAMPLE_LINES))"; fi
  fi
  rm -f "$tmp"
}

if [[ ! -d "$SCRIPTS" ]]; then
  warn "missing Scripts/s3g-mc directory: $SCRIPTS"
  exit 0
fi

printf 's3g-mc ReImGui consistency audit\n'
printf 'root: %s\n\n' "$ROOT"
printf 'exempt: s3g-mc Package Browser keeps its package-index browser visual language\n\n'

report_files_without "WARN" \
  "ReImGui scripts using widgets but not loading the shared theme module" \
  "s3g-mc ImGui Theme" \
  "ImGui\\.(Begin|Button|Slider|Checkbox|BeginCombo|Text|DrawList_)"

report_files_without "INFO" \
  "scripts installing theme but not using local theme helpers/palette; check for transitional styling" \
  "local theme = require|theme\\.|theme\\.palette\\(ImGui\\)|local THEME" \
  "s3g-mc ImGui Theme"

report_rg "WARN" \
  "local neutral color palettes remain; prefer theme.palette(ImGui) for base UI colors" \
  "local COLORS|COLORS =|COLOR_[A-Z_]+ =" \
  "s3g-mc ImGui Theme.lua"

report_rg "INFO" \
  "local color conversion helpers remain; okay for semantic canvas colors, suspect for neutral UI" \
  "ColorConvertDouble4ToU32|local function (color|rgba)" \
  "s3g-mc ImGui Theme.lua"

report_rg "INFO" \
  "bright diagram text colors: use muted gray unless the text is semantic data" \
  "(CANVAS|FLOW)\.text = (color|rgba|ImGui\.ColorConvertDouble4ToU32)\(0\.[78][0-9]*, 0\.[78][0-9]*, 0\.[78][0-9]*"


report_rg "WARN" \
  "direct PushStyleColor calls remain; prefer shared theme helpers unless the color carries signal meaning" \
  "PushStyleColor" \
  "s3g-mc ImGui Theme.lua"

report_rg "WARN" \
  "direct TextColored calls remain; prefer theme.text/theme.muted/theme.status for ordinary UI text" \
  "TextColored" \
  "s3g-mc ImGui Theme.lua"

report_rg "WARN" \
  "older bright generic active/speaker colors remain; mute or make semantic during script-specific cleanup" \
  "0\\.16, 0\\.63, 0\\.38|0\\.25, 0\\.70, 0\\.92|0\\.42, 0\\.74, 0\\.96"

report_rg "INFO" \
  "collapsing headers: verify each visible disclosure marker has real collapse value and useful default-open state" \
  "CollapsingHeader"

report_rg "INFO" \
  "standalone +/- buttons: ensure these are zoom/nudge controls, not fake collapse markers" \
  'Button\(ctx, "[+-]"'

report_rg "WARN" \
  "mixed-case visible button labels remain; fixed buttons should be all caps before any hidden ##id" \
  'ImGui\.(SmallButton|Button)\(ctx, "[^"#]*[a-z][^"#]*(##|")' \
  "s3g-mc Package Browser.lua"

report_rg "INFO" \
  "camera/view labels: normalize TOP/SIDE/FRONT/3/4 wording and zoom placement by family" \
  '"3/4 view"|"3/4##|"top##|"Top"|"front##|"Front"|"Side"|"Zoom"'

report_rg "INFO" \
  "hard-coded item widths: check family consistency and narrow-window behavior" \
  "SetNextItemWidth\\(ctx, [0-9]+\\)|Button\\(ctx, [^\n]+, [0-9]+, [0-9]+\\)" \
  "Render\", 9[0-9], 2[468]|Cancel\", 9[0-9], 2[468]"

report_rg "INFO" \
  "long SameLine chains: check for crowded rows and overlap risk" \
  "SameLine\\(ctx\\)"

report_rg "INFO" \
  "discrete sliders: named modes/orders/layouts should generally use combo menus" \
  "Slider(Int|Double)\\(ctx, \"(Mode|Algorithm|Order|Layout|Field|Method|Preset|Selected source|Seed)"

report_rg "INFO" \
  "combo menus: verify menu ordering, labels, and selected-value mapping" \
  "BeginCombo|Combo\\(ctx"

report_rg "INFO" \
  "child regions: check for nested panels, scroll traps, and footer overlap" \
  "BeginChild|EndChild"

report_rg "INFO" \
  "one-line dense UI blocks: refactor when controls become hard to audit" \
  "ImGui\\.[A-Za-z]+\\(ctx.*ImGui\\.[A-Za-z]+\\(ctx"

report_rg_path "WARN" \
  "browser utilities: hardcoded saturated legacy colors; consider shared neutral utility palette or semantic exception" \
  "#6ee7f2|#5aa8c7|#70dcf4|#78be96|#d8a24a|#f06eca|#b998ff|#86a7ff|#cf695f" \
  "$UTILITIES" "*.css" "*.js" "*.html"

report_rg_path "INFO" \
  "browser utilities: local color constants and CSS variables; audit against s3g visual language" \
  "COLORS|SCENE_COLORS|--[a-zA-Z0-9_-]+:|#[0-9a-fA-F]{3,8}|rgba\(" \
  "$UTILITIES" "*.css" "*.js" "*.html"

report_rg_path "INFO" \
  "browser utilities: camera/view hooks and labels; normalize TOP/SIDE/FRONT/3/4 wording where relevant" \
  "data-(aed-)?camera|data-view|data-gltf-camera|\"(top|side|front|3/4|zoom)\"|>(TOP|Top|SIDE|Side|FRONT|Front|3/4|Zoom)<" \
  "$UTILITIES" "*.css" "*.js" "*.html"

printf '\nSee docs/s3g-mc-ui-audit.md for the human checklist and allowed exceptions.\n'
exit 0
