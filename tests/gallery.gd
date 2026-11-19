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
	Game.hud.close_menu()
	Game.enter_zone(z)
	Game.set_mode("cinematic")
	Game.hud.set_fade(0.0)
	Game.hud.clear_text()


## The hands over your face, `w` seconds after they grab (the shot is taken ~1.5 s after the view starts).
func _grab_view(w: float) -> void:
	_zone("bedroom")
	Game.set_mode("cinematic")
	_look(Vector3(0.2, 1.6, 0.8), Vector3(-1.5, 1.2, -1.5))
	await get_tree().create_timer(maxf(1.5 - w, 0.0)).timeout
	Game.player.play_shoulder_grab()
	Game.hud.panic_text("No. No. No no no no no NONO NO N-")


func _zone(z: String) -> void:
	Game.hud.close_menu()
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
		"comp_corridor": func():
			_zone("compression")
			_look(Vector3(0.5, 1.6, -4.0), Vector3(0.5, 1.4, -14)),
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
		"maze_chase": func():
			_zone("maze")
			var z: MazeZone = Game.zone
			z._open_maint()
			var at: Vector3 = z._wing_xf * Vector3(-2.0, 0, 0)
			_look(at + Vector3(0, 1.6, 0), z._wing_xf * Vector3(-8.0, 1.4, 0))
			z._hunting = true
			z._stalker.global_position = z._wing_xf * Vector3(6.0, 0, 0)
			await get_tree().process_frame
			if not z._chase_on:
				z._begin_chase()
			var c0: Vector2i = z._chase_path[0]
			var nx: Vector2i = z._chase_path[1]
			var n2: Vector2i = z._chase_path[mini(3, z._chase_path.size() - 1)]
			_look(z.cell_center(c0.x, c0.y) + Vector3(0, 1.6, 0), z.cell_center(nx.x, nx.y).lerp(z.cell_center(n2.x, n2.y), 0.6) + Vector3(0, 1.2, 0))
			await get_tree().create_timer(0.5).timeout,
		"maze_chase_back": func():
			_zone("maze")
			var z: MazeZone = Game.zone
			z._open_maint()
			var at: Vector3 = z._wing_xf * Vector3(-2.0, 0, 0)
			_look(at + Vector3(0, 1.6, 0), z._wing_xf * Vector3(-8.0, 1.4, 0))
			z._hunting = true
			var st: Vector3 = z._wing_xf * Vector3(2.2, 0, 0)
			z._stalker.global_position = st
			await get_tree().process_frame
			if not z._chase_on:
				z._begin_chase()
			z._hunting = false
			z._stalker.speed = 0.0
			z._stalker.look_at(Vector3(at.x, 0, at.z), Vector3.UP, true)
			_look(at + Vector3(0, 1.6, 0), st + Vector3(0, 1.6, 0)),
		"chase_pit": func(): await _chase_hazard("pit"),
		"chase_beam": func(): await _chase_hazard("beam"),
		"chase_debris": func(): await _chase_hazard("debris"),
		"chase_sign": func():
			var z: MazeZone = await _chase_setup()
			for i in range(1, z._chase_path.size() - 1):
				var din: Vector2i = z._chase_path[i] - z._chase_path[i - 1]
				var dout: Vector2i = z._chase_path[i + 1] - z._chase_path[i]
				if din != dout:
					var c: Vector3 = z.cell_center(z._chase_path[i - 1].x, z._chase_path[i - 1].y)
					var f := Vector3(din.x, 0, din.y)
					_look(c - f * 1.0 + Vector3(0, 1.6, 0), c + f * 6.7 + Vector3(0, 2.3, 0))
					break,
		"chase_decoy": func():
			var z: MazeZone = await _chase_setup()
			var dc: Dictionary = z._decoys[0]
			var i: int = dc.at
			z._seal_around(i)
			await get_tree().create_timer(1.0).timeout
			var c: Vector3 = z.cell_center(z._chase_path[i - 1].x, z._chase_path[i - 1].y)
			var j: Vector3 = z.cell_center(z._chase_path[i].x, z._chase_path[i].y)
			_look(c + Vector3(0, 1.6, 0) - (j - c).normalized() * 1.5, j + Vector3(0, 1.4, 0)),
		"chase_live": func():
			var z: MazeZone = await _chase_setup()
			# a straight stretch of the route: the stalker at one end, you at the other
			var ia := 3
			for i in range(3, z._chase_path.size()):
				var d1: Vector2i = z._chase_path[i] - z._chase_path[i - 1]
				var d2: Vector2i = z._chase_path[i - 1] - z._chase_path[i - 2]
				var d3: Vector2i = z._chase_path[i - 2] - z._chase_path[i - 3]
				if d1 == d2 and d2 == d3:
					ia = i
					break
			var a: Vector2i = z._chase_path[ia]
			var b: Vector2i = z._chase_path[ia - 3]
			z._chase_idx = ia
			Game.player.global_position = z.cell_center(a.x, a.y)
			z._stalker.global_position = z.cell_center(b.x, b.y)
			Game.in_sequence = false
			z._hunting = true
			_look(z.cell_center(a.x, a.y) + Vector3(0, 1.6, 0), z.cell_center(b.x, b.y) + Vector3(0, 0.9, 0))
			for k in 6:
				await get_tree().create_timer(0.1).timeout
				Game.player.global_position = z.cell_center(a.x, a.y)
				_look(z.cell_center(a.x, a.y) + Vector3(0, 1.6, 0), z._stalker.global_position + Vector3(0, 0.9, 0))
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/live_%d.png" % [dir, k])
				print("live ", k, " scramble ", z._stalker.scramble, " speed ", z._stalker.speed, " grip ", z._stalker.grip_side, " seq ", Game.in_sequence, " hunting ", z._hunting, " pos ", z._stalker.global_position)
			z._hunting = false,
		"chase_junction": func():
			var z: MazeZone = await _chase_setup()
			var dc: Dictionary = z._decoys[0]
			var i: int = dc.at
			z._chase_idx = i - 1
			var prev: Vector2i = z._chase_path[i - 1]
			var j: Vector2i = z._chase_path[i]
			var c: Vector3 = z.cell_center(prev.x, prev.y)
			var jc: Vector3 = z.cell_center(j.x, j.y)
			_look(c + Vector3(0, 1.6, 0) - (jc - c).normalized() * 1.0, jc + Vector3(0, 1.9, 0)),
		"chase_stalker": func():
			var z: MazeZone = await _chase_setup()
			z._chase_idx = 6
			var a: Vector2i = z._chase_path[6]
			var b: Vector2i = z._chase_path[9]
			var eye: Vector3 = z.cell_center(a.x, a.y) + Vector3(0, 1.6, 0)
			_look(eye, z.cell_center(b.x, b.y) + Vector3(0, 0.9, 0))
			z._hunting = false
			z._stalker.scramble = true
			z._stalker.global_position = z.cell_center(b.x, b.y)
			var tgt: Vector3 = z.cell_center(a.x, a.y)
			var run := func():
				for k in 70:
					await get_tree().process_frame
					if not is_instance_valid(z):
						return
					z._stalker.move_to(tgt + (z._stalker.global_position - tgt).normalized() * 3.0, 4.2, get_process_delta_time())
					z._stalker.grip_side = 1
			run.call(),
		"chase_bars": func():
			var z: MazeZone = await _chase_setup()
			var before: Vector2i = z._chase_path[z._chase_path.size() - 2]
			z._hunting = false
			z._chase_on = false
			z._chase_idx = z._chase_path.size() - 1
			await get_tree().process_frame
			z._update_chase(0.016)
			z._hunting = false
			z._chase_on = false
			z._bar_gate(before)
			z._stalker.global_position = z._bars_spot
			z._stalker.scramble = false
			z._stalker.grab_bars = true
			var lift: Vector3 = z.cell_center(0, 0) + Vector3(-1.2, 0, 0)
			z._stalker.look_at(Vector3(lift.x, 0, lift.z), Vector3.UP, true)
			_look(lift + Vector3(0, 1.6, 0), z._bars_spot + Vector3(0, 1.7, 0)),
		"bo_start": func():
			_zone("blackout")
			_look(Vector3(1.5, 1.6, 1.0), Vector3(0, 1.2, -30)),
		"bo_tree": func():
			_zone("blackout")
			_look(Vector3(-1.0, 1.6, -45.0), Vector3(2, 0.8, -55)),
		"bo_red": func():
			_zone("blackout")
			var z: BlackoutZone = Game.zone
			z._red_on()
			_look(Vector3(18.0, 1.6, -45.0), Vector3(17.0, 1.4, -49)),
		"bo_power": func():
			_zone("blackout")
			var z: BlackoutZone = Game.zone
			z.no_dark_death = true
			Game.player.global_position = BlackoutZone.BOX + Vector3(0, 0, 3)
			z._power_on()
			await get_tree().create_timer(4.5).timeout
			Game.hud.set_post(0.3, 0.2, 0.5, 1.0)
			_look(BlackoutZone.BOX + Vector3(3, 1.6, 4), Vector3(0, 0.5, -70)),
		"sl_start": func():
			_zone("stilllife")
			_look(Vector3(0, 1.6, -2.2), Vector3(0, 1.4, -20)),
		"sl_guard": func():
			_zone("stilllife")
			_look(Vector3(14.8, 1.6, -33.5), Vector3(17.5, 0.9, -30.6)),
		"sl_family": func():
			_zone("stilllife")
			_look(Vector3(-6.5, 6.6, -27.0), Vector3(-10.0, 5.8, -30.0)),
		"sl_lifelike": func():
			_zone("stilllife")
			_look(Vector3(0, 11.6, -16.0), Vector3(0, 11.0, -34.0)),
		"sl_escalator": func():
			_zone("stilllife")
			_look(Vector3(0, 1.6, -9.5), Vector3(0, 3.0, -20.0)),
		"os_start": func():
			_zone("openspace")
			_look(Vector3(0, 1.6, 2.0), Vector3(-10, 1.2, -60)),
		"os_road": func():
			_zone("openspace")
			Game.set_flag("os_car")
			_look(Vector3(0, 1.6, -110.0), Vector3(14, 6.0, -260)),
		"os_station": func():
			_zone("openspace")
			_look(Vector3(4, 1.6, -235.0), Vector3(14, 2.5, -262)),
		"os_plaza": func():
			_zone("openspace")
			Game.set_flag("os_plaza")
			_look(OpenSpaceZone.PLAZA + Vector3(0, 1.6, -0.5), OpenSpaceZone.PLAZA + Vector3(20, 1.0, -120)),
		"pt_platform": func():
			_zone("pattern")
			_look(Vector3(0, 1.6, -1.5), Vector3(0, 1.4, -20)),
		"pt_hive": func():
			_zone("pattern")
			_look(PatternZone.C + Vector3(0, 1.6, 3.5), PatternZone.door_point(0) + Vector3(0, 1.3, 0)),
		"pt_swarm": func():
			_zone("pattern")
			var z: PatternZone = Game.zone
			z._swarm = 3
			z._refresh_swarm()
			z._true_door = 1
			z._show_true_door()
			_look(PatternZone.C + Vector3(-2, 1.6, 3.0), PatternZone.door_point(1) + Vector3(0, 1.3, 0)),
		"pt_core": func():
			_zone("pattern")
			_look(PatternZone.CORE + Vector3(0, 1.6, 5.0), PatternZone.CORE + Vector3(0, 2.6, -8)),
		"q_waiting": func():
			_zone("quiet")
			_look(Vector3(2, 1.6, -1.0), Vector3(-2, 1.2, -11)),
		"q_flood": func():
			_zone("quiet")
			Game.zone._figures_awake = false
			_look(Vector3(0, 1.6, -26.0), Vector3(0, 1.0, -44)),
		"q_ward6": func():
			_zone("quiet")
			_look(Vector3(0.5, 1.6, -50.8), Vector3(-1.0, 1.0, -57)),
		"q_garden": func():
			_zone("quiet")
			_look(Vector3(7.5, 1.6, -45.0), Vector3(15, 1.0, -43)),
		"maze_power": func():
			_zone("maze")
			var z: MazeZone = Game.zone
			_look(z._wing_xf * Vector3(18.5, 1.62, 0.8), z._wing_xf * Vector3(22, 1.4, 0)),
		"flash_abyss": func():
			_zone("abyss")
			Game.set_mode("game")
			_look(Vector3(0, 1.6, -2.0), Vector3(0, 1.0, -12))
			Game.player.manifestation.try_manifest(),
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
		"above_down": func():
			_zone("above")
			_look(Vector3(6, 1.6, 2), Vector3(40, -50, -30)),
		"above_far": func():
			_zone("above")
			_look(Vector3(2, 1.6, -5), Vector3(19, 30, -157)),
		"above_lift": func():
			_zone("above")
			_look(Vector3(24, 1.6, -22), Vector3(24, 1.2, -40)),
		"above_stairs": func():
			_zone("above")
			Game.player.global_position = Vector3(24, 4.05, -80.2)
			await get_tree().physics_frame
			Game.zone._update_stairs(Vector3(24, 4.0, -80.2))
			_look(Vector3(24, 5.7, -79.0), Vector3(24, 6, -86)),
		"above_site": func():
			_zone("above")
			_look(Vector3(24, 13.6, -97.0), Vector3(24, 16, -110)),
		"above_crane": func():
			_zone("above")
			Game.zone._swing_jib(true)
			_look(Vector3(19, 21.6, -110), Vector3(19, 20.5, -122)),
		"above_skyway": func():
			_zone("above")
			Game.zone._swing_jib(true)
			_look(Vector3(19, 21.6, -121), Vector3(19, 21.0, -150)),
		"above_path": func():
			_zone("above")
			Game.player.global_position = AboveZone.MAST + Vector3(0, AboveZone.MAST_H + 0.05, 0)
			Game.zone._rearrange()
			await get_tree().create_timer(5.5).timeout
			_look(AboveZone.MAST + Vector3(0, AboveZone.MAST_H + 1.6, 0.8), AboveZone.MAST + Vector3(0, AboveZone.MAST_H + 4, -20)),
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
		"death_grab_a": func():
			_zone("city")
			Game.set_mode("game")
			Game._death_sequence("fade"),
		"death_grab_b": func():
			_zone("city")
			Game.set_mode("game")
			Game._death_sequence("fade"),
		"grab_1": func(): _grab_view(0.15),
		"grab_2": func(): _grab_view(0.35),
		"grab_3": func(): _grab_view(0.6),
		"grab_4": func(): _grab_view(1.0),
		"pool_climb": func():
			_zone("deep")
			Game.set_mode("game")
			Game.player.set_locked(false)
			Game.player.global_position = Vector3(-8, -1.2, 7.2)
			Game.player.rotation.y = PI,
		"gloves_maze": func():
			_zone("maze")
			Game.set_mode("game")
			_look(Game.zone.player_start().origin + Vector3(0, 1.6, 0), Game.zone.player_start().origin + Vector3(0, 1.0, -3)),
		"gloves_deep": func():
			_zone("abyss")
			Game.set_mode("game")
			_look(Vector3(0, 1.6, -38), Vector3(0, 1.0, -44)),
		"gloves_comp": func():
			_zone("tenement")
			Game.set_mode("game")
			_look(Vector3(-4, 1.6, -8), Vector3(-5, 0.9, -11.5)),
		"gloves_above": func():
			_zone("above")
			Game.set_mode("game")
			_look(Vector3(0, 1.6, 1.5), Vector3(0, 1.0, -3)),
		"title": func():
			Game.show_title(),
		"pause": func():
			_zone("city")
			Game.set_mode("game")
			_look(Vector3(2, 1.7, 6), Vector3(0, 1.5, -10))
			Game._last_corrupted = 1e9
			Game.open_pause(),
		"maze_door_open": func():
			_zone("maze")
			var z: MazeZone = Game.zone
			z._open_maint()
			(z._maint_door.get_node("Leaf") as Node3D).rotation_degrees.y = 100.0
			var c: Vector3 = z.exit_position()
			var inw: Vector3 = z.exit_inward()
			_look(c + inw * 3.2 + Vector3(0.9, 1.6, 0.9), c + Vector3(0, 1.1, 0) - inw * 1.5),
		"maze_shutter": func():
			_zone("maze")
			var z: MazeZone = Game.zone
			z._open_escape()
			z._shutter.position.y += 2.45
			(z._escape_door.get_node("Leaf") as Node3D).rotation_degrees.y = 100.0
			_look(z._wing_xf * Vector3(17.5, 1.62, -1.0 * z._side), z._wing_xf * Vector3(20.2, 1.2, 4.0 * z._side)),
		"scare": func():
			_zone("maze")
			Game.hud.jumpscare(4.0),
		"settings": func():
			_zone("bedroom")
			Game.set_mode("menu")
			Game.hud._settings(func(): pass),
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
			await views[name].call()
			if name == "death_hands" or name == "above_path":
				await get_tree().create_timer(6.6).timeout
			if name == "death_grab_a":
				await get_tree().create_timer(6.05).timeout
			if name == "death_grab_b":
				await get_tree().create_timer(6.75).timeout
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


func _chase_setup() -> MazeZone:
	_zone("maze")
	var z: MazeZone = Game.zone
	z._open_maint()
	var at: Vector3 = z._wing_xf * Vector3(-2.0, 0, 0)
	_look(at + Vector3(0, 1.6, 0), z._wing_xf * Vector3(-8.0, 1.4, 0))
	z._hunting = true
	z._stalker.global_position = z._wing_xf * Vector3(14.0, 0, 0)
	await get_tree().process_frame
	if not z._chase_on:
		z._begin_chase()
	z._hunting = false
	for h in z._hazards:
		z._build_hazard(h, 0.0)
	return z


func _chase_hazard(kind: String) -> void:
	var z: MazeZone = await _chase_setup()
	for h in z._hazards:
		if h.kind == kind:
			z._chase_idx = h.idx
			var al: Vector3 = h.along
			_look(h.c - al * 4.2 + Vector3(0, 1.6, 0), h.c + al * 2.0 + Vector3(0, 0.6 if kind == "pit" else 1.2, 0))
			return
