extends Node
## Creates all InputMap actions in code, applies saved bindings, and supports remapping.

const ACTIONS := {
	"move_forward": {"label": "Move Forward", "key": KEY_W},
	"move_back": {"label": "Move Back", "key": KEY_S},
	"move_left": {"label": "Move Left", "key": KEY_A},
	"move_right": {"label": "Move Right", "key": KEY_D},
	"jump": {"label": "Jump", "key": KEY_SPACE},
	"run": {"label": "Run", "key": KEY_SHIFT},
	"dive": {"label": "Dive", "key": KEY_C},
	"grab": {"label": "Grab", "key": KEY_E},
	"push": {"label": "Push", "key": KEY_F},
	"recover": {"label": "Get Up", "key": KEY_R},
	"restart": {"label": "Restart Level", "key": KEY_BACKSPACE},
	"pause": {"label": "Pause", "key": KEY_ESCAPE},
}

const REMAPPABLE := ["move_forward", "move_back", "move_left", "move_right", "jump", "run", "dive", "grab", "push", "recover", "restart"]


func _ready() -> void:
	setup_defaults()
	apply_saved_bindings()


func setup_defaults() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = ACTIONS[action]["key"]
		InputMap.action_add_event(action, ev)
	# Arrow keys as secondary movement binding
	_add_key("move_forward", KEY_UP)
	_add_key("move_back", KEY_DOWN)
	_add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_RIGHT)
	# Gamepad
	_add_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_button("jump", JOY_BUTTON_A)
	_add_button("dive", JOY_BUTTON_B)
	_add_button("grab", JOY_BUTTON_RIGHT_SHOULDER)
	_add_button("push", JOY_BUTTON_X)
	_add_button("recover", JOY_BUTTON_Y)
	_add_button("pause", JOY_BUTTON_START)


func _add_key(action: String, keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _add_axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _add_button(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func apply_saved_bindings() -> void:
	var b: Dictionary = SaveData.get_setting("bindings", {})
	for action in b:
		if ACTIONS.has(action):
			rebind(action, int(b[action]), false)


## Replace the keyboard binding of an action with a new physical keycode.
func rebind(action: String, keycode: int, persist := true) -> void:
	if not ACTIONS.has(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var nev := InputEventKey.new()
	nev.physical_keycode = keycode as Key
	InputMap.action_add_event(action, nev)
	if persist:
		var b: Dictionary = SaveData.get_setting("bindings", {})
		b[action] = keycode
		SaveData.set_setting("bindings", b)


func reset_bindings() -> void:
	SaveData.set_setting("bindings", {})
	setup_defaults()


func key_label(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string(ev.physical_keycode)
	return "-"
