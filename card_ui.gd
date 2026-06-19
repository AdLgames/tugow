extends Control

signal card_clicked(card_id: String)

var stored_card_id: String = ""

func populate_card(card_id: String) -> void:
	stored_card_id = card_id
	var card_data = CardDatabase.CARDS[card_id]

	$NameLabel.text = card_data.name
	$DescriptionLabel.text = card_data.description

	if card_data.has("art"):
		$CardArt.texture = load(card_data.art)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("Visual Card Clicked: ", stored_card_id)
			card_clicked.emit(stored_card_id)
