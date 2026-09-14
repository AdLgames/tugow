@tool
class_name AppShell
extends Control

## The machine, with its two faces.
##
## **Sounds** is the front panel: pick an object, shape it, save it. It is what
## opens, because most of the time the question is "what does a crate sound
## like" and not "what is the R² of mode 7".
##
## **Analysis** is the service panel underneath — the five fit stages, the mode
## table, every threshold. It was the first screen built and it is still the
## one that proves the engine is doing what it claims; it just is not where
## someone starts.
##
## One `FitState` between them. A size change made on the front panel is what
## the spectrogram redraws, which is the whole reason to keep them in one
## application rather than shipping two tools.

const HEADER_HEIGHT := 78

enum Screen { SOUNDS, ANALYSIS }

var state := FitState.new()

var _sound_panel: SoundPanel
var _analysis_panel: ModalFitPanel
var _tabs: Array[Button] = []
var _screen: Screen = Screen.SOUNDS


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_load_first_model()
	_show(Screen.SOUNDS)


func _build() -> void:
	var backdrop := Backdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override(&"separation", 0)
	add_child(page)

	page.add_child(_build_header())

	# Both screens are built up front and kept: the analysis panel does real
	# work on construction, and rebuilding it every time someone glances at a
	# spectrogram would make the tab feel broken.
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(stack)

	_sound_panel = SoundPanel.new()
	_sound_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_sound_panel)
	_sound_panel.bind(state)

	_analysis_panel = ModalFitPanel.new()
	_analysis_panel.state = state
	_analysis_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_analysis_panel)


func _build_header() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 22)
	margin.add_theme_constant_override(&"margin_right", 22)
	margin.add_theme_constant_override(&"margin_top", 24)
	margin.add_theme_constant_override(&"margin_bottom", 14)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 20)
	margin.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override(&"separation", 8)
	left.add_child(_tracked("PROCEDURAL CONTACT AUDIO · FITTING STATION", 9,
			ModalTheme.LABEL, 3.2, ModalTheme.sans()))
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override(&"separation", 12)
	title_row.add_child(_tracked("MODAL FIT", 25, ModalTheme.TEXT, 4.0, ModalTheme.mono_bold()))
	var unit := _tracked("MF·1000", 10, ModalTheme.MUTED, 2.0, ModalTheme.mono())
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(unit)
	left.add_child(title_row)
	row.add_child(left)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 6)
	tabs.size_flags_vertical = Control.SIZE_SHRINK_END
	for screen in [Screen.SOUNDS, Screen.ANALYSIS]:
		var button := Button.new()
		button.text = "SOUNDS" if screen == Screen.SOUNDS else "ANALYSIS"
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_show.bind(screen))
		_tabs.append(button)
		tabs.add_child(button)
	row.add_child(tabs)
	return margin


func _show(screen: Screen) -> void:
	_screen = screen
	_sound_panel.visible = screen == Screen.SOUNDS
	_analysis_panel.visible = screen == Screen.ANALYSIS
	for i in _tabs.size():
		_style_tab(_tabs[i], i == int(screen))


## Opens whatever the library found first, so the application never starts on
## an empty screen when there are sounds available.
func _load_first_model() -> void:
	var paths := ModelLibrary.discover()
	if paths.size() > 0:
		state.load_model(paths[0])
	_sound_panel.refresh_presets(paths)
	_analysis_panel.set_library(paths)


func _tracked(text: String, size: int, colour: Color, tracking: float, font: Font) -> Label:
	var variation := FontVariation.new()
	variation.base_font = font
	variation.spacing_glyph = int(round(tracking))
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(&"font", variation)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", colour)
	return label


func _style_tab(button: Button, active: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = (ModalTheme.BUTTON_ON_TOP.lerp(ModalTheme.BUTTON_ON_BOTTOM, 0.5) if active
			else ModalTheme.BUTTON_FILL)
	box.set_border_width_all(1)
	box.border_color = ModalTheme.BUTTON_ON_BORDER if active else ModalTheme.PANEL_BORDER
	box.set_corner_radius_all(3)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	button.add_theme_stylebox_override(&"normal", box)
	button.add_theme_stylebox_override(&"hover", box)
	button.add_theme_stylebox_override(&"pressed", box)
	button.add_theme_stylebox_override(&"focus", ModalTheme.empty_box())
	button.add_theme_font_override(&"font", ModalTheme.sans())
	button.add_theme_font_size_override(&"font_size", 9)
	button.add_theme_color_override(&"font_color",
			ModalTheme.AMBER if active else ModalTheme.LABEL)
	button.add_theme_color_override(&"font_hover_color", ModalTheme.AMBER)
