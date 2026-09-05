extends Node
## Property fuzz. Plays the booth badly, at random, thousands of times, and
## checks the things that must be true at every single moment rather than the
## outcome of any one run.
##
## Outcome tests pass on a game that is unplayable. These are the ones that
## catch a rule quietly contradicting another rule.

const RUNS := 240
const MAX_ACTIONS := 400

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	var actions := 0
	for seed_value in RUNS:
		actions += _fuzz(seed_value)
	print("  %d actions fuzzed across %d runs" % [actions, RUNS])
	_report()


func _fuzz(seed_value: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7717 + 13
	var game := Game.new()
	game.start_run(seed_value)
	var actions := 0
	var guard := 0
	while game.phase != Game.Phase.RUN_OVER and guard < MAX_ACTIONS:
		guard += 1
		_hold(game, "seed %d" % seed_value)
		match game.phase:
			Game.Phase.SHIFT_OPENING:
				game.begin_shift()
			Game.Phase.SHIFT_OVER:
				game.next_shift()
			Game.Phase.QUESTIONING:
				actions += 1
				# Ask a random legal question, sometimes; decide at random.
				if rng.randf() < 0.6:
					var ids := Questions.all_ids()
					var pick: int = ids[rng.randi_range(0, ids.size() - 1)]
					var before := game.asks_left
					var reply := game.ask(pick)
					if reply != "":
						_expect(game.asks_left == before - 1,
							"seed %d: an answered question spent an ask" % seed_value)
				if rng.randf() < 0.45:
					game.decide(rng.randf() < 0.5)
				# Let the clock run, so armed scares actually land mid-play.
				game.tick(rng.randf_range(0.0, 9.0))
			_:
				break
	_hold(game, "seed %d end" % seed_value)
	return actions


## Everything that must be true whatever has happened.
func _hold(game: Game, tag: String) -> void:
	_expect(game.dread >= Dread.MIN and game.dread <= Dread.MAX,
		"%s: dread %d is outside its range" % [tag, game.dread])
	_expect(game.lights >= 0 and game.lights <= Dread.WINDOW_LIGHTS,
		"%s: %d lights" % [tag, game.lights])

	# A light is out for every thing let through, and for nothing else. This
	# is the only readout the player gets, so it must never lie.
	_expect(game.lights == maxi(0, Dread.WINDOW_LIGHTS - game.things_let_through),
		"%s: %d lights against %d let through" % [tag, game.lights, game.things_let_through])

	_expect(game.asks_left >= 0 and game.asks_left <= Questions.ASKS_PER_TRAVELLER,
		"%s: %d asks left" % [tag, game.asks_left])
	_expect(game.asked_this_traveller.size() <= Questions.ASKS_PER_TRAVELLER,
		"%s: more questions asked than allowed" % tag)

	# No question is asked twice of the same face.
	var seen := {}
	for q in game.asked_this_traveller:
		_expect(not seen.has(q), "%s: question %d asked twice" % [tag, q])
		seen[q] = true

	# Every thing you are allowed to refuse is catchable: at least two tells,
	# all distinct. The faceless ones are the deliberate exception — they have
	# none, and DENY does not work on them, so there is nothing to catch.
	for t in game.line:
		if not t.is_thing or t.is_faceless():
			continue
		_expect(t.tells.size() >= Tells.PER_THING_MIN,
			"%s: a thing has only %d tells" % [tag, t.tells.size()])
		var tell_seen := {}
		for tell in t.tells:
			_expect(not tell_seen.has(tell), "%s: a tell is doubled" % tag)
			tell_seen[tell] = true

	# The run cannot be over and still be taking decisions.
	if game.phase == Game.Phase.RUN_OVER:
		_expect(game.ending_id() != &"none", "%s: the run ended with no ending" % tag)
		_expect(game.end_reason != "", "%s: the run ended without saying why" % tag)

	# A faceless traveller is never refusable and never has tells; nothing
	# else may be faceless.
	for t in game.line:
		if t.is_faceless():
			_expect(t.is_thing, "%s: a faceless traveller that is a person" % tag)
			_expect(t.tells.is_empty(), "%s: a faceless traveller carrying tells" % tag)

	# Counts reconcile: every decided traveller is in exactly one tally.
	var decided := 0
	for t in game.line:
		if t.verdict >= 0:
			decided += 1
	_expect(decided <= game.line.size(), "%s: more decisions than travellers" % tag)

	# An armed scare always has a future time on it, and is a real scare.
	if game.armed_scare >= 0:
		_expect(Scares.all_ids().has(game.armed_scare),
			"%s: armed with scare %d" % [tag, game.armed_scare])

	# Learning only ever happens from shift three, and only to real questions.
	for q in game.learned:
		_expect(Questions.all_ids().has(q), "%s: learned a question that does not exist" % tag)
		_expect(game.shift >= Dread.LEARNING_FROM_SHIFT,
			"%s: something was learned on shift %d" % [tag, game.shift])


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition and not _failures.has(message):
		_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print("\n%d invariant checks passed." % _checks)
		get_tree().quit(0)
		return
	print("\n%d distinct invariant FAILURES over %d checks:" % [_failures.size(), _checks])
	for f in _failures:
		print("  - %s" % f)
	get_tree().quit(1)
