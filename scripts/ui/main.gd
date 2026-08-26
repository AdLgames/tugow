extends Control
## The saloon. A standing player looks down at a worn oval table; the man
## across it writes on the same Ledger. Everything the player reads sits
## either on the table (the Ledger, the dice) or on the lip in front of it.
##
## Built from docs/design-system/ui_kits/thirteen_boxes/table_scene.html and
## its build brief; the layer order, palette, camera and naming come from
## there. Game state is real — the dice sit where the throw resolver put them.

const STAGE := Vector2(1920, 1080)

var game: Game

var _scene: SaloonView
var _dice_layer: Control
var _die_views: Array[DieView] = []
var _ledger_well: Control
var _ledger: LedgerView
var _tray: DiceTray
var _stage: DiceStage
var _placard: Control
var _night_label: Label
var _score_label: Label
var _meter: ProgressBar
var _owed_label: Label
var _draws_label: Label
var _hint_label: Label
var _throw_buttons: Array[Button] = []
var _roll_button: Button
var _foe_panel: PanelContainer
var _adversary_panel: VBoxContainer
var _charm_label: Label
var _log_view: RichTextLabel
var _scrim: ColorRect
var _overlay: PanelContainer
var _overlay_paper := false
var _overlay_title: Label
var _overlay_body: VBoxContainer
var _debug_panel: DebugPanel

var _pending_offer: Dictionary = {}
var _pending_sacrifices: Array[int] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	_build()
	if int(RunState.meta.get("runs", 0)) == 0:
		_show_intro(0)
	else:
		_show_title()


## Labels belong to bodies that move. Repositioning them only when the game
## state changes leaves them lagging behind the dice — and during a throw the
## dice are moving the whole time.
func _process(_delta: float) -> void:
	if _stage == null or game == null:
		return
	for view in _die_views:
		if view.die == null:
			continue
		var at := _stage.screen_position_of(view.die.id)
		if at.x <= -900.0:
			view.visible = false
			continue
		view.visible = true
		view.position = at - Vector2(DieView.SIZE, DieView.SIZE) * 0.5 * view.scale.x


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		if _debug_panel != null:
			_debug_panel.visible = not _debug_panel.visible


# --- Construction ------------------------------------------------------------

func _build() -> void:
	_scene = SaloonView.new()
	add_child(_scene)

	_dice_layer = Control.new()
	_dice_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dice_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dice_layer)

	# The well the sheet slides in. It clips at the bottom bar, so a tucked
	# Ledger is cut off by the bar rather than drawn across it.
	_ledger_well = Control.new()
	_ledger_well.position = Vector2(74, 300)
	_ledger_well.size = Vector2(LedgerView.WIDTH + 24, 590)
	_ledger_well.clip_contents = true
	_ledger_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ledger_well)

	_ledger = LedgerView.new()
	# Fully out it sits on the table; closed, a quarter of it shows above the
	# bar. It starts closed — the dice are what you are looking at.
	_ledger.open_position = Vector2(0, _ledger_well.size.y - _ledger.size.y)
	_ledger.closed_position = Vector2(0, _ledger_well.size.y - _ledger.size.y * LedgerView.PEEK)
	_ledger.set_drawer(false, false)
	_ledger.line_pressed.connect(_on_box_pressed)
	_ledger.line_hovered.connect(_on_line_hovered)
	_ledger.drawer_toggled.connect(_on_drawer_toggled)
	_ledger_well.add_child(_ledger)

	_tray = DiceTray.new()
	# The tray has a wooden surround now, so it grows upward from the same
	# bottom edge rather than pushing into the lip strip.
	_tray.position = Vector2(752, 816)
	_tray.size = Vector2(1150, DiceTray.ENTRY.y + DiceTray.PAD * 2.0)
	add_child(_tray)

	# The physical dice, rendered into the clear felt. The 2D die views become
	# labels and hit areas sitting over them.
	if Balance.use_physics_dice:
		_stage = DiceStage.new()
		# Only the dice are rendered — the physical table has collision but no
		# mesh, so the painted felt shows through. The stage therefore needs
		# to cover the band of table that is actually visible, clipped to
		# what the interface leaves free.
		# Clear of the Ledger on the left, so no throw can put a die behind
		# the sheet: the stage cannot render outside its own rectangle.
		var clear_left := _ledger.position.x + _ledger.size.x + 40.0
		var felt := _scene.felt_bounds().intersection(
			Rect2(clear_left, 470, 1920 - clear_left - 40.0, 406))
		_stage.position = felt.position
		_stage.size = felt.size
		_dice_layer.add_child(_stage)
		_dice_layer.move_child(_stage, 0)

	_build_placard()
	_build_corners()
	_build_lip_strip()
	_build_overlay()

	# Lab tooling from the mock: layer toggles, camera pitch, lamp sliders.
	# Debug builds only — a player never sees it.
	if OS.is_debug_build():
		_debug_panel = DebugPanel.new(_scene)
		_debug_panel.visible = false
		add_child(_debug_panel)


