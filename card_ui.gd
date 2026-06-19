extends PanelContainer

signal card_clicked(card_id: String)

var stored_card_id: String = ""
var base_scale: Vector2 = Vector2.ONE
var is_pressed: bool = false

const RARITY_COLORS = {
	"COMMON": Color(0.45, 0.3, 0.12, 1),
	"UNCOMMON": Color(0.3, 0.6, 0.3, 1),
	"RARE": Color(0.7, 0.5, 0.1, 1),
}

func populate_card(card_id: String) -> void:
	stored_card_id = card_id
	var card_data = CardDatabase.CARDS[card_id]

	$CardLayout/NameLabel.text = card_data.name
	$CardLayout/DescriptionLabel.text = card_data.description

	if card_data.has("art"):
		$CardLayout/CardArt.texture = load(card_data.art)

	var rarity = card_data.get("rarity", "COMMON")
	_apply_rarity_style(rarity)

func _apply_rarity_style(rarity: String) -> void:
	var style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	var border_color = RARITY_COLORS.get(rarity, RARITY_COLORS["COMMON"])
	style.border_color = border_color
	if rarity == "RARE":
		style.border_width_top = 3
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	elif rarity == "UNCOMMON":
		style.border_width_top = 3
	add_theme_stylebox_override("panel", style)

	var name_label = $CardLayout/NameLabel
	if rarity == "RARE":
		name_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	elif rarity == "UNCOMMON":
		name_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_anim()
			else:
				_release_anim()
				if is_pressed:
					card_clicked.emit(stored_card_id)
			is_pressed = event.pressed

func _press_anim() -> void:
	var tw = create_tween().set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector2(0.92, 0.92), 0.08)

func _release_anim() -> void:
	var tw = create_tween().set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15)
