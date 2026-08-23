# Thirteen Boxes — Design System

*A dice roguelike where the scorecard is your health bar.*

Thirteen Boxes is an indie head-to-head roguelike being built for Steam in Godot 4.
Yahtzee's scorecard is treated as a roguelike run: thirteen boxes, each usable once,
never reset between fights. You descend twelve floors; each floor demands a score
threshold, and **every turn you take spends one box off your card for the rest of the
run**. On duel floors an Adversary writes into the same card, announcing its target box
before it rolls. Out-scoring an Adversary is the only healing in the game.

There is exactly one product surface: **the game client** (1280×720, keyboard-and-mouse,
one window). No marketing site, launcher, or companion app exists in the source, so this
system does not invent one.

## Sources this system was built from

- GitHub: **https://github.com/AdLgames/tugow** (branch `main`) — the Godot 4 prototype.
  - `scripts/ui/theme_colors.gd` — the entire palette, verbatim, and `panel_style()`.
  - `scripts/ui/main.gd` — the whole interface: header, scorecard, table, side column, overlay, and every size and separation in this system.
  - `scripts/ui/die_view.gd` — the die tile (92×104) and its condition tints.
  - `scripts/core/scoring.gd` — the thirteen box names and rule strings, used verbatim as UI copy.
  - `scripts/core/{game,scorecard,dice_pool,die,charms,forge}.gd` — the run loop and all in-game copy (log lines, forge offers, charm text).
  - `scripts/adversary/{adversary,roster}.gd` — the five Adversaries and their blurbs.
  - `docs/DESIGN.md`, `docs/BALANCE.md`, `docs/STEAM.md` — design intent, tuned numbers, shipping notes.
  - `icon.svg` — the project icon, copied unaltered to `assets/logo.svg`.

Readers with repo access should explore it further: the copy in this system is lifted from
those files, and anything not covered here (achievement strings, balance constants) lives
there. See `github.md` for the sync record.

---

## CONTENT FUNDAMENTALS

The voice is **flat, second person, and permanent**. The game states consequences as
facts and never softens them.

- **Person.** "You" for the player, "it" for the Adversary. The player is never
  addressed as "the player" and the game never says "we".
- **Casing.** Titles and headings are uppercase display type: `THIRTEEN BOXES`,
  `THE CARD`, `THE TABLE`, `THE FORGE`. Body copy is sentence case with full stops,
  including single-line hints.
- **Sentence shape.** Short declaratives, often a statement plus its cost:
  "Writing a box ends the turn and spends it for the rest of the run."
  "Locked is locked for the whole floor, not the turn."
  "Sacrifice 2 more boxes. This is permanent."
- **Naming.** Boxes keep their Yahtzee names (Aces … Chance). Rules are written as
  operations in plain words, not symbols: `Quad face cubed x 5`, `Span (max 4) x
  highest x 5`, `Sum, doubled per 6`. Use `x` for multiply — never `×` or `*`.
- **Log lines** are past-tense reports, mono, one per event:
  "Locked Ash on 5 for the floor." · "Scratched Yahtzee. A hole for the rest of the run."
  · "The Furnace burns Sixes to ash." · "You out-scored The Magpie, 402 to 244. 3 boxes come back."
- **Failure is never scolded.** A zero is a "scratch" — a sacrifice play. The word
  "failure" does not appear; "hole", "burned", "bitter", "gone" do.
- **Numbers are shown, not described.** `265 / 385`, `9 boxes left`, `Boxes taken: 2/7`.
  Never "almost there" or "you're doing great".
- **No exclamation marks. No emoji. No second-person questions.** The nearest thing to
  encouragement in the whole game is "Descend".
- **Dice and Adversaries are proper nouns.** Ash, Bramble, Cinder, Dovetail, Ember,
  Flint, Gallows, Hollow; The Auditor, The Magpie, The Twin, The Furnace, The Debtor.
  Charms too: Grudge, Symmetry, The Tithe, Sleeping Giant, The Accountant, Pigeonhole,
  Blood Pact.

---

