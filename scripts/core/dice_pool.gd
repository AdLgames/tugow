class_name DicePool
extends RefCounted
## Eight named dice. You roll five of them a turn, and locking removes a die
## from everyone's draw for the rest of the floor.

const DEFAULT_NAMES := [
	"Ash", "Bramble", "Cinder", "Dovetail",
	"Ember", "Flint", "Gallows", "Hollow",
	"Ivory", "Jetsam", "Knell", "Lantern",
]

var dice: Array[Die] = []
## The five (or fewer) dice on the table this turn.
var table: Array[Die] = []
var rng: RandomNumberGenerator


func _init(size: int = -1, seed_value: int = 0) -> void:
	rng = RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var count := size if size > 0 else Balance.pool_size
	for i in count:
		dice.append(Die.new(i, DEFAULT_NAMES[i % DEFAULT_NAMES.size()], rng))


func add_die(name_hint: String = "") -> Die:
	var idx := dice.size()
	var die_name: String = name_hint if name_hint != "" else DEFAULT_NAMES[idx % DEFAULT_NAMES.size()]
	var d := Die.new(idx, die_name, rng)
	dice.append(d)
	return d


func get_die(id: int) -> Die:
	for d in dice:
		if d.id == id:
			return d
	return null


func begin_floor() -> void:
	for d in dice:
		d.unlock()
		d.value = 0
		d.last_value = 0
		d.repeated = false
	table.clear()


func unlocked_dice() -> Array[Die]:
	var out: Array[Die] = []
	for d in dice:
		if not d.locked:
			out.append(d)
	return out


func locked_by(owner_tag: String) -> Array[Die]:
	var out: Array[Die] = []
	for d in dice:
		if d.locked and d.locked_by == owner_tag:
			out.append(d)
	return out


## Compose this turn's table: everything this side has locked, topped up with
## free dice drawn from the shared pool.
func begin_turn(owner_tag: String = "player") -> Array[Die]:
	table = locked_by(owner_tag)
	var free := unlocked_dice()
	_shuffle(free)
	var want := Balance.dice_per_roll - table.size()
	for i in mini(want, free.size()):
		table.append(free[i])
	return table


## Roll every unlocked die on the table. Locked dice keep their face.
func roll_table() -> void:
	for d in table:
		d.roll()


func table_values() -> Array:
	var out: Array = []
	for d in table:
		out.append(d.value)
	return out


func lock_die(die: Die, owner_tag: String = "player") -> void:
	if die.value == 0:
		return
	die.lock(owner_tag)


func locked_count() -> int:
	var n := 0
	for d in dice:
		if d.locked:
			n += 1
	return n


func describe_table() -> String:
	var parts: Array[String] = []
	for d in table:
		parts.append(d.describe())
	return " | ".join(parts)


func _shuffle(arr: Array[Die]) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
