#!/usr/bin/env bash
# Export a Godot iOS Xcode project. Signing and installation happen in Xcode.
# Set BAOXIAO_BUILD_DIR to a new absolute path for a separate build.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/build_common.sh"

if [[ $# -ne 0 ]]; then
  log_fatal "Usage: ./scripts/build_ios.sh"
fi

OUTPUT_DIR="$BUILD_DIR/ios-xcode"
OUTPUT="$OUTPUT_DIR/BaoXiaoSanGuo.ipa"

require_godot
require_export_templates
require_preset "iOS Xcode Project"

if [[ "$(uname -s)" != "Darwin" ]]; then
  log_fatal "iOS export requires macOS with Xcode."
fi
if ! xcodebuild -version >/dev/null 2>&1; then
  log_fatal "Xcode is unavailable. Install full Xcode and select it with xcode-select."
fi
if [[ -e "$OUTPUT_DIR" ]]; then
  log_fatal "Output directory already exists: $OUTPUT_DIR
Set BAOXIAO_BUILD_DIR to a new absolute directory to preserve the existing project."
fi

mkdir -p "$OUTPUT_DIR"
log_info "Exporting iOS Xcode project to $OUTPUT_DIR"
if ! "$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-debug "iOS Xcode Project" "$OUTPUT" > "$OUTPUT_DIR/export.log" 2>&1; then
  tail -40 "$OUTPUT_DIR/export.log" >&2
  log_fatal "Godot iOS project export failed. See $OUTPUT_DIR/export.log"
fi

if [[ ! -d "$OUTPUT_DIR/BaoXiaoSanGuo.xcodeproj" || ! -f "$OUTPUT_DIR/BaoXiaoSanGuo.pck" ]]; then
  log_fatal "Godot exited successfully, but the Xcode project or game pack is missing. See $OUTPUT_DIR/export.log"
fi

log_ok "Xcode project: $OUTPUT_DIR/BaoXiaoSanGuo.xcodeproj"
log_info "This project is not a signed IPA. In Xcode, replace the placeholder Team ID and bundle identifier, then build for an iOS device."
