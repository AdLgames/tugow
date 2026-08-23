extends Node
## Headless test suite. Run with:
##   godot --headless --path . res://tests/tests.tscn

var _failures: Array[String] = []
var _checks := 0


func _ready() -> void:
	_test_upper_boxes()
	_test_combination_boxes()
	_test_curve_variants()
	_test_pattern_gate()
	_test_scorecard()
	_test_dice_behaviour()
	_test_locking_narrows_the_table()
	_test_charms()
	_test_forge()
	_test_adversaries()
	_test_denial()
	_test_floor_transition()
	_test_overflow_carry()
	_test_lock_out_guard()
	_test_full_runs()
	_report()


# --- Scoring -----------------------------------------------------------------

func _test_upper_boxes() -> void:
	# three 5s -> 15 x 5 = 75
	check(Scoring.score(Scoring.Box.FIVES, [5, 5, 5, 2, 1]) == 75, "three 5s score 75")
	check(Scoring.score(Scoring.Box.ACES, [1, 1, 3, 4, 5]) == 2, "two aces score 2")
	check(Scoring.score(Scoring.Box.SIXES, [6, 6, 6, 6, 6]) == 180, "five 6s score 180")
	check(Scoring.score(Scoring.Box.TWOS, [1, 3, 4, 5, 6]) == 0, "no twos scores 0")


func _test_combination_boxes() -> void:
	# Three of a Kind: sum of all five x 3. 4+4+4+5+5 = 22 -> 66
	check(Scoring.score(Scoring.Box.THREE_KIND, [4, 4, 4, 5, 5]) == 66, "three of a kind sums x3")
	check(Scoring.score(Scoring.Box.THREE_KIND, [4, 4, 2, 5, 5]) == 0, "three of a kind needs a triple")
	# Full House: triple face x pair face x 10. 6s over 3s -> 180
	check(Scoring.score(Scoring.Box.FULL_HOUSE, [6, 6, 6, 3, 3]) == 180, "full house 6s over 3s = 180")
	check(Scoring.score(Scoring.Box.FULL_HOUSE, [6, 6, 6, 3, 2]) == 0, "full house needs the pair")
	# Small Straight: span x highest die x 5. 3-4-5-6 + 2 -> 4 x 6 x 5 = 120
	check(Scoring.score(Scoring.Box.SMALL_STRAIGHT, [3, 4, 5, 6, 2]) == 120, "small straight 3-4-5-6 = 120")
	check(Scoring.score(Scoring.Box.SMALL_STRAIGHT, [1, 2, 3, 4, 5]) == 100, "a five-run scores its best four")
	check(Scoring.score(Scoring.Box.SMALL_STRAIGHT, [1, 2, 3, 5, 5]) == 0, "three in a row is not a small straight")
	# Large Straight: product of all five. 2-3-4-5-6 -> 720
	check(Scoring.score(Scoring.Box.LARGE_STRAIGHT, [2, 3, 4, 5, 6]) == 720, "large straight 2-6 = 720")
	check(Scoring.score(Scoring.Box.LARGE_STRAIGHT, [1, 2, 3, 4, 6]) == 0, "broken run scores no large straight")
	# Chance: sum, doubled per 6 shown. 24 with two 6s -> 96
	check(Scoring.score(Scoring.Box.CHANCE, [6, 6, 5, 4, 3]) == 44, "chance adds 10 per 6")
	check(Scoring.score(Scoring.Box.CHANCE, [1, 2, 3, 4, 5]) == 15, "chance with no 6s is the sum")


func _test_curve_variants() -> void:
	var original: int = Balance.curve
	Balance.curve = Balance.ScoreCurve.RAW
	check(Scoring.score(Scoring.Box.FOUR_KIND, [6, 6, 6, 6, 1]) == 1296, "raw four of a kind is face^4")
	check(Scoring.score(Scoring.Box.YAHTZEE, [4, 4, 4, 4, 4]) == 1024, "raw yahtzee is face^5")
	Balance.curve = Balance.ScoreCurve.TEMPERED
	check(Scoring.score(Scoring.Box.FOUR_KIND, [6, 6, 6, 6, 1]) == 1080, "tempered four of a kind is face^3 x 5")
	check(Scoring.score(Scoring.Box.YAHTZEE, [4, 4, 4, 4, 4]) == 512, "tempered yahtzee is face^4 x 2")
	# The whole point of the operators: which face you chase is the question.
	check(Scoring.score(Scoring.Box.FOUR_KIND, [2, 2, 2, 2, 1]) == 40, "four 2s stay small")
	Balance.curve = original


