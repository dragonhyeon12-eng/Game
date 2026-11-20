class_name BedroomZone
extends Zone
## The player's bedroom, late at night. The computer plays the lucid dreaming tutorial; the notebook
## receives the rules; the bed starts the dream.
## The "waking" variant is used by the death sequence: same room, monitor off, lamp off.
##
## Layout (m): interior X -2.6..2.6, Z -2.2..2.2, Y 0..2.6.
##   -X wall: desk + computer   +X wall: bed and wardrobe   -Z wall: window   +Z wall: door

var waking := false
var egg_chance := 0.1        # (the monitor after you die: one time in ten...)
## The dream copy of the room (THE CITY's first stage): morning, the street outside in sunshine,
## and a clock that can't keep its story straight. The reality check happens here.
var dreaming := false
var _desk_notebook: Node3D
var _clock_label: Label3D
var _clock_read := 0          # 0 not read, 1 read once (3:12), 2 changed while unwatched
var _clock_unseen := 0.0

const WALL := Color(0.42, 0.45, 0.52)
const FLOOR := Color(0.30, 0.19, 0.11)
const CEILING := Color(0.75, 0.75, 0.73)
const WOOD := Color(0.24, 0.15, 0.09)
const DARK_WOOD := Color(0.13, 0.08, 0.05)
const TRIM := Color(0.8, 0.79, 0.75)
const PLASTIC := Color(0.03, 0.03, 0.035)


func zone_id() -> String: return "bedroom"
func floor_surface() -> String: return "wood"
func fear_gain() -> float: return 0.5
func fear_decay() -> float: return 4.0
func walk_speed() -> float: return 2.0
func sprint_speed() -> float: return 2.8


func player_start() -> Transform3D:
	if waking or dreaming:
		# sitting up at the edge of the bed, facing the dark monitor
		return Transform3D(Basis.from_euler(Vector3(deg_to_rad(-8), deg_to_rad(90), 0)), Vector3(1.2, 0.05, -0.9))
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(-6), deg_to_rad(90), 0)), Vector3(-1.0, 0.05, -0.6))


func build() -> void:
	_room()
	_furniture()
	_lighting()
	_interactables()
	ambient("room_tone", Vector3(-2.2, 0.8, -0.8), false, -10.0 if not waking else -16.0)
	if dreaming:
		ambient("city", Vector3(0.6, 1.4, -3.0), true, -10.0, 12.0)
		_clock_label = label(Vector3(2.25, 0.62, 0.3), 90, "3:12", 0.07, Color(1.0, 0.25, 0.2))
		if not furnish("alarm_clock", Vector3(2.25, 0.56, 0.3), -90.0):
			box(Vector3(2.25, 0.62, 0.3), Vector3(0.12, 0.1, 0.22), PLASTIC, false)
		_clock_label.position.x -= 0.065


