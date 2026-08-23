# Build brief — the Thirteen Boxes table scene

Hand this to Claude Code alongside the design system. It describes the scene at
`ui_kits/thirteen_boxes/table_scene.html` — what it is, how it is built, and every
decision already settled — so the scene can be rebuilt or ported into Godot without
re-litigating the art direction.

Read first: `readme.md` (visual foundations, voice), `guidelines/asset_manifest.md`
(the full asset list with the code constraints that affect art).

---

## What this is

A single 1920×1080 stage recreating floor tier 1 (the saloon) of *Thirteen Boxes*, a dice
roguelike where the scorecard is the health bar. It doubles as a **layer lab**: every
asset in the manifest exists as a live, toggleable layer at its spec size, so each can be
exported as a PNG or read as a reference for a painter.

No build step. One HTML file, plain CSS and vanilla JS, plus `image-slot.js` for the
drop-in art placeholders. It opens directly in a browser.

## Fiction and naming — use these words

The setting is old western, and the tone is **the last hour of a long night** — lamps low,
everyone tired, nobody leaving. Not action-western; end-of-the-line western. It is a debt
game, not a saloon game.

| System | Name in the UI |
|---|---|
| The scorecard | **The Ledger** |
| Boxes | **lines**, and they are **owed** |
| Locking a die | **staking** (the tag on a die reads `STAKED`) |
| Rolling | **The Draw** (the button) |
| Floors | **nights** |
| The forge | the Assayer's Office / the Gunsmith's Bench |

The man across the table is a man — dealer, marshal, claim-jumper — never a monster.
Adversary names in the western pass: The Taxman, The Magpie, Your Brother, The Fire, The
Debtor. (The code still uses Auditor / Magpie / Twin / Furnace / Debtor as ids — rename the
display strings, not the ids.)

## The one colour rule

**Warmth is yours, cold is his.** The room, the lamplight, the wood, the paper and your own
marks are warm amber, bone and tobacco brown. The Adversary is the only cold thing in
frame — desaturated steel rim light, `#7d8b9c` / `#a3b6c8`, with a single red eye glint as
his only warm note. Loss is char black plus one thin line of ember red. When he claims a
line, something cold enters the frame.

Everything else comes from `tokens/colors.css`, which mirrors `scripts/ui/theme_colors.gd`
exactly. Two hues in this scene are **deliberately not** in that palette — the felt green
and the table brown — because a physical table needs them. Nothing else may add a hue.

## Layer stack, bottom to top

Each layer carries `data-asset` (deliverable name + spec size) and `data-key` (its toggle
group). Order matters: this is the compositing order.

1. **Back wall / room backdrop** — 1920×1080. Saloon: plank wall, wainscot, dark doorway
   with batwing doors, faint cold moonlight, bottle shelf, wanted-poster slot.
2. **Adversary** — geometric blockout (hat brim, crown, head, shoulders) with cold rim
   light and a red eye glint, behind an `<image-slot>` for real art. Seated, so he reads
   smaller than the standing player's viewpoint.
3. **Table** — a CSS 3D plane (`perspective: 1450px`, `rotateX(58deg)`, origin bottom
   centre) holding an oval poker table 2314×1716: worn wood body, grain, dirt blotches,
   three branching cracks, a padded rail bumper, and a felt oval inset.
4. **Zones on the felt** — functional, not decorative: the **pot** (centre, warm, lit), the
   **rail** (a triple-ridged groove ring, hotter), and **past the rail** (falls into shadow).
5. **Dice** — five, on the felt. See below.
6. **Table edge lip** — 1920×220, foreground, separating the play space from the chrome.
7. **Lanterns** — two, hung from the ceiling against the back wall, one per corner. Each
   has a cage, glass, a 1024×1024 circular light pool and a 1900px spill, all centred on
   the glass. They flicker on independent cycles (4.3s and 5.9s, offset) and sway on
   separate periods (11s and 13s). Each lantern's real rotation is sampled per frame into
   `--swayL` / `--swayR`, so every die casts two shadows that drift out of phase.
8. **Vignette** — 1920×1080, multiply.
9. **Paper grain** — 1920×1080, overlay, an inline SVG `feTurbulence` tile at 240px.
10. **Interface** — the Ledger and the lip strip, above the overlays so they stay readable.

## The dice

Five worn, dotted, off-brown bone dice, 176×176, in a row on the felt.

- **Pips on a 3×3 grid**, and the grid extends past 6 because `die.gd` caps faces at 9:
  7 = outer columns + centre, 8 = outer columns + top and bottom centre, 9 = all nine.
  Values above 6 mean the die has been reshaped by the Facet rule.
- **Pip spans must be `display:block`** — as inline elements their width and height are
  ignored and the dice render as blank tiles. This bug already happened once.
- All character work goes on the **body** of the die; pip faces stay clean and
  high-contrast, readable at 30% scale. Wear must never make a value ambiguous.
- Chipped silhouette via `clip-path`, two nicked corners, grime blotches at 32% opacity
  under the face, not over it.
- **Staked** dice go gold with a `STAKED` tag; staking lasts the whole floor, so it should
  look permanent — sealed, not held. **Bitter** dice go violet with hairline cracks.
- Throwing runs a 640ms tumble with a per-die stagger, and staked dice keep their face.

## The Ledger

Paper, not felt. Foxed and stained, 610px wide, **all thirteen lines always visible**, and
the second most important object on screen after the dice.

The critical distinction, because it is the game's central threat:

- **Your scores** — pencil. Soft graphite mono, `#3c3b42`.
- **His scores** — ink. Near-black `#101c26`, bold, with a bleed shadow and a cold wash
  behind the line.
- **Scratched lines** — struck through hard with a gouged pencil line. A written zero is a
  sacrifice, not a failure, so it should look violent.
- **Burned lines** — a scorch hole. Nothing written, nothing writable.

A player should be able to tell how much of the Ledger they have lost from across the room.

## Controls in the lab

A collapsible panel, top right, that must never overlap the stage — the fit function
reserves a gutter for it and rescales the stage into the remainder. Toggles for all eight
layer groups, a wood/oak surface switch, camera pitch, per-lantern intensity, vignette
weight and grain amount.

## Known open issues

1. **Camera pitch is currently 144°**, which is past edge-on (90°) — the table is facing
   away and reads inside-out. Usable ceiling is about 78–84°; the settled value was 58°.
2. **Lantern pools were aimed at the 58° camera.** Any pitch change needs them re-aimed or
   the felt goes washed-out grey-green.
3. **The vignette floor was raised** to stop it eating the Ledger, which now lets the
   lanterns blow out at the top corners. It needs shaping, not lifting.
4. **No hands.** A first-person pass wanted wrists at the near edge; approximated in CSS
   they read as cardboard. Imply the player through the near rail instead, and leave an
   `<image-slot>` at the bottom edge for real art.
5. **The adversary and every character are blockouts, not art.** So are the charm relics,
   the parchment, the die bodies and the icons. See the manifest for what needs a painter.

## If you port this to Godot

- The palette already lives in `scripts/ui/theme_colors.gd`. Do not fork it — generate one
  from the other so the CSS and the GDScript cannot drift.
- The light pools, vignette and grain are gradients and noise: export them as PNGs at the
  sizes in `data-asset` and composite with the same blend modes (screen for the pools,
  multiply for the vignette, overlay for the grain).
- The table's 3D plane maps to a single quad with a perspective camera at roughly 58° pitch;
  the zones are texture regions on the felt, not separate geometry.
- Keep the two-shadow-per-die behaviour. Two light sources is the reason the table feels lit
  rather than drawn.
