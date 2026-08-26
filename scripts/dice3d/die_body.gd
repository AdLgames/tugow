class_name DieBody
extends RigidBody3D
## One physical die. The sim is authoritative: the face that ends up pointing
## at the ceiling is the face you rolled, and where it comes to rest is the
## zone it scored in.

## Which pip value each local axis carries. Opposite faces sum to seven, which
## is what makes the underside rule (7 - shown) true of the real object.
const FACE_AXES := [
	[Vector3.UP, 6],
	[Vector3.DOWN, 1],
	[Vector3.RIGHT, 5],
	[Vector3.LEFT, 2],
	[Vector3.BACK, 4],
	[Vector3.FORWARD, 3],
]

## Beyond this tilt a die is resting on something, not lying flat.
const FLAT_DOT := 0.86

var die_id: int = 0
var settled_value: int = 0
## Set by the sim when this die comes to rest on another one.
var cocked_on: int = -1

var _size: float = 0.5


func _init(p_id: int = 0, size: float = 0.5) -> void:
	die_id = p_id
	_size = size
	contact_monitor = true
	max_contacts_reported = 6
	continuous_cd = true
	can_sleep = true
	# Dice are dense and lively: they should bounce off the rail, not stick.
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.55
	physics_material_override.bounce = 0.28
	mass = 0.6
	# Felt eats momentum: without this the window where a die stops mid-table
	# is too narrow for the three bands to differ.
	linear_damp = 0.9
	angular_damp = 1.1


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * _size
	shape.shape = box
	add_child(shape)


## The face pointing closest to world up. Cheap and reliable — D4.
func read_face() -> int:
	var best_value := 1
	var best_dot := -2.0
	for entry in FACE_AXES:
		var axis: Vector3 = entry[0]
		var world_axis := (global_transform.basis * axis).normalized()
		var dot := world_axis.dot(Vector3.UP)
		if dot > best_dot:
			best_dot = dot
			best_value = entry[1]
	return best_value


## How square the die is sitting. Below FLAT_DOT it is leaning on something.
func flatness() -> float:
	var best := -2.0
	for entry in FACE_AXES:
		var world_axis := (global_transform.basis * (entry[0] as Vector3)).normalized()
		best = maxf(best, world_axis.dot(Vector3.UP))
	return best


func is_flat() -> bool:
	return flatness() >= FLAT_DOT


## The two faces a leaning die is showing: the one nearest the ceiling, and
## the one it has tipped toward. A die that has not settled flat is cocked,
## and this is what it reads as.
func read_two_faces() -> Array:
	var scored: Array = []
	for entry in FACE_AXES:
		var world_axis := (global_transform.basis * (entry[0] as Vector3)).normalized()
		scored.append([world_axis.dot(Vector3.UP), int(entry[1])])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	return [int(scored[0][1]), int(scored[1][1])]


func at_rest() -> bool:
	return sleeping or (linear_velocity.length() < 0.06 and angular_velocity.length() < 0.12)


## Distance from the middle of the table, in table radii.
func table_radius(lip_radius: float) -> float:
	return Vector2(global_position.x, global_position.z).length() / lip_radius


## The orientation that shows a given face to the ceiling. A staked die is
## put down showing the face it was staked on, rather than being thrown and
## happening to agree.
static func basis_showing(value: int) -> Basis:
	for entry in FACE_AXES:
		if int(entry[1]) != value:
			continue
		var axis: Vector3 = entry[0]
		if axis.is_equal_approx(Vector3.UP):
			return Basis.IDENTITY
		if axis.is_equal_approx(Vector3.DOWN):
			return Basis(Vector3.RIGHT, PI)
		# Turned so the wanted face ends up on top. The other way round puts
		# it face down, and the die shows its opposite.
		return Basis(axis.cross(Vector3.UP).normalized(), PI * 0.5)
	return Basis.IDENTITY


## Set the die down at rest, showing `value`. Used for staked dice, which are
## not thrown at all.
func rest_at(at: Vector3, value: int) -> void:
	throw_from(at, basis_showing(value), Vector3.ZERO, Vector3.ZERO)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING, true)
	settled_value = value


## Place and throw the die in one go, through the physics server.
##
## Determinism (D2) turned out to hinge on this. Assigning the transform races
## the server, and going through _integrate_forces only helps for bodies that
## are already awake — a sleeping die takes an extra tick to receive its
## throw, enters the pile late, and collides differently. body_set_state
## applies to every die on the same tick whatever its sleep state.
func throw_from(origin: Vector3, basis_in: Basis, impulse: Vector3, spin: Vector3) -> void:
	var body := get_rid()
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM,
		Transform3D(basis_in, origin))
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_SLEEPING, false)
	PhysicsServer3D.body_apply_impulse(body, impulse)
	PhysicsServer3D.body_apply_torque_impulse(body, spin)
