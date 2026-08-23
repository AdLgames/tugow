extends Node
## Drives the real interface the way a player does: every action here goes
## through a button that exists on screen, including the confirm overlays.
##   godot --headless --path . res://tests/ui_smoke.tscn

const MAX_ACTIONS := 600

var _main: Control
var _failures: Array[String] = []
var _forges_visited := 0
var _confirms_taken := 0


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame

	# The title screen is an overlay with one button on it.
	if not _press("Descend"):
		_fail("no Descend button on the title screen")
		return _report()

	var game: Game = _main.game
	var actions := 0
	while game.phase != Game.Phase.RUN_OVER and actions < MAX_ACTIONS:
		actions += 1
		if game.phase == Game.Phase.FORGE:
			_walk_forge(game)
			await get_tree().process_frame
			continue
		_take_turn(game)
		await get_tree().process_frame

	await get_tree().process_frame
	if actions >= MAX_ACTIONS:
		_fail("the run never ended")
	if _forges_visited == 0:
		_fail("never reached the forge — the floor transition is broken")
	if _confirms_taken == 0:
		_fail("never went through a write confirmation")
	if not _main._overlay.visible:
		_fail("the run ended without a run-end screen")
	print("UI smoke: %d actions, floor %d, total %d, %d forges, %d confirmed writes."
		% [actions, game.floor_number, game.card.run_total, _forges_visited, _confirms_taken])
	_report()


func _take_turn(game: Game) -> void:
	if not _main._roll_button.disabled:
		_main._roll_button.pressed.emit()
	for view in _main._dice_row.get_children():
		if view is DieView and view.die.value >= 5 and not view.disabled:
			view.pressed.emit()
			if _main._overlay.visible:
				# The lock-out warning: this is the last free die.
				_press("Lock it anyway")
	var box := _best_box(game)
	_main._box_rows[box].pressed.emit()
	if not _main._overlay.visible:
		_fail("writing a box did not ask for confirmation")
		return
	if _press("Write it"):
		_confirms_taken += 1
	else:
		_fail("no confirm button on the write overlay")


func _walk_forge(game: Game) -> void:
	_forges_visited += 1
	if not _main._overlay.visible:
		_fail("the forge did not open on floor %d" % game.floor_number)
		return
	# Take the first affordable offer, answering whatever it asks for.
	if game.card.open_count() > 4:
		var offers := Forge.offers(game)
		if not offers.is_empty() and Forge.can_afford(game, int(offers[0]["cost"])):
			var boxes_before := game.card.open_count()
			if _press(String(offers[0]["label"]).substr(0, 12)):
				for _i in int(offers[0]["cost"]):
					_press_first_box_button()
				if _main._overlay_body.get_child_count() > 0:
					_press_any_button_that_is_not("Never mind")
				if game.card.open_count() >= boxes_before:
					_fail("a forge purchase did not cost a box")
	if not _press("Descend to floor"):
		_fail("no way out of the forge")


# --- Overlay driving ---------------------------------------------------------

func _press(label_prefix: String) -> bool:
	for child in _main._overlay_body.get_children():
		if child is Button and child.text.begins_with(label_prefix) and not child.disabled:
			child.pressed.emit()
			return true
	return false


func _press_first_box_button() -> void:
	for child in _main._overlay_body.get_children():
		if child is Button and not child.text.begins_with("Never mind") and not child.disabled:
			child.pressed.emit()
			return


func _press_any_button_that_is_not(label_prefix: String) -> void:
	for child in _main._overlay_body.get_children():
		if child is Button and not child.text.begins_with(label_prefix) and not child.disabled:
			child.pressed.emit()
			return


func _best_box(game: Game) -> int:
	var boxes := game.card.open_boxes()
	var best: int = boxes[0]
	var best_value := -1
	for box in boxes:
		var v := game.preview(box)
		if v > best_value:
			best_value = v
			best = box
	return best


func _fail(reason: String) -> void:
	_failures.append(reason)


func _report() -> void:
	if _failures.is_empty():
		print("UI smoke passed.")
		get_tree().quit(0)
		return
	for f in _failures:
		print("UI smoke FAILED: %s" % f)
	get_tree().quit(1)
