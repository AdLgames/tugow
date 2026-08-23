repo: AdLgames/tugow
branch: main

## Last sync

date: 2026-08-23T07:01:34Z

### Updated in this project

- Palette, panel style and every control size taken from `scripts/ui/`.
- Box names and rule strings taken verbatim from `scripts/core/scoring.gd`.
- Adversary and charm copy taken from `scripts/adversary/roster.gd` and `scripts/core/charms.gd`.
- `icon.svg` copied unaltered to `assets/logo.svg`; no other art exists upstream.

## Screen map

| Project screen | Built from |
|---|---|
| `ui_kits/thirteen_boxes/index.html` (floor + duel) | `scripts/ui/main.gd`, `scripts/ui/die_view.gd`, `scripts/ui/theme_colors.gd` |
| `ui_kits/thirteen_boxes/engine.js` (run loop) | `scripts/core/game.gd`, `scripts/core/scoring.gd`, `scripts/core/scorecard.gd`, `scripts/core/dice_pool.gd`, `scripts/autoload/balance.gd` |
| `ui_kits/thirteen_boxes/screens.jsx` (forge, title, run over) | `scripts/ui/main.gd` overlay screens, `scripts/core/forge.gd` |
| `components/game/*` | `scripts/ui/main.gd`, `scripts/ui/die_view.gd` |
| `components/core/*` | `scripts/ui/theme_colors.gd` (`panel_style`), `scripts/ui/main.gd` |
| `tokens/*.css` | `scripts/ui/theme_colors.gd`, container constants in `scripts/ui/main.gd` |
| `guidelines/*.card.html` | `docs/DESIGN.md`, `docs/BALANCE.md` |
