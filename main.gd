extends Control

@onready var dial_label = $GameBoard/TableZone/TableContent/DialContainer/DialInner/DialLabel
@onready var overheat_label = $GameBoard/PlayerZone/PlayerContent/PlayerStats/OverheatLabel
@onready var intent_label = $GameBoard/DealerZone/DealerContent/DealerInfo/IntentLabel
@onready var status_label = $GameBoard/DealerZone/DealerContent/DealerInfo/StatusLabel
@onready var deck_count_label = $GameBoard/PlayerZone/PlayerContent/PlayerStats/DeckCountLabel
@onready var discard_count_label = $GameBoard/PlayerZone/PlayerContent/PlayerStats/DiscardCountLabel
@onready var dial_bar_fill = $GameBoard/TableZone/TableContent/DialBar/DialBarFill
@onready var dial_bar = $GameBoard/TableZone/TableContent/DialBar
@onready var hp_label = $GameBoard/PlayerZone/PlayerContent/PlayerStats/HPLabel
@onready var gold_label = $GameBoard/PlayerZone/PlayerContent/PlayerStats/GoldLabel
@onready var encounter_label = $GameBoard/DealerZone/DealerContent/DealerInfo/EncounterLabel
@onready var dealer_title = $GameBoard/DealerZone/DealerContent/DealerInfo/DealerTitle
@onready var announcement_label = $GameBoard/TableZone/TableContent/AnnouncementLabel
@onready var dealer_sprite = $GameBoard/TableZone/TableContent/DealerSprite
@onready var turn_banner = $GameBoard/TableZone/TableContent/TurnBanner
@onready var turn_banner_label = $GameBoard/TableZone/TableContent/TurnBanner/TurnBannerLabel
@onready var game_board = $GameBoard

const CARD_UI_SCENE = preload("res://card_ui.tscn")
@onready var hand_container = $GameBoard/PlayerZone/PlayerContent/HandContainer
@onready var end_turn_button = $GameBoard/PlayerZone/PlayerContent/EndTurnButton
@onready var match_end_container = $GameBoard/PlayerZone/PlayerContent/MatchEndContainer
@onready var result_label = $GameBoard/PlayerZone/PlayerContent/MatchEndContainer/ResultLabel
@onready var damage_info_label = $GameBoard/PlayerZone/PlayerContent/MatchEndContainer/DamageInfoLabel
@onready var continue_button = $GameBoard/PlayerZone/PlayerContent/MatchEndContainer/ContinueButton
@onready var restart_run_button = $GameBoard/PlayerZone/PlayerContent/MatchEndContainer/RestartRunButton
@onready var background_art = $BackgroundArt

@onready var reward_overlay = $RewardOverlay
@onready var reward_cards_container = $RewardOverlay/RewardPanel/RewardContent/RewardCardsContainer
@onready var skip_reward_button = $RewardOverlay/RewardPanel/RewardContent/SkipRewardButton

@onready var shop_overlay = $ShopOverlay
@onready var shop_gold_label = $ShopOverlay/ShopPanel/ShopContent/ShopHeader/ShopGoldLabel
@onready var shop_cards_container = $ShopOverlay/ShopPanel/ShopContent/ShopCardsContainer
@onready var leave_shop_button = $ShopOverlay/ShopPanel/ShopContent/LeaveShopButton

@onready var main_menu_overlay = $MainMenuOverlay
@onready var start_run_button = $MainMenuOverlay/MenuContent/StartRunButton
@onready var card_collection_button = $MainMenuOverlay/MenuContent/CardCollectionButton
@onready var best_run_label = $MainMenuOverlay/MenuContent/BestRunLabel

@onready var card_collection_overlay = $CardCollectionOverlay
@onready var common_cards_container = $CardCollectionOverlay/CollectionContent/CommonSection/CommonCards
@onready var uncommon_cards_container = $CardCollectionOverlay/CollectionContent/UncommonSection/UncommonCards
@onready var rare_cards_container = $CardCollectionOverlay/CollectionContent/RareSection/RareCards
@onready var collection_tier_label = $CardCollectionOverlay/CollectionContent/CollectionHeader/CollectionTierLabel
@onready var collection_back_button = $CardCollectionOverlay/CollectionContent/BackButton

const BG_ART_PATH = "res://Assets/TavernAssets/1781874905946.png"

var last_winner: String = ""
var announce_tween: Tween
var banner_tween: Tween
var best_encounter: int = 0

