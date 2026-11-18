extends Node
## Level registry and scene flow. Levels are built procedurally by scripts in
## res://scripts/levels/, so every level is data (this table) plus a builder.

signal level_changed(index: int)

const MAIN_MENU := "res://scenes/main.tscn"
const GAMEPLAY := "res://scenes/gameplay.tscn"

# par = seconds for time bonus; medals = total score thresholds (bronze, silver, gold)
const LEVELS := [
	{"id": 0, "name": "Training Room", "script": "res://scripts/levels/level_01_training.gd",
		"objective": "Learn the moves, then reach the green finish pad.", "par": 90.0, "medals": [1200, 2500, 4500], "color": Color(0.55, 0.85, 0.6)},
	{"id": 1, "name": "Slippery Rooftops", "script": "res://scripts/levels/level_02_rooftops.gd",
		"objective": "Cross the icy rooftops without taking the express elevator down.", "par": 110.0, "medals": [1500, 3000, 5500], "color": Color(0.6, 0.8, 1.0)},
	{"id": 2, "name": "Construction Chaos", "script": "res://scripts/levels/level_03_construction.gd",
		"objective": "Dodge swinging beams and falling crates to reach the crane.", "par": 120.0, "medals": [1800, 3600, 6500], "color": Color(1.0, 0.75, 0.3)},
	{"id": 3, "name": "Giant Fan Factory", "script": "res://scripts/levels/level_04_fans.gd",
		"objective": "Ride the updrafts across the factory floor.", "par": 120.0, "medals": [2000, 4000, 7000], "color": Color(0.75, 0.75, 0.85)},
	{"id": 4, "name": "Moving Platform Madness", "script": "res://scripts/levels/level_05_platforms.gd",
		"objective": "Balance on tilting, sliding and spinning platforms.", "par": 130.0, "medals": [2200, 4400, 7500], "color": Color(0.9, 0.55, 0.9)},
	{"id": 5, "name": "Ultimate Flop Arena", "script": "res://scripts/levels/level_06_arena.gd",
		"objective": "Survive every hazard in one glorious gauntlet.", "par": 160.0, "medals": [3000, 6000, 10000], "color": Color(1.0, 0.4, 0.4)},
]

var current_index := 0
var daily_mode := false


func count() -> int:
	return LEVELS.size()


func level(index: int) -> Dictionary:
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)]


func current() -> Dictionary:
	return level(current_index)


func is_unlocked(index: int) -> bool:
	return index in SaveData.data["unlocked_levels"]


func start_level(index: int, daily := false) -> void:
	current_index = clampi(index, 0, LEVELS.size() - 1)
	daily_mode = daily
	level_changed.emit(current_index)
	get_tree().paused = false
	get_tree().change_scene_to_file(GAMEPLAY)


func goto_menu() -> void:
	get_tree().paused = false
	AudioManager.stop_music()
	get_tree().change_scene_to_file(MAIN_MENU)


func next_level_index() -> int:
	return mini(current_index + 1, LEVELS.size() - 1)


func has_next() -> bool:
	return current_index < LEVELS.size() - 1


func medal_for(index: int, score: int) -> String:
	var m: Array = level(index)["medals"]
	if score >= int(m[2]):
		return "gold"
	if score >= int(m[1]):
		return "silver"
	if score >= int(m[0]):
		return "bronze"
	return "none"
