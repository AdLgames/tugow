@tool
class_name ModelTweak
extends RefCounted

## Turning a preset into your own object.
##
## Three controls, and each one is a real physical quantity rather than a
## effect knob:
##
## - **Size** scales every frequency. Geometric scaling is what this is: make a
##   mug twice as big and, for a given mode shape, it rings an octave lower.
##   The relative spacing of the modes — which is what makes it sound ceramic
##   rather than metal — is untouched.
## - **Ring** scales every decay time. This is the material's internal damping.
##   A more damped ceramic is still ceramic; it just stops sooner.
## - **Striker** is `material.contact_time_ref_ms`, which is already in the
##   format. It is what you hit the object *with*: a pen cap is a short contact
##   and a wide excitation, a rubber mallet is a long one.
##
## There is deliberately no brightness control. Brightness is the thing the
## engine is supposed to produce rather than be told — it falls out of contact
## time, which is striker and velocity. A knob that reached in and lifted the
## high modes directly would be the sample-based approximation this project
## exists to avoid, and it would make the model lie about every velocity other
## than the one it was set at.

## Frequency multiplier. Below 1 the object is bigger and rings lower.
const SIZE_MIN := 0.5
const SIZE_MAX := 2.0

## Decay multiplier.
const RING_MIN := 0.25
const RING_MAX := 4.0

## Reference contact time, milliseconds. The low end is a hard, small striker;
## the high end a soft one.
const STRIKER_MIN := 0.03
const STRIKER_MAX := 1.00


## Applies the three controls to a loaded model, returning a new one.
##
## Everything the file format requires is enforced here rather than left for
## the loader to reject later: modes pushed outside the usable band are dropped
## with the loader's own wording, and decay times are clamped into the range
## `model.h` accepts. A tweak that produced a file the runtime refuses to open
## would be a tweak the panel should not have offered.
static func apply(source: ModalModel, size: float, ring: float, striker_ms: float,
		sample_rate: float) -> ModalModel:
	var out := ModalModel.new()
	out.name = source.name
	out.source = source.source
	out.fit_quality = source.fit_quality
	out.modes_in_file = source.modes_in_file
	# The loader's own warnings travel with the model. A mode the file lost to
	# the sample rate is still lost after a tweak, and dropping that from the
	# report would make an untouched object claim every mode is voiced.
	out.warnings = source.warnings.duplicate()
	out.material.contact_time_ref_ms = clampf(striker_ms, STRIKER_MIN, STRIKER_MAX)
	out.material.roughness = source.material.roughness
	out.material.rolling_gain = source.material.rolling_gain
	out.material.scrape_gain = source.material.scrape_gain

	var scale := clampf(size, SIZE_MIN, SIZE_MAX)
	var stretch := clampf(ring, RING_MIN, RING_MAX)
	var ceiling := ModalModel.NYQUIST_FRACTION * sample_rate
	var clamped_decay := false

	# Positional, exactly as in the loader: a dropped mode takes its strike
	# gain with it, and the survivors must stay lined up.
	var kept: Array[bool] = []
	kept.resize(source.modes.size())
	kept.fill(false)

	for i in source.modes.size():
		var mode: ModalModel.Mode = source.modes[i]
		var frequency := mode.f * scale
		if frequency < ModalModel.MIN_FREQUENCY or frequency > ceiling:
			out.tweak_warnings.append("dropped mode %d at %s Hz: outside %s to %s Hz at this size" % [
				i, ModalModel._say(frequency), ModalModel._say(ModalModel.MIN_FREQUENCY),
				ModalModel._say(ceiling)])
			continue
		var tau := mode.tau * stretch
		var limited := clampf(tau, ModalModel.MIN_TAU, ModalModel.MAX_TAU)
		if not is_equal_approx(limited, tau):
			clamped_decay = true
		kept[i] = true
		out.modes.append(ModalModel.Mode.new(frequency, limited, mode.a))

	if clamped_decay:
		out.tweak_warnings.append("some decay times hit the %s to %s s limit the format allows" % [
			ModalModel._say(ModalModel.MIN_TAU), ModalModel._say(ModalModel.MAX_TAU)])

	for position in source.strike_positions:
		var moved := ModalModel.StrikePosition.new()
		moved.u = position.u
		moved.v = position.v
		moved.name = position.name
		for i in kept.size():
			if kept[i] and i < position.gains.size():
				moved.gains.append(position.gains[i])
		out.strike_positions.append(moved)

	if out.modes.is_empty():
		out.error = "no modes survive at this size"
		return out
	out.ok = true
	return out


## Writes a model as a `.modal` file.
##
## The format is the one `core/src/model.cpp` reads, and the numbers go out at
## enough precision to survive the round trip — the fitter recovers frequencies
## to 0.1 Hz and decays to three decimals, and a writer that rounded harder
## would throw away accuracy the fit worked for.
static func to_json(model: ModalModel, name: String, source_note: String) -> String:
	var modes := []
	for mode in model.modes:
		modes.append({
			"f": snappedf(mode.f, 0.0001),
			"tau": snappedf(mode.tau, 0.000001),
			"a": snappedf(mode.a, 0.000001),
		})

	var document := {
		"format": "modal",
		"version": 1,
		"name": name,
		"source": source_note,
		"fit_quality": model.fit_quality,
		"modes": modes,
	}

	if not model.strike_positions.is_empty():
		var positions := []
		for position in model.strike_positions:
			var gains := []
			for gain in position.gains:
				gains.append(snappedf(gain, 0.000001))
			var entry := {"u": position.u, "v": position.v, "gains": gains}
			if not position.name.is_empty():
				entry["name"] = position.name
			positions.append(entry)
		document["strike_positions"] = positions

	document["material"] = {
		"contact_time_ref_ms": snappedf(model.material.contact_time_ref_ms, 0.0001),
		"roughness": model.material.roughness,
		"rolling_gain": model.material.rolling_gain,
		"scrape_gain": model.material.scrape_gain,
	}
	return JSON.stringify(document, "  ") + "\n"


static func save(model: ModalModel, path: String, name: String, source_note: String) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not write %s" % path
	file.store_string(to_json(model, name, source_note))
	file.close()
	return ""


## How far the tweak has moved the object from its preset, as a sentence.
## Empty when nothing has been changed.
static func describe(size: float, ring: float, striker_ms: float, preset_striker_ms: float) -> String:
	var parts: PackedStringArray = []
	if not is_equal_approx(size, 1.0):
		# A frequency ratio is a pitch shift; semitones is how anyone who works
		# with sound actually thinks about it.
		var semitones := 12.0 * log(size) / log(2.0)
		parts.append("%+.1f semitones" % semitones)
	if not is_equal_approx(ring, 1.0):
		parts.append("%.2f× decay" % ring)
	if not is_equal_approx(striker_ms, preset_striker_ms):
		parts.append("%.2f ms striker" % striker_ms)
	return " · ".join(parts)
