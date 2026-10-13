#!/usr/bin/env bash
# Export a Windows x64 or ARM64 executable from the current Godot project.
# Usage: ./scripts/build_windows.sh [--arm64] [--release]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/build_common.sh"

PRESET="Windows x64"
OUTPUT="$BUILD_DIR/BaoXiaoSanGuo-windows-x64.exe"
BUILD_MODE="debug"

for arg in "$@"; do
  case "$arg" in
    --arm64)
      PRESET="Windows ARM64"
      OUTPUT="$BUILD_DIR/BaoXiaoSanGuo-windows-arm64.exe"
      ;;
    --release) BUILD_MODE="release" ;;
    *) log_fatal "Unknown argument '$arg'. Usage: ./scripts/build_windows.sh [--arm64] [--release]" ;;
  esac
done

log_info "Building $PRESET ($BUILD_MODE) executable"
require_godot
require_export_templates
require_preset "$PRESET"
ensure_build_dir
run_export "$PRESET" "$OUTPUT" "Windows" "$BUILD_MODE"
