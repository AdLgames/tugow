extends SceneTree

## Parity between the GUI's GDScript maths and the C++ it mirrors.
##
## The panel draws conclusions about an object — this is how bright it gets,
## this is where it stops getting brighter, these are the modes your runtime
## will actually voice — and those conclusions are only worth showing if the
## arithmetic behind them is the arithmetic in `core/`. A GUI that is
## approximately right is a GUI that lies quietly.
##
## Expected values are not hand-derived. They were produced by compiling
## `core/src/excitation.cpp` and `core/src/model.cpp` and printing the results,
## which is the same discipline `tests/test_fitter.cpp` uses: check against an
## answer you obtained independently, not against your own implementation.
##
## Run from the `gui/` directory:
##     godot --headless --script res://tests/test_parity.gd
##
## Exits non-zero on failure, so it drops straight into CI.

const RATE := 48000.0
const REF_MS := 0.15
const EPSILON := 1e-9

## velocity → [contact_seconds, pulse width, pulse scale, frames]
const CONTACT_EXPECTED := {
	0.5: [1.723047532496e-04, 8.270628155979, 0.241683131080, 9],
	1.0: [1.500000000000e-04, 7.200000000000, 0.277567932702, 8],
	2.0: [1.305825844944e-04, 6.267964055732, 0.318665583298, 7],
	4.0: [1.136787424883e-04, 5.456579639437, 0.366241470945, 6],
	8.0: [9.896309330797e-05, 4.750228478782, 0.422305101894, 5],
	10.0: [9.464360167203e-05, 4.542892880257, 0.440850483148, 5],
	20.0: [8.239204074796e-05, 3.954817955902, 0.506363136145, 4],
}

## The pulse at 2.0 m/s, sample by sample. Width, not shape, is what the
## fractional-width correction in the plan was about — but a window sampled at
## the wrong offset has the right width and the wrong spectrum, so the shape is
## checked too.
const PULSE_AT_2MS := [
	0.019597966224, 0.148641049862, 0.287557810545, 0.308060616255,
	0.191215455532, 0.044927116483, 0.000000000000,
]

## What the loader keeps from `models/ceramic_mug.modal` at 48 kHz: fourteen
## modes in the file, three above the 21.6 kHz ceiling, eleven voiced.
const CERAMIC_KEPT := 11
const CERAMIC_IN_FILE := 14
const CERAMIC_DROPPED_HZ := [22534.5, 25149.0, 27888.0]

var _failures := 0
var _checks := 0


func _init() -> void:
	_test_contact_and_pulse()
	_test_pulse_shape()
	_test_excitation_gain_is_unity_at_dc()
	_test_brightness_rises_then_clamps()
	_test_ceramic_load()
	_test_strike_gain_fallback()
	_test_every_shipped_model_loads()

	print("")
	if _failures == 0:
		print("parity: %d checks passed" % _checks)
		quit(0)
	else:
		printerr("parity: %d of %d checks FAILED" % [_failures, _checks])
		quit(1)


# --- checks ------------------------------------------------------------------

func _test_contact_and_pulse() -> void:
	for velocity in CONTACT_EXPECTED:
		var expected: Array = CONTACT_EXPECTED[velocity]
		var seconds := Excitation.contact_seconds(REF_MS, velocity)
		var pulse := Excitation.make_pulse(1.0, REF_MS, velocity, RATE)
		_close("contact_seconds at %s m/s" % velocity, seconds, expected[0])
		_close("pulse width at %s m/s" % velocity, pulse.width, expected[1])
		_close("pulse scale at %s m/s" % velocity, pulse.scale, expected[2])
		_equal("pulse frames at %s m/s" % velocity, pulse.frames, expected[3])


