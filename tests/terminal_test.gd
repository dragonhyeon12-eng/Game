extends Node3D
## Settings > TERMINAL: it lists every level, and each one starts you there (playing, on solid ground).
##   godot --headless --path . res://tests/terminal_test.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	Game.hud._settings(func(): pass)
	var settings: DPMenu = Game.hud.find_children("*", "DPMenu", true, false).back()
	var term := settings._items.filter(func(it): return it.get("label", "") == "TERMINAL")
	check(term.size() == 1, "Settings has a TERMINAL item")
	term[0].action.call()
	await get_tree().process_frame
	var tm: DPMenu = Game.hud.find_children("*", "DPMenu", true, false).back()
	var loads := tm._items.filter(func(it): return String(it.get("label", "")).begins_with("> load"))
	check(loads.size() == Game.TITLE_TOUR.size() + 1, "it lists every level (%d)" % loads.size())
	for i in Game.TITLE_TOUR.size():
		var z: String = Game.TITLE_TOUR[i][0]
		loads[i].action.call()
		await get_tree().create_timer(2.0).timeout
		check(Game.zone_type == z and Game.mode == "game" and not get_tree().paused, "%s: started there, playing" % z)
		check(Game.player.global_position.y > -2.0, "%s: on solid ground (y %.1f)" % [z, Game.player.global_position.y])
		check(Game.has_checkpoint() and JSON.parse_string(FileAccess.get_file_as_string(Game.SAVE_PATH)).zone == z, "%s: the save starts from there" % z)
		# back to the terminal for the next one (from the pause menu, the way a player would)
		Game.hud._settings(func(): pass)
		settings = Game.hud.find_children("*", "DPMenu", true, false).back()
		settings._items.filter(func(it): return it.get("label", "") == "TERMINAL")[0].action.call()
		await get_tree().process_frame
		tm = Game.hud.find_children("*", "DPMenu", true, false).back()
		loads = tm._items.filter(func(it): return String(it.get("label", "")).begins_with("> load"))
	print("TERMINAL TEST PASSED" if failures == 0 else "TERMINAL TEST FAILED (%d)" % failures)
	get_tree().quit(failures)
