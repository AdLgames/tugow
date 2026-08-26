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
	_test_charm_limit()
	_test_denial()
	_test_floor_transition()
	_test_weekly_reset()
	_test_duel_cadence()
	_test_overflow_carry()
	_test_lock_out_guard()
	_test_free_dice_excludes_lost()
	_test_throw_zones()
	_test_model_matches_calibration()
	_test_rail_persistence()
	_test_collisions_and_cocking()
	_test_underside()
	_test_rail_multiplier()
	_test_lost_dice_are_floor_long()
	_test_new_charms()
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
	game.throw()
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
	var spoken_for := 2 + game.pool.lost_dice().size()
	check(game.pool.unlocked_dice().size() == game.pool.dice.size() - spoken_for,
		"locked and lost dice both leave the pool")


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
	check(Bench.apply(game, &"reshape_face", sacrifice, die.id), "the bench accepts a box")
	check(Array(die.faces) != faces_before, "the die is reshaped")
	check(game.card.open_count() == open_before - 1, "every upgrade shortens the run")

	var pool_before := game.pool.dice.size()
	var two: Array = game.card.open_boxes().slice(0, 2)
	check(Bench.apply(game, &"ninth_die", two), "two boxes buy a ninth die")
	check(game.pool.dice.size() == pool_before + 1, "the pool grew")

	check(not Bench.apply(game, &"ninth_die", [game.card.open_boxes()[0]]),
		"the bench rejects the wrong price")

	# You can never spend your last box.
	while game.card.open_count() > 1:
		game.card.burn(game.card.open_boxes()[0])
	check(not Bench.can_afford(game, 1), "the last box is not for sale")


## One charm a night, however many lines you are willing to burn.
func _test_charm_limit() -> void:
	var game := Game.new()
	game.start_run(6161)
	var first := Bench.next_charm(game)
	check(first != null, "the bench offers a charm")
	game.take_charm(first)
	check(Bench.next_charm(game) == null, "and only the one, tonight")
	var offered_ids: Array = []
	for offer in Bench.offers(game):
		offered_ids.append(offer["id"])
	check(not offered_ids.has(&"take_charm"), "the charm is off the board once taken")
	# Charms are what a finished week pays out, so the next night inside the
	# same week offers nothing more.
	game.next_floor()
	check(Bench.next_charm(game) == null, "the next night of the same week offers no charm")
	while Balance.week_of(game.floor_number) == 1:
		game.next_floor()
	check(Bench.next_charm(game) != null, "a new week offers another")
	check(game.charms_taken_this_week == 0, "the count resets with the week")


func _test_adversaries() -> void:
	var game := Game.new()
	game.start_run(2024)

	var auditor := AdversaryRoster.Taxman.new()
	check(auditor.declare(game) == Scoring.Box.ACES, "the auditor works low to high")
	game.card.write_player(Scoring.Box.ACES, 1)
	check(auditor.declare(game) == Scoring.Box.TWOS, "the auditor moves up the section")

	# Declaration comes before the roll: you always get one turn to respond.
	var magpie := AdversaryRoster.Magpie.new()
	game.last_player_values = [6, 6, 6, 6, 2]
	var target := magpie.declare(game)
	check(target == Scoring.Box.FOUR_KIND or target == Scoring.Box.SIXES,
		"the magpie targets what you are building")

	var twin := AdversaryRoster.Reflection.new()
	game.last_player_values = [1, 1, 2, 3, 1]
	twin.declare(game)
	check(twin._roll_toward(game, twin.declared_box) == [1, 1, 2, 3, 1],
		"the twin wears your last roll — play badly to starve it")

	var furnace := AdversaryRoster.Fire.new()
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
	game.adversary = AdversaryRoster.Taxman.new()
	game.adversary.on_duel_start(game)
	game.throw()
	var target := game.adversary.declare(game)
	var denials: Array = []
	game.player_wrote.connect(func(box, _value, denied): denials.append([box, denied]))
	game.write_box(target)
	check(denials.size() == 1 and denials[0][1], "taking the announced box is a denial")
	check(not game.card.is_open(target), "the denied box is spent either way")


