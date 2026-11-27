extends Node3D
## Automated playthrough of the vertical slice. Drives every story beat through the same calls the
## player's actions trigger, checks the results and (when a display is available) saves screenshots.
##   godot --path . res://tests/flow_test.tscn -- --shots=/some/folder
## Prints "FLOW TEST PASSED" or the list of failures.

var shots_dir := ""
var failures: Array[String] = []
var step := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	if OS.get_cmdline_user_args().has("--low"):
		Settings.quality = 0.0
	DirAccess.remove_absolute(Game.SAVE_PATH)
	DirAccess.remove_absolute(Journal.PATH)
	Journal.unlocked.clear()
	Settings.deaths_seen = 0
	Game.boot(self)
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		failures.append(what)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


## Use the interactable in the current zone with this prompt (the nearest one to `near`, if given).
func use(prompt: String, near := Vector3.INF) -> bool:
	var best: Interactable = null
	var bd := INF
	for c in Game.zone.get_children():
		if c is Interactable and c.get_prompt() == prompt and c.can_interact():
			var d: float = 0.0 if near == Vector3.INF else c.global_position.distance_to(near)
			if d < bd:
				bd = d
				best = c
	if best:
		best.interact()
	return best != null


func objective_done(text_start: String) -> bool:
	for o in Game.objectives():
		if String(o[0]).begins_with(text_start):
			return o[1]
	return false


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	step += 1
	img.save_png("%s/%02d_%s.png" % [shots_dir, step, name])
	print("  shot ", name)


func look_at_point(p: Vector3) -> void:
	var pl := Game.player
	var from := pl.camera.global_position
	var d := (p - from).normalized()
	pl.rotation.y = atan2(-d.x, -d.z)
	pl.head.rotation.x = asin(clampf(d.y, -1, 1))
	pl._pitch = pl.head.rotation.x