func _test_pattern_gate() -> void:
	check(Scoring.is_pattern_met(Scoring.Box.CHANCE, [1, 1, 1, 1, 1]), "chance always takes")
	check(not Scoring.is_pattern_met(Scoring.Box.YAHTZEE, [1, 1, 1, 1, 2]), "yahtzee is unmet by four")
	check(Scoring.is_pattern_met(Scoring.Box.FOURS, [4, 1, 2, 3, 5]), "one four meets the fours box")


# --- Card --------------------------------------------------------------------

func _test_scorecard() -> void:
	var card := Scorecard.new()
	check(card.open_count() == 13, "a fresh card has thirteen boxes")
	card.write_player(Scoring.Box.SIXES, 72)
	card.write_player(Scoring.Box.YAHTZEE, 0)
	check(card.open_count() == 11, "each write spends a box")
	check(card.run_total == 72, "a scratch adds nothing")
	check(not card.is_open(Scoring.Box.YAHTZEE), "a scratched box is spent, not free")
	card.write_adversary(Scoring.Box.ACES, 4)
	check(card.open_count() == 10 and card.adversary_count() == 1, "the adversary shortens you")
	card.burn(Scoring.Box.CHANCE)
	check(card.states[Scoring.Box.CHANCE] == Scorecard.State.BURNED, "burned boxes are gone")
	var back := card.reclaim(2)
	check(back.size() == 2, "winning heals the run")
	check(card.run_total == 72, "reclaimed points stay on the run total")
	check(card.is_open(Scoring.Box.YAHTZEE), "the most recent spends come back first")


# --- Dice --------------------------------------------------------------------

func _test_dice_behaviour() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var d := Die.new(0, "Test", rng)

	# Facet: three scored locks reshape a face.
	check(not d.note_scored() and not d.note_scored(), "two locks do not reshape")
	check(d.note_scored(), "the third scored lock reshapes a face")
	check(d.faces[0] == 2, "the weakest face is pulled up")

	# Bitter: refuses its lowest face.
	var b := Die.new(1, "Bitter", rng)
	b.embitter()
	var saw_lowest := false
	for _i in 400:
		if b.roll() == b.lowest_face():
			saw_lowest = true
	check(not saw_lowest, "a bitter die refuses its lowest face")

	# Memory: dice remember their last roll.
	var m := Die.new(2, "Memory", rng)
	m.value = 4
	m.faces = PackedInt32Array([4, 4, 4, 4, 4, 4])
	m.roll()
	check(m.last_value == 4 and m.repeated, "a die notices the same face twice running")

	# Locked is locked: rolling does not move it.
	var l := Die.new(3, "Locked", rng)
	l.roll()
	var held := l.value
	l.lock()
	for _i in 20:
		l.roll()
	check(l.value == held, "a locked die holds its face")


func _test_locking_narrows_the_table() -> void:
	var game := Game.new()
	game.start_run(1234)
	var first_size := game.pool.table.size()
	check(first_size == Balance.dice_per_roll, "you roll five dice")
	game.lock_die(game.pool.table[0])
	game.lock_die(game.pool.table[1])
	var locked_values := [game.pool.table[0].value, game.pool.table[1].value]
	game.roll()
	check([game.pool.table[0].value, game.pool.table[1].value] == locked_values,
		"a reroll leaves locked dice alone")
	game.write_box(Scoring.Box.CHANCE)
	var still_locked := game.pool.locked_by("player").size()
	check(still_locked == 2, "locks persist into the next turn of the floor")
	check(game.pool.table.size() == Balance.dice_per_roll, "the table tops up from the pool")
	check(game.pool.unlocked_dice().size() == game.pool.dice.size() - 2, "locked dice leave the pool")


# --- Charms, forge, adversaries ---------------------------------------------

