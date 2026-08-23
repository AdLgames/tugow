class_name Adversary
extends RefCounted
## The opponent writes on your scorecard. Every box it claims is a box you can
## never use again — it does not damage you, it shortens you.

const TAG := "adversary"

var id: StringName
var display_name: String
var blurb: String
## The box it has announced. You get exactly one turn to respond.
var declared_box: int = -1
## Total the Adversary has scored this duel.
var duel_score: int = 0
## Some Adversaries lock dice away from the shared pool.
var locks_dice: bool = false

var _values: Array = []


func _init(p_id: StringName = &"", p_name: String = "", p_blurb: String = "") -> void:
	id = p_id
	display_name = p_name
	blurb = p_blurb


func on_duel_start(_game) -> void:
	duel_score = 0
	declared_box = -1


## Announce the next target. Called after each of its turns and at duel start.
func declare(game) -> int:
	var options: Array[int] = game.card.open_boxes()
	if options.is_empty():
		declared_box = -1
		return -1
	declared_box = choose_box(game, options)
	return declared_box


## Overridden per Adversary.
func choose_box(game, options: Array[int]) -> int:
	var best: int = options[0]
	var best_value := -1
	for box in options:
		var v := _expected_value(box)
		if v > best_value:
			best_value = v
			best = box
	return best


## Roll, reroll toward the declared box, then write. Returns a log line.
func take_turn(game) -> String:
	var box := declared_box
	if box < 0 or not game.card.is_open(box):
		var options: Array[int] = game.card.open_boxes()
		if options.is_empty():
			return "%s finds no box left to take." % display_name
		box = choose_box(game, options)
	_values = _roll_toward(game, box)
	var value := Scoring.score(box, _values)
	duel_score += value
	game.card.write_adversary(box, value)
	if locks_dice:
		_lock_favourites(game)
	return "%s takes %s with %s for %d." % [display_name, Scoring.box_name(box), str(_values), value]


func last_values() -> Array:
	return _values


## Draws five from the shared pool — player-locked dice are unavailable.
func _roll_toward(game, box: int) -> Array:
	var dice: Array[Die] = game.pool.begin_turn(TAG)
	game.pool.roll_table()
	for _i in Balance.rerolls_per_turn:
		var keep := _keep_mask(game.pool.table_values(), box)
		var rerolled := false
		for i in dice.size():
			if keep[i] or dice[i].locked:
				continue
			dice[i].roll()
			rerolled = true
		if not rerolled:
			break
	return game.pool.table_values()


func _keep_mask(values: Array, box: int) -> Array[bool]:
	var keep: Array[bool] = []
	for i in values.size():
		keep.append(false)
	match box:
		Scoring.Box.ACES, Scoring.Box.TWOS, Scoring.Box.THREES, \
		Scoring.Box.FOURS, Scoring.Box.FIVES, Scoring.Box.SIXES:
			var face := box + 1
			for i in values.size():
				keep[i] = values[i] == face
		Scoring.Box.THREE_KIND, Scoring.Box.FOUR_KIND, Scoring.Box.YAHTZEE, Scoring.Box.FULL_HOUSE:
			var modal := _modal_face(values)
			for i in values.size():
				keep[i] = values[i] == modal
		Scoring.Box.SMALL_STRAIGHT, Scoring.Box.LARGE_STRAIGHT:
			var seen := {}
			for i in values.size():
				if not seen.has(values[i]):
					seen[values[i]] = true
					keep[i] = true
		Scoring.Box.CHANCE:
			for i in values.size():
				keep[i] = values[i] >= 5
	return keep


func _modal_face(values: Array) -> int:
	var counts := {}
	for v in values:
		counts[v] = counts.get(v, 0) + 1
	var best := 0
	var best_count := 0
	for face in counts:
		# Ties break high — a big face is worth more under every operator.
		if counts[face] > best_count or (counts[face] == best_count and int(face) > best):
			best = int(face)
			best_count = counts[face]
	return best


func _lock_favourites(game) -> void:
	for d in game.pool.table:
		if d.locked:
			continue
		if d.value >= 5:
			game.pool.lock_die(d, TAG)
			return


## Rough table-independent worth of a box, used for target selection.
func _expected_value(box: int) -> int:
	match box:
		Scoring.Box.YAHTZEE:
			return 900
		Scoring.Box.LARGE_STRAIGHT:
			return 500
		Scoring.Box.FOUR_KIND:
			return 400
		Scoring.Box.FULL_HOUSE:
			return 200
		Scoring.Box.SMALL_STRAIGHT:
			return 150
		Scoring.Box.THREE_KIND:
			return 120
		Scoring.Box.CHANCE:
			return 80
	return (box + 1) * (box + 1) * 3