func _ready() -> void:
	GameManager.dial_changed.connect(_on_dial_changed)
	GameManager.overheat_changed.connect(_on_overheat_changed)
	GameManager.status_changed.connect(_on_status_changed)
	GameManager.dealer_intent_telegraphed.connect(_on_intent_telegraphed)
	GameManager.hand_drawn.connect(_on_hand_drawn)
	GameManager.match_ended.connect(_on_match_ended)
	GameManager.deck_counts_changed.connect(_on_deck_counts_changed)
	GameManager.hp_changed.connect(_on_hp_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.encounter_started.connect(_on_encounter_started)
	GameManager.reward_offered.connect(_on_reward_offered)
	GameManager.shop_opened.connect(_on_shop_opened)
	GameManager.run_over.connect(_on_run_over)
	GameManager.action_announced.connect(_on_action_announced)
	GameManager.dealer_anim_requested.connect(_on_dealer_anim_requested)
	GameManager.dealer_changed.connect(_on_dealer_changed)
	GameManager.turn_phase_changed.connect(_on_turn_phase_changed)
	continue_button.pressed.connect(_on_continue_pressed)
	restart_run_button.pressed.connect(_on_restart_run_pressed)
	skip_reward_button.pressed.connect(_on_skip_reward_pressed)
	leave_shop_button.pressed.connect(_on_leave_shop_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	start_run_button.pressed.connect(_on_start_run_pressed)
	card_collection_button.pressed.connect(_on_card_collection_pressed)
	collection_back_button.pressed.connect(_on_collection_back_pressed)
	_load_art_assets()
	_show_main_menu()

func _load_art_assets() -> void:
	if ResourceLoader.exists(BG_ART_PATH):
		background_art.texture = load(BG_ART_PATH)

# --- MAIN MENU ---

func _show_main_menu() -> void:
	game_board.visible = false
	reward_overlay.visible = false
	shop_overlay.visible = false
	card_collection_overlay.visible = false
	main_menu_overlay.visible = true
	if best_encounter > 0:
		best_run_label.text = "Best run: Encounter %d" % best_encounter
	else:
		best_run_label.text = ""

func _on_start_run_pressed() -> void:
	main_menu_overlay.visible = false
	game_board.visible = true
	GameManager.start_run()

func _on_card_collection_pressed() -> void:
	main_menu_overlay.visible = false
	card_collection_overlay.visible = true
	_populate_card_collection()

func _on_collection_back_pressed() -> void:
	card_collection_overlay.visible = false
	_show_main_menu()

func _populate_card_collection() -> void:
	for container in [common_cards_container, uncommon_cards_container, rare_cards_container]:
		for child in container.get_children():
			child.queue_free()

	var tier_text_parts: Array[String] = []
	var unlocked_rarities = GameManager.get_unlocked_rarities()

	for card_id in CardDatabase.CARDS:
		var card_data = CardDatabase.CARDS[card_id]
		var rarity = card_data.get("rarity", "COMMON")
		var is_unlocked = rarity in unlocked_rarities

		var card_instance = CARD_UI_SCENE.instantiate()

		match rarity:
			"COMMON":
				common_cards_container.add_child(card_instance)
			"UNCOMMON":
				uncommon_cards_container.add_child(card_instance)
			"RARE":
				rare_cards_container.add_child(card_instance)

		if card_instance.has_method("populate_card"):
			card_instance.populate_card(card_id)

		if not is_unlocked:
			card_instance.modulate = Color(0.3, 0.3, 0.3, 0.6)

	if "RARE" in unlocked_rarities:
		tier_text_parts.append("All tiers unlocked")
	elif "UNCOMMON" in unlocked_rarities:
		tier_text_parts.append("RARE unlocks at encounter 7")
	else:
		tier_text_parts.append("UNCOMMON unlocks at encounter 4")
	collection_tier_label.text = " | ".join(tier_text_parts)

# --- GAME SIGNALS ---

func _on_action_announced(text: String) -> void:
	announcement_label.text = text
	announcement_label.modulate.a = 1.0
	if announce_tween and announce_tween.is_running():
		announce_tween.kill()
	announce_tween = create_tween()
	announce_tween.tween_interval(2.0)
	announce_tween.tween_property(announcement_label, "modulate:a", 0.0, 0.5)

func _on_turn_phase_changed(is_player_turn: bool) -> void:
	end_turn_button.visible = is_player_turn
	_show_turn_banner(is_player_turn)

func _show_turn_banner(is_player_turn: bool) -> void:
	if is_player_turn:
		turn_banner_label.text = "YOUR TURN"
		turn_banner_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1))
	else:
		turn_banner_label.text = "DEALER'S TURN"
		turn_banner_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3, 1))
	turn_banner.visible = true
	turn_banner.modulate.a = 1.0
	if banner_tween and banner_tween.is_running():
		banner_tween.kill()
	banner_tween = create_tween()
	banner_tween.tween_interval(1.5)
	banner_tween.tween_property(turn_banner, "modulate:a", 0.0, 0.4)
	banner_tween.tween_callback(func(): turn_banner.visible = false)

func _on_end_turn_pressed() -> void:
	GameManager.manual_end_turn()

func _on_dealer_changed(dealer_data: Dictionary) -> void:
	dealer_title.text = dealer_data.name.to_upper()
	if dealer_sprite.has_method("load_dealer"):
		dealer_sprite.load_dealer(dealer_data)

func _on_dealer_anim_requested(anim_name: String) -> void:
	if dealer_sprite.has_method("play_oneshot") and anim_name != "IDLE":
		dealer_sprite.play_oneshot(anim_name)
	elif dealer_sprite.has_method("set_animation"):
		dealer_sprite.set_animation(anim_name)

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

