@tool
class_name ModalFitPanel
extends Control

## The fitting station.
##
## One screen, three columns, built in code rather than in a scene file: the
## layout is almost entirely repetition — twelve label/value rows, four plot
## wells, three panel modules per column — and a hand-authored .tscn of that
## shape is a wall of node paths nobody can review against the design.
##
## The shell around it is whichever one loaded this scene. Nothing here touches
## an editor API, which is what lets `addons/modal_fit` mount the same panel as
## a main-screen tab and the exported binary run it as an application.

const COLUMN_GAP := 14

var state: FitState = FitState.new()

var _stage_buttons: Array[Button] = []
var _mode_table: ModeTable
var _strike_map: StrikeMapView
var _solo_button: Button
var _model_menu: OptionButton
var _rate_menu: OptionButton
var _file_dialog: FileDialog

# Readouts refreshed on every state change.
var _readouts := {}
var _dropped_list: VBoxContainer
var _warning_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	state.changed.connect(_refresh)
	_refresh()


# --- construction ------------------------------------------------------------

func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override(&"margin_left", 22)
	gutter.add_theme_constant_override(&"margin_right", 22)
	gutter.add_theme_constant_override(&"margin_top", 4)
	gutter.add_theme_constant_override(&"margin_bottom", 40)
	scroll.add_child(gutter)

	# The three columns carry the design's fixed widths as minimums; extra
	# width goes to the centre column, which is the only one that gains
	# anything from it. Below about 1100 the flow container stacks them.
	var centring := HBoxContainer.new()
	gutter.add_child(centring)
	var page := VBoxContainer.new()
	page.custom_minimum_size.x = 0
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override(&"separation", COLUMN_GAP)
	centring.add_child(page)

	page.add_child(_build_header())

	var columns := HFlowContainer.new()
	columns.add_theme_constant_override(&"h_separation", COLUMN_GAP)
	columns.add_theme_constant_override(&"v_separation", COLUMN_GAP)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(columns)

	columns.add_child(_build_left_column())
	columns.add_child(_build_centre_column())
	columns.add_child(_build_right_column())

	page.add_child(_build_footer())


## Only the analysis settings. The wordmark lives in the shell, which is
## shared with the Sounds screen.
func _build_header() -> Control:
	var row := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	for line in [
		"WAV IN  ·  .MODAL OUT",
		"ANALYSIS %d / HOP %d / PAD %d×" % [FitState.WINDOW, FitState.HOP, FitState.ZERO_PAD],
		"BLACKMAN-HARRIS 4-TERM",
	]:
		var label := _tracked_label(line, 9, ModalTheme.MUTED, 1.1, ModalTheme.mono())
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_child(label)
	row.add_child(right)
	return row


# --- left column -------------------------------------------------------------

func _build_left_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 246
	column.add_theme_constant_override(&"separation", COLUMN_GAP)

	column.add_child(_build_source_module())
	column.add_child(_build_strike_module())
	column.add_child(_build_material_module())
	return column


func _build_source_module() -> Control:
	var module := PanelModule.new()
	module.title = "Source"
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 11)
	module.add_child(body)

	_model_menu = OptionButton.new()
	_model_menu.fit_to_longest_item = false
	_model_menu.clip_text = true
	_style_option_button(_model_menu)
	_model_menu.item_selected.connect(_on_model_selected)
	body.add_child(_model_menu)

	var well := GlassWell.new()
	var readout := VBoxContainer.new()
	readout.add_theme_constant_override(&"separation", 4)
	_readouts["model_name"] = _value_label("", 11, ModalTheme.AMBER, ModalTheme.mono_bold())
	_readouts["model_name"].autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	readout.add_child(_readouts["model_name"])
	_readouts["model_detail"] = _value_label("", 9, Color("#7d8a62"), ModalTheme.mono())
	_readouts["model_detail"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readout.add_child(_readouts["model_detail"])
	well.add_child(readout)
	body.add_child(well)

	var rate_row := HBoxContainer.new()
	rate_row.add_theme_constant_override(&"separation", 8)
	var rate_label := _tracked_label("HOST RATE", 9, ModalTheme.LABEL_FAINT, 0.7, ModalTheme.mono())
	rate_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rate_row.add_child(rate_label)
	_rate_menu = OptionButton.new()
	_rate_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_option_button(_rate_menu)
	for rate in FitState.SAMPLE_RATES:
		_rate_menu.add_item("%d Hz" % int(rate))
	_rate_menu.item_selected.connect(_on_rate_selected)
	rate_row.add_child(_rate_menu)
	body.add_child(rate_row)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override(&"separation", 5)
	for key in ["modes_kept", "in_file", "fit_quality", "voiced"]:
		var label := ""
		match key:
			"modes_kept": label = "MODES KEPT"
			"in_file": label = "IN FILE"
			"fit_quality": label = "FIT QUALITY"
			"voiced": label = "VOICED"
		stats.add_child(_stat_row(key, label))
	body.add_child(stats)

	_warning_label = _value_label("", 8, ModalTheme.RED, ModalTheme.mono())
	_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_warning_label)
	return module


