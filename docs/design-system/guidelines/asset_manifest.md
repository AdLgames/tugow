# Asset manifest — Thirteen Boxes

Every asset the game needs, with the sizes and counts agreed, plus the **code constraints
an artist will otherwise get wrong**. Sources: `scripts/core/die.gd`, `scripts/core/scoring.gd`,
`scripts/core/scorecard.gd`, `scripts/adversary/roster.gd`, `scripts/autoload/balance.gd`.

Status key: **built** = exists in this design system as live HTML/CSS you can export;
**spec** = defined here, needs a painter or an image model; **blocked** = needs a person
(licensing, recording).

---

## 0. Naming and delivery

```
adversary/<id>_<state>.png        auditor_idle.png · magpie_declare.png · twin_react.png
adversary/<id>_shadow.png
dice/body_<name>.png              body_ash.png … body_hollow.png
dice/pips_<n>.png                 pips_1.png … pips_9.png
dice/ov_locked.png · ov_bitter.png · ov_faceted.png · die_shadow.png
dice/tumble_sheet.png             8 frames, 256x256 each, horizontal
card/parchment.png · row_<state>.png · stamp_claim.png · mark_scorch.png · mark_scratch.png · mark_reclaim.png
ui/frame_<tone>.png · button_<state>.png · meter_<part>.png · icon_<name>.png
charm/<id>.png                    grudge · symmetry · tithe · sleeping_giant · accountant · pigeonhole · blood_pact
room/backdrop_tier<1-4>.png · table_top.png · felt_inset.png · edge_lip.png · lantern_pool.png · vignette.png · grain.png
```

Adversary ids are the code's own: `auditor`, `magpie`, `twin`, `furnace`, `debtor`.
Die names are the code's own, in pool order: Ash, Bramble, Cinder, Dovetail, Ember, Flint,
Gallows, Hollow (a ninth, Ivory, is purchasable at the forge — budget a 9th body).

---

## 1. Table and room — **built** (see `ui_kits/thirteen_boxes/table_scene.html`)

| Asset | Size | Count | Status |
|---|---|---|---|
| Back wall / room backdrop | 1920×1080 | 4, one per floor tier | tier 1 (saloon) built; 2–4 spec |
| Table top (perspective) | 1920×700 | 1 | built — oval poker table, 58° standing camera |
| Felt inset / rolling area | 900×360 | 1 | built |
| Table edge lip (foreground) | 1920×220 | 1 | built |
| Lantern light pool | 1024×1024 | 2 | built — circular, centred on each lantern glass |
| Paper grain + vignette | 1920×1080 | 2 | built — grain tiles at 240px |

Tier logic is **room changes** — different architecture per tier, not just a darker grade.
Tier 1 is the saloon. Tiers 2–4 unspecified; each needs its own backdrop and its own
lantern positions, since the light pools are authored against the room.

---

## 2. The Adversary — five characters — **spec**

| Asset | Size | Count |
|---|---|---|
| Adversary body, seated | 700×800 | 5 × 3 states = 15 |
| Adversary shadow | 700×200 | 5 |
| Declaration placard | 320×180 | 1 shared — **built** |

The three states are **idle**, **declaring** (leaning in), **reacting** (claim landed / denied).
Declaring is the load-bearing beat: `adversary.gd` announces the target box *before* it
rolls, and that one turn of warning is the whole tactical layer.

Constraints from the code:
- **The Furnace does not claim, it burns.** Its "claim landed" state should read as
  destruction, not acquisition — the box is gone unscored ("burns Sixes to ash").
- **The Debtor overwrites boxes you already filled.** Its reacting state is the only one
  that plays over a box that was *yours*.
- **The Twin wears your last roll** — `_roll_toward()` returns `last_player_values`
  verbatim. Reusing the player-side silhouette tinted is correct and cheap; it mirrors you literally.
- **Seven boxes and it takes the card** (`adversary_card_limit = 7`). The reacting state
  needs to escalate — the seventh claim is a run-ending beat, not a routine one.
- The player is standing (the camera is at standing head height); the Adversary is **seated**,
  which is why it reads smaller in frame and leans *up* into the light to declare.

Full version: 4–8 frame idle loops per character instead of a single still (~40 frames).

**Blockout available now:** the scene carries a geometric hat/head/shoulders silhouette with
lantern rim light behind an `<image-slot>` — drop finished art on top of it.

---

## 3. Dice — the biggest and most constrained set

| Asset | Size | Count | Status |
|---|---|---|---|
| Die body / material | 256×256 | 8 (+1 for Ivory) | spec |
| Pip layouts (overlay) | 256×256 | 9 | **built** — see the pip card |
| Bitter overlay | 256×256 | 1 | spec |
| Locked overlay | 256×256 | 1 | spec |
| Faceted marker | 64×64 | 1 | spec |
| Die shadow | 256×128 | 1 | built (two, one per lantern) |
| Tumble animation | 256×256 | 8 frames | spec |

19 sprites + 1 sheet instead of 8 × 9 = 72. The split is body (material) × pips (value).

**Two constraints that will bite:**

