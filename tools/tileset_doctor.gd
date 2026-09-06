extends Node
## What is actually in the tileset, and is it paintable?
##
##   godot --headless --path . res://tools/tileset_doctor.tscn
##
## The TileMap editor reports problems in terms of what it wants you to do
## next rather than what is wrong, so this prints the state instead: every
## source, its type, how many tiles it has, and whether the texture divides
## cleanly into the region size. A source with one tile in it is almost always
## a region size that does not match the image.

const TILESETS := ["res://resources/tileset.tres"]


func _ready() -> void:
	for path in TILESETS:
		_report(path)
	_scan_scenes()
	get_tree().quit(0)


func _report(path: String) -> void:
	print("\n=== %s ===" % path)
	if not ResourceLoader.exists(path):
		print("  MISSING")
		return
	var tile_set: TileSet = load(path)
	print("  tile size: %s" % tile_set.tile_size)
	print("  physics layers: %d" % tile_set.get_physics_layers_count())
	if tile_set.get_physics_layers_count() == 0:
		print("  ^ no physics layer, so no tile can ever be solid")
	print("  sources: %d" % tile_set.get_source_count())
	for i in tile_set.get_source_count():
		var id := tile_set.get_source_id(i)
		var source := tile_set.get_source(id)
		if source is TileSetAtlasSource:
			_report_atlas(id, source as TileSetAtlasSource, tile_set)
		elif source is TileSetScenesCollectionSource:
			var scenes := source as TileSetScenesCollectionSource
			print("  [%d] SCENES COLLECTION — %d scenes" % [id, scenes.get_scene_tiles_count()])
			print("      ^ this is the source that asks for a Scene Picker.")
			print("        Painting from it needs a scene chosen; to paint")
			print("        ordinary tiles, select an atlas source instead.")
		else:
			print("  [%d] %s" % [id, source.get_class()])


func _report_atlas(id: int, atlas: TileSetAtlasSource, tile_set: TileSet) -> void:
	var tex := atlas.texture
	var size := tex.get_size() if tex != null else Vector2.ZERO
	var region := atlas.texture_region_size
	print("  [%d] ATLAS — %d tiles, region %s, texture %s"
		% [id, atlas.get_tiles_count(), region, size])
	if tex == null:
		print("      ^ no texture")
		return
	if region != tile_set.tile_size:
		print("      ^ region %s does not match the tileset's tile size %s"
			% [region, tile_set.tile_size])
	var fits_x := int(size.x) % maxi(1, region.x) == 0
	var fits_y := int(size.y) % maxi(1, region.y) == 0
	if not fits_x or not fits_y:
		print("      ^ %dx%d does not divide evenly by %dx%d — the leftover strip"
			% [int(size.x), int(size.y), region.x, region.y])
		print("        cannot become tiles, which is usually why only one appears")
	var could_hold := int(size.x / region.x) * int(size.y / region.y)
	if atlas.get_tiles_count() < could_hold:
		print("      ^ %d of a possible %d tiles created. In the TileSet tab,"
			% [atlas.get_tiles_count(), could_hold])
		print("        select this source and press 'Create Tiles in Non-"
			+ "Transparent Texture Regions'")
	var solid := 0
	for i in atlas.get_tiles_count():
		var coords := atlas.get_tile_id(i)
		var data := atlas.get_tile_data(coords, 0)
		if data != null and tile_set.get_physics_layers_count() > 0 \
				and data.get_collision_polygons_count(0) > 0:
			solid += 1
	print("      %d of %d tiles carry a collision shape" % [solid, atlas.get_tiles_count()])


## Scenes that reference a script or resource that is no longer here will make
## the editor complain in ways that look like unrelated problems.
func _scan_scenes() -> void:
	print("\n=== scenes ===")
	var dir := DirAccess.open("res://scenes")
	if dir == null:
		print("  no scenes folder")
		return
	for file in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		var path := "res://scenes/" + file
		var packed = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		print("  %-22s %s" % [file, "ok" if packed != null else "WILL NOT LOAD"])
