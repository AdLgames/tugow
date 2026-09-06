class_name WorldView
extends Control
## The shop, drawn three-quarter top-down on a square grid.
##
## The camera looks straight ahead, so you only ever see the tall front face
## of the wall at the top of the room. The sides show the logs end-on and the
## near wall is a low sill, or it would stand between the camera and the floor.
##
## Two layers, the way the room is built:
##   0  the floor — no sorting, nothing can walk behind a floor
##   1  everything standing — sorted by the row its feet are in, so a figure
##      walking up the room passes behind what is above her
##
## The simulation knows none of this. It deals in whole tile coordinates and
## this is the only file that turns them into pixels.

signal tile_tapped(at: Vector2i)

## Every source tile is 64x64. Zoom is whole-numbered so the art never lands
## between screen pixels.
const TABLE_LIFT := 0.30
const WALL_TALL := 2.0
## Room left above the back row for anything tall standing on it.
const HEADROOM := 1.1

var world: World = null
var grid := GridMap2D.new()
var glitches: Array = []

var _t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	grid.mode = Balance.projection
	Tiles.warm()
	set_process(true)


func bind(p_world: World) -> void:
	world = p_world
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var kept: Array = []
	for g in glitches:
		g["life"] -= delta
		if g["life"] > 0.0:
			kept.append(g)
	glitches = kept
	queue_redraw()


func flash_glitch(at: Vector2) -> void:
	glitches.append({"at": at, "life": 0.18})


## Fit the room. The grid map knows how, for whichever layout is set.
func _layout() -> void:
	if world == null:
		return
	grid.mode = Balance.projection
	grid.fit(world.shop.size, size, HEADROOM)


func tile_size() -> float:
	return grid.tile_w


func project(at: Vector2) -> Vector2:
	return grid.project(at)


func project_centre(at: Vector2) -> Vector2:
	return grid.centre(at)


func tile_at(screen: Vector2) -> Vector2i:
	if world == null:
		return Vector2i(-1, -1)
	return grid.tile_at(screen)


func _gui_input(event: InputEvent) -> void:
	var pressed := false
	var at := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		at = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		at = event.position
	if not pressed:
		return
	tile_tapped.emit(tile_at(at))
	accept_event()


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	if world == null:
		return
	_layout()
	draw_rect(Rect2(Vector2.ZERO, size), Palette.NIGHT, true)
	_draw_outside()
	_draw_floor()
	_draw_standing()
	_draw_glitches()


func _draw_outside() -> void:
	var tex := Tiles.outside_texture()
	var n := world.shop.size
	for y in range(-2, n + 2):
		for x in range(-2, n + 2):
			if x >= 0 and y >= 0 and x < n and y < n:
				continue
			_blit(tex, Tiles.outside_colour(), Vector2i(x, y), 0.6)


## Layer 0. Every cell gets a floor, walls included, or the room has holes.
func _draw_floor() -> void:
	var corrupt_share := clampf(world.corruption / Balance.corruption_cap, 0.0, 1.0)
	var n := world.shop.size
	for y in n:
		for x in n:
			var at := Vector2i(x, y)
			var cell := world.shop.get_cell(at)
			if cell == Shop.Cell.WALL:
				cell = Shop.Cell.FLOOR
			# Corruption replaces the floor rather than tinting it, and every
			# cell has a fixed place in the queue, so the spread reads as a
			# spread and always creeps the same way.
			var corrupted := _corruption_rank(at) < corrupt_share
			_blit(Tiles.floor_texture(cell, world.level, corrupted),
				Tiles.floor_colour(cell, world.level, corrupted), at)


## A stable per-tile ordering, so the same tiles always turn first.
func _corruption_rank(at: Vector2i) -> float:
	var h := (at.x * 73856093) ^ (at.y * 19349663)
	return float(absi(h) % 1000) / 1000.0


## Mirroring was meant to break up the repeat, but a mirrored tile beside its
## original makes a butterfly, which is louder than the repetition it was
## hiding. Honest tiling until there are variant tiles to draw from.
func _flip_of(_at: Vector2i) -> bool:
	return false


