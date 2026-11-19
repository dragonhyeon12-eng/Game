extends Node3D
## The flashlight on a far wall (shadow acne check): picture the light in THE DEEP's abyss rooms, aim
## it down the long way, screenshot.   xvfb-run godot --path . res://tests/flash_shot.tscn -- out.png [--low]

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--low"):
		Settings.quality = 0.0
		Settings.apply()
	Game.boot(self)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	Game.hud.close_menu()
	Game.enter_zone("abyss")
	Game.set_mode("game")
	Game.hud.set_fade(0.0)
	await get_tree().create_timer(1.0).timeout
	var pl: Player = Game.player
	pl.teleport(Transform3D(Basis(), Vector3(0, 0.05, -28.0)))   # the corridor, looking toward the rooms
	pl.manifestation.try_manifest()
	await get_tree().create_timer(2.0).timeout
	Game.hud.clear_text()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
