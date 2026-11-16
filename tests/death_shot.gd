extends Node3D
## Visual spot checks: the death-sequence hands and the Observer at the end of the avenue.
##   godot --path . res://tests/death_shot.tscn -- /output/folder

func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func _look(p: Vector3) -> void:
	var pl := Game.player
	var d := (p - pl.camera.global_position).normalized()
	pl.rotation.y = atan2(-d.x, -d.z)
	pl._pitch = asin(clampf(d.y, -1, 1))
	pl.head.rotation.x = pl._pitch

func _run() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	await get_tree().create_timer(1.0).timeout
	Game.hud.close_menu()
	Game.enter_zone("bedroom", false, true)
	Game.set_mode("cinematic")
	Game.hud.set_fade(0.0)
	Game.player.play_shoulder_grab()
	await get_tree().create_timer(1.5).timeout
	await _shot(dir + "/death_hands.png")
	Game.player.reset_presentation()
	Game.enter_zone("city")
	Game.set_mode("game")
	Game.player.teleport(Transform3D(Basis(), Vector3(14.0, 0.2, -20.0)))
	var obs: Observer = Game.zone.observer
	_look(obs.global_position + Vector3(0, 1.0, 0))
	await get_tree().create_timer(2.0).timeout
	print("observer at ", obs.global_position, " visible=", obs.visible, " observed=", obs.observed)
	await _shot(dir + "/observer.png")
	obs.global_position = Game.player.global_position + Vector3(6, 0, 0)
	_look(obs.global_position + Vector3(0, 1.0, 0))
	await get_tree().create_timer(1.0).timeout
	print("near observer: ", obs.global_position, " children=", obs.get_child_count(), " vis=", obs.is_visible_in_tree())
	await _shot(dir + "/observer_near.png")
	Game.enter_zone("maze")
	Game.set_mode("game")
	Game.hud.set_fade(0.0)
	await get_tree().create_timer(2.0).timeout
	await _shot(dir + "/maze_corners.png")
	get_tree().quit()
