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

	print("== BACKROOMS: the power comes on - and there's a way out of the power room")
	await zone("maze")
	var mz: MazeZone = Game.zone
	mz._open_maint()
	var wx: Transform3D = mz._wing_xf
	var sd: float = mz._side
	place(wx * Vector3(20.5, 0.05, 0), 0.0)
	calm()
	for letter in mz._order:
		for b in mz._breakers:
			if b.letter == letter:
				mz._flip(b)
	await wait(0.4)
	mz._power_on()
	await wait(0.6)
	var route := [wx * Vector3(20.2, 0, 1.6 * sd), wx * Vector3(20.2, 0, 4.4 * sd), wx * Vector3(20.2, 0, 6.5 * sd),
		wx * Vector3(1.0, 0, 6.5 * sd), wx * Vector3(-2.0, 0, 6.5 * sd)]
	var ok := await run_to(route)
	check(ok and not Game.in_sequence and mz._in_grid(Game.player.global_position), "ran through the shutter and the service passage, back into the maze")
	check(mz._hunting, "and it's coming")
	var d0: float = mz._stalker.global_position.distance_to(Game.player.global_position)
	await wait(3.0)
	var through: bool = mz._in_grid(mz._stalker.global_position) or (wx.affine_inverse() * mz._stalker.global_position).z * sd > 3.0 or Game.in_sequence
	check(through, "it followed you the way you went (stalker at %s, was %.1f m away)" % [wx.affine_inverse() * mz._stalker.global_position, d0])
	print("== BACKROOMS: the chase - the maze closes down to one route to the lift")
	await wait(0.3)
	check(mz._chase_on and mz._chase_path.size() > 1, "the chase began (%d cells to the lift)" % mz._chase_path.size())
	var pts := mz.chase_waypoints()
	print("    %d rooms, %d false trails, hazards %s" % [mz._chase_path.size(), mz._decoys.size(), mz._hazards.map(func(h): return h.kind)])
	if OS.get_cmdline_user_args().has("--trace"):
		print("    path ", mz._chase_path)
	var made_it := await run_to(pts, true, 120.0)
	print("    reached route cell %d/%d, fear %.0f, stalker %.1f m behind" % [mz._chase_idx, mz._chase_path.size(), Game.player.dread.fear,
		mz._stalker.global_position.distance_to(Game.player.global_position)])
	var tw := 0.0
	while tw < 4.0 and not Game.in_sequence:
		await wait(0.1)
		tw += 0.1
	check(mz._sealed.size() >= 3, "openings slammed shut along the way (%d)" % mz._sealed.size())
	check(made_it and (Game.in_sequence or Game.has_flag("maze_escaped")) and not mz._hunting,
		"sprinting the red route, you reach the lift (the lift sequence started: %s)" % Game.in_sequence)
	tw = 0.0
	while tw < 12.0 and Game.zone_type != "deep":
		await wait(0.2)
		tw += 0.2
	check(Game.zone_type == "deep", "and the lift takes you on (zone %s)" % Game.zone_type)
	Game._cancel_sequences()

	print("== BACKROOMS: run into a hole instead of jumping it, and you fall")
	await zone("maze")
	mz = Game.zone
	mz._open_maint()
	place(mz._wing_xf * Vector3(-2.0, 0.05, 0), 0.0)
	mz._hunting = true
	await wait(0.3)
	var pits: Array = mz._hazards.filter(func(h): return h.kind == "pit")
	check(mz._chase_on and not pits.is_empty(), "a chase with a pit in it (%d)" % pits.size())
	if not pits.is_empty():
		var hz: Dictionary = pits[0]
		mz._hunting = false
		mz._stalker.global_position = mz.cell_center(0, 0)
		mz._build_hazard(hz, 0.0)
		await wait(0.5)
		var al: Vector3 = hz.along
		place(hz.c - al * 3.0 + Vector3(0, 0.05, 0), rad_to_deg(atan2(-al.x, -al.z)))
		calm()
		await walk(3.0, ["move_forward", "sprint"])
		check(Game.in_sequence, "into the hole (y=%.1f)" % Game.player.global_position.y)
		await wait(1.0)
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
	print("== STILL LIFE: look away, and it's there")
	await zone("stilllife")
	var sz: StillLifeZone = Game.zone
	var hunter: Mannequin = sz._figures[0]
	place(Vector3(-2.0, 0.05, -12.0), 0.0)           # facing -z
	hunter.global_position = Vector3(-2.0, 0.12, -6.5)  # behind you
	hunter.hunting = true
	calm()
	var tq := 0.0
	while tq < 8.0 and not Game.in_sequence:
		await wait(0.1)
		tq += 0.1
	check(Game.in_sequence, "it came up behind you (%.1f s)" % tq)
	await wait(1.0)
	Game._cancel_sequences()
	await zone("stilllife")
	sz = Game.zone
	hunter = sz._figures[0]
	place(Vector3(-2.0, 0.05, -12.0), 180.0)         # facing it
	hunter.global_position = Vector3(-2.0, 0.12, -6.5)
	hunter.hunting = true
	var hp: Vector3 = hunter.global_position
	await wait(3.0)
	check(hunter.global_position.distance_to(hp) < 0.01 and not Game.in_sequence, "watched, it doesn't move")
	hunter.hunting = false
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
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var t_run := 0.0
	while t_run < 20.0 and not Game.in_sequence and Game.player.global_position.z > AbyssZone.EXIT_Z + 1.2:
		await get_tree().physics_frame
		t_run += get_physics_process_delta_time()
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var gap: float = ab.leviathan.head_position().distance_to(Game.player.camera.global_position)
	check(not Game.in_sequence, "sprinting, you reach the door alive (%.1f s, it was %.1f m behind you)" % [t_run, gap])
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
