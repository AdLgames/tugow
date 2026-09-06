class_name Game
extends RefCounted
## The booth. One traveller at a time, three questions, one decision.
##
## Two clocks run underneath: `dread`, which decides how often the room does
## something, and an armed scare, which is deliberately timed to land on the
## *next* traveller rather than the one you got wrong. Nothing in the
## interface names either of them.

signal shift_started(number: int, title: String, opening: String)
signal traveller_arrived(traveller: Traveller)
signal answered(question: int, ask: String, reply: String, tell: int)
signal decided(traveller: Traveller, approved: bool, correct: bool)
## The faceless one, refusing to be refused.
signal refused_deny()
signal scare_armed(scare: int, delay: float)
signal scare_fired(scare: int, copy: String)
signal ambient(line: String)
signal shift_ended(number: int)
signal run_ended(ending: StringName, reason: String)
signal state_changed()

enum Phase { SHIFT_OPENING, QUESTIONING, DECIDED, SHIFT_OVER, RUN_OVER }
enum Ending { NONE, KEPT_THE_LINE, EMPTIED_THE_ZONE, TURNED_EVERYONE_AWAY }

var phase: int = Phase.SHIFT_OPENING
var shift: int = 0
var shift_title: String = ""

var line: Array[Traveller] = []
var index: int = 0
var current: Traveller = null

var asks_left: int = 0
var asked_this_traveller: Array[int] = []

## Hidden. Never rendered, never named.
var dread: int = 0
var lights: int = Dread.WINDOW_LIGHTS

var things_let_through: int = 0
var people_turned_away: int = 0
var things_denied: int = 0
var people_approved: int = 0

## A scare waits on a clock, not on an event.
var armed_scare: int = -1
var armed_at: float = 0.0
var armed_seen_travellers: int = 0
var human_question_used: bool = false

## How many times each question has been leant on. Things learn.
var question_uses: Dictionary = {}
## Learned questions stop working, per shift they were learned.
var learned: Array[int] = []

## People you turned away who are owed a return.
var owed_returns: Array = []

var log_lines: Array[String] = []
var ending: int = Ending.NONE
var end_reason: String = ""

const FACELESS_SHIFT := 5

var rng := RandomNumberGenerator.new()
var _clock: float = 0.0


func start_run(seed_value: int = 0) -> void:
	rng.seed = seed_value
	shift = 0
	dread = 0
	lights = Dread.WINDOW_LIGHTS
	things_let_through = 0
	people_turned_away = 0
	things_denied = 0
	people_approved = 0
	armed_scare = -1
	human_question_used = false
	question_uses.clear()
	learned.clear()
	owed_returns.clear()
	log_lines.clear()
	ending = Ending.NONE
	end_reason = ""
	_clock = 0.0
	next_shift()


# --- Shifts ------------------------------------------------------------------

func next_shift() -> void:
	shift += 1
	if shift > Shifts.count():
		_finish_run()
		return
	var s := Shifts.get_shift(shift)
	shift_title = s.title
	phase = Phase.SHIFT_OPENING
	_build_line(s)
	index = -1
	note("--- Shift %d: %s ---" % [shift, s.title])
	note(s.opening)
	if s.scripted != "":
		note(s.scripted)
	shift_started.emit(shift, s.title, s.opening)
	state_changed.emit()


## Compose the night's line. The ratio is a target, not a guarantee: a shift
## that is all things or all people would teach the wrong lesson, so both ends
## are clamped away except on the last shift, which is one figure.
func _build_line(s: Shifts.Shift) -> void:
	line.clear()
	if Shifts.is_final(s.number):
		line.append(_make_final_figure())
		return
	var count := rng.randi_range(Dread.TRAVELLERS_MIN, Dread.TRAVELLERS_MAX)
	var things := int(round(float(count) * s.thing_ratio))
	things = clampi(things, 1, count - 1)
	for i in count:
		line.append(_make_traveller(s, i < things))
	_shuffle(line)
	# The fifth shift sends one with no face and perfect answers. It is not
	# a puzzle: it is the night the game stops pretending you can always win.
	if s.number == FACELESS_SHIFT:
		var faceless := _make_final_figure()
		faceless.given_name = "(no name given)"
		faceless.reason = "There is nothing written on the tag."
		line.insert(mini(line.size(), line.size() / 2), faceless)
	_seed_returns()


func _make_traveller(s: Shifts.Shift, is_thing: bool) -> Traveller:
	var t := Traveller.new()
	t.given_name = Names.pick(rng)
	t.reason = Names.reason(rng)
	t.portrait = _pick_portrait()
	t.is_thing = is_thing
	if is_thing:
		t.tells = Tells.roll(rng, rng.randi_range(s.tells_min, s.tells_max))
	return t


