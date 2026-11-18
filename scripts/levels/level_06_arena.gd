extends LevelBase
## Level 6: Ultimate Flop Arena. Every mechanic in one gauntlet: ice, beams, launch pad, fans,
## movers, crate rain and a final tower. Four checkpoints.


func build() -> void:
	hint_text = "Everything at once. Good luck, Flop Master."
	kill_y = -55.0
	sky_color = Color(1.0, 0.62, 0.62)
	var arena := Color(1.0, 0.88, 0.85)

	# Start pad
	add_platform(Vector3(0, 0, 0), Vector2(12, 12), "stone", 1.0, arena)
	add_wall(Vector3(0, 0, 5.8), Vector3(12, 1.0, 0.4), "stone")

	# Ice runway with beams (z -6 .. -34)
	add_platform(Vector3(0, 0, -20), Vector2(6, 28), "ice", 1.0)
	add_beam(Vector3(0, 9.0, -14), 8.2, 45.0, 3.2, 0.0)
	add_beam(Vector3(0, 9.0, -26), 8.2, 45.0, 3.2, PI)
	add_collectible(Vector3(0, 1.0, -20))

	# Rest pad
	add_platform(Vector3(0, 0, -40), Vector2(12, 12), "stone", 1.0, arena)           # z -34..-46
	add_checkpoint(Vector3(0, 0.05, -40))
	add_crate_stack(Vector3(-3.5, 0, -43), 4, 3)
	add_crate_stack(Vector3(3.5, 0, -43), 4, 3)

	# Launch pad over the fan pit to a high platform (y = 7)
	add_launch_pad(Vector3(0, 0, -45), Vector2(4, 3), Vector3(0, 21.0, -14.5))
	add_fan(Vector3(0, -3, -53), 3.0, 14.0, 38.0, Vector3.UP, 5.0, 7.0)
	add_platform(Vector3(0, 7, -66), Vector2(12, 12), "metal", 1.0, Color(0.8, 0.85, 0.95))  # z -60..-72
	add_checkpoint(Vector3(0, 7.05, -65))
	add_collectible(Vector3(0, 9.0, -54))

	# Mover chain at height 7
	add_mover(Vector3(-3, 7, -79), Vector2(5, 5), "slide", "wood").configure_slide(Vector3(6, 0, 0), 4.0)
	add_mover(Vector3(0, 7, -88), Vector2(6, 6), "tilt", "ice", 0.6).configure_tilt(Vector3.RIGHT, 12.0, 4.5)
	add_mover(Vector3(0, 7, -98), Vector2(8, 8), "spin", "rubber", 0.6, Color(1.0, 0.6, 0.8)).configure_spin(0.8)
	add_collectible(Vector3(0, 8.0, -98))

	# Crate-rain arena (rubber floor!)
	add_platform(Vector3(0, 7, -114), Vector2(14, 20), "rubber", 1.0, Color(1.0, 0.7, 0.8))  # z -104..-124
	for sx in [-7.2, 7.2]:
		add_wall(Vector3(sx, 7, -114), Vector3(0.4, 0.8, 20), "wood")
	add_dropper(Vector3(0, 21, -110), 1.3, Vector3(5, 0, 4))
	add_dropper(Vector3(0, 21, -118), 1.5, Vector3(5, 0, 4))
	add_checkpoint(Vector3(0, 7.05, -106))
	add_collectible(Vector3(4, 8.5, -114))
	add_collectible(Vector3(-4, 8.5, -118))

	# Final: crosswind tightrope + fan tower to the summit (y = 12)
	add_platform(Vector3(0, 7, -138), Vector2(2.4, 24), "metal", 0.6, Color(1.0, 0.9, 0.5))  # z -126..-150
	add_fan(Vector3(-6, 7.8, -134), 2.2, 11.0, 24.0, Vector3.RIGHT, 0.0)
	add_fan(Vector3(6, 7.8, -142), 2.2, 11.0, 24.0, Vector3.LEFT, 3.0)
	add_beam(Vector3(0, 16.0, -146), 8.2, 45.0, 2.8, 0.0)
	add_platform(Vector3(0, 7, -158), Vector2(12, 12), "stone", 1.0, arena)                  # z -152..-164
	add_checkpoint(Vector3(0, 7.05, -154))
	add_collectible(Vector3(0, 8.0, -138))
	add_fan(Vector3(0, 3, -170.5), 3.0, 18.0, 54.0, Vector3.UP, 0.0, 6.5)
	add_platform(Vector3(0, 12, -184), Vector2(14, 14), "soft", 1.0, Color(1.0, 0.95, 0.6))  # z -177..-191
	add_finish(Vector3(0, 12, -184))

	add_hazard_zone(Vector3(0, -14, -92), Vector3(160, 2, 240), Color(1, 0.3, 0.1, 0.0))
