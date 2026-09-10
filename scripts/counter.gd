class_name Counter
extends Node2D
## A run of shop counter, any number of pieces long, along either axis.
##
## Built from Props rather than one wide sprite, so the player sorts against
## the piece they are actually standing behind rather than against the whole
## run — walk up beside a six-piece counter and only the part above you
## should hide you.
##
## A counter is exactly the thing you want to walk behind, so it can never be
## tiles: a tile in a Y-sorted layer never draws in front of a sibling node.

const PROP_SCENE := preload("res://scenes/prop.tscn")

enum Axis { ACROSS, DOWN }

## How many pieces long, ends included. Two is both ends and no middle.
@export_range(1, 40) var length: int = 4:
	set(value):
		length = maxi(1, value)
		rebuild()

## Which way the run goes. Match it to how the art is drawn: a piece capped
## along its top and bottom edges is a run that goes DOWN.
@export var axis: Axis = Axis.DOWN:
	set(value):
		axis = value
		rebuild()

## The capped piece the run starts with — the top of a DOWN run, the left of
## an ACROSS one.
@export var start_texture: Texture2D:
	set(value):
		start_texture = value
		rebuild()

@export var middle_texture: Texture2D:
	set(value):
		middle_texture = value
		rebuild()

@export var end_texture: Texture2D:
	set(value):
		end_texture = value
		rebuild()

## Whole art height, so a counter seen from above collides across all of
## itself rather than along a strip at its base. Turn it off for a run of
## something you see the side of, like shelving.
@export var flat_on_the_floor: bool = true:
	set(value):
		flat_on_the_floor = value
		rebuild()


func _ready() -> void:
	rebuild()


## Throw the pieces away and lay them out again. Cheap enough to do on every
## inspector change, which is what makes length usable as a slider.
func rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.free()
	var step := _step()
	for i in length:
		var piece: Prop = PROP_SCENE.instantiate()
		piece.texture = _texture_for(i)
		piece.position = step * i
		add_child(piece)
		# After add_child, so the piece's own nodes exist and the size it
		# took from its art is the one being overridden.
		if flat_on_the_floor:
			piece.footprint = piece.height


## How far apart the pieces sit: the size of the art itself, so pieces butt
## up against each other however big they are drawn.
func _step() -> Vector2:
	var art := middle_texture if middle_texture != null else start_texture
	if art == null:
		return Vector2(World.CELL, 0) if axis == Axis.ACROSS else Vector2(0, World.CELL)
	var image := art.get_image()
	var solid := Rect2i(Vector2i.ZERO, art.get_size()) if image == null \
		else image.get_used_rect()
	return Vector2(solid.size.x, 0) if axis == Axis.ACROSS else Vector2(0, solid.size.y)


func _texture_for(index: int) -> Texture2D:
	if index == 0 and start_texture != null:
		return start_texture
	if index == length - 1 and length > 1 and end_texture != null:
		return end_texture
	return middle_texture if middle_texture != null else start_texture
