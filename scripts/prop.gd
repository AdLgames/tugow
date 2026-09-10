class_name Prop
extends StaticBody2D
## A thing that stands on the floor — a counter, a shelf, a table.
##
## Props are scenes rather than tiles, and that is deliberate. Tiles in a
## Y-sorted TileMapLayer sort correctly against *each other*, but the layer
## does not interleave with its sibling nodes, so a tile can never be drawn
## in front of the player. A prop is an ordinary node in the same Y-sorted
## container as the player, so it sorts against them properly.
##
## Its origin is at its base, which is what makes the sort read right: a
## character whose feet are lower down is nearer the camera. Give it a
## `texture` and the art is placed standing on that origin; leave it empty
## and you get a placeholder box the same size.

## How deep the footprint is when nothing says otherwise. A shelf blocks and
## shadows the patch of floor it stands on, not its whole height — a lamp
## behind one should throw its shadow across the floor, not a wall of
## darkness.
const FOOTPRINT := 7.0

## The art, drawn standing on the origin. Its size sets `width` and `height`,
## so a 16 x 32 image is a prop one cell wide and two tall with nothing else
## to fill in.
@export var texture: Texture2D:
	set(value):
		texture = value
		_fit()

@export var height: float = 32.0:
	set(value):
		height = maxf(1.0, value)
		queue_redraw()

@export var width: float = 16.0:
	set(value):
		width = maxf(1.0, value)
		_fit()

## How deep the prop is on the floor, in pixels. The default suits something
## you see the side of — a shelf, a crate, a lamp post. Set it to `height`
## for something seen from above whose whole shape is on the floor, like a
## counter or a table, or the player will walk through most of it.
@export var footprint: float = FOOTPRINT:
	set(value):
		footprint = clampf(value, 1.0, 4096.0)
		_fit()

## Only used by the placeholder box, so it does nothing once there is art.
@export var tint: Color = Color("6e604e")

@onready var art: Sprite2D = $Art
@onready var base: CollisionShape2D = $Base
@onready var shadow: LightOccluder2D = $Shadow

## `texture` writes to `width`, whose setter fits again. Without this the two
## call each other until the stack runs out.
var _fitting := false


func _ready() -> void:
	_fit()
	queue_redraw()


## Collision, shadow and art are all derived from the same numbers, so a
## wider prop is wider in every sense rather than only on screen.
func _fit() -> void:
	if art == null or base == null or shadow == null or _fitting:
		return
	_fitting = true

	art.texture = texture
	art.visible = texture != null
	if texture != null:
		# The art's own size, not the canvas it was drawn on. A 20-pixel
		# counter centred on a 32-pixel image would otherwise collide six
		# pixels of nothing on either side.
		var solid := _art_bounds()
		width = solid.size.x
		height = solid.size.y
		# Drawn from its top-left, lifted so the bottom of the art sits on
		# the origin — the same place the collider and the shadow start from.
		art.centered = false
		art.offset = Vector2(
			-float(texture.get_width()) * 0.5,
			-float(texture.get_height()) + (texture.get_height() - solid.end.y))

	var rect := base.shape as RectangleShape2D
	if rect != null:
		# Unique, or every prop in the scene resizes together.
		rect = rect.duplicate()
		rect.size = Vector2(width - 1.0, footprint)
		base.shape = rect
	base.position = Vector2(0, -footprint * 0.5)

	var half := width * 0.5
	var occluder := OccluderPolygon2D.new()
	occluder.polygon = PackedVector2Array([
		Vector2(-half, -footprint), Vector2(half, -footprint),
		Vector2(half, 0), Vector2(-half, 0),
	])
	shadow.occluder = occluder

	_fitting = false
	queue_redraw()


## Placeholder box, drawn only while there is no art. It is the same size as
## the real thing will be, so a room blocked out with empty props already
## reads at the right scale.
func _draw() -> void:
	if texture != null:
		return
	var body := Rect2(-width * 0.5, -height, width, height)
	draw_rect(body, tint)
	draw_rect(Rect2(body.position, Vector2(width, 4)), tint.lightened(0.28))
	draw_rect(body, tint.darkened(0.45), false, 1.0)


## The opaque part of the art, in pixels. Pixel art is usually drawn on a
## square canvas with room to spare, and the transparent margin is not part
## of the object.
func _art_bounds() -> Rect2:
	var image := texture.get_image()
	if image == null:
		return Rect2(Vector2.ZERO, texture.get_size())
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return Rect2(Vector2.ZERO, texture.get_size())
	return Rect2(used)
