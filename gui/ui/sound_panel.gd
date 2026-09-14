@tool
class_name SoundPanel
extends Control

## The front of the machine.
##
## `ModalFitPanel` is the service panel — every threshold, every rejected
## candidate, the spectrogram. This is what the machine looks like from the
## front: pick a sound, shape the object, save it. Two screens over one
## `FitState`, so a change made here is what the analysis screen inspects.
##
## Three controls shape the object and one says how hard you hit it, and that
## split is the point rather than a tidying: size, ring and striker are
## properties of the thing and go into the `.modal` file; hit strength is a
## performance parameter the physics engine supplies at runtime and is never
## saved. A panel that mixed them would teach the wrong model of the system.

const COLUMN_GAP := 14

var state: FitState

var _preset_list: PresetList
var _size: LabelledSlider
var _ring: LabelledSlider
var _striker: LabelledSlider
var _hit: LabelledSlider
var _waveform: WaveformView
var _readouts := {}
var _reset_button: Button
var _save_dialog: FileDialog
var _open_dialog: FileDialog
var _model_entries: Array[Dictionary] = []
var _audition: Audition
var _strike_button: Button


func bind(new_state: FitState) -> void:
	if state != null and state.changed.is_connected(_refresh):
		state.changed.disconnect(_refresh)
	state = new_state
	if state != null:
		state.changed.connect(_refresh)
	if _waveform != null:
		_waveform.state = state
	_refresh()


func _ready() -> void:
	_audition = Audition.new()
	add_child(_audition)
	_audition.rendered.connect(_on_rendered)
	_build()
	if state != null:
		_refresh()


## Space strikes the object, the way a sampler's audition key does. Nothing
## else on this screen takes a keypress, so there is nothing to steal it from.
func _shortcut_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo \
			and (event as InputEventKey).keycode == KEY_SPACE:
		_strike()
		get_viewport().set_input_as_handled()


func _strike() -> void:
	if _audition != null and state != null and state.is_loaded():
		_audition.strike(state)


func _on_rendered(_samples: PackedFloat32Array, milliseconds: float) -> void:
	# Render cost is worth showing rather than hiding: it is the number that
	# decides whether this stays GDScript or becomes part of the GDExtension.
	# Zero means the cache answered, which is the common case.
	_readouts["render_cost"].text = ("synthesised in %.0f ms" % milliseconds
			if milliseconds > 0.0 else "replayed from cache")


# --- construction ------------------------------------------------------------

func _build() -> void:
	var gutter := MarginContainer.new()
	gutter.set_anchors_preset(Control.PRESET_FULL_RECT)
	gutter.add_theme_constant_override(&"margin_left", 22)
	gutter.add_theme_constant_override(&"margin_right", 22)
	gutter.add_theme_constant_override(&"margin_top", 4)
	gutter.add_theme_constant_override(&"margin_bottom", 28)
	add_child(gutter)

	var columns := HFlowContainer.new()
	columns.add_theme_constant_override(&"h_separation", COLUMN_GAP)
	columns.add_theme_constant_override(&"v_separation", COLUMN_GAP)
	gutter.add_child(columns)

	columns.add_child(_build_preset_column())
	columns.add_child(_build_object_column())


func _build_preset_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 292
	column.add_theme_constant_override(&"separation", COLUMN_GAP)

	var module := PanelModule.new()
	module.title = "Sound"
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 11)
	module.add_child(body)

	_preset_list = PresetList.new()
	_preset_list.chosen.connect(_on_preset_chosen)
	body.add_child(_preset_list)

	var open := Button.new()
	open.text = "OPEN A .MODAL FILE…"
	open.focus_mode = Control.FOCUS_NONE
	open.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	open.pressed.connect(_on_open_pressed)
	_style_button(open, false)
	body.add_child(open)

	body.add_child(_caption(
		"Presets are the .modal files in models/. Every object you fit with "
		+ "modal-fit appears here too."))
	column.add_child(module)
	return column


func _build_object_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 620
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", COLUMN_GAP)

	column.add_child(_build_sound_module())
	column.add_child(_build_shape_module())
	column.add_child(_build_hit_module())
	return column


