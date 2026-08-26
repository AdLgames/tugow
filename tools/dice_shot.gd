extends Node
## Renders the physical dice on the felt, once they have settled.
##   xvfb-run godot --path . res://tools/dice_shot.tscn -- --out=/tmp/dice.png

var _out := "dice.png"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	Balance.use_physics_dice = true
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	for _i in 8:
		var pressed := false
		for child in main._overlay_body.get_children():
			if child is Button and child.text.begins_with("Next"):
				child.pressed.emit()
				pressed = true
				break
		if not pressed:
			break
	for child in main._overlay_body.get_children():
		if child is Button and (child.text.begins_with("Deal me in") or child.text.begins_with("Sit down")):
			child.pressed.emit()
			break

	var waited := 0.0
	while main.game.dice_in_the_air and waited < 12.0:
		waited += get_process_delta_time()
		await get_tree().process_frame
	for _i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out)
	print("wrote %s" % _out)
	get_tree().quit(0)
