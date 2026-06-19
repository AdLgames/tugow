extends Node

# --- RUN STATE (persists across encounters) ---
var player_hp: int = 30
var max_hp: int = 30
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

# --- SIGNALS ---
signal dial_changed(new_value)
signal overheat_changed(new_value)
signal status_changed(traction, bleed, is_locked)
signal dealer_intent_telegraphed(intent_text)
signal hand_drawn(fresh_cards: Array)
signal match_ended(winner: String, damage_taken: int)
signal deck_counts_changed(deck_size: int, discard_size: int)
signal hp_changed(current_hp: int, max_hp: int)
signal encounter_started(encounter_num: int)
signal reward_offered(card_choices: Array)
signal run_over(final_encounter: int)

func start_run() -> void:
	player_hp = max_hp
	encounter_number = 1
	run_active = true
	master_deck = STARTING_DECK.duplicate()
	hp_changed.emit(player_hp, max_hp)
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
	pending_effects.clear()

	dial_changed.emit(dial_value)
	overheat_changed.emit(player_overheat)
	status_changed.emit(dealer_traction, dealer_bleed, dealer_is_locked)

	deck = master_deck.duplicate()
	hand.clear()
	discard_pile.clear()
	deck.shuffle()
	print("Encounter ", encounter_number, " — Deck: ", deck.size(), " cards. Difficulty: x", get_difficulty_modifier())

	prepare_next_dealer_intent()
	draw_hand(3)

func play_card(card_id: String) -> void:
	if not match_active:
		return
	if not CardDatabase.CARDS.has(card_id):
		push_error("Card ID not found in database: " + card_id)
		return

	var card = CardDatabase.CARDS[card_id]
	print("\n--- PLAYER PLAYED: ", card.name, " ---")

	var roll: int = card.base_val
	if card.variance > 0:
		roll += randi_range(-card.variance, card.variance)

	var resolved_value = int(roll * next_card_multiplier)
	if next_card_multiplier != 1.0:
		print("Multiplier Applied! Value scaled to: ", resolved_value)
		next_card_multiplier = 1.0

	match card.action:
		"PUSH":
			move_dial(resolved_value)

		"RESIST":
			if card.has("stacks"):
				dealer_is_locked = true
				print("Governor Lock engaged! Dealer's next turn bypassed.")
			else:
				dealer_traction += resolved_value
			status_changed.emit(dealer_traction, dealer_bleed, dealer_is_locked)

		"MULTIPLIER":
			next_card_multiplier = card.get("multiplier", 1.0)
			print("Gear charging. Next card multiplier: ", next_card_multiplier)

		"VENT":
			player_overheat = max(0, player_overheat - card.get("drain_val", 0))
			overheat_changed.emit(player_overheat)
			move_dial(resolved_value)

		"CONDITIONAL_PUSH":
			var target_mod = card.get("target_mod", 1)
			if dial_value != 0 and dial_value % target_mod == 0:
				var bonus = card.get("bonus_val", 0)
				print("Sweet Spot Hit! Bonus +", bonus)
				move_dial(resolved_value + bonus)
			else:
				move_dial(resolved_value)

		"PRECISION_STRIKE":
			move_dial(resolved_value)
			var target_mod = card.get("target_mod", 1)
			if dial_value % target_mod == 0:
				var bonus = card.get("bonus_val", 0)
				print("Precision Placement! Bonus +", bonus)
				move_dial(bonus)

		"DELAY_PUSH":
			var delay = card.get("delay_turns", 1)
			pending_effects.append({
				"action": "PUSH",
				"base_val": card.base_val,
				"variance": card.variance,
				"turns_left": delay,
				"name": card.name
			})
			print("Winding up: ", card.name, " fires in ", delay, " turn(s).")

		"BLEED":
			dealer_bleed += card.get("stacks", 0)
			status_changed.emit(dealer_traction, dealer_bleed, dealer_is_locked)
			print("Mechanism corroded. Total Bleed stacks on Dealer: ", dealer_bleed)

	discard_card_from_hand(card_id)

	if card.has("cost"):
		var cost_data = card.cost
		if cost_data.type == "OVERHEAT":
			player_overheat += cost_data.amount
			overheat_changed.emit(player_overheat)
			print("System generating heat. Overheat stacks: ", player_overheat)

	if check_win_condition(): return

	if card.get("free_action", false):
		print("Free Action card. Remaining in Player phase.")
		return

	end_player_turn()

