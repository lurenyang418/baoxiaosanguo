#!/usr/bin/env bash
# Open an isolated GUI session. Pass a checkpoint JSON to rehearse a later stage.
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
workspace_dir="$(cd "$project_dir/.." && pwd)"
day="$(date +%F)"
run_dir="$workspace_dir/tmp/campaign-manual-$day"
number=2
while [[ -e "$run_dir" ]]; do
  run_dir="$workspace_dir/tmp/campaign-manual-$day-$(printf '%02d' "$number")"
  number=$((number + 1))
done

checkpoint="${1:-}"
if [[ -n "$checkpoint" ]]; then
  checkpoint="$(cd "$(dirname "$checkpoint")" && pwd)/$(basename "$checkpoint")"
  case "$checkpoint" in
    "$workspace_dir"/tmp/*) ;;
    *) echo "Checkpoint must be inside workspace tmp" >&2; exit 2 ;;
  esac
  [[ -f "$checkpoint" ]] || { echo "Checkpoint missing: $checkpoint" >&2; exit 2; }
fi

mkdir -p "$run_dir"
save_file="$run_dir/isolated-manual-save.json"
if [[ -n "$checkpoint" ]]; then
  cp "$checkpoint" "$save_file"
fi
git -C "$project_dir" rev-parse HEAD > "$run_dir/source-commit.txt"
git -C "$project_dir" status --short > "$run_dir/source-status.txt"
export BAOXIAO_REGRESSION_SAVE_PATH="$save_file"
echo "Manual session: $run_dir"
echo "On the title screen, choose Load to resume the checkpoint."
godot --path "$project_dir"
