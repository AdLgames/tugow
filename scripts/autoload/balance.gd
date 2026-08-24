extends Node
## All tunable numbers live here so the curve can be re-tested without
## touching game logic. See tools/curve_report.gd for the resolver sweep.

## Scoring curve variant.
## RAW      — the design doc's first pass: Four of a Kind = face^4, Yahtzee = face^5.
## TEMPERED — the balance-flag fix: Four of a Kind = face^3 * 5, Yahtzee = face^4 * 2.
enum ScoreCurve { RAW, TEMPERED }

var curve: ScoreCurve = ScoreCurve.TEMPERED

# --- Floors -----------------------------------------------------------------

## Threshold for floor 1.
var floor_base_threshold: int = 60
## Multiplier applied per floor descended. The doc's starting guess is 1.6x.
var floor_scaling: float = 1.45
## Floors that host an Adversary instead of a plain threshold.
var duel_floors: PackedInt32Array = [3, 5, 7, 9, 10, 11, 12]

## Chance adds this per 6 shown. Doubling per 6 made a mediocre roll clear an
## early floor on its own — see docs/BALANCE.md.
var chance_six_bonus: int = 10

## Scoring past a threshold banks the difference toward the next floor.
var overflow_carry_ratio: float = 1.0
## ...but never more than this fraction of the next threshold, so a monster
## turn cannot skip a floor.
var overflow_carry_cap: float = 0.5

# --- The throw ---------------------------------------------------------------

## How the rail's double stacks with the category operations. Open question
## #7 — the exponential form is what the spec describes literally; the sweep
## in tools/curve_report.gd is why the default is not that.
enum RailMode { EXPONENTIAL, LINEAR, FLAT }

var rail_mode: RailMode = RailMode.LINEAR

## Landing radius band per Throw.Strength: soft never reaches the rail,
## medium can, hard can go past the lip entirely.
var throw_bands: Dictionary = {
	0: Vector2(0.00, 0.45),   # SOFT
	1: Vector2(0.10, 0.85),   # MEDIUM
	2: Vector2(0.35, 1.18),   # HARD — about a 1-in-5 chance per die of going off
}

## How far a die already resting on the rail is shoved by the next throw.
var rail_push: Dictionary = {
	0: 0.00,   # SOFT — leaves it alone
	1: 0.12,   # MEDIUM
	2: 0.45,   # HARD — usually takes it off the table
}

var rail_inner_radius: float = 0.60
## Dice landing closer than this knock each other to new faces.
var collision_radius: float = 0.18
## Closer still, and one is resting on the other: cocked.
var stack_radius: float = 0.05
var max_collision_chain: int = 12

## Physical throw profiles — impulse, spin and lift per strength. These are
## the same three bands as the model's landing radii, expressed as forces.
var throw_impulses: Dictionary = {
	0: {"impulse": 3.4, "spin": 0.9, "spread": 0.5, "lift": 0.6},    # SOFT
	1: {"impulse": 5.2, "spin": 1.8, "spread": 1.1, "lift": 1.0},    # MEDIUM
	2: {"impulse": 6.2, "spin": 2.8, "spread": 1.9, "lift": 1.5},    # HARD
}

## Physics drives the visible throw; the model in throw.gd stays the headless
## path for tests and the balance sweeps.
var use_physics_dice: bool = true

# --- Dice -------------------------------------------------------------------

var pool_size: int = 8
var dice_per_roll: int = 5
var rerolls_per_turn: int = 2
## Locks a die needs to accumulate before one of its faces is reshaped.
var facet_threshold: int = 3

# --- Scorecard --------------------------------------------------------------

var boxes_per_turn: int = 1
## Boxes the Adversary must claim before it takes the card outright.
var adversary_card_limit: int = 7
## Boxes returned to you for out-scoring an Adversary (open question #5).
var duel_reclaim: int = 3

# --- Bench ------------------------------------------------------------------

var bench_costs: Dictionary = {
	"reshape_face": 1,
	"cleanse_bitter": 1,
	"ninth_die": 2,
	"overwrite_box": 1,
	"take_charm": 1,
}


func threshold_for_floor(n: int) -> int:
	return int(round(floor_base_threshold * pow(floor_scaling, float(n - 1))))


func is_duel_floor(n: int) -> bool:
	return duel_floors.has(n)
