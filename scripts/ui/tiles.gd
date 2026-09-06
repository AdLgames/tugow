class_name Tiles
extends RefCounted
## The painted tileset, and what each cell of the shop is made of.
##
## Every floor texture is an isometric diamond whose top vertex sits at the
## top of its own image; anything below the diamond is the tile's thickness
## and hangs down over the row behind. So a tile is placed by its top vertex
## and scaled to the tile width, and the art keeps whatever depth it was
## drawn with.

const FLOOR := {
	&"planks": "res://assets/tiles/planks.png",
	&"moss": "res://assets/tiles/moss.png",
	&"grate": "res://assets/tiles/grate.png",
	&"kintsugi": "res://assets/tiles/kintsugi.png",
	&"white_tile": "res://assets/tiles/white_tile.png",
	&"flesh_cobble": "res://assets/tiles/flesh_cobble.png",
}

const STANDING := {
	&"log": "res://assets/tiles/log.png",
	&"log_tall": "res://assets/tiles/log_tall.png",
	&"wall_rust": "res://assets/tiles/wall_rust.png",
	&"wall_door": "res://assets/tiles/wall_door.png",
}

static var _cache: Dictionary = {}


## Loaded once. Reaching for a texture inside _draw every frame is both
## wasteful and unreliable — the first draw can land before the upload.
static func texture(id: StringName) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var path := String(FLOOR.get(id, STANDING.get(id, "")))
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path)
	_cache[id] = tex
	return tex


static func warm() -> void:
	for id in FLOOR:
		texture(id)
	for id in STANDING:
		texture(id)


## What the ground under a cell is made of. Corruption is not a tint here —
## the floor itself turns to flesh-set cobble, tile by tile, so a shop going
## bad is something you watch spread rather than a number you read.
static func floor_for(cell: int, level: int, corrupted: bool) -> StringName:
	if corrupted:
		return &"flesh_cobble"
	match cell:
		Shop.Cell.ALTAR:
			return &"kintsugi"
		Shop.Cell.BACKROOM:
			return &"white_tile"
		Shop.Cell.DOOR:
			return &"moss"
	return &"planks" if level == 1 else &"grate"


## The face a wall shows. Level 1 is a log cabin; level 2 is riveted iron.
static func wall_for(level: int, is_door_wall: bool) -> StringName:
	if level == 1:
		return &"log"
	return &"wall_door" if is_door_wall else &"wall_rust"
