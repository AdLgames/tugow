extends Node
## The table before the first draw, and after it.
##   xvfb-run godot --path . res://tools/first_throw_shot.tscn -- --dir=/tmp/shots

var _dir := "."
var _main: Control


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_dir)
	Balance.use_physics_dice = true
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	for _i in 8:
		if not _press("Next"):
			break
	if not _press("Deal me in"):
		_press("Sit down")
	for _i in 6:
		await get_tree().process_frame
	await _shot("01_before_the_draw")

	var game: Game = _main.game
	print("before: turn_rolled=%s table_ids=%s" % [game.turn_rolled, str(game._thrown_ids())])
	_main._throw_buttons[Throw.Strength.MEDIUM].pressed.emit()
	var waited := 0.0
	while game.dice_in_the_air and waited < 12.0:
		waited += get_process_delta_time()
		await get_tree().process_frame
	for _i in 20:
		await get_tree().process_frame
	var moved := 0
	for body in game.stage.sim.bodies:
		if body.global_position.y < 4.0:
			moved += 1
	print("after: %d of %d bodies came down onto the table" % [moved, game.stage.sim.bodies.size()])
	await _shot("02_after_the_draw")
	get_tree().quit(0)


func _press(prefix: String) -> bool:
	for child in _main._overlay_body.get_children():
		if child is Button and child.text.begins_with(prefix) and not child.disabled:
			child.pressed.emit()
			return true
	return false


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
