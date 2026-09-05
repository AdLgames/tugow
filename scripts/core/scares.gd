class_name Scares
extends RefCounted
## Six scares, and the rules about when one is allowed to happen.
##
## The single most important rule in the game: a scare never comes from the
## traveller who is currently speaking. It fires 20 to 60 seconds after the
## wrong call, which means it lands on the *next* person, once the player has
## put the last one out of their mind. Fear that arrives on cue is not fear.

enum Id { LEAN_IN, WINDOW, KNOCK, RADIO, COMEBACK, REFLECTION }

const NAMES := {
	Id.LEAN_IN: "the lean-in",
	Id.WINDOW: "the window",
	Id.KNOCK: "the knock",
	Id.RADIO: "the radio",
	Id.COMEBACK: "the comeback",
	Id.REFLECTION: "the reflection",
}

## What the player is told, if anything. Most of these are pictures and sound;
## the text is what the log records and what a screen reader would get.
const COPY := {
	Id.LEAN_IN: "They stop mid-sentence. Their face fills the glass. Nothing moves for four seconds. Then they step back and finish the sentence as though nothing happened.",
	Id.WINDOW: "Something taps the safe-zone glass behind you. When you turn, the one you approved is pressed flat against it, looking in.",
	Id.KNOCK: "Three knocks on the back door of the booth. Hard, flat, unhurried. The door does not open.",
	Id.RADIO: "The radio finds static, and then your own voice comes out of it, screaming your name.",
	Id.COMEBACK: "The next in line has the same face as the one you let through. It is already at the glass.",
	Id.REFLECTION: "Your reflection in the desk glass is a beat behind you. You stop. It stops, a moment later.",
}

## Delay window after a wrong approve, in seconds. Long enough that the
## player has moved on; short enough that they connect it to the call.
const DELAY_MIN := 20.0
const DELAY_MAX := 60.0


static func all_ids() -> Array[int]:
	var out: Array[int] = []
	for id in NAMES:
		out.append(id)
	out.sort()
	return out


static func name_of(id: int) -> String:
	return String(NAMES.get(id, "?"))


static func copy_for(id: int) -> String:
	return String(COPY.get(id, ""))


## The chance a wrong approve arms a scare at all. Rises with dread, so the
## game gets less merciful exactly as the player gets more careless.
static func chance(dread: int) -> float:
	return 1.0 / 6.0 + float(dread) / 12.0


static func delay(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(DELAY_MIN, DELAY_MAX)