func _build_strike_module() -> Control:
	var module := PanelModule.new()
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 10)
	module.add_child(body)

	var header := HBoxContainer.new()
	header.add_child(_tracked_label("STRIKE MAP", 8, ModalTheme.LABEL, 2.4, ModalTheme.sans()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_readouts["strike"] = _value_label("", 8, ModalTheme.AMBER, ModalTheme.mono())
	header.add_child(_readouts["strike"])
	body.add_child(header)

	var well := GlassWell.new()
	well.inset_content = false
	_strike_map = StrikeMapView.new()
	_strike_map.state = state
	_strike_map.position_picked.connect(state.set_strike)
	# The design's map is square. An AspectRatioContainer would express that
	# directly but reports no minimum height, so the well collapses to nothing
	# and the caption below it lands on top of the map. The column has a fixed
	# 246px minimum and 14px of padding either side, so the square is a known
	# 218px and a minimum size says it without the indirection.
	_strike_map.custom_minimum_size = Vector2(218, 218)
	well.add_child(_strike_map)
	body.add_child(well)

	body.add_child(_caption("Click to excite from (u,v). Per-mode gains come from the model file."))
	return module


func _build_material_module() -> Control:
	var module := PanelModule.new()
	module.title = "Material"
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 5)
	module.add_child(body)
	for key in ["contact_time_ref_ms", "roughness", "rolling_gain", "scrape_gain"]:
		body.add_child(_stat_row(key, key, ModalTheme.mono()))
	return module


# --- centre column -----------------------------------------------------------

func _build_centre_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 480
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", COLUMN_GAP)
	column.add_child(_build_analysis_module())
	column.add_child(_build_velocity_module())
	return column


func _build_analysis_module() -> Control:
	var module := PanelModule.new()
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 12)
	module.add_child(body)

	var steps := HFlowContainer.new()
	steps.add_theme_constant_override(&"h_separation", 6)
	steps.add_theme_constant_override(&"v_separation", 6)
	for stage in FitState.Stage.values():
		var button := Button.new()
		button.text = str(FitState.STAGE_LABELS[stage])
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(state.set_stage.bind(stage))
		_stage_buttons.append(button)
		steps.add_child(button)
	body.add_child(steps)

	var well := GlassWell.new()
	well.deep = true
	well.inset_content = false
	var stage_view := StageView.new()
	stage_view.state = state
	stage_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	well.add_child(stage_view)
	body.add_child(well)

	var plots := HFlowContainer.new()
	plots.add_theme_constant_override(&"h_separation", 12)
	plots.add_theme_constant_override(&"v_separation", 12)

	var wave_column := VBoxContainer.new()
	wave_column.custom_minimum_size.x = 300
	wave_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_column.add_theme_constant_override(&"separation", 7)
	_readouts["wave_heading"] = _tracked_label("RESYNTHESIS", 8, ModalTheme.LABEL, 2.4,
			ModalTheme.sans())
	wave_column.add_child(_readouts["wave_heading"])
	var wave_well := GlassWell.new()
	wave_well.deep = true
	wave_well.inset_content = false
	var waveform := WaveformView.new()
	waveform.state = state
	waveform.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_well.add_child(waveform)
	wave_column.add_child(wave_well)
	plots.add_child(wave_column)

	var curve_column := VBoxContainer.new()
	curve_column.custom_minimum_size.x = 240
	curve_column.add_theme_constant_override(&"separation", 7)
	curve_column.add_child(_tracked_label("VELOCITY → BRIGHTNESS", 8, ModalTheme.LABEL, 2.4,
			ModalTheme.sans()))
	var curve_well := GlassWell.new()
	curve_well.deep = true
	curve_well.inset_content = false
	var curve := VelocityCurveView.new()
	curve.state = state
	curve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	curve_well.add_child(curve)
	curve_column.add_child(curve_well)
	plots.add_child(curve_column)

	body.add_child(plots)
	return module


