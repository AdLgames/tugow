@tool
class_name LabelledSlider
extends VBoxContainer

## One front-panel fader: a name, the value it is currently at, the fader, and
## what the two ends mean.
##
## The end labels are the part that matters. "0.5 … 2.0" tells a sound designer
## nothing; "larger … smaller" tells them which way to push. The numeric value
## still sits on the right, because once someone knows what the control does
## they want the number back.

signal value_changed(value: float)

var _title: Label
var _value: Label
var _slider: HSlider
var _low: Label
var _high: Label


func setup(title: String, low: String, high: String, minimum: float, maximum: float,
		step: float, start: float) -> void:
	add_theme_constant_override(&"separation", 6)

	var header := HBoxContainer.new()
	_title = _label(title.to_upper(), 8, ModalTheme.LABEL, ModalTheme.sans(), 2.4)
	header.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_value = _label("", 12, ModalTheme.AMBER, ModalTheme.mono_bold(), 0.6)
	header.add_child(_value)
	add_child(header)

	_slider = HSlider.new()
	_slider.min_value = minimum
	_slider.max_value = maximum
	_slider.step = step
	_slider.value = start
	_slider.custom_minimum_size.y = 22
	_slider.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.value_changed.connect(func(v: float) -> void: value_changed.emit(v))
	_style(_slider)
	add_child(_slider)

	var ends := HBoxContainer.new()
	_low = _label(low, 8, ModalTheme.MUTED, ModalTheme.mono(), 0.8)
	_low.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ends.add_child(_low)
	_high = _label(high, 8, ModalTheme.MUTED, ModalTheme.mono(), 0.8)
	_high.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_high.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ends.add_child(_high)
	add_child(ends)


func value() -> float:
	return _slider.value if _slider != null else 0.0


## Moves the fader without emitting — for when the state changed elsewhere,
## such as a preset being loaded or the tweak being reset.
func set_value_silently(value: float) -> void:
	if _slider == null or is_equal_approx(_slider.value, value):
		return
	_slider.set_block_signals(true)
	_slider.value = value
	_slider.set_block_signals(false)


func set_readout(text: String) -> void:
	if _value != null:
		_value.text = text


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


func _style(slider: HSlider) -> void:
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
