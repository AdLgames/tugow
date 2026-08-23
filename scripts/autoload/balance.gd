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

# --- Forge ------------------------------------------------------------------

var forge_costs: Dictionary = {
	"reshape_face": 1,
	"ninth_die": 2,
	"cleanse_bitter": 1,
	"overwrite_box": 1,
	"take_charm": 1,
}


func threshold_for_floor(n: int) -> int:
	return int(round(floor_base_threshold * pow(floor_scaling, float(n - 1))))


func is_duel_floor(n: int) -> bool:
	return duel_floors.has(n)
