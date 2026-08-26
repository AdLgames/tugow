extends Node
## Curve visualisation for open questions #1 and #2.
##   godot --headless --path . res://tools/curve_report.tscn
##
## Prints: the operator table at every face, a Monte Carlo estimate of what a
## turn is actually worth, the floor threshold ladder, and how deep a greedy
## bot gets under each scoring curve.

const SAMPLES := 20000
const RUNS := 60


func _ready() -> void:
	_operator_table()
	_turn_value()
	_floor_ladder()
	_depth_sweep()
	_reclaim_sweep()
	_carry_sweep()
	_rail_sweep()
	get_tree().quit(0)


func _operator_table() -> void:
	print("\n=== Operators by face ===")
	print("face  upper(x5)  3kind  4kind  full house  yahtzee")
	for face in range(1, 7):
		var five := [face, face, face, face, face]
		var upper := Scoring.score(face - 1, five)
		var three := Scoring.score(Scoring.Box.THREE_KIND, five)
		var four := Scoring.score(Scoring.Box.FOUR_KIND, [face, face, face, face, 1])
		var fh := Scoring.score(Scoring.Box.FULL_HOUSE, [face, face, face, 3, 3])
		var y := Scoring.score(Scoring.Box.YAHTZEE, five)
		print("  %d %9d %6d %6d %11d %8d" % [face, upper, three, four, fh, y])
	print("large straight 2-6: %d" % Scoring.score(Scoring.Box.LARGE_STRAIGHT, [2, 3, 4, 5, 6]))
	print("chance 6,6,5,4,3:   %d (+%d per 6)" % [Scoring.score(Scoring.Box.CHANCE, [6, 6, 5, 4, 3]), Balance.chance_six_bonus])


