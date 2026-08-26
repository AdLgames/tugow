class_name Game
extends RefCounted
## The run. Floors, turns, boxes, and the Adversary duel — all headless so the
## same object drives the UI and the tests.

signal log_emitted(line: String)
signal state_changed()
signal floor_started(floor_number: int, threshold: int)
signal floor_cleared(floor_number: int, reclaimed: Array)
signal run_ended(victory: bool, reason: String)
signal player_wrote(box: int, value: int, denied: bool)
signal thrown(result: Throw.Result)
## Emitted the moment the dice leave the hand, before they land.
signal throw_began(strength: int)
## A fresh turn, with nothing on the table yet.
signal turn_started()
signal dice_lost(dice: Array)
signal adversary_declared(box: int)
signal adversary_acted(line: String)

enum Phase { FLOOR_START, TURN, BENCH, RUN_OVER }

const TOTAL_FLOORS := 12

var card: Scorecard
var pool: DicePool
var charms: Array[Charm] = []
var adversary: Adversary = null

var floor_number: int = 0
var threshold: int = 0
var floor_score: int = 0
var floor_turn: int = 0
var rerolls_left: int = 0
var turn_rolled: bool = false
## Chosen anew for every throw.
var throw_strength: int = Throw.Strength.MEDIUM
var last_throw: Throw.Result = null
## Set while the dice are in the air. Nothing may be settled mid-throw.
var dice_in_the_air: bool = false
## Supplied by the interface. When present the throw is physical and takes
## time; without one the model resolves it on the spot, which is what the
## tests and the balance sweeps run on.
var stage = null
var _throw_seeds := RandomNumberGenerator.new()
var phase: int = Phase.FLOOR_START
var victory: bool = false
var end_reason: String = ""

## The player's last completed table, read by the Reflection and the Magpie.
var last_player_values: Array = []
## Overshoot banked from the previous floor, and how much of it opened this one.
var pending_carry: int = 0
var floor_carry_in: int = 0
## Charms taken since this night began.
var charms_taken_tonight: int = 0
var log_lines: Array[String] = []


func start_run(seed_value: int = 0) -> void:
	card = Scorecard.new()
	pool = DicePool.new(Balance.pool_size, seed_value)
	charms.clear()
	floor_number = 0
	victory = false
	end_reason = ""
	log_lines.clear()
	charms_taken_tonight = 0
	pending_carry = 0
	floor_carry_in = 0
	log_line("Thirteen lines. Settle them carefully.")
	next_floor()


func next_floor() -> void:
	floor_number += 1
	if floor_number > TOTAL_FLOORS:
		_end_run(true, "You walked out with %s." % Lore.lines_owed(card.open_count()))
		return
	threshold = Balance.threshold_for_floor(floor_number)
	charms_taken_tonight = 0
	floor_carry_in = pending_carry
	floor_score = pending_carry
	pending_carry = 0
	floor_turn = 0
	phase = Phase.FLOOR_START
	pool.begin_floor()
	adversary = AdversaryRoster.for_floor(floor_number) if Balance.is_duel_floor(floor_number) else null
	for c in charms:
		c.on_floor_start(self)
	log_line("--- %s — threshold %d ---" % [Lore.night(floor_number), threshold])
	if floor_carry_in > 0:
		log_line("Carried in: %d." % floor_carry_in)
	if adversary != null:
		adversary.on_duel_start(self)
		log_line("%s steps up to the card. %s" % [adversary.display_name, adversary.blurb])
		_adversary_declare()
	floor_started.emit(floor_number, threshold)
	begin_turn()


