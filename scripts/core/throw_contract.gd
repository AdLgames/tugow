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
static func record(id: int, value: int, position: Vector2, resting_on: int = -1,
		flat: bool = true) -> Dictionary:
	return {
		"id": id,
		"value": value,
		"position": position,
		"resting_on": resting_on,
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
			entry["resting_on"] = -1
		entry["cocked_on"] = -1 if entry["lost"] else int(entry["resting_on"])
	return records


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
		var beneath := int(entry["cocked_on"])
		if beneath == -1:
			continue
		for other in records:
			if int(other["id"]) == beneath and not other["lost"]:
				out.append(int(other["value"]))
				break
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

		var beneath := int(entry["cocked_on"])
		if beneath == -1:
			continue
		if beneath == id:
			problems.append("die %d is cocked on itself" % id)
		var found := false
		for other in records:
			if int(other["id"]) == beneath:
				found = true
				if other["lost"]:
					problems.append("die %d is cocked on a die that is gone" % id)
				if int(other["cocked_on"]) == id:
					problems.append("dice %d and %d are cocked on each other" % [id, beneath])
		if not found:
			problems.append("die %d is cocked on a die that is not in this throw" % id)
	return problems
