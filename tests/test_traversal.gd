extends Node
## Headless traversal test: proves the intended routes (launch pads, fans, dive gap, ledge
## mantle) are physically possible. Run:
##   godot --headless --path . res://tests/test_traversal.tscn
## Pass `-- trace` after the scene to print trajectories.

var passed := 0
var failed := 0
var game: Gameplay
var trace := false


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
	trace = "trace" in OS.get_cmdline_user_args()
	SaveData.path_override = "user://flop_test_traversal.json"
	SaveData.reset_all()
	await _run()
	print("\nRESULT: %d passed, %d failed" % [passed, failed])
	SaveData.reset_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://flop_test_traversal.json"))
	get_tree().quit(1 if failed > 0 else 0)


func _spawn(level_index: int) -> void:
	if game != null and is_instance_valid(game):
		remove_child(game)
		game.free()
	LevelManager.current_index = level_index
	LevelManager.daily_mode = false
	game = (load("res://scenes/gameplay.tscn") as PackedScene).instantiate() as Gameplay
	add_child(game)
	await frames(2)


func _scripted(level_index: int, start: Vector3, hold: Array, total_frames: int, tap_jump_at := -1, label := "") -> Vector3:
	await _spawn(level_index)
	game.controller.respawn_at(start)
	await frames(100)
	for a in hold:
		Input.action_press(a)
	for k in total_frames:
		if tap_jump_at >= 0 and k == tap_jump_at:
			Input.action_press("jump")
		elif tap_jump_at >= 0 and k == tap_jump_at + 3:
			Input.action_release("jump")
		await frames(1)
		if trace and k % 20 == 0:
			var p := game.ragdoll.pelvis.global_position
			var v := game.ragdoll.pelvis.linear_velocity
			print("     [%s] k=%3d pos=(%.1f, %.1f, %.1f) vel=(%.1f, %.1f, %.1f) state=%d resp=%d" % [label, k, p.x, p.y, p.z, v.x, v.y, v.z, game.controller.state, game.respawn_count])
	for a in hold:
		Input.action_release(a)
	return game.ragdoll.pelvis.global_position


func _run() -> void:
	print("== Traversal: the intended routes are physically possible")
	var pos: Vector3
	pos = await _scripted(1, Vector3(0, 0.1, -60.5), ["move_forward", "run"], 400, -1, "L2 pad")
	check(pos.y > 5.5 and pos.z < -79.0 and game.respawn_count == 0, "L2 launch pad reaches the high roof (%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z])
	pos = await _scripted(5, Vector3(0, 0.1, -39.0), ["move_forward", "run"], 400)
	check(pos.y > 6.5 and pos.z < -59.0 and pos.z > -73.0 and game.respawn_count == 0, "L6 launch pad lands on the raised platform (%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z])
	pos = await _scripted(3, Vector3(0, 0.1, -4.0), ["move_forward", "run"], 700, 40)
	check(pos.z < -20.0 and game.respawn_count == 0, "L4 steady fan carries you across gap 1 (z %.1f)" % pos.z)
	pos = await _scripted(3, Vector3(0, 0.1, -30.0), ["move_forward", "run"], 700, 40, "L4 gap2")
	check(pos.z < -45.5 and pos.y > -1.0 and game.respawn_count == 0, "L4 pulsing fan carries you across gap 2 (z %.1f)" % pos.z)
	pos = await _scripted(3, Vector3(0, 0.1, -56.0), ["move_forward", "run"], 800, 40)
	check(pos.y > 5.2 and pos.z < -72.0 and game.respawn_count == 0, "L4 tower fan lifts you to the raised platform (%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z])
	pos = await _scripted(5, Vector3(0, 7.1, -158.0), ["move_forward", "run"], 800, 40)
	check(pos.y > 11.5 and pos.z < -177.0 and game.respawn_count == 0, "L6 summit fan lifts you to the finish platform (%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z])

	# L1: dive across the 4m gap (triggered by position, like a player would)
	await _spawn(0)
	game.controller.respawn_at(Vector3(0, 0.1, -32.0))
	await frames(100)
	Input.action_press("move_forward")
	Input.action_press("run")
	for k in 400:
		await frames(1)
		if game.ragdoll.pelvis.global_position.z < -38.6:
			break
	Input.action_press("dive")
	await frames(2)
	Input.action_release("dive")
	await frames(450)
	Input.action_release("move_forward")
	Input.action_release("run")
	pos = game.ragdoll.pelvis.global_position
	check(pos.z < -43.0 and game.respawn_count == 0, "L1 dive clears the 4m gap (z %.1f)" % pos.z)

	# L1: grab the ledge and mantle onto the 2.2m block
	await _spawn(0)
	game.controller.respawn_at(Vector3(0, 0.1, -50.0))
	await frames(100)
	Input.action_press("move_forward")
	Input.action_press("grab")
	for k in 600:
		if k % 50 == 30:
			Input.action_press("jump")
		elif k % 50 == 34:
			Input.action_release("jump")
		await frames(1)
		var pp := game.ragdoll.pelvis.global_position
		if pp.y > 2.5 and pp.z < -52.6:
			break
	Input.action_release("move_forward")
	Input.action_release("grab")
	Input.action_release("jump")
	await frames(300)
	pos = game.ragdoll.pelvis.global_position
	check(pos.z < -52.6 and pos.y > 2.0 and game.respawn_count == 0, "L1 grab + pull-up gets you onto the ledge (%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z])

