extends Control

@onready var dial_label = $GameBoard/TableZone/TableContent/DialContainer/DialInner/DialLabel
@onready var overheat_label = $GameBoard/PlayerZone/PlayerContent/PlayerStats/OverheatLabel
@onready var intent_label = $GameBoard/DealerZone/DealerContent/DealerInfo/IntentLabel
@onready var status_label = $GameBoard/DealerZone/DealerContent/DealerInfo/StatusLabel
@onready var deck_count_label = $GameBoard/PlayerZone/PlayerContent/PlayerStats/DeckCountLabel
@onready var discard_count_label = $GameBoard/PlayerZone/PlayerContent/PlayerStats/DiscardCountLabel
@onready var dial_bar_fill = $GameBoard/TableZone/TableContent/DialBar/DialBarFill
@onready var dial_bar = $GameBoard/TableZone/TableContent/DialBar

const CARD_UI_SCENE = preload("res://card_ui.tscn")
@onready var hand_container = $GameBoard/PlayerZone/PlayerContent/HandContainer
@onready var game_over_container = $GameBoard/PlayerZone/PlayerContent/GameOverContainer
@onready var result_label = $GameBoard/PlayerZone/PlayerContent/GameOverContainer/ResultLabel
@onready var restart_button = $GameBoard/PlayerZone/PlayerContent/GameOverContainer/RestartButton
@onready var background_art = $BackgroundArt
@onready var dealer_portrait = $GameBoard/DealerZone/DealerContent/DealerPortrait

const DEALER_ART_PATH = "res://Assets/TavernAssets/Flying Demon 2D Pixel Art/Sprites/without_outline/IDLE.png"
const BG_ART_PATH = "res://Assets/TavernAssets/Tables_props/table_0.png"

func _ready() -> void:
	GameManager.dial_changed.connect(_on_dial_changed)
	GameManager.overheat_changed.connect(_on_overheat_changed)
	GameManager.status_changed.connect(_on_status_changed)
	GameManager.dealer_intent_telegraphed.connect(_on_intent_telegraphed)
	GameManager.hand_drawn.connect(_on_hand_drawn)
	GameManager.game_over.connect(_on_game_over)
	GameManager.deck_counts_changed.connect(_on_deck_counts_changed)
	restart_button.pressed.connect(_on_restart_pressed)
	_load_art_assets()
	GameManager.start_match()

func _load_art_assets() -> void:
	if ResourceLoader.exists(DEALER_ART_PATH):
		dealer_portrait.texture = load(DEALER_ART_PATH)
	if ResourceLoader.exists(BG_ART_PATH):
		background_art.texture = load(BG_ART_PATH)

func _on_card_ui_clicked(card_id: String) -> void:
	GameManager.play_card(card_id)

func _on_dial_changed(new_value: int) -> void:
	dial_label.text = str(new_value)
	_update_dial_color(new_value)
	_update_dial_bar(new_value)

func _update_dial_color(value: int) -> void:
	if value >= 15:
		dial_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 1))
	elif value >= 10:
		dial_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.5, 1))
	elif value <= -15:
		dial_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1))
	elif value <= -10:
		dial_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3, 1))
	else:
		dial_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6, 1))

func _update_dial_bar(value: int) -> void:
	var normalized = clampf((value + 21.0) / 42.0, 0.0, 1.0)
	var bar_width = dial_bar.size.x * normalized
	dial_bar_fill.custom_minimum_size.x = bar_width
	dial_bar_fill.size.x = bar_width
	if value > 0:
		dial_bar_fill.color = Color(0.4, 0.9, 0.3, 0.8)
	elif value < 0:
		dial_bar_fill.color = Color(1.0, 0.4, 0.2, 0.8)
	else:
		dial_bar_fill.color = Color(1, 0.85, 0.3, 0.8)

func _on_overheat_changed(new_value: int) -> void:
	overheat_label.text = "Overheat: " + str(new_value)
	if new_value >= 4:
		overheat_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
	elif new_value >= 2:
		overheat_label.add_theme_color_override("font_color", Color(1, 0.5, 0.3, 1))
	else:
		overheat_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.4, 1))

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

func _on_deck_counts_changed(deck_size: int, discard_size: int) -> void:
	deck_count_label.text = "Deck: %d" % deck_size
	discard_count_label.text = "Discard: %d" % discard_size

func _on_game_over(winner: String) -> void:
	hand_container.visible = false
	game_over_container.visible = true
	if winner == "PLAYER":
		result_label.text = "VICTORY!"
		result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 1))
	else:
		result_label.text = "DEFEAT!"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1))

func _on_restart_pressed() -> void:
	hand_container.visible = true
	game_over_container.visible = false
	GameManager.start_match()
