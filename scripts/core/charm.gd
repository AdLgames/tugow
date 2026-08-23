class_name Charm
extends RefCounted
## Passive relics that react to dice behaviour, not to hand types.
## Every hook is optional; the game calls them all and charms ignore what
## they do not care about.

var id: StringName
var charm_name: String
var text: String


func _init(p_id: StringName = &"", p_name: String = "", p_text: String = "") -> void:
	id = p_id
	charm_name = p_name
	text = p_text


## Called once at the start of each floor.
func on_floor_start(_game) -> void:
	pass


## Called after every roll (initial roll and each reroll).
func on_roll(_game) -> void:
	pass


## Called when the player locks a die. May mutate the die.
func on_lock(_game, _die: Die) -> void:
	pass


## Transform the score about to be written. Return the new value.
func modify_score(_game, _box: int, _values: Array, base: int) -> int:
	return base


## Extra boxes this write also fills, as [[box, value], ...].
func extra_writes(_game, _box: int, _values: Array) -> Array:
	return []


## Additional boxes burned per turn beyond the one you write into.
func extra_boxes_per_turn() -> int:
	return 0
