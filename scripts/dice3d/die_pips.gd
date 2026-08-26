class_name DiePips
extends RefCounted
## The pip faces, drawn once at runtime into a strip of six cells.
##
## Pips are baked rather than modelled: at the size these are seen, geometry
## pips cost more and read worse. What matters is that a value is countable at
## a glance and never ambiguous — the wear lives on the body, never over the
## dots.

const CELL := 256
## The order the cells sit in the strip. DieMesh maps a face's UVs by looking
## its value up here, so this is the only place the layout is decided.
const CELL_ORDER := [1, 2, 3, 4, 5, 6]

## Pip positions on a 3x3 grid, the way a real die is spotted.
const LAYOUT := {
	1: [4],
	2: [0, 8],
	3: [0, 4, 8],
	4: [0, 2, 6, 8],
	5: [0, 2, 4, 6, 8],
	6: [0, 2, 3, 5, 6, 8],
}

const BONE := Color("cbb68d")
const BONE_SHADE := Color("a68f66")
const INK := Color("120c05")

static var _cached: ImageTexture = null


static func atlas() -> ImageTexture:
	if _cached != null:
		return _cached
	var image := Image.create(CELL * CELL_ORDER.size(), CELL, false, Image.FORMAT_RGBA8)
	for slot in CELL_ORDER.size():
		_draw_face(image, slot * CELL, int(CELL_ORDER[slot]))
	_cached = ImageTexture.create_from_image(image)
	return _cached


static func _draw_face(image: Image, x_offset: int, value: int) -> void:
	# Bone, darkening toward the edges so a face reads as a surface rather
	# than a flat colour.
	for x in CELL:
		for y in CELL:
			var to_edge := minf(minf(x, y), minf(CELL - 1 - x, CELL - 1 - y))
			var shade := clampf(to_edge / 26.0, 0.0, 1.0)
			image.set_pixel(x_offset + x, y, BONE_SHADE.lerp(BONE, shade))

	var third := float(CELL) / 3.0
	var radius := third * 0.28
	for index in LAYOUT.get(value, []):
		var centre := Vector2(third * (int(index) % 3 + 0.5), third * (int(index) / 3 + 0.5))
		_draw_pip(image, x_offset, centre, radius)


## A drilled dot: dark, with a lit lower rim so it reads as a hollow rather
## than a sticker.
static func _draw_pip(image: Image, x_offset: int, centre: Vector2, radius: float) -> void:
	var from_x := int(centre.x - radius) - 2
	var to_x := int(centre.x + radius) + 2
	var from_y := int(centre.y - radius) - 2
	var to_y := int(centre.y + radius) + 2
	for x in range(maxi(from_x, 0), mini(to_x, CELL)):
		for y in range(maxi(from_y, 0), mini(to_y, CELL)):
			var offset := Vector2(x, y) - centre
			var distance := offset.length()
			if distance > radius:
				continue
			var colour := INK
			# Rim light on the far side of the hollow.
			var rim := clampf((distance - radius * 0.66) / (radius * 0.34), 0.0, 1.0)
			if offset.y < 0.0:
				colour = INK.lerp(BONE_SHADE, rim * 0.55)
			# Feather the last pixel so a pip does not alias into a square.
			var edge := clampf((radius - distance) / 1.6, 0.0, 1.0)
			var beneath := image.get_pixel(x_offset + x, y)
			image.set_pixel(x_offset + x, y, beneath.lerp(colour, edge))
