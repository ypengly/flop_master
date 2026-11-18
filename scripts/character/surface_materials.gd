class_name SurfaceMaterials
extends RefCounted
## Helpers that turn a material name (rubber/wood/metal/ice/soft/stone) from
## config/physics.json into a PhysicsMaterial + a matching visual material.

static func apply(body: CollisionObject3D, mat_name: String) -> void:
	var def: Dictionary = Config.material_def(mat_name)
	var pm := PhysicsMaterial.new()
	pm.friction = float(def.get("friction", 0.8))
	pm.bounce = float(def.get("bounce", 0.1))
	if body is StaticBody3D:
		(body as StaticBody3D).physics_material_override = pm
	elif body is RigidBody3D:
		(body as RigidBody3D).physics_material_override = pm
	body.set_meta("material", mat_name)


static func color_of(mat_name: String) -> Color:
	var c: Array = Config.material_def(mat_name).get("color", [0.5, 0.5, 0.5])
	return Color(c[0], c[1], c[2])


static func visual(mat_name: String, tint := Color(1, 1, 1)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color_of(mat_name) * tint
	m.roughness = 0.9
	match mat_name:
		"metal":
			m.metallic = 0.6
			m.roughness = 0.35
		"ice":
			m.roughness = 0.1
			m.metallic_specular = 1.0
			m.albedo_color.a = 0.9
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"rubber":
			m.roughness = 0.4
	return m


## Name of the surface under/around a collider (walks up to parents that carry meta).
static func of(node: Node) -> String:
	var n := node
	while n != null:
		if n.has_meta("material"):
			return String(n.get_meta("material"))
		n = n.get_parent()
	return "stone"