func _run() -> void:
	print("== title")
	await wait(1.0)
	check(Game.zone_type == "bedroom" and Game.title_preview, "title shows over the bedroom (the first stop of the tour)")
	check(Game.hud.menu_open(), "title menu is open")
	await wait(1.5)
	await shot("title")

	print("== new game: bedroom")
	Game.start_new_game()
	await wait(2.6)
	check(Game.mode == "game", "player has control")
	check(Game.has_checkpoint(), "checkpoint written on new game")
	await shot("bedroom")
	look_at_point(Vector3(1.8, 0.6, -1.2))
	await shot("bedroom_bed")
	look_at_point(Vector3(-2.4, 1.1, -0.8))
	await wait(0.2)
	check(Game.player.prompt() == "Watch the video", "computer is focusable: '%s'" % Game.player.prompt())

	print("== tutorial video")
	Game.player.focused.interact()
	await wait(1.0)
	check(Game.hud.overlay_open() and Game.mode == "overlay", "tutorial overlay open")
	var tut: TutorialUI = Game.hud._overlay.get_child(0)
	for i in 4:
		tut._enter(tut._index + 1)
	await shot("tutorial")
	while not tut._done:
		tut._enter(tut._index + 1)
	await wait(1.0)
	check(Game.has_flag("tutorial_done"), "tutorial done")
	check(Notebook.build_page().size() == 5, "five rules written (%d)" % Notebook.build_page().size())
	check(Game.mode == "game", "control returned after tutorial")

	print("== notebook")
	look_at_point(Vector3(-2.13, 0.77, -0.2))
	await wait(0.2)
	check(Game.player.prompt() == "Take the notebook", "notebook is focusable: '%s'" % Game.player.prompt())
	if Game.player.focused:
		Game.player.focused.interact()
	check(Game.has_flag("has_notebook"), "took the notebook")
	Game.open_notebook()
	await wait(0.5)
	await shot("notebook_bedroom")
	Game.close_notebook()

	print("== sleep -> the dream bedroom -> summer city")
	Game.request_sleep()
	await wait(10.5)
	check(Game.zone_type == "bedroom_dream", "woke up in the dream copy of the bedroom")
	check(use("Door") and not Game.has_flag("city_realitycheck"), "can't leave before a reality check")
	check(use("Read the clock"), "read the clock")
	Game.set_flag("city_realitycheck")   # (the look-away half of the check is real-time)
	check(use("Go outside"), "go outside")
	await wait(3.5)
	check(Game.zone_type == "city", "arrived in the summer city")
	check(Game.mode == "game", "control in the city")
	await wait(2.0)
	await shot("city_arrival")
	look_at_point(Vector3(30, 3, -22))
	await shot("city_avenue")

	print("== manifestation")
	Game.player.manifestation.try_manifest()
	await wait(0.8)
	check(Game.player.manifestation.is_holding("ice_cream"), "holding an ice cream")
	look_at_point(Game.player.global_position + Vector3(1, 1.2, 0))
	await shot("ice_cream")
	Game.player.manifestation.use_held()
	check(Game.player.manifestation.held.bites_left == 2, "took a bite")

	print("== dialogue: Mina")
	var mina: NPC = null
	for c in Game.zone.get_children():
		if c is NPC and c.dialogue_id == "mina":
			mina = c
	Game.player.teleport(Transform3D(Basis(), mina.global_position + Vector3(0, 0, 2.2)))
	Game.player.manifestation.try_manifest()
	await wait(0.5)
	look_at_point(mina.global_position + Vector3(0, 1.3, 0))
	await wait(0.2)
	check(Game.player.prompt().begins_with("Talk to"), "Mina is focusable: '%s'" % Game.player.prompt())
	Dialogue.start(mina, "mina")
	await wait(0.3)
	check(Game.mode == "dialogue", "dialogue mode")
	Dialogue.advance()  # start -> hub
	await wait(0.3)
	await shot("dialogue_mina")
	Dialogue.choose(0)   # "Here. I made you one."  (requires holding ice cream)
	await wait(0.2)
	check(Game.has_flag("gave_icecream"), "gave Mina the ice cream")
	Dialogue.advance()
	Dialogue.advance()
	await wait(0.2)
	check(not Dialogue.is_active() and Game.mode == "game", "dialogue ended")

	print("== rule breaking: Halvorsen")
	var arne: NPC = null
	for c in Game.zone.get_children():
		if c is NPC and c.dialogue_id == "halvorsen":
			arne = c
	var stab_before := Game.player.dread.stability
	Dialogue.start(arne, "halvorsen")
	Dialogue.advance()   # start -> hub
	Dialogue.choose(2)   # real world -> rule break
	Dialogue.advance()   # narration -> real2
	Dialogue.choose(1)   # lottery
	await wait(0.2)
	check(Notebook.state["rule_realworld"].breaks == 2, "rule 4 broken twice")
	check(Game.has_flag("asked_lottery"), "asked for lottery numbers")
	check(Game.player.dread.stability < stab_before, "stability dropped")
	Dialogue.advance()
	Dialogue.advance()
	Dialogue.advance()
	check(not Dialogue.is_active(), "conversation over")

	print("== the observer")
	var obs: Observer = Game.zone.observer
	# put him back at his first spot, by the bus stop at the end of the avenue (rule breaks above may have moved
	# or hidden him): with your back turned, so he can appear
	Game.player.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(-2.0, CityZone.CURB, -60.0)))
	await wait(0.3)
	obs.hide_now()
	check(obs.try_appear_at(CityZone.BUS_STOP + Vector3(-0.5, 0, 4.0)), "the observer appears at the bus stop")
	await wait(1.0)
	look_at_point(obs.global_position + Vector3(0, 1.2, 0))
	await wait(1.5)
	print("    observer at ", obs.global_position, " visible=", obs.visible, " in_view=", Observation.in_view(obs.body_center(obs.global_position), 0.6),
		" clear=", Observation.has_line_of_sight(obs.body_center(obs.global_position)), " player=", Game.player.global_position)
	check(obs.observed, "observer is observed when looked at")
	await shot("observer_far")

	print("== wake up -> fall -> maze")
	Game.request_wake()
	await wait(6.5)
	check(Game.zone_type == "maze", "fell into the maze")
	check(Game.mode == "game", "control in maze")
	await wait(2.0)
	await shot("maze_start")

	print("== never read this notebook twice")
	Game.open_notebook()
	await wait(0.4)
	var page := Notebook.build_page()
	check(page.any(func(l): return l.text == "NEVER READ THIS NOTEBOOK TWICE."), "rule 6 appeared")
	await shot("notebook_rule6")
	Game.close_notebook()
	var fear_before := Game.player.dread.fear
	Game.open_notebook()
	await wait(0.3)
	check(Notebook.state["never_twice"].breaks == 1, "reading twice broke rule 6")
	check(Game.player.dread.fear > fear_before, "fear rose")
	check(Notebook.build_page().any(func(l): return l.text.begins_with("Don't think about anything scary. Don't think about it.")), "rule 2 rewrote itself")
	Game.close_notebook()

	print("== anomalies")
	Game.player.dread.set_values(70, 10)
	Anomalies.set_pacing(0.5, 0.5)
	var before := Anomalies.total_changes
	look_at_point(Game.player.global_position + Vector3(0, 1.6, -5))
	await wait(12.0)
	check(Anomalies.total_changes > before, "something changed while unobserved (%d)" % (Anomalies.total_changes - before))
	await shot("maze_dread")

	print("== corrupted pause")
	Game.player.dread.set_values(100, 20)
	await wait(0.3)
	Game._last_corrupted = -1000.0
	Game.open_pause()
	await wait(0.3)
	check(get_tree().paused, "game paused")
	var menu: DPMenu = Game.hud._menu_layer.get_child(0)
	check(menu._buttons.size() == 3 and menu._buttons.all(func(b): return b.text == "RESUME"), "menu shows RESUME x3")
	await shot("pause_corrupted")
	menu._items[1].action.call()
	await wait(0.2)
	check(not get_tree().paused, "middle RESUME resumes")

	print("== death sequence")
	Game.player.dread.set_values(100, 0)
	await wait(0.5)
	check(Game.in_sequence, "overwhelmed starts the waking sequence")
	check(not Game._death_skippable, "the first time, it can't be skipped")
	await wait(7.3)
	await shot("death_hands")
	await wait(4.0)
	await shot("death_card")
	for i in 30:
		await wait(0.5)
		if Game.zone_type == "maze" and Game.mode == "game":
			break
	check(Game.zone_type == "maze" and Game.mode == "game", "back at the maze checkpoint")
	check(absf(Game.player.dread.fear - 30.0) < 6.0, "fear reset to ~30")

	print("== the maintenance wing, the power, the lift")
	var mz: MazeZone = Game.zone
	mz._open_maint()
	for letter in mz._order:
		for b in mz._breakers:
			if b.letter == letter:
				mz._flip(b)
	await wait(0.5)
	check(mz._flipped.size() == 4, "breakers flipped in the right order")
	mz._power_on()
	await wait(3.5)
	check(Game.has_flag("maze_power") and mz._hunting, "power on; it's out")
	mz._hunting = false
	mz._lift_arrives()
	await wait(2.8)
	await wait(5.0)
	await shot("nightmare_begins")
	await wait(6.0)
	check(Game.zone_type == "deep", "arrived in THE DEEP")
	check(Game.mode == "game", "control in THE DEEP")
	check(Notebook.state.has("deep_watch") and Notebook.state["deep_watch"].pending, "a new line waits in the notebook")
	var deep: DeepZone = Game.zone
	Game.player.dread.set_values(30, 70)
	await wait(1.0)
	await shot("deep_arrival")

	print("== spotting the Observer (+25 DREAD)")
	var dobs: Observer = deep.observer
	Game.player.teleport(Transform3D(Basis(Vector3.UP, PI), Vector3(-6, 0.05, 12)))
	await wait(0.3)
	check(dobs.try_appear_at(Vector3(-6, 0, 3)), "observer appears where you are not looking")
	var before_dread := Game.player.dread.value()
	look_at_point(Vector3(-6, 1.2, 3))
	await wait(0.8)
	check(dobs.spotted, "observer spotted")
	check(Game.player.dread.value() - before_dread > 20.0, "spotting raised DREAD by ~25 (%.1f)" % (Game.player.dread.value() - before_dread))
	await shot("observer_spotted")
	await wait(2.6)
	check(not dobs.is_present(), "he glitched away within a couple of seconds")
	Game.player.dread.set_values(30, 70)

	print("== swimming")
	deep.main_level = DeepZone.REST
	Game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(90)), Vector3(-10, -1.9, 0)))
	Input.action_press("crouch")   # dive
	await wait(1.2)
	check(Game.player.swimming and Game.player.underwater, "swimming underwater")
	check(Game.player.breath < 1.0, "holding breath (%.2f)" % Game.player.breath)
	await shot("underwater")
	Input.action_release("crouch")
	await wait(2.0)
	check(Game.player.swimming and not Game.player.underwater, "floated back up to the surface")

	print("== the tunnel")
	Game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(90)), Vector3(-25.2, -1.7, 0)))
	await wait(2.5)
	check(Game.player.global_position.x > 32.0, "the tunnel surfaced in the pump room (x=%.1f)" % Game.player.global_position.x)

	print("== the drain")
	check(Game.has_flag("deep_in_pump") and objective_done("Get into the PUMP ROOM"), "objective: got into the pump room")
	use("DRAIN lever (no handle)")
	check(not deep.lever_pulled and Game.has_flag("deep_saw_lever"), "the lever has no handle")
	check(use("Take the lever handle"), "found the handle at the bottom of the pool")
	check(use("Fit the handle"), "fitted the handle")
	check(use("Pull the DRAIN lever") and deep.lever_pulled, "pulled the drain lever")
	deep.drain_rate_override = 12.0
	Game.player.teleport(Transform3D(Basis(), Vector3(33.6, 0.05, -2)))
	look_at_point(Vector3(38, 1.4, 2))
	await wait(1.5)
	check(deep.well_level > -1.0, "looking away: the water does not go down (%.1f)" % deep.well_level)
	look_at_point(Vector3(18, -1.0, 0))
	await wait(1.0)
	check(deep.well_level < -3.0, "watching: the water drains (%.1f)" % deep.well_level)
	await shot("watching_the_drain")
	await wait(3.5)
	check(deep.drained, "the deep pool is empty")
	for c in deep.get_children():
		if c is Interactable and c.get_prompt() == "Pump room door":
			c.interact()
	await wait(0.3)
	check(not deep._pump_door.visible, "the pump room door opens from inside")

	print("== the gate")
	check(use("Gate") and not Game.has_flag("deep_gate"), "the gate is padlocked")
	check(use("Locker 13") and Game.has_flag("deep_key"), "locker 13 had the key")
	check(use("Unlock the gate") and Game.has_flag("deep_gate"), "unlocked the gate")
	check(objective_done("Find the key") and objective_done("Unlock the gate"), "objectives ticked off")

	print("== down the well, into the sea")
	Game.player.teleport(Transform3D(Basis(), Vector3(18, 0.2, 2)))
	await wait(2.0)
	var mid_y := Game.player.global_position.y
	check(mid_y < -3.0 and mid_y > -29.0, "sinking down the shaft (y=%.1f)" % mid_y)
	await wait(5.0)
	check(Game.player.global_position.y < DeepZone.OCEAN_TOP, "came out into the sea (y=%.1f)" % Game.player.global_position.y)
	check(Game.player.breath > 0.99, "you can breathe in the sea")
	var f0 := Game.player.dread.fear
	look_at_point(Game.player.camera.global_position + Vector3(0.1, -5, 0))
	await wait(1.0)
	check(Game.player.dread.fear > f0 + 8.0, "looking down into the abyss fills DREAD (+%.1f)" % (Game.player.dread.fear - f0))
	Game.player.dread.set_values(20, 80)
	await shot("the_sea")
	# speed the descent up for the test
	Game.player.global_position.y = DeepZone.SEABED + 30.0
	await wait(4.0)
	check(Game.zone_type == "seabed" or Game.in_sequence, "hands from the sea floor took hold")
	await wait(4.0)
	check(Game.zone_type == "seabed", "pulled down into the second part")
	check(Game.has_flag("deep_grabbed") and Journal.is_unlocked("deep_well"), "journal entry 'The Deep End' unlocked")

	print("== the seabed")
	var sb: SeabedZone = Game.zone
	await wait(1.0)
	Game.player.manifestation.try_manifest()
	await wait(0.4)
	check(Game.player.manifestation.is_holding("flashlight"), "pictured a flashlight")
	await shot("seabed_light")
	print("== straying from the path")
	Game.player.dread.set_values(30, 70)
	Game.player.teleport(Transform3D(Basis(), Vector3(14, 0.05, -20)))
	await wait(4.0)
	check(Game.in_sequence, "the sea floor took you")
	await wait(4.0)
	check(Game._death_skippable, "seen it before: skippable")
	var ev := InputEventAction.new()
	ev.action = "jump"
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 30:
		await wait(0.5)
		if Game.zone_type == "seabed" and Game.mode == "game":
			break
	check(Game.zone_type == "seabed" and Game.mode == "game", "woke up... and back on the seabed")
	sb = Game.zone
	print("== the cave")
	Game.player.dread.set_values(30, 70)
	Game.player.teleport(Transform3D(Basis(), Vector3(-3.5, 0.05, -120)))
	await wait(0.6)
	check(sb._chase, "it is coming")
	Game.player.teleport(Transform3D(Basis(), Vector3(2, 0.05, -147)))
	await wait(1.0)
	check(sb._safe and Game.has_flag("seabed_cave"), "inside the cave")
	look_at_point(Vector3(2, 1.8, -138))
	await wait(1.2)
	await shot("it_doesnt_fit")
	var out := false
	for c in sb.get_children():
		if c is Interactable and c.get_prompt() == "Step through":
			out = true
			c.interact()
	check(out, "the glowing doorway")
	check(objective_done("Get inside the sea cave"), "seabed objectives")
	await wait(2.5)
	await _abyss()
	await wait(12.5)
	var rests = load("res://tests/realms_test.gd").new()
	add_child(rests)
	check(Game.zone_type == "rest1", "a resting place after THE DEEP")
	await rests.through_rest()
	for f in rests.failures:
		failures.append(f)
	rests.failures.clear()
	check(Game.zone_type == "compression" and Game.mode == "game", "arrived in COMPRESSION")
	check(Journal.is_unlocked("deep"), "journal entry THE DEEP unlocked")
	await _compression()
	await _above()
	# through the door in the sky: a resting place, then BLACKOUT, STILL LIFE, OPEN SPACE, PATTERN, THE QUIET
	await rests.settle()
	check(Game.zone_type == "rest2", "a resting place after ABOVE")
	await rests.through_rest()
	for f in rests.failures:
		failures.append(f)
	for k in 30:
		await wait(0.5)
		if Game.zone_type == "blackout" and Game.mode == "game" and not Game.in_sequence:
			break
	var realms = load("res://tests/realms_test.gd").new()
	add_child(realms)
	await realms.run_from("blackout")
	for f in realms.failures:
		failures.append(f)
	for e in ["blackout", "stilllife", "openspace", "pattern"]:
		check(Journal.is_unlocked(e), "journal entry %s unlocked" % e)
	for k in 40:
		await wait(0.5)
		if Game.title_preview and Game.hud.menu_open():
			break
	check(Journal.is_unlocked("quiet"), "journal entry THE QUIET unlocked")
	check(Game.title_preview and Game.hud.menu_open(), "the end of the build: back to the title")
	for e in ["video", "summer", "maze"]:
		check(Journal.is_unlocked(e), "journal entry %s unlocked" % e)

	print("== continue from checkpoint")
	Game.continue_game()
	await wait(1.0)
	check(Game.zone_type == "quiet", "continue restores THE QUIET checkpoint")
	await _deaths()

	if failures.is_empty():
		print("FLOW TEST PASSED")
	else:
		print("FLOW TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func _compression() -> void:
	var cz: CompressionZone = Game.zone
	Game.player.dread.set_values(20, 80)
	await wait(1.0)
	await shot("compression_start")
	print("== the hub; the corridor seals")
	Game.player.teleport(Transform3D(Basis(), Vector3(0.5, 0.05, -17)))
	await wait(0.5)
	check(Game.has_flag("comp_saw_box"), "found the dead elevator")
	look_at_point(Vector3(3.5, 1.4, -22))
	await wait(5.0)
	check(Game.has_flag("comp_sealed"), "the corridor behind you sealed itself")
	await shot("compression_hub")
	print("== the press")
	Game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(-90)), Vector3(8, 0.05, -18)))
	look_at_point(Vector3(14, 1.3, -18))
	await wait(1.5)
	check(cz._press_h[0] < 1.8 and cz._press_h[1] < 1.8, "walls close in when you look away (%.2f, %.2f)" % [cz._press_h[0], cz._press_h[1]])
	var h0: float = cz._press_h[0]
	look_at_point(Vector3(9, 1.3, -18 - h0))
	await wait(1.0)
	check(absf(cz._press_h[0] - h0) < 0.05, "the wall you watch stays put")
	await shot("the_press")
	check(use("Take the fuse", Vector3(13.7, 0.9, -18)), "fuse from the press")
	Game.player.teleport(Transform3D(Basis(), Vector3(0.5, 0.05, -17)))
	await wait(1.5)
	check(cz._press_h[0] > h0, "walls retreat once you're out")
	print("== the vent")
	Game.player._set_crouch(true)
	Game.player.teleport(Transform3D(Basis(), Vector3(-10.5, 0.05, -24)))
	await wait(0.5)
	Game.player._set_crouch(false)
	check(Game.player._crouched, "can't stand up inside the duct")
	await shot("the_vent")
	check(use("Take the fuse", Vector3(-6, 0.1, -29.0)), "fuse from the vent")
	Game.player._crouched = false
	print("== the drying room (walking there, so a blocked doorway shows up)")
	Game.player.dread.set_values(20, 80)
	Game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(90)), Vector3(-2.0, 0.05, -14.5)))   # facing -x
	await wait(0.3)
	Input.action_press("move_forward")
	await wait(1.6)
	Game.player.rotation.y = PI   # facing +z, down the passage
	await wait(2.2)
	Game.player.rotation.y = deg_to_rad(90)
	await wait(1.5)
	Input.action_release("move_forward")
	check(Game.player.global_position.x < -5.2 and Game.player.global_position.z > -13.0, "walked from the hub into the drying room (%s)" % Game.player.global_position)
	for f in cz._figures:
		f.global_position = f.get_meta("home")
	Game.player.dread.set_values(20, 80)
	Game.player.teleport(Transform3D(Basis(), Vector3(-6.5, 0.05, -7)))
	var fig: Node3D = cz._figures[0]
	look_at_point(fig.global_position + Vector3(0, 1.4, 0))
	await wait(2.2)   # their grace period
	var d0 := fig.global_position.distance_to(Game.player.global_position)
	look_at_point(Vector3(-2, 1.5, -7))   # away from them
	await wait(0.6)
	var d1 := fig.global_position.distance_to(Game.player.global_position)
	check(d1 < d0 - 0.4, "they come closer while you look away (%.1f -> %.1f)" % [d0, d1])
	look_at_point(fig.global_position + Vector3(0, 1.4, 0))
	await wait(0.6)
	var d2 := fig.global_position.distance_to(Game.player.global_position)
	check(absf(d2 - fig.global_position.distance_to(Game.player.global_position)) < 0.01 and d2 > 0.8, "and stop when you look")
	await shot("drying_room")
	check(use("Take the fuse", Vector3(-13.2, 0.9, -12.3)), "fuse from the drying room")
	Game.player.teleport(Transform3D(Basis(), Vector3(2.5, 0.05, -20.5)))
	await wait(0.3)
	check(Game.has_flag("comp_fuses") and Game.counters.get("fuses") == 3, "three fuses")
	print("== the freight elevator")
	check(use("Put the fuses in") and Game.has_flag("comp_power"), "power to the elevator")
	check(use("Call the elevator"), "called it")
	await wait(1.8)
	Game.player.teleport(Transform3D(Basis(), Vector3(1.0, 0.05, -23.2)))
	await wait(4.0)
	check(Game.has_flag("comp_elevator"), "riding up")
	await shot("elevator_ride")
	await wait(6.0)
	await _tenement()


