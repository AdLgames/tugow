class_name TableView
extends Control
## The table, drawn rather than sprited: pot, rail, and the lip past which
## dice are lost. Every die sits at the position the throw resolver gave it,
## so this is a readout of the real model, not a decoration. A future 2D
## scene replaces the drawing without touching the rules.

var pool: DicePool = null
var preview_strength: int = Throw.Strength.MEDIUM


func _init() -> void:
	custom_minimum_size = Vector2(340, 300)
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func bind(p_pool: DicePool) -> void:
	pool = p_pool
	queue_redraw()


func _draw() -> void:
	var centre := size * 0.5
	var lip := minf(size.x, size.y) * 0.46
	var rail_inner := lip * Balance.rail_inner_radius

	# The table itself.
	draw_circle(centre, lip, ThemeColors.PANEL_EDGE)
	draw_circle(centre, rail_inner, ThemeColors.PANEL)
	draw_arc(centre, lip, 0.0, TAU, 64, ThemeColors.INK_DIM, 2.0)
	draw_arc(centre, rail_inner, 0.0, TAU, 64, ThemeColors.LOCKED, 1.0)

	# Where this throw strength can reach.
	var band: Vector2 = Balance.throw_bands.get(preview_strength, Vector2(0, 1))
	draw_arc(centre, lip * band.y, 0.0, TAU, 64, ThemeColors.DECLARED, 1.0)

	_label(centre + Vector2(-14, -rail_inner * 0.55), "POT", ThemeColors.INK_DIM)
	_label(centre + Vector2(-14, -lip + 14), "RAIL x2", ThemeColors.LOCKED)

	if pool == null:
		return
	for d in pool.table:
		if d.lost:
			continue
		var at := centre + d.landing_position() * lip
		var tint := ThemeColors.INK
		if d.locked:
			tint = ThemeColors.LOCKED
		elif d.zone == Throw.Zone.RAIL:
			tint = ThemeColors.DECLARED
		if d.bitter:
			tint = ThemeColors.BITTER
		draw_circle(at, 15.0, ThemeColors.BACKGROUND)
		draw_arc(at, 15.0, 0.0, TAU, 24, tint, 2.0)
		if d.is_cocked():
			draw_arc(at, 19.0, 0.0, TAU, 24, ThemeColors.PLAYER, 1.0)
		_label(at + Vector2(-4, 5), str(d.value), tint)


func _label(at: Vector2, text: String, colour: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, colour)
