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
checks the player is hidden behind a prop and drawn when clear, and — by
measuring the same patch of floor with the sun drawn and hidden — that a wall
darkens the floor in front of it while open floor stays lit.

    xvfb-run godot --path . res://tools/screenshot.tscn -- --dir=/tmp/shots

    godot --headless --path . res://tools/tileset_doctor.tscn

## What is here

| | |
|---|---|
| `scenes/world.tscn` | The room: tile layers, props, lights, the player |
| `scenes/player.tscn` | CharacterBody2D with a feet-sized collider and the camera |
| `scenes/prop.tscn` | A tall thing the player walks behind, which shadows the floor |
| `scripts/sun.gd` | Daylight from outside, and the shadow the walls throw |
| `scenes/lamp.tscn` | A shadow-casting interior light |
| `tools/screenshot.gd` | Pictures of the room, including one of the whole thing |
| `scripts/world.gd` | Grid helpers; asks the tiles what is solid |
| `scripts/player.gd` | Eight-way movement |
| `resources/tileset.tres` | The TileSet. 16 × 16, one physics layer, one occlusion layer |
| `tools/apply_tile_roles.gd` | Makes wall tiles solid and shadow-casting |
| `tools/prune_missing.gd` | Repairs a tileset whose art has gone missing |
| `assets/big plank *.png` | Floor |
| `assets/*wall*.png`, `vertical.png` | Walls |

## The layers

| Layer | For | Collision | Sorting |
|---|---|---|---|
| `Ground` | Floor, and the walls painted into it | From the tile | None |
| `Walls` | Solid tiles you would rather keep off the floor layer | From the tile | Y-sorted (against each other only) |
| `Decor` | Flat clutter | From the tile | Y-sorted (against each other only) |
| `Props` | **Tall things the player walks behind** | From the prop | Y-sorted with the player |
| `Sun` | The daylight shadow, drawn over the floor | — | — |
| `Lights` | Interior lamps | — | — |

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

Daylight from outside the room, over its top-right corner, with the walls
throwing a short shadow onto the floor.

`scenes/world.tscn` has a `CanvasModulate` called **Night** setting the
ambient level, and a **Sun** node between `Ground` and `Walls`. The sun has
two knobs:

| | |
|---|---|
| `hour` | Where the sun is on a clock. Noon is straight overhead and throws the shadows straight down; each hour after moves it 15° towards the right, so `13.5` sits over the top-right corner. |
| `length` | How far a shadow reaches, in pixels. This is the sun's height: high sun, short shadow. Past half a cell it starts to read as evening. |

### The sun is drawn, not lit

A `Light2D` placed outside the room does not work, and this is worth knowing
before you try it. The wall ring occludes: a light standing behind it puts
the **entire interior** in shadow and the room goes black. There is no
setting that exempts the wall you are lighting from the wall that blocks you.

So sunlight in a top-down room is a wall-shaped smear offset across the
floor — which is also what makes it controllable. The offset *is* the time of
day, in a way an occluder-based shadow never could be, because a real 2D
shadow runs all the way to the edge of its light and cannot be shortened
without shrinking the light.

Props are drawn the same way, off their footprint rather than their height,
so a shelf darkens the floor beside it instead of painting a wall of black.

### Interior lights are still real lights

`scenes/lamp.tscn` is a genuine shadow-casting `PointLight2D` and works as it
always did — `World.add_lamp(cell)` puts one down. Nothing is placed in the
room right now because the sun lights it, but a lantern, a fire or a window
should be a `Lamp`. Take **Night** down towards black and the room becomes
dark enough for one to matter.

A `Lamp` exposes `radius`, `color`, `energy`, `cast_shadows`, `shadow_color`
and `shadow_softness`. Its light texture is built in code from a radial
gradient, so radius is a number rather than art. A `PointLight2D` with no
texture is invisible, which reads as a broken light.

`shadow_color` is not a tint over the floor — it is what the shadowed floor
gets painted with, and it is the knob for how heavy a lamp's shadows read.
Its **alpha is ignored** under the GL Compatibility renderer this project
uses, so lighten the colour, not the transparency.

### When a lamp's shadow does not appear

Three things have to line up, and missing any one fails silently: the TileSet
needs an **occlusion layer**, the wall tile needs an **occluder polygon** on
it (both from `apply_tile_roles.gd`), and the light needs **shadow_enabled**.

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

## Props

`scenes/prop.tscn` is the one prop. Give it a `texture` and the art is placed
standing on its origin; leave it empty and you get a placeholder box the same
size, which is enough to block a room out before the art exists.

It measures the **opaque part** of the art, not the canvas it was drawn on.
Twenty pixels of counter on a 32-pixel image is a twenty-pixel prop, so it
does not collide with six pixels of nothing either side.

| Property | |
|---|---|
| `texture` | The art. Sets `width` and `height` from it. |
| `footprint` | How deep it is **on the floor**. Defaults to 7 px. |
| `tint` | The placeholder box only. |

**`footprint` is the one to get right.** The default suits anything you see
the side of — a shelf, a crate, a lamp post — which stands on a shallow strip
of floor and lets a lamp behind it throw a shadow past rather than a wall of
darkness. Something seen from above, whose whole shape *is* on the floor,
wants `footprint = height` or the player walks through most of it.

### Counters

`scenes/props/counter.tscn` lays out a run of pieces. It is many props rather
than one wide sprite so the player sorts against the piece they are standing
behind, not against the whole run.

| Property | |
|---|---|
| `length` | Pieces, ends included |
| `axis` | `DOWN` or `ACROSS`. Match the art: a piece capped top and bottom is a `DOWN` run. |
| `start_texture`, `middle_texture`, `end_texture` | Capped, repeating, capped |
| `flat_on_the_floor` | On for a counter or table, off for a run of shelving |

Pieces are spaced by the size of the art, so they butt up whatever size they
are drawn. `World.add_counter(cell, length)` places one from code, and
`World.add_table(cell)` places a table.

## Tiles taller than one cell

| Property | Value | Why |
|---|---|---|
| Size in atlas | 1 x 2 | It spans two atlas cells |
| **Texture Origin** | `(0, -8)` | Lifts it so its base sits on its cell instead of straddling it |
| **Y Sort Origin** | `8` | Moves its sort point from the middle of the cell to the bottom |

Both are in the tile inspector when a tile is selected in the TileSet panel.

## When the whole project breaks at once

Deleting or renaming a PNG from outside the FileSystem dock leaves the
TileSet pointing at a path that is not there. Godot then refuses to load the
whole resource, every layer that uses it loses its tiles, and one missing
file reads as eight errors about scenes that are perfectly fine. The error
naming a `.png` is the real one; the ones naming `tileset.tres` and
`world.tscn` are consequences.

Quickest fix: put a file back at that exact path — duplicating a similar one
and renaming it will do — then remove the source properly from the TileSet
tab.

Otherwise:

    godot --headless --path . --script res://tools/prune_missing.gd
    godot --headless --path . --script res://tools/prune_missing.gd -- --apply

It reads the tileset as text rather than loading it, since a tileset in that
state cannot be loaded, and drops the dead source along with the sub-resource
and `sources/` line that go with it. Without `--apply` it only reports.

**Rename art from inside the FileSystem dock** and none of this happens —
Godot rewrites the references for you.

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
