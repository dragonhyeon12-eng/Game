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


## Run (or walk) through waypoints, steering like a player would. Returns false if you didn't get there.
func run_to(points: Array, sprint := true, timeout := 20.0) -> bool:
	Input.action_press("move_forward")
	if sprint:
		Input.action_press("sprint")
	var t := 0.0
	var i := 0
	var next_log := 1.0
	while i < points.size() and t < timeout and not Game.in_sequence:
		if OS.get_cmdline_user_args().has("--trace") and t > next_log:
			next_log += 1.0
			print("    t=%.0f waypoint %d/%d at %s -> %s  vel %.1f" % [t, i, points.size(), Game.player.global_position.snapped(Vector3.ONE * 0.1), points[i], Game.player.velocity.length()])
			for k in Game.player.get_slide_collision_count():
				var col := Game.player.get_slide_collision(k)
				var o: Object = col.get_collider()
				print("      hit %s at %s n=%s shape=%s" % [o.get_path() if o is Node else o, col.get_position().snapped(Vector3.ONE*0.1), col.get_normal().snapped(Vector3.ONE*0.1), _shape_desc(o, col.get_collider_shape_index())])
		var pl := Game.player
		var pt: Vector3 = points[i][0] if points[i] is Array else points[i]
		var to: Vector3 = pt - pl.global_position
		to.y = 0.0
		if to.length() < 0.45:
			if points[i] is Array and points[i][1] != "":
				var act: String = points[i][1]
				if act == "jump":
					Input.action_press("jump")
					await get_tree().physics_frame
					Input.action_release("jump")
				elif act == "crouch" or act == "stand":
					pl._set_crouch(act == "crouch")      # (crouch toggles on an input event, which action_press doesn't send)
				if OS.get_cmdline_user_args().has("--trace"):
					print("    %s at %s (t=%.1f, stalker %.1f m)" % [act, pl.global_position.snapped(Vector3.ONE * 0.1), t, Game.zone._stalker.global_position.distance_to(pl.global_position) if Game.zone is MazeZone else -1.0])
			i += 1
			continue
		pl.rotation.y = atan2(-to.x, -to.z)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release("move_forward")
	Input.action_release("sprint")
	return i >= points.size()


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

	print("== BACKROOMS: the power comes on - and it stays behind the glass")
	await zone("maze")
	var mz: MazeZone = Game.zone
	mz._open_maint()
	var wx: Transform3D = mz._wing_xf
	var sd: float = mz._side
	place(wx * Vector3(20.5, 0.05, 0), 0.0)
	calm()
	mz._power_on()
	await wait(3.6)
	check(mz._watching and not mz._hunting and is_instance_valid(mz._glass), "it comes to the glass - and stays behind it, watching")
	var route := [wx * Vector3(20.2, 0, 1.6 * sd), wx * Vector3(20.2, 0, 4.4 * sd), wx * Vector3(20.2, 0, 6.5 * sd),
		wx * Vector3(1.0, 0, 6.5 * sd), wx * Vector3(-2.0, 0, 6.5 * sd)]
	var ok := await run_to(route)
	check(ok and not Game.in_sequence and mz._in_grid(Game.player.global_position), "through the shutter and the service passage, back into the rooms")
	await wait(0.3)
	check(mz._way_on and mz._way_path.size() > 1 and not mz._hunting and not mz._chase_on, "red lamps and EXIT signs lead back to the lift (%d rooms) - and nothing comes after you" % mz._way_path.size())
	var pts := mz._way_path.map(func(c): return mz.cell_center(c.x, c.y))
	var made_it := await run_to(pts, true, 150.0)
	var tw := 0.0
	while tw < 6.0 and not Game.in_sequence:
		await wait(0.1)
		tw += 0.1
	check(made_it and (Game.in_sequence or Game.has_flag("maze_escaped")), "following the trail, you reach the lift (sequence %s)" % Game.in_sequence)
	tw = 0.0
	while tw < 14.0 and Game.zone_type != "deep":
		await wait(0.2)
		tw += 0.2
	check(Game.zone_type == "deep", "and the lift takes you on (zone %s)" % Game.zone_type)
	Game._cancel_sequences()
	print("== BLACKOUT: through number 9 on foot - front door, living room, kitchen, back door, garden")
	await zone("blackout")
	var bz: BlackoutZone = Game.zone
	bz.no_dark_death = true
	Game.set_flag("bo_key")
	place(Vector3(9.0, 0.05, -41.5), -90.0)
	calm()
	var walked := await run_to([Vector3(15.0, 0, -41.5), Vector3(21.5, 0, -41.5), Vector3(23.0, 0, -41.5)], false, 15.0)
	check(walked, "front door to the back door (%s)" % Game.player.global_position.snapped(Vector3.ONE * 0.1))
	for c in bz.get_children():
		if c is Interactable and c.get_prompt() == "Unlock the padlock":
			c.interact()
	await wait(1.2)
	walked = await run_to([Vector3(26.0, 0, -41.5), Vector3(30.0, 0, -50.0)], false, 10.0)
	check(walked and Game.has_flag("bo_backyard"), "out into the back garden (%s)" % Game.player.global_position.snapped(Vector3.ONE * 0.1))
	place(Vector3(9.5, 0.05, -44.5), -90.0)
	walked = await run_to([Vector3(17.0, 0, -44.5)], false, 6.0)
	check(not walked, "...and no way round the house: the garage wall is solid")
	print("== STILL LIFE: look away, and it has changed - but it's still where it was")
	await zone("stilllife")
	var sz: StillLifeZone = Game.zone
	var still: Mannequin = sz._figures[0]
	place(Vector3(-2.0, 0.05, -12.0), 0.0)           # facing -z
	still.global_position = Vector3(-2.0, 0.12, -6.5)  # behind you
	still.hunting = true
	var hp0: Vector3 = still.global_position
	var pose0: String = still.pose
	calm()
	var tq := 0.0
	while tq < 8.0 and still.pose == pose0:
		await wait(0.1)
		tq += 0.1
	check(still.pose != pose0 and still.global_position.distance_to(hp0) < 0.01 and not Game.in_sequence,
		"behind you, it changed its stance (%s -> %s) and never stepped off (%.1f s)" % [pose0, still.pose, tq])
	place(Vector3(-2.0, 0.05, -12.0), 180.0)         # facing it
	await wait(0.4)
	var pose1: String = still.pose
	await wait(3.0)
	check(still.pose == pose1 and not Game.in_sequence, "watched, it doesn't change")
	still.hunting = false
	print("== THE DEEP: through the one door that works, into the next room")
	await zone("abyss")
	var best: Interactable = null
	for c in Game.zone.get_children():
		if c is Interactable and c.get_prompt() == "Open the door" and (best == null or c.global_position.distance_to(Vector3(2.5, 1, -43.8)) < best.global_position.distance_to(Vector3(2.5, 1, -43.8))):
			best = c
	best.interact()
	await wait(1.5)
	place(Vector3(2.5, 0.05, -42.5), 0.0)
	calm()
	var pr := await walk(4.5)
	check(pr.z < -48.0 and pr.y > -0.5, "into the room beyond, on a floor (z=%.1f y=%.2f)" % [pr.z, pr.y])
	print("== THE DEEP: the room with no doors - walk into the bubbles")
	await zone("abyss")
	Game.clear_flag("abyss_room2")
	place(Vector3(0, 0.05, -50.0), 0.0)
	calm()
	var pw := await walk(3.5)
	check(pw.z < -54.6, "through the bubbling wall (z=%.2f)" % pw.z)
	check(Game.has_flag("abyss_room2"), "and the game notices")
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

	print("== THE DEEP: the leviathan passes over - and doesn't come for you")
	var ab: AbyssZone = Game.zone
	place(Vector3(0, 0.05, AbyssZone.STATION_Z - 16.0), 0.0)
	calm()
	ab._begin_chase()
	p = await walk(16.0)
	check(not Game.in_sequence and p.z < AbyssZone.STATION_Z - 30.0, "walking on, it never touches you (z=%.1f)" % p.z)
	var tw2 := 0.0
	while tw2 < 15.0 and ab._chase:
		await wait(0.2)
		tw2 += 0.2
	check(not ab._chase and not Game.in_sequence, "it's gone back into the dark")

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
	var through_duct := await run_to([Vector3(-53.0, 0, -9.0), Vector3(-53.0, 0, -23.5), Vector3(-53.0, 0, -25.2)], false, 40.0)
	p = Game.player.global_position
	check(through_duct and p.z < -24.6, "crawl the whole duct, crouched, out into the stairwell (%s)" % p)

	print("== COMPRESSION: outrunning the collapse")
	await zone("tenement")
	tz = Game.zone
	place(Vector3(TenementZone.CORR_X0 + 1.0, 0.05, TenementZone.CORR_Z), -90.0)
	calm()
	p = await walk(14.0, ["move_forward", "sprint"])
	check(tz._collapse == false and Game.has_flag("ten_shaft") and not Game.in_sequence, "sprinting, you make it to the shaft (%s)" % p)

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


func _shape_desc(o: Object, idx: int) -> String:
	if not o is CollisionObject3D:
		return ""
	var cs = o.shape_owner_get_owner(o.shape_find_owner(idx))
	if cs is CollisionShape3D:
		return "%s at %s size %s" % [cs.shape.get_class(), cs.global_position.snapped(Vector3.ONE*0.01), (cs.shape.size if cs.shape is BoxShape3D else "")]
	return str(cs)
