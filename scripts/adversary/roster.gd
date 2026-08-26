class_name AdversaryRoster
extends RefCounted
## The five opponents. The Reflection and the Magpie are the ones that turn locking
## into a bluffing game — they are the prototype pair.


class Taxman extends Adversary:
	func _init() -> void:
		super(&"taxman", "The Taxman",
			"Claims only upper-section boxes, methodically, low to high. Slow and honest. Brutal if ignored.")

	func choose_box(_game, options: Array[int]) -> int:
		for box in Scoring.UPPER_BOXES:
			if options.has(box):
				return box
		# Upper section exhausted: it falls back to plain greed.
		return super(_game, options)


class Magpie extends Adversary:
	func _init() -> void:
		super(&"magpie", "The Magpie",
			"Always targets whichever box you are building toward. Reads your locks. Punishes telegraphing.")
		locks_dice = true

	func choose_box(game, options: Array[int]) -> int:
		var read := _read_player(game)
		var best := -1
		var best_score := -1
		for box in options:
			var s := Scoring.score(box, read)
			if not Scoring.is_pattern_met(box, read):
				s = 0
			if s > best_score:
				best_score = s
				best = box
		if best_score <= 0:
			return super(game, options)
		return best

	## What the player's locks and last table say they are chasing.
	func _read_player(game) -> Array:
		var values: Array = []
		for d in game.pool.locked_by("player"):
			values.append(d.value)
		if values.size() < Balance.dice_per_roll:
			for v in game.last_player_values:
				values.append(v)
				if values.size() >= Balance.dice_per_roll:
					break
		return values


class Reflection extends Adversary:
	func _init() -> void:
		super(&"reflection", "The Reflection",
			"Rolls whatever you rolled last turn. Beat it by playing badly.")

	func choose_box(game, options: Array[int]) -> int:
		var mirror: Array = game.last_player_values
		if mirror.is_empty():
			return super(game, options)
		var best: int = options[0]
		var best_score := -1
		for box in options:
			var s := Scoring.score(box, mirror)
			if s > best_score:
				best_score = s
				best = box
		return best

	## It does not roll at all — it wears your last roll.
	func _roll_toward(game, _box: int) -> Array:
		if game.last_player_values.is_empty():
			return super(game, _box)
		return game.last_player_values.duplicate()


class Fire extends Adversary:
	func _init() -> void:
		super(&"fire", "The Fire",
			"Does not claim boxes. Burns one per turn, unscored, gone. Pure clock. Cannot be denied, only outrun.")

	## It burns your best remaining box — the one you were saving.
	func choose_box(_game, options: Array[int]) -> int:
		var best: int = options[0]
		var best_value := -1
		for box in options:
			var v := _expected_value(box)
			if v > best_value:
				best_value = v
				best = box
		return best

	func take_turn(game) -> String:
		var box := declared_box
		if box < 0 or not game.card.is_open(box):
			var options: Array[int] = game.card.open_boxes()
			if options.is_empty():
				return "%s has nothing left to burn." % display_name
			box = choose_box(game, options)
		game.card.burn(box)
		return "%s burns %s to ash." % [display_name, Scoring.box_name(box)]


class Debtor extends Adversary:
	func _init() -> void:
		super(&"debtor", "The Debtor",
			"Scores into boxes you have already filled, overwriting them. Your best score is never safe.")

	func declare(game) -> int:
		var filled: Array[int] = game.card.player_boxes()
		if filled.is_empty():
			return super(game)
		var best: int = filled[0]
		for box in filled:
			if game.card.points[box] > game.card.points[best]:
				best = box
		declared_box = best
		return declared_box

	func take_turn(game) -> String:
		var box := declared_box
		var filled: Array[int] = game.card.player_boxes()
		if box < 0 or (not filled.has(box) and not game.card.is_open(box)):
			if filled.is_empty():
				return super(game)
			box = filled[0]
		_values = _roll_toward(game, box)
		var value := Scoring.score(box, _values)
		duel_score += value
		var lost: int = game.card.overwrite(box, value)
		if lost > 0:
			return "%s overwrites your %s: %d becomes %d." % [display_name, Scoring.box_name(box), lost, value]
		return "%s writes %s for %d." % [display_name, Scoring.box_name(box), value]


static func all() -> Array[Adversary]:
	var out: Array[Adversary] = []
	out.append(Taxman.new())
	out.append(Magpie.new())
	out.append(Reflection.new())
	out.append(Fire.new())
	out.append(Debtor.new())
	return out


## Difficulty order across a run: teaching fight first, bosses last.
## Who sits down on a given night. The last night of a week is that week's
## own man; the duel nights leading up to it are the ones you already beat,
## in the order you met them. So week 5 walks you back through the whole
## roster before its own boss arrives.
static func for_floor(n: int) -> Adversary:
	var roster := all()
	var week: int = Balance.week_of(n)
	# 0 on the last night of the week, 1 the night before, and so on.
	var back: int = Balance.nights_per_week - Balance.night_of(n)
	var index: int = clampi(week - 1 - back, 0, roster.size() - 1)
	return roster[index]


static func by_id(adversary_id: StringName) -> Adversary:
	for a in all():
		if a.id == adversary_id:
			return a
	return null
