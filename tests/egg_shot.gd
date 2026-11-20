extends Node3D
## The bedroom after you die, with the one-in-ten monitor forced on: a screenshot.
##   xvfb-run godot --path . res://tests/egg_shot.tscn -- out.png

func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	Game.hud.close_menu()
	Game._stop_title()
	Game._leave_zone()
	await get_tree().process_frame
	var b := BedroomZone.new()
	b.waking = true
	b.egg_chance = 1.0
	Game.zone = b
	Game.main.add_child(b)
	b.build()
	b.finish_batches()
	Game.set_mode("game")
	Game.hud.set_fade(0.0)
	Game.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(90)), Vector3(-1.3, 0.05, -0.8)))
	Game.player._pitch = deg_to_rad(-12)
	Game.player.head.rotation.x = Game.player._pitch
	await get_tree().create_timer(1.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
