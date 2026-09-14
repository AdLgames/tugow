@tool
class_name Backdrop
extends Control

## The window ground: a radial wash centred above the top edge, so the panels
## read as lit from somewhere just off-screen. `radial-gradient(120% 90% at
## 50% -10%, …)` in the design.
##
## Godot's GradientTexture2D does radial fills, but its centre and radius are
## in normalised texture space and the design's ellipse is wider than it is
## tall and anchored off-canvas. A twenty-line shader is less machinery than a
## texture that has to be resized with the window.

const SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform vec4 inner : source_color;
uniform vec4 mid : source_color;
uniform vec4 outer : source_color;

void fragment() {
	// The design's ellipse: 120% of the width, 90% of the height, centred at
	// 50% across and 10% above the top edge.
	vec2 offset = (UV - vec2(0.5, -0.1)) / vec2(1.2, 0.9);
	float t = clamp(length(offset), 0.0, 1.0);
	// Two stops: inner to mid across the first 60%, mid to outer beyond it.
	vec3 colour = t < 0.6
		? mix(inner.rgb, mid.rgb, t / 0.6)
		: mix(mid.rgb, outer.rgb, (t - 0.6) / 0.4);
	COLOR = vec4(colour, 1.0);
}
"""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("inner", ModalTheme.BACKDROP_INNER)
	shader_material.set_shader_parameter("mid", ModalTheme.BACKDROP_MID)
	shader_material.set_shader_parameter("outer", ModalTheme.BACKDROP_OUTER)
	material = shader_material


func _draw() -> void:
	# The shader needs geometry to run over; the colour here is never seen.
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, true)
