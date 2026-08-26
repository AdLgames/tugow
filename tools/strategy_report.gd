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
const BEST_POLICY := "hold + stake rail"


func _ready() -> void:
	_budget()
	_turn_ceiling()
	_policies()
	_lever_isolation()
	_reroll_question()
	_how_runs_end()
	_depletion()
	_hold_experiment()
	_write_values()
	get_tree().quit(0)


## What a write is actually worth in play, as opposed to in the abstract.
func _write_values() -> void:
	print("\n=== What a write is worth in play ===")
	for policy in ["stake rail, all draws", "hold toward a line", "hold + stake rail"]:
		var writes: Array[int] = []
		var struck := 0
		for seed_value in 60:
			var game := Game.new()
			game.start_run(seed_value)
			var before := 0
			var guard := 0
			while game.phase != Game.Phase.RUN_OVER and guard < GUARD:
				guard += 1
				if game.phase == Game.Phase.BENCH:
					game.leave_bench()
					continue
				_take_turn(game, policy)
				writes.append(game.card.run_total - before)
				before = game.card.run_total
			struck += game.card.spend_order.size()
		writes.sort()
		var sum := 0
		var zeros := 0
		for v in writes:
			sum += v
			if v == 0:
				zeros += 1
		print("  %-22s mean %4d  median %4d  scratches %d%%"
			% [policy, sum / maxi(1, writes.size()), writes[writes.size() / 2],
				100 * zeros / maxi(1, writes.size())])


