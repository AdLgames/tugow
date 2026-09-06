class_name Portraits
extends RefCounted
## Painted faces, where they exist, and where the eyes are on each one.
##
## The blink is a mechanic rather than decoration — a thing that has not
## learned to blink does not — so a painted portrait is not finished until it
## says where its eyes are. Anything with no entry here falls back to the
## drawn face in portrait_view.gd, which blinks on its own.

## `eyes` is the band the lids close over, as a fraction of the trimmed image.
const TABLE := {
	0: {
		"path": "res://assets/portraits/00.png",
		"eyes": Rect2(0.30, 0.355, 0.42, 0.075),
	},
}


static func has_art(index: int) -> bool:
	if not TABLE.has(index):
		return false
	return ResourceLoader.exists(String(TABLE[index]["path"]))


static var _cache: Dictionary = {}


static func texture(index: int) -> Texture2D:
	if _cache.has(index):
		return _cache[index]
	var tex: Texture2D = null
	if has_art(index):
		tex = load(String(TABLE[index]["path"]))
	_cache[index] = tex
	return tex


## Pull every painted face in before the first frame is drawn.
static func warm() -> void:
	for index in TABLE:
		texture(index)


static func eyes(index: int) -> Rect2:
	if not TABLE.has(index):
		return Rect2()
	return TABLE[index]["eyes"]


## How many of the twenty have been painted. The rest are drawn.
static func painted() -> int:
	var n := 0
	for index in TABLE:
		if has_art(index):
			n += 1
	return n