func _on_hp_changed(current_hp: int, p_max_hp: int) -> void:
	hp_label.text = "HP: %d/%d" % [current_hp, p_max_hp]
	var ratio = float(current_hp) / float(p_max_hp)
	if ratio <= 0.3:
		hp_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
	elif ratio <= 0.6:
		hp_label.add_theme_color_override("font_color", Color(1, 0.7, 0.3, 1))
	else:
		hp_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 1))

func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Gold: %d" % amount

func _on_encounter_started(encounter_num: int) -> void:
	encounter_label.text = "Encounter %d" % encounter_num
	match_end_container.visible = false
	reward_overlay.visible = false
	shop_overlay.visible = false
	hand_container.visible = true

func _on_match_ended(winner: String, damage_taken: int) -> void:
	last_winner = winner
	hand_container.visible = false
	match_end_container.visible = true

	if winner == "PLAYER":
		var gold_earned = 25 + GameManager.encounter_number * 10
		result_label.text = "VICTORY!"
		result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 1))
		var info_parts: Array[String] = []
		if damage_taken > 0:
			info_parts.append("Overheat burned %d HP" % damage_taken)
		info_parts.append("+%d Gold" % gold_earned)
		damage_info_label.text = " | ".join(info_parts)
		continue_button.text = "Choose Reward"
		continue_button.visible = true
		restart_run_button.visible = false
	else:
		result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1))
		damage_info_label.text = "Took %d damage" % damage_taken
		if GameManager.player_hp <= 0:
			result_label.text = "RUN OVER"
			damage_info_label.text = "Reached encounter %d" % GameManager.encounter_number
			continue_button.visible = false
			restart_run_button.visible = true
		else:
			result_label.text = "DEFEAT!"
			continue_button.text = "Continue"
			continue_button.visible = true
			restart_run_button.visible = false

func _on_continue_pressed() -> void:
	match_end_container.visible = false
	if last_winner == "PLAYER":
		GameManager.offer_reward()
	else:
		GameManager.continue_after_loss()

func _on_restart_run_pressed() -> void:
	match_end_container.visible = false
	_show_main_menu()

# --- REWARD SCREEN ---

func _on_reward_offered(card_choices: Array) -> void:
	reward_overlay.visible = true
	for child in reward_cards_container.get_children():
		child.queue_free()

	for card_id in card_choices:
		var card_instance = CARD_UI_SCENE.instantiate()
		reward_cards_container.add_child(card_instance)

		if card_instance.has_method("populate_card"):
			card_instance.populate_card(card_id)

		if card_instance.has_signal("card_clicked"):
			card_instance.card_clicked.connect(_on_reward_card_clicked)

func _on_reward_card_clicked(card_id: String) -> void:
	reward_overlay.visible = false
	GameManager.select_reward(card_id)

func _on_skip_reward_pressed() -> void:
	reward_overlay.visible = false
	GameManager.skip_reward()

# --- SHOP SCREEN ---

func _on_shop_opened(shop_items: Array) -> void:
	shop_overlay.visible = true
	shop_gold_label.text = "Gold: %d" % GameManager.gold
	_populate_shop(shop_items)

func _populate_shop(shop_items: Array) -> void:
	for child in shop_cards_container.get_children():
		child.queue_free()

	for item in shop_items:
		var card_id: String = item.card_id
		var price: int = item.price
		var can_afford = GameManager.gold >= price

		var wrapper = VBoxContainer.new()
		wrapper.add_theme_constant_override("separation", 4)

		var card_instance = CARD_UI_SCENE.instantiate()
		wrapper.add_child(card_instance)

		if card_instance.has_method("populate_card"):
			card_instance.populate_card(card_id)

		if can_afford and card_instance.has_signal("card_clicked"):
			var bound_price = price
			card_instance.card_clicked.connect(func(_cid): _on_shop_card_bought(card_id, bound_price))
		else:
			card_instance.modulate.a = 0.4

		var price_label = Label.new()
		price_label.text = "%d gold" % price
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 12)
		if can_afford:
			price_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4, 1))
		else:
			price_label.add_theme_color_override("font_color", Color(0.5, 0.4, 0.3, 1))

		var type_tag = CardDatabase.CARDS[card_id].get("type", "")
		if type_tag == "MAGIC":
			var magic_label = Label.new()
			magic_label.text = "MAGIC"
			magic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			magic_label.add_theme_font_size_override("font_size", 10)
			magic_label.add_theme_color_override("font_color", Color(0.6, 0.4, 1.0, 1))
			wrapper.add_child(magic_label)

		wrapper.add_child(price_label)
		shop_cards_container.add_child(wrapper)

func _on_shop_card_bought(card_id: String, price: int) -> void:
	GameManager.buy_card(card_id, price)
	shop_gold_label.text = "Gold: %d" % GameManager.gold
	GameManager.open_shop()

func _on_leave_shop_pressed() -> void:
	shop_overlay.visible = false
	GameManager.leave_shop()

func _on_run_over(final_encounter: int) -> void:
	if final_encounter > best_encounter:
		best_encounter = final_encounter
	result_label.text = "RUN OVER"
	damage_info_label.text = "Reached encounter %d" % final_encounter
	continue_button.visible = false
	restart_run_button.visible = true
