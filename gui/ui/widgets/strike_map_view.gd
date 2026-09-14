@tool
class_name StrikeMapView
extends Control

## Where the object was struck, in its own (u, v) surface coordinates.
##
## Clicking selects the nearest measured position and swaps in that position's
## per-mode gains — a mug struck on the rim is a different sound from the same
## mug struck on the base, because a strike at a mode's node barely excites it
## at all.
##
## No model in `models/` carries `strike_positions` yet. The format reserves
## them, `model.cpp` validates them and the loader filters them alongside the
## modes, but nothing writes them: the fitter sees one strike per recording, so
## a position map needs several takes and a step that does not exist. Rather
## than invent four positions and let them look measured, the map says so and
## falls back to unit gains — the object excited everywhere at once, which is
## what the engine does today.

signal position_picked(index: int)

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
	mouse_default_cursor_shape = Control.CURSOR_CROSS


func _gui_input(event: InputEvent) -> void:
	if state == null or not state.is_loaded() or not state.model.has_strike_data():
		return
	var pressed := event is InputEventMouseButton \
			and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	var dragged := event is InputEventMouseMotion \
			and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if not (pressed or dragged):
		return

	var local: Vector2 = (event as InputEventMouse).position
	var u := local.x / maxf(size.x, 1.0)
	var v := local.y / maxf(size.y, 1.0)
	var best := -1
	var best_distance := INF
	for i in state.model.strike_positions.size():
		var position: ModalModel.StrikePosition = state.model.strike_positions[i]
		var distance := Vector2(position.u - u, position.v - v).length()
		if distance < best_distance:
			best_distance = distance
			best = i
	if best >= 0 and best != state.strike:
		position_picked.emit(best)
	accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ModalTheme.GLASS, true)

	for i in range(1, 8):
		var t := float(i) / 8.0
		draw_line(Vector2(t * size.x, 0), Vector2(t * size.x, size.y), ModalTheme.STRIKE_GRID, 1.0)
		draw_line(Vector2(0, t * size.y), Vector2(size.x, t * size.y), ModalTheme.STRIKE_GRID, 1.0)
	draw_rect(Rect2(0.5, 0.5, size.x - 1.0, size.y - 1.0), ModalTheme.STRIKE_FRAME, false, 1.0)

	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(size.x - 12.0, size.y - 6.0), "u",
			ModalTheme.STRIKE_AXIS)
	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(5.0, 12.0), "v", ModalTheme.STRIKE_AXIS)

	if state == null or not state.is_loaded():
		return
	if not state.model.has_strike_data():
		_draw_unmeasured()
		return

	for i in state.model.strike_positions.size():
		var position: ModalModel.StrikePosition = state.model.strike_positions[i]
		var centre := Vector2(position.u * size.x, position.v * size.y)
		var on := i == state.strike
		var colour := ModalTheme.AMBER if on else ModalTheme.STRIKE_IDLE
		var weight := 1.4 if on else 1.0

		if on:
			draw_circle(centre, 15.0, Color(ModalTheme.AMBER.r, ModalTheme.AMBER.g,
					ModalTheme.AMBER.b, 0.16))
		draw_line(centre - Vector2(6, 0), centre + Vector2(6, 0), colour, weight)
		draw_line(centre - Vector2(0, 6), centre + Vector2(0, 6), colour, weight)
		draw_arc(centre, 8.0 if on else 4.5, 0.0, TAU, 24, colour, weight, true)

		var label := position.name if not position.name.is_empty() else "P%d" % i
		var offset := -16.0 if position.v > 0.8 else 22.0
		DrawUtil.text(self, ModalTheme.mono(), 8, centre + Vector2(0, offset), label.to_upper(),
				colour, DrawUtil.Anchor.CENTRE)


## What the map says when the model has no measured positions. A single centre
## mark, dimmed, and the reason — so it reads as "not measured" rather than as
## "struck in the middle".
func _draw_unmeasured() -> void:
	var centre := size * 0.5
	var dim := Color(ModalTheme.STRIKE_IDLE.r, ModalTheme.STRIKE_IDLE.g,
			ModalTheme.STRIKE_IDLE.b, 0.45)
	DrawUtil.dashed_line(self, centre - Vector2(7, 0), centre + Vector2(7, 0), dim, 1.0, 2.0, 2.0)
	DrawUtil.dashed_line(self, centre - Vector2(0, 7), centre + Vector2(0, 7), dim, 1.0, 2.0, 2.0)
	draw_arc(centre, 9.0, 0.0, TAU, 24, dim, 1.0, true)

	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(centre.x, size.y * 0.5 + 30.0),
			"no strike_positions", ModalTheme.MUTED, DrawUtil.Anchor.CENTRE)
	DrawUtil.text(self, ModalTheme.mono(), 8, Vector2(centre.x, size.y * 0.5 + 42.0),
			"in this model", ModalTheme.MUTED, DrawUtil.Anchor.CENTRE)
