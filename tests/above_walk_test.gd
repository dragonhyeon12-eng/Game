extends Node3D
## ABOVE on foot: out of the freight lift down the hotel's corridor, into the stairwell, up onto the roof
## terrace, across it and over the footbridge to the first rooftop - real input, real physics.
##   godot --headless --path . res://tests/above_walk_test.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func run_to(points: Array, timeout: float) -> bool:
	var pl: Player = Game.player
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var t := 0.0
	var i := 0
	while i < points.size() and t < timeout:
		var to: Vector3 = points[i] - pl.global_position
		to.y = 0.0
		if to.length() < 0.5:
			i += 1
			continue
		pl.rotation.y = atan2(-to.x, -to.z)
		pl.dread.set_values(0.0, 100.0)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release("move_forward")
	Input.action_release("sprint")
	if i < points.size():
		print("    stuck at %s on the way to %s (t %.0f)" % [pl.global_position.snapped(Vector3.ONE * 0.1), points[i], t])
	return i >= points.size()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	Game.hud.close_menu()
	Game.enter_zone("above")
	Game.set_mode("game")
	Game.hud.set_fade(0.0)
	await get_tree().create_timer(1.5).timeout
	var az: AboveZone = Game.zone
	var pl: Player = Game.player
	az._gust_phase = 0
	az._gust_t = 999.0
	check(az._in_hotel(pl.global_position), "out of the lift, on the hotel's sixty-first floor (%s)" % pl.global_position.snapped(Vector3.ONE * 0.1))
	var ok := await run_to([Vector3(15.0, 0, 34.0), Vector3(15.0, 0, 31.0), Vector3(15.0, 0, 23.4), Vector3(13.0, 0, 23.4)], 25.0)
	check(ok, "down the corridor and into the stairwell")
	ok = await run_to([Vector3(13.0, 0, 29.0), Vector3(13.0, 0, 31.5)], 15.0)
	check(ok and pl.global_position.y > -0.3, "up the stairs and out onto the roof terrace (y %.2f)" % pl.global_position.y)
	ok = await run_to([Vector3(5.0, 0, 26.0), Vector3(5.0, 0, 21.0), Vector3(5.0, 0, 5.5)], 25.0)
	check(ok and pl.global_position.y > -0.3 and pl.global_position.z < 6.5, "over the footbridge onto the first rooftop (%s)" % pl.global_position.snapped(Vector3.ONE * 0.1))
	pl.teleport(Transform3D(Basis(), Vector3(8.0, 0.3, 40.0)))
	await get_tree().create_timer(1.0).timeout
	check(not pl.swimming and pl.global_position.y < -0.4 and az.surface_at(pl.global_position) == "wet", "standing in the roof pool (y %.2f)" % pl.global_position.y)
	print("ABOVE WALK TEST PASSED" if failures == 0 else "ABOVE WALK TEST FAILED (%d)" % failures)
	get_tree().quit(failures)
