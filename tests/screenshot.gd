extends Node
## Captures screenshots of the main screens (needs a real renderer, e.g. xvfb + mesa).
## xvfb-run -a godot --path . --rendering-method gl_compatibility res://tests/screenshot.tscn -- /out/dir

var out_dir := "/tmp/claude-0/shots"

func shot(name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name, " ", img.get_size())

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	Engine.set_meta("flop_test", true)
	SaveData.path_override = "user://shots_save.json"
	SaveData.reset_all()
	SaveData.data["coins"] = 800
	SaveData.data["unlocked_levels"] = [0, 1, 2]
	SaveData.data["medals"] = {"0": "gold", "1": "silver"}
	SaveData.data["best_scores"] = {"0": 5200, "1": 3300}
	SaveData.data["best_times"] = {"0": 61.2, "1": 88.5}
	var menu := (load("res://scenes/main.tscn") as PackedScene).instantiate() as MainMenu
	add_child(menu)
	await shot("01_main_menu")
	menu.show_levels()
	await shot("02_level_select")
	menu.show_customize()
	await get_tree().create_timer(0.8).timeout
	await shot("03_customize")
	menu.show_records()
	await shot("04_records")
	menu.show_settings()
	await shot("05_settings")
	menu.show_daily()
	await shot("06_daily")
	remove_child(menu)
	menu.free()
	for lv in [0, 1, 2, 3, 4, 5]:
		LevelManager.current_index = lv
		var g := (load("res://scenes/gameplay.tscn") as PackedScene).instantiate() as Gameplay
		add_child(g)
		await get_tree().create_timer(1.5).timeout
		if lv == 0:
			Input.action_press("move_forward")
			await get_tree().create_timer(1.5).timeout
			Input.action_release("move_forward")
		await shot("10_level%d" % (lv + 1))
		if lv == 0:
			g._set_paused(true)
			await shot("11_pause")
			g._set_paused(false)
			ScoreManager.register_knock(6)
			ScoreManager.register_impact(15.0, "rubber")
			g.ragdoll.teleport(g.level.finish_pos + Vector3(0, 0.3, 0))
			await get_tree().create_timer(1.8).timeout
			await shot("12_results")
		remove_child(g)
		g.free()
	get_tree().quit()
