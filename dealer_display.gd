extends TextureRect

const SPRITE_BASE = "res://Assets/TavernAssets/Flying Demon 2D Pixel Art/Sprites/without_outline/"
const FRAME_WIDTH = 79
const FRAME_HEIGHT = 69

var sprite_sheets: Dictionary = {}
var atlas_texture: AtlasTexture
var current_anim: String = "IDLE"
var frame_count: int = 1
var current_frame: int = 0
var anim_speed: float = 10.0
var last_frame_time: float = 0.0

func _ready() -> void:
	atlas_texture = AtlasTexture.new()
	texture = atlas_texture
	for anim_name in ["IDLE", "ATTACK", "DEATH", "FLYING", "HURT"]:
		var path = SPRITE_BASE + anim_name + ".png"
		if ResourceLoader.exists(path):
			sprite_sheets[anim_name] = load(path)
	set_animation("IDLE")

func set_animation(anim_name: String) -> void:
	if not sprite_sheets.has(anim_name):
		return
	if current_anim == anim_name:
		return
	current_anim = anim_name
	current_frame = 0
	last_frame_time = 0.0
	var sheet: Texture2D = sprite_sheets[anim_name]
	frame_count = max(1, sheet.get_width() / FRAME_WIDTH)
	atlas_texture.atlas = sheet
	_update_region()

func _process(delta: float) -> void:
	if not atlas_texture or not sprite_sheets.has(current_anim):
		return
	last_frame_time += delta
	var frame_duration = 1.0 / anim_speed
	if last_frame_time >= frame_duration:
		last_frame_time -= frame_duration
		current_frame = (current_frame + 1) % frame_count
		_update_region()

func _update_region() -> void:
	atlas_texture.region = Rect2(current_frame * FRAME_WIDTH, 0, FRAME_WIDTH, FRAME_HEIGHT)

func play_oneshot(anim_name: String) -> void:
	if not sprite_sheets.has(anim_name):
		return
	current_anim = anim_name
	current_frame = 0
	last_frame_time = 0.0
	var sheet: Texture2D = sprite_sheets[anim_name]
	frame_count = max(1, sheet.get_width() / FRAME_WIDTH)
	atlas_texture.atlas = sheet
	_update_region()
	var duration = float(frame_count) / anim_speed
	await get_tree().create_timer(duration).timeout
	set_animation("IDLE")
