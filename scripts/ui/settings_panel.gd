class_name SettingsPanel
extends Control
## Audio / camera settings and key remapping. Used from the main menu and the pause menu.
## Conflicting keys are swapped between actions, so nothing is ever left unbound.

var on_back: Callable
var _listening := ""
var _bind_buttons: Dictionary = {}
var _status: Label


func build(back_cb: Callable) -> void:
	on_back = back_cb
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UiKit.fullscreen_dim(0.75))
	var d := UiKit.dialog("SETTINGS", Vector2(760, 0))
	add_child(d[0])
	var v: VBoxContainer = d[1]

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var inner := UiKit.vbox(10)
	inner.custom_minimum_size = Vector2(680, 0)
	scroll.add_child(inner)

	inner.add_child(UiKit.label("Audio & Camera", 28, UiKit.COL_ACCENT))
	_slider(inner, "Master volume", "master", 0.0, 1.0, 0.05, func(_v): AudioManager.apply_volumes())
	_slider(inner, "Sound effects", "sfx", 0.0, 1.0, 0.05, func(_v): AudioManager.apply_volumes())
	_slider(inner, "Music", "music", 0.0, 1.0, 0.05, func(_v): AudioManager.apply_volumes())
	_slider(inner, "Camera shake", "shake", 0.0, 1.0, 0.05, Callable())
	_slider(inner, "Field of view", "fov", 50.0, 100.0, 1.0, Callable())
	var inv := CheckButton.new()
	inv.text = "Invert camera Y"
	inv.button_pressed = bool(SaveData.get_setting("invert_y", false))
	inv.toggled.connect(func(on: bool) -> void: SaveData.set_setting("invert_y", on))
	inner.add_child(inv)

	inner.add_child(UiKit.spacer(8))
	inner.add_child(UiKit.label("Controls (click, then press a key)", 28, UiKit.COL_ACCENT))
	for action in InputConfig.REMAPPABLE:
		var row := UiKit.hbox(12)
		var name_l := UiKit.label(InputConfig.ACTIONS[action]["label"], 22)
		name_l.custom_minimum_size = Vector2(300, 0)
		row.add_child(name_l)
		var b := UiKit.button(InputConfig.key_label(action), func() -> void: _begin_listen(action), Vector2(220, 44), 20)
		_bind_buttons[action] = b
		row.add_child(b)
		inner.add_child(row)
	inner.add_child(UiKit.button("Reset controls to default", _reset_controls, Vector2(320, 48), 20))
	_status = UiKit.label("", 18, UiKit.COL_MUTED)
	inner.add_child(_status)

	v.add_child(UiKit.button("Back", func() -> void: on_back.call()))


func _slider(parent: Control, title: String, key: String, lo: float, hi: float, step: float, extra: Callable) -> void:
	var row := UiKit.hbox(12)
	var l := UiKit.label(title, 22)
	l.custom_minimum_size = Vector2(300, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(SaveData.get_setting(key, hi))
	s.custom_minimum_size = Vector2(260, 30)
	s.value_changed.connect(func(val: float) -> void:
		SaveData.data["settings"][key] = val
		if extra.is_valid():
			extra.call(val))
	s.drag_ended.connect(func(_changed: bool) -> void: SaveData.save_game())
	row.add_child(s)
	parent.add_child(row)


func _begin_listen(action: String) -> void:
	_listening = action
	(_bind_buttons[action] as Button).text = "Press a key..."
	_status.text = "Press the new key for %s (Esc to cancel)" % InputConfig.ACTIONS[action]["label"]


func _input(event: InputEvent) -> void:
	if _listening == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var kc: int = event.physical_keycode
	if kc != KEY_ESCAPE:
		# swap with any action already using this key
		for other in InputConfig.REMAPPABLE:
			if other != _listening and _action_key(other) == kc:
				InputConfig.rebind(other, _action_key(_listening))
		InputConfig.rebind(_listening, kc)
		_status.text = "%s bound to %s" % [InputConfig.ACTIONS[_listening]["label"], OS.get_keycode_string(kc as Key)]
	else:
		_status.text = "Cancelled"
	_listening = ""
	_refresh_buttons()


func _action_key(action: String) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev.physical_keycode
	return 0


func _refresh_buttons() -> void:
	for a in _bind_buttons:
		(_bind_buttons[a] as Button).text = InputConfig.key_label(a)


func _reset_controls() -> void:
	InputConfig.reset_bindings()
	_refresh_buttons()
	_status.text = "Controls reset"
