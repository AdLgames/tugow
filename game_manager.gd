extends Node

# --- RUN STATE (persists across encounters) ---
var player_hp: int = 30
var max_hp: int = 30
var gold: int = 0
var encounter_number: int = 1
var run_active: bool = false
var master_deck: Array[String] = []

# --- MATCH STATE (reset each encounter) ---
var dial_value: int = 0
var player_overheat: int = 0
var dealer_traction: int = 0
var dealer_bleed: int = 0
var dealer_is_locked: bool = false
var next_card_multiplier: float = 1.0
var current_dealer_intent: Dictionary = {}
var match_active: bool = false
var is_resolving: bool = false
var pending_effects: Array[Dictionary] = []

# --- CARD TYPE TOGGLES ---
var magic_enabled: bool = false
var unlocked_magic_cards: Array[String] = []

# --- BATTLE DECK STATE ---
var deck: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []

const STARTING_DECK: Array[String] = [
	"piston_jab", "piston_jab", "piston_jab", "piston_jab",
	"grounding_cleats", "grounding_cleats", "grounding_cleats",
	"pressure_gauge", "pressure_gauge",
	"rivet_tap",
	"overdrive"
]

const CARD_PRICES = {
	"COMMON": 30,
	"UNCOMMON": 60,
	"RARE": 100
}

# --- SIGNALS ---
signal dial_changed(new_value)
signal overheat_changed(new_value)
signal status_changed(traction, bleed, is_locked)
signal dealer_intent_telegraphed(intent_text)
signal hand_drawn(fresh_cards: Array)
signal match_ended(winner: String, damage_taken: int)
signal deck_counts_changed(deck_size: int, discard_size: int)
signal hp_changed(current_hp: int, max_hp: int)
signal gold_changed(amount: int)
signal encounter_started(encounter_num: int)
signal reward_offered(card_choices: Array)
signal shop_opened(shop_items: Array)
signal run_over(final_encounter: int)
signal action_announced(text: String)
signal dealer_anim_requested(anim_name: String)
signal turn_phase_changed(is_player_turn: bool)

func start_run() -> void:
	player_hp = max_hp
	gold = 0
	encounter_number = 1
	run_active = true
	master_deck = STARTING_DECK.duplicate()
	unlocked_magic_cards.clear()
	hp_changed.emit(player_hp, max_hp)
	gold_changed.emit(gold)
	encounter_started.emit(encounter_number)
	start_match()

func start_match() -> void:
	dial_value = 0
	player_overheat = 0
	dealer_traction = 0
	dealer_bleed = 0
	dealer_is_locked = false
	next_card_multiplier = 1.0
	match_active = true
	is_resolving = false
	pending_effects.clear()

	dial_changed.emit(dial_value)
	overheat_changed.emit(player_overheat)
	status_changed.emit(dealer_traction, dealer_bleed, dealer_is_locked)

	deck = master_deck.duplicate()
	hand.clear()
	discard_pile.clear()
	deck.shuffle()

	action_announced.emit("Encounter %d — Fight!" % encounter_number)
	dealer_anim_requested.emit("IDLE")
	prepare_next_dealer_intent()
	draw_hand(3)
	turn_phase_changed.emit(true)

