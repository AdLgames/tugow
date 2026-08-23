class_name DiceTray
extends Control
## Five dice, countable. On the felt they overlap, cock, and go into the dirt;
## this strip is the roster — one entry per die drawn this turn, in a fixed
## order, so the player can always count their own dice and see the state of
## each without reading the log.

const ENTRY := Vector2(150, 54)

var game: Game = null


func _init() -> void:
	custom_minimum_size = Vector2(800, ENTRY.y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(p_game: Game) -> void:
	game = p_game
	queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var font := ThemeDB.fallback_font
	var index := 0
	for die in game.pool.table:
		var at := Vector2(index * (ENTRY.x + 8), 0)
		index += 1
		var state := _state_of(die)
		var tint: Color = state[1]
		draw_rect(Rect2(at, ENTRY), Color(ThemeColors.PANEL, 0.85), true)
		draw_rect(Rect2(at, ENTRY), Color(tint, 0.55), false, 1.0)
		draw_string(font, at + Vector2(10, 20), die.die_name.to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ThemeColors.INK)
		draw_string(font, at + Vector2(10, 42), state[0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)
		var value := "—" if die.lost or die.value <= 0 else str(die.value)
		draw_string(font, at + Vector2(ENTRY.x - 34, 38), value,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, tint)


func _state_of(die: Die) -> Array:
	if die.lost:
		return ["in the dirt", ThemeColors.ADVERSARY]
	if die.locked:
		return [Lore.LOCKED_TAG.to_lower(), ThemeColors.LOCKED]
	if die.is_cocked():
		return ["cocked — both", ThemeColors.PLAYER]
	if die.zone == Throw.Zone.RAIL:
		return ["on the rail x2", ThemeColors.DECLARED]
	if die.bitter:
		return ["bitter", ThemeColors.BITTER]
	return ["in the pot", ThemeColors.INK_DIM]
