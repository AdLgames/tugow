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

## What a shadowed patch of floor is painted with. This is the knob for how
## heavy the shadows read, because a 2D shadow always reaches from its
## occluder to the edge of the light — the only way to shorten one is to
## shrink the light, which would stop it filling the room. Lifting this
## towards the lit floor tone makes a long shadow read as a soft dimming
## instead of a black wedge.
##
## Its alpha is ignored under the GL Compatibility renderer this project uses,
## so lighten the *colour*, not the transparency.
@export var shadow_color: Color = Color(0.44, 0.39, 0.33, 1):
	set(value):
		shadow_color = value
		_apply()

## Blur on the shadow edge, in pixels. A hard edge on a big room reads as a
## cut-out; a few pixels of blur reads as a lamp.
@export var shadow_softness: float = 3.0:
	set(value):
		shadow_softness = maxf(0.0, value)
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
	light.shadow_color = shadow_color
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF13 if shadow_softness > 0.0 \
		else Light2D.SHADOW_FILTER_NONE
	light.shadow_filter_smooth = shadow_softness
	# The gradient is square and drawn centred, so the texture has to be twice
	# the radius across for the falloff to reach exactly that far.
	var gradient := light.texture as GradientTexture2D
	if gradient != null:
		var span := int(round(radius * 2.0))
		gradient.width = span
		gradient.height = span
	light.texture_scale = 1.0