func _build_sound_module() -> Control:
	var module := PanelModule.new()
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 10)
	module.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 12)
	_readouts["name"] = _label("", 17, ModalTheme.TEXT, ModalTheme.mono_bold(), 3.0)
	header.add_child(_readouts["name"])
	_readouts["tweak"] = _label("", 9, ModalTheme.AMBER, ModalTheme.mono(), 0.6)
	_readouts["tweak"].size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(_readouts["tweak"])
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_readouts["modes"] = _label("", 9, ModalTheme.MUTED, ModalTheme.mono(), 0.8)
	_readouts["modes"].size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(_readouts["modes"])
	body.add_child(header)

	_readouts["sentence"] = _label("", 11, ModalTheme.TEXT_DIM, ModalTheme.mono(), 0.4)
	_readouts["sentence"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_readouts["sentence"])

	var well := GlassWell.new()
	well.deep = true
	well.inset_content = false
	_waveform = WaveformView.new()
	_waveform.state = state
	_waveform.custom_minimum_size.y = 150
	_waveform.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	well.add_child(_waveform)
	body.add_child(well)

	_readouts["hint"] = _caption("", 9)
	body.add_child(_readouts["hint"])

	# Warnings from the tweak — modes lost off the top of the band, decays
	# hitting the format's limit. Silence when there is nothing to say.
	_readouts["warning"] = _label("", 9, ModalTheme.RED, ModalTheme.mono(), 0.3)
	_readouts["warning"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_readouts["warning"])
	return module


func _build_shape_module() -> Control:
	var module := PanelModule.new()
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 14)
	module.add_child(body)

	var header := HBoxContainer.new()
	header.add_child(_label("SHAPE THE OBJECT", 8, ModalTheme.LABEL, ModalTheme.sans(), 2.4))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_reset_button = Button.new()
	_reset_button.text = "RESET"
	_reset_button.focus_mode = Control.FOCUS_NONE
	_reset_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_reset_button.pressed.connect(func() -> void: state.reset_tweak())
	_style_small_button(_reset_button)
	header.add_child(_reset_button)
	body.add_child(header)

	var faders := HFlowContainer.new()
	faders.add_theme_constant_override(&"h_separation", 20)
	faders.add_theme_constant_override(&"v_separation", 14)

	_size = LabelledSlider.new()
	_size.custom_minimum_size.x = 180
	_size.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faders.add_child(_size)
	_size.setup("Size", "larger", "smaller",
			ModelTweak.SIZE_MIN, ModelTweak.SIZE_MAX, 0.01, 1.0)
	_size.value_changed.connect(_on_tweak_changed)
	_size.drag_ended.connect(func() -> void: _strike())

	_ring = LabelledSlider.new()
	_ring.custom_minimum_size.x = 180
	_ring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faders.add_child(_ring)
	_ring.setup("Ring", "dead", "ringing",
			ModelTweak.RING_MIN, ModelTweak.RING_MAX, 0.01, 1.0)
	_ring.value_changed.connect(_on_tweak_changed)
	_ring.drag_ended.connect(func() -> void: _strike())

	_striker = LabelledSlider.new()
	_striker.custom_minimum_size.x = 180
	_striker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faders.add_child(_striker)
	_striker.setup("Striker", "hard, small", "soft",
			ModelTweak.STRIKER_MIN, ModelTweak.STRIKER_MAX, 0.005, 0.15)
	_striker.value_changed.connect(_on_tweak_changed)
	_striker.drag_ended.connect(func() -> void: _strike())

	body.add_child(faders)
	body.add_child(_caption(
		"Size moves every frequency together, so the object changes scale without "
		+ "changing material. Ring is how damped it is. Striker is what you hit it "
		+ "with — a pen cap or a rubber mallet. All three are saved into the file."))

	var save := Button.new()
	save.text = "SAVE AS A NEW SOUND…"
	save.focus_mode = Control.FOCUS_NONE
	save.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	save.pressed.connect(_on_save_pressed)
	_style_button(save, true)
	body.add_child(save)
	return module


