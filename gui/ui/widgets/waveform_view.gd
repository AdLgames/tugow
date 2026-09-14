@tool
class_name WaveformView
extends Control

## The resynthesis, drawn as a min/max envelope.
##
## One column per pixel, each column the extremes of the signal across its
## span. At 612 Hz and up there are many cycles per pixel, so plotting the
## signal itself would alias into a moiré that moves when the window resizes;
## the envelope is what a DAW draws and for the same reason.

const SUBSAMPLES := 26

var state: FitState:
	set(value):
		if state == value:
			return
		if state != null and state.changed.is_connected(queue_redraw):
			state.changed.disconnect(queue_redraw)
		state = value
		if state != null:
			state.changed.connect(queue_redraw)
		queue_redraw()


func _ready() -> void:
	custom_minimum_size.y = 96


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ModalTheme.GLASS_DEEP, true)
	if state == null or not state.is_loaded():
		return

	var duration := state.display_seconds()
	var middle := size.y * 0.5
	var span := size.y * 0.5 - 5.0
	var columns := int(size.x)
	if columns <= 0:
		return

	var lows := PackedFloat32Array()
	var highs := PackedFloat32Array()
	var peak := 0.0
	for column in columns + 1:
		var low := 0.0
		var high := 0.0
		for step in SUBSAMPLES:
			var t := (float(column) + float(step) / float(SUBSAMPLES)) / float(columns) * duration
			var value := state.signal_at(t)
			low = minf(low, value)
			high = maxf(high, value)
		lows.append(low)
		highs.append(high)
		peak = maxf(peak, maxf(absf(low), absf(high)))
	if peak <= 0.0:
		peak = 1.0

	draw_line(Vector2(0, middle), Vector2(size.x, middle), ModalTheme.GRID, 1.0)
	for column in lows.size():
		var top := middle - highs[column] / peak * span
		var bottom := middle - lows[column] / peak * span
		draw_rect(Rect2(float(column), top, 1.0, maxf(1.0, bottom - top)), ModalTheme.AMBER, true)

	# The decay envelope of whichever mode is being listened to: the soloed
	# one, or the loudest when all are playing. This is the tau in the table,
	# drawn over the sound it produces.
	var index := state.solo if state.solo >= 0 else 0
	if index >= state.mode_count():
		return
	var tau: float = state.model.modes[index].tau
	var points := PackedVector2Array()
	for column in columns + 1:
		var t := float(column) / float(columns) * duration
		points.append(Vector2(float(column), middle - exp(-t / tau) * span))
	_draw_dashed_polyline(points, Color(ModalTheme.INK.r, ModalTheme.INK.g, ModalTheme.INK.b, 0.45))


func _draw_dashed_polyline(points: PackedVector2Array, colour: Color) -> void:
	var index := 0
	while index < points.size() - 1:
		draw_line(points[index], points[mini(index + 3, points.size() - 1)], colour, 1.0)
		index += 6
