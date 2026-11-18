class_name Ragdoll
extends Node3D
## Articulated ragdoll: 11 rigid bodies connected by cone-twist (spine, neck, shoulders,
## hips) and hinge (elbows, knees) joints with limits. Same-character parts share a
## collision layer that does not collide with itself, so limbs never fight each other.
## The node must sit at the world origin with an identity transform.

signal part_hit(part: RigidBody3D, speed: float, other: Node)

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_PROP := 4
const LAYER_SENSOR := 8

# name -> [shape, dims, rest_center (feet at y=0), mass, color_slot]
const SPEC := {
	"pelvis":   ["box", Vector3(0.32, 0.20, 0.2), Vector3(0, 1.08, 0), 6.0, "pants"],
	"torso":    ["box", Vector3(0.38, 0.46, 0.22), Vector3(0, 1.42, 0), 8.0, "shirt"],
	"head":     ["sphere", 0.17, Vector3(0, 1.80, 0), 3.0, "skin"],
	"upper_arm_l": ["capsule", Vector2(0.06, 0.32), Vector3(-0.30, 1.48, 0), 1.4, "shirt"],
	"upper_arm_r": ["capsule", Vector2(0.06, 0.32), Vector3(0.30, 1.48, 0), 1.4, "shirt"],
	"forearm_l": ["capsule", Vector2(0.055, 0.34), Vector3(-0.30, 1.15, 0), 1.0, "skin"],
	"forearm_r": ["capsule", Vector2(0.055, 0.34), Vector3(0.30, 1.15, 0), 1.0, "skin"],
	"thigh_l":  ["capsule", Vector2(0.09, 0.50), Vector3(-0.11, 0.76, 0), 3.0, "pants"],
	"thigh_r":  ["capsule", Vector2(0.09, 0.50), Vector3(0.11, 0.76, 0), 3.0, "pants"],
	"shin_l":   ["capsule", Vector2(0.08, 0.50), Vector3(-0.11, 0.26, 0), 2.0, "pants"],
	"shin_r":   ["capsule", Vector2(0.08, 0.50), Vector3(0.11, 0.26, 0), 2.0, "pants"],
}

var parts: Dictionary = {}        # name -> RigidBody3D
var joints: Array[Joint3D] = []
var pelvis: RigidBody3D
var torso: RigidBody3D
var head: RigidBody3D
var colors := {"skin": Color(1.0, 0.8, 0.65), "shirt": Color(0.95, 0.75, 0.2), "pants": Color(0.25, 0.35, 0.75)}
var _prev_vel: Dictionary = {}
var _prop_spin: Node3D = null


func build(feet_pos: Vector3, outfit_id := "outfit_default", hat_id := "hat_none") -> void:
	var outfit: Dictionary = Progression.ITEMS.get(outfit_id, Progression.ITEMS["outfit_default"])
	var shirt: Color = outfit.get("color", colors["shirt"])
	colors["shirt"] = shirt
	colors["pants"] = Color.from_hsv(fposmod(shirt.h + 0.55, 1.0), 0.55, 0.65)
	for part_name in SPEC:
		_add_part(part_name, feet_pos)
	pelvis = parts["pelvis"]
	torso = parts["torso"]
	head = parts["head"]
	_build_joints(feet_pos)
	_decorate_head()
	_add_hands_and_feet()
	set_hat(hat_id)


func _add_part(part_name: String, feet_pos: Vector3) -> void:
	var s: Array = SPEC[part_name]
	var body := RigidBody3D.new()
	body.name = part_name
	body.mass = s[3]
	body.collision_layer = LAYER_PLAYER
	body.collision_mask = LAYER_WORLD | LAYER_PROP
	body.contact_monitor = true
	body.max_contacts_reported = 6
	body.can_sleep = false
	body.continuous_cd = true
	body.linear_damp = 0.05
	body.angular_damp = 1.2
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.05
	body.physics_material_override = pm
	add_child(body)
	body.global_position = feet_pos + (s[2] as Vector3)

	var shape: Shape3D
	var mesh: Mesh
	match s[0]:
		"box":
			var sz: Vector3 = s[1]
			var bs := BoxShape3D.new()
			bs.size = sz
			shape = bs
			var bm := BoxMesh.new()
			bm.size = sz
			mesh = bm
		"sphere":
			var ss := SphereShape3D.new()
			ss.radius = s[1]
			shape = ss
			var sm := SphereMesh.new()
			sm.radius = s[1]
			sm.height = s[1] * 2.0
			mesh = sm
		_:
			var d: Vector2 = s[1]
			var cs := CapsuleShape3D.new()
			cs.radius = d.x
			cs.height = d.y
			shape = cs
			var cm := CapsuleMesh.new()
			cm.radius = d.x
			cm.height = d.y
			mesh = cm
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colors[s[4]]
	mat.roughness = 0.7
	mi.material_override = mat
	body.add_child(mi)
	body.body_entered.connect(_on_part_body_entered.bind(body))
	parts[part_name] = body
	_prev_vel[body] = Vector3.ZERO


