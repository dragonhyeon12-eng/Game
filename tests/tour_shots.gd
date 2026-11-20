extends Node3D
## Screenshots of places: zone, position, yaw, pitch.   xvfb-run godot --path . res://tests/tour_shots.tscn -- outdir set
const SETS := {
	"mall": [["stilllife", Vector3(0, 0.05, -1.5), 0.0, -2.0, "mall_entrance"], ["stilllife", Vector3(-3.5, 0.05, -20.0), 70.0, -4.0, "mall_windows"],
		["stilllife", Vector3(-4.6, 0.05, -14.5), 90.0, -6.0, "mall_window_close"], ["stilllife", Vector3(-5.0, 0.05, -36.5), 90.0, -8.0, "mall_family"],
		["stilllife", Vector3(0, 0.05, -70.0), 0.0, 4.0, "mall_escalators"], ["stilllife", Vector3(0, 5.05, -96.5), 0.0, -3.0, "mall_gallery"]],
	"cave": [["seabed", Vector3(2, 0.05, -128.0), 0.0, 4.0, "cave_mouth"], ["seabed", Vector3(2.5, 0.05, -150.0), 0.0, 0.0, "cave_tunnel"],
		["seabed", Vector3(2, 0.05, -172.0), 0.0, 3.0, "cave_chamber"]],
}


func _ready() -> void:
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
		var pl: Player = Game.player
		pl.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(spec[2])), spec[1]))
		pl._pitch = deg_to_rad(spec[3])
		pl.head.rotation.x = pl._pitch
		pl.dread.set_values(0.0, 100.0)
		await get_tree().create_timer(0.8).timeout
		Game.hud.clear_text()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/" + spec[4] + ".png")
	get_tree().quit()
