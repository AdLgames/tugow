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

	var scene: PackedScene = load("res://ui/app_shell.tscn")
	if scene == null:
		printerr("could not load the panel scene")
		quit(1)
		return
	var shell: AppShell = scene.instantiate()
	window.add_child(shell)

	# Fonts resolve asynchronously and the layout settles over a frame or two;
	# capturing immediately catches the panel mid-arrangement.
	#
	# The tweak has to wait for this too. `_ready` on a node added from a
	# SceneTree script's `_init` is deferred to the first frame, and the shell
	# loads its first model in it — which resets the tweak. Setting it before
	# the settle silently does nothing at all.
	for frame in SETTLE_FRAMES:
		await process_frame

	# Optional: size, ring and striker, so a capture can show a tweaked object
	# and the warnings a tweak can raise — not just the untouched preset.
	if arguments.size() >= 4:
		shell.state.set_tweak(float(arguments[1]), float(arguments[2]), float(arguments[3]))
	if arguments.size() >= 5:
		shell._show(AppShell.Screen.ANALYSIS if arguments[4] == "analysis"
				else AppShell.Screen.SOUNDS)
	for frame in 4:
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
