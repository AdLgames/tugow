class_name LedgerView
extends Control
## The Ledger: paper, not panel. All thirteen lines always visible, foxed and
## stained, and the second most important object on screen after the dice.
##
## The critical distinction is that your marks are pencil and his are ink —
## a player should be able to tell how much of the Ledger they have lost from
## across the room.
## Source: docs/design-system/BUILD_BRIEF_table_scene.md, "The Ledger".

signal line_pressed(box: int)
signal line_hovered(box: int)

const WIDTH := 610.0
const ROW_HEIGHT := 28.0
const HEADER := 74.0
const PAD := 20.0
## Previews sit in their own column, inboard of the score column, so a
## provisional number is never mistaken for a settled one — and never falls
## off the edge of the paper.
const MARGIN_SHIFT := -66.0

var game: Game = null
## Set when the only legal move left is settling a line.
var urgent: bool = false
var _hover_row: int = -1


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, HEADER + ROW_HEIGHT * Scoring.BOX_COUNT + PAD)
	size = custom_minimum_size
	rotation = deg_to_rad(-1.1)
	mouse_filter = Control.MOUSE_FILTER_STOP


func bind(p_game: Game) -> void:
	game = p_game
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var row := _row_at(event.position.y)
		if row != _hover_row:
			_hover_row = row
			line_hovered.emit(row)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var row := _row_at(event.position.y)
		if row >= 0:
			line_pressed.emit(row)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_row = -1
		line_hovered.emit(-1)
		queue_redraw()


func _row_at(y: float) -> int:
	var row := int((y - HEADER) / ROW_HEIGHT)
	if row < 0 or row >= Scoring.BOX_COUNT:
		return -1
	return row


func _draw() -> void:
	_draw_paper()
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(PAD, 30), Lore.CARD.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("241c14"))
	if game != null:
		draw_string(font, Vector2(PAD, 52),
			("SETTLE A LINE — %s" % Lore.lines_owed(game.card.open_count())) if urgent
				else ("THIRTEEN LINES · %s" % Lore.lines_owed(game.card.open_count())),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.10, 0.08, 0.13, 0.65))
	if game == null:
		return

	var declared := -1
	if game.adversary != null:
		declared = game.adversary.declared_box
	var best := 0
	if game.phase == Game.Phase.TURN:
		for box in game.card.open_boxes():
			best = maxi(best, game.preview(box))

	for box in Scoring.BOX_COUNT:
		_draw_line(box, font, declared, best)


func _draw_paper() -> void:
	# Foxed and stained: three washes over a warm sheet.
	draw_rect(Rect2(Vector2.ZERO, size), ThemeColors.PAPER_MID, true)
	var steps := 18
	for i in steps:
		var t := float(i) / float(steps - 1)
		draw_rect(Rect2(0, size.y * float(i) / steps, size.x, size.y / steps + 1),
			ThemeColors.PAPER_HI.lerp(ThemeColors.PAPER_LO, t), true)
	draw_circle(Vector2(size.x * 0.12, size.y * 0.08), 90.0, Color(0.72, 0.65, 0.50, 0.16))
	draw_circle(Vector2(size.x * 0.88, size.y * 0.82), 110.0, Color(0.66, 0.58, 0.42, 0.14))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35), false, 2.0)
	if urgent:
		draw_rect(Rect2(Vector2.ZERO, size).grow(3), Color(ThemeColors.LOCKED, 0.75), false, 3.0)


