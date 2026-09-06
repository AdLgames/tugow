class_name World
extends RefCounted
## The shop, running.
##
## Everything advances through `tick(delta)` with a seeded generator and no
## reference to frames, real time or the scene tree. That is what lets the
## whole game be played thousands of times headlessly in `tests/invariants.gd`
## while the view does nothing but draw what it finds here.

signal sold(good: int, obols: int, at: Vector2)
signal rotted(count: int)
signal returned(units: Array)
signal customer_left_empty()
signal expanded(level: int)
signal audited(passed: bool, tribute: int, destroyed: int)
signal changed()

const PLAYER_SPEED := 5.0

var level: int = 1
var shop: Shop
var thralls: Thralls
var rng := RandomNumberGenerator.new()

var obols: int = 0
var revenue: int = 0                 ## Everything ever taken. Only goes up.
var corruption: float = 0.0
var sales: int = 0
var lost_sales: int = 0
var rot_total: int = 0

## Level 2. Tribute accrues on revenue and the Void comes to collect.
var tribute_owed: int = 0
var audit_in: float = 0.0
var audits_passed: int = 0
var audits_failed: int = 0

## You, walking around. Tiles, fractional.
var player: Vector2 = Vector2.ZERO
var player_target: Vector2i = Vector2i.ZERO
var carrying: Goods.Unit = null

var customers: Array[Customer] = []
var _spawn_in: float = 0.0
var _clock: float = 0.0
var _case_timers: Dictionary = {}
var cases_owned: int = 0

var log_lines: Array[String] = []


func start(seed_value: int = 0) -> void:
	rng.seed = seed_value
	level = 1
	shop = Shop.new(Balance.grid_size[1])
	thralls = Thralls.new(Balance.starting_deck)
	obols = Balance.starting_obols
	revenue = 0
	corruption = 0.0
	sales = 0
	lost_sales = 0
	rot_total = 0
	tribute_owed = 0
	audits_passed = 0
	audits_failed = 0
	audit_in = Balance.audit_interval
	cases_owned = 0
	customers.clear()
	_case_timers.clear()
	log_lines.clear()
	_clock = 0.0
	_spawn_in = Balance.spawn_interval
	player = Vector2(shop.altar + Vector2i(0, 1))
	player_target = shop.altar + Vector2i(0, 1)
	note("The shop is yours. The counter was already warm.")


# --- The tick ----------------------------------------------------------------

func tick(delta: float) -> void:
	_clock += delta
	_tick_player(delta)
	_tick_thralls(delta)
	_tick_spoilage(delta)
	_tick_cases(delta)
	_tick_customers(delta)
	_tick_spawning(delta)
	_tick_corruption(delta)
	if level >= 2:
		_tick_audit(delta)
	changed.emit()


func _tick_player(delta: float) -> void:
	var goal := Vector2(player_target)
	var step := PLAYER_SPEED * delta
	if player.distance_to(goal) <= step:
		player = goal
		return
	player += (goal - player).normalized() * step


func _tick_thralls(delta: float) -> void:
	var back := thralls.tick(delta)
	if back.is_empty():
		return
	for unit in back:
		shop.backroom.append(unit)
	returned.emit(back)
	note("A thrall returns with %d." % back.size())


## Everything on a table and everything in the back is ageing at once.
func _tick_spoilage(delta: float) -> void:
	var turned := 0
	for key in shop.displays:
		for unit in shop.displays[key]:
			if unit.tick(delta):
				turned += 1
	for unit in shop.backroom:
		if unit.tick(delta):
			turned += 1
	if turned <= 0:
		return
	rot_total += turned
	corruption = minf(Balance.corruption_cap,
		corruption + float(turned) * Balance.corruption_per_rot)
	rotted.emit(turned)
	note("%d turned." % turned)


## Cases pull from the backroom on their own. This is the level 2 promise:
## you stop walking things out and start managing the flow into the room.
func _tick_cases(delta: float) -> void:
	if cases_owned <= 0:
		return
	for key in shop.displays:
		if shop.cells[key] != Shop.Cell.CASE:
			continue
		var left: float = float(_case_timers.get(key, Balance.case_restock_seconds)) - delta
		if left > 0.0:
			_case_timers[key] = left
			continue
		_case_timers[key] = Balance.case_restock_seconds
		if shop.backroom.is_empty():
			continue
		if shop.displays[key].size() >= Shop.TABLE_CAPACITY:
			continue
		shop.displays[key].append(shop.backroom.pop_front())


