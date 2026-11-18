class_name GrabHandler
extends Node
## Hands grab ledges and objects with pin joints. Holding drains stamina; the character
## can pull up onto a ledge by pressing Jump while hanging.

signal grabbed(target: Node)
signal released
signal pulled_up

var ragdoll: Ragdoll
var stamina := 4.0
var stamina_max := 4.0
var holding := false          # a pin joint exists
var _joints: Dictionary = {}  # side -> PinJoint3D
var _targets: Dictionary = {}
var _retry := 0.0
var _pull_cd := 0.0
var _vault_push := Vector3.ZERO   # horizontal velocity to apply once we have risen above the lip
var _vault_target_y := 0.0
var _vault_timer := 0.0
var _no_grab := 0.0           # after a mantle, hands ignore surfaces briefly so we are not pulled back


func setup(r: Ragdoll) -> void:
	ragdoll = r
	stamina_max = float(Config.get_value("character", "stamina_max", 4.0))
	stamina = stamina_max


func _own_rids() -> Array[RID]:
	var out: Array[RID] = []
	for p in ragdoll.all_parts():
		out.append((p as RigidBody3D).get_rid())
	return out


## Called every physics frame. `want_grab` = grab action held.
func update(delta: float, want_grab: bool, want_pull: bool) -> void:
	var drain := float(Config.get_value("character", "grab_drain", 1.0))
	var regen := float(Config.get_value("character", "stamina_regen", 1.5))
	_pull_cd = maxf(0.0, _pull_cd - delta)
	_no_grab = maxf(0.0, _no_grab - delta)
	_update_vault(delta)
	if want_grab and stamina > 0.0:
		_retry -= delta
		if _joints.size() < 2 and _retry <= 0.0 and _no_grab <= 0.0:
			_retry = 0.12
			_try_grab()
		if holding:
			stamina = maxf(0.0, stamina - drain * delta)
			if want_pull and _pull_cd <= 0.0:
				_pull_up()
			if stamina <= 0.0:
				release()
	else:
		if holding:
			release()
		stamina = minf(stamina_max, stamina + regen * delta)


func _try_grab() -> void:
	var space := ragdoll.get_world_3d().direct_space_state
	var radius := float(Config.get_value("character", "grab_range", 0.9)) * 0.5
	for side in ["l", "r"]:
		if _joints.has(side):
			continue
		var point := ragdoll.hand_point(side)
		var q := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		q.shape = sphere
		q.transform = Transform3D(Basis.IDENTITY, point)
		q.collision_mask = Ragdoll.LAYER_WORLD | Ragdoll.LAYER_PROP
		q.exclude = _own_rids()
		var hits := space.intersect_shape(q, 4)
		if hits.is_empty():
			continue
		var collider = hits[0]["collider"]
		if not (collider is PhysicsBody3D):
			continue
		_attach(side, point, collider)


func _attach(side: String, point: Vector3, target: PhysicsBody3D) -> void:
	var j := PinJoint3D.new()
	ragdoll.add_child(j)
	j.global_position = point
	j.node_a = ragdoll.parts["forearm_" + side].get_path()
	j.node_b = target.get_path()
	_joints[side] = j
	_targets[side] = target
	holding = true
	AudioManager.play("grab", 0.8)
	grabbed.emit(target)


func release() -> void:
	for j in _joints.values():
		if is_instance_valid(j):
			# free() (not queue_free) so the constraint is gone before the next physics step
			(j as Node).get_parent().remove_child(j)
			(j as Node).free()
	_joints.clear()
	_targets.clear()
	if holding:
		holding = false
		released.emit()


func is_hanging_on_static() -> bool:
	for t in _targets.values():
		if is_instance_valid(t) and not (t is RigidBody3D):
			return true
	return false


