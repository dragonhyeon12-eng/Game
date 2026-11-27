extends Node3D
## THE PLACE WE REMEMBER, end to end: the gate starts locked; the three markers each work; the gate opens;
## the corridor east loops (and lets you back out); through the arch onto the street; on to the maze.
##   godot --headless --path . res://tests/remember_test.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func walk(start: Vector3, yaw: float, secs: float) -> Vector3:
	var pl: Player = Game.player
	pl.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), start))
	await get_tree().create_timer(0.3).timeout
	Input.action_press("move_forward")
	var t := 0.0
	while t < secs:
		pl.dread.set_values(0.0, 100.0)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release("move_forward")
	await get_tree().create_timer(0.3).timeout
	return pl.global_position


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	Game.hud.close_menu()
	Game.start_at("remember")
	await get_tree().create_timer(2.0).timeout
	check(Game.zone_type == "remember" and Game.player.is_on_floor(), "standing at the park gates")
	var z: RememberZone = Game.zone
	check(z._markers.size() == 3, "three markers in the impossible garden (%d)" % z._markers.size())
	check(z._gate_block != null, "the gate starts locked")
	# walk the main route in legs
	var p := await walk(Vector3(0, 0.05, 6.0), 0.0, 38.0)
	check(p.z < -95.0, "in through the gates, up the path to the fountain (z %.0f)" % p.z)
	p = await walk(Vector3(-34.0, 0.05, -134.0), 0.0, 16.0)
	check(p.z < -172.0, "the west path to the gardens (z %.0f)" % p.z)
	p = await walk(Vector3(0, 0.05, -182.0), 0.0, 48.0)
	check(p.z < -318.0, "up the garden allee (z %.0f)" % p.z)
	p = await walk(Vector3(0, 0.05, -326.0), 0.0, 64.0)
	check(p.z < -486.0, "across the playground and into the impossible garden (z %.0f)" % p.z)
	# each marker: walk up to it and touch it
	for i in 3:
		var m: Array = z._markers[i]
		var mp: Vector3 = (m[0] as Node3D).position
		Game.player.teleport(Transform3D(Basis(), mp + Vector3(0, 0.05, 1.3)))
		await get_tree().create_timer(0.4).timeout
		z._activate(m)
		await get_tree().create_timer(0.3).timeout
	check(z._markers_done() == 3 and Game.has_flag("rm_gate") and z._gate_block == null, "three markers: the gate opens")
	# the endless corridor: east forever, then back out west
	p = await walk(z.HUB + Vector3(14.0, 0.05, 0.0), -90.0, 50.0)
	check(z._loops >= 1 and p.x < z.HUB.x + z.LOOP_FROM + 2.0 * z.LOOP_LEN + 1.0, "the corridor east loops (%d loops, x %.0f)" % [z._loops, p.x])
	p = await walk(Game.player.global_position, 90.0, 40.0)
	check(p.x < z.HUB.x + 20.0, "...and walking back west gets you out (x %.0f)" % p.x)
	# through the gate, down the last path, out under the arch
	p = await walk(z.HUB + Vector3(0, 0.05, 6.0), 0.0, 44.0)
	check(z._on_street, "through the gate and out under the arch onto the street (z %.0f)" % p.z)
	var w := 0.0
	while Game.zone_type != "maze" and w < 25.0:
		await get_tree().create_timer(0.5).timeout
		w += 0.5
	check(Game.zone_type == "maze", "and then the maze")
	print("REMEMBER TEST PASSED" if failures == 0 else "REMEMBER TEST FAILED (%d)" % failures)
	get_tree().quit(failures)
