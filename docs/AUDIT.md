# Audit — invariants, and the two throw paths

Run before wiring the physics dice into play, on the grounds that every
serious bug this project has had was found by looking at a render or a
measured number, and none of them by a test.

| Bug | Found by | The suite said |
|---|---|---|
| The bench was unreachable: the phase was set after the signal that opens it | playing the build | 122 passing |
| Two dice rattling each other nine times in one throw | a screenshot's log | passing |
| Every physics throw settling on the spot | the tuner: every profile returned the spawn radius | 22 passing |
| `Engine.time_scale` tunnelling dice through the table | the tuner: 83% lost at zero impulse | passing |
| Physics non-determinism from solver warm-starting | an assertion written on a hunch | — |

The common thread: `tests.gd` asserts **outcomes** — a run terminates, three
of a kind scores 66 — and almost nothing about what must always be true. An
outcome suite passes happily while the game is unplayable.

## What was added

**`scripts/core/throw_contract.gd`** — one definition of what a throw
produced. Both the model (`throw.gd`) and the physics (`dice3d/dice_sim.gd`)
hand it raw landings; it derives radius, zone, loss and cocking, and it owns
the rule that a cocked die contributes two faces. Neither path decides any of
that for itself any more, so they cannot drift apart and quietly invalidate
the numbers in BALANCE.md.

**`tests/invariants.gd`** — 52,000 assertions over ~1,300 randomly played
turns, checking after every single action that: the card is thirteen lines in
exactly one state each; the run total reconciles against the card; no line is
spent twice; an open line carries no points; the Adversary never holds more
lines than the limit that ends the run; a declared line is one that can
actually be taken; the dice on the table are distinct; a staked die is never
lost; and a turn always has a legal move.

## What it found

**1. Reclaim stranded points on reopened lines.** Winning a duel reopened a
line but left its score sitting on it. The line was then neither spent nor
scoreable, and the run total could not be reconciled against the card at all —
it was merely plausible. Reclaimed points now move to `reclaimed_total`, and
the invariant `run_total == lines held + reclaimed` holds across every run.

**2. A denied call stayed on the table.** When the player took the line the
Adversary had announced, the declaration was left pointing at it until the
Adversary's next turn — and if the night ended first, it never cleared. The
UI would show him calling a line that was already gone. The call is now dead
the moment the line is taken, and at the end of a night.

**3. My own assumption was wrong**, and worth recording: I first asserted that
the run total equals the sum of the player's lines. It does not, by design —
reclaimed points stay on the total. The invariant had to be restated rather
than the code changed.

## The cocked mechanic does not survive contact with physics

The design defines cocked as *a die resting on another die*, counting as both
faces. Measured across 180 throws at three different grouping tightnesses:

| Grouping | Closest horizontal pair | Largest vertical gap | Cocked |
|---|---|---|---|
| spread 0.50 | 0.753 | 0.005 | 0 / 60 |
| spread 0.25 | 0.916 | 0.015 | 0 / 60 |
| spread 0.10 | 0.737 | 0.133 | 0 / 60 |

Die size is 0.62. The dice never come to rest more than a fifth of a die apart
vertically, at any tightness: thrown cubes land flat on felt and stay there.
Staggering the release so dice arrive one after another — which is how a real
handful leaves the hand — did not change it.

So the mechanic is reachable in the model, which fabricates it from proximity,
and unreachable in the physics. **This is a design decision, not a bug**, and
it is open:

1. **Redefine it as the physically real case.** In dice play "cocked" means a
   die that has not settled flat — usually leaning on the rail. `DieBody`
   already detects this (`is_flat()`), and it happens often enough to matter.
   The cost: "the face of the die beneath it" needs a new meaning.
2. **Keep the definition and accept it is a once-a-run event**, effectively
   cut content on the physics path.
3. **Drop it**, and let the two faces come from somewhere else.

### Settled: option 1

A die that has not settled flat is cocked, and reads the face nearest the
ceiling plus the one it has tipped toward. Measured rate: **2.1% of settled
dice**, roughly one cocked die every ten throws — which is the design's own
"rare, powerful, unstable" without having to invent anything.

The model draws from that same measured rate rather than from proximity, and
picks a second face that is a neighbour of the first, never its opposite,
because that is how a tipped die reads.

## Calibration, and the tripwire on it

The two paths did not only disagree about cocking. The model's landing bands
were invented — soft never reached the rail, where the simulation puts a die
there one time in seven. So the model now samples the **zone** from rates
measured off the simulation (`Balance.zone_odds`) and then a radius inside
that zone. The paths agree by construction, which is what allows the balance
sweeps to run on the model and still describe the game the player gets.

Both halves are guarded:

- `tests/dice3d_tests.gd` throws 75 physical dice per strength and fails if
  the result drifts from `zone_odds`.
- `tests/tests.gd` samples 1,000 model dice per strength and fails if the
  model stops sampling what it is calibrated to.

**The tripwire fired the first time it ran.** The table had been measured
before dice were given a staggered release, so it described physics that no
longer existed — hard throws were recorded as 40% dirt when they had become
24%. Re-measured, and every depth number in BALANCE.md re-run.

Four assertions in `tests.gd` had also encoded the invented bands ("a soft
throw never reaches the rail", "a medium throw does not put dice off the
table"). Those were assertions about a fiction, and they were rewritten to
the measured behaviour rather than the code being bent back to satisfy them.
