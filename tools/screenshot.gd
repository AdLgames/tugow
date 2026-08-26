extends Node
## Renders the interface at each point of the loop so layout can be checked
## without a human.
##   xvfb-run godot --path . res://tools/screenshot.tscn -- --dir=/tmp/shots

var _dir := "."
var _main: Control


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_dir)
	# Physical throws settle in real seconds; the still frames come from the
	# model path. tools/dice_shot.tscn renders the physical table.
	Balance.use_physics_dice = false
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame

	await _shot("01_intro")
	for _i in 8:
		if not _press("Next"):
			break
	_press("Deal me in")
	_press("Sit down")
	_main._throw_buttons[Throw.Strength.HARD].pressed.emit()
	await _shot("02_turn")

	# The confirm overlay: writing a box is irreversible for the whole run.
	_main._ledger.set_drawer(true, false)
	_main._ledger.line_pressed.emit(_best_box())
	await _shot("03_confirm")
	_hold("Hold to write it")

	# Play on until the bench opens.
	var guard := 0
	while _main.game.phase != Game.Phase.BENCH and guard < 60:
		guard += 1
		await _play_one_turn()
	await _shot("04_bench")
	_press("On to ")

	# ...and on until an Adversary is on the card.
	guard = 0
	while _main.game.adversary == null and guard < 200:
		guard += 1
		if _main.game.phase == Game.Phase.BENCH:
			_press("On to ")
			continue
		if _main.game.phase == Game.Phase.RUN_OVER:
			break
		await _play_one_turn()
	if _main.game.adversary != null:
		await _shot("05_duel")

	# And to the end of the run.
	guard = 0
	while _main.game.phase != Game.Phase.RUN_OVER and guard < 300:
		guard += 1
		if _main.game.phase == Game.Phase.BENCH:
			_press("On to ")
			continue
		await _play_one_turn()
	await _shot("06_run_end")
	get_tree().quit(0)


func _play_one_turn() -> void:
	var button: Button = _main._throw_buttons[_main.game.floor_turn % 3]
	if not button.disabled:
		button.pressed.emit()
	for view in _main._die_views:
		if view.die.value >= 5 and not view.disabled:
			view.pressed.emit()
			if _main._overlay.visible:
				_press("Stake it anyway")
	_main._ledger.set_drawer(true, false)
	_main._ledger.line_pressed.emit(_best_box())
	_hold("Hold to write it")
	await get_tree().process_frame


func _best_box() -> int:
	var boxes: Array[int] = _main.game.card.open_boxes()
	var best: int = boxes[0]
	var best_value := -1
	for box in boxes:
		var v: int = _main.game.preview(box)
		if v > best_value:
			best_value = v
			best = box
	return best


func _hold(prefix: String) -> void:
	for child in _main._overlay_body.get_children():
		if child is HoldButton and child.text.begins_with(prefix):
			child.held.emit()
			return


func _press(prefix: String) -> bool:
	for child in _main._overlay_body.get_children():
		if child is Button and child.text.begins_with(prefix) and not child.disabled:
			child.pressed.emit()
			return true
	return false


func _shot(name: String) -> void:
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_dir, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("wrote %s" % path)
