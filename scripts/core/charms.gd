class_name Charms
extends RefCounted
## The charm library. Each is a small class; `library()` builds one of each.


class Grudge extends Charm:
	func _init() -> void:
		super(&"grudge", "Grudge", "A die that rolls a 1 is furious next turn: +2 to every face.")

	func on_roll(game) -> void:
		for d in game.pool.table:
			if d.value == 1 and not d.locked:
				d.furious = true


class Symmetry extends Charm:
	func _init() -> void:
		super(&"symmetry", "Symmetry", "If your dice read the same forwards and backwards, score the box twice.")

	func modify_score(game, _box: int, values: Array, base: int) -> int:
		if values.size() < 2:
			return base
		var reversed_values := values.duplicate()
		reversed_values.reverse()
		if reversed_values == values:
			game.log_line("Symmetry: %s reads both ways — scored twice." % str(values))
			return base * 2
		return base


class Tithe extends Charm:
	var locks_seen: int = 0
	var pending: int = 0

	func _init() -> void:
		super(&"tithe", "The Tithe", "Every sixth die you lock is sacrificed; its value is added to your next score.")

	func on_floor_start(_game) -> void:
		pending = 0

	func on_lock(game, die: Die) -> void:
		locks_seen += 1
		if locks_seen % 6 != 0:
			return
		pending += die.value
		die.unlock()
		die.value = 0
		game.pool.table.erase(die)
		game.log_line("The Tithe takes %s. +%d banked." % [die.die_name, pending])

	func modify_score(game, _box: int, _values: Array, base: int) -> int:
		if pending <= 0:
			return base
		var total := base + pending
		game.log_line("The Tithe pays out +%d." % pending)
		pending = 0
		return total


class SleepingGiant extends Charm:
	func _init() -> void:
		super(&"sleeping_giant", "Sleeping Giant", "A die left unlocked for three turns scores as a 6 the moment it is finally locked.")

	func on_lock(game, die: Die) -> void:
		if game.floor_turn < 3:
			return
		if die.value >= 6:
			return
		die.value = 6
		game.log_line("Sleeping Giant wakes %s as a 6." % die.die_name)


class Accountant extends Charm:
	func _init() -> void:
		super(&"accountant", "The Accountant", "+5 per box already spent. Scales as the run kills you.")

	func modify_score(game, _box: int, _values: Array, base: int) -> int:
		var spent: int = Scoring.BOX_COUNT - game.card.open_count()
		if spent <= 0:
			return base
		return base + spent * 5


class Pigeonhole extends Charm:
	func _init() -> void:
		super(&"pigeonhole", "Pigeonhole", "A Full House also counts as Three of a Kind, and scores both boxes.")

	func extra_writes(game, box: int, values: Array) -> Array:
		if box != Scoring.Box.FULL_HOUSE:
			return []
		if not game.card.is_open(Scoring.Box.THREE_KIND):
			return []
		var value: int = Scoring.score(Scoring.Box.THREE_KIND, values)
		if value <= 0:
			return []
		return [[Scoring.Box.THREE_KIND, value]]


class BloodPact extends Charm:
	func _init() -> void:
		super(&"blood_pact", "Blood Pact", "Scores are half again as large, but each turn burns two boxes instead of one.")

	func modify_score(_game, _box: int, _values: Array, base: int) -> int:
		return int(round(base * 1.5))

	func extra_boxes_per_turn() -> int:
		return 1


static func library() -> Array[Charm]:
	var out: Array[Charm] = []
	out.append(Grudge.new())
	out.append(Symmetry.new())
	out.append(Tithe.new())
	out.append(SleepingGiant.new())
	out.append(Accountant.new())
	out.append(Pigeonhole.new())
	out.append(BloodPact.new())
	return out


static func by_id(charm_id: StringName) -> Charm:
	for c in library():
		if c.id == charm_id:
			return c
	return null
