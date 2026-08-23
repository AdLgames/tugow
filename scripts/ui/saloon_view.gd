class_name SaloonView
extends Control
## Floor tier 1 — the saloon. Drawn, not sprited: every layer here is a stand-in
## for a real asset at the size named in the design's manifest, so art can
## replace them one at a time.
##
## Layer order matches docs/design-system/BUILD_BRIEF_table_scene.md exactly:
## backdrop, adversary, table, zones, dice (added as children by main.gd),
## lip, lanterns, vignette, grain, interface.

const STAGE := Vector2(1920, 1080)

## Layer toggles, driven by the debug panel.
var layers := {
	&"backdrop": true,
	&"foe": true,
	&"table": true,
	&"lip": true,
	&"lamp": true,
	&"vignette": true,
	&"grain": true,
}

var projection := TableProjection.new()
var pool: DicePool = null
var adversary_present: bool = false
var lamp_left: float = 1.0
var lamp_right: float = 1.0
var vignette_weight: float = 0.72
var grain_weight: float = 0.09
var flicker: bool = true
## Surface variant — the mock's wood/oak switch.
var dark_oak: bool = false
## Placeholder captions are lab chrome, off unless asked for.
var show_slot_captions: bool = false
## Hovering a draw button shows how far that strength can reach.
var preview_strength: int = -1

## Sampled from each lantern's sway so dice cast two shadows out of phase.
var sway_left: float = 0.0
var sway_right: float = 0.0

var _time: float = 0.0
var _lamp_texture: GradientTexture2D
var _spill_texture: GradientTexture2D
var _vignette_texture: GradientTexture2D
var _grain_texture: NoiseTexture2D
var _lamp_nodes: Array[TextureRect] = []
var _vignette_node: TextureRect
var _grain_node: TextureRect
var _lantern_hardware: Control
var _poster_slot: ImageSlot
var _foe_slot: ImageSlot
var _hands_slot: ImageSlot


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_textures()
	_build_blend_layers()
	_build_slots()
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	if flicker:
		# Two lanterns, independent cycles (4.3s and 5.9s) and sway periods
		# (11s and 13s) — the design's numbers, kept.
		sway_left = sin(TAU * _time / 11.0) * 1.1
		sway_right = sin(TAU * (_time + 0.6) / 13.0) * -1.4
	else:
		sway_left = 0.0
		sway_right = 0.0
	queue_redraw()


func lamp_intensity(is_left: bool) -> float:
	var base := lamp_left if is_left else lamp_right
	if not flicker:
		return base
	var cycle := fposmod(_time, 4.3) / 4.3 if is_left else fposmod(_time + 0.8, 5.9) / 5.9
	var dip := 1.0
	if is_left:
		if cycle > 0.40 and cycle < 0.43:
			dip = 0.52
		elif cycle > 0.66 and cycle < 0.685:
			dip = 0.36
	else:
		if cycle > 0.28 and cycle < 0.305:
			dip = 0.44
		elif cycle > 0.81 and cycle < 0.83:
			dip = 0.60
	return base * dip


## Screen position for a die at its landing spot on the felt. The disc is
## squashed onto the visible band: the near arc of a real table projects down
## behind the lip, where a die could not be read or clicked.
func felt_point(position: Vector2) -> Vector2:
	# Biased right and away, so a die never lands under the Ledger or
	# behind the lip where it could not be read or clicked.
	return Vector2(position.x * 0.55 + 0.30, position.y * 0.26 + 0.34)


func die_position(die: Die) -> Vector2:
	return projection.project(felt_point(die.landing_position()))


func die_scale(die: Die) -> float:
	return clampf(projection.scale_at(felt_point(die.landing_position())), 0.30, 0.62)


# --- Construction ------------------------------------------------------------

