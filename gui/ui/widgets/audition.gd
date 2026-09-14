@tool
class_name Audition
extends Node

## Hearing it.
##
## Renders a strike with `ModalVoice` and plays it. A small pool of players
## round-robins so two strikes in quick succession overlap rather than cutting
## each other off — which is what a real object does, and also a miniature of
## the voice pool `bank.h` describes for week 3.
##
## Rendering is not real-time and does not need to be: a two-second strike is a
## few million multiply-adds, which lands inside a frame at the sizes these
## models run to. If a model ever arrives that makes this stutter, the answer
## is the GDExtension rather than a cleverer buffer.

signal rendered(samples: PackedFloat32Array, milliseconds: float)

## Enough that a quick double-strike overlaps, few enough that a held key
## cannot pile up an unbounded number of voices.
const VOICES := 4

## How much of the decay to render. The tail below this is inaudible under any
## normal monitoring and doubling it doubles the render cost for nothing.
const MAX_SECONDS := 2.5

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_samples := PackedFloat32Array()

## The last render, and what it was a render of.
##
## Striking the same object at the same velocity twice must be instantaneous —
## that is most of what auditioning is, and a hundred milliseconds of hitch
## between pressing the key and hearing the sound makes the whole panel feel
## broken. Only a change to the object or the strike costs a render.
var _cached_key := ""
var _cached_stream: AudioStreamWAV


## Everything the rendered audio depends on. Miss anything here and the panel
## plays a stale sound while showing new numbers, which is the worst failure
## this screen could have.
static func _key(state: FitState, seconds: float) -> String:
	return "%s|%.6f|%.6f|%.6f|%.4f|%d|%.1f|%.3f" % [
		state.model_path, state.size_factor, state.ring_factor, state.striker_ms,
		state.velocity, state.strike, state.sample_rate, seconds]


func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		# Auditioning is a monitoring task, not part of a game mix.
		player.bus = &"Master"
		add_child(player)
		_players.append(player)


## Strikes the object the state currently describes, at its current velocity.
## Returns the samples so a caller can draw exactly what was heard.
func strike(state: FitState) -> PackedFloat32Array:
	if state == null or not state.is_loaded() or _players.is_empty():
		return PackedFloat32Array()

	var seconds := minf(state.display_seconds(), MAX_SECONDS)
	var key := _key(state, seconds)

	var elapsed := 0.0
	if key != _cached_key or _cached_stream == null:
		var started := Time.get_ticks_usec()
		var samples := ModalVoice.render(state.model, state.velocity, state.sample_rate, seconds,
				ModalVoice.DEFAULT_GAIN, state.model.gains_at(state.strike))
		elapsed = float(Time.get_ticks_usec() - started) / 1000.0

		if samples.is_empty():
			return samples
		# A bank that has gone non-finite would otherwise be sent to the
		# speakers, which is both unpleasant and hard to diagnose afterwards.
		if not ModalVoice.is_finite(samples):
			push_warning("Modal Fit: the resonator bank went non-finite; not playing")
			return PackedFloat32Array()

		_last_samples = samples
		_cached_stream = ModalVoice.to_stream(samples, state.sample_rate)
		_cached_key = key

	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _cached_stream
	player.play()

	rendered.emit(_last_samples, elapsed)
	return _last_samples


func stop_all() -> void:
	for player in _players:
		player.stop()


func last_samples() -> PackedFloat32Array:
	return _last_samples
