extends PanelContainer

signal card_clicked(card_id: String)

var stored_card_id: String = ""

func populate_card(card_id: String) -> void:
	stored_card_id = card_id
	var card_data = CardDatabase.CARDS[card_id]

	$CardLayout/NameLabel.text = card_data.name
	$CardLayout/DescriptionLabel.text = card_data.description

	if card_data.has("art"):
		$CardLayout/CardArt.texture = load(card_data.art)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			card_clicked.emit(stored_card_id)
