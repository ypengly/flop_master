class_name FanUpdraft
extends Node3D
## Giant fan: a spinning blade visual plus an Area3D that applies an upward (or any-direction)
## force to every ragdoll body and prop inside it. Strength falls off with distance from the fan.

var area: Area3D
var direction := Vector3.UP
var strength := 38.0           # acceleration (m/s^2) at the fan face; gravity is 24
var reach := 9.0
var blade: Node3D
var spin_speed := 9.0
var pulse := 0.0               # >0 = fan power pulses on/off with this period
var _t := 0.0
var _bodies: Array[RigidBody3D] = []


func setup(pos: Vector3, radius := 2.2, reach_len := 9.0, power := 38.0, dir := Vector3.UP, pulse_period := 0.0, flow_radius := 0.0) -> void:
	var fr := flow_radius if flow_radius > 0.0 else radius
	position = pos
	direction = dir.normalized()
	reach = reach_len
	strength = power
	pulse = pulse_period
	# housing
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius * 0.9
	tm.outer_radius = radius * 1.05
	ring.mesh = tm
	ring.material_override = SurfaceMaterials.visual("metal", Color(0.6, 0.65, 0.8))
	add_child(ring)
	blade = Node3D.new()
	add_child(blade)
	for i in 4:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(radius * 0.9, 0.06, 0.4)
		b.mesh = bm
		b.position = Vector3(radius * 0.45, 0, 0)
		var holder := Node3D.new()
		holder.rotation.y = TAU * i / 4.0
		holder.add_child(b)
		b.material_override = SurfaceMaterials.visual("metal", Color(0.9, 0.3, 0.3))
		blade.add_child(holder)
	# Orient so that local +Y = airflow direction.
	if not direction.is_equal_approx(Vector3.UP):
		var axis := Vector3.UP.cross(direction)
		if axis.length() < 0.001:
			axis = Vector3.RIGHT
		rotate(axis.normalized(), Vector3.UP.angle_to(direction))
	# flow area (local space: extends along +Y)
	area = Area3D.new()
	area.collision_layer = 0
	area.collision_mask = Ragdoll.LAYER_PLAYER | Ragdoll.LAYER_PROP
	area.monitoring = true
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = fr
	cyl.height = reach
	cs.shape = cyl
	cs.position = Vector3(0, reach * 0.5, 0)
	area.add_child(cs)
	add_child(area)
	# soft visual cone of air
	var air := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = fr
	cm.bottom_radius = fr
	cm.height = reach
	air.mesh = cm
	air.position = Vector3(0, reach * 0.5, 0)
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0.8, 0.95, 1.0, 0.10)
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	air.material_override = am
	add_child(air)
	area.body_entered.connect(func(b: Node) -> void:
		if b is RigidBody3D and not (b in _bodies):
			_bodies.append(b))
	area.body_exited.connect(func(b: Node) -> void:
		_bodies.erase(b))


## Pulsing fans never switch fully off over a pit (that would be a death sentence). Vertical fans
## bob between full power and 85% so you rise and sink a little; sideways fans drop to a light
## breeze, which is the actual gust-and-pause challenge.
func _power_now() -> float:
	if pulse <= 0.0:
		return 1.0
	var low := 0.85 if direction.y > 0.5 else 0.15
	return 1.0 if fmod(_t, pulse) < pulse * 0.6 else low


func _physics_process(delta: float) -> void:
	_t += delta
	var p := _power_now()
	blade.rotate_y(spin_speed * delta * (0.25 + 0.75 * p))
	if p <= 0.0:
		return
	var fan_pos := global_position
	for b in _bodies:
		if not is_instance_valid(b):
			continue
		var dist := (b.global_position - fan_pos).dot(direction)
		var falloff := clampf(1.0 - dist / reach, 0.0, 1.0)
		# lift per body mass so heavy and light parts float together
		var accel := strength * falloff * p
		b.apply_central_force(direction * accel * b.mass)
		if b.get_parent() is Ragdoll:
			b.apply_torque(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 2.0)   # a bit of flutter
