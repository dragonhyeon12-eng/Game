extends Node3D
## QA: walks the routes a player has to walk - with real movement input, not teleports - and checks the
## places where a level could trap or block you. Complements tests/flow_test.gd (which drives the story).
##   godot --headless --path . res://tests/qa_test.tscn
## Prints "QA TEST PASSED" or the failures.

var failures: Array[String] = []


func _ready() -> void:
	DirAccess.remove_absolute(Game.SAVE_PATH)
	Settings.deaths_seen = 1
	Game.boot(self)
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print("  ok   " if cond else "  FAIL ", what)
	if not cond:
		failures.append(what)


func wait(s: float) -> void:
	await get_tree().create_timer(s, true).timeout


func zone(z: String) -> void:
	Game.hud.close_menu()
	Game.enter_zone(z)
	Game.set_mode("game")
	Game.hud.set_fade(0.0)
	Game.player.dread.set_values(0.0, 100.0)
	await wait(0.6)


func place(pos: Vector3, yaw_deg: float) -> void:
	Game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos))


var top_y := -INF

## Hold movement keys for a while (yaw 0 = facing -Z). Returns where you ended up; top_y = highest point.
func walk(seconds: float, actions := ["move_forward"]) -> Vector3:
	top_y = -INF
	for a in actions:
		Input.action_press(a)
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		top_y = maxf(top_y, Game.player.global_position.y)
	for a in actions:
		Input.action_release(a)
	await wait(0.2)
	return Game.player.global_position


func calm() -> void:
	Game.player.dread.set_values(0.0, 100.0)


func _run() -> void:
	await wait(1.0)

	print("== objectives never show raw {placeholders}")
	await zone("city")
	var raw := Game.objectives().filter(func(o): return String(o[0]).contains("{"))
	check(raw.is_empty(), "city objectives filled in (%s)" % str(raw))

	print("== saved counters read back as whole numbers")
	await zone("tenement")
	Game.counters["floor"] = 5
	Game.save_checkpoint()
	Game.continue_game()
	await wait(0.8)
	var txt := ""
	for o in Game.objectives():
		txt += String(o[0]) + " | "
	check(not txt.contains(".0"), "no '5.0' after loading (%s)" % txt)

	print("== THE DEEP: the door you can't look at")
	await zone("abyss")
	place(Vector3(0, 0.05, -62.4), 0.0)            # facing the wall
	var p := await walk(2.0)
	check(p.z > -63.8, "looking at it, it's a wall (z=%.2f)" % p.z)
	place(Vector3(0, 0.05, -62.4), 180.0)          # facing away, walking backwards
	calm()
	p = await walk(3.0, ["move_back"])
	check(p.z < -64.6, "backwards, without looking, you go through (z=%.2f)" % p.z)
	check(Game.has_flag("abyss_room3"), "and the game notices")
	print("== THE DEEP: walking over a rock arch")
	place(AbyssZone.CROSS + Vector3(0, 0.05, 23.0), 0.0)   # the south platform, facing the centre
	calm()
	p = await walk(10.0)
	check(p.z < AbyssZone.CROSS.z + 9.5 and p.y > -1.0, "across the south arch to the centre (z=%.1f y=%.2f)" % [p.z, p.y])

	print("== THE DEEP: outrunning the leviathan (sprinting straight for the door)")
	var ab: AbyssZone = Game.zone
	place(Vector3(0, 0.05, AbyssZone.STATION_Z - 16.0), 0.0)
	calm()
	ab._begin_chase()
	p = await walk(16.0, ["move_forward", "sprint"])
	check(not Game.in_sequence and p.z < AbyssZone.EXIT_Z + 3.0, "reached the door alive (z=%.1f, caught=%s)" % [p.z, Game.in_sequence])
	print("== THE DEEP: walking, it catches you")
	await zone("abyss")
	ab = Game.zone
	place(Vector3(0, 0.05, AbyssZone.STATION_Z - 16.0), 0.0)
	calm()
	ab._begin_chase()
	p = await walk(16.0)
	check(Game.in_sequence, "walking, it's on you before the door (z=%.1f)" % p.z)
	await wait(1.0)
	Game._cancel_sequences()

	print("== COMPRESSION: climbing the stairwell on foot")
	await zone("tenement")
	var tz: TenementZone = Game.zone
	var O := TenementZone.O
	place(O + Vector3(-1.0, 0.05, -1.2), 0.0)       # bottom of flight A, facing up it
	p = await walk(2.2)
	check(p.y > 1.2, "up flight A to the half landing (y=%.2f)" % p.y)
	place(O + Vector3(1.0, 1.65, -5.0), 180.0)      # foot of flight B, facing up it
	var ups := tz._ups
	p = await walk(2.6)
	check(tz._ups == ups + 1 and absf(p.y) < 0.5, "up flight B... and you're back on the same landing (ups %d, y=%.2f)" % [tz._ups, p.y])
	var fl := tz._floor_num
	place(O + Vector3(1.0, 0.05, -1.0), 0.0)        # the landing, at the top of the flight below, facing down it
	p = await walk(2.0)
	place(O + Vector3(-1.0, -STOREY_HALF(), -4.8), 180.0)   # the half landing below, facing down the next flight
	p = await walk(2.6)
	check(tz._floor_num == fl + 1, "down two flights: the number goes UP (%d -> %d)" % [fl, tz._floor_num])
	print("== COMPRESSION: the duct")
	tz._grille_block.queue_free()
	place(Vector3(-39.0, 0.05, -9.0), 90.0)
	Game.player._set_crouch(true)
	calm()
	p = await walk(4.0)
	check(p.x < -46.0, "crawl along the duct (x=%.1f)" % p.x)

	print("== COMPRESSION: outrunning the collapse")
	await zone("tenement")
	tz = Game.zone
	place(Vector3(TenementZone.CORR_X0 + 1.0, 0.05, TenementZone.CORR_Z), -90.0)
	calm()
	p = await walk(14.0, ["move_forward", "sprint"])
	check(tz._collapse == false and Game.has_flag("ten_shaft") and not Game.in_sequence, "sprinting, you make it to the shaft (x=%.1f)" % p.x)

	print("== ABOVE: the floating stairs, on foot")
	await zone("above")
	var az: AboveZone = Game.zone
	az._gust_t = 999.0
	place(Vector3(24, 0.05, -70.5), 0.0)
	calm()
	p = await walk(5.0)
	check(top_y > 3.7, "up the first flight (highest y=%.2f, z=%.1f)" % [top_y, p.z])
	p = await walk(12.0)
	check(p.y > 11.8 and p.z < -97.0, "all the way up to the construction site (y=%.2f, z=%.1f)" % [p.y, p.z])
	print("== ABOVE: up the scaffolding, on foot")
	place(Vector3(19, 12.05, -99.0), 0.0)
	calm()
	p = await walk(5.0)
	check(top_y > 15.8, "up the first ramp (highest y=%.2f)" % top_y)
	place(Vector3(20.6, 16.05, -108.6), 180.0)
	p = await walk(5.0)
	check(top_y > 19.8, "up the second ramp (highest y=%.2f)" % top_y)

	if failures.is_empty():
		print("QA TEST PASSED")
	else:
		print("QA TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func STOREY_HALF() -> float:
	return TenementZone.STOREY * 0.5 - 0.05
