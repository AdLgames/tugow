@tool
class_name PanelModule
extends MarginContainer

## One module of the front panel.
##
## A `MarginContainer` rather than a `PanelContainer` because the casting is
## drawn here rather than by a StyleBox: StyleBoxFlat has neither a gradient
## nor a per-side border colour, and the design needs both — the casting falls
## from #2b2a26 to #232220, and its top edge is lit a full step brighter than
## the other three. A parent draws before its children, so `_draw` lands behind
## the module's contents exactly as a panel background would.

const RADIUS := 5.0

## An optional letterspaced label across the top of the module, in the design's
## small-caps treatment. Empty for modules that supply their own header row.
@export var title := "":
	set(value):
		title = value
		_apply_margins()
		queue_redraw()

@export var padding := 14:
	set(value):
		padding = value
		_apply_margins()


func _init() -> void:
	_apply_margins()


func _ready() -> void:
	_apply_margins()


func _apply_margins() -> void:
	add_theme_constant_override(&"margin_left", padding)
	add_theme_constant_override(&"margin_right", padding)
	add_theme_constant_override(&"margin_bottom", padding)
	# A titled module reserves the label's line plus the design's 11px gap.
	add_theme_constant_override(&"margin_top", padding + (18 if not title.is_empty() else 0))


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)

	# Base, border and drop shadow come from a StyleBox — it has no gradient,
	# but its shadow is one draw call where a hand-rolled stack is hundreds.
	var base := StyleBoxFlat.new()
	base.bg_color = ModalTheme.PANEL_TOP
	base.set_border_width_all(1)
	base.border_color = ModalTheme.PANEL_BORDER
	base.set_corner_radius_all(int(RADIUS))
	base.shadow_color = Color(0, 0, 0, 0.45)
	base.shadow_size = 10
	base.shadow_offset = Vector2(0, 5)
	draw_style_box(base, rect)

	# The casting's fall, laid inside the border, then the lit top edge.
	DrawUtil.rounded_vertical_gradient(self, rect.grow(-1.0), RADIUS - 1.0,
			ModalTheme.PANEL_TOP, ModalTheme.PANEL_BOTTOM)
	DrawUtil.top_bevel(self, rect, RADIUS, ModalTheme.PANEL_BEVEL)

	if not title.is_empty():
		DrawUtil.tracked_text(self, ModalTheme.sans(), 8, Vector2(padding, padding + 8),
				title.to_upper(), ModalTheme.LABEL, 2.4)
