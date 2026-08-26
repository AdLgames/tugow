extends Node
## The face you see must be the face you score.
##
## Everything else about the dice can be tested headlessly, but not this: the
## rules read an axis, the player reads a texture, and nothing in the code
## makes those agree by itself. So render each value from above, count the
## dots in the picture, and check the picture says what the rules say.
##   xvfb-run godot --path . res://tests/die_face_render.tscn

const VIEW := 220

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(VIEW, VIEW)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var body := MeshInstance3D.new()
	body.mesh = DieMesh.build(1.0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = DiePips.atlas()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body.material_override = material
	viewport.add_child(body)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.05
	viewport.add_child(camera)
	camera.position = Vector3(0, 4, 0)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)

	for value in range(1, 7):
		# Orient the die the way the rules would, then look at it.
		body.transform.basis = DieBody.basis_showing(value)
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var counted := _count_pips(viewport.get_texture().get_image())
		check(counted == value, "a die showing %d has %d dots on top" % [value, counted])

	# And the pairing a real die has.
	for pair in [[1, 6], [2, 5], [3, 4]]:
		var top: int = pair[0]
		var opposite := 0
		for entry in DieMesh.FACES:
			if (entry[0] as Vector3).is_equal_approx(-_axis_of(top)):
				opposite = int(entry[1])
		check(top + opposite == 7, "%d is opposite %d" % [top, opposite])
	_report()


func _axis_of(value: int) -> Vector3:
	for entry in DieMesh.FACES:
		if int(entry[1]) == value:
			return entry[0]
	return Vector3.ZERO


## Count the dark blobs in the rendered face.
func _count_pips(image: Image) -> int:
	var dark := {}
	for x in image.get_width():
		for y in image.get_height():
			if image.get_pixel(x, y).v < 0.28 and image.get_pixel(x, y).a > 0.5:
				dark[Vector2i(x, y)] = true
	var seen := {}
	var blobs := 0
	for cell in dark:
		if seen.has(cell):
			continue
		blobs += 1
		var queue: Array[Vector2i] = [cell]
		while not queue.is_empty():
			var at: Vector2i = queue.pop_back()
			if seen.has(at) or not dark.has(at):
				continue
			seen[at] = true
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				queue.append(at + step)
	return blobs


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   %s" % label)
	else:
		_failures.append(label)
		print("  FAIL %s" % label)


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("%d face-render checks passed." % _checks)
		get_tree().quit(0)
		return
	print("%d of %d face-render checks FAILED." % [_failures.size(), _checks])
	get_tree().quit(1)