## VISUAL FOUNDATIONS

**Colour.** One palette, thirteen values, all from `theme_colors.gd`. Page black
`#14121a`, panel `#1d1a25`, panel edge `#2e2a3a`. Ink is bone `#e8dcc0` with one dim
step `#9a9184` for everything secondary — there is no third grey. Every other colour is a
*state*, never decoration: player green `#6fae7c`, adversary red `#c8452f`, burned
`#55505e`, locked gold `#d9a441`, bitter purple `#9d6bd6`, declared orange `#e0703c`.
The mood is a lit table in a dark room: warm ink and warm accents on a cold near-black
that carries a faint violet cast. **Never introduce a hue that is not in the palette**,
and never use two accents for the same meaning.

**Type.** The prototype ships no font files; the substitutions here are Cinzel (engraved
caps — titles, box names, buttons), Lora (rules, blurbs, hints) and IBM Plex Mono (every
number, every log line, every tag). Display type is uppercase and tracked `0.14em`;
body is sentence case at 1.45 line-height; numbers are tabular. Sizes come from the
Godot UI: 22 overlay title, 20 header, 16 base, 14 small, 12 log, 34 for a die's face.

**Spacing.** The real container values are 2, 6, 8, 10, 12, 16, 20 — not a 4/8 grid.
Panels pad 10px horizontally and 8px vertically. The window insets 16/12. Rows of
thirteen boxes sit 2px apart, which is what makes the card read as a single ruled object.

**Layout.** One fixed 1280×720 window, never scrolled, three columns under a full-width
header: card (stretch 0.95, min 320) · table (stretch 1.4) · side column (0.85, min 280).
The table centres its dice with equal spacers above and below. Nothing floats; the only
overlapping element in the game is the centred overlay.

**Backgrounds.** A single flat `ColorRect` of page black. No images, no gradients, no
noise, no textures, no illustration. Depth comes only from the panel/page value step and
1px edges. The one permitted fill over black is a 12–14% state wash (locked gold behind a
locked die, adversary red behind a claimed row, declared orange behind an announced row).

**Borders, corners, shadows.** Every surface is a 1px border with a 4px radius — panels,
buttons, dice, the meter. Nothing is rounder, nothing is pill-shaped, nothing is square.
Godot draws no drop shadows, so neither does this system: the sole exception is the modal
overlay, which gets an ink-coloured 1px edge plus a deep scrim so it reads as taking the
screen. Cards, in this design language, *are* panels: flat fill, hairline edge, no shadow.

**Transparency and blur.** No blur anywhere — no frosted panels, no backdrop-filter.
Transparency is limited to the state washes and the overlay scrim (`#14121a` at 82%).

