extends Node3D
## The realms after ABOVE, played through in order (BLACKOUT, STILL LIFE, OPEN SPACE, PATTERN, THE QUIET),
## objective by objective. Used by tests/flow_test.gd (which arrives here through the door in the sky), and
## on its own:
##   godot --headless --path . res://tests/realms_test.tscn [-- <realm>]
## Prints "REALMS TEST PASSED" or the failures.

var failures: Array[String] = []
var standalone := false


func _ready() -> void:
	if get_parent() != get_tree().root:
		return
	standalone = true
	DirAccess.remove_absolute(Game.SAVE_PATH)
	Settings.deaths_seen = 1
	Game.boot(self)
	_main.call_deferred()


func _main() -> void:
	await wait(1.0)
	Game.hud.close_menu()
	var args := Array(OS.get_cmdline_user_args()).filter(func(a): return not String(a).begins_with("--"))
	var only: String = args[0] if args.size() > 0 else ""
	Game.set_mode("game")
	Game.hud.set_fade(0.0)
	var order := ["blackout", "stilllife", "openspace", "pattern", "quiet"]
	var start := order.find(only) if only != "" else 0
	Game.enter_zone(order[maxi(start, 0)])
	Game.save_checkpoint()
	await wait(0.8)
	await run_from(order[maxi(start, 0)], only != "")
	Game._cancel_sequences()
	await wait(0.5)
	if failures.is_empty():
		print("REALMS TEST PASSED")
	else:
		print("REALMS TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)


## Plays from `realm` to the end (or just that one realm).
func run_from(realm: String, just_one := false) -> void:
	var order := ["blackout", "stilllife", "openspace", "pattern", "quiet"]
	for i in range(order.find(realm), order.size()):
		var r: String = order[i]
		check(Game.zone_type == r and Game.mode == "game", "arrived in %s (zone %s, mode %s)" % [r, Game.zone_type, Game.mode])
		await call("_" + r)
		if just_one:
			return
		# the transition to the next realm (a title card) takes a while
		await settle()
		await through_rest()


func settle() -> void:
	for k in 30:
		await wait(0.5)
		if Game.mode == "game" and not Game.in_sequence:
			break


## A resting place on the way: take what's there, and on through the glowing doorway.
func through_rest() -> void:
	if not Game.zone_type.begins_with("rest"):
		return
	var r := Game.zone_type
	check(Game.player.dread.value() < 20.0, "%s: a resting place, and you're calm" % r)
	var pills := 0
	while use("Take a pill"):
		pills += 1
	check(pills >= 3 and use("Take the music box"), "%s: %d pills and the music box" % [r, pills])
	check(use("Go on"), "%s: the glowing doorway" % r)
	await settle()


func check(cond: bool, what: String) -> void:
	print("  ok   " if cond else "  FAIL ", what)
	if not cond:
		failures.append(what)


func wait(s: float) -> void:
	await get_tree().create_timer(s, true).timeout


func use(prompt: String, near := Vector3.INF) -> bool:
	var best: Interactable = null
	var bd := INF
	for c in _all(Game.zone):
		if c is Interactable and (c.get_prompt() == prompt or c.get_prompt().begins_with(prompt + " (")) and c.can_interact():
			var d: float = 0.0 if near == Vector3.INF else c.global_position.distance_to(near)
			if d < bd:
				bd = d
				best = c
	if best:
		best.interact()
	return best != null


func _all(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all(c))
	return out


func place(pos: Vector3, yaw_deg := 0.0) -> void:
	Game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos))


func look_at_point(p: Vector3) -> void:
	var pl := Game.player
	var from := pl.camera.global_position
	var d := (p - from).normalized()
	pl.rotation.y = atan2(-d.x, -d.z)
	pl._pitch = asin(clampf(d.y, -1, 1))
	pl.head.rotation.x = pl._pitch


func calm() -> void:
	Game.player.dread.set_values(0.0, 100.0)


# ------------------------------------------------------------------ BLACKOUT

