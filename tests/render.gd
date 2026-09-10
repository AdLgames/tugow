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

	await _check_lighting()
	await _check_sorting()
	_report()


## The room should be dark, and a lamp should make its patch of floor brighter
## than the far side of the map. Measured rather than asserted, because a
## CanvasModulate with no lights at all also "looks dark".
func _check_lighting() -> void:
	var lamp := _world.lights.get_child(0) as Lamp
	if lamp == null:
		_fail("there is no lamp to test")
		return
	var lit_cell := _world.cell_at(lamp.global_position)
	var dark_cell := _far_floor_from(lit_cell)
	# Both readings are of floor, so the difference is the light and not the
	# art underneath it.
	var lit := await _brightness_at(lit_cell)
	var dark := await _brightness_at(dark_cell)
	print("  brightness — under the lamp: %.3f, far corner: %.3f" % [lit, dark])
	_check(lit > dark + 0.03, "the lamp is brightest where it stands")
	# The one light is meant to reach the whole room, so the far corner being
	# dark is a failure here rather than the mood it was before.
	_check(dark > 0.2, "and still reaches the far corner")

	await _check_shadows()


## Whether shadows actually fall is not something `shadow_enabled` proves: a
## light with the flag set and nothing to occlude looks identical. So a lamp
## is put right up against a wall and the same view measured twice, with the
## shadows on and off. If the wall is casting, switching it off can only let
## more light through.
func _check_shadows() -> void:
	var beside := _floor_beside_a_wall()
	_check(not beside.is_empty(), "the map has floor up against a wall")
	if beside.is_empty():
		return
	var lamp := _world.add_lamp(beside[0], 120.0)
	lamp.energy = 2.0
	# The authored lamps would light the same walls from other angles and mask
	# the difference, so this is the only light on for the measurement.
	var others := _all_lights()
	for light in others:
		light.enabled = false
	lamp.light.enabled = true

	var shadowed := await _whole_screen_at(beside[0])
	lamp.cast_shadows = false
	var unshadowed := await _whole_screen_at(beside[0])
	lamp.cast_shadows = true

	print("  brightness — shadows on: %.3f, off: %.3f" % [shadowed, unshadowed])
	_check(unshadowed > shadowed + 0.005, "the walls cast shadows into the room")

	for light in others:
		light.enabled = true
	lamp.queue_free()


## Floor with a wall next to it, so a lamp put there has something to cast off.
func _floor_beside_a_wall() -> Array[Vector2i]:
	for cell in _world.ground.get_used_cells():
		if not _world.is_floor(cell):
			continue
		for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			if _world.is_blocked(cell + step):
				return [cell]
	return []


## Averaged over the whole viewport, because a shadow falls away from the
## light rather than under it — sampling only the middle would miss it.
func _whole_screen_at(cell: Vector2i) -> float:
	_world.player.global_position = _world.centre_of(cell)
	await _settle()
	var image := get_viewport().get_texture().get_image()
	var total := 0.0
	var count := 0
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	return total / maxi(1, count)


func _all_lights() -> Array[PointLight2D]:
	var out: Array[PointLight2D] = []
	for lamp in _world.lights.get_children():
		if lamp is Lamp:
			out.append((lamp as Lamp).light)
	return out


func _check_sorting() -> void:
	# Lighting would confuse a colour match, so the sorting half of the test
	# runs with the darkness turned off.
	_world.night.color = Color.WHITE

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


## How bright the floor is around a cell. The camera follows the player, so
## parking them on the cell puts it in the middle of the screen; only that
## middle is sampled, because averaging the whole viewport dilutes a small
## pool of light into the dark room around it until the difference vanishes.
const SAMPLE := 240

func _brightness_at(cell: Vector2i) -> float:
	_world.player.global_position = _world.centre_of(cell)
	await _settle()
	var image := get_viewport().get_texture().get_image()
	var middle := Vector2i(image.get_width(), image.get_height()) / 2
	var total := 0.0
	var count := 0
	for y in range(middle.y - SAMPLE / 2, middle.y + SAMPLE / 2, 3):
		for x in range(middle.x - SAMPLE / 2, middle.x + SAMPLE / 2, 3):
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	return total / maxi(1, count)


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


func _far_floor_from(cell: Vector2i) -> Vector2i:
	var best := cell
	var furthest := -1.0
	for at in _world.ground.get_used_cells():
		if not _world.is_floor(at):
			continue
		var away := Vector2(at - cell).length()
		if away > furthest:
			furthest = away
			best = at
	return best


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
