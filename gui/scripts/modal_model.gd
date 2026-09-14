@tool
class_name ModalModel
extends RefCounted

## A `.modal` file, loaded the way the runtime loads it.
##
## This is a GDScript port of `core/src/model.cpp`, and it is deliberately a
## port rather than an approximation. A GUI that shows you a model the loader
## would reject, or shows you fourteen modes where the runtime will only voice
## eleven, is worse than no GUI: it tells you the object sounds like something
## it will never sound like. So the same modes get dropped here, with the same
## warnings, in the same order, normalised the same way.
##
## The one thing it does not do is compute biquad coefficients — nothing here
## renders audio.

const MAX_MODES_IN_FILE := 256
const MIN_FREQUENCY := 20.0
const NYQUIST_FRACTION := 0.45
const MIN_TAU := 0.001
const MAX_TAU := 10.0


## One damped sinusoid. Mirrors `modal::Mode`.
class Mode extends RefCounted:
	var f := 0.0    ## Hz
	var tau := 0.0  ## 1/e decay time, seconds
	var a := 0.0    ## linear amplitude, loudest normalised to 1

	func _init(freq := 0.0, decay := 0.0, amp := 0.0) -> void:
		f = freq
		tau = decay
		a = amp


## A strike position and the per-mode gains measured there.
class StrikePosition extends RefCounted:
	var u := 0.0
	var v := 0.0
	var gains: PackedFloat64Array = PackedFloat64Array()
	var name := ""  ## not in the format; the GUI labels positions for display


## Per-material excitation constants. Mirrors `modal::Material`, but not named
## for it: `Material` is a native Godot class and an inner class may not hide
## one.
class MaterialConstants extends RefCounted:
	var contact_time_ref_ms := 0.15
	var roughness := 0.3
	var rolling_gain := 0.6
	var scrape_gain := 1.0


var name := ""
var source := ""
var fit_quality := 0.0
var modes: Array[Mode] = []
var strike_positions: Array[StrikePosition] = []
var material := MaterialConstants.new()

## Set by `load_from_string`. `error` is non-empty when the load failed;
## `warnings` carries the non-fatal ones, chiefly dropped modes.
var ok := false
var error := ""
var warnings: PackedStringArray = PackedStringArray()

## Warnings caused by the Sounds screen's controls rather than by the file.
##
## Kept apart from `warnings` because the two belong on different screens. A
## mode the sample rate cannot voice is a property of the file and an Analysis
## concern; a mode lost because the user shrank the object is a consequence of
## something they just did, and the simple screen has to say so — in its own
## language, not the loader's.
var tweak_warnings: PackedStringArray = PackedStringArray()

## How many modes the file held before the band filter ran. The difference
## between this and `modes.size()` is what the sample rate cost you, and the
## panel reports it because it is the single most surprising thing about
## loading a 48 kHz model at 44.1 kHz.
var modes_in_file := 0


static func load_from_file(path: String, sample_rate: float) -> ModalModel:
	var model := ModalModel.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		model.error = "could not open %s" % path
		return model
	var text := file.get_as_text()
	file.close()
	return load_from_string(text, sample_rate)