func _blackout() -> void:
	print("== BLACKOUT: the lane")
	var z: BlackoutZone = Game.zone
	check(z._lit(Game.player.global_position), "you start in the light")
	z.no_dark_death = true
	place(Vector3(0, 0.05, -50.0), 180.0)
	await wait(0.4)
	check(Game.has_flag("bo_tree"), "the tree across the road")
	print("== BLACKOUT: number 9")
	place(Vector3(14.5, 0.05, -41.5), -90.0)
	await wait(0.4)
	check(Game.has_flag("bo_inside"), "inside number 9")
	check(use("Switch on the lamp"), "the living-room lamp")
	check(use("Pull the cord"), "the red bulb")
	await wait(0.2)
	check(Game.has_flag("bo_key") and not z._key.visible, "no key to hunt for: you already have it")
	check(use("Unlock the padlock") and Game.has_flag("bo_backyard"), "out the back door")
	print("== BLACKOUT: the gardens")
	check(use("Open the gate"), "the garden gate")
	print("== BLACKOUT: the box")
	place(BlackoutZone.BOX + Vector3(0, 0.05, 1.6), 180.0)
	await wait(0.3)
	check(use("Throw the switch"), "the junction box")
	await wait(4.0)
	check(Game.has_flag("bo_power") and z._crowd[0].visible, "every light on - and the shadows")
	await wait(5.0)
	check(z._wave_t > 0.0, "and the dark coming back up the street")
	await wait(3.5)
	place(BlackoutZone.BUS_DOOR + Vector3(1.5, 0.05, 0.5), -90.0)
	await wait(0.3)
	check(use("Get on the bus"), "onto the night bus")


## Hold the movement keys for a while (yaw 0 = facing -Z). Returns where you ended up.
func walk(seconds: float, actions := ["move_forward"]) -> Vector3:
	for a in actions:
		Input.action_press(a)
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	for a in actions:
		Input.action_release(a)
	await wait(0.2)
	return Game.player.global_position


func _calm_figures(z: StillLifeZone) -> void:
	for m in z._figures:
		m.hunting = false


func _stilllife() -> void:
	print("== STILL LIFE: the arcade")
	var z: StillLifeZone = Game.zone
	place(Vector3(-4.2, 0.05, -2.3), 180.0)
	check(use("Read the directory") and Game.has_flag("sl_directory"), "the directory")
	check(z._grille != null, "the escalator is shut")
	place(StillLifeZone.KIOSK + Vector3(0, 0.05, 1.8), 180.0)
	check(use("Read the note") and Game.has_flag("sl_note"), "the security kiosk's note: at dinner")
	print("== STILL LIFE: Home & Family")
	place(Vector3(-5.0, 0.05, -38.25), 90.0)     # in the arcade, at the shop's doorway
	calm()
	var into := await walk_to(Vector3(-11.0, 0, -38.25), func(): return Game.player.global_position.x < -8.0, 8.0)
	check(into, "walked in through the doorway (%s)" % Game.player.global_position.snapped(Vector3.ONE * 0.1))
	place(StillLifeZone.SEAT + Vector3(0.9, 0.05, 0), 90.0)
	await wait(0.3)
	check(use("Sit down"), "sitting down at the table")
	await wait(6.5)
	check(Game.has_flag("sl_family") and Game.has_flag("sl_key"), "...and the guard's keys")
	var awake := z._figures.filter(func(m): return m.hunting).size()
	check(awake > 12, "...and the window displays wake (%d)" % awake)
	# look away from a window: its mannequin's out of it (one from far down the arcade: the near ones may be out already)
	var waiting := z._figures.filter(func(m): return m.has_meta("out_to"))
	check(waiting.size() > 0, "far down the arcade, some are still in their windows (%d)" % waiting.size())
	var one: Mannequin = waiting.back()
	place(Vector3(0, 0.05, one.global_position.z), 0.0)
	Game.player.rotation.y = atan2(one.global_position.x, 0.0)      # facing away from it
	await wait(1.5)
	check(not one.has_meta("out_to") and absf(one.global_position.x) < StillLifeZone.HALF, "a display stepped out of its window while you looked away")
	_calm_figures(z)
	print("== STILL LIFE: the escalator")
	place(StillLifeZone.ESC + Vector3(0, 0.05, 1.6), 0.0)
	await wait(0.3)
	check(use("Unlock the grille"), "unlocking the grille")
	await wait(1.8)
	calm()
	_calm_figures(z)
	var p := await walk(6.0)
	check(p.y > StillLifeZone.STOREY - 0.2, "up the stopped escalator on foot (y=%.2f, z=%.1f)" % [p.y, p.z])
	print("== STILL LIFE: LIFELIKE")
	check(Game.has_flag("sl_level3"), "the gallery")
	place(Vector3(0, StillLifeZone.STOREY + 0.05, StillLifeZone.GAL_Z0 - 13.0), 0.0)
	await wait(0.4)
	check(Game.has_flag("sl_lights3"), "the lights start going")
	_calm_figures(z)
	await wait(4.0)
	check(not z._sections[0].on, "a section's gone dark")
	_calm_figures(z)
	place(StillLifeZone.EXIT + Vector3(0, 0.05, 1.4), 0.0)
	await wait(0.3)
	check(use("Staff exit"), "the staff exit")


