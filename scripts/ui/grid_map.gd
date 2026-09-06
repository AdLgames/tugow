class_name GridMap2D
extends RefCounted
## Where a tile lands on the screen.
##
## The shop has been laid out both ways and the art supports both, so this is
## a setting rather than a rewrite. Everything about the grid-to-screen
## mapping lives here; the simulation deals in whole tile coordinates and
## never learns which of these is in use.
##
## ISOMETRIC — 2:1 diamonds, tile size exactly W by W/2. Depth is x + y and
##   is measured from the centre of the diamond rather than its top corner,
##   so a figure standing on a tile sorts correctly against the walls beside
##   her.
## ORTHOGONAL — square cells, the Stardew layout. Depth is simply the row.

var mode: int = Balance.View.ISOMETRIC
var tile_w: float = 96.0
## Always exactly half the width in isometric; equal to it when square.
var tile_h: float = 48.0
var origin := Vector2.ZERO


func is_iso() -> bool:
	return mode == Balance.View.ISOMETRIC


## Fit a grid of `n` cells into `view`, leaving `head` tile-widths of room
## above for anything tall standing on the back row.
func fit(n: int, view: Vector2, head: float) -> void:
	var cells := float(n)
	if is_iso():
		var want := Vector2(cells * 96.0, cells * 48.0 + 96.0 * head)
		var zoom: float = minf(view.x / want.x, view.y / want.y) * 0.96
		tile_w = maxf(16.0, 96.0 * zoom)
		tile_h = tile_w * 0.5
		# The grid is itself a diamond: all of it hangs below the top corner
		# of tile (0, 0), and its widest point is halfway down.
		origin = Vector2(view.x * 0.5,
			(view.y - cells * tile_h) * 0.5 + tile_w * head * 0.5)
		return
	var zoom_o: float = minf(view.x / (cells * 64.0), view.y / ((cells + head) * 64.0))
	tile_w = maxf(8.0, floor(64.0 * zoom_o / 4.0) * 4.0)
	tile_h = tile_w
	origin = Vector2((view.x - tile_w * cells) * 0.5,
		(view.y - tile_h * cells) * 0.5 + tile_h * 0.4)


## The anchor of a tile's texture: the top corner of the diamond in
## isometric, the top-left of the cell when square.
func project(at: Vector2) -> Vector2:
	if is_iso():
		return origin + Vector2((at.x - at.y) * tile_w * 0.5,
			(at.x + at.y) * tile_h * 0.5)
	return origin + Vector2(at.x * tile_w, at.y * tile_h)


## The middle of the tile — where a thing standing on it belongs, and what
## the depth sort is measured from.
func centre(at: Vector2) -> Vector2:
	if is_iso():
		return project(at) + Vector2(0.0, tile_h * 0.5)
	return project(at) + Vector2(tile_w * 0.5, tile_h * 0.5)


## Where a figure's feet go. Lower than the centre of a square cell, and the
## centre itself on a diamond.
func foot(at: Vector2) -> Vector2:
	if is_iso():
		return centre(at)
	return project(at) + Vector2(tile_w * 0.5, tile_h * 0.85)


## Screen back to grid: the exact inverse of `project`, measured from the
## centre of the cell so a tap anywhere inside a diamond lands on it.
func tile_at(screen: Vector2) -> Vector2i:
	if not is_iso():
		var local := (screen - origin) / Vector2(tile_w, tile_h)
		return Vector2i(int(floor(local.x)), int(floor(local.y)))
	var off := screen - origin - Vector2(0.0, tile_h * 0.5)
	var a := off.x / (tile_w * 0.5)
	var b := off.y / (tile_h * 0.5)
	return Vector2i(int(floor((a + b) * 0.5 + 0.5)), int(floor((b - a) * 0.5 + 0.5)))


## Depth. Sorting on this back to front is what puts a figure behind what is
## above her and in front of what is below.
func depth(at: Vector2) -> float:
	return at.x + at.y if is_iso() else at.y