func _test_pulse_shape() -> void:
	var pulse := Excitation.make_pulse(1.0, REF_MS, 2.0, RATE)
	_equal("pulse frame count at 2 m/s", pulse.frames, PULSE_AT_2MS.size())
	for n in PULSE_AT_2MS.size():
		# `Pulse::sample` returns float, so the reference values carry float32
		# rounding that GDScript's doubles do not. The tolerance is float32
		# epsilon rather than the double epsilon used everywhere else; anything
		# tighter tests the C++'s narrowing, not this port.
		_close("pulse sample %d" % n, pulse.sample(n), PULSE_AT_2MS[n], 1e-7)

	# The window normalises against its own sum, so the impulse arrives whole.
	# Getting this wrong delivers half the energy at every velocity, which is
	# the first correction the build plan records.
	var total := 0.0
	for n in pulse.frames:
		total += pulse.sample(n)
	_close("pulse sums to its impulse", total, 1.0, 1e-12)


func _test_excitation_gain_is_unity_at_dc() -> void:
	var pulse := Excitation.make_pulse(1.0, REF_MS, 2.0, RATE)
	_close("excitation gain at DC", Excitation.excitation_gain(pulse, 0.0, RATE), 1.0, 1e-12)


## The panel's central claim, as an assertion: brightness rises with velocity
## and stops rising once contact time hits its clamp. If this ever fails, the
## velocity slider is telling a story the engine does not.
func _test_brightness_rises_then_clamps() -> void:
	var model := _ceramic()
	if model == null:
		return
	var gains := model.gains_at(-1)

	var previous := -1.0
	for velocity in [0.5, 1.0, 2.0, 4.0, 8.0]:
		var amplitudes := Excitation.mode_amplitudes(model, velocity, gains, RATE)
		var centroid := Excitation.spectral_centroid(model, amplitudes)
		_true("centroid rises by %s m/s" % velocity, centroid > previous)
		previous = centroid

	# Where the clamp actually bites, which is a fifth power of the material's
	# reference contact time and so wildly different per material: steel at
	# 10.5 m/s, ceramic not until 243. The README's "about 10 m/s" is steel's
	# figure, and the panel must not print it under a ceramic mug.
	var clamp := Excitation.clamp_velocity(REF_MS)
	_close("ceramic clamps at 243 m/s", clamp, 243.0, 1e-6)
	_close("steel clamps near 10.5 m/s", Excitation.clamp_velocity(0.08), 10.48576, 1e-5)
	_close("glass clamps near 80 m/s", Excitation.clamp_velocity(0.12), 79.62624, 1e-5)

	# Just below the clamp the contact time is still moving; above it, it is
	# pinned, so two very different velocities give exactly the same timbre.
	_true("contact time is still free below the clamp",
			Excitation.contact_seconds(REF_MS, clamp * 0.5) > Excitation.MIN_CONTACT_SECONDS)
	_close("contact time is clamped at the clamp velocity",
			Excitation.contact_seconds(REF_MS, clamp), Excitation.MIN_CONTACT_SECONDS)
	_close("contact time stays clamped far past it",
			Excitation.contact_seconds(REF_MS, clamp * 10.0), Excitation.MIN_CONTACT_SECONDS)

	# And the consequence the panel exists to show: past the clamp, velocity
	# buys loudness but no further brightness.
	var gains_again := model.gains_at(-1)
	var past := Excitation.spectral_centroid(model,
			Excitation.mode_amplitudes(model, clamp * 2.0, gains_again, RATE))
	var far_past := Excitation.spectral_centroid(model,
			Excitation.mode_amplitudes(model, clamp * 20.0, gains_again, RATE))
	_close("brightness stops rising past the clamp", far_past, past, 1e-9)


