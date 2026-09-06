class_name Tiles
extends RefCounted
## Which texture the shop wants where, and the colour to use when there is
## none. The game ships with no tiles: every slot falls back to a flat colour
## so it runs and stays testable with nothing in assets/tiles at all.

## The theme in use. Swap this for one of your own — see TileTheme.
static var theme: TileTheme = null
static var _cache: Dictionary = {}


static func current() -> TileTheme:
	if theme == null:
		theme = TileTheme.new()
	return theme


## Textures are pulled once and kept. Reaching for one inside _draw every
## frame is both wasteful and unreliable — the first draw can land before
## the upload.
static func slot(name: StringName) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var tex := current().slot(name)
	_cache[name] = tex
	return tex


## Call after changing the theme or dropping new files in.
static func reload() -> void:
	_cache.clear()


static func warm() -> void:
	for name in TileTheme.slot_names():
		slot(name)


static func has_any() -> bool:
	for name in TileTheme.slot_names():
		if slot(name) != null:
			return true
	return false


# --- Floors ------------------------------------------------------------------

static func floor_slot(cell: int, level: int, corrupted: bool) -> StringName:
	if corrupted:
		return &"floor_corruption"
	match cell:
		Shop.Cell.ALTAR:
			return &"floor_altar"
		Shop.Cell.BACKROOM:
			return &"floor_backroom"
		Shop.Cell.DOOR:
			return &"floor_outside"
	return &"floor_shop" if level == 1 else &"floor_iron"


static func floor_texture(cell: int, level: int, corrupted: bool) -> Texture2D:
	return slot(floor_slot(cell, level, corrupted))


## What a floor looks like with no tile assigned. These are the colours the
## game was built on before there was any art, and they are still what it
## falls back to.
static func floor_colour(cell: int, level: int, corrupted: bool) -> Color:
	if corrupted:
		return Palette.ROT.darkened(0.25)
	match cell:
		Shop.Cell.ALTAR:
			return Palette.ALTAR_STAIN.darkened(0.45)
		Shop.Cell.BACKROOM:
			return Palette.STONE.darkened(0.45)
		Shop.Cell.DOOR:
			return Palette.DIRT
	return Palette.FLOOR_WOOD if level == 1 else Palette.FLOOR_IRON


static func outside_texture() -> Texture2D:
	return slot(&"floor_outside")


static func outside_colour() -> Color:
	return Palette.GRASS.darkened(0.25)


# --- Walls -------------------------------------------------------------------

## `part` is one of north, side, sill — which face of the wall the camera is
## looking at, decided by which side of the room the wall is on.
static func wall_slot(level: int, part: StringName) -> StringName:
	var stem := "wall_shop_" if level == 1 else "wall_iron_"
	return StringName(stem + String(part))


static func wall_texture(level: int, part: StringName) -> Texture2D:
	return slot(wall_slot(level, part))


static func wall_colour(level: int) -> Color:
	return Palette.WALL_WOOD if level == 1 else Palette.IRON


static func wall_top_colour(level: int) -> Color:
	return Palette.WALL_WOOD_TOP if level == 1 else Palette.IRON_TOP


## How many copies of the sprite make one cell of wall, across.
static func wall_logs_across(level: int) -> int:
	var t := current()
	return maxi(1, t.shop_wall_logs if level == 1 else t.iron_wall_logs)
