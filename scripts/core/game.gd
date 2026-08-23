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
signal adversary_declared(box: int)
signal adversary_acted(line: String)

enum Phase { FLOOR_START, TURN, FORGE, RUN_OVER }

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
var phase: int = Phase.FLOOR_START
var victory: bool = false
var end_reason: String = ""

## The player's last completed table, read by the Twin and the Magpie.
var last_player_values: Array = []
var log_lines: Array[String] = []


func start_run(seed_value: int = 0) -> void:
	card = Scorecard.new()
	pool = DicePool.new(Balance.pool_size, seed_value)
	charms.clear()
	floor_number = 0
	victory = false
	end_reason = ""
	log_lines.clear()
	log_line("Thirteen boxes. Spend them carefully.")
	next_floor()


func next_floor() -> void:
	floor_number += 1
	if floor_number > TOTAL_FLOORS:
		_end_run(true, "You walked out with %d boxes still unspent." % card.open_count())
		return
	threshold = Balance.threshold_for_floor(floor_number)
	floor_score = 0
	floor_turn = 0
	phase = Phase.FLOOR_START
	pool.begin_floor()
	adversary = AdversaryRoster.for_floor(floor_number) if Balance.is_duel_floor(floor_number) else null
	for c in charms:
		c.on_floor_start(self)
	log_line("--- Floor %d — threshold %d ---" % [floor_number, threshold])
	if adversary != null:
		adversary.on_duel_start(self)
		log_line("%s steps up to the card. %s" % [adversary.display_name, adversary.blurb])
		_adversary_declare()
	floor_started.emit(floor_number, threshold)
	begin_turn()


## Compose the table for a new turn. Locked dice are still sitting there.
func begin_turn() -> void:
	if card.is_exhausted():
		_end_run(false, "The card is full. The run ends where you are standing.")
		return
	phase = Phase.TURN
	floor_turn += 1
	rerolls_left = Balance.rerolls_per_turn
	turn_rolled = false
	pool.begin_turn("player")
	roll()


func roll() -> void:
	if phase != Phase.TURN:
		return
	if turn_rolled:
		if rerolls_left <= 0:
			return
		rerolls_left -= 1
	turn_rolled = true
	pool.roll_table()
	for c in charms:
		c.on_roll(self)
	log_line("Roll: %s" % pool.describe_table())
	state_changed.emit()


## Locked is locked for the entire floor, not the turn.
func lock_die(die: Die) -> void:
	if phase != Phase.TURN or die.locked or die.value == 0:
		return
	pool.lock_die(die, "player")
	for c in charms:
		c.on_lock(self, die)
	log_line("Locked %s on %d for the floor." % [die.die_name, die.value])
	state_changed.emit()


func table_values() -> Array:
	return pool.table_values()


func preview(box: int) -> int:
	var base := Scoring.score(box, table_values())
	for c in charms:
		base = c.modify_score(self, box, table_values(), base)
	return base


## Write into a box. This is the turn: one roll, one box, gone for the run.
func write_box(box: int) -> void:
	if phase != Phase.TURN or not card.is_open(box):
		return
	var values := table_values()
	var value := preview(box)
	var denied := adversary != null and box == adversary.declared_box
	last_player_values = values.duplicate()
	card.write_player(box, value)
	player_wrote.emit(box, value, denied)
	if denied:
		log_line("Denied: %s took %s out of %s's hands."
			% ["You", Scoring.box_name(box), adversary.display_name])
	floor_score += value
	if value == 0:
		log_line("Scratched %s. A hole for the rest of the run." % Scoring.box_name(box))
		_embitter_locked()
	else:
		log_line("%s for %d. (floor %d/%d)" % [Scoring.box_name(box), value, floor_score, threshold])
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
		_end_run(false, "The card is full on floor %d." % floor_number)
		return
	if adversary != null:
		_adversary_turn()
		if phase == Phase.RUN_OVER:
			return
		if card.is_exhausted():
			_end_run(false, "The card is full on floor %d." % floor_number)
			return
	begin_turn()


func _adversary_turn() -> void:
	var line := adversary.take_turn(self)
	log_line(line)
	adversary_acted.emit(line)
	if card.adversary_count() >= Balance.adversary_card_limit:
		_end_run(false, "%s claimed seven boxes. It takes the card." % adversary.display_name)
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
	if adversary != null:
		if floor_score > adversary.duel_score:
			reclaimed = card.reclaim(Balance.duel_reclaim)
			log_line("You out-scored %s, %d to %d. %d boxes come back."
				% [adversary.display_name, floor_score, adversary.duel_score, reclaimed.size()])
		else:
			log_line("%s out-scored you, %d to %d. The burned boxes stay burned."
				% [adversary.display_name, adversary.duel_score, floor_score])
	log_line("Floor %d cleared in %d turns. %d boxes left." % [floor_number, floor_turn, card.open_count()])
	floor_cleared.emit(floor_number, reclaimed)
	if floor_number >= TOTAL_FLOORS:
		_end_run(true, "Twelve floors down with %d boxes to spare." % card.open_count())
		return
	phase = Phase.FORGE
	state_changed.emit()


func leave_forge() -> void:
	if phase != Phase.FORGE:
		return
	next_floor()


func take_charm(charm: Charm) -> void:
	charms.append(charm)
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
