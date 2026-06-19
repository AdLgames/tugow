extends TextureRect

const SPRITE_BASE = "res://Assets/TavernAssets/Flying Demon 2D Pixel Art/Sprites/without_outline/"

var sprite_sheets: Dictionary = {}
var atlas_texture: AtlasTexture
var current_anim: String = "IDLE"
var frame_count: int = 1
var frame_width: int = 64
var frame_height: int = 64
var anim_speed: float = 8.0

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
	current_anim = anim_name
	var sheet: Texture2D = sprite_sheets[anim_name]
	frame_height = sheet.get_height()
	frame_width = frame_height
	frame_count = max(1, sheet.get_width() / frame_width)
	atlas_texture.atlas = sheet

func _process(_delta: float) -> void:
	if not atlas_texture or not sprite_sheets.has(current_anim):
		return
	var frame = int(Time.get_ticks_msec() / (1000.0 / anim_speed)) % frame_count
	atlas_texture.region = Rect2(frame * frame_width, 0, frame_width, frame_height)

func play_oneshot(anim_name: String) -> void:
	if not sprite_sheets.has(anim_name):
		return
	set_animation(anim_name)
	var duration = float(frame_count) / anim_speed
	await get_tree().create_timer(duration).timeout
	set_animation("IDLE")
