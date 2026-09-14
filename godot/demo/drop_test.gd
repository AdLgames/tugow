extends Node3D
## Fifty objects dropped onto a floor, which is the week 3 gate.
##
## Run it headless and it renders the audio to a WAV and prints the numbers;
## run it normally and you hear it. Either way the same scene, so the thing
## being judged is the thing being measured.
##
##   godot --path . --headless -- --render=out.wav --seconds=6

const MODEL := "res://models/glass_tumbler.modal"
const COUNT := 50

var _seconds := 6.0
var _elapsed := 0.0
var _worst_voices := 0
var _render_to := ""
var _capture: AudioEffectCapture
var _captured := PackedFloat32Array()


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			_seconds = float(arg.substr(10))
		elif arg.begins_with("--render="):
			_render_to = arg.substr(9)
	if _render_to != "":
		_start_capture()

	_build_floor()
	for i in COUNT:
		_drop(i)
	print("dropped %d objects, %d models loaded" % [COUNT, ModalServer.model_count()])


func _process(delta: float) -> void:
	_elapsed += delta
	_worst_voices = maxi(_worst_voices, ModalServer.get_active_voices())
	_pull_capture()
	if _elapsed >= _seconds:
		_write_capture()
		print("peak voices %d, dropped events %d, stolen %d" %
			[_worst_voices, ModalServer.get_dropped_events(), ModalServer.get_stolen_voices()])
		get_tree().quit(0)


func _build_floor() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child(floor_body)


func _drop(index: int) -> void:
	var body := RigidBody3D.new()
	# The two settings without which no contact is ever reported. ModalBody
	# warns when they are missing rather than being silently quiet.
	body.contact_monitor = true
	body.max_contacts_reported = 8
	body.mass = 0.08

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.12
	shape.shape = sphere
	body.add_child(shape)

	# Spread and staggered, so the impacts arrive over a second rather than
	# all on one frame — which is the harder case for the voice pool, not the
	# easier one.
	var angle := index * 0.61
	body.position = Vector3(cos(angle) * 2.5, 3.0 + index * 0.12, sin(angle) * 2.5)
	body.linear_velocity = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))

	var voice := ModalBody.new()
	voice.model_path = MODEL
	body.add_child(voice)
	add_child(body)


## Tapping the master bus, so what is written is what the audio callback
## produced — the real path, not a second renderer that could drift from it.
func _start_capture() -> void:
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 2.0
	AudioServer.add_bus_effect(0, _capture)


func _pull_capture() -> void:
	if _capture == null:
		return
	var available := _capture.get_frames_available()
	if available <= 0:
		return
	var frames := _capture.get_buffer(available)
	for frame in frames:
		_captured.append(frame.x)


func _write_capture() -> void:
	if _capture == null or _captured.is_empty():
		return
	var rate := int(AudioServer.get_mix_rate())
	var file := FileAccess.open(_render_to, FileAccess.WRITE)
	if file == null:
		push_error("could not write " + _render_to)
		return
	var bytes := _captured.size() * 2
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + bytes)
	file.store_buffer("WAVEfmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)
	file.store_16(1)
	file.store_32(rate)
	file.store_32(rate * 2)
	file.store_16(2)
	file.store_16(16)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(bytes)
	for sample in _captured:
		file.store_16(int(clampf(sample, -1.0, 1.0) * 32767.0) & 0xFFFF)
	file.close()
	print("wrote %s — %.2f s" % [_render_to, float(_captured.size()) / rate])
