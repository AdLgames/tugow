class_name World
extends Node2D
## The room. Three tile layers, a player, and a camera that follows.
##
## Layers, bottom to top:
##   Ground — floor. No collision, no sorting; nothing walks behind a floor.
##   Walls  — anything solid. Collision comes from the tile, not from this
##            node, so a tile is solid because you gave it a collision shape
##            in the TileSet, and only then.
##   Decor  — clutter drawn over everything. No collision.
##
## Walls and Decor are Y-sorted along with the player, so a character walking
## up the room passes behind what is above them.

## The starting room, painted in code so the project runs the moment you open
## it. Delete `_paint_starter_room()` once you are painting your own.
const ROOM := Rect2i(0, 0, 20, 14)
const CELL := 64

## Atlas coordinates in resources/tileset.tres.
const TILE_FLOOR := Vector2i(0, 0)
const TILE_FLOOR_ALT := Vector2i(1, 0)
const TILE_WALL := Vector2i(2, 0)
const SOURCE := 0

@onready var ground: TileMapLayer = $Ground
@onready var walls: TileMapLayer = $Walls
@onready var decor: TileMapLayer = $Decor
@onready var player: Player = $Player


func _ready() -> void:
	if ground.get_used_cells().is_empty() and walls.get_used_cells().is_empty():
		_paint_starter_room()
	_place_player()


## A plain walled room, so there is something to walk around in before any
## tiles have been painted by hand.
func _paint_starter_room() -> void:
	for y in range(ROOM.position.y - 1, ROOM.end.y + 1):
		for x in range(ROOM.position.x - 1, ROOM.end.x + 1):
			var at := Vector2i(x, y)
			var inside := ROOM.has_point(at)
			if inside:
				var alt := (x + y) % 2 == 0
				ground.set_cell(at, SOURCE, TILE_FLOOR_ALT if alt else TILE_FLOOR)
			else:
				walls.set_cell(at, SOURCE, TILE_WALL)


## Drop the player in the middle of whatever has been painted.
func _place_player() -> void:
	var used := ground.get_used_rect()
	if used.size == Vector2i.ZERO:
		used = ROOM
	var middle := used.position + used.size / 2
	player.global_position = Vector2(middle) * float(CELL) + Vector2(CELL, CELL) * 0.5


## Which cell a point in the world is in. Handy for anything that needs to
## reason about the grid rather than about pixels.
func cell_at(world_position: Vector2) -> Vector2i:
	return ground.local_to_map(ground.to_local(world_position))


## Is that cell blocked? A cell is solid because the tile in it carries a
## collision shape, so this asks the Walls layer rather than keeping a
## second list that could disagree with it.
func is_blocked(cell: Vector2i) -> bool:
	return walls.get_cell_source_id(cell) != -1
