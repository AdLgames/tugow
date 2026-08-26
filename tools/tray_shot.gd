extends Node
## Every slip state side by side, so the tray can be read at a glance.

var _dir := "."


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_dir)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	for _i in 8:
		if not _press(main, "Next"):
			break
	if not _press(main, "Deal me in"):
		_press(main, "Sit down")
	for _i in 4:
		await get_tree().process_frame

	var game: Game = main.game
	game.throw(Throw.Strength.MEDIUM)
	while game.dice_in_the_air:
		await get_tree().process_frame
	# One of each: staked, bitter on the rail, cocked, in the dirt, and one
	# plain die in the pot. The throw may have lost dice of its own, so every
	# slip is set explicitly rather than trusting where they landed.
	var table := game.pool.table
	for d in table:
		d.lost = false
		d.bitter = false
		d.cocked_on = -1
		d.second_value = 0
		d.zone = Throw.Zone.POT
	table[0].value = 4
	game.lock_die(table[0])
	table[1].bitter = true
	table[1].value = 6
	table[1].zone = Throw.Zone.RAIL
	table[2].value = 3
	table[2].second_value = 5
	table[2].cocked_on = table[4].id
	table[3].lost = true
	table[3].value = 0
	table[4].value = 2
	main._refresh()
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/tray_states.png" % _dir)
	get_tree().quit(0)


func _press(main: Control, prefix: String) -> bool:
	for child in main._overlay_body.get_children():
		if child is Button and child.text.begins_with(prefix) and not child.disabled:
			child.pressed.emit()
			return true
	return false