## Mantle: find the top edge of the surface being held and vault over it. If there is no
## ledge in reach (a tall wall) it just hops, which lets the player shimmy up in several tries.
func _pull_up() -> void:
	_pull_cd = 0.5
	stamina = maxf(0.0, stamina - 0.8)
	var fwd := _toward_held_surface()
	var pelvis_y := ragdoll.pelvis.global_position.y
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 24.0))
	var vy := 6.5
	var vf := 2.2
	var top := _find_ledge_top(fwd)
	var push := fwd * vf
	if top > -1000.0:
		var rise := top - pelvis_y + 1.1      # carry the pelvis to ~1.1m above the ledge
		vy = clampf(sqrt(2.0 * gravity * maxf(rise + 0.2, 0.5)), 4.0, 14.0)
		vf = 3.6
		_no_grab = 0.9
		release()                              # let go so the hands do not drag us back
		# Phase 1: go straight up (a forward push now would just ram the wall under the lip).
		# Phase 2 (see _update_vault): once the pelvis clears the lip, push forward onto it.
		_vault_push = fwd * vf
		_vault_target_y = top + 0.15
		_vault_timer = 0.8
		push = Vector3.ZERO
	for p in ragdoll.all_parts():
		(p as RigidBody3D).linear_velocity = push + Vector3.UP * vy
	AudioManager.play("grunt", 0.7)
	ScoreManager.register_stunt("ledge pull-up")
	pulled_up.emit()


func _update_vault(delta: float) -> void:
	if _vault_push == Vector3.ZERO:
		return
	_vault_timer -= delta
	if ragdoll.pelvis.global_position.y >= _vault_target_y or _vault_timer <= 0.0:
		for p in ragdoll.all_parts():
			var b := p as RigidBody3D
			b.linear_velocity = Vector3(_vault_push.x, maxf(b.linear_velocity.y, 1.0), _vault_push.z)
		_vault_push = Vector3.ZERO


## Horizontal direction from the torso toward the wall being held: the opposite of the nearest
## near-vertical surface normal found with a ring of rays. Falls back to the hands, then facing.
func _toward_held_surface() -> Vector3:
	var space := ragdoll.get_world_3d().direct_space_state
	var origin := ragdoll.torso.global_position
	var exclude := _own_rids()
	var best_d := 1e9
	var best := Vector3.ZERO
	for i in 12:
		var dir := Vector3(sin(TAU * i / 12.0), 0.0, cos(TAU * i / 12.0))
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 1.3, Ragdoll.LAYER_WORLD | Ragdoll.LAYER_PROP)
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var n: Vector3 = hit["normal"]
		if absf(n.y) > 0.4:
			continue
		var d := origin.distance_to(hit["position"])
		if d < best_d:
			best_d = d
			best = Vector3(-n.x, 0.0, -n.z)
	if best.length() > 0.01:
		return best.normalized()
	var c := Vector3.ZERO
	var cnt := 0
	for j in _joints.values():
		if is_instance_valid(j):
			c += (j as Node3D).global_position
			cnt += 1
	var d2 := Vector3.ZERO
	if cnt > 0:
		d2 = c / cnt - origin
	d2.y = 0.0
	if d2.length() < 0.05:
		d2 = -ragdoll.torso.global_basis.z
		d2.y = 0.0
	return d2.normalized() if d2.length() > 0.01 else Vector3.FORWARD


## Height of the walkable top surface just in front of the torso, or -10000 if none.
func _find_ledge_top(fwd: Vector3) -> float:
	var space := ragdoll.get_world_3d().direct_space_state
	var exclude := _own_rids()
	var best := -10000.0
	for reach: float in [0.75, 1.05]:
		var o: Vector3 = ragdoll.torso.global_position + fwd * reach + Vector3.UP * 3.2
		var q := PhysicsRayQueryParameters3D.create(o, o + Vector3.DOWN * 4.0, Ragdoll.LAYER_WORLD | Ragdoll.LAYER_PROP)
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and (hit["normal"] as Vector3).y > 0.7:
			var y: float = hit["position"].y
			if y > ragdoll.pelvis.global_position.y - 0.3 and y < ragdoll.pelvis.global_position.y + 2.4:
				best = maxf(best, y)
	return best
