class_name Tells
extends RefCounted
## The seven ways a thing gives itself away without opening its mouth.
##
## A thing carries two or three of these. None of them is conclusive on its
## own and every one of them has an innocent reading, which is the whole
## design: the player is never given proof, only a weight of impression.

enum Id {
	UNASKED,        ## Answers a question you did not ask.
	NO_IDLE,        ## Does not blink or shift. People do, constantly.
	LAGGING_GLASS,  ## Its reflection in the desk glass is half a second behind.
	KNOWS_YOU,      ## Knows something about you it has no way of knowing.
	WRONG_VOICE,    ## The voice does not match the face.
	HUM_SHIFT,      ## The room hum changes pitch when it steps up.
	ECHO,           ## Repeats your last sentence back to you.
}

const PER_THING_MIN := 2
const PER_THING_MAX := 3

const NAMES := {
	Id.UNASKED: "answers what you did not ask",
	Id.NO_IDLE: "does not blink",
	Id.LAGGING_GLASS: "reflection lags",
	Id.KNOWS_YOU: "knows you",
	Id.WRONG_VOICE: "voice does not fit the face",
	Id.HUM_SHIFT: "the hum changes",
	Id.ECHO: "repeats you back",
}

## What the player is shown when a tell fires. These are the game: they have
## to be noticeable without ever being announced.
const LINES := {
	Id.UNASKED: [
		"I've never been to Marren, if that's what you were going to ask.",
		"My mother's name was Elise. You weren't going to ask that.",
		"No, I didn't see anything on the road. You'll want to know that.",
	],
	Id.KNOWS_YOU: [
		"You look tired, %s.",
		"Is your daughter still inside, %s? She was, last week.",
		"You had bread for breakfast. The heel of it. Standing up.",
		"Your lamp's going. It went last night too, around now.",
	],
	Id.ECHO: [
		"\"%s\"",
		"\"%s\" — yes.",
	],
}

const ALL_STILL_SHIFT := 5


static func all_ids() -> Array[int]:
	var out: Array[int] = []
	for id in NAMES:
		out.append(id)
	out.sort()
	return out


static func name_of(id: int) -> String:
	return String(NAMES.get(id, "?"))


## Roll a thing's tells. Never the same one twice, always at least two, so a
## thing is always in principle catchable.
static func roll(rng: RandomNumberGenerator, count: int = 0) -> Array[int]:
	var pool := all_ids()
	_shuffle(pool, rng)
	var want := count if count > 0 else rng.randi_range(PER_THING_MIN, PER_THING_MAX)
	var out: Array[int] = []
	for i in mini(want, pool.size()):
		out.append(pool[i])
	out.sort()
	return out


## Late on, the ground moves: things learn to blink and exhausted people stop.
## After this shift, stillness means nothing at all, and a player who has been
## leaning on it has to find another way to read the line.
static func idle_is_readable(shift: int) -> bool:
	return shift < ALL_STILL_SHIFT


static func _shuffle(array: Array, rng: RandomNumberGenerator) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp
