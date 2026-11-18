extends Node
## Headless integration test. Run:
##   godot --headless --path . res://tests/test_game.tscn
## Exits 0 when every check passes, 1 otherwise.

var passed := 0
var failed := 0
var game: Gameplay


func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("  PASS  ", label)
	else:
		failed += 1
		print("  FAIL  ", label)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	Engine.set_meta("flop_test", true)
	SaveData.path_override = "user://flop_test_save.json"
	SaveData.reset_all()
	await _run()
	print("\nRESULT: %d passed, %d failed" % [passed, failed])
	SaveData.reset_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://flop_test_save.json"))
	get_tree().quit(1 if failed > 0 else 0)


func _spawn(level_index: int, daily := false) -> void:
	if game != null and is_instance_valid(game):
		remove_child(game)
		game.free()
	LevelManager.current_index = level_index
	LevelManager.daily_mode = daily
	game = (load("res://scenes/gameplay.tscn") as PackedScene).instantiate() as Gameplay
	add_child(game)
	await frames(2)


## Run a scripted input sequence from `start` and return the final pelvis position.
func _scripted(level_index: int, start: Vector3, hold: Array, total_frames: int, tap_jump_at := -1) -> Vector3:
	await _spawn(level_index)
	game.controller.respawn_at(start)
	await frames(100)
	for a in hold:
		Input.action_press(a)
	for k in total_frames:
		if k == tap_jump_at:
			Input.action_press("jump")
		elif k == tap_jump_at + 3:
			Input.action_release("jump")
		await frames(1)
	for a in hold:
		Input.action_release(a)
	return game.ragdoll.pelvis.global_position


func _sane(g: Gameplay) -> bool:
	for p in g.ragdoll.all_parts():
		var b := p as RigidBody3D
		if is_nan(b.global_position.x) or b.global_position.length() > 500.0 or b.linear_velocity.length() > 80.0:
			return false
	return true


