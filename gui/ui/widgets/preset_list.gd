@tool
class_name PresetList
extends VBoxContainer

## The sounds you can start from.
##
## Each row is a `.modal` file with its name and, underneath, what it sounds
## like in three words derived from the file itself. The description is the
## reason this is a list of rows rather than a dropdown: choosing between
## "ceramic_mug" and "steel_pipe" by filename is guesswork, and the whole point
## of the simple screen is not having to open a model to find out what it is.

signal chosen(path: String)

const ROW_HEIGHT := 46

var _entries: Array[Dictionary] = []
var _selected := -1


## `entries` is a list of {path, name, summary}. Summaries are computed by the
## caller, which is the only thing holding a sample rate.
func set_entries(entries: Array[Dictionary], selected_path: String) -> void:
	_entries = entries
	_selected = -1
	for i in entries.size():
		if entries[i].get("path", "") == selected_path:
			_selected = i
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	add_theme_constant_override(&"separation", 3)

	if _entries.is_empty():
		var empty := Label.new()
		empty.text = "no .modal files found"
		empty.add_theme_font_override(&"font", ModalTheme.mono())
		empty.add_theme_font_size_override(&"font_size", 9)
		empty.add_theme_color_override(&"font_color", ModalTheme.MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(empty)
		return

	for i in _entries.size():
		var row := Control.new()
		row.custom_minimum_size.y = ROW_HEIGHT
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.draw.connect(_draw_row.bind(row, i))
		row.gui_input.connect(_on_row_input.bind(i))
		add_child(row)


func _on_row_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton \
			and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(str(_entries[index].get("path", "")))


func _draw_row(row: Control, index: int) -> void:
	if index >= _entries.size():
		return
	var entry := _entries[index]
	var selected := index == _selected
	row.draw_style_box(ModalTheme.row_box(selected, false), Rect2(Vector2.ZERO, row.size))

	# A preset the file no longer parses still gets a row, in red, rather than
	# vanishing — a model that stopped loading is something to be told about.
	var broken := bool(entry.get("broken", false))
	var title_colour := ModalTheme.AMBER if selected else ModalTheme.TEXT
	if broken:
		title_colour = ModalTheme.RED

	DrawUtil.text(row, ModalTheme.mono_bold(), 11, Vector2(10.0, 19.0),
			str(entry.get("name", "")), title_colour)
	DrawUtil.text(row, ModalTheme.mono(), 8, Vector2(10.0, 34.0),
			str(entry.get("summary", "")), ModalTheme.MUTED)

	if selected:
		row.draw_rect(Rect2(0.0, 0.0, 2.0, row.size.y), ModalTheme.AMBER, true)
