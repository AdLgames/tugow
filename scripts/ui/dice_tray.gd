class_name DiceTray
extends Control
## Five dice, countable. On the felt they overlap, cock, and go into the dirt;
## this strip is the roster — one entry per die drawn this turn, in a fixed
## order, so the player can always count their own dice and see the state of
## each without reading the log.
##
## Every state a die can be in gets its own paper. The three that decide a
## turn — sealed for the night, doubled on the rail, gone into the dirt — must
## never be mistaken for one another or for a die that has simply not been
## thrown yet, so each carries a different tone, a different edge and a
## different mark rather than only a different word.

const ENTRY := Vector2(150, 56)
const GAP := 8.0
const PAD := 10.0

var game: Game = null


func _init() -> void:
	custom_minimum_size = Vector2(800, ENTRY.y + PAD * 2.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(p_game: Game) -> void:
	game = p_game
	queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var font := ThemeDB.fallback_font
	var count := game.pool.table.size()
	if count == 0:
		return
	_draw_tray(float(count))
	var index := 0
	for die in game.pool.table:
		_draw_slip(font, Vector2(PAD + index * (ENTRY.x + GAP), PAD), die, index)
		index += 1


## The slips sit in a tray on the rail, not loose on the lip. It is the same
## dark wood as the table edge, so the paper reads as resting on something.
func _draw_tray(count: float) -> void:
	var width := PAD * 2.0 + count * ENTRY.x + (count - 1.0) * GAP
	var box := Rect2(0, 0, width, ENTRY.y + PAD * 2.0)
	draw_rect(box.grow(2.0), ThemeColors.RAIL_EDGE, true)
	draw_rect(box, ThemeColors.RAIL_PAD, true)
	# A lit top lip, so the tray has a thickness rather than being a hole.
	draw_rect(Rect2(box.position, Vector2(box.size.x, 1.0)), Color(1, 1, 1, 0.06), true)


## One betting slip per die, in the Ledger's paper: the tray is your own note
## about your own dice, not a readout of them.
func _draw_slip(font: Font, at: Vector2, die: Die, index: int) -> void:
	var state := _state_of(die)
	var label: String = state[0]
	var tint: Color = state[1]
	var paper: Color = state[2]
	var edge: Color = state[3]

	draw_rect(Rect2(at, ENTRY), paper, true)
	draw_rect(Rect2(at + Vector2(0, ENTRY.y - 3), Vector2(ENTRY.x, 3)),
		Color(0.10, 0.08, 0.13, 0.16), true)
	# A deckled bottom edge, so it reads as torn rather than cut.
	for notch in range(0, int(ENTRY.x), 9):
		var depth := 2.0 + float((notch + index * 7) % 3)
		draw_rect(Rect2(at + Vector2(notch, ENTRY.y - depth), Vector2(5, depth)),
			ThemeColors.RAIL_PAD, true)
	if edge.a > 0.0:
		draw_rect(Rect2(at, ENTRY), edge, false, 2.0)

	var name_ink := Color("241c14") if not die.lost else ThemeColors.BURNED
	draw_string(font, at + Vector2(10, 20), die.die_name.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, ENTRY.x - 32, 13, name_ink)

	# The face is set down first so the state line knows what room is left.
	# A cocked die shows two faces and needs the width; nothing may overrun
	# into it, so the label is clipped rather than allowed to collide.
	var taken := _draw_value(font, at, die)
	draw_string(font, at + Vector2(10, 42), label,
		HORIZONTAL_ALIGNMENT_LEFT, ENTRY.x - 20 - taken, 12, tint)
	_draw_marks(at, die)


## The face, right-aligned so a three-digit face cannot run off the slip. A
## die that has not been thrown has no face at all, which is not the same as
## a die whose face was lost — the first is faint, the second is struck.
func _draw_value(font: Font, at: Vector2, die: Die) -> float:
	# Lost first, to match the order the state line reads in: a die in the
	# dirt has no face to show, whatever it was doing before it went over.
	var unthrown := die.value <= 0 and not die.lost
	var cocked := die.is_cocked() and not die.lost
	var text := "—"
	if cocked:
		text = "%d+%d" % [die.value, die.second_value]
	elif not unthrown and not die.lost:
		text = str(die.value)
	var size := 20 if cocked else 26
	var ink := ThemeColors.PENCIL
	if unthrown:
		ink = Color(ThemeColors.PENCIL, 0.30)
	elif die.lost:
		ink = ThemeColors.BURNED
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var right := at + Vector2(ENTRY.x - 10 - width, 40)
	draw_string(font, right, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	if die.lost:
		# Struck out: the face is not low, it is gone for the night.
		draw_line(right + Vector2(-3, -8), right + Vector2(width + 3, -8),
			ThemeColors.ADVERSARY, 1.5)
	return width + 6.0


## Conditions of the die, as opposed to where it is sitting. Both can be true
## at once, so they stack down the corner rather than sharing a spot.
func _draw_marks(at: Vector2, die: Die) -> void:
	var corner := at + Vector2(ENTRY.x - 12, 12)
	if die.locked:
		# A wax seal. Staking holds for the whole night, so it is stamped on
		# rather than clipped on.
		draw_circle(corner, 6.5, Color(ThemeColors.LOCKED, 0.92))
		draw_circle(corner, 3.0, Color(0.10, 0.08, 0.13, 0.30))
		corner += Vector2(0, 15)
	if die.bitter:
		draw_circle(corner, 5.0, Color(ThemeColors.BITTER, 0.85))


## Returns [label, ink, paper, edge]. Order matters: a die in the dirt cannot
## also be staked, and a staked die is sealed whatever zone it settled in.
func _state_of(die: Die) -> Array:
	var plain := ThemeColors.PAPER_HI.lerp(ThemeColors.PAPER_LO, 0.22)
	if die.lost:
		# Grey, struck, and unmistakably not paper you can still write on.
		return ["in the dirt", ThemeColors.ADVERSARY,
			ThemeColors.PAPER_LO.lerp(ThemeColors.BURNED, 0.45), Color(0, 0, 0, 0)]
	if die.value <= 0:
		# Not thrown yet: the slip is blank stock, dashed rather than torn.
		return ["in the cup", Color(0.10, 0.08, 0.13, 0.40),
			ThemeColors.PAPER_HI.lerp(ThemeColors.RAIL_PAD, 0.10), Color(0, 0, 0, 0)]
	if die.locked:
		return [Lore.LOCKED_TAG.to_lower(), Color("6b4a1e"),
			ThemeColors.PAPER_HI.lerp(ThemeColors.LOCKED, 0.22),
			Color(ThemeColors.LOCKED, 0.75)]
	if die.held:
		# Kept back from the next draw, but only for this turn, so the paper
		# is marked rather than sealed.
		return ["kept back", Color("3f5c2f"), ThemeColors.PAPER_HI.lerp(Color("6f8f52"), 0.16),
			Color("4d6b36", 0.65)]
	if die.is_cocked():
		return ["leaning", Color("2f5c39"), plain, Color(0, 0, 0, 0)]
	if die.zone == Throw.Zone.RAIL:
		return ["on the rail x2", Color("8e4a1e"), plain, Color("8e4a1e", 0.45)]
	return ["in the pot", Color(0.10, 0.08, 0.13, 0.55), plain, Color(0, 0, 0, 0)]
