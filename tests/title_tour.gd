extends Node3D
## Boots to the title and photographs each stop of the backdrop tour (needs a display).
##   godot --path . res://tests/title_tour.tscn -- <out_dir>

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	Game.boot(self)
	await get_tree().create_timer(4.0).timeout
	for i in Game.TITLE_TOUR.size():
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/tour_%d_%s.png" % [out, i, Game.zone_type])
		print("tour ", i, " ", Game.zone_type, " in_sequence=", Game.in_sequence, " mode=", Game.mode, " text='", Game.hud._thought.text, "'")
		await get_tree().create_timer(Game.TITLE_SHOT_SECONDS + 1.0).timeout
	Game.start_new_game()
	await get_tree().create_timer(3.0).timeout
	print("after NEW GAME: zone=", Game.zone_type, " mode=", Game.mode, " title_preview=", Game.title_preview, " in_sequence=", Game.in_sequence)
	get_tree().quit()