## The Adversary announces its target before it throws. That declaration is a
## physical chit on the felt, not a line of text in a corner.
func _build_placard() -> void:
	_placard = Control.new()
	_placard.size = Vector2(320, 96)
	_placard.position = Vector2(1290, 470)
	_placard.rotation = deg_to_rad(3.4)
	_placard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placard.draw.connect(_draw_placard)
	_placard.visible = false
	add_child(_placard)


func _draw_placard() -> void:
	var c := _placard
	var rect := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(rect, ThemeColors.PAPER_MID, true)
	c.draw_rect(rect, Color(ThemeColors.ADVERSARY, 0.55), false, 2.0)
	var font := ThemeDB.fallback_font
	if game == null or game.adversary == null:
		return
	c.draw_string(font, Vector2(16, 30), "HE CALLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.10, 0.08, 0.13, 0.65))
	var box := game.adversary.declared_box
	c.draw_string(font, Vector2(16, 62), Scoring.box_name(box).to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ThemeColors.HIS_INK)


func _build_corners() -> void:
	# Top right: who is across the table, and what he has taken.
	var foe_panel := PanelContainer.new()
	foe_panel.position = Vector2(1560, 24)
	foe_panel.size = Vector2(336, 200)
	_foe_panel = foe_panel
	foe_panel.add_theme_stylebox_override("panel", ThemeColors.panel_style())
	_adversary_panel = VBoxContainer.new()
	foe_panel.add_child(_adversary_panel)
	add_child(foe_panel)

	# Below it: the running account of the night.
	var log_panel := PanelContainer.new()
	log_panel.position = Vector2(1560, 236)
	log_panel.size = Vector2(336, 300)
	log_panel.add_theme_stylebox_override("panel", ThemeColors.panel_style())
	var log_column := VBoxContainer.new()
	log_panel.add_child(log_column)
	_charm_label = Label.new()
	_charm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_charm_label.add_theme_color_override("font_color", ThemeColors.INK_DIM)
	log_column.add_child(_charm_label)
	_log_view = RichTextLabel.new()
	_log_view.scroll_following = true
	_log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_view.add_theme_color_override("default_color", ThemeColors.INK_DIM)
	log_column.add_child(_log_view)
	add_child(log_panel)


## The lip strip: brand, the night's state, and the draw.
func _build_lip_strip() -> void:
	var strip := HBoxContainer.new()
	strip.position = Vector2(60, 900)
	strip.size = Vector2(1800, 140)
	strip.alignment = BoxContainer.ALIGNMENT_BEGIN
	strip.add_theme_constant_override("separation", 28)
	add_child(strip)

	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 16)
	var mark := TextureRect.new()
	if ResourceLoader.exists("res://icon.svg"):
		mark.texture = load("res://icon.svg")
	mark.custom_minimum_size = Vector2(34, 34)
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand.add_child(mark)
	var title := Label.new()
	title.text = "THIRTEEN BOXES"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", ThemeColors.INK)
	brand.add_child(title)
	strip.add_child(brand)

	_night_label = _stat(strip, Lore.week_and_night(1))
	_score_label = _stat(strip, "0 / 0")
	_meter = ProgressBar.new()
	_meter.custom_minimum_size = Vector2(220, 16)
	_meter.show_percentage = false
	strip.add_child(_meter)
	_owed_label = _stat(strip, Lore.lines_owed(13))
	_draws_label = _stat(strip, "2 draws left")

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(gap)

	for strength in [Throw.Strength.SOFT, Throw.Strength.MEDIUM, Throw.Strength.HARD]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(190, 56)
		button.tooltip_text = Throw.STRENGTH_BLURBS[strength]
		button.add_theme_color_override("font_color", ThemeColors.PENCIL)
		button.add_theme_stylebox_override("normal", _draw_button_style(0.35))
		button.add_theme_stylebox_override("hover", _draw_button_style(1.0))
		button.add_theme_stylebox_override("pressed", _draw_button_style(1.0))
		button.add_theme_stylebox_override("disabled", _draw_button_style(0.0))
		button.pressed.connect(_on_throw_pressed.bind(strength))
		button.mouse_entered.connect(_on_throw_hovered.bind(strength))
		strip.add_child(button)
		_throw_buttons.append(button)
	_roll_button = _throw_buttons[Throw.Strength.MEDIUM]

	_hint_label = Label.new()
	_hint_label.position = Vector2(360, 1040)
	_hint_label.size = Vector2(1200, 34)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_color_override("font_color", ThemeColors.INK_DIM)
	add_child(_hint_label)


