# Asset list

What the game needs drawn, in the order it is worth drawing it.

This assumes the shop from the Abyssal Bazaar design — a shopkeeper on a
tile floor, customers who come in, shelves and a counter, goods that get
stocked and sold. If the game has moved on, the rules and the first two
sections still hold; the later ones are the ones to rewrite.

Everything is priced in **hours of your time**, not money, so the order
matters more than the length.

---

## Rules that apply to everything

These are not style preferences. Break one and the engine does something
visibly wrong.

| Rule | Why |
|---|---|
| **16 × 16 per cell**, or a whole multiple of it | Anything else cannot be sliced into tiles. A texture smaller than one cell makes a source with zero tiles and nothing appears in the palette. |
| **Native size. Never scale art up in an editor.** | The camera is at `zoom = 4`. Art drawn at 64 × 64 and shown at 16 will blur; art drawn at 16 stays crisp. |
| **PNG, transparent background** | A white or coloured background becomes a square halo once it is on the floor. |
| **No baked-in shadow** | The Sun draws shadows and the lamps cast them. A shadow painted into the sprite will not move with the light and will double up. |
| **Wall art has `wall` in the filename** | `apply_tile_roles.gd` reads the filename to decide what is solid. `crate.png` will not block you; `crate wall.png` will. |
| **Props are drawn standing up, feet at the bottom edge** | A prop's origin is its base. That is what makes the player sort behind it. |
| **One palette** | Pick 16–24 colours and stay inside them. This is the single thing that makes mismatched art look like one game. |

---

## 1. What you already have

26 files, 24 of them wired into the tileset.

| Have | Count | State |
|---|---|---|
| Floor planks | 14 | Good. More variety than most rooms need. |
| Wall pieces | 10 | Working, but incomplete — see below. |
| `wood tile crack 2`, `wood tile cracked` | 2 | In `assets/` but not in the tileset. Add them or delete them. |

**Gaps in what you have**, in priority order:

1. **Wall corners.** You have `wall corner 2` and `wall corner2` — two files a
   character apart, which is a naming accident waiting to bite. A room needs
   four outer corners and four inner corners to turn cleanly. Right now the
   map's corners are fudged.
2. **A doorway.** There is no way in or out of the room. Three tiles: left
   jamb, threshold, right jamb.
3. **`wall 1.png`** — the tileset referenced it and the file is not in the
   repo. Either upload it or the source stays deleted.

---

## 2. Tiles

Drawn at 16 × 16, painted onto `Ground`, `Walls` or `Decor`.

### Floor — about 10 new

| | Count | Notes |
|---|---|---|
| Stone or flagstone floor | 4 | A second floor material, so rooms read as different places |
| Threshold / doormat | 1 | Where the door is |
| Rug or mat | 4 | 2 × 2 arrangement, marks the selling area |
| Stained / bloodied plank | 2 | Storytelling, used sparingly |

### Walls — about 14 new

| | Count | Notes |
|---|---|---|
| Outer corners | 4 | One per direction. Non-negotiable. |
| Inner corners | 4 | For rooms that are not plain rectangles |
| Doorway | 3 | Left jamb, threshold, right jamb |
| Window | 2 | Gives the sun a reason to come from that corner |
| Shelving built into the wall | 1 | |

**These must have `wall` in the filename** or they will not be solid.

---

## 3. Props — the things the player walks behind

Scenes, not tiles, because a tile can never be drawn in front of the player.
Drawn **16 wide × 32 tall** (two cells), standing on the bottom edge.

| | Count | Notes |
|---|---|---|
| Shop counter | 3 | Left, middle, right, so it can be any length |
| Shelf unit — empty | 2 | Tall and short |
| Shelf unit — stocked | 2 | Or drawn as a separate overlay so stock can change |
| Crates and barrels | 4 | Stacked and single |
| Display table | 2 | |
| Lamp / brazier / candle stand | 3 | Something to hang a `Lamp` on |
| Plant, bucket, sack, broom | 4 | Clutter. Makes a room look lived in more than anything else on this list. |

**About 20 props.** This is the section that makes the room stop looking like
a test level, and the one most worth doing well.

---

## 4. Characters

The biggest job on the list, and the one to leave until the room is right.

### The shopkeeper (you)

Drawn **16 × 24**, feet at the bottom.

| | Frames | Notes |
|---|---|---|
| Idle | 4 directions × 2 frames | 8 |
| Walk | 4 directions × 4 frames | 16 |
| Interact / hand over | 4 directions × 2 frames | 8 |

**32 frames.** Down, up, left and right — mirror left for right and it drops
to 24, at the cost of the character always parting their hair the same way.

### Customers

The cheapest possible version: **one body, recoloured**. One 16 × 24 walk
cycle, four directions, and a palette swap per customer type. Ten customers
for the price of one.

| | Count | Notes |
|---|---|---|
| Base customer body | 1 set (24 frames) | Same rig as the shopkeeper |
| Head / hat variations | 6 | Drawn as an overlay on the base |
| Palette swaps | 8 | Data, not art |

Add a genuinely distinct silhouette only for a character who matters — a
boss, a debt collector, an inspector. Two or three, not more.

---

## 5. Goods

Everything the shop sells needs to exist twice: as an **icon** in the UI, and
as a **thing on a shelf**.

| | Size | Count | Notes |
|---|---|---|---|
| Item icons | 16 × 16 | 20–30 | One per sellable item |
| Item on shelf | 16 × 16 | Same | Can often be the icon reused |
| Stock crate, full and empty | 16 × 16 | 2 | |
| Coin / currency | 8 × 8 | 3 | Single, small pile, large pile |

Start with **8 items**. Getting the loop working matters more than having a
catalogue, and 8 is enough to have cheap goods, dear goods and one that
perishes.

---

## 6. UI

Usually underestimated. Budget as much time here as for the props.

| | Notes |
|---|---|
| 9-slice panel | One frame that stretches to any size. Do this first — everything else sits inside it. |
| Button — normal, hover, pressed, disabled | 4 states, no exceptions |
| Bitmap font | Or a licensed pixel font. Do not scale a system font — it will not sit on the pixel grid with everything else. |
| Icons | Coin, day, clock, stock, warning, close. About 10, at 16 × 16. |
| Inventory slot — empty, filled, selected | 3 |
| Dialogue box with a portrait frame | |
| Portraits | 32 × 32 or 48 × 48, one per character who speaks |

---

## 7. Effects and audio

Last, and the first thing to cut if time runs out.

| | Notes |
|---|---|
| Coin sparkle | 4 frames |
| Dust puff on footsteps | 3 frames |
| Door open / close | 3 frames |
| Footsteps on wood, on stone | 4 variations each, so they do not machine-gun |
| Coin, till, door, pick up, put down | 5 one-shots |
| Shop ambience loop | 1 |
| Music | 2 — day and night, or calm and pressured |

---

## The order to do it in

1. **Wall corners and a doorway.** The room cannot be a room without them.
2. **Ten props.** Counter, shelves, crates. This is the biggest visual jump
   for the least work.
3. **The shopkeeper's walk cycle.** Four directions.
4. **The 9-slice panel and a font.** Everything else in the UI waits on these.
5. **Eight item icons.** Enough to build the selling loop against.
6. **One customer, recoloured.**
7. Everything else.

Steps 1 and 2 are worth doing before any more code. A room with a counter and
shelves in it tells you what the game needs next; an empty one does not.
