extends Node
## Persistent save data (user://save.json). All other systems read/write through here.

signal saved

const SAVE_PATH := "user://save.json"
const VERSION := 1

var path_override := ""   # tests can redirect saving
var data: Dictionary = {}


func _ready() -> void:
	load_game()


func _default_data() -> Dictionary:
	return {
		"version": VERSION,
		"unlocked_levels": [0],
		"best_scores": {},        # level_id(str) -> int
		"best_times": {},         # level_id(str) -> float
		"medals": {},             # level_id(str) -> "none|bronze|silver|gold"
		"achievements": [],
		"unlocked_items": ["outfit_default", "hat_none"],
		"equipped": {"outfit": "outfit_default", "hat": "hat_none"},
		"coins": 0,
		"stats": {"flops": 0, "levels_completed": 0, "collectibles": 0, "total_score": 0, "falls": 0, "restarts": 0},
		"daily": {"date": "", "completed": false, "best": 0},
		"settings": {"master": 0.8, "sfx": 1.0, "music": 0.5, "shake": 1.0, "fov": 68.0, "invert_y": false, "bindings": {}},
	}


func _path() -> String:
	return path_override if path_override != "" else SAVE_PATH


func load_game() -> void:
	data = _default_data()
	if not FileAccess.file_exists(_path()):
		return
	var f := FileAccess.open(_path(), FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_merge(data, parsed)
	_normalize()


## JSON has no integer type, so whole numbers come back as floats. Restore ints where we need them.
func _normalize() -> void:
	data["unlocked_levels"] = (data["unlocked_levels"] as Array).map(func(v): return int(v))
	data["version"] = int(data["version"])
	data["coins"] = int(data["coins"])
	data["daily"]["best"] = int(data["daily"].get("best", 0))
	for k in data["stats"]:
		data["stats"][k] = int(data["stats"][k])
	for k in data["best_scores"]:
		data["best_scores"][k] = int(data["best_scores"][k])
	var b: Dictionary = data["settings"].get("bindings", {})
	for k in b:
		b[k] = int(b[k])


## Recursively merge loaded values into defaults so new keys survive old saves.
func _merge(base: Dictionary, incoming: Dictionary) -> void:
	for k in incoming:
		if base.has(k) and base[k] is Dictionary and incoming[k] is Dictionary:
			_merge(base[k], incoming[k])
		else:
			base[k] = incoming[k]


func save_game() -> void:
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return
	f.store_string(JSON.stringify(data, "\t"))
	saved.emit()


func reset_all() -> void:
	data = _default_data()
	save_game()


func get_setting(key: String, default = null):
	return data["settings"].get(key, default)


func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	save_game()
