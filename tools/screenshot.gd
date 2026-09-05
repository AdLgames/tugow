extends Node
## The booth at each of the moments that matter.
##   xvfb-run godot --path . res://tools/screenshot.tscn -- --dir=/tmp/shots

var _dir := "."
var _main: Control


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_dir)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	await _shot("01_title")

	_press("Begin")
	await get_tree().process_frame
	await _shot("02_shift_opening")

	_press("Open")
	for _i in 4:
		await get_tree().process_frame
	await _shot("03_first_traveller")

	# Ask two, so the transcript has something in it.
	var asked := 0
	for button in _main._question_buttons:
		if asked >= 2:
			break
		if not button.disabled:
			button.pressed.emit()
			asked += 1
	for _i in 3:
		await get_tree().process_frame
	await _shot("04_questioning")

	# Wave everything through until the window is dark and the lamp closes in.
	var game: Game = _main.game
	var guard := 0
	while guard < 60 and game.phase != Game.Phase.RUN_OVER:
		guard += 1
		if _main._overlay.visible:
			_press_any()
			await get_tree().process_frame
			continue
		if game.phase == Game.Phase.QUESTIONING:
			_main._approve.pressed.emit()
		await get_tree().process_frame
		if game.things_let_through >= 3:
			break
	for _i in 3:
		await get_tree().process_frame
	await _shot("05_lights_going_out")

	# Force a scare so the framing can be checked.
	game.armed_scare = Scares.Id.LEAN_IN
	game.armed_at = 0.0
	game.armed_seen_travellers = 2
	game.tick(1.0)
	for _i in 3:
		await get_tree().process_frame
	await _shot("06_scare")
	get_tree().quit(0)


func _press(prefix: String) -> bool:
	for child in _main._overlay_body.get_children():
		if child is Button and child.text.begins_with(prefix) and not child.disabled:
			child.pressed.emit()
			return true
	return false


func _press_any() -> void:
	for child in _main._overlay_body.get_children():
		if child is Button and not child.disabled:
			child.pressed.emit()
			return


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, shot_name])
	print("wrote %s" % shot_name)