func _build_velocity_module() -> Control:
	var module := PanelModule.new()
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 12)
	module.add_child(body)

	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 18)
	row.add_theme_constant_override(&"v_separation", 12)

	var slider_column := VBoxContainer.new()
	slider_column.custom_minimum_size.x = 300
	slider_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_column.add_theme_constant_override(&"separation", 9)

	var header := HBoxContainer.new()
	header.add_child(_tracked_label("IMPACT VELOCITY", 8, ModalTheme.LABEL, 2.4, ModalTheme.sans()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_readouts["velocity"] = _value_label("", 13, ModalTheme.AMBER, ModalTheme.mono_bold())
	header.add_child(_readouts["velocity"])
	slider_column.add_child(header)

	var slider := HSlider.new()
	slider.min_value = VelocityCurveView.VELOCITY_MIN
	slider.max_value = VelocityCurveView.VELOCITY_MAX
	slider.step = 0.05
	slider.value = state.velocity
	slider.custom_minimum_size.y = 20
	slider.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	slider.value_changed.connect(state.set_velocity)
	_style_slider(slider)
	slider_column.add_child(slider)

	var ticks := HBoxContainer.new()
	for tick in ["0.5", "2.0", "4.0", "10.0 m/s"]:
		var label := _tracked_label(tick, 8, ModalTheme.MUTED, 0.8, ModalTheme.mono())
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = (HORIZONTAL_ALIGNMENT_RIGHT if tick.ends_with("m/s")
				else HORIZONTAL_ALIGNMENT_LEFT)
		ticks.add_child(label)
	slider_column.add_child(ticks)
	row.add_child(slider_column)

	var meters := HBoxContainer.new()
	meters.add_theme_constant_override(&"separation", 22)
	meters.size_flags_vertical = Control.SIZE_SHRINK_END
	meters.add_child(_meter("contact", "Contact", ModalTheme.INK))
	meters.add_child(_meter("pulse", "Pulse", ModalTheme.INK))
	meters.add_child(_meter("centroid", "Centroid", ModalTheme.AMBER))
	row.add_child(meters)
	body.add_child(row)

	var rule := HSeparator.new()
	rule.add_theme_stylebox_override(&"separator", _rule_box())
	body.add_child(rule)

	_readouts["clamp_note"] = _caption("", 9)
	body.add_child(_readouts["clamp_note"])
	return module


## The contact-time law, and where it runs out for *this* material.
##
## The design prints "above ~10 m/s an impact stops getting brighter", which is
## the figure the repository README quotes. That figure is steel's. The clamp
## velocity is (t_ref / 0.05 ms)^5, and a fifth power is unforgiving: the same
## sentence under a ceramic mug is wrong by a factor of twenty-four. So the
## panel works it out from the loaded model instead.
func _clamp_note() -> String:
	var law := ("t_c ∝ v^(−1/5) · a shorter contact is a wider excitation bandwidth, "
			+ "so a harder hit reaches more of the high modes. ")
	if not state.is_loaded():
		return law
	var clamp := Excitation.clamp_velocity(state.model.material.contact_time_ref_ms)
	if clamp <= VelocityCurveView.VELOCITY_MAX:
		return law + ("Contact time clamps at 0.05 ms — above %.1f m/s this material stops "
				+ "getting brighter and only gets louder.") % clamp
	return law + ("Contact time clamps at 0.05 ms, which %s does not reach until %.0f m/s — "
			+ "well past this slider, so brightness rises across its whole range.") % [
			state.model.name.replace("_", " "), clamp]


# --- right column ------------------------------------------------------------

func _build_right_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 306
	column.add_theme_constant_override(&"separation", COLUMN_GAP)
	column.add_child(_build_modes_module())
	column.add_child(_build_dropped_module())
	column.add_child(_build_export_module())
	return column


func _build_modes_module() -> Control:
	var module := PanelModule.new()
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 10)
	module.add_child(body)

	var header := HBoxContainer.new()
	header.add_child(_tracked_label("MODES", 8, ModalTheme.LABEL, 2.4, ModalTheme.sans()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_solo_button = Button.new()
	_solo_button.focus_mode = Control.FOCUS_NONE
	_solo_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_solo_button.pressed.connect(state.clear_solo)
	header.add_child(_solo_button)
	body.add_child(header)

	# Fourteen modes at 34px is taller than the design's eight rows; the list
	# scrolls rather than pushing the panels below it off the screen.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 322
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mode_table = ModeTable.new()
	_mode_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_table.solo_toggled.connect(state.toggle_solo)
	scroll.add_child(_mode_table)
	body.add_child(scroll)

	body.add_child(_caption("Bar is live amplitude at this velocity and strike. Click a row to solo."))
	return module


## The design calls this "Rejected candidates" and fills it with the fitter's
## own rejections. Those live in a `modal-fit --explain` run, not in a `.modal`
## file — the format keeps the modes that survived and no record of the ones
## that did not. What a loaded model *can* say is which of its modes this
## sample rate will not voice, which is the same shape of information and is
## real, so that is what the panel reports.
func _build_dropped_module() -> Control:
	var module := PanelModule.new()
	module.title = "Not voiced at this rate"
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 6)
	module.add_child(body)
	_dropped_list = VBoxContainer.new()
	_dropped_list.add_theme_constant_override(&"separation", 6)
	body.add_child(_dropped_list)
	body.add_child(_caption(
		"The fitter's own rejections — sidelobes, poor R², lost tracks — are printed by "
		+ "modal-fit --explain and are not carried in the .modal file."))
	return module


func _build_export_module() -> Control:
	var module := PanelModule.new()
	module.title = "Export"
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 9)
	module.add_child(body)

	var well := GlassWell.new()
	_readouts["path"] = _value_label("", 10, ModalTheme.AMBER, ModalTheme.mono())
	_readouts["path"].autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	well.add_child(_readouts["path"])
	body.add_child(well)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 8)
	var open := Button.new()
	open.text = "OPEN .MODAL"
	open.focus_mode = Control.FOCUS_NONE
	open.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open.pressed.connect(_on_open_pressed)
	_style_action_button(open, true)
	buttons.add_child(open)

	var reload := Button.new()
	reload.text = "RELOAD"
	reload.focus_mode = Control.FOCUS_NONE
	reload.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	reload.pressed.connect(_on_reload_pressed)
	_style_action_button(reload, false)
	buttons.add_child(reload)
	body.add_child(buttons)

	body.add_child(_caption(
		"Runtime reads the file at load and computes coefficients for the host sample rate."))
	return module