func _room() -> void:
	box(Vector3(0, -0.1, 0), Vector3(5.6, 0.2, 4.8), FLOOR, true, 0.0, "wood")
	box(Vector3(0, 2.7, 0), Vector3(5.6, 0.2, 4.8), CEILING, true, 0.0, "plaster")
	box(Vector3(-2.7, 1.3, 0), Vector3(0.2, 2.6, 4.8), WALL, true, 0.0, "wallpaper")
	box(Vector3(2.7, 1.3, 0), Vector3(0.2, 2.6, 4.8), WALL, true, 0.0, "wallpaper")
	box(Vector3(0, 1.3, 2.3), Vector3(5.6, 2.6, 0.2), WALL, true, 0.0, "wallpaper")
	# -Z wall with a window opening (X -0.1..1.3, Y 0.9..2.0)
	box(Vector3(-1.45, 1.3, -2.3), Vector3(2.7, 2.6, 0.2), WALL, true, 0.0, "wallpaper")
	box(Vector3(2.05, 1.3, -2.3), Vector3(1.5, 2.6, 0.2), WALL, true, 0.0, "wallpaper")
	box(Vector3(0.6, 0.45, -2.3), Vector3(1.4, 0.9, 0.2), WALL, true, 0.0, "wallpaper")
	box(Vector3(0.6, 2.3, -2.3), Vector3(1.4, 0.6, 0.2), WALL, true, 0.0, "wallpaper")
	box(Vector3(0.6, 0.88, -2.22), Vector3(1.5, 0.05, 0.3), TRIM)
	box(Vector3(0.6, 2.0, -2.3), Vector3(1.46, 0.05, 0.08), TRIM, false)
	box(Vector3(-0.12, 1.45, -2.3), Vector3(0.05, 1.15, 0.08), TRIM, false)
	box(Vector3(1.32, 1.45, -2.3), Vector3(0.05, 1.15, 0.08), TRIM, false)
	box(Vector3(0.6, 1.45, -2.3), Vector3(0.03, 1.1, 0.07), TRIM, false)
	box(Vector3(0.6, 1.45, -2.3), Vector3(1.4, 0.03, 0.05), TRIM, false)
	# curtains, half drawn
	if not furnish("curtain", Vector3(-0.32, 0.82, -2.14), 0.0, Vector3.ZERO, Vector3.ZERO, 0.95):
		box(Vector3(-0.3, 1.5, -2.14), Vector3(0.4, 1.3, 0.06), Color(0.25, 0.12, 0.15), false, 0.0, "fabric")
	if not furnish("curtain", Vector3(1.52, 0.82, -2.14), 0.0, Vector3.ZERO, Vector3.ZERO, 0.95):
		box(Vector3(1.5, 1.5, -2.14), Vector3(0.3, 1.3, 0.06), Color(0.25, 0.12, 0.15), false, 0.0, "fabric")
	# outside: night sky, rooftops, one lit window across the road, the moon
	var day := dreaming
	box(Vector3(0.6, 3.0, -16), Vector3(40, 24, 0.2), Color(0.55, 0.75, 0.98) if day else Color(0.012, 0.017, 0.045), false)
	box(Vector3(-2.0, 0.0, -9), Vector3(5, 5, 3), Color(0.85, 0.7, 0.55) if day else Color(0.02, 0.02, 0.025), false, 0.0, "plaster")
	box(Vector3(4.0, -0.5, -10), Vector3(4, 6, 3), Color(0.8, 0.6, 0.55) if day else Color(0.025, 0.02, 0.02), false, 0.0, "plaster")
	part("box", Vector3(3.2, 1.7, -8.45), Vector3(0.5, 0.6, 0.02), Color(1.0, 0.75, 0.4), null, Vector3.ZERO, 2.5)
	if not day:
		part("sphere", Vector3(-3.0, 6.5, -15.5), Vector3.ONE * 1.1, Color(0.85, 0.88, 1.0), null, Vector3.ZERO, 3.0)
	# skirting, rug, posters
	box(Vector3(-2.59, 0.05, 0), Vector3(0.02, 0.1, 4.4), TRIM, false)
	box(Vector3(2.59, 0.05, 0), Vector3(0.02, 0.1, 4.4), TRIM, false)
	box(Vector3(0, 0.05, 2.19), Vector3(5.2, 0.1, 0.02), TRIM, false)
	box(Vector3(0, 0.006, 0), Vector3(2.3, 0.012, 1.7), Color(0.38, 0.16, 0.14), false, 0.0, "carpet")
	box(Vector3(-0.8, 1.6, 2.185), Vector3(0.6, 0.85, 0.02), Color(0.12, 0.2, 0.35), false)
	box(Vector3(-0.8, 1.75, 2.17), Vector3(0.4, 0.3, 0.01), Color(0.8, 0.55, 0.2), false)
	box(Vector3(2.585, 1.7, 0.9), Vector3(0.02, 0.4, 0.55), Color(0.5, 0.6, 0.45), false)
	# door on +Z wall
	door(Vector3(1.5, 0, 2.17), 180, Color(0.62, 0.56, 0.5))


