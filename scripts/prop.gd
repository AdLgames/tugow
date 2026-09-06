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

@export var height: float = 128.0
@export var width: float = 64.0
@export var tint: Color = Color("6e604e")


func _ready() -> void:
	queue_redraw()


## Placeholder art. Replace with a Sprite2D whose offset puts the image above
## the origin, and delete this.
func _draw() -> void:
	var body := Rect2(-width * 0.5, -height, width, height)
	draw_rect(body, tint)
	draw_rect(Rect2(body.position, Vector2(width, 14)), tint.lightened(0.28))
	draw_rect(body, tint.darkened(0.45), false, 2.0)