func _build_footer() -> Control:
	var label := _caption(
		"Silent. The plots are computed from the same excitation and resonator maths the engine "
		+ "uses — fractional Hann contact pulse, per-mode excitation gain, exponential decay — but "
		+ "no audio is rendered. Modes, decays and material constants are read from the .modal "
		+ "file; the three models in models/ are hand authored, so their fit_quality is 0.", 9)
	label.add_theme_color_override(&"font_color", ModalTheme.FOOTNOTE)
	label.custom_minimum_size.x = 900
	return label


# --- model discovery ---------------------------------------------------------

## The shell finds the sounds and hands the same list to both screens.
func set_library(paths: PackedStringArray) -> void:
	_model_menu.clear()
	for path in paths:
		_model_menu.add_item(path.get_file().get_basename())
		_model_menu.set_item_metadata(_model_menu.item_count - 1, path)
	if _model_menu.item_count == 0:
		_model_menu.add_item("no models found")
		_model_menu.set_item_disabled(0, true)
		return
	_select_current()


## Points the picker at whatever the shared state has open, without reloading
## it — the other screen may have been the one that changed it.
func _select_current() -> void:
	for i in _model_menu.item_count:
		if _model_menu.get_item_metadata(i) == state.model_path:
			_model_menu.select(i)
			return


