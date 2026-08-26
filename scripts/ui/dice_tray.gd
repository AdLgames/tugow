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
		_draw_slip(font, Vector2(index * (ENTRY.x + 8), 0), die, index)
		index += 1


## One betting slip per die, in the Ledger's paper: the tray is your own note
## about your own dice, not a readout of them.
func _draw_slip(font: Font, at: Vector2, die: Die, index: int) -> void:
	var state := _state_of(die)
	var tint: Color = state[1]

	# Paper, each stub torn from the same block but not quite the same tone.
	var tone := ThemeColors.PAPER_HI.lerp(ThemeColors.PAPER_LO, 0.18 + 0.12 * float(index % 3))
	draw_rect(Rect2(at, ENTRY), tone, true)
	draw_rect(Rect2(at + Vector2(0, ENTRY.y - 3), Vector2(ENTRY.x, 3)),
		Color(0.10, 0.08, 0.13, 0.16), true)
	# A deckled bottom edge, so it reads as torn rather than cut.
	for notch in range(0, int(ENTRY.x), 9):
		var depth := 2.0 + float((notch + index * 7) % 3)
		draw_rect(Rect2(at + Vector2(notch, ENTRY.y - depth), Vector2(5, depth)),
			ThemeColors.BACKGROUND, true)

	draw_string(font, at + Vector2(10, 20), die.die_name.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("241c14"))
	draw_string(font, at + Vector2(10, 42), state[0],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)

	var value := "—" if die.lost or die.value <= 0 else str(die.value)
	draw_string(font, at + Vector2(ENTRY.x - 34, 38), value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ThemeColors.PENCIL if not die.lost else tint)

	# A bitter die is a condition of the die, not a place it is sitting, so it
	# is marked on the slip rather than written on the state line.
	if die.bitter:
		draw_circle(at + Vector2(ENTRY.x - 12, 12), 5.0, Color(ThemeColors.BITTER, 0.85))
	# Staked dice get a seal.
	if die.locked:
		draw_circle(at + Vector2(ENTRY.x - 12, 12), 6.0, Color(ThemeColors.LOCKED, 0.9))


func _state_of(die: Die) -> Array:
	if die.lost:
		return ["in the dirt", ThemeColors.ADVERSARY]
	if die.locked:
		return [Lore.LOCKED_TAG.to_lower(), Color("6b4a1e")]
	if die.is_cocked():
		return ["leaning — reads both", Color("2f5c39")]
	if die.zone == Throw.Zone.RAIL:
		return ["on the rail x2", Color("8e4a1e")]
	return ["in the pot", Color(0.10, 0.08, 0.13, 0.55)]
