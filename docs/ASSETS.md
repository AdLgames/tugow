# Abyssal Bazaar — assets

**The game ships with no art.** Every tile slot falls back to a flat colour,
so it runs, renders and passes its tests with `assets/tiles` empty. Adding
tiles is a matter of dropping PNGs in or assigning them in the inspector —
see `assets/tiles/README.md` for the slot names and sizes.

## Where the art seam is

`scripts/ui/tile_theme.gd` is the only place that names a file. `Tiles` turns
a slot into a texture or, failing that, into a colour. `WorldView` draws
whichever it gets. Nothing else in the game knows art exists.

That is the same seam that let the projection change three times without
touching a rule: the simulation deals in whole tile coordinates and
`scripts/ui/grid_map.gd` is the only thing that turns them into pixels.

## Both layouts exist

`Balance.projection` is one of `Balance.View.ORTHOGONAL` (the default,
three-quarter top-down on a square grid) or `ISOMETRIC` (2:1 diamonds). Both
are built and both are tested.

`tests/tests.gd` checks them headlessly: every tile of both floor sizes
survives the `centre -> tile_at` round trip, isometric tiles are exactly 2:1
and square ones exactly 1:1, and depth increases away from the camera in
both. Tapping is the only way input reaches the game, so a tile that does not
come back is a tile nobody can press — and it would fail in silence.

The two layouts want different art. A diamond tile on a square grid leaves a
transparent notch at every corner; a flat-bottomed sprite on a diamond grid
stair-steps and will not meet its neighbour. Pick a layout, then draw for it.

## Sizing rules

**Floors** are square and fill their cell.

**Walls** are one cell wide, drawn at their own aspect, standing on the bottom
of their cell — so the sprite's proportions decide how tall the wall is. A
64x128 sprite is two cells tall.

**Which face you see** depends on which side of the room the wall is on. The
camera looks straight ahead: only the back wall shows a tall front, the sides
are seen end-on, and the near wall is a low sill or it would stand between the
camera and the floor. On a diamond grid every wall is at the same angle and
one face does for all of them.

## Corruption is a floor, not a tint

As Corruption rises the tiles are replaced by the corruption slot, one at a
time in a fixed order, so a shop going bad is something that creeps outward
and always creeps the same way — the design document's "rotting inventory
spreading across your clean pixel-art grid", done as geometry rather than a
colour filter.

## Layering

- **Layer 0, the floor.** No sorting. Nothing can walk behind a floor.
- **Layer 1, everything standing.** Sorted back to front on `GridMap2D.depth`
  — the row when square, `x + y` isometric — measured from the centre of the
  cell a figure is standing on, so she passes behind what is above her and in
  front of what is below.

There is no physics: the simulation asks `Shop.walkable()` before accepting a
destination, so a wall is somewhere you cannot be told to go rather than
something you bump into.

## Still drawn in code

Tables, cases, people and the stock on the tables are polygons. Sprites for
those would need their own slots adding to `TileTheme`; a shopkeeper and two
or three customers, ideally with four facings, would do the most.
