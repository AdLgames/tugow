extends Control
## Thirteen Boxes — the whole interface, built in code so the scene file stays
## a single node and the layout lives next to the logic it shows.

const BOX_ROW_HEIGHT := 30

var game: Game

var _floor_label: Label
var _progress_label: Label
var _progress_bar: ProgressBar
var _boxes_label: Label
var _dice_row: HBoxContainer
var _pool_label: Label
var _throw_buttons: Array[Button] = []
var _table_view: TableView
var _roll_button: Button
var _hint_label: Label
var _box_rows: Array[Button] = []
var _box_values: Array[Label] = []
var _adversary_panel: VBoxContainer
var _charm_label: Label
var _log_view: RichTextLabel
var _scrim: ColorRect
var _overlay: PanelContainer
var _overlay_title: Label
var _overlay_body: VBoxContainer

var _pending_offer: Dictionary = {}
var _pending_sacrifices: Array[int] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	_build()
	_show_title()


# --- Construction ------------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeColors.BACKGROUND
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	root.add_child(_build_header())

	var body := HBoxContainer.new()
	body.clip_contents = true
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	body.add_child(_build_scorecard())
	body.add_child(_build_table())
	body.add_child(_build_side())

	_build_overlay()


func _build_header() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeColors.panel_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)

	var title := Label.new()
	title.text = "THIRTEEN BOXES"
	title.add_theme_color_override("font_color", ThemeColors.INK)
	title.add_theme_font_size_override("font_size", 20)
	row.add_child(title)

	_floor_label = _stat_label(row, "Floor —")
	_progress_label = _stat_label(row, "0 / 0")

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(140, 18)
	_progress_bar.show_percentage = false
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_progress_bar)

	_boxes_label = _stat_label(row, "13 boxes left")
	return panel


func _stat_label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", ThemeColors.INK_DIM)
	parent.add_child(label)
	return label


func _build_scorecard() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeColors.panel_style())
	panel.custom_minimum_size = Vector2(320, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.95

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)

	var heading := Label.new()
	heading.text = "THE CARD"
	heading.add_theme_color_override("font_color", ThemeColors.INK)
	column.add_child(heading)

	for box in Scoring.BOX_COUNT:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		column.add_child(row)

		var button := Button.new()
		button.custom_minimum_size = Vector2(228, BOX_ROW_HEIGHT)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_box_pressed.bind(box))
		row.add_child(button)
		_box_rows.append(button)

		var value := Label.new()
		value.custom_minimum_size = Vector2(70, BOX_ROW_HEIGHT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(value)
		_box_values.append(value)

	return panel


func _build_table() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeColors.panel_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.4

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var heading := Label.new()
	heading.text = "THE TABLE — click a die to lock it for the floor"
	heading.add_theme_color_override("font_color", ThemeColors.INK)
	column.add_child(heading)

	_table_view = TableView.new()
	column.add_child(_table_view)

	_dice_row = HBoxContainer.new()
	_dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dice_row.add_theme_constant_override("separation", 8)
	column.add_child(_dice_row)

	_pool_label = Label.new()
	_pool_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pool_label.add_theme_color_override("font_color", ThemeColors.INK_DIM)
	column.add_child(_pool_label)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 12)
	column.add_child(controls)

	# Throw strength is a per-turn decision, so it is three buttons, not a setting.
	for strength in [Throw.Strength.SOFT, Throw.Strength.MEDIUM, Throw.Strength.HARD]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 44)
		button.tooltip_text = Throw.STRENGTH_BLURBS[strength]
		button.pressed.connect(_on_throw_pressed.bind(strength))
		button.mouse_entered.connect(_on_throw_hovered.bind(strength))
		controls.add_child(button)
		_throw_buttons.append(button)
	# Kept as the state readout the tests and the smoke run drive.
	_roll_button = _throw_buttons[Throw.Strength.MEDIUM]

	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.custom_minimum_size = Vector2(0, 44)
	_hint_label.add_theme_color_override("font_color", ThemeColors.INK_DIM)
	column.add_child(_hint_label)

	return panel


