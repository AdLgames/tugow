extends SceneTree

## Writes a tweaked model to disk, so the C++ runtime can be asked to open it.
##
## The GUI's whole promise on the Sounds screen is that "Save as a new sound"
## produces a real `.modal` that the engine will load. A GDScript test can only
## prove the writer round-trips through the GDScript loader, which is the same
## code twice — it would pass just as happily if both halves were wrong. This
## hands the file to `modal-render --report` instead, which is the loader that
## actually matters.
##
##     godot --headless --path gui --script res://tools/write_variant.gd \
##         -- source.modal out.modal SIZE RING STRIKER_MS

const RATE := 48000.0


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 5:
		printerr("usage: -- <source.modal> <out.modal> <size> <ring> <striker_ms>")
		quit(2)
		return

	var source_path: String = arguments[0]
	var out_path: String = arguments[1]
	var size := float(arguments[2])
	var ring := float(arguments[3])
	var striker := float(arguments[4])

	var source := ModalModel.load_from_file(source_path, RATE)
	if not source.ok:
		printerr("could not load %s: %s" % [source_path, source.error])
		quit(1)
		return

	var tweaked := ModelTweak.apply(source, size, ring, striker, RATE)
	if not tweaked.ok:
		printerr("tweak failed: %s" % tweaked.error)
		quit(1)
		return

	var error := ModelTweak.save(tweaked, out_path, out_path.get_file().get_basename(),
			"written by tools/write_variant.gd")
	if not error.is_empty():
		printerr(error)
		quit(1)
		return

	print("source  %d modes, f0 %.1f Hz, longest tau %.3f s" % [
		source.modes.size(), SoundWords.fundamental(source), SoundWords.longest_decay(source)])
	print("variant %d modes, f0 %.1f Hz, longest tau %.3f s" % [
		tweaked.modes.size(), SoundWords.fundamental(tweaked), SoundWords.longest_decay(tweaked)])
	for warning in tweaked.warnings:
		print("warn: %s" % warning)
	print("wrote %s" % out_path)
	quit(0)
