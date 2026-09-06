class_name WorldView
extends Control
## The shop, drawn.
##
## Three-quarter top-down: tiles are square and flat, and everything standing
## on them is drawn with a top and a front face so it has height. Everything
## is snapped to a chunky pixel so it reads as 8-bit rather than as vector
## shapes that happen to be small.

signal tile_tapped(at: Vector2i)

## How big a drawn "pixel" is. Everything rounds to this.
const PIXEL := 4.0
## Height of a standing thing, in screen pixels.
const WALL_HEIGHT := 26.0
const TABLE_HEIGHT := 18.0

var world: World = null
var tile: float = 64.0
var origin := Vector2.ZERO
## Held for a beat after a sale, for the frame their sprite is wrong.
var glitches: Array = []

var _t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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


## Fit the whole floor into the view, on a whole number of screen pixels so
## the art never lands between them.
func _layout() -> void:
	if world == null:
		return
	var n := float(world.shop.size)
	tile = floor(minf(size.x / n, size.y / n) / PIXEL) * PIXEL
	var span := tile * n
	origin = ((size - Vector2(span, span)) * 0.5).snapped(Vector2(PIXEL, PIXEL))


func tile_at(screen: Vector2) -> Vector2i:
	if world == null or tile <= 0.0:
		return Vector2i.ZERO
	var local := (screen - origin) / tile
	return Vector2i(int(floor(local.x)), int(floor(local.y)))


func screen_of(at: Vector2) -> Vector2:
	return origin + at * tile


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		tile_tapped.emit(tile_at(event.position))
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		tile_tapped.emit(tile_at(event.position))
		accept_event()


func _draw() -> void:
	if world == null:
		return
	_layout()
	_draw_ground()
	_draw_floor()
	# Everything standing is drawn back to front so it overlaps correctly.
	var standing: Array = []
	for y in world.shop.size:
		for x in world.shop.size:
			var at := Vector2i(x, y)
			var cell := world.shop.get_cell(at)
			if cell == Shop.Cell.WALL or cell == Shop.Cell.TABLE \
					or cell == Shop.Cell.CASE or cell == Shop.Cell.ALTAR:
				standing.append({"y": float(y), "at": at, "cell": cell})
	for c in world.customers:
		standing.append({"y": c.at.y, "customer": c})
	standing.append({"y": world.player.y, "player": true})
	standing.sort_custom(func(a, b): return float(a["y"]) < float(b["y"]))
	for item in standing:
		if item.has("customer"):
			_draw_person(item["customer"].at, Palette.FLESH, item["customer"])
		elif item.has("player"):
			_draw_person(world.player, Palette.EYE, null)
		else:
			_draw_furniture(item["at"], int(item["cell"]))
	_draw_carried()
	_draw_glitches()


## The clearing the shop sits in. Trees at the edge, and the sap.
func _draw_ground() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.NIGHT, true)
	var n := world.shop.size
	var pad := tile
	var outer := Rect2(origin - Vector2(pad, pad),
		Vector2(tile * n + pad * 2.0, tile * n + pad * 2.0))
	draw_rect(outer, Palette.GRASS, true)
	# Bleeding trees all the way round the clearing.
	var count := n + 2
	for i in count:
		var f := float(i) - 1.0
		var ring: Array[Vector2] = [
			Vector2(f, -1.0), Vector2(f, float(n)),
			Vector2(-1.0, f), Vector2(float(n), f),
		]
		for k in ring.size():
			_draw_tree((origin + ring[k] * tile).snapped(Vector2(PIXEL, PIXEL)),
				i * 4 + k)


func _draw_tree(at: Vector2, seed_value: int) -> void:
	var w := tile * 0.7
	var trunk := Rect2(at + Vector2(tile * 0.34, tile * 0.42), Vector2(tile * 0.22, tile * 0.5))
	draw_rect(_snap(trunk), Palette.WOOD_DARK, true)
	draw_rect(_snap(Rect2(at + Vector2(tile * 0.12, tile * 0.02), Vector2(w, tile * 0.5))),
		Palette.GRASS_ALT.darkened(0.25), true)
	# Sap, running. It is the first thing that is wrong.
	if seed_value % 3 != 0:
		return
	var drip := fposmod(_t * 0.35 + float(seed_value) * 0.21, 1.0)
	draw_rect(_snap(Rect2(at + Vector2(tile * 0.42, tile * 0.5 + drip * tile * 0.34),
		Vector2(PIXEL, PIXEL * 2.0))), Palette.SAP, true)


