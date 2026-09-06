class_name Player
extends CharacterBody2D
## Eight-way walking, with collision against the Walls layer.
##
## The sprite is a placeholder rectangle drawn in code. Replace it with an
## AnimatedSprite2D when you have art: keep the CollisionShape2D where it is,
## because it is deliberately a short box around the feet rather than the whole
## body — that is what makes a character look like they are standing *in* the
## room rather than floating over it.

signal moved(to: Vector2)

const SIZE := Vector2(40, 56)

@export var speed: float = 260.0
## How quickly the character gets up to speed and back down again. Zero is
## instant, which feels stiff; a little smoothing reads much better.
@export var acceleration: float = 2200.0
@export var friction: float = 2600.0

## Which way they are facing, for when there are animations to pick.
var facing := Vector2.DOWN


func _physics_process(delta: float) -> void:
	var wish := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if wish.length_squared() > 0.0:
		velocity = velocity.move_toward(wish * speed, acceleration * delta)
		facing = wish.normalized()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	var before := global_position
	move_and_slide()
	if not global_position.is_equal_approx(before):
		moved.emit(global_position)


## Placeholder art. Delete this and the _draw call once there is a sprite.
func _draw() -> void:
	var body := Rect2(-SIZE.x * 0.5, -SIZE.y, SIZE.x, SIZE.y)
	draw_rect(body, Color("8fd07a"))
	draw_rect(Rect2(body.position, Vector2(SIZE.x, 6)), Color("b6e8a4"))
	# Eyes, so which way is up is obvious.
	var eye := Vector2(6, 6)
	draw_rect(Rect2(Vector2(-12, -SIZE.y + 14), eye), Color("16181e"))
	draw_rect(Rect2(Vector2(6, -SIZE.y + 14), eye), Color("16181e"))
	# A shadow on the ground, which is what sells the feet being on the floor.
	draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.25))
