class_name CharacterController
extends Node
## Drives the Ragdoll. A "balance" value (0 = limp, 1 = fully controlled) blends between
## player-controlled upright movement and pure physical reaction. Big impacts knock balance
## to zero (stun); balance then ramps back up during the get-up phase.

signal state_changed(new_state: int)
signal hard_impact(speed: float, material: String)
signal jumped
signal dove
signal fell_out
signal rescued

enum State { STANDING, AIRBORNE, RAGDOLL, GETTING_UP }

var ragdoll: Ragdoll
var grab: GrabHandler
var guard: StuckGuard
var camera_yaw := 0.0            # set by the camera each frame
var state: int = State.RAGDOLL
var balance := 0.0
var grounded := false
var ground_point := Vector3.ZERO
var ground_dist := 99.0
var input_enabled := true
var kill_y := -40.0

var _stun_timer := 0.0
var _air_time := 0.0
var _coyote := 0.0
var _ragdoll_time := 0.0
var _walk_phase := 0.0
var _last_heading := 0.0
var _heading := 0.0
var _dive_cd := 0.0
var _push_cd := 0.0
var _jump_cd := 0.0
var _getup_t := 0.0
var _last_impact_msec := 0
var _p: Dictionary = {}


func setup(r: Ragdoll, start_feet: Vector3) -> void:
	ragdoll = r
	_p = Config.section("character")
	grab = GrabHandler.new()
	add_child(grab)
	grab.setup(r)
	guard = StuckGuard.new()
	add_child(guard)
	guard.setup(r, start_feet)
	guard.rescue_needed.connect(_on_rescue_needed)
	ragdoll.part_hit.connect(_on_part_hit)
	_set_state(State.GETTING_UP)
	_getup_t = 0.0


func _f(key: String, default: float) -> float:
	return float(_p.get(key, default))


# ------------------------------------------------------------------ queries

func is_airborne() -> bool:
	return state == State.AIRBORNE or (not grounded and _air_time > 0.12)


func is_limp() -> bool:
	return state == State.RAGDOLL


func facing_dir() -> Vector3:
	var f := -ragdoll.torso.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


func speed() -> float:
	return ragdoll.pelvis.linear_velocity.length()


func stamina_ratio() -> float:
	return grab.stamina / maxf(grab.stamina_max, 0.01)


# ------------------------------------------------------------------ main loop

func physics_update(delta: float) -> void:
	if ragdoll == null:
		return
	_dive_cd = maxf(0.0, _dive_cd - delta)
	_push_cd = maxf(0.0, _push_cd - delta)
	_jump_cd = maxf(0.0, _jump_cd - delta)
	_probe_ground()
	if grounded:
		_air_time = 0.0
		_coyote = 0.12
	else:
		_air_time += delta
		_coyote = maxf(0.0, _coyote - delta)

	var move := Vector2.ZERO
	var wants_grab := false
	var wants_run := false
	if input_enabled:
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		wants_grab = Input.is_action_pressed("grab")
		wants_run = Input.is_action_pressed("run")
		if Input.is_action_just_pressed("jump"):
			_try_jump()
		if Input.is_action_just_pressed("dive"):
			_try_dive(move)
		if Input.is_action_just_pressed("push"):
			_try_push()
		if Input.is_action_just_pressed("recover") and state == State.RAGDOLL:
			_begin_getup()
	grab.update(delta, wants_grab and input_enabled, Input.is_action_just_pressed("jump") and input_enabled)

	_update_state(delta, move)
	_apply_balance(delta, move, wants_run)
	ragdoll.clamp_velocities(_f("max_linear_speed", 32.0), _f("max_angular_speed", 18.0))

	var airborne := is_airborne() and not grab.holding
	ScoreManager.update_motion(ragdoll.torso.global_position, ragdoll.torso.angular_velocity, airborne, delta)
	var upright_ok := state == State.STANDING and grounded and ragdoll.pelvis.linear_velocity.length() < 6.0
	var immobile := state == State.RAGDOLL or state == State.GETTING_UP
	guard.update(delta, upright_ok, ground_point, immobile)

	if ragdoll.pelvis.global_position.y < kill_y:
		fell_out.emit()


