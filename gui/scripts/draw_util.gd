@tool
class_name DrawUtil
extends RefCounted

## Drawing primitives Godot does not ship.
##
## Two of the design's building blocks have no direct equivalent: a rounded
## rectangle filled with a vertical gradient (the panel casting) and an inset
## shadow (the recessed glass). Both are done here by scanline, insetting each
## row by however much the corner radius eats at that height. That is exact,
## it costs one loop over the control's height, and it avoids a shader for what
## amounts to eight units of luminance.


## How far a rounded corner cuts into the row at vertical offset `dy` from the
## nearest end of the rect. Zero once past the radius.
static func _corner_inset(dy: float, radius: float) -> float:
	if radius <= 0.0 or dy >= radius:
		return 0.0
	var d := radius - dy
	return radius - sqrt(maxf(radius * radius - d * d, 0.0))


## A rounded rectangle filled top-to-bottom with a gradient.
static func rounded_vertical_gradient(canvas: CanvasItem, rect: Rect2, radius: float,
		top: Color, bottom: Color) -> void:
	var height := rect.size.y
	if height <= 0.0 or rect.size.x <= 0.0:
		return
	var rows := int(ceil(height))
	for row in rows:
		var y := rect.position.y + float(row)
		var dy_top := float(row)
		var dy_bottom := height - float(row) - 1.0
		var inset := maxf(_corner_inset(dy_top, radius), _corner_inset(dy_bottom, radius))
		var t := float(row) / maxf(height - 1.0, 1.0)
		canvas.draw_rect(
			Rect2(rect.position.x + inset, y, rect.size.x - inset * 2.0, 1.0),
			top.lerp(bottom, t), true)


## A one-pixel highlight along the top edge, following the corner radius. This
## is the lit edge of the casting, and it is most of what makes the panel read
## as a physical object rather than a rectangle.
static func top_bevel(canvas: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	var inset := _corner_inset(0.0, radius)
	canvas.draw_rect(
		Rect2(rect.position.x + inset + radius * 0.35, rect.position.y,
			rect.size.x - (inset + radius * 0.35) * 2.0, 1.0),
		color, true)


## An inset shadow: the dark halo a recessed panel casts on its own inside
## edge. Drawn as concentric one-pixel frames with falling alpha.
static func inset_shadow(canvas: CanvasItem, rect: Rect2, depth: float, color: Color) -> void:
	var steps := int(ceil(depth))
	for step in steps:
		var t := float(step) / maxf(depth, 1.0)
		var alpha := color.a * (1.0 - t) * (1.0 - t)
		if alpha <= 0.002:
			continue
		var shade := Color(color.r, color.g, color.b, alpha)
		var frame := Rect2(
			rect.position.x + float(step), rect.position.y + float(step),
			rect.size.x - float(step) * 2.0, rect.size.y - float(step) * 2.0)
		if frame.size.x <= 0.0 or frame.size.y <= 0.0:
			return
		canvas.draw_rect(frame, shade, false, 1.0)


## A dashed line. `draw_dashed_line` exists in Godot 4 but always starts a dash
## at the origin, which makes two parallel dashed lines march in step and read
## as a grid. This one takes a phase.
static func dashed_line(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color,
		width: float, dash: float, gap: float, phase := 0.0) -> void:
	var span := from.distance_to(to)
	if span <= 0.0:
		return
	var direction := (to - from) / span
	var cursor := fmod(phase, dash + gap)
	while cursor < span:
		var start := maxf(cursor, 0.0)
		var finish := minf(cursor + dash, span)
		if finish > start:
			canvas.draw_line(from + direction * start, from + direction * finish, color, width)
		cursor += dash + gap


## Text drawn with the baseline at `position`, matching how the prototype's
## canvas `fillText` places it. Godot's `draw_string` wants a rect and its own
## alignment, so every call site would otherwise carry the same fudge.
enum Anchor { LEFT, CENTRE, RIGHT }


static func text(canvas: CanvasItem, font: Font, size: int, position: Vector2, content: String,
		color: Color, anchor := Anchor.LEFT) -> void:
	if content.is_empty():
		return
	var width := font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var x := position.x
	match anchor:
		Anchor.CENTRE:
			x -= width * 0.5
		Anchor.RIGHT:
			x -= width
	canvas.draw_string(font, Vector2(x, position.y), content,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


## Letterspaced uppercase, the design's field-label treatment. Godot has no
## tracking control, so the string is drawn a glyph at a time.
static func tracked_text(canvas: CanvasItem, font: Font, size: int, position: Vector2,
		content: String, color: Color, tracking: float) -> void:
	var x := position.x
	for index in content.length():
		var glyph := content[index]
		canvas.draw_string(font, Vector2(x, position.y), glyph,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
		x += font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x + tracking


static func tracked_width(font: Font, size: int, content: String, tracking: float) -> float:
	var width := 0.0
	for index in content.length():
		width += font.get_string_size(content[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x + tracking
	return maxf(width - tracking, 0.0)
