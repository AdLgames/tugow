class_name Prop
extends StaticBody2D
## A tall thing that stands in the room — a post, a counter, a shelf.
##
## Props are scenes rather than tiles, and that is deliberate. Tiles in a
## Y-sorted TileMapLayer sort correctly against *each other*, but the layer
## does not interleave with its sibling nodes, so a tile can never be drawn
## in front of the player. A prop is an ordinary node in the same Y-sorted
## container as the player, so it sorts against them properly.
##
## Its origin is at its base, which is what makes the sort read right: a
## character whose feet are lower down is nearer the camera.

## How deep the footprint is. A prop blocks and shadows the patch of floor it
## stands on, not its whole height — a lamp behind a tall shelf should throw
## the shelf's shadow across the floor, not a wall of darkness.
const FOOTPRINT := 7.0

@export var height: float = 32.0:
	set(value):
		height = maxf(1.0, value)
		queue_redraw()

@export var width: float = 16.0:
	set(value):
		width = maxf(1.0, value)
		_fit()

@export var tint: Color = Color("6e604e")

@onready var base: CollisionShape2D = $Base
@onready var shadow: LightOccluder2D = $Shadow


func _ready() -> void:
	_fit()
	queue_redraw()


## Collision and shadow are both derived from `width`, so a wider prop is
## wider in every sense rather than only on screen.
func _fit() -> void:
	if base == null or shadow == null:
		return
	var rect := base.shape as RectangleShape2D
	if rect != null:
		# Unique, or every prop in the scene resizes together.
		rect = rect.duplicate()
		rect.size = Vector2(width - 1.0, FOOTPRINT)
		base.shape = rect
	base.position = Vector2(0, -FOOTPRINT * 0.5)
	var half := width * 0.5
	var occluder := OccluderPolygon2D.new()
	occluder.polygon = PackedVector2Array([
		Vector2(-half, -FOOTPRINT), Vector2(half, -FOOTPRINT),
		Vector2(half, 0), Vector2(-half, 0),
	])
	shadow.occluder = occluder


## Placeholder art. Replace with a Sprite2D whose offset puts the image above
## the origin, and delete this.
func _draw() -> void:
	var body := Rect2(-width * 0.5, -height, width, height)
	draw_rect(body, tint)
	draw_rect(Rect2(body.position, Vector2(width, 4)), tint.lightened(0.28))
	draw_rect(body, tint.darkened(0.45), false, 1.0)