func _on_model_selected(index: int) -> void:
	var path: Variant = _model_menu.get_item_metadata(index)
	if typeof(path) == TYPE_STRING:
		state.load_model(path)


func _on_rate_selected(index: int) -> void:
	state.set_sample_rate(FitState.SAMPLE_RATES[index])


func _on_reload_pressed() -> void:
	if not state.model_path.is_empty():
		state.load_model(state.model_path)


func _on_open_pressed() -> void:
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.filters = PackedStringArray(["*.modal ; Modal model"])
		_file_dialog.size = Vector2i(720, 480)
		_file_dialog.file_selected.connect(_on_file_chosen)
		add_child(_file_dialog)
	_file_dialog.popup_centered()


func _on_file_chosen(path: String) -> void:
	# A file opened from outside the discovered directories still belongs in
	# the picker, or the next selection silently loses it.
	var index := -1
	for i in _model_menu.item_count:
		if _model_menu.get_item_metadata(i) == path:
			index = i
			break
	if index == -1:
		_model_menu.add_item(path.get_file().get_basename())
		index = _model_menu.item_count - 1
		_model_menu.set_item_metadata(index, path)
	_model_menu.select(index)
	state.load_model(path)


# --- refresh -----------------------------------------------------------------

func _refresh() -> void:
	for i in _stage_buttons.size():
		_style_stage_button(_stage_buttons[i], i == state.stage)

	if _mode_table.state != state:
		_mode_table.bind(state)

	_solo_button.text = "ALL MODES" if state.solo < 0 else "SOLO %d · CLEAR" % state.solo
	_style_solo_button(_solo_button, state.solo >= 0)

	_select_current()

	var loaded := state.is_loaded()
	_readouts["path"].text = state.model_path.get_file() if not state.model_path.is_empty() else "—"
	_readouts["clamp_note"].text = _clamp_note()
	_readouts["wave_heading"].text = ("RESYNTHESIS · %s" % state.duration_label() if loaded
			else "RESYNTHESIS")

	if not loaded:
		_readouts["model_name"].text = "no model"
		_readouts["model_detail"].text = state.model.error if state.model != null else ""
		_warning_label.text = ""
		for key in ["modes_kept", "in_file", "fit_quality", "voiced", "velocity",
				"contact", "pulse", "centroid", "strike"]:
			_set_readout(key, "—")
		_clear_dropped()
		return

	var model := state.model
	_readouts["model_name"].text = "%s.modal" % model.name
	_readouts["model_detail"].text = "%s\n%d Hz host · ceiling %.1f kHz" % [
		model.source if not model.source.is_empty() else "no source recorded",
		int(state.sample_rate), state.usable_ceiling() / 1000.0]

	_set_readout("modes_kept", "%d / %d" % [model.modes.size(), model.modes_in_file])
	_set_readout("in_file", str(model.modes_in_file))
	# A hand-authored model has no fit to report a quality for, and showing
	# "0.000" in the same green as a good fit would read as a terrible one.
	if model.fit_quality > 0.0:
		_set_readout("fit_quality", "%.3f" % model.fit_quality, Color("#8fd0a4"))
	else:
		_set_readout("fit_quality", "not fitted", ModalTheme.MUTED)
	var voiced := model.voiced_mode_count()
	_set_readout("voiced", "%d" % voiced,
			ModalTheme.RED if voiced < model.modes.size() else ModalTheme.TEXT_DIM)

	_set_readout("contact_time_ref_ms", "%.3f ms" % model.material.contact_time_ref_ms)
	_set_readout("roughness", "%.3f" % model.material.roughness)
	_set_readout("rolling_gain", "%.3f" % model.material.rolling_gain)
	_set_readout("scrape_gain", "%.3f" % model.material.scrape_gain)

	_readouts["velocity"].text = "%.2f m/s" % state.velocity
	_set_readout("contact", "%.3f ms" % state.contact_ms)
	_set_readout("pulse", "%.2f smp" % state.pulse.width)
	_set_readout("centroid", "%d Hz" % roundi(state.centroid))

	if model.has_strike_data():
		var position: ModalModel.StrikePosition = model.strike_positions[maxi(state.strike, 0)]
		var name := position.name if not position.name.is_empty() else "P%d" % maxi(state.strike, 0)
		_readouts["strike"].text = "%s (%.2f, %.2f)" % [name.to_upper(), position.u, position.v]
	else:
		_readouts["strike"].text = "UNIT GAINS"

	_warning_label.text = "\n".join(model.warnings) if model.warnings.size() > 0 else ""
	_rebuild_dropped(model)