## A stub torn from the same block as the Ledger and the dice slips. Paper is
## the player's side of this table; the last dark panels with gold edges were
## the only interface furniture left on it.
func _draw_button_style(weight: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = ThemeColors.PAPER_HI.lerp(ThemeColors.PAPER_LO, 0.35 - weight * 0.3)
	box.border_color = Color(0.10, 0.08, 0.13, 0.10 + weight * 0.35)
	box.set_border_width_all(1)
	box.border_width_bottom = 3
	box.set_corner_radius_all(2)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


func _stat(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", ThemeColors.INK_DIM)
	parent.add_child(label)
	return label


func _build_overlay() -> void:
	_scrim = ColorRect.new()
	_scrim.color = Color(0, 0, 0, 0.6)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.visible = false
	add_child(_scrim)

	_overlay = PanelContainer.new()
	_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_overlay.add_theme_stylebox_override("panel", ThemeColors.panel_style(ThemeColors.INK))
	_overlay.custom_minimum_size = Vector2(660, 0)
	_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_overlay)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_overlay.add_child(column)

	_overlay_title = Label.new()
	_overlay_title.add_theme_font_size_override("font_size", 22)
	_overlay_title.add_theme_color_override("font_color", ThemeColors.INK)
	_overlay_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_overlay_title)

	_overlay_body = VBoxContainer.new()
	_overlay_body.add_theme_constant_override("separation", 6)
	column.add_child(_overlay_body)


func _set_overlay_visible(shown: bool) -> void:
	_overlay.visible = shown
	_scrim.visible = shown


# --- Screens -----------------------------------------------------------------

## The explanation, once, before the first run — and on demand after it.
func _show_intro(page_index: int) -> void:
	var pages := Intro.pages()
	if page_index < 0 or page_index >= pages.size():
		_show_title()
		return
	var page: Intro.Page = pages[page_index]
	_clear_overlay(page.title)
	for line in page.lines:
		_overlay_text(line)
	_overlay_text("%d of %d" % [page_index + 1, pages.size()])
	if page_index + 1 < pages.size():
		_overlay_button("Next", func() -> void: _show_intro(page_index + 1))
	else:
		_overlay_button("Deal me in", _start_run)
	if page_index > 0:
		_overlay_button("Back", func() -> void: _show_intro(page_index - 1))
	_overlay_button("Skip", _show_title)
	_set_overlay_visible(true)


func _show_title() -> void:
	_clear_overlay("THIRTEEN BOXES")
	_overlay_text("A dice roguelike where the ledger is your health bar.")
	_overlay_text("Thirteen lines. Every turn settles one, permanently, for the rest of the run. Clear a night fast and you carry the rest forward.")
	_overlay_text("Staked is staked for the whole night, not the draw.")
	var meta: Dictionary = RunState.meta
	_overlay_text("Runs: %d   Deepest night: %d   Best total: %d"
		% [int(meta["runs"]), int(meta["deepest_floor"]), int(meta["best_total"])])
	_overlay_button("Sit down", _start_run)
	_overlay_button("How this works", func() -> void: _show_intro(0))
	_set_overlay_visible(true)


func _start_run() -> void:
	game = RunState.new_run(0, _stage)
	game.state_changed.connect(_refresh)
	game.log_emitted.connect(_on_log)
	game.run_ended.connect(_on_run_ended)
	game.floor_cleared.connect(_on_floor_cleared)
	game.thrown.connect(_on_thrown)
	game.throw_began.connect(_on_throw_began)
	game.turn_started.connect(_on_turn_started)
	if _stage != null:
		if not _stage.throw_settled.is_connected(_on_stage_settled):
			_stage.throw_settled.connect(_on_stage_settled)
	_ledger.bind(game)
	_scene.pool = game.pool
	_log_view.text = ""
	for line in game.log_lines:
		_on_log(line)
	_set_overlay_visible(false)
	_refresh()


