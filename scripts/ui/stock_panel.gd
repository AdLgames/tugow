class_name StockPanel
extends Control
## What you have, and how long you have it for.
##
## Level 1 does not need this — bone keeps. Level 2 is a forecasting problem
## and you cannot forecast against a floor you have to walk around counting,
## so every unit in the shop is totalled here with the worst spoilage in the
## pile shown against it. The bar going amber is the whole warning system.

const ROW := 46.0

var world: World = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func bind(p_world: World) -> void:
	world = p_world


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.42), true)
	draw_string(font, Vector2(16, 30), "STOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
		Palette.INK)

	var totals := {}
	var worst := {}
	_gather(world.shop.backroom, totals, worst, "back")
	for key in world.shop.displays:
		_gather(world.shop.displays[key], totals, worst, "floor")

	var y := 60.0
	for id in Goods.all_ids():
		var count: int = int(totals.get(id, 0))
		if count == 0:
			continue
		_draw_row(font, y, id, count, float(worst.get(id, 0.0)))
		y += ROW
	if totals.is_empty():
		draw_string(font, Vector2(16, y + 4), "nothing at all",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.INK_DIM)
		y += ROW

	y += 12.0
	draw_string(font, Vector2(16, y), "IN THE WOODS", HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
		Palette.INK)
	y += 30.0
	if world.thralls.out.is_empty():
		draw_string(font, Vector2(16, y), "nobody", HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Palette.INK_DIM)
		return
	for errand in world.thralls.out:
		var done := 1.0 - clampf(errand.remaining / Balance.dispatch_seconds, 0.0, 1.0)
		draw_string(font, Vector2(16, y), Goods.good_name(errand.good),
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 17, Palette.INK_DIM)
		var track := Rect2(16, y + 8, size.x - 32, 8)
		draw_rect(track, Color(0, 0, 0, 0.5), true)
		draw_rect(Rect2(track.position, Vector2(track.size.x * done, track.size.y)),
			Palette.EYE, true)
		y += 34.0


func _gather(units: Array, totals: Dictionary, worst: Dictionary, _where: String) -> void:
	for unit in units:
		totals[unit.id] = int(totals.get(unit.id, 0)) + 1
		worst[unit.id] = maxf(float(worst.get(unit.id, 0.0)), unit.spoilage())


## One good: how many, and how close the oldest of them is to turning.
func _draw_row(font: Font, y: float, id: int, count: int, spoilage: float) -> void:
	draw_rect(Rect2(14, y - 14, 10, 10), Palette.good_colour(id), true)
	draw_string(font, Vector2(32, y - 4), Goods.good_name(id),
		HORIZONTAL_ALIGNMENT_LEFT, size.x - 90, 18, Palette.INK)
	var tally := str(count)
	var w := font.get_string_size(tally, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(font, Vector2(size.x - 16 - w, y - 4), tally,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.OBOL)
	if not Goods.perishable(id):
		return
	# Green while there is time, amber when there is not, and it does not
	# wait politely for you to look at it.
	var track := Rect2(32, y + 6, size.x - 64, 8)
	draw_rect(track, Color(0, 0, 0, 0.5), true)
	var tone := Palette.EYE.lerp(Palette.SAP, clampf(spoilage * 1.35, 0.0, 1.0))
	draw_rect(Rect2(track.position, Vector2(track.size.x * (1.0 - spoilage), track.size.y)),
		tone, true)
