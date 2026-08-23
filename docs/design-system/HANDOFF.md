# Handoff — commit the design system into `tugow`

The design system was built by reading `AdLgames/tugow@main` but **nothing has been pushed**.
This file tells Claude Code (or you) exactly what to commit and where.

## Source of truth

- Repo: `AdLgames/tugow`, branch `main`
- Read at: 2026-08-23 (tree `d0fc10726941`)
- Files read: `README.md`, `docs/{DESIGN,BALANCE,STEAM}.md`, `project.godot`, `export_presets.cfg`,
  `icon.svg`, `scripts/ui/{theme_colors,main,die_view}.gd`,
  `scripts/core/{scoring,game,scorecard,dice_pool,die,charms,forge}.gd`,
  `scripts/adversary/{adversary,roster}.gd`, `scripts/autoload/{balance,run_state}.gd`
- Nothing in the repo was modified.

## Proposed commit layout

The design system is web tooling, not game runtime — keep it out of the Godot import path.
`export_presets.cfg` already excludes `docs/*`, so `docs/design-system/` ships nothing.

```
docs/design-system/
  readme.md                  design guide: content fundamentals, visual foundations, iconography
  SKILL.md                   agent-skill entry point (name: thirteen-boxes-design)
  styles.css                 @import entry point
  tokens/                    colors, typography, space, shape, base
  components/core/           Panel, Button, StatLabel, ThresholdBar, LogView
  components/game/           Die, BoxRow, Scorecard, AdversaryPanel, DeclarationPlacard, Overlay, HeaderBar
  guidelines/                specimen cards + asset_manifest.md
  ui_kits/thirteen_boxes/    playable client recreation + table_scene.html
  assets/logo.svg            copy of the repo's own icon.svg — do not re-add, or symlink it
  github.md                  sync record
```

Suggested commit message:

```
docs: add Thirteen Boxes design system

Palette, type, spacing and component recreations derived from scripts/ui/
and scripts/core/. Includes an asset manifest with the code constraints
that affect art (faces cap at 9, locked is per-floor, 64px pip legibility).
```

## Things to check before committing

1. **`assets/logo.svg` duplicates `icon.svg`.** Either drop it and point the HTML at
   `../../../icon.svg`, or keep the copy for portability. Don't let them diverge.
2. **`_ds_bundle.js`, `_ds_manifest.json`, `_adherence.oxlintrc.json` are generated.**
   Add them to `.gitignore` rather than committing them, unless you want the HTML in
   `ui_kits/` and the component cards to work straight from a checkout — they need the
   bundle. If you want a working checkout, commit `_ds_bundle.js` and note it as generated.
3. **Fonts are substituted.** Cinzel / Lora / IBM Plex Mono load from Google Fonts in
   `tokens/typography.css`. The prototype ships no font files. If real faces get licensed,
   that one file is the only place to change.
4. **Two hues in `table_scene.html` are not in `theme_colors.gd`** — the felt green and the
   table brown. They are scene-only, deliberately, and noted in `readme.md`.

## If the game side should consume the palette

`tokens/colors.css` and `scripts/ui/theme_colors.gd` currently hold the same thirteen values
in two places. If they should not drift, generate the GDScript from the CSS (or the reverse)
rather than hand-syncing — the CSS carries the source comment naming `theme_colors.gd` as
the origin.

## What is NOT in here and still needs making

See `guidelines/asset_manifest.md`. Short version: 15 adversary stills + 5 shadows, 8–9 die
bodies + 3 overlays, the parchment, 7 charm relics, backdrops for tiers 2–4, the forge
backdrop, 12 icons, 5 particles, ~18 SFX, 2–3 music loops, 2 licensed font files.
