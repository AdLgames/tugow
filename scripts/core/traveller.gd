class_name Traveller
extends RefCounted
## One person in the line. Or not.

var given_name: String = ""
var reason: String = ""
var portrait: int = 0
var is_thing: bool = false
var tells: Array[int] = []
## Set when this traveller has been through the booth before — a denied human
## coming back, or something wearing a face you already approved.
var returning: bool = false
var returning_as: String = ""
## Answers already given, so a repeated question cannot be re-rolled into a
## different answer. Asking twice is a wasted ask, not a second sample.
var answered: Dictionary = {}
## Whether the player let this one through. -1 until decided.
var verdict: int = -1


## The one on the fifth shift has no face and gives perfect answers. There is
## no reading it, and the DENY stamp does not move for it — the only choice it
## offers is the one you did not want to make.
func is_faceless() -> bool:
	return portrait < 0


func has_tell(tell: int) -> bool:
	return tells.has(tell)


## Blinking only means anything while stillness still separates the two. From
## the shift things learn it, this is not evidence either way.
func idle_reads_as_still(shift: int) -> bool:
	if not Tells.idle_is_readable(shift):
		return false
	return has_tell(Tells.Id.NO_IDLE)


func to_dict() -> Dictionary:
	return {
		"name": given_name,
		"thing": is_thing,
		"tells": tells.duplicate(),
		"portrait": portrait,
	}
