extends Node
class_name DealerAI

# Define the types of moves the boss can make
enum MoveType { PULL, SABOTAGE, HEAVY_PULL }

# A structured blueprint for a Dealer Move
const MOVES = {
	"steam_winch": {
		"name": "Steam Winch",
		"type": MoveType.PULL,
		"base_val": 5,
		"variance": 1,
		"intent_text": "Preparing a steady pull (-4 to -6)"
	},
	"hydraulic_slam": {
		"name": "Hydraulic Slam",
		"type": MoveType.HEAVY_PULL,
		"base_val": 9,
		"variance": 2,
		"intent_text": "Preparing a massive, unstable slam (-7 to -11)!"
	},
	"clog_pipes": {
		"name": "Clog Pipes",
		"type": MoveType.SABOTAGE,
		"base_val": 0,
		"variance": 0,
		"intent_text": "Injecting soot. (Adds 2 Overheat to Player)"
	}
}

# The AI Decision Loop
static func select_next_move(current_dial: int) -> Dictionary:
	# STATE 1: PANIC MODE (Player is close to winning: Dial is >= 12)
	if current_dial >= 12:
		# 70% chance to drop a Heavy Pull, 30% chance for a normal pull
		return MOVES["hydraulic_slam"] if randf() < 0.70 else MOVES["steam_winch"]
		
	# STATE 2: DOMINATING MODE (Dealer is close to winning: Dial is <= -10)
	elif current_dial <= -10:
		# The Dealer has the upper hand; it sabotages the player to lock it in
		return MOVES["clog_pipes"] if randf() < 0.50 else MOVES["steam_winch"]
		
	# STATE 3: STANDARD MODE (The match is closely contested in the middle)
	else:
		# Default rotation/weighting
		var roll = randf()
		if roll < 0.60:
			return MOVES["steam_winch"]
		elif roll < 0.85:
			return MOVES["clog_pipes"]
		else:
			return MOVES["hydraulic_slam"]
