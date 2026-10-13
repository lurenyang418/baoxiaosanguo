#!/usr/bin/env bash
# Shared validation helpers for the platform export scripts.
# Source this file (do not run it directly).

set -euo pipefail

# ---------- colors ----------
if [[ -t 1 ]]; then
  C_GREEN=$'\033[0;32m'
  C_RED=$'\033[0;31m'
  C_YELLOW=$'\033[0;33m'
  C_BLUE=$'\033[0;34m'
  C_RESET=$'\033[0m'
else
  C_GREEN=""; C_RED=""; C_YELLOW=""; C_BLUE=""; C_RESET=""
fi

log_info()    { printf "%s[INFO]%s %s\n"    "$C_BLUE"   "$C_RESET" "$*"; }
log_ok()      { printf "%s[OK]%s %s\n"      "$C_GREEN"  "$C_RESET" "$*"; }
log_warn()    { printf "%s[WARN]%s %s\n"    "$C_YELLOW" "$C_RESET" "$*"; }
log_error()   { printf "%s[ERROR]%s %s\n"   "$C_RED"    "$C_RESET" "$*" >&2; }
log_fatal()   { log_error "$*"; exit 1; }

# ---------- paths ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${BAOXIAO_BUILD_DIR:-$PROJECT_DIR/build}"

# ---------- Godot ----------
GODOT_BIN="${GODOT_BIN:-godot}"

require_godot() {
  if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
    log_fatal "godot command not found in PATH. Install Godot 4.7.2 or set GODOT_BIN."
  fi
  local version
  version="$($GODOT_BIN --version 2>/dev/null | head -1 || true)"
  log_ok "Godot: $version"
  if [[ "$version" != 4.7.* ]]; then
    log_warn "Expected Godot 4.7.x but got '$version'. Exports may still work."
  fi
}

# ---------- export templates ----------
TEMPLATES_DIR="$HOME/Library/Application Support/Godot/export_templates"

require_export_templates() {
  if [[ ! -d "$TEMPLATES_DIR" ]]; then
    log_fatal "Export templates directory not found: $TEMPLATES_DIR
Open the project in Godot → Editor → Manage Export Templates → Download and Install.
This downloads macOS + Android templates (~200 MB) once."
  fi
  # Godot stores macOS/Android templates as archives and Windows templates as executables.
  local count
  count="$(find "$TEMPLATES_DIR" -mindepth 2 -maxdepth 2 -type f \( -name '*.zip' -o -name '*.exe' -o -name '*.x86_64' -o -name '*.arm64' \) 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$count" -lt 1 ]]; then
    log_fatal "No export templates under $TEMPLATES_DIR.
Open the project in Godot → Editor → Manage Export Templates → Download and Install."
  fi
  log_ok "Export templates: $count file(s) installed"
}

# ---------- export presets ----------
PRESETS_FILE="$PROJECT_DIR/export_presets.cfg"

require_preset() {
  local preset_name="$1"
  if [[ ! -f "$PRESETS_FILE" ]]; then
    log_fatal "Missing $PRESETS_FILE"
  fi
  if ! grep -q "^name=\"$preset_name\"" "$PRESETS_FILE"; then
    log_fatal "Preset '$preset_name' not found in $PRESETS_FILE.
Available presets:
$(grep -E '^name=' "$PRESETS_FILE" | sed 's/^/  /')"
  fi
  log_ok "Preset '$preset_name' found"
}

# ---------- Java (Android) ----------
JAVA_BIN="${JAVA_BIN:-java}"

# Locate a JDK 17 installation, falling back from a few common spots.
# Returns the JAVA_HOME path (or empty if none found).
find_jdk17_home() {
  # 1. Honor an explicit override.
  if [[ -n "${JDK17_HOME:-}" && -d "$JDK17_HOME" ]]; then
    echo "$JDK17_HOME"; return 0
  fi
  # 2. Temurin cask installs to /Library/Java/JavaVirtualMachines.
  local candidate
  for candidate in \
    /Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home \
    /Library/Java/JavaVirtualMachines/openjdk-17.jdk/Contents/Home \
    /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
    /opt/homebrew/opt/temurin@17/Contents/Home; do
    if [[ -x "$candidate/bin/java" ]]; then
      echo "$candidate"; return 0
    fi
  done
  return 1
}