## Compose the table for a new turn. Locked dice are still sitting there.
func begin_turn() -> void:
	if card.is_exhausted():
		_end_run(false, "The Ledger is full. The run ends where you are standing.")
		return
	phase = Phase.TURN
	floor_turn += 1
	rerolls_left = Balance.rerolls_per_turn
	turn_rolled = false
	pool.begin_turn("player")
	# The felt starts bare. Nothing is on it and nothing can be settled until
	# you have thrown — the first draw of the turn is yours to make. Staked
	# dice are the exception: they were sealed for the night and keep the face
	# they were sealed on.
	for die in pool.table:
		if die.locked:
			continue
		die.value = 0
		die.second_value = 0
		die.zone = Throw.Zone.POT
	# With every die staked there is nothing left to throw, so the faces on
	# the felt are already the hand. Count the turn as drawn or the night
	# deadlocks with no legal move.
	if not can_throw():
		turn_rolled = true
	turn_started.emit()
	state_changed.emit()


## Throw strength is the main risk dial: soft never reaches the rail, hard
## scatters wide and can put dice off the table for the rest of the floor.
func throw(strength: int = -1) -> void:
	if phase != Phase.TURN or dice_in_the_air:
		return
	if turn_rolled:
		if rerolls_left <= 0:
			return
		rerolls_left -= 1
	turn_rolled = true
	if strength >= 0:
		throw_strength = strength
	if not can_throw():
		return

	# A die resting on the rail is shoved outward before anything new lands,
	# whichever way the throw is resolved.
	var pushed := ThrowContract.push_rail_dice(
		pool.table, throw_strength, has_charm(&"long_throw"))
	for die in pushed:
		log_line("%s is shoved off the lip." % die.die_name)

	throw_began.emit(throw_strength)
	if stage != null:
		dice_in_the_air = true
		state_changed.emit()
		stage.begin_throw(throw_strength, _throw_seeds.randi(),
			staked_dice(), _thrown_ids())
		return
	last_throw = pool.throw_table(throw_strength, has_charm(&"long_throw"))
	_finish_throw(pushed)


## Which of the eight are on the table this turn, in order. The simulation
## needs their identities, not five anonymous bodies.
func _thrown_ids() -> Array:
	var ids: Array = []
	for die in pool.table:
		if not die.lost:
			ids.append(die.id)
	return ids


## Staked dice are not thrown: the stage sets them down showing their face.
func staked_dice() -> Array:
	var held: Array = []
	for die in pool.table:
		if die.locked and not die.lost:
			held.append({
				"id": die.id,
				"value": die.value,
				"position": die.landing_position(),
			})
	return held


## Called by the stage once the bodies have settled. The faces, the zones and
## the cocked dice are read off the table, not decided here.
func apply_physical_throw(records: Array) -> void:
	if not dice_in_the_air:
		return
	dice_in_the_air = false
	var lost: Array[Die] = []
	for entry in records:
		var die := pool.get_die(int(entry["id"]))
		if die == null or die.locked:
			continue
		var spot: Vector2 = entry["position"]
		die.landing_radius = spot.length()
		die.landing_angle = spot.angle()
		die.zone = int(entry["zone"])
		die.last_value = die.value
		die.value = int(entry["value"])
		die.repeated = die.value == die.last_value and die.value != 0
		die.second_value = int(entry["second_value"])
		die.cocked_on = die.id if die.second_value > 0 else -1
		if entry["lost"] and not die.lost:
			die.lost = true
			lost.append(die)
	var result := Throw.Result.new()
	result.strength = throw_strength
	result.lost = lost
	for die in pool.table:
		if die.second_value > 0:
			result.cocked.append(die)
	last_throw = result
	_finish_throw(lost)


func _finish_throw(lost: Array[Die]) -> void:
	for c in charms:
		c.on_roll(self)
	log_line(last_throw.summary())
	for c in last_throw.collisions:
		log_line("  %s knocks %s from %d to %d." % c)
	if not lost.is_empty():
		dice_lost.emit(lost)
	log_line("Table: %s" % pool.describe_table())
	thrown.emit(last_throw)
	state_changed.emit()


## Kept for tests and tools that only care about faces, not physics.
func roll() -> void:
	throw()


