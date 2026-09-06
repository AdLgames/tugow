extends Node
## The rules. The sim is deterministic and steps by delta, so a whole shop
## day runs here in milliseconds and none of it needs a window.

var _passed := 0
var _failed: Array[String] = []


func _ready() -> void:
	_test_goods()
	_test_shop_layout()
	_test_every_display_is_reachable()
	_test_placing()
	_test_deck_is_a_concurrency_limit()
	_test_haul_returns()
	_test_spoilage()
	_test_corruption()
	_test_a_sale()
	_test_empty_shop_turns_people_away()
	_test_nobody_buys_rot()
	_test_expansion_keeps_the_stock()
	_test_cases_restock_themselves()
	_test_audit()
	_test_determinism()
	_report()


# --- Goods -------------------------------------------------------------------

func _test_goods() -> void:
	check(Goods.all_ids().size() == 4, "there are four goods")
	check(Goods.for_tier(1).size() == 2, "level 1 stocks two of them")
	check(Goods.for_tier(2).size() == 4, "level 2 stocks all four")
	for id in Goods.all_ids():
		check(Goods.price(id) > 0, "%s has a price" % Goods.good_name(id))
		check(Goods.blurb(id) != "", "%s has a blurb" % Goods.good_name(id))
	# The whole level 2 pivot is that the good stuff does not keep.
	for id in Goods.for_tier(1):
		check(not Goods.perishable(id), "%s keeps" % Goods.good_name(id))
	for id in Goods.all_ids():
		if Goods.for_tier(1).has(id):
			continue
		check(Goods.perishable(id), "%s does not keep" % Goods.good_name(id))
		check(Goods.price(id) > 100, "%s is worth the trouble" % Goods.good_name(id))


# --- The floor ---------------------------------------------------------------

func _test_shop_layout() -> void:
	var shop := Shop.new(8)
	check(shop.size == 8, "level 1 is eight across")
	check(shop.get_cell(shop.altar) == Shop.Cell.ALTAR, "the counter is an altar")
	check(shop.get_cell(shop.door) == Shop.Cell.DOOR, "and there is a way in")
	check(not shop.display_indices().is_empty(), "there are tables to stock")
	for x in shop.size:
		check_quiet(shop.get_cell(Vector2i(x, 0)) == Shop.Cell.WALL, "the shop is walled")
	check(true, "the shop is walled in")

	var big := Shop.new(16)
	check(big.display_indices().size() > shop.display_indices().size(),
		"the expansion is more room, not just more floor")
	var has_backroom := false
	for i in big.cells.size():
		if big.cells[i] == Shop.Cell.BACKROOM:
			has_backroom = true
	check(has_backroom, "and it has a backroom")


## A table nobody can stand beside is a table nothing sells from.
func _test_every_display_is_reachable() -> void:
	for size in [8, 16]:
		var shop := Shop.new(size)
		for index in shop.display_indices():
			var at := shop.position_of(index)
			var spot := shop.approach_to(at)
			check_quiet(shop.walkable(spot),
				"size %d: a display can be reached" % size)
			check_quiet(spot != at, "size %d: from a tile beside it" % size)
	check(true, "every display on both floors can be walked up to")


func _test_placing() -> void:
	var shop := Shop.new(8)
	var at := shop.position_of(shop.display_indices()[0])
	for i in Shop.TABLE_CAPACITY:
		check_quiet(shop.place(at, Goods.Unit.new(Goods.Id.SHATTERED_BONE)),
			"a table takes stock")
	check(shop.stock_at(at).size() == Shop.TABLE_CAPACITY, "a table holds three")
	check(not shop.place(at, Goods.Unit.new(Goods.Id.SHATTERED_BONE)),
		"and no more than three")
	check(shop.take(at) != null, "and it can be taken off again")


# --- Thralls -----------------------------------------------------------------

## The deck is not a consumable. A card is away while its thrall is, which is
## what makes the deck a limit on how much you can have in flight.
func _test_deck_is_a_concurrency_limit() -> void:
	var world := World.new()
	world.start(11)
	check(world.thralls.ready_cards() == Balance.starting_deck, "the deck starts full")
	for i in Balance.starting_deck:
		check_quiet(world.dispatch_thrall(), "a card can be played")
	check(world.thralls.ready_cards() == 0, "playing them all empties the hand")
	check(not world.dispatch_thrall(), "and there is nothing left to play")
	check(world.thralls.deck == Balance.starting_deck, "but the deck is not smaller")

	# Wait them home and the cards come back.
	for _i in int(Balance.dispatch_seconds * 10.0) + 4:
		world.tick(0.1)
	check(world.thralls.ready_cards() == Balance.starting_deck,
		"a thrall coming home returns its card")