func _tick_spawning(delta: float) -> void:
	_spawn_in -= delta
	if _spawn_in > 0.0:
		return
	_spawn_in = maxf(Balance.spawn_interval_min,
		Balance.spawn_interval - float(sales) * Balance.spawn_interval_per_sale)
	customers.append(Customer.new(shop.door, rng.randi()))


## Corruption only fades once nothing is rotting, so it is a state you dig
## out of rather than something that forgives you on a timer.
func _tick_corruption(delta: float) -> void:
	if shop.rotted_on_floor() > 0:
		return
	corruption = maxf(0.0, corruption - Balance.corruption_decay * delta)


## The multiplier everything is sold at. Never zero — a ruined shop is still
## a shop, it is just barely worth opening.
func revenue_multiplier() -> float:
	var f := clampf(corruption / Balance.corruption_cap, 0.0, 1.0)
	return lerpf(Balance.price_multiplier, Balance.corruption_worst, f)


# --- Customers ---------------------------------------------------------------

func _tick_customers(delta: float) -> void:
	var alive: Array[Customer] = []
	for c in customers:
		c.glitching = false
		_step_customer(c, delta)
		if not c.done():
			alive.append(c)
	customers = alive


func _step_customer(c: Customer, delta: float) -> void:
	c.patience -= delta
	if c.patience <= 0.0 and c.state != Customer.State.PAYING \
			and c.state != Customer.State.LEAVING:
		_give_up(c)
		return

	match c.state:
		Customer.State.ENTERING:
			var stocked := shop.stocked_displays()
			if stocked.is_empty():
				_give_up(c)
				return
			var pick: int = stocked[c.seed_value % stocked.size()]
			c.target = shop.approach_to(shop.position_of(pick))
			c.state = Customer.State.TO_DISPLAY
		Customer.State.TO_DISPLAY:
			if c._walk(delta):
				c.state = Customer.State.BROWSING
				c.timer = Balance.browse_seconds
		Customer.State.BROWSING:
			c.timer -= delta
			if c.timer > 0.0:
				return
			var spot := _display_beside(c.target)
			var unit := _take_saleable(spot)
			if unit == null:
				# Someone got there first. Try again, or give up.
				c.state = Customer.State.ENTERING
				return
			c.carrying = unit
			c.target = shop.altar + Vector2i(0, 1)
			c.state = Customer.State.TO_ALTAR
		Customer.State.TO_ALTAR:
			if c._walk(delta):
				c.state = Customer.State.PAYING
				c.timer = 0.35
		Customer.State.PAYING:
			c.timer -= delta
			if c.timer > 0.0:
				return
			_take_payment(c)
			c.target = shop.door
			c.state = Customer.State.LEAVING
		Customer.State.LEAVING:
			if c._walk(delta):
				c.state = Customer.State.GONE


## The display next to where they are standing.
func _display_beside(spot: Vector2i) -> Vector2i:
	var steps: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(1, 0), Vector2i(-1, 0)]
	for step in steps:
		if shop.is_display(spot + step):
			return spot + step
	return spot


## Nobody buys something that has turned. They will dig past it, though.
func _take_saleable(at: Vector2i) -> Goods.Unit:
	var stock := shop.stock_at(at)
	for i in range(stock.size() - 1, -1, -1):
		if not stock[i].rotted:
			var unit: Goods.Unit = stock[i]
			stock.remove_at(i)
			return unit
	return null


func _take_payment(c: Customer) -> void:
	var paid := int(round(float(Goods.price(c.carrying.id)) * revenue_multiplier()))
	obols += paid
	revenue += paid
	sales += 1
	if level >= 2:
		tribute_owed += int(round(float(paid) * Balance.tribute_rate))
	# The frame their sprite is wrong.
	c.glitching = true
	sold.emit(c.carrying.id, paid, c.at)
	c.carrying = null


func _give_up(c: Customer) -> void:
	if c.state == Customer.State.LEAVING or c.state == Customer.State.GONE:
		return
	# Anything already picked up goes back where it can be found.
	if c.carrying != null:
		shop.backroom.append(c.carrying)
		c.carrying = null
	lost_sales += 1
	c.target = shop.door
	c.state = Customer.State.LEAVING
	customer_left_empty.emit()


