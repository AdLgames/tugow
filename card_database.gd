extends Node

# Schema contract for every card entry:
#
# REQUIRED fields (all cards):
#   "name"        : String     — Display name
#   "action"      : String     — Enum key (see ACTION TYPES below)
#   "base_val"    : int        — Core numerical value
#   "variance"    : int        — RNG range: rolls (base_val - variance) to (base_val + variance)
#   "rarity"      : String     — "COMMON" | "UNCOMMON" | "RARE"
#   "description" : String     — Human-readable flavour/rules text
#
# OPTIONAL fields (action-dependent):
#   "cost"        : Dictionary — Side-effect on play, e.g., {"type": "OVERHEAT", "amount": 2}
#   "free_action" : bool       — If true, playing this card bypasses the end-of-turn phase
#   "multiplier"  : float      — Scales ONLY the next card's resolved value (never the dial)
#   "target_val"  : int        — Exact dial value trigger for CONDITIONAL cards
#   "target_mod"  : int        — Modulo trigger (e.g., 5 = fires on any multiple of 5)
#   "bonus_val"   : int        — Extra push value if conditional logic is met
#   "delay_turns" : int        — Turns before a DELAY card resolves
#   "stacks"      : int        — Number of status stacks applied (BLEED, LOCKED, etc.)
#   "drain_val"   : int        — How much Overheat is purged on play (VENT cards)
#   "type"        : String     — "NUMBER" (pure value) or "MAGIC" (special mechanics)
#   "tag"         : Array      — Mechanical tags for synergy checks ["STEAM","PRECISION","HEAVY"]

# ── ACTION TYPES ───────────────────────────────────────────────────────────────
# PUSH              — Moves dial toward player win (+)
# RESIST            — Applies Traction status; reduces dealer's next pull by base_val
# CONDITIONAL_PUSH  — PUSH only fires if dial matches target_val OR (dial % target_mod == 0)
# DELAY_PUSH        — PUSH resolves after delay_turns, not immediately
# MULTIPLIER        — Applies a multiplier to the next card played this turn
# VENT              — Removes Overheat stacks; optionally pushes dial a small amount
# BLEED             — Applies Bleed to dealer: dealer's pulls reduced by stacks each turn
# GAMBLE            — base_val is the minimum; rolls up to base_val * 2 (high risk/reward)
# PRECISION_STRIKE  — Pushes base_val; if dial lands EXACTLY on a multiple of target_mod, bonus

