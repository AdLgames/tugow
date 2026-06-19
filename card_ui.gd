extends Control

signal card_clicked(card_id: String)

var stored_card_id: String = ""

@onready var card_art = $CardArt
@onready var name_label = $NameLabel
@onready var description_label = $DescriptionLabel

func populate_card(card_id: String) -> void:
	stored_card_id = card_id
	var card_data = CardDatabase.CARDS[card_id]

	name_label.text = card_data.name
	description_label.text = card_data.description

	if card_data.has("art"):
		card_art.texture = load(card_data.art)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("Visual Card Clicked: ", stored_card_id)
			card_clicked.emit(stored_card_id)
