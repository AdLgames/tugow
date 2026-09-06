extends Node
## Proves the wireframe works: the scene loads, the room is painted, the
## player walks, and walls stop them.
##
##   godot --headless --path . res://tests/smoke.tscn
##
## Worth keeping. The first thing that breaks in a setup like this is a tile
## being solid in the editor but not at runtime, and that is invisible until
## someone walks into it.

const DEADLINE := 30.0

var _world: World
var _failed: Array[String] = []


func _ready() -> void:
	var watchdog := Timer.new()
	watchdog.wait_time = DEADLINE
	watchdog.one_shot = true
	watchdog.timeout.connect(func() -> void:
		_fail("the run did not finish in %d seconds" % int(DEADLINE))
		_report())
	add_child(watchdog)
	watchdog.start()

	_world = load("res://scenes/world.tscn").instantiate()
	add_child(_world)
	await get_tree().physics_frame

	_check(_world.ground.tile_set != null, "the ground layer has a tileset")
	_check(_world.ground.tile_set.tile_size == Vector2i(World.CELL, World.CELL),
		"tiles are %d square" % World.CELL)
	_check(not _world.ground.get_used_cells().is_empty(), "a starter room is painted")
	_check(not _world.walls.get_used_cells().is_empty(), "and walled in")

	# The wall tile must actually be solid. A tile with no collision shape
	# looks identical in the editor and is walked straight through.
	var source := _world.walls.tile_set.get_source(World.SOURCE) as TileSetAtlasSource
	_check(source != null, "the tileset has an atlas source")
	if source != null:
		var data := source.get_tile_data(World.TILE_WALL, 0)
		_check(data != null and data.get_collision_polygons_count(0) > 0,
			"the wall tile carries a collision shape")
		var floor_data := source.get_tile_data(World.TILE_FLOOR, 0)
		_check(floor_data != null and floor_data.get_collision_polygons_count(0) == 0,
			"and the floor tile does not")

	_check(_world.is_blocked(Vector2i(-1, 5)), "a wall cell reads as blocked")
	_check(not _world.is_blocked(Vector2i(5, 5)), "and a floor cell does not")

	# Walking. Push right for a while and the player should move.
	var start: Vector2 = _world.player.global_position
	await _hold("move_right", 0.6)
	_check(_world.player.global_position.x > start.x + 20.0,
		"holding a direction walks the player")

	# And a wall should stop them. Drive hard into the left wall.
	_world.player.global_position = Vector2(World.CELL, World.CELL * 5)
	await get_tree().physics_frame
	await _hold("move_left", 1.6)
	_check(_world.player.global_position.x > 0.0,
		"a wall stops the player rather than letting them through")

	# The grid maths agrees with itself both ways.
	var misses := 0
	for y in World.ROOM.size.y:
		for x in World.ROOM.size.x:
			var cell := Vector2i(x, y)
			var middle := Vector2(cell) * World.CELL + Vector2.ONE * (World.CELL * 0.5)
			if _world.cell_at(middle) != cell:
				misses += 1
	_check(misses == 0, "every cell survives the world-to-grid round trip")

	print("Smoke: room %s, player at %s." % [World.ROOM.size, _world.player.global_position])
	_report()


## Hold an action down for real physics frames, the way a player would.
func _hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_tree().root.get_physics_process_delta_time()
	Input.action_release(action)
	await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	if not _failed.has(message):
		_failed.append(message)
		print("  FAIL %s" % message)


func _report() -> void:
	if _failed.is_empty():
		print("Smoke passed.")
		get_tree().quit(0)
		return
	print("Smoke FAILED:")
	for f in _failed:
		print("  - %s" % f)
	get_tree().quit(1)
