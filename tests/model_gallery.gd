extends Node3D
## A studio gallery of the Blender models: each on a turntable-grey floor, lit, labelled, a few per image.
##   xvfb-run godot --path . res://tests/model_gallery.tscn -- outdir

const PAGES := [
	["resting place", [["music_box", 6.0], ["pill_bottle", 9.0], ["pill", 25.0], ["shelf_white", 0.7], ["armchair", 1.0], ["bed_white", 0.5], ["table_lamp", 1.6], ["side_table", 1.3], ["flower_vase", 1.8], ["rug_round", 0.45]]],
	["houses", [["house_a", 0.09], ["house_b", 0.09], ["house_white", 0.09]]],
	["blackout", [["fence_panel", 0.45], ["gate_arch", 0.38], ["utility_pole", 0.14], ["mailbox", 0.9], ["manhole", 1.3], ["grass_tall", 0.9]]],
]


func _ready() -> void:
	Game.boot(self)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	Game.hud.close_menu()
	Game._stop_title()
	Game._leave_zone()
	Game.set_mode("cinematic")
	Game.hud.set_gameplay_visible(false)
	Game.hud.set_fade(0.0)
	var out: String = OS.get_cmdline_user_args()[0]
	var page_i := 0
	for page in PAGES:
		var root := Node3D.new()
		add_child(root)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.16, 0.17, 0.19)
		env.environment.ambient_light_color = Color(0.75, 0.77, 0.8)
		env.environment.ambient_light_energy = 0.7
		env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		root.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-40, 35, 0)
		sun.light_energy = 1.3
		sun.shadow_enabled = true
		root.add_child(sun)
		var items: Array = page[1]
		var cols := 4 if items.size() > 6 else 3
		for i in items.size():
			var slot: String = items[i][0]
			var n := Props.instance(slot)
			if n == null:
				continue
			# fit it into a 1 m cell, on the floor
			var cell := Vector3((i % cols) * 1.3, 0, (i / cols) * 1.5)
			n.scale = Vector3.ONE * float(items[i][1])
			root.add_child(n)
			var bb := Models.bounds(n)
			n.position = cell - Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
			n.rotation_degrees.y = -30.0
			var lb := Label3D.new()
			lb.text = slot
			lb.font_size = 40
			lb.pixel_size = 0.0025
			lb.position = cell + Vector3(0, -0.02, 0.62)
			lb.rotation_degrees.x = -90.0
			lb.modulate = Color(0.9, 0.9, 0.9)
			root.add_child(lb)
			var pad := MeshInstance3D.new()
			pad.mesh = CylinderMesh.new()
			pad.mesh.top_radius = 0.6
			pad.mesh.bottom_radius = 0.6
			pad.mesh.height = 0.02
			pad.position = cell + Vector3(0, -0.012, 0)
			root.add_child(pad)
		var rows := ceili(items.size() / float(cols))
		var cam := Camera3D.new()
		root.add_child(cam)
		var mid := Vector3((cols - 1) * 1.3 * 0.5, 0.3, (rows - 1) * 1.5 * 0.5)
		cam.position = mid + Vector3(0, 2.6 + rows * 0.9, 2.4 + rows * 1.1)
		cam.look_at(mid)
		cam.fov = 50.0
		cam.current = true
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/gallery_%d.png" % [out, page_i])
		page_i += 1
		root.queue_free()
		await get_tree().process_frame
	get_tree().quit()
