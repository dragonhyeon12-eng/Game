extends Node3D
## THE BACKROOMS on foot: from where you wake on the office carpet, out past the desks, down the corridor of
## doors, across the pillar hall, down the last corridor and into the yellow rooms - real input, real physics.
## Then the doorway behind you is wall.
##   godot --headless --path . res://tests/backrooms_walk_test.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


## Run along the points (turning to face each one); false if it didn't get to the last within `timeout`.
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
	Game.enter_zone("maze")
	Game.set_mode("game")
	Game.hud.set_fade(0.0)
	await get_tree().create_timer(1.5).timeout
	var mz: MazeZone = Game.zone
	var pl: Player = Game.player
	check(pl.global_position.distance_to(MazeZone.START) < 0.5, "you wake on the office carpet (%s)" % pl.global_position.snapped(Vector3.ONE * 0.1))
	var ok := await run_to([Vector3(-32.5, 0, -158.3), Vector3(-15.0, 0, -158.3), Vector3(-15.0, 0, -149.0)], 30.0)
	check(ok, "out past the desks to the glass doors")
	ok = await run_to([Vector3(-15.0, 0, -112.0), Vector3(-15.0, 0, -104.0)], 20.0)
	check(ok and mz._section == "hall", "down the corridor of doors, into the hall")
	check(mz.checkpoint_id() == "hall", "a checkpoint at the hall")
	ok = await run_to([Vector3(-14.0, 0, -94.0), Vector3(10.0, 0, -94.0), Vector3(10.0, 0, -70.0)], 25.0)
	check(ok and mz._phone_state == 1, "across the hall (and a payphone is ringing)")
	ok = await run_to([Vector3(10.0, 0, -46.0), Vector3(19.5, 0, -46.0), Vector3(19.5, 0, -41.0)], 25.0)
	check(ok, "under the EXIT sign")
	ok = await run_to([Vector3(19.5, 0, -6.0), Vector3(19.5, 0, 2.5)], 25.0)
	check(ok and mz._in_grid(pl.global_position), "down the last corridor and into the yellow rooms")
	check(mz.checkpoint_id() == "rooms", "a checkpoint before the rooms")
	await get_tree().create_timer(0.5).timeout
	check(mz._entry_sealed, "behind you, the doorway has closed up")
	await run_to([Vector3(19.5, 0, -7.0)], 3.0)
	check(pl.global_position.z > -3.3, "and there's no going back through it (z %.1f)" % pl.global_position.z)
	print("BACKROOMS WALK TEST PASSED" if failures == 0 else "BACKROOMS WALK TEST FAILED (%d)" % failures)
	get_tree().quit(failures)