func _draw_line(box: int, font: Font, declared: int, best: int) -> void:
	var top := HEADER + ROW_HEIGHT * box
	var row := Rect2(0, top, size.x, ROW_HEIGHT)
	var state: int = game.card.states[box]
	var open := state == Scorecard.State.OPEN
	var scratched := state == Scorecard.State.PLAYER and game.card.points[box] == 0

	# His claims bring a cold wash onto the paper.
	if state == Scorecard.State.ADVERSARY:
		draw_rect(row, Color(0.10, 0.16, 0.22, 0.10), true)
	elif state == Scorecard.State.BURNED:
		for i in range(0, int(size.x), 12):
			draw_line(Vector2(i, top), Vector2(i + 6, top + ROW_HEIGHT), Color(0.10, 0.08, 0.13, 0.07), 2.0)
	if box == declared and open:
		draw_rect(row, Color(ThemeColors.DECLARED, 0.16), true)
		draw_rect(row, Color(ThemeColors.ADVERSARY, 0.36), false, 1.0)
	elif open and box == _hover_row and game.phase == Game.Phase.TURN:
		draw_rect(row, Color(0.10, 0.08, 0.13, 0.06), true)
	draw_line(Vector2(PAD * 0.5, top + ROW_HEIGHT), Vector2(size.x - PAD * 0.5, top + ROW_HEIGHT),
		Color(0.10, 0.08, 0.13, 0.12), 1.0)

	var baseline := top + 20.0
	if box == declared and open:
		draw_string(font, Vector2(8, baseline), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			ThemeColors.SCRATCH_RED)

	draw_string(font, Vector2(PAD, baseline), Scoring.box_name(box).to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("241c14"))
	var name_width := font.get_string_size(Scoring.box_name(box).to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2(PAD + name_width + 10, baseline), Scoring.box_rule(box),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.10, 0.08, 0.13, 0.62))

	_draw_value(box, font, baseline, top, state, open, scratched, best)


func _draw_value(box: int, font: Font, baseline: float, top: float,
		state: int, open: bool, scratched: bool, best: int) -> void:
	if open:
		_draw_preview(box, font, baseline, best)
		return

	# Settled: committed weight, in the score column.
	var text := ""
	var colour := ThemeColors.PENCIL
	var bold := false
	if state == Scorecard.State.BURNED:
		text = "burned"
		colour = Color(0.10, 0.08, 0.13, 0.40)
	elif state == Scorecard.State.ADVERSARY:
		# Ink. Near-black, bold, and it bleeds through the paper.
		text = "him %d" % game.card.points[box]
		colour = ThemeColors.HIS_INK
		bold = true
	else:
		text = "you %d" % game.card.points[box]
		colour = ThemeColors.SCRATCH_RED if scratched else ThemeColors.PENCIL

	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var at := Vector2(size.x - PAD - width, baseline)
	if bold:
		draw_string(font, at + Vector2(0.6, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(colour, 0.55))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, colour)

	# A written zero is a sacrifice, not a failure: strike it hard.
	if scratched:
		draw_line(Vector2(24, top + 15), Vector2(size.x - 110, top + 13),
			Color("4a4952"), 3.0)
	# A burned line is a scorch hole. Nothing written, nothing writable.
	if state == Scorecard.State.BURNED:
		var centre := Vector2(size.x * 0.44, top + ROW_HEIGHT * 0.5)
		draw_circle(centre, 32.0, Color(ThemeColors.SCORCH, 0.30))
		draw_circle(centre, 20.0, Color("120c08"))


## Nothing here is written yet: ghosted pencil, out in the margin, and a zero
## barely there at all — six zeros in the score column read as real entries.
func _draw_preview(box: int, font: Font, baseline: float, best: int) -> void:
	if game.phase != Game.Phase.TURN:
		return
	var value := game.preview(box)
	var text := str(value) if value > 0 else "—"
	var colour := Color(ThemeColors.PENCIL, 0.42)
	var size_px := 12
	if value <= 0:
		colour = Color(ThemeColors.PENCIL, 0.16)
	elif value == best:
		colour = Color("6b4a1e")
		size_px = 14
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	# The margin, not the column: settled scores own the column.
	draw_string(font, Vector2(size.x - PAD - width + MARGIN_SHIFT, baseline), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, colour)
	if value > 0 and value == best:
		draw_line(Vector2(size.x - PAD + MARGIN_SHIFT - width - 8, baseline + 3),
			Vector2(size.x - PAD + MARGIN_SHIFT + 2, baseline + 3), Color("6b4a1e", 0.5), 1.0)