func _furniture() -> void:
	# desk against -X wall
	if not furnish("desk_wood", Vector3(-2.25, 0, -0.8), 90.0, Vector3(1.5, 0.76, 0.7), Vector3(0, 0.38, 0)):
		box(Vector3(-2.25, 0.74, -0.8), Vector3(0.7, 0.04, 1.5), WOOD, true, 0.0, "wood")
		for p in [Vector2(-2.55, -1.5), Vector2(-1.95, -1.5), Vector2(-2.55, -0.1), Vector2(-1.95, -0.1)]:
			box(Vector3(p.x, 0.36, p.y), Vector3(0.04, 0.72, 0.04), DARK_WOOD, true, 0.0, "wood")
	# monitor, keyboard and mouse
	var pc := prop("pc_set", Vector3(-2.43, 0.76, -0.8), 90.0)
	if pc == null:
		shape_at("cylinder", Vector3(-2.42, 0.77, -0.8), Vector3(0.18, 0.02, 0.18), PLASTIC)
		box(Vector3(-2.44, 0.86, -0.8), Vector3(0.04, 0.16, 0.04), PLASTIC, false)
	if pc == null:
		box(Vector3(-2.43, 1.13, -0.8), Vector3(0.05, 0.38, 0.64), PLASTIC)
	else:
		blocker(Vector3(-2.43, 1.13, -0.8), Vector3(0.05, 0.38, 0.64))
	if waking and randf() < egg_chance:
		# ...one time in ten, the monitor isn't showing nothing.
		part("box", Vector3(-2.398, 1.13, -0.8), Vector3(0.01, 0.33, 0.58), Color(0.02, 0.02, 0.02), null, Vector3.ZERO, 0.0)
		_egg_screen()
	elif waking:
		# the monitor is on, showing nothing
		part("box", Vector3(-2.398, 1.13, -0.8), Vector3(0.01, 0.33, 0.58), Color(0.25, 0.3, 0.4), null, Vector3.ZERO, 1.0)
		label(Vector3(-2.388, 1.13, -0.8), 90, "NO SIGNAL", 0.03, Color(0.85, 0.9, 1.0))
	else:
		part("box", Vector3(-2.398, 1.13, -0.8), Vector3(0.01, 0.33, 0.58), Color(0.35, 0.45, 0.65), null, Vector3.ZERO, 1.2)
		label(Vector3(-2.388, 1.17, -0.8), 90, "HOW TO LUCID DREAM TONIGHT!\n(100% WORKING)", 0.03, Color(1, 1, 1))
		label(Vector3(-2.388, 1.03, -0.8), 90, "LucidLarry  -  2.1M views", 0.016, Color(0.8, 0.85, 1.0))
	# keyboard, mouse, mug
	if pc == null:
		box(Vector3(-2.13, 0.77, -0.8), Vector3(0.16, 0.02, 0.44), PLASTIC, false)
		box(Vector3(-2.12, 0.77, -0.4), Vector3(0.1, 0.025, 0.06), PLASTIC, false)
	if not furnish("mug", Vector3(-2.28, 0.76, -1.2), 200.0):
		shape_at("cylinder", Vector3(-2.3, 0.81, -1.38), Vector3(0.08, 0.1, 0.08), Color(0.7, 0.25, 0.2))
	# the notebook (dark red cover)
	_desk_notebook = prop("notebook", Vector3(-2.13, 0.76, -0.2), 90.0)
	if _desk_notebook == null:
		_desk_notebook = part("box", Vector3(-2.13, 0.768, -0.2), Vector3(0.17, 0.016, 0.23), Color(0.42, 0.06, 0.06))
	# desk lamp
	if not furnish("desk_lamp", Vector3(-2.42, 0.76, -1.42), 0.0):
		shape_at("cylinder", Vector3(-2.4, 0.77, -1.42), Vector3(0.12, 0.02, 0.12), PLASTIC)
		box(Vector3(-2.4, 0.98, -1.42), Vector3(0.02, 0.42, 0.02), PLASTIC, false)
		shape_at("cone", Vector3(-2.36, 1.2, -1.42), Vector3(0.14, 0.12, 0.14), PLASTIC)
	# chair
	if not furnish("office_chair", Vector3(-1.62, 0, -0.8), -90.0, Vector3(0.5, 1.0, 0.5), Vector3(0, 0.5, 0)):
		box(Vector3(-1.65, 0.46, -0.8), Vector3(0.44, 0.06, 0.44), PLASTIC)
		box(Vector3(-1.42, 0.8, -0.8), Vector3(0.05, 0.55, 0.42), PLASTIC)
		shape_at("cylinder", Vector3(-1.65, 0.22, -0.8), Vector3(0.05, 0.4, 0.05), PLASTIC)
		shape_at("cylinder", Vector3(-1.65, 0.03, -0.8), Vector3(0.5, 0.04, 0.5), PLASTIC)
	# bed along +X wall, the nightstand by it
	if not furnish("bed_single", Vector3(2.0, 0, -1.02), 0.0, Vector3(1.12, 0.6, 2.06), Vector3(0, 0.3, 0)):
		box(Vector3(2.0, 0.18, -1.02), Vector3(1.12, 0.26, 2.06), DARK_WOOD, true, 0.0, "wood")
		box(Vector3(2.0, 0.4, -1.0), Vector3(1.02, 0.18, 1.94), Color(0.82, 0.82, 0.8), true, 0.0, "fabric")
		box(Vector3(2.0, 0.54, -1.78), Vector3(0.62, 0.11, 0.32), Color(0.88, 0.88, 0.86), false, 0.0, "fabric")
		box(Vector3(2.0, 0.51, -0.78), Vector3(1.04, 0.05, 1.4), Color(0.16, 0.3, 0.36), false, 0.0, "fabric")
		box(Vector3(2.0, 0.62, -2.08), Vector3(1.12, 0.9, 0.08), DARK_WOOD, true, 0.0, "wood")
	else:
		blocker(Vector3(2.0, 0.55, -2.06), Vector3(1.12, 1.1, 0.08))
	if not furnish("nightstand", Vector3(2.25, 0, 0.3), -90.0, Vector3(0.5, 0.56, 0.45), Vector3(0, 0.28, 0)):
		box(Vector3(2.25, 0.28, 0.3), Vector3(0.5, 0.56, 0.45), WOOD, true, 0.0, "wood")
	# wardrobe with the covered mirror
	if not furnish("wardrobe", Vector3(2.25, 0, 1.4), -90.0, Vector3(1.3, 2.0, 0.7), Vector3(0, 1.0, 0)):
		box(Vector3(2.25, 1.0, 1.4), Vector3(0.7, 2.0, 1.3), WOOD, true, 0.0, "wood")
	box(Vector3(1.893, 1.15, 1.4), Vector3(0.016, 1.0, 0.56), Color(0.55, 0.6, 0.62), false, 0.0, 0.1)
	box(Vector3(1.872, 1.28, 1.4), Vector3(0.02, 0.82, 0.62), Color(0.82, 0.8, 0.74), false, 0.0, "fabric")
	box(Vector3(1.86, 1.69, 1.4), Vector3(0.04, 0.06, 0.66), Color(0.78, 0.76, 0.7), false)


