class_name Lamp
extends Node2D
## A light that casts shadows off anything solid.
##
## The light texture is built here rather than being an image on disk, so the
## radius is a number you can change in the inspector instead of art you have
## to redraw. Godot needs *some* texture on a PointLight2D — without one the
## light is invisible, which reads as a broken light rather than a missing
## texture.

## How far the light reaches, in pixels. One cell is World.CELL.
@export var radius: float = 90.0:
	set(value):
		radius = maxf(1.0, value)
		_apply()

@export var color: Color = Color(1.0, 0.86, 0.62):
	set(value):
		color = value
		_apply()

## Above 1.0 the middle of the pool blows out to white, which is usually what
## you want for a flame and never what you want for daylight.
@export var energy: float = 1.35:
	set(value):
		energy = maxf(0.0, value)
		_apply()

@export var cast_shadows: bool = true:
	set(value):
		cast_shadows = value
		_apply()

@onready var light: PointLight2D = $Light


func _ready() -> void:
	_apply()


func _apply() -> void:
	if light == null:
		return
	light.color = color
	light.energy = energy
	light.shadow_enabled = cast_shadows
	# The gradient is square and drawn centred, so the texture has to be twice
	# the radius across for the falloff to reach exactly that far.
	var gradient := light.texture as GradientTexture2D
	if gradient != null:
		var span := int(round(radius * 2.0))
		gradient.width = span
		gradient.height = span
	light.texture_scale = 1.0
