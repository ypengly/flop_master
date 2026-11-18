class_name Gameplay
extends Node3D
## Orchestrates one run: builds the level, spawns the ragdoll, wires the controller, camera,
## HUD, pause menu and results screen together, and handles checkpoints, respawns and finishing.

var info: Dictionary
var level: LevelBase
var ragdoll: Ragdoll
var controller: CharacterController
var cam: FollowCamera
var hud: Hud
var pause_menu: PauseMenu
var results: ResultsScreen

var checkpoint_pos := Vector3.ZERO
var checkpoint_index := -1
var run_over := false
var is_paused := false
var respawn_count := 0
var _respawn_cd := 0.0
var _recover_hold := 0.0
var _hint_timer := 14.0
var headless_test := false


func _ready() -> void:
	headless_test = Engine.has_meta("flop_test")
	info = LevelManager.current()
	if not headless_test:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	level = (load(info["script"]) as GDScript).new() as LevelBase
	add_child(level)
	level.setup()
	checkpoint_pos = level.spawn_point

	ragdoll = Ragdoll.new()
	add_child(ragdoll)
	ragdoll.build(level.spawn_point, Progression.equipped("outfit"), Progression.equipped("hat"))

	controller = CharacterController.new()
	add_child(controller)
	controller.setup(ragdoll, level.spawn_point)
	controller.kill_y = level.kill_y
	controller.fell_out.connect(_on_fell_out)
	controller.rescued.connect(_on_rescued)
	controller.hard_impact.connect(_on_hard_impact)

	cam = FollowCamera.new()
	add_child(cam)
	var rids: Array[RID] = []
	for p in ragdoll.all_parts():
		rids.append((p as RigidBody3D).get_rid())
	cam.setup(ragdoll.torso, rids, level.spawn_yaw)

	hud = Hud.new()
	add_child(hud)
	hud.build(info, level.collectible_total, level.hint_text)

	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.build()
	pause_menu.visible = false
	pause_menu.resume_requested.connect(_set_paused.bind(false))
	pause_menu.restart_requested.connect(restart_level)
	pause_menu.quit_requested.connect(LevelManager.goto_menu)
	pause_menu.end_run_requested.connect(_end_run_early)

	level.checkpoint_reached.connect(_on_checkpoint)
	level.collectible_taken.connect(_on_collectible)
	level.finish_reached.connect(_on_finish)
	level.hazard_hit.connect(_on_hazard)

	ScoreManager.score_changed.connect(_on_score_changed)
	ScoreManager.stunt_announced.connect(_on_stunt)
	ScoreManager.rating_changed.connect(_on_rating)
	ScoreManager.start_run()
	hud.set_collectibles(0, level.collectible_total)
	hud.show_banner(String(info["name"]).to_upper(), UiKit.COL_ACCENT, 2.2)
	hud.show_objective(String(info["objective"]))
	AudioManager.play_music()


func _exit_tree() -> void:
	if ScoreManager.score_changed.is_connected(_on_score_changed):
		ScoreManager.score_changed.disconnect(_on_score_changed)
	if ScoreManager.stunt_announced.is_connected(_on_stunt):
		ScoreManager.stunt_announced.disconnect(_on_stunt)
	if ScoreManager.rating_changed.is_connected(_on_rating):
		ScoreManager.rating_changed.disconnect(_on_rating)
	ScoreManager.stop_run()


# ------------------------------------------------------------------ frame loop

func _physics_process(delta: float) -> void:
	if run_over:
		return
	_respawn_cd = maxf(0.0, _respawn_cd - delta)
	ScoreManager.tick(delta)
	cam.target_velocity = ragdoll.pelvis.linear_velocity
	controller.camera_yaw = cam.yaw
	controller.physics_update(delta)

	# Hold "get up" to give up and go back to the last checkpoint.
	if Input.is_action_pressed("recover") and controller.state == CharacterController.State.RAGDOLL:
		_recover_hold += delta
		if _recover_hold > 1.2:
			_recover_hold = 0.0
			respawn()
	else:
		_recover_hold = 0.0

	hud.set_time(ScoreManager.elapsed)
	hud.set_stamina(controller.stamina_ratio())
	_hint_timer -= delta
	if _hint_timer <= 0.0:
		hud.hide_hint()


