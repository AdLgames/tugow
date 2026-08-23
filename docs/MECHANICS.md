# Thirteen Boxes — implementation notes

The mechanics specification is the source of truth for what this game does.
This file records how each system is implemented, and every place the build
knowingly differs from the spec.

Numbers live in `scripts/autoload/balance.gd`. Evidence for the tuned ones is
in [BALANCE.md](BALANCE.md), produced by `tools/curve_report.tscn`.

## The throw

Implemented as a **resolved model, not a physics simulation**
(`scripts/core/throw.gd`). Each thrown die is given a polar landing position
on a unit disc; zone, collisions, stacking and losses all fall out of those
positions. A 2D scene can animate the result without changing a rule, and the
whole layer stays headless-testable.

| Spec | Implementation |
|---|---|
| Soft / medium / hard | Landing radius bands `0–0.45`, `0.10–0.85`, `0.35–1.18` |
| Pot / rail / floor | Radius `< 0.60` / `0.60–1.00` / `> 1.00` |
| Rail scores double | See "rail multiplier" below |
| Collisions reroll the struck die | Dice landing within `0.18` strike; chains resolve in impact order, capped at 12 |
| Cocked dice count as both faces | Dice landing within `0.05` stack; the upper die contributes its own face *and* the face beneath |
| Underside = 7 − shown | Generalised: lowest face + highest face − shown, so reshaped dice keep the relationship |
| Locked dice are immune | Not thrown, not struck, never lost |
| Hard throws can lose dice | ~1 in 5 per die per hard throw |

### Rail persistence — a resolved ambiguity

The spec says a rail die "must survive the next throw or it goes off", but it
also says every unlocked die is re-thrown, which would make the rule
unreachable — a re-thrown die simply lands somewhere new.

Implemented so the rule has teeth: **rail dice are pushed outward at the start
of the next throw, before anything is re-thrown.** A hard throw (`+0.45`)
almost always takes them off; medium (`+0.12`) rarely does; soft never does.
So taking a rail double poses a real question: lock it, score it now, or
gamble it.

### Rail multiplier — open question #7, measured

The spec flags that rail doubling on top of exponential categories may be
uncontrollable. It is. A Large Straight (2-3-4-5-6, base 720) on the rail:

| Mode | 1 die | 3 dice | 5 dice |
|---|---|---|---|
| `EXPONENTIAL` (2^n, the literal reading) | 1,440 | 5,760 | **23,040** |
| `LINEAR` (1+n) — **committed** | 1,440 | 2,880 | 4,320 |
| `FLAT` (×2 for any rail die) | 1,440 | 1,440 | 1,440 |

The floor-12 threshold is 3,574. Exponential lets one turn score six times the
final floor of the run; it is not a play, it is a run-ender. Greedy-bot mean
depth: exponential 7.50, linear 7.05, flat 6.18.

**Linear is committed.** Flat is safe but makes the rail binary and throws away
the "how many did I get out there" texture; linear keeps each extra rail die
meaningful without the ceiling going vertical.

The multiplier is applied to the category result *before* charms, so Symmetry
doubles a rail-boosted score rather than the base.

## Overflow — resolved

The spec lists this as blocking, with three options. **Option 1 is
implemented and measured**: overshoot banks toward the next floor's starting
score, capped at half that floor's threshold so one huge turn cannot skip a
floor. Greedy-bot mean depth: no carry 5.97, half carry 6.65, full carry 7.05.

Carried points deliberately do not count toward out-scoring an Adversary — you
beat it with what you score on its floor, not with what you brought in.

Option 3 (overflow buys back boxes) is the more thematically consistent one and
remains open; it is a change to `Game._bank_overflow()` and nothing else.

## Departures from the spec

1. **Small Straight spans four at most.** The spec's own example
   (`3-4-5-6 + 2` → 120) requires it; uncapped, that run is five long and
   would score 150 while Large Straight scores the same dice 720.
