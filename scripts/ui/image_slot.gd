class_name ImageSlot
extends Control
## The Godot equivalent of the design's <image-slot>: a labelled drop point
## for art that does not exist yet. If the texture is present it is drawn; if
## not, you get the dashed frame and the caption, so the scene reads as
## deliberately unfinished rather than broken.
##
## Every slot names a real deliverable from
## docs/design-system/guidelines/asset_manifest.md.

var slot_id: StringName
var caption: String = ""
## The deliverable this slot is waiting for, shown when captions are on.
var dev_caption: String = "Drop an image"
var texture_path: String = ""
var texture: Texture2D = null
## Draw the placeholder frame even when art is present (debug).
var always_show_frame: bool = false


func _init(p_id: StringName = &"", p_caption: String = "", p_path: String = "") -> void:
	slot_id = p_id
	dev_caption = p_caption
	texture_path = p_path
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	reload()


## Art drops in by filename: no code change, just put the file in place.
func reload() -> void:
	if texture_path != "" and ResourceLoader.exists(texture_path):
		texture = load(texture_path)
	queue_redraw()


func has_art() -> bool:
	return texture != null


func _draw() -> void:
	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
		if not always_show_frame:
			return
	_draw_dashed_frame()
	if caption == "":
		return
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(font, Vector2((size.x - text_size.x) * 0.5, size.y * 0.5 + 6),
		caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ThemeColors.BURNED)


func _draw_dashed_frame() -> void:
	var dash := 9.0
	var gap := 7.0
	var colour := Color(1, 1, 1, 0.08)
	var corners := [
		[Vector2.ZERO, Vector2(size.x, 0)],
		[Vector2(size.x, 0), size],
		[size, Vector2(0, size.y)],
		[Vector2(0, size.y), Vector2.ZERO],
	]
	for edge in corners:
		var from: Vector2 = edge[0]
		var to: Vector2 = edge[1]
		var length := from.distance_to(to)
		var dir := (to - from).normalized()
		var travelled := 0.0
		while travelled < length:
			var seg := minf(dash, length - travelled)
			draw_line(from + dir * travelled, from + dir * (travelled + seg), colour, 1.0)
			travelled += dash + gap
