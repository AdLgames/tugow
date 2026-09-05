class_name PortraitView
extends Control
## The face at the glass.
##
## The idle blink is a mechanic, not decoration: people blink and shift, and
## a thing that has not learned to yet does not. Drawn from a seed so the same
## traveller always has the same face, and so twenty portraits exist before
## any art does.

const SIZE := Vector2(520, 560)

var traveller: Traveller = null
var shift: int = 1
## Drives the lean-in scare. 0 is at the glass, 1 is filling it.
var lean: float = 0.0

var _t: float = 0.0
var _blink: float = 0.0
var _next_blink: float = 1.4
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func show_traveller(t: Traveller) -> void:
	traveller = t
	_rng.seed = 0 if t == null else t.portrait * 977 + 13
	_t = 0.0
	_blink = 0.0
	_next_blink = _rng.randf_range(1.0, 3.2)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _is_still():
		_blink = 0.0
	else:
		_next_blink -= delta
		if _next_blink <= 0.0:
			_blink = 0.13
			_next_blink = _rng.randf_range(1.2, 4.0)
		_blink = maxf(0.0, _blink - delta)
	queue_redraw()


## Stillness only tells you anything while it still separates the two.
func _is_still() -> bool:
	if traveller == null:
		return true
	return traveller.idle_reads_as_still(shift)


func _draw() -> void:
	if traveller == null:
		return
	# The lean-in grows the face toward the glass without moving the box it
	# is drawn in, so nothing else on screen shifts when it happens.
	var grow := 1.0 + lean * 0.85
	var centre := Vector2(size.x * 0.5, size.y * 0.46)
	_rng.seed = traveller.portrait * 977 + 13
	var head_r := size.x * 0.26 * grow
	# People sway a little. Things do not.
	var sway := 0.0 if _is_still() else sin(_t * 0.9) * 2.5
	var at := centre + Vector2(sway, 0.0)

	if traveller.is_faceless():
		_draw_faceless(at, head_r)
		return

	var skin := Color.from_hsv(0.06 + _rng.randf_range(-0.02, 0.03),
		_rng.randf_range(0.16, 0.30), _rng.randf_range(0.38, 0.62))
	_draw_shoulders(at, head_r, skin.darkened(0.72))
	draw_circle(at, head_r, skin)
	_draw_hair(at, head_r, skin)
	_draw_face(at, head_r, skin)


## A coat and shoulders, clipped to the bottom of the box so the figure sits
## in the frame rather than spilling out of it.
func _draw_shoulders(at: Vector2, r: float, coat: Color) -> void:
	var top := at.y + r * 0.95
	var half := r * 1.5
	var points := PackedVector2Array([
		Vector2(at.x - half, size.y),
		Vector2(at.x - half * 0.86, top + r * 0.30),
		Vector2(at.x - r * 0.44, top),
		Vector2(at.x + r * 0.44, top),
		Vector2(at.x + half * 0.86, top + r * 0.30),
		Vector2(at.x + half, size.y),
	])
	draw_colored_polygon(points, coat)


func _draw_hair(at: Vector2, r: float, skin: Color) -> void:
	var hair := skin.darkened(_rng.randf_range(0.55, 0.82))
	var brow := at.y - r * 0.30
	var points := PackedVector2Array([
		Vector2(at.x - r * 0.99, brow),
		Vector2(at.x - r * 0.82, at.y - r * 0.92),
		Vector2(at.x, at.y - r * 1.06),
		Vector2(at.x + r * 0.82, at.y - r * 0.92),
		Vector2(at.x + r * 0.99, brow),
		Vector2(at.x + r * 0.70, at.y - r * 0.52),
		Vector2(at.x - r * 0.70, at.y - r * 0.52),
	])
	draw_colored_polygon(points, hair)


func _draw_face(at: Vector2, r: float, skin: Color) -> void:
	var eye_y := at.y - r * 0.10
	var spread := r * 0.36
	var open := _blink <= 0.0
	var dark := skin.darkened(0.75)
	for side in [-1.0, 1.0]:
		var eye := Vector2(at.x + spread * side, eye_y)
		if open:
			draw_circle(eye, r * 0.13, Color("efe7d6"))
			draw_circle(eye, r * 0.062, Palette.NIGHT)
		else:
			draw_line(eye - Vector2(r * 0.14, 0), eye + Vector2(r * 0.14, 0), dark, 3.0)
	draw_line(at + Vector2(0, r * 0.02), at + Vector2(0, r * 0.26),
		skin.darkened(0.30), 3.0)
	# A thing that has been asked outright holds its smile.
	var mouth := Vector2(at.x, at.y + r * 0.52)
	if traveller.is_thing and traveller.answered.has(Questions.Id.ARE_YOU_HUMAN):
		draw_arc(mouth - Vector2(0, r * 0.22), r * 0.34, 0.22 * PI, 0.78 * PI, 24, dark, 3.5)
	else:
		draw_line(mouth - Vector2(r * 0.22, 0), mouth + Vector2(r * 0.22, 0), dark, 3.0)


## No face at all. There is nothing to read, and DENY does not work on it.
func _draw_faceless(at: Vector2, r: float) -> void:
	_draw_shoulders(at, r, Color("100e0c"))
	draw_circle(at, r, Color("17150f"))
	draw_arc(at, r, 0.0, TAU, 56, Color(Palette.WRONG, 0.28), 2.0)
