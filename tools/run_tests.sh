#!/usr/bin/env bash
# Headless test run. Set GODOT to your Godot 4.4+ binary if it is not on PATH.
set -euo pipefail
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# First run in a clean checkout needs an import pass to register class names.
if [ ! -d "$ROOT/.godot" ]; then
  "$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
fi
"$GODOT" --headless --path "$ROOT" res://tests/tests.tscn
"$GODOT" --headless --path "$ROOT" res://tests/invariants.tscn
"$GODOT" --headless --path "$ROOT" res://tests/dice3d_tests.tscn
"$GODOT" --headless --path "$ROOT" res://tests/physical_turn.tscn
# Needs a display: the point of it is what the dice actually render as.
xvfb-run -a "$GODOT" --path "$ROOT" res://tests/die_face_render.tscn
