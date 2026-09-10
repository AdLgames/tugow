extends Node
## Proves the sorting actually occludes, and that the lights light, by looking
## at the pixels.
##
##   xvfb-run godot --path . res://tests/render.tscn
##
## Worth its weight: Y-sorting and lighting are both configuration rather than
## code, and when either is wrong nothing errors — the player simply walks
## over the top of things, or the room is a black rectangle.
##
## This was found the hard way. Tiles in a Y-sorted TileMapLayer sort against
## each other but do NOT interleave with sibling nodes, so anything the player
## must pass behind has to be a prop rather than a tile.

const PLAYER_TONE := Color("8fd07a")
const DEADLINE := 60.0

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

	await _check_sun()
	await _check_sorting()
	_report()


## The wall should be throwing a shadow onto the floor beside it. Measured
## rather than asserted, because the sun is drawn rather than lit and a
## drawing that ended up under the floor, or behind the wall it came from,
## looks exactly like no shadow at all.
func _check_sun() -> void:
	var sun := _world.sun
	if sun == null:
		_fail("there is no sun to test")
		return
	var shaded := _shaded_cell()
	_check(not shaded.is_empty(), "a wall has floor in its shadow")
	if shaded.is_empty():
		return

	var with_sun := await _floor_tone(shaded[0])
	sun.visible = false
	var without := await _floor_tone(shaded[0])
	sun.visible = true
	print("  floor beside the wall — sun on: %.3f, sun off: %.3f" % [with_sun, without])
	_check(without > with_sun + 0.01, "the wall darkens the floor in front of it")

	# And it must not darken the whole room, which is what a shadow drawn at
	# the wrong offset would do.
	var open := _open_cell()
	if not open.is_empty():
		var lit := await _floor_tone(open[0])
		print("  open floor: %.3f" % lit)
		_check(lit > with_sun, "while open floor stays lit")


## The floor cell a wall's shadow falls on: one step along the shadow from a
## wall, with nothing else on it.
func _shaded_cell() -> Array[Vector2i]:
	var shift := _world.sun.offset()
	var step := Vector2i(signi(roundi(shift.x)), signi(roundi(shift.y)))
	for cell in _world.ground.get_used_cells():
		if not _world.is_blocked(cell):
			continue
		var onto := cell + Vector2i(0, step.y)
		if _world.is_floor(onto) and _world.is_floor(onto + Vector2i(0, step.y)):
			return [onto]
	return []


## How bright a small patch of floor is, with the player moved off it so
## their own colour is not counted.
func _floor_tone(cell: Vector2i) -> float:
	_world.player.global_position = _world.centre_of(cell + Vector2i(4, 4))
	await _settle()
	var image := get_viewport().get_texture().get_image()
	var middle := Vector2i(image.get_width(), image.get_height()) / 2
	var at := _world.centre_of(cell) - _world.player.global_position
	# The camera is centred on the player at 4x, so a world offset is four
	# screen pixels per pixel.
	var on_screen := middle + Vector2i(at * 4.0)
	var total := 0.0
	var count := 0
	for y in range(on_screen.y - 12, on_screen.y + 12, 2):
		for x in range(on_screen.x - 24, on_screen.x + 24, 2):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	return total / maxi(1, count)


func _check_sorting() -> void:
	# The sun's shading would confuse a colour match, so the sorting half of
	# the test runs without it.
	_world.night.color = Color.WHITE
	_world.sun.visible = false

	var found := _open_cell()
	if found.is_empty():
		_fail("no open floor to stand a prop on")
		return
	var prop_cell := found[0]
	_world.add_prop(prop_cell, 32.0)
	await get_tree().physics_frame

	# Positions are in cells, not pixels. An earlier version of this test hard
	# coded pixel offsets and quietly stopped testing anything the moment the
	# cell size changed.
	var behind := await _player_pixels(_world.centre_of(prop_cell + Vector2i.UP) + Vector2(0, 4))
	var in_front := await _player_pixels(_world.centre_of(prop_cell + Vector2i.DOWN * 2))

	print("  player pixels — behind the prop: %d, in front of it: %d"
		% [behind, in_front])
	_check(in_front > 400, "the player is drawn when nothing is in the way")
	_check(behind < in_front * 0.5,
		"and is hidden behind a prop they are standing above")



## How much of the player is on screen, counted in pixels of their own colour.
func _player_pixels(at: Vector2) -> int:
	_world.player.global_position = at
	await _settle()
	var image := get_viewport().get_texture().get_image()
	var seen := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).is_equal_approx(PLAYER_TONE):
				seen += 1
	return seen


## The camera smooths towards the player, so a capture taken straight after a
## teleport is of the old position.
func _settle() -> void:
	for _i in 20:
		await get_tree().physics_frame
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


## A floor cell with floor all around it, so a prop and a player both fit.
## Empty when there is nowhere suitable, so the caller cannot mistake "none"
## for a real cell at the origin.
func _open_cell() -> Array[Vector2i]:
	for cell in _world.ground.get_used_cells():
		var clear := true
		for dy in range(-1, 3):
			if not _world.is_floor(cell + Vector2i(0, dy)):
				clear = false
				break
		if clear:
			return [cell]
	return []



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
