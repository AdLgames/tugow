@tool
class_name VelocityCurveView
extends Control

## Spectral centroid against impact velocity — the week 1 gate, drawn.
##
## The curve rises because a harder hit is a shorter contact and a shorter
## contact reaches more of the high modes, and it flattens at the top because
## contact time is clamped at 0.05 ms. That flattening is the point: it is a
## real ceiling in the model rather than a plotting artefact, and a developer
## who can see where it sits knows where velocity stops buying brightness.

const VELOCITY_MIN := 0.5
const VELOCITY_MAX := 10.0
const SAMPLES := 30

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

	var rect := Rect2(34.0, 12.0, maxf(size.x - 42.0, 1.0), maxf(size.y - 28.0, 1.0))
	var gains := state.model.gains_at(state.strike)

	var curve := PackedFloat64Array()
	var low := INF
	var high := -INF
	for i in SAMPLES + 1:
		var v := VELOCITY_MIN + (VELOCITY_MAX - VELOCITY_MIN) * float(i) / float(SAMPLES)
		var amplitudes := Excitation.mode_amplitudes(state.model, v, gains, state.sample_rate)
		var value := Excitation.spectral_centroid(state.model, amplitudes)
		curve.append(value)
		low = minf(low, value)
		high = maxf(high, value)

	# A flat curve would otherwise divide by zero and, worse, be drawn as a
	# dramatic line through the middle of an invented range.
	var padding := (high - low) * 0.15
	if padding <= 0.0:
		padding = 50.0
	low -= padding
	high += padding

	var x_of := func(v: float) -> float:
		return rect.position.x + rect.size.x * (v - VELOCITY_MIN) / (VELOCITY_MAX - VELOCITY_MIN)
	var y_of := func(f: float) -> float:
		return rect.end.y - rect.size.y * (f - low) / (high - low)

	draw_rect(rect, ModalTheme.GRID, false, 1.0)

	var points := PackedVector2Array()
	for i in curve.size():
		var v := VELOCITY_MIN + (VELOCITY_MAX - VELOCITY_MIN) * float(i) / float(SAMPLES)
		points.append(Vector2(x_of.call(v), y_of.call(curve[i])))
	if points.size() > 1:
		draw_polyline(points, ModalTheme.AMBER, 1.4, true)

	# Where the slider currently sits.
	var marker_x: float = x_of.call(state.velocity)
	DrawUtil.dashed_line(self, Vector2(marker_x, rect.position.y), Vector2(marker_x, rect.end.y),
			Color(ModalTheme.INK.r, ModalTheme.INK.g, ModalTheme.INK.b, 0.4), 1.0, 2.0, 3.0)
	draw_circle(Vector2(marker_x, y_of.call(state.centroid)), 3.0, ModalTheme.INK)

	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(rect.position.x - 5.0, rect.position.y + 8.0),
			"%d" % roundi(high), ModalTheme.GRID_DIM, DrawUtil.Anchor.RIGHT)
	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(rect.position.x - 5.0, rect.end.y),
			"%d" % roundi(low), ModalTheme.GRID_DIM, DrawUtil.Anchor.RIGHT)
	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(rect.position.x, size.y - 4.0),
			"%.1f" % VELOCITY_MIN, ModalTheme.GRID_DIM)
	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(rect.end.x, size.y - 4.0),
			"%d m/s" % int(VELOCITY_MAX), ModalTheme.GRID_DIM, DrawUtil.Anchor.RIGHT)

	draw_set_transform(Vector2(10.0, rect.get_center().y), -PI * 0.5, Vector2.ONE)
	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2.ZERO, "centroid Hz",
			ModalTheme.GRID_DIM, DrawUtil.Anchor.CENTRE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
