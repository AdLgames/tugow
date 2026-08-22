# Shipping on Steam

The game is playable without any Steam integration — `scripts/autoload/steam_manager.gd`
detects GodotSteam at runtime and no-ops when it is absent. Nothing in the game
logic calls into Steam directly; only `scripts/autoload/run_state.gd` does, and
only to unlock achievements and set rich presence.

## 1. Engine

Install [GodotSteam](https://godotsteam.com), either as a custom engine build or
the GDExtension. No project change is needed: the manager looks for the `Steam`
singleton and connects if it exists.

## 2. App id

Set it in two places:

- `APP_ID` in `scripts/autoload/steam_manager.gd`
- `steam_appid.txt` beside the binary (local testing only — do not ship it)

The committed value, `480`, is Valve's public Spacewar test app, which is what
you want until the real id exists.

## 3. Achievements

Create these API names in the Steamworks partner site; the strings are already
the ids the code unlocks:

| API name | Unlocks when |
|---|---|
| `FIRST_DESCENT` | Clear the first floor |
| `TWO_TURN_FLOOR` | Clear a floor in two turns |
| `SCRATCH_THE_YAHTZEE` | Scratch the Yahtzee box on purpose |
| `DENIED` | Take a box the Adversary announced |
| `OUTSCORED` | Out-score an Adversary and reclaim boxes |
| `DEEP_SIX` | Reach floor six |
| `THIRTEEN_BOXES` | Fill all thirteen boxes in a single run |
| `WALK_OUT` | Clear floor twelve |

All eight are wired to run events in `scripts/autoload/run_state.gd`.

Stats: `deepest_floor` (INT) is written on every run end.

## 4. Export

`export_presets.cfg` carries Windows and Linux presets that exclude `docs/`,
`tests/`, and `tools/` from the build:

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/ThirteenBoxes.exe
godot --headless --path . --export-release "Linux" build/linux/ThirteenBoxes.x86_64
```

Ship the Steamworks redistributable (`steam_api64.dll` / `libsteam_api.so`)
alongside the executable, and point the Steamworks depot at the build folder.

## 5. Saves

Meta progress lives in `user://thirteen_boxes.cfg` (runs, deepest floor, best
total, wins). For Steam Cloud, map the platform `user://` path in the partner
site's auto-cloud configuration — no code change is required.
