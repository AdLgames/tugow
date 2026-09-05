class_name Shifts
extends RefCounted
## Seven shifts. The difficulty is not in the numbers — it is in what the
## game stops letting you rely on.

class Shift extends RefCounted:
	var number: int
	var title: String
	var opening: String
	## Roughly how much of the line is not human.
	var thing_ratio: float
	## Tells per thing. Late shifts give fewer, so a thing is harder to read.
	var tells_min: int
	var tells_max: int
	var scripted: String = ""


const TABLE := [
	{
		"title": "Wrong",
		"opening": "Nothing you could write down. A smile held a half-second past its use. Someone answers \"yes\" to a question that was not one. The radio, for a moment, sounds like you.",
		"ratio": 0.25, "min": 3, "max": 3,
		"scripted": "",
	},
	{
		"title": "Learning",
		"opening": "You are starting to know what you are looking at. That is not the same as being right.",
		"ratio": 0.35, "min": 2, "max": 3,
		"scripted": "",
	},
	{
		"title": "Consequence",
		"opening": "A call came through from inside. Someone you passed is standing at a door on the residential row. Not knocking. Standing.",
		"ratio": 0.40, "min": 2, "max": 3,
		"scripted": "They have been there since the shift began.",
	},
	{
		"title": "Doubt",
		"opening": "Someone you turned away is in the line again. You are no longer certain they were not a person.",
		"ratio": 0.40, "min": 2, "max": 2,
		"scripted": "",
	},
	{
		"title": "Escalation",
		"opening": "The blinking stopped meaning anything tonight. Things have learned it, and the people out there are too tired to do it.",
		"ratio": 0.45, "min": 2, "max": 2,
		"scripted": "A girl asks whether her mother came through. She gives a name you stamped.",
	},
	{
		"title": "Isolation",
		"opening": "Your lamp is the only light left on this side. The radio has begun giving you the questions before you ask them.",
		"ratio": 0.50, "min": 2, "max": 2,
		"scripted": "The traveller tells you what you are going to decide. They are not wrong.",
	},
	{
		"title": "You",
		"opening": "The line is empty except for one figure, and it has your face.",
		"ratio": 1.00, "min": 2, "max": 3,
		"scripted": "It asks the questions. You answer them.",
	},
]


static func count() -> int:
	return TABLE.size()


static func get_shift(n: int) -> Shift:
	var s := Shift.new()
	var row: Dictionary = TABLE[clampi(n - 1, 0, TABLE.size() - 1)]
	s.number = n
	s.title = String(row["title"])
	s.opening = String(row["opening"])
	s.thing_ratio = float(row["ratio"])
	s.tells_min = int(row["min"])
	s.tells_max = int(row["max"])
	s.scripted = String(row["scripted"])
	return s


## The last shift is one figure and no line.
static func is_final(n: int) -> bool:
	return n >= count()