func _on_floor_cleared(_floor_number: int, _reclaimed: Array) -> void:
	if game.phase == Game.Phase.BENCH:
		_show_bench()


## A fresh turn: the felt is cleared and nothing is scoreable until the
## player has thrown.
func _on_turn_started() -> void:
	if _stage != null:
		# Bare felt for a fresh turn — except for dice staked for the night,
		# which stay down on the faces they were sealed on.
		var held := game.staked_dice()
		if held.is_empty():
			_stage.clear_table()
		else:
			_stage.show_held(held)
	_refresh()


func _on_throw_began(_strength: int) -> void:
	_hint_label.text = "The dice are in the air."
	_refresh_throw_buttons()


## The bodies have settled: hand the table back to the rules.
func _on_stage_settled(records: Array) -> void:
	game.apply_physical_throw(records)


func _on_thrown(_result: Throw.Result) -> void:
	_refresh()
	for i in _die_views.size():
		_die_views[i].tumble(i * 0.055)


func _on_run_ended(won: bool, reason: String) -> void:
	_clear_overlay("You walked out." if won else "The night ends.")
	_overlay_text(reason)
	_overlay_text("Run total: %d over %d night%s."
		% [game.card.run_total, game.floor_number, "" if game.floor_number == 1 else "s"])
	var scratched := 0
	for box in game.card.player_boxes():
		if game.card.points[box] == 0:
			scratched += 1
	_overlay_text("The Ledger: %d yours, %d his, %d burned, %d never settled. %d of yours were struck through."
		% [
			game.card.count_state(Scorecard.State.PLAYER),
			game.card.count_state(Scorecard.State.ADVERSARY),
			game.card.count_state(Scorecard.State.BURNED),
			game.card.open_count(),
			scratched,
		])
	var meta: Dictionary = RunState.meta
	_overlay_text("Best total: %d   Deepest night: %d" % [int(meta["best_total"]), int(meta["deepest_floor"])])
	_overlay_button("Again", _start_run)
	_set_overlay_visible(true)


# --- The Assayer's Office ----------------------------------------------------

func _show_bench() -> void:
	_pending_offer = {}
	_pending_sacrifices.clear()
	_clear_overlay(Lore.BENCH.to_upper(), true)
	_overlay_subtitle("OFFICIAL POSTED NOTICE · FRONTIER COURT")
	_overlay_text("%s cleared in %s. The only currency is your Ledger: %s."
		% [Lore.night(game.floor_number), Lore.draws(game.floor_turn),
			Lore.lines_owed(game.card.open_count())])
	if game.pending_carry > 0:
		_overlay_text("You overshot; %d carries into the next night." % game.pending_carry)
	var charm_names: Array[String] = []
	for c in game.charms:
		charm_names.append(c.charm_name)
	if not charm_names.is_empty():
		_overlay_text("Charms: %s" % ", ".join(charm_names))
	_overlay_rule()
	# Every offer costs lines off the Ledger, so each is posted with its price
	# stamped in the margin. An offer you cannot pay for stays on the board.
	for offer in Bench.offers(game):
		var cost := int(offer["cost"])
		var row := NoticeButton.new(String(offer["label"]), String(offer["detail"]),
			"%d %s" % [cost, Lore.BOX.to_upper() if cost == 1 else Lore.BOXES.to_upper()])
		row.affordable = Bench.can_afford(game, cost)
		row.disabled = not row.affordable
		row.pressed.connect(_on_bench_offer.bind(offer))
		_overlay_body.add_child(row)
	_overlay_rule()
	var out := _overlay_button("On to %s" % Lore.night(game.floor_number + 1), _leave_bench)
	out.alignment = HORIZONTAL_ALIGNMENT_CENTER
	out.custom_minimum_size = Vector2(0, 44)
	for state in ["normal", "hover", "pressed"]:
		out.add_theme_stylebox_override(state, _stamped_style(state == "hover"))
	out.add_theme_color_override("font_color", ThemeColors.INK)
	out.add_theme_color_override("font_hover_color", ThemeColors.LOCKED)
	out.add_theme_color_override("font_pressed_color", ThemeColors.LOCKED)
	_set_overlay_visible(true)


func _on_bench_offer(offer: Dictionary) -> void:
	_pending_offer = offer
	_pending_sacrifices.clear()
	_ask_for_sacrifice()


