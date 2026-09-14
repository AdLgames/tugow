@tool
class_name SoundWords
extends RefCounted

## Saying what a model sounds like, in words, from its numbers.
##
## The analysis panel answers "what is in this file". This answers "what will I
## hear", which is the question someone choosing a sound for a crate or a
## bottle is actually asking — and it is not one a table of frequencies and
## decay constants answers quickly.
##
## Every word here is derived from the model rather than written per preset.
## Hand-authored blurbs would go stale the moment a preset is tweaked, and they
## would say nothing at all about a model the user fitted themselves — which is
## most of them, once the fitting tool is doing its job.

## Pitch, from the loudest mode. Anchored musically rather than arbitrarily:
## the first boundary is around middle C, and each one after is roughly an
## octave and a half. Calibrated against the three shipped models — a steel
## pipe at 620 Hz should read "low" and a mug at 1245 Hz "mid", which is how
## anyone describing them out loud would put it.
const PITCH_BANDS := [
	[250.0, "deep"],
	[700.0, "low"],
	[2000.0, "mid"],
	[5000.0, "high"],
	[INF, "very high"],
]

## How long it rings, from the longest decay the model carries. The upper
## bands are spread wider than they look like they need to be because the
## shipped models cluster there — ceramic 1.4 s, glass 2.6, steel 5.4 — and
## bands that called all three "very long" would describe nothing.
const RING_BANDS := [
	[0.15, "dead"],
	[0.50, "short"],
	[1.50, "ringing"],
	[3.00, "long"],
	[6.00, "very long"],
	[INF, "endless"],
]

## Brightness as the spectral centroid in octaves above the fundamental. A
## ratio rather than an absolute frequency, because a small bright object and a
## large bright object are the same kind of bright.
const BRIGHTNESS_BANDS := [
	[0.6, "dark"],
	[1.3, "warm"],
	[2.2, "bright"],
	[INF, "glassy"],
]


static func _band(bands: Array, value: float) -> String:
	for entry in bands:
		if value < float(entry[0]):
			return str(entry[1])
	return str(bands[bands.size() - 1][1])


## The loudest mode — what you hear as the pitch of the object.
static func fundamental(model: ModalModel) -> float:
	if model == null or model.modes.is_empty():
		return 0.0
	# Modes are sorted loudest first by the loader, so this is mode 0. Taking
	# the lowest frequency instead would name a mode nobody hears as the pitch.
	return model.modes[0].f


static func longest_decay(model: ModalModel) -> float:
	if model == null:
		return 0.0
	var longest := 0.0
	for mode in model.modes:
		longest = maxf(longest, mode.tau)
	return longest


## Octaves between the fundamental and the spectral centroid at this velocity.
static func brightness_octaves(model: ModalModel, centroid: float) -> float:
	var root := fundamental(model)
	if root <= 0.0 or centroid <= 0.0:
		return 0.0
	return log(centroid / root) / log(2.0)


static func pitch_word(model: ModalModel) -> String:
	return _band(PITCH_BANDS, fundamental(model))


static func ring_word(model: ModalModel) -> String:
	return _band(RING_BANDS, longest_decay(model))


static func brightness_word(model: ModalModel, centroid: float) -> String:
	return _band(BRIGHTNESS_BANDS, brightness_octaves(model, centroid))


## The one-line summary under a preset's name: "low · ringing · warm".
static func summary(model: ModalModel, centroid: float) -> String:
	if model == null or not model.ok:
		return ""
	return " · ".join(PackedStringArray([
		pitch_word(model), ring_word(model), brightness_word(model, centroid),
	]))


## A longer sentence, for the selected sound. Reads as a description of an
## object rather than a readout, but every clause is a measured number.
static func sentence(model: ModalModel, centroid: float) -> String:
	if model == null or not model.ok:
		return ""
	var root := fundamental(model)
	var ring := longest_decay(model)
	var ring_phrase := "stops almost at once"
	if ring >= 1.5:
		ring_phrase = "rings on for about %.1f seconds" % ring
	elif ring >= 0.5:
		ring_phrase = "rings for about %.1f seconds" % ring
	elif ring >= 0.15:
		ring_phrase = "is a short knock"

	return "A %s %s sound at about %d Hz that %s." % [
		brightness_word(model, centroid), pitch_word(model), roundi(root), ring_phrase]


## How much brightness the hit fader actually buys on this object, in octaves
## of spectral centroid across the fader's range.
static func velocity_response(low_centroid: float, high_centroid: float) -> float:
	if low_centroid <= 0.0 or high_centroid <= 0.0:
		return 0.0
	return log(high_centroid / low_centroid) / log(2.0)


## Below this, hitting the object harder is only turning it up.
const FLAT_RESPONSE_OCTAVES := 0.08


static func is_flat(low_centroid: float, high_centroid: float) -> bool:
	return velocity_response(low_centroid, high_centroid) < FLAT_RESPONSE_OCTAVES


## What changing the hit strength will do to this particular object, in plain
## terms — and when the answer is "nothing", why.
##
## This is the panel's most important sentence. An object whose timbre does not
## move with velocity is the exact failure the engine exists to avoid: six
## clips of glass at different volumes, which is where the illusion collapses.
## It is also easy to cause by accident from the Sounds screen, because a very
## hard striker puts contact time on its 0.05 ms floor and pins it there at
## every velocity above a walking pace. Saying so, with the number, is the
## difference between a control that feels broken and one that is explaining
## a real limit.
static func velocity_hint(model: ModalModel, low_centroid: float, high_centroid: float,
		clamp_velocity: float, fader_max: float) -> String:
	if model == null or not model.ok or low_centroid <= 0.0:
		return ""
	var octaves := velocity_response(low_centroid, high_centroid)

	if octaves < FLAT_RESPONSE_OCTAVES:
		if clamp_velocity <= fader_max:
			return ("This object stops getting brighter above %.1f m/s — the striker is hard "
					+ "enough that contact time is already at its 0.05 ms floor. Harder hits "
					+ "will only be louder. Soften the striker to get the brightness back.") % clamp_velocity
		return "Hitting this harder makes it louder but barely brighter."

	if clamp_velocity <= fader_max:
		return ("Hitting this harder brightens it, up to %.1f m/s — past that the contact time "
				+ "is at its floor and it only gets louder.") % clamp_velocity
	if octaves < 0.25:
		return "Hitting this harder brightens it a little, as well as making it louder."
	return "Hitting this harder brightens it noticeably, not just louder."