## Regression: the bench opens because the phase is set before the signal fires.
func _test_floor_transition() -> void:
	var game := Game.new()
	game.start_run(11)
	# Captured through an array: GDScript lambdas copy plain locals.
	var phase_at_signal: Array[int] = []
	game.floor_cleared.connect(func(_n, _r): phase_at_signal.append(game.phase))
	game.throw()
	game.floor_score = game.threshold
	game.write_box(Scoring.Box.CHANCE)
	check(phase_at_signal.size() == 1 and phase_at_signal[0] == Game.Phase.BENCH,
		"the bench is open when the floor-cleared signal lands")
	check(game.phase == Game.Phase.BENCH, "clearing a floor stops for the bench")

	var floor_before := game.floor_number
	game.leave_bench()
	check(game.floor_number == floor_before + 1, "leaving the bench descends")
	check(game.threshold > 0 and game.rerolls_left == Balance.rerolls_per_turn, "the next floor resets the turn")
	check(game.pool.locked_count() == 0, "a new floor unlocks every die")
	check(game.floor_score == game.pending_carry + game.floor_carry_in, "the floor score restarts from the carry")


## A week is the unit of play: thirteen lines have to carry seven nights, and
## surviving one hands the paper back.
func _test_weekly_reset() -> void:
	var game := Game.new()
	game.start_run(4477)
	check(Balance.week_of(1) == 1 and Balance.night_of(1) == 1, "the run opens on week 1 night 1")
	check(Balance.week_of(Balance.nights_per_week + 1) == 2,
		"the night after a full week starts the next one")

	game.card.write_player(Scoring.Box.ACES, 12)
	game.card.write_adversary(Scoring.Box.TWOS, 8)
	game.card.burn(Scoring.Box.THREES)
	var banked := game.card.run_total
	check(game.card.open_count() == Scoring.BOX_COUNT - 3, "three lines are gone")

	var wiped := game.card.new_week()
	check(wiped.size() == 3, "every spent line comes back, his and burned alike")
	check(game.card.open_count() == Scoring.BOX_COUNT, "the card is whole again")
	check(game.card.run_total == banked, "what was scored is kept")
	check(game.card.spend_order.is_empty(), "and nothing is still marked spent")

	# The run total still reconciles: nothing is stranded by the wipe.
	var owed := 0
	for box in game.card.player_boxes():
		owed += game.card.points[box]
	check(owed + game.card.reclaimed_total == game.card.run_total,
		"the total reconciles across the wipe")

	# Playing through a whole week hands the paper back on its own.
	var fresh := Game.new()
	fresh.start_run(4478)
	while Balance.week_of(fresh.floor_number) == 1 and fresh.phase != Game.Phase.RUN_OVER:
		fresh.card.write_player(fresh.card.open_boxes()[0], 5)
		if fresh.phase == Game.Phase.BENCH:
			fresh.leave_bench()
		else:
			fresh.next_floor()
	check(fresh.phase == Game.Phase.RUN_OVER or fresh.card.open_count() == Scoring.BOX_COUNT,
		"crossing into a new week wipes the card without being asked")


## He arrives later in the week early on, and earlier as the run goes.
func _test_duel_cadence() -> void:
	var counts: Array[int] = []
	for week in range(1, Balance.weeks_per_run + 1):
		var n := 0
		for night in range(1, Balance.nights_per_week + 1):
			if Balance.is_duel_floor((week - 1) * Balance.nights_per_week + night):
				n += 1
		counts.append(n)
	check(counts[0] == 1, "week 1 has him on one night")
	for i in range(1, counts.size()):
		check(counts[i] > counts[i - 1], "each week puts him at the table more often")
	check(Balance.is_duel_floor(Balance.nights_per_week),
		"the last night of a week is always his")


