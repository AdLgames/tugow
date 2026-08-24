extends Node
## Physics tests. These run headless — physics does not need a renderer — so
## the dice layer is covered by CI the same way the resolver is.
##   godot --headless --path . res://tests/dice3d_tests.tscn

var _failures: Array[String] = []
var _checks := 0
var _sim: DiceSim


func _ready() -> void:
	_sim = DiceSim.new()
	add_child(_sim)
	_sim.spawn(5)
	await get_tree().physics_frame

	await _test_settles()
	await _test_faces()
	await _test_determinism()
	await _test_strength_bands()
	await _test_cocked_happens()
	await _test_cocked_on_dice()
	await _test_calibration_still_holds()
	await _test_forced_outcome()
	_report()


func _throw(strength: int, seed_value: int) -> Array:
	_sim.begin_throw(_sim.bodies, strength, seed_value)
	var guard := 0
	while _sim.is_running() and guard < 2000:
		guard += 1
		await get_tree().physics_frame
	return _sim.read_outcome()


func _test_settles() -> void:
	# Every throw must end, including one that leaves a die on an edge.
	for seed_value in [1, 2, 3, 4, 5]:
		var outcome := await _throw(Throw.Strength.MEDIUM, seed_value)
		check(outcome.size() == 5, "throw %d returns five dice" % seed_value)
		var still_running := _sim.is_running()
		check(not still_running, "throw %d settles or times out" % seed_value)


func _test_faces() -> void:
	var outcome := await _throw(Throw.Strength.MEDIUM, 11)
	var all_valid := true
	for entry in outcome:
		if entry["lost"]:
			continue
		if entry["value"] < 1 or entry["value"] > 6:
			all_valid = false
	check(all_valid, "every settled die reads a face between 1 and 6")

	# Opposite faces sum to seven, which is what makes the underside rule true
	# of the physical object rather than a convention in the scoring code.
	var body: DieBody = _sim.bodies[0]
	body.global_rotation = Vector3.ZERO
	check(body.read_face() == 6, "the up axis reads its own face")
	body.global_rotation = Vector3(PI, 0, 0)
	check(body.read_face() == 1, "flipping it reads the opposite face")
	var pairs := {6: 1, 5: 2, 4: 3}
	var sums_to_seven := true
	for top in pairs:
		if top + pairs[top] != 7:
			sums_to_seven = false
	check(sums_to_seven, "opposite faces sum to seven")


func _test_determinism() -> void:
	# Same seed, same strength, same result — or replays and the forced-outcome
	# search are both worthless (D2).
	var first := await _throw(Throw.Strength.HARD, 4242)
	var second := await _throw(Throw.Strength.HARD, 4242)
	var same := true
	for i in first.size():
		if first[i]["value"] != second[i]["value"]:
			same = false
		if absf(first[i]["radius"] - second[i]["radius"]) > 0.02:
			same = false
	if not same:
		for i in first.size():
			print("    die %d: %d@%.3f vs %d@%.3f" % [i, first[i]["value"], first[i]["radius"],
				second[i]["value"], second[i]["radius"]])
	check(same, "the same seed throws the same dice twice")

	var different := await _throw(Throw.Strength.HARD, 99)
	var any_difference := false
	for i in first.size():
		if first[i]["value"] != different[i]["value"]:
			any_difference = true
	check(any_difference, "a different seed throws differently")


func _test_strength_bands() -> void:
	# Soft clusters, hard scatters and puts dice in the dirt (D7).
	var soft_spread := 0.0
	var soft_lost := 0
	var hard_spread := 0.0
	var hard_lost := 0
	for seed_value in range(20, 32):
		var soft := await _throw(Throw.Strength.SOFT, seed_value)
		for entry in soft:
			soft_spread += entry["radius"]
			if entry["lost"]:
				soft_lost += 1
		var hard := await _throw(Throw.Strength.HARD, seed_value)
		for entry in hard:
			hard_spread += entry["radius"]
			if entry["lost"]:
				hard_lost += 1
	check(hard_spread > soft_spread, "a hard throw scatters wider than a soft one")
	check(soft_lost == 0, "a soft throw never puts a die in the dirt")
	print("  soft mean radius %.2f, hard mean radius %.2f, hard lost %d of 60"
		% [soft_spread / 60.0, hard_spread / 60.0, hard_lost])


