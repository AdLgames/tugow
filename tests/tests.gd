extends Node
## Checks on the rules. The scare timing and the learning rule are the two
## things the design leans on hardest, so they get the most attention.

var _passed := 0
var _failed: Array[String] = []


func _ready() -> void:
	_test_question_pool()
	_test_answers_differ()
	_test_asking_is_limited()
	_test_repeat_question_is_wasted()
	_test_trap_costs_you()
	_test_tells()
	_test_line_composition()
	_test_decisions()
	_test_lights()
	_test_scare_never_from_current_speaker()
	_test_scare_chance_rises()
	_test_things_learn()
	_test_denied_people_return()
	_test_endings()
	_test_faceless()
	_test_final_shift()
	_report()


# --- Questions ---------------------------------------------------------------

func _test_question_pool() -> void:
	check(Questions.all_ids().size() == 8, "there are eight questions")
	for id in Questions.all_ids():
		check(Questions.ask_text(id) != "", "question %d has text" % id)
		var row: Dictionary = Questions.POOL[id]
		check(not Array(row["human"]).is_empty(), "question %d has human answers" % id)
		check(not Array(row["thing"]).is_empty(), "question %d has thing answers" % id)


## Every question has to separate the two, or it is not a question.
func _test_answers_differ() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for id in Questions.all_ids():
		var human_bank: Array = Questions.POOL[id]["human"]
		var thing_bank: Array = Questions.POOL[id]["thing"]
		var overlap := false
		for h in human_bank:
			if thing_bank.has(h):
				overlap = true
		check(not overlap, "question %d: no answer is on both lists" % id)


func _test_asking_is_limited() -> void:
	var game := _running_game(101)
	check(game.asks_left == Questions.ASKS_PER_TRAVELLER, "three asks to start")
	var ids := Questions.all_ids()
	game.ask(ids[0])
	game.ask(ids[1])
	game.ask(ids[2])
	check(game.asks_left == 0, "three asks and no more")
	check(game.ask(ids[3]) == "", "a fourth ask gives nothing")


## Asking twice is a wasted ask, not a second sample. Otherwise the limit is
## no limit at all — you could re-roll a suspicious answer until it was clean.
func _test_repeat_question_is_wasted() -> void:
	var game := _running_game(102)
	var id: int = Questions.all_ids()[0]
	var first := game.ask(id)
	check(game.can_ask(id) == false, "the same question cannot be asked twice")
	check(game.asks_left == 2, "and the ask was spent")
	check(game.current.answered[id] == first, "the answer is kept, not re-rolled")


func _test_trap_costs_you() -> void:
	var game := _running_game(103)
	var before := game.dread
	game.ask(Questions.Id.ARE_YOU_HUMAN)
	check(game.dread == before + Dread.ASK_TRAP_COST, "asking outright raises dread")
	check(game.human_question_used, "and the game remembers you asked")
	var other := _running_game(104)
	var d := other.dread
	other.ask(Questions.Id.BREAKFAST)
	check(other.dread == d, "an ordinary question costs nothing")


# --- Tells -------------------------------------------------------------------

func _test_tells() -> void:
	check(Tells.all_ids().size() == 7, "there are seven tells")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for _i in 200:
		var rolled := Tells.roll(rng)
		check_quiet(rolled.size() >= Tells.PER_THING_MIN, "a thing has at least two tells")
		check_quiet(rolled.size() <= Tells.PER_THING_MAX, "and at most three")
		var seen := {}
		for t in rolled:
			check_quiet(not seen.has(t), "no tell is rolled twice")
			seen[t] = true
	check(true, "200 rolls give two or three distinct tells each")

	# Late on, stillness stops meaning anything: things learn to blink and
	# people are too tired to.
	check(Tells.idle_is_readable(1), "blinking reads early")
	check(not Tells.idle_is_readable(Tells.ALL_STILL_SHIFT), "and stops reading late")
	var t := Traveller.new()
	t.is_thing = true
	t.tells = [Tells.Id.NO_IDLE]
	check(t.idle_reads_as_still(1), "a still thing reads as still early")
	check(not t.idle_reads_as_still(6), "but not once everyone is still")


# --- The line ----------------------------------------------------------------

func _test_line_composition() -> void:
	for seed_value in 40:
		var game := Game.new()
		game.start_run(seed_value)
		check_quiet(game.line.size() >= Dread.TRAVELLERS_MIN, "a shift is six or more")
		check_quiet(game.line.size() <= Dread.TRAVELLERS_MAX, "and eight or fewer")
		var things := 0
		for t in game.line:
			if t.is_thing:
				things += 1
		# Never all of one kind: a shift with no thing teaches nothing, and a
		# shift with no person makes denying everything correct.
		check_quiet(things >= 1, "every shift has something in it")
		check_quiet(things < game.line.size(), "and someone real in it")
	check(true, "40 opening shifts are mixed, six to eight long")


