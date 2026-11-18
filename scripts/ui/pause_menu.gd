class_name PauseMenu
extends CanvasLayer
## Pause overlay: Resume, Restart, Settings, Quit. Works while the tree is paused.

signal resume_requested
signal restart_requested
signal quit_requested
signal end_run_requested

var _main_view: Control
var _settings: SettingsPanel


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UiKit.make_theme()
	add_child(root)
	_main_view = Control.new()
	_main_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_main_view)
	_main_view.add_child(UiKit.fullscreen_dim(0.6))
	var d := UiKit.dialog("PAUSED", Vector2(420, 0))
	_main_view.add_child(d[0])
	var v: VBoxContainer = d[1]
	v.add_child(UiKit.button("Resume", func() -> void: resume_requested.emit()))
	v.add_child(UiKit.button("Restart Level", func() -> void: restart_requested.emit()))
	v.add_child(UiKit.button("End Run & Score It", func() -> void: end_run_requested.emit()))
	v.add_child(UiKit.button("Settings", _open_settings))
	v.add_child(UiKit.button("Quit to Menu", func() -> void: quit_requested.emit()))
	var hint := UiKit.label("Restart anytime with %s" % InputConfig.key_label("restart"), 18, UiKit.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(hint)
	_settings = SettingsPanel.new()
	root.add_child(_settings)
	_settings.build(_close_settings)
	_settings.visible = false


func _open_settings() -> void:
	_main_view.visible = false
	_settings.visible = true


func _close_settings() -> void:
	_settings.visible = false
	_main_view.visible = true
	SaveData.save_game()
