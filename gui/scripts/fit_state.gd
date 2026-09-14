@tool
class_name FitState
extends RefCounted

## Everything the panel is currently showing, and the one place it is computed.
##
## Four controls drive this — the velocity slider, the strike map, the mode
## solo and the stage stepper — and every plot reads from it. Amplitudes are
## recomputed on change rather than per-frame or per-view: at eight to fifty
## modes and a pulse a handful of samples wide the whole recomputation is
## microseconds, and having one cached answer means the mode table's bar and
## the spectrogram's band can never disagree.

signal changed

## Analysis constants from `fitter/src/fitter.h` — shown in the header, and
## used to place the resolution limit on the peaks view.
const WINDOW := 4096
const HOP := 512
const ZERO_PAD := 2
const PEAK_FLOOR_DB := -65.0
const ONSET_FLOOR_DB := -40.0
const MIN_R_SQUARED := 0.80
const MIN_PEAK_SEPARATION_BINS := 4.0

## Sample rates worth offering. The point of the switch is that it visibly
## changes which modes survive the load — a 48 kHz model opened at 44.1 kHz
## loses everything above 19.8 kHz, and the panel should show that rather than
## let a developer discover it in the game.
const SAMPLE_RATES: Array[float] = [48000.0, 44100.0, 96000.0]

enum Stage { ONSET, PEAKS, TRACKING, DECAY, VERIFY }

const STAGE_LABELS := {
	Stage.ONSET: "1 · ONSET",
	Stage.PEAKS: "2 · PEAKS",
	Stage.TRACKING: "3 · TRACKING",
	Stage.DECAY: "4 · DECAY FIT",
	Stage.VERIFY: "5 · VERIFY",
}

const STAGE_TITLES := {
	Stage.ONSET: "Onset detection",
	Stage.PEAKS: "Peak picking · frame 2",
	Stage.TRACKING: "Mode tracking",
	Stage.DECAY: "Decay fitting",
	Stage.VERIFY: "Original · resynthesis · difference",
}

## Built from the thresholds above rather than written out, so a note can never
## quote a figure the panel is no longer using.
static func stage_note(stage: Stage) -> String:
	match stage:
		Stage.ONSET:
			return "first sample past the %.0f dBFS backoff" % ONSET_FLOOR_DB
		Stage.PEAKS:
			return "Blackman-Harris, sidelobes 92 dB down · floor %.0f dB" % PEAK_FLOOR_DB
		Stage.TRACKING:
			return "search anchored ±%d bins where the peak was found" % 2
		Stage.DECAY:
			return "log-magnitude regression per mode · reject R² < %.2f" % MIN_R_SQUARED
		_:
			return "resynthesis from the loaded model"

var model: ModalModel
var model_path := ""
var sample_rate := 48000.0

var velocity := 2.0
var stage: Stage = Stage.TRACKING
var solo := -1      ## index into `model.modes`, or -1 for all
var strike := -1    ## index into `model.strike_positions`, or -1 for none

## Cached, recomputed by `_recompute`.
var amplitudes := PackedFloat64Array()
var peak_amplitude := 1.0
var centroid := 0.0
var contact_ms := 0.0
var pulse: Excitation.Pulse


func load_model(path: String) -> bool:
	var loaded := ModalModel.load_from_file(path, sample_rate)
	model = loaded
	model_path = path
	# A model's own strike positions are the only ones there are; with none in
	# the file the map has nothing to select.
	strike = 0 if loaded.has_strike_data() else -1
	solo = -1
	_recompute()
	changed.emit()
	return loaded.ok


func set_sample_rate(rate: float) -> void:
	if is_equal_approx(rate, sample_rate):
		return
	sample_rate = rate
	# Reloading is not optional: which modes survive is decided at load, so a
	# rate change has to go back through the loader to be honest about it.
	if not model_path.is_empty():
		load_model(model_path)
	else:
		_recompute()
		changed.emit()