## Overshoot carries instead of evaporating.
func _test_overflow_carry() -> void:
	var game := Game.new()
	game.start_run(21)
	var next_threshold := Balance.threshold_for_floor(2)
	# Under the cap, so the whole overshoot carries.
	var overshoot := int(next_threshold * Balance.overflow_carry_cap) - 1
	game.floor_score = game.threshold + overshoot
	game._bank_overflow()
	check(game.pending_carry == overshoot, "the overshoot banks")
	game.leave_bench() if game.phase == Game.Phase.BENCH else game.next_floor()
	check(game.floor_carry_in == overshoot and game.floor_score == overshoot,
		"it opens the next floor")
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
	duel.adversary = AdversaryRoster.Taxman.new()
	duel.adversary.duel_score = 100
	duel.threshold = 400
	duel._clear_floor()
	check(duel.card.open_count() == Scoring.BOX_COUNT, "carried points do not win a duel")


## Locking your last free die freezes the floor — the UI must be able to warn.
## Lost dice are not throwable, and the throw controls must agree.
func _test_free_dice_excludes_lost() -> void:
	var game := Game.new()
	game.start_run(4141)
	var before := game.free_dice_on_table()
	game.pool.table[0].lost = true
	check(game.free_dice_on_table() == before - 1, "a lost die is not a throwable die")
	check(game.can_throw(), "the rest of the table can still be thrown")
	for d in game.pool.table:
		d.lost = true
	check(not game.can_throw(), "an empty table cannot be thrown")


func _test_lock_out_guard() -> void:
	var game := Game.new()
	game.start_run(31)
	game.throw()
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


# --- The throw ---------------------------------------------------------------

func _make_dice(n: int, rng: RandomNumberGenerator) -> Array[Die]:
	var out: Array[Die] = []
	for i in n:
		out.append(Die.new(i, "D%d" % i, rng))
	return out


func _test_throw_zones() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242

	# Soft: clustered, safe, never reaches the rail.
	var soft_rail := 0
	var soft_lost := 0
	for _i in 200:
		var dice := _make_dice(5, rng)
		var result := Throw.resolve(dice, Throw.Strength.SOFT, rng)
		soft_rail += Throw.rail_count(dice)
		soft_lost += result.lost.size()
	# Soft reaches the rail about one die in six — measured from the sim, not
	# assumed. What it never does is put a die in the dirt.
	check(soft_rail > 0, "a soft throw can still reach the rail")
	check(soft_lost == 0, "a soft throw never loses a die")

	# Medium: some rail, no losses.
	var medium_rail := 0
	var medium_lost := 0
	for _i in 200:
		var dice := _make_dice(5, rng)
		var result := Throw.resolve(dice, Throw.Strength.MEDIUM, rng)
		medium_rail += Throw.rail_count(dice)
		medium_lost += result.lost.size()
	check(medium_rail > 0, "a medium throw reaches the rail")
	check(medium_lost > 0, "a medium throw can put a die off the table")

	# Hard: wide scatter, real risk.
	var hard_rail := 0
	var hard_lost := 0
	for _i in 200:
		var dice := _make_dice(5, rng)
		var result := Throw.resolve(dice, Throw.Strength.HARD, rng)
		hard_rail += Throw.rail_count(dice)
		hard_lost += result.lost.size()
	# Measured, not assumed: a hard throw both reaches the rail more often
	# than a soft one and puts far more dice in the dirt than a medium one.
	check(hard_rail > soft_rail, "a hard throw reaches the rail more often than a soft one")
	check(hard_lost > medium_lost, "a hard throw loses more dice than a medium one")


