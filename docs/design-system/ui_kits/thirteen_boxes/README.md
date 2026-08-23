# Thirteen Boxes — game client

The only product surface: one 1280×720 window, mouse-driven, never scrolled.
Recreated from `scripts/ui/main.gd` and `scripts/ui/die_view.gd`.

## Screens

| Screen | Source | Notes |
|---|---|---|
| Title | `_show_title()` | Blurb, meta stats, one button: Descend. |
| Floor | `_build()` + `_refresh()` | Header, THE CARD, THE TABLE, side column (adversary / charms / log). |
| Duel floor | same, with `_refresh_adversary()` | Floors 3, 5, 7, 9, 10, 11, 12. The announced box is marked `>` and turns orange. |
| Forge | `_show_forge()` | Overlay; offers priced in boxes, unaffordable ones disabled. |
| Run over | `_on_run_ended()` | Reason, run total, Again. |

## Interactions that work

Descend · roll and reroll (2 per turn) · click a die to lock it for the floor · click an
open box to write it (live previews update per roll) · scratch a box for zero (locked dice
turn bitter) · clear the threshold to reach the forge · spend boxes at the forge · duel
floors where the Adversary announces, then claims, and out-scoring it reclaims 3 boxes ·
run ends when the card fills, an Adversary claims seven boxes, or floor 12 is cleared.

## Deliberately simplified

- Charms are listed but not simulated (the forge line logs the take).
- Facets and the Grudge/Tithe/Symmetry effects are not resolved.
- The Adversary rolls fresh dice rather than drawing from the shared pool; the Twin does
  not mirror your last roll and the Magpie does not lock dice away.
- Forge sacrifices are auto-picked instead of asking which box to burn.
- Dice faces stay 1–6 (no reshaping past 6).

Everything visual — palette, sizes, spacing, copy, states — matches the source.

## Files

`index.html` (mount) · `engine.js` (run loop, scoring resolver on the TEMPERED curve) ·
`screens.jsx` (FloorScreen, TablePanel, SideColumn, TitleScreen, ForgeScreen, RunOverScreen) ·
`app.jsx` (state wiring).