## Draw a cell. With no texture in the slot the cell is a flat colour, which
## is how the whole shop looked before there was any art and how it looks
## again with assets/tiles empty.
func _blit(tex: Texture2D, tint: Color, at: Vector2i, alpha: float = 1.0) -> void:
	var w := grid.tile_w
	if tex == null:
		var box := Rect2(project(Vector2(at)), Vector2(w, grid.tile_h))
		if grid.is_iso():
			var c := grid.centre(Vector2(at))
			var half := Vector2(w * 0.5, grid.tile_h * 0.5)
			draw_colored_polygon(PackedVector2Array([
				c - Vector2(0.0, half.y), c + Vector2(half.x, 0.0),
				c + Vector2(0.0, half.y), c - Vector2(half.x, 0.0)]),
				Color(tint, alpha))
			return
		# A seam, so a field of one colour still reads as a floor of tiles.
		draw_rect(box, Color(tint, alpha), true)
		draw_rect(Rect2(box.position, Vector2(box.size.x, 1.0)),
			Color(tint.darkened(0.3), alpha), true)
		draw_rect(Rect2(box.position, Vector2(1.0, box.size.y)),
			Color(tint.darkened(0.3), alpha), true)
		return
	if grid.is_iso():
		# A diamond is drawn centred on the top corner of its cell and keeps
		# whatever depth it was painted with, which hangs over the row behind.
		var h := w * float(tex.get_height()) / float(tex.get_width())
		draw_texture_rect(tex, Rect2(project(Vector2(at)) - Vector2(w * 0.5, 0.0),
			Vector2(w, h)), false, Color(1, 1, 1, alpha))
		return
	draw_texture_rect(tex, Rect2(project(Vector2(at)), Vector2(w, grid.tile_h)),
		false, Color(1, 1, 1, alpha))


## Layer 1, sorted by the row a thing's feet are in.
func _draw_standing() -> void:
	var queue: Array = []
	var n := world.shop.size
	for y in n:
		for x in n:
			var at := Vector2i(x, y)
			var cell := world.shop.get_cell(at)
			if cell == Shop.Cell.WALL:
				queue.append({"sort": grid.depth(Vector2(at)), "wall": at})
			elif cell == Shop.Cell.TABLE or cell == Shop.Cell.CASE:
				queue.append({"sort": grid.depth(Vector2(at)) + 0.4,
					"table": at, "cell": cell})
	# Sorted from the centre of the cell a figure is standing on, not from a
	# corner of it, so she passes behind what is above her and in front of
	# what is below whichever layout is running.
	for c in world.customers:
		queue.append({"sort": grid.depth(c.at) + 0.5, "customer": c})
	queue.append({"sort": grid.depth(world.player) + 0.5, "player": true})
	queue.sort_custom(func(a, b): return float(a["sort"]) < float(b["sort"]))
	for item in queue:
		if item.has("wall"):
			_draw_wall(item["wall"])
		elif item.has("table"):
			_draw_table(item["table"], int(item["cell"]))
		elif item.has("customer"):
			_draw_person(item["customer"].at, Palette.FLESH, item["customer"])
		else:
			_draw_person(world.player, Palette.EYE, null)


