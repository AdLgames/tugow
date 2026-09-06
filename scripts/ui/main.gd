extends Control
## The bazaar. Floor in the middle, numbers on top, cards along the bottom.
##
## Everything is sized for a thumb: nothing you have to hit is under 80px,
## and the whole floor is one tap target that resolves to a tile. The counter
## is deliberately the largest thing on screen — it is the hook.

const TOUCH := 84.0
const BAR := 128.0

var world: World
var _view: WorldView
var _stock_panel: StockPanel

var _obol_label: Label
var _obol_tick: Label
var _revenue_label: Label
var _stat_row: HBoxContainer
var _corruption_bar: ProgressBar
var _audit_label: Label
var _corruption_caption: Label
var _log_label: Label
var _hint: Label

var _card_row: HBoxContainer
var _card_buttons: Array[Button] = []
var _action_row: HBoxContainer
var _take_button: Button
var _sweep_button: Button
var _buy_card_button: Button
var _expand_button: Button
var _case_button: Button

var _overlay: Control
var _overlay_title: Label
var _overlay_body: VBoxContainer

## The counter animates toward the real number, because a number that slams
## is a number nobody watches.
var _shown_obols: float = 0.0
var _placing_case: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_start()
	set_process(true)


func _build() -> void:
	var back := ColorRect.new()
	back.color = Palette.NIGHT
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	_view = WorldView.new()
	_view.position = Vector2(0, BAR)
	_view.size = Vector2(1250, 1000 - BAR - BAR * 1.5)
	_view.tile_tapped.connect(_on_tile_tapped)
	add_child(_view)

	# The right gutter is the forecasting panel: you cannot balance an inflow
	# you have to walk the floor to count.
	_stock_panel = StockPanel.new()
	_stock_panel.position = Vector2(1256, BAR + 8)
	_stock_panel.size = Vector2(330, 1000 - BAR - BAR * 1.5 - 16)
	add_child(_stock_panel)

	_build_top_bar()
	_build_bottom_bar()
	_build_overlay()


## The number, and everything that qualifies it.
func _build_top_bar() -> void:
	var bar := ColorRect.new()
	bar.color = Color(0, 0, 0, 0.55)
	bar.size = Vector2(1600, BAR)
	add_child(bar)

	_obol_label = _label("0", 62, Palette.OBOL)
	_obol_label.position = Vector2(28, 16)
	_obol_label.size = Vector2(420, 70)

	_obol_tick = _label("obols", 20, Palette.INK_DIM)
	_obol_tick.position = Vector2(32, 88)
	_obol_tick.size = Vector2(420, 26)

	_revenue_label = _label("", 20, Palette.INK_DIM)
	_revenue_label.position = Vector2(430, 24)
	_revenue_label.size = Vector2(400, 26)

	_stat_row = HBoxContainer.new()
	_stat_row.position = Vector2(430, 56)
	_stat_row.size = Vector2(700, 40)
	_stat_row.add_theme_constant_override("separation", 26)
	add_child(_stat_row)

	# Level 2 only: the two numbers that can end you.
	_corruption_bar = ProgressBar.new()
	_corruption_bar.position = Vector2(1130, 30)
	_corruption_bar.size = Vector2(300, 26)
	_corruption_bar.max_value = Balance.corruption_cap
	_corruption_bar.show_percentage = false
	_corruption_bar.visible = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.55)
	track.border_color = Color(0, 0, 0, 0.7)
	track.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.ROT
	_corruption_bar.add_theme_stylebox_override("background", track)
	_corruption_bar.add_theme_stylebox_override("fill", fill)
	add_child(_corruption_bar)

	var corruption_caption := _label("corruption", 17, Palette.INK_DIM)
	corruption_caption.position = Vector2(1130, 4)
	corruption_caption.size = Vector2(300, 24)
	_corruption_caption = corruption_caption

	_audit_label = _label("", 20, Palette.VOID)
	_audit_label.position = Vector2(1130, 64)
	_audit_label.size = Vector2(440, 30)

	_log_label = _label("", 18, Palette.INK_DIM)
	_log_label.position = Vector2(24, BAR + 14)
	_log_label.size = Vector2(232, 300)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP


