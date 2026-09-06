# Abyssal Bazaar

A cozy little shop in a clearing. The trees bleed sap and the counter is an
altar. Send thralls into the woods, put what they bring back on the tables,
and watch the number go up.

Godot 4.4, GL Compatibility, 1600x1000, sized for a thumb.

## Running it

    godot --path .

## Checks

    GODOT=/path/to/godot tools/run_tests.sh

- `tests/tests.gd` — the rules.
- `tests/invariants.gd` — property fuzz: runs the shop badly, at random, 160
  times, and checks what must hold at every tick rather than the outcome of
  any run.
- `tests/ui_smoke.gd` — plays the real scene through the real buttons.
  Needs a display: `xvfb-run godot --path . res://tests/ui_smoke.tscn`

## Screenshots

    xvfb-run godot --path . res://tools/screenshot.tscn -- --dir=/tmp/shots

## Where things are

The sim knows nothing about the screen. It advances by `tick(delta)` with a
seeded generator and no reference to frames, real time or the scene tree,
which is what lets the whole game run thousands of times headlessly while the
view does nothing but draw what it finds.

| | |
|---|---|
| `scripts/sim/world.gd` | The shop, running. Everything goes through `tick`. |
| `scripts/sim/shop.gd` | The floor: what is where, and what is on it |
| `scripts/sim/goods.gd` | The four goods, and what does not keep |
| `scripts/sim/thralls.gd` | The deck, and what is out in the woods |
| `scripts/sim/customers.gd` | Someone off the path |
| `scripts/autoload/balance.gd` | Every tunable number |
| `scripts/ui/world_view.gd` | The shop, drawn |
| `scripts/ui/grid_map.gd` | Where a tile lands on screen, either layout |
| `scripts/ui/tile_theme.gd` | The tile slots. **The game ships with no art** |
| `assets/tiles/README.md` | How to add your own tiles |
| `scenes/painted_map.tscn` | **The 50x50 TileMapLayers you paint on** |
| `docs/PAINTING.md` | How to paint them |
| `scripts/ui/stock_panel.gd` | What you have and how long you have it for |
| `docs/DESIGN.md` | Why the deck is a concurrency limit, and what rot is for |