func set_velocity(value: float) -> void:
	if is_equal_approx(value, velocity):
		return
	velocity = value
	_recompute()
	changed.emit()


func set_stage(value: Stage) -> void:
	if value == stage:
		return
	stage = value
	changed.emit()


func toggle_solo(index: int) -> void:
	solo = -1 if solo == index else index
	changed.emit()


func clear_solo() -> void:
	if solo == -1:
		return
	solo = -1
	changed.emit()


func set_strike(index: int) -> void:
	if index == strike:
		return
	strike = index
	_recompute()
	changed.emit()


func is_loaded() -> bool:
	return model != null and model.ok


func is_visible_mode(index: int) -> bool:
	return solo == -1 or solo == index


func mode_count() -> int:
	return model.modes.size() if is_loaded() else 0


## Normalised amplitude, 0 to 1, of one mode at the current velocity and
## strike. This is what the table's bar and the plots' levels both read.
func normalised(index: int) -> float:
	if index < 0 or index >= amplitudes.size() or peak_amplitude <= 0.0:
		return 0.0
	return amplitudes[index] / peak_amplitude


func _recompute() -> void:
	if not is_loaded():
		amplitudes = PackedFloat64Array()
		peak_amplitude = 1.0
		centroid = 0.0
		contact_ms = 0.0
		pulse = null
		return
	pulse = Excitation.make_pulse(1.0, model.material.contact_time_ref_ms, velocity, sample_rate)
	contact_ms = Excitation.contact_seconds(model.material.contact_time_ref_ms, velocity) * 1000.0
	amplitudes = Excitation.mode_amplitudes(model, velocity, model.gains_at(strike), sample_rate)
	peak_amplitude = 0.0
	for value in amplitudes:
		peak_amplitude = maxf(peak_amplitude, value)
	if peak_amplitude <= 0.0:
		peak_amplitude = 1.0
	centroid = Excitation.spectral_centroid(model, amplitudes)


## The signal the model produces at time `t`, summed over the visible modes.
## Used by the waveform and the onset and verify views. Amplitudes are the
## cached ones, so this is the sound of the strike currently selected.
func signal_at(t: float) -> float:
	var y := 0.0
	for i in model.modes.size():
		if not is_visible_mode(i):
			continue
		var mode := model.modes[i]
		y += amplitudes[i] * exp(-t / mode.tau) * sin(TAU * mode.f * t)
	return y


## Peak of `signal_at` over a window, by sampling. Every trace is drawn
## normalised to its own peak, because the panel is about timbre and the
## velocity slider would otherwise mostly change the height of everything.
func signal_peak(duration: float, steps := 800) -> float:
	var peak := 0.0
	for i in steps:
		peak = maxf(peak, absf(signal_at(float(i) / float(steps) * duration)))
	return peak if peak > 0.0 else 1.0


## The highest frequency the current sample rate will voice, from
## `kNyquistFraction` in `model.h`.
func usable_ceiling() -> float:
	return ModalModel.NYQUIST_FRACTION * sample_rate


## How long a window the time plots should show.
##
## The design fixes this at 1.2 s, which suited its hand-authored stand-ins —
## their longest decay was 0.41 s. The shipped ceramic model rings for 1.4 s,
## and against a 1.2 s window every trace is a solid block and the spectrogram
## shows no decay at all: the plot is drawing the truth and saying nothing.
##
## Two and a half time constants leaves a mode at 8% of its starting level,
## which is far enough down to read as decayed. The cap keeps a pathological
## ten-second tau from flattening everything else into the first few pixels.
func display_seconds() -> float:
	if not is_loaded():
		return 1.2
	var longest := 0.0
	for i in model.modes.size():
		if is_visible_mode(i):
			longest = maxf(longest, model.modes[i].tau)
	if longest <= 0.0:
		return 1.2
	return clampf(longest * 2.5, 0.4, 4.0)


## The time axis label for `display_seconds`, so the plots agree with it.
func duration_label() -> String:
	return "%.1f s" % display_seconds()
