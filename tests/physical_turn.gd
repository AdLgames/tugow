extends Node
## The interface, driven by the physics. The smoke run plays on the model
## because a real throw takes seconds to settle; this plays a handful of turns
## on the simulation and checks the wiring between them: the dice go up, the
## game waits, the table that comes back is the table the rules read.
##   godot --headless --path . res://tests/physical_turn.tscn

const TURNS := 4

var _main: Control
var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	Balance.use_physics_dice = true
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	for _i in 8:
		if not _press("Next"):
			break
	if not (_press("Deal me in") or _press("Sit down")):
		_fail("no way into a run")
		return _report()

	var game: Game = _main.game
	check(game.stage != null, "the run is wired to the physical dice")

	for turn in TURNS:
		# A night that clears mid-test opens the bench. Walk straight out of
		# it and keep throwing: this test is about the physical turn, and how
		# many turns a night takes now depends on how well the dice are held.
		if game.phase == Game.Phase.BENCH:
			game.leave_bench()
			await get_tree().process_frame
		if game.phase != Game.Phase.TURN:
			break
		# Captured through an array: GDScript lambdas copy plain locals.
		var caught: Array = []
		game.stage.throw_settled.connect(
			func(records): caught.append(records), CONNECT_ONE_SHOT)
		_main._throw_buttons[turn % 3].pressed.emit()
		check(game.dice_in_the_air, "turn %d: the dice are in the air" % turn)
		check(_main._throw_buttons[0].disabled, "turn %d: you cannot throw again mid-throw" % turn)

		var waited := 0.0
		while game.dice_in_the_air and waited < 12.0:
			waited += get_process_delta_time()
			await get_tree().process_frame
		check(not game.dice_in_the_air, "turn %d: the dice come down" % turn)
		check(not caught.is_empty(), "turn %d: the stage hands back a table" % turn)
		var settled_records: Array = caught[0] if not caught.is_empty() else []
		for problem in ThrowContract.violations(settled_records):
			_fail("turn %d: %s" % [turn, problem])

		# What the rules see is what the simulation settled.
		var faces: Array = []
		for entry in settled_records:
			if not entry["lost"]:
				faces.append(int(entry["value"]))
		var read := game.pool.table_values()
		var missing := false
		for face in faces:
			if not read.has(face):
				missing = true
		check(not missing, "turn %d: every settled face reaches the resolver" % turn)

		var open := game.card.open_boxes()
		if not open.is_empty():
			_main._ledger.set_drawer(true, false)
			_main._ledger.line_pressed.emit(open[0])
			if not _hold("Hold to write it"):
				_fail("turn %d: no way to settle a line" % turn)
		await get_tree().process_frame

	check(game.card.open_count() < Scoring.BOX_COUNT, "lines were settled from physical throws")
	_report()


func _press(prefix: String) -> bool:
	for child in _main._overlay_body.get_children():
		if child is Button and child.text.begins_with(prefix) and not child.disabled:
			child.pressed.emit()
			return true
	return false


func _hold(prefix: String) -> bool:
	for child in _main._overlay_body.get_children():
		if child is HoldButton and child.text.begins_with(prefix):
			child.held.emit()
			return true
	return false


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	if not _failures.has(label):
		_failures.append(label)
		print("  FAIL %s" % label)


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("%d physical-turn checks passed." % _checks)
		get_tree().quit(0)
		return
	print("%d of %d physical-turn checks FAILED." % [_failures.size(), _checks])
	get_tree().quit(1)
