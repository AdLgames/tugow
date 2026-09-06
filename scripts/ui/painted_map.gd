@tool
class_name PaintedMap
extends Node2D
## The hand-painted map: three TileMapLayers you paint in the editor.
##
## Open scenes/painted_map.tscn, select a layer, and paint. The working area
## is MAP_SIZE cells square and is outlined in the editor so you can see where
## it ends — nothing stops you painting outside it, but the game only looks
## inside.
##
## Layers, bottom to top:
##   Ground — floor. No sorting; nothing can walk behind a floor.
##   Walls  — anything with height. Y-sorted, so figures pass behind it.
##   Decor  — clutter that sits over the walls.
##
## The shop itself is still simulated, not painted: its tables, its people and
## its own floor are drawn over this. Paint the world the shop stands in.

## Cells square. The game reads this rectangle and ignores anything outside it.
const MAP_SIZE := 50
## Matches TileSet.tile_size in resources/bazaar_tileset.tres, and the size the
## drawing code assumes for a cell.
const CELL := 64

@export var show_guide: bool = true:
	set(value):
		show_guide = value
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func ground() -> TileMapLayer:
	return get_node_or_null("Ground") as TileMapLayer


func walls() -> TileMapLayer:
	return get_node_or_null("Walls") as TileMapLayer


func decor() -> TileMapLayer:
	return get_node_or_null("Decor") as TileMapLayer


func layers() -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	for layer in [ground(), walls(), decor()]:
		if layer != null:
			out.append(layer)
	return out


## Whether anything has been painted at all. The game keeps drawing its own
## flat floor until something has, so an empty map is not a black screen.
func has_paint() -> bool:
	for layer in layers():
		if not layer.get_used_cells().is_empty():
			return true
	return false


## The painted rectangle, in cells, clamped to the working area.
func painted_rect() -> Rect2i:
	var bounds := Rect2i()
	var first := true
	for layer in layers():
		for cell in layer.get_used_cells():
			if first:
				bounds = Rect2i(cell, Vector2i.ONE)
				first = false
			else:
				bounds = bounds.expand(cell).expand(cell + Vector2i.ONE)
	return bounds.intersection(Rect2i(0, 0, MAP_SIZE, MAP_SIZE))


## The working area outlined, so the edge of the map is visible while you
## paint. Editor only — it is never drawn in the running game.
func _draw() -> void:
	if not Engine.is_editor_hint() or not show_guide:
		return
	var span := float(MAP_SIZE * CELL)
	draw_rect(Rect2(0, 0, span, span), Color(0.55, 0.85, 0.55, 0.55), false, 3.0)
	for i in range(0, MAP_SIZE + 1, 10):
		var at := float(i * CELL)
		draw_line(Vector2(at, 0), Vector2(at, span), Color(1, 1, 1, 0.10), 1.0)
		draw_line(Vector2(0, at), Vector2(span, at), Color(1, 1, 1, 0.10), 1.0)
