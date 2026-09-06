# Abyssal Bazaar — assets

The art is **isometric**: 2:1 diamonds, not square tiles. The design document
asked for three-quarter top-down, and the first pass was built that way, but
diamonds cannot be laid on a square grid without looking broken — so the
projection follows the art. The simulation never learned about either; it
deals in whole tile coordinates and `scripts/ui/world_view.gd` is the only
file that knows where they land on a screen.

## The tileset

| File | Used for |
|---|---|
| `planks.png` | Level 1 floor — the cozy wooden shop |
| `moss.png` | The clearing outside the walls, and the doorway |
| `grate.png` | Level 2 floor — cold iron |
| `white_tile.png` | The level 2 backroom |
| `kintsugi.png` | The altar. Black stone, gold and red in the cracks |
| `flesh_cobble.png` | **Corruption.** See below |
| `log.png` | Level 1 walls, repeated across each tile as a stockade |
| `wall_rust.png` | Level 2 walls |
| `wall_door.png` | The level 2 wall the door is in |

Every floor texture is a diamond whose **top vertex sits at the top of its own
image**; anything below the diamond is that tile's thickness and hangs over
the row behind it. So a floor tile is placed by its top vertex and scaled to
the tile width, and the art keeps whatever depth it was drawn with.

**Walls are scaled by height, not width.** A log is tall and narrow, an iron
panel is square; sizing either by tile width puts one of them three tiles
high. A narrow post is repeated across its tile so a run of logs reads as a
cabin wall rather than a picket fence.

## Corruption is a floor, not a tint

`flesh_cobble.png` is grey cobble with meat set between the stones, and it is
what Corruption looks like. Rather than washing the floor green, the tiles
themselves turn — one at a time, in a fixed order, so the spread reads as a
spread and always creeps the same way. At full corruption the whole shop is
walking on it.

This is the design document's "rotting inventory spreading across your clean
pixel-art grid", done as geometry rather than as a colour filter.

## What is still drawn in code

Tables, display cases, people and the stock on the tables are built from
polygons in the same projection — a top diamond and two side faces. They can
be replaced with painted sprites without the layout moving.

Still wanted: table and case sprites, a shopkeeper and a few customer sprites
(ideally with a walk cycle in four facings), and corner pieces for the wall
runs.

## Layering

Drawn the way the floor is built:

- **Layer 0 — the floor.** No sorting at all. Nothing can walk behind a floor.
- **Layer 1 — everything standing.** Sorted back to front by `x + y`, which
  is the isometric depth order, so a figure walking up the room slides behind
  the wall in front of her.

There is no physics: the simulation asks `Shop.walkable()` before it accepts a
destination, so a wall is somewhere you cannot be told to go rather than
something you bump into.

`tests/ui_smoke.gd` checks that every tile on both floors survives the
projection round trip — tapping is the only way input reaches the game, so a
tile that does not come back is a tile nobody can press.
