#!/usr/bin/env bash
# Build a macOS .app (Debug) or an ad-hoc signed .dmg (Release).
#
# Usage:
#   ./scripts/build_macos.sh           # Debug .app, no signing
#   ./scripts/build_macos.sh --release # Release app + DMG with an /Applications link
#   ./scripts/build_macos.sh --release --arm64  # Apple Silicon Release DMG
#   ./scripts/build_macos.sh --release --x86_64 # Intel Release DMG
# The installed Godot macOS release template is Universal 2; architecture flags
# thin the exported app with lipo before re-signing it ad-hoc.
#
# Outputs go to build/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/build_common.sh"

PRESET="macOS"
OUTPUT="$BUILD_DIR/BaoXiaoSanGuo.app"
BUILD_MODE="debug"
RELEASE_APP="$BUILD_DIR/macos-release/BaoXiaoSanGuo.app"
ARCH=""

for arg in "$@"; do
  case "$arg" in
    --release) BUILD_MODE="release" ;;
    --arm64) ARCH="arm64" ;;
    --x86_64) ARCH="x86_64" ;;
    *) log_fatal "Unknown argument '$arg'. Use --release, optionally with --arm64 or --x86_64." ;;
  esac
done

if [[ "$ARCH" != "" && "$BUILD_MODE" != "release" ]]; then
  log_fatal "Architecture-specific macOS exports currently require --release."
fi

if [[ "$BUILD_MODE" == "release" ]]; then
  if [[ "$ARCH" == "arm64" ]]; then
    PRESET="macOS Release"
    RELEASE_APP="$BUILD_DIR/macos-release-arm64/BaoXiaoSanGuo.app"
    OUTPUT="$BUILD_DIR/BaoXiaoSanGuo-arm64.dmg"
  elif [[ "$ARCH" == "x86_64" ]]; then
    PRESET="macOS Release"
    RELEASE_APP="$BUILD_DIR/macos-release-intel/BaoXiaoSanGuo.app"
    OUTPUT="$BUILD_DIR/BaoXiaoSanGuo-x86_64.dmg"
  else
    PRESET="macOS Release"
    OUTPUT="$BUILD_DIR/BaoXiaoSanGuo.dmg"
  fi
fi

log_info "Building macOS — preset '$PRESET'"

require_godot
require_export_templates
require_preset "$PRESET"
ensure_build_dir

if [[ "$PRESET" == "macOS" ]]; then
  run_export "$PRESET" "$OUTPUT" "macOS" "$BUILD_MODE"
  log_info "Debug build complete. Launch with:"
  echo "    open \"$OUTPUT\""
else
  mkdir -p "$(dirname "$RELEASE_APP")"
  run_export "$PRESET" "$RELEASE_APP" "macOS" "$BUILD_MODE"

  if [[ -n "$ARCH" ]]; then
    EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$RELEASE_APP/Contents/Info.plist")"
    EXECUTABLE_PATH="$RELEASE_APP/Contents/MacOS/$EXECUTABLE_NAME"
    AVAILABLE_ARCHS="$(lipo -archs "$EXECUTABLE_PATH")"
    case " $AVAILABLE_ARCHS " in
      *" $ARCH "*) ;;
      *) log_fatal "Exported macOS binary lacks requested architecture '$ARCH' (found: $AVAILABLE_ARCHS)." ;;
    esac
    THIN_EXECUTABLE="$EXECUTABLE_PATH.thin"
    rm -f "$THIN_EXECUTABLE"
    lipo -thin "$ARCH" "$EXECUTABLE_PATH" -output "$THIN_EXECUTABLE"
    mv "$THIN_EXECUTABLE" "$EXECUTABLE_PATH"
    codesign --force --deep --sign - "$RELEASE_APP"
    log_ok "Thinned macOS app to $ARCH using the installed Universal 2 template."
  fi

  codesign --verify --deep --strict "$RELEASE_APP"

  STAGING_DIR="$(mktemp -d "$BUILD_DIR/.BaoXiaoSanGuo-dmg.XXXXXX")"
  trap 'rm -rf "$STAGING_DIR"' EXIT
  cp -R "$RELEASE_APP" "$STAGING_DIR/"
  ln -s /Applications "$STAGING_DIR/Applications"
  hdiutil create -volname "爆笑三国" -srcfolder "$STAGING_DIR" -ov -format UDZO "$OUTPUT"

  if [[ ! -s "$OUTPUT" ]]; then
    log_fatal "DMG export reported success but '$OUTPUT' is missing or empty."
  fi
  log_ok "Built: $OUTPUT ($(du -sh "$OUTPUT" | awk '{print $1}'))"
  log_info "Ad-hoc signed ${ARCH:-Universal 2} DMG built for local testing: $OUTPUT"
  log_warn "Public distribution still requires Developer ID signing and notarization."
fi