func _build_textures() -> void:
	_lamp_texture = _radial([
		[0.00, Color(1, 0.94, 0.81, 1.00)],
		[0.24, Color(1, 0.84, 0.58, 0.72)],
		[0.46, Color(0.88, 0.63, 0.30, 0.38)],
		[0.66, Color(0.66, 0.39, 0.11, 0.16)],
		[0.82, Color(0, 0, 0, 0)],
	])
	_spill_texture = _radial([
		[0.00, Color(0.62, 0.70, 0.78, 0.60)],
		[0.34, Color(0.88, 0.63, 0.30, 0.26)],
		[0.56, Color(0.66, 0.39, 0.11, 0.08)],
		[0.72, Color(0, 0, 0, 0)],
	])
	_vignette_texture = _radial([
		[0.00, Color(1, 1, 1, 1)],
		[0.42, Color(0.92, 0.90, 0.93, 1)],
		[0.62, Color(0.71, 0.69, 0.75, 1)],
		[0.80, Color(0.43, 0.41, 0.47, 1)],
		[1.00, Color(0.20, 0.18, 0.24, 1)],
	])
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_VALUE
	noise.frequency = 0.35
	_grain_texture = NoiseTexture2D.new()
	_grain_texture.noise = noise
	_grain_texture.width = 240
	_grain_texture.height = 240
	_grain_texture.seamless = true


func _radial(stops: Array) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array()
	gradient.colors = PackedColorArray()
	for stop in stops:
		gradient.add_point(stop[0], stop[1])
	gradient.remove_point(0)
	gradient.remove_point(0)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 512
	texture.height = 512
	return texture


func _build_slots() -> void:
	# Each slot names a deliverable from the asset manifest.
	_poster_slot = ImageSlot.new(&"wanted-poster", "Wanted poster art",
		"res://assets/scene/wanted_poster.png")
	_poster_slot.position = Vector2(1480, 150)
	_poster_slot.size = Vector2(230, 300)
	_poster_slot.rotation = deg_to_rad(-2.2)
	add_child(_poster_slot)

	_foe_slot = ImageSlot.new(&"adversary-cowboy", "Adversary — cut out on transparency",
		"res://assets/adversary/seated.png")
	_foe_slot.position = Vector2(630, 34)
	_foe_slot.size = Vector2(660, 430)
	add_child(_foe_slot)

	# Brief, known issue #4: imply the player through the near rail, and leave
	# a slot at the bottom edge rather than faking hands in geometry.
	_hands_slot = ImageSlot.new(&"player-hands", "Player hands at the near rail",
		"res://assets/scene/hands.png")
	_hands_slot.position = Vector2(360, 880)
	_hands_slot.size = Vector2(1200, 200)
	add_child(_hands_slot)


func _draw() -> void:
	if layers[&"backdrop"]:
		_draw_backdrop()
	if layers[&"foe"]:
		_draw_adversary()
	if layers[&"table"]:
		_draw_table()
	if layers[&"lip"]:
		_draw_lip()
	_update_lamps()
	_poster_slot.visible = layers[&"backdrop"]
	for slot in [_poster_slot, _foe_slot, _hands_slot]:
		slot.caption = slot.dev_caption if OS.is_debug_build() and show_slot_captions else ""
	_foe_slot.visible = layers[&"foe"] and not adversary_present
	_hands_slot.visible = layers[&"table"]


# --- Layer 1: the room -------------------------------------------------------

func _draw_backdrop() -> void:
	draw_rect(Rect2(Vector2.ZERO, STAGE), ThemeColors.ROOM_DARK, true)
	# Warm pool on the back wall, falling to black at the edges.
	_draw_radial(Rect2(Vector2(-100, -240), Vector2(2120, 1160)),
		ThemeColors.ROOM_WALL, 0.85)

	# Plank wall.
	for x in range(0, 1920, 130):
		draw_rect(Rect2(x + 62, 0, 4, 560), Color(0, 0, 0, 0.30), true)
		draw_rect(Rect2(x + 66, 0, 2, 560), Color(1, 1, 1, 0.03), true)

	# Wainscot.
	draw_rect(Rect2(0, 330, 1920, 230), Color("221710"), true)
	for x in range(0, 1920, 96):
		draw_rect(Rect2(x, 330, 92, 230), Color("2b1d15"), true)
	draw_line(Vector2(0, 330), Vector2(1920, 330), Color(1, 1, 1, 0.06), 2.0)

	# Doorway with batwings, and the cold moonlight behind them.
	var door := Rect2(700, 70, 520, 400)
	draw_rect(door, Color("04060a"), true)
	draw_rect(door.grow(6), Color("150e0a"), false, 6.0)
	draw_rect(Rect2(706, 110, 250, 230), Color("1a110c"), true)
	draw_rect(Rect2(964, 110, 250, 230), Color("1a110c"), true)
	for x in range(706, 1214, 30):
		draw_rect(Rect2(x, 110, 26, 230), Color("241811"), true)
	draw_rect(Rect2(700, 70, 520, 170), Color(0.37, 0.49, 0.59, 0.08), true)

	# Bottle shelf.
	draw_rect(Rect2(120, 250, 420, 14), Color("3a2818"), true)
	var heights := [78, 62, 84, 56, 70]
	for i in heights.size():
		var h: int = heights[i]
		draw_rect(Rect2(140 + i * 44, 250 - h, 22, h), Color("1a2a1c"), true)
		draw_rect(Rect2(140 + i * 44 + 18, 250 - h, 3, h), Color(1, 1, 1, 0.07), true)


