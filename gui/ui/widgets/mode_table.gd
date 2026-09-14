@tool
class_name ModeTable
extends VBoxContainer

## The mode list: frequency, decay, live amplitude, one row per mode.
##
## The bar is not the model's stored amplitude — it is the amplitude at the
## velocity and strike currently selected, which is the model's amplitude times
## the strike gain times how much of that mode the contact pulse reaches. That
## is why the bars redraw when the slider moves, and why the top mode is not
## always mode 0.
##
## Clicking a row solos it. Every plot follows, which is the only way to see
## which of fourteen overlapping decay curves belongs to which frequency.

signal solo_toggled(index: int)

const ROW_HEIGHT := 34

var state: FitState
var _rows: Array[Control] = []
var _list: VBoxContainer


func _ready() -> void:
	add_theme_constant_override(&"separation", 6)
	_build_header()
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 2)
	add_child(_list)
	refresh()


func bind(new_state: FitState) -> void:
	if state != null and state.changed.is_connected(refresh):
		state.changed.disconnect(refresh)
	state = new_state
	if state != null:
		state.changed.connect(refresh)
	refresh()


func _build_header() -> void:
	var header := Control.new()
	header.custom_minimum_size.y = 16
	header.draw.connect(_draw_header.bind(header))
	add_child(header)


func _draw_header(header: Control) -> void:
	var font := ModalTheme.mono()
	var columns := _column_positions(header.size.x)
	DrawUtil.tracked_text(header, font, 8, Vector2(8.0, 8.0), "#", ModalTheme.MUTED, 1.1)
	var labels := ["f Hz", "τ s", "a"]
	for i in labels.size():
		var width := DrawUtil.tracked_width(font, 8, labels[i], 1.1)
		DrawUtil.tracked_text(header, font, 8, Vector2(columns[i + 1] - width, 8.0),
				labels[i], ModalTheme.MUTED, 1.1)
	header.draw_line(Vector2(0, header.size.y - 1.0), Vector2(header.size.x, header.size.y - 1.0),
			ModalTheme.RULE, 1.0)


## Right edges of the four columns: index, frequency, tau, amplitude.
static func _column_positions(width: float) -> PackedFloat32Array:
	var index_width := 22.0
	var remaining := maxf(width - index_width - 16.0, 30.0)
	var step := remaining / 3.0
	return PackedFloat32Array([
		8.0 + index_width,
		8.0 + index_width + step,
		8.0 + index_width + step * 2.0,
		8.0 + index_width + step * 3.0,
	])


func refresh() -> void:
	if _list == null:
		return
	var count := state.mode_count() if state != null else 0

	# Rows are reused rather than rebuilt: with the velocity slider dragging,
	# rebuilding fourteen rows a frame churns the scene tree for no reason.
	while _rows.size() > count:
		var row: Control = _rows.pop_back()
		_list.remove_child(row)
		row.queue_free()
	while _rows.size() < count:
		var index := _rows.size()
		var row := Control.new()
		row.custom_minimum_size.y = ROW_HEIGHT
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.draw.connect(_draw_row.bind(row, index))
		row.gui_input.connect(_on_row_input.bind(index))
		_list.add_child(row)
		_rows.append(row)

	for row in _rows:
		row.queue_redraw()


func _on_row_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton \
			and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		solo_toggled.emit(index)


func _draw_row(row: Control, index: int) -> void:
	if state == null or index >= state.mode_count():
		return
	var mode: ModalModel.Mode = state.model.modes[index]
	var selected := state.solo == index
	var dimmed := not state.is_visible_mode(index)
	var level := state.normalised(index)

	row.draw_style_box(ModalTheme.row_box(selected, dimmed), Rect2(Vector2.ZERO, row.size))

	var font := ModalTheme.mono()
	var alpha := 0.45 if dimmed else 1.0
	var columns := _column_positions(row.size.x)
	var baseline := 16.0

	DrawUtil.text(row, font, 10, Vector2(8.0, baseline), str(index),
			_fade(ModalTheme.LABEL_FAINT, alpha))
	_draw_right(row, font, columns[1], baseline, "%.1f" % mode.f, _fade(Color("#e8e3d7"), alpha))
	_draw_right(row, font, columns[2], baseline, "%.3f" % mode.tau, _fade(ModalTheme.TEXT_DIM, alpha))
	_draw_right(row, font, columns[3], baseline, "%.3f" % level, _fade(ModalTheme.TEXT_DIM, alpha))

	# The live amplitude bar.
	var track := Rect2(8.0, row.size.y - 10.0, row.size.x - 16.0, 3.0)
	row.draw_rect(track, Color("#191c18"), true)
	var fill := track
	fill.size.x = track.size.x * clampf(level, 0.0, 1.0)
	if fill.size.x > 0.0:
		row.draw_rect(fill, _fade(ModalTheme.AMBER if not dimmed else ModalTheme.TRACE_OFF, alpha), true)


static func _draw_right(canvas: CanvasItem, font: Font, right: float, baseline: float,
		content: String, colour: Color) -> void:
	DrawUtil.text(canvas, font, 10, Vector2(right, baseline), content, colour, DrawUtil.Anchor.RIGHT)


static func _fade(colour: Color, alpha: float) -> Color:
	return Color(colour.r, colour.g, colour.b, colour.a * alpha)
