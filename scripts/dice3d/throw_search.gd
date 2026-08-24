class_name ThrowSearch
extends RefCounted
## Forced outcomes, the way dice games do them — D3.
##
## The design needs results the physics cannot be asked for politely: the
## Reflection throwing what you threw, a charm setting a face, an Adversary
## scripted to land what it declared. Rather than teleport the dice after the
## fact, run the sim invisibly at speed, keep re-seeding until the result
## satisfies the requirement, and then play that seed back visibly. The throw
## the player watches is a real throw.

const MAX_ATTEMPTS := 48
## How much faster than real time the invisible runs go.
const SEARCH_TIME_SCALE := 24.0

## Returns {"seed": int, "outcome": Array, "attempts": int, "matched": bool}.
## `requirement` takes the outcome array and returns true when it will do.
## When nothing matches inside the budget the last run is returned with
## matched=false: a throw the player can see beats a hang.
static func find(sim: DiceSim, dice: Array[DieBody], strength: int,
		requirement: Callable, rng: RandomNumberGenerator,
		attempts: int = MAX_ATTEMPTS) -> Dictionary:
	var tree := sim.get_tree()
	var previous := _begin_fast(SEARCH_TIME_SCALE)

	var last_seed := 0
	var last_outcome: Array = []
	var matched := false
	var used := 0
	for attempt in attempts:
		used = attempt + 1
		last_seed = rng.randi()
		sim.begin_throw(dice, strength, last_seed)
		while sim.is_running():
			await tree.physics_frame
		last_outcome = sim.read_outcome()
		if requirement.is_null() or requirement.call(last_outcome):
			matched = true
			break

	_end_fast(previous)
	return {
		"seed": last_seed,
		"outcome": last_outcome,
		"attempts": used,
		"matched": matched,
	}


## Running the sim faster than real time means taking MORE steps, not longer
## ones: Engine.time_scale stretches the step size, so the tick rate has to
## rise with it or the dice tunnel straight through the table.
static func _begin_fast(scale: float) -> Dictionary:
	var previous := {
		"time_scale": Engine.time_scale,
		"ticks": Engine.physics_ticks_per_second,
		"steps": Engine.max_physics_steps_per_frame,
	}
	Engine.physics_ticks_per_second = int(60.0 * scale)
	Engine.max_physics_steps_per_frame = int(scale * 8.0)
	Engine.time_scale = scale
	return previous


static func _end_fast(previous: Dictionary) -> void:
	Engine.time_scale = float(previous["time_scale"])
	Engine.physics_ticks_per_second = int(previous["ticks"])
	Engine.max_physics_steps_per_frame = int(previous["steps"])


## Requirement helper: every die shows one of these faces.
static func faces_in(allowed: Array) -> Callable:
	return func(outcome: Array) -> bool:
		for entry in outcome:
			if entry["lost"]:
				return false
			if not allowed.has(entry["value"]):
				return false
		return true


## Requirement helper: the multiset of faces matches exactly — what the
## Reflection needs to wear your last throw.
static func matches_values(wanted: Array) -> Callable:
	return func(outcome: Array) -> bool:
		var got: Array = []
		for entry in outcome:
			if not entry["lost"]:
				got.append(entry["value"])
		got.sort()
		var target := wanted.duplicate()
		target.sort()
		return got == target