# --- What you do -------------------------------------------------------------

func walk_to(at: Vector2i) -> void:
	if shop.walkable(at):
		player_target = at


func dispatch_thrall() -> bool:
	if not thralls.can_dispatch():
		return false
	var errand := thralls.dispatch(rng, level)
	note("A thrall goes into the trees for %s." % Goods.good_name(errand.good))
	changed.emit()
	return true


## Pick a unit out of the backroom to carry. You can hold one thing.
func take_from_backroom() -> bool:
	if carrying != null or shop.backroom.is_empty():
		return false
	carrying = shop.backroom.pop_front()
	changed.emit()
	return true


## Put what you are carrying on the display you are standing beside.
func place_carried(at: Vector2i) -> bool:
	if carrying == null:
		return false
	if not shop.is_display(at):
		return false
	if player.distance_to(Vector2(at)) > 1.9:
		return false
	if not shop.place(at, carrying):
		return false
	carrying = null
	changed.emit()
	return true


## Throw out everything that has turned, wherever it is.
func sweep() -> int:
	var n := shop.sweep_rot()
	if n > 0:
		note("%d swept off the floor." % n)
		changed.emit()
	return n


func can_afford(cost: int) -> bool:
	return obols >= cost


func buy_card() -> bool:
	var cost := card_cost()
	if not can_afford(cost) or thralls.deck >= Balance.max_deck:
		return false
	obols -= cost
	thralls.deck += 1
	note("Another thrall answers. The deck is %d." % thralls.deck)
	changed.emit()
	return true


## Each card is dearer than the last, so the deck is a decision every time.
func card_cost() -> int:
	return int(round(60.0 * pow(1.8, float(thralls.deck - Balance.starting_deck))))


func buy_case(at: Vector2i) -> bool:
	if level < 2 or not can_afford(Balance.case_cost):
		return false
	if not shop.is_display(at) or shop.get_cell(at) == Shop.Cell.CASE:
		return false
	obols -= Balance.case_cost
	shop.cells[shop.index_of(at)] = Shop.Cell.CASE
	_case_timers[shop.index_of(at)] = Balance.case_restock_seconds
	cases_owned += 1
	note("A case is installed. It will stock itself.")
	changed.emit()
	return true


## The point of level 1.
func can_expand() -> bool:
	return level == 1 and obols >= Balance.expansion_cost


func expand() -> bool:
	if not can_expand():
		return false
	obols -= Balance.expansion_cost
	level = 2
	shop.build(Balance.grid_size[2])
	player = Vector2(shop.altar + Vector2i(0, 1))
	player_target = shop.altar + Vector2i(0, 1)
	for c in customers:
		c.state = Customer.State.LEAVING
		c.target = shop.door
	audit_in = Balance.audit_interval
	note("The walls come down. What goes up is not wood.")
	expanded.emit(level)
	changed.emit()
	return true


# --- The Void ----------------------------------------------------------------

func _tick_audit(delta: float) -> void:
	audit_in -= delta
	if audit_in > 0.0:
		return
	audit_in = Balance.audit_interval
	_audit()


## Two ways to fail: not holding the tribute, or running a rotten floor. Both
## are the same failure — you were not watching the numbers.
func _audit() -> void:
	var owed := tribute_owed
	var passed := obols >= owed and corruption <= Balance.audit_corruption_limit
	var destroyed := 0
	if passed:
		obols -= owed
		tribute_owed = 0
		audits_passed += 1
		note("The Void reads the ledger and finds it adequate. %d paid." % owed)
	else:
		destroyed = int(round(float(obols) * Balance.audit_penalty))
		obols -= destroyed
		audits_failed += 1
		note("The audit fails. %d is unmade." % destroyed)
	audited.emit(passed, owed if passed else 0, destroyed)
	changed.emit()


# --- Readouts ----------------------------------------------------------------

func stock_summary() -> Dictionary:
	var out := {}
	for key in shop.displays:
		for unit in shop.displays[key]:
			out[unit.id] = int(out.get(unit.id, 0)) + 1
	for unit in shop.backroom:
		out[unit.id] = int(out.get(unit.id, 0)) + 1
	return out


func clock() -> float:
	return _clock


func note(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 120:
		log_lines.remove_at(0)
