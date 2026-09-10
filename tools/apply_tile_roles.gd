@tool
extends SceneTree
## Give every tile the collision and shadow shape its role calls for.
##
##   godot --headless --path . --script res://tools/apply_tile_roles.gd
##
## Roles are decided by the texture's filename, because that is the only thing
## the art carries. A source whose name matches WALL_WORDS becomes solid and
## casts a shadow; anything else is floor and gets both stripped, so a tile
## that was solid by accident stops being solid.
##
## Re-run it after adding art. It is safe to run twice; it rewrites the shapes
## rather than adding another copy.

const TILESET := "res://resources/tileset.tres"

## Substrings that mark a texture as something you cannot walk through.
const WALL_WORDS := ["wall", "vertical"]

## A full cell, in the tile's own coordinates: the origin sits at the centre,
## so a 16x16 tile runs from -8 to 8.
const HALF := 8.0


func _init() -> void:
	var tile_set: TileSet = load(TILESET)
	if tile_set == null:
		push_error("no tileset at %s" % TILESET)
		quit(1)
		return
	if tile_set.get_physics_layers_count() == 0:
		tile_set.add_physics_layer()
		tile_set.set_physics_layer_collision_layer(0, 1)
	if tile_set.get_occlusion_layers_count() == 0:
		tile_set.add_occlusion_layer()
		tile_set.set_occlusion_layer_light_mask(0, 1)

	var walls := 0
	var floors := 0
	var dropped := 0
	for i in tile_set.get_source_count():
		var id := tile_set.get_source_id(i)
		var atlas := tile_set.get_source(id) as TileSetAtlasSource
		if atlas == null:
			continue
		if atlas.texture == null:
			print("source %d has no texture — remove it in the TileSet tab" % id)
			dropped += 1
			continue
		var solid := _is_wall(atlas.texture.resource_path)
		_ensure_tiles(atlas)
		for t in atlas.get_tiles_count():
			var data := atlas.get_tile_data(atlas.get_tile_id(t), 0)
			_shape(data, solid, tile_set.tile_size)
		if solid:
			walls += 1
		else:
			floors += 1

	var uids := _uids_in(TILESET)
	var err := ResourceSaver.save(tile_set, TILESET)
	if err != OK:
		push_error("could not save: %d" % err)
		quit(1)
		return
	_restore_uids(TILESET, uids)
	print("%d wall sources, %d floor sources, %d unusable" % [walls, floors, dropped])
	quit(0)


func _is_wall(path: String) -> bool:
	var name := path.get_file().to_lower()
	for word in WALL_WORDS:
		if name.contains(word):
			return true
	return false


## A source with no tile in it is invisible in the palette, which looks like
## the art failed to load. One 16x16 image is always one tile at 0:0.
func _ensure_tiles(atlas: TileSetAtlasSource) -> void:
	if atlas.get_tiles_count() > 0:
		return
	var grid := atlas.get_atlas_grid_size()
	if grid.x < 1 or grid.y < 1:
		print("  %s is smaller than one %s region, so it holds no tiles"
			% [atlas.texture.resource_path.get_file(), atlas.texture_region_size])
		return
	atlas.create_tile(Vector2i.ZERO)


## Collision and shadow both want the same square, so they are set together —
## that way a wall can never end up solid but shadowless, or the reverse.
func _shape(data: TileData, solid: bool, cell: Vector2i) -> void:
	if data == null:
		return
	data.set_collision_polygons_count(0, 1 if solid else 0)
	data.set_occluder_polygons_count(0, 1 if solid else 0)
	if not solid:
		return
	var square := _square(cell)
	data.set_collision_polygon_points(0, 0, square)
	var occluder := OccluderPolygon2D.new()
	occluder.polygon = square
	data.set_occluder_polygon(0, 0, occluder)


func _square(cell: Vector2i) -> PackedVector2Array:
	var w := cell.x * 0.5
	var h := cell.y * 0.5
	return PackedVector2Array([
		Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h),
	])


## Saving from a headless script drops the uid= on every resource reference,
## because the uid cache the editor keeps is not loaded here. Godot recovers
## by path, but the file churns on every run and any scene that points at this
## tileset by uid warns until someone opens the editor. So the uids are read
## before the save and written back after it.
func _uids_in(path: String) -> Dictionary:
	var out := {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	while not file.eof_reached():
		var line := file.get_line()
		if not line.begins_with("[gd_resource") and not line.begins_with("[ext_resource"):
			continue
		var uid := _quoted_after(line, "uid=")
		if uid.is_empty():
			continue
		# The resource's own uid is on the gd_resource line, which has no path.
		out[_quoted_after(line, "path=")] = uid
	return out


func _restore_uids(path: String, uids: Dictionary) -> void:
	if uids.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var lines: Array[String] = []
	var changed := false
	while not file.eof_reached():
		var line := file.get_line()
		var heading := line.begins_with("[gd_resource") or line.begins_with("[ext_resource")
		if heading and not line.contains("uid="):
			var key := _quoted_after(line, "path=")
			if uids.has(key):
				line = line.trim_suffix("]") + " uid=\"%s\"]" % uids[key]
				changed = true
		lines.append(line)
	file.close()
	if not changed:
		return
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		return
	out.store_string("\n".join(lines))


func _quoted_after(line: String, key: String) -> String:
	var at := line.find(key)
	if at == -1:
		return ""
	var rest := line.substr(at + key.length())
	if not rest.begins_with("\""):
		return ""
	var end := rest.find("\"", 1)
	return rest.substr(1, end - 1) if end > 0 else ""