## Painted faces are worth showing, so they come up more often than one in
## twenty would give — but not so often that a shift is the same person over
## and over. Everything else falls back to a face drawn from its own seed.
func _pick_portrait() -> int:
	var painted := Portraits.painted()
	if painted > 0 and rng.randf() < 0.34:
		var order: Array = []
		for index in Portraits.TABLE:
			if Portraits.has_art(index):
				order.append(index)
		return int(order[rng.randi_range(0, order.size() - 1)])
	return rng.randi_range(0, Dread.PORTRAITS - 1)


## The last figure has your face and asks your questions. It is the only
## traveller in the game whose answers are all correct.
func _make_final_figure() -> Traveller:
	var t := Traveller.new()
	t.given_name = "—"
	t.reason = "It is wearing your face."
	t.portrait = -1
	t.is_thing = true
	t.tells = []
	return t


## Someone you turned away comes back, two shifts later and worse for it.
func _seed_returns() -> void:
	var still_owed: Array = []
	for owed in owed_returns:
		if shift - int(owed["shift"]) >= Dread.GUILT_RETURN_AFTER and not line.is_empty():
			var t: Traveller = line[rng.randi_range(0, line.size() - 1)]
			t.returning = true
			t.returning_as = String(owed["name"])
			t.given_name = String(owed["name"])
			note("%s is in the line again." % t.given_name)
		else:
			still_owed.append(owed)
	owed_returns = still_owed


func begin_shift() -> void:
	if phase != Phase.SHIFT_OPENING:
		return
	next_traveller()


# --- Travellers --------------------------------------------------------------

func next_traveller() -> void:
	index += 1
	if index >= line.size():
		_end_shift()
		return
	current = line[index]
	asks_left = Questions.ASKS_PER_TRAVELLER
	asked_this_traveller.clear()
	armed_seen_travellers += 1
	phase = Phase.QUESTIONING
	note("Next: %s — %s" % [current.given_name, current.reason])
	if current.returning:
		note("You have seen this face before.")
	traveller_arrived.emit(current)
	_ambient_for_arrival()
	state_changed.emit()


## Tells that fire on arrival rather than in an answer. These are the ones a
## player catches by looking rather than asking, which is the only way the
## three-question limit stays survivable.
func _ambient_for_arrival() -> void:
	if current == null or not current.is_thing:
		return
	if current.has_tell(Tells.Id.HUM_SHIFT):
		_say("The room hum drops a tone as they step up.")
	if current.has_tell(Tells.Id.LAGGING_GLASS):
		_say("In the desk glass their reflection arrives a moment after they do.")
	if current.has_tell(Tells.Id.WRONG_VOICE):
		_say("When they clear their throat, the sound is not the right size for the face.")
	if current.has_tell(Tells.Id.UNASKED):
		var bank: Array = Tells.LINES[Tells.Id.UNASKED]
		_say(String(bank[rng.randi_range(0, bank.size() - 1)]))
	if current.has_tell(Tells.Id.KNOWS_YOU):
		var bank2: Array = Tells.LINES[Tells.Id.KNOWS_YOU]
		var line_text := String(bank2[rng.randi_range(0, bank2.size() - 1)])
		if line_text.contains("%s"):
			line_text = line_text % RunState.officer_name
		_say(line_text)


func _say(text: String) -> void:
	note(text)
	ambient.emit(text)


# --- Asking ------------------------------------------------------------------

func can_ask(question: int) -> bool:
	if phase != Phase.QUESTIONING or current == null:
		return false
	if asks_left <= 0:
		return false
	return not asked_this_traveller.has(question)


## Ask, listen. The answer is drawn once and kept: asking the same question
## twice is a wasted ask, not a second sample.
func ask(question: int) -> String:
	if not can_ask(question):
		return ""
	asks_left -= 1
	asked_this_traveller.append(question)
	question_uses[question] = int(question_uses.get(question, 0)) + 1
	_learn_from(question)

	if Questions.is_trap(question):
		human_question_used = true
		_raise(Dread.ASK_TRAP_COST)

	var worn := is_learned(question)
	var reply: String = current.answered.get(question, "")
	if reply == "":
		reply = Questions.answer(question, current.is_thing, rng, current.given_name, worn)
		current.answered[question] = reply
	var tell := -1
	if current.is_thing and not worn:
		tell = question
	# Repeating you back is a reply to whatever you just asked, so it lands
	# here rather than on arrival.
	if current.is_thing and current.has_tell(Tells.Id.ECHO) and rng.randf() < 0.5:
		var echoes: Array = Tells.LINES[Tells.Id.ECHO]
		reply = String(echoes[rng.randi_range(0, echoes.size() - 1)]) % Questions.ask_text(question)
	note("Q: %s" % Questions.ask_text(question))
	note("A: %s" % reply)
	answered.emit(question, Questions.ask_text(question), reply, tell)
	state_changed.emit()
	return reply


