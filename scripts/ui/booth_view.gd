class_name BoothView
extends Control
## The room. The painting does the work — the desk, the hatch, the lamp and
## its light are all in the art — so everything drawn here is either a thing
## that changes (the safe-zone lights, the family photo) or a thing that has
## to respond to the player (the dark closing in as dread rises).
##
## Art: assets/scene/booth.png, 1344x768 pixel art, drawn nearest-neighbour so
## it stays crisp at 1920x1080.

## Where things sit in the painting, as fractions of the frame, so the layout
## survives a re-scale or a repaint at another size.
const HATCH := Rect2(0.348, 0.219, 0.322, 0.419)     ## The open pane they stand in.
const SAFE_ZONE := Rect2(0.358, 0.045, 0.305, 0.135)  ## Upper pane: the safe zone, a long way off.
const SIDE_PANE := Rect2(0.043, 0.030, 0.285, 0.620)  ## Side window: dark glass, where the talking goes.
const DESK_TOP := 0.667
const DESK_FRONT := 0.859
const LAMP := Vector2(0.830, 0.545)                  ## The bulb in the painting.

var lights: int = Dread.WINDOW_LIGHTS
var shift: int = 1
## Rises with dread. The lamp is the only light in the room, so this is the
## dark outside its reach closing in.
var closeness: float = 0.0
## Set for a beat when the desk glass is misbehaving.
var glass_lag: float = 0.0

var _art: Texture2D
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pixel art, scaled up. Anything but nearest turns it to mush.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art = load("res://assets/scene/booth.png") if ResourceLoader.exists("res://assets/scene/booth.png") else null
	Props.warm()
	Portraits.warm()
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


## Where the traveller stands, in screen coordinates. The interface asks the
## painting where things are rather than repeating the numbers.
func hatch_rect() -> Rect2:
	return Rect2(HATCH.position * size, HATCH.size * size)


## The dark glass of the side window: where everything said is written.
func side_pane_rect() -> Rect2:
	return Rect2(SIDE_PANE.position * size, SIDE_PANE.size * size)


func _draw() -> void:
	if _art == null:
		draw_rect(Rect2(Vector2.ZERO, size), Palette.NIGHT, true)
	else:
		draw_texture_rect(_art, Rect2(Vector2.ZERO, size), false)
	_draw_safe_zone(size)
	_draw_props(size)
	_draw_photo_faces(size)
	_draw_glass(size)
	_draw_dark(size)


## The safe zone, seen through the side window. Eight lit windows, one of
## which goes out for every thing you wave through. It is the only readout in
## the game and it is deliberately across the room from everything else.
func _draw_safe_zone(s: Vector2) -> void:
	var pane := Rect2(SAFE_ZONE.position * s, SAFE_ZONE.size * s)
	var cols := 4
	var rows := 2
	var pad := pane.size.x * 0.045
	var cell := Vector2(
		(pane.size.x - pad * float(cols + 1)) / float(cols),
		(pane.size.y - pad * float(rows + 1)) / float(rows))
	# A block of flats a long way off, most of the frame given to the dark
	# between the windows.
	for i in Dread.WINDOW_LIGHTS:
		var at := pane.position + Vector2(
			pad + float(i % cols) * (cell.x + pad),
			pad + float(i / cols) * (cell.y + pad))
		var box := Rect2(at, cell * Vector2(0.58, 0.52))
		if i >= lights:
			draw_rect(box, Color("07080b", 0.85), true)
			continue
		var flicker := 0.50 + 0.13 * sin(_t * (1.6 + float(i) * 0.29) + float(i) * 1.7)
		draw_rect(box.grow(4.0), Color(Palette.WINDOW_LIT, 0.05), true)
		draw_rect(box, Color(Palette.WINDOW_LIT, flicker), true)


## The dressing: clipboard, radio, mug, photograph, lamp. Painted props, laid
## out from a table of fractions so nothing here is hard-coded to 1920x1080.
func _draw_props(s: Vector2) -> void:
	for id in Props.ids():
		var tex := Props.texture(id)
		if tex == null:
			continue
		var at := Props.rect_for(id, s, tex)
		var tilt := Props.tilt_of(id)
		if is_zero_approx(tilt):
			draw_texture_rect(tex, at, false)
			continue
		# Nothing on a desk is ever quite square to it.
		draw_set_transform(at.get_center(), tilt, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-at.size * 0.5, at.size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The photograph is real art, and one of its three faces stops being a face
## on every shift after the first. Rather than eight painted variants, the
## face is put out — which is closer to what it should feel like anyway.
func _draw_photo_faces(s: Vector2) -> void:
	if shift <= 1:
		return
	var tex := Props.texture(&"photo_family")
	if tex == null:
		return
	var at := Props.rect_for(&"photo_family", s, tex)
	# The three heads, as fractions of the framed photograph.
	var heads := [Vector2(0.34, 0.42), Vector2(0.56, 0.33), Vector2(0.62, 0.52)]
	var which: int = (shift - 2) % heads.size()
	var head: Vector2 = heads[which]
	var centre := at.position + head * at.size
	draw_set_transform(at.get_center(), Props.tilt_of(&"photo_family"), Vector2.ONE)
	var local := centre - at.get_center()
	draw_circle(local, at.size.x * 0.115, Color("0a0a0d", 0.93))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Your own reflection in the desk glass. Ordinarily a smear you never notice;
## for a few seconds after the reflection scare, a beat behind you.
func _draw_glass(s: Vector2) -> void:
	if glass_lag <= 0.0:
		return
	var drift := sin(_t * 3.4) * s.x * 0.006
	var box := Rect2(s.x * 0.42 + drift, s.y * DESK_TOP + s.y * 0.012,
		s.x * 0.075, s.y * 0.055)
	draw_rect(box, Color(Palette.INK, 0.055), true)


## The lamp is the only light in the room. As dread rises the dark outside it
## closes in — this is the only place dread is ever expressed, and it is never
## named or numbered.
func _draw_dark(s: Vector2) -> void:
	var centre := LAMP * s
	var reach := lerpf(s.x * 1.05, s.x * 0.44, clampf(closeness, 0.0, 1.0))
	var bands := 22
	for i in bands:
		var f := float(i) / float(bands)
		# Rings of shadow, tight to the frame and opening out toward the lamp.
		var radius := reach + f * f * s.x * 0.55
		draw_arc(centre, radius, 0.0, TAU, 96,
			Color(0, 0, 0, 0.055 + 0.03 * closeness), s.x * 0.035)
	# A flat sit-down on everything, so a frightened booth is simply darker.
	if closeness > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.30 * closeness), true)
