class_name Throw
extends RefCounted
## The physical layer, resolved as a model rather than a physics sim: every
## die gets a landing position on a unit disc, and the zone, collisions,
## stacks and losses fall out of those positions. A visual scene can animate
## these results without changing a rule.

enum Strength { SOFT, MEDIUM, HARD }
enum Zone { POT, RAIL, LOST }

const STRENGTH_NAMES := {
	Strength.SOFT: "Soft",
	Strength.MEDIUM: "Medium",
	Strength.HARD: "Hard",
}

const STRENGTH_BLURBS := {
	Strength.SOFT: "Clustered, safe, never reaches the rail.",
	Strength.MEDIUM: "Normal spread. Some dice reach the rail.",
	Strength.HARD: "Wide scatter. Rail hits, collisions, and dice can go off the table.",
}


## Result of one throw, for logging and for a future visual layer to replay.
class Result extends RefCounted:
	var strength: int
	var thrown: Array[Die] = []
	var pushed_off: Array[Die] = []
	var lost: Array[Die] = []
	var collisions: Array = []   ## [[striker, struck, old_face, new_face], ...]
	var cocked: Array[Die] = []

	func summary() -> String:
		var parts: Array[String] = []
		parts.append("%s throw" % Throw.STRENGTH_NAMES[strength])
		if not collisions.is_empty():
			parts.append("%d collision%s" % [collisions.size(), "" if collisions.size() == 1 else "s"])
		if not cocked.is_empty():
			var names: Array[String] = []
			for d in cocked:
				names.append(d.die_name)
			parts.append("cocked: %s" % ", ".join(names))
		if not lost.is_empty():
			var lost_names: Array[String] = []
			for d in lost:
				lost_names.append(d.die_name)
			parts.append("lost off the table: %s" % ", ".join(lost_names))
		return " — ".join(parts)


static func strength_name(strength: int) -> String:
	return STRENGTH_NAMES.get(strength, "?")


## Resolve one throw over `dice` (the dice on the table). Mutates them.
## `long_throw` is the charm: hard throws no longer lose dice.
static func resolve(dice: Array[Die], strength: int, rng: RandomNumberGenerator, long_throw: bool = false) -> Result:
	var result := Result.new()
	result.strength = strength

	# 1. Dice already resting on the rail are pushed outward before anything
	#    else lands. This is what makes taking a rail double a real risk: you
	#    either lock it, score it now, or gamble it on the next throw.
	for d in dice:
		if d.lost or d.locked or d.zone != Zone.RAIL:
			continue
		d.landing_radius += _push_for(strength)
		if d.landing_radius > 1.0:
			if long_throw:
				d.landing_radius = 0.98
				continue
			_lose(d)
			result.pushed_off.append(d)
			result.lost.append(d)
	_prune_lost(dice)

	# 2. Throw everything that is free to move.
	for d in dice:
		if d.lost or d.locked:
			continue
		_place(d, strength, rng)
		d.roll()
		result.thrown.append(d)

	# 3. Dice that strike other dice knock them to a new face. Chains allowed.
	_resolve_collisions(dice, result, rng)

	# 4. A die resting on another is cocked: it counts as both faces.
	_resolve_stacks(dice, result)

	# 5. Anything past the rail is gone for the rest of the floor.
	for d in dice:
		if d.lost or d.locked:
			continue
		if d.landing_radius > 1.0:
			if long_throw:
				d.landing_radius = 0.98
				d.zone = Zone.RAIL
				continue
			_lose(d)
			result.lost.append(d)
	_prune_lost(dice)
	return result


static func zone_for_radius(radius: float) -> int:
	if radius > 1.0:
		return Zone.LOST
	if radius >= Balance.rail_inner_radius:
		return Zone.RAIL
	return Zone.POT


## How many of these dice took the rail double.
static func rail_count(dice: Array[Die]) -> int:
	var n := 0
	for d in dice:
		if not d.lost and d.zone == Zone.RAIL:
			n += 1
	return n


## The multiplier the rail applies to a score. Open question #7 — three
## shapes, all measured in tools/curve_report.gd.
static func rail_multiplier(dice: Array[Die]) -> float:
	var n := rail_count(dice)
	if n <= 0:
		return 1.0
	match Balance.rail_mode:
		Balance.RailMode.EXPONENTIAL:
			return pow(2.0, n)
		Balance.RailMode.LINEAR:
			return 1.0 + n
		Balance.RailMode.FLAT:
			return 2.0
	return 1.0


# --- Internals ---------------------------------------------------------------

static func _place(die: Die, strength: int, rng: RandomNumberGenerator) -> void:
	var band: Vector2 = Balance.throw_bands[strength]
	die.landing_radius = rng.randf_range(band.x, band.y)
	die.landing_angle = rng.randf_range(0.0, TAU)
	die.zone = zone_for_radius(die.landing_radius)
	die.cocked_on = -1


static func _push_for(strength: int) -> float:
	return Balance.rail_push.get(strength, 0.0)


static func _lose(die: Die) -> void:
	die.lost = true
	die.zone = Zone.LOST
	die.value = 0
	die.cocked_on = -1


static func _prune_lost(dice: Array[Die]) -> void:
	for d in dice:
		if d.lost and d.cocked_on != -1:
			d.cocked_on = -1


## A landing die that comes down close to a resting one knocks it to a new
## face. Locked dice cannot be hit.
static func _resolve_collisions(dice: Array[Die], result: Result, rng: RandomNumberGenerator) -> void:
	var queue: Array[Die] = result.thrown.duplicate()
	# A die is struck at most once per throw. Chains propagate outward
	# (A hits B, B hits C) but two neighbours cannot rattle each other
	# back and forth until the cap.
	var already_struck := {}
	var chain := 0
	while not queue.is_empty() and chain < Balance.max_collision_chain:
		chain += 1
		var striker: Die = queue.pop_front()
		if striker.lost:
			continue
		for other in dice:
			if other == striker or other.lost or other.locked:
				continue
			if already_struck.has(other.id):
				continue
			var gap := _distance(striker, other)
			if gap >= Balance.collision_radius or gap < Balance.stack_radius:
				continue
			var before := other.value
			other.roll()
			already_struck[other.id] = true
			result.collisions.append([striker.die_name, other.die_name, before, other.value])
			queue.append(other)
	# A collision unseats a cocked die.
	for d in dice:
		for c in result.collisions:
			if d.die_name == c[1]:
				d.cocked_on = -1


## Landing all but on top of another die: counts as both faces until disturbed.
static func _resolve_stacks(dice: Array[Die], result: Result) -> void:
	for d in dice:
		if d.lost or d.locked:
			continue
		d.cocked_on = -1
		for other in dice:
			if other == d or other.lost:
				continue
			if _distance(d, other) < Balance.stack_radius:
				d.cocked_on = other.id
				d.zone = other.zone
				result.cocked.append(d)
				break


static func _distance(a: Die, b: Die) -> float:
	return a.landing_position().distance_to(b.landing_position())