# --- Layer 2: the man across the table --------------------------------------

func _draw_adversary() -> void:
	if _foe_slot.has_art():
		return
	# Blockout: crown, brim, head, shoulders. Cold rim light down one side,
	# one red glint. He is the only cold thing in frame.
	var cx := 960.0
	var body := Color("161c24")

	# Shoulders first, so the head and hat sit over them.
	var torso := PackedVector2Array([
		Vector2(cx - 132, 300), Vector2(cx + 132, 300),
		Vector2(cx + 232, 500), Vector2(cx - 232, 500),
	])
	draw_colored_polygon(torso, body)
	draw_line(torso[0], torso[3], Color(ThemeColors.COLD_RIM, 0.55), 3.0)
	draw_line(torso[1], torso[2], Color(ThemeColors.COLD_SHADE, 0.40), 3.0)

	_draw_ellipse(Vector2(cx, 246), Vector2(52, 58), Color("11161d"))
	draw_line(Vector2(cx - 48, 228), Vector2(cx - 42, 282), Color(ThemeColors.COLD_RIM, 0.60), 4.0)
	draw_line(Vector2(cx + 48, 228), Vector2(cx + 42, 282), Color(ThemeColors.COLD_SHADE, 0.40), 4.0)

	# Hat: brim, then crown.
	_draw_ellipse(Vector2(cx, 212), Vector2(154, 30), body)
	draw_arc(Vector2(cx, 210), 152.0, PI, TAU, 40, Color(ThemeColors.COLD_RIM, 0.50), 3.0)
	draw_rect(Rect2(cx - 68, 148, 136, 66), body, true)
	draw_line(Vector2(cx - 68, 150), Vector2(cx + 68, 150), Color(ThemeColors.COLD_RIM, 0.55), 3.0)

	# The single warm note he gets.
	_draw_radial(Rect2(cx - 40, 236, 80, 16), ThemeColors.ADVERSARY, 0.90)


# --- Layer 3 and 4: the table and its zones ---------------------------------

