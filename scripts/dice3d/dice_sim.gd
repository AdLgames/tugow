class_name DiceSim
extends Node3D
## The physical throw. Five rigid bodies, a felt disc, a rail the dice can
## genuinely clear, and the dirt beyond it.
##
## The sim decides what the dice do; it does not decide what that means. Raw
## landings go to ThrowContract, which derives zone, loss and cocking for both
## this path and the model in throw.gd — so the two cannot drift apart and
## quietly invalidate the balance sweeps.
##
## Forced outcomes are handled the way dice games handle them: re-seed, re-run
## invisibly, and keep the seed that satisfies the requirement (throw_search.gd).
##
## It runs headless: physics does not need a renderer, so the tests and any
## invisible search cost nothing but time.

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
## Dice leave the hand in a stream, not a rank: released together they land
## together and bounce apart, and no die can ever come to rest on another.
const RELEASE_STAGGER := 0.09
const RELEASE_JITTER := 0.05

var bodies: Array[DieBody] = []
var rng := RandomNumberGenerator.new()

var _felt: StaticBody3D
var _elapsed: float = 0.0
var _running: bool = false
var _live: Array[DieBody] = []
## Dice waiting to leave the hand.
var _release_queue: Array = []
var _last_release: float = 0.0


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
		wall.position = Vector3(cos(angle) * LIP_RADIUS, RAIL_HEIGHT * 0.5, sin(angle) * LIP_RADIUS)
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
	# something. Five bodies is nothing to rebuild.
	spawn(dice.size())
	rng.seed = seed_value
	_live = bodies
	_elapsed = 0.0
	_running = true
	_release_queue.clear()
	_last_release = 0.0

	var profile: Dictionary = Balance.throw_impulses[strength]
	for i in _live.size():
		var body := _live[i]
		body.cocked_on = -1
		body.settled_value = 0
		var release_at := float(i) * RELEASE_STAGGER + rng.randf_range(0.0, RELEASE_JITTER)
		_last_release = maxf(_last_release, release_at)
		var lateral := rng.randf_range(-1.0, 1.0) * float(profile["spread"])
		var origin := Vector3(lateral, 1.6 + rng.randf_range(0.0, 0.5),
			LIP_RADIUS * 0.80 + rng.randf_range(-0.2, 0.2))
		var aim := Vector3(
			rng.randf_range(-1.0, 1.0) * float(profile["spread"]),
			float(profile["lift"]),
			-float(profile["impulse"]) * rng.randf_range(0.86, 1.14))
		var spin := Vector3(
			rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)
		) * float(profile["spin"])
		var start := Basis.from_euler(Vector3(
			rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU)))
		# Parked out of the way until its turn, so it cannot be struck early.
		body.throw_from(Vector3(0, 40.0 + i, 0), start, Vector3.ZERO, Vector3.ZERO)
		_release_queue.append({
			"die": body, "at": release_at, "origin": origin,
			"basis": start, "impulse": aim, "spin": spin,
		})


func is_running() -> bool:
	return _running


func _physics_process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	_release_due()
	if _elapsed < MIN_FLIGHT + _last_release:
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


## Let go of any die whose moment has come.
func _release_due() -> void:
	var still_waiting: Array = []
	for entry in _release_queue:
		if _elapsed < float(entry["at"]):
			still_waiting.append(entry)
			continue
		var body: DieBody = entry["die"]
		body.throw_from(entry["origin"], entry["basis"], entry["impulse"], entry["spin"])
	_release_queue = still_waiting


## Read the raw landings off the settled bodies and hand them to the contract.
## Nothing about zones, loss or cocking is decided here.
func read_outcome() -> Array:
	var records: Array = []
	for body in _live:
		var position := Vector2(body.global_position.x, body.global_position.z) / LIP_RADIUS
		if body.global_position.y < DIRT_Y:
			# Past the lip and still falling: park it outside the disc so the
			# contract reads it as lost.
			position = position.normalized() * 1.5 if position.length() > 0.01 \
				else Vector2(1.5, 0.0)
		var flat := body.is_flat()
		var value := body.read_face()
		var second := 0
		if not flat:
			# Leaning: it is showing two faces, and both count.
			var faces := body.read_two_faces()
			value = int(faces[0])
			second = int(faces[1])
		body.cocked_on = -1 if flat else body.die_id
		records.append(ThrowContract.record(body.die_id, value, position, second, flat))
	return ThrowContract.derive(records)
