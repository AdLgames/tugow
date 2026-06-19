extends Node
class_name DealerAI

enum MoveType { PULL, SABOTAGE, HEAVY_PULL }

const DEALERS = {
	"imp": {
		"name": "Tavern Imp",
		"sprite_base": "res://Assets/TavernAssets/Flying Demon 2D Pixel Art/Sprites/without_outline/",
		"frame_width": 79,
		"frame_height": 69,
		"moves": {
			"swipe": {
				"name": "Claw Swipe",
				"type": MoveType.PULL,
				"base_val": 4,
				"variance": 1,
				"intent_text": "Swiping claws (-3 to -5)"
			},
			"pounce": {
				"name": "Pounce",
				"type": MoveType.HEAVY_PULL,
				"base_val": 6,
				"variance": 2,
				"intent_text": "Winding up a pounce (-4 to -8)!"
			},
			"hex": {
				"name": "Imp Hex",
				"type": MoveType.SABOTAGE,
				"base_val": 0,
				"variance": 0,
				"intent_text": "Casting a hex (Adds Overheat)"
			}
		},
		"ai": "standard"
	},
	"goblin_mechanic": {
		"name": "Goblin Mechanic",
		"sprite_base": "res://Assets/TavernAssets/Flying Demon 2D Pixel Art/Sprites/without_outline/",
		"frame_width": 79,
		"frame_height": 69,
		"moves": {
			"wrench_pull": {
				"name": "Wrench Yank",
				"type": MoveType.PULL,
				"base_val": 3,
				"variance": 1,
				"intent_text": "Yanking with a wrench (-2 to -4)"
			},
			"gear_grind": {
				"name": "Gear Grinder",
				"type": MoveType.HEAVY_PULL,
				"base_val": 7,
				"variance": 2,
				"intent_text": "Cranking the grinder (-5 to -9)!"
			},
			"soot_bomb": {
				"name": "Soot Bomb",
				"type": MoveType.SABOTAGE,
				"base_val": 0,
				"variance": 0,
				"intent_text": "Lobbing a soot bomb (Adds Overheat)"
			}
		},
		"ai": "saboteur"
	},
	"iron_golem": {
		"name": "Iron Golem",
		"sprite_base": "res://Assets/TavernAssets/Flying Demon 2D Pixel Art/Sprites/without_outline/",
		"frame_width": 79,
		"frame_height": 69,
		"moves": {
			"iron_drag": {
				"name": "Iron Drag",
				"type": MoveType.PULL,
				"base_val": 5,
				"variance": 1,
				"intent_text": "Dragging with iron fists (-4 to -6)"
			},
			"boulder_slam": {
				"name": "Boulder Slam",
				"type": MoveType.HEAVY_PULL,
				"base_val": 9,
				"variance": 2,
				"intent_text": "Raising a massive boulder (-7 to -11)!"
			},
			"rust_cloud": {
				"name": "Rust Cloud",
				"type": MoveType.SABOTAGE,
				"base_val": 0,
				"variance": 0,
				"intent_text": "Exhaling rust (Adds Overheat)"
			}
		},
		"ai": "bruiser"
	},
	"infernal_dealer": {
		"name": "The Infernal",
		"sprite_base": "res://Assets/TavernAssets/Flying Demon 2D Pixel Art/Sprites/without_outline/",
		"frame_width": 79,
		"frame_height": 69,
		"moves": {
			"hellfire_pull": {
				"name": "Hellfire Pull",
				"type": MoveType.PULL,
				"base_val": 5,
				"variance": 2,
				"intent_text": "Chains of hellfire (-3 to -7)"
			},
			"abyssal_slam": {
				"name": "Abyssal Slam",
				"type": MoveType.HEAVY_PULL,
				"base_val": 10,
				"variance": 3,
				"intent_text": "Opening the abyss (-7 to -13)!!"
			},
			"soul_burn": {
				"name": "Soul Burn",
				"type": MoveType.SABOTAGE,
				"base_val": 0,
				"variance": 0,
				"intent_text": "Igniting your soul (Adds Overheat)"
			}
		},
		"ai": "aggressive"
	}
}

const ENCOUNTER_DEALERS = {
	1: "imp", 2: "imp", 3: "imp",
	4: "goblin_mechanic", 5: "goblin_mechanic", 6: "goblin_mechanic",
	7: "iron_golem", 8: "iron_golem", 9: "iron_golem",
}

static func get_dealer_for_encounter(encounter_num: int) -> Dictionary:
	if ENCOUNTER_DEALERS.has(encounter_num):
		var dealer_id = ENCOUNTER_DEALERS[encounter_num]
		return DEALERS[dealer_id]
	return DEALERS["infernal_dealer"]

static func select_next_move(current_dial: int, dealer_data: Dictionary) -> Dictionary:
	var moves = dealer_data.moves
	var move_keys = moves.keys()
	var pull_key = move_keys[0]
	var heavy_key = move_keys[1]
	var sabotage_key = move_keys[2]
	var ai_type = dealer_data.get("ai", "standard")

	match ai_type:
		"saboteur":
			return _ai_saboteur(current_dial, moves, pull_key, heavy_key, sabotage_key)
		"bruiser":
			return _ai_bruiser(current_dial, moves, pull_key, heavy_key, sabotage_key)
		"aggressive":
			return _ai_aggressive(current_dial, moves, pull_key, heavy_key, sabotage_key)
		_:
			return _ai_standard(current_dial, moves, pull_key, heavy_key, sabotage_key)

static func _ai_standard(dial: int, moves: Dictionary, pull: String, heavy: String, sab: String) -> Dictionary:
	if dial >= 12:
		return moves[heavy] if randf() < 0.60 else moves[pull]
	elif dial <= -10:
		return moves[sab] if randf() < 0.50 else moves[pull]
	else:
		var roll = randf()
		if roll < 0.55:
			return moves[pull]
		elif roll < 0.80:
			return moves[sab]
		else:
			return moves[heavy]

static func _ai_saboteur(dial: int, moves: Dictionary, pull: String, heavy: String, sab: String) -> Dictionary:
	if dial >= 12:
		var roll = randf()
		if roll < 0.40:
			return moves[heavy]
		elif roll < 0.75:
			return moves[sab]
		else:
			return moves[pull]
	elif dial <= -10:
		return moves[sab] if randf() < 0.70 else moves[pull]
	else:
		var roll = randf()
		if roll < 0.35:
			return moves[pull]
		elif roll < 0.75:
			return moves[sab]
		else:
			return moves[heavy]

static func _ai_bruiser(dial: int, moves: Dictionary, pull: String, heavy: String, sab: String) -> Dictionary:
	if dial >= 12:
		return moves[heavy] if randf() < 0.75 else moves[pull]
	elif dial <= -10:
		return moves[pull] if randf() < 0.60 else moves[sab]
	else:
		var roll = randf()
		if roll < 0.40:
			return moves[pull]
		elif roll < 0.55:
			return moves[sab]
		else:
			return moves[heavy]

static func _ai_aggressive(dial: int, moves: Dictionary, pull: String, heavy: String, sab: String) -> Dictionary:
	if dial >= 12:
		return moves[heavy] if randf() < 0.70 else moves[sab]
	elif dial <= -10:
		var roll = randf()
		if roll < 0.40:
			return moves[sab]
		elif roll < 0.70:
			return moves[heavy]
		else:
			return moves[pull]
	else:
		var roll = randf()
		if roll < 0.30:
			return moves[pull]
		elif roll < 0.55:
			return moves[sab]
		else:
			return moves[heavy]
