extends Node
## Drives the real interface the way a player does: every action here goes
## through a button that exists on screen, including the confirm overlays.
##   godot --headless --path . res://tests/ui_smoke.tscn

const MAX_ACTIONS := 600

var _main: Control
var _failures: Array[String] = []
var _benches_visited := 0
var _confirms_taken := 0
var _throws_by_strength := [0, 0, 0]
var _dice_lost := 0
var _next_strength := 0


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame

	# The title screen is an overlay with one button on it.
	# A first-time player is shown the explanation before the title.
	var guard_pages := 0
	while _press("Next") and guard_pages < 12:
		guard_pages += 1
	if not (_press("Deal me in") or _press("Sit down")):
		_fail("no way into a run from the opening screens")
		return _report()

	var game: Game = _main.game
	game.dice_lost.connect(func(lost): _dice_lost += lost.size())
	var actions := 0
	while game.phase != Game.Phase.RUN_OVER and actions < MAX_ACTIONS:
		actions += 1
		if game.phase == Game.Phase.BENCH:
			_walk_bench(game)
			await get_tree().process_frame
			continue
		_take_turn(game)
		await get_tree().process_frame

	await get_tree().process_frame
	if actions >= MAX_ACTIONS:
		_fail("the run never ended")
	if _benches_visited == 0:
		_fail("never reached the bench — the floor transition is broken")
	if _confirms_taken == 0:
		_fail("never went through a write confirmation")
	if not _main._overlay.visible:
		_fail("the run ended without a run-end screen")
	if _throws_by_strength.min() == 0:
		_fail("some throw strength was never used: %s" % str(_throws_by_strength))
	print("UI smoke: %d actions, floor %d, total %d, %d benches, %d confirmed writes, throws %s, %d dice lost."
		% [actions, game.floor_number, game.card.run_total, _benches_visited, _confirms_taken,
			str(_throws_by_strength), _dice_lost])
	_report()


func _take_turn(game: Game) -> void:
	# Rotate through throw strengths so every band gets exercised.
	var strength: int = _next_strength
	_next_strength = (_next_strength + 1) % 3
	var button: Button = _main._throw_buttons[strength]
	if not button.disabled:
		button.pressed.emit()
		_throws_by_strength[strength] += 1
	for view in _main._die_views:
		if view.die.value >= 5 and not view.disabled:
			view.pressed.emit()
			if _main._overlay.visible:
				# The lock-out warning: this is the last free die.
				_press("Stake it anyway")
	var box := _best_box(game)
	_main._ledger.line_pressed.emit(box)
	if not _main._overlay.visible:
		_fail("writing a box did not ask for confirmation")
		return
	if _hold("Hold to write it"):
		_confirms_taken += 1
	else:
		_fail("no hold-to-commit control on the write overlay")


func _walk_bench(game: Game) -> void:
	_benches_visited += 1
	if not _main._overlay.visible:
		_fail("the bench did not open on floor %d" % game.floor_number)
		return
	# Take the first affordable offer, answering whatever it asks for.
	if game.card.open_count() > 4:
		var offers := Bench.offers(game)
		if not offers.is_empty() and Bench.can_afford(game, int(offers[0]["cost"])):
			var boxes_before := game.card.open_count()
			if _press(String(offers[0]["label"]).substr(0, 12)):
				for _i in int(offers[0]["cost"]):
					_press_first_box_button()
				if _main._overlay_body.get_child_count() > 0:
					_press_any_button_that_is_not("Never mind")
				if game.card.open_count() >= boxes_before:
					_fail("a forge purchase did not cost a box")
	if not _press("On to "):
		_fail("no way out of the bench")


# --- Overlay driving ---------------------------------------------------------

## Settling is a press-and-hold, so the test holds it.
func _hold(label_prefix: String) -> bool:
	for child in _main._overlay_body.get_children():
		if child is HoldButton and child.text.begins_with(label_prefix):
			child.held.emit()
			return true
	return false


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
