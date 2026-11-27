extends Node3D
## THE CITY on foot: the player walks (real input, real physics) through each join of the long walk north -
## park to avenue, through the arcade into the lido, up the steps, through the gate, up the hill.
##   godot --headless --path . res://tests/city_walk_test.tscn

var failures := 0
var top_y := -INF       # the highest the last walk got


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


## Walk forward from `start` facing `yaw` for `secs`; returns where you ended up.
func walk(start: Vector3, yaw: float, secs: float, run := false) -> Vector3:
	var pl: Player = Game.player
	pl.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), start))
	await get_tree().create_timer(0.4).timeout
	Input.action_press("move_forward")
	if run:
		Input.action_press("sprint")
	var t := 0.0
	top_y = -INF
	while t < secs:
		top_y = maxf(top_y, pl.global_position.y)
		pl.dread.set_values(0.0, 100.0)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await get_tree().create_timer(0.3).timeout
	return pl.global_position


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	Game.hud.close_menu()
	Game.enter_zone("city")
	Game.set_mode("game")
	Game.hud.set_fade(0.0)
	await get_tree().create_timer(1.5).timeout
	var p := await walk(Vector3(0, 0.3, -12.0), 0.0, 25.0)
	check(p.z < -80.0, "out of the park and up the avenue (z %.0f)" % p.z)
	p = await walk(Vector3(44.0, 0.3, -116.0), 0.0, 26.0)
	check(p.z < -180.0, "across the cross street, through the arcade, out onto the pool deck (z %.0f)" % p.z)
	p = await walk(Vector3(54.0, 0.3, -246.0), 0.0, 16.0)
	check(p.z < -284.0 and p.y > TerraceY.Y - 0.5, "up the steps to the terrace (z %.0f, y %.1f)" % [p.z, p.y])
	p = await walk(Vector3(55.0, 9.3, -290.0), 0.0, 14.0)
	check(p.z < -322.0, "through the playground gate into the meadow (z %.0f)" % p.z)
	p = await walk(Vector3(52.0, 9.3, -330.0), 0.0, 30.0)
	check(top_y > 11.5, "up the hill to the big tree (highest %.1f)" % top_y)
	# you can swim in the pool
	Game.player.teleport(Transform3D(Basis(), Vector3(50.0, 0.5, -205.0)))
	await get_tree().create_timer(1.5).timeout
	check(Game.player.global_position.y > -1.6, "afloat in the lido, not walking on its floor (y %.1f)" % Game.player.global_position.y)
	print("CITY WALK TEST PASSED" if failures == 0 else "CITY WALK TEST FAILED (%d)" % failures)
	get_tree().quit(failures)


class TerraceY:
	const Y := 9.15
