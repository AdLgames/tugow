extends Node
## All tunable numbers live here so the curve can be re-tested without
## touching game logic. See tools/curve_report.gd for the resolver sweep.

## Scoring curve variant.
## RAW      — the design doc's first pass: Four of a Kind = face^4, Yahtzee = face^5.
## TEMPERED — the balance-flag fix: Four of a Kind = face^3 * 5, Yahtzee = face^4 * 2.
enum ScoreCurve { RAW, TEMPERED }

var curve: ScoreCurve = ScoreCurve.TEMPERED

# --- Weeks and nights --------------------------------------------------------
#
# A run is a handful of weeks, and a week is seven nights. The Ledger is
# wiped clean at the end of each week, which is what makes a week the real
# unit of play: thirteen lines have to carry you seven nights, not a whole
# run. Everything you scored is kept; only the paper is fresh.

var nights_per_week: int = 7
var weeks_per_run: int = 5

## Threshold for the first night of the first week.
var floor_base_threshold: int = 40
## Multiplier applied per night inside a week. The bar climbs all week.
var night_scaling: float = 1.10
## Multiplier applied to a week's opening night, week over week. A new week
## starts easier than the night before it ended on, but harder than the last
## week began — the sawtooth is the point.
var week_scaling: float = 1.55

## Chance adds this per 6 shown. Doubling per 6 made a mediocre roll clear an
## early floor on its own — see docs/BALANCE.md.
var chance_six_bonus: int = 10

## Scoring past a threshold banks the difference toward the next floor.
## This is the only way a good night pays for a later one, which makes it the
## counter to a card that empties in the back half of a week — deaths were
## clustered on nights 5 to 7 before the cap was raised.
var overflow_carry_ratio: float = 1.0
## ...but never the whole of the next threshold, so a monster turn cannot skip
## a night outright.
var overflow_carry_cap: float = 0.85

# --- The throw ---------------------------------------------------------------

## How the rail's double stacks with the category operations. Open question
## #7 — the exponential form is what the spec describes literally; the sweep
## in tools/curve_report.gd is why the default is not that.
enum RailMode { EXPONENTIAL, LINEAR, FLAT }

var rail_mode: RailMode = RailMode.LINEAR

## Where each strength puts a die, as measured from the physics sim by
## tools/throw_tuner.tscn — pot / rail / dirt.
##
## The model is a calibrated stand-in for the simulation, not a second opinion
## about it. Sampling the zone from these odds, then a radius inside that
## zone, makes the two paths agree by construction — which is what lets the
## balance sweeps run on the model and still describe the game the player
## gets. Re-run the tuner and update this table after any change to the dice,
## the table or the throw profiles.
var zone_odds: Dictionary = {
	0: {"pot": 0.85, "rail": 0.15, "lost": 0.00},   # SOFT
	1: {"pot": 0.50, "rail": 0.44, "lost": 0.06},   # MEDIUM
	2: {"pot": 0.32, "rail": 0.51, "lost": 0.17},   # HARD
}

## How often a settled die is left showing two faces at once, measured the
## same way. A die that does not lie flat is cocked.
var cocked_odds: float = 0.021

## The furthest a strength can reach, for the interface's aim preview.
func reach_of(strength: int) -> float:
	var odds: Dictionary = zone_odds[strength]
	if float(odds["lost"]) > 0.0:
		return 1.15
	return 1.0 if float(odds["rail"]) > 0.0 else rail_inner_radius

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
	# Damn Fool put a third of the dice in the dirt, which made it a mistake
	# rather than a gamble: measured over whole runs it cost two thirds of a
	# run's depth and was never the right call. Pulled back until it is the
	# widest reach on the table — the highest rail rate of the three bands —
	# at a survivable price.
	2: {"impulse": 5.6, "spin": 2.4, "spread": 1.6, "lift": 1.5},    # HARD
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

## Charms a week, awarded for surviving one. The bench is open every night,
## but a charm is what a finished week pays out — so charms mark weeks, and
## a run is as many charms as it is weeks.
var charms_per_week: int = 1

var bench_costs: Dictionary = {
	"reshape_face": 1,
	"cleanse_bitter": 1,
	"ninth_die": 2,
	"overwrite_box": 1,
	"take_charm": 1,
}


## Nights are numbered straight through the run; week and night-of-week are
## derived so nothing has to keep two counters in step.
func total_nights() -> int:
	return weeks_per_run * nights_per_week


func week_of(n: int) -> int:
	return (n - 1) / nights_per_week + 1


func night_of(n: int) -> int:
	return (n - 1) % nights_per_week + 1


## The last night of a week is the hardest night of that week; the first
## night of the next week drops back down, but not as far as the last week
## started.
func threshold_for_floor(n: int) -> int:
	var week := week_of(n)
	var night := night_of(n)
	return int(round(floor_base_threshold
		* pow(week_scaling, float(week - 1))
		* pow(night_scaling, float(night - 1))))


## He arrives later in the week early on, and earlier in the week as the run
## goes: week 1 he sits down only on the last night, week 5 for most of it.
## Difficulty comes from how much of the week he is at the table, not only
## from the numbers on the card.
func duel_nights_in_week(week: int) -> int:
	return clampi(week, 1, nights_per_week)


func is_duel_floor(n: int) -> bool:
	return night_of(n) > nights_per_week - duel_nights_in_week(week_of(n))


## Every night of the run that hosts an Adversary.
func duel_floors() -> Array[int]:
	var out: Array[int] = []
	for n in range(1, total_nights() + 1):
		if is_duel_floor(n):
			out.append(n)
	return out