func _ask_for_sacrifice() -> void:
	var cost := int(_pending_offer["cost"])
	if _pending_sacrifices.size() >= cost:
		_ask_for_target()
		return
	var remaining := cost - _pending_sacrifices.size()
	_clear_overlay(String(_pending_offer["label"]), true)
	_overlay_text("Give up %d more %s. This is permanent."
		% [remaining, Lore.BOX if remaining == 1 else Lore.BOXES])
	for box in game.card.open_boxes():
		if _pending_sacrifices.has(box):
			continue
		_overlay_button("%s — %s" % [Scoring.box_name(box), Scoring.box_rule(box)], func() -> void:
			_pending_sacrifices.append(box)
			_ask_for_sacrifice())
	_overlay_button("Never mind", _show_bench)


func _ask_for_target() -> void:
	var target: String = _pending_offer["target"]
	match target:
		"none":
			_apply_bench(-1)
		"die":
			_clear_overlay("Which die?", true)
			for d in game.pool.dice:
				_overlay_button("%s — faces %s" % [d.die_name, str(Array(d.faces))], _apply_bench.bind(d.id))
			_overlay_button("Never mind", _show_bench)
		"bitter_die":
			_clear_overlay("Which bitter die?", true)
			for d in game.pool.dice:
				if d.bitter:
					_overlay_button(d.die_name, _apply_bench.bind(d.id))
			_overlay_button("Never mind", _show_bench)
		"filled_box":
			_clear_overlay("Which line do you hate?", true)
			for box in game.card.player_boxes():
				_overlay_button("%s — %d" % [Scoring.box_name(box), game.card.points[box]], _apply_bench.bind(box))
			_overlay_button("Never mind", _show_bench)


func _apply_bench(target: int) -> void:
	Bench.apply(game, _pending_offer["id"], _pending_sacrifices, target)
	_show_bench()


func _leave_bench() -> void:
	_set_overlay_visible(false)
	game.leave_bench()
	_refresh()


# --- Input -------------------------------------------------------------------

func _on_throw_pressed(strength: int) -> void:
	game.throw(strength)


func _on_throw_hovered(strength: int) -> void:
	if _scene != null:
		_scene.preview_strength = strength
		_scene.queue_redraw()


func _on_die_pressed(die: Die) -> void:
	if game.dice_in_the_air:
		return
	if not game.would_lock_out(die):
		game.lock_die(die)
		return
	_clear_overlay("Stake %s — your last free die?" % die.die_name)
	_overlay_text("Every die on the table would be staked for the rest of the night. There is nothing left to throw: every remaining draw scores exactly %s, and only the line you settle changes."
		% str(game.table_values()))
	_overlay_button("Stake it anyway", func() -> void:
		_set_overlay_visible(false)
		game.lock_die(die)
		_refresh())
	_overlay_button("Back", func() -> void:
		_set_overlay_visible(false)
		_refresh())
	_set_overlay_visible(true)


## A preview that shows only the reward is half the decision.
## With the Ledger tucked away the felt below it is clear, so the dice have
## the run of the table.
func _on_drawer_toggled(_open: bool) -> void:
	if _scene != null:
		_scene.rolling_bounds = _clear_felt()
	_hint_label.text = _hint()


func _on_line_hovered(box: int) -> void:
	if game == null or box < 0 or game.phase != Game.Phase.TURN or not game.card.is_open(box):
		_hint_label.text = _hint()
		return
	var value := game.preview(box)
	if value > 0:
		_hint_label.text = "%d — and %s is gone for the run. %s would remain."\
			% [value, Scoring.box_name(box).to_upper(), Lore.lines_owed(game.card.open_count() - 1)]
	else:
		_hint_label.text = "Nothing — and %s is still gone for the run. %s would remain."\
			% [Scoring.box_name(box).to_upper(), Lore.lines_owed(game.card.open_count() - 1)]