require_java() {
  if ! command -v "$JAVA_BIN" >/dev/null 2>&1; then
    log_fatal "java command not found. Install JDK 17 (recommended):
    brew install --cask temurin@17"
  fi
  local ver
  ver="$($JAVA_BIN -version 2>&1 | head -1 | awk -F\" '{print $2}')"
  if [[ "$ver" == 27* ]]; then
    local jdk17
    if jdk17="$(find_jdk17_home)"; then
      log_warn "Detected JDK 27 but Godot 4.x officially recommends JDK 17.
Auto-switching JAVA_HOME to: $jdk17"
      export JAVA_HOME="$jdk17"
      JAVA_BIN="$jdk17/bin/java"
      ver="$($JAVA_BIN -version 2>&1 | head -1 | awk -F\" '{print $2}')"
    else
      log_fatal "Detected JDK 27 but no JDK 17 found.
Install Temurin 17 with:
    brew install --cask temurin@17
Then re-run. (Godot 4's bundled Gradle wrapper cannot parse Java 27 class files.)"
    fi
  fi
  log_ok "Java: $ver (JAVA_HOME=${JAVA_HOME:-not set})"
}

# ---------- Android SDK ----------
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"

require_android_sdk() {
  if [[ ! -d "$ANDROID_SDK_ROOT" ]]; then
    log_fatal "Android SDK not found at $ANDROID_SDK_ROOT.
Install with:
    brew install --cask android-commandlinetools
    sdkmanager \"platform-tools\" \"platforms;android-35\" \"build-tools;35.0.1\"
Or set ANDROID_SDK_ROOT to your SDK path."
  fi
  if [[ ! -d "$ANDROID_SDK_ROOT/build-tools" ]]; then
    log_fatal "build-tools missing under $ANDROID_SDK_ROOT.
    sdkmanager \"build-tools;35.0.1\""
  fi
  log_ok "Android SDK: $ANDROID_SDK_ROOT"
}

# ---------- build dir ----------
ensure_build_dir() {
  mkdir -p "$BUILD_DIR"
  # Build outputs live inside the project by default; keep them out of Godot's
  # resource scan/export so old packages and diagnostic screenshots aren't packed.
  touch "$BUILD_DIR/.gdignore"
  log_ok "Build dir: $BUILD_DIR"
}

# ---------- godot --export wrapper ----------
# Args: <preset_name> <output_path> [platform] [debug|release]
run_export() {
  local preset="$1"
  local output="$2"
  local platform="${3:-}"
  local build_mode="${4:-debug}"
  local mode_flag="--export-debug"
  local -a export_cmd=("$GODOT_BIN" "--headless" "--path" "$PROJECT_DIR")

  case "$build_mode" in
    debug) ;;
    release) mode_flag="--export-release" ;;
    *) log_fatal "Unknown export mode '$build_mode' (expected debug or release)." ;;
  esac

  # Auto-install Android build template (idempotent — Godot skips if present).
  if [[ "$platform" == "Android" ]]; then
    export_cmd+=("--install-android-build-template")
  fi

  log_info "Running: ${export_cmd[*]} $mode_flag \"$preset\" \"$output\""
  if ! "${export_cmd[@]}" "$mode_flag" "$preset" "$output"; then
    log_fatal "Godot export failed for preset '$preset'.
Common causes:
  - Export templates not installed (Editor → Manage Export Templates)
  - Output path not writable
  - Missing icon / assets referenced by preset
  - (Android) JDK too new — try JDK 17
  - (macOS Release) codesign identity not set in Xcode"
  fi
  if [[ ! -e "$output" ]]; then
    log_fatal "Godot reported success but '$output' was not created."
  fi
  log_ok "Built: $output ($(du -sh "$output" | awk '{print $1}'))"
}