func _clear_dropped() -> void:
	for child in _dropped_list.get_children():
		child.queue_free()


func _rebuild_dropped(model: ModalModel) -> void:
	_clear_dropped()
	if model.warnings.is_empty():
		var none := _value_label("every mode in the file is voiced at this rate", 9,
				ModalTheme.MUTED, ModalTheme.mono())
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_dropped_list.add_child(none)
		return

	for warning in model.warnings:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 9)

		var mark := _value_label("×", 9, ModalTheme.RED, ModalTheme.mono())
		mark.custom_minimum_size.x = 14
		row.add_child(mark)

		# "dropped mode 8 at 15438 Hz: outside 20 to 21600 Hz at this sample
		# rate" — split so the frequency sits in its own column, as drawn.
		var frequency := "—"
		var reason := warning
		var at := warning.find(" at ")
		var colon := warning.find(":")
		if at != -1 and colon > at:
			frequency = warning.substr(at + 4, colon - at - 4)
			reason = warning.substr(colon + 2)
		var frequency_label := _value_label(frequency, 9, ModalTheme.TEXT_DIM, ModalTheme.mono())
		frequency_label.custom_minimum_size.x = 72
		frequency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(frequency_label)

		var reason_label := _value_label(reason, 9, ModalTheme.MUTED, ModalTheme.mono())
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(reason_label)
		_dropped_list.add_child(row)


func _set_readout(key: String, value: String, colour := Color.TRANSPARENT) -> void:
	if not _readouts.has(key):
		return
	var label: Label = _readouts[key]
	label.text = value
	if colour.a > 0.0:
		label.add_theme_color_override(&"font_color", colour)


# --- small builders ----------------------------------------------------------

func _stat_row(key: String, label: String, font := ModalTheme.mono()) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_value_label(label, 9, ModalTheme.LABEL_FAINT, font))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var value := _value_label("—", 9, ModalTheme.TEXT_DIM, font)
	row.add_child(value)
	_readouts[key] = value
	return row


func _meter(key: String, label: String, colour: Color) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 2)
	column.add_child(_tracked_label(label, 8, ModalTheme.LABEL_FAINT, 1.9, ModalTheme.sans()))
	var value := _value_label("—", 14, colour, ModalTheme.mono_bold())
	column.add_child(value)
	_readouts[key] = value
	return column


