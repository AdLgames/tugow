class_name Die
extends RefCounted
## One of the eight dice in the pool. Dice are individuals, not instances of a
## rank: they carry a name, a reshaped face set, a grudge, and a memory.

const FACE_CAP := 9

var id: int
var die_name: String
## Six face values, index 0..5. Reshaped by the Facet rule.
var faces: PackedInt32Array = [1, 2, 3, 4, 5, 6]

## Current showing value. 0 means "not rolled yet this floor".
var value: int = 0
## Locked is locked for the whole floor, not the turn.
var locked: bool = false
## Who locked it (relevant for the shared pool during a duel).
var locked_by: String = ""
## Kept back from the next draw, for this turn only. Holding is free and
## costs nothing, but a held die is still sitting on the felt where a landing
## die can knock it. Staking is what makes a face untouchable — and it lasts
## the night.
var held: bool = false

## Memory — the face shown on the previous roll. Charms read this.
var last_value: int = 0
## True when the die rolled the same face twice running.
var repeated: bool = false

## Bitter dice refuse their lowest face and swing harder.
var bitter: bool = false
## Times this die has been locked into a scored box; three reshapes a face.
var lock_scores: int = 0
## Set by the Grudge charm when the die rolls a 1.
var furious: bool = false

# --- Where it landed ---------------------------------------------------------

## Polar position on the table's unit disc: 0 is dead centre, 1.0 is the lip.
var landing_radius: float = 0.0
var landing_angle: float = 0.0
## Throw.Zone — pot, rail, or off the table.
var zone: int = 0
## Gone for the rest of the floor.
var lost: bool = false
## Id of the die this one came down on, or -1. Kept for the log and the
## model's own bookkeeping.
var cocked_on: int = -1
## The second face a cocked die is showing, or 0. Whichever path threw the
## die fills this in; the rules only ever read this.
var second_value: int = 0


func landing_position() -> Vector2:
	return Vector2(cos(landing_angle), sin(landing_angle)) * landing_radius


## Every die has a hidden face opposite the one showing. On a standard die
## that is 7 - shown; on a reshaped die it is the sum of its lowest and
## highest face minus the one showing, which keeps the same relationship.
func underside() -> int:
	if value <= 0:
		return 0
	return maxi(1, lowest_face() + highest_face() - value)

var _rng: RandomNumberGenerator


func _init(p_id: int, p_name: String, rng: RandomNumberGenerator = null) -> void:
	id = p_id
	die_name = p_name
	_rng = rng if rng != null else RandomNumberGenerator.new()


func lowest_face() -> int:
	var lo := faces[0]
	for f in faces:
		lo = mini(lo, f)
	return lo


func highest_face() -> int:
	var hi := faces[0]
	for f in faces:
		hi = maxi(hi, f)
	return hi


func average_face() -> float:
	var total := 0
	for f in faces:
		total += f
	return float(total) / float(faces.size())


func roll() -> int:
	if locked:
		return value
	var result := _raw_roll()
	if bitter:
		# Refuses its lowest face, and swings: two draws, the wilder one wins.
		var mean := average_face()
		var a := _raw_roll()
		var b := _raw_roll()
		result = a if absf(float(a) - mean) >= absf(float(b) - mean) else b
		var guard := 0
		while result == lowest_face() and guard < 12:
			result = _raw_roll()
			guard += 1
	if furious:
		result = mini(result + 2, FACE_CAP)
		furious = false
	repeated = result == value and value != 0
	last_value = value
	value = result
	return value


func _raw_roll() -> int:
	return faces[_rng.randi_range(0, faces.size() - 1)]


func is_cocked() -> bool:
	return cocked_on != -1


## Not going to be thrown: staked for the night, or held for this turn.
func kept() -> bool:
	return locked or held


func lock(owner_tag: String = "player") -> void:
	locked = true
	locked_by = owner_tag


func unlock() -> void:
	locked = false
	locked_by = ""


## Called when this die was locked into a box that actually scored.
## Returns true if the die reshaped a face this time.
func note_scored() -> bool:
	lock_scores += 1
	if lock_scores % Balance.facet_threshold != 0:
		return false
	return reshape_weakest()


## Facet: pull the weakest face up one pip.
func reshape_weakest() -> bool:
	var idx := 0
	for i in faces.size():
		if faces[i] < faces[idx]:
			idx = i
	if faces[idx] >= FACE_CAP:
		return false
	faces[idx] += 1
	return true


func set_face(index: int, new_value: int) -> void:
	faces[index] = clampi(new_value, 1, FACE_CAP)


func embitter() -> void:
	bitter = true


func cleanse() -> void:
	bitter = false


func describe() -> String:
	var tags: Array[String] = []
	if bitter:
		tags.append("bitter")
	if locked:
		tags.append("locked")
	if faces != PackedInt32Array([1, 2, 3, 4, 5, 6]):
		tags.append("faceted %s" % str(Array(faces)))
	var suffix := "" if tags.is_empty() else " (%s)" % ", ".join(tags)
	return "%s: %d%s" % [die_name, value, suffix]


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": die_name,
		"faces": Array(faces),
		"bitter": bitter,
		"lock_scores": lock_scores,
	}


func load_dict(d: Dictionary) -> void:
	die_name = d.get("name", die_name)
	faces = PackedInt32Array(d.get("faces", Array(faces)))
	bitter = d.get("bitter", false)
	lock_scores = int(d.get("lock_scores", 0))