## Through a conversation: pick these choices (by visible index) in turn, advancing past everything else.
func talk(choices: Array) -> void:
	var k := 0
	for step in 40:
		if not Dialogue.is_active():
			return
		if Dialogue._visible.is_empty():
			Dialogue.advance()
		elif k < choices.size():
			Dialogue.choose(choices[k])
			k += 1
		else:
			Dialogue.choose(Dialogue._visible.size() - 1)
		await wait(0.1)


func _openspace() -> void:
	print("== OPEN SPACE: the car park")
	var z: OpenSpaceZone = Game.zone
	place(z._car.global_position + Vector3(0, 0.05, 2.2), 0.0)
	await wait(0.3)
	check(use("Get in"), "found the car")
	await wait(12.5)
	check(Game.has_flag("os_car") and Game.mode == "game", "it won't start; the gas station")
	print("== OPEN SPACE: the road (walking toward it while looking at it)")
	place(Vector3(0, 0.05, -120.0), 0.0)
	await wait(0.2)
	look_at_point(z._sign_point())
	var d0: float = Game.player.global_position.distance_to(z._station.global_position)
	calm()
	await walk(4.0)
	var d1: float = Game.player.global_position.distance_to(z._station.global_position)
	check(z._recede > 6.0 and d1 > d0 - 3.0, "watching it, it gets no closer (%.0f m -> %.0f m, it moved back %.0f m)" % [d0, d1, z._recede])
	Game.player._pitch = deg_to_rad(-60.0)
	Game.player.head.rotation.x = Game.player._pitch
	var r0: float = z._recede
	await walk(3.0)
	check(is_equal_approx(z._recede, r0), "watching the road, it stays put")
	place(z._station.global_position + Vector3(0, 0.05, 12.0), 0.0)
	await wait(0.3)
	check(Game.has_flag("os_station") and z._phone_ringing, "the gas station; a phone ringing")
	print("== OPEN SPACE: the phone")
	var ph: Vector3 = z._station.global_position + Vector3(2.0, 0, -11.8)
	calm()
	var door_front: Vector3 = z._station.global_position + Vector3(0, 0, -6.0)
	await walk_to(door_front, func(): return Vector2(Game.player.global_position.x - door_front.x, Game.player.global_position.z - door_front.z).length() < 0.5, 10.0)
	var walked := await walk_to(ph, func(): return Vector2(Game.player.global_position.x - ph.x, Game.player.global_position.z - ph.z).length() < 0.9, 12.0)
	check(walked, "walked under the canopy and into the shop (%s, phone at %s)" % [Game.player.global_position.snapped(Vector3.ONE * 0.1), ph.snapped(Vector3.ONE * 0.1)])
	check(use("Answer the phone"), "answering it")
	await talk([3])
	check(Game.has_flag("os_call"), "Mina, on the line")
	check(use("Out the back"), "out the back door")
	await wait(1.5)
	check(Game.has_flag("os_plaza") and Game.player.global_position.x > 1000.0, "...into a square that doesn't end")
	print("== OPEN SPACE: the plaza")
	var s0: Vector3 = z._stairs.global_position
	place(Game.player.global_position, 180.0)
	await wait(2.0)
	check(z._stairs.global_position.distance_to(s0) > 5.0, "looked away: the stairs moved")
	place(z._stairs.global_position + Vector3(0, 0.05, 3.0), 0.0)
	await wait(0.3)
	check(use("Go down the stairs"), "down the stairs")


## Face a point and walk at it until `done` is true (or time runs out).
func walk_to(target: Vector3, done: Callable, timeout := 8.0) -> bool:
	Input.action_press("move_forward")
	var t := 0.0
	while t < timeout and not done.call():
		var to := target - Game.player.global_position
		to.y = 0.0
		Game.player.rotation.y = atan2(-to.x, -to.z)
		Game.player._pitch = 0.0
		Game.player.head.rotation.x = 0.0
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release("move_forward")
	await wait(0.2)
	return done.call()


