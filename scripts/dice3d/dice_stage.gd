class_name DiceStage
extends SubViewportContainer
## The physical dice, rendered. A SubViewport holding the simulation, a camera
## looking down at the felt, and a light — composited into the saloon over the
## clear felt so the dice you watch are the dice the rules read.
##
## Game asks this for a throw and waits; when the bodies settle it hands back
## contract records. Nothing decides a face here.

signal throw_settled(records: Array)

## Elevation above the felt. The painted table is drawn at the scene's own
## camera angle, so this has to sit near it or the rendered dice look like
## they are on a different table — but a little steeper, because at the
## painted angle the top faces foreshorten and the pips stop being countable.
## Flat enough that the whole play area fits the band of felt the interface
## leaves visible, steep enough that a top face is still countable.
var camera_pitch: float = 26.0
var camera_distance: float = 12.0

var sim: DiceSim
var viewport: SubViewport
var camera: Camera3D

var _pip_material: StandardMaterial3D
var _throwing: bool = false


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	viewport = SubViewport.new()
	# Its own world: the host is a 2D scene, and without this the bodies are
	# added to a world no camera here is looking at.
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(size)
	add_child(viewport)

	sim = DiceSim.new()
	viewport.add_child(sim)
	sim.spawn(Balance.dice_per_roll)
	sim.settled.connect(_on_settled)

	camera = Camera3D.new()
	camera.fov = 46.0
	# Added to the tree first: look_at needs a valid global transform, and a
	# camera that has not been added yet keeps an identity basis — which
	# unprojects every die to somewhere off the frame.
	viewport.add_child(camera)
	aim_camera()

	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-58.0, -34.0, 0.0)
	lamp.light_energy = 1.5
	lamp.light_color = ThemeColors.LAMP_WARM
	viewport.add_child(lamp)

	# Something for the felt to bounce: with no environment the dice render
	# as silhouettes.
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_CLEAR_COLOR
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = ThemeColors.LAMP_AMBER
	settings.ambient_light_energy = 0.55
	environment.environment = settings
	viewport.add_child(environment)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-3.0, 5.0, 2.0)
	fill.omni_range = 22.0
	fill.light_energy = 0.8
	fill.light_color = ThemeColors.LAMP_AMBER
	viewport.add_child(fill)

	_pip_material = _make_die_material()
	_dress_bodies()
	resized.connect(_on_resized)


## Placed so the whole table is in frame, whatever the strip's proportions.
func aim_camera() -> void:
	if camera == null:
		return
	var pitch := deg_to_rad(camera_pitch)
	camera.position = Vector3(0.0, sin(pitch) * camera_distance, cos(pitch) * camera_distance)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	# Fit the table's width across the frame. Its depth on screen is
	# foreshortened by the angle, which is what lets a round table sit in a
	# wide, shallow band.
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	var across := DiceSim.LIP_RADIUS * 2.2
	camera.fov = clampf(rad_to_deg(2.0 * atan(across * 0.5 / camera_distance)), 20.0, 80.0)


func _on_resized() -> void:
	if viewport != null:
		viewport.size = Vector2i(size)
	aim_camera()


## Bone-coloured, with the pips baked into the texture rather than modelled —
## geometry pips cost more and fight legibility at this size.
func _make_die_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = DiePips.atlas()
	material.roughness = 0.72
	material.metallic = 0.0
	return material


func _dress_bodies() -> void:
	for body in sim.bodies:
		if body.has_node("Mesh"):
			continue
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh"
		var box := BoxMesh.new()
		box.size = Vector3.ONE * DiceSim.DIE_SIZE
		mesh.mesh = box
		mesh.material_override = _pip_material
		body.add_child(mesh)


func is_throwing() -> bool:
	return _throwing


## Throw, and let the caller wait for `throw_settled`.
func begin_throw(strength: int, seed_value: int, held: Array = [], ids: Array = []) -> void:
	_throwing = true
	sim.begin_throw(sim.bodies, strength, seed_value, held, ids)
	_dress_bodies()


func _on_settled(records: Array) -> void:
	_throwing = false
	throw_settled.emit(records)


## Where a die is on screen, for the label and the hit area that sits over it.
## Where a die of the pool is on screen, by its id.
func screen_position_of(die_id: int) -> Vector2:
	if camera == null:
		return Vector2(-999, -999)
	for body in sim.bodies:
		if body.die_id != die_id:
			continue
		if body.global_position.y < DiceSim.DIRT_Y:
			return Vector2(-999, -999)
		# A die behind the camera unprojects to nonsense.
		if camera.is_position_behind(body.global_position):
			return Vector2(-999, -999)
		var at := camera.unproject_position(body.global_position)
		if at.x < 0.0 or at.y < 0.0 or at.x > size.x or at.y > size.y:
			return Vector2(-999, -999)
		return position + at
	return Vector2(-999, -999)
