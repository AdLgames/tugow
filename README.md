# Thirteen Boxes

*A dice roguelike where the scorecard is your health bar.*

Yahtzee's scorecard is already a roguelike run: thirteen boxes, each usable once,
every choice permanent. So the card is not reset between fights. You descend
through floors, each demanding a score threshold, and **every turn you take
spends one box off your card for the rest of the run**.

This repository is the Godot 4 prototype: the scoring resolver, the box-spend
loop, the shared dice pool, the Adversary duel, charms, and the bench — all
playable, all headless-testable.

## Running it

Requires **Godot 4.4 or newer** (standard build; no C# needed).

```bash
godot --path .                      # play
godot --headless --path . --import  # first run in a fresh checkout
./tools/run_tests.sh                # 150 logic checks
godot --headless --path . res://tests/ui_smoke.tscn      # drive the real UI
xvfb-run godot --path . res://tools/screenshot.tscn -- --dir=/tmp/shots  # render every screen
godot --headless --path . res://tools/curve_report.tscn  # balance sweeps
```

`GODOT=/path/to/godot ./tools/run_tests.sh` if the binary is not on PATH.

## How a floor plays

1. Five dice are drawn from your pool of eight and thrown. You choose the
   throw strength each time: soft stays in the pot, hard scatters to the
   **rail** (which multiplies your score) and can put dice **off the table**
   for the rest of the floor. Two rethrows.
2. Clicking a die **locks it for the entire floor** — not the turn. It scores
   for you every turn from now on, and you roll one die fewer, forever.
3. Writing into a box ends the turn and spends that box for the rest of the run.
   Writing a zero is a **scratch**: a sacrifice play, not a failure.
4. Every open box shows what it would score for the dice in front of you,
   greyed at zero and highlighted on the best one. Writing asks you to confirm,
   because the box is gone for the rest of the run either way.
5. Clear the threshold and you descend with whatever boxes you have left.
   Overshoot is not wasted: the excess carries into the next floor.

On duel floors an Adversary writes into the same card. It **announces its target
box before rolling**, which gives you exactly one turn to respond: deny it by
taking that box yourself, outpace it by ending the floor, or starve it by
locking the dice it needs away from the shared pool. Out-score it and you
reclaim spent boxes — beating an Adversary is the only healing in the game.
Let it claim seven boxes and it takes the card.

## Layout

| Path | What is in it |
|---|---|
| `scripts/core/scoring.gd` | The resolver — all thirteen operators |
| `scripts/core/throw.gd` | Throw strength, zones, collisions, stacking, losses |
| `scripts/core/game.gd` | The run: floors, turns, duels, box spending |
| `scripts/core/scorecard.gd` | Thirteen boxes and their states |
| `scripts/core/dice_pool.gd`, `die.gd` | Eight named dice, locking, facets, bitterness, memory |
| `scripts/core/charms.gd` | The seven charms |
| `scripts/core/forge.gd` | Between-floor upgrades priced in boxes |
| `scripts/adversary/` | Base AI plus the Auditor, Magpie, Twin, Furnace, Debtor |
| `scripts/autoload/balance.gd` | Every tunable number in one file |
| `scripts/autoload/steam_manager.gd` | Optional Steam layer (no-ops without it) |
| `scripts/ui/` | The interface, built in code |
| `tests/`, `tools/` | Headless suite, UI smoke test, curve report |

Source of truth: the mechanics specification. How it is implemented, and every
knowing departure from it: [`docs/MECHANICS.md`](docs/MECHANICS.md). The
original vision document is kept at [`docs/DESIGN.md`](docs/DESIGN.md).
Resolver findings and answers to the open questions: [`docs/BALANCE.md`](docs/BALANCE.md).

## Steam

The game runs standalone; Steam is additive.

1. Install [GodotSteam](https://godotsteam.com) (engine build or GDExtension).
2. Put your real app id in `scripts/autoload/steam_manager.gd` (`APP_ID`) and in
   `steam_appid.txt` beside the binary for local testing. The committed value is
   `480` (Valve's public test app).
3. Ship the Steamworks redistributables next to the export.

`Steam.unlock(&"DEEP_SIX")` and friends are already wired to run events in
`scripts/autoload/run_state.gd`; the achievement ids in `ACHIEVEMENTS` are the
list to create in the Steamworks partner site.

## Prototype status

Following the design doc's build order:

- [x] 1. Scoring resolver — thirteen operators, curve visualisation
- [x] 2. Single floor, no Adversary — the box-spend tension in isolation
- [x] 3. The Auditor — shared card
- [x] 4. Shared dice pool + The Magpie — the bluffing layer
- [x] 5. Forge — boxes as the only currency
- [ ] Art, audio, run seeds/dailies, tutorial, Steam Cloud saves
