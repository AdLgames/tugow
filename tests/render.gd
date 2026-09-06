extends Node
## Proves the sorting actually occludes, by looking at the pixels.
##
##   xvfb-run godot --path . res://tests/render.tscn
##
## Worth its weight: Y-sorting is configuration, not code, and when it is
## wrong nothing errors — the player simply walks over the top of things.
## This was found the hard way. Tiles in a Y-sorted TileMapLayer sort against
## each other but do NOT interleave with sibling nodes, so anything the player
## must pass behind has to be a prop rather than a tile.

const PLAYER_TONE := Color("8fd07a")
const DEADLINE := 40.0

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

	var prop_cell := Vector2i(6, 6)
	# Positions are in cells, not pixels. An earlier version of this test hard
	# coded pixel offsets and quietly stopped testing anything the moment the
	# cell size changed.
	var behind := await _visible_player_pixels(_at(prop_cell.x + 0.5, prop_cell.y - 0.25))
	var in_front := await _visible_player_pixels(_at(prop_cell.x + 0.5, prop_cell.y + 1.8))

	print("  player pixels — behind the prop: %d, in front of it: %d"
		% [behind, in_front])
	_check(in_front > 400, "the player is drawn when nothing is in the way")
	_check(behind < in_front * 0.5,
		"and is hidden behind a prop they are standing above")
	_report()


## A point given in cells, so nothing here depends on the cell size.
func _at(cx: float, cy: float) -> Vector2:
	return Vector2(cx, cy) * float(World.CELL)


## How much of the player is on screen, counted in pixels of their own colour.
func _visible_player_pixels(at: Vector2) -> int:
	_world.player.global_position = at
	for _i in 6:
		await get_tree().physics_frame
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var seen := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).is_equal_approx(PLAYER_TONE):
				seen += 1
	return seen


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
		print("Render passed.")
		get_tree().quit(0)
		return
	print("Render FAILED:")
	for f in _failed:
		print("  - %s" % f)
	get_tree().quit(1)
