class_name TileTheme
extends Resource
## The tiles the shop is drawn from. Every slot is optional.
##
## Assign textures in the inspector, or drop PNGs into res://assets/tiles/
## under the names in `FILES` below and they are picked up with no code
## change. A slot left empty falls back to a flat colour, so the game runs,
## renders and stays testable with no art at all.
##
## Sizes are what the drawing code assumes, not what it enforces:
##   floors  — square, any size, drawn to fill one cell (64x64 suits)
##   walls   — one cell wide, drawn at their own aspect, standing on the
##             bottom of their cell, so a 64x128 sprite is two cells tall
## Isometric art wants square tiles reprojected first; see docs/ASSETS.md.

## Floors.
@export var floor_shop: Texture2D          ## Level 1 — the wooden shop
@export var floor_iron: Texture2D          ## Level 2 — the cold expansion
@export var floor_outside: Texture2D       ## The clearing, and the doorway
@export var floor_altar: Texture2D         ## The counter you sell across
@export var floor_backroom: Texture2D      ## Level 2 stores
@export var floor_corruption: Texture2D    ## What a floor turns into

## Walls. `north` is the back of the room and the only tall face the camera
## sees; `side` is the wall seen end-on; `sill` is the near wall, kept low so
## it does not stand between the camera and the floor.
@export var wall_shop_north: Texture2D
@export var wall_shop_side: Texture2D
@export var wall_shop_sill: Texture2D
@export var wall_iron_north: Texture2D
@export var wall_iron_side: Texture2D
@export var wall_iron_sill: Texture2D

## How many copies of the wall sprite make up one cell, across. Two gives a
## stockade of small logs stacked four to a cell; one gives a single panel.
@export_range(1, 4) var shop_wall_logs: int = 1
@export_range(1, 4) var iron_wall_logs: int = 1


## The filenames looked for in res://assets/tiles/ when a slot is left empty.
## Drop a PNG in with one of these names and it is used.
const FILES := {
	&"floor_shop": "floor_shop.png",
	&"floor_iron": "floor_iron.png",
	&"floor_outside": "floor_outside.png",
	&"floor_altar": "floor_altar.png",
	&"floor_backroom": "floor_backroom.png",
	&"floor_corruption": "floor_corruption.png",
	&"wall_shop_north": "wall_shop_north.png",
	&"wall_shop_side": "wall_shop_side.png",
	&"wall_shop_sill": "wall_shop_sill.png",
	&"wall_iron_north": "wall_iron_north.png",
	&"wall_iron_side": "wall_iron_side.png",
	&"wall_iron_sill": "wall_iron_sill.png",
}


## The texture for a slot: what is assigned, or what is sitting in the folder
## under the expected name, or nothing.
func slot(name: StringName) -> Texture2D:
	var assigned: Variant = get(name)
	if assigned is Texture2D:
		return assigned
	var file: String = String(FILES.get(name, ""))
	if file == "":
		return null
	var path := "res://assets/tiles/" + file
	return load(path) if ResourceLoader.exists(path) else null


## Every slot name, for tooling and for warming the cache.
static func slot_names() -> Array[StringName]:
	var out: Array[StringName] = []
	for name in FILES:
		out.append(name)
	return out
