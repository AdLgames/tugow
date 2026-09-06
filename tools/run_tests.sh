#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path "$ROOT" res://tests/smoke.tscn
# Needs a display: it checks the sorting by looking at the pixels.
xvfb-run -a "$GODOT" --path "$ROOT" res://tests/render.tscn
