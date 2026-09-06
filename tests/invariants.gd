extends Node
## Property fuzz. Runs the shop badly — dispatching at random, stocking at
## random, never sweeping, expanding when it can — hundreds of times, and
## checks what must be true at every tick rather than the outcome of any run.
##
## Outcome tests pass on a shop that quietly loses stock. These are the ones
## that catch a unit falling out of the world.

const RUNS := 160
const TICKS := 1600
const DT := 0.2

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	var ticks := 0
	for seed_value in RUNS:
		ticks += _fuzz(seed_value)
	print("  %d ticks fuzzed across %d shops" % [ticks, RUNS])
	_report()


func _fuzz(seed_value: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 6011 + 7
	var world := World.new()
	world.start(seed_value)
	var tag := "seed %d" % seed_value

	for i in TICKS:
		# Play badly and at random.
		if rng.randf() < 0.10:
			world.dispatch_thrall()
		if rng.randf() < 0.12 and world.carrying == null:
			world.take_from_backroom()
		if rng.randf() < 0.12 and world.carrying != null:
			var spots := world.shop.display_indices()
			var at := world.shop.position_of(spots[rng.randi_range(0, spots.size() - 1)])
			# Placing needs you to be standing beside it, so walk there first.
			world.player = Vector2(at)
			world.place_carried(at)
		if rng.randf() < 0.02:
			world.sweep()
		if rng.randf() < 0.01:
			world.buy_card()
		if world.can_expand() and rng.randf() < 0.3:
			world.expand()
		if world.level >= 2 and rng.randf() < 0.01:
			var spots2 := world.shop.display_indices()
			world.buy_case(world.shop.position_of(spots2[rng.randi_range(0, spots2.size() - 1)]))
		world.tick(DT)
		_hold(world, tag)
	_hold(world, tag + " end")
	return TICKS


func _hold(world: World, tag: String) -> void:
	# Money is never negative, and revenue only ever goes up.
	_expect(world.obols >= 0, "%s: %d obols" % [tag, world.obols])
	_expect(world.revenue >= 0, "%s: revenue %d" % [tag, world.revenue])

	# Corruption stays inside its range, and the multiplier inside its.
	_expect(world.corruption >= 0.0 and world.corruption <= Balance.corruption_cap,
		"%s: corruption %.1f" % [tag, world.corruption])
	var mult := world.revenue_multiplier()
	_expect(mult >= Balance.corruption_worst and mult <= Balance.price_multiplier,
		"%s: multiplier %.2f" % [tag, mult])

	# The deck is a concurrency limit: never more thralls out than cards, and
	# a card is never destroyed by playing it.
	_expect(world.thralls.out.size() <= world.thralls.deck,
		"%s: %d thralls out on a deck of %d"
		% [tag, world.thralls.out.size(), world.thralls.deck])
	_expect(world.thralls.ready_cards() >= 0, "%s: negative hand" % tag)
	_expect(world.thralls.deck >= Balance.starting_deck
		and world.thralls.deck <= Balance.max_deck,
		"%s: deck of %d" % [tag, world.thralls.deck])

	# No table ever holds more than a table holds.
	for key in world.shop.displays:
		_expect(world.shop.displays[key].size() <= Shop.TABLE_CAPACITY,
			"%s: a display holds %d" % [tag, world.shop.displays[key].size()])

	# Everything on the floor is a real good, and a rotted unit is fully aged.
	for key in world.shop.displays:
		for unit in world.shop.displays[key]:
			_expect(Goods.TABLE.has(unit.id), "%s: an unknown thing is on a table" % tag)
			if unit.rotted:
				_expect(Goods.perishable(unit.id),
					"%s: something that keeps has turned" % tag)

	# Nothing that keeps ever turns, however long the shop runs.
	for unit in world.shop.backroom:
		if not Goods.perishable(unit.id):
			_expect(not unit.rotted, "%s: bone turned in the back" % tag)

	# Customers are always somewhere real and holding something real.
	for c in world.customers:
		_expect(c.state >= Customer.State.ENTERING and c.state <= Customer.State.GONE,
			"%s: a customer is in state %d" % [tag, c.state])
		_expect(c.at.x >= -1.0 and c.at.y >= -1.0
			and c.at.x <= float(world.shop.size) and c.at.y <= float(world.shop.size),
			"%s: a customer is outside the shop at %s" % [tag, c.at])
		if c.carrying != null:
			_expect(Goods.TABLE.has(c.carrying.id),
				"%s: a customer is holding an unknown thing" % tag)
			_expect(not c.carrying.rotted, "%s: a customer picked up rot" % tag)

	# The level and the floor agree about how big the shop is.
	_expect(world.shop.size == Balance.grid_size[world.level],
		"%s: level %d on a floor of %d" % [tag, world.level, world.shop.size])

	# Sales and lost sales are only ever counted forward.
	_expect(world.sales >= 0 and world.lost_sales >= 0,
		"%s: negative sales" % tag)

	# Level 1 never owes tribute, because the Void has not noticed it yet.
	if world.level == 1:
		_expect(world.tribute_owed == 0,
			"%s: tribute owed before the Void was watching" % tag)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition and not _failures.has(message):
		_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print("\n%d invariant checks passed." % _checks)
		get_tree().quit(0)
		return
	print("\n%d distinct invariant FAILURES over %d checks:" % [_failures.size(), _checks])
	for f in _failures:
		print("  - %s" % f)
	get_tree().quit(1)
