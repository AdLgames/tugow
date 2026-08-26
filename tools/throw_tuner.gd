extends Node
## Sweeps the physical throw profiles and reports what each band actually
## does: where dice come to rest, and how often a throw costs you one.
##
## This is open question F5's instrument — "does throw strength feel like a
## decision?" cannot be answered until the three bands measurably differ.
##   godot --headless --path . res://tools/throw_tuner.tscn

const RUNS := 20
## The sweep is dozens of throws; run them faster than real time.
const TIME_SCALE := 24.0

var _sim: DiceSim


func _ready() -> void:
	_sim = DiceSim.new()
	add_child(_sim)
	_sim.spawn(5)
	await get_tree().physics_frame

	Engine.physics_ticks_per_second = int(60.0 * TIME_SCALE)
	Engine.max_physics_steps_per_frame = int(TIME_SCALE * 8.0)
	Engine.time_scale = TIME_SCALE
	print("\n=== Throw profile sweep ===")
	print("impulse  lift  spin  | mean radius  in pot  on rail  in the dirt")
	if "--sweep" in OS.get_cmdline_user_args():
		for impulse in [1.6, 2.4, 3.2, 4.0, 4.8, 5.6, 6.4, 7.2]:
			await _measure(impulse, 1.4, impulse * 0.45)
	# Damn Fool loses a third of its dice, which makes it never worth throwing.
	# These are the candidates for a band that is a gamble rather than a
	# mistake: still the widest reach, but survivable.
	if "--hard" in OS.get_cmdline_user_args():
		print("\n=== Damn Fool candidates ===")
		for candidate in [[5.4, 1.3], [5.6, 1.4], [5.8, 1.5], [5.6, 1.6], [5.8, 1.7]]:
			await _measure(candidate[0], 1.5, 2.4, "i%.1f s%.1f" % [candidate[0], candidate[1]],
				candidate[1])
	print("\n=== Committed bands ===")
	for strength in [Throw.Strength.SOFT, Throw.Strength.MEDIUM, Throw.Strength.HARD]:
		var profile: Dictionary = Balance.throw_impulses[strength]
		await _measure(float(profile["impulse"]), float(profile["lift"]),
			float(profile["spin"]), Throw.strength_name(strength), float(profile["spread"]))
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	get_tree().quit(0)


func _measure(impulse: float, lift: float, spin: float, label: String = "",
		spread: float = 1.1) -> void:
	var original: Dictionary = Balance.throw_impulses[Throw.Strength.MEDIUM].duplicate()
	Balance.throw_impulses[Throw.Strength.MEDIUM] = {
		"impulse": impulse, "spin": spin, "spread": spread, "lift": lift,
	}
	var radius_total := 0.0
	var pot := 0
	var rail := 0
	var dirt := 0
	var dice := 0
	for seed_value in range(1, RUNS + 1):
		_sim.begin_throw(_sim.bodies, Throw.Strength.MEDIUM, seed_value * 31)
		var guard := 0
		while _sim.is_running() and guard < 2000:
			guard += 1
			await get_tree().physics_frame
		for entry in _sim.read_outcome():
			dice += 1
			if entry["lost"]:
				dirt += 1
				continue
			radius_total += float(entry["radius"])
			if float(entry["radius"]) >= Balance.rail_inner_radius:
				rail += 1
			else:
				pot += 1
	Balance.throw_impulses[Throw.Strength.MEDIUM] = original
	var landed := maxi(1, dice - dirt)
	print("%5.1f  %4.1f  %4.1f  |  %10.2f  %5.0f%%  %6.0f%%  %10.0f%%   %s" % [
		impulse, lift, spin, radius_total / landed,
		100.0 * pot / dice, 100.0 * rail / dice, 100.0 * dirt / dice, label,
	])
