# Bazaar Wireframe

A bare top-down 2D skeleton in Godot 4.4: three tile layers, a player that
walks, a camera that follows, and walls that stop you. Orthogonal square
grid, **64 × 64** per tile.

Press Play and you are standing in a room.

## Running it

    godot --path .

    W A S D / arrow keys — walk

## Checks

    GODOT=/path/to/godot tools/run_tests.sh

`tests/smoke.gd` loads the real scene and checks the things that break first:
that the wall tile actually carries a collision shape (a tile with none looks
identical in the editor and is walked straight through), that the floor tile
does not, that holding a direction moves the player, that a wall stops them,
and that world coordinates and grid cells agree both ways.

    xvfb-run godot --path . res://tools/screenshot.tscn -- --dir=/tmp/shots

## What is here

| | |
|---|---|
| `scenes/world.tscn` | The room. Three TileMapLayers, the player, the camera |
| `scenes/player.tscn` | CharacterBody2D with a feet-sized collider |
| `scripts/world.gd` | Paints the starter room; grid helpers |
| `scripts/player.gd` | Eight-way movement |
| `resources/tileset.tres` | The TileSet. 64 × 64, one physics layer |
| `assets/placeholder_tiles.png` | **Placeholder art. Replace it** |

## The layers

| Layer | For | Collision | Sorting |
|---|---|---|---|
| `Ground` | Floor | None | None — nothing walks behind a floor |
| `Walls` | Anything solid | From the tile | Y-sorted |
| `Decor` | Clutter over the walls | None | Y-sorted |

Collision comes from the **tile**, not from the layer. A tile is solid because
you gave it a collision shape in the TileSet, and only then. That is why the
smoke test checks for one.

## Putting your own tiles in

1. Drop your PNG in `assets/`.
2. Open `resources/tileset.tres`, or select a layer in `scenes/world.tscn` and
   open the **TileSet** panel at the bottom.
3. Drag the PNG in. Godot offers to slice it at 64 × 64 — say yes.
4. For any tile that should be solid: select it, open **Physics** in the tile
   inspector, and draw a rectangle on physics layer 0.
5. Switch to the **TileMap** tab and paint.

Changing tile size means changing it in three places: `tile_size` in the
TileSet, `World.CELL`, and the region size on the atlas source.

## The starter room

`World._paint_starter_room()` paints a 20 × 14 walled room in code so the
project runs before anything has been painted by hand. It only runs when both
layers are empty, so **the moment you paint anything it stops** — you will not
find code fighting your map. Delete the function when you no longer want it.

## Where to build from here

- **A sprite for the player.** Swap the `_draw()` in `player.gd` for an
  `AnimatedSprite2D`. Leave the collider where it is: it is a short box around
  the feet rather than the whole body, which is what makes a character read as
  standing *in* the room instead of floating over it. `Player.facing` is
  already tracked for picking an animation.
- **Interaction.** `World.cell_at()` turns a position into a grid cell and
  `World.is_blocked()` asks the Walls layer whether it is solid — ask the
  layer rather than keeping a second list that could disagree with it.
- **A bigger map.** The layers are unbounded; paint as far as you like. The
  camera follows the player, so nothing needs to change.
