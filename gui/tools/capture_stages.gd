extends SceneTree

## Captures all five fit stages, at two velocities, into one contact sheet.
##
## The stage stepper is the design's main control and four of its five views
## are only reachable by clicking. A single capture proves one of them draws;
## this walks the whole set so a broken view cannot hide behind the default.
##
##     xvfb-run -a godot --path gui --script res://tools/capture_stages.gd -- out_prefix

const WIDTH := 1384
const HEIGHT := 1200
const SETTLE_FRAMES := 8


func _init() -> void:
	var prefix := "stage"
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0:
		prefix = arguments[0]

	var window := get_root()
	window.size = Vector2i(WIDTH, HEIGHT)
	var scene: PackedScene = load("res://ui/modal_fit_panel.tscn")
	var panel: ModalFitPanel = scene.instantiate()
	window.add_child(panel)

	for frame in SETTLE_FRAMES:
		await process_frame

	var failures := 0
	for stage in FitState.Stage.values():
		panel.state.set_stage(stage)
		# Two velocities per stage: the contact pulse drives every view, so a
		# view that ignores it is a view that is drawing something stale.
		for velocity in [0.8, 9.0]:
			panel.state.set_velocity(velocity)
			for frame in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var image := window.get_texture().get_image()
			var name := "%s_%d_%s.png" % [prefix, stage, String.num(velocity, 1)]
			if image == null or image.save_png(name) != OK:
				printerr("could not capture stage %d" % stage)
				failures += 1
			else:
				print("wrote %s" % name)
	quit(1 if failures > 0 else 0)