func _test_decisions() -> void:
	var game := _running_game(201)
	var was_thing: bool = game.current.is_thing
	var before := game.dread
	game.decide(false)
	if was_thing:
		check(game.things_denied == 1, "denying a thing is counted")
		check(game.dread == maxi(0, before + Dread.RIGHT_DENY), "and lowers dread")
	else:
		check(game.people_turned_away == 1, "denying a person is counted")
		check(game.dread == before + Dread.WRONG_DENY, "and raises dread")

	# Dread never leaves its range, however many mistakes are made.
	var g2 := _running_game(202)
	for _i in 30:
		if g2.phase != Game.Phase.QUESTIONING:
			break
		g2.decide(true)
	check(g2.dread >= Dread.MIN and g2.dread <= Dread.MAX, "dread stays in range")


func _test_lights() -> void:
	var game := _running_game(203)
	var lit := game.lights
	var turned_off := 0
	for _i in 20:
		if game.phase != Game.Phase.QUESTIONING:
			break
		var thing: bool = game.current.is_thing
		game.decide(true)
		if thing:
			turned_off += 1
	check(game.lights == maxi(0, lit - turned_off),
		"one light goes out per thing let through, and never below zero")


# --- Scares ------------------------------------------------------------------

## The single most important rule in the game.
func _test_scare_never_from_current_speaker() -> void:
	var fired_on: Array = []
	var never_early := true
	for seed_value in range(300, 360):
		var game := Game.new()
		game.start_run(seed_value)
		game.begin_shift()
		var guard := 0
		while game.phase == Game.Phase.QUESTIONING and guard < 40:
			guard += 1
			var caused_by := game.index
			var was_thing: bool = game.current.is_thing
			game.decide(true)
			if not was_thing:
				continue
			# Run the clock right past the longest possible delay.
			var steps := 0
			while game.scare_pending() and steps < 400:
				steps += 1
				game.tick(0.25)
				if not game.scare_pending():
					if game.index == caused_by:
						never_early = false
					fired_on.append(game.index - caused_by)
					break
	check(never_early, "no scare ever fires on the traveller that caused it")
	check(not fired_on.is_empty(), "and scares do fire")