func _build_joints(feet: Vector3) -> void:
	var down := Basis(Vector3.BACK, -PI / 2.0)   # joint +X axis points down the limb
	var up := Basis(Vector3.BACK, PI / 2.0)      # joint +X axis points up
	var hinge_x := Basis(Vector3.UP, PI / 2.0)   # hinge axis (joint Z) = world X (bends forward/back)
	_cone("spine", pelvis, torso, feet + Vector3(0, 1.24, 0), up, 28.0, 22.0)
	_cone("neck", torso, head, feet + Vector3(0, 1.64, 0), up, 40.0, 40.0)
	_cone("shoulder_l", torso, parts["upper_arm_l"], feet + Vector3(-0.25, 1.6, 0), down, 95.0, 35.0)
	_cone("shoulder_r", torso, parts["upper_arm_r"], feet + Vector3(0.25, 1.6, 0), down, 95.0, 35.0)
	_hinge("elbow_l", parts["upper_arm_l"], parts["forearm_l"], feet + Vector3(-0.30, 1.32, 0), hinge_x, 0.0, 2.3)
	_hinge("elbow_r", parts["upper_arm_r"], parts["forearm_r"], feet + Vector3(0.30, 1.32, 0), hinge_x, 0.0, 2.3)
	_cone("hip_l", pelvis, parts["thigh_l"], feet + Vector3(-0.11, 1.0, 0), down, 70.0, 15.0)
	_cone("hip_r", pelvis, parts["thigh_r"], feet + Vector3(0.11, 1.0, 0), down, 70.0, 15.0)
	_hinge("knee_l", parts["thigh_l"], parts["shin_l"], feet + Vector3(-0.11, 0.51, 0), hinge_x, 0.0, 2.2)
	_hinge("knee_r", parts["thigh_r"], parts["shin_r"], feet + Vector3(0.11, 0.51, 0), hinge_x, 0.0, 2.2)


func _cone(jname: String, a: RigidBody3D, b: RigidBody3D, anchor: Vector3, basis: Basis, swing_deg: float, twist_deg: float) -> void:
	var j := ConeTwistJoint3D.new()
	j.name = jname
	add_child(j)
	j.global_transform = Transform3D(basis, anchor)
	j.node_a = a.get_path()
	j.node_b = b.get_path()
	j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(swing_deg))
	j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(twist_deg))
	joints.append(j)


func _hinge(jname: String, a: RigidBody3D, b: RigidBody3D, anchor: Vector3, basis: Basis, lower: float, upper: float) -> void:
	var j := HingeJoint3D.new()
	j.name = jname
	add_child(j)
	j.global_transform = Transform3D(basis, anchor)
	j.node_a = a.get_path()
	j.node_b = b.get_path()
	j.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	j.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, lower)
	j.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, upper)
	joints.append(j)


# ------------------------------------------------------------------ visuals

func _decorate_head() -> void:
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.045
		em.height = 0.09
		eye.mesh = em
		eye.position = Vector3(0.065 * sx, 0.03, -0.14)
		eye.material_override = _flat(Color.WHITE)
		head.add_child(eye)
		var pupil := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 0.022
		pm.height = 0.044
		pupil.mesh = pm
		pupil.position = Vector3(0.065 * sx, 0.03, -0.18)
		pupil.material_override = _flat(Color.BLACK)
		head.add_child(pupil)
	var mouth := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.1, 0.03, 0.02)
	mouth.mesh = mm
	mouth.position = Vector3(0, -0.07, -0.16)
	mouth.material_override = _flat(Color(0.5, 0.1, 0.1))
	head.add_child(mouth)


func _add_hands_and_feet() -> void:
	for side in ["l", "r"]:
		var fa: RigidBody3D = parts["forearm_" + side]
		var hand := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.075
		hm.height = 0.15
		hand.mesh = hm
		hand.position = Vector3(0, -0.2, 0)
		hand.material_override = _flat(colors["skin"])
		fa.add_child(hand)
		var shin: RigidBody3D = parts["shin_" + side]
		var shoe := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.14, 0.09, 0.3)
		shoe.mesh = sm
		shoe.position = Vector3(0, -0.24, -0.06)
		shoe.material_override = _flat(Color(0.35, 0.2, 0.12))
		shin.add_child(shoe)


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