## Which face of the wall you are looking at depends on where it is. The
## camera looks straight ahead: only the top of the room shows a tall front
## face, the sides show the logs end-on, and the near wall is a low sill.
## Which face of the wall you see depends on which side of the room it is on:
## the camera looks straight ahead, so only the back wall shows a tall front,
## the sides are seen end-on, and the near wall is kept low or it would stand
## between the camera and the floor. On a diamond grid every wall is at the
## same angle, so they all use the same face.
func _draw_wall(at: Vector2i) -> void:
	var n := world.shop.size
	var w := grid.tile_w
	var part := &"north"
	if not grid.is_iso():
		if at.y == n - 1:
			part = &"sill"
		elif at.y != 0:
			part = &"side"
	var tex := Tiles.wall_texture(world.level, part)
	if tex == null:
		_draw_blank_wall(at, part)
		return

	# One cell wide, at the sprite's own aspect, standing on the bottom of
	# its cell. Whatever height it was drawn at is the height it stands.
	var aspect := float(tex.get_height()) / float(tex.get_width())
	var foot := project(Vector2(at)) + Vector2(0.0, grid.tile_h)
	if grid.is_iso():
		foot = grid.centre(Vector2(at)) + Vector2(-w * 0.5, grid.tile_h * 0.5)

	# A stockade can be made of many small logs rather than one big one.
	# Four to a cell, two across and two deep, with the back pair drawn first
	# so the front pair overlaps them the way stacked timber does.
	var across := Tiles.wall_logs_across(world.level)
	if across <= 1:
		var h := w * aspect
		draw_texture_rect(tex, Rect2(foot - Vector2(0.0, h), Vector2(w, h)), false)
		return
	var lw := w / float(across)
	var lh := lw * aspect
	for row in range(across - 1, -1, -1):
		var y := foot.y - lh - float(row) * (grid.tile_h / float(across)) * 0.9
		for col in across:
			# Every other row is nudged along, so the seams do not line up
			# into a column running the height of the wall.
			var stagger := 0.0 if row % 2 == 0 else lw * 0.5
			var x := foot.x + float(col) * lw + stagger
			if x + lw > foot.x + w + 0.5:
				x -= w
			draw_texture_rect(tex, Rect2(Vector2(x, y), Vector2(lw, lh)), false)


## No sprite in the slot: a block with a lit top, which is enough to read as
## a wall and enough to play against.
func _draw_blank_wall(at: Vector2i, part: StringName) -> void:
	var w := grid.tile_w
	var tall := w * (0.9 if part == &"north" else (0.35 if part == &"sill" else 0.6))
	var face := Tiles.wall_colour(world.level)
	var top := Tiles.wall_top_colour(world.level)
	var foot := project(Vector2(at)) + Vector2(0.0, grid.tile_h)
	if grid.is_iso():
		foot = grid.centre(Vector2(at)) + Vector2(-w * 0.5, grid.tile_h * 0.5)
		tall = w * 0.55
	draw_rect(Rect2(foot - Vector2(0.0, tall), Vector2(w, tall)), face, true)
	draw_rect(Rect2(foot - Vector2(0.0, tall), Vector2(w, maxf(2.0, w * 0.08))),
		top, true)


func _draw_table(at: Vector2i, cell: int) -> void:
	var tile := grid.tile_w
	var lift := tile * TABLE_LIFT * (1.35 if cell == Shop.Cell.CASE else 1.0)
	var face := Palette.WOOD if cell == Shop.Cell.TABLE else Palette.STONE
	var lit := Palette.WOOD_TOP if cell == Shop.Cell.TABLE else Palette.STONE_TOP
	var middle := grid.centre(Vector2(at))

	if grid.is_iso():
		# A box on a diamond grid: a diamond top with two faces dropped from
		# its near edges, in the same projection as the floor under it.
		var w := tile * 0.82
		var h := grid.tile_h * 0.82
		var top := middle - Vector2(0.0, lift)
		var left := top + Vector2(-w * 0.5, 0.0)
		var right := top + Vector2(w * 0.5, 0.0)
		var near := top + Vector2(0.0, h * 0.5)
		draw_colored_polygon(PackedVector2Array([left, near,
			near + Vector2(0.0, lift), left + Vector2(0.0, lift)]), face.darkened(0.35))
		draw_colored_polygon(PackedVector2Array([near, right,
			right + Vector2(0.0, lift), near + Vector2(0.0, lift)]), face.darkened(0.12))
		draw_colored_polygon(PackedVector2Array([
			top - Vector2(0.0, h * 0.5), right, near, left]), lit)
		_draw_stock(at, top - Vector2(0.0, h * 0.18))
		return

	var box := Rect2(middle - Vector2(tile * 0.43, grid.tile_h * 0.43),
		Vector2(tile * 0.86, grid.tile_h * 0.86))
	draw_rect(Rect2(box.position + Vector2(0.0, box.size.y - lift),
		Vector2(box.size.x, lift)), face.darkened(0.35), true)
	draw_rect(Rect2(box.position - Vector2(0.0, lift),
		Vector2(box.size.x, box.size.y - lift)), lit, true)
	draw_rect(Rect2(box.position - Vector2(0.0, lift), Vector2(box.size.x, 3.0)),
		lit.lightened(0.3), true)
	_draw_stock(at, box.position + Vector2(box.size.x * 0.5, box.size.y * 0.42 - lift))


