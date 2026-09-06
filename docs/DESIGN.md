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