func _above() -> void:
	var az: AboveZone = Game.zone
	Game.player.dread.set_values(20, 80)
	await wait(1.0)
	Game.player.teleport(Transform3D(Basis(), Vector3(0, 0.05, 1.5)))
	await wait(0.5)
	await shot("above_start")
	print("== falling")
	Game.player.teleport(Transform3D(Basis(), Vector3(0, 0.05, -9)))
	await wait(2.5)
	check(Game.in_sequence, "fell off the roof")
	for i in 40:
		await wait(1.0)
		if Game.zone_type == "above" and Game.mode == "game":
			break
	check(Game.zone_type == "above" and Game.mode == "game", "woke up... and back on the roof")
	az = Game.zone
	Game.player.dread.set_values(20, 80)
	print("== the plank")
	Game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(90)), Vector3(-12.5, 0.05, -3)))
	await wait(0.6)
	check(Game.player.global_position.y > -0.5, "the plank holds you")
	await shot("the_plank")
	check(use("Take the key"), "took the key")
	print("== the beam and the wind")
	az._gust_phase = 2
	az._gust_t = 5.0
	az._gust_dir = Vector3(0, 0, 1)
	az._gust_strength = 1.8
	check(az.wind_at(Vector3(12, 0, 0)).length() > 1.0, "gust pushes")
	Game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(-90)), Vector3(12, 0.05, 0)))
	Game.player._set_crouch(true)
	await wait(1.0)
	check(absf(Game.player.global_position.z) < 0.1 and Game.player.global_position.y > -0.5, "crouched: the wind can't move you")
	await shot("the_beam")
	Game.player._set_crouch(false)
	az._gust_phase = 0
	az._gust_t = 30.0
	Game.player.teleport(Transform3D(Basis(), Vector3(24, 0.05, 0)))
	look_at_point(Vector3(30, 1, -10))
	await wait(4.0)
	check(Game.has_flag("above_cross") and az._beam_gone, "across, and the beam is gone")
	print("== the bridge and the mast")
	check(use("Use the key") and Game.has_flag("above_bridge"), "bridge extending")
	await wait(4.5)
	Game.player.teleport(Transform3D(Basis(), Vector3(24, 0.1, -11)))
	await wait(0.8)
	check(Game.player.global_position.y > -0.5, "the bridge holds you")
	print("== the sky lift")
	Game.player.teleport(Transform3D(Basis(), Vector3(24, 0.05, -27.0)))
	await wait(0.3)
	check(use("Press the button"), "pressed the lift button")
	await wait(17.5)
	check(az._lift_at_d and Game.mode == "game" and Game.player.global_position.z < -58.0, "the lift crossed to the next tower (z=%.1f)" % Game.player.global_position.z)
	await shot("sky_lift")
	print("== the floating stairs")
	Game.player.teleport(Transform3D(Basis(), Vector3(24, 0.05, -70.8)))
	await wait(0.4)
	check(az._steps[0][2] and not az._steps[30][2], "near steps appear; far ones aren't there")
	Game.player.teleport(Transform3D(Basis(), Vector3(24, 4.1, -80.2)))
	await wait(0.6)
	check(Game.player.global_position.y > 3.5, "standing on stairs in the air (y=%.1f)" % Game.player.global_position.y)
	Game.player.teleport(Transform3D(Basis(), Vector3(24, 12.05, -99.5)))
	await wait(0.4)
	check(Game.has_flag("above_stairs"), "reached the construction site")
	print("== the crane")
	Game.player.teleport(Transform3D(Basis(), Vector3(19.0, 20.05, -112.5)))
	await wait(0.5)
	check(Game.player.global_position.y > 19.5, "up on the scaffolding")
	check(use("Swing the crane"), "swung the crane")
	await wait(13.0)
	check(not az._girder_body.get_child(0).disabled, "the girder bridges the gap")
	Game.player.teleport(Transform3D(Basis(), Vector3(19, 20.15, -116.5)))
	await wait(0.6)
	check(Game.player.global_position.y > 19.5, "the girder holds you")
	await shot("the_girder")
	print("== the skyway")
	Game.player.teleport(Transform3D(Basis(), Vector3(19, 20.05, -131)))
	await wait(0.4)
	check(az._glass_cracked, "the glass floor cracked")
	Game.player.teleport(Transform3D(Basis(), Vector3(19, 20.05, -153.5)))
	await wait(0.4)
	check(Game.has_flag("above_skyway"), "across the skyway")
	print("== the final ascent")
	Game.player.teleport(Transform3D(Basis(), AboveZone.MAST + Vector3(0, 0.05, 1.4)))
	await wait(0.3)
	check(use("Climb the ladder"), "climbing")
	await wait(9.5)
	check(Game.has_flag("above_mast") and Game.player.global_position.y > AboveZone.MAST.y + 17.0, "at the top of the mast (y=%.1f)" % Game.player.global_position.y)
	look_at_point(AboveZone.MAST + Vector3(0, AboveZone.MAST_H + 1.1, 0))
	await wait(0.5)
	await shot("the_light")
	check(use("Touch the light"), "the light")
	await wait(6.5)
	check(az._path_tiles.size() == 14, "the platform built a path into the sky")
	var last: Node3D = az._path_tiles[-1]
	Game.player.teleport(Transform3D(Basis(), last.global_position + Vector3(0, 0.6, 0)))
	await wait(0.5)
	check(Game.player.global_position.y > last.global_position.y - 0.5, "walking the path")
	await shot("the_path")
	check(use("Step through"), "the door in the sky")
	await wait(3.0)
	check(Journal.is_unlocked("above"), "journal entry ABOVE unlocked")


