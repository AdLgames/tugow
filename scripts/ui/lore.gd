class_name Lore
extends RefCounted
## Every player-facing word in one place. The mechanics are boxes, floors and
## locking; the fiction is a ledger of debts on the last night of a long game.
## Code ids never change — only what the player reads.
##
## Source: docs/design-system/BUILD_BRIEF_table_scene.md, "Fiction and naming".

const CARD := "The Ledger"
const BOX := "line"
const BOXES := "lines"
const OWED := "owed"
const LOCK_VERB := "Stake"
const LOCKED_TAG := "STAKED"
const THROW := "The Draw"
const FLOOR := "Night"
const BENCH := "The Assayer's Office"

## Adversary display names for the western pass. Ids stay as they are.
const ADVERSARY_NAMES := {
	&"taxman": "The Taxman",
	&"magpie": "The Magpie",
	&"reflection": "Your Brother",
	&"fire": "The Fire",
	&"debtor": "The Debtor",
}


static func adversary_name(id: StringName, fallback: String) -> String:
	return ADVERSARY_NAMES.get(id, fallback)


## "9 lines owed" / "1 line owed"
static func lines_owed(count: int) -> String:
	return "%d %s %s" % [count, BOX if count == 1 else BOXES, OWED]


## "in 1 draw" / "in 3 draws"
static func draws(count: int) -> String:
	return "%d %s" % [count, "draw" if count == 1 else "draws"]


## Nights are numbered inside their week, because that is the unit the
## player is budgeting against: "Night 3" of seven, not night 17 of 35.
static func night(n: int) -> String:
	return "%s %d" % [FLOOR, Balance.night_of(n)]


## Where the run is, in full: "Week 2 · Night 3".
static func week_and_night(n: int) -> String:
	return "Week %d · %s %d" % [Balance.week_of(n), FLOOR, Balance.night_of(n)]


## "3 nights left this week" — the real budget line.
static func nights_left(n: int) -> String:
	var left := Balance.nights_per_week - Balance.night_of(n)
	if left == 0:
		return "last night of the week"
	return "%d %s left this week" % [left, "night" if left == 1 else "nights"]
