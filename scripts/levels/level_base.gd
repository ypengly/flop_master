class_name LevelBase
extends Node3D
## Base class for procedurally built levels. Subclasses override build() and use the helper
## methods (add_box, add_checkpoint, add_collectible, add_finish, add_crate, ...) so every level
## is a few lines of data. Emits signals the Gameplay node listens to.

signal checkpoint_reached(index: int, spawn: Vector3)
signal collectible_taken(total: int)
signal finish_reached
signal hazard_hit

var spawn_point := Vector3(0, 1.0, 0)
var spawn_yaw := 0.0
var kill_y := -40.0
var collectible_total := 0
var collectible_count := 0
var checkpoints: Array[Vector3] = []
var reached_checkpoint := -1
var finished := false
var finish_pos := Vector3.ZERO
var hint_text := ""
var sky_color := Color(0.55, 0.78, 0.95)


## Override in subclasses.
func build() -> void:
	pass


func setup() -> void:
	_add_environment()
	build()


func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 1.0)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = sky_color
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)


# ------------------------------------------------------------------ geometry

func _tint(mat_name: String, tint: Color) -> StandardMaterial3D:
	return SurfaceMaterials.visual(mat_name, tint)


## Static box. Returns the StaticBody3D.
func add_box(pos: Vector3, size: Vector3, mat_name := "stone", tint := Color.WHITE, rot_deg := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Ragdoll.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees = rot_deg
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _tint(mat_name, tint)
	body.add_child(mi)
	SurfaceMaterials.apply(body, mat_name)
	add_child(body)
	return body


## Platform helper: top surface at pos.y, thin slab.
func add_platform(pos: Vector3, size_xz: Vector2, mat_name := "stone", thickness := 0.6, tint := Color.WHITE) -> StaticBody3D:
	return add_box(pos - Vector3(0, thickness * 0.5, 0), Vector3(size_xz.x, thickness, size_xz.y), mat_name, tint)


func add_wall(pos: Vector3, size: Vector3, mat_name := "stone", tint := Color(0.9, 0.9, 1.0)) -> StaticBody3D:
	return add_box(pos + Vector3(0, size.y * 0.5, 0), size, mat_name, tint)


## Dynamic crate (knockable, scores when hit).
func add_crate(pos: Vector3, size := Vector3(0.8, 0.8, 0.8), mat_name := "wood", mass := 4.0) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.collision_layer = Ragdoll.LAYER_PROP
	rb.collision_mask = Ragdoll.LAYER_WORLD | Ragdoll.LAYER_PROP | Ragdoll.LAYER_PLAYER
	rb.mass = mass
	rb.position = pos
	rb.continuous_cd = true
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _tint(mat_name, Color(1.1, 1.0, 0.9))
	rb.add_child(mi)
	SurfaceMaterials.apply(rb, mat_name)
	rb.set_meta("knockable", true)
	add_child(rb)
	return rb


func add_ball(pos: Vector3, radius := 0.5, mat_name := "rubber", mass := 3.0) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.collision_layer = Ragdoll.LAYER_PROP
	rb.collision_mask = Ragdoll.LAYER_WORLD | Ragdoll.LAYER_PROP | Ragdoll.LAYER_PLAYER
	rb.mass = mass
	rb.position = pos
	rb.continuous_cd = true
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = radius
	cs.shape = ss
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.material_override = _tint(mat_name, Color.WHITE)
	rb.add_child(mi)
	SurfaceMaterials.apply(rb, mat_name)
	rb.set_meta("knockable", true)
	add_child(rb)
	return rb


## Stack of crates forming a pyramid wall (knock them down for points).
func add_crate_stack(origin: Vector3, cols: int, rows: int, size := 0.8) -> void:
	for r in rows:
		for c in cols - r:
			var x := origin.x + (c + r * 0.5 - (cols - 1) * 0.5) * (size + 0.02)
			add_crate(Vector3(x, origin.y + size * 0.5 + r * (size + 0.01), origin.z), Vector3(size, size, size))


# ------------------------------------------------------------------ triggers

func _add_area(pos: Vector3, size: Vector3, callback: Callable, color := Color(1, 1, 1, 0.25), visible_box := true) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = Ragdoll.LAYER_SENSOR
	a.collision_mask = Ragdoll.LAYER_PLAYER
	a.position = pos
	a.monitoring = true
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	a.add_child(cs)
	if visible_box:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		a.add_child(mi)
	a.body_entered.connect(callback)
	add_child(a)
	return a


func _is_player(body: Node) -> bool:
	return body.get_parent() is Ragdoll


func add_checkpoint(pos: Vector3) -> void:
	var idx := checkpoints.size()
	checkpoints.append(pos)
	var flag := Node3D.new()
	flag.position = pos
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.05
	pm.bottom_radius = 0.05
	pm.height = 2.4
	pole.mesh = pm
	pole.position.y = 1.2
	pole.material_override = _tint("metal", Color.WHITE)
	flag.add_child(pole)
	var cloth := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.9, 0.5, 0.04)
	cloth.mesh = cm
	cloth.position = Vector3(0.45, 2.1, 0)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(1.0, 0.3, 0.3)
	cloth.material_override = cmat
	flag.add_child(cloth)
	add_child(flag)
	var area_cb := func(body: Node) -> void:
		if not _is_player(body) or idx <= reached_checkpoint:
			return
		reached_checkpoint = idx
		cmat.albedo_color = Color(0.3, 1.0, 0.4)
		checkpoint_reached.emit(idx, pos)
	_add_area(pos + Vector3(0, 1.2, 0), Vector3(3.0, 2.6, 3.0), area_cb, Color(0.3, 1.0, 0.4, 0.08), true)