func _draw_floor() -> void:
	var tint := Palette.floor_tint(world.corruption)
	for y in world.shop.size:
		for x in world.shop.size:
			var at := Vector2i(x, y)
			var box := _snap(Rect2(screen_of(Vector2(at)), Vector2(tile, tile)))
			var cell := world.shop.get_cell(at)
			var base := Palette.FLOOR_WOOD if world.level == 1 else Palette.FLOOR_IRON
			if (x + y) % 2 == 0:
				base = base.lightened(0.05)
			if cell == Shop.Cell.DOOR:
				base = Palette.DIRT
			elif cell == Shop.Cell.BACKROOM:
				base = Palette.STONE.darkened(0.45)
			draw_rect(box, base, true)
			# Board seams. Cheap, and it stops the floor reading as a colour
			# field that furniture disappears into.
			draw_rect(_snap(Rect2(box.position, Vector2(box.size.x, PIXEL))),
				base.darkened(0.35), true)
			if tint.a > 0.0:
				draw_rect(box, tint, true)


## A top face and a front face: enough height to read as three-quarter.
func _draw_furniture(at: Vector2i, cell: int) -> void:
	var box := _snap(Rect2(screen_of(Vector2(at)), Vector2(tile, tile)))
	var height := WALL_HEIGHT if cell == Shop.Cell.WALL else TABLE_HEIGHT
	var top := Palette.WALL_TOP
	var face := Palette.WALL
	match cell:
		Shop.Cell.WALL:
			if world.level >= 2:
				top = Palette.IRON_TOP
				face = Palette.IRON
			else:
				top = Palette.WALL_WOOD_TOP
				face = Palette.WALL_WOOD
		Shop.Cell.TABLE:
			top = Palette.WOOD_TOP
			face = Palette.WOOD
		Shop.Cell.CASE:
			top = Palette.STONE_TOP
			face = Palette.STONE.darkened(0.3)
		Shop.Cell.ALTAR:
			top = Palette.STONE_TOP
			face = Palette.STONE.darkened(0.4)
	# Walls fill their tile; furniture is inset, so an aisle reads as an aisle.
	var inset := 0.0 if cell == Shop.Cell.WALL else tile * 0.08
	var body := Rect2(box.position + Vector2(inset, inset),
		box.size - Vector2(inset * 2.0, inset * 2.0))
	if cell != Shop.Cell.WALL:
		# Legs, before the top goes on over them.
		var leg := Vector2(PIXEL * 2.0, height)
		draw_rect(_snap(Rect2(body.position + Vector2(0, body.size.y - height * 0.4), leg)),
			face.darkened(0.35), true)
		draw_rect(_snap(Rect2(body.position + Vector2(body.size.x - leg.x,
			body.size.y - height * 0.4), leg)), face.darkened(0.35), true)
	draw_rect(_snap(Rect2(body.position + Vector2(0, body.size.y - height),
		Vector2(body.size.x, height))), face, true)
	draw_rect(_snap(Rect2(body.position, Vector2(body.size.x, body.size.y - height))),
		top, true)
	# A lit rim along the top edge, which is what sells the height.
	draw_rect(_snap(Rect2(body.position, Vector2(body.size.x, PIXEL))),
		top.lightened(0.28), true)
	box = body
	if cell == Shop.Cell.ALTAR:
		_draw_altar_stain(box, height)
	if cell == Shop.Cell.TABLE or cell == Shop.Cell.CASE:
		_draw_stock(at, box, height)


