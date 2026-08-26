class_name ThrowContract
extends RefCounted
## One definition of what a throw produced, for both the model in throw.gd
## and the physics in dice3d/dice_sim.gd.
##
## There are two ways to throw dice in this project: a resolved model, which
## the tests and the balance sweeps run on, and a rigid-body simulation, which
## the player will watch. If they disagree about what counts as the rail, what
## counts as lost, or what counts as cocked, then the numbers in BALANCE.md
## stop describing the game they were measured from. So neither path decides
## any of that: both hand their raw landings here, and this file derives the
## rest.

## One die's landing, before derivation. `position` is on the unit disc:
## length 1.0 is the lip of the table.
## A cocked die is one that is showing two faces at once. In the physics that
## is a die which did not settle flat, reading the face nearest the ceiling
## and the one it has tipped toward; in the model it is a die that came down
## on another, reading its own face and the one beneath. Either way the rules
## see the same thing: `second_value` greater than zero.
static func record(id: int, value: int, position: Vector2, second_value: int = 0,
		flat: bool = true) -> Dictionary:
	return {
		"id": id,
		"value": value,
		"position": position,
		"second_value": second_value,
		"flat": flat,
	}


## Fill in radius, zone, lost and cocked from the raw landings. Every field a
## rule reads is derived here and nowhere else.
static func derive(records: Array) -> Array:
	for entry in records:
		var position: Vector2 = entry["position"]
		var radius: float = position.length()
		entry["radius"] = radius
		entry["lost"] = radius > 1.0
		entry["zone"] = zone_for_radius(radius)
		if entry["lost"]:
			entry["value"] = 0
			entry["second_value"] = 0
		entry["cocked"] = int(entry["second_value"]) > 0
	return records


## Dice already resting on the rail are shoved outward before the next throw
## lands. This is what makes taking a rail double a decision rather than a
## free double: lock it, settle now, or gamble it. Returns the dice lost.
static func push_rail_dice(dice: Array, strength: int, long_throw: bool) -> Array[Die]:
	var lost: Array[Die] = []
	for die in dice:
		if die.lost or die.locked or die.zone != Throw.Zone.RAIL:
			continue
		die.landing_radius += float(Balance.rail_push.get(strength, 0.0))
		if die.landing_radius <= 1.0:
			continue
		if long_throw:
			die.landing_radius = 0.98
			continue
		die.lost = true
		die.zone = Throw.Zone.LOST
		die.value = 0
		die.second_value = 0
		lost.append(die)
	return lost


static func zone_for_radius(radius: float) -> int:
	if radius > 1.0:
		return Throw.Zone.LOST
	if radius >= Balance.rail_inner_radius:
		return Throw.Zone.RAIL
	return Throw.Zone.POT


## The values the resolver scores. A cocked die contributes its own face and
## the face of the die beneath it — the one place that rule is written.
static func values_of(records: Array) -> Array:
	var out: Array = []
	for entry in records:
		if entry["lost"] or int(entry["value"]) <= 0:
			continue
		out.append(int(entry["value"]))
		if int(entry["second_value"]) > 0:
			out.append(int(entry["second_value"]))
	return out


## Everything that must be true of any throw, from either path. Returns the
## list of violations, empty when the throw is well formed.
static func violations(records: Array) -> Array[String]:
	var problems: Array[String] = []
	var seen_ids := {}
	for entry in records:
		var id := int(entry["id"])
		if seen_ids.has(id):
			problems.append("die %d appears twice in one throw" % id)
		seen_ids[id] = true

		var radius: float = entry["radius"]
		var zone := int(entry["zone"])
		if zone != zone_for_radius(radius):
			problems.append("die %d: zone %d disagrees with radius %.3f" % [id, zone, radius])
		if entry["lost"] != (zone == Throw.Zone.LOST):
			problems.append("die %d: lost flag disagrees with its zone" % id)
		if entry["lost"] and int(entry["value"]) != 0:
			problems.append("die %d is lost but still shows a face" % id)
		if not entry["lost"] and (int(entry["value"]) < 1 or int(entry["value"]) > 9):
			problems.append("die %d shows %d, outside 1-9" % [id, int(entry["value"])])

		var second := int(entry["second_value"])
		if second == 0:
			continue
		if second < 1 or second > 9:
			problems.append("die %d shows a second face of %d" % [id, second])
		if second == int(entry["value"]):
			problems.append("die %d is cocked between a face and itself" % id)
	return problems