## Every die on the table is locked or gone: there is nothing to throw.
## Draws left this turn, including the first one if it has not been made.
func draws_left() -> int:
	return rerolls_left + (0 if turn_rolled else 1)


func can_throw() -> bool:
	for d in pool.table:
		if not d.locked and not d.lost:
			return true
	return false


## Locked is locked for the entire floor, not the turn.
func lock_die(die: Die) -> void:
	if phase != Phase.TURN or die.locked or die.value == 0:
		return
	pool.lock_die(die, "player")
	for c in charms:
		c.on_lock(self, die)
	log_line("Staked %s on %d for the night." % [die.die_name, die.value])
	state_changed.emit()


## Dice on the table that are still free to throw: not locked, not lost.
func free_dice_on_table() -> int:
	var n := 0
	for d in pool.table:
		if not d.locked and not d.lost:
			n += 1
	return n


## Locking every die on the table freezes the rest of the floor: the same
## score, every turn, with no way to change it. Sometimes correct, never an
## accident.
func would_lock_out(die: Die) -> bool:
	return not die.locked and free_dice_on_table() == 1


func preview(box: int) -> int:
	if not turn_rolled:
		return 0
	var values := table_values()
	var base := int(round(Scoring.score(box, values) * Throw.rail_multiplier(pool.table)))
	for c in charms:
		base = c.modify_score(self, box, values, base)
	return base


## What the resolver reads: the dice on the table, after any charm that
## changes how they are read (the Underhand takes a die's hidden face).
func table_values() -> Array:
	var values := pool.table_values()
	for c in charms:
		values = c.modify_values(self, values, pool.live_table())
	return values


## Write into a box. This is the turn: one roll, one box, gone for the run.
func write_box(box: int) -> void:
	if phase != Phase.TURN or not card.is_open(box):
		return
	# You settle a line against dice. Before the first throw there are none.
	if not turn_rolled:
		return
	var values := table_values()
	var value := preview(box)
	var denied := adversary != null and box == adversary.declared_box
	last_player_values = values.duplicate()
	card.write_player(box, value)
	player_wrote.emit(box, value, denied)
	if denied:
		log_line("Denied: you took %s out of %s's hands."
			% [Scoring.box_name(box), adversary.display_name])
		# The call is dead the moment the line is taken.
		adversary.declared_box = -1
	floor_score += value
	if value == 0:
		log_line("Struck out %s. A hole in the Ledger for the rest of the run." % Scoring.box_name(box))
		_embitter_locked()
	else:
		log_line("%s for %d. (%d/%d tonight)" % [Scoring.box_name(box), value, floor_score, threshold])
		_reward_locked_dice()
	for c in charms:
		for extra in c.extra_writes(self, box, values):
			if card.is_open(extra[0]):
				card.write_player(extra[0], extra[1])
				floor_score += extra[1]
				log_line("%s also fills %s for %d." % [c.charm_name, Scoring.box_name(extra[0]), extra[1]])
	_burn_extra_boxes()
	state_changed.emit()
	_after_player_turn()


func _after_player_turn() -> void:
	if floor_score >= threshold:
		_clear_floor()
		return
	if card.is_exhausted():
		_end_run(false, "The Ledger is full on %s." % Lore.night(floor_number).to_lower())
		return
	if adversary != null:
		_adversary_turn()
		if phase == Phase.RUN_OVER:
			return
		if card.is_exhausted():
			_end_run(false, "The Ledger is full on %s." % Lore.night(floor_number).to_lower())
			return
	begin_turn()


func _adversary_turn() -> void:
	var line := adversary.take_turn(self)
	log_line(line)
	adversary_acted.emit(line)
	if card.adversary_count() >= Balance.adversary_card_limit:
		_end_run(false, "%s has seven lines. He takes the Ledger." % adversary.display_name)
		return
	_adversary_declare()