func _build_hit_module() -> Control:
	var module := PanelModule.new()
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 10)
	module.add_child(body)

	_hit = LabelledSlider.new()
	body.add_child(_hit)
	_hit.setup("How hard you hit it", "a nudge", "a hard knock",
			VelocityCurveView.VELOCITY_MIN, VelocityCurveView.VELOCITY_MAX, 0.05, 2.0)
	# Moving the fader strikes, so the timbre change is something you hear
	# rather than read off a centroid. Released rather than continuously, or
	# dragging would fire a strike every frame.
	_hit.value_changed.connect(func(v: float) -> void: state.set_velocity(v))
	_hit.drag_ended.connect(func() -> void: _strike())

	var strike_row := HBoxContainer.new()
	strike_row.add_theme_constant_override(&"separation", 12)
	_strike_button = Button.new()
	_strike_button.text = "STRIKE  ·  SPACE"
	_strike_button.focus_mode = Control.FOCUS_NONE
	_strike_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_strike_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strike_button.pressed.connect(_strike)
	_style_button(_strike_button, true)
	strike_row.add_child(_strike_button)
	_readouts["render_cost"] = _label("", 8, ModalTheme.MUTED, ModalTheme.mono(), 0.4)
	_readouts["render_cost"].size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strike_row.add_child(_readouts["render_cost"])
	body.add_child(strike_row)

	body.add_child(_caption(
		"Not saved. In a game this comes from the collision, every time — which is "
		+ "why the same object never sounds quite the same twice. Every strike here "
		+ "is synthesised from the model, not a recording played back."))
	return module


# --- presets -----------------------------------------------------------------

## Rebuilds the preset rows, loading each file to describe it. Called when the
## screen is bound and after a save, which is rare enough that reading a
## handful of small JSON files costs nothing worth optimising.
func refresh_presets(paths: PackedStringArray) -> void:
	_model_entries.clear()
	for path in paths:
		var model := ModalModel.load_from_file(path, state.sample_rate)
		var entry := {"path": path, "name": _pretty_name(path)}
		if model.ok:
			# Described at a mid-range strike, so the summary is the object
			# rather than the object at whatever the slider happens to be on.
			var gains := model.gains_at(-1)
			var centroid := Excitation.spectral_centroid(model,
					Excitation.mode_amplitudes(model, 2.0, gains, state.sample_rate))
			entry["summary"] = SoundWords.summary(model, centroid)
		else:
			entry["summary"] = model.error
			entry["broken"] = true
		_model_entries.append(entry)
	_preset_list.set_entries(_model_entries, state.model_path)


static func _pretty_name(path: String) -> String:
	return path.get_file().get_basename().replace("_", " ").capitalize()


## Picking a sound plays it. Browsing a sound library by reading descriptions
## is not browsing; this is the behaviour every sampler has had since the
## machines this panel is dressed as.
func _on_preset_chosen(path: String) -> void:
	state.load_model(path)
	_preset_list.set_entries(_model_entries, state.model_path)
	_strike()


func _on_tweak_changed(_value: float) -> void:
	state.set_tweak(_size.value(), _ring.value(), _striker.value())


# --- files -------------------------------------------------------------------

func _on_open_pressed() -> void:
	if _open_dialog == null:
		_open_dialog = FileDialog.new()
		_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_open_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_open_dialog.filters = PackedStringArray(["*.modal ; Modal model"])
		_open_dialog.size = Vector2i(720, 480)
		_open_dialog.file_selected.connect(func(path: String) -> void:
			state.load_model(path)
			var paths := PackedStringArray()
			for entry in _model_entries:
				paths.append(str(entry.get("path", "")))
			if not paths.has(path):
				paths.append(path)
			refresh_presets(paths))
		add_child(_open_dialog)
	_open_dialog.popup_centered()


func _on_save_pressed() -> void:
	if not state.is_loaded():
		return
	if _save_dialog == null:
		_save_dialog = FileDialog.new()
		_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_save_dialog.filters = PackedStringArray(["*.modal ; Modal model"])
		_save_dialog.size = Vector2i(720, 480)
		_save_dialog.file_selected.connect(_on_save_chosen)
		add_child(_save_dialog)
	_save_dialog.current_dir = ModelLibrary.default_save_directory(state.model_path)
	_save_dialog.current_file = "%s_variant.modal" % state.preset.name
	_save_dialog.popup_centered()


func _on_save_chosen(path: String) -> void:
	var name := path.get_file().get_basename()
	# The provenance line matters: a variant is not a fit, and six months later
	# nobody will remember which files came off a recording and which came off
	# a fader.
	var note := "tweaked from %s" % state.preset.name
	var tweak := ModelTweak.describe(state.size_factor, state.ring_factor, state.striker_ms,
			state.preset.material.contact_time_ref_ms)
	if not tweak.is_empty():
		note += " · " + tweak
	var error := ModelTweak.save(state.model, path, name, note)
	if not error.is_empty():
		_readouts["warning"].text = error
		return

	var paths := PackedStringArray()
	for entry in _model_entries:
		paths.append(str(entry.get("path", "")))
	if not paths.has(path):
		paths.append(path)
	state.load_model(path)
	refresh_presets(paths)


