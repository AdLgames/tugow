extends Node
## Drives the real interface without a human: start a run, roll, lock, write,
## walk the forge, and keep going until the run ends. Catches runtime errors
## the headless logic tests cannot see.
##   godot --headless --path . res://tests/ui_smoke.tscn

const MAX_ACTIONS := 500

var _main: Control


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame

	_main._start_run()
	var game: Game = _main.game
	var actions := 0
	while game.phase != Game.Phase.RUN_OVER and actions < MAX_ACTIONS:
		actions += 1
		if game.phase == Game.Phase.FORGE:
			_walk_forge(game)
			continue
		_main._on_roll_pressed()
		for d in game.pool.table:
			if d.value >= 5:
				_main._on_die_pressed(d)
		_main._on_box_pressed(_best_box(game))
		await get_tree().process_frame

	await get_tree().process_frame
	if actions >= MAX_ACTIONS:
		print("UI smoke FAILED: the run never ended.")
		get_tree().quit(1)
		return
	print("UI smoke passed: %d actions, floor %d, total %d." % [actions, game.floor_number, game.card.run_total])
	get_tree().quit(0)


func _walk_forge(game: Game) -> void:
	_main._show_forge()
	var offers := Forge.offers(game)
	if not offers.is_empty() and Forge.can_afford(game, int(offers[0]["cost"])) and game.card.open_count() > 4:
		_main._on_forge_offer(offers[0])
		# The forge asks for the sacrifice, then the target; answer both.
		while _main._pending_sacrifices.size() < int(offers[0]["cost"]):
			_main._pending_sacrifices.append(game.card.open_boxes()[0])
		_main._ask_for_target()
		if _main._overlay_body.get_child_count() > 0 and not _main._pending_offer.is_empty():
			if String(_main._pending_offer["target"]) != "none":
				_main._apply_forge(game.pool.dice[0].id)
	_main._leave_forge()


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
