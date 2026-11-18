extends Node
## The Flop Score. Rewards spectacular failures (air distance, tumbles, flips, impacts,
## knocked objects, big falls, stunt variety) while a completion + time bonus keeps
## actually finishing a level worthwhile.

signal score_changed(total: int)
signal stunt_announced(text: String, points: int)
signal rating_changed(rating: String)

var running := false
var elapsed := 0.0

# Raw components (points, already weighted)
var air_distance := 0.0      # metres travelled horizontally while airborne
var tumbles := 0
var flips := 0
var impact_points := 0.0
var knocked := 0
var fall_points := 0.0
var final_fall := 0.0        # metres of the most recent significant fall
var biggest_fall := 0.0
var collectibles := 0
var stunts: Dictionary = {}  # stunt name -> times performed (variety)
var completed := false

var _rot_air := 0.0
var _rot_ground := 0.0
var _was_airborne := false
var _last_air_pos := Vector3.ZERO
var _air_start_y := 0.0
var _last_impact_time := -10.0
var _last_rating := ""


func start_run() -> void:
	running = true
	completed = false
	elapsed = 0.0
	air_distance = 0.0
	tumbles = 0
	flips = 0
	impact_points = 0.0
	knocked = 0
	fall_points = 0.0
	final_fall = 0.0
	biggest_fall = 0.0
	collectibles = 0
	stunts = {}
	_rot_air = 0.0
	_rot_ground = 0.0
	_was_airborne = false
	_last_rating = ratings_for(0)
	score_changed.emit(0)


func stop_run() -> void:
	running = false


func tick(delta: float) -> void:
	if running:
		elapsed += delta


## Called every physics frame with the torso state.
func update_motion(pos: Vector3, ang_vel: Vector3, airborne: bool, delta: float) -> void:
	if not running:
		return
	var rot := ang_vel.length() * delta
	if airborne:
		if not _was_airborne:
			_last_air_pos = pos
			_air_start_y = pos.y
			_rot_air = 0.0
		var step := Vector2(pos.x - _last_air_pos.x, pos.z - _last_air_pos.z).length()
		air_distance += step
		_last_air_pos = pos
		_rot_air += rot
		if _rot_air >= TAU * 0.9:
			_rot_air = 0.0
			flips += 1
			_announce("FLIP!", int(Config.get_value("scoring", "flip_points", 90)))
			register_stunt("flip")
	else:
		if _was_airborne:
			var drop := _air_start_y - pos.y
			_on_landed(drop)
		_rot_ground += rot
		if _rot_ground >= TAU:
			_rot_ground = 0.0
			tumbles += 1
			_announce("TUMBLE!", int(Config.get_value("scoring", "tumble_points", 60)))
	_was_airborne = airborne
	_emit_score()


func _on_landed(drop: float) -> void:
	var min_h := float(Config.get_value("scoring", "fall_min_height", 3.0))
	if drop >= min_h:
		final_fall = drop
		biggest_fall = maxf(biggest_fall, drop)
		var pts := drop * float(Config.get_value("scoring", "fall_mult", 12.0))
		fall_points += pts
		_announce("BIG FALL %.0fm" % drop, int(pts))
	_rot_air = 0.0


## Called when the player falls out of the world: award the fall, then reset airborne tracking.
func register_death_fall(current_y: float) -> void:
	if not running:
		return
	if _was_airborne:
		_on_landed(_air_start_y - current_y)
	_was_airborne = false
	_rot_air = 0.0
	_emit_score()


func register_impact(speed: float, material := "stone") -> void:
	if not running:
		return
	var min_s := float(Config.get_value("scoring", "impact_min_speed", 5.0))
	var now := elapsed
	if speed < min_s or now - _last_impact_time < float(Config.get_value("scoring", "impact_cooldown", 0.25)):
		return
	_last_impact_time = now
	var pts := minf((speed - min_s) * float(Config.get_value("scoring", "impact_mult", 1.5)) * 6.0, 400.0)
	impact_points += pts
	if material == "rubber":
		register_stunt("rubber bounce")
	elif material == "ice":
		register_stunt("ice crash")
	if pts >= 60.0:
		_announce("CRASH!", int(pts))
	_emit_score()


func register_knock(count := 1) -> void:
	if not running:
		return
	knocked += count
	_announce("KNOCKED OVER!", int(Config.get_value("scoring", "knock_points", 35)) * count)
	_emit_score()


func register_collectible() -> void:
	if not running:
		return
	collectibles += 1
	_announce("COLLECTED!", int(Config.get_value("scoring", "collectible_points", 150)))
	_emit_score()


## Each distinct stunt gives variety bonus the first time; repeats don't stack.
func register_stunt(stunt_name: String) -> void:
	if not running:
		return
	if not stunts.has(stunt_name):
		stunts[stunt_name] = 0
		_announce("NEW STUNT: %s" % stunt_name.to_upper(), int(Config.get_value("scoring", "variety_points", 80)))
	stunts[stunt_name] += 1
	_emit_score()


func _announce(text: String, points: int) -> void:
	stunt_announced.emit(text, points)


func breakdown() -> Dictionary:
	var s: Dictionary = Config.section("scoring")
	return {
		"Air distance": int(air_distance * float(s.get("air_distance_mult", 4.0))),
		"Tumbles": tumbles * int(s.get("tumble_points", 60)),
		"Flips": flips * int(s.get("flip_points", 90)),
		"Impacts": int(impact_points),
		"Knocked over": knocked * int(s.get("knock_points", 35)),
		"Big falls": int(fall_points),
		"Stunt variety": stunts.size() * int(s.get("variety_points", 80)),
		"Collectibles": collectibles * int(s.get("collectible_points", 150)),
	}


func flop_total() -> int:
	var t := 0
	for v in breakdown().values():
		t += int(v)
	return t


## Completion keeps winning relevant: a flat bonus plus a time bonus vs the level's par time.
func completion_bonus(par_time: float) -> int:
	if not completed:
		return 0
	var s: Dictionary = Config.section("scoring")
	var bonus := int(s.get("completion_bonus", 1000))
	bonus += int(maxf(0.0, par_time - elapsed) * float(s.get("time_bonus_per_sec", 12.0)))
	return bonus


func total_with_bonus(par_time: float) -> int:
	return flop_total() + completion_bonus(par_time)


func ratings_for(score: int) -> String:
	var best := "Mildly Wobbly"
	var list = Config.get_value("scoring", "ratings", [])
	for r in list:
		if score >= int(r["min"]):
			best = String(r["name"])
	return best


func _emit_score() -> void:
	var t := flop_total()
	score_changed.emit(t)
	var r := ratings_for(t)
	if r != _last_rating:
		_last_rating = r
		rating_changed.emit(r)
