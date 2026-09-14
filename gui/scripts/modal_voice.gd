@tool
class_name ModalVoice
extends RefCounted

## Actually making the sound.
##
## A port of `core/src/bank.cpp` and the render path in `harness/src/main.cpp`:
## one two-pole resonator per mode, driven by the contact pulse, summed and
## peak-normalised. The plots elsewhere in this panel are computed from the
## same model, but they are drawn from the closed-form `a·e^(−t/τ)·sin(2πft)`.
## This is the recursion the engine will actually run in its audio callback,
## which is the only thing that settles whether a fit sounds right.
##
## **The state is float32 on purpose.** `Bank` holds `float y1[]`/`y2[]`, and
## for a long decay `r` sits within a few parts per million of 1.0 — so the
## difference between accumulating in float and in double is audible over a
## second and a half of ring, and it is the float answer the runtime produces.
## GDScript has only doubles, so the state lives in `PackedFloat32Array`, where
## every store truncates exactly as the C++ does.
##
## Not real-time. This renders a whole strike into a buffer and hands it to an
## `AudioStreamPlayer`; the engine's version runs block by block under the
## no-allocation rules in `bank.h`. For auditioning a fit, a buffer is the
## right shape and is a few milliseconds of work.

## `kMaxModes` from `bank.h` — the cap a single voice can hold.
const MAX_MODES := 48

## What `modal-render` uses, so an audition and a rendered WAV match.
const DEFAULT_SECONDS := 2.0
const DEFAULT_GAIN := 0.5

## The harness's stand-in for a physics engine: a plausible impulse for a small
## object at this speed. The point is not the absolute level — every render is
## peak-normalised anyway — but that the same J at different velocities still
## changes the timbre, because the contact time does.
const IMPULSE_PER_VELOCITY := 0.1


## Renders one strike. Returns mono samples in −1..1.
static func render(model: ModalModel, velocity: float, sample_rate: float,
		seconds := DEFAULT_SECONDS, gain := DEFAULT_GAIN, gains: PackedFloat64Array = [],
		max_modes := MAX_MODES) -> PackedFloat32Array:
	var frames := int(seconds * sample_rate)
	var out := PackedFloat32Array()
	if model == null or not model.ok or frames <= 0:
		return out
	out.resize(frames)

	var count := mini(mini(max_modes, MAX_MODES), model.modes.size())

	# Coefficients, from `coefficients_for` in model.cpp. Computed in double
	# and narrowed once: r is within a few parts per million of 1.0 for a long
	# decay, and squaring it in float32 loses the difference that makes the
	# decay right.
	var b0 := PackedFloat32Array()
	var a1 := PackedFloat32Array()
	var a2 := PackedFloat32Array()
	b0.resize(count)
	a1.resize(count)
	a2.resize(count)
	for k in count:
		var mode: ModalModel.Mode = model.modes[k]
		var amplitude := mode.a
		if k < gains.size():
			amplitude *= gains[k]
		var omega := TAU * mode.f / sample_rate
		var r := exp(-1.0 / (mode.tau * sample_rate))
		a1[k] = 2.0 * r * cos(omega)
		a2[k] = -(r * r)
		# b0 = a·sin(omega) makes the impulse response peak at a, which keeps
		# the relative level of the modes the same as in the file.
		b0[k] = amplitude * sin(omega)

	var y1 := PackedFloat32Array()
	var y2 := PackedFloat32Array()
	y1.resize(count)
	y2.resize(count)

	var impulse := IMPULSE_PER_VELOCITY * velocity
	var pulse := Excitation.make_pulse(impulse, model.material.contact_time_ref_ms,
			velocity, sample_rate)

	# The excitation, once. It is a handful of non-zero samples followed by
	# silence, so it costs nothing to keep and saves a branch per sample.
	var excitation := PackedFloat32Array()
	excitation.resize(pulse.frames)
	for i in pulse.frames:
		excitation[i] = pulse.sample(i)

	# One mode at a time over the whole buffer, rather than all modes at each
	# sample. `bank_process` does it the other way because it is filling a
	# block in an audio callback and wants one pass over the output; here the
	# whole buffer exists already, and hoisting a mode's three coefficients and
	# two state variables into locals takes roughly two thirds off the cost —
	# in GDScript the array indexing *is* the work.
	# The pulse is a handful of samples — seven at 2 m/s on ceramic — against a
	# buffer of ninety-six thousand. Running the driven form over the whole
	# thing spends the entire render multiplying by zero, so the two phases are
	# split and the long one drops the input term altogether.
	var driven := mini(pulse.frames, frames)
	for k in count:
		var mode_b0 := b0[k]
		var mode_a1 := a1[k]
		var mode_a2 := a2[k]
		var s1 := 0.0
		var s2 := 0.0
		for i in driven:
			var y := mode_b0 * excitation[i] + mode_a1 * s1 + mode_a2 * s2
			s2 = s1
			s1 = y
			out[i] = out[i] + y
		for i in range(driven, frames):
			var y := mode_a1 * s1 + mode_a2 * s2
			s2 = s1
			s1 = y
			out[i] = out[i] + y
		y1[k] = s1
		y2[k] = s2

	var peak := 0.0
	for i in frames:
		peak = maxf(peak, absf(out[i]))

	# Peak-normalised, exactly as the harness does it, so two velocities are
	# compared on timbre rather than on loudness.
	var scale := gain / peak if peak > 0.0 else 0.0
	for i in frames:
		out[i] = out[i] * scale
	return out


## Is the bank still producing numbers? One bad coefficient otherwise poisons
## the buffer and the report is never reproducible. `bank.h` has the same check
## for the same reason.
static func is_finite(samples: PackedFloat32Array) -> bool:
	for sample in samples:
		if not is_finite_value(sample):
			return false
	return true


static func is_finite_value(value: float) -> bool:
	return not (is_nan(value) or is_inf(value))


## 16-bit PCM, the way `harness/src/wav.h` writes it: clamped to −1..1 then
## scaled by 32767 and truncated toward zero. Matching the truncation matters
## only for comparing against a golden WAV, but it costs nothing to match.
static func to_pcm16(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var limited := clampf(samples[i], -1.0, 1.0)
		var value := int(limited * 32767.0)
		bytes.encode_s16(i * 2, value)
	return bytes


## A playable stream for one strike.
static func to_stream(samples: PackedFloat32Array, sample_rate: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_rate)
	stream.stereo = false
	stream.data = to_pcm16(samples)
	return stream