func move_dial(amount: int) -> void:
	dial_value += amount
	dial_changed.emit(dial_value)
	print("Dial Adjusted: ", dial_value)

func end_player_turn() -> void:
	if player_overheat > 0:
		var slip_amount = player_overheat * 2
		print("Overheat Backlash! Dial slips back by: -", slip_amount)
		move_dial(-slip_amount)

	if check_win_condition(): return

	pass_turn_to_dealer()

func pass_turn_to_dealer() -> void:
	print("--- ENTERING DEALER PHASE ---")

	if dealer_is_locked:
		print("Dealer is frozen by structural lock! Skipping phase.")
		dealer_is_locked = false
		status_changed.emit(dealer_traction, dealer_bleed, dealer_is_locked)
		start_new_round()
		return

	await get_tree().create_timer(0.8).timeout

	execute_dealer_move()

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
		print("Dealer pulls for ", scaled_roll, " (Mitigated by ", mitigation, ") = Actual Pull: -", final_pull)
		move_dial(-final_pull)

	elif move.type == DealerAI.MoveType.SABOTAGE:
		var sabotage_amount = 2 + int((encounter_number - 1) / 3)
		player_overheat += sabotage_amount
		overheat_changed.emit(player_overheat)
		print("Dealer sabotaged player mechanics! +", sabotage_amount, " Overheat.")

	dealer_traction = 0
	if dealer_bleed > 0:
		dealer_bleed -= 1
	status_changed.emit(dealer_traction, dealer_bleed, dealer_is_locked)

	if check_win_condition(): return

	start_new_round()

func start_new_round() -> void:
	print("--- STARTING NEW ROUND ---")
	resolve_pending_effects()
	if check_win_condition(): return
	prepare_next_dealer_intent()
	draw_hand(3)

func resolve_pending_effects() -> void:
	var still_pending: Array[Dictionary] = []
	for effect in pending_effects:
		effect.turns_left -= 1
		if effect.turns_left <= 0:
			var roll: int = effect.base_val
			if effect.variance > 0:
				roll += randi_range(-effect.variance, effect.variance)
			print("Delayed effect triggers: ", effect.name, " for +", roll)
			move_dial(roll)
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
	var damage: int = 0
	if winner == "PLAYER":
		damage = player_overheat
		if damage > 0:
			print("Victory! But overheat burns for ", damage, " HP.")
	else:
		damage = 8 + encounter_number * 2
		print("Defeat! Taking ", damage, " damage.")

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
	print("Card added to deck: ", card_id, ". Deck size: ", master_deck.size())
	advance_encounter()

func skip_reward() -> void:
	print("Reward skipped.")
	advance_encounter()

func continue_after_loss() -> void:
	if run_active:
		advance_encounter()

func advance_encounter() -> void:
	encounter_number += 1
	encounter_started.emit(encounter_number)
	start_match()

func get_difficulty_modifier() -> float:
	return 1.0 + (encounter_number - 1) * 0.15

func initialize_deck() -> void:
	deck = master_deck.duplicate()
	hand.clear()
	discard_pile.clear()
	deck.shuffle()
	print("Deck initialized and shuffled. Total cards: ", deck.size())

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

	print("Hand drawn: ", hand, " | Remaining Deck: ", deck.size(), " | Discard: ", discard_pile.size())

	hand_drawn.emit(hand)
	deck_counts_changed.emit(deck.size(), discard_pile.size())

func recycle_discard_into_deck() -> void:
	print("--- Deck empty! Shuffling discard pile back into deck. ---")
	deck = discard_pile.duplicate()
	discard_pile.clear()
	deck.shuffle()

func discard_card_from_hand(card_id: String) -> void:
	var index = hand.find(card_id)
	if index != -1:
		hand.remove_at(index)
		discard_pile.append(card_id)
		deck_counts_changed.emit(deck.size(), discard_pile.size())

func unlock_magic_card(card_id: String) -> void:
	if card_id not in unlocked_magic_cards:
		unlocked_magic_cards.append(card_id)
		print("Magic card unlocked: ", card_id)

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
		print("Card added to master deck: ", card_id)
