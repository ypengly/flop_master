class_name StuckGuard
extends Node
## Protects against the ragdoll getting trapped inside geometry or wedged somewhere.
## Remembers the last safe standing spot; reports when the character should be rescued.

signal rescue_needed(safe_pos: Vector3)

var ragdoll: Ragdoll
var last_safe := Vector3.ZERO
var _safe_timer := 0.0
var _window_timer := 0.0
var _window_pos := Vector3.ZERO
var _inside_time := 0.0
var enabled := true


func setup(r: Ragdoll, start_feet_pos: Vector3) -> void:
	ragdoll = r
	last_safe = start_feet_pos
	_window_pos = r.pelvis.global_position


func remember_safe(feet_pos: Vector3) -> void:
	last_safe = feet_pos


func reset(feet_pos: Vector3) -> void:
	last_safe = feet_pos
	_window_timer = 0.0
	_inside_time = 0.0
	_window_pos = ragdoll.pelvis.global_position


## Call once per physics frame. `grounded_upright` = standing normally right now.
func update(delta: float, grounded_upright: bool, ground_point: Vector3, immobile_state: bool) -> void:
	if not enabled or ragdoll == null:
		return
	if grounded_upright:
		_safe_timer += delta
		if _safe_timer > 0.5:
			_safe_timer = 0.0
			last_safe = ground_point + Vector3.UP * 0.05
	else:
		_safe_timer = 0.0

	# 1. Body core inside static geometry?
	if _core_inside_world():
		_inside_time += delta
		if _inside_time > 0.35:
			_inside_time = 0.0
			rescue_needed.emit(last_safe)
			return
	else:
		_inside_time = 0.0

	# 2. Wedged: a ragdolled/recovering body that is not moving for too long
	var check_time := float(Config.get_value("character", "stuck_check_time", 2.5))
	var eps := float(Config.get_value("character", "stuck_move_epsilon", 0.05))
	if immobile_state:
		_window_timer += delta
		if _window_timer >= check_time:
			var moved := ragdoll.pelvis.global_position.distance_to(_window_pos)
			_window_timer = 0.0
			_window_pos = ragdoll.pelvis.global_position
			if moved < eps * check_time and ragdoll.pelvis.linear_velocity.length() < 0.3 and _is_wedged():
				rescue_needed.emit(last_safe)
	else:
		_window_timer = 0.0
		_window_pos = ragdoll.pelvis.global_position


func _core_inside_world() -> bool:
	var space := ragdoll.get_world_3d().direct_space_state
	for part_name in ["pelvis", "torso", "head"]:
		var q := PhysicsShapeQueryParameters3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.05
		q.shape = s
		q.transform = Transform3D(Basis.IDENTITY, (ragdoll.parts[part_name] as RigidBody3D).global_position)
		q.collision_mask = Ragdoll.LAYER_WORLD
		if not space.intersect_shape(q, 1).is_empty():
			return true
	return false


## Wedged = jammed against geometry on two or more sides (e.g. in a crack), not just lying down.
func _is_wedged() -> bool:
	var space := ragdoll.get_world_3d().direct_space_state
	var c := ragdoll.pelvis.global_position
	var blocked := 0
	for dir in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3.UP]:
		var q := PhysicsRayQueryParameters3D.create(c, c + dir * 0.45, Ragdoll.LAYER_WORLD | Ragdoll.LAYER_PROP)
		if not space.intersect_ray(q).is_empty():
			blocked += 1
	return blocked >= 3
