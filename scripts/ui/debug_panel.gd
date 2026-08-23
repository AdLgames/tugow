class_name DebugPanel
extends PanelContainer
## The mock's "Layers & light" lab panel, ported for dev builds only. F3
## toggles it; OS.is_debug_build() keeps it out of a release export entirely.
##
## Source: docs/design-system/ui_kits/thirteen_boxes/table_scene.html, #tweaks.

var scene: SaloonView


func _init(p_scene: SaloonView) -> void:
	scene = p_scene
	position = Vector2(1560, 560)
	custom_minimum_size = Vector2(336, 0)
	add_theme_stylebox_override("panel", ThemeColors.panel_style())


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	_heading(column, "LAYERS & LIGHT  (F3)")
	for key in [&"backdrop", &"foe", &"table", &"lip", &"lamp", &"vignette", &"grain"]:
		var check := CheckBox.new()
		check.text = String(key)
		check.button_pressed = scene.layers[key]
		check.toggled.connect(func(on: bool) -> void:
			scene.layers[key] = on
			scene.queue_redraw())
		column.add_child(check)

	_heading(column, "SURFACE")
	var oak := CheckBox.new()
	oak.text = "dark oak"
	oak.toggled.connect(func(on: bool) -> void:
		scene.dark_oak = on
		scene.queue_redraw())
	column.add_child(oak)

	# Known issue #1 in the brief: the shipped mock still had 144, which is
	# past edge-on. 58 is the settled value and the default here.
	_slider(column, "camera pitch", 40.0, 84.0, scene.projection.pitch_degrees,
		func(v: float) -> void:
			scene.projection.pitch_degrees = v
			scene.queue_redraw())
	_slider(column, "left lantern", 0.0, 1.4, scene.lamp_left,
		func(v: float) -> void: scene.lamp_left = v)
	_slider(column, "right lantern", 0.0, 1.4, scene.lamp_right,
		func(v: float) -> void: scene.lamp_right = v)
	_slider(column, "vignette", 0.0, 1.0, scene.vignette_weight,
		func(v: float) -> void: scene.vignette_weight = v)
	_slider(column, "grain", 0.0, 0.30, scene.grain_weight,
		func(v: float) -> void: scene.grain_weight = v)

	var flick := CheckBox.new()
	flick.text = "flicker + sway"
	flick.button_pressed = scene.flicker
	flick.toggled.connect(func(on: bool) -> void: scene.flicker = on)
	column.add_child(flick)


func _heading(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", ThemeColors.INK)
	parent.add_child(label)


func _slider(parent: Node, label_text: String, from: float, to: float,
		value: float, on_change: Callable) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", ThemeColors.INK_DIM)
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = from
	slider.max_value = to
	slider.step = (to - from) / 100.0
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 18)
	slider.value_changed.connect(on_change)
	parent.add_child(slider)
