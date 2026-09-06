#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path "$ROOT" res://tests/smoke.tscn
