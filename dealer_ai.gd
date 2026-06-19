extends Node
class_name DealerAI

enum MoveType { PULL, SABOTAGE, HEAVY_PULL }

const MOVES = {
	"steam_winch": {
		"name": "Steam Winch",
		"type": MoveType.PULL,
		"base_val": 4,
		"variance": 1,
		"intent_text": "Preparing a steady pull (-3 to -5)"
	},
	"hydraulic_slam": {
		"name": "Hydraulic Slam",
		"type": MoveType.HEAVY_PULL,
		"base_val": 7,
		"variance": 2,
		"intent_text": "Preparing a heavy slam (-5 to -9)!"
	},
	"clog_pipes": {
		"name": "Clog Pipes",
		"type": MoveType.SABOTAGE,
		"base_val": 0,
		"variance": 0,
		"intent_text": "Injecting soot. (Adds Overheat to Player)"
	}
}

static func select_next_move(current_dial: int) -> Dictionary:
	if current_dial >= 12:
		return MOVES["hydraulic_slam"] if randf() < 0.60 else MOVES["steam_winch"]
	elif current_dial <= -10:
		return MOVES["clog_pipes"] if randf() < 0.50 else MOVES["steam_winch"]
	else:
		var roll = randf()
		if roll < 0.55:
			return MOVES["steam_winch"]
		elif roll < 0.80:
			return MOVES["clog_pipes"]
		else:
			return MOVES["hydraulic_slam"]
