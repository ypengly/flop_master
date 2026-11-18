class_name CrateDropper
extends Node3D
## Periodically drops a crate/ball from above, with a warning shadow. Old drops are freed so
## the physics world stays light. Crates that fall away count as "knockable" props.

var interval := 2.5
var size_range := Vector2(0.6, 1.0)
var spread := Vector3(3, 0, 3)
var max_alive := 6
var level: LevelBase
var _t := 0.0
var _alive: Array[RigidBody3D] = []
var rng := RandomNumberGenerator.new()
var ball_chance := 0.2
var target: Node3D            # optional: aim near the player


func setup(lvl: LevelBase, pos: Vector3, per := 2.5, area := Vector3(3, 0, 3)) -> void:
	level = lvl
	position = pos
	interval = per
	spread = area
	rng.seed = int(pos.x * 31 + pos.z * 17 + 7)
	_t = rng.randf() * per
	# visual hopper
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(area.x * 2.0 + 1.0, 0.3, area.z * 2.0 + 1.0)
	mi.mesh = bm
	mi.material_override = SurfaceMaterials.visual("metal", Color(0.5, 0.5, 0.55))
	add_child(mi)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < interval:
		return
	_t = 0.0
	_alive = _alive.filter(func(c): return is_instance_valid(c) and c.global_position.y > -30.0)
	while _alive.size() >= max_alive:
		var old: RigidBody3D = _alive.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var offset := Vector3(rng.randf_range(-spread.x, spread.x), -0.5, rng.randf_range(-spread.z, spread.z))
	if target != null and is_instance_valid(target) and rng.randf() < 0.5:
		offset = Vector3(target.global_position.x - global_position.x, -0.5, target.global_position.z - global_position.z)
		offset.x = clampf(offset.x, -spread.x * 2.0, spread.x * 2.0)
		offset.z = clampf(offset.z, -spread.z * 2.0, spread.z * 2.0)
	var spawn_pos := global_position + offset
	var rb: RigidBody3D
	if rng.randf() < ball_chance:
		rb = level.add_ball(spawn_pos, rng.randf_range(0.35, 0.6), "rubber", 3.0)
	else:
		var s := rng.randf_range(size_range.x, size_range.y)
		rb = level.add_crate(spawn_pos, Vector3(s, s, s), "wood" if rng.randf() < 0.7 else "metal", 4.0 + s * 3.0)
	rb.angular_velocity = Vector3(rng.randf_range(-2, 2), rng.randf_range(-2, 2), rng.randf_range(-2, 2))
	_alive.append(rb)
