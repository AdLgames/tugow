class_name Questions
extends RefCounted
## The eight things you are allowed to ask, and what each one is worth.
##
## There is no document to compare. Every tell is behavioural, which means a
## question is only ever evidence about the answer — never proof. The pool is
## deliberately small so that by shift three the player knows all eight and is
## choosing between them rather than discovering them.

enum Id {
	BREAKFAST,
	COMING_FROM,
	WHO_WAITS,
	THE_TRIP,
	REMOVE_HAT,
	SAY_NAME,
	ARE_YOU_HUMAN,
	CAN_YOU_WAIT,
}

const ASKS_PER_TRAVELLER := 3

## The question as the player asks it, and the two shapes an answer comes in.
## `human` is what a tired person says; `thing` is the tell. Neither is
## labelled in play — the player is reading, not being told.
const POOL := {
	Id.BREAKFAST: {
		"ask": "What did you have for breakfast?",
		"human": [
			"God. Nothing? There was a heel of bread. I think I ate it walking.",
			"I don't— it was still dark. Something. I wasn't paying attention.",
			"Does coffee count. It wasn't coffee. It was the colour of coffee.",
		],
		"thing": [
			"Two slices of rye, toasted four minutes, a boiled egg with the shell cracked at the wide end, and half a cup of black tea at six-forty.",
			"Oats. Forty grams. Water, not milk. I ate them at the window facing east.",
			"Bread, butter to the crust, no jam. I chewed each mouthful eleven times.",
		],
	},
	Id.COMING_FROM: {
		"ask": "Where are you coming from?",
		"human": [
			"Ashfield. What's left of it. The east end mostly.",
			"Marren. Past the reservoir. You know it?",
			"The Halloway estate. Or where it was.",
		],
		"thing": [
			"East.",
			"From behind you. The other way. That way.",
			"Toward here.",
		],
	},
	Id.WHO_WAITS: {
		"ask": "Who's waiting for you inside?",
		"human": [
			"My sister. Dena. She went through in the spring.",
			"Nobody. That's rather the point.",
			"My boy. He's nine. He went with the second convoy.",
		],
		"thing": [
			"A man at a desk. Tired. He has a lamp and a stamp and a photograph he does not look at.",
			"Someone who asks questions. Someone who is cold. Someone who is you.",
			"You'll be there. You're always there.",
		],
	},
	Id.THE_TRIP: {
		"ask": "How was your trip?",
		"human": [
			"Long. My feet are ruined. Are we nearly done?",
			"Awful. There's a dead horse on the Marren road nobody's moved.",
			"I walked most of it. I'd rather not talk about the rest.",
		],
		"thing": [
			"Yes.",
			"It was.",
			"Yes. It was how it was.",
		],
	},
	Id.REMOVE_HAT: {
		"ask": "Remove your hat.",
		"human": [
			"[takes it off] Happy? It's cold, you know.",
			"[pulls it off, flattens their hair] There.",
			"[removes it slowly] It's not much of a face to look at.",
		],
		"thing": [
			"I was telling you about the road. There's a dead horse on it. Nobody's moved it.",
			"My sister is inside. She went through in the spring. She'll be waiting.",
			"[does not move] It's cold. It's very cold out here, isn't it.",
		],
	},
	Id.SAY_NAME: {
		"ask": "Say your name again.",
		"human": [
			"%s. Same as it was a minute ago.",
			"%s. Do you want it spelled?",
			"%s. You've got it written down.",
		],
		"thing": [
			"%s.",
			"%s. That's right, isn't it.",
			"%s. Yes.",
		],
	},
	Id.ARE_YOU_HUMAN: {
		"ask": "Are you human?",
		"human": [
			"What kind of question— yes. Yes, obviously. Christ.",
			"Are you? Look at me. Look at my hands.",
			"[a long pause] That's a cruel thing to ask someone.",
		],
		"thing": [
			"[smiles] Are you?",
			"[smiles, and holds it] What a thing to ask.",
			"[smiles] Yes. We both are.",
		],
	},
	Id.CAN_YOU_WAIT: {
		"ask": "Can you wait a moment?",
		"human": [
			"[sighs] Take your time. It's only my legs.",
			"I've waited eleven days. What's a moment.",
			"[shifts weight, rubs their arms] Fine. Fine.",
		],
		"thing": [
			"[stops blinking]",
			"[goes completely still]",
			"[does not move at all, and does not look away]",
		],
	},
}


static func all_ids() -> Array[int]:
	var out: Array[int] = []
	for id in POOL:
		out.append(id)
	out.sort()
	return out


static func ask_text(id: int) -> String:
	return String(POOL[id]["ask"])


## The answer this traveller gives. `worn` is the question having stopped
## working — the thing has learned it, and answers like a person would.
static func answer(id: int, is_thing: bool, rng: RandomNumberGenerator,
		traveller_name: String, worn: bool = false) -> String:
	var bank: Array = POOL[id]["thing" if is_thing and not worn else "human"]
	var line := String(bank[rng.randi_range(0, bank.size() - 1)])
	if line.contains("%s"):
		line = line % traveller_name
	return line


## Asking outright is the one question that costs you something. It never
## catches anything a patient player could not catch another way.
static func is_trap(id: int) -> bool:
	return id == Id.ARE_YOU_HUMAN
