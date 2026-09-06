extends Node
## Plays the real scene through the real controls. Outcome tests pass on a
## shop nobody can tap; this one presses what a thumb presses.

var _main: Control
var _failed: Array[String] = []
var _dispatched := 0
var _placed := 0


## Longest the whole run may take. A script error inside an async _ready
## abandons the test without reporting anything, and the suite then waits for
## a verdict that is never coming — which is indistinguishable from a slow
## machine and wasted a lot of time once. This turns that into a failure.
const DEADLINE := 180.0


func _ready() -> void:
	var watchdog := Timer.new()
	watchdog.wait_time = DEADLINE
	watchdog.one_shot = true
	watchdog.timeout.connect(func() -> void:
		_fail("the run did not finish within %d seconds" % int(DEADLINE))
		_report())
	add_child(watchdog)
	watchdog.start()

	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	if not _press("Open the shop"):
		_fail("no way into the game")
		return _report()
	await get_tree().process_frame

	var world: World = _main.world
	_check(world != null, "the shop opens")

	# Level 1: play thralls, stock what comes back, sell it. Five rounds is
	# enough to prove the loop and to afford the expansion; more only makes
	# the suite slow to run, which is the same as not running it.
	for _round in 5:
		for button in _main._card_buttons:
			if not button.disabled:
				button.pressed.emit()
				_dispatched += 1
		await _run(31.0)
		await _stock_via_ui(world)
		await _run(16.0)

	_check(_dispatched > 0, "thrall cards can be played (%d)" % _dispatched)
	_check(_placed > 0, "stock can be put on tables (%d)" % _placed)
	_check(world.sales > 0, "and it sells (%d)" % world.sales)
	_check(world.obols > Balance.starting_obols, "the counter goes up")

	# The expand button is the whole point of level 1.
	world.obols = maxi(world.obols, Balance.expansion_cost)
	_main._refresh()
	_check(not _main._expand_button.disabled, "the expansion unlocks when you can pay")
	_main._expand_button.pressed.emit()
	await get_tree().process_frame
	_check(world.level == 2, "and pressing it takes you to level 2")
	_main._overlay.visible = false

	# Level 2: the panels that only exist here.
	_main._refresh()
	_check(_main._corruption_bar.visible, "level 2 shows corruption")
	_check(_main._case_button.visible, "and sells display cases")

	# Tapping the floor walks; tapping a table with something in hand places it.
	# Find real floor rather than assuming: the aisles move with the layout,
	# and tapping a table is meant to walk you beside it instead.
	var spot := Vector2i(-1, -1)
	for y in range(2, world.shop.size - 2):
		for x in range(2, world.shop.size - 2):
			if world.shop.get_cell(Vector2i(x, y)) == Shop.Cell.FLOOR:
				spot = Vector2i(x, y)
				break
		if spot.x >= 0:
			break
	_check(spot.x >= 0, "the floor has somewhere to stand")
	_main._on_tile_tapped(spot)
	_check(world.player_target == spot, "tapping the floor walks you there")

	# And tapping a table walks you to its side rather than into it.
	var table := world.shop.position_of(world.shop.display_indices()[0])
	_main._on_tile_tapped(table)
	_check(world.player_target != table, "tapping a table does not walk you into it")
	_check(world.shop.walkable(world.player_target), "it walks you beside it")

	# The projection is the only way input reaches the sim, so a
	# tile that does not survive the round trip is a tile nobody can tap.
	var view: WorldView = _main._view
	var misses := 0
	for y in world.shop.size:
		for x in world.shop.size:
			var at := Vector2i(x, y)
			if view.tile_at(view.project_centre(Vector2(at))) != at:
				misses += 1
	_check(misses == 0, "every tile survives the projection round trip (%d missed)" % misses)

	# And a tap between two tiles lands on one of them, not on nothing.
	var centre := view.project_centre(Vector2(world.shop.size / 2, world.shop.size / 2))
	var nudged := view.tile_at(centre + Vector2(view.tile_size() * 0.2, 0.0))
	_check(world.shop.in_bounds(nudged), "a tap just off centre still lands on the floor")

	await _run(45.0)
	_check(world.tribute_owed >= 0, "tribute accrues without going negative")
	print("UI smoke: %d dispatched, %d placed, %d sold, %d obols, level %d."
		% [_dispatched, _placed, world.sales, world.obols, world.level])
	_report()


func _run(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		_main.world.tick(0.1)
		left -= 0.1
	await get_tree().process_frame


## Take from the back and place, the way a player does: through the button
## and a tap on a table.
func _stock_via_ui(world: World) -> void:
	for index in world.shop.display_indices():
		var at := world.shop.position_of(index)
		while world.shop.stock_at(at).size() < Shop.TABLE_CAPACITY:
			if world.shop.backroom.is_empty():
				return
			_main._take_button.pressed.emit()
			if world.carrying == null:
				return
			# Walking is real, so stand beside it before tapping.
			world.player = Vector2(world.shop.approach_to(at))
			_main._on_tile_tapped(at)
			if world.carrying != null:
				return
			_placed += 1
	await get_tree().process_frame


func _press(prefix: String) -> bool:
	for child in _main._overlay_body.get_children():
		if child is Button and child.text.begins_with(prefix):
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