## Cards along the bottom, then the things you press.
func _build_bottom_bar() -> void:
	var top := 1000.0 - BAR * 1.5
	var bar := ColorRect.new()
	bar.color = Color(0, 0, 0, 0.55)
	bar.position = Vector2(0, top)
	bar.size = Vector2(1600, BAR * 1.5)
	add_child(bar)

	_hint = _label("", 20, Palette.INK_DIM)
	_hint.position = Vector2(28, top + 6)
	_hint.size = Vector2(1540, 26)

	_card_row = HBoxContainer.new()
	_card_row.position = Vector2(28, top + 36)
	_card_row.size = Vector2(760, TOUCH)
	_card_row.add_theme_constant_override("separation", 12)
	add_child(_card_row)

	_action_row = HBoxContainer.new()
	_action_row.position = Vector2(820, top + 36)
	_action_row.size = Vector2(760, TOUCH)
	_action_row.add_theme_constant_override("separation", 12)
	add_child(_action_row)

	_take_button = _action("Take stock", _on_take)
	_sweep_button = _action("Sweep", _on_sweep)
	_buy_card_button = _action("Thrall", _on_buy_card)
	_case_button = _action("Case", _on_case)
	_expand_button = _action("EXPAND", _on_expand)


func _label(text: String, font_size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	add_child(l)
	return l


func _action(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(TOUCH * 1.7, TOUCH)
	button.add_theme_font_size_override("font_size", 22)
	_style(button, Palette.WOOD_DARK)
	button.pressed.connect(action)
	_action_row.add_child(button)
	return button


func _style(button: Button, fill: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		var tint := fill
		if state == "hover":
			tint = fill.lightened(0.14)
		elif state == "pressed":
			tint = fill.lightened(0.26)
		elif state == "disabled":
			tint = fill.darkened(0.55)
		box.bg_color = tint
		box.border_color = Color(0, 0, 0, 0.6)
		box.set_border_width_all(2)
		box.content_margin_left = 14
		box.content_margin_right = 14
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Palette.INK)
	button.add_theme_color_override("font_disabled_color", Palette.INK_DIM.darkened(0.4))


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.88)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(scrim)
	var column := VBoxContainer.new()
	column.position = Vector2(180, 240)
	column.size = Vector2(1240, 520)
	column.add_theme_constant_override("separation", 22)
	_overlay.add_child(column)
	_overlay_title = Label.new()
	_overlay_title.add_theme_font_size_override("font_size", 52)
	_overlay_title.add_theme_color_override("font_color", Palette.OBOL)
	column.add_child(_overlay_title)
	_overlay_body = VBoxContainer.new()
	_overlay_body.add_theme_constant_override("separation", 16)
	column.add_child(_overlay_body)


# --- Running -----------------------------------------------------------------

func _start() -> void:
	world = World.new()
	world.start(randi())
	world.sold.connect(_on_sold)
	world.expanded.connect(_on_expanded)
	world.audited.connect(_on_audited)
	_view.bind(world)
	_stock_panel.bind(world)
	_shown_obols = float(world.obols)
	_rebuild_cards()
	_show_title()


func _show_title() -> void:
	_clear_overlay("ABYSSAL BAZAAR")
	_overlay_line("You have inherited a shop in a clearing. The trees bleed. The counter is an altar and it was already warm.")
	_overlay_line("Play a thrall card to send someone into the woods. Thirty seconds later they come back with something to sell.")
	_overlay_line("Carry it to a table. Put it out. They will come.")
	_overlay_button("Open the shop", func() -> void:
		_overlay.visible = false)
	_overlay.visible = true


func _process(delta: float) -> void:
	if world == null or _overlay.visible:
		return
	world.tick(delta)
	# The counter chases the number rather than jumping to it.
	_shown_obols = lerpf(_shown_obols, float(world.obols), clampf(delta * 7.0, 0.0, 1.0))
	if absf(_shown_obols - float(world.obols)) < 0.6:
		_shown_obols = float(world.obols)
	_refresh()


func _refresh() -> void:
	_obol_label.text = str(int(round(_shown_obols)))
	_revenue_label.text = "%d taken · %d sold · %d turned away" % [
		world.revenue, world.sales, world.lost_sales]
	_hint.text = _hint_text()
	# The last few lines, newest first, because the shop talks a lot.
	var recent: Array[String] = []
	for i in range(world.log_lines.size() - 1, maxi(-1, world.log_lines.size() - 6), -1):
		recent.append(world.log_lines[i])
	_log_label.text = "\n".join(recent)

	var level_two := world.level >= 2
	_corruption_bar.visible = level_two
	_corruption_caption.visible = level_two
	_corruption_bar.value = world.corruption
	_audit_label.visible = level_two
	if level_two:
		_audit_label.text = "tribute %d · the Void in %ds" % [
			world.tribute_owed, int(ceil(world.audit_in))]

	_take_button.disabled = world.carrying != null or world.shop.backroom.is_empty()
	_take_button.text = "Take stock (%d)" % world.shop.backroom.size()
	_sweep_button.disabled = world.shop.rotted_on_floor() == 0
	_buy_card_button.disabled = not world.can_afford(world.card_cost()) \
		or world.thralls.deck >= Balance.max_deck
	_buy_card_button.text = "Thrall %d" % world.card_cost()
	_case_button.visible = level_two
	_case_button.disabled = not world.can_afford(Balance.case_cost)
	_case_button.text = "Case %d" % Balance.case_cost
	_expand_button.visible = world.level == 1
	_expand_button.disabled = not world.can_expand()
	_expand_button.text = "EXPAND %d" % Balance.expansion_cost
	_refresh_cards()


func _hint_text() -> String:
	if _placing_case:
		return "Tap a table to put the case there."
	if world.carrying != null:
		return "Carrying %s. Tap a table beside you to put it out." \
			% Goods.good_name(world.carrying.id)
	if not world.shop.backroom.is_empty():
		return "%d waiting out the back. Take stock, then walk it to a table." \
			% world.shop.backroom.size()
	if world.thralls.out.is_empty():
		return "Nothing in the woods. Play a thrall."
	return "Tap the floor to walk. Tap a table beside you to put something on it."


## One card per thrall in the deck, showing whether it is in your hand or out.
func _rebuild_cards() -> void:
	for button in _card_buttons:
		button.queue_free()
	_card_buttons.clear()
	for i in world.thralls.deck:
		var button := Button.new()
		button.custom_minimum_size = Vector2(TOUCH * 1.1, TOUCH)
		button.add_theme_font_size_override("font_size", 20)
		_style(button, Palette.STONE.darkened(0.35))
		button.pressed.connect(_on_dispatch)
		_card_row.add_child(button)
		_card_buttons.append(button)


func _refresh_cards() -> void:
	if _card_buttons.size() != world.thralls.deck:
		_rebuild_cards()
	var ready := world.thralls.ready_cards()
	for i in _card_buttons.size():
		var button := _card_buttons[i]
		var in_hand := i < ready
		button.disabled = not in_hand
		button.text = "THRALL" if in_hand else "…"


# --- What the player does ----------------------------------------------------

func _on_tile_tapped(at: Vector2i) -> void:
	if world == null or _overlay.visible:
		return
	if _placing_case:
		if world.buy_case(at):
			_placing_case = false
		return
	# Tapping a table you are standing beside puts down what you are holding.
	if world.carrying != null and world.shop.is_display(at) and world.place_carried(at):
		return
	if world.shop.is_display(at):
		# Walk to the nearest side of it instead.
		world.walk_to(world.shop.approach_to(at))
		return
	world.walk_to(at)


func _on_dispatch() -> void:
	world.dispatch_thrall()


func _on_take() -> void:
	world.take_from_backroom()


func _on_sweep() -> void:
	world.sweep()


func _on_buy_card() -> void:
	if world.buy_card():
		_rebuild_cards()


func _on_case() -> void:
	_placing_case = true


func _on_expand() -> void:
	world.expand()


# --- What the shop does back --------------------------------------------------

func _on_sold(_good: int, _obols: int, at: Vector2) -> void:
	_view.flash_glitch(at)


func _on_expanded(_level: int) -> void:
	_clear_overlay("SUPPLY CHAIN OF THE DAMNED")
	_overlay_line("The wooden walls come down. What goes up is cold and black and does not creak.")
	_overlay_line("The woods will give you Fresh Screams and Pulsing Biomass now. Neither keeps. Anything you overstock will turn on the table, and what turns becomes Corruption, and Corruption eats what every sale is worth.")
	_overlay_line("The Void audits this shop. It expects its tribute in hand and the floor clean. It is not interested in why.")
	_overlay_button("Open the doors", func() -> void:
		_overlay.visible = false)
	_overlay.visible = true


func _on_audited(passed: bool, tribute: int, destroyed: int) -> void:
	_clear_overlay("THE VOID READS THE LEDGER" if passed else "THE AUDIT FAILS")
	if passed:
		_overlay_line("Found adequate. %d paid in tribute." % tribute)
	else:
		_overlay_line("%d obols are unmade. Not spent — unmade." % destroyed)
		_overlay_line("It will be back.")
	_overlay_button("Continue", func() -> void:
		_overlay.visible = false)
	_overlay.visible = true


# --- Overlay -----------------------------------------------------------------

func _clear_overlay(title: String) -> void:
	_overlay_title.text = title
	for child in _overlay_body.get_children():
		_overlay_body.remove_child(child)
		child.queue_free()


func _overlay_line(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1200, 0)
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Palette.INK_DIM)
	_overlay_body.add_child(l)
	return l


func _overlay_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(420, TOUCH)
	button.add_theme_font_size_override("font_size", 26)
	_style(button, Palette.WOOD_DARK)
	button.pressed.connect(action)
	_overlay_body.add_child(button)
	return button
