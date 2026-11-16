class_name BedroomZone
extends Zone
## The player's bedroom, late at night. The computer plays the lucid dreaming tutorial; the notebook
## receives the rules; the bed starts the dream.
## The "waking" variant is used by the death sequence: same room, monitor off, lamp off.
##
## Layout (m): interior X -2.6..2.6, Z -2.2..2.2, Y 0..2.6.
##   -X wall: desk + computer   +X wall: bed and wardrobe   -Z wall: window   +Z wall: door

var waking := false
var _desk_notebook: MeshInstance3D

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
	if waking:
		# sitting up at the edge of the bed, facing the dark monitor
		return Transform3D(Basis.from_euler(Vector3(deg_to_rad(-8), deg_to_rad(90), 0)), Vector3(1.2, 0.05, -0.9))
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(-6), deg_to_rad(90), 0)), Vector3(-1.0, 0.05, -0.6))


func build() -> void:
	_room()
	_furniture()
	_lighting()
	_interactables()
	ambient("room_tone", Vector3(-2.2, 0.8, -0.8), false, -10.0 if not waking else -16.0)


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
	box(Vector3(-0.3, 1.5, -2.14), Vector3(0.4, 1.3, 0.06), Color(0.25, 0.12, 0.15), false, 0.0, "fabric")
	box(Vector3(1.5, 1.5, -2.14), Vector3(0.3, 1.3, 0.06), Color(0.25, 0.12, 0.15), false, 0.0, "fabric")
	# outside: night sky, rooftops, one lit window across the road, the moon
	box(Vector3(0.6, 3.0, -16), Vector3(40, 24, 0.2), Color(0.012, 0.017, 0.045), false)
	box(Vector3(-2.0, 0.0, -9), Vector3(5, 5, 3), Color(0.02, 0.02, 0.025), false)
	box(Vector3(4.0, -0.5, -10), Vector3(4, 6, 3), Color(0.025, 0.02, 0.02), false)
	part("box", Vector3(3.2, 1.7, -8.45), Vector3(0.5, 0.6, 0.02), Color(1.0, 0.75, 0.4), null, Vector3.ZERO, 2.5)
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
	box(Vector3(-2.25, 0.74, -0.8), Vector3(0.7, 0.04, 1.5), WOOD, true, 0.0, "wood")
	for p in [Vector2(-2.55, -1.5), Vector2(-1.95, -1.5), Vector2(-2.55, -0.1), Vector2(-1.95, -0.1)]:
		box(Vector3(p.x, 0.36, p.y), Vector3(0.04, 0.72, 0.04), DARK_WOOD, true, 0.0, "wood")
	# monitor
	shape_at("cylinder", Vector3(-2.42, 0.77, -0.8), Vector3(0.18, 0.02, 0.18), PLASTIC)
	box(Vector3(-2.44, 0.86, -0.8), Vector3(0.04, 0.16, 0.04), PLASTIC, false)
	box(Vector3(-2.43, 1.13, -0.8), Vector3(0.05, 0.38, 0.64), PLASTIC)
	if waking:
		part("box", Vector3(-2.398, 1.13, -0.8), Vector3(0.01, 0.33, 0.58), Color(0.01, 0.01, 0.012))
	else:
		part("box", Vector3(-2.398, 1.13, -0.8), Vector3(0.01, 0.33, 0.58), Color(0.35, 0.45, 0.65), null, Vector3.ZERO, 1.2)
		label(Vector3(-2.388, 1.17, -0.8), 90, "HOW TO LUCID DREAM TONIGHT!\n(100% WORKING)", 0.03, Color(1, 1, 1))
		label(Vector3(-2.388, 1.03, -0.8), 90, "LucidLarry  -  2.1M views", 0.016, Color(0.8, 0.85, 1.0))
	# keyboard, mouse, mug
	box(Vector3(-2.13, 0.77, -0.8), Vector3(0.16, 0.02, 0.44), PLASTIC, false)
	box(Vector3(-2.12, 0.77, -0.4), Vector3(0.1, 0.025, 0.06), PLASTIC, false)
	shape_at("cylinder", Vector3(-2.3, 0.81, -1.38), Vector3(0.08, 0.1, 0.08), Color(0.7, 0.25, 0.2))
	# the notebook (dark red cover)
	_desk_notebook = part("box", Vector3(-2.13, 0.768, -0.2), Vector3(0.17, 0.016, 0.23), Color(0.42, 0.06, 0.06))
	# desk lamp
	shape_at("cylinder", Vector3(-2.4, 0.77, -1.42), Vector3(0.12, 0.02, 0.12), PLASTIC)
	box(Vector3(-2.4, 0.98, -1.42), Vector3(0.02, 0.42, 0.02), PLASTIC, false)
	shape_at("cone", Vector3(-2.36, 1.2, -1.42), Vector3(0.14, 0.12, 0.14), PLASTIC)
	# chair
	box(Vector3(-1.65, 0.46, -0.8), Vector3(0.44, 0.06, 0.44), PLASTIC)
	box(Vector3(-1.42, 0.8, -0.8), Vector3(0.05, 0.55, 0.42), PLASTIC)
	shape_at("cylinder", Vector3(-1.65, 0.22, -0.8), Vector3(0.05, 0.4, 0.05), PLASTIC)
	shape_at("cylinder", Vector3(-1.65, 0.03, -0.8), Vector3(0.5, 0.04, 0.5), PLASTIC)
	# bed along +X wall
	box(Vector3(2.0, 0.18, -1.02), Vector3(1.12, 0.26, 2.06), DARK_WOOD, true, 0.0, "wood")
	box(Vector3(2.0, 0.4, -1.0), Vector3(1.02, 0.18, 1.94), Color(0.82, 0.82, 0.8), true, 0.0, "fabric")
	box(Vector3(2.0, 0.54, -1.78), Vector3(0.62, 0.11, 0.32), Color(0.88, 0.88, 0.86), false, 0.0, "fabric")
	box(Vector3(2.0, 0.51, -0.78), Vector3(1.04, 0.05, 1.4), Color(0.16, 0.3, 0.36), false, 0.0, "fabric")
	box(Vector3(2.0, 0.62, -2.08), Vector3(1.12, 0.9, 0.08), DARK_WOOD, true, 0.0, "wood")
	box(Vector3(2.25, 0.28, 0.3), Vector3(0.5, 0.56, 0.45), WOOD, true, 0.0, "wood")
	# wardrobe with the covered mirror
	box(Vector3(2.25, 1.0, 1.4), Vector3(0.7, 2.0, 1.3), WOOD, true, 0.0, "wood")
	box(Vector3(1.893, 1.15, 1.4), Vector3(0.016, 1.0, 0.56), Color(0.55, 0.6, 0.62), false, 0.0, 0.1)
	box(Vector3(1.872, 1.28, 1.4), Vector3(0.02, 0.82, 0.62), Color(0.82, 0.8, 0.74), false, 0.0, "fabric")
	box(Vector3(1.86, 1.69, 1.4), Vector3(0.04, 0.06, 0.66), Color(0.78, 0.76, 0.7), false)


func _lighting() -> void:
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
		omni(Vector3(-2.2, 1.13, -0.8), Color(0.6, 0.72, 1.0), 0.6, 3.5, false)  # monitor glow


func _interactables() -> void:
	if waking:
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
	_desk_notebook.visible = waking or not Game.has_flag("has_notebook")
