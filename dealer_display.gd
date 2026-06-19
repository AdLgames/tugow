extends TextureRect

const DEFAULT_SPRITE_BASE = "res://Assets/TavernAssets/Flying Demon 2D Pixel Art/Sprites/without_outline/"
const DEFAULT_FRAME_WIDTH = 79
const DEFAULT_FRAME_HEIGHT = 69

var sprite_sheets: Dictionary = {}
var atlas_texture: AtlasTexture
var current_anim: String = ""
var frame_count: int = 1
var current_frame: int = 0
var anim_speed: float = 10.0
var last_frame_time: float = 0.0
var frame_width: int = DEFAULT_FRAME_WIDTH
var frame_height: int = DEFAULT_FRAME_HEIGHT

func _ready() -> void:
	atlas_texture = AtlasTexture.new()
	texture = atlas_texture
	_load_sprites(DEFAULT_SPRITE_BASE, DEFAULT_FRAME_WIDTH, DEFAULT_FRAME_HEIGHT)

func load_dealer(dealer_data: Dictionary) -> void:
	var base = dealer_data.get("sprite_base", DEFAULT_SPRITE_BASE)
	var fw = dealer_data.get("frame_width", DEFAULT_FRAME_WIDTH)
	var fh = dealer_data.get("frame_height", DEFAULT_FRAME_HEIGHT)
	current_anim = ""
	_load_sprites(base, fw, fh)

func _load_sprites(sprite_base: String, fw: int, fh: int) -> void:
	frame_width = fw
	frame_height = fh
	sprite_sheets.clear()
	for anim_name in ["IDLE", "ATTACK", "DEATH", "FLYING", "HURT"]:
		var path = sprite_base + anim_name + ".png"
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
	frame_count = max(1, sheet.get_width() / frame_width)
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
	atlas_texture.region = Rect2(current_frame * frame_width, 0, frame_width, frame_height)

func play_oneshot(anim_name: String) -> void:
	if not sprite_sheets.has(anim_name):
		return
	current_anim = anim_name
	current_frame = 0
	last_frame_time = 0.0
	var sheet: Texture2D = sprite_sheets[anim_name]
	frame_count = max(1, sheet.get_width() / frame_width)
	atlas_texture.atlas = sheet
	_update_region()
	var duration = float(frame_count) / anim_speed
	await get_tree().create_timer(duration).timeout
	set_animation("IDLE")
