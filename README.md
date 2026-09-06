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

    godot --headless --path . res://tools/tileset_doctor.tscn

## What is here

| | |
|---|---|
| `scenes/world.tscn` | The room. Three TileMapLayers, the player, the camera |
| `scenes/player.tscn` | CharacterBody2D with a feet-sized collider |
| `scripts/world.gd` | Paints the starter room; grid helpers |
| `scripts/player.gd` | Eight-way movement |
| `scenes/prop.tscn` | A tall thing the player can walk behind |
| `resources/tileset.tres` | The TileSet. 64 × 64, one physics layer |
| `assets/wood tile.png` | Your floor |
| `assets/stone tile.png` | Your wall — carries the collision |
| `assets/placeholder_tiles.png` | Placeholder art, including the tall-tile example |

## The layers

| Layer | For | Collision | Sorting |
|---|---|---|---|
| `Ground` | Floor | None | None — nothing walks behind a floor |
| `Walls` | Solid walls at the room's edge | From the tile | Y-sorted (against each other only) |
| `Decor` | Flat clutter | None | Y-sorted (against each other only) |
| `Props` | **Tall things the player walks behind** | From the prop | Y-sorted with the player |

Collision comes from the **tile**, not from the layer. A tile is solid because
you gave it a collision shape in the TileSet, and only then. That is why the
smoke test checks for one.

## Do I need to configure tile properties?

**Floor tiles: no.** Slice and paint. Nothing else.

**Anything solid: yes — a collision shape.** Select the tile, open **Physics**
in the tile inspector, and draw a rectangle on physics layer 0. A tile with no
shape looks identical in the editor and is walked straight through; the smoke
test checks for one on the wall tile for exactly that reason.

**Tiles taller than one cell: two origins.** For a 16 x 32 tile in a 16 grid:

| Property | Value | Why |
|---|---|---|
| Size in atlas | 1 x 2 | It spans two atlas cells |
| **Texture Origin** | `(0, -8)` | Lifts it so its base sits on its cell instead of straddling it |
| **Y Sort Origin** | `8` | Moves its sort point from the middle of the cell to the bottom |

Both are in the tile inspector when a tile is selected in the TileSet panel.
`4:0` in `resources/tileset.tres` is a worked example.

## What Y-sorting will and will not do

Tiles in a Y-sorted TileMapLayer **sort correctly against each other**, so
tall tiles overlap in the right order. They do **not** interleave with sibling
nodes — a tile can never be drawn in front of the player, whatever origins you
set, and no error is raised. The player simply walks over the top of it.

So **anything the player must pass behind is a prop, not a tile**:
`scenes/prop.tscn`, added to the `Props` node, which is Y-sorted and contains
the player. `World.add_prop(cell)` puts one on a cell for you.

Use tile layers for floors and for walls at the edge of the room, where
nothing ever needs to walk behind them. Use props for posts, counters,
shelves — anything standing in the middle of the floor.

`tests/render.gd` checks this by counting pixels of the player on screen: zero
when standing behind a prop, about sixteen hundred when nothing is in the way.
It is the only way to catch a sorting mistake, because getting it wrong throws
no error.

## Putting your own tiles in

1. Drop your PNG in `assets/`.
2. Open `resources/tileset.tres`, or select a layer in `scenes/world.tscn` and
   open the **TileSet** panel at the bottom.
3. Drag the PNG in. Godot offers to slice it at 64 × 64 — say yes.
4. For any tile that should be solid: select it, open **Physics** in the tile
   inspector, and draw a rectangle on physics layer 0.
5. Switch to the **TileMap** tab and paint.

## Tile size

**16 x 16.** Pixel art is kept at its native size and the camera is zoomed
instead (`zoom = 4` on the Camera2D in `scenes/player.tscn`), so nothing is
ever resampled and the pixels stay square.

Your art must match. A texture smaller than one region makes a source with
**zero tiles in it** — nothing appears in the palette and nothing can be
painted, which is exactly what a 16 x 16 image does in a 64 x 64 tileset.
`tools/tileset_doctor.gd` says so in as many words.

Changing the size means changing it in three places: `tile_size` in the
TileSet, the region size on each atlas source, and `World.CELL`. Everything
else — the player, the props, the collision shapes — is expressed in cells.

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