func _unhandled_input(event: InputEvent) -> void:
	if run_over:
		return
	if event.is_action_pressed("pause"):
		_set_paused(not is_paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart") and not is_paused:
		restart_level()


func _set_paused(on: bool) -> void:
	is_paused = on
	get_tree().paused = on
	pause_menu.visible = on
	if not headless_test:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------------ level events

func _on_checkpoint(index: int, spawn: Vector3) -> void:
	checkpoint_index = index
	checkpoint_pos = spawn + Vector3(0, 0.05, 0)
	hud.set_checkpoint(index)
	hud.show_banner("CHECKPOINT!", UiKit.COL_GOOD, 1.0)
	AudioManager.play("checkpoint", 0.9)


func _on_collectible(count: int) -> void:
	hud.set_collectibles(count, level.collectible_total)


func _on_hazard() -> void:
	respawn()


func _on_fell_out() -> void:
	respawn()


func _on_rescued() -> void:
	hud.show_banner("UNSTUCK!", UiKit.COL_MUTED, 1.0)


func _on_hard_impact(speed: float, _material: String) -> void:
	cam.add_shake(clampf(speed / 25.0, 0.0, 1.0))


func _on_score_changed(total: int) -> void:
	hud.set_score(total)


func _on_stunt(text: String, points: int) -> void:
	hud.popup(text, points)


func _on_rating(rating: String) -> void:
	hud.set_rating(rating)


## Return to the last checkpoint (keeps score; the fall itself is scored first).
func respawn() -> void:
	if run_over or _respawn_cd > 0.0:
		return
	_respawn_cd = 0.8
	respawn_count += 1
	ScoreManager.register_death_fall(ragdoll.pelvis.global_position.y)
	SaveData.data["stats"]["falls"] = int(SaveData.data["stats"]["falls"]) + 1
	controller.respawn_at(checkpoint_pos, level.spawn_yaw)
	cam.snap()
	AudioManager.play("fail", 0.5)
	hud.show_banner("OOPS!", UiKit.COL_BAD, 0.8)


func restart_level() -> void:
	SaveData.data["stats"]["restarts"] = int(SaveData.data["stats"]["restarts"]) + 1
	SaveData.save_game()
	LevelManager.start_level(LevelManager.current_index, LevelManager.daily_mode)


# ------------------------------------------------------------------ finishing

func _on_finish() -> void:
	if run_over:
		return
	ScoreManager.completed = true
	_finish_run(true)


func _end_run_early() -> void:
	_set_paused(false)
	_finish_run(false)


func _finish_run(completed: bool) -> void:
	if run_over:
		return
	run_over = true
	controller.input_enabled = false
	ScoreManager.stop_run()
	var par := float(info["par"])
	var total := ScoreManager.total_with_bonus(par)
	var run := {
		"tumbles": ScoreManager.tumbles, "flips": ScoreManager.flips,
		"knocked": ScoreManager.knocked, "air_distance": ScoreManager.air_distance,
		"collectibles": level.collectible_count, "biggest_fall": ScoreManager.biggest_fall,
		"all_collectibles": level.collectible_total > 0 and level.collectible_count >= level.collectible_total,
	}
	var result := Progression.record_run(LevelManager.current_index, total, ScoreManager.elapsed, completed, run)
	var daily_done := false
	if LevelManager.daily_mode:
		daily_done = Progression.check_daily(LevelManager.current_index, run, total, ScoreManager.elapsed, completed)
		SaveData.save_game()
	var data := {
		"completed": completed, "level_name": info["name"], "rating": ScoreManager.ratings_for(total),
		"breakdown": ScoreManager.breakdown(), "bonus": ScoreManager.completion_bonus(par), "total": total,
		"time": ScoreManager.elapsed, "collectibles": level.collectible_count, "collectible_total": level.collectible_total,
		"biggest_fall": ScoreManager.biggest_fall, "result": result, "daily_done": daily_done,
	}
	last_result = data
	if not headless_test:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	results = ResultsScreen.new()
	add_child(results)
	results.show_results(data)
	results.retry_requested.connect(restart_level)
	results.next_requested.connect(func() -> void: LevelManager.start_level(LevelManager.next_level_index()))
	results.menu_requested.connect(LevelManager.goto_menu)


var last_result: Dictionary = {}