## Things learn. A question you have leant on twice stops catching anything
## from shift three on — same question, same face, a person's answer.
func _learn_from(question: int) -> void:
	if shift < Dread.LEARNING_FROM_SHIFT:
		return
	if learned.has(question):
		return
	if int(question_uses.get(question, 0)) >= Dread.USES_BEFORE_LEARNED:
		learned.append(question)
		note("They have heard that one before.")


func is_learned(question: int) -> bool:
	return learned.has(question)


# --- Deciding ----------------------------------------------------------------

func decide(approve: bool) -> void:
	if phase != Phase.QUESTIONING or current == null:
		return
	# Only approve works on the faceless one. Refusing is not on offer, and
	# the stamp simply does not move — the rule lives here so the interface
	# and the tests cannot disagree about it.
	if current.is_faceless() and not approve:
		note("The DENY stamp does not move.")
		refused_deny.emit()
		return
	var correct := approve != current.is_thing
	current.verdict = 1 if approve else 0
	phase = Phase.DECIDED

	if approve and current.is_thing:
		things_let_through += 1
		lights = maxi(0, lights - 1)
		_raise(Dread.WRONG_APPROVE)
		note("Approved. A light goes out in the safe-zone window.")
		_roll_scare()
	elif approve:
		people_approved += 1
		note("Approved.")
	elif current.is_thing:
		things_denied += 1
		_raise(Dread.RIGHT_DENY)
		note("Denied. It stares at you for a moment, and then it goes.")
	else:
		people_turned_away += 1
		_raise(Dread.WRONG_DENY)
		owed_returns.append({"name": current.given_name, "shift": shift})
		note("Denied. They do not argue. That is worse.")

	decided.emit(current, approve, correct)
	state_changed.emit()
	if _check_run_over():
		return
	next_traveller()


func _raise(amount: int) -> void:
	dread = clampi(dread + amount, Dread.MIN, Dread.MAX)


# --- Scares ------------------------------------------------------------------

## Arm, do not fire. The delay is the mechanism: by the time it lands the
## player is reading someone else's face and has stopped bracing.
func _roll_scare() -> void:
	if armed_scare >= 0:
		return
	if rng.randf() >= Scares.chance(dread):
		return
	var options := Scares.all_ids()
	# The comeback needs someone to come back as, and only one of the six
	# can be spent on the outright question.
	_shuffle(options)
	armed_scare = options[0]
	armed_at = _clock + Scares.delay(rng)
	armed_seen_travellers = 0
	scare_armed.emit(armed_scare, armed_at - _clock)


## Called every frame by the scene, and stepped directly in tests.
func tick(delta: float) -> void:
	_clock += delta
	if armed_scare < 0 or _clock < armed_at:
		return
	# Never from the traveller who caused it. It waits for the next face.
	if armed_seen_travellers < 1:
		return
	var scare := armed_scare
	armed_scare = -1
	note(Scares.copy_for(scare))
	scare_fired.emit(scare, Scares.copy_for(scare))
	state_changed.emit()


func scare_pending() -> bool:
	return armed_scare >= 0


# --- Endings -----------------------------------------------------------------

func _end_shift() -> void:
	phase = Phase.SHIFT_OVER
	note("Shift %d ends. %d %s still lit." % [shift, lights,
		"light" if lights == 1 else "lights"])
	shift_ended.emit(shift)
	state_changed.emit()
	if _check_run_over():
		return
	if shift >= Shifts.count():
		_finish_run()


func _check_run_over() -> bool:
	if things_let_through >= Dread.EMPTIED_AT:
		_end(Ending.EMPTIED_THE_ZONE,
			"The window is dark. The last one in the line has your family's faces.")
		return true
	if people_turned_away >= Dread.TURNED_AWAY_AT:
		_end(Ending.TURNED_EVERYONE_AWAY,
			"There is no line any more. Behind you, the booth door opens.")
		return true
	return false


func _finish_run() -> void:
	_end(Ending.KEPT_THE_LINE,
		"The last figure answered every question the way you would have. You stamped it through. You do not know which of you walked away.")


func _end(which: int, reason: String) -> void:
	if phase == Phase.RUN_OVER:
		return
	phase = Phase.RUN_OVER
	ending = which
	end_reason = reason
	note(reason)
	run_ended.emit(ending_id(), reason)
	state_changed.emit()


func ending_id() -> StringName:
	match ending:
		Ending.KEPT_THE_LINE:
			return &"kept_the_line"
		Ending.EMPTIED_THE_ZONE:
			return &"emptied_the_zone"
		Ending.TURNED_EVERYONE_AWAY:
			return &"turned_everyone_away"
	return &"none"


## No score is shown at the end. This is what the game knows.
func tally() -> Dictionary:
	return {
		"things_let_through": things_let_through,
		"people_turned_away": people_turned_away,
		"things_denied": things_denied,
		"people_approved": people_approved,
		"lights": lights,
		"shift": shift,
	}


func note(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 300:
		log_lines.remove_at(0)


func _shuffle(array: Array) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp
