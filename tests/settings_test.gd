extends Node3D
## The settings menu, used the way a phone does: tapping the < > arrow buttons, tapping a row, scrolling.
##   godot --path . --resolution 844x390 res://tests/settings_test.tscn -- <out_dir>   (needs a display for the screenshot)
var failures: Array[String] = []

func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()

func check(c: bool, what: String) -> void:
	print("  ok   " if c else "  FAIL ", what)
	if not c: failures.append(what)

func click(at: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		get_viewport().push_input(e, true)
		await get_tree().process_frame

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	Settings.set_value("master_volume", 0.8)
	Settings.set_value("epilepsy_safe", false)
	Game.hud._settings(func(): pass)
	await get_tree().create_timer(0.5).timeout
	var menu: DPMenu = Game.hud.find_children("*", "DPMenu", true, false)[0] if not Game.hud.find_children("*", "DPMenu", true, false).is_empty() else null
	var rows := {}
	for b in menu._buttons:
		rows[b.text] = b
	var vol: Button = null
	var epi: Button = null
	for t in rows:
		if t.begins_with("Master volume"): vol = rows[t]
		if t.begins_with("Epilepsy-safe mode"): epi = rows[t]
	var arrows := vol.get_parent().get_children().filter(func(c): return c is Button and c != vol)
	check(arrows.size() == 2, "Master volume has two arrow buttons")
	await click(arrows[0].get_global_rect().get_center())
	check(is_equal_approx(Settings.master_volume, 0.7), "tap <: volume down to 70%% (%.2f)" % Settings.master_volume)
	await click(arrows[1].get_global_rect().get_center())
	await click(arrows[1].get_global_rect().get_center())
	check(is_equal_approx(Settings.master_volume, 0.9), "tap > twice: 90%% (%.2f)" % Settings.master_volume)
	await click(epi.get_global_rect().get_center())
	check(Settings.epilepsy_safe and epi.text.ends_with("ON"), "tap the row: epilepsy-safe mode ON (%s)" % epi.text)
	check(Settings.visual() == 0.0 and not Settings.flashing_ok(), "...and nothing may flash")
	var epi_arrows := epi.get_parent().get_children().filter(func(c): return c is Button and c != epi)
	await click(epi_arrows[0].get_global_rect().get_center())
	check(not Settings.epilepsy_safe, "tap < on it: OFF again")
	# the last row is reachable: scroll down
	var scroll: ScrollContainer = menu.find_children("*", "ScrollContainer", true, false)[0]
	scroll.scroll_vertical = 10000
	await get_tree().process_frame
	await get_tree().process_frame
	var last: Button = menu._buttons[-1]
	var vis := get_viewport().get_visible_rect().has_point(last.get_global_rect().get_center())
	check(vis, "scrolled down, BACK is on screen")
	scroll.scroll_vertical = 0
	await get_tree().process_frame
	if out != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/settings.png")
	Settings.set_value("master_volume", 0.8)
	print("SETTINGS TEST PASSED" if failures.is_empty() else "SETTINGS TEST FAILED: %s" % [failures])
	get_tree().quit()
