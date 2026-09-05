extends Node
## Every tunable number, so the fear can be re-tested without touching logic.

## Dread is hidden from the player. It is never shown, never named in the
## interface, and only ever felt as how often the room does something.
const MIN := 0
const MAX := 10

## What each call is worth.
const WRONG_APPROVE := 2   ## Let a thing in.
const WRONG_DENY := 1      ## Turned away a person.
const RIGHT_DENY := -1     ## Turned away a thing. The only thing that helps.
const RIGHT_APPROVE := 0   ## Nothing happens. That is the reward.

## Asking outright is a tell you give them.
const ASK_TRAP_COST := 2

## The line, per shift.
const TRAVELLERS_MIN := 6
const TRAVELLERS_MAX := 8
const SHIFTS := 7

## Lights in the safe-zone window. One goes out per thing you let through.
const WINDOW_LIGHTS := 8

## Denied humans do not simply vanish. They come back, and they are worse for
## having been out there.
const GUILT_RETURN_AFTER := 2   ## Shifts later.

## How wrong the run has to go for each ending.
const EMPTIED_AT := 5           ## Things let through.
const TURNED_AWAY_AT := 6       ## People denied.

## Things learn. A question you have leant on twice stops working from this
## shift on — the same question, the same person, a human answer.
const LEARNING_FROM_SHIFT := 3
const USES_BEFORE_LEARNED := 2

## Portraits available.
const PORTRAITS := 20