func _test_haul_returns() -> void:
	var world := World.new()
	world.start(12)
	world.dispatch_thrall()
	var before: int = world.shop.backroom.size()
	for _i in int(Balance.dispatch_seconds * 10.0) + 4:
		world.tick(0.1)
	var got: int = world.shop.backroom.size() - before
	check(got >= Balance.haul_min and got <= Balance.haul_max,
		"a thrall brings back one to three")

	# Over many errands the haul stays inside its band.
	var world2 := World.new()
	world2.start(13)
	for run in 40:
		while world2.thralls.can_dispatch():
			world2.dispatch_thrall()
		for _i in int(Balance.dispatch_seconds * 5.0) + 2:
			world2.tick(0.2)
	check(world2.shop.backroom.size() > 0, "and keeps bringing them")


# --- Rot ---------------------------------------------------------------------

func _test_spoilage() -> void:
	var keeps := Goods.Unit.new(Goods.Id.SHATTERED_BONE)
	for _i in 400:
		check_quiet(not keeps.tick(1.0), "bone does not turn")
	check(not keeps.rotted, "bone keeps for ever")
	check(is_zero_approx(keeps.spoilage()), "and never looks like turning")

	var turns := Goods.Unit.new(Goods.Id.PULSING_BIOMASS)
	var fired := 0
	for _i in 400:
		if turns.tick(1.0):
			fired += 1
	check(turns.rotted, "biomass turns")
	check(fired == 1, "and says so exactly once")
	check(is_equal_approx(turns.spoilage(), 1.0), "and reads as gone afterwards")

	var half := Goods.Unit.new(Goods.Id.FRESH_SCREAMS)
	half.tick(Goods.shelf_life(Goods.Id.FRESH_SCREAMS) * 0.5)
	check(absf(half.spoilage() - 0.5) < 0.02, "spoilage reads as it ages")


## Corruption is a hole you dig out of, not a timer that forgives you.
func _test_corruption() -> void:
	var world := World.new()
	world.start(21)
	world.level = 2
	var at := world.shop.position_of(world.shop.display_indices()[0])
	# Nearly gone already, so it turns before anyone can walk in and buy it.
	# Left fresh, a customer takes it long before its shelf life is up, which
	# is the whole point of the good stuff and not what is being checked here.
	var doomed := Goods.Unit.new(Goods.Id.PULSING_BIOMASS)
	doomed.age = Goods.shelf_life(Goods.Id.PULSING_BIOMASS) - 0.5
	world.shop.place(at, doomed)
	check(is_zero_approx(world.corruption), "a clean shop is not corrupt")

	for _i in 12:
		world.tick(0.1)
	check(world.corruption > 0.0, "letting stock turn is corrupting")
	check(world.rot_total >= 1, "and it is counted")
	check(world.revenue_multiplier() < 1.0, "which costs you on every sale")

	var held := world.corruption
	for _i in 30:
		world.tick(1.0)
	check(is_equal_approx(world.corruption, held),
		"and it does not fade while the rot is still on the floor")

	check(world.sweep() > 0, "sweeping clears it")
	for _i in 60:
		world.tick(1.0)
	check(world.corruption < held, "and only then does corruption fall")

	world.corruption = Balance.corruption_cap * 4.0
	world.tick(0.1)
	check(world.revenue_multiplier() >= Balance.corruption_worst,
		"a ruined shop still sells for something")


# --- Selling -----------------------------------------------------------------

func _test_a_sale() -> void:
	var world := World.new()
	world.start(31)
	var at := world.shop.position_of(world.shop.stocked_or_first())
	world.shop.place(at, Goods.Unit.new(Goods.Id.FEY_BERRIES))
	var before := world.obols
	var guard := 0
	while world.sales == 0 and guard < 4000:
		guard += 1
		world.tick(0.1)
	check(world.sales == 1, "someone comes in and buys it")
	check(world.obols > before, "and leaves money on the altar")
	check(world.revenue == world.obols - before, "which is counted as revenue")
	check(world.shop.units_on_floor() == 0, "and takes the item with them")


func _test_empty_shop_turns_people_away() -> void:
	var world := World.new()
	world.start(32)
	var guard := 0
	while world.lost_sales == 0 and guard < 4000:
		guard += 1
		world.tick(0.1)
	check(world.lost_sales > 0, "an empty shop turns people around")
	check(world.sales == 0, "and sells nothing")
	check(world.obols == Balance.starting_obols, "and takes nothing")