func _abyss() -> void:
	check(Game.zone_type == "abyss" and Game.mode == "game", "through the doorway: deeper")
	var ab: AbyssZone = Game.zone
	Game.player.dread.set_values(20, 80)
	await wait(1.0)
	await shot("abyss_start")
	print("== the flooded maze")
	check(use("Turn the valve"), "turned a valve")
	check(use("Turn the valve"), "turned the other valve")
	await wait(3.5)
	check(Game.has_flag("abyss_valves") and ab._bulkhead.position.y > 3.0, "the bulkhead opened")
	print("== the rooms")
	Game.player.teleport(Transform3D(Basis(), Vector3(0, 0.05, -40)))
	await wait(0.3)
	use("Open the door", Vector3(-2.5, 1.0, -43.8))
	await wait(1.2)
	check(Game.player.global_position.z > -38.5, "a door that opens into the same room")
	check(use("Open the door", Vector3(2.5, 1.0, -43.8)) and Game.has_flag("abyss_room1"), "the door that goes somewhere")
	Game.player.teleport(Transform3D(Basis(), Vector3(0, 0.05, -55.0)))
	await wait(0.5)
	check(Game.has_flag("abyss_room2"), "through the wall")
	Game.player.teleport(Transform3D(Basis(), Vector3(0, 0.05, -61.0)))
	await wait(0.4)
	check(ab._room3_block.visible, "looking at it: a wall")
	Game.player.rotation.y = PI
	await wait(0.4)
	check(not ab._room3_block.visible and ab._room3_door.visible, "looking away: a door")
	Game.player.teleport(Transform3D(Basis(), Vector3(0, 0.05, -65.5)))
	await wait(0.4)
	check(Game.has_flag("abyss_room3"), "backwards through the door you can't look at")
	print("== the abyssal cross")
	Game.player.teleport(Transform3D(Basis(), Vector3(0, 0.05, -74)))
	await wait(0.5)
	check(Game.has_flag("abyss_cross"), "the cross; the station's lights")
	await shot("abyss_cross")
	for id in ["S", "E", "W", "N"]:
		var post: Vector3 = ab._beacon_posts[id]
		Game.player.teleport(Transform3D(Basis(), post + (AbyssZone.CROSS - post).normalized() * 1.5 + Vector3(0, 0.05, 0)))
		await wait(0.3)
		check(use("Light the beacon", post), "lit beacon " + id)
	await wait(4.0)
	check(Game.has_flag("abyss_beacons") and ab._bridge_parts.size() > 0 and ab._bridge_parts[-1].visible, "a bridge of light")
	Game.player.teleport(Transform3D(Basis(), Vector3(0, 0.15, -135)))
	await wait(0.6)
	check(Game.player.global_position.y > -1.0, "the bridge holds you")
	print("== the station; the leviathan")
	Game.player.teleport(Transform3D(Basis(), Vector3(0, 0.05, AbyssZone.STATION_Z - 4.0)))
	await wait(0.6)
	check(Game.has_flag("abyss_station"), "something hit the station")
	Game.player.teleport(Transform3D(Basis(), Vector3(0, 0.05, AbyssZone.STATION_Z - 17.5)))
	await wait(0.6)
	check(ab._chase, "it's coming")
	await shot("abyss_chase")
	Game.player.teleport(Transform3D(Basis(), Vector3(0, 0.05, AbyssZone.EXIT_Z + 1.5)))
	await wait(0.3)
	check(use("Step through"), "the door in the cliff")


