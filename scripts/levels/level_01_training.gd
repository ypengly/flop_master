extends LevelBase
## Level 1: Training Room. Gentle, safe, teaches every verb in order.


func build() -> void:
	hint_text = "Move: WASD  |  Run: Shift  |  Jump: Space  |  Dive: C  |  Grab: E  |  Push: F  |  Get up: R"
	kill_y = -15.0
	sky_color = Color(0.75, 0.88, 1.0)
	spawn_point = Vector3(0, 0.1, 4)
	var floor_tint := Color(0.85, 0.95, 0.85)

	# Floor A (z +8 .. -39), gap of 4m, Floor B (z -43 .. -52.5) then a raised block to the finish.
	add_platform(Vector3(0, 0, -15.5), Vector2(14, 47), "stone", 1.0, floor_tint)
	add_platform(Vector3(0, 0, -47.75), Vector2(14, 9.5), "stone", 1.0, floor_tint)
	add_wall(Vector3(0, 0, -66), Vector3(14, 2.2, 27), "wood", Color(1.0, 0.92, 0.75))   # z -52.5 .. -79.5
	add_hazard_zone(Vector3(0, -6, -41), Vector3(20, 2, 8), Color(0.4, 0.4, 0.9, 0.0))

	# Rails and back wall
	for sx in [-7.2, 7.2]:
		add_wall(Vector3(sx, 0, -15.5), Vector3(0.4, 1.2, 47), "wood", Color(0.9, 0.8, 0.6))
		add_wall(Vector3(sx, 0, -47.75), Vector3(0.4, 1.2, 9.5), "wood", Color(0.9, 0.8, 0.6))
		add_wall(Vector3(sx, 2.2, -66), Vector3(0.4, 1.2, 27), "wood", Color(0.9, 0.8, 0.6))
	add_wall(Vector3(0, 0, 8.2), Vector3(14.8, 3.0, 0.4), "stone")

	add_sign(Vector3(0, 3.0, -4), "WALK (WASD)  -  SHIFT TO RUN")
	add_collectible(Vector3(0, 1.0, -8))
	add_collectible(Vector3(2, 1.0, -11))

	add_sign(Vector3(0, 3.0, -14), "JUMP (SPACE)")
	add_wall(Vector3(0, 0, -17), Vector3(14, 0.7, 0.8), "rubber", Color(1.0, 0.6, 0.7))
	add_collectible(Vector3(0, 2.2, -17))

	add_checkpoint(Vector3(0, 0.05, -22))

	add_sign(Vector3(0, 3.0, -25), "PUSH (F)  -  KNOCK THEM DOWN!")
	add_crate_stack(Vector3(0, 0, -30), 5, 4)
	add_crate_stack(Vector3(-3.5, 0, -30), 3, 2)
	add_crate_stack(Vector3(3.5, 0, -30), 3, 2)

	add_sign(Vector3(0, 3.0, -37), "DIVE (C) ACROSS THE GAP")
	add_collectible(Vector3(0, 2.2, -41))

	add_sign(Vector3(0, 4.5, -48), "GRAB (E) THE LEDGE, THEN PRESS JUMP TO PULL UP")
	add_checkpoint(Vector3(0, 2.2, -56))

	add_sign(Vector3(0, 6.0, -62), "BOUNCE! RUBBER LOVES YOU")
	add_platform(Vector3(0, 2.25, -64), Vector2(10, 5), "rubber", 0.1, Color(1.0, 0.7, 0.8))
	add_collectible(Vector3(0, 6.0, -64))

	add_finish(Vector3(0, 2.2, -75))