func _pattern() -> void:
	print("== PATTERN: the platform")
	var z: PatternZone = Game.zone
	z.no_swarm_death = true
	place(Vector3(-3.4, 0.05, -6.0), 90.0)
	check(use("Read the map") and Game.has_flag("pt_map"), "the network map")
	print("== PATTERN: the hive (walking it)")
	place(Vector3(0, 0.05, -17.0), 0.0)
	calm()
	var inside := await walk_to(PatternZone.C, func(): return z._in_hive, 8.0)
	check(inside and Game.has_flag("pt_hive"), "into the hive; the way back's gone")
	# one wrong door, on purpose
	var wrong: int = (z._true_door + 1) % 6
	if wrong == z._entry:
		wrong = (wrong + 1) % 6
	var sw: int = z._swarm
	await walk_to(PatternZone.door_point(wrong) + PatternZone.door_dir(wrong) * 4.0, func(): return z._swarm > sw, 8.0)
	check(z._swarm == sw + 1 and z._depth == 0, "a wrong door: back in the same room, and more holes (swarm %d)" % z._swarm)
	for k in 4:
		calm()
		var d: int = z._depth
		var td: int = z._true_door
		await walk_to(PatternZone.C, func(): return (Game.player.global_position - PatternZone.C).length() < 2.0, 6.0)
		print("    true door %d, entry %d, swarm %d, player %s" % [z._true_door, z._entry, z._swarm, Game.player.global_position.snapped(Vector3.ONE * 0.1)])
		var sw2: int = z._swarm
		var front: Vector3 = PatternZone.door_point(z._true_door) - PatternZone.door_dir(z._true_door) * 1.2
		await walk_to(front, func(): return Vector2(Game.player.global_position.x - front.x, Game.player.global_position.z - front.z).length() < 0.4, 5.0)
		var ok := await walk_to(PatternZone.door_point(z._true_door) + PatternZone.door_dir(z._true_door) * 4.0, func(): return z._depth > d or z._swarm > sw2, 8.0)
		print("    -> depth %d, swarm %d, true now %d, player %s" % [z._depth, z._swarm, z._true_door, Game.player.global_position.snapped(Vector3.ONE * 0.1)])
		ok = z._depth > d
		check(ok, "through the clean doorway (%d), deeper: %d" % [td, z._depth])
	check(Game.has_flag("pt_deep") and z._true_door == 0, "four rooms deep: a corridor behind the clean door")
	await walk_to(PatternZone.C, func(): return (Game.player.global_position - PatternZone.C).length() < 2.0, 6.0)
	var f0: Vector3 = PatternZone.door_point(0) - PatternZone.door_dir(0) * 1.2
	await walk_to(f0, func(): return Vector2(Game.player.global_position.x - f0.x, Game.player.global_position.z - f0.z).length() < 0.4, 5.0)
	var reached := await walk_to(PatternZone.CORE, func(): return Game.has_flag("pt_core"), 16.0)
	check(reached, "down the long corridor to the middle")
	print("== PATTERN: the rings")
	place(PatternZone.CORE + Vector3(0, 0.05, -1.6), 0.0)
	var tr := 0.0
	while tr < 12.0 and not Game.has_flag("pt_rings"):
		await wait(0.2)
		tr += 0.2
	check(Game.has_flag("pt_rings"), "the rings turn by themselves and line up; the round door rolls aside (%.1f s)" % tr)
	await wait(3.0)
	place(PatternZone.CORE + PatternZone.door_dir(0) * 7.0 + Vector3(0, 0.05, 0), 0.0)
	await wait(0.3)
	check(use("Through the porthole door"), "WARD 6")


func _quiet() -> void:
	print("== THE QUIET: waiting")
	var z: QuietZone = Game.zone
	place(Vector3(-6.5, 0.05, -2.3), 0.0)
	check(use("Take a number") and Game.has_flag("q_number"), "number 13")
	check(use("Read the visitors' book") and Game.has_flag("q_book"), "the visitors' book")
	print("== THE QUIET: records")
	place(Vector3(-3.5, 0.05, -18.0), 90.0)
	await wait(0.2)
	check(use("Read the file: MINA (no surname)"), "Mina's file")
	check(use("Read the Ward 6 file") and Game.has_flag("q_records"), "the Ward 6 file")
	print("== THE QUIET: the nurses' station")
	place(Vector3(5.0, 0.05, -25.0), -90.0)
	check(use("Take the key to Ward 6") and Game.has_flag("q_key"), "the key")
	check(z._figures_awake, "...and the visitors in the corridor wake")
	z.no_figures = true
	print("== THE QUIET: Ward 6")
	place(Vector3(0, 0.05, -48.5), 0.0)
	await wait(0.2)
	check(use("Unlock Ward 6") and Game.has_flag("q_ward6"), "into Ward 6")
	await wait(1.5)
	calm()
	var p := await walk(1.5)
	check(p.z < -51.0, "through the door on foot (z=%.1f)" % p.z)
	check(use("Read the chart") and Game.has_flag("q_chart"), "the chart: 'not yet.'")
	await wait(4.5)
	check(z._garden_block == null, "every clock stops; the garden door opens")
	print("== THE QUIET: the garden")
	place(Vector3(0, 0.05, -46.0), -90.0)
	calm()
	p = await walk(4.0)
	check(Game.has_flag("q_garden") and p.x > 6.0, "out into the garden on foot (x=%.1f)" % p.x)
	z._halvorsen.interact()
	await wait(0.3)
	await talk([4])
	check(Game.has_flag("q_gatekey"), "Mr. Halvorsen gives you the key")
	place(QuietZone.GATE + Vector3(-1.5, 0.05, 0), -90.0)
	check(use("Open the gate"), "the gate opens")