func _probe_ground() -> void:
	var space := ragdoll.get_world_3d().direct_space_state
	var origin := ragdoll.pelvis.global_position
	var q := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * (_f("stand_height", 1.05) + 0.35), Ragdoll.LAYER_WORLD | Ragdoll.LAYER_PROP)
	var exclude: Array[RID] = []
	for p in ragdoll.all_parts():
		exclude.append((p as RigidBody3D).get_rid())
	q.exclude = exclude
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		grounded = false
		ground_dist = 99.0
		return
	ground_point = hit["position"]
	ground_dist = origin.y - ground_point.y
	var n: Vector3 = hit["normal"]
	grounded = n.y > 0.5 and ground_dist < _f("stand_height", 1.05) + 0.25


func _update_state(delta: float, move: Vector2) -> void:
	var tilt := rad_to_deg(acos(clampf(ragdoll.torso.global_basis.y.dot(Vector3.UP), -1.0, 1.0)))
	match state:
		State.STANDING, State.AIRBORNE:
			_stun_timer = maxf(0.0, _stun_timer - delta)
			if _stun_timer > 0.0 or tilt > 75.0:
				_set_state(State.RAGDOLL)
			elif not grounded and _air_time > 0.12:
				if state != State.AIRBORNE:
					_set_state(State.AIRBORNE)
			elif state == State.AIRBORNE and grounded:
				_set_state(State.STANDING)
		State.RAGDOLL:
			_ragdoll_time += delta
			_stun_timer = maxf(0.0, _stun_timer - delta)
			var calm := ragdoll.pelvis.linear_velocity.length() < 2.5 and ragdoll.torso.angular_velocity.length() < 3.0
			var auto := _ragdoll_time > _f("get_up_time", 1.2) + 1.0 and calm and grounded
			if _stun_timer <= 0.0 and ((auto and move.length() > 0.1) or auto):
				_begin_getup()
		State.GETTING_UP:
			_getup_t += delta
			# Start fairly strong (0.45) so the body can rotate upright, then ease to full control.
			var t := clampf(_getup_t / _f("get_up_time", 1.2), 0.0, 1.0)
			balance = 0.45 + 0.55 * t * t * (3.0 - 2.0 * t)
			if tilt > 125.0 and _getup_t > 0.5:
				_set_state(State.RAGDOLL)   # failed, try again
			elif t >= 1.0 and tilt < 50.0:
				_set_state(State.STANDING if grounded else State.AIRBORNE)


func _set_state(s: int) -> void:
	if state == s:
		return
	state = s
	if s == State.RAGDOLL:
		_ragdoll_time = 0.0
		grab.release()
	if s == State.STANDING or s == State.AIRBORNE:
		balance = 1.0
	state_changed.emit(s)


func _begin_getup() -> void:
	_getup_t = 0.0
	balance = 0.0
	_stun_timer = 0.0
	_set_state(State.GETTING_UP)


# ------------------------------------------------------------------ balance & motion