func _tenement() -> void:
	check(Game.zone_type == "tenement" and Game.mode == "game", "the elevator went up into the tenement")
	var tz: TenementZone = Game.zone
	Game.player.dread.set_values(20, 80)
	await wait(1.0)
	await shot("tenement_hall")
	print("== apartment 3B")
	Game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(90)), Vector3(-2.5, 0.05, -9)))
	await wait(0.4)
	check(Game.has_flag("ten_apartment"), "inside 3B")
	Game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(90)), Vector3(-32.5, 0.05, -9)))
	await wait(0.6)
	check(tz._obs_stage >= 1, "into the child's room")
	Game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(90)), Vector3(-39.0, 0.05, -9.0)))
	await wait(0.3)
	check(use("Pull the vent cover off") and Game.has_flag("ten_vent"), "the vent cover")
	print("== the squeeze")
	Game.player._set_crouch(true)
	Game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(90)), Vector3(-45, 0.05, -9)))
	await wait(0.5)
	check(Game.player._crouched and Game.player.global_position.y < 0.5, "crawling through the duct")
	await shot("the_squeeze")
	Game.player.teleport(Transform3D(Basis(), Vector3(-53, 0.05, -21)))
	Input.action_press("move_forward")
	await wait(3.0)
	Input.action_release("move_forward")
	check(Game.has_flag("ten_stairs"), "out into the stairwell (z=%.1f)" % Game.player.global_position.z)
	Game.player._set_crouch(false)
	print("== the stairs that don't go up")
	var O := TenementZone.O
	Game.player.teleport(Transform3D(Basis(), O + Vector3(1.0, TenementZone.STOREY + 0.05, -0.8)))
	await wait(0.3)
	check(tz._ups == 1 and tz._floor_num == 4 and absf(Game.player.global_position.y) < 0.5, "up a floor: still floor 4")
	for i in 3:
		Game.player.teleport(Transform3D(Basis(), O + Vector3(-1.0, -TenementZone.STOREY + 0.05, -0.8)))
		await wait(0.3)
	check(tz._floor_num == 7 and Game.has_flag("ten_floor7"), "down three times: floor 7")
	await shot("floor_7")
	print("== the collapse")
	Game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(-90)), Vector3(TenementZone.CORR_X0 + 2.5, 0.05, TenementZone.CORR_Z)))
	await wait(0.3)
	check(tz._collapse, "the building comes down behind you")
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await wait(2.5)
	check(not Game.in_sequence and Game.player.global_position.x > tz._front + 1.0, "outrunning it (%.1f ahead)" % (Game.player.global_position.x - tz._front))
	await shot("the_collapse")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	Game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(-90)), Vector3(TenementZone.CORR_X1 + 0.7, 0.05, TenementZone.CORR_Z)))
	await wait(0.3)
	check(Game.has_flag("ten_shaft") and not tz._collapse, "made it to the shaft")
	print("== the escape shaft")
	check(use("Climb"), "climbing the shaft")
	await wait(9.5)
	check(Game.player.global_position.y > TenementZone.SHAFT_H - 0.5, "at the top of the shaft (y=%.1f)" % Game.player.global_position.y)
	check(use("Open the door"), "the door at the top")
	await wait(14.0)
	check(Game.zone_type == "above" and Game.mode == "game", "arrived ABOVE")
	check(Journal.is_unlocked("compression"), "journal entry COMPRESSION unlocked")


