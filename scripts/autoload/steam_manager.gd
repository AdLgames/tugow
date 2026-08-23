extends Node
## Optional Steam layer. The game runs identically with or without GodotSteam
## installed — every call here degrades to a no-op and a log line.
##
## To enable: install the GodotSteam engine build (or the GDExtension), set
## APP_ID below to the real app id, and put that same id in steam_appid.txt
## next to the binary for local testing.

const APP_ID := 480  # 480 = Spacewar, Valve's public test app.

const ACHIEVEMENTS := {
	&"FIRST_DESCENT": "Clear the first floor.",
	&"TWO_TURN_FLOOR": "Clear a floor in two turns.",
	&"SCRATCH_THE_YAHTZEE": "Scratch the Yahtzee box on purpose.",
	&"DENIED": "Take a box the Adversary announced.",
	&"OUTSCORED": "Out-score an Adversary and reclaim boxes.",
	&"DEEP_SIX": "Reach floor six.",
	&"THIRTEEN_BOXES": "Fill all thirteen boxes in a single run.",
	&"WALK_OUT": "Clear floor twelve.",
}

var available: bool = false
var steam_id: int = 0
var user_name: String = "Player"

var _steam: Object = null


func _ready() -> void:
	_connect_to_steam()


func _connect_to_steam() -> void:
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
	elif ClassDB.class_exists("Steam"):
		_steam = ClassDB.instantiate("Steam")
	if _steam == null:
		print("[Steam] Not present — running standalone.")
		return
	var init_result: Variant = null
	if _steam.has_method("steamInitEx"):
		init_result = _steam.call("steamInitEx", APP_ID, true)
	elif _steam.has_method("steamInit"):
		init_result = _steam.call("steamInit")
	available = _init_succeeded(init_result)
	if not available:
		print("[Steam] Init failed: %s" % str(init_result))
		return
	if _steam.has_method("getSteamID"):
		steam_id = int(_steam.call("getSteamID"))
	if _steam.has_method("getPersonaName"):
		user_name = str(_steam.call("getPersonaName"))
	print("[Steam] Connected as %s (%d)." % [user_name, steam_id])


func _init_succeeded(result: Variant) -> bool:
	if result is Dictionary:
		return int(result.get("status", 1)) == 0
	if result is bool:
		return result
	if result is int:
		return int(result) == 1 or int(result) == 0
	return false


func _process(_delta: float) -> void:
	if available and _steam != null and _steam.has_method("run_callbacks"):
		_steam.call("run_callbacks")


func unlock(achievement: StringName) -> void:
	if not ACHIEVEMENTS.has(achievement):
		push_warning("Unknown achievement: %s" % achievement)
		return
	if not available:
		print("[Steam] (offline) achievement: %s" % achievement)
		return
	_steam.call("setAchievement", String(achievement))
	_steam.call("storeStats")


func set_stat(stat_name: String, value: int) -> void:
	if not available:
		return
	_steam.call("setStatInt", stat_name, value)
	_steam.call("storeStats")


func set_rich_presence(text: String) -> void:
	if not available:
		return
	_steam.call("setRichPresence", "steam_display", text)
