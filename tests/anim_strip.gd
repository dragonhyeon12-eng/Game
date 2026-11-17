extends Node3D
## Films a creature's animation as strips of frames (needs a display):
##   godot --path . res://tests/anim_strip.tscn -- <out_dir> [stalker|leviathan]
## Stalker: a side view walking and running, and a front view running. Leviathan: prints how much the head
## turns per frame while it chases a moving target (jitter check).

var out := "/tmp"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var what := args[1] if args.size() > 1 else "stalker"
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.32, 0.31, 0.27)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.78, 0.7)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.55, 0.5, 0.36)
	floor.material_override = fm
	add_child(floor)
	if what == "leviathan":
		await _leviathan()
	else:
		await _stalker()
	get_tree().quit()


func _strip(cam: Camera3D, frames: int, dt: float, name: String, follow: Node3D, offset: Vector3, look_off: Vector3) -> void:
	var imgs: Array[Image] = []
	for i in frames:
		var t := 0.0
		while t < dt:
			await get_tree().process_frame
			t += get_process_delta_time()
			cam.global_position = follow.global_position + offset
			cam.look_at(follow.global_position + look_off)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(320, 360)
		imgs.append(img)
	var sheet := Image.create(320 * frames, 360, false, imgs[0].get_format())
	for i in imgs.size():
		sheet.blit_rect(imgs[i], Rect2i(0, 0, 320, 360), Vector2i(i * 320, 0))
	sheet.save_png("%s/%s.png" % [out, name])
	print("strip ", name)


func _stalker() -> void:
	var s := Stalker.new()
	add_child(s)
	var cam := Camera3D.new()
	cam.fov = 45
	add_child(cam)
	cam.current = true
	await get_tree().create_timer(0.5).timeout
	for mode in [["idle", 0.0, 8, 0.18], ["walk", 1.6, 8, 0.11], ["run", 3.7, 8, 0.07]]:
		s.global_position = Vector3(-6, 0, 0)
		var target := Vector3(60, 0, 0)
		var spd: float = mode[1]
		# warm up the gait, then film it from the side
		var warm := 0.0
		while warm < 1.2:
			await get_tree().process_frame
			var d := get_process_delta_time()
			warm += d
			if spd > 0.0:
				s.move_to(target, spd, d)
		var mover := func():
			while is_instance_valid(s) and spd > 0.0:
				await get_tree().process_frame
				s.move_to(target, spd, get_process_delta_time())
		mover.call()
		await _strip(cam, mode[2], mode[3], "stalker_" + mode[0] + "_side", s, Vector3(0, 1.4, 3.6), Vector3(0, 1.2, 0))
		spd = 0.0
		await get_tree().process_frame
	# head-on, running at the camera
	s.global_position = Vector3(0, 0, -20)
	var spd2 := 3.7
	var run_at := func():
		while is_instance_valid(s) and spd2 > 0.0:
			await get_tree().process_frame
			s.move_to(Vector3(0, 0, 40), spd2, get_process_delta_time())
	run_at.call()
	await get_tree().create_timer(1.0).timeout
	await _strip(cam, 8, 0.07, "stalker_run_front", s, Vector3(0, 1.7, 5.0), Vector3(0, 1.4, 0))
	spd2 = 0.0


func _leviathan() -> void:
	var lev := Leviathan.new()
	add_child(lev)
	lev.place_head(Vector3(0, 5, -30), Vector3(0, 0, 1))
	var target := Node3D.new()
	add_child(target)
	var last := lev.global_transform.basis
	var worst := 0.0
	var total := 0.0
	var n := 0
	for i in 400:
		target.global_position = Vector3(sin(i * 0.03) * 6.0, 2.0, i * 0.02)
		lev.rush(target.global_position, 3.0 if i < 200 else 8.0)
		await get_tree().process_frame
		var b: Basis = lev._segs[0].global_transform.basis
		var ang := rad_to_deg(b.get_rotation_quaternion().angle_to(last.get_rotation_quaternion()))
		last = b
		if i > 5:
			worst = maxf(worst, ang)
			total += ang
			n += 1
	print("LEVIATHAN HEAD: average turn %.2f deg/frame, worst %.2f deg/frame" % [total / n, worst])
