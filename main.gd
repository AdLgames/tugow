extends Control

@onready var dial_label = $GameBoard/TableZone/TableContent/DialLabel
@onready var overheat_label = $GameBoard/PlayerZone/PlayerContent/PlayerStats/OverheatLabel
@onready var intent_label = $GameBoard/DealerZone/DealerContent/DealerInfo/IntentLabel
@onready var status_label = $GameBoard/DealerZone/DealerContent/DealerInfo/StatusLabel

const CARD_UI_SCENE = preload("res://card_ui.tscn")
@onready var hand_container = $GameBoard/PlayerZone/PlayerContent/HandContainer
@onready var game_over_container = $GameBoard/PlayerZone/PlayerContent/GameOverContainer
@onready var result_label = $GameBoard/PlayerZone/PlayerContent/GameOverContainer/ResultLabel
@onready var restart_button = $GameBoard/PlayerZone/PlayerContent/GameOverContainer/RestartButton

func _ready() -> void:
	GameManager.dial_changed.connect(_on_dial_changed)
	GameManager.overheat_changed.connect(_on_overheat_changed)
	GameManager.status_changed.connect(_on_status_changed)
	GameManager.dealer_intent_telegraphed.connect(_on_intent_telegraphed)
	GameManager.hand_drawn.connect(_on_hand_drawn)
	GameManager.game_over.connect(_on_game_over)
	restart_button.pressed.connect(_on_restart_pressed)
	GameManager.start_match()

func _on_card_ui_clicked(card_id: String) -> void:
	GameManager.play_card(card_id)

func _on_dial_changed(new_value: int) -> void:
	dial_label.text = str(new_value)

func _on_overheat_changed(new_value: int) -> void:
	overheat_label.text = "Overheat: " + str(new_value)

func _on_intent_telegraphed(intent_text: String) -> void:
	intent_label.text = intent_text

func _on_status_changed(traction: int, bleed: int, is_locked: bool) -> void:
	var parts: Array[String] = []
	if traction > 0:
		parts.append("Traction: %d" % traction)
	if bleed > 0:
		parts.append("Bleed: %d" % bleed)
	if is_locked:
		parts.append("LOCKED")
	status_label.text = " | ".join(parts) if parts.size() > 0 else ""

func _on_hand_drawn(fresh_cards: Array) -> void:
	for child in hand_container.get_children():
		child.queue_free()

	for card_id in fresh_cards:
		var card_instance = CARD_UI_SCENE.instantiate()
		hand_container.add_child(card_instance)

		if card_instance.has_method("populate_card"):
			card_instance.populate_card(card_id)

		if card_instance.has_signal("card_clicked"):
			card_instance.card_clicked.connect(_on_card_ui_clicked)

func _on_game_over(winner: String) -> void:
	hand_container.visible = false
	game_over_container.visible = true
	result_label.text = "VICTORY!" if winner == "PLAYER" else "DEFEAT!"

func _on_restart_pressed() -> void:
	hand_container.visible = true
	game_over_container.visible = false
	GameManager.start_match()
