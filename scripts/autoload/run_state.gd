extends Node
## What survives between scenes, and the one detail the game knows about you.

signal run_started(game)

var game: Game = null
## Things that know you use this. It is asked for once, at the start, and the
## game never explains why it wanted it.
var officer_name: String = "Vasch"
var seen_intro: bool = false


func new_run(seed_value: int = 0) -> Game:
	game = Game.new()
	game.start_run(seed_value if seed_value != 0 else randi())
	run_started.emit(game)
	return game
