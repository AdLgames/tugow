class_name DieView
extends Button
## A worn bone die on the felt. Click to stake it — for the whole night, not
## the turn.
##
## All character work goes on the body: the pip face stays clean and
## high-contrast so a value is never ambiguous at small scale.
## Source: docs/design-system/BUILD_BRIEF_table_scene.md, "The dice".

const SIZE := 176.0
const TUMBLE_SECONDS := 0.64

## Pip layouts on a 3x3 grid. The grid runs past 6 because die.gd caps a
## reshaped face at 9.
const PIPS := {
	1: [4],
	2: [0, 8],
	3: [0, 4, 8],
	4: [0, 2, 6, 8],
	5: [0, 2, 4, 6, 8],
	6: [0, 2, 3, 5, 6, 8],
	7: [0, 2, 3, 4, 5, 6, 8],
	8: [0, 1, 2, 3, 5, 6, 7, 8],
	9: [0, 1, 2, 3, 4, 5, 6, 7, 8],
}

## The chipped silhouette, as fractions of the die's box.
const SILHOUETTE := [
	Vector2(0.09, 0.00), Vector2(0.93, 0.02), Vector2(1.00, 0.12),
	Vector2(0.98, 0.92), Vector2(0.90, 1.00), Vector2(0.08, 0.99),
	Vector2(0.00, 0.90), Vector2(0.02, 0.08),
]

var die: Die
## When the physical dice are rendered underneath, this view is only the
## name, the state tag and the hit area — the die itself is a real object in
## the simulation and drawing a second one over it would be a lie.
var render_body: bool = true
var sway_left: float = 0.0
var sway_right: float = 0.0

var _tumble: float = 0.0
var _hover: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	pivot_offset = Vector2(SIZE, SIZE) * 0.5
	focus_mode = Control.FOCUS_NONE
	flat = true
	text = ""
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())


func bind(p_die: Die) -> void:
	die = p_die
	refresh()


func refresh() -> void:
	if die == null:
		return
	disabled = die.locked or die.value == 0 or die.lost
	tooltip_text = _tooltip()
	queue_redraw()


## Staked dice keep their face, so they do not tumble.
func tumble(delay: float = 0.0) -> void:
	if die != null and die.locked:
		return
	_tumble = TUMBLE_SECONDS + delay
	set_process(true)


func _process(delta: float) -> void:
	_tumble -= delta
	if _tumble <= 0.0:
		_tumble = 0.0
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if die == null or die.lost:
		return
	var offset := Vector2.ZERO
	var spin := 0.0
	var scale_factor := 1.0
	if _tumble > 0.0:
		var t := clampf(1.0 - (_tumble / TUMBLE_SECONDS), 0.0, 1.0)
		offset = Vector2(sin(t * 9.0) * 18.0 * (1.0 - t), -330.0 * pow(1.0 - t, 1.6))
		spin = t * TAU * 2.0
		scale_factor = lerpf(0.86, 1.0, t)
	elif _hover and not die.locked:
		offset = Vector2(0, -4)

	if render_body:
		# Two lanterns, so two shadows, drifting out of phase.
		_shadow(offset, 40.0 - sway_left * 2.0)
		_shadow(offset, -40.0 - sway_right * 2.0)

		var body := _silhouette(offset, spin, scale_factor)
		draw_colored_polygon(body, _body_colour())
		_draw_body_shading(body)
		_draw_face(offset, scale_factor)
		_draw_wear(offset)
	elif die.locked or die.zone == Throw.Zone.RAIL or _hover:
		# A ring is enough to mark a real die underneath.
		var centre := Vector2(SIZE, SIZE) * 0.5 + offset
		var tint := ThemeColors.LOCKED if die.locked else ThemeColors.DECLARED
		if _hover and not die.locked:
			tint = ThemeColors.INK
		draw_arc(centre, SIZE * 0.48, 0.0, TAU, 40, Color(tint, 0.85), 3.0)
	_draw_name(offset)
	if die.is_cocked():
		_draw_cocked(offset)
	if die.locked:
		_draw_tag(Lore.LOCKED_TAG, ThemeColors.LOCKED)
	elif die.zone == Throw.Zone.RAIL:
		_draw_tag("RAIL x2", ThemeColors.DECLARED)
	elif die.is_cocked():
		_draw_tag("COCKED — BOTH FACES", ThemeColors.PLAYER)


func _body_colour() -> Color:
	if die.locked:
		return Color("d9b463")
	if die.bitter:
		return Color("6d5480")
	return Color("a08a63")


func _silhouette(offset: Vector2, spin: float, scale_factor: float) -> PackedVector2Array:
	var centre := Vector2(SIZE, SIZE) * 0.5
	var points := PackedVector2Array()
	for p in SILHOUETTE:
		var local: Vector2 = (p * SIZE - centre) * scale_factor
		if spin != 0.0:
			local = local.rotated(spin)
		points.append(centre + local + offset)
	return points


