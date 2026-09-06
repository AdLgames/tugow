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
## A 64x128 post. Twice as tall as its cell, so it needs a texture origin to
## rise out of it and a y-sort origin to sort by its base — see the README.
const TILE_POST := Vector2i(4, 0)
const SOURCE := 0

const PROP_SCENE := preload("res://scenes/prop.tscn")

@onready var ground: TileMapLayer = $Ground
@onready var walls: TileMapLayer = $Walls
@onready var decor: TileMapLayer = $Decor
## Everything that has to sort against the player lives in here, including
## the player. See the note on Prop for why this is not a tile layer.
@onready var props: Node2D = $Props
@onready var player: Player = $Props/Player


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
	# A couple of posts inside the room. They are props rather than tiles, so
	# the player passes behind them.
	for x in [6, 13]:
		add_prop(Vector2i(x, 6))


## Drop the player in the middle of whatever has been painted.
func _place_player() -> void:
	var used := ground.get_used_rect()
	if used.size == Vector2i.ZERO:
		used = ROOM
	var middle := used.position + used.size / 2
	player.global_position = Vector2(middle) * float(CELL) + Vector2(CELL, CELL) * 0.5


## Stand a prop on a cell. Its origin goes at the bottom of the cell, so it
## sorts by where it touches the floor.
func add_prop(cell: Vector2i, height: float = 128.0) -> Prop:
	var prop: Prop = PROP_SCENE.instantiate()
	prop.height = height
	prop.position = Vector2(cell.x * CELL + CELL * 0.5, cell.y * CELL + CELL)
	props.add_child(prop)
	return prop


## Which cell a point in the world is in. Handy for anything that needs to
## reason about the grid rather than about pixels.
func cell_at(world_position: Vector2) -> Vector2i:
	return ground.local_to_map(ground.to_local(world_position))


## Is that cell blocked? A cell is solid because the tile in it carries a
## collision shape, so this asks the Walls layer rather than keeping a
## second list that could disagree with it.
func is_blocked(cell: Vector2i) -> bool:
	return walls.get_cell_source_id(cell) != -1
