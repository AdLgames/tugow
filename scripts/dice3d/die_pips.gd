class_name DiePips
extends RefCounted
## The pip atlas, drawn once at runtime. Six faces across one texture, in the
## order a BoxMesh unwraps them, so a cube reads as a die without an artist.
##
## Pips are baked into the texture rather than modelled: geometry pips cost
## more and, at the size these are seen, fight legibility rather than help it.

const FACE := 128
const PIPS := {
	1: [4], 2: [0, 8], 3: [0, 4, 8], 4: [0, 2, 6, 8],
	5: [0, 2, 4, 6, 8], 6: [0, 2, 3, 5, 6, 8],
}
## BoxMesh unwraps its faces in this order across the atlas.
const FACE_ORDER := [5, 2, 6, 1, 4, 3]

static var _cached: ImageTexture = null


static func atlas() -> ImageTexture:
	if _cached != null:
		return _cached
	var image := Image.create(FACE * FACE_ORDER.size(), FACE, false, Image.FORMAT_RGBA8)
	for slot in FACE_ORDER.size():
		_draw_face(image, slot * FACE, int(FACE_ORDER[slot]))
	_cached = ImageTexture.create_from_image(image)
	return _cached


static func _draw_face(image: Image, x_offset: int, value: int) -> void:
	var bone := Color("b7a179")
	var edge := Color("8d7a56")
	for x in FACE:
		for y in FACE:
			var near_edge: bool = x < 5 or y < 5 or x > FACE - 6 or y > FACE - 6
			image.set_pixel(x_offset + x, y, edge if near_edge else bone)
	var cell := float(FACE) / 3.0
	var radius := cell * 0.26
	for index in PIPS.get(value, []):
		var column := int(index) % 3
		var row := int(index) / 3
		var centre := Vector2(cell * (column + 0.5), cell * (row + 0.5))
		for x in range(int(centre.x - radius) - 1, int(centre.x + radius) + 2):
			for y in range(int(centre.y - radius) - 1, int(centre.y + radius) + 2):
				if x < 0 or y < 0 or x >= FACE or y >= FACE:
					continue
				var distance := Vector2(x, y).distance_to(centre)
				if distance > radius:
					continue
				# A soft rim so a pip does not alias into a square at distance.
				var ink := Color("140d05").lerp(bone, clampf((distance - radius + 2.0) / 2.0, 0.0, 1.0))
				image.set_pixel(x_offset + x, y, ink)