2. **Floor scaling is 1.45×, not 1.6×.** At 1.6× floor 12 asks 10,555. See
   BALANCE.md.
3. **Blood Pact is +50%.** "Enormous" plus a second box burned per turn is a
   worse deal than it looks; +50% keeps it a decision.
4. **Sleeping Giant requires three turns of patience**, or every first lock of
   a floor is a free 6.
5. **Locking out is a warning, not a hard block** (spec section 3's open
   question). Freezing the floor is occasionally correct — it should cost you
   a confirmation, not be forbidden.

## The saloon scene

The playing screen is a port of
`docs/design-system/ui_kits/thirteen_boxes/table_scene.html` and its build
brief. Layer order, palette, camera and naming come from there; the game state
under it is real.

| Design layer | Godot |
|---|---|
| CSS 3D plane, `perspective` + `rotateX` | `scripts/ui/table_projection.gd` — a pinhole projection of the throw model's unit disc |
| Backdrop, adversary blockout, table, zones, lip | `scripts/ui/saloon_view.gd`, drawn in the brief's compositing order |
| Light pools, vignette, grain | Child nodes with their own `CanvasItemMaterial` — blend modes are per-node in Godot, not per-draw-call |
| `.die` | `scripts/ui/die_view.gd` — pips on a 3×3 grid, layouts through 9 |
| `.sheet` | `scripts/ui/ledger_view.gd` — pencil for yours, ink for his |
| `<image-slot>` | `scripts/ui/image_slot.gd` — loads `res://assets/…` if present, else a dashed frame |
| `#tweaks` | `scripts/ui/debug_panel.gd` — F3, `OS.is_debug_build()` only |

Art drops in by filename, no code change:
`res://assets/adversary/seated.png`, `res://assets/scene/wanted_poster.png`,
`res://assets/scene/hands.png`.

### Where the port differs from the mock, deliberately

1. **Camera pitch is 58°, not the 144° in the shipped HTML.** 144 is past
   edge-on and renders the table inside-out — the brief's own known issue #1,
   which names 58 as the settled value.
2. **Dice sit where the throw resolver put them**, not in a fixed row. The
   mock's row is a static arrangement; the zones are functional here, so a
   die on the rail is drawn on the rail. Landing positions are mapped into the
   band of felt that is actually visible and clickable, so a die never lands
   under the Ledger or behind the lip.
3. **Chance reads "Sum, +10 per 6".** The mock still carries the old doubling
   rule; the code changed and the mock did not.
4. **Screen and overlay blending are approximated.** Godot has no screen or
   overlay blend mode: light pools use additive (near-identical over a dark
   room) and grain uses a low-alpha mix. Real exported PNGs would keep the
   same approximation.
5. **Three draw buttons, not one.** The mock has a single "The Draw"; the game
   needs soft, medium and hard, styled as the mock's `.rollbtn`.

## Section 9 — required UI state

| Requirement | Status |
|---|---|
| Score preview on every unfilled box | Done — live value, dim at zero, highlighted on the best |
| Confirm on scoring | Done — states the rule, the resulting floor total, boxes remaining |
| Throws remaining | Done — on each throw button |
| Lock state, unmistakable | Done — die tint, `LOCKED` tag, pool strip, table ring |
| Zone boundaries visible | Done — the table is drawn with pot, rail and lip |
| Throw strength indicator | Done — three buttons; hovering previews that band's reach on the table |
| Adversary declared target | Done — marked on the card and in the corner panel |
| Charm slots | Done |
| Die names and condition | Done — pool strip shows facet progress, bitterness, holder, losses |
| Boxes remaining | Done — lip strip, agreeing with the Ledger |

## Naming

`scripts/ui/lore.gd` holds every player-facing word: the Ledger, lines owed,
staking, the Draw, nights, the Assayer's Office, and the adversary display
names (The Taxman, The Magpie, Your Brother, The Fire, The Debtor). Code ids,
class names, tests and the rest of these docs keep the mechanical terms — the
brief asks for the display strings to change, not the ids.
