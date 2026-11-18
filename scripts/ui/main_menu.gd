class_name MainMenu
extends Control
## All front-end screens. Each view is rebuilt on demand into `content`.

var content: Control
var _title_tween: Tween
var _spin_tween: Tween
var _preview_ragdoll: Ragdoll
var _preview_pivot: Node3D
var _coins_label: Label


func _ready() -> void:
	theme = UiKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_background()
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	AudioManager.play_music()
	show_main()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = UiKit.COL_BG
	add_child(bg)
	# drifting confetti blobs
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 22:
		var blob := ColorRect.new()
		var sz := rng.randf_range(24, 90)
		blob.size = Vector2(sz, sz)
		blob.color = Color.from_hsv(rng.randf(), 0.55, 0.9, 0.18)
		blob.position = Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720))
		blob.rotation = rng.randf() * TAU
		add_child(blob)
		var tw := create_tween().set_loops()
		var dy := rng.randf_range(20, 60)
		var dur := rng.randf_range(2.5, 5.0)
		tw.tween_property(blob, "position:y", blob.position.y + dy, dur).set_trans(Tween.TRANS_SINE)
		tw.tween_property(blob, "position:y", blob.position.y, dur).set_trans(Tween.TRANS_SINE)


func _clear() -> void:
	# Kill looping tweens first: their targets are about to be freed.
	if _title_tween:
		_title_tween.kill()
		_title_tween = null
	if _spin_tween:
		_spin_tween.kill()
		_spin_tween = null
	for c in content.get_children():
		c.queue_free()
		content.remove_child(c)
	if _preview_ragdoll:
		_preview_ragdoll = null


func _coins_text() -> String:
	return "Coins: %d" % int(SaveData.data["coins"])


# ------------------------------------------------------------------ main

