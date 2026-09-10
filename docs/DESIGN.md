# Abyssal Bazaar — design

## The shape

**Level 1 — the mom-and-pop nightmare.** An 8x8 clearing. Play a thrall card,
wait thirty seconds, carry what comes back to a table, and hooded figures
wander in off the path and leave copper on the altar. The counter is the hook
and the only goal is the 500 obols that buys the expansion.

**Level 2 — supply chain of the damned.** 16x16 of black iron with a
backroom. The good stock does not keep. Overstock and it turns on the table,
and what turns becomes Corruption, and Corruption eats what every sale is
worth. The Void audits the shop and expects its tribute in hand.

## The deck is a concurrency limit

A thrall card is not spent, it is *away*. It comes back when its thrall does.
So the size of your deck is how many errands you can have running at once, and
buying a card is buying throughput rather than a consumable.

That is the whole tension of level 2 in one number: more thralls means more
stock, and more stock than you can sell is what rots. The deck is the dial
between "not enough on the tables" and "a floor covered in Corruption", and
each card costs 1.8x the last, so widening it is a decision every time.

`tests/tests.gd` holds this rule directly: playing every card empties the hand
but does not shrink the deck, and waiting the thralls home returns every card.

## Rot, and why Corruption does not forgive you

Perishables carry their own clock and turn exactly once. Turning adds
Corruption, and Corruption scales the multiplier every sale is paid at, down
to 15% at the cap — a ruined shop still sells, it is just barely worth
opening.

Corruption **only decays once nothing on the floor is rotting**. It is a hole
you dig out of with the sweep, not a timer that forgives you for waiting. That
is what makes the visual of green spreading across the tables a thing you act
on rather than watch.

## What the interface tells you

The counter is deliberately the largest thing on screen, and it chases the
real number rather than jumping to it, because a number that slams is a number
nobody watches.

Level 2 adds the two readouts that can end a run — a corruption meter and the
countdown to the next audit — and the stock panel down the right, which totals
every unit in the shop against the worst spoilage in each pile. You cannot
forecast against a floor you have to walk around counting.

## The horror

Level 1 is a single frame. A customer's sprite goes wrong for exactly the
tick they pay, and then they walk out with their shopping. Nothing is
explained.

Level 2 gives that up for the dread of a supply chain going bad: green
spreading across a floor you were proud of, a multiplier falling while you
watch, and prices climbing far enough that meeting them means running more
thralls than you can possibly sell for.

## Two deliberate simplifications

**Customers walk in straight lines.** The floor is a room you can see all of,
and a path solver would be a lot of machinery for it. The tables are laid in
rows with aisles cut through every third column so this reads plausibly, and
`tests/tests.gd` checks that every display on both floors has a walkable tile
beside it — a table nobody can stand at is a table nothing sells from.

**The sim never touches the clock.** No `randf()` outside the seeded
generator, no `delta` from anywhere but the caller. Two shops on the same seed
run identically, which is checked, and is what lets the fuzz mean anything.

---

## The numbers

Recovered along with the rest of this document from commit `fd1f0e8`, where
they lived in `scripts/autoload/balance.gd`. That build is gone; these are
the values it was tuned to.

### Thralls

| | |
|---|---|
| Errand length | 30 s |
| Haul per errand | 1–3 units |
| Starting deck | 3 cards |
| Deck cap | 8 cards |
| Card price | 1.8× the last one |

### Customers

| | |
|---|---|
| First arrival gap | 9 s, falling to 2.2 s |
| Faster by | 0.06 s per sale |
| Browsing | 2.4 s |
| Walking | 2.6 tiles/s |
| Patience | 26 s, then they leave with nothing |

### Money and rot

| | |
|---|---|
| Starting purse | 40 obols |
| Expansion | **500 obols** — the whole of level 1 |
| Corruption per unit rotted | 1.0 |
| Corruption decay | 0.02 /s, **only** once nothing is rotting |
| Revenue at full corruption | 15% |

### The audit

| | |
|---|---|
| Interval | 120 s |
| Tribute | 18% of revenue since the last one |
| Failure costs | 45% of everything held |
| Corruption that is itself a finding | above 35 |
| Display case | 220 obols, restocks every 6 s |

## What this predates

Written for the earlier build: a 64-pixel isometric grid, 8×8 for level 1 and
16×16 for level 2. The current project is **16-pixel orthogonal** and the room
is 20×11. The loop and the numbers carry over; the grid figures do not, and
distances in tiles will need re-reading against the smaller cell.
