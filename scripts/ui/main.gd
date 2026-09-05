extends Control
## The booth, assembled. Portrait and name tag above, transcript in the
## middle, eight questions and two decisions below.
##
## The interface never shows dread, never shows a score, and never tells you
## whether you were right. The only readout in the game is the window.

const TYPE_SPEED := 62.0

var game: Game = null

var _booth: BoothView
var _portrait: PortraitView
var _name_label: Label
var _reason_label: Label
var _transcript: RichTextLabel
var _asks_label: Label
var _shift_label: Label
var _question_buttons: Array[Button] = []
var _approve: Button
var _deny: Button
var _overlay: Control
var _overlay_title: Label
var _overlay_body: VBoxContainer
var _scare_flash: ColorRect
var _scare_text: Label
var _scare_plate: ColorRect

var _typing: String = ""
var _typed: float = 0.0
var _scare_hold: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_show_title()
	set_process(true)


func _build() -> void:
	_booth = BoothView.new()
	add_child(_booth)

	_portrait = PortraitView.new()
	_portrait.position = Vector2(150, 120)
	_portrait.size = PortraitView.SIZE
	add_child(_portrait)

	_shift_label = _label("", 18, Palette.INK_DIM)
	_shift_label.position = Vector2(60, 44)
	_shift_label.size = Vector2(600, 26)

	_name_label = _label("", 34, Palette.INK)
	_name_label.position = Vector2(720, 150)
	_name_label.size = Vector2(560, 44)

	_reason_label = _label("", 18, Palette.INK_DIM)
	_reason_label.position = Vector2(720, 200)
	_reason_label.size = Vector2(560, 70)
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_transcript = RichTextLabel.new()
	_transcript.position = Vector2(720, 280)
	_transcript.size = Vector2(1000, 330)
	_transcript.bbcode_enabled = true
	_transcript.scroll_following = true
	_transcript.add_theme_color_override("default_color", Palette.INK_DIM)
	_transcript.add_theme_font_size_override("normal_font_size", 19)
	add_child(_transcript)

	_asks_label = _label("", 18, Palette.LAMP_DIM)
	_asks_label.position = Vector2(1320, 656)
	_asks_label.size = Vector2(520, 26)

	_build_questions()
	_build_decisions()
	_build_overlay()
	_build_scare()


func _label(text: String, font_size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	add_child(l)
	return l


## Eight questions, always all eight, always in the same order. The player
## should know the whole pool by shift two — the decision is which three.
func _build_questions() -> void:
	var ids := Questions.all_ids()
	for i in ids.size():
		var button := Button.new()
		button.text = Questions.ask_text(ids[i])
		button.position = Vector2(60 + float(i % 2) * 620.0, 700.0 + float(i / 2) * 58.0)
		button.size = Vector2(590, 48)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 19)
		_style(button, Palette.DESK, Palette.INK)
		button.pressed.connect(_on_ask.bind(ids[i]))
		add_child(button)
		_question_buttons.append(button)


func _build_decisions() -> void:
	_deny = Button.new()
	_deny.text = "DENY"
	_deny.position = Vector2(1320, 700)
	_deny.size = Vector2(250, 106)
	_deny.add_theme_font_size_override("font_size", 30)
	_style(_deny, Palette.DENY.darkened(0.55), Palette.INK)
	_deny.pressed.connect(_on_decide.bind(false))
	add_child(_deny)

	_approve = Button.new()
	_approve.text = "APPROVE"
	_approve.position = Vector2(1590, 700)
	_approve.size = Vector2(250, 106)
	_approve.add_theme_font_size_override("font_size", 30)
	_style(_approve, Palette.APPROVE.darkened(0.55), Palette.INK)
	_approve.pressed.connect(_on_decide.bind(true))
	add_child(_approve)