func _test_nobody_buys_rot() -> void:
	var world := World.new()
	world.start(33)
	var at := world.shop.position_of(world.shop.display_indices()[0])
	var unit := Goods.Unit.new(Goods.Id.FRESH_SCREAMS)
	unit.rotted = true
	world.shop.place(at, unit)
	check(world.shop.stocked_displays().is_empty(),
		"a table of rot counts as an empty table")
	for _i in 600:
		world.tick(0.1)
	check(world.sales == 0, "and nobody buys off it")
	check(world.shop.units_on_floor() == 1, "the rot is still sitting there")


# --- Growing -----------------------------------------------------------------

func _test_expansion_keeps_the_stock() -> void:
	var world := World.new()
	world.start(41)
	for i in 6:
		world.shop.backroom.append(Goods.Unit.new(Goods.Id.SHATTERED_BONE))
	var at := world.shop.position_of(world.shop.display_indices()[0])
	world.shop.place(at, Goods.Unit.new(Goods.Id.FEY_BERRIES))
	var total_before := world.shop.units_on_floor() + world.shop.backroom.size()

	check(not world.can_expand(), "you cannot expand while broke")
	world.obols = Balance.expansion_cost
	check(world.can_expand(), "the whole of level 1 is reaching this number")
	check(world.expand(), "and then the walls come down")
	check(world.level == 2, "which is level 2")
	check(world.shop.size == Balance.grid_size[2], "a bigger floor")
	check(world.shop.units_on_floor() + world.shop.backroom.size() == total_before,
		"and nothing you owned is lost in the move")
	check(not world.can_expand(), "and it only happens once")


func _test_cases_restock_themselves() -> void:
	var world := World.new()
	world.start(42)
	world.obols = Balance.expansion_cost + Balance.case_cost
	world.expand()
	var at := world.shop.position_of(world.shop.display_indices()[0])
	check(world.buy_case(at), "a case can be bought")
	check(world.shop.get_cell(at) == Shop.Cell.CASE, "and it goes in")
	for _i in 4:
		world.shop.backroom.append(Goods.Unit.new(Goods.Id.SHATTERED_BONE))
	var on_floor := world.shop.units_on_floor()
	for _i in int(Balance.case_restock_seconds * 20.0):
		world.tick(0.1)
	check(world.shop.units_on_floor() > on_floor,
		"and it pulls from the backroom without you")
	check(world.shop.stock_at(at).size() <= Shop.TABLE_CAPACITY,
		"and never overfills itself")


func _test_audit() -> void:
	var world := World.new()
	world.start(51)
	world.obols = Balance.expansion_cost
	world.expand()
	world.obols = 10000
	world.tribute_owed = 1000
	world.corruption = 0.0
	world._audit()
	check(world.audits_passed == 1, "the Void is satisfied when you can pay")
	check(world.obols == 9000, "and takes exactly what it is owed")
	check(world.tribute_owed == 0, "leaving nothing owed")

	# Not holding it is a finding.
	world.tribute_owed = 100000
	var held := world.obols
	world._audit()
	check(world.audits_failed == 1, "failing to pay is a finding")
	check(world.obols < held, "and costs you a share of everything")

	# So is running a rotten floor, even with the money in hand.
	var clean := World.new()
	clean.start(52)
	clean.obols = Balance.expansion_cost
	clean.expand()
	clean.obols = 100000
	clean.tribute_owed = 10
	clean.corruption = Balance.audit_corruption_limit + 1.0
	clean._audit()
	check(clean.audits_failed == 1, "so is a corrupt floor, however flush you are")


## Same seed, same shop. This is what lets the sweeps mean anything.
func _test_determinism() -> void:
	var a := World.new()
	var b := World.new()
	a.start(99)
	b.start(99)
	for i in 3000:
		a.tick(0.1)
		b.tick(0.1)
		if i % 400 == 0:
			a.dispatch_thrall()
			b.dispatch_thrall()
	check(a.obols == b.obols and a.sales == b.sales and a.lost_sales == b.lost_sales,
		"two shops on the same seed run identically")
	check(a.shop.backroom.size() == b.shop.backroom.size(),
		"down to what is in the back")


# --- Harness -----------------------------------------------------------------

func check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % message)
	else:
		_failed.append(message)
		print("  FAIL %s" % message)


func check_quiet(condition: bool, message: String) -> void:
	if not condition and not _failed.has(message):
		_failed.append(message)
		print("  FAIL %s" % message)


func _report() -> void:
	if _failed.is_empty():
		print("\n%d checks passed." % _passed)
		get_tree().quit(0)
		return
	print("\n%d of %d checks FAILED:" % [_failed.size(), _passed + _failed.size()])
	for f in _failed:
		print("  - %s" % f)
	get_tree().quit(1)
