# Resolver findings

Everything here comes out of `tools/curve_report.gd`. Rerun it after any change
to `scripts/autoload/balance.gd`:

```bash
godot --headless --path . res://tools/curve_report.tscn
```

Figures below are from the committed settings: tempered curve, base threshold
60, floor scaling 1.45×, reclaim 3, twelve floors.

## 1. The exponential curve (open question #1)

Raw operators, five of a face:

| face | upper | 3-kind | 4-kind (raw `f^4`) | 4-kind (tempered `f³×5`) | Yahtzee (raw `f^5`) | Yahtzee (tempered `f⁴×2`) |
|---|---|---|---|---|---|---|
| 2 | 20 | 30 | 16 | 40 | 32 | 32 |
| 4 | 80 | 60 | 256 | 320 | 1,024 | 512 |
| 6 | 180 | 90 | 1,296 | 1,080 | 7,776 | 2,592 |

The raw curve's problem is not its ceiling, it is its *slope between faces*: raw
Yahtzee runs 32 → 7,776 across the face range, so a five-of-a-kind on 2s is
worthless and one on 6s ends the floor by itself, with nothing in between worth
steering toward. Tempered keeps the "which face you chase is the whole question"
property (four 6s = 1,080 against four 2s = 40, a 27× spread) while pulling the
top end back to roughly three floors' worth of threshold instead of nine.

Both curves ship. `Balance.curve = Balance.ScoreCurve.RAW` restores the doc's
first pass for comparison; the test suite asserts both.

**Small Straight was capped to a span of four.** The doc's own example
(`3-4-5-6 + 2` → 120) only works that way: 2-3-4-5-6 is a five-long run, and an
uncapped span scores it 150 while Large Straight scores the identical dice 720.
Capping the span keeps the two boxes distinct and matches the stated number.

## 2. What a turn is worth, and why Chance changed

20,000 fresh five-dice rolls, taking the best of all thirteen boxes.

**Before:** mean best 79.4. Picked box: Fives 21.8%, Sixes 20.4%,
**Chance 20.3%**, Small Straight 12.5%. Doubling per 6 made Chance the best box
on a fifth of all rolls — and a 20 with two 6s became an 80, which clears
floor 1 (threshold 60) on turn one with no decision made. A box whose whole
purpose is "the roll did nothing, dump it here" was the strongest opening play.

**Now** (`sum + 10 per 6`): mean best 75.0. Picked box: Sixes 40.5%, Fives
21.8%, Small Straight 12.5%, Three of a Kind 9.9%. **Chance is never the
highest-scoring box.**

That is the intended shape, and it is worth being explicit about it: Chance is
now a *safety valve*, not a play. It is the box that always scores something
when the dice have given you nothing, which is exactly what it should be when
scratching is the alternative. The greedy reference bot therefore never picks
it, which is a limitation of the bot, not evidence the box is dead — a human
reaches for it precisely in the situations the bot's "highest score wins"
metric never encounters.

If Chance should be a live *option* rather than a floor, `chance_six_bonus` is
one line in `balance.gd`; 15 puts it back in competition without restoring the
solo-clear.

## 2b. Overshoot carries

Scoring 97 into a 60 threshold used to waste 37 points, which meant there was
never a reason to score big — only to score *enough*, and the whole
"is this roll worth a box?" question collapsed into "does it clear?".

Overshoot now banks: the excess carries into the next floor's starting score,
capped at half of that floor's threshold so that one monster turn cannot skip
a floor outright (`overflow_carry_ratio`, `overflow_carry_cap`).

Greedy-bot mean depth by carry ratio: 0.0 → 3.67, 0.5 → 3.90, 1.0 → 3.97.
Committed at 1.0 with the 50% cap. The duel comparison deliberately ignores
carried points — you out-score an Adversary with what you scored on its floor,
not with what you brought in.

## 3. Floor scaling (open question #2)

At 1.45×: 60, 87, 126, 183, 265, 385, 558, 809, 1,172, 1,700, 2,465, 3,574.

Floor 1 falls to a single average turn (79 vs 60). Floor 8 needs 809, which is
ten average turns' worth of scoring — you cannot get there on rolls, only on an
engine of locked high dice plus a big operator. That is exactly the doc's
target for floor 8, one floor earlier than at 1.6×.

1.6× was tested and rejected: it puts floor 12 at 10,555, which is four
maximum-value Yahtzees, and the ladder stops being a target and becomes a wall.

## 4. Reclaim generosity (open question #5)

Greedy-bot mean depth by reclaim value: 0 → 3.72, 1 → 3.80, 2 → 3.88,
3 → 3.97, 4 → 4.13, 5 → 4.20. Monotonic and gentle — no value tested makes the
run unkillable, so **3 is committed** on the grounds that it is a visible
reward (a quarter of the card) without being a reset.

The more useful finding is what the sweep exposes: **run length is governed by
turns-per-floor, not by thresholds.** Scaling from 1.4× to 1.6× moves mean
depth by about half a floor (4.47 → 3.97), while the card runs dry either way; the bot dies at floor 4 in every configuration because it
spends three boxes a floor and only meets an Adversary on floors 3 and 5. The
scorecard, not the difficulty curve, is the clock — which is the design working
as intended, but it means future tuning should go to reclaim, duel frequency,
and turn efficiency rather than to thresholds.

Caveat on all bot numbers: the reference bot locks anything showing 5+ and takes
the highest-scoring box available. It builds no engine and never denies an
Adversary, so treat its depth as a floor on human performance, not an estimate
of it.

## 5. Still unanswered

Open questions #3 (does deny-vs-race feel tight?) and #4 (is playing badly
against the Twin fun or just confusing?) are playtest questions. The loop they
need is implemented — the Adversary announces before it rolls, the pool is
shared, and the Twin wears your last roll — but no amount of simulation
answers them. They need hands on the build.
