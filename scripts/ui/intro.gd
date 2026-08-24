class_name Intro
extends RefCounted
## What the game is, before the first hand. Five pages, each one thing.
##
## The rules that need saying are the ones no dice game has: the card does not
## reset, a turn costs a line whatever it scores, and staking lasts the night.
## Everything else a player can find out by playing.

class Page extends RefCounted:
	var title: String
	var lines: Array[String]

	func _init(p_title: String, p_lines: Array[String]) -> void:
		title = p_title
		lines = p_lines


static func pages() -> Array:
	var out: Array = []
	out.append(Page.new("THE LEDGER IS YOUR HEALTH", [
		"Thirteen lines. Each can be settled once, and once settled it is gone for the rest of the run — not the night, the run.",
		"You are not trying to score well on a card. You are spending a card to stay at the table.",
	]))
	out.append(Page.new("EVERY DRAW COSTS A LINE", [
		"A night sets a number you have to reach. You throw, you settle a line, and that line is spent whether it scored 300 or nothing.",
		"Clear a night in two draws and you carry eleven lines to the next one. Take six and you are bleeding.",
		"Writing a zero is a real move. Strike out a line you were saving to survive tonight, and live with the hole.",
	]))
	out.append(Page.new("STAKED IS STAKED FOR THE NIGHT", [
		"Click a die to stake it. It holds that face until the night ends — scoring for you every draw, and never rolling again.",
		"You are trading what you might roll for what you already have. The table narrows as the night goes on, and that is the same bargain the Ledger makes.",
	]))
	out.append(Page.new("THE POT, THE RAIL, THE DIRT", [
		"Choose how hard you throw. Soft keeps the dice in the pot. Hard scatters them to the rail, where they score double, and past it into the dirt, where they are gone for the night.",
		"A die on the rail is not safe: the next draw shoves it toward the lip. Stake it, settle now, or gamble it.",
	]))
	out.append(Page.new("THE MAN OPPOSITE", [
		"On some nights someone sits down and writes on the same Ledger. Every line he takes is a line you can never use.",
		"He calls his line out loud before he throws. That is your one turn to answer: take it yourself, race the number and end the night, or stake away the dice he needs.",
		"Out-score him and you get spent lines back. He is the only way this run gets longer.",
	]))
	return out
