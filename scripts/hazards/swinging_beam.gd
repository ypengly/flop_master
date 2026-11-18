class_name SwingingBeam
extends AnimatableBody3D
## A heavy beam hanging from a pivot, swinging like a pendulum. Kinematic (sync_to_physics) so
## it shoves the ragdoll hard without being pushed around itself.

var pivot_pos := Vector3.ZERO
var length := 5.0
var amplitude_deg := 55.0
var period := 3.0
var phase := 0.0
var axis := Vector3.RIGHT      # swing axis (rotation about this axis)
var _t := 0.0


func setup(pivot: Vector3, beam_length := 5.0, size := Vector3(0.6, 0.6, 3.0), amp_deg := 55.0, per := 3.0, ph := 0.0, swing_axis := Vector3.RIGHT) -> void:
	pivot_pos = pivot
	length = beam_length
	amplitude_deg = amp_deg
	period = per
	phase = ph
	axis = swing_axis
	sync_to_physics = true
	collision_layer = Ragdoll.LAYER_WORLD
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = Vector3(0, -length, 0)
	add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = Vector3(0, -length, 0)
	mi.material_override = SurfaceMaterials.visual("metal", Color(1.0, 0.7, 0.2))
	add_child(mi)
	# chain / rod
	var rod := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.06
	cm.height = length
	rod.mesh = cm
	rod.position = Vector3(0, -length * 0.5, 0)
	rod.material_override = SurfaceMaterials.visual("metal", Color(0.6, 0.6, 0.6))
	add_child(rod)
	SurfaceMaterials.apply(self, "metal")
	position = pivot_pos


func _physics_process(delta: float) -> void:
	_t += delta
	var ang := deg_to_rad(amplitude_deg) * sin(TAU * (_t / period) + phase)
	transform = Transform3D(Basis(axis.normalized(), ang), pivot_pos)
