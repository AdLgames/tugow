extends Node
## Property tests. The suite in tests.gd asserts outcomes — a run terminates,
## three of a kind scores 66 — and every serious bug this project has had
## slipped past it: the bench was unreachable for a whole build, two dice
## rattled each other nine times in one throw, and every physics throw settled
## on the spot. All of those violate something that should never be true.
##
## So this file asserts what must hold after EVERY action, over thousands of
## randomly played turns, rather than what a particular action returns.
##   godot --headless --path . res://tests/invariants.tscn

const RUNS := 60
const MAX_ACTIONS := 400

var _failures: Array[String] = []
var _checks := 0
var _actions := 0


func _ready() -> void:
	_fuzz_runs()
	_fuzz_throws()
	_report()


# --- The run's state machine -------------------------------------------------

func _fuzz_runs() -> void:
	for seed_value in range(1, RUNS + 1):
		var game := Game.new()
		game.start_run(seed_value)
		var guard := 0
		while game.phase != Game.Phase.RUN_OVER and guard < MAX_ACTIONS:
			guard += 1
			_actions += 1
			_check_invariants(game, seed_value)
			if game.phase == Game.Phase.BENCH:
				_random_bench(game, seed_value + guard)
				continue
			_random_turn(game, seed_value + guard)
		_check_invariants(game, seed_value)
		if guard >= MAX_ACTIONS:
			_fail("run %d never ended" % seed_value)
	print("  %d actions fuzzed across %d runs" % [_actions, RUNS])


## Everything that must be true of the game at rest, whatever just happened.
func _check_invariants(game: Game, seed_value: int) -> void:
	var card := game.card
	var tag := "seed %d" % seed_value

	# The card is thirteen lines, always, in exactly one state each.
	var counted := card.count_state(Scorecard.State.OPEN) \
		+ card.count_state(Scorecard.State.PLAYER) \
		+ card.count_state(Scorecard.State.ADVERSARY) \
		+ card.count_state(Scorecard.State.BURNED)
	_expect(counted == Scoring.BOX_COUNT, "%s: the card is not thirteen lines (%d)" % [tag, counted])
	_expect(card.open_count() == card.open_boxes().size(), "%s: open count disagrees with open list" % tag)

	# The run total reconciles against the card: the lines the player still
	# holds, plus what was on lines an Adversary loss handed back. Nothing
	# else may add to or subtract from it.
	var owed := 0
	for box in card.player_boxes():
		owed += card.points[box]
	_expect(owed + card.reclaimed_total == card.run_total,
		"%s: run total %d but lines sum to %d and %d was reclaimed"
		% [tag, card.run_total, owed, card.reclaimed_total])

	# An open line carries no points. Reopening one without clearing it left
	# scores stranded on lines that were neither spent nor scoreable.
	for box in card.open_boxes():
		_expect(card.points[box] == 0,
			"%s: %s is open but still carries %d" % [tag, Scoring.box_name(box), card.points[box]])

	# No line is spent twice, and nothing is spent that is still open.
	var spent_seen := {}
	for box in card.spend_order:
		_expect(not spent_seen.has(box), "%s: %s spent twice" % [tag, Scoring.box_name(box)])
		spent_seen[box] = true
		_expect(card.states[box] != Scorecard.State.OPEN,
			"%s: %s is in the spend order but still open" % [tag, Scoring.box_name(box)])

	# An adversary can never hold more lines than the limit that ends the run.
	_expect(card.adversary_count() <= Balance.adversary_card_limit,
		"%s: adversary holds %d lines, past the limit" % [tag, card.adversary_count()])

	# A declared line is always one the adversary could actually take.
	if game.adversary != null and game.adversary.declared_box >= 0:
		var declared: int = game.adversary.declared_box
		var takeable := card.is_open(declared) \
			or game.adversary.id == &"debtor" and card.states[declared] == Scorecard.State.PLAYER
		_expect(takeable, "%s: %s is declared but cannot be taken"
			% [tag, Scoring.box_name(declared)])

	# The dice on the table are distinct, and a staked die is never lost.
	var ids := {}
	for die in game.pool.table:
		_expect(not ids.has(die.id), "%s: %s is on the table twice" % [tag, die.die_name])
		ids[die.id] = true
		_expect(not (die.locked and die.lost), "%s: %s is staked and in the dirt" % [tag, die.die_name])
		_expect(die.value >= 0 and die.value <= Die.FACE_CAP,
			"%s: %s shows %d" % [tag, die.die_name, die.value])

	# The floor score never runs below what was carried into it.
	_expect(game.floor_score >= game.floor_carry_in,
		"%s: floor score %d below the %d carried in" % [tag, game.floor_score, game.floor_carry_in])

	# A turn always has a legal move: something to throw, or a line to settle.
	if game.phase == Game.Phase.TURN:
		var can_act := game.can_throw() and game.draws_left() > 0
		_expect(can_act or (game.turn_rolled and card.open_count() > 0),
			"%s: a turn with nothing to throw and nothing to settle" % tag)