func _test_charms() -> void:
	var game := Game.new()
	game.start_run(7)

	var symmetry := Charms.Symmetry.new()
	check(symmetry.modify_score(game, Scoring.Box.CHANCE, [2, 5, 3, 5, 2], 10) == 20,
		"symmetry doubles a palindrome")
	check(symmetry.modify_score(game, Scoring.Box.CHANCE, [2, 5, 3, 5, 4], 10) == 10,
		"symmetry ignores an asymmetric table")

	var accountant := Charms.Accountant.new()
	game.card.write_player(Scoring.Box.ACES, 3)
	check(accountant.modify_score(game, Scoring.Box.CHANCE, [], 10) == 15,
		"the accountant grows as the card empties")

	var pigeonhole := Charms.Pigeonhole.new()
	var extra := pigeonhole.extra_writes(game, Scoring.Box.FULL_HOUSE, [5, 5, 5, 2, 2])
	check(extra.size() == 1 and extra[0][0] == Scoring.Box.THREE_KIND,
		"pigeonhole also fills three of a kind")

	var pact := Charms.BloodPact.new()
	check(pact.extra_boxes_per_turn() == 1, "blood pact burns a second box")
	var before := game.card.open_count()
	game.charms.append(pact)
	game._burn_extra_boxes()
	check(game.card.open_count() == before - 1, "the pact takes its box")

	var grudge := Charms.Grudge.new()
	game.pool.table[0].value = 1
	grudge.on_roll(game)
	check(game.pool.table[0].furious, "a die that rolls a 1 is furious")


func _test_forge() -> void:
	var game := Game.new()
	game.start_run(42)
	var open_before := game.card.open_count()
	var die := game.pool.dice[0]
	var faces_before := Array(die.faces)
	var sacrifice: Array = [game.card.open_boxes()[0]]
	check(Forge.apply(game, &"reshape_face", sacrifice, die.id), "the forge accepts a box")
	check(Array(die.faces) != faces_before, "the die is reshaped")
	check(game.card.open_count() == open_before - 1, "every upgrade shortens the run")

	var pool_before := game.pool.dice.size()
	var two: Array = game.card.open_boxes().slice(0, 2)
	check(Forge.apply(game, &"ninth_die", two), "two boxes buy a ninth die")
	check(game.pool.dice.size() == pool_before + 1, "the pool grew")

	check(not Forge.apply(game, &"ninth_die", [game.card.open_boxes()[0]]),
		"the forge rejects the wrong price")

	# You can never spend your last box.
	while game.card.open_count() > 1:
		game.card.burn(game.card.open_boxes()[0])
	check(not Forge.can_afford(game, 1), "the last box is not for sale")


func _test_adversaries() -> void:
	var game := Game.new()
	game.start_run(2024)

	var auditor := AdversaryRoster.Auditor.new()
	check(auditor.declare(game) == Scoring.Box.ACES, "the auditor works low to high")
	game.card.write_player(Scoring.Box.ACES, 1)
	check(auditor.declare(game) == Scoring.Box.TWOS, "the auditor moves up the section")

	# Declaration comes before the roll: you always get one turn to respond.
	var magpie := AdversaryRoster.Magpie.new()
	game.last_player_values = [6, 6, 6, 6, 2]
	var target := magpie.declare(game)
	check(target == Scoring.Box.FOUR_KIND or target == Scoring.Box.SIXES,
		"the magpie targets what you are building")

	var twin := AdversaryRoster.Twin.new()
	game.last_player_values = [1, 1, 2, 3, 1]
	twin.declare(game)
	check(twin._roll_toward(game, twin.declared_box) == [1, 1, 2, 3, 1],
		"the twin wears your last roll — play badly to starve it")

	var furnace := AdversaryRoster.Furnace.new()
	var burn_target := furnace.declare(game)
	furnace.take_turn(game)
	check(game.card.states[burn_target] == Scorecard.State.BURNED,
		"the furnace burns rather than claims")

	var debtor := AdversaryRoster.Debtor.new()
	game.card.write_player(Scoring.Box.SIXES, 144)
	check(debtor.declare(game) == Scoring.Box.SIXES, "the debtor comes for your best box")
	debtor.take_turn(game)
	check(game.card.states[Scoring.Box.SIXES] == Scorecard.State.ADVERSARY,
		"the debtor overwrites a filled box")


## Denying the Adversary is a real move: you take the box it announced.
func _test_denial() -> void:
	var game := Game.new()
	game.start_run(555)
	game.adversary = AdversaryRoster.Auditor.new()
	game.adversary.on_duel_start(game)
	var target := game.adversary.declare(game)
	var denials: Array = []
	game.player_wrote.connect(func(box, _value, denied): denials.append([box, denied]))
	game.write_box(target)
	check(denials.size() == 1 and denials[0][1], "taking the announced box is a denial")
	check(not game.card.is_open(target), "the denied box is spent either way")


