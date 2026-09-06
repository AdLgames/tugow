class_name Goods
extends RefCounted
## What the shop sells. Level 1 stock keeps; level 2 stock does not.

enum Id { SHATTERED_BONE, FEY_BERRIES, FRESH_SCREAMS, PULSING_BIOMASS }

## `life` of 0.0 means it keeps for ever. Anything else is seconds on a table
## before it turns, and turning is what makes corruption.
const TABLE := {
	Id.SHATTERED_BONE: {
		"name": "Shattered Bone", "price": 12, "life": 0.0, "tier": 1,
		"blurb": "Splinters of something that walked upright.",
	},
	Id.FEY_BERRIES: {
		"name": "Fey-Touched Berries", "price": 18, "life": 0.0, "tier": 1,
		"blurb": "Sweet. They watch you back.",
	},
	Id.FRESH_SCREAMS: {
		"name": "Fresh Screams", "price": 140, "life": 75.0, "tier": 2,
		"blurb": "Bottled at the moment of. Keeps badly.",
	},
	Id.PULSING_BIOMASS: {
		"name": "Pulsing Biomass", "price": 260, "life": 50.0, "tier": 2,
		"blurb": "Still deciding what it wants to be.",
	},
}


static func all_ids() -> Array[int]:
	var out: Array[int] = []
	for id in TABLE:
		out.append(id)
	out.sort()
	return out


static func for_tier(tier: int) -> Array[int]:
	var out: Array[int] = []
	for id in all_ids():
		if int(TABLE[id]["tier"]) <= tier:
			out.append(id)
	return out


static func good_name(id: int) -> String:
	return String(TABLE[id]["name"])


static func price(id: int) -> int:
	return int(TABLE[id]["price"])


static func shelf_life(id: int) -> float:
	return float(TABLE[id]["life"])


static func perishable(id: int) -> bool:
	return shelf_life(id) > 0.0


static func blurb(id: int) -> String:
	return String(TABLE[id]["blurb"])


## One unit, with its own clock. A unit knows how close it is to turning so
## the shop floor can show it going off before it does.
class Unit extends RefCounted:
	var id: int
	var age: float = 0.0
	var rotted: bool = false

	func _init(p_id: int = 0) -> void:
		id = p_id

	## 0.0 fresh, 1.0 gone. Always 0.0 for anything that keeps.
	func spoilage() -> float:
		var life := Goods.shelf_life(id)
		if life <= 0.0:
			return 0.0
		return clampf(age / life, 0.0, 1.0)

	## Returns true on the tick it turns, and only that tick.
	func tick(delta: float) -> bool:
		if rotted or not Goods.perishable(id):
			return false
		age += delta
		if age < Goods.shelf_life(id):
			return false
		rotted = true
		return true
