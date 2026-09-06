class_name WorldView
extends Control
## The shop, drawn isometric.
##
## The art is 2:1 diamonds, so the projection is a true isometric one rather
## than the square three-quarter grid this started as. The simulation never
## learned about either — it deals in whole tile coordinates and this file
## is the only thing that knows where they land on a screen.
##
## Drawing is layered the way the floor is built: ground first with no sorting
## at all, then everything standing, sorted back to front by x+y so a figure
## walking up the room slides behind the wall in front of it.

signal tile_tapped(at: Vector2i)

## Tile width on screen. The diamond is half as tall as it is wide.
const TILE_W := 96.0
const TILE_H := TILE_W * 0.5
## How tall a wall stands, as a fraction of the tile width.
const WALL_TALL := 1.05
const TABLE_LIFT := TILE_H * 0.45

var world: World = null
var origin := Vector2.ZERO
var scale_factor: float = 1.0
var glitches: Array = []

var _t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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


func tile_w() -> float:
	return TILE_W * scale_factor


func tile_h() -> float:
	return TILE_H * scale_factor


## Fit the whole diamond of the floor into the view. An isometric grid is
## twice as wide as it is tall, so the width is almost always what binds.
func _layout() -> void:
	if world == null:
		return
	var n := float(world.shop.size)
	var want := Vector2(n * TILE_W, n * TILE_H + TILE_W * WALL_TALL)
	scale_factor = minf(size.x / want.x, size.y / want.y) * 0.96
	# The grid's own bounding box, so it can be centred rather than guessed at.
	var span := Vector2(n * tile_w(), n * tile_h())
	origin = Vector2(size.x * 0.5, (size.y - span.y) * 0.5 + TILE_W * WALL_TALL * scale_factor * 0.5)


## Top vertex of the diamond for a tile. Fractional coordinates are welcome:
## this is how a walking figure is placed between tiles.
func project(at: Vector2) -> Vector2:
	return origin + Vector2((at.x - at.y) * tile_w() * 0.5,
		(at.x + at.y) * tile_h() * 0.5)


## Centre of a tile's diamond — where a thing standing on it belongs.
func project_centre(at: Vector2) -> Vector2:
	return project(at) + Vector2(0.0, tile_h() * 0.5)


## Screen back to grid. The inverse of the projection, measured from the
## centre of the diamond rather than its top vertex.
func tile_at(screen: Vector2) -> Vector2i:
	if world == null or tile_w() <= 0.0:
		return Vector2i(-1, -1)
	var local := screen - origin - Vector2(0.0, tile_h() * 0.5)
	var a := local.x / (tile_w() * 0.5)
	var b := local.y / (tile_h() * 0.5)
	return Vector2i(int(floor((a + b) * 0.5 + 0.5)), int(floor((b - a) * 0.5 + 0.5)))


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
	_draw_surround()
	_draw_floor()
	_draw_standing()
	_draw_glitches()


## A ring of ground outside the walls, so the shop sits in something.
func _draw_surround() -> void:
	var n := world.shop.size
	for ring in range(-1, n + 1):
		for other in range(-1, n + 1):
			var at := Vector2i(ring, other)
			if at.x >= 0 and at.y >= 0 and at.x < n and at.y < n:
				continue
			_blit_floor(Vector2(at), &"moss", 0.55)


## Layer 0. No sorting: nothing can ever walk behind a floor.
func _draw_floor() -> void:
	var corrupt_share := clampf(world.corruption / Balance.corruption_cap, 0.0, 1.0)
	var n := world.shop.size
	for y in n:
		for x in n:
			var at := Vector2i(x, y)
			var cell := world.shop.get_cell(at)
			if cell == Shop.Cell.WALL:
				# Walls get a floor under them too, or the room has holes.
				_blit_floor(Vector2(at), Tiles.floor_for(Shop.Cell.FLOOR, world.level, false))
				continue
			# Corruption spreads across the grid rather than tinting it. The
			# same tiles turn every time, so it creeps outward from the door.
			var corrupted := _corruption_rank(at, n) < corrupt_share
			_blit_floor(Vector2(at), Tiles.floor_for(cell, world.level, corrupted))


