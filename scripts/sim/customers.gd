class_name Customer
extends RefCounted
## Someone off the path. They do not speak.
##
## A customer walks in, finds a table, looks at it, takes something, walks to
## the altar, puts money down, and leaves. Every one of those is a step they
## can fail at — an empty shop turns them around at the door — which is what
## makes stocking a decision rather than a chore.

enum State { ENTERING, TO_DISPLAY, BROWSING, TO_ALTAR, PAYING, LEAVING, GONE }

var state: int = State.ENTERING
var at: Vector2 = Vector2.ZERO       ## Tiles, fractional while walking.
var target: Vector2i = Vector2i.ZERO
var carrying: Goods.Unit = null
var timer: float = 0.0
var patience: float = 0.0
## Set for a single tick when they buy: the frame their sprite is wrong.
var glitching: bool = false
var seed_value: int = 0


func _init(entry: Vector2i, p_seed: int = 0) -> void:
	at = Vector2(entry)
	target = entry
	patience = Balance.patience_seconds
	seed_value = p_seed


func done() -> bool:
	return state == State.GONE


## Walk toward the target. Straight lines: the floor is open and a path
## solver would be a lot of machinery for a shop you can see all of.
func _walk(delta: float) -> bool:
	var goal := Vector2(target)
	var step := Balance.walk_speed * delta
	if at.distance_to(goal) <= step:
		at = goal
		return true
	at += (goal - at).normalized() * step
	return false
