# THIRTEEN BOXES

*A dice roguelike where the scorecard is your health bar.*

This is the design document the prototype is built from. Where the code
deliberately departs from it, the departure is listed at the bottom and the
reasoning is in [BALANCE.md](BALANCE.md).

---

## 1. Core Premise

Yahtzee's scorecard is already a roguelike run. Thirteen boxes, each usable exactly once, every choice permanent and irreversible.

So: **don't reset the card between fights.**

You descend through floors. Each floor demands a score threshold. You take turns — roll five dice, up to two rerolls — until you clear it. **Every turn you take spends one box off your card, permanently, for the rest of the run.**

Clear a floor in two turns and you carry eleven boxes forward. Clear it in six and you're bleeding out. Fill all thirteen and the run ends wherever you're standing.

### The central tension

Points and boxes are opposed currencies.

- Playing greedy for a big score means spending turns setting it up — and turns are your life.
- Playing safe means dumping garbage into boxes you'll desperately want later.

Every single turn asks: *is this roll worth spending a piece of my run on?*

### Scratching is a real move

Writing a zero is no longer failure — it's a sacrifice play. Burn your Yahtzee box for nothing to survive this turn, and live with the hole for the next eight floors.

---

## 2. Scoring: The Dice Are The Multiplier

No chips. No mult. No second currency. Every category names an **operation**, and the dice themselves supply all the scale.

| Box | Operation | Example |
|---|---|---|
| Aces – Sixes | Sum of matching dice **× the face** | three 5s → 15 × 5 = **75** |
| Three of a Kind | Sum of all five dice **× 3** | sum 22 → **66** |
| Four of a Kind | The quad's face **^4** | four 6s → **1,296** |
| Full House | Triple face **×** pair face **× 10** | 6s over 3s → **180** |
| Small Straight | Span **×** highest die **× 5** | 3-4-5-6 + 2 → 4 × 6 × 5 = **120** |
| Large Straight | **Product** of all five dice | 2-3-4-5-6 → **720** |
| Yahtzee | Face **^5** | five 4s → **1,024** |
| Chance | Sum, **doubled per 6 shown** | 24 with two 6s → **96** |

### Why this works

Four 6s = 1,296. Four 2s = 16. **Which face you chase becomes the entire strategic question**, and it's legible at a glance without a single tooltip.

> ⚠️ **Balance flag:** the exponentials get ugly fast. Four of a Kind and Yahtzee both want a nerf or a soft cap — likely `face^4` → `face^3 × 5`. Needs a resolver and a curve test before committing.

---

## 3. Dice Are Individuals, Not A Deck

You keep a **pool of eight dice** and roll five each turn. These are not interchangeable instances of a rank — they are eight specific objects you will recognize on sight by floor six.

### Dice level through use

- **Facet** — a die locked and scored three times permanently reshapes one of its faces.
- **Bitter** — a die used in a scratched (zeroed) box turns bitter: higher variance, and it refuses to roll its lowest face.
- **Memory** — dice remember their last roll. Certain charms read this: *"if this die shows the same face twice in a row, it splits."*

By late run you have the cracked die that keeps saving you, and the greedy one you're afraid to roll.

---

## 4. Locking Is The Real Verb

**Locked is locked for the entire floor, not the turn.**

Lock a 6 on turn one and it's still sitting there on turn four. Free guaranteed score every turn — but you're now rolling four dice instead of five, forever.

You are trading future options for present certainty. That's the same trade the scorecard makes. Two systems, one theme.

**Consequence:** your board *narrows* as a floor progresses. There is no play-hand-redraw-repeat rhythm. Every floor is a funnel you dig yourself into.

---

## 5. The Adversary

The strongest version of a boss fight here isn't a health bar. It's an opponent who **writes on your scorecard.**

One card. Thirteen boxes. You both score into it. Every box the Adversary claims is a box you can never use again — it doesn't damage you, it *shortens you*.

### How a duel runs

You alternate turns. On its turn the Adversary rolls its own five dice and claims a box — **and it always announces its target box before rolling.**

That declaration gives you exactly one turn to respond:

| Response | What it costs |
|---|---|
| **Deny** | Score that box yourself first, even with garbage. Spend a good box badly to keep it from enemy hands. |
| **Outpace** | Ignore the theft entirely. Race the threshold and end the floor before it collects enough. |
| **Starve** | Some Adversaries need specific faces. Lock those dice away from the pool. |

### The shared pool

**You and the Adversary draw from the same eight dice.**

Locking is no longer just self-commitment — it's denial. Your best die is safe inside your lock, but so are the dice you don't want *it* rolling. Locking becomes offense, and becomes a bluff.

### Win and loss conditions