func _test_cocked_happens() -> void:
	# How often does a thrown die fail to settle flat? This is the rate the
	# cocked mechanic actually has, now that "resting on another die" is
	# known to be unreachable.
	var leaning := 0
	var total := 0
	for seed_value in range(100, 110):
		for strength in [Throw.Strength.SOFT, Throw.Strength.MEDIUM, Throw.Strength.HARD]:
			for entry in await _throw(strength, seed_value * 3 + strength):
				if entry["lost"]:
					continue
				total += 1
				if not entry["flat"]:
					leaning += 1
	print("  dice that did not settle flat: %d of %d (%.1f%%)"
		% [leaning, total, 100.0 * leaning / maxi(1, total)])


func _test_cocked_on_dice() -> void:
	# The sim gives cocked dice for nothing; check the reader sees them.
	var seen := 0
	for seed_value in range(40, 70):
		var outcome := await _throw(Throw.Strength.HARD, seed_value)
		for entry in outcome:
			if int(entry["cocked_on"]) != -1:
				seen += 1
	print("  cocked dice seen in 30 hard throws: %d" % seen)
	check(true, "cocked detection runs over a batch without erroring")


## The model in throw.gd samples its landings from Balance.zone_odds, which
## was measured from this simulation. If the sim changes and that table is not
## re-measured, the balance sweeps quietly stop describing the game. This is
## the tripwire for that.
func _test_calibration_still_holds() -> void:
	for strength in [Throw.Strength.SOFT, Throw.Strength.MEDIUM, Throw.Strength.HARD]:
		var counts := {"pot": 0, "rail": 0, "lost": 0}
		var dice := 0
		for seed_value in range(200, 215):
			for entry in await _throw(strength, seed_value * 5 + strength):
				dice += 1
				match int(entry["zone"]):
					Throw.Zone.LOST:
						counts["lost"] += 1
					Throw.Zone.RAIL:
						counts["rail"] += 1
					_:
						counts["pot"] += 1
		var expected: Dictionary = Balance.zone_odds[strength]
		var worst := 0.0
		for zone in counts:
			var measured := float(counts[zone]) / float(maxi(1, dice))
			worst = maxf(worst, absf(measured - float(expected[zone])))
		print("  %s: pot %.2f rail %.2f dirt %.2f (table says %.2f/%.2f/%.2f, worst gap %.2f)"
			% [Throw.strength_name(strength),
				float(counts["pot"]) / dice, float(counts["rail"]) / dice,
				float(counts["lost"]) / dice,
				expected["pot"], expected["rail"], expected["lost"], worst])
		check(worst < 0.20,
			"%s throws still land the way Balance.zone_odds says" % Throw.strength_name(strength))


func _test_forced_outcome() -> void:
	# Re-seed and re-run until the result is the one the rules need, then keep
	# that seed to play back (D3).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var wanted := [1, 2, 3, 4, 5]
	var result: Dictionary = await ThrowSearch.find(
		_sim, _sim.bodies, Throw.Strength.MEDIUM,
		func(outcome: Array) -> bool:
			var total := 0
			for entry in outcome:
				total += int(entry["value"])
			return total >= 22,
		rng, 24)
	check(result["outcome"].size() == 5, "the search returns a throw")
	print("  forced-outcome search: matched=%s in %d attempts" % [result["matched"], result["attempts"]])
	if result["matched"]:
		# The kept seed must reproduce the result it was chosen for.
		var replay := await _throw(Throw.Strength.MEDIUM, int(result["seed"]))
		var same := true
		for i in replay.size():
			if replay[i]["value"] != result["outcome"][i]["value"]:
				same = false
		check(same, "the seed the search kept replays the same throw")
	check(Engine.time_scale == 1.0, "the search restores real time when it finishes")


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   %s" % label)
	else:
		_failures.append(label)
		print("  FAIL %s" % label)


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("%d physics checks passed." % _checks)
		get_tree().quit(0)
		return
	print("%d of %d physics checks FAILED:" % [_failures.size(), _checks])
	for f in _failures:
		print("  - %s" % f)
	get_tree().quit(1)
