extends Node
## What does perfect play look like?
##   godot --headless --path . res://tools/strategy_report.tscn
##
## Plays whole runs under a set of named policies and reports how deep each
## one gets. The point is not to find the best bot; it is to find out whether
## one line of play dominates, which would mean the choices on offer are not
## really choices.

const RUNS := 200
const GUARD := 600


func _ready() -> void:
	_budget()
	_turn_ceiling()
	_policies()
	_lever_isolation()
	_reroll_question()
	_how_runs_end()
	get_tree().quit(0)


## Which constraint actually kills a run: the Ledger running out of lines, or
## the man across the table taking them?
func _how_runs_end() -> void:
	print("\n=== How runs end (best policy, %d runs) ===" % RUNS)
	var reasons := {}
	var lines_spent := 0
	var nights := 0
	for seed_value in RUNS:
		var game := _play("stake rail, all draws", seed_value)
		var key := "ledger full" if game.end_reason.find("Ledger is full") >= 0 else \
			("adversary took the card" if game.end_reason.find("seven lines") >= 0 else "other")
		if game.victory:
			key = "won"
		reasons[key] = reasons.get(key, 0) + 1
		lines_spent += game.card.spend_order.size()
		nights += game.floor_number
	for key in reasons:
		print("  %-26s %d" % [key, reasons[key]])
	print("  mean lines spent: %.1f over %.1f nights (%.2f lines a night)"
		% [float(lines_spent) / RUNS, float(nights) / RUNS,
			float(lines_spent) / maxf(1.0, float(nights))])
	print("  points a line needs to average to finish: %d"
		% (11384 / maxi(1, Scoring.BOX_COUNT + Balance.duel_floors.size() * Balance.duel_reclaim)))