1. **Faces go above 6.** `die.gd` sets `FACE_CAP := 9` and the Facet rule pulls the
   weakest face up one pip every third scoring lock, so a die can legitimately show 7, 8
   or 9. The 3×3 pip grid extends cleanly and is what this system uses:

   | Value | Grid cells filled |
   |---|---|
   | 1 | centre |
   | 2 | two opposite corners |
   | 3 | diagonal |
   | 4 | four corners |
   | 5 | four corners + centre |
   | 6 | two full outer columns |
   | 7 | two full outer columns + centre |
   | 8 | two full outer columns + top and bottom centre |
   | 9 | all nine |

   7–9 are the non-standard arrangements; they stay on the same grid so one overlay set
   covers every value and 7 never gets mistaken for 6.

2. **They must read at two sizes** — large on the felt and ~64px in the strip under the
   table. Pips at 64px are roughly 9px across: keep pip diameter ≥ 28% of the die width,
   keep the material's value contrast high (a glass or ember body needs a dark pip well),
   and do not put the faceted notch or the bitter crack where a pip sits.

**Materials, distinct at a glance** (names are the code's, the material read is open):
bone, brass, wood, glass, ember are the five suggested; eight bodies need eight reads.
By floor six the player should recognise Gallows on sight without reading the label.

- **Bitter** = cracked, violet sheen (`--tb-bitter #9d6bd6`). Earned by being locked into a
  scratched box; it refuses its lowest face afterwards.
- **Locked** = wax seal or clamp. Locking is **for the whole floor, not the turn**, so it must
  look permanent — sealed, not held. Gold (`--tb-locked #d9a441`).
- **Faceted** = small notch, 64×64, showing the die has been reshaped away from 1–6.

---

## 4. The card — thirteen boxes as a physical object

| Asset | Size | Count | Status |
|---|---|---|---|
| Card / parchment | 760×980 | 1 | spec (ruled for 13 rows) |
| Row state treatments | 700×56 | 5 | **built** — open, yours, theirs, burned, scratched |
| Claim stamp | 220×80 | 1 | **built** |
| Scorch hole | 200×70 | 1 | **built** |
| Scratch X | 200×70 | 1 | **built** |
| Reclaim flourish | 220×80 | 1 | **built** |

Constraints: the card is **never reset between floors** — it is the health bar, so wear
accumulates across a whole run and the parchment must survive thirteen marks without
becoming unreadable. `scorecard.gd` distinguishes `open / PLAYER / ADVERSARY / BURNED`, and a
**scratch is a written zero — a sacrifice, not a failure** — so the scratch X should look
violent while the burn should look like absence. Reclaim (out-scoring an Adversary returns 3
boxes) is the only mark that *removes* another mark: an erasure, not a new stamp.

---

## 5. UI frames and icons — mostly **built as CSS**, sprites are **spec**

| Asset | Size | Count | Status |
|---|---|---|---|
| Corner panel frame (9-slice) | 256×256 source | 2 (neutral, adversary-red) | built as 1px/4px CSS panels; 9-slice art is spec |
| Button (9-slice) × 4 states | 192×64 source | 4 | built as CSS (default, hover→gold, pressed, disabled-keeps-tint) |
| Threshold meter: track, fill, cap | 512×48 | 3 | built (140×18 in engine) |
| Icons | 64×64 | ~12 | **spec — and a deliberate departure** |
| Charm relic art | 192×192 | 7 | spec |
| Forge backdrop | 1920×1080 | 1 | spec |

**On icons:** the shipped prototype has none — every affordance is a word or a number, and
the only glyph is the ASCII `>` marking the announced box. The 12 icons on this list
(lock, reroll, box-left pip, carry, forge, facet, bitter, deny, burn…) are therefore a
*new* system, not a recreation. Worth deciding deliberately: they buy legibility at 64px in
the strip, and they cost the "legible without a single tooltip" property the design doc
claims. If they ship, they need one stroke weight and one fill rule across all twelve.

**Charms** are relics that react to dice behaviour, and their names are already vivid —
Grudge, Symmetry, The Tithe, Sleeping Giant, The Accountant, Pigeonhole, Blood Pact. Blood
Pact burns two boxes a turn instead of one, so it should look like the worst bargain on the table.

---

## 6. Fonts, effects, audio — **blocked**

- **Fonts:** one display face + one body face, commercially licensed, 2 files. **Numerals
  matter most** — every score is read at a glance and scores range from 0 to 2,592. This
  system currently substitutes Cinzel / Lora / IBM Plex Mono from Google Fonts; the mono
  face is doing the numeral work and any replacement must be tabular.
- **Particles:** dust puff, ember, ink splatter, soft glow, smoke — 64×64, ~5 PNGs. Spec.
- **SFX (~18):** dice roll + 3 land variants, lock clunk, pen scratch, stamp thud, paper
  burn, 5 per-adversary stingers, forge hammer, descend, run end. I cannot produce audio.
- **Music:** 2–3 loops — descent, duel, forge.

The lock clunk and the pen scratch are the two sounds the game leans on hardest: locking is
permanent for the floor, and writing a box spends it for the run. Both should sound final.

---

## Totals

| | Minimum playable | Full |
|---|---|---|
| Sprites | ~75 | ~130 + animation frames |
| Audio | ~12 | ~21 |

Of the minimum-playable sprite set, the room layers, the nine pip overlays, the die shadows,
the five row treatments, the four card marks, the placard, the meter, the buttons and the
panel frames are **built here as live CSS** and can be exported at spec size. What genuinely
needs a painter: 15 adversary stills + 5 shadows, 8–9 die bodies, 3 die overlays, the
parchment, 7 charm relics, 3 backdrops, the forge backdrop, 12 icons, 5 particles.
