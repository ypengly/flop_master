extends Node
## Unlocks, medals, achievements, personal bests and the daily stunt challenge.

signal achievement_unlocked(id: String, title: String)
signal item_unlocked(id: String)

const ITEMS := {
	"outfit_default": {"slot": "outfit", "name": "Classic Flopper", "cost": 0, "color": Color(0.95, 0.75, 0.2)},
	"outfit_red": {"slot": "outfit", "name": "Tomato Suit", "cost": 150, "color": Color(0.9, 0.2, 0.2)},
	"outfit_blue": {"slot": "outfit", "name": "Blueberry Onesie", "cost": 150, "color": Color(0.25, 0.4, 0.95)},
	"outfit_green": {"slot": "outfit", "name": "Pickle Pajamas", "cost": 300, "color": Color(0.3, 0.8, 0.35)},
	"outfit_purple": {"slot": "outfit", "name": "Grape Gown", "cost": 450, "color": Color(0.6, 0.3, 0.85)},
	"outfit_gold": {"slot": "outfit", "name": "Solid Gold Noodle", "cost": 1200, "color": Color(1.0, 0.85, 0.2)},
	"hat_none": {"slot": "hat", "name": "No Hat", "cost": 0},
	"hat_cone": {"slot": "hat", "name": "Traffic Cone", "cost": 100},
	"hat_tophat": {"slot": "hat", "name": "Fancy Top Hat", "cost": 250},
	"hat_party": {"slot": "hat", "name": "Party Hat", "cost": 200},
	"hat_propeller": {"slot": "hat", "name": "Propeller Beanie", "cost": 400},
	"hat_chicken": {"slot": "hat", "name": "Chicken Helmet", "cost": 600},
	"hat_crown": {"slot": "hat", "name": "Tiny Crown", "cost": 1000},
}

const ACHIEVEMENTS := {
	"first_finish": "First Finish: complete any level",
	"tumble_king": "Tumble King: 15 tumbles in one run",
	"high_flyer": "High Flyer: 40m of airtime in one run",
	"flip_master": "Flip Master: 6 flips in one run",
	"demolition": "Demolition Crew: knock over 12 objects in one run",
	"collector": "Collector: grab every collectible in a level",
	"catastrophe": "Certified Catastrophe: reach that rating",
	"gold_medal": "Golden Flopper: earn a gold medal",
	"all_levels": "Flop Graduate: complete all six levels",
	"daily_done": "Daily Disaster: finish a daily challenge",
	"big_fall": "Look Out Below: fall 25m or more",
}

const DAILY_GOALS := [
	{"type": "score", "text": "Reach a Flop Score of %d", "targets": [2500, 3500, 5000]},
	{"type": "flips", "text": "Perform %d flips", "targets": [3, 5, 8]},
	{"type": "knocked", "text": "Knock over %d objects", "targets": [6, 10, 15]},
	{"type": "air", "text": "Travel %d m while airborne", "targets": [20, 35, 50]},
	{"type": "finish", "text": "Finish the level in under %d seconds", "targets": [75, 60, 45]},
]


# ------------------------------------------------------------------ items

func is_item_unlocked(id: String) -> bool:
	return id in SaveData.data["unlocked_items"]


func buy_item(id: String) -> bool:
	if not ITEMS.has(id) or is_item_unlocked(id):
		return false
	var cost: int = ITEMS[id]["cost"]
	if int(SaveData.data["coins"]) < cost:
		return false
	SaveData.data["coins"] = int(SaveData.data["coins"]) - cost
	SaveData.data["unlocked_items"].append(id)
	SaveData.save_game()
	item_unlocked.emit(id)
	return true


func equip(id: String) -> bool:
	if not ITEMS.has(id) or not is_item_unlocked(id):
		return false
	SaveData.data["equipped"][ITEMS[id]["slot"]] = id
	SaveData.save_game()
	return true


func equipped(slot: String) -> String:
	return String(SaveData.data["equipped"].get(slot, "outfit_default" if slot == "outfit" else "hat_none"))


func items_for_slot(slot: String) -> Array:
	var out := []
	for id in ITEMS:
		if ITEMS[id]["slot"] == slot:
			out.append(id)
	return out


# ------------------------------------------------------------- completion