## What would a per-turn hold be worth? Today a redraw rerolls every die, so
## a hand can never be built toward a line — which is why the exotic lines
## are almost always a scratch. This simulates the same three draws with the
## player keeping dice toward a target, and re-measures what a line is worth.
## Nothing in the rules is changed; this is a measurement of a proposal.
func _hold_experiment() -> void:
	print("\n=== What a line would be worth with a per-turn hold ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	print("lines left   mean best write   median   (today's mean, for comparison)")
	var today := [74, 36, 23, 12, 4, 1, 0, 0, 0, 0, 0, 0, 0]
	for spent in range(0, Scoring.BOX_COUNT):
		var scores: Array[int] = []
		var samples := 3000
		for _i in samples:
			scores.append(_hold_turn(rng, spent))
		scores.sort()
		var sum := 0
		for v in scores:
			sum += v
		print("  %2d %14d %8d   (%d)"
			% [Scoring.BOX_COUNT - spent, sum / samples, scores[samples / 2], today[spent]])


## One turn with three draws, keeping the dice that serve the best target
## among the lines still open.
func _hold_turn(rng: RandomNumberGenerator, spent: int) -> int:
	var values: Array = []
	for _d in Balance.dice_per_roll:
		values.append(rng.randi_range(1, 6))
	# The lines a greedy player would already have spent are the ones that
	# score best on a typical hand, so what is left is the tail.
	var ranked := Scoring.all_boxes()
	ranked.sort_custom(func(a, b): return Scoring.score(a, values) > Scoring.score(b, values))
	var open_boxes: Array[int] = []
	for i in range(spent, ranked.size()):
		open_boxes.append(ranked[i])
	if open_boxes.is_empty():
		return 0
	for _draw in Balance.rerolls_per_turn:
		var target := _best_target(open_boxes, values)
		var keep := _keep_for(target, values)
		for i in values.size():
			if not keep[i]:
				values[i] = rng.randi_range(1, 6)
	var best := 0
	for box in open_boxes:
		best = maxi(best, Scoring.score(box, values))
	return best


## Which open line this hand is closest to being worth something on.
func _best_target(open_boxes: Array[int], values: Array) -> int:
	var best: int = open_boxes[0]
	var best_score := -1
	for box in open_boxes:
		# Judge a target by what it would pay if the kept dice repeated,
		# not by what the hand scores right now.
		var keep := _keep_for(box, values)
		var kept: Array = []
		for i in values.size():
			if keep[i]:
				kept.append(values[i])
		while kept.size() < values.size():
			kept.append(kept[0] if not kept.is_empty() else 1)
		var s := Scoring.score(box, kept)
		if s > best_score:
			best_score = s
			best = box
	return best


func _keep_for(box: int, values: Array) -> Array[bool]:
	var keep: Array[bool] = []
	for i in values.size():
		keep.append(false)
	match box:
		Scoring.Box.ACES, Scoring.Box.TWOS, Scoring.Box.THREES, \
		Scoring.Box.FOURS, Scoring.Box.FIVES, Scoring.Box.SIXES:
			var face := box + 1
			for i in values.size():
				keep[i] = values[i] == face
		Scoring.Box.THREE_KIND, Scoring.Box.FOUR_KIND, Scoring.Box.YAHTZEE, \
		Scoring.Box.FULL_HOUSE:
			var modal := _modal(values)
			for i in values.size():
				keep[i] = values[i] == modal
		Scoring.Box.SMALL_STRAIGHT, Scoring.Box.LARGE_STRAIGHT:
			var seen := {}
			for i in values.size():
				if not seen.has(values[i]):
					seen[values[i]] = true
					keep[i] = true
		Scoring.Box.CHANCE:
			for i in values.size():
				keep[i] = values[i] >= 5
	return keep


func _modal(values: Array) -> int:
	var counts := {}
	for v in values:
		counts[v] = counts.get(v, 0) + 1
	var best := 0
	var best_count := 0
	for face in counts:
		if counts[face] > best_count or (counts[face] == best_count and int(face) > best):
			best = int(face)
			best_count = counts[face]
	return best


## The heart of a week: as lines are spent the card gets worse, while the
## threshold climbs. If those two curves cross, the back half of a week is
## unplayable no matter how well it is played.
func _depletion() -> void:
	print("\n=== What a line is worth as the card empties ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	print("lines left   mean best write   median   p(>= that night's bar)")
	for spent in range(0, Scoring.BOX_COUNT):
		var left := Scoring.BOX_COUNT - spent
		# Spending greedily takes the best lines first, so what is left is
		# the tail. Model that by removing the boxes a greedy player would
		# have used on average: the high-scoring ones.
		var open_boxes: Array[int] = []
		for box in Scoring.all_boxes():
			open_boxes.append(box)
		var scores: Array[int] = []
		var samples := 4000
		for _i in samples:
			var values: Array = []
			for _d in Balance.dice_per_roll:
				values.append(rng.randi_range(1, 6))
			# Drop the `spent` boxes that scored best on a typical hand.
			var ranked := open_boxes.duplicate()
			ranked.sort_custom(func(a, b): return Scoring.score(a, values) > Scoring.score(b, values))
			var best := 0
			if spent < ranked.size():
				best = Scoring.score(ranked[spent], values)
			scores.append(best)
		scores.sort()
		var sum := 0
		for v in scores:
			sum += v
		# The night you would be on if you spent this many lines at the
		# budgeted rate of 13 lines across 7 nights.
		var night := mini(Balance.nights_per_week, spent * Balance.nights_per_week / Scoring.BOX_COUNT + 1)
		var bar := Balance.threshold_for_floor(night)
		var over := 0
		for v in scores:
			if v >= bar:
				over += 1
		print("  %2d %14d %8d   night %d bar %4d -> %5.1f%%"
			% [left, sum / samples, scores[samples / 2], night, bar,
				100.0 * float(over) / float(samples)])


## Which constraint actually kills a run: the Ledger running out of lines, or
## the man across the table taking them?
func _how_runs_end() -> void:
	print("\n=== How runs end (%s, %d runs) ===" % [BEST_POLICY, RUNS])
	var reasons := {}
	var lines_spent := 0
	var nights := 0
	for seed_value in RUNS:
		var game := _play(BEST_POLICY, seed_value)
		var key := "ledger full" if game.end_reason.find("Ledger is full") >= 0 else \
			("adversary took the card" if game.end_reason.find("seven lines") >= 0 else "other")
		if game.victory:
			key = "won"
		reasons[key] = reasons.get(key, 0) + 1
		lines_spent += game.card.spend_order.size()
		nights += game.floor_number
	for key in reasons:
		print("  %-26s %d" % [key, reasons[key]])
	print("  mean night reached: %.2f of %d" % [float(nights) / RUNS, Balance.total_nights()])
	print("  mean lines spent: %.1f over %.1f nights (%.2f lines a night)"
		% [float(lines_spent) / RUNS, float(nights) / RUNS,
			float(lines_spent) / maxf(1.0, float(nights))])
	var demand := 0
	for n in range(1, Game.total_nights() + 1):
		demand += Balance.threshold_for_floor(n)
	print("  points a line needs to average to finish: %d"
		% (demand / maxi(1, Scoring.BOX_COUNT * Balance.weeks_per_run)))


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
	for n in range(1, Game.total_nights() + 1):
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
	var duels: int = Balance.duel_floors().size()
	print("lines on the Ledger: %d, wiped clean every week" % total)
	print("weeks in a run:      %d of %d nights" % [Balance.weeks_per_run, Balance.nights_per_week])
	print("lines available:     %d over the run (%d a week)"
		% [total * Balance.weeks_per_run, total])
	print("nights to survive:   %d" % Game.total_nights())
	print("duel nights:         %d (each can reclaim %d) -> ceiling %d lines"
		% [duels, Balance.duel_reclaim, total + duels * Balance.duel_reclaim])
	var sum := 0
	for n in range(1, Game.total_nights() + 1):
		sum += Balance.threshold_for_floor(n)
	print("total points demanded across 12 nights: %d" % sum)
	print("the last night alone demands: %d" % Balance.threshold_for_floor(Game.total_nights()))
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
			"clear-the-night", "hoard the big lines",
			"hold toward a line", "hold + stake rail", "hold + clear-the-night"]:
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


## Lines are turns. Spending one at the bench is spending a night later, so
## the bot buys at most one thing a visit and only out of genuine surplus —
## an earlier version bought until it was broke and starved itself of turns,
## which is a trap a player can fall into just as easily.
func _shop(game: Game) -> void:
	var nights_left := Balance.nights_per_week - Balance.night_of(game.floor_number)
	if game.card.open_count() <= nights_left + 4:
		return
	var guard := 0
	while guard < 1:
		guard += 1
		var bought := false
		for offer in Bench.offers(game):
			var cost := int(offer["cost"])
			if not Bench.can_afford(game, cost):
				continue
			if game.card.open_count() - cost <= nights_left + 2:
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
		if policy.begins_with("hold"):
			_hold_toward_target(game)
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


## Pick the open line this hand is closest to paying on, and keep the dice
## that serve it. This is the whole point of the hold: without it a hand can
## never be built toward anything.
func _hold_toward_target(game: Game) -> void:
	var open_boxes := game.card.open_boxes()
	if open_boxes.is_empty():
		return
	var live: Array[Die] = []
	for d in game.pool.table:
		if not d.lost and d.value > 0:
			live.append(d)
	if live.is_empty():
		return
	var values: Array = []
	for d in live:
		values.append(d.value)
	var target := _best_target(open_boxes, values)
	var keep := _keep_for(target, values)
	for i in live.size():
		game.hold_die(live[i], keep[i])


func _wants_another_draw(game: Game, policy: String) -> bool:
	if policy == "one throw, greedy":
		return false
	if not game.can_throw():
		return false
	if policy.begins_with("hold"):
		# With a hold, a redraw only improves the dice you did not keep, so
		# it is always worth taking while anything is still free to move.
		return game.throwable_dice() > 0
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
		"hold + stake rail", "stake rail, all draws":
			for d in game.pool.table:
				if not d.locked and not d.lost and d.zone == Throw.Zone.RAIL \
						and not game.would_lock_out(d):
					game.lock_die(d)
		"stake >=5, all draws":
			for d in game.pool.table:
				if not d.locked and not d.lost and d.value >= 5 and not game.would_lock_out(d):
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
		"clear-the-night", "hold + clear-the-night":
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