func _draw_altar_stain(box: Rect2, height: float) -> void:
	var top := box.position + Vector2(0, height * 0.2)
	draw_rect(_snap(Rect2(top + Vector2(tile * 0.22, tile * 0.18),
		Vector2(tile * 0.56, tile * 0.10))), Palette.ALTAR_STAIN, true)
	draw_rect(_snap(Rect2(top + Vector2(tile * 0.36, tile * 0.30),
		Vector2(tile * 0.10, tile * 0.22))), Palette.ALTAR_STAIN.darkened(0.2), true)


## What is on the table. Rot is unmistakable: it goes green and it twitches.
func _draw_stock(at: Vector2i, box: Rect2, height: float) -> void:
	var stock := world.shop.stock_at(at)
	var surface := box.position + Vector2(0, height * 0.1)
	for i in stock.size():
		var unit: Goods.Unit = stock[i]
		var slot := Vector2(tile * (0.14 + 0.28 * float(i)), tile * 0.20)
		var w := tile * 0.22
		var colour := Palette.good_colour(unit.id)
		if unit.rotted:
			colour = Palette.ROT
			slot.y += sin(_t * 9.0 + float(i)) * PIXEL
		elif unit.spoilage() > 0.6:
			colour = colour.lerp(Palette.ROT, (unit.spoilage() - 0.6) / 0.4)
		draw_rect(_snap(Rect2(surface + slot, Vector2(w, w))), colour, true)
		draw_rect(_snap(Rect2(surface + slot + Vector2(0, w - PIXEL), Vector2(w, PIXEL))),
			colour.darkened(0.4), true)


## A person: two blocks and a head. Enough to read who is who at this size.
func _draw_person(at: Vector2, tone: Color, customer: Customer) -> void:
	var foot := screen_of(at) + Vector2(tile * 0.5, tile * 0.72)
	var glitched := customer != null and customer.glitching
	var body := tone if not glitched else Palette.VOID
	var w := tile * 0.32
	var h := tile * 0.42
	draw_rect(_snap(Rect2(foot + Vector2(-w * 0.5, -h), Vector2(w, h))), body, true)
	var head := tile * 0.26
	draw_rect(_snap(Rect2(foot + Vector2(-head * 0.5, -h - head), Vector2(head, head))),
		body.lightened(0.22), true)
	if glitched:
		# The single frame where the sprite is something else.
		draw_rect(_snap(Rect2(foot + Vector2(-w, -h - head * 1.6),
			Vector2(w * 2.0, head * 0.5))), Palette.SAP, true)
		return
	# Eyes. A customer facing you is worse than one facing away.
	var eye := Vector2(head * 0.22, PIXEL)
	draw_rect(_snap(Rect2(foot + Vector2(-head * 0.34, -h - head * 0.62), eye)),
		Palette.NIGHT, true)
	draw_rect(_snap(Rect2(foot + Vector2(head * 0.10, -h - head * 0.62), eye)),
		Palette.NIGHT, true)
	if customer != null and customer.carrying != null:
		draw_rect(_snap(Rect2(foot + Vector2(w * 0.4, -h * 0.6),
			Vector2(tile * 0.18, tile * 0.18))),
			Palette.good_colour(customer.carrying.id), true)


## What you are holding, over your head, so you know you are holding it.
func _draw_carried() -> void:
	if world.carrying == null:
		return
	var foot := screen_of(world.player) + Vector2(tile * 0.5, tile * 0.72)
	var w := tile * 0.24
	draw_rect(_snap(Rect2(foot + Vector2(-w * 0.5, -tile * 1.05), Vector2(w, w))),
		Palette.good_colour(world.carrying.id), true)


func _draw_glitches() -> void:
	for g in glitches:
		var at: Vector2 = g["at"]
		var f: float = float(g["life"]) / 0.18
		var box := Rect2(screen_of(at) - Vector2(tile, tile) * 0.5,
			Vector2(tile, tile) * 2.0)
		draw_rect(_snap(box), Color(Palette.VOID, 0.30 * f), true)


func _snap(box: Rect2) -> Rect2:
	return Rect2(box.position.snapped(Vector2(PIXEL, PIXEL)),
		box.size.snapped(Vector2(PIXEL, PIXEL)))
