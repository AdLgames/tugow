extends Node
## Renders the interface to PNG so layout can be checked without a human.
##   xvfb-run godot --path . res://tools/screenshot.tscn -- --out=/tmp/shot.png

var _out := "shot.png"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._start_run()
	main._on_roll_pressed()
	for d in main.game.pool.table:
		if d.value >= 5:
			main._on_die_pressed(d)
	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_out)
	print("wrote %s" % _out)
	get_tree().quit(0)
