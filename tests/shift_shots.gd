extends Node3D
## THE SHIFT: before / after screenshots (look at a room, look away for a while, look back).
##   xvfb-run godot --path . res://tests/shift_shots.tscn -- outdir

func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/" + name + ".png")


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	Game.start_prototype()
	await get_tree().create_timer(2.0).timeout
	Game.hud.clear_text()
	var z: ShiftZone = Game.zone
	var pl: Player = Game.player
	# stand in the middle of the first room, looking east through whatever is there
	pl.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(-90)), ShiftZone.center(0, 0) + Vector3(-2.5, 0.05, 0)))
	await get_tree().create_timer(1.0).timeout
	var seen := 0
	for r in ShiftZone.N:
		for c in ShiftZone.N:
			if z.seg_visible(z.segment(c, r)):
				seen += 1
	print("rooms in view: %d" % seen)
	await _shot("shift_1_before")
	pl.rotation.y += PI
	z.speed = 1.0
	for s in [8.0, 15.0, 22.0]:
		pass
	await get_tree().create_timer(16.0).timeout
	Game.hud.clear_text()
	pl.rotation.y -= PI
	await get_tree().create_timer(0.3).timeout
	await _shot("shift_2_after16s")
	pl.rotation.y += PI
	await get_tree().create_timer(16.0).timeout
	Game.hud.clear_text()
	pl.rotation.y -= PI
	await get_tree().create_timer(0.3).timeout
	await _shot("shift_3_after32s")
	print(z.stats)
	get_tree().quit()
