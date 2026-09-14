extends SceneTree

## Smoke-tests the audition path through the real screen, and times it.
##
## The parity test proves the samples are right; this proves the button is
## wired to them, that a strike survives being asked for four times in a row,
## and what it costs. Render cost is the number that decides whether this stays
## GDScript or moves into the GDExtension in week 3, so it gets printed rather
## than assumed.
##
##     godot --headless --path gui --script res://tools/audition_check.gd
##
## Runs headless: Godot falls back to a dummy audio driver with no sound card,
## which exercises everything except the speaker.

const SETTLE_FRAMES := 10


func _init() -> void:
	var scene: PackedScene = load("res://ui/app_shell.tscn")
	var shell: AppShell = scene.instantiate()
	get_root().add_child(shell)
	for frame in SETTLE_FRAMES:
		await process_frame

	var failures := 0
	var paths := ModelLibrary.discover()
	print("%d models in the library" % paths.size())

	for path in paths:
		shell.state.load_model(path)
		await process_frame
		if not shell.state.is_loaded():
			printerr("FAIL  %s did not load" % path.get_file())
			failures += 1
			continue

		var name := path.get_file().get_basename()
		for velocity in [0.5, 2.0, 8.0]:
			shell.state.set_velocity(velocity)
			var started := Time.get_ticks_usec()
			var samples := ModalVoice.render(shell.state.model, velocity,
					shell.state.sample_rate, 2.0)
			var elapsed := float(Time.get_ticks_usec() - started) / 1000.0

			if samples.is_empty():
				printerr("FAIL  %s at %s m/s rendered nothing" % [name, velocity])
				failures += 1
				continue
			if not ModalVoice.is_finite(samples):
				printerr("FAIL  %s at %s m/s went non-finite" % [name, velocity])
				failures += 1
				continue
			var peak := 0.0
			for sample in samples:
				peak = maxf(peak, absf(sample))
			print("  %-14s v=%4.1f  %6d samples  peak %.3f  %5.0f ms  %d modes" % [
				name, velocity, samples.size(), peak, elapsed,
				shell.state.model.modes.size()])

	# The integrated path: the panel's own strike, four times, which also
	# exercises the voice pool wrapping round.
	var panel: SoundPanel = shell._sound_panel
	for i in 5:
		panel._strike()
		await process_frame
	print("five strikes through the panel, no crash")

	if failures > 0:
		printerr("audition: %d failures" % failures)
		quit(1)
	else:
		print("audition: ok")
		quit(0)
