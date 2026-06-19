extends Node

@onready var dial_label = $UI_Layout/DialLabel
@onready var overheat_label = $UI_Layout/OverheatLabel
@onready var intent_label = $UI_Layout/IntentLabel
@onready var status_label = $UI_Layout/StatusLabel

const CARD_UI_SCENE = preload("res://card_ui.tscn")
@onready var hand_container = $UI_Layout/HandContainer

func _ready() -> void:
	# Connect UI to GameManager events
	GameManager.dial_changed.connect(_on_dial_changed)
	GameManager.overheat_changed.connect(_on_overheat_changed)
	GameManager.status_changed.connect(_on_status_changed)
	GameManager.dealer_intent_telegraphed.connect(_on_intent_telegraphed)
	GameManager.hand_drawn.connect(_on_hand_drawn) # Fixed name alignment
	GameManager.game_over.connect(_on_game_over)
	GameManager.start_match() 

# --- USER INPUT ROUTING ---
func _on_card_ui_clicked(card_id: String) -> void:
	# Tell the engine what card the player chose. The engine does all the heavy math.
	GameManager.play_card(card_id)

# --- REACTION CALLBACKS (Updating Display Nodes) ---
func _on_dial_changed(new_value: int) -> void:
	dial_label.text = "Dial Value: " + str(new_value)

func _on_overheat_changed(new_value: int) -> void:
	overheat_label.text = "Player Overheat: " + str(new_value)

func _on_intent_telegraphed(intent_text: String) -> void:
	intent_label.text = "Dealer Intent: " + intent_text

func _on_status_changed(traction: int, bleed: int, is_locked: bool) -> void:
	status_label.text = "Traction: %d | Bleed: %d | Locked: %s" % [traction, bleed, str(is_locked)]

# Fixed name to match the connection target, and added the fresh_cards parameter
func _on_hand_drawn(fresh_cards: Array) -> void:
	print("UI Action: Drawing fresh cards... ", fresh_cards)
	
	# 1. Clear out any old visual card nodes left over from the last round
	for child in hand_container.get_children():
		child.queue_free()
		
	# 2. Dynamically spawn a brand-new UI node for each card dealt by the backend
	for card_id in fresh_cards:
		var card_instance = CARD_UI_SCENE.instantiate()
		hand_container.add_child(card_instance)
		
		# Pass the data payload down to the card node so it can display its text
		if card_instance.has_method("populate_card"):
			card_instance.populate_card(card_id)
			
		# Connect the card's visual click action back to our routing function
		if card_instance.has_signal("card_clicked"):
			card_instance.card_clicked.connect(_on_card_ui_clicked)


func _on_game_over(winner: String) -> void:
	for child in hand_container.get_children():
		child.queue_free()

	var label = Label.new()
	label.text = "VICTORY!" if winner == "PLAYER" else "DEFEAT!"
	hand_container.add_child(label)

	var restart_btn = Button.new()
	restart_btn.text = "Play Again"
	restart_btn.pressed.connect(_on_restart_pressed)
	hand_container.add_child(restart_btn)

func _on_restart_pressed() -> void:
	GameManager.start_match()
