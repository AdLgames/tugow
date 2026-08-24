class_name DiceSim
extends Node3D
## The physical throw. Five rigid bodies, a felt disc, a rail the dice can
## genuinely clear, and the dirt beyond it.
##
## The sim is authoritative for what the dice do. Everything the rules need —
## face, zone, cocked, lost — is read back off the settled bodies rather than
## decided in advance. Forced outcomes are handled the way dice games handle
## them: re-seed, re-run invisibly, and keep the seed that satisfies the
## requirement (see throw_search.gd).
##
## It runs headless: physics does not need a renderer, so the tests and any
## invisible search cost nothing but time.
##
## NOT YET WIRED INTO THE GAME. Game.throw() still runs the model in
## throw.gd, and the two disagree: this sim produces no cocked dice at the
## committed profiles, where the model produces them regularly. Reconcile the
## two behind one contract for zones, loss and cocking before switching the
## game over, or the balance sweeps stop describing the game they measure.

signal settled(outcome: Array)

## Table geometry, in metres.
const LIP_RADIUS := 5.0
const DIE_SIZE := 0.62
const RAIL_HEIGHT := 0.62      ## Low enough that a hard throw clears it — D5.
const RAIL_SEGMENTS := 28
const DIRT_Y := -4.0
## A die balanced on an edge must never hang the turn — D4.
const SETTLE_TIMEOUT := 4.0
## The impulse is integrated on the next tick, so a rest check before this has
## not seen the throw happen yet — without it every throw settles on the spot.
const MIN_FLIGHT := 0.45

var bodies: Array[DieBody] = []
var rng := RandomNumberGenerator.new()

var _felt: StaticBody3D
var _elapsed: float = 0.0
var _running: bool = false
var _live: Array[DieBody] = []


func _ready() -> void:
	_build_table()


func _build_table() -> void:
	_felt = StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = LIP_RADIUS
	cylinder.height = 0.4
	floor_shape.shape = cylinder
	floor_shape.position = Vector3(0, -0.2, 0)
	_felt.add_child(floor_shape)
	var felt_material := PhysicsMaterial.new()
	felt_material.friction = 0.8
	felt_material.bounce = 0.12
	_felt.physics_material_override = felt_material
	add_child(_felt)

	# The rail: a ring of low walls. Dice can clear it on a hard throw, which
	# is what makes the risk real rather than theatrical.
	var rail := StaticBody3D.new()
	for i in RAIL_SEGMENTS:
		var angle := TAU * float(i) / float(RAIL_SEGMENTS)
		var wall := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var segment_width := TAU * LIP_RADIUS / float(RAIL_SEGMENTS) * 1.2
		box.size = Vector3(segment_width, RAIL_HEIGHT, 0.28)
		wall.shape = box
		wall.position = Vector3(cos(angle), RAIL_HEIGHT * 0.5, sin(angle)) * LIP_RADIUS
		wall.position.y = RAIL_HEIGHT * 0.5
		wall.rotation.y = -angle
		rail.add_child(wall)
	add_child(rail)


func spawn(count: int) -> void:
	for body in bodies:
		remove_child(body)
		body.free()
	bodies.clear()
	for i in count:
		var body := DieBody.new(i, DIE_SIZE)
		add_child(body)
		body.global_position = Vector3(-3.0 + i * 1.2, 6.0, 0.0)
		bodies.append(body)


## Throw `dice` at the given strength. Same seed and same strength produce the
## same result: the impulses come from a seeded generator and the physics tick
## is fixed, so nothing here is tied to frame rate — D2.
func begin_throw(dice: Array[DieBody], strength: int, seed_value: int) -> void:
	# Fresh bodies every throw. The solver warm-starts from the previous
	# frame's contacts, so two identical throws made from different histories
	# diverge — dice that never touched each other in one run collide in the
	# next. New RIDs carry no history, which is what makes a seed mean
	# something (D2). Five bodies is nothing to rebuild.
	spawn(dice.size())
	rng.seed = seed_value
	_live = bodies
	_elapsed = 0.0
	_running = true
	var profile: Dictionary = Balance.throw_impulses[strength]
	for i in dice.size():
		var body := dice[i]
		body.cocked_on = -1
		body.settled_value = 0
		# Thrown from the near lip, across the felt.
		var lateral := rng.randf_range(-1.0, 1.0) * float(profile["spread"])
		var origin := Vector3(lateral, 1.6 + rng.randf_range(0.0, 0.5), LIP_RADIUS * 0.80)
		var aim := Vector3(
			rng.randf_range(-1.0, 1.0) * float(profile["spread"]),
			float(profile["lift"]),
			-float(profile["impulse"]) * rng.randf_range(0.86, 1.14))
		var spin := Vector3(
			rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)
		) * float(profile["spin"])
		var start := Basis.from_euler(Vector3(
			rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU)))
		body.throw_from(origin, start, aim, spin)


func is_running() -> bool:
	return _running


func _physics_process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	if _elapsed < MIN_FLIGHT:
		return
	var all_rested := true
	for body in _live:
		if body.global_position.y < DIRT_Y:
			continue
		if not body.at_rest():
			all_rested = false
			break
	if all_rested or _elapsed >= SETTLE_TIMEOUT:
		_running = false
		settled.emit(read_outcome())


## Read the rules' state off the settled bodies. Nothing is decided here that
## the physics did not already decide.
func read_outcome() -> Array:
	var out: Array = []
	for body in _live:
		var lost := body.global_position.y < DIRT_Y \
			or body.table_radius(LIP_RADIUS) > 1.0
		body.settled_value = 0 if lost else body.read_face()
		out.append({
			"id": body.die_id,
			"value": body.settled_value,
			"radius": body.table_radius(LIP_RADIUS),
			"lost": lost,
			"flat": body.is_flat(),
			"position": Vector2(body.global_position.x, body.global_position.z) / LIP_RADIUS,
		})
	_resolve_cocked(out)
	return out


## A die resting on another is a natural outcome of the sim rather than a
## special case — D6. Read geometrically rather than from contacts, because a
## sleeping body reports no contacts and every settled die is asleep.
func _resolve_cocked(out: Array) -> void:
	for i in _live.size():
		out[i]["cocked_on"] = -1
	for i in _live.size():
		var body := _live[i]
		# Resting on another die is the definition, flat or not: a die sitting
		# squarely on top of another is the commonest stack, and gating on
		# tilt excluded exactly that case.
		if out[i]["lost"]:
			continue
		var beneath := -1
		var best_drop := 0.0
		for j in _live.size():
			if i == j or out[j]["lost"]:
				continue
			var other := _live[j]
			var drop := body.global_position.y - other.global_position.y
			if drop < DIE_SIZE * 0.35 or drop > DIE_SIZE * 1.4:
				continue
			var flat_gap := Vector2(
				body.global_position.x - other.global_position.x,
				body.global_position.z - other.global_position.z).length()
			if flat_gap > DIE_SIZE * 1.05:
				continue
			if drop > best_drop:
				best_drop = drop
				beneath = other.die_id
		body.cocked_on = beneath
		out[i]["cocked_on"] = beneath