static func load_from_string(text: String, sample_rate: float) -> ModalModel:
	var model := ModalModel.new()

	var json := JSON.new()
	if json.parse(text) != OK:
		model.error = "not valid JSON: %s (line %d)" % [json.get_error_message(), json.get_error_line()]
		return model
	var root: Variant = json.data
	if typeof(root) != TYPE_DICTIONARY:
		model.error = "the top level is not an object"
		return model

	if root.get("format", "") != "modal":
		model.error = "not a modal file: \"format\" is not \"modal\""
		return model
	if float(root.get("version", 0.0)) != 1.0:
		model.error = "unsupported version %s" % _say(float(root.get("version", 0.0)))
		return model
	if sample_rate <= 0.0:
		model.error = "sample rate must be positive"
		return model

	model.name = str(root.get("name", ""))
	model.source = str(root.get("source", ""))
	model.fit_quality = float(root.get("fit_quality", 0.0))

	# 1. modes non-empty, length <= 256.
	var raw_modes: Variant = root.get("modes", null)
	if typeof(raw_modes) != TYPE_ARRAY or (raw_modes as Array).is_empty():
		model.error = "\"modes\" is missing or empty"
		return model
	var entries: Array = raw_modes
	if entries.size() > MAX_MODES_IN_FILE:
		model.error = "too many modes: %d, the limit is %d" % [entries.size(), MAX_MODES_IN_FILE]
		return model
	model.modes_in_file = entries.size()

	# A mode is kept or dropped, but the file's own indexing has to survive
	# either way — the strike gains are positional.
	var highest := NYQUIST_FRACTION * sample_rate
	var kept: Array[bool] = []
	kept.resize(entries.size())
	kept.fill(false)

	for i in entries.size():
		var entry: Variant = entries[i]
		if typeof(entry) != TYPE_DICTIONARY:
			model.error = "mode %d is missing f, tau or a" % i
			return model
		var dict: Dictionary = entry
		if not (_is_number(dict.get("f")) and _is_number(dict.get("tau")) and _is_number(dict.get("a"))):
			model.error = "mode %d is missing f, tau or a" % i
			return model
		var mode := Mode.new(float(dict["f"]), float(dict["tau"]), float(dict["a"]))

		# 4. tau in range. Out of range is an error: it is a broken file rather
		#    than a mode this sample rate cannot reach.
		if not (mode.tau >= MIN_TAU and mode.tau <= MAX_TAU):
			model.error = "mode %d has tau %s, outside %s to %s" % [
				i, _say(mode.tau), _say(MIN_TAU), _say(MAX_TAU)]
			return model
		# 5. amplitude positive and no greater than 1.
		if not (mode.a > 0.0 and mode.a <= 1.0):
			model.error = "mode %d has amplitude %s, outside 0 to 1" % [i, _say(mode.a)]
			return model
		# 3. frequency inside the usable band — a warning, not an error, so a
		#    model fitted at 48 kHz still loads at 44.1 kHz.
		if mode.f < MIN_FREQUENCY or mode.f > highest:
			model.warnings.append("dropped mode %d at %s Hz: outside %s to %s Hz at this sample rate" % [
				i, _say(mode.f), _say(MIN_FREQUENCY), _say(highest)])
			continue
		kept[i] = true
		model.modes.append(mode)

	if model.modes.is_empty():
		model.error = "every mode was outside the usable band at %s Hz" % _say(sample_rate)
		return model

	# 6 and 7. Strike gains are per mode and positional, so they are filtered
	#          by the same decision the modes were.
	if root.has("strike_positions"):
		var raw_positions: Variant = root["strike_positions"]
		if typeof(raw_positions) != TYPE_ARRAY:
			model.error = "\"strike_positions\" is not an array"
			return model
		var positions: Array = raw_positions
		for p in positions.size():
			var entry: Variant = positions[p]
			if typeof(entry) != TYPE_DICTIONARY:
				model.error = "strike position %d is missing u or v" % p
				return model
			var dict: Dictionary = entry
			if not (_is_number(dict.get("u")) and _is_number(dict.get("v"))):
				model.error = "strike position %d is missing u or v" % p
				return model
			var position := StrikePosition.new()
			position.u = float(dict["u"])
			position.v = float(dict["v"])
			if position.u < 0.0 or position.u > 1.0 or position.v < 0.0 or position.v > 1.0:
				model.error = "strike position %d is outside the unit square" % p
				return model
			# Not part of the format, but a position with a name reads far
			# better on the strike map than "(0.50, 0.08)".
			position.name = str(dict.get("name", ""))

			var raw_gains: Variant = dict.get("gains", null)
			if typeof(raw_gains) != TYPE_ARRAY or (raw_gains as Array).size() != entries.size():
				var count := 0
				if typeof(raw_gains) == TYPE_ARRAY:
					count = (raw_gains as Array).size()
				model.error = "strike position %d has %d gains for %d modes" % [p, count, entries.size()]
				return model
			var gains: Array = raw_gains
			for i in gains.size():
				if not _is_number(gains[i]):
					model.error = "strike position %d has a gain that is not a number" % p
					return model
				if kept[i]:
					position.gains.append(float(gains[i]))
			model.strike_positions.append(position)

	if root.has("material"):
		var raw_material: Variant = root["material"]
		if typeof(raw_material) == TYPE_DICTIONARY:
			var dict: Dictionary = raw_material
			var mat := model.material
			if _is_number(dict.get("contact_time_ref_ms")):
				mat.contact_time_ref_ms = float(dict["contact_time_ref_ms"])
			if _is_number(dict.get("roughness")):
				mat.roughness = float(dict["roughness"])
			if _is_number(dict.get("rolling_gain")):
				mat.rolling_gain = float(dict["rolling_gain"])
			if _is_number(dict.get("scrape_gain")):
				mat.scrape_gain = float(dict["scrape_gain"])
			if mat.contact_time_ref_ms <= 0.0:
				model.error = "contact_time_ref_ms must be positive"
				return model

	# 2. Sorted by amplitude descending. This is what makes the level-of-detail
	#    truncation safe: dropping the tail always drops the quietest. The
	#    strike gains are reordered with it or they stop lining up.
	var order: Array[int] = []
	for i in model.modes.size():
		order.append(i)
	# `sort_custom` is not stable, so ties are broken on the original index to
	# match the `std::stable_sort` the loader uses.
	var by_amplitude := func(x: int, y: int) -> bool:
		var ax := model.modes[x].a
		var ay := model.modes[y].a
		if ax == ay:
			return x < y
		return ax > ay
	order.sort_custom(by_amplitude)

	var already_sorted := true
	for i in order.size():
		if order[i] != i:
			already_sorted = false
			break
	if not already_sorted:
		model.warnings.append("modes were not sorted by amplitude; sorted on load")
		var sorted: Array[Mode] = []
		for i in order:
			sorted.append(model.modes[i])
		model.modes = sorted
		for position in model.strike_positions:
			var gains := PackedFloat64Array()
			for i in order:
				gains.append(position.gains[i])
			position.gains = gains

	# 5, continued. Normalise so the loudest mode is exactly 1.
	var loudest := model.modes[0].a
	if loudest <= 0.0:
		model.error = "every mode has zero amplitude"
		return model
	if absf(loudest - 1.0) > 1e-9:
		for mode in model.modes:
			mode.a /= loudest

	model.ok = true
	return model


## Gains at a strike position, or all-ones when the model carries none.
##
## No model in `models/` ships `strike_positions` — the format reserves them
## and the loader validates them, but nothing writes them yet. Returning unit
## gains means the panel shows the object struck everywhere at once, which is
## the honest picture rather than an invented one.
func gains_at(index: int) -> PackedFloat64Array:
	if index < 0 or index >= strike_positions.size():
		var flat := PackedFloat64Array()
		flat.resize(modes.size())
		flat.fill(1.0)
		return flat
	return strike_positions[index].gains


func has_strike_data() -> bool:
	return not strike_positions.is_empty()


## The modes the runtime will actually voice. `bank.h` caps a voice at
## `kMaxModes` = 48 and loads quietest-first so the tail is what gets dropped.
const MAX_VOICED_MODES := 48


func voiced_mode_count() -> int:
	return mini(modes.size(), MAX_VOICED_MODES)


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


## Matches the loader's `say()`, which is `ostringstream << double`: trailing
## zeros trimmed, so 21600.0 reads as "21600" and 0.001 as "0.001". GDScript's
## `%` formatter has no `%g`, so the trimming is done here.
static func _say(value: float) -> String:
	var text := String.num(value, 6)
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text if not text.is_empty() else "0"