func _draw_table() -> void:
	var wood_hi := ThemeColors.WOOD_HI
	var wood_lo := ThemeColors.WOOD_LO
	if dark_oak:
		wood_hi = Color("2b1e14")
		wood_lo = Color("130d0a")

	# Body: shaded from the far lit edge to the near dark one.
	_draw_shaded_disc(1.0, wood_hi, ThemeColors.WOOD_MID, wood_lo)

	# Grain, running across the boards.
	for i in range(-14, 15):
		var offset := float(i) / 15.0
		var a := projection.project(Vector2(-0.96, offset))
		var b := projection.project(Vector2(0.96, offset))
		draw_line(a, b, Color(0, 0, 0, 0.16), 2.0)

	# The padded rail bumper the felt sits inside.
	_draw_ring(0.995, 0.855, ThemeColors.RAIL_PAD)
	draw_polyline(projection.ring(0.855), ThemeColors.RAIL_EDGE, 3.0, true)
	draw_polyline(projection.ring(1.0), Color(0, 0, 0, 0.45), 3.0, true)
	# Highlight on the far lip, where the lamps catch it.
	var far := projection.ring(0.93)
	for i in range(0, 22):
		draw_line(far[i], far[(i + 1) % far.size()], Color(1, 1, 1, 0.07), 3.0)

	# Felt inset.
	_draw_shaded_disc(0.845, ThemeColors.FELT_HI, ThemeColors.FELT_MID, ThemeColors.FELT_LO)

	# The felt's own light, warm and off-centre toward the lamps.
	var glow_centre := projection.project(Vector2(0.0, 0.30))
	_draw_radial(Rect2(glow_centre - Vector2(680, 300), Vector2(1360, 600)),
		Color("3d5140"), 0.85)
	_draw_radial(Rect2(glow_centre - Vector2(420, 190), Vector2(840, 380)),
		ThemeColors.LAMP_AMBER, 0.10)

	# Zones. Functional, not decorative: the pot is lit, the rail is hotter,
	# past the rail falls into shadow.
	_draw_disc(Balance.rail_inner_radius * 0.845, Color(ThemeColors.LAMP_WARM, 0.10))
	draw_polyline(projection.ring(Balance.rail_inner_radius * 0.845),
		Color(ThemeColors.LAMP_WARM, 0.16), 2.0, true)
	var rail_ring := projection.ring(0.845)
	draw_polyline(rail_ring, Color(ThemeColors.LAMP_WARM, 0.18), 6.0, true)
	draw_polyline(projection.ring(0.80), Color(0, 0, 0, 0.40), 3.0, true)
	# Dashed seam in the felt.
	_draw_dashed_ring(0.76, Color(ThemeColors.INK_DIM, 0.12))

	# Where the hovered draw can reach — the lip included, which is the point.
	if preview_strength >= 0:
		var band: Vector2 = Balance.throw_bands.get(preview_strength, Vector2(0, 1))
		var reach: PackedVector2Array = projection.ring(
			minf(band.y, 1.0) * 0.845 * 0.55 + 0.0)
		draw_polyline(reach, Color(ThemeColors.DECLARED, 0.55), 2.0, true)


func _draw_lip() -> void:
	draw_rect(Rect2(0, 860, 1920, 220), Color("150e09"), true)
	_draw_vertical_fade(Rect2(0, 860, 1920, 220), Color("241811"), Color("070505"))
	draw_line(Vector2(0, 860), Vector2(1920, 860), Color(1, 1, 1, 0.07), 2.0)


# --- Layer 7: the lanterns ---------------------------------------------------

## Light pools and the overlays are separate nodes so each can carry its own
## blend mode; only the lantern hardware is drawn inline.
func _build_blend_layers() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in 4:
		var node := TextureRect.new()
		node.texture = _spill_texture if i < 2 else _lamp_texture
		node.material = additive
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(node)
		_lamp_nodes.append(node)

	_lantern_hardware = Control.new()
	_lantern_hardware.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lantern_hardware.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lantern_hardware.draw.connect(_draw_lantern_hardware)
	add_child(_lantern_hardware)

	var multiply := CanvasItemMaterial.new()
	multiply.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_vignette_node = TextureRect.new()
	_vignette_node.texture = _vignette_texture
	_vignette_node.material = multiply
	_vignette_node.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_node.position = Vector2(-260, -140)
	_vignette_node.size = STAGE + Vector2(520, 280)
	add_child(_vignette_node)

	# Godot has no overlay blend; grain rides as a low-alpha mix instead.
	_grain_node = TextureRect.new()
	_grain_node.texture = _grain_texture
	_grain_node.stretch_mode = TextureRect.STRETCH_TILE
	_grain_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grain_node.size = STAGE
	add_child(_grain_node)


func _update_lamps() -> void:
	var lit_left := lamp_intensity(true)
	var lit_right := lamp_intensity(false)
	var left := _glass_centre(430.0, sway_left)
	var right := _glass_centre(1470.0, sway_right)
	_place_lamp(_lamp_nodes[0], left, 1900.0, Color(1, 1, 1, 0.9 * lit_left))
	_place_lamp(_lamp_nodes[1], right, 1900.0, Color(1, 1, 1, 0.9 * lit_right))
	_place_lamp(_lamp_nodes[2], left, 1024.0, Color(1, 1, 1, lit_left))
	_place_lamp(_lamp_nodes[3], right, 1024.0, Color(1, 1, 1, lit_right))
	for node in _lamp_nodes:
		node.visible = layers[&"lamp"]
	_lantern_hardware.visible = layers[&"lamp"]
	_lantern_hardware.queue_redraw()
	_vignette_node.visible = layers[&"vignette"]
	_vignette_node.modulate = Color(1, 1, 1, vignette_weight)
	_grain_node.visible = layers[&"grain"]
	_grain_node.modulate = Color(1, 1, 1, grain_weight)


