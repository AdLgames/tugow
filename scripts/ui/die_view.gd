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
	if die.lost:
		tags.append("OFF TABLE")
	if die.zone == Throw.Zone.RAIL and not die.lost:
		tags.append("RAIL x2")
	if die.is_cocked():
		tags.append("COCKED")
	if die.locked:
		tags.append("LOCKED")
	if die.bitter:
		tags.append("bitter")
	if die.repeated:
		tags.append("again")
	if Array(die.faces) != [1, 2, 3, 4, 5, 6]:
		tags.append("faceted")
	text = "%s\n\n%s\n\n%s" % [
		die.die_name, "—" if die.lost else str(die.value), "\n".join(tags),
	]
	disabled = die.locked or die.value == 0 or die.lost
	var tint := ThemeColors.INK
	if die.lost:
		tint = ThemeColors.BURNED
	elif die.locked:
		tint = ThemeColors.LOCKED
	elif die.zone == Throw.Zone.RAIL:
		tint = ThemeColors.DECLARED
	elif die.bitter:
		tint = ThemeColors.BITTER
	add_theme_color_override("font_color", tint)
	add_theme_color_override("font_disabled_color", tint)
	tooltip_text = "%s — faces %s, hidden face %d%s" % [
		die.die_name, str(Array(die.faces)), die.underside(),
		"\nBitter: refuses its lowest face." if die.bitter else "",
	]
