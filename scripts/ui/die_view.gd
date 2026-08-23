class_name DieView
extends Button
## One die on the table. Click to lock it — for the whole floor, not the turn.

var die: Die


func _init() -> void:
	custom_minimum_size = Vector2(92, 104)
	focus_mode = Control.FOCUS_NONE
	clip_text = true
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func bind(p_die: Die) -> void:
	die = p_die
	refresh()


func refresh() -> void:
	if die == null:
		return
	var tags: Array[String] = []
	if die.locked:
		tags.append("LOCKED")
	if die.bitter:
		tags.append("bitter")
	if die.repeated:
		tags.append("again")
	if Array(die.faces) != [1, 2, 3, 4, 5, 6]:
		tags.append("faceted")
	text = "%s\n\n%d\n\n%s" % [die.die_name, die.value, " ".join(tags)]
	disabled = die.locked or die.value == 0
	var tint := ThemeColors.INK
	if die.locked:
		tint = ThemeColors.LOCKED
	elif die.bitter:
		tint = ThemeColors.BITTER
	add_theme_color_override("font_color", tint)
	add_theme_color_override("font_disabled_color", tint)
	tooltip_text = "%s — faces %s%s" % [
		die.die_name, str(Array(die.faces)),
		"\nBitter: refuses its lowest face." if die.bitter else "",
	]