## A stable ordering of tiles, so corruption always takes the same ones first
## and the spread reads as a spread rather than as static.
func _corruption_rank(at: Vector2i, n: int) -> float:
	var h := (at.x * 73856093) ^ (at.y * 19349663)
	return float(absi(h) % 1000) / 1000.0


func _blit_floor(at: Vector2, id: StringName, alpha: float = 1.0) -> void:
	var tex := Tiles.texture(id)
	if tex == null:
		return
	var w := tile_w()
	var h := w * float(tex.get_height()) / float(tex.get_width())
	var top := project(at)
	draw_texture_rect(tex, Rect2(top - Vector2(w * 0.5, 0.0), Vector2(w, h)),
		false, Color(1, 1, 1, alpha))


## Layer 1. Everything with height, back to front, so the shopkeeper walking
## up the room slides behind the wall ahead of her.
func _draw_standing() -> void:
	var queue: Array = []
	var n := world.shop.size
	for y in n:
		for x in n:
			var at := Vector2i(x, y)
			var cell := world.shop.get_cell(at)
			if cell == Shop.Cell.WALL:
				queue.append({"sort": float(x + y), "wall": at})
			elif cell == Shop.Cell.TABLE or cell == Shop.Cell.CASE:
				queue.append({"sort": float(x + y), "table": at, "cell": cell})
	for c in world.customers:
		queue.append({"sort": c.at.x + c.at.y, "customer": c})
	queue.append({"sort": world.player.x + world.player.y, "player": true})
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


## A wall is a flat face standing on its tile, anchored to the bottom of the
## diamond so it reads as sitting on the floor rather than floating over it.
func _draw_wall(at: Vector2i) -> void:
	var is_door_wall := at.y == world.shop.size - 1
	var id := Tiles.wall_for(world.level, is_door_wall)
	var tex := Tiles.texture(id)
	if tex == null:
		return
	# Walls are scaled by their HEIGHT, not their width. A log is tall and
	# narrow and an iron panel is square, so sizing either by tile width puts
	# one of them three tiles high.
	var h := tile_w() * WALL_TALL
	var w := h * float(tex.get_width()) / float(tex.get_height())
	var foot := project_centre(Vector2(at)) + Vector2(0.0, tile_h() * 0.45)
	# A narrow post is repeated across the tile, so a run of logs reads as a
	# cabin wall rather than a picket fence.
	var across := maxi(1, int(round(tile_w() / w)))
	for i in across:
		var offset := (float(i) - float(across - 1) * 0.5) * (tile_w() / float(across))
		draw_texture_rect(tex, Rect2(foot + Vector2(offset - w * 0.5, -h),
			Vector2(w, h)), false)


## Tables are not painted, so they are built: a top diamond and two side
## faces, in the same projection as everything else.
func _draw_table(at: Vector2i, cell: int) -> void:
	var w := tile_w() * 0.82
	var h := tile_h() * 0.82
	var lift := TABLE_LIFT * scale_factor * (1.4 if cell == Shop.Cell.CASE else 1.0)
	var centre := project_centre(Vector2(at))
	var top := centre - Vector2(0.0, lift)
	var face := Palette.WOOD if cell == Shop.Cell.TABLE else Palette.STONE
	var lit := Palette.WOOD_TOP if cell == Shop.Cell.TABLE else Palette.STONE_TOP

	var left := top + Vector2(-w * 0.5, 0.0)
	var right := top + Vector2(w * 0.5, 0.0)
	var bottom := top + Vector2(0.0, h * 0.5)
	# Two side faces, dropped to the floor.
	draw_colored_polygon(PackedVector2Array([left, bottom,
		bottom + Vector2(0, lift), left + Vector2(0, lift)]), face.darkened(0.35))
	draw_colored_polygon(PackedVector2Array([bottom, right,
		right + Vector2(0, lift), bottom + Vector2(0, lift)]), face.darkened(0.15))
	# The top.
	draw_colored_polygon(PackedVector2Array([
		top - Vector2(0.0, h * 0.5), right, bottom, left]), lit)
	_draw_stock(at, top - Vector2(0.0, h * 0.25))