## Regression: the forge opens because the phase is set before the signal fires.
func _test_floor_transition() -> void:
	var game := Game.new()
	game.start_run(11)
	# Captured through an array: GDScript lambdas copy plain locals.
	var phase_at_signal: Array[int] = []
	game.floor_cleared.connect(func(_n, _r): phase_at_signal.append(game.phase))
	game.floor_score = game.threshold
	game.write_box(Scoring.Box.CHANCE)
	check(phase_at_signal.size() == 1 and phase_at_signal[0] == Game.Phase.FORGE,
		"the forge is open when the floor-cleared signal lands")
	check(game.phase == Game.Phase.FORGE, "clearing a floor stops for the forge")

	var floor_before := game.floor_number
	game.leave_forge()
	check(game.floor_number == floor_before + 1, "leaving the forge descends")
	check(game.threshold > 0 and game.rerolls_left == Balance.rerolls_per_turn, "the next floor resets the turn")
	check(game.pool.locked_count() == 0, "a new floor unlocks every die")
	check(game.floor_score == game.pending_carry + game.floor_carry_in, "the floor score restarts from the carry")


## Overshoot carries instead of evaporating.
func _test_overflow_carry() -> void:
	var game := Game.new()
	game.start_run(21)
	var next_threshold := Balance.threshold_for_floor(2)
	game.floor_score = game.threshold + 40
	game._bank_overflow()
	check(game.pending_carry == 40, "the overshoot banks")
	game.leave_forge() if game.phase == Game.Phase.FORGE else game.next_floor()
	check(game.floor_carry_in == 40 and game.floor_score == 40, "it opens the next floor")
	check(game.pending_carry == 0, "and is spent once")

	# A monster turn cannot skip a floor outright.
	var big := Game.new()
	big.start_run(22)
	big.floor_score = big.threshold + 100000
	big._bank_overflow()
	check(big.pending_carry == int(next_threshold * Balance.overflow_carry_cap),
		"carry is capped below the next threshold")

	# The duel is judged on what you scored, not on what you carried in.
	var duel := Game.new()
	duel.start_run(23)
	duel.floor_carry_in = 500
	duel.floor_score = 500
	duel.adversary = AdversaryRoster.Auditor.new()
	duel.adversary.duel_score = 100
	duel.threshold = 400
	duel._clear_floor()
	check(duel.card.open_count() == Scoring.BOX_COUNT, "carried points do not win a duel")


## Locking your last free die freezes the floor — the UI must be able to warn.
func _test_lock_out_guard() -> void:
	var game := Game.new()
	game.start_run(31)
	check(game.free_dice_on_table() == Balance.dice_per_roll, "five free dice to start")
	while game.free_dice_on_table() > 1:
		for d in game.pool.table:
			if not d.locked:
				game.lock_die(d)
				break
	var last: Die = null
	for d in game.pool.table:
		if not d.locked:
			last = d
	check(game.would_lock_out(last), "the last free die is flagged")
	game.lock_die(last)
	check(game.free_dice_on_table() == 0, "and locking it freezes the table")


func _test_full_runs() -> void:
	var deepest := 0
	var ended := 0
	for seed_value in range(1, 41):
		var game := Game.new()
		game.start_run(seed_value)
		var guard := 0
		while game.phase != Game.Phase.RUN_OVER and guard < 400:
			guard += 1
			if game.phase == Game.Phase.FORGE:
				game.leave_forge()
				continue
			_greedy_turn(game)
		check(guard < 400, "run %d terminates" % seed_value)
		if game.phase == Game.Phase.RUN_OVER:
			ended += 1
		deepest = maxi(deepest, game.floor_number)
	check(ended == 40, "every run reaches an ending")
	check(deepest >= 3, "a greedy bot gets at least a few floors down")
	print("  greedy bot deepest floor: %d" % deepest)


## Plays the single best box available, locking anything showing 5 or more.
func _greedy_turn(game: Game) -> void:
	for _i in Balance.rerolls_per_turn:
		var best_now := _best_box(game)
		if best_now[1] > 0 and game.rerolls_left == 0:
			break
		game.roll()
	for d in game.pool.table:
		if d.value >= 5:
			game.lock_die(d)
	var best := _best_box(game)
	game.write_box(best[0])


func _best_box(game: Game) -> Array:
	var boxes := game.card.open_boxes()
	if boxes.is_empty():
		return [0, 0]
	var best: int = boxes[0]
	var best_value := -1
	for box in boxes:
		var v := game.preview(box)
		if v > best_value:
			best_value = v
			best = box
	return [best, best_value]


# --- Harness -----------------------------------------------------------------

func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   %s" % label)
	else:
		_failures.append(label)
		print("  FAIL %s" % label)


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("%d checks passed." % _checks)
		get_tree().quit(0)
		return
	print("%d of %d checks FAILED:" % [_failures.size(), _checks])
	for f in _failures:
		print("  - %s" % f)
	get_tree().quit(1)
