class_name MovingPlatform
extends AnimatableBody3D
## Kinematic platform with several motion modes. Uses sync_to_physics so riders are carried.
## Modes: "slide" (A<->B), "tilt" (see-saw about an axis), "spin" (turntable), "bob" (vertical).

var mode := "slide"
var origin := Vector3.ZERO
var travel := Vector3(6, 0, 0)
var period := 4.0
var phase := 0.0
var tilt_axis := Vector3.RIGHT
var tilt_deg := 14.0
var spin_rate := 0.8
var _t := 0.0


func setup(pos: Vector3, size: Vector3, motion: String, mat_name := "wood", tint := Color.WHITE) -> void:
	mode = motion
	origin = pos
	position = pos
	sync_to_physics = true
	collision_layer = Ragdoll.LAYER_WORLD
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = SurfaceMaterials.visual(mat_name, tint)
	add_child(mi)
	SurfaceMaterials.apply(self, mat_name)


func configure_slide(delta_pos: Vector3, per := 4.0, ph := 0.0) -> MovingPlatform:
	travel = delta_pos
	period = per
	phase = ph
	return self


func configure_tilt(axis: Vector3, deg := 14.0, per := 4.0, ph := 0.0) -> MovingPlatform:
	tilt_axis = axis
	tilt_deg = deg
	period = per
	phase = ph
	return self


func configure_spin(rate := 0.8) -> MovingPlatform:
	spin_rate = rate
	return self


func _physics_process(delta: float) -> void:
	_t += delta
	match mode:
		"slide", "bob":
			var s := sin(TAU * _t / period + phase) * 0.5 + 0.5
			global_transform = Transform3D(Basis.IDENTITY, origin + travel * s)
		"tilt":
			var ang := deg_to_rad(tilt_deg) * sin(TAU * _t / period + phase)
			global_transform = Transform3D(Basis(tilt_axis.normalized(), ang), origin)
		"spin":
			global_transform = Transform3D(Basis(Vector3.UP, spin_rate * _t), origin)