func _on_box_pressed(box: int) -> void:
	if game == null or game.phase != Game.Phase.TURN or not game.card.is_open(box):
		return
	if game.dice_in_the_air or not game.turn_rolled:
		return
	var value := game.preview(box)
	_clear_overlay("%s for %d" % [Scoring.box_name(box), value])
	if value > 0:
		_overlay_text("%s on %s." % [Scoring.box_rule(box), str(game.table_values())])
	else:
		_overlay_text("These dice do not meet %s. Settling it now strikes the line through for nothing — a sacrifice, not a mistake."
			% Scoring.box_name(box))
	if game.adversary != null and box == game.adversary.declared_box:
		_overlay_text("This is the line %s called. Taking it denies him." % game.adversary.display_name)
	_overlay_text("The line is settled for the rest of the run. %s would remain."
		% Lore.lines_owed(game.card.open_count() - 1))
	_overlay_text("%s: %d + %d = %d of %d."
		% [Lore.night(game.floor_number), game.floor_score, value, game.floor_score + value, game.threshold])
	var commit := HoldButton.new("Hold to write it — %s is gone for the run"
		% Scoring.box_name(box).to_upper())
	commit.held.connect(func() -> void:
		_set_overlay_visible(false)
		game.write_box(box)
		_ledger.set_drawer(false)
		_refresh())
	_overlay_body.add_child(commit)
	_overlay_button("Back", func() -> void:
		_set_overlay_visible(false)
		_refresh())
	_set_overlay_visible(true)


# --- Refresh -----------------------------------------------------------------

func _refresh() -> void:
	if game == null:
		return
	_night_label.text = Lore.week_and_night(game.floor_number)
	_score_label.text = "%d / %d" % [game.floor_score, game.threshold]
	if game.floor_carry_in > 0:
		_score_label.text += "  (%d carried)" % game.floor_carry_in
	_meter.max_value = maxf(1.0, float(game.threshold))
	_meter.value = minf(float(game.floor_score), _meter.max_value)
	_owed_label.text = Lore.lines_owed(game.card.open_count())

	_scene.pool = game.pool
	_scene.adversary_present = game.adversary != null
	_tray.bind(game)
	_refresh_dice()
	_ledger.queue_redraw()
	_refresh_adversary()
	_refresh_throw_buttons()

	var charm_names: Array[String] = []
	for c in game.charms:
		charm_names.append(c.charm_name)
	_charm_label.text = "Charms: %s" % ("none yet" if charm_names.is_empty() else ", ".join(charm_names))
	_hint_label.text = _hint()

	_placard.visible = game.adversary != null and game.adversary.declared_box >= 0
	_placard.queue_redraw()


## What is left of the table once the interface has taken its room: right of
## the Ledger, below the man opposite, above the dice tray. Derived from the
## real node rectangles so it cannot drift out of step with them.
func _clear_felt() -> Rect2:
	# Measured against the sheet as it sits now: tucked away it takes only a
	# strip at the bottom, and the dice get the rest.
	var ledger_top := _ledger_well.position.y + _ledger.position.y
	var left := _ledger_well.position.x + _ledger.size.x + 40.0
	if ledger_top > 700.0:
		# Tucked away: the felt below is clear, so the dice get the table.
		left = 760.0
	var top := 540.0
	var bottom := _tray.position.y - 24.0
	var right := 1880.0
	return Rect2(left, top, right - left, bottom - top)


## Dice are laid out by the scene, which keeps them inside the clear felt and
## out of each other's way.
func _refresh_dice() -> void:
	for view in _die_views:
		view.queue_free()
	_die_views.clear()
	_scene.rolling_bounds = _clear_felt()
	# Before the draw the felt is bare, save for dice staked for the night:
	# they are already down, and their faces still count.
	var live: Array = []
	for d in game.pool.table:
		if d.lost:
			continue
		if game.turn_rolled or d.locked:
			live.append(d)
	var physical: bool = _stage != null and game.stage == _stage
	for placement in _scene.place_dice(live):
		var view := DieView.new()
		_dice_layer.add_child(view)
		view.bind(placement["die"])
		var factor: float = placement["scale"]
		view.scale = Vector2(factor, factor)
		view.position = placement["position"] - Vector2(DieView.SIZE, DieView.SIZE) * 0.5 * factor
		view.render_body = not physical
		if physical:
			# The label belongs to a real body. If that body cannot be
			# located on screen the die is gone or out of frame, and a label
			# floating at a made-up position would be worse than none.
			var at := _stage.screen_position_of(int(placement["die"].id))
			if at.x <= -900.0:
				view.visible = false
			else:
				view.position = at - Vector2(DieView.SIZE, DieView.SIZE) * 0.5 * factor
		view.sway_left = _scene.sway_left
		view.sway_right = _scene.sway_right
		view.pressed.connect(_on_die_pressed.bind(placement["die"]))
		_die_views.append(view)


