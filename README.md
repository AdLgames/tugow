# Bazaar Wireframe

A top-down 2D skeleton in Godot: tile layers, a player that walks, a camera
that follows, walls that stop you, and lamps that throw shadows off them.
Orthogonal square grid, **16 × 16** per tile.

Press Play and you are standing in a lit room.

## Running it

    godot --path .

    W A S D / arrow keys — walk

## Checks

    GODOT=/path/to/godot tools/run_tests.sh

`tests/smoke.gd` loads the real scene and checks the things that break first:
that **every** wall tile carries a collision shape and an occluder (a tile
missing either looks identical in the editor — one is a hole in the wall, the
other a wall that casts no shadow), that no floor tile carries them, that the
map has both solid and walkable cells, that the player starts somewhere they
can stand, that holding a direction moves them, and that a wall stops them.

`tests/render.gd` looks at actual pixels, because sorting and lighting are
configuration rather than code and neither raises an error when wrong. It
checks the player is hidden behind a prop and drawn when clear, that a lamp
lights the floor under it while the far side of the room stays dark, and —
by measuring the same view with shadows switched on and off — that the walls
genuinely occlude.

    xvfb-run godot --path . res://tools/screenshot.tscn -- --dir=/tmp/shots

    godot --headless --path . res://tools/tileset_doctor.tscn

## What is here

| | |
|---|---|
| `scenes/world.tscn` | The room: tile layers, props, lights, the player |
| `scenes/player.tscn` | CharacterBody2D with a feet-sized collider and the camera |
| `scenes/prop.tscn` | A tall thing the player walks behind, which shadows the floor |
| `scenes/lamp.tscn` | A shadow-casting light |
| `scripts/world.gd` | Grid helpers; asks the tiles what is solid |
| `scripts/player.gd` | Eight-way movement |
| `resources/tileset.tres` | The TileSet. 16 × 16, one physics layer, one occlusion layer |
| `tools/apply_tile_roles.gd` | Makes wall tiles solid and shadow-casting |
| `assets/big plank *.png` | Floor |
| `assets/*wall*.png`, `vertical.png` | Walls |

## The layers

| Layer | For | Collision | Sorting |
|---|---|---|---|
| `Ground` | Floor, and the walls painted into it | From the tile | None |
| `Walls` | Solid tiles you would rather keep off the floor layer | From the tile | Y-sorted (against each other only) |
| `Decor` | Flat clutter | From the tile | Y-sorted (against each other only) |
| `Props` | **Tall things the player walks behind** | From the prop | Y-sorted with the player |
| `Lights` | Lamps | — | — |

Solidity comes from the **tile**, never from the layer. A tile blocks you
because it carries a collision shape, and shadows because it carries an
occluder. So a wall painted onto `Ground` is exactly as solid as one on
`Walls` — which matters, because the map here was painted by hand and its
walls are on `Ground`. `World.is_blocked()` asks every layer for that reason.

## Making tiles solid

Don't do it by hand, twenty-four times. Run:

    godot --headless --path . --script res://tools/apply_tile_roles.gd

It decides from the texture's filename: anything containing **wall** or
**vertical** becomes solid and casts a shadow; everything else is floor and
has both stripped, so a tile that was solid by accident stops being solid.
Re-run it whenever you add art — it rewrites the shapes rather than stacking
another copy on top.

If your art is named differently, edit `WALL_WORDS` at the top of that file
**and** the copy in `tests/smoke.gd`. The test keeps its own list precisely so
the two have to be kept in step deliberately.

To do it by hand instead: select the tile, open **Physics** in the tile
inspector and draw a rectangle on physics layer 0, then **Occlusion** and draw
the same rectangle.

## Lighting

`scenes/world.tscn` has a `CanvasModulate` called **Night** that dims the
whole scene, and a `Lights` node holding `Lamp` instances. Without the
darkener the lamps have nothing to light and the room looks flat; set its
colour to white and you are back in daylight.

