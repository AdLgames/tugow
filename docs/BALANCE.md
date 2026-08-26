# Resolver findings

Everything here comes out of `tools/curve_report.gd`. Rerun it after any change
to `scripts/autoload/balance.gd`:

```bash
godot --headless --path . res://tools/curve_report.tscn
```

Figures below are from the committed settings: tempered curve, base threshold
60, floor scaling 1.45×, reclaim 3, carry 1.0, linear rail, twelve floors.

**These numbers were re-measured after the model was calibrated to the
physics** (see [AUDIT.md](AUDIT.md)); the model's landings are now sampled
from rates measured off the simulation rather than from invented radius
bands, which shifts every depth figure.

**The throw layer changed every depth number in this file.** Rail multipliers
and lost dice together moved greedy-bot mean depth from roughly floor 4 to
floor 7. Sections 3–4 have been re-measured; the rail's own numbers are in
[MECHANICS.md](MECHANICS.md#rail-multiplier--open-question-7-measured).

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

Greedy-bot mean depth by carry ratio: 0.0 → 5.77, 0.5 → 6.78, 1.0 → 7.20.
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

Greedy-bot mean depth by reclaim value: 0 → 5.37, 1 → 5.93, 2 → 6.40,
3 → 7.20, 4 → 7.47, 5 → 7.53. Monotonic and gentle — no value tested makes the
run unkillable, so **3 is committed** on the grounds that it is a visible
reward (a quarter of the card) without being a reset.

The more useful finding is what the sweep exposes: **run length is governed by
turns-per-floor, not by thresholds.** Scaling from 1.4× to 1.6× moves mean depth about
a floor and a half (7.52 → 6.03), while the card still runs dry first; the bot still spends about three boxes a floor and only meets an
Adversary on floors 3, 5 and 7. The
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

---

## Tuning pass: the back-of-week wall and Damn Fool

Measured with `tools/strategy_report.gd`, 200 runs a policy, best-known play
(hold toward a line, stake the rail).

### The wall

Deaths clustered on nights 5, 6 and 7 of *every* week, peaking at night 6, with
the Adversary holding only 1.8 lines on average. So it was never the boss: the
threshold climbed while the card emptied, and the card lost.

Two numbers moved:

| | Was | Now | Why |
|---|---|---|---|
| `night_scaling` | 1.18 | **1.10** | night 7 is 1.77x night 1 rather than 2.70x |
| `overflow_carry_cap` | 0.50 | **0.85** | a good night can nearly pay for the next one |

The carry cap was the bigger lever by far — it is the only route by which a
strong night buys a later one, which makes it the direct counter to a card that
empties late in a week. It stays under 1.0 so a monster turn still cannot skip
a night outright.

| | Before | After |
|---|---|---|
| Mean night reached (of 35) | 13.6 | **20.7** |
| Median night | 7 | **20** |
| Runs won of 200 | 4 | **44** |

### Damn Fool

The band put a third of the dice in the dirt, and cost two thirds of a run's
depth: it was a mistake, not a gamble. The profile was pulled back and the
odds re-measured from the simulation (`tools/throw_tuner.tscn --hard`):

| Band | pot | rail | dirt |
|---|---|---|---|
| Careful | 85% | 15% | 0% |
| Chancy | 50% | 44% | 6% |
| Damn Fool | 32% | **51%** | 17% (was 32%) |

It now has the highest rail rate of the three — the widest reach on the table —
at half the price.

**It is still not competitive, and the reason is the loss duration, not the
loss rate.** A die in the dirt is gone for the whole night, and the pool holds
eight against five on the table, so three losses shrink every remaining turn of
that night. One Damn Fool turn averages about 2.5 losses. Against that, the
rail multiplier only applies to the write in front of you.

Measured under best play: Careful 22.7 nights, Chancy 20.7, Damn Fool 9.2. A
policy that gambles only when a careful throw cannot clear the night scores
20.3 — still short of simply playing Careful.

If Damn Fool should be a real choice, the change is to bound its cost: dice in
the dirt returning at the start of the next turn rather than the next night.
That is a rules change and is not made here.
