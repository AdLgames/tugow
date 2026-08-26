class_name NoticeButton
extends Button
## One line of an Assayer's notice: a posted offer with its price in the
## left margin.
##
## The price is the whole economy of the forge — everything is bought with
## lines off your own Ledger, and a line spent here is a line you cannot
## score later. So the cost is not a number inside a sentence; it is a
## stamped chip in the margin, read before the offer it pays for.
##
## It stays a Button with its `text` set to the offer label, because that is
## how the screen is driven and tested; the drawing is done over the top.

const ROW_HEIGHT := 62.0
const CHIP := Vector2(78, 26)

var detail: String = ""
var cost_text: String = ""
var affordable: bool = true


func _init(label: String, p_detail: String, p_cost_text: String) -> void:
	text = label
	detail = p_detail
	cost_text = p_cost_text
	custom_minimum_size = Vector2(0, ROW_HEIGHT)
	autowrap_mode = TextServer.AUTOWRAP_OFF
	# The built-in label would print underneath the notice. The text stays set
	# so the row can still be found by name.
	add_theme_color_override("font_color", Color.TRANSPARENT)
	add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	add_theme_color_override("font_disabled_color", Color.TRANSPARENT)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	# The hover tint is drawn by hand, so the redraw has to be asked for.
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var box := Rect2(Vector2.ZERO, size)
	var hot := not disabled and is_hovered()

	var paper := ThemeColors.PAPER_HI.lerp(ThemeColors.PAPER_LO, 0.30)
	if disabled:
		paper = ThemeColors.PAPER_LO.lerp(ThemeColors.BURNED, 0.30)
	elif hot:
		paper = ThemeColors.PAPER_HI.lerp(ThemeColors.LOCKED, 0.12)
	draw_rect(box, paper, true)
	draw_rect(box, Color(0.10, 0.08, 0.13, 0.16 if not hot else 0.42), false, 1.0)
	draw_rect(Rect2(0, size.y - 2, size.x, 2), Color(0.10, 0.08, 0.13, 0.12), true)

	_draw_chip(font)

	var ink := ThemeColors.PENCIL if not disabled else ThemeColors.BURNED
	var dim := Color(ink, 0.70)
	draw_string(font, Vector2(CHIP.x + 28, 27), text,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - CHIP.x - 40, 15, ink)
	draw_string(font, Vector2(CHIP.x + 28, 48), detail,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - CHIP.x - 40, 12, dim)


## Stamped and filled when you can pay it, cut as an empty outline when you
## cannot — the row still says what is on offer and what it would take.
func _draw_chip(font: Font) -> void:
	var at := Rect2(14, (ROW_HEIGHT - CHIP.y) * 0.5, CHIP.x, CHIP.y)
	if affordable and not disabled:
		draw_rect(at, ThemeColors.ADVERSARY.lerp(Color("6b2c1a"), 0.35), true)
		_chip_label(font, at, ThemeColors.INK)
	else:
		draw_rect(at, Color(ThemeColors.BURNED, 0.55), false, 1.0)
		_chip_label(font, at, ThemeColors.BURNED)


func _chip_label(font: Font, at: Rect2, ink: Color) -> void:
	var width := font.get_string_size(cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, at.position + Vector2((at.size.x - width) * 0.5, at.size.y * 0.5 + 4),
		cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