func _value_label(text: String, size: int, colour: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", colour)
	return label


## The design's letterspaced treatment for labels and the wordmark.
##
## Godot has no tracking property on Label. `TextServer` exposes per-glyph
## spacing through the font itself, so the tracking rides on a `FontVariation`
## of the face rather than on the control — which also means the spacing
## survives into `get_string_size` and the layout stays correct.
func _tracked_label(text: String, size: int, colour: Color, tracking: float, font: Font) -> Label:
	var variation := FontVariation.new()
	variation.base_font = font
	variation.spacing_glyph = int(round(tracking))
	return _value_label(text, size, colour, variation)


func _caption(text: String, size := 8) -> Label:
	var label := _value_label(text, size, ModalTheme.MUTED, ModalTheme.mono())
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _rule_box() -> StyleBoxLine:
	var box := StyleBoxLine.new()
	box.color = ModalTheme.RULE
	box.thickness = 1
	return box


# --- control styling ---------------------------------------------------------

func _style_stage_button(button: Button, active: bool) -> void:
	button.add_theme_stylebox_override(&"normal", ModalTheme.button_box(active))
	button.add_theme_stylebox_override(&"hover", ModalTheme.button_box(true))
	button.add_theme_stylebox_override(&"pressed", ModalTheme.button_box(true))
	button.add_theme_stylebox_override(&"focus", ModalTheme.empty_box())
	button.add_theme_font_override(&"font", ModalTheme.sans())
	button.add_theme_font_size_override(&"font_size", 9)
	button.add_theme_color_override(&"font_color",
			ModalTheme.AMBER if active else ModalTheme.LABEL)
	button.add_theme_color_override(&"font_hover_color", ModalTheme.AMBER)
	button.add_theme_color_override(&"font_pressed_color", ModalTheme.AMBER)


func _style_solo_button(button: Button, active: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = ModalTheme.ROW_SELECTED if active else ModalTheme.BUTTON_FILL
	box.set_border_width_all(1)
	box.border_color = ModalTheme.BUTTON_ON_BORDER if active else ModalTheme.PANEL_BORDER
	box.set_corner_radius_all(3)
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	button.add_theme_stylebox_override(&"normal", box)
	button.add_theme_stylebox_override(&"hover", box)
	button.add_theme_stylebox_override(&"pressed", box)
	button.add_theme_stylebox_override(&"focus", ModalTheme.empty_box())
	button.add_theme_font_override(&"font", ModalTheme.mono())
	button.add_theme_font_size_override(&"font_size", 8)
	button.add_theme_color_override(&"font_color",
			ModalTheme.AMBER if active else ModalTheme.MUTED)
	button.add_theme_color_override(&"font_hover_color", ModalTheme.TEXT)


func _style_action_button(button: Button, primary: bool) -> void:
	if primary:
		button.add_theme_stylebox_override(&"normal", ModalTheme.action_box(false))
		button.add_theme_stylebox_override(&"hover", ModalTheme.action_box(true))
		button.add_theme_stylebox_override(&"pressed", ModalTheme.action_box(true))
		button.add_theme_color_override(&"font_color", ModalTheme.TEXT)
	else:
		button.add_theme_stylebox_override(&"normal", ModalTheme.button_box(false))
		button.add_theme_stylebox_override(&"hover", ModalTheme.button_box(true))
		button.add_theme_stylebox_override(&"pressed", ModalTheme.button_box(true))
		button.add_theme_color_override(&"font_color", ModalTheme.TEXT_DIM)
		button.add_theme_color_override(&"font_hover_color", ModalTheme.TEXT)
	button.add_theme_stylebox_override(&"focus", ModalTheme.empty_box())
	button.add_theme_font_override(&"font", ModalTheme.sans())
	button.add_theme_font_size_override(&"font_size", 9)


func _style_option_button(menu: OptionButton) -> void:
	menu.add_theme_stylebox_override(&"normal", ModalTheme.button_box(false))
	menu.add_theme_stylebox_override(&"hover", ModalTheme.button_box(true))
	menu.add_theme_stylebox_override(&"pressed", ModalTheme.button_box(true))
	menu.add_theme_stylebox_override(&"focus", ModalTheme.empty_box())
	menu.add_theme_font_override(&"font", ModalTheme.mono())
	menu.add_theme_font_size_override(&"font_size", 10)
	menu.add_theme_color_override(&"font_color", ModalTheme.TEXT)
	menu.focus_mode = Control.FOCUS_NONE
	menu.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#191c18")
	track.set_corner_radius_all(2)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	slider.add_theme_stylebox_override(&"slider", track)

	var filled := StyleBoxFlat.new()
	filled.bg_color = ModalTheme.AMBER
	filled.set_corner_radius_all(2)
	slider.add_theme_stylebox_override(&"grabber_area", filled)
	slider.add_theme_stylebox_override(&"grabber_area_highlight", filled)
	slider.add_theme_stylebox_override(&"focus", ModalTheme.empty_box())
