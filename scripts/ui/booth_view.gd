class_name BoothView
extends Control
## The room, drawn. One desk, one lamp, one window onto the safe zone, and a
## photograph the player will stop looking at after shift two.
##
## Everything here is drawn rather than textured, so the whole game runs with
## no art at all — art can be dropped over the top later without the layout
## moving. See docs/ASSETS.md.

var lights: int = Dread.WINDOW_LIGHTS
var shift: int = 1
## Rises with dread. Only ever expressed as how far the lamp reaches.
var closeness: float = 0.0
## Set for a beat when the desk glass is behaving badly.
var glass_lag: float = 0.0

var _t: float = 0.0


func _ready() -> void:
	# The room is drawn from `size`, so it is pinned to the viewport rather
	# than left to an anchor pass that has not run by the first frame.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()
	get_viewport().size_changed.connect(_fit)
	set_process(true)


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _process(delta: float) -> void:
	_t += delta
	glass_lag = maxf(0.0, glass_lag - delta)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Palette.NIGHT, true)
	_draw_lamp_pool(w, h)
	_draw_back_wall(w, h)
	_draw_window(w, h)
	_draw_desk(w, h)
	_draw_photo(w, h)
	_draw_vignette(w, h)


## The lamp is the whole lighting model, and it is small. Everything outside
## it is black — which is the point of a booth at night. As dread rises the
## pool draws in, until on the sixth shift it barely clears the desk.
func _draw_lamp_pool(w: float, h: float) -> void:
	var centre := Vector2(w * 0.32, h * 0.50)
	var reach := lerpf(w * 0.34, w * 0.19, clampf(closeness, 0.0, 1.0))
	var steps := 30
	for i in steps:
		var f := float(i) / float(steps)
		# Falls off fast: a bright core and very little spill.
		var radius := reach * (1.0 - f)
		var alpha := 0.020 * pow(1.0 - f, 0.6)
		draw_circle(centre, radius, Color(Palette.LAMP.r, Palette.LAMP.g, Palette.LAMP.b, alpha))


## Barely there. The player should be looking at a face, not at planks.
func _draw_back_wall(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h * 0.62), Color(Palette.BOOTH, 0.55), true)
	for i in 24:
		var x := w * float(i) / 24.0
		draw_line(Vector2(x, 0), Vector2(x, h * 0.62), Color(0, 0, 0, 0.22), 2.0)


## The safe zone, far off over their shoulder. One light goes out per thing
## you wave through, and it is the only score the game ever shows.
func _draw_window(w: float, h: float) -> void:
	var frame := Rect2(w * 0.78, h * 0.11, w * 0.145, h * 0.115)
	draw_rect(frame.grow(4.0), Color("0b0b0e"), true)
	draw_rect(frame, Palette.WINDOW_DARK, true)
	var cols := 4
	var rows := 2
	var pad := 5.0
	var cell := Vector2(
		(frame.size.x - pad * float(cols + 1)) / float(cols),
		(frame.size.y - pad * float(rows + 1)) / float(rows))
	for i in Dread.WINDOW_LIGHTS:
		var at := frame.position + Vector2(
			pad + float(i % cols) * (cell.x + pad),
			pad + float(i / cols) * (cell.y + pad))
		var box := Rect2(at, cell)
		if i >= lights:
			draw_rect(box, Color("0e0f12"), true)
			continue
		# A lamp behind a curtain, a long way off, is never quite steady.
		var flicker := 0.62 + 0.16 * sin(_t * (1.7 + float(i) * 0.31) + float(i))
		draw_rect(box, Color(Palette.WINDOW_LIT, flicker), true)
		draw_rect(box.grow(3.0), Color(Palette.WINDOW_LIT, 0.05), true)


func _draw_desk(w: float, h: float) -> void:
	var top := h * 0.62
	draw_rect(Rect2(0, top, w, h - top), Palette.DESK.darkened(0.45), true)
	draw_rect(Rect2(0, top, w, 3), Color(Palette.LAMP_DIM, 0.35), true)
	# The glass they lean on, and that you can see yourself in.
	var glass := Rect2(w * 0.05, top + 18.0, w * 0.30, h * 0.055)
	draw_rect(glass, Color(Palette.GLASS, 0.30), true)
	draw_rect(glass, Color(0, 0, 0, 0.45), false, 2.0)
	# Your reflection. When the glass misbehaves it is a beat behind you.
	var drift := 0.0 if glass_lag <= 0.0 else sin(_t * 3.4) * 10.0
	draw_rect(Rect2(glass.position + Vector2(26.0 + drift, 12.0),
		Vector2(70, glass.size.y - 24.0)), Color(Palette.INK, 0.045), true)


## Eight variants, one face changing per shift. Nobody notices on shift two.
func _draw_photo(w: float, h: float) -> void:
	var at := Rect2(w * 0.80, h * 0.40, 116, 86)
	draw_rect(at.grow(4.0), Color("3a3128"), true)
	draw_rect(at, Color("1a1713"), true)
	var faces := 3
	for i in faces:
		var cx := at.position.x + at.size.x * (float(i) + 0.5) / float(faces)
		var cy := at.position.y + at.size.y * 0.44
		# One of them stops being a face, a different one each shift.
		var changed := i == (shift - 1) % faces and shift > 1
		draw_circle(Vector2(cx, cy), 11.0,
			Color(Palette.INK_DIM if not changed else Color("0f1013"), 0.62))
		if changed:
			continue
		draw_circle(Vector2(cx - 3.5, cy - 2.5), 1.6, Palette.NIGHT)
		draw_circle(Vector2(cx + 3.5, cy - 2.5), 1.6, Palette.NIGHT)


## Heavy. The room should close on the player as much as the lamp allows.
func _draw_vignette(w: float, h: float) -> void:
	var bands := 26
	for i in bands:
		var f := float(i) / float(bands)
		var inset := f * f * 520.0
		draw_rect(Rect2(inset, inset, w - inset * 2.0, h - inset * 2.0),
			Color(0, 0, 0, 0.055), false, 26.0)