func _test_scare_chance_rises() -> void:
	check(Scares.all_ids().size() == 6, "there are six scares")
	check(is_equal_approx(Scares.chance(0), 1.0 / 6.0), "a calm booth is one in six")
	check(Scares.chance(10) > Scares.chance(0), "a frightened one is worse")
	check(Scares.chance(10) <= 1.0, "and never a certainty above one")
	for id in Scares.all_ids():
		check(Scares.copy_for(id) != "", "scare %d has copy" % id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for _i in 100:
		var d := Scares.delay(rng)
		check_quiet(d >= Scares.DELAY_MIN and d <= Scares.DELAY_MAX, "delay in range")
	check(true, "the delay is always twenty to sixty seconds")


# --- Learning ----------------------------------------------------------------

## Lean on a question twice and it stops working. This is what stops the game
## being solved on shift two and played on rails afterwards.
func _test_things_learn() -> void:
	var game := _running_game(401)
	var id: int = Questions.Id.BREAKFAST

	game.shift = 1
	for _i in 5:
		game.question_uses[id] = int(game.question_uses.get(id, 0)) + 1
		game._learn_from(id)
	check(not game.is_learned(id), "early on, nothing is learned")

	game.shift = Dread.LEARNING_FROM_SHIFT
	game._learn_from(id)
	check(game.is_learned(id), "from shift three, a well-used question is learned")

	# A learned question gets a person's answer out of a thing.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var human_bank: Array = Questions.POOL[id]["human"]
	var worn := Questions.answer(id, true, rng, "Elise", true)
	check(human_bank.has(worn), "a learned question gets a human answer from a thing")


func _test_denied_people_return() -> void:
	var game := _running_game(501)
	# Turn away a person, and note it.
	var guard := 0
	while game.phase == Game.Phase.QUESTIONING and guard < 40:
		guard += 1
		if not game.current.is_thing:
			game.decide(false)
			break
		game.decide(true)
	check(not game.owed_returns.is_empty(), "a turned-away person is owed a return")
	var owed_name := String(game.owed_returns[0]["name"])

	# Push forward until the debt comes due.
	var seen := false
	for _i in 60:
		if game.phase == Game.Phase.RUN_OVER:
			break
		if game.phase == Game.Phase.SHIFT_OVER:
			game.next_shift()
			game.begin_shift()
		elif game.phase == Game.Phase.SHIFT_OPENING:
			game.begin_shift()
		elif game.phase == Game.Phase.QUESTIONING:
			for t in game.line:
				if t.returning and t.returning_as == owed_name:
					seen = true
			game.decide(true)
		if seen:
			break
	check(seen or game.phase == Game.Phase.RUN_OVER,
		"they come back, unless the run ended first")


# --- Endings -----------------------------------------------------------------

func _test_endings() -> void:
	# Let everything through.
	var g1 := _running_game(601)
	var guard := 0
	while g1.phase != Game.Phase.RUN_OVER and guard < 200:
		guard += 1
		if g1.phase == Game.Phase.QUESTIONING:
			g1.decide(true)
		elif g1.phase == Game.Phase.SHIFT_OVER:
			g1.next_shift()
			g1.begin_shift()
		elif g1.phase == Game.Phase.SHIFT_OPENING:
			g1.begin_shift()
	check(g1.ending_id() == &"emptied_the_zone", "letting everything in empties the zone")

	# Turn everything away.
	var g2 := _running_game(602)
	guard = 0
	while g2.phase != Game.Phase.RUN_OVER and guard < 200:
		guard += 1
		if g2.phase == Game.Phase.QUESTIONING:
			g2.decide(false)
		elif g2.phase == Game.Phase.SHIFT_OVER:
			g2.next_shift()
			g2.begin_shift()
		elif g2.phase == Game.Phase.SHIFT_OPENING:
			g2.begin_shift()
	check(g2.ending_id() == &"turned_everyone_away", "denying everyone empties the line")

	# Play it right.
	var g3 := _running_game(603)
	var unrefusable := 0
	guard = 0
	while g3.phase != Game.Phase.RUN_OVER and guard < 400:
		guard += 1
		if g3.phase == Game.Phase.QUESTIONING:
			# The faceless ones cannot be refused, so perfect play approves
			# them and accepts the light. A driver that does not know this
			# stands at the glass pressing DENY for ever, which is the point.
			if g3.current.is_faceless():
				unrefusable += 1
			g3.decide((not g3.current.is_thing) or g3.current.is_faceless())
		elif g3.phase == Game.Phase.SHIFT_OVER:
			g3.next_shift()
			g3.begin_shift()
		elif g3.phase == Game.Phase.SHIFT_OPENING:
			g3.begin_shift()
	check(g3.ending_id() == &"kept_the_line", "a perfect run keeps the line")
	# Not every light: the best possible run still loses one for each figure
	# it was never allowed to turn away, and none for anything else.
	check(unrefusable > 0, "a perfect run still meets something it cannot refuse")
	check(g3.things_let_through == unrefusable,
		"and the only things it lets through are the ones it could not refuse")
	check(g3.lights == Dread.WINDOW_LIGHTS - unrefusable,
		"the window loses exactly those lights and no others")
	check(g3.shift >= Shifts.count(), "and reaches the last shift")


## The fifth shift sends something you are not allowed to refuse.
func _test_faceless() -> void:
	var game := Game.new()
	game.start_run(801)
	game.shift = Game.FACELESS_SHIFT - 1
	game.next_shift()
	var faceless: Traveller = null
	for t in game.line:
		if t.is_faceless():
			faceless = t
	check(faceless != null, "the fifth shift has one with no face")
	check(faceless.is_thing, "and it is not a person")

	# Walk the line until it steps up, then try to refuse it.
	game.begin_shift()
	var guard := 0
	while game.phase == Game.Phase.QUESTIONING and not game.current.is_faceless() and guard < 20:
		guard += 1
		game.decide(true)
	if game.phase == Game.Phase.QUESTIONING and game.current.is_faceless():
		var before := game.index
		game.decide(false)
		check(game.index == before, "denying it does nothing at all")
		check(game.current.is_faceless(), "and it is still standing there")
		game.decide(true)
		check(game.index == before + 1, "approving is the only way past it")


func _test_final_shift() -> void:
	check(Shifts.count() == 7, "there are seven shifts")
	for n in range(1, 8):
		var s := Shifts.get_shift(n)
		check_quiet(s.title != "" and s.opening != "", "shift %d is written" % n)
	check(true, "every shift has a title and an opening")
	check(Shifts.is_final(7), "the seventh is the last")

	var game := Game.new()
	game.start_run(701)
	game.shift = Shifts.count() - 1
	game.next_shift()
	check(game.line.size() == 1, "the last shift is one figure")
	check(game.line[0].is_thing, "and it is not a person")


# --- Harness -----------------------------------------------------------------

func _running_game(seed_value: int) -> Game:
	var game := Game.new()
	game.start_run(seed_value)
	game.begin_shift()
	return game


func check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % message)
	else:
		_failed.append(message)
		print("  FAIL %s" % message)


func check_quiet(condition: bool, message: String) -> void:
	if not condition and not _failed.has(message):
		_failed.append(message)
		print("  FAIL %s" % message)


func _report() -> void:
	if _failed.is_empty():
		print("\n%d checks passed." % _passed)
		get_tree().quit(0)
		return
	print("\n%d of %d checks FAILED:" % [_failed.size(), _passed + _failed.size()])
	for f in _failed:
		print("  - %s" % f)
	get_tree().quit(1)
