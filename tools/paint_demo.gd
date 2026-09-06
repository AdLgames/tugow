extends Node
## Proves the painted map reaches the screen, with no art needed.
##
## Builds a throwaway two-tile atlas at runtime, paints the whole working
## area with it, and takes a picture. If this comes out looking like a
## chequerboard under the shop then the tileset, the layers, the alignment
## and the draw order are all wired up, and dropping real tiles in is the
## only thing left to do.
##
##   xvfb-run godot --path . res://tools/paint_demo.tscn -- --dir=/tmp/shots

const CELL := PaintedMap.CELL

var _dir := "."
var _main: Control


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_dir)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	for child in _main._overlay_body.get_children():
		if child is Button:
			child.pressed.emit()
			break
	await get_tree().process_frame

	var painted: PaintedMap = _main._view.painted
	if painted == null:
		print("FAIL: no painted map in the view")
		get_tree().quit(1)
		return

	var source_id := _build_atlas(painted)
	_paint(painted, source_id)
	print("painted %d cells; has_paint=%s; rect=%s"
		% [painted.ground().get_used_cells().size(), painted.has_paint(),
			painted.painted_rect()])
	for _i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/painted_map.png" % _dir)
	print("wrote painted_map.png")
	get_tree().quit(0)


## Two flat tiles in one atlas, made in memory.
func _build_atlas(painted: PaintedMap) -> int:
	var image := Image.create(CELL * 2, CELL, false, Image.FORMAT_RGBA8)
	for x in CELL * 2:
		for y in CELL:
			var light := x < CELL
			var edge := x % CELL < 2 or y < 2
			var tone := Color("4a6b3f") if light else Color("2e3f52")
			if edge:
				tone = tone.darkened(0.35)
			image.set_pixel(x, y, tone)
	var tex := ImageTexture.create_from_image(image)

	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(CELL, CELL)
	source.create_tile(Vector2i(0, 0))
	source.create_tile(Vector2i(1, 0))
	return painted.ground().tile_set.add_source(source)


## A chequer across the whole working area, so the edges of the map and the
## alignment against the shop are both obvious in the picture.
func _paint(painted: PaintedMap, source_id: int) -> void:
	var layer := painted.ground()
	for y in PaintedMap.MAP_SIZE:
		for x in PaintedMap.MAP_SIZE:
			var which := Vector2i(0, 0) if (x + y) % 2 == 0 else Vector2i(1, 0)
			layer.set_cell(Vector2i(x, y), source_id, which)