## The other half of the tripwire: the model must actually sample the odds it
## is calibrated to.
func _test_model_matches_calibration() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	for strength in [Throw.Strength.SOFT, Throw.Strength.MEDIUM, Throw.Strength.HARD]:
		var counts := {"pot": 0, "rail": 0, "lost": 0}
		var dice := 0
		for _i in 200:
			var thrown := _make_dice(5, rng)
			Throw.resolve(thrown, strength, rng)
			for d in thrown:
				dice += 1
				if d.lost:
					counts["lost"] += 1
				elif d.zone == Throw.Zone.RAIL:
					counts["rail"] += 1
				else:
					counts["pot"] += 1
		var expected: Dictionary = Balance.zone_odds[strength]
		var worst := 0.0
		for zone in counts:
			worst = maxf(worst, absf(float(counts[zone]) / float(dice) - float(expected[zone])))
		check(worst < 0.10, "the model lands %s throws the way it is calibrated to"
			% Throw.strength_name(strength).to_lower())


func _test_rail_persistence() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# The shove lives in ThrowContract now, so that the model and the physics
	# cannot apply it differently. Both paths call it before they throw.
	var dice := _make_dice(2, rng)
	dice[0].value = 6
	dice[0].landing_radius = 0.95
	dice[0].zone = Throw.Zone.RAIL
	var lost := ThrowContract.push_rail_dice(dice, Throw.Strength.HARD, false)
	check(dice[0].lost and lost.has(dice[0]), "a hard throw shoves a rail die off the table")

	# Unless it was staked: staked dice cannot be lost.
	var safe := _make_dice(2, rng)
	safe[0].value = 6
	safe[0].landing_radius = 0.95
	safe[0].zone = Throw.Zone.RAIL
	safe[0].lock()
	ThrowContract.push_rail_dice(safe, Throw.Strength.HARD, false)
	Throw.resolve(safe, Throw.Strength.HARD, rng)
	check(not safe[0].lost, "a staked die cannot be pushed off")
	check(safe[0].value == 6, "a staked die keeps its face through a throw")

	# Or unless you have the Long Throw.
	var charmed := _make_dice(2, rng)
	charmed[0].value = 6
	charmed[0].landing_radius = 0.95
	charmed[0].zone = Throw.Zone.RAIL
	ThrowContract.push_rail_dice(charmed, Throw.Strength.HARD, true)
	check(not charmed[0].lost, "Long Throw keeps hard throws on the table")

	# A die in the pot is not shoved at all.
	var quiet := _make_dice(2, rng)
	quiet[0].value = 4
	quiet[0].landing_radius = 0.30
	quiet[0].zone = Throw.Zone.POT
	ThrowContract.push_rail_dice(quiet, Throw.Strength.HARD, false)
	check(not quiet[0].lost, "a die in the pot is left alone")


func _test_collisions_and_cocking() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# Dice landing close together knock each other to new faces.
	var collisions := 0
	var cocked := 0
	for _i in 300:
		var dice := _make_dice(5, rng)
		var result := Throw.resolve(dice, Throw.Strength.HARD, rng)
		collisions += result.collisions.size()
		cocked += result.cocked.size()
	check(collisions > 0, "dice striking dice knock them to new faces")

	# Chains propagate, but two neighbours must not rattle each other forever.
	for _i in 300:
		var chain_dice := _make_dice(5, rng)
		var chain_result := Throw.resolve(chain_dice, Throw.Strength.HARD, rng)
		var struck := {}
		var double_hit := false
		for c in chain_result.collisions:
			if struck.has(c[1]):
				double_hit = true
			struck[c[1]] = true
		check_once(not double_hit, "no die is struck twice in one throw")

	# A cocked die counts as both its face and the one beneath it.
	var pool := DicePool.new(2, 5)
	pool.table = pool.dice
	pool.dice[0].value = 5
	pool.dice[1].value = 3
	# A cocked die is one showing two faces; which two is the throwing path's
	# business, and the rules only read the pair.
	pool.dice[0].cocked_on = pool.dice[1].id
	pool.dice[0].second_value = pool.dice[1].value
	var values := pool.table_values()
	check(values.size() == 3, "a cocked die adds a face to the table")
	check(values.count(3) == 2, "its second face is read alongside its first")


