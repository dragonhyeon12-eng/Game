extends Node3D
## Screenshots of places: zone, position, yaw, pitch.   xvfb-run godot --path . res://tests/tour_shots.tscn -- outdir set
const SETS := {
	"mall": [["stilllife", Vector3(0, 0.05, -1.5), 0.0, -2.0, "mall_entrance"], ["stilllife", Vector3(-3.5, 0.05, -20.0), 70.0, -4.0, "mall_windows"],
		["stilllife", Vector3(-4.6, 0.05, -14.5), 90.0, -6.0, "mall_window_close"], ["stilllife", Vector3(-5.0, 0.05, -36.5), 90.0, -8.0, "mall_family"],
		["stilllife", Vector3(0, 0.05, -70.0), 0.0, 4.0, "mall_escalators"], ["stilllife", Vector3(0, 5.05, -96.5), 0.0, -3.0, "mall_gallery"]],
	"blackout": [["blackout", Vector3(0, 0.05, -6.0), 0.0, 2.0, "bo_street"], ["blackout", Vector3(4.0, 0.05, -30.0), -60.0, 6.0, "bo_houses"],
		["blackout", Vector3(-3.0, 0.05, -62.0), 160.0, 6.0, "bo_poles"], ["blackout", Vector3(29.5, 0.05, -50.0), 0.0, -4.0, "bo_gate"]],
	"openspace": [["openspace", Vector3(0, 0.05, -60.0), 0.0, 3.0, "os_road"], ["openspace", Vector3(0, 0.05, -150.0), 70.0, 4.0, "os_hills"],
		["openspace", Vector3(-30, 0.05, -20.0), 120.0, 2.0, "os_carpark"], ["openspace", Vector3(5, 0.05, -230.0), 0.0, 3.0, "os_station"]],
	"bench": [["city", Vector3(-9.0, 0.3, -0.6), 0.0, -12.0, "bench_city_front"], ["city", Vector3(-7.2, 0.3, 2.0), 90.0, -10.0, "bench_city_side"],
		["quiet", Vector3(14.0, 0.05, -39.8), 0.0, -12.0, "bench_quiet_front"], ["quiet", Vector3(15.8, 0.05, -42.5), 90.0, -10.0, "bench_quiet_side"]],
	"items": [["bedroom", Vector3(-1.2, 0.05, -0.6), 90.0, -22.0, "it_desk"], ["tenement", Vector3(0, 0.05, -6.0), 0.0, -4.0, "it_doors"],
		["abyss", Vector3(-5.0, 0.05, -23.6), 0.0, 6.0, "it_valves"], ["openspace", Vector3(17.0, 0.05, -270.6), 0.0, 4.0, "it_phone"],
		["city", Vector3(-9.0, 0.6, -1.2), 0.0, -30.0, "it_pigeons"]],
	"rooms": [["bedroom", Vector3(0.3, 0.05, 1.8), 0.0, -12.0, "rm_bedroom"], ["bedroom", Vector3(0.6, 0.05, 0.2), 90.0, -16.0, "rm_desk"],
		["bedroom", Vector3(-0.4, 0.05, 0.2), -90.0, -14.0, "rm_bed"], ["city", Vector3(0, 0.3, 7.0), 0.0, -6.0, "pk_fountain"],
		["city", Vector3(2.4, 0.3, -4.5), 0.0, -8.0, "pk_cart"], ["city", Vector3(66.0, 0.3, -31.5), -90.0, -2.0, "pk_shelter"]],
	"apt": [["tenement", Vector3(-1.8, 0.05, -9.0), 80.0, -10.0, "apt_living"], ["tenement", Vector3(-6.5, 0.05, -10.5), -150.0, -8.0, "apt_living2"],
		["tenement", Vector3(-31.8, 0.05, -9.0), 80.0, -12.0, "apt_kids"], ["tenement", Vector3(-34.5, 0.05, -10.5), -60.0, -8.0, "apt_kids2"],
		["tenement", Vector3(-37.5, 0.05, -9.0), 90.0, -18.0, "apt_bath"], ["tenement", Vector3(-20.0, 0.05, -9.0), 90.0, 4.0, "apt_yellow"]],
	"skyline": [["city", Vector3(0, 0.3, 7.0), 0.0, 4.0, "sky_park"], ["city", Vector3(68.5, 0.3, 0.0), 0.0, 2.0, "sky_street"]],
	"fix": [["deep", Vector3(-29.6, 0.05, -2.6), 70.0, -6.0, "lockers_shut"], ["deep", Vector3(-29.6, 0.05, -2.6), 70.0, -6.0, "lockers_open", "open_locker"],
		["maze", Vector3.ZERO, 0.0, -5.0, "breakers_off", "breakers"], ["maze", Vector3.ZERO, 0.0, -5.0, "breakers_some_up", "flip_two"]],
	"walk": [["city", Vector3(-13.5, 0.3, 0), -90.0, 2.0, "w01_park"], ["city", Vector3(0, 0.3, -30.0), 0.0, 3.0, "w02_avenue"],
		["city", Vector3(0, 0.3, -95.0), 0.0, 3.0, "w03_mural"], ["city", Vector3(30.0, 0.3, -118.0), -60.0, 4.0, "w04_cross"],
		["city", Vector3(44.0, 0.3, -133.0), 0.0, 2.0, "w05_arcade"], ["city", Vector3(44.0, 0.3, -172.0), 0.0, -2.0, "w06_arcade_end"],
		["city", Vector3(40.0, 0.3, -184.0), -30.0, -6.0, "w07_lido"], ["city", Vector3(80.0, 0.3, -192.0), 70.0, -8.0, "w08_lido_deep"],
		["city", Vector3(54.0, 0.3, -248.0), 0.0, 12.0, "w09_steps"], ["city", Vector3(55.0, 9.3, -286.0), 0.0, -4.0, "w10_playground"],
		["city", Vector3(55.0, 9.3, -322.0), 0.0, 2.0, "w11_meadow"], ["city", Vector3(62.0, 9.3, -375.0), -10.0, 6.0, "w12_hill"]],
	"walk2": [["city", Vector3(40.0, 0.3, -184.0), -30.0, -6.0, "w07_lido"], ["city", Vector3(80.0, 0.3, -192.0), 70.0, -8.0, "w08_lido_deep"],
		["city", Vector3(55.0, 9.3, -286.0), 0.0, -4.0, "w10_playground"], ["city", Vector3(55.0, 9.3, -322.0), 0.0, 2.0, "w11_meadow"]],
	"plaza": [["city", Vector3(0, 0.2, 24.0), 0.0, 6.0, "pz1_arrival"], ["city", Vector3(0, 0.2, 24.0), 0.0, 6.0, "pz2_flowing", "fountain_on"],
		["city", Vector3(10.0, 0.2, 14.0), 35.0, 2.0, "pz3_rotunda"], ["city", Vector3(-7.0, 0.2, 13.0), 160.0, -6.0, "pz4_bench"],
		["city", Vector3(4.0, 0.2, 9.0), -10.0, 30.0, "pz5_sky"], ["city", Vector3(-6.0, 0.2, 16.0), 200.0, 14.0, "pz7_sky_s"], ["city", Vector3(0, 0.2, -24.0), 180.0, 4.0, "pz6_back"]],
	"cave": [["seabed", Vector3(2, 0.05, -128.0), 0.0, 4.0, "cave_mouth"], ["seabed", Vector3(2.5, 0.05, -150.0), 0.0, 0.0, "cave_tunnel"],
		["seabed", Vector3(2, 0.05, -172.0), 0.0, 3.0, "cave_chamber"]],
}


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--low"):
		Settings.quality = 0.0
		Settings.apply()
	Game.boot(self)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	var out: String = OS.get_cmdline_user_args()[0]
	var cur := ""
	for spec in SETS[OS.get_cmdline_user_args()[1]]:
		if spec[0] != cur:
			cur = spec[0]
			Game.hud.close_menu()
			Game.enter_zone(cur)
			Game.set_mode("game")
			Game.hud.set_fade(0.0)
			await get_tree().create_timer(1.0).timeout
			if OS.get_cmdline_user_args().has("--bright"):      # (review only: daylight on a night scene)
				for we in Game.zone.find_children("*", "WorldEnvironment", true, false):
					we.environment.ambient_light_energy = 1.4
					we.environment.ambient_light_color = Color(0.8, 0.82, 0.9)
					we.environment.background_color = Color(0.45, 0.55, 0.7)
		var pl: Player = Game.player
		var at: Vector3 = spec[1]
		var yaw: float = deg_to_rad(spec[2])
		var act: String = spec[5] if spec.size() > 5 else ""
		if act == "fountain_on":
			Game.zone._change("fountain")
			Game.zone._change("lamps")
			await get_tree().create_timer(1.0).timeout
		if act == "open_locker":
			Game.zone._open_locker(true)
		if act == "breakers" or act == "flip_two":      # stand at the maze's breaker panel, facing it
			var wx: Transform3D = Game.zone._wing_xf
			at = wx * Vector3(20.5, 0.05, 0.0)
			var d: Vector3 = wx.basis * Vector3(1, 0, 0)
			yaw = atan2(-d.x, -d.z)
			if act == "flip_two":
				Game.zone._set_breaker(Game.zone._breakers[0], true)
				Game.zone._set_breaker(Game.zone._breakers[2], true)
		pl.teleport(Transform3D(Basis(Vector3.UP, yaw), at))
		pl._pitch = deg_to_rad(spec[3])
		pl.head.rotation.x = pl._pitch
		pl.dread.set_values(0.0, 100.0)
		await get_tree().create_timer(0.8).timeout
		Game.hud.clear_text()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/" + spec[4] + ".png")
	get_tree().quit()
