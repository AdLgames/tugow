class_name Scoring
extends RefCounted
## The resolver. Every box names an operation and the dice supply all the scale.
## No chips, no mult, no second currency.

enum Box {
	ACES,
	TWOS,
	THREES,
	FOURS,
	FIVES,
	SIXES,
	THREE_KIND,
	FOUR_KIND,
	FULL_HOUSE,
	SMALL_STRAIGHT,
	LARGE_STRAIGHT,
	YAHTZEE,
	CHANCE,
}

const BOX_COUNT := 13

const BOX_NAMES := {
	Box.ACES: "Aces",
	Box.TWOS: "Twos",
	Box.THREES: "Threes",
	Box.FOURS: "Fours",
	Box.FIVES: "Fives",
	Box.SIXES: "Sixes",
	Box.THREE_KIND: "Three of a Kind",
	Box.FOUR_KIND: "Four of a Kind",
	Box.FULL_HOUSE: "Full House",
	Box.SMALL_STRAIGHT: "Small Straight",
	Box.LARGE_STRAIGHT: "Large Straight",
	Box.YAHTZEE: "Yahtzee",
	Box.CHANCE: "Chance",
}

const BOX_RULES := {
	Box.ACES: "Sum of 1s x 1",
	Box.TWOS: "Sum of 2s x 2",
	Box.THREES: "Sum of 3s x 3",
	Box.FOURS: "Sum of 4s x 4",
	Box.FIVES: "Sum of 5s x 5",
	Box.SIXES: "Sum of 6s x 6",
	Box.THREE_KIND: "Sum of all five x 3",
	Box.FOUR_KIND: "Quad face cubed x 5",
	Box.FULL_HOUSE: "Triple x pair x 10",
	Box.SMALL_STRAIGHT: "Span (max 4) x highest x 5",
	Box.LARGE_STRAIGHT: "Product of all five",
	Box.YAHTZEE: "Face to the fourth x 2",
	Box.CHANCE: "Sum, +10 per 6",
}

const UPPER_BOXES: Array[Box] = [Box.ACES, Box.TWOS, Box.THREES, Box.FOURS, Box.FIVES, Box.SIXES]


static func box_name(box: int) -> String:
	return BOX_NAMES.get(box, "?")


static func box_rule(box: int) -> String:
	if Balance.curve == Balance.ScoreCurve.RAW:
		if box == Box.FOUR_KIND:
			return "Quad face to the fourth"
		if box == Box.YAHTZEE:
			return "Face to the fifth"
	return BOX_RULES.get(box, "")


static func all_boxes() -> Array[int]:
	var out: Array[int] = []
	for i in BOX_COUNT:
		out.append(i)
	return out


## Values of the five dice on the table, in any order.
static func score(box: int, values: Array) -> int:
	if values.is_empty():
		return 0
	var counts := _counts(values)
	match box:
		Box.ACES, Box.TWOS, Box.THREES, Box.FOURS, Box.FIVES, Box.SIXES:
			var face := box + 1
			return counts.get(face, 0) * face * face
		Box.THREE_KIND:
			if _max_of_a_kind(counts) < 3:
				return 0
			return _sum(values) * 3
		Box.FOUR_KIND:
			var quad := _face_with_at_least(counts, 4)
			if quad == 0:
				return 0
			if Balance.curve == Balance.ScoreCurve.RAW:
				return int(pow(quad, 4))
			return int(pow(quad, 3)) * 5
		Box.FULL_HOUSE:
			var pair := _full_house_faces(counts)
			if pair.is_empty():
				return 0
			return pair[0] * pair[1] * 10
		Box.SMALL_STRAIGHT:
			var run := _longest_run(counts)
			if run.size() < 4:
				return 0
			# A small straight spans four at most: a five-run scores its best four.
			var span := mini(run.size(), 4)
			return span * run[run.size() - 1] * 5
		Box.LARGE_STRAIGHT:
			var big := _longest_run(counts)
			if big.size() < 5:
				return 0
			return _product(values)
		Box.YAHTZEE:
			var face_all := _face_with_at_least(counts, 5)
			if face_all == 0:
				return 0
			if Balance.curve == Balance.ScoreCurve.RAW:
				return int(pow(face_all, 5))
			return int(pow(face_all, 4)) * 2
		Box.CHANCE:
			var total := _sum(values)
			for v in values:
				if v == 6:
					total += Balance.chance_six_bonus
			return total
	return 0


## True when the dice actually satisfy the box's pattern (so a zero is a
## deliberate scratch rather than a mis-click).
static func is_pattern_met(box: int, values: Array) -> bool:
	if box == Box.CHANCE:
		return true
	if box in UPPER_BOXES:
		return _counts(values).get(box + 1, 0) > 0
	return score(box, values) > 0


static func _counts(values: Array) -> Dictionary:
	var counts := {}
	for v in values:
		counts[v] = counts.get(v, 0) + 1
	return counts


static func _sum(values: Array) -> int:
	var total := 0
	for v in values:
		total += int(v)
	return total


static func _product(values: Array) -> int:
	var total := 1
	for v in values:
		total *= int(v)
	return total


static func _max_of_a_kind(counts: Dictionary) -> int:
	var best := 0
	for face in counts:
		best = maxi(best, counts[face])
	return best


static func _face_with_at_least(counts: Dictionary, n: int) -> int:
	var best := 0
	for face in counts:
		if counts[face] >= n:
			best = maxi(best, int(face))
	return best


## Returns [triple_face, pair_face] or [] when there is no full house.
static func _full_house_faces(counts: Dictionary) -> Array:
	var triple := 0
	var pair := 0
	var faces := counts.keys()
	faces.sort()
	faces.reverse()
	for face in faces:
		if counts[face] >= 3 and triple == 0:
			triple = int(face)
	if triple == 0:
		return []
	for face in faces:
		if int(face) == triple:
			continue
		if counts[face] >= 2:
			pair = maxi(pair, int(face))
	# Five of a kind counts as a full house of itself.
	if pair == 0 and counts.get(triple, 0) >= 5:
		pair = triple
	if pair == 0:
		return []
	return [triple, pair]


## Longest run of consecutive distinct faces, ascending.
static func _longest_run(counts: Dictionary) -> Array:
	var faces := counts.keys()
	faces.sort()
	var best: Array = []
	var current: Array = []
	for face in faces:
		if current.is_empty() or int(face) == int(current[current.size() - 1]) + 1:
			current.append(int(face))
		else:
			current = [int(face)]
		if current.size() > best.size():
			best = current.duplicate()
	return best