func _test_underside() -> void:
	var rng := RandomNumberGenerator.new()
	var d := Die.new(0, "Under", rng)
	d.value = 1
	check(d.underside() == 6, "a shown 1 hides a 6")
	d.value = 4
	check(d.underside() == 3, "a shown 4 hides a 3")
	# A reshaped die keeps the same relationship between its own extremes.
	d.faces = PackedInt32Array([2, 2, 3, 4, 5, 9])
	d.value = 9
	check(d.underside() == 2, "a faceted die hides its lowest under its highest")


func _test_rail_multiplier() -> void:
	var rng := RandomNumberGenerator.new()
	var dice := _make_dice(3, rng)
	for d in dice:
		d.value = 4
		d.zone = Throw.Zone.RAIL
	var original: int = Balance.rail_mode
	Balance.rail_mode = Balance.RailMode.EXPONENTIAL
	check(is_equal_approx(Throw.rail_multiplier(dice), 8.0), "exponential rail doubles per die")
	Balance.rail_mode = Balance.RailMode.LINEAR
	check(is_equal_approx(Throw.rail_multiplier(dice), 4.0), "linear rail adds per die")
	Balance.rail_mode = Balance.RailMode.FLAT
	check(is_equal_approx(Throw.rail_multiplier(dice), 2.0), "flat rail doubles once")
	Balance.rail_mode = original
	for d in dice:
		d.zone = Throw.Zone.POT
	check(is_equal_approx(Throw.rail_multiplier(dice), 1.0), "the pot does not multiply")


func _test_lost_dice_are_floor_long() -> void:
	var game := Game.new()
	game.start_run(808)
	game.throw()
	# Pick a die that is actually on the table with a face on it: the opening
	# throw can already have put one in the dirt, and a die that was never
	# worth anything cannot demonstrate that losing it costs you something.
	var victim: Die = null
	for d in game.pool.live_table():
		if d.value > 0:
			victim = d
			break
	check(victim != null, "the opening throw leaves at least one die on the table")
	if victim == null:
		return
	# Take the die off the table and see what the resolver stops reading. A
	# cocked die is worth two faces, and any die on the table may be one.
	var before_values: Array = game.pool.table_values().duplicate()
	var victim_value := victim.value
	victim.lost = true
	victim.zone = Throw.Zone.LOST
	victim.cocked_on = -1
	check(not game.pool.unlocked_dice().has(victim), "a lost die leaves the pool")
	var after_values: Array = game.pool.table_values()
	check(after_values.size() < before_values.size(), "a lost die scores nothing")
	check(before_values.count(victim_value) > after_values.count(victim_value),
		"the lost die's face is the one that left")
	game.pool.begin_floor()
	check(not victim.lost, "the next floor brings it back")


func _test_new_charms() -> void:
	var game := Game.new()
	game.start_run(909)
	var underhand := Charms.Underhand.new()
	var dice: Array[Die] = []
	var rng := RandomNumberGenerator.new()
	var low := Die.new(0, "Low", rng)
	low.value = 1
	var high := Die.new(1, "High", rng)
	high.value = 5
	dice.append(low)
	dice.append(high)
	var flipped := underhand.modify_values(game, [1, 5], dice)
	check(flipped == [6, 5], "Underhand reads the hidden face of the lowest die")

	game.charms.append(Charms.LongThrow.new())
	check(game.has_charm(&"long_throw"), "Long Throw is held, and the throw reads it")


func _test_full_runs() -> void:
	var deepest := 0
	var ended := 0
	for seed_value in range(1, 41):
		var game := Game.new()
		game.start_run(seed_value)
		var guard := 0
		while game.phase != Game.Phase.RUN_OVER and guard < 400:
			guard += 1
			if game.phase == Game.Phase.BENCH:
				game.leave_bench()
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

## For assertions inside a loop: only the first failure is worth printing.
var _once_reported := {}

func check_once(condition: bool, label: String) -> void:
	if condition:
		if not _once_reported.has(label):
			_once_reported[label] = true
			check(true, label)
		return
	if _once_reported.get(label, false) == "failed":
		return
	_once_reported[label] = "failed"
	_checks += 1
	_failures.append(label)
	print("  FAIL %s" % label)


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