func _draw_stock(at: Vector2i, centre: Vector2) -> void:
	var stock := world.shop.stock_at(at)
	var tile := grid.tile_w
	var step := tile * 0.22
	for i in stock.size():
		var unit: Goods.Unit = stock[i]
		var s := tile * 0.17
		var offset := Vector2((float(i) - float(stock.size() - 1) * 0.5) * step, 0.0)
		var colour := Palette.good_colour(unit.id)
		var wobble := 0.0
		if unit.rotted:
			colour = Palette.ROT
			wobble = sin(_t * 9.0 + float(i)) * 3.0
		elif unit.spoilage() > 0.6:
			colour = colour.lerp(Palette.ROT, (unit.spoilage() - 0.6) / 0.4)
		var box := Rect2(centre + offset + Vector2(-s * 0.5, -s + wobble), Vector2(s, s))
		draw_rect(box, colour, true)
		draw_rect(Rect2(box.position + Vector2(0.0, box.size.y - 3.0),
			Vector2(box.size.x, 3.0)), colour.darkened(0.45), true)


func _draw_person(at: Vector2, tone: Color, customer: Customer) -> void:
	var tile := grid.tile_w
	var foot := grid.foot(at)
	var glitched := customer != null and customer.glitching
	var body := tone if not glitched else Palette.VOID
	var w := tile * 0.34
	var h := tile * 0.42
	draw_rect(Rect2(foot + Vector2(-w * 0.55, -tile * 0.06),
		Vector2(w * 1.1, tile * 0.10)), Color(0, 0, 0, 0.32), true)
	draw_rect(Rect2(foot + Vector2(-w * 0.5, -h), Vector2(w, h)), body, true)
	var head := tile * 0.28
	draw_rect(Rect2(foot + Vector2(-head * 0.5, -h - head), Vector2(head, head)),
		body.lightened(0.22), true)
	if glitched:
		draw_rect(Rect2(foot + Vector2(-w, -h - head * 1.7),
			Vector2(w * 2.0, head * 0.5)), Palette.SAP, true)
		return
	var eye := Vector2(head * 0.20, maxf(2.0, tile * 0.045))
	draw_rect(Rect2(foot + Vector2(-head * 0.30, -h - head * 0.60), eye), Palette.NIGHT, true)
	draw_rect(Rect2(foot + Vector2(head * 0.10, -h - head * 0.60), eye), Palette.NIGHT, true)
	if customer != null and customer.carrying != null:
		draw_rect(Rect2(foot + Vector2(w * 0.45, -h * 0.7), Vector2(tile * 0.16, tile * 0.16)),
			Palette.good_colour(customer.carrying.id), true)
	if customer == null and world.carrying != null:
		draw_rect(Rect2(foot + Vector2(-tile * 0.09, -h - head * 1.9),
			Vector2(tile * 0.18, tile * 0.18)),
			Palette.good_colour(world.carrying.id), true)


func _draw_glitches() -> void:
	for g in glitches:
		var at: Vector2 = g["at"]
		var f: float = float(g["life"]) / 0.18
		var c := grid.centre(at)
		var w := grid.tile_w
		draw_rect(Rect2(c - Vector2(w * 0.9, w * 0.5), Vector2(w * 1.8, w)),
			Color(Palette.VOID, 0.28 * f), true)
