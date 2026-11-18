extends Node
## Loads tunable physics/camera/scoring parameters from res://config/physics.json.
## Nothing gameplay-critical is hardcoded in other scripts; they call Config.get_value().

const CONFIG_PATH := "res://config/physics.json"

var data: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	data = {}
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("Config file missing: %s (using defaults)" % CONFIG_PATH)
		return
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		data = parsed
	else:
		push_error("Config JSON failed to parse: %s" % CONFIG_PATH)


## Fetch a value: Config.get_value("character", "walk_speed", 3.0)
func get_value(section: String, key: String, default = 0.0):
	var sec = data.get(section, {})
	if sec is Dictionary and sec.has(key):
		return sec[key]
	return default


func section(name: String) -> Dictionary:
	var s = data.get(name, {})
	return s if s is Dictionary else {}


func material_def(name: String) -> Dictionary:
	var mats: Dictionary = section("materials")
	return mats.get(name, mats.get("stone", {"friction": 0.8, "bounce": 0.1, "color": [0.5, 0.5, 0.5]}))
