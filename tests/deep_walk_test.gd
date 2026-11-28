extends Node3D
## THE DEEP on foot: from the lobby through the turnstiles, the changing rooms and the foot bath, across the
## pool rooms (the shallows, the channel, the big room), down the last corridor into the pool hall - real
## input, real physics. And out where the far wall isn't, into the water that goes to the sky.
##   godot --headless --path . res://tests/deep_walk_test.tscn

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
	Game.enter_zone("deep")
	Game.set_mode("game")
	Game.hud.set_fade(0.0)
	await get_tree().create_timer(1.5).timeout
	var dz: DeepZone = Game.zone
	var pl: Player = Game.player
	check(dz._section == "lobby", "you arrive in the lobby (%s)" % pl.global_position.snapped(Vector3.ONE * 0.1))
	var ok := await run_to([Vector3(-13.5, 0, 25.2), Vector3(-18.0, 0, 25.2)], 15.0)
	check(ok and dz._section == "changing", "through the turnstiles into the changing rooms")
	ok = await run_to([Vector3(-41.0, 0, 25.2), Vector3(-41.0, 0, 28.0), Vector3(-44.5, 0, 28.0)], 20.0)
	check(ok and dz.surface_at(pl.global_position) == "wet", "into the foot bath (wet underfoot)")
	ok = await run_to([Vector3(-47.4, 0, 28.0), Vector3(-47.4, 0, 8.0)], 20.0)
	check(ok and dz._section == "rooms" and dz._world_env.environment == dz._env_rooms, "out into the pool rooms - daylight")
	check(dz.checkpoint_id() == "rooms", "a checkpoint at the pool rooms")
	ok = await run_to([Vector3(-66.8, 0, 8.0), Vector3(-66.8, 0, -33.0), Vector3(-66.8, 0, -37.0)], 30.0)
	check(ok, "down the channel corridor into the big room")
	ok = await run_to([Vector3(-36.5, 0, -37.0), Vector3(-36.5, 0, -30.0), Vector3(-36.5, 0, -14.5), Vector3(-30.0, 0, -14.5)], 30.0)
	check(ok and dz._section == "hall" and dz._world_env.environment == dz._env_hall, "down the last corridor and into the pool hall, at night")
	check(dz.checkpoint_id() == "hall" and Game.has_flag("deep_hall"), "a checkpoint at the hall")
	# the shallows: wading, not swimming
	pl.teleport(Transform3D(Basis(), Vector3(-70.0, 0.05, 20.0)))
	await get_tree().create_timer(1.0).timeout
	check(not pl.swimming and pl.global_position.y < -0.3, "standing in the shallows, not swimming (y %.2f)" % pl.global_position.y)
	# the deep end: swimming
	pl.teleport(Transform3D(Basis(), Vector3(-52.0, -1.0, -50.0)))
	await get_tree().create_timer(1.0).timeout
	check(pl.swimming, "in the deep end, swimming")
	# out where the wall isn't
	pl.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(-90.0, -0.4, -50.0)))
	await get_tree().create_timer(0.5).timeout
	ok = await run_to([Vector3(-130.0, 0, -50.0)], 10.0)
	check(not ok and pl.global_position.x > -112.5 and pl.global_position.x < -100.0, "out into the water to the sky - as far as it lets you (x %.1f)" % pl.global_position.x)
	print("DEEP WALK TEST PASSED" if failures == 0 else "DEEP WALK TEST FAILED (%d)" % failures)
	get_tree().quit(failures)