## Records a finished run. Returns a dictionary describing what changed.
func record_run(level_index: int, total_score: int, time: float, completed: bool, run: Dictionary) -> Dictionary:
	var key := str(level_index)
	var result := {"new_best": false, "new_best_time": false, "medal": "none", "coins": 0, "unlocked_next": false, "new_achievements": []}
	var d: Dictionary = SaveData.data
	d["stats"]["flops"] = int(d["stats"]["flops"]) + 1
	d["stats"]["total_score"] = int(d["stats"]["total_score"]) + total_score
	d["stats"]["collectibles"] = int(d["stats"]["collectibles"]) + int(run.get("collectibles", 0))

	if total_score > int(d["best_scores"].get(key, 0)):
		d["best_scores"][key] = total_score
		result["new_best"] = true

	var coins := int(total_score / 40.0) + int(run.get("collectibles", 0)) * 10
	if completed:
		coins += 50
		d["stats"]["levels_completed"] = int(d["stats"]["levels_completed"]) + 1
		if not d["best_times"].has(key) or time < float(d["best_times"][key]):
			d["best_times"][key] = time
			result["new_best_time"] = true
		var medal := LevelManager.medal_for(level_index, total_score)
		result["medal"] = medal
		if _medal_rank(medal) > _medal_rank(String(d["medals"].get(key, "none"))):
			d["medals"][key] = medal
		var nxt := level_index + 1
		if nxt < LevelManager.count() and not (nxt in d["unlocked_levels"]):
			d["unlocked_levels"].append(nxt)
			result["unlocked_next"] = true
	d["coins"] = int(d["coins"]) + coins
	result["coins"] = coins

	result["new_achievements"] = _check_achievements(level_index, run, completed, result["medal"], total_score)
	SaveData.save_game()
	return result


func _medal_rank(m: String) -> int:
	return ["none", "bronze", "silver", "gold"].find(m)


func _check_achievements(level_index: int, run: Dictionary, completed: bool, medal: String, total_score: int) -> Array:
	var got := []
	if completed:
		_grant("first_finish", got)
	if int(run.get("tumbles", 0)) >= 15:
		_grant("tumble_king", got)
	if float(run.get("air_distance", 0.0)) >= 40.0:
		_grant("high_flyer", got)
	if int(run.get("flips", 0)) >= 6:
		_grant("flip_master", got)
	if int(run.get("knocked", 0)) >= 12:
		_grant("demolition", got)
	if run.get("all_collectibles", false):
		_grant("collector", got)
	if ScoreManager.ratings_for(total_score) == "Certified Catastrophe" or total_score >= 11000:
		_grant("catastrophe", got)
	if medal == "gold":
		_grant("gold_medal", got)
	if float(run.get("biggest_fall", 0.0)) >= 25.0:
		_grant("big_fall", got)
	if completed and SaveData.data["stats"]["levels_completed"] >= 6 and _all_levels_done():
		_grant("all_levels", got)
	return got


func _all_levels_done() -> bool:
	for i in LevelManager.count():
		if not SaveData.data["medals"].has(str(i)):
			return false
	return true


func _grant(id: String, got: Array) -> void:
	if id in SaveData.data["achievements"]:
		return
	SaveData.data["achievements"].append(id)
	got.append(id)
	achievement_unlocked.emit(id, ACHIEVEMENTS[id])


# ------------------------------------------------------------------ daily

func today_string() -> String:
	var t := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [t["year"], t["month"], t["day"]]


## Deterministic from the date, so everybody gets the same daily stunt.
func get_daily(date_str := "") -> Dictionary:
	if date_str == "":
		date_str = today_string()
	var h := hash(date_str)
	var unlocked_count: int = SaveData.data["unlocked_levels"].size()
	var level_idx := absi(h) % maxi(1, unlocked_count)
	var goal: Dictionary = DAILY_GOALS[absi(h / 7) % DAILY_GOALS.size()]
	var target: int = goal["targets"][absi(h / 31) % goal["targets"].size()]
	return {
		"date": date_str, "level": level_idx, "type": goal["type"], "target": target,
		"text": goal["text"] % target, "level_name": LevelManager.level(level_idx)["name"],
	}


func daily_completed() -> bool:
	var dd: Dictionary = SaveData.data["daily"]
	return dd["date"] == today_string() and bool(dd["completed"])


## Returns true if this run satisfied the daily goal (and awards the reward once).
func check_daily(level_index: int, run: Dictionary, total_score: int, time: float, completed: bool) -> bool:
	var daily := get_daily()
	if level_index != daily["level"] or daily_completed():
		return false
	var ok := false
	match daily["type"]:
		"score": ok = total_score >= daily["target"]
		"flips": ok = int(run.get("flips", 0)) >= daily["target"]
		"knocked": ok = int(run.get("knocked", 0)) >= daily["target"]
		"air": ok = float(run.get("air_distance", 0.0)) >= daily["target"]
		"finish": ok = completed and time <= float(daily["target"])
	if ok:
		SaveData.data["daily"] = {"date": daily["date"], "completed": true, "best": total_score}
		SaveData.data["coins"] = int(SaveData.data["coins"]) + 250
		var got := []
		_grant("daily_done", got)
		SaveData.save_game()
	return ok
