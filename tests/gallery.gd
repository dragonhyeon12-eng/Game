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


func _zone_t(z: String) -> void:
	Game.enter_zone(z)
	Game.set_mode("cinematic")
	Game.hud.set_fade(0.0)
	Game.hud.clear_text()


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
		"feet_beam": func():
			_zone("above")
			Game.set_mode("game")
			_look(Vector3(11, 1.62, 0), Vector3(11.4, 0, -0.2)),
		"feet_walk": func():
			_zone("deep")
			Game.set_mode("game")
			_look(Vector3(-6, 1.62, 15), Vector3(-6, 0, 13.6))
			Input.action_press("move_forward"),
		"swim_view": func():
			_zone("deep")
			Game.set_mode("game")
			_look(Vector3(-10, 0.3, 2), Vector3(-10, -0.6, -3))
			Input.action_press("move_forward"),
		"body_3p": func():
			_zone("deep")
			Game.set_mode("game")
			_look(Vector3(-6, 1.62, 15), Vector3(-6, 1.62, 13))
			Input.action_press("move_forward")
			Game.player.camera.cull_mask = 0xFFFFF
			Game.player.camera.position = Vector3(-2.2, -0.5, -2.2)
			Game.player.camera.rotation_degrees = Vector3(0, -135, 0),
		"swim_3p": func():
			_zone("deep")
			Game.set_mode("game")
			_look(Vector3(-10, 0.3, 2), Vector3(-10, 0.3, -3))
			Input.action_press("move_forward")
			Game.player.camera.cull_mask = 0xFFFFF
			Game.player.camera.position = Vector3(-3.0, 0.4, 0.0)
			Game.player.camera.rotation_degrees = Vector3(-5, -90, 0),
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
		"abyss": func():
			_zone("deep")
			var z: DeepZone = Game.zone
			z.drained = true
			z.well_level = DeepZone.OCEAN_TOP
			z._well_water.visible = false
			_look(Vector3(18, 1.7, 4.5), Vector3(18, -60, -1)),
		"ocean": func():
			_zone("deep")
			Game.player.global_position = Vector3(18, -80, 0)
			_look(Vector3(18, -78, 0), Vector3(70, -100, 30)),
		"ocean_down": func():
			_zone("deep")
			_look(Vector3(18, -60, 0), Vector3(30, -170, 10)),
		"seabed": func():
			_zone("seabed")
			Game.set_mode("game")
			_look(Vector3(0, 1.6, 4), Vector3(4, 0.8, -14))
			Game.player.manifestation.try_manifest(),
		"lev_head": func():
			_zone("seabed")
			var z: SeabedZone = Game.zone
			z.leviathan.speed = 0.0
			z.leviathan.place_head(Vector3(0, 6, -30), Vector3(0.35, -0.05, 1))
			_look(Vector3(7, 4.5, -15), Vector3(0, 5, -32)),
		"lev_rush": func():
			_zone("seabed")
			var z: SeabedZone = Game.zone
			z.leviathan.place_head(Vector3(0, 4, -24), Vector3(0.25, 0, 1))
			z.leviathan.rush(Vector3(0, 4, -24), 0.0)
			_look(Vector3(4, 3.5, -12), Vector3(0, 3.5, -25)),
		"lev_side": func():
			_zone("deep")
			var z: DeepZone = Game.zone
			for l in z.leviathans:
				l.speed = 0.0
			z.leviathans[0].place_head(Vector3(45, -100, 0), Vector3(1, 0.05, 0))
			Game.player.global_position = Vector3(5, -100, 48)
			_look(Vector3(5, -99, 48), Vector3(5, -101, 0)),
		"cave": func():
			_zone("seabed")
			Game.set_mode("game")
			var z: SeabedZone = Game.zone
			# seen from inside the cave, looking back out at the opening
			Game.player.global_position = Vector3(2, 0, -150)
			_look(Vector3(2, 1.6, -150), Vector3(2, 2.0, -136))
			Game.player.manifestation.try_manifest()
			z.leviathan.place_head(Vector3(-10, 4, -126), Vector3(1, 0, 0))
			z.leviathan.block_at(SeabedZone.MOUTH + Vector3(0, 1.8, 3.0 + z.leviathan.thickness * 4.0)),
		"journal": func():
			for e in Data.journal:
				Journal.unlocked[e.id] = true
			Game.hud._set_menu(JournalUI.create(func(): pass)),
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
		"comp_start": func():
			_zone("compression")
			_look(Vector3(0.5, 1.6, -2.0), Vector3(0.5, 1.2, -12)),
		"comp_drying_door": func():
			_zone("compression")
			_look(Vector3(1.0, 1.6, -18.5), Vector3(-4, 1.6, -14.5)),
		"comp_hub": func():
			_zone("compression")
			_look(Vector3(2.0, 1.6, -15.0), Vector3(1.0, 1.2, -22)),
		"comp_press": func():
			_zone("compression")
			_look(Vector3(5.5, 1.6, -18.0), Vector3(14, 1.0, -18)),
		"comp_vent": func():
			_zone("compression")
			_look(Vector3(-10.5, 0.9, -18.0), Vector3(-10.5, 0.7, -28)),
		"dream_bedroom": func():
			_zone_t("bedroom_dream")
			_look(Vector3(1.2, 1.4, -0.9), Vector3(0.6, 1.4, -2.3)),
		"city_hill": func():
			_zone("city")
			_look(Vector3(0, 1.8, -8), Vector3(0, 8, -84)),
		"maze_wing": func():
			_zone("maze")
			var z: MazeZone = Game.zone
			z._open_maint()
			var p: Vector3 = z._wing_xf * Vector3(6.0, 1.62, 0.6)
			_look(p, z._wing_xf * Vector3(9.3, 1.4, -3.5)),
		"maze_power": func():
			_zone("maze")
			var z: MazeZone = Game.zone
			_look(z._wing_xf * Vector3(18.5, 1.62, 0.8), z._wing_xf * Vector3(22, 1.4, 0)),
		"abyss_maze": func():
			_zone("abyss")
			_look(Vector3(-1, 1.5, -9), Vector3(-3, 1.2, -14)),
		"abyss_rooms": func():
			_zone("abyss")
			_look(Vector3(0, 1.6, -37), Vector3(0, 1.2, -44)),
		"abyss_cross": func():
			_zone("abyss")
			for id in ["S", "N", "E", "W"]:
				Game.zone._light_beacon(id)
			_look(Vector3(0, 2.5, -74), Vector3(0, -1, -110)),
		"abyss_station": func():
			_zone("abyss")
			_look(Vector3(0, 2.0, -126), Vector3(0, 1.5, -150)),
		"ten_hall": func():
			_zone("tenement")
			_look(Vector3(0, 1.6, -1.0), Vector3(-0.4, 1.3, -12)),
		"ten_living": func():
			_zone("tenement")
			_look(Vector3(-2.0, 1.6, -7.0), Vector3(-7, 0.9, -11)),
		"ten_yellow": func():
			_zone("tenement")
			_look(Vector3(-9.6, 1.6, -9.0), Vector3(-30, 1.2, -9.0)),
		"ten_duct": func():
			_zone("tenement")
			_look(Vector3(-41.0, 0.9, -9.0), Vector3(-53, 0.6, -9.0)),
		"ten_stairs": func():
			_zone("tenement")
			var O := TenementZone.O
			_look(O + Vector3(1.4, 1.6, -0.4), O + Vector3(-1.0, 1.4, -5.5)),
		"ten_stairs_up": func():
			_zone("tenement")
			var O := TenementZone.O
			_look(O + Vector3(0.6, 1.6, -0.5), O + Vector3(1.0, 2.5, -4.0)),
		"ten_corridor": func():
			_zone("tenement")
			_look(Vector3(-49.0, 1.6, -24.8), Vector3(-10, 1.6, -24.8)),
		"ten_collapse": func():
			_zone("tenement")
			var z: TenementZone = Game.zone
			Game.player.teleport(Transform3D(Basis(), Vector3(-30, 0.05, -24.8)))
			z._begin_collapse()
			z._front = -36.0
			z._update_collapse(0.016)
			z._collapse = false
			_look(Vector3(-30, 1.6, -24.8), Vector3(-40, 1.0, -24.8)),
		"comp_sheets": func():
			_zone("compression")
			_look(Vector3(-9.2, 1.6, -12.4), Vector3(-9.6, 1.2, -4)),
		"comp_figure": func():
			_zone("compression")
			_look(Vector3(-7.6, 1.6, -8.0), Vector3(-9.0, 1.2, -5.6)),
		"comp_drying": func():
			_zone("compression")
			_look(Vector3(-5.6, 1.6, -12.0), Vector3(-12, 1.2, -7)),
		"above_start": func():
			_zone("above")
			_look(Vector3(0, 1.6, 2.0), Vector3(12, -2, -6)),
		"above_plank": func():
			_zone("above")
			_look(Vector3(-5.5, 1.6, -3.0), Vector3(-13, -1.5, -3)),
		"above_beam": func():
			_zone("above")
			_look(Vector3(7.5, 1.6, 0.0), Vector3(19, 0, 0)),
		"above_mast": func():
			_zone("above")
			_look(Vector3(24, 1.6, -3.0), Vector3(24, 6, -22)),
		"deep_gate": func():
			_zone("deep")
			_look(Vector3(7.0, 1.6, 2.5), Vector3(14, 0.5, 0)),
		"deep_locker": func():
			_zone("deep")
			_look(Vector3(-29.5, 1.6, -1.0), Vector3(-31.4, 1.2, -1.8)),
		"death_hands": func():
			_zone("city")
			Game.set_mode("game")
			Game._death_sequence("fade"),
		"pool_climb": func():
			_zone("deep")
			Game.set_mode("game")
			Game.player.set_locked(false)
			Game.player.global_position = Vector3(-8, -1.2, 7.2)
			Game.player.rotation.y = PI,
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
			if name == "death_hands":
				await get_tree().create_timer(6.6).timeout
			if name == "pool_climb":
				await get_tree().create_timer(1.5).timeout
				print("pool_climb before y=%.2f swimming=%s" % [Game.player.global_position.y, Game.player.swimming])
				Input.action_press("jump")
				await get_tree().physics_frame
				await get_tree().physics_frame
				Input.action_release("jump")
				await get_tree().create_timer(1.5).timeout
				print("pool_climb after pos=%s swimming=%s floor=%s" % [Game.player.global_position, Game.player.swimming, Game.player.is_on_floor()])
			await _shot(name)
			Input.action_release("move_forward")
	get_tree().quit()
