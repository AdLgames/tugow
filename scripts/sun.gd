class_name Sun
extends Node2D
## Daylight from outside the room, and the short shadow the walls throw
## because of it.
##
## This is drawn rather than lit, and that is not a shortcut — it is the only
## thing that works. A Light2D placed outside the room is blocked by the wall
## ring it is standing behind, so every occluder-based shadow would put the
## *entire* interior in shadow and the room would go black. Sunlight in a
## top-down room is therefore a wall-shaped smear offset across the floor,
## which is also what makes it controllable: the offset is the time of day.
##
## Interior lights are still real lights — see scenes/lamp.tscn. This handles
## only the sun.

## Where the sun is, on a clock. Noon puts it straight above the room and
## throws the shadows straight down; each hour after that moves it 15 degrees
## towards the right-hand side, so early afternoon sits over the top-right
## corner and the shadows fall down and to the left.
@export var hour: float = 13.5:
	set(value):
		hour = clampf(value, 6.0, 18.0)
		queue_redraw()

## How far a wall's shadow reaches, in pixels. This is the sun's height, in
## effect: a high sun makes a short shadow. Anything past half a cell starts
## to read as evening.
@export var length: float = 8.0:
	set(value):
		length = maxf(0.0, value)
		queue_redraw()

@export var color: Color = Color(0.05, 0.04, 0.10, 0.32):
	set(value):
		color = value
		queue_redraw()

var _world: World


## Called by World once the layers exist. Kept explicit rather than hunting
## for the parent, so this node can be dropped under something else later.
func paint(world: World) -> void:
	_world = world
	queue_redraw()


## Which way a shadow points, in pixels. Straight down at noon, swinging left
## as the afternoon goes on.
func offset() -> Vector2:
	var from_vertical := deg_to_rad((hour - 12.0) * 15.0)
	return Vector2(-sin(from_vertical), cos(from_vertical)) * length


func _draw() -> void:
	if _world == null:
		return
	var cell := Vector2(World.CELL, World.CELL)
	var shift := offset()
	# Every wall cell is the same size and they do not overlap, so neither do
	# their shadows — no need to merge them, and no double-darkened seams
	# where two walls meet.
	for at in shadow_cells():
		var corner := _world.centre_of(at) - cell * 0.5 + shift
		draw_rect(Rect2(corner, cell), color)
	# Props stand in the same daylight. Their shadow comes off the footprint
	# rather than the whole height, for the same reason the lamps' does: a
	# shelf should darken the floor beside it, not paint a wall of black.
	for child in _world.props.get_children():
		var prop := child as Prop
		if prop == null:
			continue
		var base := Vector2(prop.width, Prop.FOOTPRINT)
		var at := prop.position - Vector2(base.x * 0.5, base.y) + shift
		draw_rect(Rect2(at, base), color)


## Wall cells whose shadow would land on something. A wall on the outside of
## the room throws its shadow into the void beyond the map, where a dark
## rectangle sitting on the background reads as a hole rather than a shadow.
##
## The test is on the neighbouring cell rather than on where the offset lands,
## because a short shadow does not clear its own cell — at five pixels it is
## still inside the wall it came from, and asking that cell whether it is
## floor would rule out every shadow in the room.
func shadow_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var shift := offset()
	var step := Vector2i(signi(roundi(shift.x)), signi(roundi(shift.y)))
	var toward: Array[Vector2i] = [step, Vector2i(step.x, 0), Vector2i(0, step.y)]
	for layer in _world.layers():
		for at in layer.get_used_cells():
			if not _world.is_blocked(at) or out.has(at):
				continue
			for neighbour in toward:
				if neighbour != Vector2i.ZERO and _world.is_floor(at + neighbour):
					out.append(at)
					break
	return out
