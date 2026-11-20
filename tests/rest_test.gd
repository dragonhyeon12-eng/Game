extends Node3D
## The resting places: take the pills and the music box, use them (a pill stops fear building for 10 s;
## the music box takes the fear away), and the glowing doorway leads on. With an output dir (and a
## display), screenshots of each room and of the items in use.
##   xvfb-run godot --path . res://tests/rest_test.tscn -- [outdir]

var failures := 0
var out := ""


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func shot(name: String) -> void:
	if out == "":
		return
	Game.hud.clear_text()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")


func use(prompt: String) -> bool:
	for it in Game.zone.find_children("*", "Interactable", true, false):
		if it.get_prompt() == prompt:
			it.interact()
			return true
	return false


func _run() -> void:
	out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	await get_tree().create_timer(1.0).timeout
	for r in ["rest1", "rest2", "rest3"]:
		Game.hud.close_menu()
		Game._reset_world()
		Game.enter_zone(r)
		Game.set_mode("game")
		Game.hud.set_fade(0.0)
		await get_tree().create_timer(1.5).timeout
		check(Game.zone_type == r and Game.player.is_on_floor(), "%s: standing in the room" % r)
		await shot(r + "_view")
		var pl: Player = Game.player
		pl.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(180)), Vector3(-1.6, 0.05, 1.6)))
		pl._pitch = deg_to_rad(-20)
		pl.head.rotation.x = pl._pitch
		await get_tree().create_timer(0.5).timeout
		await shot(r + "_shelf")
		var took := 0
		while use("Take a pill"):
			took += 1
			await get_tree().process_frame
		check(took >= 3 and took <= 4 and Game.items.count("pills") == took, "%s: %d pills on the shelf, all taken" % [r, took])
		check(use("Take the music box") and Game.items.count("music_box") == 1, "%s: took the music box" % r)
		if r != "rest1":
			continue
		# the pill: fear can't climb for 10 s
		pl.dread.set_values(30.0, 70.0)
		Game.items.use("pills")
		await get_tree().create_timer(0.5).timeout
		await shot("pill_in_use")
		await get_tree().create_timer(1.0).timeout
		check(pl.dread.calm_left() > 7.0, "a pill: calm for %.1f s more" % pl.dread.calm_left())
		var f := pl.dread.fear
		pl.dread.add_fear(30.0, "test")
		check(pl.dread.fear <= f + 0.01, "a scare while calm adds nothing (%.0f -> %.0f)" % [f, pl.dread.fear])
		await get_tree().create_timer(9.5).timeout
		pl.dread.add_fear(10.0, "test")
		check(pl.dread.fear > f + 5.0 - 6.0 * 10.0 or pl.dread.fear >= 9.0, "after 10 s, fear can climb again (%.0f)" % pl.dread.fear)
		# the music box: from terrified to calm
		pl.dread.set_values(85.0, 20.0)
		Game.items.use("music_box")
		await get_tree().create_timer(2.6).timeout
		await shot("music_box_in_use")
		await get_tree().create_timer(6.0).timeout
		check(pl.dread.value() < 10.0 and Game.items.count("music_box") == 0, "the music box: DREAD %.0f, and it's gone" % pl.dread.value())
		# and out through the doorway
		check(use("Go on"), "the glowing doorway")
		var w := 0.0
		while Game.zone_type != "compression" and w < 20.0:
			await get_tree().create_timer(0.5).timeout
			w += 0.5
		check(Game.zone_type == "compression", "...leads on to COMPRESSION")
		check(Game.items.count("pills") >= 2, "the pills came with you (%d)" % Game.items.count("pills"))
	print("REST TEST PASSED" if failures == 0 else "REST TEST FAILED (%d)" % failures)
	get_tree().quit(failures)
