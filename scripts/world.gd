class_name World
extends Node2D
## The room. Tile layers, a player, props, and the lights.
##
## Layers, bottom to top:
##   Ground — the floor, and the walls painted into it.
##   Walls  — anything solid you would rather keep off the floor layer.
##   Decor  — clutter drawn over everything.
##
## Between Ground and Walls sits Sun, which draws the daylight shadow the
## walls throw across the floor. See scripts/sun.gd for why that is drawn
## rather than lit.
##
## Solidity comes from the tile, never from the layer: a tile blocks you
## because it carries a collision shape in the TileSet, and casts a shadow
## because it carries an occluder. Both are applied by
## tools/apply_tile_roles.gd, which decides from the texture's filename.
## That means a wall painted onto Ground is just as solid as one on Walls,
## which is what you want when the map was painted by hand.
##
## Walls, Decor and Props are Y-sorted, so a character walking up the room
## passes behind what is above them.

## Pixel art is kept at its native size and the camera is zoomed instead, so
## nothing is ever resampled. Matches tile_size in resources/tileset.tres.
const CELL := 16

const PROP_SCENE := preload("res://scenes/prop.tscn")
const LAMP_SCENE := preload("res://scenes/lamp.tscn")

## How far to search for somewhere to stand when the player has been left on
## top of a wall. Cells, in a widening ring.
const SPAWN_SEARCH := 12

@onready var ground: TileMapLayer = $Ground
@onready var sun: Sun = $Sun
@onready var walls: TileMapLayer = $Walls
@onready var decor: TileMapLayer = $Decor
## Everything that has to sort against the player lives in here, including
## the player. See the note on Prop for why this is not a tile layer.
@onready var props: Node2D = $Props
@onready var lights: Node2D = $Lights
## Darkens the whole scene so the lamps have something to light. Turn its
## colour up to white and the room reads as daylight again.
@onready var night: CanvasModulate = $Night
@onready var player: Player = $Props/Player


func _ready() -> void:
	# The sun draws between the floor and everything standing on it, which is
	# why it is a sibling sitting after Ground rather than a child of it.
	sun.paint(self)
	_free_the_player()


## Every tile layer, in draw order. Anything that walks the map should ask
## all of them rather than guessing which one a wall was painted on.
func layers() -> Array[TileMapLayer]:
	return [ground, walls, decor]


## Which cell a point in the world is in.
func cell_at(world_position: Vector2) -> Vector2i:
	return ground.local_to_map(ground.to_local(world_position))


## The middle of a cell, in world coordinates.
func centre_of(cell: Vector2i) -> Vector2:
	return ground.to_global(ground.map_to_local(cell))


## Is that cell blocked? A cell is solid because the tile in it carries a
## collision shape, so this asks the tiles rather than keeping a second list
## that could disagree with them.
func is_blocked(cell: Vector2i) -> bool:
	for layer in layers():
		var data := layer.get_cell_tile_data(cell)
		if data == null:
			continue
		if data.get_collision_polygons_count(0) > 0:
			return true
	return false


## Does that cell have floor under it? Standing off the edge of the map is
## not blocked, but it is not somewhere to spawn either.
func is_floor(cell: Vector2i) -> bool:
	if is_blocked(cell):
		return false
	for layer in layers():
		if layer.get_cell_source_id(cell) != -1:
			return true
	return false


## Stand a prop on a cell. Its origin goes at the bottom of the cell, so it
## sorts by where it touches the floor.
func add_prop(cell: Vector2i, height: float = 32.0) -> Prop:
	var prop: Prop = PROP_SCENE.instantiate()
	prop.height = height
	prop.position = centre_of(cell) + Vector2(0, CELL * 0.5)
	props.add_child(prop)
	# The sun draws prop shadows as well as wall ones, so it has to be told.
	sun.queue_redraw()
	return prop


## Hang a light over a cell. Lights sit in their own container rather than
## under Props, because a light has no size and nothing sorts against it.
func add_lamp(cell: Vector2i, radius: float = 90.0) -> Lamp:
	var lamp: Lamp = LAMP_SCENE.instantiate()
	lamp.position = centre_of(cell)
	lights.add_child(lamp)
	lamp.radius = radius
	return lamp


## Walls are solid now, so a player left standing inside one would be stuck
## against the collider from the first frame. Leave them where the scene puts
## them if that is somewhere to stand, and otherwise walk outwards until it is.
func _free_the_player() -> void:
	var start := cell_at(player.global_position)
	if is_floor(start):
		return
	player.global_position = centre_of(_nearest_floor(start, start))


## The closest cell with floor and no wall, searched in widening rings so the
## player never teleports further than they have to. Falls back to `absent`
## when the search finds nothing, rather than handing back a null the caller
## has to remember to check.
func _nearest_floor(from: Vector2i, absent: Vector2i) -> Vector2i:
	for ring in range(1, SPAWN_SEARCH + 1):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var at := from + Vector2i(dx, dy)
				if is_floor(at):
					return at
	return absent
