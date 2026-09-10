extends Node
## A picture of the wireframe running.
##   xvfb-run godot --path . res://tools/screenshot.tscn -- --dir=/tmp/shots

var _dir := "."


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_dir)
	var world: World = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	for _i in 8:
		await get_tree().process_frame
	await _shot("01_start")

	# The whole room in one frame, which is the only way to judge lighting
	# that is meant to reach every corner.
	var camera: Camera2D = world.player.get_node("Camera")
	var was := camera.zoom
	var room := world.ground.get_used_rect()
	world.player.global_position = world.centre_of(room.position + room.size / 2)
	camera.zoom = Vector2(3.0, 3.0)
	for _i in 20:
		await get_tree().physics_frame
	await _shot("02_the_room")
	camera.zoom = was

	# Stand under each lamp in turn, since the lighting is the point of most
	# of these shots and a lamp off screen tells you nothing.
	var index := 2
	for lamp in world.lights.get_children():
		world.player.global_position = (lamp as Node2D).global_position
		for _i in 12:
			await get_tree().physics_frame
		await _shot("0%d_under_%s" % [index + 1, (lamp as Node2D).name.to_lower()])
		index += 1

	# A prop, to show the sorting. Stand in the cell *above* it — not inside
	# it, which is solid and would simply shove the player back out. From
	# there the player's body overlaps the prop and should be hidden by it.
	var stand := world.cell_at(world.player.global_position)
	world.add_prop(stand + Vector2i.DOWN * 2, 32.0)
	world.player.global_position = world.centre_of(stand + Vector2i.DOWN)
	for _i in 12:
		await get_tree().physics_frame
	await _shot("0%d_behind_a_prop" % [index + 1])
	Input.action_press("move_right")
	Input.action_press("move_down")
	for _i in 40:
		await get_tree().physics_frame
	Input.action_release("move_right")
	Input.action_release("move_down")
	for _i in 8:
		await get_tree().process_frame
	await _shot("0%d_walked" % [index + 2])
	get_tree().quit(0)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, shot_name])
	print("wrote %s" % shot_name)
