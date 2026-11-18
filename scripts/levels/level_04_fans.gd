extends LevelBase
## Level 4: Giant Fan Factory. Float over pits on updrafts. Hold a direction while airborne to
## drift across; the later fans pulse on and off and some blow sideways.


func build() -> void:
	hint_text = "Jump into the airflow, then hold forward to drift across. Fans blow in pulses later!"
	kill_y = -45.0
	sky_color = Color(0.7, 0.72, 0.8)
	var floor_c := Color(0.75, 0.78, 0.9)

	# Start (z -6..6)
	add_platform(Vector3(0, 0, 0), Vector2(12, 12), "metal", 1.0, floor_c)
	add_wall(Vector3(0, 0, 5.8), Vector3(12, 1.0, 0.4), "metal")
	add_sign(Vector3(0, 3.0, -4), "JUMP INTO THE AIRFLOW")

	# Gap 1 (z -6..-20), steady fan
	add_fan(Vector3(0, -3, -13), 3.0, 14.0, 38.0, Vector3.UP, 0.0, 6.5)
	add_platform(Vector3(0, 0, -26), Vector2(12, 12), "metal", 1.0, floor_c)       # z -20..-32
	add_collectible(Vector3(0, 4.0, -13))

	# Gap 2 (z -32..-46), pulsing fan
	add_fan(Vector3(0, -3, -39), 3.0, 14.0, 46.0, Vector3.UP, 4.0, 6.5)
	add_platform(Vector3(0, 0, -52), Vector2(12, 12), "metal", 1.0, floor_c)       # z -46..-58
	add_checkpoint(Vector3(0, 0.05, -52))
	add_collectible(Vector3(0, 4.0, -39))

	# Tower lift: strong fan in a pit up to a raised platform (y = 5)
	add_fan(Vector3(0, -3, -65), 3.2, 18.0, 50.0, Vector3.UP, 0.0, 7.0)
	add_platform(Vector3(0, 5, -78), Vector2(12, 12), "metal", 1.0, floor_c)       # z -72..-84
	add_checkpoint(Vector3(0, 5.05, -77))
	add_collectible(Vector3(0, 6.0, -65))

	# Crosswind bridge (y = 5, z -84..-106) with sideways fans
	add_platform(Vector3(0, 5, -95), Vector2(3.4, 22), "metal", 0.6, floor_c)
	add_fan(Vector3(-7, 5.8, -90), 2.4, 12.0, 26.0, Vector3.RIGHT, 0.0)
	add_fan(Vector3(7, 5.8, -98), 2.4, 12.0, 26.0, Vector3.LEFT, 3.0)
	add_collectible(Vector3(0, 6.0, -95))

	# Final platform
	add_platform(Vector3(0, 5, -112), Vector2(14, 12), "metal", 1.0, floor_c)       # z -106..-118
	add_checkpoint(Vector3(0, 5.05, -108))
	add_finish(Vector3(0, 5, -114))

	add_hazard_zone(Vector3(0, -14, -58), Vector3(120, 2, 140), Color(1, 0.3, 0.1, 0.0))