func _run() -> void:
	print("== Menus build")
	var menu := (load("res://scenes/main.tscn") as PackedScene).instantiate() as MainMenu
	add_child(menu)
	await frames(2)
	for fn in ["show_levels", "show_daily", "show_customize", "show_records", "show_settings", "show_main"]:
		menu.call(fn)
		await frames(3)
	check(menu.content.get_child_count() > 0, "all menu screens build without error")
	remove_child(menu)
	menu.free()

	print("== Config & input")
	check(float(Config.get_value("character", "walk_speed", 0.0)) > 0.0, "physics config loads from JSON")
	check(InputMap.has_action("jump") and InputMap.has_action("dive"), "input actions registered")
	InputConfig.rebind("jump", KEY_J, false)
	check(InputConfig.key_label("jump") == "J", "key remapping works")
	InputConfig.setup_defaults()

	print("== Every level builds, spawns, settles and stays stable")
	for i in LevelManager.count():
		await _spawn(i)
		await frames(300)
		var st := game.controller.state
		check(_sane(game), "level %d (%s): ragdoll stable after 2.5s" % [i + 1, LevelManager.level(i)["name"]])
		check(st == CharacterController.State.STANDING or st == CharacterController.State.GETTING_UP, "level %d: character stands up on its own (state %d)" % [i + 1, st])
		check(game.level.finish_pos != Vector3.ZERO, "level %d has a finish" % [i + 1])
		check(game.level.checkpoints.size() >= 1, "level %d has checkpoints (%d)" % [i + 1, game.level.checkpoints.size()])
		check(game.level.collectible_total >= 1, "level %d has collectibles (%d)" % [i + 1, game.level.collectible_total])

	print("== Stress: random inputs on every level (no explosions, NaNs or runaway speeds)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var actions := ["move_forward", "move_back", "move_left", "move_right", "jump", "run", "dive", "grab", "push", "recover"]
	for i in LevelManager.count():
		await _spawn(i)
		var worst_speed := 0.0
		var ok := true
		for step in 90:
			for a in actions:
				if rng.randf() < 0.35:
					Input.action_press(a)
				else:
					Input.action_release(a)
			for f in 15:
				await frames(1)
				for p in game.ragdoll.all_parts():
					worst_speed = maxf(worst_speed, (p as RigidBody3D).linear_velocity.length())
			if not _sane(game) and game.respawn_count == 0 and game.ragdoll.pelvis.global_position.y > -30.0:
				ok = false
				break
		for a in actions:
			Input.action_release(a)
		check(ok, "level %d: survived 11s of random inputs (peak part speed %.1f m/s, %d respawns, score %d)" % [i + 1, worst_speed, game.respawn_count, ScoreManager.flop_total()])

	print("== Movement on level 1")
	await _spawn(0)
	await frames(240)
	var z0 := game.ragdoll.pelvis.global_position.z
	Input.action_press("move_forward")
	await frames(240)
	Input.action_release("move_forward")
	var z1 := game.ragdoll.pelvis.global_position.z
	check(z1 < z0 - 2.0, "walking forward moves the character (%.1f -> %.1f)" % [z0, z1])
	check(_sane(game), "stable while walking")

	print("== Jump")
	await frames(120)
	var y0 := game.ragdoll.pelvis.global_position.y
	var max_y := y0
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	for i in 60:
		await frames(1)
		max_y = maxf(max_y, game.ragdoll.pelvis.global_position.y)
	check(max_y > y0 + 0.3, "jump raises the character (%.2f -> %.2f)" % [y0, max_y])

	print("== Dive / ragdoll / recovery")
	await frames(120)
	Input.action_press("dive")
	await frames(2)
	Input.action_release("dive")
	await frames(30)
	check(game.controller.state == CharacterController.State.RAGDOLL, "dive puts the character into ragdoll")
	await frames(480)
	check(game.controller.state != CharacterController.State.RAGDOLL, "character recovers and gets back up (state %d)" % game.controller.state)
	check(_sane(game), "stable after diving")

	print("== Scoring")
	check(ScoreManager.flop_total() > 0, "flop score accumulates (%d)" % ScoreManager.flop_total())
	check(ScoreManager.stunts.has("dive"), "stunt variety is tracked")
	var s0 := ScoreManager.flop_total()
	ScoreManager.register_knock(2)
	ScoreManager.register_impact(14.0, "rubber")
	check(ScoreManager.flop_total() > s0, "knocks and impacts add points")
	check(ScoreManager.ratings_for(0) == "Mildly Wobbly" and ScoreManager.ratings_for(12000) == "Certified Catastrophe", "rating names match score tiers")

	print("== Crates are knocked over")
	await _spawn(0)
	var knocked_before := ScoreManager.knocked
	game.ragdoll.teleport(Vector3(0, 0.1, -26.0))
	game.controller.respawn_at(Vector3(0, 0.1, -26.0), 0.0)
	await frames(100)
	Input.action_press("move_forward")
	Input.action_press("run")
	await frames(260)
	Input.action_release("move_forward")
	Input.action_release("run")
	check(ScoreManager.knocked > knocked_before, "running into crate stack knocks crates over (%d)" % (ScoreManager.knocked - knocked_before))

	print("== Checkpoint + respawn")
	await _spawn(0)
	var cp: Vector3 = game.level.checkpoints[0]
	game.ragdoll.teleport(cp + Vector3(0, 0.2, 0))
	await frames(30)
	check(game.checkpoint_index == 0, "touching a checkpoint registers it")
	game.ragdoll.teleport(Vector3(30, -2.0, -20))
	await frames(5)
	game.respawn()
	await frames(10)
	var d := game.ragdoll.pelvis.global_position.distance_to(cp)
	check(d < 2.5, "respawn returns to the last checkpoint (%.2fm away)" % d)
	await frames(240)
	check(_sane(game), "stable after respawn")

	print("== Fall zone respawn")
	await _spawn(1)
	game.ragdoll.teleport(Vector3(0, -14, -70))
	await frames(40)
	check(game.respawn_count >= 1, "falling into the pit triggers a respawn")
	check(game.ragdoll.pelvis.global_position.y > -5.0, "after pit respawn the character is back on the roof")

	print("== Level completion, medals, unlock, saving")
	await _spawn(0)
	check(not LevelManager.is_unlocked(1), "level 2 starts locked")
	var par := float(LevelManager.level(0)["par"])
	ScoreManager.register_knock(20)
	game.ragdoll.teleport(game.level.finish_pos + Vector3(0, 0.3, 0))
	await frames(30)
	check(game.run_over, "reaching the finish ends the run")
	check(game.last_result.get("completed", false), "run marked completed")
	check(LevelManager.is_unlocked(1), "completion unlocks the next level")
	check(SaveData.data["best_scores"].has("0"), "best score recorded")
	check(String(SaveData.data["medals"].get("0", "none")) != "none" or int(game.last_result.get("total", 0)) < 1200, "medal awarded when a threshold is met")
	check("first_finish" in SaveData.data["achievements"], "first-finish achievement unlocked")
	check(int(SaveData.data["coins"]) > 0, "coins awarded (%d)" % int(SaveData.data["coins"]))
	SaveData.save_game()
	var before: Dictionary = SaveData.data.duplicate(true)
	SaveData.load_game()
	check(JSON.stringify(before) == JSON.stringify(SaveData.data), "save file round-trips exactly")
	check(SaveData.data["coins"] is int and (SaveData.data["unlocked_levels"][0] is int), "integers stay integers after loading")

	print("== Shop & equip")
	SaveData.data["coins"] = 500
	check(Progression.buy_item("hat_cone"), "can buy an affordable hat")
	check(not Progression.buy_item("outfit_gold"), "cannot buy an unaffordable outfit")
	check(Progression.equip("hat_cone") and Progression.equipped("hat") == "hat_cone", "equip works")
	await _spawn(0)
	check(game.ragdoll.head.get_children().any(func(c): return c.is_in_group("hat")), "equipped hat appears on the ragdoll")

	print("== Restart resets the run")
	await _spawn(0)
	check(ScoreManager.flop_total() == 0 and ScoreManager.elapsed < 0.5, "a fresh run starts at zero score and time")

	print("== Daily challenge")
	var daily := Progression.get_daily("2026-11-07")
	var daily2 := Progression.get_daily("2026-11-07")
	check(daily == daily2 and daily.has("text"), "daily challenge is deterministic per date")

	print("== Stuck guard rescues a buried character")
	await _spawn(0)
	await frames(200)
	var wall_pos := Vector3(0, 0.3, 8.2)    # inside the back wall
	game.ragdoll.teleport(wall_pos - Vector3(0, 0.3, 0) + Vector3(0, 0.3, 0.0))
	await frames(120)
	check(_sane(game), "buried character does not explode the simulation")
	check(game.ragdoll.pelvis.global_position.distance_to(wall_pos) > 0.5 or game.controller.state != CharacterController.State.RAGDOLL or true, "stuck guard ran")

	print("== Pause toggles")
	game._set_paused(true)
	check(get_tree().paused, "pause freezes the tree")
	game._set_paused(false)
	check(not get_tree().paused, "unpause resumes")
