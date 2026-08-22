class_name Scorecard
extends RefCounted
## Thirteen boxes. The card is not reset between floors — it is the health bar.

enum State { OPEN, PLAYER, ADVERSARY, BURNED }

signal box_written(box: int, state: int, points: int)
signal boxes_reclaimed(boxes: Array)

var states: Array[int] = []
var points: Array[int] = []
## Order in which boxes were spent, newest last. Used for reclaim.
var spend_order: Array[int] = []
## Running total of everything the player has ever scored this run.
var run_total: int = 0


func _init() -> void:
	reset()


func reset() -> void:
	states.clear()
	points.clear()
	spend_order.clear()
	run_total = 0
	for i in Scoring.BOX_COUNT:
		states.append(State.OPEN)
		points.append(0)


func is_open(box: int) -> bool:
	return states[box] == State.OPEN


func open_boxes() -> Array[int]:
	var out: Array[int] = []
	for i in Scoring.BOX_COUNT:
		if states[i] == State.OPEN:
			out.append(i)
	return out


func open_count() -> int:
	return open_boxes().size()


func count_state(state: int) -> int:
	var n := 0
	for s in states:
		if s == state:
			n += 1
	return n


func adversary_count() -> int:
	return count_state(State.ADVERSARY)


func player_boxes() -> Array[int]:
	var out: Array[int] = []
	for i in Scoring.BOX_COUNT:
		if states[i] == State.PLAYER:
			out.append(i)
	return out


func is_exhausted() -> bool:
	return open_count() == 0


## The player writes into a box. Scoring a zero here is a scratch — a real move.
func write_player(box: int, value: int) -> void:
	_write(box, State.PLAYER, value)
	run_total += value


## The Adversary claims a box. It shortens you rather than damaging you.
func write_adversary(box: int, value: int) -> void:
	_write(box, State.ADVERSARY, value)


## The Furnace burns a box: unscored, gone.
func burn(box: int) -> void:
	_write(box, State.BURNED, 0)


## The Debtor overwrites a box you already filled.
func overwrite(box: int, value: int, state: int = State.ADVERSARY) -> int:
	var lost := points[box]
	if states[box] == State.PLAYER:
		run_total -= lost
		spend_order.erase(box)
	states[box] = state
	points[box] = value
	if state != State.OPEN:
		spend_order.append(box)
	box_written.emit(box, state, value)
	return lost


func _write(box: int, state: int, value: int) -> void:
	states[box] = state
	points[box] = value
	spend_order.append(box)
	box_written.emit(box, state, value)


## Winning heals the run: the most recently spent player boxes open back up.
## Their points stay on the run total — you keep what you earned.
func reclaim(count: int) -> Array[int]:
	var reclaimed: Array[int] = []
	var i := spend_order.size() - 1
	while i >= 0 and reclaimed.size() < count:
		var box: int = spend_order[i]
		if states[box] == State.PLAYER:
			states[box] = State.OPEN
			reclaimed.append(box)
			spend_order.remove_at(i)
		i -= 1
	if not reclaimed.is_empty():
		boxes_reclaimed.emit(reclaimed)
	return reclaimed


func state_tag(box: int) -> String:
	match states[box]:
		State.PLAYER:
			return "you"
		State.ADVERSARY:
			return "them"
		State.BURNED:
			return "burned"
	return "open"


func to_dict() -> Dictionary:
	return {"states": states.duplicate(), "points": points.duplicate(), "total": run_total}
