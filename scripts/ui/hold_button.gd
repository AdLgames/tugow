class_name HoldButton
extends Button
## A button you must mean. Settling a line ends the run's access to it, so the
## commit is a press-and-hold rather than a click a player can fire through
## reflexively.

signal held()

const HOLD_SECONDS := 0.45

var _progress: float = 0.0


func _init(label: String = "") -> void:
	text = label
	custom_minimum_size = Vector2(0, 40)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle_mode = false
	set_process(false)
	button_down.connect(func(): set_process(true))
	button_up.connect(_cancel)
	mouse_exited.connect(_cancel)


func _cancel() -> void:
	_progress = 0.0
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_progress += delta / HOLD_SECONDS
	if _progress >= 1.0:
		_progress = 0.0
		set_process(false)
		queue_redraw()
		held.emit()
		return
	queue_redraw()


func _draw() -> void:
	if _progress <= 0.0:
		return
	draw_rect(Rect2(0, size.y - 4, size.x * _progress, 4), ThemeColors.LOCKED, true)
