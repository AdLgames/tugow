class_name Thralls
extends RefCounted
## The deck, and what is out in the woods.
##
## A card is not spent, it is *away*. It comes back when its thrall does, so
## the size of the deck is how many errands you can have running at once.
## That is the whole tension: more thralls means more stock, and more stock
## than you can sell is what rots.

class Errand extends RefCounted:
	var remaining: float
	var haul: int
	var good: int

	func _init(p_remaining: float, p_haul: int, p_good: int) -> void:
		remaining = p_remaining
		haul = p_haul
		good = p_good


var deck: int = 0
var out: Array[Errand] = []


func _init(p_deck: int = 3) -> void:
	deck = p_deck


func ready_cards() -> int:
	return deck - out.size()


func can_dispatch() -> bool:
	return ready_cards() > 0


## Send one into the woods. `tier` is what the shop can currently stock.
func dispatch(rng: RandomNumberGenerator, tier: int) -> Errand:
	if not can_dispatch():
		return null
	var choices := Goods.for_tier(tier)
	var good: int = choices[rng.randi_range(0, choices.size() - 1)]
	var haul := rng.randi_range(Balance.haul_min, Balance.haul_max)
	var errand := Errand.new(Balance.dispatch_seconds, haul, good)
	out.append(errand)
	return errand


## Advance every errand. Returns the units that came back this tick.
func tick(delta: float) -> Array:
	var returned: Array = []
	var still_out: Array[Errand] = []
	for errand in out:
		errand.remaining -= delta
		if errand.remaining > 0.0:
			still_out.append(errand)
			continue
		for _i in errand.haul:
			returned.append(Goods.Unit.new(errand.good))
	out = still_out
	return returned


## How far along the nearest errand is, for the card that is closest to
## coming home. 1.0 when something is due.
func soonest_progress() -> float:
	var best := 0.0
	for errand in out:
		var done := 1.0 - clampf(errand.remaining / Balance.dispatch_seconds, 0.0, 1.0)
		best = maxf(best, done)
	return best
