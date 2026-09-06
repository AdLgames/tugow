# Drop your tiles here

The game ships with no art. Every tile slot falls back to a flat colour, so
it runs, renders and passes its tests with this folder empty.

## Two ways to add tiles

**By filename.** Save a PNG here under the name in the table below and it is
picked up with no code change and no editor work.

**In the inspector.** `scripts/ui/tile_theme.gd` is a `TileTheme` resource
with an exported slot per tile. Create one (right-click → New Resource →
TileTheme), assign textures to the slots, and set `Tiles.theme` to it. An
assigned texture wins over a file of the same name.

## The slots

### Floors — square, drawn to fill one cell. 64x64 suits the rest of the game.

| File | What it is |
|---|---|
| `floor_shop.png` | Level 1, the wooden shop |
| `floor_iron.png` | Level 2, the cold expansion |
| `floor_outside.png` | The clearing round the shop, and the doorway |
| `floor_altar.png` | The counter you sell across |
| `floor_backroom.png` | Level 2 stores |
| `floor_corruption.png` | What a floor turns into. See below |

### Walls — one cell wide, drawn at their own aspect, standing on the bottom of their cell.

A 64x128 sprite is therefore two cells tall; a 64x32 one is half a cell.

| File | What it is |
|---|---|
| `wall_shop_north.png` | Level 1, the back of the room — the only tall face the camera sees |
| `wall_shop_side.png` | Level 1, the wall seen end-on down the sides |
| `wall_shop_sill.png` | Level 1, the near wall. Keep it low or it stands between the camera and the floor |
| `wall_iron_north.png` | Level 2, the same three |
| `wall_iron_side.png` | |
| `wall_iron_sill.png` | |

## Two things worth knowing

**Corruption is a floor, not a tint.** As Corruption rises, tiles are replaced
by `floor_corruption.png` one at a time in a fixed order, so the spread reads
as a spread and always creeps the same way. Draw something you would not want
to walk on.

**Isometric art needs reprojecting first.** The renderer supports both
layouts — `Balance.projection`, one of `Balance.View.ORTHOGONAL` (the default)
or `ISOMETRIC` — but the two want different art. On a square grid a diamond
tile leaves a transparent notch at every corner. Converting one to the other
is a stretch back to square, a 45-degree rotation, and a crop inside the
ragged rim the rotation leaves; there is a script for it in the git history
at `tools/convert_tiles.py`.

**Stacking.** `TileTheme.shop_wall_logs` and `iron_wall_logs` set how many
copies of the wall sprite make up one cell, across. Two gives a stockade of
small logs stacked four to a cell; one gives a single panel.