func _build_side() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(280, 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 0.85
	column.add_theme_constant_override("separation", 10)

	var adversary_box := PanelContainer.new()
	adversary_box.add_theme_stylebox_override("panel", ThemeColors.panel_style(ThemeColors.ADVERSARY))
	_adversary_panel = VBoxContainer.new()
	adversary_box.add_child(_adversary_panel)
	column.add_child(adversary_box)

	var charm_box := PanelContainer.new()
	charm_box.add_theme_stylebox_override("panel", ThemeColors.panel_style())
	_charm_label = Label.new()
	_charm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_charm_label.add_theme_color_override("font_color", ThemeColors.INK_DIM)
	charm_box.add_child(_charm_label)
	column.add_child(charm_box)

	var log_box := PanelContainer.new()
	log_box.add_theme_stylebox_override("panel", ThemeColors.panel_style())
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_view = RichTextLabel.new()
	_log_view.scroll_following = true
	_log_view.bbcode_enabled = false
	_log_view.add_theme_color_override("default_color", ThemeColors.INK_DIM)
	log_box.add_child(_log_view)
	column.add_child(log_box)

	return column


func _build_overlay() -> void:
	_scrim = ColorRect.new()
	_scrim.color = Color(0, 0, 0, 0.6)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.visible = false
	add_child(_scrim)

	_overlay = PanelContainer.new()
	_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_overlay.add_theme_stylebox_override("panel", ThemeColors.panel_style(ThemeColors.INK))
	_overlay.custom_minimum_size = Vector2(560, 0)
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


## The overlay is modal: whatever is behind it is not clickable and should
## not look like it is.
func _set_overlay_visible(shown: bool) -> void:
	_overlay.visible = shown
	_scrim.visible = shown


# --- Screens -----------------------------------------------------------------

func _show_title() -> void:
	_clear_overlay("THIRTEEN BOXES")
	_overlay_text("A dice roguelike where the scorecard is your health bar.")
	_overlay_text("Thirteen boxes. Every turn spends one, permanently, for the rest of the run. Clear a floor fast and you carry the rest forward.")
	_overlay_text("Locked is locked for the whole floor, not the turn.")
	var meta: Dictionary = RunState.meta
	_overlay_text("Runs: %d   Deepest floor: %d   Best total: %d"
		% [int(meta["runs"]), int(meta["deepest_floor"]), int(meta["best_total"])])
	_overlay_button("Descend", _start_run)
	_set_overlay_visible(true)


func _start_run() -> void:
	game = RunState.new_run()
	game.state_changed.connect(_refresh)
	game.log_emitted.connect(_on_log)
	game.run_ended.connect(_on_run_ended)
	game.floor_cleared.connect(_on_floor_cleared)
	_log_view.text = ""
	for line in game.log_lines:
		_on_log(line)
	_set_overlay_visible(false)
	_refresh()


func _on_floor_cleared(_floor_number: int, _reclaimed: Array) -> void:
	if game.phase == Game.Phase.BENCH:
		_show_bench()


func _on_run_ended(won: bool, reason: String) -> void:
	_clear_overlay("You walked out." if won else "The run ends.")
	_overlay_text(reason)
	_overlay_text("Run total: %d over %d floor%s."
		% [game.card.run_total, game.floor_number, "" if game.floor_number == 1 else "s"])
	var scratched := 0
	for box in game.card.player_boxes():
		if game.card.points[box] == 0:
			scratched += 1
	_overlay_text("The card: %d yours, %d taken, %d burned, %d never spent. %d of yours were scratches."
		% [
			game.card.count_state(Scorecard.State.PLAYER),
			game.card.count_state(Scorecard.State.ADVERSARY),
			game.card.count_state(Scorecard.State.BURNED),
			game.card.open_count(),
			scratched,
		])
	var meta: Dictionary = RunState.meta
	_overlay_text("Best total: %d   Deepest floor: %d" % [int(meta["best_total"]), int(meta["deepest_floor"])])
	_overlay_button("Again", _start_run)
	_set_overlay_visible(true)


# --- The bench ---------------------------------------------------------------

func _show_bench() -> void:
	_pending_offer = {}
	_pending_sacrifices.clear()
	_clear_overlay("THE BENCH")
	_overlay_text("Floor %d cleared in %d turns. The only currency is your scorecard: %d boxes left."
		% [game.floor_number, game.floor_turn, game.card.open_count()])
	if game.pending_carry > 0:
		_overlay_text("You overshot; %d points carry into the next floor." % game.pending_carry)
	var charm_names: Array[String] = []
	for c in game.charms:
		charm_names.append(c.charm_name)
	if not charm_names.is_empty():
		_overlay_text("Charms: %s" % ", ".join(charm_names))
	for offer in Bench.offers(game):
		var affordable: bool = Bench.can_afford(game, int(offer["cost"]))
		var label := "%s — %d box%s\n%s" % [
			offer["label"], int(offer["cost"]),
			"" if int(offer["cost"]) == 1 else "es", offer["detail"],
		]
		var button := _overlay_button(label, _on_bench_offer.bind(offer))
		button.disabled = not affordable
	_overlay_button("Descend to floor %d" % (game.floor_number + 1), _leave_bench)
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
	_clear_overlay(String(_pending_offer["label"]))
	_overlay_text("Sacrifice %d more box%s. This is permanent."
		% [cost - _pending_sacrifices.size(), "" if cost - _pending_sacrifices.size() == 1 else "es"])
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
			_clear_overlay("Which die?")
			for d in game.pool.dice:
				_overlay_button("%s — faces %s" % [d.die_name, str(Array(d.faces))], _apply_bench.bind(d.id))
			_overlay_button("Never mind", _show_bench)
		"bitter_die":
			_clear_overlay("Which bitter die?")
			for d in game.pool.dice:
				if d.bitter:
					_overlay_button(d.die_name, _apply_bench.bind(d.id))
			_overlay_button("Never mind", _show_bench)
		"filled_box":
			_clear_overlay("Which box do you hate?")
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
	if _table_view != null:
		_table_view.preview_strength = strength
		_table_view.queue_redraw()


func _on_die_pressed(die: Die) -> void:
	if not game.would_lock_out(die):
		game.lock_die(die)
		return
	_clear_overlay("Lock %s — your last free die?" % die.die_name)
	_overlay_text("Every die on the table would be locked for the rest of the floor. There is nothing left to reroll: every remaining turn scores exactly %s, and only the box you write changes."
		% str(game.table_values()))
	_overlay_button("Lock it anyway", func() -> void:
		_set_overlay_visible(false)
		game.lock_die(die)
		_refresh())
	_overlay_button("Back", func() -> void:
		_set_overlay_visible(false)
		_refresh())
	_set_overlay_visible(true)


func _on_box_pressed(box: int) -> void:
	if game == null or game.phase != Game.Phase.TURN or not game.card.is_open(box):
		return
	var value := game.preview(box)
	_clear_overlay("%s for %d" % [Scoring.box_name(box), value])
	if value > 0:
		_overlay_text("%s on %s." % [Scoring.box_rule(box), str(game.table_values())])
	else:
		_overlay_text("These dice do not meet %s. Writing it now scratches the box for nothing — a sacrifice, not a mistake."
			% Scoring.box_name(box))
	if game.adversary != null and box == game.adversary.declared_box:
		_overlay_text("This is the box %s announced. Taking it denies the claim."
			% game.adversary.display_name)
	_overlay_text("The box is spent for the rest of the run. %d would remain."
		% (game.card.open_count() - 1))
	_overlay_text("Floor: %d + %d = %d of %d." % [game.floor_score, value, game.floor_score + value, game.threshold])
	_overlay_button("Write it", func() -> void:
		_set_overlay_visible(false)
		game.write_box(box)
		_refresh())
	_overlay_button("Back", func() -> void:
		_set_overlay_visible(false)
		_refresh())
	_set_overlay_visible(true)


# --- Refresh -----------------------------------------------------------------

func _refresh() -> void:
	if game == null:
		return
	_floor_label.text = "Floor %d" % game.floor_number
	_progress_label.text = "%d / %d" % [game.floor_score, game.threshold]
	if game.floor_carry_in > 0:
		_progress_label.text += "  (%d carried)" % game.floor_carry_in
	_progress_bar.max_value = maxf(1.0, float(game.threshold))
	_progress_bar.value = minf(float(game.floor_score), _progress_bar.max_value)
	_boxes_label.text = "%d boxes left" % game.card.open_count()

	_table_view.bind(game.pool)
	_refresh_dice()
	_refresh_pool()
	_refresh_card()
	_refresh_adversary()

	var charm_names: Array[String] = []
	for c in game.charms:
		charm_names.append(c.charm_name)
	_charm_label.text = "Charms: %s" % ("none yet" if charm_names.is_empty() else ", ".join(charm_names))

	_refresh_throw_buttons()
	_hint_label.text = _hint()


func _refresh_throw_buttons() -> void:
	var frozen := not game.can_throw()
	var throws_left := game.rerolls_left
	var free := game.free_dice_on_table()
	for strength in _throw_buttons.size():
		var button := _throw_buttons[strength]
		button.disabled = game.phase != Game.Phase.TURN or throws_left <= 0 or frozen
		if frozen:
			button.text = "Nothing to throw"
		elif throws_left <= 0:
			button.text = "No throws left"
		else:
			button.text = "%s throw\n%d %s, %d left" % [
				Throw.strength_name(strength), free,
				"die" if free == 1 else "dice", throws_left,
			]
		var tint := ThemeColors.INK
		if strength == Throw.Strength.HARD:
			tint = ThemeColors.ADVERSARY
		elif strength == Throw.Strength.SOFT:
			tint = ThemeColors.PLAYER
		button.add_theme_color_override("font_color", tint)


func _refresh_dice() -> void:
	for child in _dice_row.get_children():
		child.queue_free()
	for d in game.pool.table:
		var view := DieView.new()
		_dice_row.add_child(view)
		view.bind(d)
		view.pressed.connect(_on_die_pressed.bind(d))


## The pool is eight named individuals; the table only ever shows five of them.
func _refresh_pool() -> void:
	var parts: Array[String] = []
	for d in game.pool.dice:
		var tags: Array[String] = []
		if d.locked:
			tags.append("locked by %s" % d.locked_by)
		if d.bitter:
			tags.append("bitter")
		if Array(d.faces) != [1, 2, 3, 4, 5, 6]:
			tags.append(str(Array(d.faces)))
		if d.lost:
			tags.append("off the table")
		if d.lock_scores > 0 and not d.locked and not d.lost:
			tags.append("%d/%d to facet" % [d.lock_scores % Balance.facet_threshold, Balance.facet_threshold])
		parts.append(d.die_name if tags.is_empty() else "%s (%s)" % [d.die_name, ", ".join(tags)])
	_pool_label.text = "THE POOL — %s" % "   ".join(parts)


func _refresh_card() -> void:
	var declared := -1
	if game.adversary != null:
		declared = game.adversary.declared_box
	var best_preview := 0
	if game.phase == Game.Phase.TURN:
		for box in game.card.open_boxes():
			best_preview = maxi(best_preview, game.preview(box))
	for box in Scoring.BOX_COUNT:
		var button := _box_rows[box]
		var value := _box_values[box]
		var open := game.card.is_open(box)
		button.disabled = not open or game.phase != Game.Phase.TURN
		var marker := "> " if box == declared and open else "  "
		button.text = "%s%s  %s" % [marker, Scoring.box_name(box), Scoring.box_rule(box)]
		var colour := ThemeColors.for_state(game.card.states[box])
		if box == declared and open:
			colour = ThemeColors.DECLARED
		button.add_theme_color_override("font_color", colour)
		button.add_theme_color_override("font_disabled_color", colour)
		button.add_theme_color_override("font_hover_color", ThemeColors.LOCKED)
		if open:
			var preview := game.preview(box) if game.phase == Game.Phase.TURN else 0
			value.text = str(preview)
			var tone := ThemeColors.INK_DIM
			if preview <= 0:
				tone = ThemeColors.BURNED
			elif preview == best_preview:
				tone = ThemeColors.LOCKED
			elif preview > 0:
				tone = ThemeColors.INK
			value.add_theme_color_override("font_color", tone)
		else:
			value.text = "%s %d" % [game.card.state_tag(box), game.card.points[box]]
			value.add_theme_color_override("font_color", colour)


func _refresh_adversary() -> void:
	for child in _adversary_panel.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(0, 0)
	heading.add_theme_color_override("font_color", ThemeColors.ADVERSARY)
	_adversary_panel.add_child(heading)
	if game.adversary == null:
		heading.text = "NO ADVERSARY"
		var waiting := Label.new()
		waiting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		waiting.add_theme_color_override("font_color", ThemeColors.INK_DIM)
		var next_duel := _next_duel_floor()
		if next_duel < 0:
			waiting.text = "Nothing else is coming for the card. Spend it as you like."
		else:
			var who := AdversaryRoster.for_floor(next_duel)
			waiting.text = "Just the threshold this floor. %s waits on floor %d."\
				% [who.display_name, next_duel]
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
	status.text = "Announced: %s\nIts score: %d   Boxes taken: %d/%d" % [
		Scoring.box_name(declared) if declared >= 0 else "nothing",
		game.adversary.duel_score,
		game.card.adversary_count(),
		Balance.adversary_card_limit,
	]
	_adversary_panel.add_child(status)


func _next_duel_floor() -> int:
	for n in range(game.floor_number + 1, Game.TOTAL_FLOORS + 1):
		if Balance.is_duel_floor(n):
			return n
	return -1


func _hint() -> String:
	if game.phase != Game.Phase.TURN:
		return ""
	var rails := Throw.rail_count(game.pool.table)
	if rails > 0:
		return "%d die on the rail: x%.0f on this score, but the next throw shoves it toward the lip. Lock it, or score now."\
			% [rails, Throw.rail_multiplier(game.pool.table)] if rails == 1 else \
			"%d dice on the rail: x%.0f on this score, but the next throw shoves them toward the lip."\
			% [rails, Throw.rail_multiplier(game.pool.table)]
	if game.adversary != null and game.adversary.declared_box >= 0:
		return "Deny it by taking %s yourself, or outpace it — you need %d more."\
			% [Scoring.box_name(game.adversary.declared_box), maxi(0, game.threshold - game.floor_score)]
	return "Writing a box ends the turn and spends it for the rest of the run. %d more to clear."\
		% maxi(0, game.threshold - game.floor_score)


func _on_log(line: String) -> void:
	_log_view.append_text(line + "\n")


# --- Overlay helpers ---------------------------------------------------------

func _clear_overlay(title: String) -> void:
	_overlay_title.text = title
	for child in _overlay_body.get_children():
		_overlay_body.remove_child(child)
		child.queue_free()


func _overlay_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", ThemeColors.INK_DIM)
	_overlay_body.add_child(label)
	return label


func _overlay_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 34)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(action)
	_overlay_body.add_child(button)
	return button