func _test_ceramic_load() -> void:
	var model := _ceramic()
	if model == null:
		return
	_true("ceramic model loads", model.ok)
	_equal("modes in file", model.modes_in_file, CERAMIC_IN_FILE)
	_equal("modes kept at 48 kHz", model.modes.size(), CERAMIC_KEPT)
	_equal("warnings raised", model.warnings.size(), CERAMIC_DROPPED_HZ.size())
	for frequency in CERAMIC_DROPPED_HZ:
		var text := ModalModel._say(frequency)
		var found := false
		for warning in model.warnings:
			if warning.contains(text):
				found = true
				break
		_true("dropped mode at %s Hz is reported" % text, found)

	# Sorted by amplitude descending and normalised so the loudest is one —
	# the two properties the level-of-detail truncation depends on.
	_close("loudest mode normalised", model.modes[0].a, 1.0)
	for i in range(1, model.modes.size()):
		_true("mode %d is no louder than mode %d" % [i, i - 1],
				model.modes[i].a <= model.modes[i - 1].a + EPSILON)

	# At 44.1 kHz the ceiling drops to 19.845 kHz and takes another two modes.
	var narrower := ModalModel.load_from_file(_ceramic_path(), 44100.0)
	_true("ceramic model loads at 44.1 kHz", narrower.ok)
	_true("a lower rate voices fewer modes", narrower.modes.size() < model.modes.size())


func _test_strike_gain_fallback() -> void:
	var model := _ceramic()
	if model == null:
		return
	# No shipped model carries strike_positions; the fallback must be unit
	# gains of exactly the right length, or the amplitude loop reads past its
	# end and the panel silently shows a quieter object.
	_true("ceramic model has no strike data", not model.has_strike_data())
	var gains := model.gains_at(-1)
	_equal("fallback gain count", gains.size(), model.modes.size())
	for gain in gains:
		_close("fallback gain is unity", gain, 1.0)


## Every model in `models/`, at every rate the panel offers. The panel picks
## these up by discovery, so a model added later is a model the panel will try
## to draw — and each one carries its own material, which is what sets the
## clamp velocity and the axis.
func _test_every_shipped_model_loads() -> void:
	var directory := ProjectSettings.globalize_path("res://").path_join("../models")
	var files := DirAccess.get_files_at(directory)
	_true("models/ is not empty", files.size() > 0)

	for file in files:
		if not file.ends_with(".modal"):
			continue
		for rate in FitState.SAMPLE_RATES:
			var model := ModalModel.load_from_file(directory.path_join(file), rate)
			_true("%s loads at %d Hz" % [file, int(rate)], model.ok)
			if not model.ok:
				printerr("      " + model.error)
				continue
			_true("%s voices at least one mode at %d Hz" % [file, int(rate)],
					model.modes.size() > 0)
			_close("%s loudest mode is normalised at %d Hz" % [file, int(rate)],
					model.modes[0].a, 1.0)
			# Every mode kept must be inside the band the runtime will voice,
			# or the panel is drawing something the engine will drop.
			for mode in model.modes:
				_true("%s keeps only voiceable modes at %d Hz" % [file, int(rate)],
						mode.f >= ModalModel.MIN_FREQUENCY
						and mode.f <= ModalModel.NYQUIST_FRACTION * rate)
			# And the clamp velocity must be a real, positive figure — the
			# panel prints it as a claim about the material.
			_true("%s has a positive clamp velocity" % file,
					Excitation.clamp_velocity(model.material.contact_time_ref_ms) > 0.0)


# --- fixtures ----------------------------------------------------------------

func _ceramic_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../models/ceramic_mug.modal")


func _ceramic() -> ModalModel:
	var path := _ceramic_path()
	if not FileAccess.file_exists(path):
		_fail("models/ceramic_mug.modal not found at %s" % path)
		return null
	return ModalModel.load_from_file(path, RATE)


# --- harness -----------------------------------------------------------------

func _close(what: String, actual: float, expected: float, tolerance := 1e-9) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		# No %e in GDScript's formatter, so the delta goes through String.num.
		_fail("%s: expected %.12f, got %.12f (Δ %s)" % [
			what, expected, actual, String.num(absf(actual - expected), 14)])


func _equal(what: String, actual: int, expected: int) -> void:
	_checks += 1
	if actual != expected:
		_fail("%s: expected %d, got %d" % [what, expected, actual])


func _true(what: String, condition: bool) -> void:
	_checks += 1
	if not condition:
		_fail(what)


func _fail(message: String) -> void:
	_failures += 1
	printerr("FAIL  " + message)