func _style(button: Button, fill: Color, ink: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		var tint := fill
		if state == "hover":
			tint = fill.lightened(0.12)
		elif state == "pressed":
			tint = fill.lightened(0.2)
		elif state == "disabled":
			tint = fill.darkened(0.5)
		box.bg_color = tint
		box.border_color = Color(0, 0, 0, 0.5)
		box.set_border_width_all(1)
		box.content_margin_left = 16
		box.content_margin_right = 16
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", Palette.LAMP)
	button.add_theme_color_override("font_disabled_color", Palette.INK_DIM.darkened(0.4))


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.86)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(scrim)
	var column := VBoxContainer.new()
	column.position = Vector2(360, 300)
	column.size = Vector2(1200, 480)
	column.add_theme_constant_override("separation", 22)
	_overlay.add_child(column)
	_overlay_title = Label.new()
	_overlay_title.add_theme_font_size_override("font_size", 44)
	_overlay_title.add_theme_color_override("font_color", Palette.LAMP)
	column.add_child(_overlay_title)
	_overlay_body = VBoxContainer.new()
	_overlay_body.add_theme_constant_override("separation", 16)
	column.add_child(_overlay_body)


func _build_scare() -> void:
	_scare_flash = ColorRect.new()
	_scare_flash.color = Color(0, 0, 0, 0)
	_scare_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scare_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scare_flash)
	# A plate behind the words, or a scare that lands over a face is unreadable.
	_scare_plate = ColorRect.new()
	_scare_plate.color = Color(0, 0, 0, 0.72)
	_scare_plate.position = Vector2(220, 500)
	_scare_plate.size = Vector2(1480, 150)
	_scare_plate.visible = false
	_scare_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scare_plate)

	_scare_text = Label.new()
	_scare_text.position = Vector2(260, 516)
	_scare_text.size = Vector2(1400, 120)
	_scare_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scare_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scare_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scare_text.add_theme_font_size_override("font_size", 30)
	_scare_text.add_theme_color_override("font_color", Palette.WRONG)
	_scare_text.visible = false
	add_child(_scare_text)


# --- Screens -----------------------------------------------------------------

func _show_title() -> void:
	_clear_overlay("CHECKPOINT")
	_overlay_line("No papers. No proof. Just their face and your questions.")
	_overlay_line("")
	_overlay_line("You are the last human on this side of the glass. Ask up to three questions. Decide who comes in.")
	_overlay_line("Some of them are not people. None of them will tell you.")
	_overlay_button("Begin the shift", _start_run)
	_set_overlay(true)


func _start_run() -> void:
	game = RunState.new_run()
	game.traveller_arrived.connect(_on_arrival)
	game.answered.connect(_on_answered)
	game.ambient.connect(_on_ambient)
	game.shift_started.connect(_on_shift_started)
	game.shift_ended.connect(_on_shift_ended)
	game.scare_fired.connect(_on_scare)
	game.run_ended.connect(_on_run_ended)
	game.refused_deny.connect(func() -> void:
		_write("[color=#9fb4c4][i]The DENY stamp does not move.[/i][/color]"))
	_transcript.text = ""
	_on_shift_started(game.shift, game.shift_title, Shifts.get_shift(game.shift).opening)


func _on_shift_started(number: int, title: String, opening: String) -> void:
	_clear_overlay("Shift %d — %s" % [number, title])
	_overlay_line(opening)
	var s := Shifts.get_shift(number)
	if s.scripted != "":
		_overlay_line(s.scripted)
	_overlay_button("Open the window", func() -> void:
		_set_overlay(false)
		_transcript.text = ""
		game.begin_shift()
		_refresh())
	_set_overlay(true)


func _on_shift_ended(number: int) -> void:
	if game.phase == Game.Phase.RUN_OVER:
		return
	_clear_overlay("Shift %d ends" % number)
	_overlay_line("%d %s still lit in the safe-zone window."
		% [game.lights, "light" if game.lights == 1 else "lights"])
	_overlay_button("Next shift", func() -> void:
		_set_overlay(false)
		game.next_shift())
	_set_overlay(true)


