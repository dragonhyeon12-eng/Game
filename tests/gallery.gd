extends Node3D
## Renders a set of viewpoints for visual review.
##   godot --path . res://tests/gallery.tscn -- /output/folder [view names...]

var dir := ""


func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func _shot(name: String) -> void:
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("shot ", name)


func _look(from: Vector3, at: Vector3) -> void:
	var pl := Game.player
	pl.global_position = from - Vector3(0, Player.EYE_HEIGHT, 0)
	var d := (at - from).normalized()
	pl.rotation.y = atan2(-d.x, -d.z)
	pl._pitch = asin(clampf(d.y, -1, 1))
	pl.head.rotation.x = pl._pitch


func _zone(z: String) -> void:
	Game.enter_zone(z)
	Game.set_mode("cinematic")
	Game.hud.set_fade(0.0)
	Game.hud.clear_text()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	dir = args[0]
	var only := args.slice(1)
	await get_tree().create_timer(1.0).timeout
	Game.hud.close_menu()
	var views := {
		"bedroom": func():
			_zone("bedroom")
			_look(Vector3(-0.6, 1.6, 0.6), Vector3(-2.4, 1.0, -0.9)),
		"bedroom_door": func():
			_zone("bedroom")
			_look(Vector3(0.0, 1.6, -0.5), Vector3(1.5, 1.0, 2.2)),
		"city": func():
			_zone("city")
			_look(Vector3(-13.5, 1.8, 0), Vector3(0, 1.0, 0)),
		"city_people": func():
			_zone("city")
			_look(Vector3(-6.5, 1.7, -1.0), Vector3(-9, 0.9, 2.0)),
		"mina": func():
			_zone("city")
			_look(Vector3(2.4, 1.6, -7.4), Vector3(2.4, 1.35, -10.4)),
		"face": func():
			_zone("city")
			_look(Vector3(2.4, 1.55, -9.3), Vector3(2.4, 1.5, -10.4)),
		"face_side": func():
			_zone("city")
			_look(Vector3(1.0, 1.4, -9.0), Vector3(2.4, 1.2, -10.4)),
		"observer": func():
			_zone("maze")
			var obs: Observer = Game.zone.observer
			obs.try_appear_at(Vector3(10, 0, 0))
			obs._glitch = 0.5
			_look(Vector3(5, 1.6, 0), Vector3(10, 1.4, 0)),
		"theo": func():
			_zone("city")
			_look(Vector3(9.0, 1.4, 12.0), Vector3(9.5, 0.8, 9.5)),
		"maze": func():
			_zone("maze")
			_look(Vector3(0, 1.6, 0) , Vector3(5, 1.4, 0)),
		"maze_exit": func():
			_zone("maze")
			var ex: Vector3 = Game.zone.exit_position()
			var inward: Vector3 = Game.zone.exit_inward()
			_look(ex + inward * 3.5 + Vector3(0, 1.6, 0), ex + Vector3(0, 1.4, 0)),
		"deep": func():
			_zone("deep")
			var xf: Transform3D = Game.zone.player_start()
			_look(xf.origin + Vector3(0, 1.6, 0), xf.origin + Vector3(0, 1.4, 0) - xf.basis.z * 10.0),
		"deep_pool": func():
			_zone("deep")
			_look(Vector3(0, 3.0, 12), Vector3(5, -1.0, 0)),
		"deep_under": func():
			_zone("deep")
			_look(Vector3(-5, -1.2, 2), Vector3(-19, -1.5, 0)),
		"hands": func():
			_zone("bedroom")
			Game.set_mode("game")
			_look(Vector3(-0.6, 1.6, 0.6), Vector3(-2.4, 1.0, -0.9)),
		"hands_hold": func():
			_zone("city")
			Game.set_mode("game")
			_look(Vector3(-10, 1.7, 0), Vector3(0, 1.5, 0))
			Game.player.manifestation.try_manifest(),
		"hands_conjure": func():
			_zone("city")
			Game.set_mode("game")
			_look(Vector3(-10, 1.7, 0), Vector3(0, 1.5, 0))
			Game.player.manifestation.clear_all()
			Game.player.manifest_hold = 0.0
			Game.player.hands.conjuring = true,
	}
	for name in views:
		if only.is_empty() or only.has(name):
			views[name].call()
			await _shot(name)
	get_tree().quit()