func _lighting() -> void:
	if dreaming:
		# morning sun pouring through the window: the dream starts warm and safe
		var envd := make_env(Color(0.9, 0.85, 0.75), 0.55)
		envd.background_mode = Environment.BG_COLOR
		envd.background_color = Color(0.6, 0.78, 1.0)
		envd.glow_intensity = 0.8
		envd.tonemap_exposure = 1.1
		environment(envd)
		spot(Vector3(0.6, 3.4, -4.6), Vector3(1.2, 0, 0.6), Color(1.0, 0.88, 0.7), 4.0, 9.0, 24.0)
		omni(Vector3(0.6, 1.6, -1.6), Color(1.0, 0.9, 0.75), 0.6, 6.0, false)
		return
	var env := make_env(Color(0.25, 0.3, 0.5), 0.12)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.glow_intensity = 0.9
	env.tonemap_exposure = 0.95
	environment(env)
	# moonlight through the window, a sodium street lamp below it
	spot(Vector3(0.6, 2.4, -3.2), Vector3(0.6, 0, 0.2), Color(0.55, 0.65, 1.0), 0.45, 7.0, 20.0)
	omni(Vector3(2.5, -0.4, -7.0), Color(1.0, 0.6, 0.3), 1.0 if waking else 2.0, 9.0)
	if not waking:
		omni(Vector3(-2.3, 1.05, -1.42), Color(1.0, 0.72, 0.42), 1.1, 5.0, false)  # desk lamp (inside its shade: no shadows)
	omni(Vector3(-2.2, 1.13, -0.8), Color(0.6, 0.72, 1.0), 0.6 if not waking else 0.9, 3.5 if not waking else 5.0, false)  # monitor glow


func _interactables() -> void:
	if waking:
		return
	if dreaming:
		_dream_interactables()
		return
	interactable(Vector3(-2.32, 1.12, -0.8), Vector3(0.28, 0.48, 0.72),
		func(): return "The video's over" if Game.has_flag("tutorial_done") else "Watch the video",
		func():
			if Game.has_flag("tutorial_done"):
				Game.hud.show_thought("\"Like and subscribe.\" Yeah. Sure.", 3.0)
			else:
				Game.request_tutorial())
	interactable(Vector3(-2.13, 0.78, -0.2), Vector3(0.3, 0.12, 0.32),
		func(): return "Take the notebook" if Game.has_flag("tutorial_done") else "Notebook",
		func():
			if not Game.has_flag("tutorial_done"):
				Game.hud.show_thought("My dream journal. Empty, mostly. Tonight that changes.", 3.5)
				return
			Game.set_flag("has_notebook")
			_desk_notebook.visible = false
			Game.hud.show_hint("Read the notebook any time: N", 6.0),
		func(): return not Game.has_flag("has_notebook"))
	interactable(Vector3(2.0, 0.5, -1.0), Vector3(1.1, 0.5, 2.0),
		func(): return "Go to sleep",
		func():
			if not Game.has_flag("tutorial_done"):
				Game.hud.show_thought("Not yet. I want to finish that video first.", 3.0)
			elif not Game.has_flag("has_notebook"):
				Game.hud.show_thought("The notebook. I should keep it close tonight.", 3.0)
			else:
				Game.request_sleep())
	interactable(Vector3(1.9, 1.25, 1.4), Vector3(0.16, 0.96, 0.68),
		func(): return "Wardrobe mirror",
		func(): Game.hud.show_thought("There's a towel hanging over the mirror. You leave it there.", 3.5))
	interactable(Vector3(1.5, 1.0, 2.14), Vector3(0.92, 2.0, 0.16),
		func(): return "Door",
		func(): Game.hud.show_thought("It's late. Everyone's asleep.", 2.5))
	interactable(Vector3(0.6, 1.45, -2.22), Vector3(1.4, 1.1, 0.16),
		func(): return "Window",
		func(): Game.hud.show_thought("Quiet street. Somebody left a light on across the road.", 3.0))


