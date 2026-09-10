extends Node
## Proves the wireframe works: the scene loads, the painted map is solid where
## it should be, the player walks, and walls stop them.
##
##   godot --headless --path . res://tests/smoke.tscn
##
## Worth keeping. The first thing that breaks in a setup like this is a tile
## being solid in the editor but not at runtime, and that is invisible until
## someone walks into it.

const DEADLINE := 30.0
## Names that mark a texture as a wall. Kept in step with WALL_WORDS in
## tools/apply_tile_roles.gd — if these two ever disagree, a tile is one thing
## to the tool and another to the game.
const WALL_WORDS := ["wall", "vertical"]

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

	_check_tileset()
	_check_map()
	await _check_props()
	_check_lighting()
	await _check_walking()
	_report()


func _check_tileset() -> void:
	var tile_set: TileSet = _world.ground.tile_set
	_check(tile_set != null, "the ground layer has a tileset")
	if tile_set == null:
		return
	_check(tile_set.tile_size == Vector2i(World.CELL, World.CELL),
		"tiles are %d square" % World.CELL)
	_check(tile_set.get_physics_layers_count() > 0, "there is a physics layer")
	_check(tile_set.get_occlusion_layers_count() > 0,
		"and an occlusion layer, without which nothing casts a shadow")
	if tile_set.get_physics_layers_count() == 0 or tile_set.get_occlusion_layers_count() == 0:
		return

	# Every source is checked, not a sample. A single wall tile that missed
	# its collision shape is a hole in the room you find by falling through it.
	var walls := 0
	var floors := 0
	var wrong: Array[String] = []
	for i in tile_set.get_source_count():
		var id := tile_set.get_source_id(i)
		var atlas := tile_set.get_source(id) as TileSetAtlasSource
		if atlas == null or atlas.texture == null:
			wrong.append("source %d has no texture" % id)
			continue
		var name := atlas.texture.resource_path.get_file()
		var solid := _is_wall(name)
		if solid:
			walls += 1
		else:
			floors += 1
		_check(atlas.get_tiles_count() > 0, "%s has a tile in it" % name)
		for t in atlas.get_tiles_count():
			var data := atlas.get_tile_data(atlas.get_tile_id(t), 0)
			if data == null:
				continue
			var blocks := data.get_collision_polygons_count(0) > 0
			var shadows := data.get_occluder_polygons_count(0) > 0
			if blocks != solid:
				wrong.append("%s %s solid" % [name, "is" if blocks else "is not"])
			if shadows != solid:
				wrong.append("%s %s a shadow" % [name, "casts" if shadows else "casts no"])
	_check(walls > 0, "some sources are walls (%d)" % walls)
	_check(floors > 0, "and some are floor (%d)" % floors)
	_check(wrong.is_empty(), "every tile blocks and shadows to match its name")
	for w in wrong:
		print("       %s" % w)


func _check_map() -> void:
	var painted := _world.ground.get_used_cells().size()
	_check(painted > 0, "the map has tiles painted on it (%d)" % painted)
	var solid := 0
	var walkable := 0
	for cell in _world.ground.get_used_cells():
		if _world.is_blocked(cell):
			solid += 1
		elif _world.is_floor(cell):
			walkable += 1
	_check(solid > 0, "some of them are solid (%d)" % solid)
	_check(walkable > 0, "and some are somewhere to stand (%d)" % walkable)

	# The layers are only useful together if they agree on where a cell is.
	# A nudged layer puts its collision half a tile off from its art.
	for layer in _world.layers():
		_check(layer.position == Vector2.ZERO,
			"the %s layer sits on the grid" % layer.name)

	_check(_world.is_floor(_world.cell_at(_world.player.global_position)),
		"the player starts somewhere they can stand")


## Props built from art, rather than the placeholder box.
func _check_props() -> void:
	var counter := _world.add_counter(_first_open_cell(), 4)
	await get_tree().physics_frame
	_check(counter.get_child_count() == 4, "a counter of four is four pieces")
	if counter.get_child_count() != 4:
		return

	var pieces := counter.get_children()
	var first := pieces[0] as Prop
	var last := pieces[3] as Prop
	_check(first != null and first.texture == counter.start_texture,
		"the first piece is the capped end")
	_check(last != null and last.texture == counter.end_texture,
		"and the last is the other one")

	# The art is 20 pixels of counter on a 32 pixel canvas. Taking the canvas
	# would collide six pixels of nothing either side, and the run would sit
	# twelve pixels apart instead of butting up.
	_check(first.width < 32.0, "a piece is as wide as its art, not its canvas (%.0f)"
		% first.width)
	_check(is_equal_approx(pieces[1].position.y - first.position.y, first.height),
		"pieces butt up against each other")
	for piece in pieces:
		var prop := piece as Prop
		_check(prop != null and prop.footprint > World.CELL,
			"%s is solid across all of itself, not just its base" % prop.name)
		_check(prop.base != null and prop.base.shape != null,
			"%s carries a collision shape" % prop.name)
	counter.queue_free()

	# A table is seen from the side, so it keeps the shallow footprint.
	var table := _world.add_table(_first_open_cell())
	await get_tree().physics_frame
	_check(table.footprint < World.CELL, "a table keeps a shallow footprint")
	table.queue_free()