# --- refresh -----------------------------------------------------------------

func _refresh() -> void:
	if state == null or _size == null:
		return

	# The analysis screen can change the model too, so the highlighted row is
	# refreshed from the state rather than only on click.
	if _preset_list != null:
		_preset_list.set_entries(_model_entries, state.model_path)

	_size.set_value_silently(state.size_factor)
	_ring.set_value_silently(state.ring_factor)
	_striker.set_value_silently(state.striker_ms)
	_hit.set_value_silently(state.velocity)

	if not state.is_loaded():
		_readouts["name"].text = "NO SOUND LOADED"
		_readouts["sentence"].text = ""
		_readouts["modes"].text = ""
		_readouts["tweak"].text = ""
		_readouts["hint"].text = ""
		_readouts["warning"].text = state.model.error if state.model != null else ""
		return

	var model := state.model
	_readouts["name"].text = _pretty_name(state.model_path).to_upper()
	_readouts["sentence"].text = SoundWords.sentence(model, state.centroid)
	_readouts["modes"].text = "%d modes · %s" % [model.modes.size(), state.duration_label()]

	var tweak := ModelTweak.describe(state.size_factor, state.ring_factor, state.striker_ms,
			state.preset.material.contact_time_ref_ms)
	_readouts["tweak"].text = ("· " + tweak) if not tweak.is_empty() else ""
	_reset_button.disabled = tweak.is_empty()

	# The two ends of the hit fader, so the hint describes this object rather
	# than the general principle.
	var low := state.centroid_at(VelocityCurveView.VELOCITY_MIN)
	var high := state.centroid_at(VelocityCurveView.VELOCITY_MAX)
	var clamp := Excitation.clamp_velocity(state.striker_ms)
	_readouts["hint"].text = SoundWords.velocity_hint(model, low, high, clamp,
			VelocityCurveView.VELOCITY_MAX)
	# An object that no longer responds to velocity is the failure the whole
	# engine is built to avoid, so it is not left in caption grey.
	_readouts["hint"].add_theme_color_override(&"font_color",
			ModalTheme.RED if SoundWords.is_flat(low, high) else ModalTheme.MUTED)
	_readouts["warning"].text = _tweak_warning(model)

	# Readouts in the units the control is actually in.
	_size.set_readout("%d Hz" % roundi(SoundWords.fundamental(model)))
	_ring.set_readout("%.2f s" % SoundWords.longest_decay(model))
	_striker.set_readout("%.2f ms" % state.striker_ms)
	_hit.set_readout("%.2f m/s" % state.velocity)


## What a tweak has cost the object, in the screen's own language.
##
## The loader's wording — "dropped mode 11 at 22534.5 Hz: outside 20 to 21600
## Hz at this sample rate" — is correct and belongs on Analysis. Here it is
## noise: it names an index the user has never seen, in units they did not ask
## for, about a decision the file made before they touched anything. Only what
## *their* controls caused is worth saying, and only as a consequence.
func _tweak_warning(model: ModalModel) -> String:
	if model.tweak_warnings.is_empty():
		return ""
	var dropped := 0
	var clamped := false
	for warning in model.tweak_warnings:
		if warning.begins_with("dropped mode"):
			dropped += 1
		else:
			clamped = true

	var parts: PackedStringArray = []
	if dropped > 0:
		# Shrinking pushes the top modes past what the sample rate can carry.
		parts.append("%d %s too high to play at this size, so the object has lost some of its top end. Make it larger to get them back." % [
			dropped, "mode is" if dropped == 1 else "modes are"])
	if clamped:
		parts.append("Some decays have hit the longest the format allows.")
	return " ".join(parts)


# --- small builders ----------------------------------------------------------

func _label(text: String, size: int, colour: Color, font: Font, tracking: float) -> Label:
	var variation := FontVariation.new()
	variation.base_font = font
	variation.spacing_glyph = int(round(tracking))
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(&"font", variation)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", colour)
	return label


func _caption(text: String, size := 9) -> Label:
	var label := _label(text, size, ModalTheme.MUTED, ModalTheme.mono(), 0.3)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _style_button(button: Button, primary: bool) -> void:
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


func _style_small_button(button: Button) -> void:
	_style_button(button, false)
	button.add_theme_font_size_override(&"font_size", 8)