func on_player_entered(_from_save: bool) -> void:
	_desk_notebook.visible = waking or (not dreaming and not Game.has_flag("has_notebook"))
	if dreaming:
		_desk_notebook.visible = false
		Game.hud.show_thought("...Morning? No. I was asleep a minute ago.", 4.0)
		Game.hud.show_hint("Reality check: read the clock by the bed. Look away. Read it again.", 8.0)


func _dream_interactables() -> void:
	interactable(Vector3(2.25, 0.62, 0.3), Vector3(0.3, 0.3, 0.4),
		func(): return "Read the clock",
		func():
			if _clock_read == 0:
				_clock_read = 1
				Game.hud.show_thought("3:12. ...Same as when I went to bed. Look away, then read it again.", 4.0)
			elif _clock_read == 1:
				Game.hud.show_thought("Still 3:12. Look away first. Really look away.", 3.0)
			elif not Game.has_flag("city_realitycheck"):
				Game.set_flag("city_realitycheck")
				Sfx.play("chime", -4.0, 0.8)
				Game.hud.show_thought("11:68. That's not a time. ...I'm dreaming. I'm DREAMING.", 4.5)
			else:
				Game.hud.show_thought("It reads something different every time I look.", 3.0))
	interactable(Vector3(1.5, 1.0, 2.14), Vector3(0.92, 2.0, 0.16),
		func(): return "Go outside" if Game.has_flag("city_realitycheck") else "Door",
		func():
			if Game.has_flag("city_realitycheck"):
				Game.leave_dream_house()
			else:
				Game.hud.show_thought("Something's off about this morning. Check first.", 3.0))
	interactable(Vector3(0.6, 1.45, -2.22), Vector3(1.4, 1.1, 0.16),
		func(): return "Window",
		func(): Game.hud.show_thought("Sunshine. Summer. It was the middle of the night a minute ago.", 3.5))


func _process(delta: float) -> void:
	_egg_frame(delta)
	if not dreaming or _clock_label == null:
		return
	# the clock only changes while nobody is reading it
	if _clock_read == 1:
		if Observation.is_observed(_clock_label.global_position, 0.15):
			_clock_unseen = 0.0
		else:
			_clock_unseen += delta
			if _clock_unseen > 1.0:
				_clock_read = 2
				_clock_label.text = "11:68"
	elif _clock_read == 2 and Game.has_flag("city_realitycheck"):
		if not Observation.is_observed(_clock_label.global_position, 0.15) and randf() < delta * 0.5:
			_clock_label.text = "%d:%02d" % [randi_range(1, 99), randi_range(0, 99)]


# ---- the easter egg: a 40-frame clip, 8 x 5 frames to a sheet, 20 frames a second

const EGG_FRAMES := 40
const EGG_COLS := 8
const EGG_ROWS := 5
var _egg_mat: StandardMaterial3D
var _egg_t := 0.0


func _egg_screen() -> void:
	var tex: Texture2D = load("res://assets/textures/no_signal_egg.jpg")
	if tex == null:
		return
	_egg_mat = StandardMaterial3D.new()
	_egg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_egg_mat.albedo_texture = tex
	_egg_mat.uv1_scale = Vector3(1.0 / EGG_COLS, 1.0 / EGG_ROWS, 1.0)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.33, 0.33)
	q.mesh = qm
	q.material_override = _egg_mat
	q.position = Vector3(-2.391, 1.13, -0.8)
	q.rotation_degrees.y = 90.0           # facing into the room
	add_child(q)
	set_process(true)


func _egg_frame(delta: float) -> void:
	if _egg_mat == null:
		return
	_egg_t += delta
	var f := int(_egg_t * 20.0) % EGG_FRAMES
	_egg_mat.uv1_offset = Vector3(float(f % EGG_COLS) / EGG_COLS, float(f / EGG_COLS) / EGG_ROWS, 0.0)