A `Lamp` exposes `radius`, `color`, `energy` and `cast_shadows` in the
inspector. Its light texture is built in code from a radial gradient, so the
radius is a number you change rather than art you redraw. A `PointLight2D`
with no texture at all is invisible, which reads as a broken light.

`World.add_lamp(cell)` puts one on a cell from code.

Three things have to line up for a shadow to fall, and missing any one fails
silently: the TileSet needs an **occlusion layer**, the wall tile needs an
**occluder polygon** on it, and the light needs **shadow_enabled**. The
render test measures the room with shadows on and off for that reason —
`shadow_enabled` on its own proves nothing.

## What Y-sorting will and will not do

Tiles in a Y-sorted TileMapLayer **sort correctly against each other**, so
tall tiles overlap in the right order. They do **not** interleave with sibling
nodes — a tile can never be drawn in front of the player, whatever origins you
set, and no error is raised. The player simply walks over the top of it.

So **anything the player must pass behind is a prop, not a tile**:
`scenes/prop.tscn`, added to the `Props` node, which is Y-sorted and contains
the player. `World.add_prop(cell)` puts one on a cell for you. A prop blocks
and shadows the patch of floor it stands on rather than its whole height, so
a lamp behind a shelf throws the shelf's shadow across the floor instead of a
wall of darkness.

Use tile layers for floors and for walls. Use props for posts, counters,
shelves — anything standing in the middle of the floor.

## Tiles taller than one cell

| Property | Value | Why |
|---|---|---|
| Size in atlas | 1 x 2 | It spans two atlas cells |
| **Texture Origin** | `(0, -8)` | Lifts it so its base sits on its cell instead of straddling it |
| **Y Sort Origin** | `8` | Moves its sort point from the middle of the cell to the bottom |

Both are in the tile inspector when a tile is selected in the TileSet panel.

## Putting your own tiles in

1. Drop your PNG in `assets/`, named so `apply_tile_roles.gd` can tell what
   it is — a wall wants **wall** in the name.
2. Select a layer in `scenes/world.tscn` and open the **TileSet** panel at
   the bottom of the editor.
3. Drag the PNG in. A 16 × 16 image becomes one tile.
4. Run `apply_tile_roles.gd`.
5. Switch to the **TileMap** tab — the one next to **TileSet** — pick the
   source on the left, tap a tile, tap the map. The **TileSet** tab edits a
   tile's properties and does not paint.

## Tile size

**16 × 16.** Pixel art is kept at its native size and the camera is zoomed
instead (`zoom = 4` on the Camera2D in `scenes/player.tscn`), so nothing is
ever resampled and the pixels stay square.

Your art must match. A texture smaller than one region makes a source with
**zero tiles in it** — nothing appears in the palette and nothing can be
painted. `tools/tileset_doctor.gd` says so in as many words.

Changing the size means changing it in three places: `tile_size` in the
TileSet, the region size on each atlas source, and `World.CELL`. Everything
else — the player, the props, the collision shapes — is expressed in cells.

## Where to build from here

- **A sprite for the player.** Swap the `_draw()` in `player.gd` for an
  `AnimatedSprite2D`. Leave the collider where it is: it is a short box around
  the feet rather than the whole body, which is what makes a character read as
  standing *in* the room instead of floating over it. `Player.facing` is
  already tracked for picking an animation.
- **Something other than the keyboard driving the player.** `Player.walk()`
  takes a direction for one physics frame and the keyboard wins while it is
  held, so NPCs, cutscenes and tests all use the same movement code instead of
  a second path that drifts out of step with it.
- **Interaction.** `World.cell_at()` turns a position into a grid cell,
  `World.is_blocked()` says whether it is solid and `World.is_floor()` whether
  it is somewhere to stand.
- **A bigger map.** The layers are unbounded; paint as far as you like.
