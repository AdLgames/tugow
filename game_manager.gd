extends Node

# --- GAME STATE DATA ---
var dial_value: int = 0
var player_overheat: int = 0
var dealer_traction: int = 0
var dealer_bleed: int = 0
var dealer_is_locked: bool = false
var next_card_multiplier: float = 1.0

var current_dealer_intent: Dictionary = {}

# --- DECK MANAGEMENT STATE ---
var deck: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []

# A standard starter deck list using your Database IDs
const STARTING_DECK: Array[String] = [
	"piston_jab", "piston_jab", "piston_jab", "piston_jab",
	"grounding_cleats", "grounding_cleats", "grounding_cleats",
	"pressure_gauge", "pressure_gauge",
	"rivet_tap",
	"overdrive"
]

# --- SIGNALS FOR THE UI (main.gd) TO LISTEN TO ---
signal dial_changed(new_value)
signal overheat_changed(new_value)
signal status_changed(traction, bleed, is_locked)
signal dealer_intent_telegraphed(intent_text)
signal hand_drawn(fresh_cards: Array) # Fixed name alignment here
signal game_over(winner) # Outputs "PLAYER" or "DEALER"

func _ready() -> void:
	randomize()

func start_match() -> void:
	# 1. Reset all the basic stats to zero
	dial_value = 0
	player_overheat = 0
	dealer_traction = 0
	dealer_bleed = 0
	dealer_is_locked = false
	next_card_multiplier = 1.0
	
	# 2. Tell the UI to update its basic displays
	dial_changed.emit(dial_value)
	overheat_changed.emit(player_overheat)
	status_changed.emit(dealer_traction, dealer_bleed, dealer_is_locked)
	
	# 3. Initialize deck state and draw opening hand
	initialize_deck()            
	prepare_next_dealer_intent() 
	draw_hand(3)                 

func play_card(card_id: String) -> void:
	if not CardDatabase.CARDS.has(card_id):
		push_error("Card ID not found in database: " + card_id)
		return
		
	var card = CardDatabase.CARDS[card_id]
	print("\n--- PLAYER PLAYED: ", card.name, " ---")
	
	# 1. Roll Base Value + Variance
	var roll: int = card.base_val
	if card.variance > 0:
		roll += randi_range(-card.variance, card.variance)
		
	# 2. Process Multiplier Logic
	var resolved_value = int(roll * next_card_multiplier)
	if next_card_multiplier != 1.0:
		print("Multiplier Applied! Value scaled to: ", resolved_value)
		next_card_multiplier = 1.0 # Reset immediately
	
	# 3. Match Actions
	match card.action:
		"PUSH":
			move_dial(resolved_value)
			
		"RESIST":
			if card.has("stacks"): # Governor Lock mechanic
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
			if dial_value % target_mod == 0:
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
				
		"BLEED":
			dealer_bleed += card.get("stacks", 0)
			status_changed.emit(dealer_traction, dealer_bleed, dealer_is_locked)
			print("Mechanism corroded. Total Bleed stacks on Dealer: ", dealer_bleed)

	# 4. Remove card from active hand array
	discard_card_from_hand(card_id)

	# 5. Apply Cost Effects
	if card.has("cost"):
		var cost_data = card.cost
		if cost_data.type == "OVERHEAT":
			player_overheat += cost_data.amount
			overheat_changed.emit(player_overheat)
			print("System generating heat. Overheat stacks: ", player_overheat)

	# 6. Immediate Post-Card Win Check
	if check_win_condition(): return
	
	# 7. Turn Lifecycle Decision
	if card.get("free_action", false):
		print("Free Action card. Remaining in Player phase.")
		return
		
	end_player_turn()

func move_dial(amount: int) -> void:
	dial_value += amount
	dial_changed.emit(dial_value)
	print("Dial Adjusted: ", dial_value)

func end_player_turn() -> void:
	# Process player Overheat penalties
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
		
	# Process Dramatic Delay
	await get_tree().create_timer(0.8).timeout
	
	execute_dealer_move()

func execute_dealer_move() -> void:
	var move = current_dealer_intent
	var base_roll = move.base_val
	if move.variance > 0:
		base_roll += randi_range(-move.variance, move.variance)
		
	if move.type == DealerAI.MoveType.PULL or move.type == DealerAI.MoveType.HEAVY_PULL:
		# Calculate Defensive Mitigation
		var mitigation = dealer_traction + dealer_bleed
		var final_pull = max(0, base_roll - mitigation)
		print("Dealer pulls for ", base_roll, " (Mitigated by ", mitigation, ") = Actual Pull: -", final_pull)
		move_dial(-final_pull)
		
	elif move.type == DealerAI.MoveType.SABOTAGE:
		player_overheat += 2
		overheat_changed.emit(player_overheat)
		print("Dealer sabotaged player mechanics! +2 Overheat.")

	# End of Round Cleanup & Status Decay
	dealer_traction = 0
	if dealer_bleed > 0:
		dealer_bleed -= 1
	status_changed.emit(dealer_traction, dealer_bleed, dealer_is_locked)
	
	if check_win_condition(): return
	
	start_new_round()

func start_new_round() -> void:
	print("--- STARTING NEW ROUND ---")
	prepare_next_dealer_intent()
	draw_hand(3)

func prepare_next_dealer_intent() -> void:
	current_dealer_intent = DealerAI.select_next_move(dial_value)
	dealer_intent_telegraphed.emit(current_dealer_intent.intent_text)

func check_win_condition() -> bool:
	if dial_value >= 21:
		game_over.emit("PLAYER")
		return true
	elif dial_value <= -21:
		game_over.emit("DEALER")
		return true
	return false

func initialize_deck() -> void:
	deck = STARTING_DECK.duplicate()
	hand.clear()
	discard_pile.clear()
	deck.shuffle()
	print("Deck initialized and shuffled. Total cards: ", deck.size())

func draw_hand(amount: int = 3) -> void:
	# 1. Clear any leftover cards in the hand straight to the discard pile
	for card in hand:
		discard_pile.append(card)
	hand.clear()
	
	# 2. Draw the requested number of cards
	for i in range(amount):
		if deck.is_empty():
			recycle_discard_into_deck()
			
		if not deck.is_empty():
			var drawn_card = deck.pop_back()
			hand.append(drawn_card)
			
	print("Hand drawn: ", hand, " | Remaining Deck: ", deck.size(), " | Discard: ", discard_pile.size())
	
	# Send the updated hand array up to main.gd
	hand_drawn.emit(hand)

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
