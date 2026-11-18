extends LevelBase
## Level 2: Slippery Rooftops. Narrow ice and wood platforms between buildings, with a launch
## pad for the big jump. Falling is the express elevator.


func build() -> void:
	hint_text = "Ice is slippery! Dive and rubber bounce help with the long gaps."
	kill_y = -50.0
	sky_color = Color(0.98, 0.78, 0.6)
	spawn_point = Vector3(0, 0.1, 0)
	var ice := Color(1, 1, 1)
	var roof := Color(0.7, 0.65, 0.7)

	# Start roof (z -6..6), ice strip (-6..-22), roof B (-22..-30)
	add_platform(Vector3(0, 0, 0), Vector2(10, 12), "stone", 1.0, roof)
	add_wall(Vector3(0, 0, 5.8), Vector3(10, 1.0, 0.4), "stone", Color(0.6, 0.55, 0.6))
	add_platform(Vector3(0, 0, -14), Vector2(4, 16), "ice", 1.0, ice)
	add_collectible(Vector3(0, 1.0, -12))
	add_platform(Vector3(0, 0, -26), Vector2(8, 8), "stone", 1.0, roof)
	add_checkpoint(Vector3(0, 0.05, -25))

	# Zig-zag narrow planks (wood)
	add_platform(Vector3(5, 0, -35), Vector2(3, 6), "wood", 0.5)
	add_platform(Vector3(-2, 0, -42), Vector2(3, 6), "wood", 0.5)
	add_platform(Vector3(5, 0, -49), Vector2(3, 6), "wood", 0.5)
	add_collectible(Vector3(5, 1.0, -49))
	add_platform(Vector3(0, 0, -58), Vector2(9, 8), "stone", 1.0, roof)
	add_checkpoint(Vector3(0, 0.05, -58))

	# Launch pad up to the high roof (6 m up, ~15 m across)
	add_launch_pad(Vector3(0, 0, -65), Vector2(4, 4), Vector3(0, 20.0, -19.5))
	add_platform(Vector3(0, 6, -85), Vector2(10, 14), "stone", 1.0, roof)
	add_collectible(Vector3(0, 8.5, -75))
	add_checkpoint(Vector3(0, 6.05, -84))

	# High ice tightrope (z -89 .. -107) then roof D (-108 .. -116)
	add_platform(Vector3(0, 6, -98), Vector2(1.8, 18), "ice", 0.5, ice)
	add_collectible(Vector3(0, 7, -98))
	add_platform(Vector3(0, 6, -112), Vector2(10, 8), "stone", 1.0, roof)
	add_checkpoint(Vector3(0, 6.05, -110))
	add_crate_stack(Vector3(0, 6, -114), 5, 4)

	# Final ice slide down to the finish
	add_box(Vector3(0, 3.8, -128), Vector3(8, 0.6, 18), "ice", ice, Vector3(-12, 0, 0))
	add_platform(Vector3(0, 2, -142), Vector2(12, 10), "soft", 1.0, Color(0.9, 0.8, 0.9))
	add_finish(Vector3(0, 2.0, -142))

	# Fast respawn if you fall between buildings
	add_hazard_zone(Vector3(0, -12, -70), Vector3(120, 2, 160), Color(1, 0.3, 0.1, 0.0))