func set_hat(hat_id: String) -> void:
	for c in head.get_children():
		if c.is_in_group("hat"):
			c.queue_free()
	_prop_spin = null
	if hat_id == "hat_none":
		return
	var hat := Node3D.new()
	hat.add_to_group("hat")
	head.add_child(hat)
	hat.position = Vector3(0, 0.15, 0)
	match hat_id:
		"hat_cone": _mesh(hat, _cyl(0.0, 0.11, 0.26), Vector3(0, 0.12, 0), Color(1.0, 0.45, 0.1))
		"hat_tophat":
			_mesh(hat, _cyl(0.2, 0.2, 0.03), Vector3(0, 0.01, 0), Color(0.1, 0.1, 0.12))
			_mesh(hat, _cyl(0.12, 0.12, 0.26), Vector3(0, 0.15, 0), Color(0.1, 0.1, 0.12))
		"hat_party":
			_mesh(hat, _cyl(0.0, 0.1, 0.3), Vector3(0, 0.14, 0), Color(0.9, 0.2, 0.7))
			_mesh(hat, _ball(0.04), Vector3(0, 0.3, 0), Color(1.0, 0.9, 0.2))
		"hat_propeller":
			_mesh(hat, _cyl(0.15, 0.15, 0.06), Vector3(0, 0.02, 0), Color(0.2, 0.6, 1.0))
			_prop_spin = Node3D.new()
			hat.add_child(_prop_spin)
			_prop_spin.position = Vector3(0, 0.1, 0)
			_mesh(_prop_spin, _box(Vector3(0.32, 0.01, 0.05)), Vector3.ZERO, Color(1.0, 0.3, 0.3))
		"hat_chicken":
			_mesh(hat, _ball(0.2), Vector3(0, 0.02, 0), Color(1.0, 0.98, 0.9))
			_mesh(hat, _cyl(0.0, 0.05, 0.12), Vector3(0, 0.0, -0.2), Color(1.0, 0.6, 0.1))
			_mesh(hat, _box(Vector3(0.04, 0.1, 0.1)), Vector3(0, 0.2, 0), Color(0.9, 0.1, 0.1))
		"hat_crown":
			_mesh(hat, _cyl(0.14, 0.14, 0.1), Vector3(0, 0.05, 0), Color(1.0, 0.85, 0.2))
			for i in 5:
				var a := TAU * i / 5.0
				_mesh(hat, _cyl(0.0, 0.035, 0.1), Vector3(cos(a) * 0.12, 0.14, sin(a) * 0.12), Color(1.0, 0.85, 0.2))


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	return m


func _ball(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return m


func _box(sz: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = sz
	return m


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _flat(color)
	parent.add_child(mi)


func set_outfit(outfit_id: String) -> void:
	var outfit: Dictionary = Progression.ITEMS.get(outfit_id, Progression.ITEMS["outfit_default"])
	var shirt: Color = outfit.get("color", colors["shirt"])
	var pants := Color.from_hsv(fposmod(shirt.h + 0.55, 1.0), 0.55, 0.65)
	for part_name in SPEC:
		var slot: String = SPEC[part_name][4]
		if slot == "shirt" or slot == "pants":
			var mi := (parts[part_name] as RigidBody3D).get_child(1) as MeshInstance3D
			(mi.material_override as StandardMaterial3D).albedo_color = shirt if slot == "shirt" else pants


# ------------------------------------------------------------------ physics

func _physics_process(_delta: float) -> void:
	for p in parts.values():
		_prev_vel[p] = (p as RigidBody3D).linear_velocity
	if _prop_spin != null:
		_prop_spin.rotate_y(0.5 + minf(pelvis.linear_velocity.length() * 0.2, 1.5))


func _on_part_body_entered(other: Node, part: RigidBody3D) -> void:
	var v: Vector3 = _prev_vel.get(part, part.linear_velocity)
	if other is RigidBody3D:
		v -= (other as RigidBody3D).linear_velocity
	part_hit.emit(part, v.length(), other)


func all_parts() -> Array:
	return parts.values()


func total_mass() -> float:
	var m := 0.0
	for p in parts.values():
		m += (p as RigidBody3D).mass
	return m


func center_of_mass() -> Vector3:
	var c := Vector3.ZERO
	var m := 0.0
	for p in parts.values():
		var b := p as RigidBody3D
		c += b.global_position * b.mass
		m += b.mass
	return c / m


func hand_point(side: String) -> Vector3:
	var fa: RigidBody3D = parts["forearm_" + side]
	return fa.to_global(Vector3(0, -0.2, 0))


func clamp_velocities(max_lin: float, max_ang: float) -> void:
	for p in parts.values():
		var b := p as RigidBody3D
		if b.linear_velocity.length() > max_lin:
			b.linear_velocity = b.linear_velocity.normalized() * max_lin
		if b.angular_velocity.length() > max_ang:
			b.angular_velocity = b.angular_velocity.normalized() * max_ang


## Move the whole body (keeping its pose) so the feet are at `feet_pos`, zeroing velocity.
func teleport(feet_pos: Vector3, yaw := 0.0) -> void:
	var rot := Basis(Vector3.UP, yaw)
	for part_name in parts:
		var b: RigidBody3D = parts[part_name]
		var t := Transform3D(rot, feet_pos + rot * (SPEC[part_name][2] as Vector3))
		PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, t)
		PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
		PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
		_prev_vel[b] = Vector3.ZERO


func apply_to_all(impulse: Vector3) -> void:
	var tm := total_mass()
	for p in parts.values():
		var b := p as RigidBody3D
		b.apply_central_impulse(impulse * (b.mass / tm))