func _refresh_throw_buttons() -> void:
	var frozen := not game.can_throw()
	var throws_left := game.draws_left()
	var free := game.free_dice_on_table()
	for strength in _throw_buttons.size():
		var button := _throw_buttons[strength]
		var reason := ""
		if game.phase != Game.Phase.TURN:
			reason = "not your draw"
		elif frozen:
			# Two different dead ends, and the player needs to know which.
			reason = "every die in the dirt" if _table_is_empty() else "every die staked"
		elif throws_left <= 0:
			reason = "no draws left — settle a line"
		if game.dice_in_the_air:
			reason = "in the air"
		button.disabled = reason != ""
		# The name survives the disabled state; the reason sits under it.
		button.text = "%s\n%s" % [
			Throw.strength_name(strength).to_upper(),
			reason if reason != "" else Throw.STRENGTH_SHORT[strength],
		]
		button.tooltip_text = Throw.STRENGTH_BLURBS[strength]
		# Written on the stub: green ink for the careful throw, pencil for the
		# ordinary one, red for the one that loses dice.
		var tint := ThemeColors.PENCIL
		if reason != "":
			tint = Color(0.10, 0.08, 0.13, 0.35)
		elif strength == Throw.Strength.HARD:
			tint = ThemeColors.SCRATCH_RED
		elif strength == Throw.Strength.SOFT:
			tint = Color("2f5c39")
		button.add_theme_color_override("font_color", tint)
		button.add_theme_color_override("font_disabled_color", tint)

	# With no draws left there is exactly one legal move. Say so, and put the
	# light on the Ledger rather than the table.
	var out_of_draws := throws_left <= 0 or frozen
	_ledger.urgent = out_of_draws and game.phase == Game.Phase.TURN
	if _ledger.urgent and not _ledger.drawer_open:
		# The only legal move is on the sheet, so do not make them find it.
		_ledger.set_drawer(true)
	_scene.dim_table = _ledger.urgent
	_draws_label.text = "%d %s left" % [maxi(0, throws_left), "draw" if throws_left == 1 else "draws"]
	if not game.turn_rolled and game.phase == Game.Phase.TURN:
		_draws_label.text = "your draw"
	_draws_label.add_theme_color_override("font_color",
		ThemeColors.DECLARED if out_of_draws else ThemeColors.INK_DIM)


## Nothing left to throw because they are all gone, rather than all staked.
func _table_is_empty() -> bool:
	for d in game.pool.table:
		if not d.lost:
			return false
	return true


func _refresh_adversary() -> void:
	for child in _adversary_panel.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Red belongs to the man, to lines being taken, and to dice in the dirt.
	# Nobody across the table is the reassuring state: keep it warm.
	var threat := game.adversary != null
	heading.add_theme_color_override("font_color",
		ThemeColors.ADVERSARY if threat else ThemeColors.INK_DIM)
	_foe_panel.add_theme_stylebox_override("panel",
		ThemeColors.panel_style(ThemeColors.ADVERSARY if threat else ThemeColors.PANEL_EDGE))
	_adversary_panel.add_child(heading)
	if game.adversary == null:
		heading.text = "the chair opposite is empty"
		var waiting := Label.new()
		waiting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		waiting.add_theme_color_override("font_color", ThemeColors.INK_DIM)
		var next_duel := _next_duel_floor()
		if next_duel < 0:
			waiting.text = "Nothing else is coming for the Ledger."
		else:
			var who := AdversaryRoster.for_floor(next_duel)
			waiting.text = "Just the threshold tonight. %s sits down on %s."\
				% [Lore.adversary_name(who.id, who.display_name), Lore.night(next_duel).to_lower()]
		_adversary_panel.add_child(waiting)
		return
	heading.text = game.adversary.display_name.to_upper()
	var blurb := Label.new()
	blurb.text = game.adversary.blurb
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_color_override("font_color", ThemeColors.INK_DIM)
	_adversary_panel.add_child(blurb)
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", ThemeColors.INK)
	var declared := game.adversary.declared_box
	status.text = "Calls: %s\nHis score: %d   Lines taken: %d/%d" % [
		Scoring.box_name(declared) if declared >= 0 else "nothing",
		game.adversary.duel_score,
		game.card.adversary_count(),
		Balance.adversary_card_limit,
	]
	_adversary_panel.add_child(status)


func _next_duel_floor() -> int:
	for n in range(game.floor_number + 1, Game.total_nights() + 1):
		if Balance.is_duel_floor(n):
			return n
	return -1


