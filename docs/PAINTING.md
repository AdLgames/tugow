# Painting the map

`scenes/painted_map.tscn` is three `TileMapLayer` nodes over a **50 × 50**
working area, using `resources/bazaar_tileset.tres` at **64 × 64** per tile.
It is instanced into the game automatically and drawn behind the shop.

## Getting your tiles in

1. Open `scenes/painted_map.tscn`.
2. Select a layer. In the inspector, open `TileSet` → **TileSet** panel at
   the bottom.
3. Drag your PNG into the panel. Godot offers to slice it into 64 × 64 tiles —
   say yes.
4. Switch to the **TileMap** tab, pick a tile, and paint.

Save the scene. That is all — the game reads it on next run.

## The layers

| Layer | For | Sorting |
|---|---|---|
| `Ground` | Floor | None. Nothing can walk behind a floor. |
| `Walls` | Anything with height | Y-sorted, so figures pass behind it |
| `Decor` | Clutter over the walls | Y-sorted |

## The working area

50 × 50 cells, from `(0, 0)` to `(49, 49)`, outlined in green in the editor
with a grid line every ten cells. You can paint outside it; the game will not
look there. `PaintedMap.MAP_SIZE` is the number if you want to change it.

## How it lines up with the shop

The shop is **simulated, not painted** — it builds its own 8 × 8 floor, and
16 × 16 after the expansion. It is centred on your map, so shop cell `(0, 0)`
sits at map cell `(21, 21)` at level 1 and `(17, 17)` at level 2. One painted
cell is always one shop cell, at whatever zoom the view has settled on.

Paint the world the shop stands in: the clearing, the trees, the path the
customers come up. You can paint under the shop too — a painted cell wins over
the flat floor the game would otherwise draw there.

**Except corruption.** A floor tile that has turned is the game telling you
something, so it draws over your paint rather than under it.

## What is still not painted

Tables, cases, people and the stock on them are drawn in code. They sit on top
of every layer. Sprites for those would need slots adding to `TileTheme`.

## If nothing shows up

The game only uses the map once something is painted — an empty map is not a
black screen, it falls back to the flat floor it shipped with. `tools/paint_demo.gd`
paints the whole area with a throwaway two-tile atlas made in memory and takes
a picture, which is the fastest way to tell a wiring problem from an art one:

    xvfb-run godot --path . res://tools/paint_demo.tscn -- --dir=/tmp/shots
