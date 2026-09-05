extends Node
## Plays the real scene through the real buttons. Outcome tests pass on a game
## that cannot be clicked; this one presses what a player presses.

var _main: Control
var _failed: Array[String] = []
var _asked := 0
var _decided := 0
var _unrefusable := 0


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	if not _press("Begin"):
		_fail("no way into the game")
		return _report()
	await get_tree().process_frame

	var guard := 0
	while guard < 400:
		guard += 1
		var game: Game = _main.game
		if game == null:
			_fail("the run never started")
			break
		if game.phase == Game.Phase.RUN_OVER:
			break
		if _main._overlay.visible:
			if not _press_any():
				_fail("an overlay with no way out")
				break
			await get_tree().process_frame
			continue
		if game.phase != Game.Phase.QUESTIONING:
			await get_tree().process_frame
			continue
		# Ask two, then decide honestly, so the run reaches the last shift.
		var asked_here := 0
		for button in _main._question_buttons:
			if asked_here >= 2:
				break
			if not button.disabled:
				button.pressed.emit()
				_asked += 1
				asked_here += 1
		_check(game.asks_left == Questions.ASKS_PER_TRAVELLER - asked_here,
			"asks are spent by pressing the buttons")
		# Denying the faceless ones does nothing, so the honest play is to
		# approve them and take the light.
		var truth: bool = (not game.current.is_thing) or game.current.is_faceless()
		if game.current.is_faceless():
			_unrefusable += 1
		(_main._approve if truth else _main._deny).pressed.emit()
		_decided += 1
		await get_tree().process_frame

	var final: Game = _main.game
	_check(final != null and final.phase == Game.Phase.RUN_OVER, "the run reaches an ending")
	_check(_asked > 10, "questions were actually asked (%d)" % _asked)
	_check(_decided > 10, "decisions were actually made (%d)" % _decided)
	_check(final != null and final.ending_id() == &"kept_the_line",
		"playing it correctly keeps the line")
	_check(_unrefusable > 0, "and meets something it is not allowed to refuse")
	_check(final.lights == Dread.WINDOW_LIGHTS - _unrefusable,
		"costing exactly the lights it could not refuse, and no others")
	print("UI smoke: %d questions, %d decisions, shift %d, %d lights."
		% [_asked, _decided, final.shift, final.lights])
	_report()


func _press(prefix: String) -> bool:
	for child in _main._overlay_body.get_children():
		if child is Button and child.text.begins_with(prefix) and not child.disabled:
			child.pressed.emit()
			return true
	return false


func _press_any() -> bool:
	for child in _main._overlay_body.get_children():
		if child is Button and not child.disabled:
			child.pressed.emit()
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	if not _failed.has(message):
		_failed.append(message)
		print("  FAIL %s" % message)


func _report() -> void:
	if _failed.is_empty():
		print("UI smoke passed.")
		get_tree().quit(0)
		return
	print("UI smoke FAILED:")
	for f in _failed:
		print("  - %s" % f)
	get_tree().quit(1)