func play_card(card_id: String) -> void:
	if not match_active or is_resolving:
		return
	if not CardDatabase.CARDS.has(card_id):
		return

	is_resolving = true
	var card = CardDatabase.CARDS[card_id]

	discard_card_from_hand(card_id)

	var roll: int = card.base_val
	if card.variance > 0:
		roll += randi_range(-card.variance, card.variance)

	var applied_multiplier = next_card_multiplier
	var resolved_value = int(roll * applied_multiplier)
	if applied_multiplier != 1.0:
		next_card_multiplier = 1.0

	match card.action:
		"PUSH":
			move_dial(resolved_value)
			if applied_multiplier != 1.0:
				action_announced.emit("%s: Dial +%d (x%.1f!)" % [card.name, resolved_value, applied_multiplier])
			else:
				action_announced.emit("%s: Dial +%d" % [card.name, resolved_value])

		"RESIST":
			if card.has("stacks"):
				dealer_is_locked = true
				action_announced.emit("%s: Dealer LOCKED!" % card.name)
			else:
				dealer_traction += resolved_value
				action_announced.emit("%s: Traction +%d" % [card.name, resolved_value])
			status_changed.emit(dealer_traction, dealer_bleed, dealer_is_locked)

		"MULTIPLIER":
			next_card_multiplier = card.get("multiplier", 1.0)
			action_announced.emit("%s: Next card x%.1f!" % [card.name, next_card_multiplier])

		"VENT":
			var drain = card.get("drain_val", 0)
			player_overheat = max(0, player_overheat - drain)
			overheat_changed.emit(player_overheat)
			move_dial(resolved_value)
			action_announced.emit("%s: -%d Heat, Dial +%d" % [card.name, drain, resolved_value])

		"CONDITIONAL_PUSH":
			var target_mod = card.get("target_mod", 1)
			if dial_value != 0 and dial_value % target_mod == 0:
				var bonus = card.get("bonus_val", 0)
				move_dial(resolved_value + bonus)
				action_announced.emit("%s: Sweet Spot! +%d" % [card.name, resolved_value + bonus])
			else:
				move_dial(resolved_value)
				action_announced.emit("%s: Dial +%d" % [card.name, resolved_value])

		"PRECISION_STRIKE":
			move_dial(resolved_value)
			var target_mod = card.get("target_mod", 1)
			if dial_value % target_mod == 0:
				var bonus = card.get("bonus_val", 0)
				move_dial(bonus)
				action_announced.emit("%s: Precision! +%d then +%d" % [card.name, resolved_value, bonus])
			else:
				action_announced.emit("%s: Dial +%d" % [card.name, resolved_value])

		"DELAY_PUSH":
			var delay = card.get("delay_turns", 1)
			pending_effects.append({
				"action": "PUSH",
				"base_val": card.base_val,
				"variance": card.variance,
				"turns_left": delay,
				"name": card.name
			})
			action_announced.emit("%s: Fires in %d turn(s)!" % [card.name, delay])

		"BLEED":
			dealer_bleed += card.get("stacks", 0)
			status_changed.emit(dealer_traction, dealer_bleed, dealer_is_locked)
			action_announced.emit("%s: Bleed +%d on Dealer" % [card.name, card.get("stacks", 0)])

	if card.has("cost"):
		var cost_data = card.cost
		if cost_data.type == "OVERHEAT":
			player_overheat += cost_data.amount
			overheat_changed.emit(player_overheat)

	if check_win_condition():
		return

	# Hand empty → auto end turn after a brief pause
	if hand.is_empty():
		await get_tree().create_timer(0.5).timeout
		await end_player_turn()
	else:
		is_resolving = false

func manual_end_turn() -> void:
	if not match_active or is_resolving:
		return
	is_resolving = true
	turn_phase_changed.emit(false)
	await get_tree().create_timer(0.3).timeout
	await end_player_turn()

func move_dial(amount: int) -> void:
	dial_value += amount
	dial_changed.emit(dial_value)

func end_player_turn() -> void:
	turn_phase_changed.emit(false)
	if player_overheat > 0:
		var slip_amount = player_overheat
		action_announced.emit("Overheat backlash: -%d!" % slip_amount)
		move_dial(-slip_amount)
		await get_tree().create_timer(0.5).timeout

	if check_win_condition():
		return

	await pass_turn_to_dealer()

func pass_turn_to_dealer() -> void:
	if dealer_is_locked:
		action_announced.emit("Dealer is LOCKED! Turn skipped.")
		dealer_anim_requested.emit("HURT")
		await get_tree().create_timer(0.8).timeout
		dealer_is_locked = false
		status_changed.emit(dealer_traction, dealer_bleed, dealer_is_locked)
		await start_new_round()
		return

	action_announced.emit("Dealer: " + current_dealer_intent.name)
	dealer_anim_requested.emit("ATTACK")
	await get_tree().create_timer(0.8).timeout

	await execute_dealer_move()

func execute_dealer_move() -> void:
	var move = current_dealer_intent
	var difficulty = get_difficulty_modifier()
	var base_roll = move.base_val
	if move.variance > 0:
		base_roll += randi_range(-move.variance, move.variance)

	if move.type == DealerAI.MoveType.PULL or move.type == DealerAI.MoveType.HEAVY_PULL:
		var scaled_roll = int(base_roll * difficulty)
		var mitigation = dealer_traction + dealer_bleed
		var final_pull = max(0, scaled_roll - mitigation)
		move_dial(-final_pull)
		if mitigation > 0:
			action_announced.emit("Pulls -%d (blocked %d)" % [final_pull, mitigation])
		else:
			action_announced.emit("Pulls -%d!" % final_pull)

	elif move.type == DealerAI.MoveType.SABOTAGE:
		var sabotage_amount = 1 + int((encounter_number - 1) / 3)
		player_overheat += sabotage_amount
		overheat_changed.emit(player_overheat)
		action_announced.emit("Sabotage! Overheat +%d" % sabotage_amount)

	await get_tree().create_timer(0.6).timeout
	dealer_anim_requested.emit("IDLE")

	dealer_traction = 0
	if dealer_bleed > 0:
		dealer_bleed -= 1
	status_changed.emit(dealer_traction, dealer_bleed, dealer_is_locked)

	if check_win_condition():
		return

	await start_new_round()

func start_new_round() -> void:
	await resolve_pending_effects()
	if check_win_condition():
		return
	prepare_next_dealer_intent()
	draw_hand(3)
	turn_phase_changed.emit(true)
	is_resolving = false

