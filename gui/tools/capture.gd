extends SceneTree

## Renders the panel to a PNG, for design review and for catching draw errors
## in CI.
##
## Headless runs never call `_draw`, and nearly all of this panel is `_draw` —
## four plot views, the casting, the mode rows. A parity test proves the
## arithmetic; this proves the drawing code runs at all, and gives something to
## hold next to the design.
##
## Needs a display. On a headless machine:
##     xvfb-run -a godot --path gui --script res://tools/capture.gd -- out.png
##
## The window size is the design's layout width, so the capture is directly
## comparable to the mockup rather than to whatever the last window was.

const WIDTH := 1384
const HEIGHT := 1200
const SETTLE_FRAMES := 12


func _init() -> void:
	var output := "modal_fit.png"
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0:
		output = arguments[0]

	var window := get_root()
	window.size = Vector2i(WIDTH, HEIGHT)
	window.transparent_bg = false

	var scene: PackedScene = load("res://ui/modal_fit_panel.tscn")
	if scene == null:
		printerr("could not load the panel scene")
		quit(1)
		return
	window.add_child(scene.instantiate())

	# Fonts resolve asynchronously and the layout settles over a frame or two;
	# capturing immediately catches the panel mid-arrangement.
	for frame in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw

	var image := window.get_texture().get_image()
	if image == null:
		printerr("no viewport image — is there a display?")
		quit(1)
		return
	var error := image.save_png(output)
	if error != OK:
		printerr("could not write %s (error %d)" % [output, error])
		quit(1)
		return
	print("wrote %s (%d×%d)" % [output, image.get_width(), image.get_height()])
	quit(0)
