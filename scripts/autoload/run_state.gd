extends Node
## Owns the live run and the small amount of meta that survives it.

signal run_created(game: Game)

const SAVE_PATH := "user://thirteen_boxes.cfg"

var game: Game = null
var meta := {
	"runs": 0,
	"best_total": 0,
	"deepest_floor": 0,
	"wins": 0,
}


func _ready() -> void:
	load_meta()


## `stage` is handed over before the run starts: attaching it afterwards left
## the first throw of every run resolving on the model while the physical
## dice sat untouched at the edge of the table.
func new_run(seed_value: int = 0, stage = null) -> Game:
	game = Game.new()
	game.stage = stage
	game.run_ended.connect(_on_run_ended)
	game.floor_cleared.connect(_on_floor_cleared)
	game.player_wrote.connect(_on_player_wrote)
	game.start_run(seed_value)
	meta["runs"] = int(meta["runs"]) + 1
	run_created.emit(game)
	Steam.set_rich_presence("Floor 1")
	return game


func _on_player_wrote(box: int, value: int, denied: bool) -> void:
	if denied:
		Steam.unlock(&"DENIED")
	if box == Scoring.Box.YAHTZEE and value == 0:
		Steam.unlock(&"SCRATCH_THE_YAHTZEE")


func _on_floor_cleared(floor_number: int, reclaimed: Array) -> void:
	meta["deepest_floor"] = maxi(int(meta["deepest_floor"]), floor_number)
	Steam.set_rich_presence("Floor %d" % (floor_number + 1))
	if floor_number == 1:
		Steam.unlock(&"FIRST_DESCENT")
	if floor_number == 6:
		Steam.unlock(&"DEEP_SIX")
	if game != null and game.floor_turn <= 2:
		Steam.unlock(&"TWO_TURN_FLOOR")
	if not reclaimed.is_empty():
		Steam.unlock(&"OUTSCORED")
	save_meta()


func _on_run_ended(won: bool, _reason: String) -> void:
	if game != null:
		meta["best_total"] = maxi(int(meta["best_total"]), game.card.run_total)
		if game.card.is_exhausted():
			Steam.unlock(&"THIRTEEN_BOXES")
	if won:
		meta["wins"] = int(meta["wins"]) + 1
		Steam.unlock(&"WALK_OUT")
	Steam.set_stat("deepest_floor", int(meta["deepest_floor"]))
	save_meta()


func save_meta() -> void:
	var cfg := ConfigFile.new()
	for key in meta:
		cfg.set_value("meta", key, meta[key])
	cfg.save(SAVE_PATH)


func load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for key in meta.keys():
		meta[key] = cfg.get_value("meta", key, meta[key])
