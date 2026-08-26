class_name DieMesh
extends RefCounted
## The die, built face by face.
##
## A BoxMesh's own unwrap puts the six faces somewhere in the texture, and
## "somewhere" is not good enough here: the face pointing at the ceiling is
## the face the rules score, so the pips a player counts have to be the pips
## on that side of the cube. Building the mesh explicitly means each face's
## UVs are chosen, not guessed at, and the mapping is the same one
## DieBody.FACE_AXES scores from.
##
## Opposite faces sum to seven, as a real die's do.

## normal, value — matching DieBody.FACE_AXES exactly.
const FACES := [
	[Vector3.UP, 6],
	[Vector3.DOWN, 1],
	[Vector3.RIGHT, 5],
	[Vector3.LEFT, 2],
	[Vector3.BACK, 4],
	[Vector3.FORWARD, 3],
]


static func build(size: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var half := size * 0.5

	for slot in FACES.size():
		var normal: Vector3 = FACES[slot][0]
		var value: int = FACES[slot][1]
		var right := _tangent(normal)
		var up := normal.cross(right).normalized()
		var centre := normal * half

		var corners := [
			centre - right * half - up * half,
			centre + right * half - up * half,
			centre + right * half + up * half,
			centre - right * half + up * half,
		]
		# The atlas is one row of six cells, in DiePips.CELL_ORDER.
		var cell := float(DiePips.CELL_ORDER.find(value))
		var span := 1.0 / float(DiePips.CELL_ORDER.size())
		var face_uvs := [
			Vector2((cell + 0.001) * span, 0.999),
			Vector2((cell + 0.999) * span, 0.999),
			Vector2((cell + 0.999) * span, 0.001),
			Vector2((cell + 0.001) * span, 0.001),
		]

		var base := vertices.size()
		for i in 4:
			vertices.append(corners[i])
			normals.append(normal)
			uvs.append(face_uvs[i])
		# Wound so the outward side is the front face. Reversed, every face is
		# culled and the camera sees the inside of the far one — which shows
		# the opposite value, and a die scored as a six renders as a one.
		for offset in [0, 2, 1, 0, 3, 2]:
			indices.append(base + offset)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Any axis perpendicular to the normal will do for the face's own right.
static func _tangent(normal: Vector3) -> Vector3:
	if absf(normal.dot(Vector3.UP)) > 0.9:
		return Vector3.RIGHT
	return Vector3.UP.cross(normal).normalized()