**Animation.** The prototype animates nothing; it rebuilds rows on state change. Keep
motion at that level of restraint: 90–160ms linear colour and width transitions
(threshold meter fill, a die's edge lighting when locked). No easing curves, no bounce,
no fades between screens, no dice-tumble animation. If something must move, it should
look like a value changed, not like a thing travelled.

**Hover and press.** Hover *brightens toward gold* — `main.gd` sets `font_hover_color`
on every box row to locked gold `#d9a441`; buttons lift their border to the ink dim.
Press does not scale or shift; the value simply changes. Disabled elements **keep their
tint** (the source sets `font_disabled_color` to the same colour deliberately) and only
lose their cursor: an unaffordable forge offer and a spent box must stay readable, because
the card you can no longer use is the information.

**Iconography.** See below — there is essentially none, by design.

---

## ICONOGRAPHY

The game ships **one** piece of vector art: `icon.svg`, the project icon, copied here as
`assets/logo.svg`. It is a ruled card — a 3×3 grid inside a rounded square, drawn in bone
ink on page black — with three adversary-red pips falling diagonally through it. That
mark is the whole brand identity; there is no separate wordmark file, so the wordmark is
`THIRTEEN BOXES` set in the display face, uppercase, tracked.

Beyond it the interface has **no icon set at all**: no icon font, no sprite sheet, no PNG
glyphs, no CDN icon library, no emoji. Every affordance is a word or a number. This is a
deliberate property of the design — "legible at a glance without a single tooltip" — and
new work should follow it:

- Status is carried by **colour + a word**: `you 180`, `them 512`, `burned 0`, `scratch`.
- Die condition is carried by **lowercase mono tags** under the face: `LOCKED`, `bitter`,
  `again`, `faceted`.
- The only glyph used as an icon is the ASCII **`>`** marker that `main.gd` prefixes to
  the box the Adversary has announced. Unicode arrows, chevrons and dingbats are not used.
- Dice show **numerals, not pip patterns** — faces can be reshaped past 6 (up to 9), so
  pips could not represent them.

If a future surface genuinely needs icons, flag it rather than importing a set: nothing in
the source sanctions one.

---

## Components

Authored from the widgets `scripts/ui/` actually defines — no more.

**Core** (`components/core/`)
- `Panel` — PanelContainer + `panel_style()`; the only container, with a coloured edge.
- `Button` — the game's button in its three real shapes: action (Roll), overlay row, box row.
- `StatLabel` — dim mono header readout.
- `ThresholdBar` — the 140×18 threshold meter.
- `LogView` — the run log, dim mono, auto-scrolled.

**Game** (`components/game/`)
- `Die` — one die on the table, 92×104, click to lock for the floor.
- `BoxRow` — one of the thirteen: name, operation, preview or spent result.
- `Scorecard` — THE CARD; thirteen `BoxRow`s (exports `BOXES`, the canonical names and rules).
- `AdversaryPanel` — who is writing on your card and what it announced.
- `DeclarationPlacard` — the 320×180 chit the Adversary slides onto the felt naming its next box.
- `Overlay` / `OverlayText` — the one modal shell: title screen, forge, run over.
- `HeaderBar` — wordmark, floor, threshold meter, boxes left.

**Intentional additions:** none. `Panel`, `Button`, `StatLabel`, `ThresholdBar` and
`LogView` are direct stand-ins for the Godot widgets the game themes; everything else is a
one-to-one recreation of a construct in `main.gd`.

**Not built, because the source has none:** tabs, tooltips (beyond native `title`),
toasts, avatars, inputs, selects, checkboxes, switches, badges, menus, settings screens.

## UI kit

`ui_kits/thirteen_boxes/` — the game client at its real 1280×720, playable: title screen →
descend → roll, reroll, lock dice, write boxes → forge between floors → duel floors 3, 5,
7, 9, 10, 11, 12 → run over. Scoring, thresholds (60 × 1.45ⁿ⁻¹), duel floors and the
3-box reclaim mirror the committed balance values. See its README for what is simplified.

---

## Index

| Path | What is in it |
|---|---|
| `styles.css` | The entry point consumers link — `@import`s only |
| `tokens/colors.css` | The palette and its semantic aliases |
| `tokens/typography.css` | Font stacks, sizes, tracking (webfonts via Google Fonts) |
| `tokens/space.css` | Separations and every fixed control size |
| `tokens/shape.css` | Borders, radii, the two allowed shadows, motion |
| `tokens/base.css` | Page defaults, `.tb-panel`, `.tb-heading`, link colours |
| `components/core/`, `components/game/` | The eleven components, each with `.d.ts` + `.prompt.md` |
| `guidelines/*.card.html` | Foundation specimen cards (Colors, Type, Space, Shape, Brand) |
| `ui_kits/thirteen_boxes/` | The playable game-client recreation |
| `assets/logo.svg` | The project icon, unaltered |
| `github.md` | Source repo and last sync |
| `SKILL.md` | Agent-skill entry point |

## Substitutions to confirm

- **Fonts.** The Godot prototype uses the engine's default UI face and ships no font
  files, so type here is a judgement call: **Cinzel** (display), **Lora** (body),
  **IBM Plex Mono** (numbers/log), loaded from Google Fonts. If the game picks real
  faces, send the files and this system will be re-cut around them.
- **Nothing else is substituted.** Colours, sizes, spacing, copy and the logo are taken
  from the repo as-is.