func add_collectible(pos: Vector3) -> void:
	collectible_total += 1
	var a := Area3D.new()
	a.collision_layer = Ragdoll.LAYER_SENSOR
	a.collision_mask = Ragdoll.LAYER_PLAYER
	a.position = pos
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = 0.55
	cs.shape = ss
	a.add_child(cs)
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.18
	tm.outer_radius = 0.34
	mi.mesh = tm
	mi.rotation_degrees = Vector3(90, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.1)
	mat.emission_energy_multiplier = 0.8
	mi.material_override = mat
	a.add_child(mi)
	a.set_meta("spin", mi)
	add_child(a)
	a.body_entered.connect(func(body: Node) -> void:
		if not _is_player(body) or not is_instance_valid(a):
			return
		collectible_count += 1
		AudioManager.play("pickup", 0.9)
		ScoreManager.register_collectible()
		collectible_taken.emit(collectible_count)
		a.queue_free())


func add_finish(pos: Vector3, size := Vector3(4, 0.3, 4)) -> void:
	finish_pos = pos
	var pad := add_box(pos - Vector3(0, 0.15, 0), size, "soft", Color(0.4, 1.0, 0.5))
	# checkered arch
	for sx in [-1, 1]:
		var post := add_box(pos + Vector3(sx * (size.x * 0.5 - 0.2), 1.5, 0), Vector3(0.3, 3.0, 0.3), "metal", Color(1, 1, 0.5))
		post.collision_layer = 0
	var top := add_box(pos + Vector3(0, 3.1, 0), Vector3(size.x, 0.4, 0.3), "metal", Color(1, 0.9, 0.3))
	top.collision_layer = 0
	var cb := func(body: Node) -> void:
		if _is_player(body) and not finished:
			finished = true
			finish_reached.emit()
	_add_area(pos + Vector3(0, 1.5, 0), Vector3(size.x - 0.4, 3.0, size.z - 0.4), cb, Color(0.4, 1.0, 0.5, 0.12), true)


## Invisible-ish danger zone (lava, acid...). Respawns the player at last checkpoint.
func add_hazard_zone(pos: Vector3, size: Vector3, color := Color(1.0, 0.3, 0.1, 0.45)) -> void:
	var cb := func(body: Node) -> void:
		if _is_player(body):
			hazard_hit.emit()
	_add_area(pos, size, cb, color, true)


## Pendulum beam. `pivot` is the world-space pivot; by default swings side to side (about Z).
func add_beam(pivot: Vector3, length := 8.0, amp_deg := 50.0, per := 3.0, ph := 0.0, size := Vector3(4.5, 0.6, 0.6), axis := Vector3(0, 0, 1)) -> SwingingBeam:
	var b := SwingingBeam.new()
	add_child(b)
	b.setup(pivot, length, size, amp_deg, per, ph, axis)
	return b


func add_fan(pos: Vector3, radius := 3.0, reach := 14.0, power := 38.0, dir := Vector3.UP, pulse_period := 0.0, flow_radius := 0.0) -> FanUpdraft:
	var f := FanUpdraft.new()
	add_child(f)
	f.setup(pos, radius, reach, power, dir, pulse_period, flow_radius)
	return f


## Moving platform; `top_pos` is the centre of the top surface at rest.
func add_mover(top_pos: Vector3, size_xz: Vector2, mode: String, mat_name := "wood", thickness := 0.6, tint := Color.WHITE) -> MovingPlatform:
	var m := MovingPlatform.new()
	add_child(m)
	m.setup(top_pos - Vector3(0, thickness * 0.5, 0), Vector3(size_xz.x, thickness, size_xz.y), mode, mat_name, tint)
	return m


func add_dropper(pos: Vector3, per := 2.5, area := Vector3(3, 0, 3)) -> CrateDropper:
	var d := CrateDropper.new()
	add_child(d)
	d.setup(self, pos, per, area)
	return d


## Spring pad: sets the velocity of every ragdoll part to `velocity` when stepped on.
func add_launch_pad(pos: Vector3, size_xz: Vector2, velocity: Vector3) -> void:
	var pad := add_platform(pos, size_xz, "rubber", 0.5, Color(1.0, 0.5, 0.8))
	# Looks like rubber, but must not grip: friction would brake the launch as the feet leave.
	var slick := PhysicsMaterial.new()
	slick.friction = 0.02
	slick.bounce = 0.0
	pad.physics_material_override = slick
	var arrow := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = minf(size_xz.x, size_xz.y) * 0.3
	cm.height = 0.9
	arrow.mesh = cm
	arrow.position = pos + Vector3(0, 0.55, 0)
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(1.0, 0.95, 0.2)
	am.emission_enabled = true
	am.emission = Color(1.0, 0.9, 0.1)
	arrow.material_override = am
	add_child(arrow)
	var last_fire := [-10.0]
	var cb := func(body: Node) -> void:
		var rd := body.get_parent() as Ragdoll
		if rd == null:
			return
		var now := Time.get_ticks_msec() / 1000.0
		if now - last_fire[0] < 0.8:
			return
		last_fire[0] = now
		for p in rd.all_parts():
			(p as RigidBody3D).linear_velocity = velocity
		AudioManager.play("boing", 1.0, 1.0)
		ScoreManager.register_stunt("launch pad")
	_add_area(pos + Vector3(0, 0.6, 0), Vector3(size_xz.x, 1.0, size_xz.y), cb, Color(1, 1, 0.3, 0.12), true)


func add_sign(pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = 48
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 12
	l.modulate = Color(1, 1, 1)
	l.outline_modulate = Color(0.1, 0.1, 0.2)
	add_child(l)


func _process(delta: float) -> void:
	for c in get_children():
		if c is Area3D and c.has_meta("spin"):
			(c.get_meta("spin") as Node3D).rotate_z(delta * 2.5)