func resolve_pending_effects() -> void:
	var still_pending: Array[Dictionary] = []
	for effect in pending_effects:
		effect.turns_left -= 1
		if effect.turns_left <= 0:
			var roll: int = effect.base_val
			if effect.variance > 0:
				roll += randi_range(-effect.variance, effect.variance)
			move_dial(roll)
			action_announced.emit("%s triggers: +%d!" % [effect.name, roll])
			await get_tree().create_timer(0.5).timeout
		else:
			still_pending.append(effect)
	pending_effects = still_pending

func prepare_next_dealer_intent() -> void:
	current_dealer_intent = DealerAI.select_next_move(dial_value)
	dealer_intent_telegraphed.emit(current_dealer_intent.intent_text)

func check_win_condition() -> bool:
	if dial_value >= 21:
		_end_match("PLAYER")
		return true
	elif dial_value <= -21:
		_end_match("DEALER")
		return true
	return false

func _end_match(winner: String) -> void:
	match_active = false
	is_resolving = false
	turn_phase_changed.emit(false)
	var damage: int = 0
	if winner == "PLAYER":
		damage = player_overheat
		var gold_earned = 25 + encounter_number * 10
		gold += gold_earned
		gold_changed.emit(gold)
		dealer_anim_requested.emit("DEATH")
	else:
		damage = 5 + encounter_number * 2
		dealer_anim_requested.emit("FLYING")

	if damage > 0:
		take_damage(damage)

	match_ended.emit(winner, damage)

func take_damage(amount: int) -> void:
	player_hp = max(0, player_hp - amount)
	hp_changed.emit(player_hp, max_hp)

func offer_reward() -> void:
	var pool: Array[String] = []
	for card_id in CardDatabase.CARDS:
		if is_card_available(card_id):
			pool.append(card_id)
	pool.shuffle()
	var choices = pool.slice(0, mini(3, pool.size()))
	reward_offered.emit(choices)

func select_reward(card_id: String) -> void:
	master_deck.append(card_id)
	var card = CardDatabase.CARDS.get(card_id, {})
	if card.get("type", "") == "MAGIC":
		unlock_magic_card(card_id)
	open_shop()

func skip_reward() -> void:
	open_shop()

func open_shop() -> void:
	var pool: Array[String] = []
	for card_id in CardDatabase.CARDS:
		pool.append(card_id)
	pool.shuffle()
	var items: Array[Dictionary] = []
	for i in range(mini(4, pool.size())):
		var card_id = pool[i]
		var rarity = CardDatabase.CARDS[card_id].get("rarity", "COMMON")
		items.append({
			"card_id": card_id,
			"price": CARD_PRICES.get(rarity, 50)
		})
	shop_opened.emit(items)

func buy_card(card_id: String, price: int) -> void:
	if gold < price:
		return
	gold -= price
	gold_changed.emit(gold)
	master_deck.append(card_id)
	var card = CardDatabase.CARDS.get(card_id, {})
	if card.get("type", "") == "MAGIC":
		unlock_magic_card(card_id)

func leave_shop() -> void:
	advance_encounter()

func continue_after_loss() -> void:
	if run_active:
		advance_encounter()

func advance_encounter() -> void:
	encounter_number += 1
	encounter_started.emit(encounter_number)
	start_match()

func get_difficulty_modifier() -> float:
	return 1.0 + (encounter_number - 1) * 0.1

func draw_hand(amount: int = 3) -> void:
	for card in hand:
		discard_pile.append(card)
	hand.clear()

	for i in range(amount):
		if deck.is_empty():
			recycle_discard_into_deck()
		if not deck.is_empty():
			var drawn_card = deck.pop_back()
			hand.append(drawn_card)

	hand_drawn.emit(hand)
	deck_counts_changed.emit(deck.size(), discard_pile.size())

func recycle_discard_into_deck() -> void:
	deck = discard_pile.duplicate()
	discard_pile.clear()
	deck.shuffle()
	action_announced.emit("Discard reshuffled into deck!")

func discard_card_from_hand(card_id: String) -> void:
	var index = hand.find(card_id)
	if index != -1:
		hand.remove_at(index)
		discard_pile.append(card_id)
		hand_drawn.emit(hand)
		deck_counts_changed.emit(deck.size(), discard_pile.size())

func unlock_magic_card(card_id: String) -> void:
	if card_id not in unlocked_magic_cards:
		unlocked_magic_cards.append(card_id)

func is_card_available(card_id: String) -> bool:
	var card = CardDatabase.CARDS.get(card_id, {})
	if card.get("type", "") == "NUMBER":
		return true
	if card.get("type", "") == "MAGIC":
		return magic_enabled or card_id in unlocked_magic_cards
	return false

func add_card_to_deck(card_id: String) -> void:
	if is_card_available(card_id):
		master_deck.append(card_id)