func _apply_balance(delta: float, move: Vector2, wants_run: bool) -> void:
	var b := 0.0
	match state:
		State.STANDING: b = 1.0
		State.AIRBORNE: b = 0.35
		State.GETTING_UP: b = balance
		State.RAGDOLL: b = 0.0
	if grab.holding:
		b = maxf(minf(b, 0.8), 0.6) if b > 0.0 else 0.0
		if grab.is_hanging_on_static():
			# Arms take most of the body weight while hanging from a ledge.
			var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 24.0))
			var hold_f := Vector3.UP * g * ragdoll.total_mass() * 0.85
			ragdoll.pelvis.apply_central_force(hold_f * 0.5)
			ragdoll.torso.apply_central_force(hold_f * 0.5)
			# Stop the body spinning around its hands while hanging.
			for rb in [ragdoll.torso, ragdoll.pelvis]:
				(rb as RigidBody3D).apply_torque(-(rb as RigidBody3D).angular_velocity * 10.0)
	if b <= 0.01:
		return

	var pelvis := ragdoll.pelvis
	var torso := ragdoll.torso
	var head := ragdoll.head

	# Stay upright: torque torso and pelvis toward world up, head follows torso.
	var k := _f("upright_torque", 120.0) * b
	var damp := _f("upright_damping", 14.0)
	for body in [torso, pelvis]:
		var rb := body as RigidBody3D
		var axis := rb.global_basis.y.cross(Vector3.UP)
		rb.apply_torque(axis * k - rb.angular_velocity * damp * b)
	var haxis := head.global_basis.y.cross(Vector3.UP)
	head.apply_torque(haxis * k * 0.15 - head.angular_velocity * damp * 0.05)

	# Height spring (only while a ground contact is near) keeps the body "standing" on floppy legs.
	if grounded and state != State.AIRBORNE:
		# Spring in acceleration units (m/s^2) so it scales with the body's total mass.
		var target := _f("stand_height", 1.05)
		var err := target - ground_dist
		var accel_up := err * _f("stand_spring", 140.0) - pelvis.linear_velocity.y * _f("stand_damping", 16.0)
		accel_up = clampf(accel_up, -20.0, 60.0) * b
		var f_up := accel_up * ragdoll.total_mass()
		pelvis.apply_central_force(Vector3.UP * f_up * 0.7)
		torso.apply_central_force(Vector3.UP * f_up * 0.3)
		# Straighten the legs when standing: thighs/shins toward vertical
		for side in ["l", "r"]:
			for leg in ["thigh_", "shin_"]:
				var rb: RigidBody3D = ragdoll.parts[leg + side]
				var ax := rb.global_basis.y.cross(Vector3.UP)
				rb.apply_torque(ax * 40.0 * b - rb.angular_velocity * 2.0 * b)

	# Move relative to camera.
	var dir := Vector3.ZERO
	if move.length() > 0.1:
		dir = Vector3(move.x, 0.0, move.y).rotated(Vector3.UP, camera_yaw).normalized() * minf(move.length(), 1.0)
	if dir.length() > 0.05:
		var target_speed := _f("run_speed", 5.6) if wants_run else _f("walk_speed", 3.2)
		var control := b * (1.0 if grounded else _f("air_control", 0.35))
		var hv := Vector3(pelvis.linear_velocity.x, 0.0, pelvis.linear_velocity.z)
		var want := dir * target_speed
		# move_force is the maximum horizontal acceleration in m/s^2.
		var accel := ((want - hv) * 8.0).limit_length(_f("move_force", 30.0)) * control
		var f_move := accel * ragdoll.total_mass()
		pelvis.apply_central_force(f_move * 0.6)
		torso.apply_central_force(f_move * 0.4)
		# Face the direction of travel.
		_heading = atan2(-dir.x, -dir.z)
		_turn_toward(_heading, b)
		_animate_legs(delta, hv.length(), b)

	# Stumble: at high speed or when slipping on ice, trip a bit by weakening balance.
	if grounded and state == State.STANDING:
		var hv2 := Vector2(pelvis.linear_velocity.x, pelvis.linear_velocity.z).length()
		if hv2 > _f("run_speed", 5.6) * 1.9:
			_stun_timer = maxf(_stun_timer, 0.8)   # too fast to keep your feet


func _turn_toward(heading: float, b: float) -> void:
	var cur_f := facing_dir()
	var cur := atan2(-cur_f.x, -cur_f.z)
	var diff := wrapf(heading - cur, -PI, PI)
	var t := clampf(diff * _f("turn_torque", 60.0), -90.0, 90.0) * b
	for body in [ragdoll.torso, ragdoll.pelvis]:
		var rb := body as RigidBody3D
		rb.apply_torque(Vector3.UP * t - Vector3.UP * rb.angular_velocity.y * 6.0 * b)


func _animate_legs(delta: float, hspeed: float, b: float) -> void:
	_walk_phase += delta * (4.0 + hspeed * 1.6)
	var amp := clampf(hspeed / 4.0, 0.2, 1.0) * 28.0 * b
	var right := ragdoll.torso.global_basis.x
	var s := sin(_walk_phase)
	(ragdoll.parts["thigh_l"] as RigidBody3D).apply_torque(right * s * amp)
	(ragdoll.parts["thigh_r"] as RigidBody3D).apply_torque(-right * s * amp)
	(ragdoll.parts["upper_arm_l"] as RigidBody3D).apply_torque(-right * s * amp * 0.4)
	(ragdoll.parts["upper_arm_r"] as RigidBody3D).apply_torque(right * s * amp * 0.4)


# ------------------------------------------------------------------ actions