func _hint() -> String:
	if game.phase != Game.Phase.TURN:
		return ""
	if not game.turn_rolled:
		if Throw.staked_count(game.pool.table) > 0:
			return "Only your staked dice are down. Throw the rest, and see what you are working with."
		return "Nothing on the felt yet. Throw, and see what you are working with."
	if not game.can_throw() or game.rerolls_left <= 0:
		if _table_is_empty():
			return "Every die is in the dirt. Settle a line — it will take nothing, and it is still gone for the run."
		return "No draws left. Settle a line: it is the only move you have."
	var rails := Throw.rail_count(game.pool.table)
	if rails > 0:
		return "%d on the rail: x%.0f on this score, but the next draw shoves %s toward the lip. Stake, or settle now."\
			% [rails, Throw.rail_multiplier(game.pool.table), "it" if rails == 1 else "them"]
	if game.adversary != null and game.adversary.declared_box >= 0:
		return "Deny him by taking %s yourself, or outpace him — you need %d more."\
			% [Scoring.box_name(game.adversary.declared_box), maxi(0, game.threshold - game.floor_score)]
	return "Settling a line ends the draw and spends it for the rest of the run. %d more to clear."\
		% maxi(0, game.threshold - game.floor_score)


func _on_log(line: String) -> void:
	_log_view.append_text(line + "\n")


# --- Overlay helpers ---------------------------------------------------------

## `paper` puts the overlay on posted parchment rather than a dark panel. The
## forge is a notice nailed to a wall in a lit room, not a system dialogue,
## and paper is the player's side of this table — so the whole screen changes
## material rather than gaining a decorative border.
func _clear_overlay(title: String, paper: bool = false) -> void:
	_overlay_paper = paper
	_overlay_title.text = title
	_overlay.add_theme_stylebox_override("panel",
		_notice_style() if paper else ThemeColors.panel_style(ThemeColors.INK))
	_overlay_title.add_theme_color_override("font_color",
		Color("6b2c1a") if paper else ThemeColors.INK)
	for child in _overlay_body.get_children():
		_overlay_body.remove_child(child)
		child.queue_free()


## The one dark bar on the notice: descending is the only irreversible thing
## on this page, so it is the only thing stamped in ink.
func _stamped_style(hot: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("241c14") if not hot else Color("32271b")
	box.border_color = Color("3a2a1c")
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


## Parchment, with the hard dark edge of something posted on a board.
func _notice_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = ThemeColors.PAPER_HI.lerp(ThemeColors.PAPER_LO, 0.12)
	box.border_color = Color("3a2a1c")
	box.set_border_width_all(2)
	box.set_corner_radius_all(2)
	box.content_margin_left = 26
	box.content_margin_right = 26
	box.content_margin_top = 20
	box.content_margin_bottom = 22
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 10
	return box


func _overlay_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color",
		Color(ThemeColors.PENCIL, 0.85) if _overlay_paper else ThemeColors.INK_DIM)
	_overlay_body.add_child(label)
	return label


## A smaller line under the title — the notice's own letterhead.
func _overlay_subtitle(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(ThemeColors.PENCIL, 0.60))
	_overlay_body.add_child(label)
	return label


## A printer's rule, separating the notice's preamble from what is on offer.
func _overlay_rule() -> void:
	var rule := ColorRect.new()
	rule.color = Color(ThemeColors.PENCIL, 0.28) if _overlay_paper \
		else Color(ThemeColors.INK_DIM, 0.25)
	rule.custom_minimum_size = Vector2(0, 1)
	_overlay_body.add_child(rule)


func _overlay_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 34)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(action)
	if _overlay_paper:
		# A dark system button on parchment would read as a hole in the page.
		button.add_theme_stylebox_override("normal", _draw_button_style(0.0))
		button.add_theme_stylebox_override("hover", _draw_button_style(0.5))
		button.add_theme_stylebox_override("pressed", _draw_button_style(1.0))
		button.add_theme_stylebox_override("disabled", _draw_button_style(0.0))
		button.add_theme_color_override("font_color", ThemeColors.PENCIL)
		button.add_theme_color_override("font_hover_color", ThemeColors.PENCIL)
		button.add_theme_color_override("font_pressed_color", ThemeColors.PENCIL)
		button.add_theme_color_override("font_disabled_color", ThemeColors.BURNED)
	_overlay_body.add_child(button)
	return button
