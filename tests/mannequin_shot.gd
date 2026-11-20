extends Node3D
## The sculpted mannequin up close, in a few poses and realism levels: screenshots.
##   xvfb-run godot --path . res://tests/mannequin_shot.tscn -- outdir

func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	Game.hud.close_menu()
	Game._stop_title()
	Game._leave_zone()
	var root := Node3D.new()
	add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.12, 0.14)
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.environment.ambient_light_energy = 0.6
	root.add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-35, 30, 0)
	root.add_child(l)
	var o := OmniLight3D.new()
	o.position = Vector3(1, 2.2, 2)
	o.omni_range = 8
	root.add_child(o)
	for i in 3:
		var m := Mannequin.new()
		m.pose = ["stand", "hip", "reach"][i]
		root.add_child(m)
		m.build(Color(0.88, 0.82, 0.76), i, 1.0)
		m.position = Vector3(-1.1 + i * 1.1, 0, 0)
	Game.set_mode("cinematic")
	Game.hud.set_fade(0.0)
	Game.hud.set_gameplay_visible(false)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 1.2, 3.6)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.current = true
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/mannequins.png")
	cam.position = Vector3(1.1, 1.75, 0.75)
	cam.look_at(Vector3(1.1, 1.72, 0))
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/mannequin_face.png")
	get_tree().quit()