func _try_jump() -> void:
	if _jump_cd > 0.0 or state == State.RAGDOLL:
		return
	if grab.holding and grab.is_hanging_on_static():
		return  # pull-up handled in grab handler
	if _coyote <= 0.0 and not grab.holding:
		return
	_jump_cd = 0.35
	_coyote = 0.0
	grab.release()
	# jump_impulse is the vertical velocity change (m/s) given to every body part.
	ragdoll.apply_to_all(Vector3.UP * _f("jump_impulse", 7.5) * ragdoll.total_mass())
	AudioManager.play("jump", 0.8)
	jumped.emit()
	ScoreManager.register_stunt("jump")


func _try_dive(move: Vector2) -> void:
	if _dive_cd > 0.0:
		return
	_dive_cd = 1.0
	grab.release()
	var dir := facing_dir()
	if move.length() > 0.1:
		dir = Vector3(move.x, 0.0, move.y).rotated(Vector3.UP, camera_yaw).normalized()
	var imp := _f("dive_impulse", 8.5)
	var lift := _f("dive_lift", 2.5)
	ragdoll.apply_to_all((dir * imp + Vector3.UP * lift) * ragdoll.total_mass())
	# tip the torso forward into a superman pose
	var side := dir.cross(Vector3.UP)
	ragdoll.torso.apply_torque_impulse(side * -6.0)
	_stun_timer = 0.9
	_set_state(State.RAGDOLL)
	AudioManager.play("whoosh", 0.8)
	dove.emit()
	ScoreManager.register_stunt("dive")


func _try_push() -> void:
	if _push_cd > 0.0 or state == State.RAGDOLL:
		return
	_push_cd = 0.6
	var space := ragdoll.get_world_3d().direct_space_state
	var origin := ragdoll.torso.global_position
	var fwd := facing_dir()
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.7
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, origin + fwd * 0.9)
	q.collision_mask = Ragdoll.LAYER_PROP
	var hits := space.intersect_shape(q, 8)
	var imp := _f("push_impulse", 6.0)
	for h in hits:
		var c = h["collider"]
		if c is RigidBody3D:
			(c as RigidBody3D).apply_central_impulse((fwd * imp + Vector3.UP * 1.0) * maxf((c as RigidBody3D).mass, 1.0) * 0.6)
			ScoreManager.register_stunt("push")
	# arms swing forward
	var right := ragdoll.torso.global_basis.x
	(ragdoll.parts["upper_arm_l"] as RigidBody3D).apply_torque_impulse(right * -3.0)
	(ragdoll.parts["upper_arm_r"] as RigidBody3D).apply_torque_impulse(right * -3.0)
	ragdoll.torso.apply_central_impulse(fwd * 4.0)
	AudioManager.play("whoosh", 0.5, 1.3)


# ------------------------------------------------------------------ impacts

func _on_part_hit(part: RigidBody3D, impact_speed: float, other: Node) -> void:
	var mat := SurfaceMaterials.of(other)
	var now := Time.get_ticks_msec()
	if impact_speed > 4.0 and now - _last_impact_msec > 90:
		_last_impact_msec = now
		AudioManager.play_impact(impact_speed, mat)
		ScoreManager.register_impact(impact_speed, mat)
		hard_impact.emit(impact_speed, mat)
		var threshold := _f("stun_speed_threshold", 9.0)
		if impact_speed > threshold and state != State.RAGDOLL and part.name != "shin_l" and part.name != "shin_r":
			_stun_timer = maxf(_stun_timer, _f("stun_time", 1.4) * clampf(impact_speed / (threshold * 1.6), 0.5, 1.5))
			ScoreManager.register_stunt("big hit")
	if other is RigidBody3D and other.has_meta("knockable") and not bool(other.get_meta("knocked", false)) and impact_speed > 2.5:
		other.set_meta("knocked", true)
		ScoreManager.register_knock(1)


# ------------------------------------------------------------------ rescue / respawn

func _on_rescue_needed(safe_pos: Vector3) -> void:
	respawn_at(safe_pos, _heading)
	rescued.emit()


## Teleport the character (feet at `feet_pos`) and start the get-up sequence.
func respawn_at(feet_pos: Vector3, yaw := 0.0) -> void:
	grab.release()
	ragdoll.teleport(feet_pos, yaw)
	guard.reset(feet_pos)
	_stun_timer = 0.0
	_air_time = 0.0
	_ragdoll_time = 0.0
	balance = 0.0
	_getup_t = 0.0
	_heading = yaw
	state = State.GETTING_UP
	state_changed.emit(state)
