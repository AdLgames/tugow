@tool
class_name Excitation
extends RefCounted

## What the resonators are struck with.
##
## A GDScript port of `core/include/modal/excitation.h` and its implementation.
## The panel's whole argument — that a harder hit is a brighter hit, and that
## it stops getting brighter past about 10 m/s — is this file. If it drifts
## from the C++, the GUI starts telling a story the engine does not.
##
## `excitation_gain` has no counterpart in the core. The engine never needs the
## pulse's spectrum, because it convolves in the time domain; the panel needs
## it to draw how much of each mode a given strike actually reaches.

const MIN_CONTACT_SECONDS := 0.05e-3
const MAX_CONTACT_SECONDS := 20.0e-3
const REFERENCE_VELOCITY := 1.0  ## m/s, where t_ref is measured

## The narrowest the window may be. Below one sample the centre lands on a zero
## of the window and the pulse vanishes.
const MIN_PULSE_WIDTH := 1.0


## A Hann pulse whose samples sum to `impulse`. Mirrors `modal::Pulse`.
class Pulse extends RefCounted:
	var impulse := 1.0
	var width := 1.0  ## samples, fractional
	var scale := 1.0  ## impulse / sum of the window
	var frames := 1   ## samples to render, ceil(width)

	func sample(n: int) -> float:
		if n < 0 or n >= frames:
			return 0.0
		return Excitation.window_at(n, width) * scale


## Contact duration at an impact velocity, from the material's reference.
##
## Hertz gives t_c proportional to v^(-1/5). A standing-still contact has no
## impact velocity to speak of, so the low end is clamped rather than allowed
## to divide by zero.
static func contact_seconds(contact_time_ref_ms: float, velocity: float) -> float:
	var reference := contact_time_ref_ms * 1e-3
	var safe_velocity := maxf(velocity, 1e-4)
	var scaled := reference * pow(REFERENCE_VELOCITY / safe_velocity, 0.2)
	return clampf(scaled, MIN_CONTACT_SECONDS, MAX_CONTACT_SECONDS)


## Hann, evaluated at the centre of sample n.
##
## Centre sampling is what lets the width be fractional: at a width of one
## sample the single centre lands on the peak of the window rather than on its
## leading zero.
static func window_at(n: int, width: float) -> float:
	var position := (float(n) + 0.5) / width
	if position <= 0.0 or position >= 1.0:
		return 0.0
	return 0.5 * (1.0 - cos(TAU * position))


static func make_pulse(impulse: float, contact_time_ref_ms: float, velocity: float,
		sample_rate: float) -> Pulse:
	var pulse := Pulse.new()
	pulse.impulse = impulse
	var seconds := contact_seconds(contact_time_ref_ms, velocity)
	pulse.width = maxf(MIN_PULSE_WIDTH, seconds * sample_rate)
	pulse.frames = maxi(1, int(ceil(pulse.width)))

	var total := 0.0
	for n in pulse.frames:
		total += window_at(n, pulse.width)
	# A width of exactly one sample puts its only centre at the window's peak,
	# so the sum is never zero, but a guard costs nothing and a silent impact
	# is a bug nobody can find.
	pulse.scale = impulse / total if total > 0.0 else impulse
	return pulse


## |DTFT| of the pulse at `frequency` — how much of a mode at that frequency
## this strike actually excites.
##
## Because the pulse is normalised to sum to its impulse, this is exactly
## `impulse` at DC and falls away above it. The first null sits near 1/t_c,
## which is the whole reason a shorter contact reaches higher modes: halve the
## contact time and the first null doubles.
##
## Direct evaluation rather than an FFT. The pulse is a handful of samples
## wide at any velocity a game will produce — eight at 0.5 m/s on ceramic —
## so a transform would cost more to set up than this costs to run.
static func excitation_gain(pulse: Pulse, frequency: float, sample_rate: float) -> float:
	var re := 0.0
	var im := 0.0
	var step := TAU * frequency / sample_rate
	for n in pulse.frames:
		var value := pulse.sample(n)
		if value == 0.0:
			continue
		var theta := step * float(n)
		re += value * cos(theta)
		im -= value * sin(theta)
	return sqrt(re * re + im * im)


## Per-mode amplitude for one strike: the model's own amplitude, scaled by the
## strike position's gain, scaled by how much of that mode the contact pulse
## reaches.
static func mode_amplitudes(model: ModalModel, velocity: float, gains: PackedFloat64Array,
		sample_rate: float) -> PackedFloat64Array:
	var pulse := make_pulse(1.0, model.material.contact_time_ref_ms, velocity, sample_rate)
	var out := PackedFloat64Array()
	out.resize(model.modes.size())
	for i in model.modes.size():
		var gain := gains[i] if i < gains.size() else 1.0
		out[i] = model.modes[i].a * gain * excitation_gain(pulse, model.modes[i].f, sample_rate)
	return out


## The impact velocity at which contact time hits its lower clamp, past which
## an impact stops getting brighter and only gets louder.
##
## Inverting t_ref · v^(−1/5) = t_min gives v = (t_ref / t_min)^5, and the
## fifth power makes this enormously material-dependent: steel clamps at
## 10.5 m/s, glass at 80, ceramic not until 243. The repository README quotes
## the steel figure, which is the one a developer meets in practice — but it is
## a property of the material, not of the engine, so the panel derives it from
## whichever model is loaded rather than printing a constant.
static func clamp_velocity(contact_time_ref_ms: float) -> float:
	var reference := contact_time_ref_ms * 1e-3
	if reference <= MIN_CONTACT_SECONDS:
		return 0.0
	return pow(reference / MIN_CONTACT_SECONDS, 5.0)


## Amplitude-weighted mean frequency — the number the week 1 gate is measured
## in. See the table in the repository README.
static func spectral_centroid(model: ModalModel, amplitudes: PackedFloat64Array) -> float:
	var numerator := 0.0
	var denominator := 0.0
	for i in model.modes.size():
		if i >= amplitudes.size():
			break
		numerator += model.modes[i].f * amplitudes[i]
		denominator += amplitudes[i]
	return numerator / denominator if denominator > 0.0 else 0.0