## What is one turn worth? Roll five fair dice, take the best open box.
func _turn_value() -> void:
	print("\n=== Best-box value of a fresh roll (%d samples) ===" % SAMPLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var totals := 0
	var histogram := {}
	var best_ever := 0
	for _i in SAMPLES:
		var values: Array = []
		for _d in 5:
			values.append(rng.randi_range(1, 6))
		var best := 0
		var best_box := 0
		for box in Scoring.BOX_COUNT:
			var v := Scoring.score(box, values)
			if v > best:
				best = v
				best_box = box
		totals += best
		best_ever = maxi(best_ever, best)
		histogram[best_box] = histogram.get(best_box, 0) + 1
	print("mean best score per roll: %.1f   ceiling seen: %d" % [float(totals) / SAMPLES, best_ever])
	var keys := histogram.keys()
	keys.sort_custom(func(a, b): return histogram[a] > histogram[b])
	for box in keys:
		print("  %-16s picked %5.1f%%" % [Scoring.box_name(box), 100.0 * histogram[box] / SAMPLES])


func _floor_ladder() -> void:
	print("\n=== Floor thresholds (base %d, x%.2f per floor) ===" % [Balance.floor_base_threshold, Balance.floor_scaling])
	for n in range(1, Game.TOTAL_FLOORS + 1):
		var tag := "  duel" if Balance.is_duel_floor(n) else ""
		print("  floor %2d: %7d%s" % [n, Balance.threshold_for_floor(n), tag])


func _depth_sweep() -> void:
	print("\n=== Greedy bot depth ===")
	var original_curve: int = Balance.curve
	var original_scaling: float = Balance.floor_scaling
	for curve in [Balance.ScoreCurve.RAW, Balance.ScoreCurve.TEMPERED]:
		Balance.curve = curve
		for scaling in [1.4, 1.5, 1.6]:
			Balance.floor_scaling = scaling
			var depths: Array[int] = []
			for seed_value in range(1, RUNS + 1):
				depths.append(_play(seed_value))
			depths.sort()
			var sum := 0
			for d in depths:
				sum += d
			print("  curve=%-8s scaling=%.2f  mean floor %.2f  median %d  best %d"
				% ["RAW" if curve == Balance.ScoreCurve.RAW else "TEMPERED",
					scaling, float(sum) / depths.size(), depths[depths.size() / 2], depths[depths.size() - 1]])
	Balance.curve = original_curve
	Balance.floor_scaling = original_scaling


## Open question #7: rail doubling on top of exponential categories.
func _rail_sweep() -> void:
	print("\n=== Rail multiplier (open question #7) ===")
	var original: int = Balance.rail_mode
	# What one rail Large Straight is worth under each shape.
	var straight := Scoring.score(Scoring.Box.LARGE_STRAIGHT, [2, 3, 4, 5, 6])
	for mode in [Balance.RailMode.EXPONENTIAL, Balance.RailMode.LINEAR, Balance.RailMode.FLAT]:
		Balance.rail_mode = mode
		var label: String = ["EXPONENTIAL", "LINEAR", "FLAT"][mode]
		var line := "  %-12s  large straight on the rail:" % label
		for rail_dice in [1, 3, 5]:
			var dice: Array[Die] = []
			for i in rail_dice:
				var d := Die.new(i, "d", null)
				d.zone = Throw.Zone.RAIL
				dice.append(d)
			line += "  %dx=%d" % [rail_dice, int(straight * Throw.rail_multiplier(dice))]
		print(line)
	for mode in [Balance.RailMode.EXPONENTIAL, Balance.RailMode.LINEAR, Balance.RailMode.FLAT]:
		Balance.rail_mode = mode
		var sum := 0
		var best := 0
		for seed_value in range(1, RUNS + 1):
			var depth := _play(seed_value)
			sum += depth
			best = maxi(best, depth)
		var name: String = ["EXPONENTIAL", "LINEAR", "FLAT"][mode]
		print("  %-12s  mean floor %.2f  best %d  (threshold at floor 12: %d)"
			% [name, float(sum) / RUNS, best,
				Balance.threshold_for_floor(12)])
	Balance.rail_mode = original


## How much of an overshoot should carry to the next floor?
func _carry_sweep() -> void:
	print("\n=== Overflow carry ===")
	var original: float = Balance.overflow_carry_ratio
	for ratio in [0.0, 0.5, 1.0]:
		Balance.overflow_carry_ratio = ratio
		var sum := 0
		var best := 0
		for seed_value in range(1, RUNS + 1):
			var depth := _play(seed_value)
			sum += depth
			best = maxi(best, depth)
		print("  carry=%.2f  mean floor %.2f  best %d" % [ratio, float(sum) / RUNS, best])
	Balance.overflow_carry_ratio = original


## Open question #5: how many boxes should out-scoring an Adversary return?
func _reclaim_sweep() -> void:
	print("\n=== Reclaim generosity ===")
	var original: int = Balance.duel_reclaim
	for reclaim in [0, 1, 2, 3, 4, 5]:
		Balance.duel_reclaim = reclaim
		var sum := 0
		var wins := 0
		for seed_value in range(1, RUNS + 1):
			var depth := _play(seed_value)
			sum += depth
			if depth > Game.TOTAL_FLOORS:
				wins += 1
		print("  reclaim=%d  mean floor %.2f  full clears %d/%d" % [reclaim, float(sum) / RUNS, wins, RUNS])
	Balance.duel_reclaim = original


func _play(seed_value: int) -> int:
	var game := Game.new()
	game.start_run(seed_value)
	var guard := 0
	while game.phase != Game.Phase.RUN_OVER and guard < 400:
		guard += 1
		if game.phase == Game.Phase.BENCH:
			game.leave_bench()
			continue
		# The table starts empty each turn: throw before reading it.
		if not game.turn_rolled:
			game.throw()
		for d in game.pool.table:
			if d.value >= 5:
				game.lock_die(d)
		var boxes := game.card.open_boxes()
		var best: int = boxes[0]
		var best_value := -1
		for box in boxes:
			var v := game.preview(box)
			if v > best_value:
				best_value = v
				best = box
		game.write_box(best)
	return game.floor_number