## What is one turn actually worth, against what each night demands? If the
## ladder outruns the dice, no policy can matter.
func _turn_ceiling() -> void:
	print("\n=== One turn against the ladder ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var samples := 20000
	var best_scores: Array[int] = []
	for _i in samples:
		var values: Array = []
		for _d in Balance.dice_per_roll:
			values.append(rng.randi_range(1, 6))
		var best := 0
		for box in Scoring.all_boxes():
			best = maxi(best, Scoring.score(box, values))
		best_scores.append(best)
	best_scores.sort()
	var mean := 0
	for v in best_scores:
		mean += v
	print("best-box value of a fresh roll, all 13 lines open:")
	print("  mean %d | median %d | p90 %d | p99 %d | max %d"
		% [mean / samples, best_scores[samples / 2], best_scores[int(samples * 0.9)],
			best_scores[int(samples * 0.99)], best_scores[samples - 1]])
	print("night  threshold  p(one fresh roll clears it, any line)")
	for n in range(1, Game.TOTAL_FLOORS + 1):
		var t := Balance.threshold_for_floor(n)
		var over := 0
		for v in best_scores:
			if v >= t:
				over += 1
		print("  %2d %10d  %6.2f%%" % [n, t, 100.0 * float(over) / float(samples)])


## The reroll is the turn's only free lever. Is it worth pulling?
func _reroll_question() -> void:
	print("\n=== The reroll ===")
	for policy in ["one throw, greedy", "all draws, greedy", "reroll only weak hands"]:
		var m := _measure(policy)
		print("  %-24s mean %.2f nights, run total %d"
			% [policy, m["mean"], int(m["total"])])


## The hard arithmetic of the run, before any dice are thrown.
func _budget() -> void:
	print("\n=== The line budget ===")
	var total := Scoring.BOX_COUNT
	var duels: int = Balance.duel_floors.size()
	print("lines on the Ledger: %d" % total)
	print("nights to survive:   %d" % Game.TOTAL_FLOORS)
	print("duel nights:         %d (each can reclaim %d) -> ceiling %d lines"
		% [duels, Balance.duel_reclaim, total + duels * Balance.duel_reclaim])
	var sum := 0
	for n in range(1, Game.TOTAL_FLOORS + 1):
		sum += Balance.threshold_for_floor(n)
	print("total points demanded across 12 nights: %d" % sum)
	print("night 12 alone demands: %d" % Balance.threshold_for_floor(Game.TOTAL_FLOORS))
	print("best single write in the game (yahtzee of sixes): %d"
		% Scoring.score(Scoring.Box.YAHTZEE, [6, 6, 6, 6, 6]))
	print("  ...on a full rail (x%d): %d"
		% [1 + Balance.dice_per_roll,
			Scoring.score(Scoring.Box.YAHTZEE, [6, 6, 6, 6, 6]) * (1 + Balance.dice_per_roll)])


func _policies() -> void:
	print("\n=== Policies over %d runs each ===" % RUNS)
	print("%-22s %7s %7s %7s %7s %7s" % ["policy", "mean", "median", "best", "wins", "total"])
	for policy in ["one throw, greedy", "all draws, greedy", "all draws, careful",
			"all draws, damn fool", "stake >=5, all draws", "stake rail, all draws",
			"clear-the-night", "hoard the big lines"]:
		_report(policy)


## Each lever on its own, against the same baseline, so it is clear which of
## them actually pays.
func _lever_isolation() -> void:
	print("\n=== Does the choice matter? ===")
	var base := _measure("all draws, greedy")
	for policy in ["one throw, greedy", "all draws, careful", "all draws, damn fool",
			"stake >=5, all draws", "clear-the-night"]:
		var m := _measure(policy)
		print("  %-24s %+.2f nights vs baseline" % [policy, m["mean"] - base["mean"]])


func _report(policy: String) -> void:
	var m := _measure(policy)
	print("%-22s %7.2f %7d %7d %7d %7d" % [policy, m["mean"], m["median"],
		m["best"], m["wins"], int(m["total"])])


func _measure(policy: String) -> Dictionary:
	var floors: Array[int] = []
	var wins := 0
	var totals := 0
	for seed_value in RUNS:
		var game := _play(policy, seed_value)
		floors.append(game.floor_number)
		totals += game.card.run_total
		if game.victory:
			wins += 1
	floors.sort()
	var sum := 0
	for f in floors:
		sum += f
	return {
		"mean": float(sum) / float(floors.size()),
		"median": floors[floors.size() / 2],
		"best": floors[floors.size() - 1],
		"wins": wins,
		"total": float(totals) / float(RUNS),
	}


func _play(policy: String, seed_value: int) -> Game:
	var game := Game.new()
	game.start_run(seed_value)
	var guard := 0
	while game.phase != Game.Phase.RUN_OVER and guard < GUARD:
		guard += 1
		if game.phase == Game.Phase.BENCH:
			_shop(game)
			game.leave_bench()
			continue
		_take_turn(game, policy)
	return game


## Buy whatever is affordable, cheapest first, while lines remain to spare.
## Spending a line here is spending a turn later, so the bot keeps a reserve.
func _shop(game: Game) -> void:
	var guard := 0
	while guard < 12:
		guard += 1
		var bought := false
		for offer in Bench.offers(game):
			var cost := int(offer["cost"])
			if not Bench.can_afford(game, cost):
				continue
			if game.card.open_count() - cost < 4:
				continue
			var target := -1
			if String(offer["target"]) == "die":
				target = game.pool.dice[0].id
			elif String(offer["target"]) == "bitter_die":
				for d in game.pool.dice:
					if d.bitter:
						target = d.id
			elif String(offer["target"]) == "filled_box":
				var filled := game.card.player_boxes()
				if filled.is_empty():
					continue
				target = filled[0]
			var open := game.card.open_boxes()
			if open.size() < cost:
				continue
			var pay: Array[int] = []
			for i in cost:
				pay.append(open[i])
			Bench.apply(game, offer["id"], pay, target)
			bought = true
			break
		if not bought:
			return


func _take_turn(game: Game, policy: String) -> void:
	var strength := _strength_for(policy)
	while game.draws_left() > 0:
		game.throw(strength)
		_stake(game, policy)
		if not _wants_another_draw(game, policy):
			break
	var boxes := game.card.open_boxes()
	if boxes.is_empty():
		return
	game.write_box(_choose_box(game, boxes, policy))


func _strength_for(policy: String) -> int:
	match policy:
		"all draws, careful":
			return Throw.Strength.SOFT
		"all draws, damn fool":
			return Throw.Strength.HARD
	return Throw.Strength.MEDIUM


func _wants_another_draw(game: Game, policy: String) -> bool:
	if policy == "one throw, greedy":
		return false
	if not game.can_throw():
		return false
	if policy == "reroll only weak hands":
		# Throw again only when what is on the felt cannot finish the night.
		# Every die is rerolled, so a good hand is destroyed by trying.
		var need := game.threshold - game.floor_score
		var best := 0
		for box in game.card.open_boxes():
			best = maxi(best, game.preview(box))
		return best < need
	return true


## Staking is for the whole night, not the turn, so a bot that stakes is
## making a much bigger commitment than a Yahtzee hold.
func _stake(game: Game, policy: String) -> void:
	match policy:
		"stake >=5, all draws":
			for d in game.pool.table:
				if not d.locked and not d.lost and d.value >= 5 and not game.would_lock_out(d):
					game.lock_die(d)
		"stake rail, all draws":
			for d in game.pool.table:
				if not d.locked and not d.lost and d.zone == Throw.Zone.RAIL \
						and not game.would_lock_out(d):
					game.lock_die(d)


func _choose_box(game: Game, boxes: Array, policy: String) -> int:
	var best: int = boxes[0]
	var best_value := -1
	for box in boxes:
		var v := game.preview(box)
		if v > best_value:
			best_value = v
			best = box
	match policy:
		"clear-the-night":
			# Spend the cheapest line that still finishes the night. Anything
			# more is a line burned for points you did not need.
			var need := game.threshold - game.floor_score
			var frugal := -1
			var frugal_value := 1 << 30
			for box in boxes:
				var v := game.preview(box)
				if v >= need and v < frugal_value:
					frugal_value = v
					frugal = box
			if frugal >= 0:
				return frugal
		"hoard the big lines":
			# Keep the exponential lines for later nights; spend the flat
			# upper ones early while thresholds are small.
			var need2 := game.threshold - game.floor_score
			var cheap := -1
			var cheap_value := 1 << 30
			for box in boxes:
				if not Scoring.UPPER_BOXES.has(box) and box != Scoring.Box.CHANCE:
					continue
				var v := game.preview(box)
				if v >= need2 and v < cheap_value:
					cheap_value = v
					cheap = box
			if cheap >= 0:
				return cheap
	return best
