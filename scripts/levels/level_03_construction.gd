extends LevelBase
## Level 3: Construction Chaos. Steel girders, swinging wrecking beams and a crate rain zone.


func build() -> void:
	hint_text = "Time the swinging beams. Rubber is bouncy, metal is slick-ish, and crates fall from the sky!"
	kill_y = -45.0
	sky_color = Color(0.95, 0.85, 0.65)
	var deck := Color(0.95, 0.8, 0.45)

	# Start deck z -6..6
	add_platform(Vector3(0, 0, 0), Vector2(12, 12), "stone", 1.0, Color(0.7, 0.7, 0.65))
	add_wall(Vector3(0, 0, 5.8), Vector3(12, 1.0, 0.4), "stone")
	add_sign(Vector3(0, 3.0, -3), "WRECKING BEAMS AHEAD")

	# Girder walkway 1 (z -6 .. -28): two beams
	add_platform(Vector3(0, 0, -17), Vector2(6, 22), "metal", 0.8, deck)
	add_beam(Vector3(0, 9.0, -13), 8.2, 48.0, 3.0, 0.0)
	add_beam(Vector3(0, 9.0, -22), 8.2, 48.0, 3.0, PI)
	add_collectible(Vector3(0, 1.0, -17))

	# Deck 2 with crate stacks to wreck
	add_platform(Vector3(0, 0, -34), Vector2(12, 12), "stone", 1.0, Color(0.7, 0.7, 0.65))
	add_checkpoint(Vector3(0, 0.05, -32))
	add_crate_stack(Vector3(-3.5, 0, -37), 4, 3)
	add_crate_stack(Vector3(3.5, 0, -37), 4, 3)

	# Crate-rain zone (z -40 .. -64), wood floor with low side rails
	add_platform(Vector3(0, 0, -52), Vector2(10, 24), "wood", 1.0, Color(0.9, 0.75, 0.55))
	for sx in [-5.2, 5.2]:
		add_wall(Vector3(sx, 0, -52), Vector3(0.4, 0.8, 24), "wood")
	add_dropper(Vector3(0, 14, -46), 1.6, Vector3(3.5, 0, 4))
	add_dropper(Vector3(0, 14, -58), 1.9, Vector3(3.5, 0, 4))
	add_collectible(Vector3(3, 1.0, -48))
	add_collectible(Vector3(-3, 1.0, -58))

	# Deck 3
	add_platform(Vector3(0, 0, -70), Vector2(12, 12), "stone", 1.0, Color(0.7, 0.7, 0.65))
	add_checkpoint(Vector3(0, 0.05, -68))

	# Narrow girder gauntlet: 3 beams, 2.6m wide beam of steel (z -76 .. -102)
	add_platform(Vector3(0, 0, -89), Vector2(2.6, 26), "metal", 0.6, deck)
	add_beam(Vector3(0, 9.0, -81), 8.4, 55.0, 2.6, 0.0)
	add_beam(Vector3(0, 9.0, -89), 8.4, 55.0, 2.6, PI * 0.5)
	add_beam(Vector3(0, 9.0, -97), 8.4, 55.0, 2.6, PI)
	add_collectible(Vector3(0, 1.0, -89))

	# Crane platform and finish
	add_platform(Vector3(0, 0, -112), Vector2(14, 14), "stone", 1.0, Color(0.7, 0.7, 0.65))
	add_checkpoint(Vector3(0, 0.05, -107))
	add_finish(Vector3(0, 0, -115))

	# The ground far below: respawn quickly
	add_hazard_zone(Vector3(0, -14, -58), Vector3(120, 2, 140), Color(1, 0.3, 0.1, 0.0))
