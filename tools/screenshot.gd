extends Node
## The shop at the moments that matter.
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

	_press("Open the shop")
	await _settle(6)
	await _shot("02_level1_empty")

	# Play the shop: dispatch, stock, sell.
	var world: World = _main.world
	for _round in 6:
		while world.thralls.can_dispatch():
			world.dispatch_thrall()
		await _run(31.0)
		await _stock_everything(world)
		await _run(24.0)
	await _shot("03_level1_trading")

	# Buy the expansion.
	world.obols = maxi(world.obols, Balance.expansion_cost)
	await _settle(3)
	_main._on_expand()
	await _settle(3)
	await _shot("04_expanded")
	_main._overlay.visible = false
	await _settle(3)

	# Trade at level 2 until something turns.
	for _round in 5:
		while world.thralls.can_dispatch():
			world.dispatch_thrall()
		await _run(31.0)
		await _stock_everything(world)
		await _run(18.0)
	await _shot("05_level2_trading")

	# Let a floor go bad on purpose.
	for key in world.shop.displays:
		for unit in world.shop.displays[key]:
			if Goods.perishable(unit.id):
				unit.age = Goods.shelf_life(unit.id) + 1.0
	world.corruption = Balance.corruption_cap * 0.7
	await _run(2.0)
	await _shot("06_corrupted")
	get_tree().quit(0)


## Drive the sim forward in real steps, and let the view draw.
func _run(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		_main.world.tick(0.1)
		left -= 0.1
		if fmod(left, 1.0) < 0.1:
			await get_tree().process_frame
	await get_tree().process_frame


func _stock_everything(world: World) -> void:
	for at_index in world.shop.display_indices():
		var at := world.shop.position_of(at_index)
		while world.shop.stock_at(at).size() < Shop.TABLE_CAPACITY:
			if not world.take_from_backroom():
				return
			world.player = Vector2(at)
			world.place_carried(at)
	await get_tree().process_frame


func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


func _press(prefix: String) -> bool:
	for child in _main._overlay_body.get_children():
		if child is Button and child.text.begins_with(prefix):
			child.pressed.emit()
			return true
	return false


func _shot(shot_name: String) -> void:
	# An audit can fire mid-run; the shot is of the shop, not of a dialogue.
	if _main._overlay.visible and shot_name != "01_title":
		_main._overlay.visible = false
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, shot_name])
	print("wrote %s" % shot_name)