## What is on the table. Rot is unmistakable: it goes green and it twitches.
func _draw_stock(at: Vector2i, centre: Vector2) -> void:
	var stock := world.shop.stock_at(at)
	var step := tile_w() * 0.20
	for i in stock.size():
		var unit: Goods.Unit = stock[i]
		var offset := Vector2((float(i) - float(stock.size() - 1) * 0.5) * step, 0.0)
		var s := tile_w() * 0.15
		var colour := Palette.good_colour(unit.id)
		var wobble := 0.0
		if unit.rotted:
			colour = Palette.ROT
			wobble = sin(_t * 9.0 + float(i)) * 3.0
		elif unit.spoilage() > 0.6:
			colour = colour.lerp(Palette.ROT, (unit.spoilage() - 0.6) / 0.4)
		var box := Rect2(centre + offset + Vector2(-s * 0.5, -s + wobble), Vector2(s, s))
		draw_rect(box, colour, true)
		draw_rect(Rect2(box.position + Vector2(0, box.size.y - 3.0),
			Vector2(box.size.x, 3.0)), colour.darkened(0.45), true)


## A person: a body and a head, standing on the diamond they occupy.
func _draw_person(at: Vector2, tone: Color, customer: Customer) -> void:
	var foot := project_centre(at)
	var glitched := customer != null and customer.glitching
	var body := tone if not glitched else Palette.VOID
	var w := tile_w() * 0.26
	var h := tile_w() * 0.34
	# A shadow, which is most of what sells a figure standing on a diamond.
	draw_colored_polygon(PackedVector2Array([
		foot + Vector2(-w * 0.7, 0), foot + Vector2(0, w * 0.35),
		foot + Vector2(w * 0.7, 0), foot + Vector2(0, -w * 0.35)]),
		Color(0, 0, 0, 0.35))
	draw_rect(Rect2(foot + Vector2(-w * 0.5, -h), Vector2(w, h)), body, true)
	var head := tile_w() * 0.21
	draw_rect(Rect2(foot + Vector2(-head * 0.5, -h - head), Vector2(head, head)),
		body.lightened(0.22), true)
	if glitched:
		draw_rect(Rect2(foot + Vector2(-w, -h - head * 1.7),
			Vector2(w * 2.0, head * 0.5)), Palette.SAP, true)
		return
	var eye := Vector2(head * 0.22, 3.0)
	draw_rect(Rect2(foot + Vector2(-head * 0.32, -h - head * 0.62), eye), Palette.NIGHT, true)
	draw_rect(Rect2(foot + Vector2(head * 0.12, -h - head * 0.62), eye), Palette.NIGHT, true)
	if customer != null and customer.carrying != null:
		draw_rect(Rect2(foot + Vector2(w * 0.45, -h * 0.7),
			Vector2(tile_w() * 0.13, tile_w() * 0.13)),
			Palette.good_colour(customer.carrying.id), true)
	if customer == null and world.carrying != null:
		draw_rect(Rect2(foot + Vector2(-tile_w() * 0.07, -h - head * 1.9),
			Vector2(tile_w() * 0.14, tile_w() * 0.14)),
			Palette.good_colour(world.carrying.id), true)


func _draw_glitches() -> void:
	for g in glitches:
		var at: Vector2 = g["at"]
		var f: float = float(g["life"]) / 0.18
		var c := project_centre(at)
		var w := tile_w()
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-w, 0), c + Vector2(0, w * 0.5),
			c + Vector2(w, 0), c + Vector2(0, -w * 0.5)]),
			Color(Palette.VOID, 0.30 * f))
