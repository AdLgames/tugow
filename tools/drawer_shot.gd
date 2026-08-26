extends Node
## The Ledger drawer, closed and open.
##   xvfb-run godot --path . res://tools/drawer_shot.tscn -- --dir=/tmp/shots

var _dir := "."


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_dir)
	Balance.use_physics_dice = true
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	for _i in 8:
		if not _press(main, "Next"):
			break
	if not _press(main, "Deal me in"):
		_press(main, "Sit down")
	var waited := 0.0
	while main.game.dice_in_the_air and waited < 12.0:
		waited += get_process_delta_time()
		await get_tree().process_frame
	for _i in 20:
		await get_tree().process_frame
	await _shot("ledger_closed")
	main._ledger.set_drawer(true, false)
	main._refresh()
	for _i in 6:
		await get_tree().process_frame
	await _shot("ledger_open")
	get_tree().quit(0)


func _press(main: Control, prefix: String) -> bool:
	for child in main._overlay_body.get_children():
		if child is Button and child.text.begins_with(prefix) and not child.disabled:
			child.pressed.emit()
			return true
	return false


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	print("wrote %s" % name)
