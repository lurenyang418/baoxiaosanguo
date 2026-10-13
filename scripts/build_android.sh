#!/usr/bin/env bash
# Build an Android .apk (Debug or optimized Release) for Bao Xiao San Guo.
#
# Usage:
#   ./scripts/build_android.sh           # Debug .apk (uses Gradle, signs with debug keystore)
#   ./scripts/build_android.sh --release # optimized, locally signed Release .apk
#
# Outputs go to build/android/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/build_common.sh"

PRESET="Android"
ANDROID_BUILD_DIR="$BUILD_DIR/android"
OUTPUT="$ANDROID_BUILD_DIR/baoxiaosanguo-debug.apk"
BUILD_MODE="debug"

if [[ "${1:-}" == "--release" ]]; then
  PRESET="Android Release"
  OUTPUT="$ANDROID_BUILD_DIR/baoxiaosanguo-release.apk"
  BUILD_MODE="release"
fi

log_info "Building Android — preset '$PRESET'"

require_godot
require_export_templates
require_java
require_android_sdk
require_preset "$PRESET"
ensure_build_dir
mkdir -p "$ANDROID_BUILD_DIR"

if [[ "$BUILD_MODE" == "release" ]]; then
  # Match the local sideload policy used by ../xpod: prefer a local stable key,
  # otherwise use the machine's standard Android debug key for Release builds.
  # Godot recognizes these environment variables as Android export overrides.
  CREDENTIALS_FILE="$PROJECT_DIR/.android-release.env"
  ENV_RELEASE_PATH="${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}"
  ENV_RELEASE_USER="${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-}"
  ENV_RELEASE_PASSWORD="${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-}"
  if [[ -f "$CREDENTIALS_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$CREDENTIALS_FILE"
    set +a
  fi
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${ENV_RELEASE_PATH:-${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}}"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${ENV_RELEASE_USER:-${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-}}"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${ENV_RELEASE_PASSWORD:-${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-}}"

  configured=0
  if [[ -n "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ]]; then configured=$((configured + 1)); fi
  if [[ -n "$GODOT_ANDROID_KEYSTORE_RELEASE_USER" ]]; then configured=$((configured + 1)); fi
  if [[ -n "$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" ]]; then configured=$((configured + 1)); fi

  if (( configured == 0 )); then
    GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$HOME/.android/debug.keystore"
    GODOT_ANDROID_KEYSTORE_RELEASE_USER="androiddebugkey"
    GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="android"
    export GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
    mkdir -p "$HOME/.android"
    if [[ ! -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ]]; then
      log_info "Creating the standard local Android debug keystore for sideload Release signing"
      keytool -genkeypair -noprompt \
        -keystore "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" \
        -storepass android -alias androiddebugkey -keypass android \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=Android Debug,O=Android,C=US"
    fi
    log_warn "No local stable signing key configured; signing Release APK with this machine's Android debug key. Keep ~/.android/debug.keystore to preserve update compatibility."
  elif (( configured != 3 )); then
    log_error "Incomplete Android Release signing configuration. Set all three GODOT_ANDROID_KEYSTORE_RELEASE_* values."
    echo "See docs/BUILD.md → Android Release signing."
    exit 1
  fi

  if [[ ! -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ]]; then
    log_error "Release keystore not found: $GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
    exit 1
  fi
fi

run_export "$PRESET" "$OUTPUT" "Android" "$BUILD_MODE"

if [[ "$PRESET" == "Android" ]]; then
  log_info "Debug build complete. Install with:"
  echo "    adb install -r \"$OUTPUT\""
else
  log_info "Release .apk built for local installation or sideload distribution."
fi
