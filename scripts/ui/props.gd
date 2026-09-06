class_name Props
extends RefCounted
## The things on the desk, and where they sit.
##
## Positions are fractions of the frame so the dressing survives a re-scale
## or a repainted background. Each prop names a height as a fraction of the
## frame and keeps its own aspect — nothing here is stretched.

## anchor is the prop's bottom-centre, so a thing standing on the desk stays
## standing on it whatever size the frame is.
const TABLE := {
	&"clipboard": {"path": "res://assets/props/clipboard.png",
		"anchor": Vector2(0.108, 0.965), "height": 0.360, "tilt": -0.04},
	&"radio": {"path": "res://assets/props/radio.png",
		"anchor": Vector2(0.300, 0.845), "height": 0.115, "tilt": 0.0},
	&"mug": {"path": "res://assets/props/mug.png",
		"anchor": Vector2(0.385, 0.860), "height": 0.100, "tilt": 0.0},
	&"photo_family": {"path": "res://assets/props/photo_family.png",
		"anchor": Vector2(0.468, 0.795), "height": 0.130, "tilt": 0.03},
	&"lamp": {"path": "res://assets/props/lamp.png",
		"anchor": Vector2(0.610, 0.885), "height": 0.275, "tilt": 0.0},
}


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in TABLE:
		out.append(id)
	return out


## Loaded once and kept. Reaching for a texture inside _draw every frame is
## both wasteful and unreliable — the first draw can land before the upload.
static var _cache: Dictionary = {}


static func texture(id: StringName) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var path := String(TABLE[id]["path"])
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[id] = tex
	return tex


## Pull every prop in before the first frame is drawn.
static func warm() -> void:
	for id in ids():
		texture(id)


## Where the prop lands on screen, keeping its own proportions.
static func rect_for(id: StringName, frame: Vector2, tex: Texture2D) -> Rect2:
	var row: Dictionary = TABLE[id]
	var h := frame.y * float(row["height"])
	var w := h * (float(tex.get_width()) / float(tex.get_height()))
	var anchor: Vector2 = row["anchor"]
	return Rect2(Vector2(anchor.x * frame.x - w * 0.5, anchor.y * frame.y - h),
		Vector2(w, h))


static func tilt_of(id: StringName) -> float:
	return float(TABLE[id].get("tilt", 0.0))
