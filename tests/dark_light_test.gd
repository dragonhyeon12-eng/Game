extends Node3D
## The flashlight in the dark realms: COMPRESSION (basement and tenement) and BLACKOUT let you picture
## it (a weaker one), and in BLACKOUT it holds the dark off for longer - not for ever.
##   godot --headless --path . res://tests/dark_light_test.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	for z in ["compression", "tenement", "blackout"]:
		Game.hud.close_menu()
		Game.enter_zone(z)
		Game.set_mode("game")
		await get_tree().create_timer(0.5).timeout
		var pl: Player = Game.player
		check(pl.manifestation.try_manifest() and pl.manifestation.is_holding("flashlight"), "%s: you can picture a flashlight" % z)
		var beam: SpotLight3D = pl.manifestation.held.find_children("*", "SpotLight3D", true, false)[0]
		check(beam.light_energy < 12.0 * 0.5, "%s: a weak one (energy %.1f)" % [z, beam.light_energy])
		pl.manifestation.clear_all()
	# BLACKOUT: stand in the dark with and without it
	var bz: BlackoutZone = Game.zone
	var pl2: Player = Game.player
	var dark_spot := Vector3(-30, 0.05, 30)
	pl2.teleport(Transform3D(Basis(), dark_spot))
	await get_tree().physics_frame
	if bz._lit(pl2.global_position):
		print("  (spot is lit - skipping the dark timing check)")
	else:
		bz._dark_t = 0.0
		await get_tree().create_timer(2.0).timeout
		var bare := bz._dark_t
		bz._dark_t = 0.0
		pl2.manifestation.try_manifest()
		await get_tree().create_timer(2.0).timeout
		var lit := bz._dark_t
		check(lit > 0.0 and lit < bare * 0.5, "BLACKOUT: with the light, the dark creeps up slower (%.2f vs %.2f in 2 s)" % [lit, bare])
	print("DARK LIGHT TEST PASSED" if failures == 0 else "DARK LIGHT TEST FAILED (%d)" % failures)
	get_tree().quit(failures)