func _place_lamp(node: TextureRect, centre: Vector2, span: float, tint: Color) -> void:
	node.position = centre - Vector2(span, span) * 0.5
	node.size = Vector2(span, span)
	node.modulate = tint


func _glass_centre(x: float, sway: float) -> Vector2:
	return Vector2(x + sin(deg_to_rad(sway)) * 190.0, 196)


func _draw_lantern_hardware() -> void:
	_draw_lantern(430.0, sway_left, lamp_intensity(true))
	_draw_lantern(1470.0, sway_right, lamp_intensity(false))


func _draw_lantern(x: float, sway: float, lit: float) -> void:
	var glass_centre := _glass_centre(x, sway)
	var c := _lantern_hardware
	c.draw_line(Vector2(x, 0), glass_centre - Vector2(0, 54), Color("1d150e"), 3.0)
	var cage := Rect2(glass_centre.x - 32, glass_centre.y - 48, 64, 96)
	c.draw_rect(cage, Color("191108"), true)
	c.draw_rect(cage, Color("3d2b1a"), false, 2.0)
	c.draw_rect(Rect2(glass_centre.x - 22, glass_centre.y - 36, 44, 66),
		Color(ThemeColors.LAMP_WARM, lit), true)
	for i in 4:
		c.draw_line(Vector2(cage.position.x + 3 + i * 17, cage.position.y),
			Vector2(cage.position.x + 3 + i * 17, cage.end.y), Color("241a12"), 3.0)


# --- Drawing helpers ---------------------------------------------------------

func _draw_disc(radius: float, colour: Color) -> void:
	draw_colored_polygon(projection.ring(radius), colour)


## Three-stop shading across the disc, far edge to near.
func _draw_shaded_disc(radius: float, far: Color, mid: Color, near: Color) -> void:
	var points := projection.ring(radius)
	var colours := PackedColorArray()
	for i in points.size():
		var a := TAU * float(i) / float(points.size())
		var t := (sin(a) + 1.0) * 0.5   # 0 at the far edge, 1 at the near
		colours.append(far.lerp(mid, minf(1.0, t * 2.0)) if t < 0.5 else mid.lerp(near, (t - 0.5) * 2.0))
	draw_polygon(points, colours)


func _draw_ring(outer: float, inner: float, colour: Color) -> void:
	var out_points := projection.ring(outer)
	var in_points := projection.ring(inner)
	for i in out_points.size():
		var j := (i + 1) % out_points.size()
		draw_colored_polygon(PackedVector2Array([
			out_points[i], out_points[j], in_points[j], in_points[i],
		]), colour)


func _draw_dashed_ring(radius: float, colour: Color) -> void:
	var points := projection.ring(radius, 72)
	for i in range(0, points.size(), 2):
		draw_line(points[i], points[(i + 1) % points.size()], colour, 1.0)


func _draw_ellipse(centre: Vector2, radii: Vector2, colour: Color) -> void:
	var points := PackedVector2Array()
	for i in 48:
		var a := TAU * float(i) / 48.0
		points.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, colour)


func _draw_ellipse_outline(centre: Vector2, radii: Vector2, colour: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 48:
		var a := TAU * float(i) / 48.0
		points.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_polyline(points, colour, width, true)


var _radial_cache := {}

func _draw_radial(rect: Rect2, colour: Color, alpha: float) -> void:
	var key := "%s:%f" % [colour.to_html(), alpha]
	if not _radial_cache.has(key):
		_radial_cache[key] = _radial([[0.0, Color(colour, alpha)], [1.0, Color(colour, 0.0)]])
	draw_texture_rect(_radial_cache[key], rect, false)


func _draw_vertical_fade(rect: Rect2, top: Color, bottom: Color) -> void:
	var steps := 24
	for i in steps:
		var t := float(i) / float(steps - 1)
		draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * float(i) / steps,
			rect.size.x, rect.size.y / steps + 1), top.lerp(bottom, t), true)


