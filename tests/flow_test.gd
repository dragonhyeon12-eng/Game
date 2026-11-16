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
	check(Game.zone_type == "bedroom", "title shows over the bedroom")
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

	print("== sleep -> summer city")
	Game.request_sleep()
	await wait(10.5)
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
	Game.player.teleport(Transform3D(Basis(), Vector3(16, CityZone.CURB, -21)))
	# put him back at his first spot (rule breaks above may have moved him somewhere out of sight)
	obs._pending_move = false
	obs.global_position = Vector3(69.75, CityZone.CURB, -27.8)
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
	await wait(7.3)
	await shot("death_hands")
	await wait(4.0)
	await shot("death_card")
	await wait(8.0)
	check(Game.zone_type == "maze" and Game.mode == "game", "back at the maze checkpoint")
	check(absf(Game.player.dread.fear - 30.0) < 6.0, "fear reset to ~30")

	print("== maze exit")
	var exit_found := false
	for c in Game.zone.get_children():
		if c is Interactable and c.get_prompt() == "Open the door":
			exit_found = true
			c.interact()
	check(exit_found, "exit door exists")
	await wait(7.0)
	await shot("slice_end")
	await wait(8.5)
	check(Game.zone_type == "bedroom" and Game.hud.menu_open(), "returned to title")

	print("== continue from checkpoint")
	Game.continue_game()
	await wait(1.0)
	check(Game.zone_type == "maze", "continue restores the maze")
	check(Notebook.build_page().size() == 5 and Notebook.state["never_twice"].pending, "notebook restored from save (rule 6 still pending)")

	if failures.is_empty():
		print("FLOW TEST PASSED")
	else:
		print("FLOW TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
