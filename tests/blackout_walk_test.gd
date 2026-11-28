extends Node3D
## BLACKOUT on foot: from the petrol station's canopy out onto Mill Road, east along it streetlight to
## streetlight (the dark is real: stay in it too long and it has you), and into Larkspur Lane.
##   godot --headless --path . res://tests/blackout_walk_test.tscn

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
	Game.enter_zone("blackout")
	Game.set_mode("game")
	Game.hud.set_fade(0.0)
	await get_tree().create_timer(1.5).timeout
	var bz: BlackoutZone = Game.zone
	var pl: Player = Game.player
	check(bz._lit(pl.global_position), "you start in the light of the petrol station (%s)" % pl.global_position.snapped(Vector3.ONE * 0.1))
	var ok := await run_to([Vector3(-57.0, 0, 13.0), Vector3(-2.0, 0, 13.0), Vector3(0.0, 0, 5.0)], 40.0)
	check(ok and not Game.in_sequence, "down Mill Road in the dark, light to light, and still here")
	check(bz.checkpoint_id() == "lane", "a checkpoint at the mouth of Larkspur Lane")
	ok = await run_to([Vector3(0.0, 0, -20.0)], 15.0)
	check(ok and not Game.in_sequence, "up the lane")
	print("BLACKOUT WALK TEST PASSED" if failures == 0 else "BLACKOUT WALK TEST FAILED (%d)" % failures)
	get_tree().quit(failures)
