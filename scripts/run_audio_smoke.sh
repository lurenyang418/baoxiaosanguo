#!/usr/bin/env bash
set -u

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
workspace_dir="$(cd "$project_dir/.." && pwd)"
day="$(date +%F)"
run_dir="$workspace_dir/tmp/audio-smoke-$day"
number=2
while [[ -e "$run_dir" ]]; do
  run_dir="$workspace_dir/tmp/audio-smoke-$day-$(printf '%02d' "$number")"
  number=$((number + 1))
done

export BAOXIAO_AUDIO_TEST_DIR="$run_dir"
echo "Audio smoke output: $run_dir"
if [[ "${BAOXIAO_AUDIO_HEADLESS:-0}" == "1" ]]; then
  godot --headless --path "$project_dir" --scene res://tests/audio_smoke.tscn
else
  godot --path "$project_dir" --scene res://tests/audio_smoke.tscn
fi
result=$?
if [[ -d "$run_dir" ]]; then
  git -C "$project_dir" rev-parse HEAD > "$run_dir/source-commit.txt"
  git -C "$project_dir" status --short > "$run_dir/source-status.txt"
fi
exit "$result"
