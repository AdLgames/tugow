# Checkpoint

*Check who's in line. Don't look behind you.*

A short horror game about a checkpoint into the safe zone. There are no
papers to check. You ask up to three questions, you listen, and you decide who
comes in. Some of them are not people, and none of them will tell you.

Godot 4.4, GL Compatibility, 1920x1080.

## Running it

    godot --path .

## Checks

    GODOT=/path/to/godot tools/run_tests.sh

- `tests/tests.gd` — the rules, including the two the design leans on hardest:
  that a scare never fires on the traveller that caused it, and that questions
  wear out once you lean on them.
- `tests/invariants.gd` — property fuzz. Plays the booth badly, at random,
  hundreds of times, and checks what must be true at every moment rather than
  the outcome of any one run.
- `tests/ui_smoke.gd` — plays the real scene through the real buttons.
  Needs a display: `xvfb-run godot --path . res://tests/ui_smoke.tscn`

## Screenshots

    xvfb-run godot --path . res://tools/screenshot.tscn -- --dir=/tmp/shots

## Where things are

| | |
|---|---|
| `scripts/core/questions.gd` | The eight questions and both shapes of every answer |
| `scripts/core/tells.gd` | The seven tells |
| `scripts/core/scares.gd` | The six scares and the rules about when one may happen |
| `scripts/core/game.gd` | The booth: asking, deciding, dread, arming a scare |
| `scripts/core/shifts.gd` | Seven shifts, and what each one takes away from you |
| `scripts/autoload/dread.gd` | Every tunable number |
| `docs/DESIGN.md` | Why the scare is late, and what the interface refuses to tell you |
| `docs/ASSETS.md` | What is drawn in code and what a painter would replace |