func _first_open_cell() -> Vector2i:
	for cell in _world.ground.get_used_cells():
		if _world.is_floor(cell):
			return cell
	return Vector2i.ZERO


func _check_lighting() -> void:
	_check(_world.night != null, "the scene sets an ambient level")

	var sun := _world.sun
	_check(sun != null, "there is a sun")
	if sun == null:
		return
	# Drawn between the floor and everything standing on it. Before Ground and
	# the floor covers it; after Props and it darkens the player.
	var order := _world.get_children()
	_check(order.find(sun) > order.find(_world.ground),
		"the sun draws over the floor")
	_check(order.find(sun) < order.find(_world.props),
		"and under whatever is standing on it")

	# Afternoon, so the sun is over the right of the room and the shadows
	# fall down and to the left. Both signs matter: a shadow pointing the
	# other way puts the sun in the wrong corner and nothing errors.
	var shift := sun.offset()
	_check(sun.hour > 12.0 and sun.hour < 18.0, "it is afternoon (%.1f)" % sun.hour)
	_check(shift.y > 0.0, "shadows fall away from the top of the room")
	_check(shift.x < 0.0, "and towards its left, so the sun is on the right")
	_check(shift.length() < World.CELL, "and are shorter than a cell (%.1f px)"
		% shift.length())
	_check(not sun.shadow_cells().is_empty(),
		"walls throw a shadow onto the floor (%d of them)" % sun.shadow_cells().size())

	# No lamp is placed in the room — the sun is the light — but the lamp is
	# still what an interior light will be, so it is checked on one built
	# here rather than left untested until someone needs it.
	var lamp := _world.add_lamp(_world.cell_at(_world.player.global_position))
	_check(lamp.light != null and lamp.light.texture != null,
		"a lamp has a light texture, without which it is invisible")
	_check(lamp.light != null and lamp.light.shadow_enabled, "and casts shadows")
	lamp.queue_free()


func _check_walking() -> void:
	var start := _world.cell_at(_world.player.global_position)

	# Walking into open floor should move you.
	var open := _open_direction(start)
	_check(open != Vector2i.ZERO, "there is open floor next to the player")
	if open != Vector2i.ZERO:
		var before := _world.player.global_position
		await _walk(Vector2(open), 0.6)
		_check(_world.player.global_position.distance_to(before) > World.CELL * 0.5,
			"holding a direction walks")

	# And walking into a wall should not. The player is moved next to one
	# rather than hoping they spawned beside it, so the test means the same
	# thing whatever the map looks like.
	var spot := _floor_beside_a_wall()
	_check(not spot.is_empty(), "the map has floor up against a wall")
	if spot.is_empty():
		return
	_world.player.global_position = _world.centre_of(spot[0])
	await get_tree().physics_frame
	var into := _wall_direction(spot[0])
	var at_wall := _world.player.global_position
	await _walk(Vector2(into), 1.2)
	_check(_world.player.global_position.distance_to(at_wall) < World.CELL * 1.5,
		"and a wall stops you")


## Hold a direction for a while and let physics run.
func _walk(direction: Vector2, seconds: float) -> void:
	var steps := int(seconds / get_physics_process_delta_time())
	for _i in steps:
		_world.player.walk(direction)
		await get_tree().physics_frame


func _open_direction(from: Vector2i) -> Vector2i:
	for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if _world.is_floor(from + step) and _world.is_floor(from + step * 2):
			return step
	return Vector2i.ZERO


## A cell you can stand in with a wall next to it. Empty when the map has
## none, which is worth failing on: a room with no walls is not a room.
func _floor_beside_a_wall() -> Array[Vector2i]:
	for cell in _world.ground.get_used_cells():
		if not _world.is_floor(cell):
			continue
		if _wall_direction(cell) != Vector2i.ZERO:
			return [cell]
	return []


func _wall_direction(from: Vector2i) -> Vector2i:
	for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if _world.is_blocked(from + step):
			return step
	return Vector2i.ZERO


func _is_wall(name: String) -> bool:
	var lower := name.to_lower()
	for word in WALL_WORDS:
		if lower.contains(word):
			return true
	return false


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
