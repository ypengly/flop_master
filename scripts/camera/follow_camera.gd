class_name FollowCamera
extends Camera3D
## Smoothed third-person camera with dynamic framing: pulls back and widens FOV with speed,
## looks slightly ahead of the velocity, shakes on impacts, and never clips through walls.

var target: Node3D            # usually the torso
var target_velocity := Vector3.ZERO
var yaw := 0.0
var pitch := -0.28
var _pos_smooth := Vector3.ZERO
var _look_smooth := Vector3.ZERO
var _shake := 0.0
var _extra_dist := 0.0
var _initialized := false
var _exclude: Array[RID] = []
var free_look := true


func setup(t: Node3D, exclude_rids: Array[RID], start_yaw := 0.0) -> void:
	target = t
	_exclude = exclude_rids
	yaw = start_yaw
	fov = float(SaveData.get_setting("fov", Config.get_value("camera", "fov_base", 68.0)))
	current = true
	_initialized = false


func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount * float(SaveData.get_setting("shake", 1.0)), 1.2)


func snap() -> void:
	_initialized = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and free_look and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := float(Config.get_value("camera", "mouse_sensitivity", 0.0035))
		yaw -= event.relative.x * s
		var inv := -1.0 if bool(SaveData.get_setting("invert_y", false)) else 1.0
		pitch = clampf(pitch - event.relative.y * s * inv, -1.2, 0.2)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	# Gamepad / keyboard look
	var look := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") if false else Vector2.ZERO
	yaw -= look.x * delta * 2.0

	var cs: Dictionary = Config.section("camera")
	var speed := target_velocity.length()
	var want_extra := minf(speed * float(cs.get("speed_zoom", 0.22)), float(cs.get("max_extra_distance", 6.0)))
	_extra_dist = lerpf(_extra_dist, want_extra, 1.0 - exp(-2.0 * delta))
	var dist := float(cs.get("distance", 7.5)) + _extra_dist
	var height := float(cs.get("height", 3.2)) + _extra_dist * 0.25
	var base_fov := float(SaveData.get_setting("fov", cs.get("fov_base", 68.0)))
	var fov_extra := minf(speed * float(cs.get("fov_speed_gain", 0.5)), float(cs.get("fov_max_extra", 22.0)))
	fov = lerpf(fov, base_fov + fov_extra, 1.0 - exp(-3.0 * delta))

	var focus := target.global_position + Vector3(0, 0.3, 0)
	var ahead := Vector3(target_velocity.x, 0.0, target_velocity.z) * 0.12
	focus += ahead.limit_length(2.5)

	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	var desired := focus + dir * dist + Vector3(0, height * 0.35, 0)

	# keep camera out of walls
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(focus, desired, Ragdoll.LAYER_WORLD)
	q.exclude = _exclude
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		desired = hit["position"] + (focus - desired).normalized() * 0.3

	if not _initialized:
		_pos_smooth = desired
		_look_smooth = focus
		_initialized = true
	var follow := float(cs.get("follow_smooth", 5.0))
	var look_s := float(cs.get("look_smooth", 7.0))
	_pos_smooth = _pos_smooth.lerp(desired, 1.0 - exp(-follow * delta))
	_look_smooth = _look_smooth.lerp(focus, 1.0 - exp(-look_s * delta))

	var shake_off := Vector3.ZERO
	if _shake > 0.01:
		shake_off = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25
		_shake = maxf(0.0, _shake - float(cs.get("shake_decay", 4.0)) * delta * 0.25)
	global_position = _pos_smooth + shake_off
	if (_look_smooth - global_position).length() > 0.1:
		look_at(_look_smooth, Vector3.UP)