func _on_run_ended(id: StringName, reason: String) -> void:
	var titles := {
		&"kept_the_line": "You kept the line",
		&"emptied_the_zone": "You emptied the zone",
		&"turned_everyone_away": "You turned everyone away",
	}
	_clear_overlay(String(titles.get(id, "The shift ends")))
	_overlay_line(reason)
	_overlay_line("")
	# No score. The game does not tell you how you did.
	_overlay_line("The window is not a scoreboard. It was never a scoreboard.")
	_overlay_button("Again", _start_run)
	_set_overlay(true)


# --- Play --------------------------------------------------------------------

func _on_arrival(t: Traveller) -> void:
	_portrait.shift = game.shift
	_portrait.show_traveller(t)
	_name_label.text = t.given_name
	_reason_label.text = t.reason
	if t.returning:
		_reason_label.text += "\nYou have seen this face before."
	_refresh()


func _on_ask(question: int) -> void:
	if game == null or not game.can_ask(question):
		return
	game.ask(question)
	_refresh()


func _on_answered(_question: int, ask: String, reply: String, _tell: int) -> void:
	_write("[color=#8f8878]%s[/color]" % ask)
	_write("[color=#e6ddcb]%s[/color]" % reply)


func _on_ambient(line: String) -> void:
	_write("[color=#6f6a5e][i]%s[/i][/color]" % line)


func _on_decide(approve: bool) -> void:
	if game == null or game.phase != Game.Phase.QUESTIONING:
		return
	game.decide(approve)
	_refresh()


func _on_scare(scare: int, copy: String) -> void:
	_scare_hold = 3.4
	_scare_text.text = copy
	_scare_text.visible = true
	_scare_plate.visible = true
	match scare:
		Scares.Id.LEAN_IN:
			_portrait.lean = 1.0
		Scares.Id.REFLECTION:
			_booth.glass_lag = 3.4
		Scares.Id.WINDOW, Scares.Id.COMEBACK, Scares.Id.KNOCK, Scares.Id.RADIO:
			_scare_flash.color = Color(0, 0, 0, 0.55)


func _process(delta: float) -> void:
	if game == null:
		return
	game.tick(delta)
	_booth.lights = game.lights
	_booth.shift = game.shift
	# Dread is never shown. It is only ever how far the lamp reaches.
	_booth.closeness = float(game.dread) / float(Dread.MAX)
	if _scare_hold > 0.0:
		_scare_hold = maxf(0.0, _scare_hold - delta)
		if _scare_hold == 0.0:
			_scare_text.visible = false
			_scare_plate.visible = false
			_scare_flash.color = Color(0, 0, 0, 0)
			_portrait.lean = 0.0


func _refresh() -> void:
	if game == null:
		return
	_shift_label.text = "Shift %d — %s" % [game.shift, game.shift_title]
	var playing := game.phase == Game.Phase.QUESTIONING
	_asks_label.text = "" if not playing else "%d %s left" % [game.asks_left,
		"question" if game.asks_left == 1 else "questions"]
	var ids := Questions.all_ids()
	for i in _question_buttons.size():
		var button := _question_buttons[i]
		button.disabled = not game.can_ask(ids[i])
		# A question that has stopped working still looks exactly the same.
		button.text = Questions.ask_text(ids[i])
	_approve.disabled = not playing
	_deny.disabled = not playing


func _write(line: String) -> void:
	_transcript.append_text(line + "\n")


# --- Overlay -----------------------------------------------------------------

func _clear_overlay(title: String) -> void:
	_overlay_title.text = title
	for child in _overlay_body.get_children():
		_overlay_body.remove_child(child)
		child.queue_free()


func _overlay_line(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1100, 0)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Palette.INK_DIM)
	_overlay_body.add_child(l)
	return l


func _overlay_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(340, 54)
	button.add_theme_font_size_override("font_size", 22)
	_style(button, Palette.DESK, Palette.LAMP)
	button.pressed.connect(action)
	_overlay_body.add_child(button)
	return button


func _set_overlay(shown: bool) -> void:
	_overlay.visible = shown