func show_main() -> void:
	_clear()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(center)
	var v := UiKit.vbox(14)
	center.add_child(v)
	var title := UiKit.label("FLOP MASTER", 96, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 14)
	title.pivot_offset = Vector2(330, 60)
	v.add_child(title)
	v.add_child(UiKit.label("The art of falling over, professionally.", 26, UiKit.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.spacer(18))
	if _title_tween:
		_title_tween.kill()
	_title_tween = create_tween().set_loops()
	_title_tween.tween_property(title, "rotation_degrees", 2.5, 1.2).set_trans(Tween.TRANS_SINE)
	_title_tween.tween_property(title, "rotation_degrees", -2.5, 1.2).set_trans(Tween.TRANS_SINE)

	var col := UiKit.vbox(10)
	var cc := CenterContainer.new()
	cc.add_child(col)
	v.add_child(cc)
	var play := UiKit.button("PLAY", show_levels, Vector2(360, 64), 30)
	col.add_child(play)
	col.add_child(UiKit.button("Daily Stunt Challenge", show_daily, Vector2(360, 52)))
	col.add_child(UiKit.button("Customize Character", show_customize, Vector2(360, 52)))
	col.add_child(UiKit.button("Records & Achievements", show_records, Vector2(360, 52)))
	col.add_child(UiKit.button("Settings", show_settings, Vector2(360, 52)))
	if OS.get_name() != "Web":
		col.add_child(UiKit.button("Quit", func() -> void: get_tree().quit(), Vector2(360, 52)))
	play.grab_focus()
	var foot := UiKit.label(_coins_text(), 24, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(foot)


# ------------------------------------------------------------------ level select

func show_levels() -> void:
	_clear()
	var d := UiKit.dialog("SELECT LEVEL", Vector2(1100, 0))
	content.add_child(d[0])
	var v: VBoxContainer = d[1]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	v.add_child(grid)
	for i in LevelManager.count():
		grid.add_child(_level_card(i))
	v.add_child(UiKit.button("Back", show_main))


func _level_card(i: int) -> Control:
	var info := LevelManager.level(i)
	var unlocked := LevelManager.is_unlocked(i)
	var p := UiKit.panel(Vector2(330, 170))
	var sb := UiKit.style(Color(info["color"]).darkened(0.55) if unlocked else Color(0.16, 0.15, 0.25), 18, Color(info["color"]) if unlocked else Color(0.3, 0.3, 0.4), 3)
	p.add_theme_stylebox_override("panel", sb)
	var v := UiKit.vbox(4)
	p.add_child(v)
	v.add_child(UiKit.label("%d. %s" % [i + 1, info["name"]], 24, UiKit.COL_TEXT if unlocked else UiKit.COL_MUTED))
	if unlocked:
		var key := str(i)
		var medal: String = SaveData.data["medals"].get(key, "none")
		var best: int = int(SaveData.data["best_scores"].get(key, 0))
		var t = SaveData.data["best_times"].get(key, null)
		v.add_child(UiKit.label("Medal: %s" % medal.capitalize(), 20, UiKit.medal_color(medal)))
		v.add_child(UiKit.label("Best: %d   Time: %s" % [best, UiKit.fmt_time(float(t)) if t != null else "--"], 18, UiKit.COL_MUTED))
		v.add_child(UiKit.button("Play", func() -> void: LevelManager.start_level(i), Vector2(120, 40), 20))
	else:
		v.add_child(UiKit.label("LOCKED", 28, UiKit.COL_BAD))
		v.add_child(UiKit.label("Finish level %d to unlock" % i, 18, UiKit.COL_MUTED))
	return p


# ------------------------------------------------------------------ daily

func show_daily() -> void:
	_clear()
	var d := UiKit.dialog("DAILY STUNT CHALLENGE", Vector2(700, 0))
	content.add_child(d[0])
	var v: VBoxContainer = d[1]
	var daily := Progression.get_daily()
	v.add_child(UiKit.label(daily["date"], 22, UiKit.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.label("Level: " + String(daily["level_name"]), 30, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var goal := UiKit.label(String(daily["text"]), 30, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(goal)
	v.add_child(UiKit.label("Reward: 250 coins", 22, UiKit.COL_GOOD, HORIZONTAL_ALIGNMENT_CENTER))
	if Progression.daily_completed():
		v.add_child(UiKit.label("COMPLETED TODAY!", 32, UiKit.COL_GOOD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.button("Play Today's Challenge", func() -> void: LevelManager.start_level(int(daily["level"]), true), Vector2(380, 60), 26))
	v.add_child(UiKit.button("Back", show_main))


# ------------------------------------------------------------------ customize

func show_customize() -> void:
	_clear()
	var d := UiKit.dialog("CUSTOMIZE", Vector2(1100, 0))
	content.add_child(d[0])
	var v: VBoxContainer = d[1]
	_coins_label = UiKit.label(_coins_text(), 26, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_coins_label)
	var row := UiKit.hbox(24)
	v.add_child(row)

	# 3D preview
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(340, 440)
	svc.stretch = true
	row.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = false
	sv.size = Vector2i(340, 440)
	sv.msaa_3d = Viewport.MSAA_4X
	svc.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.26, 0.55)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	sv.add_child(light)
	_preview_pivot = Node3D.new()
	_preview_pivot.position = Vector3(0, 0.95, 0)
	sv.add_child(_preview_pivot)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0.05, 3.2)
	camera.fov = 40.0
	_preview_pivot.add_child(camera)
	_preview_ragdoll = Ragdoll.new()
	sv.add_child(_preview_ragdoll)
	_preview_ragdoll.build(Vector3.ZERO, Progression.equipped("outfit"), Progression.equipped("hat"))
	for part in _preview_ragdoll.all_parts():
		(part as RigidBody3D).freeze = true
		(part as RigidBody3D).collision_layer = 0
		(part as RigidBody3D).collision_mask = 0
	_spin_tween = create_tween().set_loops()
	_spin_tween.tween_property(_preview_pivot, "rotation:y", TAU, 9.0).from(0.0)

	var lists := UiKit.vbox(10)
	lists.custom_minimum_size = Vector2(660, 0)
	row.add_child(lists)
	lists.add_child(UiKit.label("Outfits", 26, UiKit.COL_ACCENT))
	lists.add_child(_item_grid("outfit"))
	lists.add_child(UiKit.label("Hats", 26, UiKit.COL_ACCENT))
	lists.add_child(_item_grid("hat"))
	v.add_child(UiKit.button("Back", show_main))


func _item_grid(slot: String) -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for id in Progression.items_for_slot(slot):
		var item: Dictionary = Progression.ITEMS[id]
		var owned := Progression.is_item_unlocked(id)
		var equipped: bool = Progression.equipped(slot) == id
		var text: String = String(item["name"])
		if equipped:
			text += "  [ON]"
		elif not owned:
			text += "  (%d)" % int(item["cost"])
		var b := UiKit.button(text, func() -> void: _on_item_pressed(id), Vector2(208, 48), 17)
		if not owned and int(SaveData.data["coins"]) < int(item["cost"]):
			b.modulate = Color(1, 1, 1, 0.55)
		grid.add_child(b)
	return grid


func _on_item_pressed(id: String) -> void:
	if not Progression.is_item_unlocked(id):
		if not Progression.buy_item(id):
			AudioManager.play("fail", 0.4)
			return
		AudioManager.play("pickup")
	Progression.equip(id)
	show_customize()


# ------------------------------------------------------------------ records

func show_records() -> void:
	_clear()
	var d := UiKit.dialog("RECORDS & ACHIEVEMENTS", Vector2(980, 0))
	content.add_child(d[0])
	var v: VBoxContainer = d[1]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(920, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var inner := UiKit.vbox(6)
	inner.custom_minimum_size = Vector2(900, 0)
	scroll.add_child(inner)

	inner.add_child(UiKit.label("Personal Bests", 28, UiKit.COL_ACCENT))
	for i in LevelManager.count():
		var key := str(i)
		var medal: String = SaveData.data["medals"].get(key, "none")
		var t = SaveData.data["best_times"].get(key, null)
		var line := "%d. %-26s  Score %6d   Time %s   Medal %s" % [i + 1, LevelManager.level(i)["name"], int(SaveData.data["best_scores"].get(key, 0)), UiKit.fmt_time(float(t)) if t != null else "--", medal.capitalize()]
		inner.add_child(UiKit.label(line, 20, UiKit.medal_color(medal) if medal != "none" else UiKit.COL_TEXT))

	inner.add_child(UiKit.spacer(10))
	var st: Dictionary = SaveData.data["stats"]
	inner.add_child(UiKit.label("Lifetime Stats", 28, UiKit.COL_ACCENT))
	inner.add_child(UiKit.label("Runs %d    Levels completed %d    Rings %d    Falls %d    Restarts %d    Total flop score %d" % [st["flops"], st["levels_completed"], st["collectibles"], st["falls"], st["restarts"], st["total_score"]], 20))

	inner.add_child(UiKit.spacer(10))
	var got: Array = SaveData.data["achievements"]
	inner.add_child(UiKit.label("Achievements  %d / %d" % [got.size(), Progression.ACHIEVEMENTS.size()], 28, UiKit.COL_ACCENT))
	for id in Progression.ACHIEVEMENTS:
		var unlocked: bool = id in got
		inner.add_child(UiKit.label(("[x] " if unlocked else "[ ] ") + String(Progression.ACHIEVEMENTS[id]), 20, UiKit.COL_GOOD if unlocked else UiKit.COL_MUTED))
	v.add_child(UiKit.button("Back", show_main))


# ------------------------------------------------------------------ settings

func show_settings() -> void:
	_clear()
	var panel := SettingsPanel.new()
	content.add_child(panel)
	panel.build(func() -> void:
		SaveData.save_game()
		show_main())
