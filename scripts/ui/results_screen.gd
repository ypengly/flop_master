class_name ResultsScreen
extends CanvasLayer
## End-of-run screen: Flop Score breakdown with a count-up reveal, rating, medal, coins,
## personal bests, new achievements and Retry / Next / Menu buttons.

signal retry_requested
signal next_requested
signal menu_requested


func _init() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_results(info: Dictionary) -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UiKit.make_theme()
	add_child(root)
	root.add_child(UiKit.fullscreen_dim(0.78))
	var title := "LEVEL COMPLETE!" if info["completed"] else "RUN OVER"
	var d := UiKit.dialog(title, Vector2(760, 0))
	root.add_child(d[0])
	var v: VBoxContainer = d[1]
	v.add_theme_constant_override("separation", 6)
	(v.get_child(0) as Label).add_theme_font_size_override("font_size", 34)
	v.add_child(UiKit.label(info["level_name"], 20, UiKit.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var rating := UiKit.label(String(info["rating"]).to_upper(), 38, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(rating)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 2)
	var center_row := CenterContainer.new()
	center_row.add_child(grid)
	v.add_child(center_row)
	var rows: Array = []
	var breakdown: Dictionary = info["breakdown"]
	for k in breakdown:
		if int(breakdown[k]) > 0:
			rows.append([k, int(breakdown[k])])
	if int(info["bonus"]) > 0:
		rows.append(["Completion + time bonus", int(info["bonus"])])
	if rows.is_empty():
		rows.append(["Barely flopped at all", 0])
	var value_labels: Array[Label] = []
	for r in rows:
		var nl := UiKit.label(r[0], 19, UiKit.COL_MUTED)
		nl.custom_minimum_size = Vector2(190, 0)
		grid.add_child(nl)
		var vl := UiKit.label("0", 19, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		vl.custom_minimum_size = Vector2(70, 0)
		grid.add_child(vl)
		value_labels.append(vl)

	var total_l := UiKit.label("TOTAL  0", 40, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(total_l)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var details := UiKit.vbox(1)
	details.custom_minimum_size = Vector2(690, 0)
	scroll.add_child(details)
	details.add_child(UiKit.label("Time %s    Rings %d/%d    Biggest fall %.0fm" % [UiKit.fmt_time(info["time"]), info["collectibles"], info["collectible_total"], info["biggest_fall"]], 20, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var res: Dictionary = info["result"]
	if info["completed"]:
		var medal: String = res["medal"]
		var ml := UiKit.label("Medal: %s" % medal.to_upper(), 24, UiKit.medal_color(medal), HORIZONTAL_ALIGNMENT_CENTER)
		details.add_child(ml)
	if res["new_best"]:
		details.add_child(UiKit.label("NEW PERSONAL BEST SCORE!", 20, UiKit.COL_GOOD, HORIZONTAL_ALIGNMENT_CENTER))
	if res["new_best_time"]:
		details.add_child(UiKit.label("New best time!", 18, UiKit.COL_GOOD, HORIZONTAL_ALIGNMENT_CENTER))
	details.add_child(UiKit.label("+%d coins" % int(res["coins"]), 20, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	if res["unlocked_next"]:
		details.add_child(UiKit.label("New stage unlocked!", 20, UiKit.COL_GOOD, HORIZONTAL_ALIGNMENT_CENTER))
	if info.get("daily_done", false):
		details.add_child(UiKit.label("DAILY CHALLENGE COMPLETE! +250 coins", 20, Color(0.6, 1.0, 0.8), HORIZONTAL_ALIGNMENT_CENTER))
	for id in res["new_achievements"]:
		details.add_child(UiKit.label("Achievement: " + String(Progression.ACHIEVEMENTS[id]), 20, Color(1.0, 0.7, 0.9), HORIZONTAL_ALIGNMENT_CENTER))

	var buttons := UiKit.hbox(14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(buttons)
	buttons.add_child(UiKit.button("Retry", func() -> void: retry_requested.emit(), Vector2(190, 56)))
	if info["completed"] and LevelManager.has_next() and not LevelManager.daily_mode:
		buttons.add_child(UiKit.button("Next Level", func() -> void: next_requested.emit(), Vector2(190, 56)))
	buttons.add_child(UiKit.button("Menu", func() -> void: menu_requested.emit(), Vector2(190, 56)))

	# count-up reveal
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for i in rows.size():
		var target: int = rows[i][1]
		var lab: Label = value_labels[i]
		tw.tween_method(func(x: float) -> void: lab.text = str(int(x)), 0.0, float(target), 0.25)
	tw.tween_method(func(x: float) -> void: total_l.text = "TOTAL  %d" % int(x), 0.0, float(info["total"]), 0.6)
	AudioManager.play("win" if info["completed"] else "fail", 0.8, 1.0, 0.0)