const CARDS: Dictionary = {

	# ── COMMON ─────────────────────────────────────────────────────────────────

	"piston_jab": {
		"name": "Piston Jab",
		"action": "PUSH",
		"type": "NUMBER",
		"base_val": 3,
		"variance": 1,           # Resolves 2–4
		"rarity": "COMMON",
		"tag": ["STEAM"],
		"art": "res://Assets/Pixel Fantasy Player Cards/Player Cards/card-clubs-3.png",
		"description": "A reliable forward stroke. Pushes the dial by 2–4.",
	},

	"grounding_cleats": {
		"name": "Grounding Cleats",
		"action": "RESIST",
		"type": "NUMBER",
		"base_val": 3,
		"variance": 0,           # Fixed: always reduces next dealer pull by 3
		"rarity": "COMMON",
		"tag": ["DEFENSE"],
		"art": "res://Assets/Pixel Fantasy Player Cards/Player Cards/card-spades-3.png",
		"description": "Plant your feet. Reduces the Dealer's next pull by 3.",
	},

	"pressure_gauge": {
		"name": "Pressure Gauge",
		"action": "VENT",
		"type": "NUMBER",
		"base_val": 1,
		"variance": 0,
		"drain_val": 2,          # Removes 2 Overheat stacks
		"rarity": "COMMON",
		"tag": ["STEAM"],
		"art": "res://Assets/Pixel Fantasy Player Cards/Player Cards/card-hearts-2.png",
		"description": "Bleed off steam. Removes 2 Overheat, pushes +1.",
	},

	"rivet_tap": {
		"name": "Rivet Tap",
		"action": "PUSH",
		"type": "NUMBER",
		"base_val": 2,
		"variance": 0,           # Fixed push of 2 — boring but safe
		"rarity": "COMMON",
		"tag": ["PRECISION"],
		"art": "res://Assets/Pixel Fantasy Player Cards/Player Cards/card-diamonds-2.png",
		"description": "Measured and exact. Pushes exactly +2, no variance.",
	},

	# ── UNCOMMON ───────────────────────────────────────────────────────────────

	"overdrive": {
		"name": "Overdrive",
		"action": "PUSH",
		"type": "NUMBER",
		"base_val": 7,
		"variance": 2,           # Resolves 5–9
		"cost": {"type": "OVERHEAT", "amount": 2}, # STRONGLY TYPED
		"rarity": "UNCOMMON",
		"tag": ["HEAVY", "STEAM"],
		"art": "res://Assets/Pixel Fantasy Player Cards/Player Cards/card-clubs-7.png",
		"description": "Massive thrust. Pushes 5–9 but adds 2 Overheat.",
	},

	"windup_spring": {
		"name": "Wind-up Spring",
		"action": "DELAY_PUSH",
		"type": "MAGIC",
		"base_val": 7,
		"variance": 1,           # Resolves 6–8 on trigger turn
		"delay_turns": 1,
		"rarity": "UNCOMMON",
		"tag": ["STEAM"],
		"art": "res://Assets/Pixel Fantasy Player Cards/Player Cards/card-hearts-7.png",
		"description": "Coil tension now, release next turn. Pushes 6–8 at start of your next turn.",
	},

	"gear_multiplier": {
		"name": "Overdrive Gear",
		"action": "MULTIPLIER",
		"type": "MAGIC",
		"base_val": 0,
		"variance": 0,
		"multiplier": 1.5,       # Next card's resolved value × 1.5 (rounded down)
		"free_action": true,     # PLAYER KEEPS THEIR TURN
		"rarity": "UNCOMMON",
		"tag": ["STEAM"],
		"art": "res://Assets/Pixel Fantasy Player Cards/Player Cards/card-diamonds-4.png",
		"description": "Engage a higher gear. The next card you play is worth 1.5× its rolled value.",
	},

	"sweet_spot": {
		"name": "Sweet Spot",
		"action": "CONDITIONAL_PUSH",
		"type": "MAGIC",
		"base_val": 3,
		"variance": 0,
		"target_mod": 5,         # Bonus fires if dial % 5 == 0
		"bonus_val": 8,          # Extra push if condition met (total 3+8=11)
		"rarity": "UNCOMMON",
		"tag": ["PRECISION"],
		"art": "res://Assets/Pixel Fantasy Player Cards/Player Cards/card-hearts-5.png",
		"description": "Pushes +3. If the dial is on a multiple of 5, pushes +11 instead.",
	},

	"iron_brace": {
		"name": "Iron Brace",
		"action": "RESIST",
		"type": "NUMBER",
		"base_val": 6,
		"variance": 1,           # Reduces next dealer pull by 5–7
		"cost": {"type": "OVERHEAT", "amount": 1}, # STRONGLY TYPED
		"rarity": "UNCOMMON",
		"tag": ["DEFENSE", "HEAVY"],
		"art": "res://Assets/Pixel Fantasy Player Cards/Player Cards/card-spades-6.png",
		"description": "Heavy protection. Reduces Dealer's next pull by 5–7, but adds 1 Overheat.",
	},

	"rust_bleed": {
		"name": "Rust Bleed",
		"action": "BLEED",
		"type": "MAGIC",
		"base_val": 1,
		"variance": 0,
		"stacks": 2,             # Applies 2 Bleed to dealer (each reduces dealer pull by 1/stack/turn)
		"rarity": "UNCOMMON",
		"tag": ["ATTRITION"],
		"art": "res://Assets/Pixel Fantasy Player Cards/Player Cards/card-spades-2.png",
		"description": "Corrode the mechanism. Dealer's pulls are reduced by 1 per Bleed stack for 2 turns.",
	},

	# ── RARE ───────────────────────────────────────────────────────────────────

	"redline": {
		"name": "Redline",
		"action": "PUSH",
		"type": "NUMBER",
		"base_val": 10,
		"variance": 3,           # Resolves 7–13
		"cost": {"type": "OVERHEAT", "amount": 3}, # STRONGLY TYPED
		"rarity": "RARE",
		"tag": ["HEAVY", "STEAM"],
		"art": "res://Assets/Pixel Fantasy Player Cards/Player Cards/card-clubs-10.png",
		"description": "Push everything to the limit. Pushes 7–13, adds 3 Overheat. Dangerous.",
	},

	"dead_reckoning": {
		"name": "Dead Reckoning",
		"action": "PRECISION_STRIKE",
		"type": "MAGIC",
		"base_val": 5,
		"variance": 0,
		"target_mod": 5,
		"bonus_val": 10,         # Lands exactly on multiple of 5 → +10 bonus on top of push
		"rarity": "RARE",
		"tag": ["PRECISION", "STEAM"],
		"art": "res://Assets/Pixel Fantasy Player Cards/Player Cards/card-diamonds-5.png",
		"description": "Pushes +5. If the result lands exactly on a multiple of 5, gain +10 additional.",
	},

	"emergency_vent": {
		"name": "Emergency Vent",
		"action": "VENT",
		"type": "MAGIC",
		"base_val": 2,
		"variance": 0,
		"drain_val": 99,         # Clears ALL Overheat
		"rarity": "RARE",
		"tag": ["DEFENSE", "STEAM"],
		"art": "res://Assets/Pixel Fantasy Player Cards/Player Cards/card-hearts-9.png",
		"description": "Full pressure release. Clears all Overheat stacks, pushes +2.",
	},

	"governor_lock": {
		"name": "Governor Lock",
		"action": "RESIST",
		"type": "MAGIC",
		"base_val": 10,
		"variance": 0,
		"stacks": 1,             # Applies "LOCKED" status — dealer's NEXT TURN does 0 pull
		"rarity": "RARE",
		"tag": ["DEFENSE", "PRECISION"],
		"art": "res://Assets/Pixel Fantasy Player Cards/Player Cards/card-spades-10.png",
		"description": "Engage the governor. The Dealer's next turn pull is reduced to zero.",
	},

	"double_action": {
		"name": "Double Action",
		"action": "MULTIPLIER",
		"type": "MAGIC",
		"base_val": 0,
		"variance": 0,
		"multiplier": 2.0,       # Next card's value × 2.0 — high ceiling, pairs with Overheat risk
		"cost": {"type": "OVERHEAT", "amount": 2}, # STRONGLY TYPED
		"free_action": true,     # PLAYER KEEPS THEIR TURN
		"rarity": "RARE",
		"tag": ["HEAVY", "STEAM"],
		"art": "res://Assets/Pixel Fantasy Player Cards/Player Cards/card-hearts-8.png",
		"description": "Push twice as hard. Next card played hits for 2× value, but adds 2 Overheat.",
	},
}

static func get_cards_by_type(card_type: String) -> Array[String]:
	var result: Array[String] = []
	for card_id in CARDS:
		if CARDS[card_id].get("type", "") == card_type:
			result.append(card_id)
	return result

static func get_available_cards(include_magic: bool) -> Array[String]:
	var result: Array[String] = []
	for card_id in CARDS:
		var card = CARDS[card_id]
		if card.get("type", "") == "NUMBER":
			result.append(card_id)
		elif include_magic and card.get("type", "") == "MAGIC":
			result.append(card_id)
	return result
