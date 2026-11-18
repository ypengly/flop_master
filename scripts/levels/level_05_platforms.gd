extends LevelBase
## Level 5: Moving Platform Madness. Sliders, see-saws, a turntable, an elevator and tilting ice.


func build() -> void:
	hint_text = "Wait for platforms to line up. See-saws tip you; the turntable flings you!"
	kill_y = -45.0
	sky_color = Color(0.85, 0.7, 0.95)
	var stone_c := Color(0.8, 0.75, 0.85)

	# Start z -8..8
	add_platform(Vector3(0, 0, 0), Vector2(12, 16), "stone", 1.0, stone_c)
	add_wall(Vector3(0, 0, 7.8), Vector3(12, 1.0, 0.4), "stone")

	# Slider along X (z -9.5 .. -14.5)
	add_mover(Vector3(-3.5, 0, -12.5), Vector2(5, 5), "slide", "wood").configure_slide(Vector3(7, 0, 0), 5.0)
	add_collectible(Vector3(0, 1.0, -12.5))

	# See-saw (tilts about X so the ends go up and down)
	add_mover(Vector3(0, 0, -21), Vector2(6, 7), "tilt", "wood", 0.6, Color(1.0, 0.9, 0.7)).configure_tilt(Vector3.RIGHT, 13.0, 5.0)

	# Turntable
	add_mover(Vector3(0, 0, -31), Vector2(9, 9), "spin", "rubber", 0.6, Color(1.0, 0.6, 0.8)).configure_spin(0.7)
	add_collectible(Vector3(0, 1.0, -31))

	# Safe island
	add_platform(Vector3(0, 0, -42), Vector2(10, 8), "stone", 1.0, stone_c)         # z -38..-46
	add_checkpoint(Vector3(0, 0.05, -42))

	# Forward/back shuttle and side slider
	add_mover(Vector3(0, 0, -53), Vector2(5, 5), "slide", "wood").configure_slide(Vector3(0, 0, -6), 6.0)
	add_mover(Vector3(-3, 0, -66), Vector2(5, 5), "slide", "metal").configure_slide(Vector3(6, 0, 0), 4.0, PI)
	add_collectible(Vector3(0, 1.0, -66))

	# Island 2 + elevator up to y = 4
	add_platform(Vector3(0, 0, -76), Vector2(10, 8), "stone", 1.0, stone_c)         # z -72..-80
	add_checkpoint(Vector3(0, 0.05, -75))
	add_mover(Vector3(0, 0, -86), Vector2(6, 6), "bob", "rubber", 0.6, Color(1.0, 0.7, 0.8)).configure_slide(Vector3(0, 4.0, 0), 6.0)
	add_platform(Vector3(0, 4, -96), Vector2(10, 8), "stone", 1.0, stone_c)         # z -92..-100
	add_checkpoint(Vector3(0, 4.05, -95))
	add_collectible(Vector3(0, 5.0, -96))

	# Tilting ice rolls (axis Z so they roll sideways)
	add_mover(Vector3(0, 4, -108), Vector2(6, 8), "tilt", "ice", 0.6).configure_tilt(Vector3(0, 0, 1), 12.0, 4.5)
	add_mover(Vector3(0, 4, -118), Vector2(6, 8), "tilt", "ice", 0.6).configure_tilt(Vector3(0, 0, 1), 12.0, 4.5, PI)
	add_collectible(Vector3(0, 5.0, -113))

	# Finish island
	add_platform(Vector3(0, 4, -130), Vector2(14, 12), "soft", 1.0, Color(0.9, 0.8, 0.95))   # z -124..-136
	add_checkpoint(Vector3(0, 4.05, -126))
	add_finish(Vector3(0, 4, -132))

	add_hazard_zone(Vector3(0, -14, -66), Vector3(120, 2, 160), Color(1, 0.3, 0.1, 0.0))
