@tool
extends EditorPlugin

## The editor shell.
##
## The standalone application and this plugin instantiate the same scene; all
## that differs is who owns the window. Keeping the panel free of any editor
## API is what makes that possible, so nothing below leaks `EditorInterface`
## into the panel itself.

const PANEL := preload("res://ui/app_shell.tscn")

var _panel: Control


func _enter_tree() -> void:
	_panel = PANEL.instantiate()
	# The main screen hands out its own sizing; the panel must not fight it.
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	EditorInterface.get_editor_main_screen().add_child(_panel)
	_make_visible(false)


func _exit_tree() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if is_instance_valid(_panel):
		_panel.visible = visible


func _get_plugin_name() -> String:
	return "Modal Fit"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(&"AudioStreamPlayer", &"EditorIcons")
