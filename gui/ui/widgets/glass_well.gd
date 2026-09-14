@tool
class_name GlassWell
extends MarginContainer

## A recessed display cut into the casting: near-black glass, a hairline
## border, and the shadow the cut-out casts on its own inside edge.
##
## Two depths, matching the design. The shallow one holds text readouts (the
## source filename, the export path); the deep one holds a plot, and is a
## shade darker with a heavier inset so the traces sit at the bottom of a well
## rather than on a card.

const RADIUS := 3.0

@export var deep := false:
	set(value):
		deep = value
		queue_redraw()

## Plots draw edge to edge; readouts are inset.
@export var inset_content := true:
	set(value):
		inset_content = value
		_apply_margins()


func _init() -> void:
	_apply_margins()


func _ready() -> void:
	_apply_margins()


func _apply_margins() -> void:
	var horizontal := 10 if inset_content else 0
	var vertical := 9 if inset_content else 0
	add_theme_constant_override(&"margin_left", horizontal)
	add_theme_constant_override(&"margin_right", horizontal)
	add_theme_constant_override(&"margin_top", vertical)
	add_theme_constant_override(&"margin_bottom", vertical)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)

	var box := StyleBoxFlat.new()
	box.bg_color = ModalTheme.GLASS_DEEP if deep else ModalTheme.GLASS
	box.set_border_width_all(1)
	box.border_color = ModalTheme.GLASS_BORDER
	box.set_corner_radius_all(int(RADIUS))
	draw_style_box(box, rect)

	DrawUtil.inset_shadow(self, rect.grow(-1.0), 14.0 if deep else 8.0,
			Color(0, 0, 0, 0.6 if deep else 0.5))
