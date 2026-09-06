class_name Shop
extends RefCounted
## The floor: what is where, and what is on it.
##
## The grid is small and the rules about it are few, so it is kept as plain
## data the view can read rather than a node tree. Level 1 is 8x8; the
## expansion re-lays the same shop at 16x16 without losing anything on it.

enum Cell { FLOOR, WALL, ALTAR, TABLE, CASE, DOOR, BACKROOM }

const TABLE_CAPACITY := 3

var size: int = 8
var cells: Array[int] = []
## Tables and cases, by cell index, each holding up to TABLE_CAPACITY units.
var displays: Dictionary = {}
## Everything gathered but not yet put out. Level 2 gives it a room; level 1
## keeps it in your arms.
var backroom: Array = []

var altar := Vector2i(0, 0)
var door := Vector2i(0, 0)


func _init(p_size: int = 8) -> void:
	build(p_size)


## Lay out a shop. The altar sits at the back, the door at the front, and the
## tables in rows you can walk between — a customer must be able to reach any
## display, so nothing is ever placed against a wall it cannot be read from.
func build(p_size: int) -> void:
	size = p_size
	cells.clear()
	for i in size * size:
		cells.append(Cell.FLOOR)
	for x in size:
		_put(Vector2i(x, 0), Cell.WALL)
		_put(Vector2i(x, size - 1), Cell.WALL)
	for y in size:
		_put(Vector2i(0, y), Cell.WALL)
		_put(Vector2i(size - 1, y), Cell.WALL)

	door = Vector2i(size / 2, size - 1)
	_put(door, Cell.DOOR)
	altar = Vector2i(size / 2, 1)
	_put(altar, Cell.ALTAR)

	# A backroom, once there is room for one.
	if size >= 12:
		for x in range(1, 4):
			for y in range(1, 4):
				if Vector2i(x, y) != altar:
					_put(Vector2i(x, y), Cell.BACKROOM)

	_lay_tables()


## Rows of tables with a gap between them. Every table has at least one open
## side, or a customer could not reach it and the sale would never happen.
func _lay_tables() -> void:
	var kept := displays.duplicate()
	displays.clear()
	# Rows with aisles cut through them. A solid row of tables reads as a wall
	# and leaves nowhere to stand, so every third column is left open.
	for y in range(3, size - 2, 2):
		for x in range(2, size - 2):
			if x % 3 == 0:
				continue
			if get_cell(Vector2i(x, y)) != Cell.FLOOR:
				continue
			_put(Vector2i(x, y), Cell.TABLE)
			displays[index_of(Vector2i(x, y))] = []
	# Anything already on a table stays on one.
	var spare: Array = []
	for key in kept:
		for unit in kept[key]:
			spare.append(unit)
	for key in displays:
		while not spare.is_empty() and displays[key].size() < TABLE_CAPACITY:
			displays[key].append(spare.pop_front())
	for unit in spare:
		backroom.append(unit)


func index_of(at: Vector2i) -> int:
	return at.y * size + at.x


func position_of(index: int) -> Vector2i:
	return Vector2i(index % size, index / size)


func in_bounds(at: Vector2i) -> bool:
	return at.x >= 0 and at.y >= 0 and at.x < size and at.y < size


func get_cell(at: Vector2i) -> int:
	if not in_bounds(at):
		return Cell.WALL
	return cells[index_of(at)]


func _put(at: Vector2i, cell: int) -> void:
	if in_bounds(at):
		cells[index_of(at)] = cell


## Walkable for people. Tables and cases are furniture; the door is the way in.
func walkable(at: Vector2i) -> bool:
	var cell := get_cell(at)
	return cell == Cell.FLOOR or cell == Cell.DOOR or cell == Cell.BACKROOM \
		or cell == Cell.ALTAR


func display_indices() -> Array[int]:
	var out: Array[int] = []
	for key in displays:
		out.append(int(key))
	out.sort()
	return out


func is_display(at: Vector2i) -> bool:
	return displays.has(index_of(at))


func stock_at(at: Vector2i) -> Array:
	return displays.get(index_of(at), [])


## Put a unit out. Returns false when the table is full, which is the only
## reason it can fail.
func place(at: Vector2i, unit: Goods.Unit) -> bool:
	var key := index_of(at)
	if not displays.has(key):
		return false
	if displays[key].size() >= TABLE_CAPACITY:
		return false
	displays[key].append(unit)
	return true


func take(at: Vector2i) -> Goods.Unit:
	var key := index_of(at)
	if not displays.has(key) or displays[key].is_empty():
		return null
	return displays[key].pop_back()


## Every display with something on it that has not turned.
func stocked_displays() -> Array[int]:
	var out: Array[int] = []
	for key in displays:
		for unit in displays[key]:
			if not unit.rotted:
				out.append(int(key))
				break
	return out


## The first display with something on it, or simply the first display. Used
## where a caller needs somewhere to put a thing and does not care where.
func stocked_or_first() -> int:
	var stocked := stocked_displays()
	if not stocked.is_empty():
		return stocked[0]
	return display_indices()[0]


func units_on_floor() -> int:
	var n := 0
	for key in displays:
		n += displays[key].size()
	return n


func rotted_on_floor() -> int:
	var n := 0
	for key in displays:
		for unit in displays[key]:
			if unit.rotted:
				n += 1
	return n


## Clear what has turned, wherever it is. Returns how much was thrown out.
func sweep_rot() -> int:
	var n := 0
	for key in displays:
		var keep: Array = []
		for unit in displays[key]:
			if unit.rotted:
				n += 1
			else:
				keep.append(unit)
		displays[key] = keep
	var kept_back: Array = []
	for unit in backroom:
		if unit.rotted:
			n += 1
		else:
			kept_back.append(unit)
	backroom = kept_back
	return n


## The nearest walkable tile a customer can stand on to reach a display.
func approach_to(at: Vector2i) -> Vector2i:
	var steps: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 0), Vector2i(-1, 0)]
	for step in steps:
		var spot: Vector2i = at + step
		if walkable(spot):
			return spot
	return at