func _random_turn(game: Game, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Nothing can be settled before the dice have been thrown.
	if not game.turn_rolled:
		game.throw(rng.randi_range(0, 2))
		return
	if game.rerolls_left > 0 and game.can_throw() and rng.randf() < 0.7:
		game.throw(rng.randi_range(0, 2))
		return
	# Stake something, sometimes, including the last free die.
	for die in game.pool.table:
		if not die.locked and not die.lost and rng.randf() < 0.25:
			game.lock_die(die)
	var boxes := game.card.open_boxes()
	if boxes.is_empty():
		return
	game.write_box(boxes[rng.randi_range(0, boxes.size() - 1)])


func _random_bench(game: Game, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var offers := Bench.offers(game)
	if not offers.is_empty() and rng.randf() < 0.5:
		var offer: Dictionary = offers[rng.randi_range(0, offers.size() - 1)]
		var cost := int(offer["cost"])
		if Bench.can_afford(game, cost):
			var open := game.card.open_boxes()
			if open.size() >= cost:
				var sacrifices: Array[int] = []
				for i in cost:
					sacrifices.append(open[i])
				var target := -1
				match String(offer["target"]):
					"die", "bitter_die":
						target = game.pool.dice[0].id
						for d in game.pool.dice:
							if d.bitter:
								target = d.id
					"filled_box":
						var filled := game.card.player_boxes()
						if not filled.is_empty():
							target = filled[0]
				Bench.apply(game, offer["id"], sacrifices, target)
	game.leave_bench()


# --- Throws, from both paths -------------------------------------------------

func _fuzz_throws() -> void:
	# Whatever produced a throw, it must satisfy the contract.
	var game := Game.new()
	game.start_run(4242)
	var violations := 0
	for i in 400:
		game.pool.begin_turn("player")
		game.pool.throw_table(i % 3, false)
		var records := Throw.records_for(game.pool.table)
		for problem in ThrowContract.violations(records):
			violations += 1
			_fail("model throw: %s" % problem)
		# The values the resolver reads never include a lost die, and always
		# include the extra face of a cocked one.
		var expected := 0
		for entry in records:
			if entry["lost"]:
				continue
			expected += 1
			if int(entry["second_value"]) > 0:
				expected += 1
		_expect(ThrowContract.values_of(records).size() == expected,
			"model throw %d: the resolver reads the wrong number of faces" % i)
	print("  400 model throws checked against the contract, %d violations" % violations)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	# One line per distinct problem: a broken invariant fires thousands of times.
	if not _failures.has(message):
		_failures.append(message)


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("%d invariant checks passed." % _checks)
		get_tree().quit(0)
		return
	print("%d distinct invariant FAILURES over %d checks:" % [_failures.size(), _checks])
	for f in _failures:
		print("  - %s" % f)
	get_tree().quit(1)