func _draw_body_shading(body: PackedVector2Array) -> void:
	# Lit from the top-left, dropping into the bottom-right.
	var highlight := Color(1, 0.94, 0.78, 0.22) if not die.bitter else Color(1, 1, 1, 0.10)
	draw_colored_polygon(PackedVector2Array([body[0], body[1], body[2], body[7]]), highlight)
	draw_colored_polygon(PackedVector2Array([body[3], body[4], body[5], body[6]]),
		Color(0.17, 0.13, 0.07, 0.35))
	draw_polyline(body, Color(0, 0, 0, 0.45), 2.0, true)
	if die.bitter:
		# Hairline cracks.
		var c := Vector2(SIZE, SIZE) * 0.5
		draw_line(c + Vector2(-40, -52), c + Vector2(6, 10), Color(0.05, 0.03, 0.08, 0.75), 2.0)
		draw_line(c + Vector2(6, 10), c + Vector2(48, 40), Color(0.05, 0.03, 0.08, 0.75), 2.0)


func _draw_face(offset: Vector2, scale_factor: float) -> void:
	var value := die.value
	if value <= 0:
		return
	var inset := 22.0
	var cell := (SIZE - inset * 2.0) / 3.0
	var pip_colour := Color("140d05")
	if value > 9:
		return
	if not PIPS.has(value):
		return
	for index in PIPS[value]:
		var col: int = int(index) % 3
		var row: int = int(index) / 3
		var centre := Vector2(inset + cell * (col + 0.5), inset + cell * (row + 0.5))
		centre = (centre - Vector2(SIZE, SIZE) * 0.5) * scale_factor + Vector2(SIZE, SIZE) * 0.5
		draw_circle(centre + offset + Vector2(0, 1), 19.0 * scale_factor, Color(1, 1, 1, 0.18))
		draw_circle(centre + offset, 19.0 * scale_factor, pip_colour)
		draw_circle(centre + offset - Vector2(5, 5) * scale_factor, 6.0 * scale_factor,
			Color(0.24, 0.19, 0.12, 0.55))


## Wear must never make a value ambiguous: everything here stays outside the
## pip grid and lighter than a pip, so nothing on the body can be miscounted.
func _draw_wear(offset: Vector2) -> void:
	var grime := Color(0.42, 0.34, 0.22, 0.10)
	draw_circle(Vector2(SIZE - 26, 20) + offset, 16.0, grime)
	draw_circle(Vector2(20, SIZE - 24) + offset, 12.0, grime)
	# Nicks ride the silhouette edge, lighter than the body, never near a pip.
	var chip := Color(0.66, 0.57, 0.40, 0.55)
	draw_line(Vector2(SIZE - 6, 8) + offset, Vector2(SIZE - 2, 30) + offset, chip, 3.0)
	draw_line(Vector2(4, SIZE - 34) + offset, Vector2(1, SIZE - 12) + offset, chip, 3.0)


func _shadow(offset: Vector2, dx: float) -> void:
	var centre := Vector2(SIZE * 0.5 + dx, SIZE + 14) + Vector2(0, offset.y * 0.12)
	var points := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		points.append(centre + Vector2(cos(a) * SIZE * 0.52, sin(a) * 13.0))
	draw_colored_polygon(points, Color(0, 0, 0, 0.38))


## Eight named individuals, not interchangeable props.
func _draw_name(offset: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var label := die.die_name.to_upper()
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var at := Vector2((SIZE - width) * 0.5, -12) + offset
	draw_string(font, at + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(0, 0, 0, 0.65))
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		ThemeColors.LOCKED if die.locked else ThemeColors.INK_DIM)


## A cocked die is resting on another and counts as both faces — a major
## state that was text in the log and nothing on the table.
func _draw_cocked(offset: Vector2) -> void:
	var centre := Vector2(SIZE, SIZE) * 0.5 + offset
	draw_arc(centre, SIZE * 0.62, 0.0, TAU, 40, Color(ThemeColors.PLAYER, 0.75), 3.0)
	draw_arc(centre, SIZE * 0.68, 0.0, TAU, 40, Color(ThemeColors.PLAYER, 0.25), 2.0)


func _draw_tag(label: String, colour: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var at := Vector2((SIZE - width) * 0.5, SIZE + 32)
	draw_string(font, at + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0, 0, 0, 0.7))
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, colour)


func _tooltip() -> String:
	var lines: Array[String] = ["%s — faces %s" % [die.die_name, str(Array(die.faces))]]
	lines.append("hidden face %d" % die.underside())
	if die.bitter:
		lines.append("Bitter: refuses its lowest face.")
	if die.locked:
		lines.append("Staked for the rest of the night.")
	if die.zone == Throw.Zone.RAIL:
		lines.append("On the rail: doubles, but the next draw shoves it toward the lip.")
	if die.is_cocked():
		lines.append("Cocked: counts as both faces.")
	return "\n".join(lines)
