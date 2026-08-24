class_name Bench
extends RefCounted
## Between floors. The only currency is your scorecard: every upgrade shortens
## the run that the upgrade exists to extend.


static func offers(game: Game) -> Array:
	var out: Array = []
	out.append({
		"id": &"reshape_face",
		"label": "Reshape a face",
		"detail": "Pull a die's weakest face up one pip.",
		"cost": Balance.bench_costs["reshape_face"],
		"target": "die",
	})
	out.append({
		"id": &"ninth_die",
		"label": "Pull another die into the pool",
		"detail": "The pool grows to %d." % (game.pool.dice.size() + 1),
		"cost": Balance.bench_costs["ninth_die"],
		"target": "none",
	})
	if _has_bitter(game):
		out.append({
			"id": &"cleanse_bitter",
			"label": "Cleanse a bitter die",
			"detail": "It rolls honestly again.",
			"cost": Balance.bench_costs["cleanse_bitter"],
			"target": "bitter_die",
		})
	if not game.card.player_boxes().is_empty():
		out.append({
			"id": &"overwrite_box",
			"label": "Overwrite a box you hate",
			"detail": "Reopen a box you already filled; its points leave the run total.",
			"cost": Balance.bench_costs["overwrite_box"],
			"target": "filled_box",
		})
	var charm := next_charm(game)
	if charm != null:
		out.append({
			"id": &"take_charm",
			"label": "Take the charm: %s" % charm.charm_name,
			"detail": charm.text,
			"cost": Balance.bench_costs["take_charm"],
			"target": "none",
		})
	return out


## The charm on offer tonight, or null when tonight's charm is already bought.
static func next_charm(game: Game) -> Charm:
	if game.charms_taken_tonight >= Balance.charms_per_night:
		return null
	for c in Charms.library():
		if not game.has_charm(c.id):
			return c
	return null


static func can_afford(game: Game, cost: int) -> bool:
	# You must keep at least one box: a run with no boxes is over.
	return game.card.open_count() - cost >= 1


## `sacrifices` are open boxes to burn; `target` is a die id or box index.
static func apply(game: Game, offer_id: StringName, sacrifices: Array, target: int = -1) -> bool:
	var cost: int = Balance.bench_costs.get(String(offer_id), 1)
	if sacrifices.size() != cost or not can_afford(game, cost):
		return false
	for box in sacrifices:
		if not game.card.is_open(box):
			return false

	match offer_id:
		&"reshape_face":
			var die := game.pool.get_die(target)
			if die == null or not die.reshape_weakest():
				return false
			game.log_line("Bench: %s reshaped to %s." % [die.die_name, str(Array(die.faces))])
		&"ninth_die":
			var added := game.pool.add_die()
			game.log_line("Bench: %s joins the pool (%d dice)." % [added.die_name, game.pool.dice.size()])
		&"cleanse_bitter":
			var bitter_die := game.pool.get_die(target)
			if bitter_die == null or not bitter_die.bitter:
				return false
			bitter_die.cleanse()
			game.log_line("Bench: %s is cleansed." % bitter_die.die_name)
		&"overwrite_box":
			if target < 0 or game.card.states[target] != Scorecard.State.PLAYER:
				return false
			game.card.overwrite(target, 0, Scorecard.State.OPEN)
			game.log_line("Bench: %s is yours to fill again." % Scoring.box_name(target))
		&"take_charm":
			var charm := next_charm(game)
			if charm == null:
				return false
			game.take_charm(charm)
		_:
			return false

	for box in sacrifices:
		game.card.burn(box)
		game.log_line("The bench takes %s. %d boxes left." % [Scoring.box_name(box), game.card.open_count()])
	game.state_changed.emit()
	return true


static func _has_bitter(game: Game) -> bool:
	for d in game.pool.dice:
		if d.bitter:
			return true
	return false
