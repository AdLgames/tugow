extends Node
## Every tunable number, so the curve can be re-tested without touching logic.
## See tools/curve_report.gd for the sweep this table was set from.

# --- The floor ---------------------------------------------------------------

const TILE := 64

## How the shop is laid out on screen. Both are built and both have art:
## isometric uses the delivered 2:1 diamonds, orthogonal uses the square
## tiles derived from them by tools/convert_tiles.py. The simulation is the
## same either way — see scripts/ui/projection.gd.
##
## The enum lives here rather than on GridMap2D because this is an autoload
## and parses before the class cache has heard of anything else.
enum View { ISOMETRIC, ORTHOGONAL }

var projection: int = View.ORTHOGONAL

## Level 1 is a clearing you can walk across. Level 2 is a warehouse.
var grid_size := {1: 8, 2: 16}

# --- Thralls -----------------------------------------------------------------

## A card is spent for as long as its thrall is in the woods, so the deck is
## your concurrency limit rather than a consumable. Running more thralls than
## you can sell for is how corruption starts.
var dispatch_seconds: float = 30.0
var haul_min: int = 1
var haul_max: int = 3
var starting_deck: int = 3
var max_deck: int = 8

# --- Customers ---------------------------------------------------------------

## Seconds between arrivals. Falls as the shop gets a reputation.
var spawn_interval: float = 9.0
var spawn_interval_min: float = 2.2
## Every sale makes the path a little busier.
var spawn_interval_per_sale: float = 0.06
var browse_seconds: float = 2.4
var walk_speed: float = 2.6   ## Tiles a second.
## A customer who finds nothing worth taking leaves, and says so by leaving.
var patience_seconds: float = 26.0

# --- Money -------------------------------------------------------------------

var starting_obols: int = 40
## What the shop is worth to walk into. Rises with what is on the tables.
var price_multiplier: float = 1.0

## Corruption eats the multiplier. At the cap you are working for nothing.
var corruption_per_rot: float = 1.0
var corruption_decay: float = 0.02      ## A second, once nothing is rotting.
var corruption_cap: float = 100.0
## Revenue multiplier at full corruption.
var corruption_worst: float = 0.15

# --- Level 2 -----------------------------------------------------------------

## Expansion price. Level 1 exists to reach this number.
var expansion_cost: int = 500

## Tribute owed to the Elder Gods, and how often the Void comes to check.
var audit_interval: float = 120.0
var tribute_rate: float = 0.18          ## Of revenue since the last audit.
## Failing an audit destroys this share of everything you hold.
var audit_penalty: float = 0.45
## Corruption above this is itself a finding.
var audit_corruption_limit: float = 35.0

## Display cases pull from the backroom on their own, at a price.
var case_cost: int = 220
var case_restock_seconds: float = 6.0
