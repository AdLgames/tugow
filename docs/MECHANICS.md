# Thirteen Boxes — mechanics

## The shape of a run

A run is **5 weeks**. A week is **7 nights**. A night is as many **turns** as it
takes to meet that night's threshold.

The Ledger has thirteen lines and every turn spends one, permanently — but the
Ledger is **wiped clean at the end of each week**. That is what makes the week
the real unit of play: thirteen lines have to carry seven nights, not a whole
run. Everything you scored is kept; only the paper is fresh, and every line the
Adversary took or burned comes back with it.

Surviving a week pays out **one charm**.

### The night ladder

Thresholds climb through a week and reset lower at the start of the next one,
higher than the last week opened. The sawtooth is deliberate: a week should end
harder than it began, and a new week should feel like air.

    threshold = 40 x 1.55^(week-1) x 1.18^(night-1)

### The man across the table

He arrives later in the week early on and earlier as the run goes: week 1 he
sits down only on the last night, week 5 for five of the seven. The last night
of a week is always his, and it is that week's own adversary; the duel nights
leading up to it are the ones you already beat, in the order you met them.

## The turn

Three draws, then settle one line.

**Holding** keeps a die back from the next draw. It is free, reversible, and
lasts only the turn you are in — it is what lets a hand be built toward a line
at all. A held die is still sitting on the felt, so a landing die can knock it,
and a held die on the rail is still shoved by the next throw.

**Staking** keeps a die for the whole night, and nothing can touch it: it is
never struck, never shoved, never lost. Staked dice also level — three scores
and one of the die's faces is reshaped.

A draw that would move nothing is refused rather than spent, so keeping every
die back cannot burn a draw.

Without a per-turn hold the card collapsed rather than depleted: only two or
three lines score on any random hand, so once those were spent every remaining
turn was a forced scratch. Measured over whole runs, the hold roughly halves
the scratch rate and is worth more than every other decision in the turn.

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

## Charms

One a night. The bench is visited once between nights, and re-rendered after
each purchase, so a night with lines to spare could previously buy several
charms at once. `Balance.charms_per_night` caps it.

## The physical throw

`Game.throw()` has two paths behind one call. With a stage attached the throw
is physical and takes real time: the dice go up, `dice_in_the_air` locks the
interface, and the simulation hands back contract records when the bodies
settle. Without one — the tests, the balance sweeps, the tuner — the model
resolves it on the spot.

- `scripts/dice3d/dice_stage.gd` — a SubViewport holding the simulation, a
  camera and lights, composited over the painted felt. Only the dice have
  meshes: the table has collision but no geometry, so the painted felt shows
  through and there is never a second table.
- `scripts/dice3d/die_pips.gd` — the pip atlas, drawn at runtime into the six
  faces a BoxMesh unwraps, so a cube reads as a die without an artist.
- Staked dice are **set down**, not thrown. A staked die that tumbled onto a
  new face would contradict the rule that staking holds a face for the night.
- The simulation's bodies carry the real die ids. The table holds five of
  eight named dice, so a body's identity comes from the game — without that a
  face settles on one die and is read onto another.
- The rail shove lives in `ThrowContract`, applied by the caller, so the two
  paths cannot shove differently.

The 2D die views become labels and hit areas over the rendered dice: a name, a
state tag, and a ring when staked or on the rail. A view whose body cannot be
located on screen hides rather than falling back to a made-up position.

## The dice as objects

`scripts/dice3d/die_mesh.gd` builds the cube face by face rather than using a
BoxMesh. A BoxMesh's own unwrap puts the six faces somewhere in the texture,
and "somewhere" is not good enough: the face pointing at the ceiling is the
face the rules score, so the pips a player counts have to be the pips on that
side of the cube. Opposite faces sum to seven, as a real die's do.

`tests/die_face_render.tscn` is the test that matters, and the only one that
needs a display: it orients a die to each value in turn, renders it from
above, counts the dots in the picture, and fails if the picture disagrees
with the rules. It caught both halves of this being wrong — the triangle
winding was reversed, so every face was culled and the camera saw the inside
of the far one (a die scored as six rendered as one), and the orientation
helper turned the wanted face downward, so two through five each showed
their opposite.

## The Ledger drawer

The Ledger is tucked into the bottom of the table with a quarter of it
showing, and pulled up when you want to read it. It lives in a well that
clips, so a closed sheet is genuinely cut off by the bottom bar rather than
drawn across it. The head of the sheet is the handle; the lines are only live
once it is out. When the only legal move left is settling a line, it opens
itself — there is no sense making someone hunt for the one thing they can do.

## The clear felt

Dice land in the region of table left over once the Ledger, the dice tray and
the draw buttons have taken their room — derived from those nodes' real
rectangles in `main.gd`, not guessed at in the scene, so it cannot drift out
of step with the layout.

Inside it, `SaloonView.place_dice()` relaxes the arrangement until no two dice
overlap. Their landing positions still order them, but two dice can genuinely
come to rest in the same place on a table, and two overlapping sprites cannot
be counted or clicked. The footprint used for spacing is half a die's
diagonal, not half its width, because the name above and the tag below are
part of what must stay legible.

## Naming

`scripts/ui/lore.gd` holds every player-facing word: the Ledger, lines owed,
staking, the Draw, nights, the Assayer's Office, and the adversary display
names (The Taxman, The Magpie, Your Brother, The Fire, The Debtor). Code ids,
class names, tests and the rest of these docs keep the mechanical terms — the
brief asks for the display strings to change, not the ids.