func _adversary_declare() -> void:
	var box := adversary.declare(self)
	if box < 0:
		return
	log_line("%s announces: %s." % [adversary.display_name, Scoring.box_name(box)])
	adversary_declared.emit(box)


func _clear_floor() -> void:
	var reclaimed: Array = []
	var earned := floor_score - floor_carry_in
	if adversary != null:
		if earned > adversary.duel_score:
			reclaimed = card.reclaim(Balance.duel_reclaim)
			log_line("You out-scored %s, %d to %d. %d boxes come back."
				% [adversary.display_name, earned, adversary.duel_score, reclaimed.size()])
		else:
			log_line("%s out-scored you, %d to %d. The burned boxes stay burned."
				% [adversary.display_name, adversary.duel_score, earned])
	log_line("%s cleared in %s. %s." % [Lore.night(floor_number), Lore.draws(floor_turn),
		Lore.lines_owed(card.open_count())])
	if adversary != null:
		# The night is over; nothing is on call any more.
		adversary.declared_box = -1
	_bank_overflow()
	if floor_number >= TOTAL_FLOORS:
		floor_cleared.emit(floor_number, reclaimed)
		_end_run(true, "Twelve nights down with %s." % Lore.lines_owed(card.open_count()))
		return
	# Phase first: listeners read it to decide whether to open the bench.
	phase = Phase.BENCH
	floor_cleared.emit(floor_number, reclaimed)
	state_changed.emit()


## Overshoot is not wasted. Scoring past the threshold banks the difference
## toward the next floor, capped so a huge turn cannot skip a floor outright.
func _bank_overflow() -> void:
	var overflow := floor_score - threshold
	if overflow <= 0:
		return
	var next_threshold := Balance.threshold_for_floor(floor_number + 1)
	var cap := int(next_threshold * Balance.overflow_carry_cap)
	pending_carry = mini(int(overflow * Balance.overflow_carry_ratio), cap)
	if pending_carry <= 0:
		return
	log_line("Overshot by %d. %d carries to %s." % [overflow, pending_carry, Lore.night(floor_number + 1).to_lower()])


func leave_bench() -> void:
	if phase != Phase.BENCH:
		return
	next_floor()


func take_charm(charm: Charm) -> void:
	charms.append(charm)
	charms_taken_tonight += 1
	log_line("Charm taken: %s — %s" % [charm.charm_name, charm.text])
	state_changed.emit()


func has_charm(charm_id: StringName) -> bool:
	for c in charms:
		if c.id == charm_id:
			return true
	return false


## Dice locked into a scoring box level up; three scores reshapes a face.
func _reward_locked_dice() -> void:
	for d in pool.table:
		if not d.locked:
			continue
		if d.note_scored():
			log_line("%s reshapes a face: %s" % [d.die_name, str(Array(d.faces))])


## Dice used in a scratched box turn bitter.
func _embitter_locked() -> void:
	for d in pool.table:
		if d.locked and not d.bitter:
			d.embitter()
			log_line("%s turns bitter." % d.die_name)


func _burn_extra_boxes() -> void:
	var extra := 0
	for c in charms:
		extra += c.extra_boxes_per_turn()
	for _i in extra:
		var open_now := card.open_boxes()
		if open_now.is_empty():
			return
		var cheapest: int = open_now[0]
		for box in open_now:
			if Scoring.score(box, [1, 1, 1, 1, 1]) < Scoring.score(cheapest, [1, 1, 1, 1, 1]):
				cheapest = box
		card.burn(cheapest)
		log_line("Blood Pact burns %s." % Scoring.box_name(cheapest))


func _end_run(won: bool, reason: String) -> void:
	phase = Phase.RUN_OVER
	victory = won
	end_reason = reason
	log_line(reason)
	log_line("Run total: %d over %d floors." % [card.run_total, floor_number])
	run_ended.emit(won, reason)
	state_changed.emit()


func log_line(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 200:
		log_lines.remove_at(0)
	log_emitted.emit(line)
