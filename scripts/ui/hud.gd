class_name Hud
extends CanvasLayer
## In-game HUD: score + rating, timer, collectibles, stamina bar, stunt popups, objective/hints.

var score_label: Label
var rating_label: Label
var time_label: Label
var coll_label: Label
var cp_label: Label
var hint_label: Label
var daily_label: Label
var stamina: ProgressBar
var popup_box: VBoxContainer
var banner: Label
var objective_label: Label
var _score_shown := 0.0
var _score_target := 0
var _banner_tween: Tween


func build(level_info: Dictionary, collectible_total: int, hint: String) -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = UiKit.make_theme()

	# top-left: score
	var tl := UiKit.vbox(0)
	tl.position = Vector2(24, 16)
	root.add_child(tl)
	tl.add_child(UiKit.label("FLOP SCORE", 18, UiKit.COL_MUTED))
	score_label = UiKit.label("0", 56, UiKit.COL_ACCENT)
	tl.add_child(score_label)
	rating_label = UiKit.label("Mildly Wobbly", 24, UiKit.COL_TEXT)
	tl.add_child(rating_label)

	# top-right: time, collectibles, checkpoint
	var tr := UiKit.vbox(2)
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-300, 16)
	tr.custom_minimum_size = Vector2(276, 0)
	root.add_child(tr)
	time_label = UiKit.label("0:00.00", 40, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	tr.add_child(time_label)
	coll_label = UiKit.label("Rings 0/%d" % collectible_total, 24, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	tr.add_child(coll_label)
	cp_label = UiKit.label("Checkpoint: start", 20, UiKit.COL_MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	tr.add_child(cp_label)
	tr.add_child(UiKit.label(level_info["name"], 20, UiKit.COL_MUTED, HORIZONTAL_ALIGNMENT_RIGHT))

	# bottom-left: stamina
	var bl := UiKit.vbox(2)
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(24, -120)
	root.add_child(bl)
	bl.add_child(UiKit.label("GRIP", 16, UiKit.COL_MUTED))
	stamina = ProgressBar.new()
	stamina.custom_minimum_size = Vector2(240, 18)
	stamina.max_value = 1.0
	stamina.value = 1.0
	stamina.show_percentage = false
	bl.add_child(stamina)

	# bottom-center: hint
	hint_label = UiKit.label(hint, 20, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position = Vector2(-500, -48)
	hint_label.custom_minimum_size = Vector2(1000, 0)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint_label)

	# right-center: stunt popups
	popup_box = UiKit.vbox(2)
	popup_box.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	popup_box.position = Vector2(-380, -120)
	popup_box.custom_minimum_size = Vector2(340, 0)
	root.add_child(popup_box)

	# center banner
	banner = UiKit.label("", 54, UiKit.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.position = Vector2(-400, 150)
	banner.custom_minimum_size = Vector2(800, 0)
	banner.modulate.a = 0.0
	root.add_child(banner)

	# objective subtitle under the banner
	objective_label = UiKit.label("", 26, UiKit.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective_label.position = Vector2(-450, 225)
	objective_label.custom_minimum_size = Vector2(900, 0)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.modulate.a = 0.0
	root.add_child(objective_label)

	# daily banner
	daily_label = UiKit.label("", 20, Color(0.6, 1.0, 0.8))
	daily_label.position = Vector2(24, 140)
	root.add_child(daily_label)
	if LevelManager.daily_mode:
		var d := Progression.get_daily()
		daily_label.text = "DAILY: " + String(d["text"])


func set_score(total: int) -> void:
	_score_target = total


func set_rating(rating: String) -> void:
	rating_label.text = rating
	show_banner(rating.to_upper() + "!", UiKit.COL_ACCENT)


func set_time(t: float) -> void:
	time_label.text = UiKit.fmt_time(t)


func set_collectibles(count: int, total: int) -> void:
	coll_label.text = "Rings %d/%d" % [count, total]


func set_checkpoint(index: int) -> void:
	cp_label.text = "Checkpoint: %d" % (index + 1)


func set_stamina(ratio: float) -> void:
	stamina.value = ratio
	var fill := stamina.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	fill.bg_color = UiKit.COL_GOOD.lerp(UiKit.COL_BAD, 1.0 - ratio)
	stamina.add_theme_stylebox_override("fill", fill)


func popup(text: String, points: int) -> void:
	var l := UiKit.label("%s  +%d" % [text, points] if points > 0 else text, 26, UiKit.COL_ACCENT)
	popup_box.add_child(l)
	while popup_box.get_child_count() > 6:
		popup_box.get_child(0).queue_free()
		popup_box.remove_child(popup_box.get_child(0))
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func show_banner(text: String, color: Color, duration := 1.6) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	if _banner_tween:
		_banner_tween.kill()
	banner.modulate.a = 1.0
	banner.scale = Vector2(1.4, 1.4)
	banner.pivot_offset = banner.size * 0.5
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	_banner_tween.tween_interval(duration)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.4)


func show_objective(text: String, duration := 5.0) -> void:
	objective_label.text = text
	objective_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_property(objective_label, "modulate:a", 0.0, 0.6)


func hide_hint() -> void:
	if hint_label:
		hint_label.visible = false


func _process(delta: float) -> void:
	if score_label == null:
		return
	_score_shown = lerpf(_score_shown, float(_score_target), 1.0 - exp(-8.0 * delta))
	score_label.text = str(int(round(_score_shown)))
