extends Node
## Headless check: ragdoll dropped on a floor stays assembled, doesn't explode, settles.
## Run: godot --headless --path . res://tests/test_ragdoll_drop.tscn

var rd: Ragdoll
var frames := 0
var max_speed := 0.0


func _ready() -> void:
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(40, 1, 40)
	cs.shape = bs
	floor_body.add_child(cs)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child(floor_body)
	rd = Ragdoll.new()
	add_child(rd)
	rd.build(Vector3(0, 0.5, 0))
	print("engine: ", ProjectSettings.get_setting("physics/3d/physics_engine"))


func _physics_process(_delta: float) -> void:
	frames += 1
	for p in rd.all_parts():
		max_speed = maxf(max_speed, (p as RigidBody3D).linear_velocity.length())
	if frames == 360:
		var pel := rd.pelvis.global_position
		var head_y := rd.head.global_position.y
		var thigh_gap: float = rd.parts["thigh_l"].global_position.distance_to(pel)
		var shin_gap: float = rd.parts["shin_l"].global_position.distance_to(rd.parts["thigh_l"].global_position)
		print("pelvis=", pel, " head_y=", snappedf(head_y, 0.01), " thigh_gap=", snappedf(thigh_gap, 0.01), " shin_gap=", snappedf(shin_gap, 0.01), " max_speed=", snappedf(max_speed, 0.1))
		var bad := pel.y < 0.0 or pel.y > 3.0 or thigh_gap > 1.0 or shin_gap > 0.8 or max_speed > 40.0 or is_nan(pel.x)
		print("FAIL: ragdoll unstable" if bad else "PASS: ragdoll stable")
		get_tree().quit(1 if bad else 0)
