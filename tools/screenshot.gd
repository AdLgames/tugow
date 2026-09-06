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
	# Walk a little, so the camera has followed and the shot is not static.
	# Stand in the cell *above* a post — not inside it, which is solid and
	# would simply shove the player back out. From there the player's body
	# overlaps the post's upper half and should be hidden behind it.
	world.player.global_position = Vector2(6.5, 5.75) * float(World.CELL)
	for _i in 4:
		await get_tree().physics_frame
	await _shot("02_behind_a_post")
	world.player.global_position = Vector2(6.5, 7.8) * float(World.CELL)
	for _i in 4:
		await get_tree().physics_frame
	await _shot("03_in_front_of_a_post")
	Input.action_press("move_right")
	Input.action_press("move_down")
	for _i in 40:
		await get_tree().physics_frame
	Input.action_release("move_right")
	Input.action_release("move_down")
	for _i in 8:
		await get_tree().process_frame
	await _shot("04_walked")
	get_tree().quit(0)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, shot_name])
	print("wrote %s" % shot_name)
