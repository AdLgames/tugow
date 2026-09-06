#!/usr/bin/env bash
# Every check, in the order that fails fastest.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path "$ROOT" res://tests/tests.tscn
"$GODOT" --headless --path "$ROOT" res://tests/invariants.tscn
# Needs a display: it presses the real buttons in the real scene.
xvfb-run -a "$GODOT" --path "$ROOT" res://tests/ui_smoke.tscn