## Every entity's death plays through and wakes you at the checkpoint.
func _deaths() -> void:
	for kind in ["fall", "crush", "sheet", "observer", "leviathan", "stalker", "shadow", "mannequin", "pattern"]:
		print("== death: ", kind)
		Game.player.dread.set_values(20, 80)
		var who: Node3D = null
		var fwd := -Game.player.global_transform.basis.z
		if kind == "leviathan":
			var lev := Leviathan.new()
			Game.zone.add_child(lev)
			lev.place_head(Game.player.global_position + fwd * 25.0 + Vector3(0, 3, 0), -fwd)
			who = lev
		elif kind == "mannequin":
			var m := Mannequin.new()
			Game.zone.add_child(m)
			m.build()
			m.global_position = Game.player.global_position + fwd * 2.0
			who = m
		elif kind == "sheet" or kind == "stalker":
			who = Node3D.new()
			Game.zone.add_child(who)
			who.global_position = Game.player.global_position + fwd * 2.0
		Game.entity_death(kind, who)
		await wait(0.5)
		check(Game.in_sequence, "%s: the death plays" % kind)
		await wait(5.0)
		var ev := InputEventAction.new()
		ev.action = "jump"
		ev.pressed = true
		Input.parse_input_event(ev)
		for i in 20:
			await wait(0.5)
			if Game.mode == "game" and not Game.in_sequence:
				break
		check(Game.mode == "game" and not Game.in_sequence and Game.zone_type == "quiet", "%s: woke up and back at the checkpoint" % kind)
