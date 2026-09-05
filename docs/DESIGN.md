# Checkpoint — design

*No papers. No proof. Just their face and your questions.*

You are the last human at a checkpoint into the safe zone. There are no
documents to compare and nothing to verify against. You ask, you listen, and
you decide. Let the wrong one through and something follows you home.

## The loop

One traveller at a time:

1. They step up. You get a portrait, a name, and a one-line reason for entry.
2. You may ask **up to three** of eight questions.
3. They answer. You watch.
4. **APPROVE** or **DENY**.
5. The consequence resolves — but not now, and not visibly.
6. Next. A shift is six to eight travellers; there are seven shifts.

The verbs are **ask, listen, decide**. Nothing else.

## What the interface never does

- It never shows a score.
- It never shows dread.
- It never tells you whether a call was right.

The only readout in the game is the safe-zone window over the traveller's
shoulder: eight lights, one of which goes out for every thing you wave
through. `tests/invariants.gd` holds that window to the truth — it can never
show a number that is not exactly the count of things let in.

## Dread, and why the scare is late

`dread` runs 0 to 10 and is hidden. A wrong approve adds 2 and rolls for a
scare at `1/6 + dread/12`. On a hit, a scare is **armed**, not fired: it waits
20 to 60 seconds and then lands on the *next* traveller, once the player has
stopped bracing.

That delay is the single most important rule in the game, and it has its own
test (`_test_scare_never_from_current_speaker`) which plays sixty runs and
asserts no scare has ever fired on the traveller that caused it. Fear that
arrives on cue is not fear; it is a cutscene.

Dread is expressed to the player only as how far the lamp reaches. By shift
six it barely clears the desk.

## Things learn

From shift three, a question you have leant on twice stops working. The
traveller gives a person's answer, the button looks exactly the same, and
nothing announces it. A player who finds one reliable question and rides it
gets punished for exactly that.

## What you are not allowed to do

The fifth shift sends one traveller with no face and perfect answers. DENY
does not work on it. The stamp does not move. The only way past is to approve
it and watch a light go out — so a perfect run still costs you, and the game
stops pretending that care is always enough.

That rule lives in `Game.decide()` rather than in the interface, so the model
and the screen cannot disagree about it.

## Endings

- **Kept the line** — you reached the seventh shift. The last figure has your
  face and answers every question the way you would. You stamp it through.
- **Emptied the zone** — five things let in. The window is dark, and the last
  traveller has your family's faces.
- **Turned everyone away** — six people denied. There is no line any more, and
  behind you the booth door opens.

## Structure

| Shift | Title | What changes |
|---|---|---|
| 1 | Wrong | Small offness. A smile held too long. "Yes." |
| 2 | Learning | The tells become readable. |
| 3 | Consequence | Someone you passed is standing at a door inside. Questions start to wear out. |
| 4 | Doubt | Someone you turned away is back in the line. |
| 5 | Escalation | Blinking stops meaning anything. The faceless one arrives. |
| 6 | Isolation | Your lamp is the only light left. |
| 7 | You | One figure. It has your face and asks your questions. |