- **You out-score it** → you clear the floor **and reclaim your spent boxes.** Winning heals the run.
- **It out-scores it** → you clear the floor, but the burned boxes stay burned.
- **It fills seven boxes** → it takes the card. Run over.

The Adversary is simultaneously the enemy, the clock, and the only healer in the game. Beating one decisively is how you get deep — not merely how you survive.

### Roster

| Adversary | Behaviour |
|---|---|
| **The Auditor** | Claims only upper-section boxes, methodically, low to high. Slow and honest. Brutal if ignored. The teaching fight. |
| **The Magpie** | Always targets whichever box *you* are building toward. Reads your locks. Punishes telegraphing. |
| **The Twin** | Rolls whatever you rolled last turn. Beat it by playing badly — a genuinely strange thing to ask of a player. |
| **The Furnace** *(boss)* | Doesn't claim boxes. *Burns* one per turn, unscored, gone. Pure clock. Cannot be denied, only outrun. |
| **The Debtor** *(boss)* | Scores into boxes you have already filled, overwriting them. Your best score is never safe. |

> **Prototype these two first:** The Twin and The Magpie. They're the pair that turns locking into a bluffing game, which is the furthest this design gets from anything else in the genre.

---

## 6. Charms

Passive relics that react to **dice behaviour**, not to hand types.

- **Grudge** — a die that rolls a 1 is furious next turn: +2 to every face.
- **Symmetry** — if your five dice read the same forwards and backwards, score the box twice.
- **The Tithe** — every sixth die you lock is sacrificed, its value added to your next score.
- **Sleeping Giant** — a die never locked all floor scores as a 6 the moment it finally is.
- **The Accountant** — grows in value with every box already spent. Scales as the run kills you.
- **Pigeonhole** — a Full House also counts as Three of a Kind, and scores both boxes.
- **Blood Pact** — enormous score bonus, but each turn burns two boxes instead of one.

---

## 7. The Forge (No Shops)

Between floors you visit the forge. **The only currency is your scorecard.**

- Trade a box away to reshape a die face.
- Burn two boxes to pull a ninth die into the pool.
- Sacrifice a box to cleanse a bitter die.
- Spend a box to overwrite a box you hate.

Every upgrade shortens the run that the upgrade exists to extend. That's the whole game's tension compressed into the meta layer — and it means no gold, no dollars, no shop rerolls, no economy minigame.

---

## 8. Verb Comparison

| Genre standard | Thirteen Boxes |
|---|---|
| Play / Discard | **Roll / Lock** |
| Buy / Sell | **Forge / Sacrifice** |
| Deck of interchangeable cards | **Eight named dice that level** |
| Health bar | **The scorecard itself** |
| Healing item | **Beating an Adversary** |

---

## 9. Open Questions

1. **Exponential curve** — Four of a Kind and Yahtzee likely break the math. Build the resolver, test the curve.
2. **Floor scaling** — roughly 1.6× per floor is the starting guess. By floor 8 the player should need a genuine engine, not good rolls.
3. **Does deny-vs-race actually feel tight?** This is the load-bearing decision of the Adversary system and it needs a playable loop to validate.
4. **Is "play badly to beat The Twin" fun or just confusing?** Worth an early test.
5. **Reclaim generosity** — how many boxes does out-scoring an Adversary return? Too many and the run never ends; too few and the incentive to fight rather than race disappears.

---

## 10. Prototype Order

1. **Scoring resolver** — all thirteen operators, curve visualisation.
2. **Single floor, no Adversary** — validate the box-spend tension in isolation.
3. **The Auditor** — simplest opponent, proves the shared-card mechanic.
4. **Shared dice pool + The Magpie** — the bluffing layer.
5. **Forge** — meta progression last, once the core loop is proven.

---

## Appendix: where the prototype departs from this document

Each of these is a decision the resolver forced; the numbers behind them are in
[BALANCE.md](BALANCE.md), and all of them are one line in
`scripts/autoload/balance.gd`.

1. **Four of a Kind and Yahtzee are tempered by default** — `face^3 × 5` and
   `face^4 × 2`. The raw `face^4` / `face^5` curve is still implemented and
   selectable (`Balance.curve = Balance.ScoreCurve.RAW`) for comparison.
2. **Small Straight spans four at most.** The doc's own example (`3-4-5-6 + 2`
   → 120) requires it: the run there is actually five long, and an uncapped
   span would score it 150 and blur the line with Large Straight.
3. **Floor scaling starts at 1.45×, not 1.6×.** See BALANCE.md — at 1.6× the
   threshold ladder outruns any card, not just a greedy one.
4. **Blood Pact is +50%, not "enormous".** A doubling with a second box burned
   per turn is a strictly better deal than it looks; +50% keeps it a real choice.
5. **Sleeping Giant needs three turns of patience**, rather than triggering on
   any first lock — otherwise every first lock of a floor is a free 6.
